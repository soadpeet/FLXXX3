#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# FLXXX3 start test (GitHub workflow, Android emulator): installs the APK, starts the app
# without a DDJ-FLX4 and checks that it is still running after WAIT seconds, without a crash
# (Java exception, native signal, missing system function).
#   android_start_test.sh <apk> <output folder>
# The output folder gets logcat.txt, mixxx.log (the app's own log), crash.txt if there is one,
# and screen.png.
# What it does not show: problems of real graphics drivers (Adreno, Mali) and of the FLX4.
set -uo pipefail

APK="$1"
OUT="$2"
PKG=de.biggo.flxxx3
WAIT="${WAIT:-90}"
API="$(adb shell getprop ro.build.version.sdk | tr -d '\r')"
ABIS="$(adb shell getprop ro.product.cpu.abilist | tr -d '\r')"
mkdir -p "$OUT"

fail() {
    adb logcat -d > "$OUT/logcat.txt" 2>/dev/null
    adb exec-out screencap -p > "$OUT/screen.png" 2>/dev/null
    # Lines that explain a crash, as one annotation (tools/ci/annotate_failure.sh).
    grep -E -A12 "FATAL EXCEPTION|Fatal signal|CANNOT LINK|dlopen failed|cannot locate symbol|backtrace:|$PKG.*(died|crash)" \
        "$OUT/logcat.txt" | head -80 > "$OUT/crash-lines.txt"
    [ -s "$OUT/crash-lines.txt" ] || tail -60 "$OUT/logcat.txt" > "$OUT/crash-lines.txt"
    [ -s "$OUT/install.txt" ] && cat "$OUT/install.txt" >> "$OUT/crash-lines.txt"
    bash "$(dirname "$0")/annotate_failure.sh" "Start test API $API ($ABIS): $1" "$OUT/crash-lines.txt"
    exit 1
}

echo "Android API $API, ABI list: $ABIS"
adb install -r --no-incremental "$APK" > "$OUT/install.txt" 2>&1 || fail "install"

# What a user grants on the first start (else the app asks and waits, which is fine too).
adb shell appops set "$PKG" MANAGE_EXTERNAL_STORAGE allow 2>/dev/null || true
adb shell pm grant "$PKG" android.permission.RECORD_AUDIO 2>/dev/null || true

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null || fail "launch"

for i in $(seq 1 "$WAIT"); do
    sleep 1
    if ! adb shell pidof "$PKG" > /dev/null 2>&1; then
        sleep 2 # restarted by the system?
        adb shell pidof "$PKG" > /dev/null 2>&1 || fail "app ended after ${i} s"
    fi
    if adb logcat -d 2>/dev/null | grep -qE "FATAL EXCEPTION|Fatal signal|CANNOT LINK"; then
        fail "crash after ${i} s"
    fi
done

echo "still running after $WAIT s"
adb logcat -d > "$OUT/logcat.txt"
adb exec-out screencap -p > "$OUT/screen.png"
DOCS="/storage/emulated/0/Android/data/$PKG/files/Documents"
adb pull "$DOCS/mixxx.log" "$OUT/mixxx.log" > /dev/null 2>&1 || true
# The app opens crash.txt at the start (the crash handler may only write then); only a
# report in it counts.
if adb pull "$DOCS/crash.txt" "$OUT/crash.txt" > /dev/null 2>&1 && [ -s "$OUT/crash.txt" ]; then
    cp "$OUT/crash.txt" "$OUT/install.txt"
    fail "crash report in crash.txt"
fi
exit 0
