#!/usr/bin/env bash
# KI-Disclaimer: Dieses Skript wurde von einem KI-Agenten (Claude) geschrieben.
# Baut die Android-APK, richtet sie aus, signiert sie (debug.keystore) und installiert sie per adb.
# Aufruf:  bash build-install.sh [--no-install]
# Optional: KEYSTORE_PASS=... (Standard: "android"), ADB_TARGET=<ip:port> fuer WLAN-Debugging.
set -euo pipefail

# Alle Werte koennen per Umgebungsvariable ueberschrieben werden; die Standardwerte
# entsprechen dem bisherigen Verhalten (siehe docs/android-port/build/README.md).
BASE="${MIXXX_ANDROID_BASE:-$HOME/mixxx-android}"
BUILD="${BUILD_DIR:-$BASE/build-flxxx3}"
KEYSTORE="${KEYSTORE:-/mnt/x/Dev/android-tools/debug.keystore}"
ALIAS="${KEYSTORE_ALIAS:-mixxxdebug}"
PASS="${KEYSTORE_PASS:-android}"
BT="${BUILD_TOOLS:-/usr/lib/android-sdk/build-tools/35.0.0}"
ADB="${ADB:-/usr/lib/android-sdk/platform-tools/adb}"

# shellcheck disable=SC1091
source "$BASE/env.sh"
export PATH="$BASE/shim:$PATH"   # uname-Shim wegen WSL-Sperre (CMakeLists.txt:268-276)

cmake --build "$BUILD" --target apk -j"$(nproc)"
# A change in QML files only is copied into the assets, but the apk target does not notice
# it and keeps the old APK: run gradle once more (a no-op when nothing changed).
( cd "$BUILD/android-build" && ANDROID_SDK_ROOT="$ANDROID_SDK" ./gradlew assembleRelease --offline -q )

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
