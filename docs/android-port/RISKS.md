<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# RISKS

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha. Bewertungen sind Einschätzungen, nicht bewiesen (keine Hardware getestet).

| # | Risiko | Schwierigkeit | Wahrscheinlichkeit | Workaround / Beleg |
|---|---|---|---|---|
| 1 | USB-MIDI fehlt auf Android | hoch | sicher (kein Backend) [CODE `CMakeLists.txt:3785`, kein AMidi] | Neues AMidi/`MidiManager`-JNI-Backend; Alternative libusb-MIDI |
| 2 | FLX4-Audio-Routing (Master+Kopfhörer, ≥4 Kanäle) | hoch | mittel [EXPERIMENT] | Mixxx-Modell erlaubt es (`soundmanagerutil.cpp:217-230`); Fallback: Master am FLX4, Cue über Phone/Kopfhörer-Dongle; Kanalzahl vorab messen |
| 3 | Android-Audiozugriff/Oboe-Parameter | mittel | mittel | Fester Exclusive/LowLatency (`sounddeviceportaudio.cpp:255-275`), Core-4-Pinning; Parameter konfigurierbar machen |
| 4 | USB-Stick-Zugriff | mittel | mittel | Kein Android-Zweig in `findRekordboxDevices`; `MANAGE_EXTERNAL_STORAGE` vorhanden; Fallback SAF (aufwendig) |
| 5 | Rekordbox-Kompatibilität (OneLibrary, `.DAT`-only-Grid) | mittel | mittel–hoch | Export im Device-Library-Format erzwingen; Fix `rekordboxfeature.cpp:908-911` |
| 6 | Waveform ohne Analyse | gelöst für Rekordbox-Titel mit `.EXT` | war sicher (kein Import im Upstream) | **Gelöst (2026-11-05):** Import aus ANLZ (PWV5/PWV3) in `rekordboxfeature.cpp`, getestet auf S25 (`PROGRESS.md`, Etappe 7g); etwas gröber als die analysierte (150 Spalten/s). Titel ohne `.EXT` fallen auf die Analyse zurück. |
| 7 | Performance/Latenz | hoch | mittel [EXPERIMENT] | Puffer-Index, Loopback-Messung; ADPF-Session nur auf Main-Thread |
| 8 | Touch-GUI (QML „unstable“, wenig Touch) | hoch | hoch | Neue QML-UI auf `QmlControlProxy`/`QmlPlayerProxy`; Knobs akzeptieren nur Mouse/TouchPad (`Knob.qml:143`) |
| 9 | Akku/Temperatur | mittel | mittel [EXPERIMENT] | PD-Hub speist das Phone; Waveform-Rendering/Analyse-Last reduzieren |
| 10 | Build/Buildenv (Qt/FFmpeg unbekannt, `-std=c++11`, NDK-Pfade) | mittel | mittel | Etappe 1a früh ausführen |
| 10a | CMake-Sperre für WSL (`CMakeLists.txt:268-276`) | niedrig–mittel | **eingetreten** | Natives Linux/VM/Docker mit echtem Kernel-Namen; oder lokale Umgehung (Eingriff nötig, Entscheidung offen) |
| 11 | Upstream-Drift / QML-Instabilität | mittel | hoch | Änderungen minimal, eigener Branch |

## Top 5
1 (MIDI), 2 (FLX4-Audio), 6 (Waveform), 4/5 (Stick + Rekordbox-Daten), 8 (Touch-GUI).

<!-- Ende KI-generierter Text -->
