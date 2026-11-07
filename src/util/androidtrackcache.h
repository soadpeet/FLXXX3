#pragma once

#include <QHash>
#include <QList>
#include <QMutex>
#include <QObject>
#include <QSet>
#include <QString>
#include <QThreadPool>
#include <functional>

namespace mixxx {

/// Copies audio files from removable media (USB sticks) into the app cache.
///
/// Android's volume daemon terminates every process that holds a file open on a
/// removable volume when that volume disappears (see PROGRESS.md, etappe 11a).
/// Playing a cached copy instead means Mixxx does not keep files on the stick
/// open, so pulling the stick does not kill the app and playing tracks keep
/// playing. The copy runs in the background; playback starts from the stick
/// immediately and switches to the copy when it is complete.
class AndroidTrackCache : public QObject {
    Q_OBJECT
  public:
    static AndroidTrackCache& instance();

    /// True for paths on removable volumes: /mnt/media_rw/<uuid>/... and
    /// /storage/<uuid>/... (but not the internal /storage/emulated/...).
    static bool isRemovablePath(const QString& path);

    /// Path of the finished cached copy of `originalPath`, or an empty string
    /// if there is none (yet). Marks the copy as recently used.
    QString cachedPath(const QString& originalPath);

    /// Starts copying `originalPath` into the cache in the background, unless
    /// a finished copy exists or a copy is already running. `onFinished` is
    /// called from the copy thread once a finished copy is available (also
    /// immediately if it already is). It is not called if the copy fails.
    void requestCopy(const QString& originalPath, std::function<void()> onFinished);

    /// Number of files currently being copied (or waiting to be copied).
    int pendingCopies();
    /// Original paths of the files currently being copied.
    QStringList pendingPaths();

    /// Reports that a file on a removable volume was read (track data, analysis
    /// files, audio). The USB indicator blinks for a moment after that.
    void noteAccess(const QString& path);
    /// Paths of files that are being copied or were read in the last
    /// `withinMs` milliseconds.
    QStringList busyPaths(qint64 withinMs);

  private:
    AndroidTrackCache();

    QString cacheDirPath() const;
    QString cacheFilePathFor(const QString& originalPath) const;
    void copyFile(const QString& originalPath);
    void evictOldFiles(const QString& keepPath);

    QMutex m_mutex;
    QHash<QString, QList<std::function<void()>>> m_waiters;
    QHash<QString, qint64> m_lastAccess;
    QThreadPool m_pool;
};

} // namespace mixxx
