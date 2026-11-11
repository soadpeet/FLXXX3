<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# PROJECT_ASSESSMENT – FLXXX3 (Android-DJ auf Mixxx-Basis)

**Stand:** 2026-11-11, Branch `android-midi`, HEAD `8c99f51a5f`. Reine Bestandsaufnahme: Es wurde **keine** Quelldatei geändert, nichts verschoben, gelöscht oder aktualisiert und **kein Build gestartet**. Einzige neue Datei ist dieses Dokument.

Kennzeichnung: **[geprüft]** = in dieser Sitzung selbst nachgesehen (Dateien, Git, WSL-Umgebung, CMake-Cache). **[Doku]** = aus den vorhandenen Notizen in `docs/android-port/` übernommen, nicht neu geprüft. **[offen]** = unklar oder widersprüchlich.

---

## 1. Kurzfassung

- FLXXX3 ist ein Fork von **Mixxx 2.7.0-alpha** (Basis `bc49961fd3`, 2026-10-30, `origin` = `mixxxdj/mixxx`, eigener Fork `soadpeet/FLXXX3`). [geprüft: `git remote -v`, `git log`]
- Gegenüber der Basis: **141 geänderte Dateien, +16 472 / −796 Zeilen** (ohne `docs/`), 12 Commits „Android edition: …“, dazu 7 uncommittete Dateien. [geprüft: `git diff --shortstat bc49961fd3 HEAD`]
- Das Produkt ist ein Player mit Touch-Oberfläche im Stil des XDJ-RX3 für ein Galaxy S25/Tab A11 mit DDJ-FLX4 und Rekordbox-USB-Stick. [Doku: `docs/android-port/CLAUDE.md`]
- Der Android-Build **läuft**, hängt aber an einer Umgebung **außerhalb des Repos** (`~/mixxx-android/` in WSL), deren Konfigurationsaufruf nirgends vollständig dokumentiert ist. Das ist das größte Reproduzierbarkeitsrisiko (Abschnitt 6).
- **Windows** ist als Ziel im Repo nicht umgesetzt: Die neue Oberfläche wird nur auf Mobilgeräten geladen, alle Eigenentwicklungen sind auf Android zugeschnitten (Abschnitt 8).
- **Lizenz:** Der Code ist GPL (Mixxx GPL-2.0-oder-später) und enthält GPL-Bibliotheken. Ein geschlossenes kommerzielles Produkt ist auf dieser Basis nicht möglich (Abschnitt 7). Keine Rechtsberatung.

---

## 2. Projektstruktur und Build-System

Wurzel `X:\Dev\FLXXX3` (in WSL `/mnt/x/Dev/FLXXX3`): [geprüft]

| Pfad | Inhalt |
|---|---|
| `CMakeLists.txt` | Ein monolithisches Build-Skript (>5 000 Zeilen). Android-Zweige u. a. bei `:57-100` (Toolchain), `:268-276` (WSL-Sperre), `:2373-2452` (Zielpaket `org.mixxx`, Berechtigungen, `copy-resource-android`), `:3719`, `:3752-3758` (GLES, Oboe) [Doku: `ANDROID_BUILD_ANALYSIS.md`] |
| `src/` | C++-Quellen (Engine, Controller, Library, Mixer, Effekte, QML-Anbindung, Waveform, Sound-I/O) |
| `res/` | Ressourcen: `res/qml/` (QML-Oberfläche), `res/controllers/` (JS/XML-Mappings), `res/skins/` |
| `lib/` | Eingebundene Fremdbibliotheken (siehe Abschnitt 5) |
| `packaging/android/` | `AndroidManifest.xml`, Java-Helfer in `src/org/mixxx/`, Icons, USB-Filter |
| `tools/android_buildenv.sh` | Upstream-Skript für die Android-Umgebung (unverändert, siehe Abschnitt 6) |
| `cmake/` | CMake-Module (Find-Skripte) |
| `docs/android-port/` | 19 Notizdateien (≈ 830 Zeilen), darunter `CLAUDE.md` (Projektgedächtnis), `PROGRESS.md`, `CHANGES_INVENTORY.md`, `build-install.sh` |
| `Releases/` | Ausgabeordner für APKs, in `.gitignore` |

Build-System: **CMake + Qt 6.10.3 + vcpkg-basierte Fertig-Umgebung** („Buildenv“ `mixxx-deps-2.7-arm64-android-1c20f84a`, von `downloads.mixxx.org`), Generator Unix Makefiles, Gradle über `androiddeployqt` für die APK. Es gibt kein `CMakePresets.json`. [geprüft: CMake-Cache; Qt-Version laut Doku]

Git: Branches `android-midi` (aktuell, auf Fork gepusht), `android-rekordbox`, `android-touch` (beide noch auf der Basis `bc49961fd3`, also leer), `main`. 54 151 Commits Gesamthistorie (Upstream). [geprüft]

---

## 3. Vorhandene Funktionen und Eigenentwicklungen

Die Gruppen A–O mit Dateilisten stehen in `docs/android-port/CHANGES_INVENTORY.md`. Zusammenfassung mit Größenangaben [geprüft: `wc -l`, `git diff --name-status`]:

| Bereich | Wesentliche Dateien | Umfang |
|---|---|---|
| **Touch-Oberfläche** („eine Ansicht wie der RX3“) | `res/qml/AndroidDJ/` – 18 Dateien, u. a. `MainWindow.qml` (962 Z.), `DeckPanel.qml` (638), `SourceScreen.qml` (681), `AdvancedSettings.qml` (619), `FxPanel.qml` (608), `UtilityMenu.qml` (504); Einstieg `res/qml/main.qml` (lädt auf Mobilgeräten `AndroidDJ.MainWindow`) | ≈ 6 100 Zeilen QML |
| **Browse/Listen** | `res/qml/Library/{BrowseScreen,InfoTrackList,ListStore,SearchKeyboard}.qml` (neu), `res/qml/AdvSettings/` | – |
| **Android-MIDI-Backend** (MidiManager + AMidi) | `src/controllers/midi/androidmidi{controller,enumerator,parser}.{h,cpp}` (≈ 650 Z.), `packaging/android/src/org/mixxx/MidiHelper.java` | ersetzt das fehlende PortMidi |
| **Eigene USB-Audio-Ausgabe** für den FLX4 (libusb, isochron, 4 Kanäle, umgeht den Android-Audiostack) | `src/soundio/androidusbaudio.{h,cpp}`, `packaging/android/src/org/mixxx/UsbAudioHelper.java`, `UsbPermission.java`, `res/xml/usb_device_filter.xml` | **in `CHANGES_INVENTORY.md` noch nicht aufgeführt** (Inventar ist älter als diese Dateien) |
| **Rekordbox-USB-Import** (Stick-Suche unter `/mnt/media_rw`, Beatgrid, Cues, Waveform aus ANLZ-Dateien) | `src/library/rekordbox/rekordboxfeature.{h,cpp}`, `lib/rekordbox-metadata/` (Kaitai), `src/waveform/rekordbox3band.h` | Parser vorhanden in Upstream, Android-Pfad und Waveform-Import eigen |
| **Track-Cache** für Wechseldatenträger | `src/util/androidtrackcache.{h,cpp}` (≈ 300 Z.), Änderungen in `soundsourceproxy.*`, `cachingreaderworker.*` | berührt die Engine |
| **Status/Brücke QML↔Android** | `src/qml/qmlandroidstatusproxy.{h,cpp}` (≈ 490 Z.) | – |
| **Quantize/Startpunkt wie Rekordbox** | `src/engine/enginebuffer.*`, `src/engine/controls/{bpmcontrol,cuecontrol}.*` | greift in Engine-Kern ein |
| **Beat-/Color-FX** | `src/effects/backends/builtin/{beatfxeffects,colorfxeffects}.{h,cpp}` (neu), `echo/flanger/phaser`, `src/engine/effects/engineeffectchain.*` (Bandweiche LOW/MID/HI) | – |
| **Waveform-Anzeige** (3BAND/RGB, RX3-Marker, Loop) | `src/waveform/renderers/…`, `src/qml/qmlwaveform*.{h,cpp}` | – |
| **Render-Fix** (Farbe von Knoten) | `src/rendergraph/scenegraph/backend/basematerial.cpp` | allgemein nützlich, nicht Android-spezifisch |
| **FLX4-Mapping** | `res/controllers/Pioneer-DDJ-FLX4-script.js`, `Pioneer-DDJ-FLX4.midi.xml` | Loop, Sync, FX-LEDs, Tempo-Bereiche |
| **Abschaltungen** | Auto-DJ, Crates, fremde Quellen, Sampler, Mikro/Aux, ReplayGain (nur Android) | per `__ANDROID__`/Konfiguration |

Umfang der Android-Sonderzweige im Code: `__ANDROID__` kommt in **58 Quelldateien** vor (`src/`), in `CMakeLists.txt` 53 Zeilen mit „ANDROID“. [geprüft: grep]

Bekannte Lücken laut Doku: Ordner-Filter OFF/ACTIVE filtert die Liste noch nicht, BROWSE ohne PLAYLIST/FOLDER/HISTORY/GENRE/SEARCH/Sortierung, Beat FX ohne Spiral/Helix/Trans, kein MIDI-Hotplug, Cache-Fenster vor Kopierende, Dateisystem-Dirty-Flag nach hartem Ziehen des Sticks. [Doku: `CHANGES_INVENTORY.md` §3, `CLAUDE.md`]

**Uncommittet** (Stand Sitzungsbeginn): `.gitignore`, `docs/android-port/build-install.sh`, `res/qml/AndroidDJ/{DeckPanel,MainWindow,UtilityMenu}.qml`, `res/skins/LateNight/palemoon/buttons/btn__jump_{backward,forward}.svg`. [geprüft: `git status`]
Auffällig: Für die zwei SVG-Dateien schlägt `git diff` unter Windows mit „Function not implemented / cannot hash“ fehl (Dateisystem-/Zugriffsproblem im Git-Bash-Aufruf). Ursache nicht untersucht. [offen]

---

## 4. Mixxx-Abhängigkeiten und übernommene Komponenten

- **Gesamter Mixxx-Kern wird weiterverwendet:** Engine (`src/engine/`), Mixer (`src/mixer/`), Library/SQLite (`src/library/`), Controller-Framework (`src/controllers/`), Effekte (`src/effects/`), Analyse (`src/analyzer/`), Sound-I/O (`src/soundio/`, PortAudio+Oboe), QML-Schicht (`src/qml/`, `res/qml/`).
- **Eigenentwicklung sitzt als Aufsatz** (neue Dateien, Android-Zweige) **plus Eingriffe in Kerndateien** (Engine-Quantize, CachingReader, Waveform-Renderer, Effektkette, SoundManager). Diese Eingriffe machen künftige Upstream-Merges teurer. Die Doku sieht Upstream-Drift selbst als Risiko 11. [Doku: `RISKS.md`]
- Der Fork liegt auf einem **alpha-Stand** (2.7.0-alpha, Qt-5-Entfernung gerade erst eingearbeitet). Mixxx’ QML-Oberfläche gilt upstream als instabil/wenig touch-tauglich. [Doku: `RISKS.md` #8, #11]
- Referenzprojekt **NauticMixxx** (Fremdprojekt, GPLv3, baut auf Mixxx 2.5.6) wurde analysiert und als Vorlage für die ANLZ-Dekodierung gelesen; die Doku sagt, der Code in `rekordboxfeature.cpp` sei „eigener, kleiner Code“. Ob Code übernommen wurde, habe ich **nicht** geprüft. [Doku: `NAUTICMIXXX_ANALYSIS.md`, `PROGRESS.md` Etappe 7g; offen]

---

## 5. C++-Module, Android-Komponenten, externe Bibliotheken

### Android-spezifische Komponenten
- Java in `packaging/android/src/org/mixxx/`: `MainActivity.java` (27 Z.), `MidiHelper.java` (166), `UsbAudioHelper.java` (85), `UsbPermission.java` (51). [geprüft]
- Manifest: App-Name FLXXX3, Berechtigungen u. a. `MANAGE_EXTERNAL_STORAGE`, `RECORD_AUDIO`, USB. [Doku]
- Native: Oboe/AAudio (über PortAudio), AMidi, libusb (isochron), GLES2.

### Eingebundene Bibliotheken (`lib/`) [geprüft: Verzeichnisliste, Lizenzdateien]
`fidlib` (GPL/LGPL), `hidapi`, `kaitai`, `libshout-idjc` (GPL), `mp3guessenc-0.27.4` (GPL), `portaudio` (MIT-artig), `qm-dsp` (GPL), `rekordbox-metadata` (Kaitai-generiert), `replaygain`, `reverb`, `rigtorp`, `xwax`, `apple`.

### Aus dem vcpkg-Buildenv (Android arm64) [geprüft: `…/installed/arm64-android/share/*/copyright`]
Qt 6.10.3 (174 Qt-Module installiert), FFmpeg (LGPL), libusb (LGPL), Oboe (Apache-2.0), TagLib (LGPL), SoundTouch (LGPL), **Rubber Band (GPL)**, **libkeyfinder (GPL)**, **FFTW3 (GPL)**, Chromaprint (MIT-Basis), Opus, SQLite, PortAudio u. a.

---

## 6. Aktueller Android-Build: Voraussetzungen und Reproduzierbarkeit

### 6.1 Was auf dieser Maschine tatsächlich vorhanden ist [geprüft, nur lesend]

| Komponente | Ist-Zustand |
|---|---|
| Host | Windows 11, WSL2, Ubuntu 24.04 (Nutzer `biggo`), x86_64 |
| Quellcode | Windows `X:\Dev\FLXXX3` = WSL `/mnt/x/Dev/FLXXX3` (`CMAKE_HOME_DIRECTORY`) |
| Buildenv | `~/mixxx-android/buildenv/mixxx-deps-2.7-arm64-android-1c20f84a` (15 GB), SHA256 `6786c09f…be83c` (in `env.sh`) |
| Build-Ordner | `~/mixxx-android/build-flxxx3` (9,2 GB), `Unix Makefiles`, `RelWithDebInfo`, ABI `arm64-v8a`, API 35 |
| Android SDK | `/usr/lib/android-sdk`: NDK **27.2.12479018**, Build-Tools **34.0.0 + 35.0.0**, Plattform **android-35** |
| Java | `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64` (in `env.sh`); System-Standard wäre Java **21** (17 und 21 installiert) |
| CMake | 3.28.3 |
| Zusatzpaket | `libsm6` installiert (fehlt in `tools/android_buildenv.sh`) |
| `uname`-Shim | `~/mixxx-android/shim/uname` meldet Kernel `6.18.54.1-generic` statt `…-microsoft-standard-WSL2`, weil `CMakeLists.txt:268-276` WSL-Builds per `FATAL_ERROR` abweist |
| Signierung | Debug-Keystore, Alias `mixxxdebug`, Passwort-Standard `android` |
| Build-Dauer | letzter Voll-/Inkrementbuild laut `build-flxxx3.time`: 22 min 17 s real |
| Ergebnis | `android-build-release-unsigned.apk` (259 MB) → signiert `~/mixxx-android/flx.apk` (10.11., 22:42) |

### 6.2 Reproduktions-Anleitung (Wiederholung des bestehenden Ablaufs)

Voraussetzung: die oben genannte WSL-Umgebung existiert. Dann **ohne Eingriff in den Quellcode**:

```bash
# in WSL (Ubuntu 24.04)
cd /mnt/x/Dev/FLXXX3
bash docs/android-port/build-install.sh --no-install    # baut + signiert, installiert nicht
# Ergebnis: ~/mixxx-android/flx.apk
# Mit Installation auf das Gerät (adb, ggf. ADB_TARGET=<ip:port> für WLAN):
bash docs/android-port/build-install.sh
```

Was das Skript tut [geprüft: `docs/android-port/build-install.sh`]:
1. `source ~/mixxx-android/env.sh` (setzt `MIXXX_VCPKG_ROOT`, `VCPKG_TARGET_TRIPLET=arm64-android`, `ANDROID_NDK_HOME`, `JAVA_HOME`, …) und `uname`-Shim vor den `PATH`.
2. `cmake --build ~/mixxx-android/build-flxxx3 --target apk -j$(nproc)`.
3. Zusätzlich `gradlew assembleRelease --offline`, weil das `apk`-Target reine QML-Änderungen nicht bemerkt.
4. `zipalign -p 4` und `apksigner sign` mit `/mnt/x/Dev/android-tools/debug.keystore`.
5. Optional `adb install -r`.

Manuelle Kurzform laut Doku (`CLAUDE.md`): `source ~/mixxx-android/env.sh; export PATH=$HOME/mixxx-android/shim:$PATH; cd ~/mixxx-android/build-flxxx3; cmake --build . --target apk -j28`.

### 6.3 Was zu einem Neuaufbau von Grund auf fehlt (Lücken)

Ein Neuaufbau auf einer frischen Maschine ist mit dem Repo allein **nicht** möglich:

1. **Der CMake-Konfigurationsaufruf ist nirgends gespeichert.** Das Konfigurationslog beginnt ohne Kommandozeile. Rekonstruierbar aus dem Cache und `ANDROID_BUILD_ANALYSIS.md`/`.github/workflows/build.yml:180-197` (**nicht erneut ausgeführt, daher unverifiziert**):
   `cmake -S /mnt/x/Dev/FLXXX3 -B ~/mixxx-android/build-flxxx3 -DCMAKE_TOOLCHAIN_FILE=$MIXXX_VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake -DCMAKE_SYSTEM_NAME=Android -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_DEFAULT_HOST_TRIPLET=x64-linux-release -DQT6=ON -DQML=ON -DBULK=ON -DHID=ON -DBUILD_TESTING=OFF -DBUILD_BENCH=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo`
2. **`~/mixxx-android/` liegt außerhalb von Git** (`env.sh`, `shim/uname`, Buildenv-Entpackung, Keystore-Kopie, Skripte). Geht dieses Verzeichnis verloren, fehlt die Rezeptur. `docs/android-port/` sagt, es gebe eine Sicherung unter `~/mixxx-android/backup/`, die liegt ebenfalls dort.
3. **Hartcodierte Pfade im Skript:** `BASE=$HOME/mixxx-android`, Keystore `/mnt/x/Dev/android-tools/debug.keystore` (die Doku nennt an anderer Stelle `~/mixxx-android/debug.keystore`; beide Dateien existieren, Gleichheit nicht geprüft), `BT=/usr/lib/android-sdk/build-tools/35.0.0`. Der Build-Ordner steht in `CMakeCache.txt` mit absolutem Pfad `/home/biggo/...` – ein Umzug des Ordners funktioniert nicht.
4. **Der `uname`-Shim ist eine Umgehung einer bewussten Upstream-Sperre.** Funktioniert, ist aber fragil; Alternative wäre ein nativer Linux-Host oder eine VM.
5. **Setup nicht skriptbar rekonstruiert:** `tools/android_buildenv.sh setup` braucht `sudo`, `multiverse` und scheitert laut Doku an fehlendem `libsm6` auf Ubuntu 24.04. Der Download des Buildenvs (≈ 3,4 GB) passiert beim Konfigurieren.
6. **JDK-Auswahl:** Systemstandard ist Java 21, der Build erwartet 17 (`env.sh`). Wer `env.sh` nicht sourct, nutzt das falsche JDK. Gradle läuft `--offline` und setzt einen gefüllten Gradle-Cache voraus.
7. **[offen] Widerspruch Konfiguration ↔ Doku:** Die Doku sagt „Stems aus (`-DSTEM=OFF`)“ und „Build ohne BROADCAST, VINYLCONTROL, ENGINEPRIME, LILV, HID, BULK, MODPLUG“. Der aktuelle Cache `build-flxxx3/CMakeCache.txt` zeigt dagegen `STEM=ON`, `BROADCAST=ON`, `VINYLCONTROL=ON`, `ENGINEPRIME=ON`, `LILV=ON`, `MODPLUG=ON`, `HID=ON`, `BULK=ON`. Der Build-Ordner stammt vom 9.11. und wurde offenbar mit anderen Optionen neu angelegt (der Mini-Fix in `track.h` macht beides baubar). Welche Optionen das ausgelieferte APK wirklich hat, ist damit nicht eindeutig, bis das geklärt ist.
8. **Signierung nur Debug.** Keine Release-Signierung, keine Versionsnummer-Strategie, Passwort-Standard `android` im Skript.

Der funktionierende Zustand ist damit **eine gepflegte Einzelmaschine**, nicht ein reproduzierbarer Build.

---

## 7. Lizenzen und rechtliche Punkte (keine Rechtsberatung)

- **Mixxx: GPL-2.0-oder-später** (`LICENSE`, `COPYING`). Alle Änderungen am Fork unterliegen derselben Lizenz; bei Weitergabe der APK muss der Quelltext angeboten werden.
- **GPL-Bibliotheken im Build** (Rubber Band, libkeyfinder, FFTW3, QM-DSP, fidlib, libshout-idjc, mp3guessenc): ein proprietäres Closed-Source-Produkt ist ohne Austausch dieser Teile ausgeschlossen. Mit einem lizenzierten Mixxx-Ersatz-Kern wäre es ein anderes Projekt.
- **LGPL-Bibliotheken** (Qt, FFmpeg, libusb, TagLib, SoundTouch): bei statischem Linken auf Android sind austauschbare Relink-Möglichkeiten bzw. die Pflichten der jeweiligen Lizenz zu prüfen; Qt-Lizenzvariante (LGPL/GPL vs. kommerziell) für das Endprodukt klären.
- **Google Play / Stores:** GPL und Store-Nutzungsbedingungen sind ein bekannter Konfliktpunkt; vorab prüfen.
- **Pioneer/AlphaTheta-Bezüge:** Das Rekordbox-Exportformat wird über eine Community-Spezifikation (Kaitai) gelesen; Name „FLXXX3“ und die Anlehnung an das XDJ-RX3-Layout, Gerätenamen (DDJ-FLX4) und Marke „rekordbox“ sind für eine **eigenständige Veröffentlichung** markenrechtlich zu klären (Name, Optik, Nennung).
- **NauticMixxx-Bezug:** Falls Code oder Skin-Teile übernommen wurden, gelten dessen Bedingungen (GPLv3) und Attributionspflichten. Aktuell nicht geprüft; ein GPLv2-**oder-später**-Anteil und GPLv3-Anteile müssen zusammenpassen. [offen]
- **Drittquellen:** `THIRD_PARTY_NOTICES`/Lizenzseite der App gibt es im Repo nicht gesondert für das Produkt (nicht gefunden).

---

## 8. Eignung für das Ziel „eigenständiges Produkt für Android und Windows“

**Positiv**
- Funktionierender, auf realer Hardware getesteter Kern: FLX4 über MIDI + eigenes USB-Audio, Rekordbox-Import, Touch-Oberfläche.
- Mixxx liefert eine ausgereifte Engine, die auch unter Windows lauffähig ist (Upstream baut dort).
- Die Doku-Disziplin ist hoch (19 Dokumente, Quellenlabels).

**Hindernisse**
- **Windows ist kein Teil dieses Stands:** `res/qml/main.qml` lädt die neue Oberfläche nur unter `isMobile`; Rekordbox-Stick-Suche, MIDI-Backend, USB-Audio, Track-Cache und Berechtigungen sind Android-Code (`__ANDROID__`). Für Windows gäbe es Mixxx’ normale Desktop-Oberfläche, nicht die FLXXX3-Ansicht. Ein Windows-Build wurde in diesen Unterlagen nicht gefunden.
- **Keine Trennung von Produkt und Mixxx:** Eingriffe in Engine/Waveform/Effekte ohne Schalter erschweren Upstream-Updates; die Doku schlägt eine Aufteilung in Branches A–O vor, umgesetzt ist sie nicht (nur `android-midi` hat Commits).
- **Build-Wissen sitzt außerhalb des Repos** (Abschnitt 6.3), Debug-Signierung.
- **GPL-Bindung** (Abschnitt 7) bestimmt das Geschäftsmodell.
- **Alpha-Basis** Mixxx 2.7.0 und Qt 6.10 (sehr neu); QML-Oberfläche upstream als unfertig.
- **Tests:** `BUILD_TESTING=OFF`; keine automatischen Tests für die Eigenentwicklungen gefunden. Abnahme erfolgt per Gerät und Nutzerbestätigung.

---

## 9. Empfohlene nächste Schritte (nichts davon ist ausgeführt – wartet auf Freigabe)

Reihenfolge nach Risiko/Nutzen, jeweils ohne den laufenden Build zu verändern:

1. **Build-Rezept sichern:** `env.sh`, `uname`-Shim, den tatsächlichen `cmake`-Konfigurationsaufruf und eine Toolchain-Versionsliste (NDK, Build-Tools, JDK, CMake, Buildenv-Hash) als neue Dateien in `docs/android-port/build/` ablegen (reine Kopien/Neuanlage, Originale bleiben).
2. **Widerspruch Abschnitt 6.3 Nr. 7 klären:** Mit `cmake -L` bzw. dem Inhalt der installierten APK feststellen, welche Optionen wirklich aktiv sind (lesend).
3. **Sicherung** der WSL-Umgebung (`~/mixxx-android`) und des Keystores außerhalb des Rechners.
4. **Uncommittete Änderungen** nach den Regeln in `AGENTS.md` (Freigabe pro Commit) sichern; das SVG-Problem prüfen.
5. **Lizenz- und Markenklärung** vor jeder Weitergabe (Abschnitt 7).
6. **Windows-Machbarkeitsstudie:** Desktop-Build von Mixxx 2.7 auf Windows testen und die Android-spezifischen Teile in Plattformmodule trennen (Konzept, kein Umbau ohne Freigabe).
7. **Branch-Trennung** der Gruppen A–O (siehe `CHANGES_INVENTORY.md` §4), `CHANGES_INVENTORY.md` um die USB-Audio-Dateien ergänzen.
8. **Release-Signierung** und ein reproduzierbarer Container/Skript-Build (Docker/VM mit echtem Linux-Kernel statt Shim).

---

## 10. Nicht geprüft

Kein Build ausgeführt, kein Gerätetest, kein Windows-Build, keine Prüfung der Funktionsbehauptungen aus `PROGRESS.md` (nur die Dateien und Größen), keine Inhaltsprüfung der Lizenztexte über die ersten Zeilen hinaus, keine Prüfung, ob `~/mixxx-android/debug.keystore` und `/mnt/x/Dev/android-tools/debug.keystore` identisch sind, kein Abgleich der Qt-Version mit dem Quellcode (Angabe aus `ANDROID_BUILD_ANALYSIS.md`).

<!-- Ende KI-generierter Text -->
