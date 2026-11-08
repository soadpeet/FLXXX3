<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# AUDIO_LATENZ – Messungen und Versuche (Stand 2026-11-07)

**Ziel (KO-Kriterium des Inhabers):** DDJ-FLX4 mit **Kopfhörer-Cue (4 Kanäle)** und **geringer Latenz** (Tablet-Niveau oder besser) auf dem Galaxy S25.

## Messwerte (AudioFlinger, `dumpsys media.audio_flinger`, „Threadloop write latency“)
| Weg | Gerät | Ergebnis |
|---|---|---|
| Mixxx/PortAudio-Oboe, 4 Kanäle, Float, Legacy-Pfad (AAudio „got Legacy, perf = NO“) | S25 (Android 17) | **~148 ms**, HAL-Block 960 Frames |
| derselbe Weg | Tablet SM-X130 (Android 16) | **~67 ms**, HAL-Block 1024 Frames (fühlt sich nach Nutzerangabe latenzfrei an) |
| nur Stereo (Main, Kanäle 1+2) | S25 | AAudio **MMAP, LowLatency, Burst 96 Frames** (~2 ms), aber Cue stumm |
| Rekordbox (JUCE, **OpenSL ES**) | S25 | **DIRECT**-Thread (`AUDIO_OUTPUT_FLAG_DIRECT`), 16 Bit, Quad-Maske 0x33, 48 kHz, HAL-Block 3840, **~31–39 ms**; der Track hat Puffer 7680 Frames, aber **FrmRdy 0** (leer) und viele Underruns (3552) |
| eigener Oboe-Stream (I16, Quad 0x33, 48 kHz) | S25 | DIRECT-Thread wird gewählt; Puffer 1920 → Underruns, Stottern; Puffer 3840–7680 → keine Underruns, aber **350–430 ms** |
| eigener OpenSL-ES-Stream (4 Kanäle, 16 Bit, Quad, BufferQueue mit 2/3/4 Puffern à 1024) | S25 | DIRECT-Thread, aber Track-Puffer **komplett voll** (FrmRdy 7680), Latenz **~270 ms**, unabhängig von der Pufferzahl |

| OpenSL ES **mit Echtzeit-Takt** (Block erst rendern, wenn der Player die vorigen abgespielt hat; Position über `SLPlayItf::GetPosition`), 1–2 Puffer à 1024 | S25 | Track-Puffer hält ~2048 Frames (FrmRdy), Latenz **~110–134 ms**, aber die Underrun-Zähler laufen ständig hoch und der Ton **stottert** (vom Inhaber bestätigt) |

## Erkenntnisse
- Android lehnt MMAP für die FLX4 mit 4 Kanälen ab (Stereo geht). Der Cue kostet also den schnellen Pfad.
- Die DIRECT-Variante hängt an der Fülle des Track-Puffers: Ist er voll, füllt der DIRECT-Thread den HAL-Ring (~270 ms Latenz). Bei Rekordbox ist er leer (Daten kommen just-in-time, DIRECT-Thread schreibt Teilblöcke). Warum Rekordbox das erreicht, wissen wir nicht (JUCE-OpenSL-Code, vermutlich anderes Füllverhalten oder Flags; Track-Flags bei Rekordbox `0x200`, bei uns `0x000`).
- In der eigenen Binärdatei sind `SL_IID_*`-Variablen aus einer statischen Bibliothek definiert (Wert ungültig für das System); die IDs müssen per `dlsym` aus `libOpenSLES.so` geholt werden (siehe `androidopenslout.cpp`).

## Stand im Code
- Das OpenSL-ES-Experiment (`androidopenslout.{h,cpp}`, `openAndroidDirect`, Datei `audio_direct`) wurde **am 2026-11-08 aus dem Code entfernt** (Ergebnis siehe Tabelle: Latenz ~270 ms oder Stottern); der eigene USB-Audiotreiber (`androidusbaudio.*`) hat die Latenz gelöst.
- UTILITY → AUDIO OUTPUT: „FAST, NO CUE“ (Stereo, MMAP) oder „WITH CUE“ (Standard), gilt nach Neustart (`[AndroidDJ] audioStereo`).

- Mit zeitgesteuerter Lieferung (nur CPU-Uhr) wächst der Track-Puffer, weil der DIRECT-Thread erst verzögert zu lesen beginnt; mit Positionsrückkopplung bleibt er bei ~2048, die Positionsauflösung ist aber grob (DIRECT-Thread liest 3840-Frame-Blöcke), und der Ton stottert.
- JUCE-Quelltext (`juce_OpenSL_android.cpp`): 1 Puffer in der Queue, begrenzt den Ausgang auf 2 Kanäle, setzt keinen Performance-Modus. Rekordbox' 4-Kanal-Player ist also kein JUCE-Standardcode, sondern eigener Code des Herstellers.

## Offene Wege
1. Rekordbox-Verhalten genauer nachbauen (JUCE-Quelltext lesen: `juce_OpenSL_android.h`; Puffergrößen, `SL_ANDROID_KEY_PERFORMANCE_MODE`, Anzahl Puffer, Verhalten des Callback-Threads).
2. Eigener USB-Audiotreiber mit libusb (isochron, UAC-Deskriptoren der FLX4 lesen, Alt-Setting, Feedback-Endpoint, 4 Kanäle). Unabhängig von Android-Version und Gerät, aber groß und riskant.
3. Tablet als Hauptgerät benutzen (67 ms), S25 im Stereo-Modus ohne Cue.

## Eigener USB-Treiber (libusb) – 2026-11-07
- `src/soundio/androidusbaudio.{h,cpp}` + `packaging/android/src/org/mixxx/UsbAudioHelper.java` (Berechtigung, Datei-Deskriptor), Einbindung in `sounddeviceportaudio.cpp` (`openAndroidUsb`); aktiv nur mit Datei `/sdcard/Android/data/org.mixxx/files/audio_usb`. Target-SDK 35 (CMake).
- FLX4: Interface 1 (Ausgang), isochron, Endpoint 0x01, 4 Kanäle, 24 Bit (Alt 1, 576 Byte/ms) oder 16 Bit (Alt 2), Rate per UAC1-Control auf dem Endpoint.
- Tablet: läuft (Nutzer: „es funktioniert“), geschätzte Latenz 29 ms (Mixer-Block + 4x2 ms in der USB-Pipeline); beim Start einige Underruns (30 in den ersten 15 s).

<!-- Ende KI-generierter Text -->
