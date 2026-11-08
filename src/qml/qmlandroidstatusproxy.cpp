#include <android/log.h>
#include "qml/qmlandroidstatusproxy.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/private/qandroidextras_p.h>
#include <QDir>
#include <QHash>
#include <QStorageInfo>
#include <QFile>
#include <QFileInfo>

#include "controllers/midi/androidmidicontroller.h"
#include "moc_qmlandroidstatusproxy.cpp"
#include "util/androidtrackcache.h"

namespace mixxx {
namespace qml {

namespace {
constexpr int kUpdateIntervalMs = 500;

// Volume ids (uuid) of the removable volumes. Apps cannot list /storage or
// /mnt/media_rw; the mount table shows them as /mnt/media_rw/<uuid> (same
// approach as the Rekordbox scanner).
QStringList removableVolumeIds() {
    // Reading the mount table directly is much cheaper than
    // QStorageInfo::mountedVolumes(), which calls statfs() for every mount.
    QStringList ids;
    QFile mountInfo(QStringLiteral("/proc/self/mountinfo"));
    if (!mountInfo.open(QIODevice::ReadOnly)) {
        return ids;
    }
    // Files in /proc report size 0: atEnd() / readLine() do not work, read it all.
    const QList<QByteArray> lines = mountInfo.readAll().split('\n');
    for (const QByteArray& line : lines) {
        // Format: id parent major:minor root mountpoint options ...
        const QList<QByteArray> fields = line.split(' ');
        if (fields.size() < 5) {
            continue;
        }
        const QString root = QString::fromUtf8(fields.at(4));
        const bool removable = root.startsWith(QStringLiteral("/mnt/media_rw/")) ||
                (root.startsWith(QStringLiteral("/storage/")) &&
                        !root.startsWith(QStringLiteral("/storage/emulated")) &&
                        !root.startsWith(QStringLiteral("/storage/self")));
        if (removable) {
            const QString id = QFileInfo(root).fileName();
            if (!id.isEmpty() && !ids.contains(id)) {
                ids.append(id);
            }
        }
    }
    ids.sort();
    return ids;
}
} // namespace

QmlAndroidStatusProxy::QmlAndroidStatusProxy(QObject* parent)
        : QObject(parent) {
    connect(&m_timer, &QTimer::timeout, this, &QmlAndroidStatusProxy::update);
    m_timer.start(kUpdateIntervalMs);
    update();
}

void QmlAndroidStatusProxy::readBattery() {
    // The battery state is a sticky broadcast: registerReceiver(null, filter)
    // returns the last value without registering a receiver.
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        return;
    }
    const QJniObject action = QJniObject::fromString(QStringLiteral("android.intent.action.BATTERY_CHANGED"));
    const QJniObject filter("android/content/IntentFilter", "(Ljava/lang/String;)V", action.object<jstring>());
    const QJniObject intent = context.callObjectMethod("registerReceiver",
            "(Landroid/content/BroadcastReceiver;Landroid/content/IntentFilter;)Landroid/content/Intent;",
            nullptr,
            filter.object());
    if (!intent.isValid()) {
        QJniEnvironment().checkAndClearExceptions();
        return;
    }
    const QJniObject levelKey = QJniObject::fromString(QStringLiteral("level"));
    const QJniObject scaleKey = QJniObject::fromString(QStringLiteral("scale"));
    const QJniObject statusKey = QJniObject::fromString(QStringLiteral("status"));
    const jint level = intent.callMethod<jint>(
            "getIntExtra", "(Ljava/lang/String;I)I", levelKey.object<jstring>(), jint(-1));
    const jint scale = intent.callMethod<jint>(
            "getIntExtra", "(Ljava/lang/String;I)I", scaleKey.object<jstring>(), jint(-1));
    const jint status = intent.callMethod<jint>(
            "getIntExtra", "(Ljava/lang/String;I)I", statusKey.object<jstring>(), jint(-1));
    QJniEnvironment().checkAndClearExceptions();
    if (level >= 0 && scale > 0) {
        m_batteryPercent = (level * 100) / scale;
    }
    // BatteryManager.BATTERY_STATUS_CHARGING = 2, BATTERY_STATUS_FULL = 5
    m_batteryCharging = status == 2 || status == 5;
}

// The output of Mixxx must not depend on the phone's media volume (Android
// applies it in software to USB audio devices): while the app is in the
// foreground and the controller is connected the music volume is kept at the maximum.
void QmlAndroidStatusProxy::keepMaxVolume() {
    if (QGuiApplication::applicationState() != Qt::ApplicationActive) {
        return;
    }
    // Without the controller the tablet speaker / headphones are used: the user's
    // volume stays as it is.
    if (!m_controllerConnected) {
        return;
    }
    constexpr jint kStreamMusic = 3;
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        return;
    }
    const QJniObject audio = context.callObjectMethod("getSystemService",
            "(Ljava/lang/String;)Ljava/lang/Object;",
            QJniObject::fromString(QStringLiteral("audio")).object<jstring>());
    if (audio.isValid()) {
        const jint maxVolume = audio.callMethod<jint>("getStreamMaxVolume", "(I)I", kStreamMusic);
        const jint volume = audio.callMethod<jint>("getStreamVolume", "(I)I", kStreamMusic);
        if (maxVolume > 0 && volume < maxVolume) {
            audio.callMethod<void>("setStreamVolume", "(III)V", kStreamMusic, maxVolume, jint(0));
        }
    }
    QJniEnvironment().checkAndClearExceptions();
}

namespace {
// The name of a removable volume as Android shows it (the label of the stick,
// e.g. "BIGGO 2"), looked up by the uuid of the volume (e.g. "181B-156E").
QString volumeDescription(const QString& uuid) {
    static QHash<QString, QString> cache;
    const auto cached = cache.constFind(uuid);
    if (cached != cache.constEnd()) {
        return cached.value();
    }
    QString result;
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    const QJniObject serviceName = QJniObject::fromString(QStringLiteral("storage"));
    const QJniObject manager = context.callObjectMethod("getSystemService",
            "(Ljava/lang/String;)Ljava/lang/Object;",
            serviceName.object<jstring>());
    if (manager.isValid()) {
        const QJniObject volumes = manager.callObjectMethod("getStorageVolumes", "()Ljava/util/List;");
        if (volumes.isValid()) {
            const int count = volumes.callMethod<jint>("size");
            for (int i = 0; i < count; ++i) {
                const QJniObject volume = volumes.callObjectMethod(
                        "get", "(I)Ljava/lang/Object;", i);
                const QJniObject volumeUuid = volume.callObjectMethod(
                        "getUuid", "()Ljava/lang/String;");
                if (volumeUuid.isValid() &&
                        volumeUuid.toString().compare(uuid, Qt::CaseInsensitive) == 0) {
                    const QJniObject description = volume.callObjectMethod("getDescription",
                            "(Landroid/content/Context;)Ljava/lang/String;",
                            context.object());
                    if (description.isValid()) {
                        result = description.toString();
                    }
                    break;
                }
            }
        }
    }
    QJniEnvironment().checkAndClearExceptions();
    if (!result.isEmpty()) {
        cache.insert(uuid, result);
    }
    return result;
}

QVariantMap storageDetails(const QString& path, const QString& fallbackLabel) {
    QVariantMap info;
    const QStorageInfo storage(path);
    info.insert(QStringLiteral("present"), storage.isValid() && storage.isReady());
    info.insert(QStringLiteral("path"), path);
    QString label = storage.name();
    if (label.isEmpty()) {
        label = fallbackLabel;
    }
    info.insert(QStringLiteral("label"), label);
    info.insert(QStringLiteral("total"), static_cast<double>(storage.bytesTotal()));
    info.insert(QStringLiteral("free"), static_cast<double>(storage.bytesAvailable()));
    return info;
}
} // namespace

QVariantMap QmlAndroidStatusProxy::stickInfo(int slot) const {
    if (slot < 1 || slot > 2 || m_slotIds[slot - 1].isEmpty()) {
        QVariantMap none;
        none.insert(QStringLiteral("present"), false);
        return none;
    }
    const QString id = m_slotIds[slot - 1];
    QString path = QStringLiteral("/storage/") + id;
    if (!QDir(path).exists()) {
        path = QStringLiteral("/mnt/media_rw/") + id;
    }
    QVariantMap info = storageDetails(path, id);
    const QString description = volumeDescription(id);
    if (!description.isEmpty()) {
        info.insert(QStringLiteral("label"), description);
    }
    return info;
}

QVariantMap QmlAndroidStatusProxy::tabletInfo() const {
    return storageDetails(QStringLiteral("/storage/emulated/0"), QStringLiteral("Tablet"));
}

QStringList QmlAndroidStatusProxy::subDirectories(const QString& path) const {
    QStringList names;
    const QDir dir(path);
    const QFileInfoList entries = dir.entryInfoList(
            QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable, QDir::Name | QDir::IgnoreCase);
    for (const QFileInfo& entry : entries) {
        if (!entry.fileName().startsWith(QLatin1Char('.'))) {
            names << entry.fileName();
        }
    }
    return names;
}

void QmlAndroidStatusProxy::update() {
    keepMaxVolume();
    const int oldPercent = m_batteryPercent;
    const bool oldCharging = m_batteryCharging;
    const bool oldController = m_controllerConnected;
    const QString oldName = m_controllerName;
    const bool oldStick = m_stickPresent;
    const int oldCopies = m_cacheCopies;
    const bool oldSlotPresent[2] = {m_slotPresent[0], m_slotPresent[1]};
    const bool oldSlotBusy[2] = {m_slotBusy[0], m_slotBusy[1]};

    // The battery is not shown in the UI any more: no JNI call needed.
    m_controllerConnected = AndroidMidiController::openControllerCount() > 0;
    m_controllerName = m_controllerConnected
            ? AndroidMidiController::lastOpenedControllerName()
            : QString();

    // A stick keeps its slot (USB1 / USB2) while it stays plugged in.
    const QStringList ids = removableVolumeIds();
    for (QString& slotId : m_slotIds) {
        if (!ids.contains(slotId)) {
            slotId.clear();
        }
    }
    for (const QString& id : ids) {
        if (id == m_slotIds[0] || id == m_slotIds[1]) {
            continue;
        }
        for (QString& slotId : m_slotIds) {
            if (slotId.isEmpty()) {
                slotId = id;
                break;
            }
        }
    }
    m_stickPresent = !ids.isEmpty();
    const QStringList pending = AndroidTrackCache::instance().busyPaths(2500);
    for (int slot = 0; slot < 2; ++slot) {
        m_slotPresent[slot] = !m_slotIds[slot].isEmpty();
        m_slotBusy[slot] = false;
        if (m_slotPresent[slot]) {
            const QString marker = QStringLiteral("/") + m_slotIds[slot] + QStringLiteral("/");
            for (const QString& path : pending) {
                if (path.contains(marker)) {
                    m_slotBusy[slot] = true;
                    break;
                }
            }
        }
    }
    m_cacheCopies = AndroidTrackCache::instance().pendingCopies();

    if (oldPercent != m_batteryPercent || oldCharging != m_batteryCharging ||
            oldController != m_controllerConnected || oldName != m_controllerName ||
            oldStick != m_stickPresent || oldCopies != m_cacheCopies ||
            oldSlotPresent[0] != m_slotPresent[0] || oldSlotPresent[1] != m_slotPresent[1] ||
            oldSlotBusy[0] != m_slotBusy[0] || oldSlotBusy[1] != m_slotBusy[1]) {
        emit changed();
    }
}

void QmlAndroidStatusProxy::setScreenBrightness(double value) {
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([value]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) {
            return;
        }
        QJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (!window.isValid()) {
            return;
        }
        QJniObject attributes = window.callObjectMethod(
                "getAttributes", "()Landroid/view/WindowManager$LayoutParams;");
        if (!attributes.isValid()) {
            return;
        }
        attributes.setField<jfloat>("screenBrightness", static_cast<jfloat>(value));
        window.callMethod<void>("setAttributes",
                "(Landroid/view/WindowManager$LayoutParams;)V",
                attributes.object());
    });
}

void QmlAndroidStatusProxy::lockScreen() {
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) {
            return;
        }
        QJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (window.isValid()) {
            // FLAG_KEEP_SCREEN_ON: the screen stays on while the app is in front.
            window.callMethod<void>("addFlags", "(I)V", 0x00000080);
            // Fixed refresh rate: the adaptive (variable) refresh of some phones makes
            // a still picture flicker when the rate changes.
            QJniObject attributes = window.callObjectMethod(
                    "getAttributes", "()Landroid/view/WindowManager$LayoutParams;");
            if (attributes.isValid()) {
                attributes.setField<jfloat>("preferredRefreshRate", 60.0f);
                window.callMethod<void>("setAttributes",
                        "(Landroid/view/WindowManager$LayoutParams;)V",
                        attributes.object());
            }
            QJniObject decor = window.callObjectMethod("getDecorView", "()Landroid/view/View;");
            if (decor.isValid()) {
                // IMMERSIVE_STICKY | HIDE_NAVIGATION | FULLSCREEN | LAYOUT_*
                decor.callMethod<void>("setSystemUiVisibility", "(I)V", 0x1706);
            }
        }
    });
}

void QmlAndroidStatusProxy::log(const QString& text) {
    __android_log_print(ANDROID_LOG_INFO, "mixxx-qml", "%s", text.toUtf8().constData());
}

void QmlAndroidStatusProxy::quitApp() {
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) {
            return;
        }
        activity.callMethod<void>("finishAndRemoveTask", "()V");
    });
}

} // namespace qml
} // namespace mixxx
