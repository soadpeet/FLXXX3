<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# LICENSE_AUDIT – Lizenzlage von FLXXX3 und Wege zum eigenständigen Produkt

**Stand:** 2026-11-11, HEAD `8c99f51a5f`. **Keine Rechtsberatung.** Technische Bestandsaufnahme als Vorbereitung für ein Gespräch mit einer Fachperson für Open-Source- und Markenrecht. Es wurde nichts am Projekt geändert.

Kennzeichnung: **[geprüft]** = in dieser Sitzung in Dateien nachgesehen. **[Einschätzung]** = meine Bewertung. **[offen]** = muss geklärt werden.

---

## 1. Ergebnis in Kürze

1. FLXXX3 ist ein **abgeleitetes Werk von Mixxx** und steht damit unter **GPL-2.0-oder-später**. Das gilt für jede geänderte Mixxx-Datei und für neue Dateien, die gegen Mixxx-Interna programmiert sind (alle heutigen Eigenentwicklungen). [Einschätzung]
2. Das aktuell gebaute APK ist durch mitgelinkte Bibliotheken faktisch nur unter **GPL-3.0** verteilbar (xwax ist GPL-3.0-only, libkeyfinder GPL-3.0, libdjinterop LGPL-3.0). [geprüft, Abschnitt 3]
3. Ein **eigenständiges Produkt ist unter der GPL uneingeschränkt möglich**: eigener Name, eigene Marke, eigene Oberfläche, auch Verkauf. Bedingung: Quelltext mitliefern oder anbieten, Urheber- und Lizenzhinweise erhalten, Änderungen kennzeichnen.
4. Ein **geschlossenes (proprietäres) Produkt ist mit dieser Codebasis nicht möglich**. Dafür wäre eine Neuentwicklung ohne Mixxx-Code nötig (siehe `ARCHITECTURE_PROPOSAL.md`, Variante D).
5. Es gibt **zwei konkrete Problemstellen im aktuellen Build**, die vor einer Weitergabe geklärt werden müssen: **fdk-aac** (statisch gelinkt, Lizenz gilt als GPL-unverträglich) und die **EPL-1.0-Angabe** der Rekordbox-Formatbeschreibungen. [geprüft, Abschnitt 4]

---

## 2. Lizenz des Kerns

| Teil | Lizenz | Beleg |
|---|---|---|
| Mixxx-Quelltext | GPL-2.0-oder-später | `LICENSE:1-12`, `COPYING` [geprüft] |
| Skins | teils Creative Commons, je Skin in `skin.xml` | `LICENSE:16-18` [geprüft] |
| Controller-Mappings (`res/controllers/`) | GPL-2.0-oder-später, Autoren im `<info><author>` | Upstream-Konvention; betrifft das geänderte FLX4-Mapping |
| Eigene neue Dateien (`res/qml/AndroidDJ/`, `src/controllers/midi/androidmidi*`, `src/soundio/androidusbaudio.*`, `src/util/androidtrackcache.*`, Java-Helfer) | müssen GPL-2.0-oder-später-verträglich sein, weil sie Teil desselben Programms sind | [Einschätzung] |

Hinweis zur Urheberschaft: Viele neue Dateien tragen den Vermerk, sie seien von einem KI-Agenten geschrieben (z. B. `src/soundio/androidusbaudio.h:5`). Ob und wem an KI-erzeugtem Code Urheberrechte zustehen, ist je nach Rechtsordnung ungeklärt. Für die GPL-Pflichten ändert das nichts; es wäre aber relevant, falls eigene Teile später gesondert (z. B. doppelt) lizenziert werden sollen. [offen]

---

## 3. Bibliotheken im aktuellen Android-Build

Quelle: Link-Zeile `build-flxxx3/CMakeFiles/mixxx.dir/link.txt`, CMake-Cache und `copyright`-Dateien im Buildenv `mixxx-deps-2.7-arm64-android-1c20f84a`. [geprüft]

### Copyleft stark (bestimmen die Lizenz des Ganzen)

| Bibliothek | Lizenz | Einbindung | Abschaltbar |
|---|---|---|---|
| xwax (`lib/xwax/`) | **GPL-3.0-only** (`lib/xwax/timecoder.h:6-8`) | kompiliert, weil `VINYLCONTROL=ON` im Cache | ja, `-DVINYLCONTROL=OFF` (im Produkt ungenutzt) |
| libkeyfinder | **GPL-3.0** (Buildenv `share/libkeyfinder/copyright`) | statisch (`libkeyfinder.a`), `KEYFINDER=ON` | ja, `-DKEYFINDER=OFF` (dann Key-Analyse über QM-DSP) |
| Rubber Band | GPL-2.0-oder-später (kommerzielle Lizenz käuflich) | statisch | ja, `-DRUBBERBAND=OFF` (dann SoundTouch) |
| FFTW3 | GPL-2.0-oder-später | statisch (u. a. für Rubber Band/KeyFinder) | hängt an den beiden oben |
| QM-DSP (`lib/qm-dsp/`) | GPL-2.0-oder-später | immer kompiliert | nein (Beat-/Key-Analyse) |
| fidlib (`lib/fidlib/`) | LGPL-2.1 | kompiliert | nein (Filter) |
| libshout-idjc, mp3guessenc | GPL / LGPL | `BROADCAST=ON` | ja, `-DBROADCAST=OFF` (im Produkt ungenutzt) |
| libmodplug | Public Domain/MIT-artig | `MODPLUG=ON` | ja |

### Copyleft schwach

| Bibliothek | Lizenz | Einbindung |
|---|---|---|
| Qt 6.10.3 (Core, Qml, Quick …) | LGPL-3.0 / GPL (einzelne Module nur GPL) / kommerziell | **dynamisch** (`libQt6Core_arm64-v8a.so` usw.) [geprüft] |
| FFmpeg (libavcodec 61) | LGPL-2.1-oder-später laut `copyright`; Build-Optionen nicht geprüft | statisch |
| libusb, hidapi | LGPL-2.1 / wahlweise BSD-GPL | statisch |
| libdjinterop | **LGPL-3.0** | statisch, `ENGINEPRIME=ON` (im Produkt ungenutzt) |
| TagLib, SoundTouch, libsndfile, libmad (GPL-2.0-oder-später), LAME (LGPL) | wie genannt | statisch |

Statisches Linken von LGPL-Bibliotheken ist hier unkritisch, **solange das Gesamtprodukt GPL bleibt** (Quelltext wird ohnehin offengelegt).

### Freizügig
Oboe (Apache-2.0), PortAudio (MIT-artig), Opus, FLAC/Vorbis (BSD), SQLite (Public Domain), Chromaprint (MIT-Kern), Kaitai-Runtime (`lib/kaitai/LICENSE`, MIT), rigtorp SPSCQueue (MIT), Protobuf (BSD), libomp (Apache-2.0 mit LLVM-Ausnahme).

Apache-2.0 (Oboe) ist mit GPL-3.0 verträglich, mit GPL-2.0-only nicht. Auch deshalb ist **„GPL-3.0-oder-später für das gebaute Produkt“** die saubere Aussage.

---

## 4. Problemstellen, die vor einer Weitergabe zu klären sind

| # | Befund | Warum heikel | Vorschlag (nicht ausgeführt) |
|---|---|---|---|
| L1 | **`libfdk-aac.a` steht in der Link-Zeile** des APK-Builds. [geprüft] | Die FDK-AAC-Lizenz enthält Patent- und Nutzungsklauseln, die die FSF als GPL-unverträglich einstuft. Ein GPL-Binary mit eingelinktem fdk-aac ist deshalb fraglich weiterverteilbar. Ob Mixxx/FFmpeg es hier direkt oder indirekt zieht, habe ich nicht verfolgt. | Herkunft klären (`FindFdkAac.cmake`, FFmpeg-Features im Buildenv); AAC-Dekodierung auf Android über FFmpeg-eigenen Decoder oder den Android-MediaCodec; fdk-aac aus dem Link entfernen. [offen] |
| L2 | `lib/rekordbox-metadata/rekordbox_{pdb,anlz}.ksy` nennen **`license: EPL-1.0`** (`rekordbox_pdb.ksy:7`, `rekordbox_anlz.ksy:8`); daraus ist der C++-Parser generiert. Quelle: Deep-Symmetry/crate-digger. | EPL-1.0 gilt als nicht GPL-verträglich. Upstream-Mixxx liefert das seit Jahren so aus; das Risiko ist geerbt, nicht neu. | Bei Upstream/crate-digger den aktuellen Stand prüfen (crate-digger ist inzwischen EPL-2.0, dort gibt es eine GPL-Sekundärlizenz-Option); alternativ eigener Parser nach der öffentlichen Formatdokumentation. [offen] |
| L3 | Der Cache baut **ungenutzte** Funktionen mit (VINYLCONTROL, BROADCAST, ENGINEPRIME, LILV, MODPLUG, STEM), obwohl die Doku das Gegenteil sagt (`PROJECT_ASSESSMENT.md` §6.3 Nr. 7). | Jede unnötige Bibliothek vergrößert die Pflichtenliste (xwax zwingt zu GPL-3.0-only-Verträglichkeit). | Für das Produkt einen festen, minimalen Optionssatz festlegen. |
| L4 | **Keine Lizenz-/Hinweisseite** in der App und kein `NOTICE`/`THIRD_PARTY`-Verzeichnis für das Produkt. | GPL §1/§2 und LGPL/Apache verlangen sichtbare Hinweise und Lizenztexte. | `NOTICE`-Datei und „About/Licenses“-Ansicht; Quelltext-Angebot (Link auf das Fork-Repo mit dem exakten Commit je Release). |
| L5 | **Paketname `org.mixxx`** und Mixxx-Reste in der App. | Verwechslungsgefahr mit dem Original; „Mixxx“ ist der Name des Upstream-Projekts. | Eigene Anwendungs-ID und klare Abgrenzung („basiert auf Mixxx, nicht mit dem Mixxx-Projekt verbunden“). |
| L6 | **Marken Dritter:** „rekordbox“, „DDJ-FLX4“, „XDJ-RX3“, „Pioneer DJ“ (AlphaTheta). Produktname **FLXXX3** und RX3-nahe Optik. | Beschreibende Nennung („kompatibel mit …“) ist üblich; ein Name, der an fremde Produktnamen anklingt, und nachgeahmte Gestaltung sind ein Abmahnrisiko. | Vor Veröffentlichung Namens- und Designprüfung; Hinweis „nicht verbunden mit AlphaTheta“. [offen] |
| L7 | **NauticMixxx** (GPL-3.0) diente als Vorlage für die ANLZ-Dekodierung (`docs/android-port/PROGRESS.md`, Etappe 7g). | Falls Code übernommen wurde: Attribution nötig, und der betroffene Teil ist GPL-3.0. Die Doku sagt „eigener Code“, das Bitlayout sei dort „gelesen“. | Stelle in `src/library/rekordbox/rekordboxfeature.cpp` gegenprüfen und im `NOTICE` nennen. [offen] |
| L8 | **Patente/Codecs:** AAC (lizenzpflichtige Patente, je nach Vertriebsmodell), MP3 (abgelaufen). | Unabhängig vom Urheberrecht. | Auf Android System-Decoder nutzen. [offen] |

---

## 5. Pflichten bei Weitergabe unter GPL (Checkliste)

1. Vollständiger **korrespondierender Quelltext** zu jedem verteilten Binary, einschließlich Build-Skripten (das spricht zusätzlich dafür, `env.sh`, Shim und Konfigurationsaufruf ins Repo zu nehmen).
2. **Lizenztexte** (GPL-3.0, GPL-2.0, LGPL, Apache-2.0 …) und Urhebervermerke mitliefern.
3. **Änderungen kennzeichnen** (GPL-2.0 §2a / GPL-3.0 §5a): Hinweis, dass und wann geändert wurde.
4. **Keine zusätzlichen Beschränkungen** (kein DRM-Zwang, keine Nutzungsbedingungen, die Weitergabe verbieten).
5. GPL-3.0 §6: bei Geräten für Endverbraucher müssen **Installationsinformationen** für geänderte Versionen möglich sein. Bei frei installierbaren APKs/Windows-Programmen gegeben.
6. **App-Stores:** Google Play und Microsoft Store verbreiten GPL-Programme; Apples Store gilt als problematisch (für die Ziele Android/Windows ohne Belang). Store-Bedingungen im Einzelfall prüfen. [Einschätzung]

Erlaubt bleibt: eigener Name, eigenes Logo, eigener Vertrieb, Preis für Binary oder Support, eigene Marke auf dem Namen.

---

## 6. OpenDJ aus Lizenzsicht

[geprüft am Klon, Commit `052dde7f` vom 2026-11-11: `LICENSE`, `NOTICE`, `Cargo.toml`, `deny.toml`]

- Quelltext **GPL-2.0-oder-später**; gebaute Programme **GPL-3.0** (wegen Slint-GPL-Lizenz, ASIO-SDK unter GPL-3.0, `rbox` GPL-3.0-only) und laut `NOTICE` sogar **AGPL-3.0**, weil Drum-Patterns aus „mpump“ (AGPL-3.0) eingebettet sind.
- **Übernahme von Quelltext nach FLXXX3 ist lizenzrechtlich möglich** (beide GPL-2.0-oder-später), mit Urhebervermerk. Zu meiden: `crates/export` (hängt an `rbox`, GPL-3.0-only), `crates/engine/data/grooves/mpump.txt` (AGPL-3.0), Modellgewichte und `third_party/` nur nach Einzelprüfung.
- Die Mixxx-Mappings in `res/controllers` sind dort unverändert aus Mixxx kopiert (`res/controllers/README.md`), also dieselbe Quelle wie bei FLXXX3.
- Vorbildlich und übernehmenswert als **Verfahren**: `NOTICE` mit Herkunft je Fremdanteil und `cargo-deny` als automatische Lizenzprüfung in der CI (`deny.toml`).

---

## 7. Lizenzstrategien im Vergleich

| Strategie | Machbar | Aufwand | Bemerkung |
|---|---|---|---|
| **S1: Eigenständiges GPL-Produkt** (empfohlen) | ja | gering | Quelltext offen, eigener Name; Einnahmen über Verkauf im Store, Support, Hardware-Bundles möglich. |
| S2: GPL-Kern + proprietäre Zusatzteile im selben Programm | nein | – | Verstößt gegen die GPL, sobald beides ein Programm bildet. Getrennte Programme mit loser Kopplung (z. B. eigenständige Begleit-App über Netzwerkprotokoll) wären denkbar. |
| S3: Mixxx kommerziell lizenzieren | praktisch nein | – | Hunderte Rechteinhaber, kein zentraler Lizenzgeber. |
| S4: Neuentwicklung ohne Mixxx-Code mit freizügigen/kommerziellen Bibliotheken | ja | sehr hoch (Personenjahre) | Einziger Weg zu Closed Source; verliert alles bisher Erreichte. |

**Empfehlung:** S1. Erklärung „Quelltext GPL-2.0-oder-später, gebaute Pakete GPL-3.0-oder-später“, Optionssatz ohne xwax/Broadcast/EnginePrime, L1 und L2 klären, `NOTICE` einführen.

---

## 8. Nicht geprüft

Lizenztexte nur in den Kopfzeilen gelesen; FFmpeg-Konfiguration (`--enable-gpl`/`nonfree`) nicht ermittelt; Qt-Modulliste des APK nicht einzeln gegen „nur GPL“-Module abgeglichen; Windows-Abhängigkeiten (ASIO-SDK, MSVC-Laufzeit, Media Foundation) nur aus `LICENSE:20-34` und OpenDJ-`NOTICE` entnommen; Markenregister nicht recherchiert.

<!-- Ende KI-generierter Text -->
