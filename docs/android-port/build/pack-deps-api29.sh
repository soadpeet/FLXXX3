#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# FLXXX3: packs the Android 10 (API 29) dependencies in use into one file for the GitHub
# workflow (.github/workflows/flxxx3-android.yml), which cannot build them itself (about 3 h on
# the development computer, far longer on a GitHub runner).
#
#   pack-deps-api29.sh [output folder]      default: ~/mixxx-android
#
# Result: flxxx3-deps-2.7-arm64-android-api29-<date>.tar.xz (about 1.2 GB) and its .sha256.
# The file holds the folder mixxx-deps-2.7-arm64-android-api29 in the layout of a Mixxx
# dependency package: installed/ (without the debug libraries and the CMake files that name
# them, share/*/*-debug.cmake), scripts/, triplets/.
# Upload it to a GitHub release of the fork and put its name and SHA256 into the workflow
# (DEPS_FILE, DEPS_SHA256, DEPS_TAG).

set -euo pipefail

BASE="${MIXXX_ANDROID_BASE:-$HOME/mixxx-android}"
OUT_DIR="${1:-$BASE}"
VCPKG_SRC="${FLXXX3_VCPKG_SRC:-$BASE/vcpkg-src}"
NAME=mixxx-deps-2.7-arm64-android-api29
DEPS_ROOT="$BASE/buildenv/$NAME"
TRIPLET=arm64-android-api29

INSTALLED="$(readlink -f "$DEPS_ROOT/installed")"
[ -d "$INSTALLED/$TRIPLET/lib" ] || { echo "no dependencies in $DEPS_ROOT/installed" >&2; exit 1; }
if [ -e "$INSTALLED/$TRIPLET/lib/libfdk-aac.a" ]; then
    echo "$INSTALLED still has libfdk-aac (not GPL compatible): not packed" >&2
    exit 1
fi

FILE="$OUT_DIR/flxxx3-deps-2.7-$TRIPLET-$(date +%Y%m%d).tar.xz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Small parts as copies (the package root on the development computer links to vcpkg-src).
mkdir -p "$TMP/$NAME/triplets"
cp -a "$VCPKG_SRC/scripts" "$TMP/$NAME/scripts"
cp -a "$VCPKG_SRC/triplets/." "$TMP/$NAME/triplets/"
cp -a "$VCPKG_SRC/overlay/triplets/$TRIPLET.cmake" "$TMP/$NAME/triplets/"
touch "$TMP/$NAME/.vcpkg-root"

echo "packing $INSTALLED -> $FILE"
tar -cf - \
    -C "$(dirname "$INSTALLED")" \
    --exclude="installed/$TRIPLET/debug" \
    --exclude="installed/$TRIPLET/share/*-debug.cmake" \
    --transform "s,^installed,$NAME/installed," \
    installed \
    -C "$TMP" "$NAME" \
    | xz -T0 -6 > "$FILE"
(cd "$OUT_DIR" && sha256sum "$(basename "$FILE")" > "$(basename "$FILE").sha256")
ls -l "$FILE"
cat "$FILE.sha256"
