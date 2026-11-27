// AI disclaimer: this file was written autonomously by an AI agent (Claude).
// Desktop implementation of the platform services (Windows, Linux; see platformservices.h).

#include <QCoreApplication>
#include <QDebug>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <QHash>
#include <QMutex>
#include <QStandardPaths>
#include <QStorageInfo>

#include "platform/platformservices.h"

#ifdef Q_OS_WIN
#include <windows.h>
#include <winioctl.h>
// WinMM (MIDI device list), after windows.h
#include <mmsystem.h>
#ifdef _MSC_VER
#pragma comment(lib, "winmm.lib")
#endif
#endif

namespace mixxx::platform {

namespace {
// id -> path of the volumes found by the last removableVolumeIds() (called from a worker).
QMutex s_mutex;
QHash<QString, QString> s_paths;

// A Rekordbox export (PIONEER folder) on a drive that is not the system drive counts as a
// stick too: USB hard disks report as fixed drives.
bool hasRekordboxExport(const QString& root) {
    return QDir(root + QStringLiteral("PIONEER")).exists() ||
            QDir(root + QStringLiteral("Contents")).exists();
}
} // namespace

QStringList removableVolumeIds() {
    QHash<QString, QString> found;
    const QList<QStorageInfo> volumes = QStorageInfo::mountedVolumes();
    for (const QStorageInfo& volume : volumes) {
        if (!volume.isValid() || !volume.isReady()) {
            continue;
        }
        QString root = volume.rootPath();
        if (!root.endsWith(QLatin1Char('/'))) {
            root += QLatin1Char('/');
        }
#ifdef Q_OS_WIN
        // "E:/" -> id "E:" (the name the Rekordbox device list uses on Windows).
        const UINT type = GetDriveTypeW(reinterpret_cast<LPCWSTR>(root.utf16()));
        const bool systemDrive = root.startsWith(QDir::rootPath(), Qt::CaseInsensitive);
        if (type == DRIVE_REMOVABLE || (!systemDrive && hasRekordboxExport(root))) {
            QString id = root;
            id.chop(1);
            found.insert(id, root);
        }
#else
        // Linux: sticks are mounted below /media or /run/media.
        if (root.startsWith(QStringLiteral("/media/")) ||
                root.startsWith(QStringLiteral("/run/media/"))) {
            QString path = root;
            path.chop(1);
            found.insert(QDir(path).dirName(), root);
        }
#endif
    }
    QStringList ids = found.keys();
    ids.sort();
    const QMutexLocker locker(&s_mutex);
    s_paths = found;
    return ids;
}

int ejectRemovableVolume(const QString& id) {
#ifdef Q_OS_WIN
    // id "E:" -> the volume \\.\E: : lock (fails while files are open), dismount, allow
    // removal, eject.
    const QString device = QStringLiteral("\\\\.\\") + id;
    HANDLE handle = CreateFileW(reinterpret_cast<LPCWSTR>(device.utf16()),
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            nullptr,
            OPEN_EXISTING,
            0,
            nullptr);
    if (handle == INVALID_HANDLE_VALUE) {
        qWarning() << "FLXXX3: eject" << id << "cannot open the volume";
        return 1;
    }
    DWORD returned = 0;
    bool locked = false;
    for (int attempt = 0; attempt < 5 && !locked; ++attempt) {
        locked = DeviceIoControl(handle, FSCTL_LOCK_VOLUME, nullptr, 0, nullptr, 0, &returned, nullptr);
        if (!locked) {
            Sleep(300);
        }
    }
    if (!locked) {
        qWarning() << "FLXXX3: eject" << id << "the volume is in use";
        CloseHandle(handle);
        return 1;
    }
    DeviceIoControl(handle, FSCTL_DISMOUNT_VOLUME, nullptr, 0, nullptr, 0, &returned, nullptr);
    PREVENT_MEDIA_REMOVAL allow = {FALSE};
    DeviceIoControl(handle, IOCTL_STORAGE_MEDIA_REMOVAL, &allow, sizeof(allow), nullptr, 0, &returned, nullptr);
    const bool ok = DeviceIoControl(handle, IOCTL_STORAGE_EJECT_MEDIA, nullptr, 0, nullptr, 0, &returned, nullptr);
    CloseHandle(handle);
    return ok ? 0 : 1;
#else
    Q_UNUSED(id);
    return 1;
#endif
}

QString removableVolumePath(const QString& id) {
    const QMutexLocker locker(&s_mutex);
    return s_paths.value(id, id + QLatin1Char('/'));
}

QString removableVolumeLabel(const QString& id) {
    return QStorageInfo(removableVolumePath(id)).name();
}

QString removableVolumeIdOfPath(const QString& filePath) {
#ifdef Q_OS_WIN
    // "E:/Contents/..." -> "E:" unless E: is the system drive or a fixed drive that is there
    // and holds no Rekordbox export (then it is the computer's own disk).
    if (filePath.size() < 3 || filePath.at(1) != QLatin1Char(':')) {
        return {};
    }
    const QString root = filePath.left(2) + QLatin1Char('/');
    if (root.compare(QDir::rootPath(), Qt::CaseInsensitive) == 0) {
        return {};
    }
    const UINT type = GetDriveTypeW(reinterpret_cast<LPCWSTR>(root.utf16()));
    if (type == DRIVE_FIXED && !hasRekordboxExport(root)) {
        return {};
    }
    return filePath.left(2);
#else
    for (const QString& base : {QStringLiteral("/run/media/"), QStringLiteral("/media/")}) {
        if (filePath.startsWith(base)) {
            // /media/<user>/<volume>/... or /media/<volume>/...
            const QStringList parts = filePath.mid(base.size()).split(QLatin1Char('/'));
            if (parts.size() > 2) {
                return parts.at(1);
            }
            if (parts.size() > 1) {
                return parts.at(0);
            }
        }
    }
    return {};
#endif
}

QString removableVolumeRelativePath(const QString& filePath) {
    const QString id = removableVolumeIdOfPath(filePath);
    if (id.isEmpty()) {
        return {};
    }
#ifdef Q_OS_WIN
    return filePath.mid(2); // "E:/Contents/..." -> "/Contents/..."
#else
    const int at = filePath.indexOf(QLatin1Char('/') + id + QLatin1Char('/'));
    return at < 0 ? QString() : filePath.mid(at + id.size() + 1);
#endif
}

QString internalStoragePath() {
    return QDir::homePath();
}

QString internalStorageName() {
    return QStringLiteral("PC");
}

QStringList trackCacheBusyPaths(int) {
    return {};
}

int trackCachePendingCopies() {
    return 0;
}

void setScreenBrightness(double) {
    // The brightness of a desktop screen belongs to the system.
}

void keepScreenOn() {
#ifdef Q_OS_WIN
    // The display stays on while the app runs (like FLAG_KEEP_SCREEN_ON on Android).
    SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED);
#endif
}

void log(const QString& text) {
    logDiagnostic("mixxx-qml", text);
}

void logDiagnostic(const char* tag, const QString& text) {
    qInfo().noquote() << QString::fromLatin1(tag) + QStringLiteral(":") << text;
}

void quitApp() {
    QCoreApplication::quit();
}

void shareLogFiles(const QString& logFilePath) {
    QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(logFilePath).absolutePath()));
}

QStringList midiInputNames(bool* pSupported) {
    QStringList names;
#ifdef Q_OS_WIN
    if (pSupported) {
        *pSupported = true;
    }
    // WinMM asks the system each time (PortMidi caches the list of its start).
    const UINT count = midiInGetNumDevs();
    for (UINT i = 0; i < count; ++i) {
        MIDIINCAPSW caps{};
        if (midiInGetDevCapsW(i, &caps, sizeof(caps)) == MMSYSERR_NOERROR) {
            names << QString::fromWCharArray(caps.szPname);
        }
    }
#else
    if (pSupported) {
        *pSupported = false;
    }
#endif
    return names;
}

} // namespace mixxx::platform
