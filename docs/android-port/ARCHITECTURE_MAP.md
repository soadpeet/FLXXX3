<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# ARCHITECTURE_MAP – Was ist Mixxx, Kern, Produkt, Android?

Stand: 2026-11-11, abgeleitet aus `git diff --name-status bc49961fd3 HEAD` (Mixxx-Basis bis HEAD `8c99f51a5f`, ohne `docs/`) plus uncommittete Dateien. Reine Zuordnung; **kein Code wurde verschoben oder geändert.** Zielbild: `ARCHITECTURE_PROPOSAL.md`.

Legende der Schichten:
- **K** = Mixxx-Kern (Herkunft Mixxx, GPL-2.0-oder-später), von FLXXX3 unverändert oder nur wenig angepasst.
- **K\*** = Mixxx-Kern, **von FLXXX3 geändert** (Eingriff in Upstream-Datei; erschwert Updates).
- **P** = FLXXX3-Produktlogik/-Oberfläche (neu), plattformneutral denkbar.
- **A** = Android-Plattform (neu), plattformspezifisch.
- **W** = Windows: nicht vorhanden.

## 1. Neue Dateien (von FLXXX3)

| Schicht | Dateien |
|---|---|
| **A** MIDI | `src/controllers/midi/androidmidi{controller,enumerator,parser}.{h,cpp}`, `packaging/android/src/org/mixxx/MidiHelper.java` |
| **A** USB-Audio | `src/soundio/androidusbaudio.{h,cpp}`, `packaging/android/src/org/mixxx/UsbAudioHelper.java`, `packaging/android/res/xml/usb_device_filter.xml` |
| **A** Datenträger-Cache | `src/util/androidtrackcache.{h,cpp}` (fachlich plattformneutral machbar) |
| **A/P** Status-Brücke | `src/qml/qmlandroidstatusproxy.{h,cpp}` (Android-Status; Teile davon Produktlogik) |
| **P** Oberfläche | `res/qml/AndroidDJ/*.qml` (18 Dateien), `res/qml/AdvSettings/{AdvSettings.qml,qmldir}` |
| **P** Browse/Listen | `res/qml/Library/{BrowseScreen,InfoTrackList,ListStore,SearchKeyboard}.qml` |
| **P** Effekte | `src/effects/backends/builtin/{beatfxeffects,colorfxeffects}.{h,cpp}` |
| **P** Waveform-Daten | `src/waveform/rekordbox3band.h` |

Unverändert aus Mixxx und im Android-Paket genutzt: `packaging/android/src/org/mixxx/{MainActivity,UsbPermission}.java`, `src/controllers/android.cpp`.

## 2. Von FLXXX3 geänderte Mixxx-Dateien (K\*)

| Bereich | Dateien | Art der Änderung |
|---|---|---|
| Engine | `src/engine/enginebuffer.{h,cpp}`, `src/engine/controls/{bpmcontrol,cuecontrol}.{h,cpp}` | Quantize/Startpunkt wie Rekordbox (unter `__ANDROID__`) |
| Engine/Cache | `src/engine/cachingreader/cachingreaderworker.{h,cpp}`, `src/sources/soundsourceproxy.{h,cpp}` | Track-Cache |
| Engine/Effekte | `src/engine/effects/{engineeffectchain.{h,cpp},message.h}`, `src/effects/{effectchain,effectsmanager}.{h,cpp}`, `src/effects/visibleeffectslist.cpp`, `src/effects/backends/builtin/{builtinbackend,echoeffect,filtereffect,flangereffect,phasereffect,bessel8lvmixeqeffect}.*` | Beat-FX-Bänder, feste Effektliste |
| Sound-I/O | `src/soundio/{soundmanager,soundmanagerconfig,sounddeviceportaudio}.{h,cpp}` | FLX4-Zuordnung, USB-Audio-Anbindung, Puffer/Samplerate |
| Controller | `src/controllers/controllermanager.{h,cpp}`, `res/controllers/Pioneer-DDJ-FLX4*` | Android-MIDI, FLX4-Mapping |
| Bibliothek | `src/library/{library.cpp,searchqueryparser.cpp}`, `src/library/rekordbox/rekordboxfeature.{h,cpp}` | Stick-Suche, ANLZ-Waveform, Android-Pfade |
| Mixer/Start | `src/mixer/{basetrackplayer.cpp,playermanager.*}`, `src/coreservices.cpp`, `src/main.cpp`, `src/util/logging.cpp` | Android-Einstellungen, Sprache, Abschaltungen |
| Track/Analyse | `src/track/{track.h,keyutils.cpp}`, `src/analyzer/analyzerwaveform.cpp`, `src/preferences/replaygainsettings.cpp`, `src/util/color/predefinedcolorpalettes.cpp` | Stems aus, Analyse-Tempo, Farben |
| QML-Anbindung | `src/qml/{qmlconfigproxy,qmllibraryproxy,qmllibrarysource,qmllibrarytracklistcolumn,qmllibrarytracklistmodel,qmlplayerproxy,qmlwaveformdisplay,qmlwaveformoverview}.*` | Proxys für die Produktoberfläche |
| Waveform | `src/waveform/renderers/**` (9 Dateien) | Anzeige-Varianten, Marker, Höhe |
| Render | `src/rendergraph/scenegraph/backend/basematerial.cpp` | Fehlerkorrektur (nicht Android-spezifisch, für Upstream geeignet) |
| QML (Mixxx-eigen) | `res/qml/{main,Deck,Library,Sampler,Settings,WaveformDisplay,WaveformOverview}.qml`, `res/qml/Library/{Browser,Cell,SourceTree,Track,TrackList}.qml`, `res/qml/Settings/Library.qml`, `res/qml/Mixxx/Controls/WaveformOverview*.qml` | Touch-Fixes, Einstieg `main.qml` |
| Build/Paket | `CMakeLists.txt`, `packaging/android/AndroidManifest.xml`, Icons | Android-Zweige, Manifest |
| Projektregeln | `AGENTS.md` | lokale Ausnahme für Commits (Abschnitt „Local exception“) |

Alles Übrige im Baum ist unverändert aus Mixxx (Kern **K**).

## 3. Wo die Plattformgrenze heute verläuft

| Merkmal | Befund |
|---|---|
| Android-Bedingungen im Code | `__ANDROID__` in 58 `src/`-Dateien; Schwerpunkte: `rekordboxfeature.cpp` (22), Waveform-Renderer (≈ 30 zusammen), `library.cpp` (7), `soundmanagerconfig.cpp` (6), `cuecontrol.cpp` (6) |
| Oberfläche | `res/qml/main.qml` lädt `AndroidDJ.MainWindow` nur bei `isMobile` (Android/iOS) |
| Saubere Kapselung | MIDI, USB-Audio, Track-Cache, Java-Helfer (alles in eigenen Dateien) |
| Vermischt | Produktverhalten (Quantize, Abschaltungen, Waveform-Varianten, Rekordbox-Import) steht als `__ANDROID__`-Block mitten in Mixxx-Dateien |
| Windows | keine Umsetzung; Upstream-Zweige (z. B. `rekordboxfeature.cpp:219`) unberührt |

## 4. Folgerungen (nur Vorschläge, nichts umgesetzt)

1. Ein Umbau in Ordner `src/product/` und `src/platform/` bringt jetzt **keinen** Nutzen, solange die K\*-Dateien nicht angefasst werden dürfen; er ist erst in Phase 2 der `ROADMAP.md` sinnvoll, wenn Produktverhalten auf Schalter umgestellt wird. Verschieben würde außerdem die Git-Historie der Dateien erschweren.
2. Ein CMake-Schalter `FLXXX3_PRODUCT` wurde bewusst **nicht** eingeführt: Es gibt keinen konkreten technischen Grund, solange es nur einen Zielplatz (Android) gibt; die bestehenden Android-Bedingungen in `CMakeLists.txt` (Zeilen ≈ 57–100, 2373–2452, 3719, 3752–3758, 3785, 5316–5322) erfüllen den Zweck.
3. Wenn Windows beginnt: zuerst die K\*-Dateien mit Produktverhalten (Zeile „Engine“, „Bibliothek“, „Waveform“ oben) auf Konfigurationsschalter umstellen, danach `res/qml/AndroidDJ/` plattformneutral benennen.

<!-- Ende KI-generierter Text -->
