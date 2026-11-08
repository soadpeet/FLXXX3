<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# MIDI_BACKEND_PLAN – Android-MIDI für das DDJ-FLX4

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18` (Arbeitsbranch `android-touch`), 2026-11-05. **Nur Plan, kein Code geschrieben.** Umsetzung erst nach ausdrücklicher Freigabe.

## 1. Ausgangslage
- [EXPERIMENT] Android sieht das FLX4 als MIDI-Gerät (`dumpsys midi`: 1 Eingabe- + 1 Ausgabeport, AlphaTheta, USB 0x2B73:0x45) – siehe `PROGRESS.md`, Etappe 4/5.
- [CODE] Mixxx hat unter Android **keinen** MIDI-Pfad: `PORTMIDI` default aus (`CMakeLists.txt:3785`), `PortMidiEnumerator` nur unter `#ifdef __PORTMIDI__` (`src/controllers/controllermanager.cpp:~173`). Kein AMidi/RtMidi im Code.
- [CODE] Vorhandene Android-USB-Infrastruktur: `src/controllers/android.{h,cpp}` (JNI, `UsbPermission`-Broadcast, wird bei `__ANDROID__` kompiliert, `CMakeLists.txt:5317`) und `packaging/android/src/org/mixxx/{MainActivity,UsbPermission}.java`. Sie ist für HID/Bulk gebaut, nicht für MIDI.
- [CODE] Wiederverwendbar bleibt die komplette MIDI-Logik oberhalb des Transports: `MidiController` (`src/controllers/midi/midicontroller.h`: Mapping, Input-/Output-Handler, Scripting, `receivedShortMessage`, `receive(sysex)`). Nur Transport fehlt.

## 2. Gewählter Ansatz (empfohlen)
**Android `MidiManager` (Java, via JNI) zum Finden/Öffnen + AMidi (NDK, nativ) für den Datenstrom.** Neue Klasse analog zu `PortMidiController`.
- Passt zum Polling-Modell: `ControllerManager` ruft `poll()` alle 5 ms (Android) bzw. 1 ms auf (`controllermanager.cpp:42-44, 395-410`); AMidi-Lesen blockiert nicht [DOKU, Suchtreffer 2026-11-05, lokalisierte Seite developer.android.com/ndk/guides/audio/midi].
- Erkennung, Hotplug-Daten und Namen kommen vom System, ohne dass Mixxx das USB-Gerät selbst belegt (anders als libusb: das Audio-Interface hängt am Kernel-Treiber, vgl. `USB_MIDI_ANALYSIS.md`).

**Verworfene Alternativen**
- *libusb/Bulk-MIDI (vorhandener `BulkEnumerator`):* müsste das USB-MIDI-Streaming selbst parsen und mit dem Audio-Treiber am selben Gerät koexistieren. [WAHRSCHEINLICH] riskanter.
- *Reiner Java-Callback (`MidiReceiver`):* würde auch ohne AMidi gehen und ignoriert die API-Frage unten, passt aber schlechter zum Poll-Modell (Thread-Übergabe nötig). Fallback, falls AMidi nicht nutzbar.
- *PortMidi/RtMidi:* haben keinen Android-Backend im Repo/Buildenv (nicht verifiziert für das Buildenv).

## 3. Änderungen (minimal-invasiv, überwiegend neue Dateien)
| Datei | Art | Inhalt |
|---|---|---|
| `packaging/android/src/org/mixxx/MidiHelper.java` | neu | Hält `MidiManager`; `getDevices()` → Liste (Name, Vendor/Product-ID aus Properties, Portzahlen); `openDevice(info)` asynchron per `MidiManager.OpenDeviceListener`, liefert `MidiDevice` an natives. Kein Eingriff in `MainActivity` nötig. |
| `src/controllers/midi/androidmidicontroller.{h,cpp}` | neu | `AndroidMidiController : MidiController` (wie `PortMidiController`): `open()` → `AMidiDevice_fromJava`, `AMidiOutputPort_open` (Daten *vom* Gerät = Mixxx-Eingang), `AMidiInputPort_open` (Daten *zum* Gerät = Mixxx-Ausgang); `poll()` liest nicht-blockierend; `sendShortMsg()`/`sendBytes()` per `AMidiInputPort_send`; `close()`, `startEngine()/applyMapping()` wie PortMidi-Ablauf (`portmidicontroller.cpp:46-110`); Getter für Vendor/Produkt/Seriennummer aus den Geräte-Properties. |
| `src/controllers/midi/androidmidiparser.{h,cpp}` | neu (klein) | Zerlegt den von AMidi gelieferten Byte-Strom in Short-Messages (Running Status, Realtime `0xF8..`), sammelt SysEx über Paketgrenzen und liefert `receivedShortMessage(...)` / `receive(QByteArray)`. Ersetzt die PmEvent-Logik aus `PortMidiController::poll()` (`:96-185`). Gut als Unit-Test ohne Gerät testbar. |
| `src/controllers/midi/androidmidienumerator.{h,cpp}` | neu | `AndroidMidiEnumerator : MidiEnumerator::queryDevices()`: JNI → `MidiHelper.getDevices()`, je Gerät ein `AndroidMidiController`; Besitz der Controller analog zu `PortMidiEnumerator`. |
| `src/controllers/controllermanager.cpp` | klein | `#ifdef __ANDROID_MIDI__ m_enumerators.push_back(std::make_unique<AndroidMidiEnumerator>());` neben dem PortMidi-Eintrag (`:~173`). |
| `CMakeLists.txt` | klein | Unter `if(ANDROID)` (nahe `:3785`/`:5317`): neue Quellen zu `mixxx-lib`, `target_compile_definitions(mixxx-lib PUBLIC __ANDROID_MIDI__)`, `target_link_libraries(... amidi)`. |
| Tests | neu | `src/test/androidmidiparser_test.cpp` (Running Status, SysEx-Fragmente, Realtime). Läuft nicht im Android-Build (`BUILD_TESTING=OFF` in der CI, Grund: OpenMP), daher nur Host-/Desktop-Test, falls die Parser-Datei ohne Android-Header kompiliert. |

Umfang grob [WAHRSCHEINLICH]: ~400–600 Zeilen C++, ~100 Zeilen Java. Merge-Konflikt-Risiko mit Upstream gering (neue Dateien + zwei kleine Edits).

## 4. Technische Punkte und Risiken
1. **API-Level:** APK hat `minSdkVersion 28` (lokal geprüft mit `aapt dump badging`). AMidi wurde nach meiner Erinnerung erst mit API 29 eingeführt. **Nicht verifiziert** – vor Umsetzung in der NDK-Header-Datei (`.../ndk/27.2.12479018/.../amidi/AMidi.h`, `__INTRODUCED_IN(...)`) nachlesen. Falls 29: Laufzeit-Guard (`android_get_device_api_level() >= 29`) oder `minSdk` anheben (das S25 läuft mit Android 17, praktisch unkritisch); sonst Java-Callback-Fallback.
2. **Port-Exklusivität:** Ein MIDI-Port eines Android-Geräts kann nach meiner Erinnerung nur von einem Client gleichzeitig geöffnet werden. **Nicht verifiziert.** Ein Grund, die Rekordbox-App deaktiviert zu lassen (Absprache siehe Memory).
3. **Berechtigung:** Für `MidiManager`-Geräte erwarte ich keinen USB-Berechtigungsdialog [WAHRSCHEINLICH, nicht verifiziert]. Falls doch nötig, bestehende `UsbPermission`-Logik (`android.cpp`) wiederverwenden.
4. **Kein Hotplug:** `ControllerManager::updateControllerList()` läuft nur beim Start (Kommentar im Code). FLX4 muss vor dem Mixxx-Start angeschlossen sein; Abstecken → Controller bleibt ohne Reaktion. Hotplug wäre ein späteres Thema. Das FLX4 hat sich beim Test mehrfach ab-/angemeldet (siehe `PROGRESS.md`) – Robustheit gegen Verbindungsverlust (kein Absturz in `poll()`/`send`) ist Pflicht.
5. **JNI-Threads:** `AMidiDevice_fromJava` braucht ein `JNIEnv`; Controller läuft im Controller-Thread von Mixxx. `QJniEnvironment` verwenden (hängt Thread an) oder das Öffnen im Main-Thread machen und das native `AMidiDevice*` weiterreichen.
6. **Mapping-Zuordnung:** [CODE] `MidiController::matchMapping()` gibt `false` zurück („Product info mapping not implemented for MIDI devices“, `midicontroller.cpp:99-103`); das FLX4-Mapping hat `<controller id="DDJ-FLX4">` (`res/controllers/Pioneer-DDJ-FLX4.midi.xml`). Wie Mixxx das Mapping einem MIDI-Gerät zuordnet (Name? manuell in den Controller-Einstellungen, `res/qml/Settings/Controller.qml`?), ist **nicht geprüft** und bestimmt, welchen Gerätenamen der neue Controller liefern muss. Vor der Umsetzung `PortMidiEnumerator` und die Mapping-Suche (`controllermanager.cpp`) genauer lesen.
7. **Logging:** Release-Build ignoriert die Start-Argumente (`--log-level`, siehe `PROGRESS.md`), `qDebug` ist daher unsichtbar. Neuer Code loggt wichtige Schritte zusätzlich mit `__android_log_print` (wie `android.cpp`), damit `adb logcat` reicht.
8. **Latenz:** Polling mit 5 ms (`kPollInterval`, `controllermanager.cpp:42`) addiert bis zu 5 ms zur MIDI-Eingabe. Für Fader/Pads vermutlich ok, für Jog (Scratch) ggf. spürbar [EXPERIMENT]; bei Bedarf Android-Poll-Intervall auf 1 ms setzen (kleine Änderung).
9. **FLX4-Eigenheiten:** Das Mapping sendet einen SysEx-Keep-Alive alle 200 ms und eine Start-Abfrage (`Pioneer-DDJ-FLX4-script.js:~174`); `sendBytes()` muss SysEx korrekt (mit `F0`/`F7`) über AMidi senden. [EXPERIMENT] prüfen, ob das FLX4 den Keep-Alive über Android-MIDI akzeptiert (Schaltzustand der Tasten ist ein guter Indikator: im Moment „schwach beleuchtet“, ohne Host-Kommunikation).

## 5. Etappen mit Abnahme (alle am echten Gerät, Rekordbox-App deaktiviert, FLX4 vor dem Start angeschlossen)
| # | Ziel | Abnahme | Abbruch/Alternative |
|---|---|---|---|
| M0 | Vorab-Klärung ohne Code | AMidi-Header: API-Level; Zuordnung Mapping↔Gerät gelesen (Punkte 1, 6) | API 28 nötig → Java-Callback-Variante |
| M1 | Enumerator + Controller-Gerüst | Controller „DDJ-FLX4“ erscheint in Mixxx (Controller-Einstellungen); `adb logcat` zeigt Öffnen der Ports | Öffnen schlägt fehl (Exklusivität) → Rekordbox/andere Clients prüfen |
| M2 | Eingang | Fader/Knob am FLX4 → Log zeigt korrekte CC/Note-Bytes; Mixxx-Control reagiert (z. B. Kanalfader) | Bytes unplausibel → Parser/Port-Zuordnung prüfen |
| M3 | Mapping aktiv | FLX4-Mapping geladen, Play/Cue, Jog-Scratch, Pads, EQ, Crossfader steuern Mixxx | Zuordnung der Mapping-Datei klären (Punkt 6) |
| M4 | Ausgang/LEDs/SysEx | Play-/Cue-LEDs, VU-Meter, Pad-LEDs leuchten; Tasten nicht mehr „schwach“ (Keep-Alive wirkt) | Keep-Alive wird nicht akzeptiert → SysEx-Länge/Timing prüfen |
| M5 | Stabilität | 30 min DJ-Betrieb, einmal Abstecken/Anstecken ohne Absturz; Latenz subjektiv ok | Abstürze → defensiver `poll()`/`send`, ggf. Reconnect-Logik |

## 6. Regeln für die Umsetzung (AGENTS.md)
- Kein `git commit`/`push`/PR durch den Agenten; Änderungen bleiben im Arbeitsverzeichnis des Branches, Review und Test durch den Menschen am echten DJ-Setup.
- KI-erzeugter Code und Text mit Disclaimer (Anfang/Ende); neue Dateien entsprechend kennzeichnen, soweit das Projekt es verlangt.
- Build erst nach Freigabe; neue APK wie bisher signieren und nach `C:\Users\olibi\Downloads` kopieren.

## 7. Offene Fragen vor der Freigabe
1. AMidi-API-Level (M0), `minSdk` anheben ok?
2. Wie wird das Mapping einem MIDI-Gerät zugeordnet (M0)?
3. Soll Hotplug in diesem Schritt mit rein (eher nein, später)?
4. Eigener Branch (z. B. `android-midi`) statt `android-touch`?

<!-- Ende KI-generierter Text -->

## 8. M0-Ergebnisse (2026-11-05, nur gelesen)
- **AMidi-API-Level [CODE]:** In `.../ndk/27.2.12479018/.../sysroot/usr/include/amidi/AMidi.h` sind **alle** benötigten Funktionen `__INTRODUCED_IN(29)` (`AMidiDevice_fromJava`, `AMidiOutputPort_open/receive`, `AMidiInputPort_open/send`, `AMidiDevice_release`). `libamidi.so` liegt im NDK ab API 29 (`.../aarch64-linux-android/<api>/libamidi.so`, z. B. 31/32/35). Unsere APK hat `minSdkVersion 28`. → Entweder `minSdk` auf 29 anheben (S25: Android 17, Tab A11: laut Listings Android 15/16 – beide unkritisch) oder AMidi nur per `dlopen` mit Laufzeit-Guard nutzen. **Empfehlung: minSdk 29**, einfacher; Auswirkung auf das manifest/CMake (`packaging/android/AndroidManifest.xml`, `CMakeLists.txt` Android-Block) noch zu prüfen.
- **Zuordnung Mapping ↔ Gerät [CODE]:** `MidiController::matchMapping()` gibt für MIDI immer `false` zurück (`midicontroller.cpp:99-103`). Mixxx speichert Aktivierung und Mapping **pro Controller-Namen**: `[Controller] <sanitizeDeviceName(name)>` (an/aus) und `kSettingsGroup`-Eintrag mit dem Mapping-Pfad (`controllermanager.cpp:268-330, 455-475`). Beim Start (`slotSetUpDevices`) lädt Mixxx für jedes aktivierte Gerät mit gespeichertem Mapping die Datei und öffnet es (`pController->open(resourcePath)`). Im Sicherheitsmodus wird nicht geöffnet. → Der neue `AndroidMidiController` muss einen **stabilen Namen** liefern (Produktname „DDJ-FLX4“ aus `MidiDeviceInfo`); danach reicht einmaliges Aktivieren + Mapping-Wahl in den Controller-Einstellungen (`res/qml/Settings/Controller.qml`). **Vereinfachung wie bei der Audio-Zuordnung:** beim Start für „DDJ-FLX4“ automatisch aktivieren und `Pioneer-DDJ-FLX4.midi.xml` eintragen (kleine, feste Zuordnung, optional).
- **PortMidi-Paarung [CODE]:** `PortMidiEnumerator::queryDevices()` (`portmidienumerator.cpp:~170-269`) paart getrennte Ein-/Ausgänge nach Namensmustern zu einem Controller. Bei Android liefert `MidiDeviceInfo` Ein- und Ausgabeport desselben Geräts bereits zusammen → diese Paarlogik entfällt.
- **Offen:** Wo liegen die Mapping-Dateien zur Laufzeit auf Android (`res/controllers` im `assets:/`-Pfad, Skript-Ladeweg über Qt-Ressourcen), ob die Script-Engine sie von dort lädt (`controllerscriptenginelegacy.cpp:57` deaktiviert nur das Datei-Watching) – **nicht geprüft**, Teil von M3.
