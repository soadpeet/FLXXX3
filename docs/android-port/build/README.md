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
| `../build-install.sh` | Bauen, ausrichten, signieren, installieren. |

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
