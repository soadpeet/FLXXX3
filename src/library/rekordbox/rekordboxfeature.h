// This feature reads tracks, playlists and folders from removable Recordbox
// prepared devices (USB drives, etc), by parsing the binary *.PDB files
// stored on each removable device. It does not read the locally stored
// Rekordbox database (Collection).

// It draws heavily from the hard work completed here:

//      https://github.com/Deep-Symmetry/crate-digger

// And uses the C++ Kaitai Struct binary parsing libraries:

//      http://kaitai.io
//      https://github.com/kaitai-io/kaitai_struct
//      https://github.com/kaitai-io/kaitai_struct_cpp_stl_runtime

// The *.PDB C++ files:

//      rekordbox_pdb.h
//      rekordbox_pdb.cpp

// Were generated from the following structure definition file:

//      https://github.com/Deep-Symmetry/crate-digger/blob/master/src/main/kaitai/rekordbox_pdb.ksy

#pragma once

#include <QFuture>
#include <QFutureWatcher>
#include <QStringListModel>
#include <QtConcurrentRun>
#include <fstream>

#include "library/baseexternallibraryfeature.h"
#include "library/baseexternalplaylistmodel.h"
#include "library/baseexternaltrackmodel.h"
#include <QSet>

#include "library/treeitemmodel.h"
#include "util/parented_ptr.h"

class TrackCollectionManager;
class BaseExternalPlaylistModel;

class RekordboxPlaylistModel : public BaseExternalPlaylistModel {
    Q_OBJECT
  public:
    RekordboxPlaylistModel(QObject* parent,
            TrackCollectionManager* pTrackCollectionManager,
            QSharedPointer<BaseTrackCache> trackSource);
    TrackPointer getTrack(const QModelIndex& index) const override;
#ifdef FLXXX3
    /// FLXXX3: reads the Rekordbox data of the track (MP3 scan, analysis files,
    /// waveform) on a worker thread, so that a flicked list does not block the GUI thread.
    /// Returns true if the data is there already; otherwise trackPrefetched() follows.
    bool prefetchTrack(const QModelIndex& index) const;
    /// The track object made by prefetchTrack() for the waveform preview of a list row (a
    /// temporary track: not in the library database, no tags read). Null if not ready.
    TrackPointer previewTrack(const QModelIndex& index) const;
    /// True if the preview of the row was made before (no file is read to find out).
    bool hasPreview(const QModelIndex& index) const;
#endif
    bool isColumnHiddenByDefault(int column) override;
    bool isColumnInternal(int column) override;

  protected:
    void initSortColumnMapping() override;

#ifdef FLXXX3
  signals:
    /// The Rekordbox data of the track at `location` was read by prefetchTrack().
    void trackPrefetched(const QString& location);
#endif
};

class RekordboxFeature : public BaseExternalLibraryFeature {
    Q_OBJECT
  public:
    RekordboxFeature(Library* pLibrary, UserSettingsPointer pConfig);
    ~RekordboxFeature() override;

    QVariant title() override;
    static bool isSupported();
    void bindLibraryWidget(WLibrary* libraryWidget,
            KeyboardEventFilter* keyboard) override;

    TreeItemModel* sidebarModel() const override;
#ifdef FLXXX3
    static void importDataForTrack(const TrackPointer& pTrack);
    /// True if the folder holds a Rekordbox export (PIONEER/rekordbox/export.pdb).
    /// Such library folders are read like a stick.
    static bool hasRekordboxExport(const QString& folderPath);
#endif

  public slots:
    void activate() override;
    void activateChild(const QModelIndex& index) override;
    void refreshLibraryModels();
    void onRekordboxDevicesFound();
    void onTracksFound();

  private slots:
    void htmlLinkClicked(const QUrl& link);
#ifdef FLXXX3
    void checkRemovableVolumes();
    void onMountedVolumesRead();
    void parseNextDevice();
    void rebuildAllSticksList();
#endif

  private:
    QString formatRootViewHtml() const;
    std::unique_ptr<BaseSqlTableModel> createPlaylistModelForPlaylist(
            const QVariant& data) override;

    parented_ptr<TreeItemModel> m_pSidebarModel;
    parented_ptr<RekordboxPlaylistModel> m_pRekordboxPlaylistModel;

    QFutureWatcher<QList<TreeItem*>> m_devicesFutureWatcher;
    QFuture<QList<TreeItem*>> m_devicesFuture;
    QFutureWatcher<QString> m_tracksFutureWatcher;
    QFuture<QString> m_tracksFuture;
    // The worker thread that reads a device builds the playlist tree into this detached item,
    // which nothing else touches; when it is done the GUI thread copies the entries into the
    // sidebar (attachParsedTree). Before, the worker read and extended the sidebar item itself
    // while the GUI thread used it: data races that corrupted memory (random crashes).
    std::unique_ptr<TreeItem> m_pParseTree;
    QString m_parseDevicePath;
    void startDeviceParse(TreeItem* pDevice);
    // Looks for sticks (and FLXXX3: library folders with a Rekordbox export) on a worker thread.
    void startDeviceSearch();
    void attachParsedTree();
    QString m_title;

    QSharedPointer<BaseTrackCache> m_trackSource;
#ifdef FLXXX3
    // FLXXX3: ids of the removable volumes mounted at the last check.
    QSet<QString> m_mountedVolumes;
    // Reading /proc/self/mountinfo takes 3-10 ms, so it runs off the GUI thread.
    QFutureWatcher<QSet<QString>> m_mountedFutureWatcher;
    bool m_volumesChecked = false;
    bool m_silentParse = false;
    bool m_manualScan = false;
    bool m_shown = false;
    QString m_devicePlaylist;
    QStringList m_devicePlaylists;
    // Library folders at the last check: those with a Rekordbox export are read like a stick.
    QStringList m_libraryFolders;
#endif
};

#ifdef BUILD_TESTING
// FLXXX3: entry points for the tests (src/test/rekordboxfeature_test.cpp).
#include "audio/types.h"
#include "track/track_decl.h"
#include "util/db/dbconnectionpool.h"
class QSqlDatabase;
class TreeItem;
namespace mixxx::rekordboxtest {
// The export.pdb of a stick or folder (empty if there is none).
QString findPdbPath(const QString& devicePath);
// The temporary tables the import fills (rekordbox_library, _playlists, _playlist_tracks).
void createTables(QSqlDatabase& database);
// Reads the export.pdb of devicePath into the tables and the playlist tree below
// pDeviceItem; returns devicePath, or an empty string if the database could not be opened.
QString parseDevice(mixxx::DbConnectionPoolPtr dbConnectionPool,
        const QString& device,
        const QString& devicePath,
        TreeItem* pDeviceItem);
// Puts beat grid, cues and waveform from the analysis files (anlzPath: the .DAT file) on
// the track, as on loading a track from a stick (without timing offset).
void readAnalysis(const TrackPointer& track,
        mixxx::audio::SampleRate sampleRate,
        const QString& anlzPath);
} // namespace mixxx::rekordboxtest
#endif
