<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# NOTICE – Herkunft und Lizenzhinweise von FLXXX3

FLXXX3 ist ein Fork von **Mixxx** (https://mixxx.org, Repository `mixxxdj/mixxx`) und enthält dessen Quelltext. FLXXX3 ist ein eigenständiges Vorhaben und **nicht mit dem Mixxx-Projekt verbunden und nicht von ihm unterstützt**. „Mixxx“ ist der Name des Upstream-Projekts.

Basis des Forks: Mixxx 2.7.0-alpha, Commit `bc49961fd3` (Merge pull request #15251). Die Änderungen seitdem stehen in der Git-Historie (Branch `android-midi`) und sind in `docs/android-port/CHANGES_INVENTORY.md` nach Gruppen beschrieben.

## Lizenz

- Mixxx und alle Änderungen daran: **GNU General Public License, Version 2 oder (nach Wahl) jede spätere Version**. Volltext: `LICENSE`, `COPYING`. **Diese Dateien und alle Urhebervermerke in den Quelldateien bleiben unverändert.**
- Gebaute Programmdateien (APK) enthalten Bibliotheken unter GPL-3.0 (u. a. xwax, libkeyfinder). Sie sind daher als **GPL-3.0** weiterzugeben (GPL-2.0-oder-später erlaubt das). Details: `LICENSE_AUDIT.md`.
- Eigene Ergänzungen von FLXXX3 stehen unter derselben Lizenz (GPL-2.0-oder-später). Ein Teil davon wurde mit Hilfe eines KI-Agenten (Claude) erstellt; solche Dateien tragen einen entsprechenden Vermerk.
- Der Quelltext zu jedem verteilten Build ist unter dem Commit des jeweiligen Release verfügbar (Repository `soadpeet/FLXXX3`).

## Aus Mixxx übernommen (unverändert oder angepasst)

| Bereich | Pfad | Hinweis |
|---|---|---|
| Engine, Mixer, Sync, Loops, Cues | `src/engine/`, `src/mixer/` | in einigen Dateien durch FLXXX3 geändert (Quantize/Startpunkt, Cache-Reader) |
| Controller-Framework, MIDI/HID | `src/controllers/` | MIDI-Backend für Android ist neu (`androidmidi*`) |
| Bibliothek, Rekordbox-Import | `src/library/`, `lib/rekordbox-metadata/` | Android-Pfad und Waveform-Import ergänzt |
| Effekte | `src/effects/`, `src/engine/effects/` | Beat-/Color-FX ergänzt |
| Waveform | `src/waveform/`, `src/rendergraph/` | Anzeige angepasst |
| Sound-I/O | `src/soundio/` | PortAudio/Oboe; USB-Audio-Treiber für Android neu |
| QML-Schicht | `src/qml/`, `res/qml/` | Produktoberfläche in `res/qml/AndroidDJ/` neu |
| Controller-Mappings | `res/controllers/` | FLX4-Mapping von FLXXX3 erweitert; Autoren stehen im jeweiligen `<info>`-Element |
| Skins | `res/skins/` | je Skin eigene Lizenz in `skin.xml` (teils Creative Commons) |
| Übernommene Bibliotheken | `lib/` | siehe unten |

Welche Dateien neu von FLXXX3 stammen und welche aus Mixxx: `docs/android-port/ARCHITECTURE_MAP.md`.

## Bibliotheken im Quellbaum (`lib/`)

| Pfad | Lizenz (laut Dateikopf/Lizenzdatei) |
|---|---|
| `lib/xwax` | GPL-3.0 |
| `lib/qm-dsp` | GPL-2.0-oder-später |
| `lib/fidlib` | GPL / LGPL (siehe `COPYING`, `COPYING_LIB`) |
| `lib/libshout-idjc` | GPL |
| `lib/mp3guessenc-0.27.4` | GPL |
| `lib/portaudio` | MIT-artig (`LICENSE.txt`) |
| `lib/kaitai` | MIT (`LICENSE`) |
| `lib/rekordbox-metadata` | generiert aus Formatbeschreibungen von Deep Symmetry (crate-digger), deklariert als **EPL-1.0** – Klärung offen (`LICENSE_AUDIT.md` L2) |
| `lib/rigtorp/SPSCQueue`, `lib/hidapi`, `lib/replaygain`, `lib/reverb`, `lib/apple` | jeweils eigene Dateiköpfe |

## Bibliotheken im Android-Build (Buildenv `mixxx-deps-2.7-arm64-android-1c20f84a`)

Qt 6.10.3 (LGPL/GPL, dynamisch), FFmpeg (LGPL), libusb (LGPL), libdjinterop (LGPL-3.0), TagLib (LGPL), SoundTouch (LGPL), Rubber Band (GPL), libkeyfinder (GPL-3.0), FFTW3 (GPL), libmad (GPL), LAME (LGPL), Oboe (Apache-2.0), PortAudio (MIT-artig), Opus, FLAC, Vorbis, SQLite, Chromaprint (MIT-Kern), Protobuf u. a. Die vollständige Prüfung steht in `LICENSE_AUDIT.md`. **Offen:** `libfdk-aac.a` ist im Link enthalten (Lizenz gilt als GPL-unverträglich, `LICENSE_AUDIT.md` L1).

## Marken

„rekordbox“, „Pioneer DJ“, „AlphaTheta“, „DDJ-FLX4“, „XDJ-RX3“ sind Marken ihrer jeweiligen Inhaber und werden nur zur Beschreibung der Kompatibilität genannt. FLXXX3 ist nicht mit ihnen verbunden. „Qt“, „Android“, „ASIO“ gehören ebenfalls ihren Inhabern.

## Referenzprojekte

Das Rekordbox-Waveform-Layout wurde anhand der Beschreibung im Projekt NauticMixxx (GPL-3.0) nachvollzogen; ob und in welchem Umfang Code übernommen wurde, ist noch zu prüfen (`LICENSE_AUDIT.md` L7).

<!-- Ende KI-generierter Text -->
