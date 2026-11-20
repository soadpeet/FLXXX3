#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# Builds the Windows installer of FLXXX3 (run in WSL):
#   1. tools/windows/build.bat            the program (X:\Dev\FLXXX3-win\build)
#   2. tools/windows/stage_windows.py     the folder it installs (X:\Dev\FLXXX3-win\stage\FLXXX3)
#   3. Inno Setup (ISCC.exe)              Releases/v<version>/FLXXX3-v<version>-windows-setup.exe
#
# Needs Inno Setup 7 (https://jrsoftware.org/isinfo.php), by default in
# X:\Dev\FLXXX3-win\tools\InnoSetup (ISCC=... for another place).
# The version comes from packaging/android/AndroidManifest.xml (versionName).
set -euo pipefail

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
ISCC="${ISCC:-/mnt/x/Dev/FLXXX3-win/tools/InnoSetup/ISCC.exe}"
STAGE="/mnt/x/Dev/FLXXX3-win/stage/FLXXX3"

[ -f "$ISCC" ] || { echo "Inno Setup not found: $ISCC" >&2; exit 1; }
VERSION="$(sed -n 's/.*android:versionName="\([^"]*\)".*/\1/p' "$SRC/packaging/android/AndroidManifest.xml")"
[ -n "$VERSION" ] || { echo "no versionName in the Android manifest" >&2; exit 1; }
OUT="$SRC/Releases/v$VERSION"
mkdir -p "$OUT"

if [ "${1:-}" != "--no-build" ]; then
  cmd.exe /c "$(wslpath -w "$SRC/tools/windows/build.bat")"
fi
python3 "$SRC/tools/windows/stage_windows.py"

"$ISCC" /Q "/DAppVersion=$VERSION" "/DStageDir=$(wslpath -w "$STAGE")" "/DOutputDir=$(wslpath -w "$OUT")" \
  "$(wslpath -w "$SRC/packaging/windows/flxxx3.iss")"
echo "Installer: $OUT/FLXXX3-v$VERSION-windows-setup.exe"
