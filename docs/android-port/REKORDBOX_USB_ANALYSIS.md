<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# REKORDBOX_USB_ANALYSIS

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha.

## Code
- [CODE] `src/library/rekordbox/rekordboxfeature.{h,cpp}` (`RekordboxFeature : BaseExternalLibraryFeature`, `RekordboxPlaylistModel`), `rekordboxconstants.h`; Parser (Kaitai) `lib/rekordbox-metadata/rekordbox_pdb.*`, `rekordbox_anlz.*` (Specs von Deep Symmetry crate-digger).

## Gelesene Formate
- [CODE] `export.pdb` (DeviceSQL) in `PIONEER/rekordbox/` und `.PIONEER/rekordbox/` (`kPdbPaths`, Z. 47-50) sowie ANLZ `.DAT`/`.EXT` (`.EXT`-Pfad durch Endungstausch, Z. 1281-1284).
- [NICHT UNTERSTÜTZT] Rekordbox-6+-Desktop-`master.db` (kein `djmdContent`/SQLCipher im `src`), `.2EX`, PSSI.
- [NICHT UNTERSTÜTZT] OneLibrary: kein Treffer im Code. Issues/PRs: `gh` fehlt, Websuche fand nichts Mixxx-Spezifisches (2026-11-05). [DOKU] OneLibrary ist laut Rekordbox-Support ein neues Exportformat (rekordbox ≥ 7.2.x), https://rekordbox.com/en/support/faq/onelibrary-7 (Suchtreffer 2026-11-05). Ob der Stick im „Device Library“-Format (PDB) oder nur OneLibrary exportiert wird, muss beim Export geprüft werden [EXPERIMENT].
- Rekordbox-Versionen: im Code nicht ausgewiesen.

## Import (was landet wo)
- [CODE] `parseDeviceDB` (Z. 454-780) → temp. SQLite `rekordbox_library`: Artist/Title/Album/Jahr/Genre/Kommentar/Track-Nr., **BPM** (`tempo()/100`), Bitrate, Dauer, `location`, Rating, **Key** (Lookup), Farbe, `analyze_path`; Playlists/Ordner via `buildPlaylistTree`.
- [CODE] `readAnalyze` (Z. ~867-1045), lazy in `getTrack` (Z. ~1216): **PQTZ = alle Beatpositionen** → `Beats::fromBeatPositions(..., "Rekordbox USB drive")` + `trySetBeats` (volle Beatmap, auch variables Tempo); **PCOB/PCO2** → Hotcues (mit RGB und Kommentar aus PCO2), Memory-Cues, Loops; erster chronologischer Memory-Cue → MainCue, übrige → zusätzliche Hotcues.
- [CODE] Key wird als `KeyFactory::makeBasicKeysNormalized(..., USER)` gesetzt (Z. ~1296-1305) → AnalyzerKey läuft nicht erneut.
- [CODE] **Nicht importiert:** Waveforms (PWAV/PWV2/PWV3/PWV4/PWV5/PWV7 sind im ksy definiert, `rekordbox_anlz.ksy:78-84`, aber in `readAnalyze` nicht behandelt), Song-Struktur, Loop-Farben aus Rekordbox-Palette teils nur ID-basiert.

## Auffälligkeiten (selbst nachgelesen, nicht ausgeführt)
- [CODE] Existiert eine `.EXT`: Beatgrid aus `.DAT` (`ignoreCues=true`), Cues aus `.EXT`. Existiert **nur `.DAT`**: `readAnalyze(..., ignoreCues=false, ...)`, aber `case SECTION_TAGS_BEAT_GRID` bricht bei `!ignoreCues` ab (Z. 908-911) → **kein Beatgrid** in diesem Fall. Kritisch für einen Player ohne Analyse. Relevanz für echte Sticks (liefert Rekordbox immer `.EXT`?) [EXPERIMENT].
- [CODE] `kColorForIDRed(0xF870900)` (Z. 77) hat 7 Hex-Stellen, vermutlich Tippfehler; Folge nicht geprüft.
- [CODE] `analyzerbeats.cpp:163-165`: Rekordbox-Beatgrid wird nur bei Option „Reanalyze imported“ neu analysiert.
- Timing-Offsets (MP3/m4a) gegen Dekoder-Padding (Z. 1233-1277): Beatgrid-Genauigkeit auf Android hängt vom dort genutzten Decoder ab [EXPERIMENT].

## Zugriff auf den USB-Stick unter Android
- [CODE] Gerätesuche `findRekordboxDevices` (Z. ~186): Windows `QDir::drives()`, Linux `/media`, `/media/$USER`, `/run/media/$USER`, macOS `/Volumes`. **Kein Android-Zweig.** Dateizugriff per `QFile`/`std::ifstream`.
- [CODE] Kein SAF, kein `content://`, kein `DocumentFile`. Stattdessen `MANAGE_EXTERNAL_STORAGE` (Manifest; `qmlapplication.cpp:66-80`).
- [WAHRSCHEINLICH] Mit All-Files-Access ist der Stick unter `/storage/<UUID>/` per normalem Pfad lesbar (QFile, TagLib, libsndfile/FFmpeg ok). Fallback bei Problemen: SAF mit persistierten URIs → dann bräuchten Qt-/TagLib-/Decoder-Pfade fd-basierte Zugriffe (großer Aufwand). [EXPERIMENT] Stick einstecken, `adb shell ls /storage/`, Lesetest per App; exFAT/FAT32 prüfen.
- Android-Erkennung des Sticks nötig: Pfad suchen (z. B. `/storage/*/PIONEER`) oder `StorageManager`/`QStorageInfo` [WAHRSCHEINLICH, nicht verifiziert].
- Cache: [WAHRSCHEINLICH] Das Feature hält die Tabellen temporär (`rekordbox_library` etc.); für Start-Zeit evtl. Persistenz nötig, ohne Analyse und ohne zweite Bibliothek. Nicht geprüft, wie lange das Parsen großer PDBs dauert [EXPERIMENT].

<!-- Ende KI-generierter Text -->
