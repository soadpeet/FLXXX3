<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# OPENDJ_ANALYSIS – Was aus OpenDJ für FLXXX3 sinnvoll ist

**Stand:** 2026-11-11. Untersucht wurde ein Klon von `https://github.com/openwave-studio/opendj`, Commit `052dde7f2813` (2026-11-11), außerhalb des Projekts. Gelesen: `README.md`, `LICENSE`, `NOTICE`, `Cargo.toml`, `deny.toml`, alle `crates/*/Cargo.toml`, `docs/windows.md`, `openspec/roadmap.md`, Kopfkommentare zentraler Module, Git-Historie. **Nicht** gebaut, nicht gestartet, nicht Zeile für Zeile gelesen (≈ 210 000 Zeilen).

---

## 1. Steckbrief

| Merkmal | Befund |
|---|---|
| Was | DJ-Programm in **Rust** für macOS, Linux, Windows (Windows als „preview“) |
| Version | 0.6.0, „beta“ (`README.md`) |
| Alter | Erster Commit **2026-10-14**, also rund vier Wochen alt; 660 Commits |
| Autoren | `openwave` 422, `Claude` 185, `DJ Nahuel` 46 Commits: im Kern ein Betreiber mit starker KI-Unterstützung |
| Umfang | 16 Crates, u. a. `app` ≈ 98 600 Zeilen (Rust + Slint), `engine` ≈ 42 800, `controllers` ≈ 17 300, `plugins` ≈ 14 800, `library` ≈ 11 300; 1 121 Pakete in `Cargo.lock` |
| Lizenz | Quelltext GPL-2.0-oder-später; Binaries GPL-3.0 bzw. AGPL-3.0 (siehe `LICENSE_AUDIT.md` §6) |
| **Android** | **Nicht vorhanden.** Kein `target_os = "android"`, keine Android-Paketierung; „android“ kommt nur in der Web-Fernbedienung und der Website vor |
| Verhältnis zu Mixxx | Eigenständige Neuimplementierung, die **Mixxx’ Control-Namen und Mapping-Format** übernimmt und Mixxx’ Mappings unverändert mitliefert |

---

## 2. Technischer Aufbau

| Schicht | Technik | Fundstelle |
|---|---|---|
| Oberfläche | **Slint 1.18** (deklarativ, Renderer femtovg auf wgpu), gepatchtes femtovg in `third_party/femtovg` | `crates/app/Cargo.toml`, `crates/app/ui/` |
| Waveform | eigener **wgpu**-Renderer, Fragment-Shader zeichnet in eine Textur; ausdrücklich „nach dem Ansatz von Mixxx’ allshader-Renderern“ | `crates/waveform/src/lib.rs:1-11` |
| Audio-Ausgabe | **cpal 0.18**: WASAPI (shared) und ASIO unter Windows, CoreAudio, ALSA; Ausgänge als Liste von „Routen“ (Master, Kopfhörer, Booth, Einzeldeck → Kanalpaar eines Geräts), Ringpuffer für Zweitgeräte, Zustandsüberwachung mit Wiederöffnen | `crates/engine/src/output.rs:1-20`, `docs/windows.md` |
| Steuerwerte | Registry mit Mixxx-Namen (`[Channel1],play`), einmal aufgelöste Handles, Lesen/Schreiben atomar ohne Sperre | `crates/control/src/lib.rs:1-7` |
| Controller | Mixxx-XML wird gelesen, Mixxx-JavaScript läuft in **QuickJS** (`rquickjs`) gegen dieselbe `engine`/`midi`-API; MIDI über `midir`, HID über `hidapi` | `crates/controllers/src/lib.rs:1-10` |
| Dekodierung/Tags | `symphonia`, `lofty` (reines Rust) | `crates/engine/Cargo.toml` |
| Time-Stretch | `signalsmith-stretch` (gepatcht) statt Rubber Band/SoundTouch | `Cargo.toml` `[patch.crates-io]` |
| Analyse | Beat-Erkennung neuronal („Beat This!“ über `rten`), neuronaler Key-Detektor, Phrasen | `crates/engine/src/{beatthis,keynet,phrases}.rs`, `NOTICE` |
| Stems | Demucs über `burn` (wgpu/Vulkan/Metal) | `crates/separation/` |
| Bibliothek | SQLite über `rusqlite` | `crates/library/` |
| Rekordbox | **Import** aus `master.db` (rekordbox 6/7) und XML auf dem Rechner; **Export** auf USB-Sticks über `rbox` (GPL-3.0-only, „experimentell bis an einem Player getestet“) | `crates/plugins/src/rekordbox/mod.rs:1-5`, `crates/export/`, `openspec/roadmap.md` |
| Sonstiges | Ableton Link, Icecast/Shoutcast, OSC, Telefon-Fernbedienung (WebSocket + QR), CLAP/VST3/AU-Hosting in eigenem Prozess | `crates/{broadcast,osc,remote,plugin-host}` |
| Windows-Paket | Inno Setup, Installation ohne Adminrechte, Selbst-Update mit SHA-256-Prüfung | `docs/windows.md` |
| Prozess | OpenSpec-Änderungsordner mit Aufgabenlisten, `cargo-deny` für Lizenzen und Sicherheitsmeldungen, `NOTICE` je Fremdanteil | `openspec/`, `deny.toml` |

---

## 3. Abgleich mit dem FLXXX3-Kernanwendungsfall

FLXXX3 heute: Android-Gerät, DDJ-FLX4 über eigenes USB-Audio und AMidi, **Rekordbox-Stick direkt lesen** (PDB + ANLZ inklusive Waveform), Touch-Ansicht im RX3-Stil.

| Fähigkeit | FLXXX3 | OpenDJ |
|---|---|---|
| Android | läuft auf S25/Tab A11 | fehlt |
| Windows | fehlt (Mixxx-Basis könnte es) | Vorschau vorhanden |
| Rekordbox-**Stick** lesen (`export.pdb`, ANLZ) | ja | nein (nur Rechner-Bibliothek `master.db`/XML; Sticks werden geschrieben, nicht gelesen) |
| FLX4 | eigenes, erweitertes Mapping, auf Hardware getestet | Mixxx-Mapping mitgeliefert, „FLX4 pad modes“ laut Roadmap v0.3.5 |
| USB-Audio am Android-Stack vorbei | ja (`src/soundio/androidusbaudio.*`) | nein |
| Touch-Bedienung | Kernziel | Desktop-Oberfläche mit Maus/Tastatur |
| Stems, Automix, Sampler, Plugins, Streaming-Browse | bewusst entfernt/aus | vorhanden |

**Folgerung:** OpenDJ löst ein anderes Problem (Desktop-DJ-Programm mit breitem Funktionsumfang). Genau die Teile, die FLXXX3 ausmachen, hat es nicht.

---

## 4. Sinnvolle Ansätze und Funktionen

### 4.1 Als Konzept übernehmen (kein Code nötig)

| # | Ansatz aus OpenDJ | Nutzen für FLXXX3 | Aufwand |
|---|---|---|---|
| O1 | **Ausgänge als Routenliste** mit Zustandsüberwachung und automatischem Wiederöffnen eines verschwundenen Geräts (`output.rs`) | Vorbild für die gemeinsame Audio-Schicht Android/Windows und für das fehlende Hotplug | mittel |
| O2 | **Beat-FX als eigene Effekt-Einheit** nach Pioneer-Mixer-Vorbild (`[EffectRack1_EffectUnit5]`, `crates/engine/src/controls.rs:9-16`) | Abgleich mit der eigenen Beat-FX-Lösung; gleiche Control-Namen würden Mappings austauschbar halten | gering |
| O3 | **Lizenz-Disziplin**: `NOTICE` mit Herkunft je Fremdanteil, automatische Lizenzprüfung in der CI | deckt Lücke L4 in `LICENSE_AUDIT.md` | gering |
| O4 | **Änderungs-Spezifikationen** (OpenSpec: Vorschlag, Spezifikation, Aufgabenliste je Änderung) | passt zur bereits gepflegten Doku in `docs/android-port/` | gering |
| O5 | **Windows-Auslieferung**: Inno Setup pro Benutzer, portable ZIP, Selbst-Update mit Prüfsumme, WASAPI + ASIO in einer Geräteliste | Blaupause für den Windows-Teil | mittel |
| O6 | **„Player“-Layout und Track-End-Warnung, Slip, Beat-Jump, Phrasenzähler** als Funktionsideen | Auswahl nach Bedarf; Track-End-Warnung gibt es in FLXXX3 bereits | je Funktion |
| O7 | **Telefon-Fernbedienung per QR/WebSocket** | Idee für eine spätere Begleitfunktion, lizenzrechtlich als getrenntes Programm denkbar | hoch |

### 4.2 Als Code oder Bibliothek prüfenswert (später, nur mit Rust-Entscheidung)

| # | Baustein | Bewertung |
|---|---|---|
| O8 | **`rbox`-Crates** (Rekordbox-Formate lesen/schreiben) | Fachlich der interessanteste Fund für einen Stick-Parser in Rust. Lizenz GPL-3.0-only: bindet das Produkt fest an GPL-3.0. Lesefähigkeit für `export.pdb` in `rbox-devlib` nicht geprüft. |
| O9 | **Beat This!** über `beat-this`/`rten` (MIT) | Bessere Beatgrids für Titel ohne Rekordbox-Daten. Rechenlast auf dem Telefon ungeklärt. |
| O10 | **`signalsmith-stretch`** (MIT) | Freizügig lizenzierte Alternative zu Rubber Band (GPL) für Key Lock. Klangvergleich nötig. |
| O11 | **QuickJS-Mapping-Laufzeit** | Zeigt, dass Mixxx-Mappings ohne Qt laufen können. Für FLXXX3 erst relevant, falls die Engine einmal ersetzt würde. |

### 4.3 Nicht übernehmen

- **OpenDJ als neue Codebasis.** Kein Android, vier Wochen alt, ein Hauptbetreiber, sehr hohe Änderungsrate, Windows nur Vorschau. Alle auf Hardware erarbeiteten FLXXX3-Teile (USB-Audio, AMidi, Stick-Import, Touch-UI) müssten neu gebaut werden.
- **AGPL-Anteile** (mpump-Grooves) und alles, was ohne Not an GPL-3.0-only bindet.
- **Streaming-Dienste durchsuchen**: rechtlich und vertraglich heikel, kein Ziel von FLXXX3.
- **Stems per Demucs/wgpu**: vom Inhaber bereits ausgeschlossen, auf Mobilgeräten schwer.

---

## 5. Risiken, falls OpenDJ doch stärker genutzt würde

| Risiko | Einschätzung |
|---|---|
| Reife | Beta, kurze Historie; Verhalten unter Last und auf fremder Hardware unbekannt |
| Abhängigkeit von einer Person | hoch |
| Android-Tauglichkeit der Bausteine | Slint und wgpu unterstützen Android, cpal hat ein Android-Backend, **`midir` hat kein Android-Backend**; nichts davon ist in OpenDJ erprobt [nicht geprüft, Stand meines Wissens] |
| Lizenzbindung | GPL-3.0/AGPL-3.0 im Binary; für FLXXX3 kein Nachteil gegenüber heute, aber keine Erleichterung |
| KI-erzeugter Code in großem Umfang | Qualität nur durch eigene Prüfung feststellbar |

---

## 6. Empfehlung

OpenDJ als **Ideen- und Vergleichsquelle** nutzen (O1–O6 sofort als Konzepte, O8–O10 als Kandidaten für einen späteren Rust-Pilot, siehe `CPP_RUST_MIGRATION.md`). **Nicht** als Basis für FLXXX3 verwenden und keinen Code ungeprüft übernehmen. Nach etwa sechs Monaten erneut bewerten: Wenn OpenDJ bis dahin stabil ist und Android unterstützt, ändert sich die Abwägung.

<!-- Ende KI-generierter Text -->
