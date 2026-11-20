// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// FLXXX3: tests of the Rekordbox import with the demo export of rekordcrate
// (tests/flxxx3/data/rekordbox-demo: export.pdb and the analysis files, no audio).
#include <gtest/gtest.h>

#include <QDir>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtConcurrentRun>

#include "library/rekordbox/rekordboxfeature.h"
#include "library/treeitem.h"
#include "test/mixxxdbtest.h"
#include "track/beats.h"
#include "track/cue.h"
#include "track/track.h"

namespace {

class RekordboxFeatureTest : public MixxxDbTest {
  protected:
    static QString demoExportPath() {
        return QDir::cleanPath(getOrInitTestDir().filePath(
                QStringLiteral("../../tests/flxxx3/data/rekordbox-demo")));
    }

    // Reads the demo export into the temporary tables (on a worker thread, like the app).
    void parseDemoExport(TreeItem* pDeviceItem) {
        QSqlDatabase database = dbConnection();
        mixxx::rekordboxtest::createTables(database);
        // Without a slash at the end, like the paths of sticks and folders in the app.
        const QString path = demoExportPath();
        const auto pool = dbConnectionPooler();
        const QString result = QtConcurrent::run([pool, path, pDeviceItem]() {
            return mixxx::rekordboxtest::parseDevice(pool, QStringLiteral("DEMO"), path, pDeviceItem);
        }).result();
        ASSERT_EQ(path, result);
    }

    // column of the track with this title in rekordbox_library.
    QVariant trackValue(const QString& title, const QString& column) {
        QSqlQuery query(dbConnection());
        query.prepare(QStringLiteral("SELECT ") + column +
                QStringLiteral(" FROM rekordbox_library WHERE title = :title"));
        query.bindValue(QStringLiteral(":title"), title);
        EXPECT_TRUE(query.exec());
        return query.next() ? query.value(0) : QVariant();
    }

    int count(const QString& sql) {
        QSqlQuery query(dbConnection());
        EXPECT_TRUE(query.exec(sql));
        return query.next() ? query.value(0).toInt() : -1;
    }
};

TEST_F(RekordboxFeatureTest, FindsExport) {
    ASSERT_TRUE(QDir(demoExportPath()).exists()) << demoExportPath().toStdString();
    const QString pdb = mixxx::rekordboxtest::findPdbPath(demoExportPath() + QStringLiteral("/"));
    EXPECT_TRUE(pdb.endsWith(QStringLiteral("PIONEER/rekordbox/export.pdb"))) << pdb.toStdString();
    EXPECT_TRUE(RekordboxFeature::hasRekordboxExport(demoExportPath()));

    QTemporaryDir empty;
    EXPECT_TRUE(mixxx::rekordboxtest::findPdbPath(empty.path() + QStringLiteral("/")).isEmpty());
    EXPECT_FALSE(RekordboxFeature::hasRekordboxExport(empty.path()));
}

TEST_F(RekordboxFeatureTest, ReadsTracks) {
    TreeItem device(QStringLiteral("DEMO"));
    parseDemoExport(&device);

    // The demo export: the two demo tracks (the names of the sound effects in the file are
    // left-overs of the Rekordbox template, not rows of the track table).
    EXPECT_EQ(2, count(QStringLiteral("SELECT COUNT(*) FROM rekordbox_library")));
    const QString path = demoExportPath() + QStringLiteral("/");
    EXPECT_EQ(path + QStringLiteral("Contents/Loopmasters/UnknownAlbum/Demo Track 1.mp3"),
            trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("location")).toString());
    EXPECT_EQ(QStringLiteral("mp3"),
            trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("filetype")).toString());
    EXPECT_EQ(QStringLiteral("Loopmasters"),
            trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("artist")).toString());
    EXPECT_GT(trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("bpm")).toDouble(), 60.0);
    EXPECT_GT(trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("duration")).toInt(), 0);
    const QString anlz =
            trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("analyze_path")).toString();
    EXPECT_TRUE(anlz.startsWith(path + QStringLiteral("PIONEER/USBANLZ/"))) << anlz.toStdString();
    EXPECT_TRUE(anlz.endsWith(QStringLiteral("ANLZ0000.DAT"))) << anlz.toStdString();
    EXPECT_EQ(path + QStringLiteral("Contents/Loopmasters/UnknownAlbum/Demo Track 2.mp3"),
            trackValue(QStringLiteral("Demo Track 2"), QStringLiteral("location")).toString());

    // Every track is in the playlist of the whole device.
    EXPECT_EQ(2, count(QStringLiteral("SELECT COUNT(*) FROM rekordbox_playlist_tracks")));
    EXPECT_GE(count(QStringLiteral("SELECT COUNT(*) FROM rekordbox_playlists")), 1);
}

TEST_F(RekordboxFeatureTest, ReadsAnalysis) {
    TreeItem device(QStringLiteral("DEMO"));
    parseDemoExport(&device);
    const QString anlz =
            trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("analyze_path")).toString();
    ASSERT_TRUE(QFile::exists(anlz)) << anlz.toStdString();
    const double bpm = trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("bpm")).toDouble();

    const double durationSeconds =
            trackValue(QStringLiteral("Demo Track 1"), QStringLiteral("duration")).toDouble();
    // The audio properties come from the file in the app (it is not part of the test data).
    TrackPointer pTrack = Track::newTemporary();
    pTrack->setAudioProperties(mixxx::audio::ChannelCount(2),
            mixxx::audio::SampleRate(44100),
            mixxx::audio::Bitrate(320),
            mixxx::Duration::fromSeconds(durationSeconds));
    mixxx::rekordboxtest::readAnalysis(pTrack, mixxx::audio::SampleRate(44100), anlz);

    // Beat grid with the tempo of the database.
    const mixxx::BeatsPointer pBeats = pTrack->getBeats();
    ASSERT_TRUE(pBeats);
    EXPECT_NEAR(bpm, pTrack->getBpm(), 0.5);

    // The demo tracks have no hot cues and no memory cues (the cue sections of their
    // .DAT and .EXT files are empty): nothing is added, also no main cue from them.
    EXPECT_TRUE(pTrack->getCuePoints().isEmpty());

    // The 3-band waveform (.2EX) is put on the track.
    EXPECT_TRUE(pTrack->getWaveform());
    EXPECT_TRUE(pTrack->getWaveformSummary());
}

TEST_F(RekordboxFeatureTest, MissingAnalysisFile) {
    TrackPointer pTrack = Track::newTemporary();
    mixxx::rekordboxtest::readAnalysis(pTrack,
            mixxx::audio::SampleRate(44100),
            demoExportPath() + QStringLiteral("/PIONEER/USBANLZ/missing/ANLZ0000.DAT"));
    EXPECT_FALSE(pTrack->getBeats());
    EXPECT_TRUE(pTrack->getCuePoints().isEmpty());
}

} // namespace
