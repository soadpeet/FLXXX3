#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# FLXXX3: configures a second Android build folder for Android 10 (API 29), with the
# dependencies built by build-deps-api29.sh. The normal build folder (build-flxxx3, API 35
# dependencies) stays as it is.
#
#   configure-api29.sh [build folder]     default: ~/mixxx-android/build-flxxx3-api29
#
# Then build the APK with:
#   BUILD_DIR=~/mixxx-android/build-flxxx3-api29 bash docs/android-port/build-install.sh --no-install

set -euo pipefail

BASE="${MIXXX_ANDROID_BASE:-$HOME/mixxx-android}"
SRC="${SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
BUILD="${1:-$BASE/build-flxxx3-api29}"
DEPS_WORK="${FLXXX3_DEPS_WORK:-$BASE/deps-api29}"
VCPKG_SRC="${FLXXX3_VCPKG_SRC:-$BASE/vcpkg-src}"
TRIPLET=arm64-android-api29
# Same layout as the downloaded Mixxx package: scripts/ (toolchain) and installed/.
DEPS_ROOT="$BASE/buildenv/mixxx-deps-2.7-arm64-android-api29"

if [ ! -d "$DEPS_WORK/installed/$TRIPLET/lib" ]; then
    echo "No dependencies for $TRIPLET in $DEPS_WORK/installed (build-deps-api29.sh start)" >&2
    exit 1
fi
if [ -e "$BUILD/CMakeCache.txt" ]; then
    echo "$BUILD is configured already; give a new folder." >&2
    exit 1
fi

mkdir -p "$DEPS_ROOT"
ln -sfn "$VCPKG_SRC/scripts" "$DEPS_ROOT/scripts"
ln -sfn "$DEPS_WORK/installed" "$DEPS_ROOT/installed"
ln -sfn "$VCPKG_SRC/triplets" "$DEPS_ROOT/triplets"
ln -sfn "$VCPKG_SRC/vcpkg" "$DEPS_ROOT/vcpkg"
touch "$DEPS_ROOT/.vcpkg-root" # the vcpkg toolchain finds its root by this file

source "$BASE/env.sh"
export MIXXX_VCPKG_ROOT="$DEPS_ROOT"
export VCPKG_TARGET_TRIPLET="$TRIPLET"
export PATH="$BASE/shim:$PATH" # uname shim for WSL (CMakeLists.txt)

cmake -S "$SRC" -B "$BUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$DEPS_ROOT/scripts/buildsystems/vcpkg.cmake" \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DVCPKG_TARGET_TRIPLET="$TRIPLET" \
    -DVCPKG_DEFAULT_HOST_TRIPLET=x64-linux-release \
    -DANDROID_API_LEVEL=29 \
    -DANDROID_MIN_SDK=29 \
    -DQT6=ON -DQML=ON -DHID=ON -DBULK=ON -DPORTMIDI=OFF -DFAAD=OFF \
    -DFFMPEG=ON -DSTEM=ON -DKEYFINDER=ON -DRUBBERBAND=ON -DOPUS=ON -DWAVPACK=ON -DMAD=ON \
    -DQTKEYCHAIN=ON -DLOCALECOMPARE=ON \
    -DBROADCAST=ON -DVINYLCONTROL=ON -DENGINEPRIME=ON -DLILV=ON -DMODPLUG=ON \
    -DBUILD_TESTING=OFF -DBUILD_BENCH=OFF
