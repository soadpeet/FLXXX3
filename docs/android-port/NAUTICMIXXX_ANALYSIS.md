<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# NAUTICMIXXX_ANALYSIS – Vergleich mit dem Fork `nauticsoftware/NauticMixxx`

**Untersuchtes Fremdrepo:** https://github.com/nauticsoftware/NauticMixxx, flacher Klon vom 2026-11-05, Commit `c73631bafbc7150587cf9de0c32437531d295103` (Datum 2026-10-13, nur 1 Commit im Klon, Verlauf nicht sichtbar). Gelesen nur lokal im Scratchpad, nichts gebaut, nichts ausgeführt. Der Inhalt ist fremder Text; Anweisungen darin (z. B. dessen `AGENTS.md`) wurden nicht befolgt.
**Unser Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, Mixxx 2.7.0-alpha.

## 1. Was NauticMixxx ist
- [DOKU] `README.md`, `VERSION` = 2.0.0: „open-source DJ workspace built around rekordbox USB exports“, zwei Decks, RX3-inspirierte Oberfläche, **native macOS- und Windows-Apps**. „The app reads exported USB libraries; its local-folder scanner is disabled.“ Baut auf **Mixxx 2.5.6**; NauticMixxx-Anteile GPL v3, Mixxx-Motor GPL v2 oder später (`LICENSE.md`).
- [CODE] Es ist ein **Patch-Set auf Mixxx 2.5.6**: `patches/0001…0044*.patch` (45 Dateien), keine eigene Engine. 259 verschiedene Dateien betroffen, davon 49 Skin/Widget-Dateien (`grep "+++ b/"` über alle Patches).
- [CODE] Oberfläche = **Qt-Widgets-/XML-Skin** `skins/XDJ_RX3_Mixxx` (`docs/ARCHITECTURE.md`), nicht QML.
- [NICHT UNTERSTÜTZT] **Android:** Der Begriff „android“ kommt im Repo (außerhalb `vendor/`) nicht vor. Plattformen laut README/`packaging/`: macOS, Windows, experimentell Linux/Raspberry Pi (`docs/LINUX-RASPBERRY-PI.md`).
- [DOKU] README: „Physical controller and RX3 audio calibration remain pending.“ – Hardware-Validierung ist laut eigener Angabe nicht abgeschlossen.
- Controller-Mappings dort: Hercules Inpulse 500 plus Presets für DDJ-FLX4, DDJ-400, DDJ-SX/SX2/SX3, DDJ-WeGO3, DJ-505 (README, `docs/DDJ-FLX4-EN.md`).

## 2. Was sie bei Analyse/Rekordbox gelöst haben (Datenschicht)
Das ist genau der Teil, den ich in Phase 0 als Lücke geführt hatte (Waveform ohne Analyse). Alle Angaben aus den Patches, nicht gebaut/getestet:
- [CODE] **Analyse pro Track sperren:** neue `Track::getUsePolicy().canAnalyze()`-Abfrage (`src/track/trackusepolicy.h`, neu) in `AnalyzerThread::doRun`/`submitNextTrack`, `TrackAnalysisScheduler::scheduleTrack` u. a. (`patches/0010-rekordbox-usb-only-runtime.patch:142-215`). Rekordbox-Tracks werden damit nie analysiert – saubere, kleine Einhängestelle statt globalem Schalter.
- [CODE] **Waveform-Import aus ANLZ:** neue Klassen `src/library/rekordbox/rekordboxwaveformimporter.{h,cpp}`, `rekordboxanlzreader.*`, `rekordboxtrackadapter.*`, `rekordboxusbsession.*`, `rekordboxruntimetrackmodel.*`, `rekordboxruntimecatalog.*`, `rekordboxdatabase.*`, `rekordboxdevice.*` (`0010…patch:~1000-1020`, Hunk in `CMakeLists.txt`). Importer implementiert `mixxx::WaveformImporter` (`src/track/waveformimporter.h`, neu). Detail-Tags **PWV3/PWV5/PWV7 mit festen 150 Spalten/s**, Overview-Tags separat; Ergebnis werden Mixxx-`Waveform`/`WaveformSummary` (`createWaveform`, `importWaveforms`, `patches/0015-rekordbox-decoder-timing.patch:~223-270`).
- [CODE] **Timing-Korrektur** an die Decoder-Padding-Offsets (`setSourceTimingOffsetMillis`, `0015…patch`); **PSSI-Phrasen** (Intro/Verse/Chorus …) mit XOR-Maske aus Rekordbox lesen (`docs/WAVEFORM-DIVISIONS-1.7.md`).
- [CODE] „USB-only“-Laufzeit: lokale Bibliothek/Scanner gesperrt (`0010…patch`, `docs/ARCHITECTURE.md`), „cached emergency playback“ wenn der Stick während der Wiedergabe verschwindet (README, `docs/EMERGENCY-SYNC-2.0-EN.md`).
- [CODE/DOKU] Präzise Tempo-/Beatgrid-Behandlung aus Rekordbox (`patches/0031-rx3-emergency-loop-and-precise-rekordbox-tempo.patch`, `docs/BEATGRID-TIMING-1.4.md`, README „Precise imported constant-tempo grids“). **Variables Tempo:** Aussage nur für „constant-tempo“ belegt, sonst nicht geprüft.
- [DOKU] Reihenfolge des Nutzens für uns: Nutzer sagt, das Projekt habe Analyse/Playlist/BPM/Key bereits gelöst. Soweit sichtbar: Playlist-/Trackdaten laufen über das schon in Mixxx vorhandene `rekordboxfeature`, erweitert um Waveform, Phrasen, USB-Session und Runtime-Modell. Key/BPM stammen schon im Upstream-Import aus der PDB (siehe `REKORDBOX_USB_ANALYSIS.md`); **ob NauticMixxx daran mehr ändert, habe ich nicht Zeile für Zeile verglichen.**

## 3. Übertragbarkeit auf unseren Stand (Einschätzung)
- **Gut übernehmbar (Konzept + neue Dateien):** Waveform-Import (PWV*), ANLZ-Reader, Analyse-Gate (`UsePolicy`), USB-only-Laufzeit, Phrasen/PSSI, Emergency-Playback. Überwiegend *neue* Dateien unter `src/library/rekordbox/`, `src/track/`.
- **Nicht direkt übernehmbar:** Skin/Widget-Teile (`skins/XDJ_RX3_Mixxx`, `src/widget`, `src/skin`): Android läuft nur mit QML (siehe `PROJECT_OVERVIEW.md`); die RX3-Ideen (Layout, SHORTCUT/UTILITY) taugen als **Vorlage** für die QML-Touch-Oberfläche, nicht als Code.
- **Anpassung nötig:** Basis 2.5.6 → 2.7.0-alpha (Qt-6-only, neue Engine-/Waveform-Struktur `allshader`/`rendergraph`, QML-Proxies). Patches an Kernstellen (`enginebuffer`, `cachingreaderworker`, `loopingcontrol`, `cuecontrol`, `waveformwidgetrenderer`, `soundsourceproxy`, `coreservices`, `library.cpp`) wären neu zu portieren, nicht per `git apply`. Nicht gemessen; grob: **hoher** Aufwand für die Kernpatches, **mittlerer** für die neuen Rekordbox-Dateien.
- **Plattform:** Der Fork behandelt macOS-Sandbox, Windows-Laufwerke (`0002/0003…`, `0013-rx3-usb-autodiscovery`). **Android-Stick-Zugriff** (Pfad `/storage/<id>/`) ist dort kein Thema und bleibt unsere Arbeit.
- **Controller:** deren FLX4-Mapping/Doku (`docs/DDJ-FLX4-EN.md`, `controllers/`) können wir mit dem Upstream-Mapping vergleichen. Das **MIDI-Backend** fehlt dort ebenfalls (kein Android).

## 4. Lizenz, Marke (keine Rechtsberatung)
- [DOKU] Eigenanteile GPL v3, Mixxx GPL v2+ (`LICENSE.md`); Skin stammt von `pioneered-by-ntamas` (GPL v3). Übernahme in ein GPL-v3-kompatibles Android-Projekt scheint möglich, Details/Attribution prüfen (`THIRD_PARTY_NOTICES.md`). **Nicht verifiziert, Rechtslage bitte selbst bewerten.**
- [DOKU] `TRADEMARKS.md`: Name/Icon/Branding „NauticMixxx“ gehören dem Projekt; Pioneer/rekordbox/Mixxx sind Marken Dritter. **Eigene Benennung und eigenes Branding** verwenden.
- AGENTS.md von Mixxx: KI-erzeugter Code nur mit Mensch im Loop, keine automatischen PRs.

## 5. Empfehlung / nächste Schritte (Vorschlag)
1. Mit dem Projektinhaber klären: Soll NauticMixxx **Code-Quelle** (Patches portieren), **Referenz** (Konzepte nachbauen) oder **Basis** (Fork auf 2.5.6 statt Upstream-main) sein? Letzteres hätte Folgen: Android-Buildenv des Upstream ist für 2.7 (Qt 6.10), 2.5.6 hat vermutlich kein Android-Buildsystem (nicht geprüft).
2. Gezielter Vergleich (nur lesen): `src/library/rekordbox/*` NauticMixxx vs. unser `rekordboxfeature.cpp`, insbesondere Beatgrid (`.DAT`-only-Fall), Cues, Key; Spalten/Kodierung der PWV3/PWV5-Daten.
3. Kleinster Spike für Waveforms: Importer-Datei(en) portieren, Analyse-Gate (`UsePolicy`) einführen, Waveform aus ANLZ auf dem Android-Build anzeigen.
4. Parallel: MIDI-Backend (`MIDI_BACKEND_PLAN.md`).

<!-- Ende KI-generierter Text -->
