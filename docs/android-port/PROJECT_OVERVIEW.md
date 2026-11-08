<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# PROJECT_OVERVIEW

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha — [CODE] `CMakeLists.txt:532-534` (kein separates VERSION-File).

## Architektur (Kurz)
- [CODE] Engine/Controls kommunizieren über `ControlObject`/`ControlProxy` (`[Group],key`), laut `AGENTS.md`. `CoreServices` (Engine, Library, Controller, Player) ist UI-unabhängig, UI wird in `src/main.cpp:46-135` gewählt.
- [CODE] Zwei UIs: Widgets (`MixxxMainWindow`, `src/skin/legacy/`, `res/skins/`) und QML (`mixxx::qml::QmlApplication`, `src/qml/qmlapplication.*`, `res/qml/`, `res/skins/LateNightQML/`).

## QML / Android-Bezug
- [CODE] CMake-Option `QML` (`CMakeLists.txt:2356-2366`), `mixxx-qml-lib` (`:3880-4070`); QML-Bindung: `QmlControlProxy` (`src/qml/qmlcontrolproxy.h`), `QmlPlayerProxy`, `QmlTrackProxy`, `QmlLibraryProxy`, `QmlSoundManagerProxy` u. a.
- [CODE] Android startet immer QML: `QT_ANDROID_APPLICATION_ARGUMENTS "--qml --log-level debug --developer"` (`CMakeLists.txt:2395`); Manifest nutzt `--new-ui` (`packaging/android/AndroidManifest.xml`).
- [CODE] `res/qml/main.qml:11-27`: `isMobile`-Zweig (Vollbild). Waveform in QML: `QmlWaveformDisplay` (`src/qml/qmlwaveformdisplay.h:42`), nutzt allshader-Renderer.
- [CODE] QML-Einstellungsseiten u. a. `res/qml/Settings/SoundHardware.qml`, `AudioRouter.qml`, `AudioConnection.qml`, `Controller.qml`.
- [CODE] Touch: Es gibt `TapHandler` (43×), `DragHandler` (4×), `WheelHandler` (3×) in `res/qml` und `LateNightQML`; Knobs/Loop akzeptieren nur `Mouse|TouchPad` (`res/qml/Mixxx/Controls/Knob.qml:143,158`, `res/qml/Deck/Loop.qml:125`). Eine eigens touch-optimierte Deck-Oberfläche: nicht gefunden.
- [CODE] Hinweis auf Instabilität: QML-UI ist als „highly unstable“ gekennzeichnet (Startpfad, `main.cpp`/`cmdlineargs.cpp:292-307`); `QmlApplication` hängt noch an `QApplication` und legt `DlgPreferences` an (`qmlapplication.cpp:236-241`).
- [WAHRSCHEINLICH] Eine neue Touch-QML-UI auf bestehenden Proxies ist machbar, da Engine↔GUI über Controls entkoppelt ist.
- [NICHT UNTERSTÜTZT] Kein `--no-gui`/Headless-Flag in `cmdlineargs.cpp`.

## Wiederverwendung
Engine, Effekte, Beat-/Loop-/Cue-Controls, Library, Controller-Scripting, QML-Proxies: vorhanden. Neu: MIDI-Backend, Android-USB-Stick-Suche, ggf. Touch-UI, Waveform-Strategie. Details: siehe die Fachdokumente.

<!-- Ende KI-generierter Text -->
