<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# USB_MIDI_ANALYSIS

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha. (MIDI strikt getrennt von USB-Audio; MIDI-Erkennung sagt nichts über Audio.)

## Mixxx-MIDI-Anbindung
- [CODE] PortMidi: `default_option(PORTMIDI ... "NOT ANDROID")` (`CMakeLists.txt:3785`), `__PORTMIDI__`, Quellen `src/controllers/midi/portmidicontroller.cpp`, `portmidienumerator.cpp`; Registrierung nur `#ifdef __PORTMIDI__` in `src/controllers/controllermanager.cpp:19-20, 173-174`.
- [CODE] Weitere: HSS1394 (macOS), HID (hidapi ≥ 0.14, `CMakeLists.txt:5285-5300`), Bulk (libusb, `:5331`).
- [NICHT UNTERSTÜTZT] Kein RtMidi, kein AMidi im Code (grep `amidi` ohne Treffer). Es gibt keinen MIDI-Backend für Android.
- [CODE] Android-USB-Code nur für HID/Bulk: `src/controllers/android.{h,cpp}` (JNI `org/mixxx/UsbPermission`), `hid/hidenumerator.cpp`, `bulk/bulkenumerator.cpp` mit `__ANDROID__`-Zweigen.
- Folge: Das DDJ-FLX4 (reines MIDI-Controller-Mapping, `.midi.xml`) hat unter Android **keinen Eingabepfad**.

## Nötige Lösung
- [DOKU] Android bietet AMidi ab NDK r20b; Gerätesuche/Öffnen weiterhin über Java `MidiManager`/`MidiDevice`, dann `AMidiDevice_fromJava()`, `AMidiInputPort_open()`/`AMidiOutputPort_open()`; Lesen blockiert nicht (https://developer.android.com/ndk/guides/audio/midi, Abruf 2026-11-05 via Websuche, nur lokalisierte Treffer).
- [WAHRSCHEINLICH] Aufwand: neuer `MidiController`-Nachfolger + `MidiEnumerator` (JNI zu `MidiManager`, USB-Permission analog zu `UsbPermission.java`), Registrierung in `controllermanager.cpp:~173`, SysEx-Pfad (Keep-Alive des FLX4) und Ausgabe (LEDs) mit abdecken. Bestehende Mapping-Engine (`midicontroller.*`, `midioutputhandler.*`, `legacymidicontrollermapping*`) ist wiederverwendbar.
- Alternative [WAHRSCHEINLICH, riskanter]: MIDI via Bulk/libusb selbst parsen (USB-MIDI-Class-Pakete) – umgeht Android-MIDI-Stack, kollidiert aber potenziell mit dem Kernel-Treiber/Audio-Klasse am selben Gerät. [EXPERIMENT]
- [EXPERIMENT] Test auf S25: `adb shell dumpsys midi` bzw. Android-MIDI-Test-App; prüfen, ob FLX4 als MIDI-Gerät erscheint und LED-Rückkanal (Note-On) funktioniert.

<!-- Ende KI-generierter Text -->
