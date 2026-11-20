#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# Puts the FFmpeg built by tools/windows/build_ffmpeg.bat (AAC decoder of FFmpeg, no
# libfdk-aac) into the Windows dependency package of Mixxx, and moves libfdk-aac out of it.
# Run in WSL, then rebuild: tools/windows/build.bat configure
#
# The replaced files are kept once in $BACKUP (to go back: copy them back).
set -euo pipefail

WIN="${FLXXX3_WIN_DIR:-/mnt/x/Dev/FLXXX3-win}"
NEW="$WIN/ffmpeg-noaac/x64-windows-release"
DEPS="$WIN/buildenv/mixxx-deps-2.7-x64-windows-1c20f84a/installed/x64-windows"
BACKUP="$WIN/buildenv/backup-ffmpeg-fdk-aac"

[ -f "$NEW/bin/avcodec-61.dll" ] || { echo "no FFmpeg in $NEW (run build_ffmpeg.bat)" >&2; exit 1; }

# Files of the package that are replaced or removed.
files=()
for f in avcodec-61 avdevice-61 avfilter-10 avformat-61 avutil-59 swresample-5 swscale-8; do
  files+=("bin/$f.dll" "bin/$f.pdb")
done
for f in avcodec avdevice avfilter avformat avutil swresample swscale; do
  files+=("lib/$f.lib")
done
files+=("share/ffmpeg/vcpkg-cmake-wrapper.cmake")
fdk=("bin/fdk-aac.dll" "bin/fdk-aac.pdb" "lib/fdk-aac.lib" "debug/bin/fdk-aac.dll" "debug/bin/fdk-aac.pdb" "debug/lib/fdk-aac.lib")

if [ ! -d "$BACKUP" ]; then
  for f in "${files[@]}" "${fdk[@]}"; do
    [ -f "$DEPS/$f" ] && install -D -m 644 "$DEPS/$f" "$BACKUP/$f"
  done
  echo "backup: $BACKUP"
fi

for f in "${files[@]}"; do
  [ -f "$NEW/$f" ] && install -D -m 644 "$NEW/$f" "$DEPS/$f"
done
for f in "${fdk[@]}"; do
  rm -f "${DEPS:?}/${f:?}"
done
# The new CMake wrapper no longer asks for libfdk-aac ("if(OFF)" in front of find_package(fdk-aac)).
grep -q "^if(OFF)" "$DEPS/share/ffmpeg/vcpkg-cmake-wrapper.cmake" || { echo "unexpected FFmpeg CMake wrapper" >&2; exit 1; }
echo "FFmpeg without libfdk-aac in $DEPS"
