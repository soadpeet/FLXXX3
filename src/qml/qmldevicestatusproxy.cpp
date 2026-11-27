#include "qml/qmldevicestatusproxy.h"

#include <QDir>
#include <QFileInfo>
#include <QStorageInfo>
#include <QtConcurrent>

#include "controllers/controller.h"
#include "moc_qmldevicestatusproxy.cpp"
#include "platform/platformservices.h"
#include "util/logging.h"

namespace mixxx {
namespace qml {

namespace {
constexpr int kUpdateIntervalMs = 500;

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

QmlDeviceStatusProxy::QmlDeviceStatusProxy(QObject* parent)
        : QObject(parent) {
    connect(&m_timer, &QTimer::timeout, this, &QmlDeviceStatusProxy::update);
    connect(&m_idsWatcher,
            &QFutureWatcher<QStringList>::finished,
            this,
            &QmlDeviceStatusProxy::onVolumeIdsRead);
    m_timer.start(kUpdateIntervalMs);
    update();
}

QVariantMap QmlDeviceStatusProxy::stickInfo(int slot) const {
    if (slot < 1 || slot > 2 || m_slotIds[slot - 1].isEmpty()) {
        QVariantMap none;
        none.insert(QStringLiteral("present"), false);
        return none;
    }
    const QString id = m_slotIds[slot - 1];
    QVariantMap info = storageDetails(platform::removableVolumePath(id), id);
    // The id as the Rekordbox device list names the volume (uuid on Android, "E:" on Windows).
    info.insert(QStringLiteral("id"), id);
    const QString label = platform::removableVolumeLabel(id);
    if (!label.isEmpty()) {
        info.insert(QStringLiteral("label"), label);
    }
    return info;
}

QVariantMap QmlDeviceStatusProxy::tabletInfo() const {
    const QString name = platform::internalStorageName();
    QVariantMap info = storageDetails(platform::internalStoragePath(), name);
    info.insert(QStringLiteral("name"), name);
    return info;
}

QStringList QmlDeviceStatusProxy::subDirectories(const QString& path) const {
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

void QmlDeviceStatusProxy::update() {
    if (!m_idsWatcher.isRunning()) {
        m_idsWatcher.setFuture(QtConcurrent::run(platform::removableVolumeIds));
    }
    refreshState();
}

void QmlDeviceStatusProxy::onVolumeIdsRead() {
    m_volumeIds = m_idsWatcher.result();
    refreshState();
}

void QmlDeviceStatusProxy::refreshState() {
    const bool oldController = m_controllerConnected;
    const QString oldName = m_controllerName;
    const bool oldStick = m_stickPresent;
    const int oldCopies = m_cacheCopies;
    const bool oldSlotPresent[2] = {m_slotPresent[0], m_slotPresent[1]};
    const bool oldSlotBusy[2] = {m_slotBusy[0], m_slotBusy[1]};

    m_controllerConnected = Controller::openControllerCount() > 0;
    m_controllerName = m_controllerConnected
            ? Controller::lastOpenedControllerName()
            : QString();

    // A stick keeps its slot (USB1 / USB2) while it stays plugged in.
    const QStringList ids = m_volumeIds;
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
    const QStringList pending = platform::trackCacheBusyPaths(2500);
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
    m_cacheCopies = platform::trackCachePendingCopies();

    if (oldController != m_controllerConnected || oldName != m_controllerName ||
            oldStick != m_stickPresent || oldCopies != m_cacheCopies ||
            oldSlotPresent[0] != m_slotPresent[0] || oldSlotPresent[1] != m_slotPresent[1] ||
            oldSlotBusy[0] != m_slotBusy[0] || oldSlotBusy[1] != m_slotBusy[1]) {
        emit changed();
    }
}

void QmlDeviceStatusProxy::setScreenBrightness(double value) {
    platform::setScreenBrightness(value);
}

void QmlDeviceStatusProxy::lockScreen() {
    platform::keepScreenOn();
}

void QmlDeviceStatusProxy::log(const QString& text) {
    platform::log(text);
}

QString QmlDeviceStatusProxy::logFilePath() const {
    return Logging::logFilePath();
}

int QmlDeviceStatusProxy::ejectStick(int slot) {
    if (slot < 1 || slot > 2 || m_slotIds[slot - 1].isEmpty()) {
        return 1;
    }
    return platform::ejectRemovableVolume(m_slotIds[slot - 1]);
}

void QmlDeviceStatusProxy::setStartMonitor(int index) {
    platform::setStartMonitor(index);
}

void QmlDeviceStatusProxy::shareLog() {
    Logging::flushLogFile();
    const QString path = Logging::logFilePath();
    if (!path.isEmpty()) {
        platform::shareLogFiles(path);
    }
}

void QmlDeviceStatusProxy::quitApp() {
    platform::quitApp();
}

} // namespace qml
} // namespace mixxx
