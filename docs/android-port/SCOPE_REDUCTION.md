<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# SCOPE_REDUCTION (Stems und Track-Analyse)

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha.

## 1. Stems
- [CODE] Stem-Support existiert. CMake-Option `STEM` = `default_option(STEM ... "FFmpeg_FOUND;FFMPEG")` (`CMakeLists.txt:2846`): standardmäßig an, wenn FFmpeg gefunden wird; harter Fehler, wenn `STEM` an und `FFMPEG` aus (`:2848-2849`). Definiert `__STEM__` (`:2851`, QML-Lib `:4058`).
- [CODE] Nur mit STEM kompiliert (`:2853-2866`): `src/sources/soundsourcestem.cpp`, `src/track/steminfoimporter.cpp`, `steminfo.cpp`, `src/widget/wtrackstemmenu.cpp`, `wstemlabel.cpp`, `src/waveform/renderers/allshader/waveformrendererstem.cpp`, `src/qml/qmlstemsmodel.cpp`.
- [CODE] Weitere `#ifdef __STEM__`-Stellen: `engine.h:10-25`, `enginebuffer.cpp:1591-1607`, `enginedeck.cpp` (Controls `stem_count`, `[ChannelN_StemM]`), `playermanager.cpp:389-395, 610-684`, `basetrackplayer.cpp:347-355`, Skins/QML (`res/qml/StemKnob.qml`, `LateNightQML/Waveforms/Stem*.qml`), `legacyskinparser.cpp:771-775` (blendet Stem-Gruppen bei STEM=OFF aus).
- [CODE] Kein DB-Schema (`res/schema.xml` ohne Stem-Spalten); Stem-Info wird aus Datei gelesen. Keine eigene Lib: nur FFmpeg (MP4-Atome handgeschrieben).
- **Abschalten:** [CODE] `-DSTEM=OFF` ist die vorgesehene, saubere Option. Funktioniert im Android-Build: CI übergibt weder `STEM` noch `FFMPEG` (`build.yml:180-197`) → Verhalten hängt davon ab, ob FFmpeg im Buildenv liegt (nicht verifiziert). [WAHRSCHEINLICH] `-DSTEM=OFF` reicht ohne Codeänderung; Merge-Konflikte: keine.
- Entfallende Abhängigkeiten: nur der STEM-Teil; FFmpeg bleibt, solange `FFMPEG` an ist (Audio-Decoder). `-DFFMPEG=OFF` zusätzlich würde den FFmpeg-Decoder streichen → nur wenn Android-Decoder (z. B. libsndfile/MP3/AAC-Pfad) ausreichen [nicht verifiziert]. Größe/Build-Zeit: nicht gemessen.
- FLX4-Script: Stem-Pads bleiben im Mapping, laufen ohne Stem-Controls ins Leere [WAHRSCHEINLICH].

## 2. Track-Analyse
**Aufbau** [CODE]
- `src/analyzer/`: `AnalyzerBeats` (QM-DSP, SoundTouch-Plugin), `AnalyzerKey` (QM-DSP, KeyFinder bei `__KEYFINDER__`), `AnalyzerGain` (RG v1)/`AnalyzerEbur128` (RG v2), `AnalyzerSilence` (Cues/Intro/Outro), `AnalyzerWaveform`. Thread: `AnalyzerThread::doRun` (`analyzerthread.cpp:90-117`), Scheduler `TrackAnalysisScheduler`.
- Auslöser: `PlayerManager::bindToLibrary` erzeugt Scheduler mit `AnalyzerModeFlags::WithWaveform` (`playermanager.cpp:173-175`); `slotAnalyzeTrack` (`:788-802`) hängt an `newTrackLoaded` für Decks/Sampler/Preview. Batch: `AnalysisFeature` (nutzerausgelöst).

**Ergebnisse und Verbraucher** [CODE]
| Ergebnis | Speicherort | Leser |
|---|---|---|
| Beats/BPM | `Track::trySetBeats` (`track.cpp:456-500`), DB | `BpmControl`, `QuantizeControl`, `ClockControl`, `SyncControl`, `LoopingControl`, Waveform-Beatmarken |
| Key | `Track::setKeys` (`track.cpp:1584-1626`) | `KeyControl` (`file_key`), GUI |
| ReplayGain | Track | `EngineBuffer` (`enginebuffer.cpp:590`) |
| Waveform | `track_analysis`-Tabelle (`AnalysisDao`) | Waveform-Renderer, Overview (`OverviewCache`) |
| Silence/Intro/Outro | Cues | Cue-Controls |

**Abschaltbarkeit**
- [CODE] BPM (`[BPM],BPMDetectionEnabled`), Key (`[Key],KeyDetectionEnabled`), ReplayGain (`[ReplayGain],ReplayGainAnalyserEnabled`) einzeln per Preferences/Config abschaltbar. `AnalyzerBeats` überspringt bei deaktivierter Erkennung (`analyzerbeats.cpp:51-62`) und bei vorhandenem gültigem Beatgrid.
- [CODE] **Waveform-Analyse ist beim Laden hartcodiert aktiv** (`WithWaveform`, `playermanager.cpp:175`); kein Setting. [CODE] Kein globaler Analyse-Schalter, keine CMake-Option.
- [CODE] Bei Rekordbox-Tracks mit importiertem Grid/Key überspringen AnalyzerBeats/AnalyzerKey bereits selbst (siehe `REKORDBOX_USB_ANALYSIS.md`).

**Ohne Analyse** [CODE]
- Tracks laden und spielen; Engine-Controls prüfen `m_pBeats` auf null (`bpmcontrol.cpp:299-306, 356, 419`, `clockcontrol.cpp:78-100`, `quantizecontrol.cpp:110`, `synccontrol.cpp:376-390`). Ungültiger BPM via `Bpm::isValid()`, nicht 0 (`bpmcontrol.cpp:306`). Beatloops: Fake-60-BPM (`loopingcontrol.cpp:1295-1310`, `m_trueTrackBeats=false`).
- Waveform: ohne Daten zeichnen Renderer nichts (`waveformwidgetrenderer.cpp:465-470`). Kein On-the-fly-Pfad außerhalb des Analyzers gefunden.
- Wie die Control `bpm` für Skins/Skripte bei null-Beats aussieht und Key-Verhalten bei ungültigem Key: **nicht verfolgt**.

## 3. Funktionstabelle
| Funktion | hängt an Analyse | Ersatz aus Rekordbox | Konsequenz |
|---|---|---|---|
| BPM/Beatgrid | ja | ja (PQTZ voll, aus `.DAT`) | Nur mit `.EXT` oder dem Fix-Fall; nur-`.DAT`-Fall liefert kein Grid [CODE] |
| Sync | ja (Beats) | ja, wenn Grid da | Ohne Grid kein Sync |
| Quantize / Beatjump / Beatloop | ja | ja, wenn Grid da | Ohne Grid Fake-60-BPM-Verhalten |
| Key / Key-Anzeige | ja | ja (Key-ID→Text) | Keylock/Pitch ohne Key funktionsfähig, Anzeige leer |
| Hotcues/Memory/Loops | nein | ja (PCOB/PCO2) | ok; Farben teils ID-basiert |
| Waveform (Deck) | ja (`AnalyzerWaveform`) | **nein** (PWV* nicht gelesen) | Hauptlücke |
| Overview-Waveform | ja | nein | wie oben |
| ReplayGain | ja | nein | verzichtbar; stattdessen manuelles Gain am FLX4 |
| Silence/Intro/Outro | ja | teils (Memory-Cues) | verzichtbar |
| FLX4-Pads (Beatjump/Loops/Sync) | indirekt (Beats) | ja, wenn Grid | siehe Grid |

## 4. Waveform-Optionen (Aufwand/Risiko)
1. **Analyzer nur für Waveform weiterlaufen lassen** (Ist-Zustand, `WithWaveform`): kein Eingriff; Last auf dem Phone beim Laden (CPU/Akku) [EXPERIMENT]; Verstoß gegen „keine Analyse“, aber BPM/Key/Gain aus. Geringstes Risiko.
2. **ANLZ-Waveform konvertieren** (PWAV/PWV3/PWV5 → Mixxx-`Waveform`/Summary): Format im ksy beschrieben; Mixxx-Waveform hat andere Struktur (mehrbandig, `signal_stems` in `waveform.proto:32`) → mittlerer/hoher Aufwand, Qualität ungewiss; Dateien `.EXT` nötig. Neuer Code in Upstream-nahem Bereich.
3. **Vereinfachte on-the-fly-Darstellung** (z. B. Dekodieren+Peak beim Laden): im Code nicht vorhanden; faktisch eigener Mini-Analyzer; Ladeverzögerung.
4. **Ohne Waveform** (Typ „Empty“ in `WaveformWidgetFactory`): trivial, DJ-Nutzbarkeit stark reduziert (XDJ-Vorbild hat Waveforms).
Empfehlung: Start mit 1, später 2 prüfen.

## 5. Tracks ohne Rekordbox-Daten
[CODE] Kein Grid → kein Sync, Fake-60-BPM-Beatloops. Notbehelf [WAHRSCHEINLICH]: Mixxx-Funktion BPM-Tap/„Tap“-Control; Nutzung von `AnalyzerBeats` nur als bewusst aktivierter Fallback (Preferences).

## 6. Empfehlung (am wenigsten invasiv)
1. **Konfiguration:** `-DSTEM=OFF` (Build); Defaults in `UserSettings` setzen: BPM-/Key-Detection und ReplayGain-Analyse aus; `ReanalyzeImported` aus.
2. **Kleine Codeänderung (nur falls nötig):** Waveform-Strategie in `PlayerManager::bindToLibrary` (`playermanager.cpp:173-175`) – Flag je nach Setting statt hartcodiert.
3. **Nichts entfernen.** Analyzer-Code bleibt kompiliert (QM-DSP/KeyFinder/Ebur128 sind Pflichtbestandteile; Wegfall nur mit größeren Eingriffen).
4. **Vor allem:** den `.DAT`-only-Beatgrid-Fall in `rekordboxfeature.cpp:908-911` bewerten (kleiner Fix, Upstream-PR-fähig).

<!-- Ende KI-generierter Text -->

## Nachtrag 2026-11-05 (nach Umsetzung)
- **Stems:** `-DSTEM=OFF` baut in diesem Commit **nicht** ohne Quelländerung (`Track::hasStem()` fehlt ohne STEM, Aufrufe in vier Wellenform-Renderern); mit 3 Zeilen in `track.h` baut es. Größenersparnis nur ca. 0,04 % (APK −115 KB). Siehe `PROGRESS.md`, Etappe 1b.
- **Waveform:** Der Rekordbox-Import ist umgesetzt (ANLZ PWV5/PWV3 → Mixxx-Waveform); `AnalyzerWaveform::shouldAnalyze()` überspringt die Analyse, wenn am Track bereits Waveform und Summary hängen. Siehe Etappe 7g. Die Tabelle oben („Waveform (Deck) | ja | **nein**“) ist damit überholt: Ersatz aus Rekordbox = **ja** (für Titel mit `.EXT`).
- **Analyse für Nicht-Rekordbox-Titel:** bewusst an gelassen (Entscheidung des Inhabers).
