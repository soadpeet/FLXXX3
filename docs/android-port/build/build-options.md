<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# Tatsächliche Build-Optionen (gemessen)

Quelle: `~/mixxx-android/build-flxxx3/CMakeCache.txt`, gelesen am 2026-11-11 (lesend, nichts geändert). Quellordner: `/mnt/x/Dev/FLXXX3`. Generator: Unix Makefiles.

| Option | Wert |
|---|---|
| `CMAKE_BUILD_TYPE` | RelWithDebInfo |
| `CMAKE_SYSTEM_NAME` | Android |
| `CMAKE_TOOLCHAIN_FILE` | `<buildenv>/scripts/buildsystems/vcpkg.cmake` |
| `VCPKG_TARGET_TRIPLET` / `VCPKG_DEFAULT_HOST_TRIPLET` | `arm64-android` / `x64-linux-release` |
| `QT_ANDROID_ABIS` | `arm64-v8a` |
| `QT6`, `QML`, `HID`, `BULK` | ON |
| `BUILD_TESTING`, `BUILD_BENCH` | OFF |
| `OPTIMIZE` | portable |
| `PORTMIDI` | OFF (eigenes Android-MIDI-Backend) |
| `FFMPEG`, `STEM`, `KEYFINDER`, `RUBBERBAND`, `OPUS`, `WAVPACK`, `MAD`, `QTKEYCHAIN`, `LOCALECOMPARE` | ON |
| `BROADCAST`, `VINYLCONTROL`, `ENGINEPRIME`, `LILV`, `MODPLUG` | ON |
| `FAAD` | OFF |

Hinweis: Die Option `STEM=ON` und die weiteren ON-Optionen widersprechen älteren Notizen in `../PROGRESS.md`/`../CLAUDE.md`. Im Link des APK stehen u. a. `libfdk-aac.a`, `libkeyfinder.a`, `librubberband.a`, `libdjinterop.a`, `libusb-1.0.a`, `libhidapi-libusb.a` (siehe `/LICENSE_AUDIT.md`).

<!-- Ende KI-generierter Text -->
