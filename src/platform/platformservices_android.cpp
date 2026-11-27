// AI disclaimer: this file was written autonomously by an AI agent (Claude).
// Android implementation of the platform services (see platformservices.h).

#include <android/log.h>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJniEnvironment>
#include <QJniObject>
#include <QRegularExpression>
#include <QtCore/private/qandroidextras_p.h>

#include "platform/platformservices.h"
#include "util/androidtrackcache.h"

namespace mixxx::platform {

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
QString removableVolumePath(const QString& id) {
    const QString path = QStringLiteral("/storage/") + id;
    if (QDir(path).exists()) {
        return path;
    }
    return QStringLiteral("/mnt/media_rw/") + id;
}

// The name of a removable volume as Android shows it (the label of the stick,
// e.g. "BIGGO 2"), looked up by the uuid of the volume (e.g. "181B-156E").
QString removableVolumeLabel(const QString& uuid) {
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

QString removableVolumeIdOfPath(const QString& filePath) {
    static const QRegularExpression volumePath(
            QStringLiteral("^/(?:mnt/media_rw|storage)/([^/]+)/"));
    const QRegularExpressionMatch match = volumePath.match(filePath);
    if (!match.hasMatch()) {
        return {};
    }
    const QString id = match.captured(1);
    if (id == QStringLiteral("emulated") || id == QStringLiteral("self")) {
        return {};
    }
    return id;
}

QString removableVolumeRelativePath(const QString& filePath) {
    static const QRegularExpression volumePrefix(
            QStringLiteral("^/(?:mnt/media_rw|storage)/[^/]+"));
    if (removableVolumeIdOfPath(filePath).isEmpty()) {
        return {};
    }
    QString relative = filePath;
    relative.remove(volumePrefix);
    return relative;
}

QString internalStoragePath() {
    return QStringLiteral("/storage/emulated/0");
}

QString internalStorageName() {
    return QStringLiteral("TABLET");
}

QStringList trackCacheBusyPaths(int recentMs) {
    return AndroidTrackCache::instance().busyPaths(recentMs);
}

int trackCachePendingCopies() {
    return AndroidTrackCache::instance().pendingCopies();
}

void setScreenBrightness(double value) {
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
        // Only on a real change: every change of the attributes lays the window out again
        // (at the start NORMAL is set, which is the value the window already has).
        if (attributes.getField<jfloat>("screenBrightness") == static_cast<jfloat>(value)) {
            return;
        }
        attributes.setField<jfloat>("screenBrightness", static_cast<jfloat>(value));
        window.callMethod<void>("setAttributes",
                "(Landroid/view/WindowManager$LayoutParams;)V",
                attributes.object());
    });
}

void keepScreenOn() {
    // The screen-on flag, the refresh rate and the full screen are set by MainActivity.onCreate,
    // before anything is drawn: changing them here (when the QML was ready) laid the window out
    // again while Qt was drawing, which crashed the app in the system graphics now and then.
}

void log(const QString& text) {
    logDiagnostic("mixxx-qml", text);
}

void logDiagnostic(const char* tag, const QString& text) {
    __android_log_print(ANDROID_LOG_INFO, tag, "%s", text.toUtf8().constData());
}

void quitApp() {
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) {
            return;
        }
        activity.callMethod<void>("finishAndRemoveTask", "()V");
    });
}

int ejectRemovableVolume(const QString& id) {
    Q_UNUSED(id);
    // An app cannot unmount a stick on Android: the storage settings of the system open,
    // where the stick has its eject button.
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) {
            return;
        }
        QJniObject intent("android/content/Intent",
                "(Ljava/lang/String;)V",
                QJniObject::fromString(QStringLiteral("android.settings.INTERNAL_STORAGE_SETTINGS"))
                        .object<jstring>());
        intent.callObjectMethod("addFlags", "(I)Landroid/content/Intent;", 0x10000000);
        activity.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", intent.object());
    });
    return 2;
}

void shareLogFiles(const QString& logFilePath) {
    const QDir folder = QFileInfo(logFilePath).absoluteDir();
    QStringList paths;
    // The current log, the one of the run before (e.g. the run that crashed) and the crash
    // reports, if there are any.
    const QString logName = QFileInfo(logFilePath).fileName();
    const QStringList names{logName, logName + QStringLiteral(".1"), QStringLiteral("crash.txt")};
    for (const QString& name : names) {
        const QFileInfo file(folder.filePath(name));
        if (file.exists() && file.size() > 0) {
            paths << file.absoluteFilePath();
        }
    }
    if (paths.isEmpty()) {
        return;
    }
    QJniEnvironment env;
    jobjectArray array = env->NewObjectArray(static_cast<jsize>(paths.size()),
            env->FindClass("java/lang/String"),
            nullptr);
    for (int i = 0; i < paths.size(); ++i) {
        QJniObject text = QJniObject::fromString(paths.at(i));
        env->SetObjectArrayElement(array, i, text.object<jstring>());
    }
    QJniObject::callStaticMethod<void>("de/biggo/flxxx3/MainActivity",
            "shareFiles",
            "([Ljava/lang/String;Ljava/lang/String;)V",
            array,
            QJniObject::fromString(QStringLiteral("FLXXX3 log")).object<jstring>());
    env->DeleteLocalRef(array);
}

QStringList midiInputNames(bool* pSupported) {
    // Android: AndroidMidiEnumerator lists the devices itself.
    if (pSupported) {
        *pSupported = false;
    }
    return {};
}

} // namespace mixxx::platform
