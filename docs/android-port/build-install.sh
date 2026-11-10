#!/usr/bin/env bash
# KI-Disclaimer: Dieses Skript wurde von einem KI-Agenten (Claude) geschrieben.
# Baut die Android-APK, richtet sie aus, signiert sie (debug.keystore) und installiert sie per adb.
# Aufruf:  bash build-install.sh [--no-install]
# Optional: KEYSTORE_PASS=... (Standard: "android"), ADB_TARGET=<ip:port> fuer WLAN-Debugging.
set -euo pipefail

BASE="$HOME/mixxx-android"
BUILD="$BASE/build-flxxx3"
KEYSTORE="/mnt/x/Dev/android-tools/debug.keystore"
ALIAS="mixxxdebug"
PASS="${KEYSTORE_PASS:-android}"
BT="/usr/lib/android-sdk/build-tools/35.0.0"
ADB="/usr/lib/android-sdk/platform-tools/adb"

# shellcheck disable=SC1091
source "$BASE/env.sh"
export PATH="$BASE/shim:$PATH"   # uname-Shim wegen WSL-Sperre (CMakeLists.txt:268-276)

cmake --build "$BUILD" --target apk -j"$(nproc)"

UNSIGNED="$BUILD/android-build/build/outputs/apk/release/android-build-release-unsigned.apk"
ALIGNED="$BASE/flx-aligned.apk"
SIGNED="$BASE/flx.apk"

rm -f "$ALIGNED" "$SIGNED" "$SIGNED.idsig"
"$BT/zipalign" -f -p 4 "$UNSIGNED" "$ALIGNED"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-key-alias "$ALIAS" \
  --ks-pass "pass:$PASS" --key-pass "pass:$PASS" --out "$SIGNED" "$ALIGNED"
rm -f "$ALIGNED"
echo "Signierte APK: $SIGNED"

if [ "${1:-}" = "--no-install" ]; then exit 0; fi
if [ -n "${ADB_TARGET:-}" ]; then "$ADB" connect "$ADB_TARGET"; fi
"$ADB" install -r "$SIGNED"
