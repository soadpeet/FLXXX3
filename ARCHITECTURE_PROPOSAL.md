<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# ARCHITECTURE_PROPOSAL – Gemeinsame Architektur für Android und Windows

**Stand:** 2026-11-11, HEAD `8c99f51a5f`. Reiner Vorschlag: nichts wurde geändert, verschoben oder implementiert. Grundlagen: `PROJECT_ASSESSMENT.md`, `LICENSE_AUDIT.md`, `OPENDJ_ANALYSIS.md`, eigene Code-Stichproben. Aufwandsangaben sind grobe Schätzungen für eine Person mit KI-Unterstützung, nicht belegt.

---

## 1. Empfehlung in einem Absatz

**Auf der Mixxx-Basis (C++/Qt 6/QML) bleiben und FLXXX3 als sauber geschichtetes, eigenständiges GPL-Produkt ausbauen.** Die Engine bleibt Mixxx-Code; alles Eigene wandert schrittweise in klar abgegrenzte Schichten (Produkt-Oberfläche, Produktlogik, Plattformdienste), sodass derselbe Quellbaum Android und Windows bedient. Rust wird nicht als Ersatz, sondern höchstens später für einzelne, abgeschlossene Bausteine eingesetzt. Ein Neuaufbau (in Rust, auf OpenDJ oder proprietär) wird nicht empfohlen.

Begründung: Mixxx läuft bereits auf Windows, Qt Quick läuft auf beiden Plattformen, und die schwierigsten Teile (FLX4-Audio/MIDI auf Android, Stick-Import, Touch-Oberfläche) sind vorhanden und auf Hardware getestet. Der Weg zu Windows ist damit eine Aufräum- und Portierungsaufgabe, kein Neubau.

---

## 2. Varianten im Vergleich

| | A: Mixxx-Fork schichten (empfohlen) | B: Umstieg auf OpenDJ/Rust | C: Mixxx-Kern + Rust-Bausteine | D: Proprietäre Neuentwicklung |
|---|---|---|---|---|
| Android | vorhanden | fehlt komplett | vorhanden | neu |
| Windows | Mixxx baut dort; eigene Oberfläche portieren | Vorschau vorhanden | wie A | neu |
| Wiederverwendung des Bestands | fast alles | fast nichts | fast alles | nichts (GPL-Code darf nicht hinein) |
| Lizenz | GPL-3.0 (Binary) | GPL-3.0/AGPL-3.0 | GPL-3.0 | frei wählbar |
| Aufwand bis Windows-Beta | ≈ 3–5 Monate | ≈ 9–15 Monate | A plus 1–2 Monate je Baustein | Personenjahre |
| Hauptrisiko | Upstream-Drift, QML-Reife in Mixxx | junge Fremdbasis, Android-Neuland | zweite Toolchain im Android-/Windows-Build | Umfang, Finanzierung |
| Bewertung | **beste Aufwand/Nutzen-Relation** | nicht empfohlen | als spätere Ergänzung zu A | nur bei zwingendem Closed-Source-Ziel |

Variante C ist kein Gegenentwurf, sondern eine mögliche Ausbaustufe von A (Details in `CPP_RUST_MIGRATION.md`).

---

## 3. Zielarchitektur (Variante A)

```
┌──────────────────────────────────────────────────────────────────────┐
│ 5  Produkt-Oberfläche (QML)                                          │
│    res/qml/AndroidDJ/ → künftig plattformneutral („Product UI“)      │
│    eine Ansicht, Layout-Varianten für Telefon / Tablet / Desktop     │
├──────────────────────────────────────────────────────────────────────┤
│ 4  Produktlogik (C++, QML-Proxys)                                    │
│    Einstellungen/Presets, Stick-Verwaltung, Statusmodell,            │
│    Beat-/Color-FX-Auswahl, Browse-Modelle                            │
│    heute verteilt: src/qml/qmlandroidstatusproxy.*, [AndroidDJ]-Keys │
├──────────────────────────────────────────────────────────────────────┤
│ 3  Mixxx-Kern (unverändert halten, Abweichungen nur über Schalter)   │
│    Engine, Mixer, Sync, Effekte, Controller-Framework + JS-Mappings, │
│    Library/SQLite, Waveform-Renderer, Dekoder, Analyse               │
├──────────────────────────────────────────────────────────────────────┤
│ 2  Plattformdienste (Schnittstellen, je Plattform eine Umsetzung)    │
│    Audio-Ausgabe │ MIDI │ Wechseldatenträger │ Datei-Cache │         │
│    System (Helligkeit, Lautstärke, Wachhalten, Berechtigungen)       │
├───────────────────────────────┬──────────────────────────────────────┤
│ 1a Android                    │ 1b Windows                           │
│  Oboe/AAudio, libusb-UAC,     │  PortAudio: WASAPI / ASIO,           │
│  AMidi + Java-Helfer,         │  PortMidi (WinMM),                   │
│  /mnt/media_rw, JNI           │  Laufwerksbuchstaben, Win32          │
└───────────────────────────────┴──────────────────────────────────────┘
```

### Regeln der Schichtung
1. **Schicht 5 und 4 kennen keine Plattform.** Kein `Qt.platform.os`-Zweig für Fachlogik, kein `__ANDROID__` oberhalb von Schicht 2. Unterschiede kommen als Fähigkeiten aus Schicht 2 (z. B. „kann Systemhelligkeit setzen: ja/nein“).
2. **Abweichungen vom Mixxx-Verhalten sind Optionen, nicht Plattformzweige.** Beispiel: Quantize/Startpunkt „wie Rekordbox“ steht heute fest unter `__ANDROID__` (`src/engine/enginebuffer.*`, `src/engine/controls/{bpmcontrol,cuecontrol}.*`). Als Konfigurationsschalter gilt es auf beiden Plattformen und ist upstream-fähig.
3. **Kern-Eingriffe klein und einzeln begründet halten**, damit Mixxx-Updates einspielbar bleiben. Allgemeine Fehlerkorrekturen (z. B. `src/rendergraph/scenegraph/backend/basematerial.cpp`) gehören an Upstream (durch den Inhaber, siehe `AGENTS.md`).
4. **Engine-Thread-Regeln gelten unverändert**: keine Allokation, keine Sperren.

### Ist-Zustand gegenüber dem Ziel [geprüft]
- Die neue Oberfläche wird nur mobil geladen: `res/qml/main.qml:12` (`isMobile`), `:55`.
- `__ANDROID__` steht in 58 Quelldateien, gehäuft in `src/library/rekordbox/rekordboxfeature.cpp` (22 Stellen), den Waveform-Renderern (`waveformrendererfiltered.cpp` 10, `waveformrenderbeat.cpp` 9, `waveformrendererrgb.cpp` 6), `src/library/library.cpp` (7), `src/soundio/soundmanagerconfig.cpp` (6), `src/engine/controls/cuecontrol.cpp` (6). Das meiste davon ist **Produktverhalten**, nicht Plattformtechnik, und gehört hinter Schalter.
- Echte Plattformtechnik ist bereits gut gekapselt: `src/controllers/midi/androidmidi*`, `src/soundio/androidusbaudio.*`, `src/util/androidtrackcache.*`, `packaging/android/src/org/mixxx/*.java`.
- Die Stick-Suche hat schon einen Windows-Zweig aus Upstream: `rekordboxfeature.cpp:219` (`__WINDOWS__`) neben dem eigenen Android-Zweig `:273`.

---

## 4. Plattformdienste im Einzelnen

| Dienst | Android (vorhanden) | Windows (zu bauen/prüfen) | Gemeinsame Schnittstelle |
|---|---|---|---|
| **Audio** | Oboe/AAudio über PortAudio (`sounddeviceportaudio.*`); für den FLX4 eigener libusb-Treiber mit 1-ms-Paketen (`androidusbaudio.*`) | PortAudio mit WASAPI und ASIO (Mixxx-Standard). FLX4 als 4-Kanal-Gerät: Main 1/2, Kopfhörer 3/4 | Routenmodell „Mix → Kanalpaar eines Geräts“ mit Zustand und Wiederöffnen (Anregung O1 aus `OPENDJ_ANALYSIS.md`); feste FLX4-Zuordnung als Profil statt Android-Sonderfall |
| **MIDI** | AMidi + `MidiHelper.java` | PortMidi (Mixxx-Standard, im Android-Build aus) | Mixxx’ `MidiController`-Basisklasse ist bereits die Schnittstelle; Hotplug auf beiden ergänzen |
| **Wechseldatenträger** | `/mnt/media_rw/<uuid>`, `MANAGE_EXTERNAL_STORAGE` | Laufwerksbuchstaben, Geräte-Ereignisse | „Liste der Datenträger + Ereignis angesteckt/entfernt“ |
| **Datei-Cache** | Kopie in App-Cache, damit Ziehen des Sticks nicht abstürzt | fachlich gleich sinnvoll; Pfade anders | plattformneutral machen (ist kaum Android-spezifisch) |
| **System** | Helligkeit, Medienlautstärke, Wachhalten, Berechtigungen (JNI) | Energiesparen verhindern, sonst wenig | Fähigkeitsabfrage, fehlende Funktion blendet die Bedienung aus |
| **Paketierung** | Gradle/`androiddeployqt`, APK-Signierung | Installer (Inno Setup oder Mixxx’ WiX/CPack), Code-Signatur | getrennt, gemeinsame Versionsnummer |

---

## 5. GUI-Technologien

| Technik | Android | Windows | Lizenz | Passung |
|---|---|---|---|---|
| **Qt Quick / QML** (heute) | ja, im Einsatz | ja | LGPL-3.0/GPL/kommerziell | **Empfehlung.** ≈ 6 100 Zeilen eigene Oberfläche vorhanden; direkte Bindung an Mixxx-Controls über `Mixxx.ControlProxy`; Waveform-Renderer hängen am Qt-Szenengraphen |
| Slint (OpenDJ) | ja (laut Hersteller) | ja | GPL-3.0 / gebührenfrei mit Auflagen / kommerziell | technisch möglich, aber kompletter Neubau der Oberfläche und der Waveform-Anbindung; kein Gewinn |
| Flutter | ja | ja | BSD | starke Touch-UI, aber Brücke zur C++-Engine und GPU-Waveforms über Texturen aufwendig; zweite Laufzeit |
| Compose Multiplatform | ja | ja (JVM) | Apache-2.0 | JVM auf dem Desktop, gleiche Brückenprobleme |
| Dear ImGui / eigene GL-Oberfläche | ja | ja | MIT | volle Kontrolle, aber alles selbst (Text, Listen, Barrierefreiheit) |
| Qt Widgets (Mixxx-Skins) | ungeeignet für Touch | ja | wie Qt | nur als Übergang, falls Windows früh etwas zeigen soll |

**Empfehlung:** Qt Quick behalten und `res/qml/AndroidDJ/` zur einzigen Produktoberfläche für beide Plattformen machen. Nötig dafür: Layout nach Fenstergröße statt Gerätetyp, Maus/Tastatur zusätzlich zu Touch, Fenster statt Vollbild.
Risiko: Mixxx’ QML-Schicht ist upstream noch im Umbau; Mischbetrieb Widgets/QML unter Windows und die Renderer-Wahl (OpenGL gegenüber Direct3D über Qt RHI) sind zu prüfen. [nicht geprüft]

---

## 6. Audio-Technologien

| Technik | Android | Windows | Lizenz | Bewertung |
|---|---|---|---|---|
| **PortAudio** (heute) | über Oboe | WASAPI, ASIO, WDM-KS | MIT-artig | **behalten**; ein API für beide |
| Oboe direkt | ja | nein | Apache-2.0 | nur Android, steckt bereits unter PortAudio |
| **Eigener USB-Audio-Treiber** (libusb) | ja, umgeht 70–150 ms Latenz des Android-USB-Pfads (`androidusbaudio.h:20-23`) | nicht nötig, dort leisten ASIO/WASAPI-Exklusiv dasselbe | LGPL (libusb) | **als Android-Spezialweg behalten**, hinter der Audio-Schnittstelle |
| ASIO-SDK | – | ja | Steinberg-Lizenz bzw. GPL-3.0 (so nutzt es OpenDJ) | für niedrige Latenz unter Windows wichtig; mit GPL-3.0-Produkt verträglich [Lizenz im Detail prüfen] |
| cpal (Rust) | ja | ja | Apache-2.0 | nur sinnvoll bei Rust-Engine |
| miniaudio / RtAudio / JUCE | ja | ja | frei / MIT / AGPL-kommerziell | Alternativen ohne Vorteil gegenüber dem Bestand |

**Empfehlung:** PortAudio als gemeinsamer Standardweg, der libusb-Treiber als zusätzlicher Android-Weg; beide hinter einem Routenmodell mit Gerätezustand. Offene Prüfpunkte für Windows: Latenz des FLX4 über WASAPI-Exklusiv und über ASIO, vier Kanäle gleichzeitig, Verhalten beim Abziehen.

---

## 7. Empfohlene Quellstruktur (Zielbild, nicht umgesetzt)

Schrittweise und mit Freigabe je Schritt; hier nur das Ziel:

- `src/product/` – Produktlogik (Schicht 4), plattformneutral.
- `src/platform/{android,windows}/` plus gemeinsame Schnittstellen – Schicht 2/1.
- `res/qml/Product/` (heute `res/qml/AndroidDJ/`) – Schicht 5.
- `packaging/{android,windows}/` – Paketierung, eigene Anwendungs-ID.
- Build-Optionen: ein Schalter `PRODUCT_FLXXX3` (oder ähnlich) statt `__ANDROID__` für Produktverhalten; fester minimaler Optionssatz (ohne VINYLCONTROL, BROADCAST, ENGINEPRIME, LILV, MODPLUG, STEM).
- `CMakePresets.json` mit je einem Preset für Android und Windows, damit der Konfigurationsaufruf im Repo steht.

Bis zur Freigabe bleibt die heutige Struktur unangetastet.

---

## 8. Umgang mit Upstream

- Fork auf einem **Mixxx-Stabilstand** verankern, sobald 2.7 erschienen ist; bis dahin selten und gezielt aktualisieren.
- Eigene Änderungen in thematische Commits trennen (Gruppen A–O in `docs/android-port/CHANGES_INVENTORY.md`).
- Was allgemein nützt, an Mixxx zurückgeben (weniger eigene Last). Was Produktverhalten ist, hinter Schalter.
- Kennzahl zur Kontrolle: Anzahl geänderter Kerndateien außerhalb der Produkt- und Plattformordner (heute dreistellig mit Docs; Ziel: so wenige wie möglich).

---

## 9. Risiken der empfohlenen Architektur

| Risiko | Wahrscheinlichkeit | Gegenmaßnahme |
|---|---|---|
| Upstream ändert QML/Engine stark (2.7 ist alpha) | hoch | Kern-Eingriffe minimieren, Stabilstand abwarten |
| Touch-Oberfläche wirkt am Desktop fremd | mittel | Layout-Varianten, Maus-/Tastaturbedienung früh testen |
| FLX4-Audio unter Windows erfüllt Latenzziel nicht | niedrig–mittel | früh messen (WASAPI-Exklusiv, ASIO) |
| Umbau in Schichten bricht den laufenden Android-Build | mittel | kleine Schritte, nach jedem Schritt Gerätetest, Build-Rezept vorher sichern |
| Lizenzfragen L1/L2 (`LICENSE_AUDIT.md`) bleiben offen | mittel | vor erster Weitergabe klären |
| Abhängigkeit von einer Entwicklungsmaschine | hoch (heute) | Presets, Container/VM-Build, CI |

<!-- Ende KI-generierter Text -->
