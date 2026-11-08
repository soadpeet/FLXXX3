<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# ANDROID_BUILD_ANALYSIS

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha.

## Skript `tools/android_buildenv.sh` (141 Zeilen)
- [CODE] Muss gesourct werden (Zeilen 7-11); Unterbefehle `name`, `setup`.
- [CODE] Nur Host `x86_64` (Z. 30-49). Triplet `arm64-android` → `mixxx-deps-2.7-arm64-android-1c20f84a`; mit `BUILDENV_RELEASE` → `arm64-android-rel` (`...-rel-ee6dc7fe`), SHA256 hartcodiert (Z. 32-43). Download von `downloads.mixxx.org/dependencies/...` (Z. 51).
- [CODE] `ANDROID_API=35`, Build-Tools 35.0.0, NDK `27.2.12479018` (Z. 53-55). `setup` nutzt `sudo apt-get install` (u. a. `openjdk-17-jdk`, `google-android-cmdline-tools-13.0-installer`, `cmake`, `ccache`, `libasound2-dev`) und `sudo sdkmanager` (Z. 68-132); `ANDROID_SDK=/usr/lib/android-sdk` hartcodiert; `JAVA_HOME` per `find /usr/lib/jvm -name 'java-17-openjdk*'`.
- [CODE] Das Skript lädt das Buildenv-Zip nicht selbst; es gibt den cmake-Aufruf aus (`-DCMAKE_TOOLCHAIN_FILE=$MIXXX_VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake -DCMAKE_SYSTEM_NAME=Android`). Ob der Download beim Konfigurieren erfolgt: nicht verifiziert (Block `CMakeLists.txt:~101-110`).

## Android-CMake (`CMakeLists.txt`)
- [CODE] `:57-100` Toolchain: `JAVA_HOME` Pflicht, ABI fix `arm64-v8a`, API 35, STL `c++_shared`, Signierung wenn `QT_ANDROID_KEYSTORE_PATH` gesetzt.
- [CODE] `:2373-2452` `qt_add_executable(mixxx ... MANUAL_FINALIZATION)`, Package `org.mixxx`, Quelle `packaging/android`, Permissions: Netz, `MODIFY_AUDIO_SETTINGS`, `RECORD_AUDIO`, Storage inkl. `MANAGE_EXTERNAL_STORAGE`, `WAKE_LOCK`, `USB_PERMISSION`; `libomp.so` aus hartcodiertem `lib/clang/18/...` (NDK-r27-spezifisch); Target `copy-resource-android` kopiert `res/` nach `android-build/assets`.
- [CODE] Auffälligkeiten: `CMAKE_CXX_FLAGS += -std=c++11 -fPIC` (`:~2430`) im Android-Block (Wirkung nicht geprüft); `CMAKE_CXX_COMPILER` wird nach `project()` gesetzt.
- [CODE] Android-Konditionen: ccache/mold aus (`:1048, :1115`), `GLESv2`+`QT_OPENGL_ES_2` (`:3719`), `OpenSLES android` + `PA_USE_OBOE` (`:3755-3758`), `PORTMIDI` default aus (`:3785`), `controllers/android.cpp` statt `controllerhidreporttabsmanager.cpp` (`:5316-5322`).
- [CODE] Keine `CMakePresets.json`, kein Android-spezifischer Workflow außer Matrix-Eintrag.

## CI
- [CODE] `.github/workflows/build.yml:180-197`: „Android 15 arm64“, `ubuntu-24.04`, Flags `-DBULK=ON -DQT6=ON -DQML=ON -DHID=ON -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_DEFAULT_HOST_TRIPLET=x64-linux-release -DCMAKE_SYSTEM_NAME=Android -DBUILD_TESTING=OFF -DBUILD_BENCH=OFF`. Artefakt `build/android-build/build/outputs/apk/release/*.apk`.
- [CODE] Signierung `build.yml:332-357`: ohne Secrets temporärer Keystore via `keytool` (365 Tage); mit `ANDROID_SIGNING_KEYSTORE_BASE64`/`ANDROID_SIGNING_PASSWORD` echter Keystore. APK via androiddeployqt/Gradle.
- [DOKU] `CONTRIBUTING.md:92` (laut Agent): ~3,4 GB Download / 13 GB Platz.

## Enthält der Build / was nicht
- [CODE] Enthalten: QML-UI, PortAudio+Oboe, HID/Bulk-USB (libusb), `STEM` nur wenn FFmpeg gefunden (nicht verifiziert, ob im Buildenv).
- [CODE] Nicht: PortMidi, Widgets-UI als Start, Tests/Benchmarks (CI), PipeWire/JACK/ALSA.
- **Verifiziert in Etappe 1a (2026-11-05), Buildenv `mixxx-deps-2.7-arm64-android-1c20f84a`:** Qt **6.10.3** (`share/Qt6/Qt6ConfigVersion.cmake`, vcpkg `qtbase_6.10.3_arm64-android`); FFmpeg libavcodec 61.19.100 / libavformat 61.7.100 vorhanden (→ `STEM` ist im Android-Build standardmäßig AN); PortAudio 19.8 + Oboe statisch (`liboboe.a`). Konfiguration lief mit `uname`-Shim bis zum QML-Import-Scan; dort fehlte auf dem Host `libSM.so.6` (Paket `libsm6`, nicht in der apt-Liste von `android_buildenv.sh`) → Skript-Lücke für 24.04, auf der CI-Runner-Image offenbar vorhanden.
- (alt, überholt:) Qt-Version: **nicht verifiziert** (kommt aus externem Buildenv). [WAHRSCHEINLICH] ≥ 6.8, da `qt_add_android_permission`/`QJniArray` genutzt werden (Agentenbefund, nicht selbst gegen Qt-Doku geprüft).

## Eignung Windows 11 + WSL2 + Ubuntu 24.04
- **KORREKTUR (2026-11-05, Etappe 1a):** [CODE] `CMakeLists.txt:268-276` bricht per `FATAL_ERROR` ab, wenn `uname -r` „microsoft“ oder „WSL“ enthält („Building on Windows Subsystem for Linux (WSL) is not supported“). Gilt für alle UNIX-Builds, auch Android-Cross-Compile. Hier real aufgetreten: Kernel `6.18.54.1-microsoft-standard-WSL2`, Konfiguration brach nach Download+SHA256-Check des Buildenv ab. Die ursprüngliche Einschätzung unten („passt“) war falsch, ich hatte diese Sperre in Phase 0 nicht gefunden. Historie: Commits `6a84bdd5db`, `daf25479fb`.
- [CODE] CI nutzt ubuntu-24.04 → apt-Paketsatz plausibel passend. Die Maschine ist Ubuntu 24.04.5 auf WSL2, x86_64 (lokal geprüft). `apt-cache policy`: `google-android-cmdline-tools-13.0-installer` in `noble/multiverse`, `openjdk-17-jdk` in `noble-updates/main`.
- [WAHRSCHEINLICH] Stolpersteine: multiverse muss aktiv sein; `sudo` nötig; `JAVA_HOME`-`find` kann bei mehreren JDKs mehrdeutig sein; Repo muss auf ext4 (nicht `/mnt/c`) liegen (hier der Fall); `adb` zum Gerät aus WSL2 nur über Windows-`adb` oder usbipd [EXPERIMENT].
- Wiki-Vergleich: Wiki-Seite „Compiling dependencies for android“ nicht abrufbar → **nicht verifiziert**. [DOKU] README verweist nur auf das Wiki (Suchtreffer, 2026-11-05).

<!-- Ende KI-generierter Text -->
