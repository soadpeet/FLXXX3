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
VCPKG_SRC="${FLXXX3_VCPKG_SRC:-$BASE/vcpkg-src}"
TRIPLET=arm64-android-api29
# Same layout as the downloaded Mixxx package: scripts/ (toolchain) and installed/.
DEPS_ROOT="$BASE/buildenv/mixxx-deps-2.7-arm64-android-api29"
# The dependencies in use: FLXXX3_DEPS_WORK if given, otherwise the folder the package root
# points to already (it is switched by hand after a new dependency build), otherwise deps-api29.
if [ -d "$DEPS_ROOT/installed" ] && [ ! -L "$DEPS_ROOT/installed" ]; then
    DEPS_WORK="$DEPS_ROOT" # an unpacked package of pack-deps-api29.sh (GitHub workflow)
elif [ -n "${FLXXX3_DEPS_WORK:-}" ]; then
    DEPS_WORK="$FLXXX3_DEPS_WORK"
elif [ -L "$DEPS_ROOT/installed" ]; then
    DEPS_WORK="$(dirname "$(readlink "$DEPS_ROOT/installed")")"
else
    DEPS_WORK="$BASE/deps-api29"
fi

if [ ! -d "$DEPS_WORK/installed/$TRIPLET/lib" ]; then
    echo "No dependencies for $TRIPLET in $DEPS_WORK/installed (build-deps-api29.sh start)" >&2
    exit 1
fi
if [ -e "$BUILD/CMakeCache.txt" ]; then
    echo "$BUILD is configured already; give a new folder." >&2
    exit 1
fi

if [ "$DEPS_WORK" != "$DEPS_ROOT" ]; then
    mkdir -p "$DEPS_ROOT"
    ln -sfn "$VCPKG_SRC/scripts" "$DEPS_ROOT/scripts"
    ln -sfn "$DEPS_WORK/installed" "$DEPS_ROOT/installed"
    ln -sfn "$VCPKG_SRC/triplets" "$DEPS_ROOT/triplets"
    ln -sfn "$VCPKG_SRC/vcpkg" "$DEPS_ROOT/vcpkg"
    touch "$DEPS_ROOT/.vcpkg-root" # the vcpkg toolchain finds its root by this file
fi

source "$BASE/env.sh"
export MIXXX_VCPKG_ROOT="$DEPS_ROOT"

# Options: CMakePresets.json, preset android-api29 (the same set as the Windows build).
cmake --preset android-api29 -S "$SRC" -B "$BUILD"
