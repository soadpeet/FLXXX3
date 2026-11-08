<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# CHANGES_INVENTORY – Bestandsaufnahme der Änderungen am Mixxx-Quellcode

**Stand:** 2026-11-07, Branch `android-midi` (alles **uncommittet** im Arbeitsverzeichnis, Basis `bc49961fd3`). Zahlen aus `git diff --stat` / `git status`: 80 geänderte Dateien (2984 Zeilen hinzugefügt, 709 entfernt), 14 neue Pfade (Dateien/Ordner, siehe unten). Commits, Branches und Pushes macht der Mensch (AGENTS.md); dieses Dokument schlägt nur die Aufteilung vor und führt nichts aus.

Spalte „Upstream“: Eignung für einen Beitrag an das Mixxx-Projekt ([WAHRSCHEINLICH], Einschätzung). Fast alles ist mit `__ANDROID__`/Android-Pfaden begrenzt; Ausnahmen sind vermerkt.

## 1. Gruppen (jede könnte ein eigener Branch/Commit-Satz werden)

Pfade mit `*` sind neu (untracked) und brauchen `git add`. Dateien mit Hunks mehrerer Gruppen sind unter „gemischt“ aufgeführt: dort `git add -p` benutzen.

| # | Gruppe | Dateien | Zweck | Upstream |
|---|---|---|---|---|
| A | **Android-MIDI-Backend** | `packaging/android/src/org/mixxx/MidiHelper.java`*, `src/controllers/midi/androidmidi{controller,enumerator,parser}.{h,cpp}`*; gemischt: `CMakeLists.txt`, `src/controllers/controllermanager.cpp` | USB-MIDI-Controller (FLX4) über `MidiManager` + AMidi; FLX4-Auto-Einrichtung | Parser gut; Auto-Einrichtung projektspezifisch |
| B | **Audio-Zuordnung FLX4** | `src/soundio/soundmanager.cpp`, `src/soundio/soundmanagerconfig.{h,cpp}` | Oboe-Default, feste Zuordnung Main→1/2, PFL→3/4 | API-Default ja, Rest projektspezifisch |
| C | **Rekordbox auf Android** | `src/library/rekordbox/rekordboxfeature.{h,cpp}`, `src/qml/qmllibrarysource.{h,cpp}`, `src/qml/qmlandroidstatusproxy.{h,cpp}`* | Stick-Suche (`/mnt/media_rw`), ANLZ-Import (Waveform, Beatgrid, Cues), alle Sticks automatisch lesen, gemeinsame Liste „ALL STICKS“, Beatgrid mit erstem Beat knapp vor 0 | Import ja (Schalter nötig), Android-Pfad mit Vorbehalt |
| D | **Track-Cache für Wechseldatenträger** | `src/util/androidtrackcache.{h,cpp}`*, `src/sources/soundsourceproxy.{h,cpp}`, `src/engine/cachingreader/cachingreaderworker.{h,cpp}`; gemischt: `CMakeLists.txt` | Kopie in den App-Cache, damit Ziehen die App nicht beendet | riskant für Upstream (Engine), nur Android |
| E | **Quantize / Startpunkt wie Rekordbox** | `src/engine/enginebuffer.{h,cpp}`, `src/engine/controls/bpmcontrol.{h,cpp}`, `src/engine/controls/cuecontrol.{h,cpp}` | Phasenabgleich zum anderen Deck nur bei Sync, Quantize-Beat-Wert, Startpunkt = erster Beat (bis 65 ms vor 0), AUTO CUE | als Option denkbar; fest unter `__ANDROID__` |
| F | **Touch/QML-Fixes** | `res/qml/Settings.qml`, `res/qml/Settings/Library.qml`, `res/qml/Library/{Cell,Track,SourceTree,Browser}.qml`, `res/qml/Deck.qml`, `res/qml/Sampler.qml` | Schließen der Einstellungen, Absturz beim Scrollen, Lesbarkeit | gut |
| G | **Stems aus / Analyse-Tempo** | `src/track/track.h`, `src/analyzer/analyzerwaveform.cpp`, `src/preferences/replaygainsettings.cpp` | `hasStem()` ohne `__STEM__`; schnellere Stride-Prüfung; kein ReplayGain auf Android | `track.h` und Analyse-Tempo gut |
| H | **Touch-Oberfläche (eine Ansicht)** | `res/qml/AndroidDJ/`* (13 Dateien), `res/qml/main.qml` (Android-Fenster, FLXXX3-Startbild), `src/coreservices.cpp`, `src/main.cpp`, `src/util/logging.cpp`, `src/library/library.cpp`, `src/mixer/playermanager.{h,cpp}`, `src/mixer/basetrackplayer.cpp`, `src/qml/qmlconfigproxy.{h,cpp}` | RX3-artige Oberfläche, Sprache, kein AutoDJ/Crates, Android-Einstellungen | projektspezifisch |
| I | **BROWSE / SOURCE** | `res/qml/Library/BrowseScreen.qml`*, `res/qml/Library.qml`, `res/qml/Library/TrackList.qml`, `res/qml/AndroidDJ/SourceScreen.qml`* (in H-Ordner), `src/qml/qmllibraryproxy.{h,cpp}`, `src/qml/qmllibrarytracklistmodel.{h,cpp}` | Kategorien, INFO, Track-Menü (langer Druck), Key-Format, Ordner mit OFF/ACTIVE, Sticks als Hauptquelle | projektspezifisch |
| J | **Waveform (Anzeige)** | `src/waveform/renderers/allshader/{waveformrendererfiltered,waveformrendererrgb,waveformrenderbeat,waveformrendermarkrange}.{h,cpp}`, `src/waveform/renderers/{waveformmark,waveformrenderersignalbase,waveformwidgetrenderer}.{h,cpp}`, `src/qml/qmlwaveformdisplay.cpp`, `src/qml/qmlwaveformoverview.{h,cpp}`, `res/qml/WaveformDisplay.qml`, `res/qml/WaveformOverview.qml`, `res/qml/Mixxx/Controls/WaveformOverview*.qml` | 3BAND/BLUE/RGB, RX3-Marker, Loop orange/weiß, Beat-Ticks, feste Höhe | projektspezifisch |
| K | **Render-Fix: Farbe von Knoten** | `src/rendergraph/scenegraph/backend/basematerial.cpp` | `updateUniformsByteArray` kopierte nur bei „dirty“; der Zwischenspeicher wird aber von allen Materialien eines Typs geteilt → Knoten zeichneten mit der Farbe eines anderen (flimmernde Loop-Fläche) | **gut für Upstream** (eigener kleiner Commit, nicht Android-spezifisch; Kosten: Upload je Knoten und Frame) |
| L | **Beat FX** | `src/effects/backends/builtin/{builtinbackend,echoeffect,flangereffect,phasereffect}.{h,cpp}`, `src/effects/visibleeffectslist.cpp`, `src/effects/effectchain.{h,cpp}`, `src/engine/effects/{engineeffectchain.{h,cpp},message.h}`, `res/qml/AndroidDJ/{FxPanel,FxPresetBand}.qml` (in H-Ordner) | Delay, Ping Pong, feste Liste; Beat-Werte; Bandwahl LOW/MID/HI (Frequenzweiche in `EngineEffectChain`, Steuerwert `[EffectRackN_EffectUnitM],bands`) | Bandwahl als Feature denkbar |
| M | **FLX4-Skript und -Mapping** | `res/controllers/Pioneer-DDJ-FLX4-script.js`, `res/controllers/Pioneer-DDJ-FLX4.midi.xml` | Tempo-Bereiche, Sync/MASTER, Beat-FX (ON/OFF-LED: 0x7F = Blinken, 0x00 = Leuchten), SHIFT+Browse = 10 Titel pro Schritt, LOOP IN/OUT (in einer aktiven Loop ohne Wirkung; IN setzt nur den Start, OUT setzt das Ende und erzeugt die Loop), RELOOP/EXIT (Loop verlassen oder neue 4-Beat-Loop), Loop setzt Cue | projektspezifisch |
| N | **Paketierung** | `packaging/android/AndroidManifest.xml`, `packaging/android/res/drawable/ic_launcher_{background,foreground}.xml` | App-Name FLXXX3, Symbole; `profileable` ist entfernt | projektspezifisch |
| O | **ADVANCED SETTINGS** | `res/qml/AdvSettings/`* (`AdvSettings.qml`, `qmldir`), `res/qml/AndroidDJ/{AdvancedSettings,UtilityMenu}.qml`, `src/soundio/soundmanager.h`, `src/soundio/soundmanagerconfig.cpp`, `src/qml/qmlandroidstatusproxy.cpp`, `src/library/rekordbox/rekordboxfeature.{h,cpp}`, `src/waveform/renderers/{waveformrenderersignalbase.cpp,allshader/waveformrenderer{filtered,rgb}.cpp}` | Feineinstellungen mit Presets: AUDIO (USB-Puffer, Samplerate, Master-Headroom), WAVEFORM (Zoom, Höhe, Beatgrid-Helligkeit), WINDOW (Zeiten), JOGWHEEL (Backspin, Vinyl-Stop/Start), START (Tempo-Bereich, Sticks automatisch oder auf Abruf lesen), INFO; Nachtmodus = Systemhelligkeit + Abdunklung; Medienlautstärke nur mit FLX4 auf Max | projektspezifisch |
| – | **Dokumentation** | `docs/android-port/`* | Projektgedächtnis | nicht für Upstream |

## 2. Diagnose und Aufräumen

Am 2026-11-07 entfernt: Diagnose-Hook `engine.log`→logcat (`controllerscriptinterfacelegacy.cpp`), `engine.log`-Zeilen und LED-Test im FLX4-Skript, erweiterte Beat-Grid-Logzeile, ungenutzte `android/log.h`-Includes (`enginebuffer.cpp`, `cuecontrol.cpp`, `waveformrenderersignalbase.cpp`), `profileable` im Manifest.

Noch zu prüfen (nicht angefasst):
- `mixxx-sound`-Logs: nicht mehr vorhanden (2026-11-07 geprüft).
- `mixxx-rekordbox`: auf die Beat-Grid-Zeile reduziert (2026-11-07).
- `mixxx-midi`: Roh-Nachrichten gibt es nicht mehr; „ports opened“, „applyMapping“ und die Geräteanzahl entfernt, Lebenszyklus- und Fehler-Logs bleiben (2026-11-07).
- `mixxx-cache`-Logs → behalten (nützlich im Feld).
- `res/qml/Library/Cell.qml`: Diff wegen Einrückung groß (`git diff -w`).
- Reste im FLX4-Skript: keine bekannt; Tempo-Regler eines Sync-Followers wird bewusst ignoriert (Pick-up nach Sync-Aus).

## 3. Bekannte Lücken
- Stand 2026-11-08: Die Diagnose-Logs (Waveform SUM/NO-DRAW, Color FX, TRIM, `masterkey`, `STICKSCAN`) sind aus dem Quelltext entfernt (per Suche geprüft, nicht am Gerät); `androidopenslout.*` ist entfernt (Commit `e583d485ea`).
- ADVANCED SETTINGS: USB-Puffer und Samplerate wirken erst nach einem Neustart; Master-Headroom ist eine feste Pegelabsenkung (Mixxx hat keinen Limiter); Beat-Grid-Helligkeit am Gerät nicht gesondert bestätigt.
- Ordner-Schalter OFF/ACTIVE in SOURCE filtert die Tablet-Liste noch nicht pro Ordner (zeigt alle Titel, sobald ein Ordner aktiv ist).
- BROWSE: PLAYLIST, FOLDER, HISTORY, GENRE, SEARCH, TAG LIST, Sortieren, TRACK FILTER fehlen.
- Beat FX: Spiral, Helix, Trans fehlen; Filter ohne Tempo-Parameter; Bandweiche ist eine einfache Frequenzweiche (250 Hz / 2,5 kHz) ohne Latenzausgleich.
- Zoom über FLX4 (Regler ohne SHIFT bei geschlossener Bibliothek) ist gesperrt für Titelwechsel; ob der Hänger beim starken Zoomen ganz weg ist, ist nicht belegt.
- Cache-Fenster vor Kopierende, Analyse-Thread vom Stick, kein MIDI-Hotplug (siehe `PROGRESS.md`).
- Die ON/OFF-LED der FLX4 ist nur durch Probieren ermittelt (Werte), nicht aus einer Herstellerangabe.

## 4. Vorschlag zum Trennen in Branches (vom Menschen auszuführen)

Basis jeweils `main` (`bc49961fd3`). Beispiel für Gruppe K (kleinster, eigenständiger Commit) und Gruppe A:
```
git checkout main && git checkout -b render-uniform-fix
git add src/rendergraph/scenegraph/backend/basematerial.cpp
git commit

git checkout main && git checkout -b android-midi-backend
git add packaging/android/src/org/mixxx/MidiHelper.java src/controllers/midi/androidmidi*
git add -p CMakeLists.txt src/controllers/controllermanager.cpp   # nur die MIDI-Hunks wählen
git commit
```
Dateien mit mehreren Gruppen (`CMakeLists.txt`, `src/controllers/controllermanager.cpp`, `rekordboxfeature.cpp` für C und I) mit `git add -p` je Gruppe auswählen. Vor dem Committen: Abschnitt 2 abarbeiten und AGENTS.md beachten (Texte, die eine KI geschrieben hat, brauchen den Disclaimer am Anfang und am Ende).

## 5. Nicht im Quellcode
Build-Hilfen liegen außerhalb des Repos in `~/mixxx-android/` (Buildenv, `env.sh`, `uname`-Shim wegen WSL-Sperre `CMakeLists.txt:268-276`, `debug.keystore`, signierte APKs `backup/2026-11-06c/ui1xx.apk`, `perf/`). `tools/android_buildenv.sh` ist unverändert; das Host-Paket `libsm6` muss separat installiert werden. Tablet: Galaxy Tab A11 (SM-X130), adb per WLAN (Port wechselt), `platform-tools` unter `/usr/lib/android-sdk/platform-tools`.

<!-- Ende KI-generierter Text -->
