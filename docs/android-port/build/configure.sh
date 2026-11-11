#!/usr/bin/env bash
# KI-Disclaimer: Dieses Skript wurde autonom von einem KI-Agenten (Claude) geschrieben.
#
# ACHTUNG: REKONSTRUIERT, NICHT AUSGEFUEHRT.
# Der urspruengliche Konfigurationsaufruf von ~/mixxx-android/build-flxxx3 wurde nirgends
# gespeichert. Dieses Skript ist aus CMakeCache.txt (docs/android-port/build/build-options.md)
# und .github/workflows/build.yml:180-197 abgeleitet. Vor dem ersten Einsatz in einem
# NEUEN, leeren Build-Ordner pruefen. Es veraendert keinen bestehenden Build-Ordner,
# solange BUILD auf einen neuen Pfad zeigt.
#
# Aufruf (WSL):  bash docs/android-port/build/configure.sh [neuer-build-ordner]
set -euo pipefail

BASE="${MIXXX_ANDROID_BASE:-$HOME/mixxx-android}"
SRC="${SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
BUILD="${1:-$BASE/build-flxxx3-new}"

if [ -e "$BUILD/CMakeCache.txt" ]; then
  echo "Abbruch: $BUILD ist bereits konfiguriert. Neuen Ordner angeben." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$BASE/env.sh"
export PATH="$BASE/shim:$PATH"   # uname-Shim wegen WSL-Sperre (CMakeLists.txt:268-276)

cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_TOOLCHAIN_FILE="$MIXXX_VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DVCPKG_TARGET_TRIPLET="$VCPKG_TARGET_TRIPLET" \
  -DVCPKG_DEFAULT_HOST_TRIPLET=x64-linux-release \
  -DQT6=ON -DQML=ON -DHID=ON -DBULK=ON \
  -DBUILD_TESTING=OFF -DBUILD_BENCH=OFF
