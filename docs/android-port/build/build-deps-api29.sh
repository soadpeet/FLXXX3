#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# FLXXX3: builds the Mixxx dependencies (Qt, FFmpeg, ... ~90 vcpkg ports) for Android 10
# (API 29) instead of API 35, so that the APK runs on Android 10 and newer.
# The prebuilt Mixxx package (mixxx-deps-2.7-arm64-android-1c20f84a) is built for API 35
# and uses C library functions of Android 11-15 (see commit 70108a1d05).
#
# The build can be stopped at any time and continued later: vcpkg keeps every finished
# package in its binary cache (~/.cache/vcpkg/archives), a new "start" only builds what
# is still missing.
#
#   build-deps-api29.sh setup    one time: clone mixxxdj/vcpkg at 1c20f84a, add the triplet
#   build-deps-api29.sh start    build (in the background, log: $WORK/build.log)
#   build-deps-api29.sh stop     stop the build (finished packages stay in the cache)
#   build-deps-api29.sh status   running or not, number of finished packages, last lines
#
# Needs (Ubuntu 24.04, once):
#   sudo apt-get install -y libgl1-mesa-dev libdrm-dev libgbm-dev libsm-dev libudev-dev \
#       libxrandr-dev nasm python3-venv zip ninja-build
# plus the packages the normal Android build needs (Android SDK, NDK 27.2.12479018, JDK 17).

set -euo pipefail

WORK="${FLXXX3_DEPS_WORK:-$HOME/mixxx-android/deps-api29}"
VCPKG="${FLXXX3_VCPKG_SRC:-$HOME/mixxx-android/vcpkg-src}"
VCPKG_COMMIT=1c20f84aa1ffca2ef18a7d9c6bd7cdd1f5f2e265
TRIPLET=arm64-android-api29
HOST_TRIPLET=x64-linux-release
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-/usr/lib/android-sdk/ndk/27.2.12479018}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
PIDFILE="$WORK/build.pid"

setup() {
    mkdir -p "$WORK"
    if [ ! -d "$VCPKG/.git" ]; then
        git clone --filter=blob:none https://github.com/mixxxdj/vcpkg.git "$VCPKG"
    fi
    git -C "$VCPKG" -c advice.detachedHead=false checkout -q "$VCPKG_COMMIT"
    # Same as overlay/triplets/arm64-android.cmake, but API 29.
    sed 's/VCPKG_CMAKE_SYSTEM_VERSION 35/VCPKG_CMAKE_SYSTEM_VERSION 29/; s/ANDROID_API_VERSION 35/ANDROID_API_VERSION 29/' \
        "$VCPKG/overlay/triplets/arm64-android.cmake" > "$VCPKG/overlay/triplets/$TRIPLET.cmake"
    # Sources whose download archives were re-packed by the server after 1c20f84a (same
    # content as the release tag, checked by hand; only the archive hash differs).
    # soundtouch 2.4.0 (codeberg, checked against git tag 2.4.0 on 2026-11-19):
    sed -i 's/8bd199c6363104ba6c9af1abbd3c4da3567ccda5fe3a68298917817fc9312ecb0914609afba1abd864307b0a596becf450bc7073eeec17b1de5a7c5086fbc45e/97e4afcce100f210d89c665dd83f4eaa7b0bec88ba35ba1cf29729e9260d143a5c0f89156646c4dddc83030c5f6b8493c6abc1a82bfba52ed6a87929c8e0fdea/' \
        "$VCPKG/ports/soundtouch/portfile.cmake"
    # FLXXX3 overlay ports (here: ICU with less data, see overlay-ports/icu/portfile.cmake).
    cp -r "$(dirname "$0")/overlay-ports/." "$VCPKG/overlay/ports/"
    if [ ! -x "$VCPKG/vcpkg" ]; then
        (cd "$VCPKG" && ./bootstrap-vcpkg.sh -disableMetrics)
    fi
    echo "setup done: $VCPKG ($VCPKG_COMMIT), triplet $TRIPLET"
}

running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

start() {
    if running; then
        echo "already running (pid $(cat "$PIDFILE"))"
        return
    fi
    [ -x "$VCPKG/vcpkg" ] || setup
    mkdir -p "$WORK"
    echo "=== start $(date -Iseconds)" >> "$WORK/build.log"
    # setsid + nohup: the build goes on when the terminal or the agent session ends.
    (
        cd "$VCPKG"
        export VCPKG_DEFAULT_TRIPLET="$TRIPLET"
        export VCPKG_DEFAULT_HOST_TRIPLET="$HOST_TRIPLET"
        export VCPKG_DISABLE_METRICS=1
        exec setsid nohup ./vcpkg install \
            --vcpkg-root="$VCPKG" \
            --x-install-root="$WORK/installed" \
            --clean-after-build --recurse \
            --feature-flags="-compilertracking,manifests,registries,versions" \
            --x-abi-tools-use-exact-versions \
            >> "$WORK/build.log" 2>&1
    ) &
    echo $! > "$PIDFILE"
    echo "started (pid $(cat "$PIDFILE")), log: $WORK/build.log"
}

stop() {
    if ! running; then
        echo "not running"
        return
    fi
    local pid
    pid="$(cat "$PIDFILE")"
    # The whole process group (vcpkg, cmake, compilers).
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid"
    rm -f "$PIDFILE"
    echo "stopped; finished packages stay in ~/.cache/vcpkg/archives"
}

status() {
    if running; then echo "running (pid $(cat "$PIDFILE"))"; else echo "not running"; fi
    local done=0
    if [ -d "$WORK/installed/vcpkg/info" ]; then
        done=$(ls "$WORK/installed/vcpkg/info" | grep -c "_${TRIPLET}\.list$" || true)
    fi
    echo "installed for $TRIPLET: $done packages"
    [ -f "$WORK/build.log" ] && grep -E "^(Building|Installing|Completed|error|Elapsed)" "$WORK/build.log" | tail -n 5 || true
}

case "${1:-status}" in
setup) setup ;;
start) start ;;
stop) stop ;;
status) status ;;
*) echo "usage: $0 setup|start|stop|status"; exit 1 ;;
esac
