<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# CPP_RUST_MIGRATION – Welche C++-Module bleiben, wo Rust sinnvoll wäre

**Stand:** 2026-11-11. Analyse und Empfehlung; **keine Migration begonnen, kein Code geschrieben.** Aufwandsangaben sind grobe Schätzungen.

---

## 1. Empfehlung in Kürze

1. **Keine Migration der Engine oder des Mixxx-Kerns nach Rust.** Der Kern ist groß, auf Qt aufgebaut und funktioniert; ein Umschreiben brächte Jahre Arbeit ohne Nutzen für die Anwender.
2. **Rust nur ergänzend**, und erst **nach** dem Aufräumen der Architektur (`ROADMAP.md`, Phase 2) und dem ersten Windows-Stand (Phase 3).
3. **Erster sinnvoller Pilot:** ein eigenständiger Leser für Rekordbox-Datenträger (PDB/ANLZ) als Bibliothek mit C-Schnittstelle. Er verarbeitet fremde Binärdaten, ist nicht echtzeitkritisch, gut testbar und könnte nebenbei die Lizenzfrage L2 (`LICENSE_AUDIT.md`) lösen.
4. Wenn der Pilot den Build nicht spürbar erschwert, folgen höchstens weitere abgeschlossene, nicht echtzeitkritische Bausteine. Andernfalls bleibt es bei C++.

---

## 2. Warum kein großer Umstieg

| Punkt | Befund |
|---|---|
| Umfang | Mixxx hat mehrere hunderttausend Zeilen C++; FLXXX3 fügt ≈ 16 500 Zeilen hinzu. OpenDJ zeigt, dass eine Rust-Neuimplementierung möglich ist, braucht dafür aber selbst ≈ 210 000 Zeilen und hat kein Android. |
| Qt-Verflechtung | Controls, Signale, Library-Modelle, QML-Proxys und Waveform-Renderer hängen an Qt-Objekten (`QObject`, `QSql*`, Szenengraph). Rust kann Qt nur über Brücken (`cxx-qt`) ansprechen; das verdoppelt die Schnittstellen. |
| Echtzeit | Der Audiopfad ist in C++ bereits ohne Allokation und Sperren gebaut. Rust macht ihn nicht schneller; es schützt vor Speicherfehlern, die dort bisher nicht als Problem dokumentiert sind. |
| Build | Heute schon heikel (vcpkg-Buildenv, WSL-Shim, NDK 27, Gradle). Eine zweite Toolchain (rustup, Ziel `aarch64-linux-android`, unter Windows MSVC) erhöht das Risiko genau dort, wo das Projekt am verletzlichsten ist. |
| Upstream | Jede nach Rust verlagerte Kernfunktion entfernt den Fork weiter von Mixxx. |

---

## 3. Modulbewertung

**Legende:** *Bleibt* = in C++ belassen. *Kandidat* = Rust als Ergänzung denkbar. *Nein* = Rust ausdrücklich nicht empfohlen.

| Modul | Pfad | Urteil | Begründung |
|---|---|---|---|
| Engine, Mixer, Sync, Loops, Cues | `src/engine/`, `src/mixer/` | **Bleibt / Nein** | Echtzeit, Kern von Mixxx, hohe Kopplung, bewährt |
| Effekte inkl. Beat-/Color-FX | `src/effects/`, `src/engine/effects/` | **Bleibt** | DSP in C++ unkritisch, eigene Effekte bereits fertig |
| Time-Stretch/Pitch | Rubber Band, SoundTouch | **Bleibt**; Alternative beobachten | `signalsmith-stretch` (MIT) wäre lizenzfreundlicher; es ist selbst eine C++-Bibliothek und ohne Rust einbindbar |
| Controller-Framework und JS-Mappings | `src/controllers/` | **Bleibt / Nein** | hängt an `QJSEngine`; FLX4-Mapping läuft |
| Android-MIDI | `src/controllers/midi/androidmidi*` (≈ 650 Z.) | **Bleibt** | klein, fertig, JNI-nah |
| Android-USB-Audio | `src/soundio/androidusbaudio.*` | **Bleibt** (vorerst) | echtzeitkritisch, auf Hardware abgestimmt. Rust (`rusb`/`nusb`) brächte Sicherheit bei Puffergrenzen, aber das Risiko einer Neufassung überwiegt, solange es stabil läuft |
| Sound-I/O | `src/soundio/` | **Bleibt** | PortAudio deckt Android und Windows ab |
| Waveform-Renderer | `src/waveform/`, `src/rendergraph/` | **Bleibt / Nein** | Qt-Szenengraph, Shader |
| Library/Datenbank | `src/library/` (ohne Rekordbox) | **Bleibt / Nein** | `QSql`-Modelle direkt an QML gebunden |
| QML-Proxys, Produktlogik | `src/qml/` | **Bleibt** | Qt-Objekte per Definition |
| Dekoder, Tags | `src/sources/`, TagLib, FFmpeg | **Bleibt** | funktioniert; `symphonia`/`lofty` (OpenDJ) wären Ersatz ohne erkennbaren Gewinn |
| **Rekordbox-Leser** (PDB, ANLZ, Waveform-Dekodierung) | `lib/rekordbox-metadata/` (Kaitai-generiert), Teile von `src/library/rekordbox/rekordboxfeature.cpp` | **Kandidat 1** | fremde Binärdaten vom Stick (Speichersicherheit zählt hier wirklich), kein Echtzeitpfad, klare Ein-/Ausgabe, heute mit 22 `__ANDROID__`-Stellen verwoben; EPL-Frage L2 |
| **Track-Cache/Dateikopie** | `src/util/androidtrackcache.*` (≈ 300 Z.) | **Kandidat 3** (schwach) | plattformneutral machbar, aber klein; in C++ belassen ist vernünftig |
| **Analyse (neu)**: neuronale Beat-Erkennung | – (in OpenDJ: `beat-this` + `rten`, MIT) | **Kandidat 2** | nur als zusätzliche Offline-Analyse für Titel ohne Rekordbox-Daten; Last auf dem Telefon vorher messen |
| **Werkzeuge außerhalb der App** (Stick prüfen, Diagnose, Build-Helfer) | – | **Kandidat** (frei) | berühren den App-Build nicht; risikofreier Einstieg |

---

## 4. Wie Rust technisch eingebunden würde (falls freigegeben)

| Thema | Vorschlag | Anmerkung |
|---|---|---|
| Schnittstelle | schmale **C-Schnittstelle** (`extern "C"`, Header per `cbindgen`), Daten als einfache Strukturen/Puffer | bewusst kein `cxx-qt`; Qt bleibt auf der C++-Seite |
| Bibliotheksform | statische Bibliothek (`staticlib`), in `libmixxx_arm64-v8a.so` bzw. die Windows-EXE gelinkt | keine zusätzliche Laufzeitdatei im APK |
| CMake | Einbindung über **Corrosion** oder einen `add_custom_command` mit `cargo build --target …` | Corrosion ist eine neue Build-Abhängigkeit (nur beim Bauen) |
| Android | Rust-Ziel `aarch64-linux-android`, Linker aus NDK 27.2 | C++-Laufzeit bleibt `c++_shared`; Rust-Teil ohne C++-Abhängigkeit halten |
| Windows | Ziel `x86_64-pc-windows-msvc`, passend zur MSVC-Laufzeit von Mixxx | |
| Fehlerbehandlung | keine Panics über die Grenze (`catch_unwind`, Fehlercodes) | |
| Threads | Rust-Bausteine laufen nur außerhalb des Engine-Threads | |
| Lizenzprüfung | `cargo-deny` mit Erlaubnisliste, `Cargo.lock` eingecheckt (wie OpenDJ `deny.toml`) | jede Crate vergrößert die Lizenzliste; `rbox` wäre GPL-3.0-only |
| Tests | Unit-Tests mit Beispiel-Sticks/Dateien auf dem Entwicklungsrechner, unabhängig vom Gerät | größter praktischer Gewinn, da es heute keine automatischen Tests für die Eigenentwicklungen gibt |

---

## 5. Pilot „Rekordbox-Leser“ im Detail

- **Umfang:** `export.pdb` (Titel, Playlists, Ordner), ANLZ `.DAT/.EXT/.2EX` (Beatgrid, Cues, PWV3/PWV5/PWV7-Waveforms), Ausgabe als neutrale Strukturen. Die Umwandlung in Mixxx-Objekte (`Track`, `Waveform`, `Beats`) bleibt in C++.
- **Zwei Wege:**
  1. vorhandene `rbox`-Crates nutzen (schnell, aber GPL-3.0-only, zieht SQLite/OpenSSL-Varianten mit; Lesefähigkeit für `export.pdb` vor Entscheidung prüfen);
  2. eigener Parser nach der öffentlichen Formatbeschreibung (mehr Arbeit, keine Lizenzbindung, kleiner).
- **Erfolgskriterien:** gleiche Ergebnisse wie der heutige Import auf den vorhandenen Test-Sticks; APK nicht mehr als ≈ 1–2 MB größer; Android- und Windows-Build ohne Handarbeit; Build-Dauer kaum länger.
- **Abbruchkriterien:** Build auf WSL/NDK wird instabil, oder die Schnittstelle zu Mixxx wird größer als der ersetzte Code.
- **Aufwand:** ≈ 4–6 Wochen einschließlich Tests und Build-Integration. [Schätzung]
- **Rückweg:** Der C++-Import bleibt bis zum bestandenen Vergleich parallel erhalten (Schalter).

---

## 6. Risiken und Kosten von Rust im Projekt

| Risiko | Auswirkung |
|---|---|
| Zweite Toolchain im ohnehin fragilen Android-Build | hoch; deshalb erst nach gesichertem Build-Rezept |
| Zwei Sprachen für ein kleines Team | Einarbeitung, doppelte Werkzeuge (Formatierung, Lint, Debugger) |
| Fehlersuche über die Sprachgrenze auf dem Gerät | Stacktraces über JNI → C++ → Rust sind mühsam |
| Größere Binaries (Rust-Standardbibliothek) | gering bei einem Baustein |
| Lizenzzuwachs durch Crates | beherrschbar mit `cargo-deny` |
| „Zweites System“: schleichende Parallelentwicklung | durch klare Erfolgs-/Abbruchkriterien begrenzen |

---

## 7. Entscheidungspunkte

1. Nach Phase 2/3 der Roadmap: Soll der Rust-Pilot gestartet werden? (ja/nein)
2. Falls ja: `rbox` (GPL-3.0-only) oder eigener Parser?
3. Nach dem Pilot: Rust im Projekt behalten und Kandidat 2 angehen, oder bei C++ bleiben?

Bis zu einer Freigabe gilt: Alles bleibt in C++.

<!-- Ende KI-generierter Text -->
