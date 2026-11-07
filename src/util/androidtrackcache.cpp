#include "util/androidtrackcache.h"

#include <android/log.h>

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QtConcurrent>
#include <algorithm>

#include "moc_androidtrackcache.cpp"

namespace mixxx {

namespace {
constexpr const char* kLogTag = "mixxx-cache";
constexpr qint64 kCopyBufferSize = 1024 * 1024;
// Cache size limit. Older copies are removed first.
constexpr qint64 kMaxCacheBytes = 1024LL * 1024 * 1024;
// The newest copies are never removed (they are probably loaded in decks).
constexpr int kKeepNewestFiles = 6;
const QString kPartSuffix = QStringLiteral(".part");
} // namespace

// static
AndroidTrackCache& AndroidTrackCache::instance() {
    static AndroidTrackCache s_instance;
    return s_instance;
}

// static
bool AndroidTrackCache::isRemovablePath(const QString& path) {
    if (path.startsWith(QStringLiteral("/mnt/media_rw/"))) {
        return true;
    }
    return path.startsWith(QStringLiteral("/storage/")) &&
            !path.startsWith(QStringLiteral("/storage/emulated")) &&
            !path.startsWith(QStringLiteral("/storage/self"));
}

AndroidTrackCache::AndroidTrackCache() {
    m_pool.setMaxThreadCount(1); // one copy at a time: USB sticks are slow
    // Remove leftovers of interrupted copies.
    const QDir dir(cacheDirPath());
    const QStringList parts = dir.entryList({QStringLiteral("*") + kPartSuffix}, QDir::Files);
    for (const QString& part : parts) {
        QFile::remove(dir.filePath(part));
    }
}

QString AndroidTrackCache::cacheDirPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) +
            QStringLiteral("/tracks");
}

QString AndroidTrackCache::cacheFilePathFor(const QString& originalPath) const {
    const QFileInfo info(originalPath);
    // The key changes when the file changes, so a stale copy is never used.
    const QByteArray key = originalPath.toUtf8() + '|' +
            QByteArray::number(info.size()) + '|' +
            QByteArray::number(info.lastModified().toMSecsSinceEpoch());
    const QString hash = QString::fromLatin1(
            QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex());
    const QString suffix = info.suffix();
    return cacheDirPath() + QLatin1Char('/') + hash +
            (suffix.isEmpty() ? QString() : QLatin1Char('.') + suffix);
}

QString AndroidTrackCache::cachedPath(const QString& originalPath) {
    if (!isRemovablePath(originalPath)) {
        return {};
    }
    const QString path = cacheFilePathFor(originalPath);
    QFile file(path);
    if (!file.exists()) {
        return {};
    }
    // Mark as recently used for the eviction order.
    file.open(QIODevice::ReadWrite);
    file.setFileTime(QDateTime::currentDateTime(), QFileDevice::FileModificationTime);
    return path;
}

void AndroidTrackCache::requestCopy(
        const QString& originalPath, std::function<void()> onFinished) {
    if (!isRemovablePath(originalPath)) {
        return;
    }
    if (!cachedPath(originalPath).isEmpty()) {
        if (onFinished) {
            onFinished();
        }
        return;
    }
    {
        const auto locker = QMutexLocker(&m_mutex);
        const bool alreadyRunning = m_waiters.contains(originalPath);
        m_waiters[originalPath].append(std::move(onFinished));
        if (alreadyRunning) {
            return;
        }
    }
    QtConcurrent::run(&m_pool, [this, originalPath]() { copyFile(originalPath); });
}

QStringList AndroidTrackCache::pendingPaths() {
    const auto locker = QMutexLocker(&m_mutex);
    return m_waiters.keys();
}

void AndroidTrackCache::noteAccess(const QString& path) {
    if (!isRemovablePath(path)) {
        return;
    }
    const auto locker = QMutexLocker(&m_mutex);
    m_lastAccess.insert(path, QDateTime::currentMSecsSinceEpoch());
}

QStringList AndroidTrackCache::busyPaths(qint64 withinMs) {
    const auto locker = QMutexLocker(&m_mutex);
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    QStringList paths = m_waiters.keys();
    for (auto it = m_lastAccess.begin(); it != m_lastAccess.end();) {
        if (now - it.value() <= withinMs) {
            paths << it.key();
            ++it;
        } else {
            it = m_lastAccess.erase(it);
        }
    }
    return paths;
}

int AndroidTrackCache::pendingCopies() {
    const auto locker = QMutexLocker(&m_mutex);
    return m_waiters.size();
}

void AndroidTrackCache::copyFile(const QString& originalPath) {
    QElapsedTimer timer;
    timer.start();

    bool ok = false;
    qint64 totalBytes = 0;
    const QString finalPath = cacheFilePathFor(originalPath);
    const QString partPath = finalPath + kPartSuffix;

    QDir().mkpath(cacheDirPath());
    {
        QFile source(originalPath);
        QFile target(partPath);
        if (source.open(QIODevice::ReadOnly) && target.open(QIODevice::WriteOnly)) {
            QByteArray buffer(static_cast<int>(kCopyBufferSize), Qt::Uninitialized);
            ok = true;
            while (!source.atEnd()) {
                const qint64 read = source.read(buffer.data(), buffer.size());
                if (read < 0) {
                    ok = false;
                    break;
                }
                if (read == 0) {
                    break;
                }
                if (target.write(buffer.constData(), read) != read) {
                    ok = false;
                    break;
                }
                totalBytes += read;
            }
            // Detect a truncated copy (e.g. the stick vanished mid-read).
            ok = ok && source.error() == QFileDevice::NoError &&
                    totalBytes == source.size();
            ok = target.flush() && ok;
            target.close();
        }
    }

    if (ok) {
        QFile::remove(finalPath);
        ok = QFile::rename(partPath, finalPath);
    }
    if (!ok) {
        QFile::remove(partPath);
    }

    __android_log_print(ok ? ANDROID_LOG_INFO : ANDROID_LOG_WARN,
            kLogTag,
            "copy %s: %lld bytes in %lld ms -> %s",
            ok ? "finished" : "FAILED",
            static_cast<long long>(totalBytes),
            static_cast<long long>(timer.elapsed()),
            originalPath.toUtf8().constData());

    QList<std::function<void()>> waiters;
    {
        const auto locker = QMutexLocker(&m_mutex);
        waiters = m_waiters.take(originalPath);
    }
    if (ok) {
        evictOldFiles(finalPath);
        for (const auto& waiter : std::as_const(waiters)) {
            if (waiter) {
                waiter();
            }
        }
    }
}

void AndroidTrackCache::evictOldFiles(const QString& keepPath) {
    const QDir dir(cacheDirPath());
    QFileInfoList files = dir.entryInfoList(QDir::Files, QDir::Time); // newest first
    qint64 total = 0;
    for (const QFileInfo& file : std::as_const(files)) {
        total += file.size();
    }
    // Remove from the oldest end until the limit is met.
    for (int i = static_cast<int>(files.size()) - 1; i >= kKeepNewestFiles && total > kMaxCacheBytes;
            --i) {
        const QFileInfo& file = files.at(i);
        if (file.absoluteFilePath() == keepPath ||
                file.fileName().endsWith(kPartSuffix)) {
            continue;
        }
        total -= file.size();
        QFile::remove(file.absoluteFilePath());
    }
}

} // namespace mixxx
