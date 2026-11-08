<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# DEPENDENCIES

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha.

| Abhängigkeit | Rolle | Beleg / Android |
|---|---|---|
| Qt 6 (≥ 6.2, Android-Pfade vermutlich ≥ 6.8) | UI/QML, JNI | [CODE] `CMakeLists.txt:3828`; tatsächliche Version im Buildenv **nicht verifiziert** |
| PortAudio + Oboe | Audio | [CODE] `CMakeLists.txt:3752-3758`, `FindPortAudio.cmake:113-123`; extern (vcpkg) |
| OpenSLES, android (NDK-Libs) | Audio/JNI | [CODE] `:3755` |
| GLESv2 | Waveform-Rendering | [CODE] `:3719` |
| libusb / hidapi | Bulk/HID-Controller | [CODE] `:5282, 5285-5300` |
| Kaitai (rekordbox_metadata) | Rekordbox-Parser | [CODE] `:3646-3670`, `lib/rekordbox-metadata/` |
| QM-DSP | Beat-/Key-Analyse | [CODE] `lib/qm-dsp` (immer kompiliert) |
| libkeyfinder | Key-Analyse | [CODE] Option `KEYFINDER` (default an, `:3511`) |
| Ebur128 | ReplayGain 2 | [CODE] `REQUIRED` (`:3470`) |
| Chromaprint | MusicBrainz, nicht Analyzer | [CODE] `:3243-3248` (Pflicht) |
| SoundTouch, Rubberband | Time-Stretch/Pitch | [CODE] Rubberband-Option `:4795` |
| FFmpeg | Decoder + STEM | [CODE] `FFMPEG`-Option; Präsenz im Android-Buildenv **nicht verifiziert** |
| OpenMP (`libomp.so`) | Android-Link | [CODE] Clang-18-Pfad fest verdrahtet |
| SQLite | Library-DB | [CODE] `FindSQLite3.cmake:78,94` (Static-Workarounds) |

## Wegfall durch Scope-Reduktion
- `-DSTEM=OFF`: entfernt STEM-Quellen (siehe `SCOPE_REDUCTION.md`), keine externe Lib entfällt.
- Analyse aus (Config): keine Abhängigkeit entfällt (QM-DSP/Ebur128 Pflicht, KeyFinder per `-DKEYFINDER=OFF` abwählbar [CODE, nicht getestet]).
- Größe/Build-Zeit-Einsparung: nicht gemessen.

<!-- Ende KI-generierter Text -->
