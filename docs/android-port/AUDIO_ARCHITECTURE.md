<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# AUDIO_ARCHITECTURE

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha.

## Backends
- [CODE] `src/soundio/`: `soundmanager.*`, `sounddevice.*`, `sounddeviceportaudio.*` + `portaudioenumerator.*` (PortAudio), `sounddevicepipewire.*` (nur Linux, Option `PIPEWIRE`, `CMakeLists.txt:3772-3780`), `sounddevicenetwork.*`, `soundmanagerios.mm`.
- [CODE] Android = PortAudio mit Oboe-Hostapi: `find_package(PortAudio REQUIRED)`, `OpenSLES android`, `PA_USE_OBOE` (`CMakeLists.txt:3752-3758`); `cmake/modules/FindPortAudio.cmake:113-123` verlangt `Oboe` und linkt `Oboe::Oboe`. Qt Multimedia nur fürs QML (`CMakeLists.txt:3839`), nicht fürs Audio.
- Header `pa_oboe.h` und PortAudio-/Oboe-Quellen stammen aus dem externen Buildenv, nicht aus dem Repo → Version und Verhalten **nicht verifiziert**. Ob Oboe intern AAudio oder OpenSL ES nimmt: **nicht verifiziert** [WAHRSCHEINLICH AAudio auf API ≥ 27].

## Geräteauswahl unter Android
- [CODE] `PortAudioEnumerator::initialize` (`portaudioenumerator.cpp:52-170`): per JNI `AudioManager.getDevices(INPUTS/OUTPUTS)`, Whitelist der `AudioDeviceInfo`-Typen (u. a. USB-Device/-Headset, Lautsprecher, BT), je Gerät `max(getChannelCounts())` und **nur erste** Samplerate, `PaOboe_RegisterDevice(name, id, direction, channels, rate)`. Setzt `PaOboe_SetNativeBufferSize()` aus `PROPERTY_OUTPUT_FRAMES_PER_BUFFER` und `PaOboe_SetNumberOfBuffers(4)`; pinnt den Thread per `sched_setaffinity` hart auf CPU 4.
- [CODE] Ein bestimmtes Gerät (AudioDeviceInfo-ID) wird also einzeln registriert und ist wählbar. Geräte ohne gemeldete Samplerate werden nicht registriert (`:~100-110`, Agentenbefund).
- [CODE] Stream-Parameter nur Output (`sounddeviceportaudio.cpp:255-275`): `Usage::Media`, `PerformanceMode::LowLatency`, `SharingMode::Exclusive`, `ContentType::Music`. Input: `hostApiSpecificStreamInfo = nullptr`. Keine Nutzereinstellung dafür.
- Direktzugriff auf USB-Audio (libusb/UAC) für Audio: [NICHT UNTERSTÜTZT] im Repo; Audio läuft nur über das Android-Audiosystem. (Die Bulk-/HID-USB-Controller-Pfade betreffen Controller, nicht Audio.)

## Routing Master + Kopfhörer
- [CODE] `AudioPath::AudioPathType`: `Main`, `Headphones`, `Booth`, `Bus`, `Deck`, `VinylControl`, `Microphone`, `Auxiliary`, `RecordBroadcast` (`soundmanagerutil.h:59-69`). Jeder Pfad max. Stereo (`soundmanagerutil.cpp:217-230`); `ChannelGroup(channelBase, count)` erlaubt z. B. Main = Kanal 1-2, Headphones = 3-4 auf demselben Gerät; Überlappung wird per `channelsClash` verhindert.
- [CODE] Konfig: `SoundManagerConfig` (`m_outputs`/`m_inputs` als `QMultiHash<SoundDeviceId, AudioOutput>`), UI Desktop `DlgPrefSound` (Widgets); QML-Pendant `res/qml/Settings/SoundHardware.qml`, `AudioRouter.qml`.
- [CODE] `loadDefaults()` (`soundmanagerconfig.cpp:~521-575`) hat keinen Android-Zweig; Host-API-Konstanten enthalten kein „Oboe“ (`soundmanagerconfig.h:80-89`) → Defaults unter Android müssen in den Prefs gewählt werden. (Agentenbefund, nicht in allen Details nachgelesen.)
- [WAHRSCHEINLICH] Master auf FLX4-Master, Kopfhörer getrennt: im Mixxx-Modell machbar, wenn das Gerät ≥4 Output-Kanäle als ein `AudioDeviceInfo` liefert.
- [EXPERIMENT] Auf dem S25 mit FLX4: `adb shell dumpsys audio` / App-Geräteliste → Kanalzahl; Test: 440-Hz-Ton auf Kanal 1-2 vs. 3-4 hören. Das FLX4-USB-Audioverhalten (Kanalzahl, Klasse) ist nicht belegt: Websuche (2026-11-05) fand nur Händlerangaben „kein Treiber nötig“ am PC/Mac [DOKU, schwach] und eine Erwähnung der Mic-Ausgabe über USB; keine Kanalzahl.

## Latenz
- [CODE] Puffer-Index 1-7 (Default 5 = `Size20xms`); `getFramesPerBuffer()` = `bit_ceil(kHz) << (index-1)` → 48 kHz: 1024 Frames (~21 ms) bei Index 5, 256 bei Index 3 (`soundmanagerconfig.cpp:~413-455`). `kDefaultSyncBuffers = 2` (`:341-343`). `suggestedLatency` = Frames/Rate; Output-Latenz wird in `[App],output_latency_ms` geschrieben (`sounddeviceportaudio.cpp:418-429`).
- [CODE] Android-spezifisch: ADPF-Hint-Session auf dem Main-Thread (`qmlapplication.cpp:363-376`), nicht auf dem Audio-Thread.
- [WAHRSCHEINLICH] Exclusive/LowLatency kann bei USB-Geräten fehlschlagen oder fallen; hartes Core-4-Pinning ist gerätespezifisch (S25-Topologie nicht verifiziert). [EXPERIMENT] Round-Trip-Latenz messen (Loopback), Underruns bei 5/10/20 ms zählen, Thermik über 30 min.
- Wechselwirkung `PaOboe_SetNumberOfBuffers(4)` ↔ Mixxx-Index: nicht verifiziert (gepatchtes PortAudio extern).

<!-- Ende KI-generierter Text -->
