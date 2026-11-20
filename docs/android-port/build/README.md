<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# Android-Build reproduzieren (FLXXX3)

Stand: 2026-11-11, Quellstand `8c99f51a5f` plus uncommittete Änderungen. Dieser Ordner hält das Build-Rezept **im Repo** fest, damit es nicht nur in `~/mixxx-android/` (außerhalb von Git) existiert. Die Dateien hier sind **Kopien/Beschreibungen**; der laufende Build benutzt weiterhin `~/mixxx-android/`.

## Inhalt

| Datei | Zweck |
|---|---|
| `env.sh.example` | Kopie von `~/mixxx-android/env.sh` (Buildenv, SDK, NDK, JDK). Pfade enthalten `/home/biggo` und sind anzupassen. |
| `uname-shim` | Kopie von `~/mixxx-android/shim/uname`; umgeht die WSL-Sperre `CMakeLists.txt:268-276`. |
| `configure.sh` | Konfigurationsaufruf, **rekonstruiert**, nicht neu ausgeführt (siehe Kopf der Datei). |
| `build-options.md` | Tatsächliche CMake-Optionen des Build-Ordners `build-flxxx3` (Stand 2026-11-11). |
| `../build-install.sh` | Bauen, ausrichten, signieren, installieren (`BUILD_DIR`, `OUT_APK` einstellbar). |
| `build-deps-api29.sh` | Baut die Mixxx-Abhängigkeiten (vcpkg, Stand `1c20f84a`, ~90 Pakete inkl. Qt/FFmpeg) für **Android 10 (API 29)** statt API 35; `setup`/`start`/`stop`/`status`, fortsetzbar. Dauer ca. 3 h. |
| `configure-api29.sh` | Konfiguriert den zweiten Build-Ordner `~/mixxx-android/build-flxxx3-api29` mit diesen Abhängigkeiten (`ANDROID_API_LEVEL=29`, `ANDROID_MIN_SDK=29`). |

## Android 10 und neuer (seit 2026-11-19)

Das fertige Mixxx-Paket (`mixxx-deps-2.7-arm64-android-1c20f84a`) ist für API 35 gebaut und nutzt C-Bibliotheksfunktionen von Android 11–15; eine APK damit startet erst ab Android 14 (`ANDROID_MIN_SDK` 34). Für Android 10:

```bash
bash docs/android-port/build/build-deps-api29.sh setup
bash docs/android-port/build/build-deps-api29.sh start      # status / stop, fortsetzbar
bash docs/android-port/build/configure-api29.sh
BUILD_DIR=~/mixxx-android/build-flxxx3-api29 OUT_APK=~/mixxx-android/flx-api29.apk \
    bash docs/android-port/build-install.sh --no-install
```

Zusätzliche Systempakete (Ubuntu 24.04): `libgl1-mesa-dev libdrm-dev libgbm-dev libsm-dev libudev-dev libxrandr-dev nasm python3-venv zip ninja-build libtool autopoint gperf texinfo`.
`setup` legt die FLXXX3-Ports aus `overlay-ports/` über die von Mixxx (jeder ersetzt den gleichnamigen Port ganz):
- `icu`: ohne Zeitzonen-, Währungs-, Sprachnamen- und ähnliche Daten (ICU-Daten 13 statt 33 MB).
- `ffmpeg`: AAC (M4A) mit dem Decoder von FFmpeg selbst statt libfdk-aac, dessen Lizenz nicht GPL-verträglich ist; `setup` streicht `fdk-aac` auch aus `vcpkg.json`. Derselbe Port baut FFmpeg für Windows (`tools/windows/build_ffmpeg.bat`, `use_ffmpeg.sh`).

Nach einem Wechsel der Abhängigkeiten im vorhandenen Build-Ordner die zwischengespeicherten Fundstellen löschen (mit dem uname-Shim im `PATH`): `cmake -U '*FdkAac*' -U '*fdk-aac*' -U 'FFmpeg_*' -U '*PC_FFmpeg*' ~/mixxx-android/build-flxxx3-api29`.

Geprüft: alle 103 Bibliotheken der APK gegen die API-29-Systembibliotheken des NDK (keine fehlenden Funktionen); Test auf dem Tablet (Android 16) mit FLX4.

## Voraussetzungen (geprüft auf der Entwicklungsmaschine, 2026-11-11)

| Teil | Version |
|---|---|
| Host | Windows 11 + WSL2, Ubuntu 24.04, x86_64 |
| CMake | 3.28.3 |
| NDK | 27.2.12479018 (`/usr/lib/android-sdk/ndk/`) |
| Build-Tools / Plattform | 35.0.0 (auch 34.0.0 installiert) / android-35 |
| JDK | 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`); Systemstandard ist 21, daher `env.sh` immer sourcen |
| Gradle | 8.14.3 (Wrapper, läuft `--offline`, benötigt gefüllten Gradle-Cache) |
| Buildenv | `mixxx-deps-2.7-arm64-android-1c20f84a`, SHA256 `6786c09f491166352880984842ffa6f554e974f30a3766a2392298444c1be83c`, ca. 15 GB; Qt 6.10.3 |
| Zusatzpaket | `libsm6` (fehlt in `tools/android_buildenv.sh`) |
| Platz | Build-Ordner ca. 9 GB |
| Dauer | Vollbuild ca. 22 min (gemessen), inkrementell deutlich kürzer |

## Vorhandene Umgebung erneut bauen

```bash
# in WSL
cd /mnt/x/Dev/FLXXX3
bash docs/android-port/build-install.sh --no-install     # nur bauen + signieren
bash docs/android-port/build-install.sh                  # zusätzlich per adb installieren
```

Optionale Umgebungsvariablen von `build-install.sh` (Standardwerte = bisheriges Verhalten):
`MIXXX_ANDROID_BASE`, `KEYSTORE`, `KEYSTORE_ALIAS`, `KEYSTORE_PASS`, `BUILD_TOOLS`, `ADB`, `ADB_TARGET` (`ip:port` für WLAN-Debugging).

## Neue Umgebung aufsetzen (noch nicht erprobt)

1. WSL2/Ubuntu 24.04, `sudo apt install libsm6` und die Pakete aus `tools/android_buildenv.sh setup` (JDK 17, Android-cmdline-tools, NDK/SDK-Versionen siehe oben).
2. Ordner `~/mixxx-android/` anlegen, `env.sh.example` als `env.sh` kopieren und Pfade anpassen, `uname-shim` nach `~/mixxx-android/shim/uname` (ausführbar).
3. Buildenv laden und prüfen (Zip von `downloads.mixxx.org`, SHA256 aus `env.sh`).
4. `configure.sh` ausführen (Pfade und Optionen vorher prüfen).
5. Wie oben bauen.

## Bekannte Lücken

- `configure.sh` wurde **nicht** gegen einen frischen Build-Ordner getestet.
- Die Doku (`../CLAUDE.md`) nennt „STEM aus, ohne BROADCAST/VINYLCONTROL/…“, der aktuelle CMake-Cache zeigt diese Optionen **an**. Maßgeblich ist `build-options.md` (gemessen). Ein bewusst reduzierter Optionssatz steht als Aufgabe in `LICENSE_AUDIT.md` (L3).
- Signierung nur mit Debug-Schlüssel. Konzept für Release-Schlüssel: `RELEASE.md`.
- Kein Schlüssel, kein Passwort gehört ins Repo.

<!-- Ende KI-generierter Text -->
