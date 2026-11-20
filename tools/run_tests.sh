#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# Runs the automated tests of FLXXX3 (in WSL; the tests run on Windows):
#   tests/flxxx3/controllers         the DDJ-FLX4 mapping (script and XML) against a stand-in
#                                    engine (qmltestrunner of the Windows Qt, no build needed)
#   src/test/rekordboxfeature_test   the Rekordbox import with the demo export in
#                                    tests/flxxx3/data (mixxx-test.exe of the test build)
#
#   tools/run_tests.sh               both (the C++ part only if the test build exists)
#   tools/run_tests.sh --all         also all unit tests of Mixxx
#   tools/run_tests.sh <tst_*.qml>   one QML test file
#
# The test build (once, then again after changes):
#   cmd.exe /c "set FLXXX3_BUILD_DIR=X:\Dev\FLXXX3-win\build-test&& set FLXXX3_BUILD_TESTING=ON&&
#               X:\Dev\FLXXX3\tools\windows\build.bat configure mixxx-test"
# Exit code 0 when all tests pass.
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
WIN=/mnt/x/Dev/FLXXX3-win
RESULT="$WIN/qml-test-results.txt"
TEST_EXE="$WIN/build-test/mixxx-test.exe"
DEPS_WIN='X:\Dev\FLXXX3-win\buildenv\mixxx-deps-2.7-x64-windows-1c20f84a\installed\x64-windows'

all=0
input=""
case "${1:-}" in
--all) all=1 ;;
"") ;;
*) input="$(wslpath -w "$(realpath "$1")")" ;;
esac

# cmd.exe needs a Windows folder as working directory.
cd /mnt/x || exit 1

echo "=== QML tests (tests/flxxx3)"
rm -f "$RESULT"
cmd.exe /c "$(wslpath -w "$SRC/tools/windows/run_qml_tests.bat")" "$input" "$(wslpath -w "$RESULT")"
status=$?
if [ -f "$RESULT" ]; then
  tr -d '\r' < "$RESULT" | grep -v -E "^PASS   : .*::(initTestCase|cleanupTestCase)\(\)$"
else
  echo "no test results ($RESULT)" >&2
  status=1
fi
[ -n "$input" ] && exit $status

echo
if [ ! -f "$TEST_EXE" ]; then
  echo "=== C++ tests skipped: no $TEST_EXE (see the test build above)"
  exit $status
fi
log="$WIN/mixxx-test.log"
: > "$log"
# The test build folder only holds the DLLs that CMake copies; the plugins of Qt load
# further DLLs (qjpeg.dll needs jpeg62.dll) and QML modules from the dependency package.
run_cpp() {
  (cd "$WIN/build-test" && cmd.exe /c "set QT_PLUGIN_PATH=$DEPS_WIN\\Qt6\\plugins&& set QML_IMPORT_PATH=$DEPS_WIN\\Qt6\\qml&& set PATH=$DEPS_WIN\\bin;%PATH%&& $(wslpath -w "$TEST_EXE") --gtest_filter=$1" >> "$log" 2>&1)
}
filters=("RekordboxFeatureTest.*")
if [ $all -eq 1 ]; then
  # The QML start test and QmlLibraryProxyTest create the whole application
  # (CoreServices); after another instance in the same process they crash, so they run
  # in a process of their own (ctest also runs every test in its own process).
  filters=("*-QmlSkins/QmlStartupSmokeTest.*:QmlLibraryProxyTest.*"
    "QmlLibraryProxyTest.*"
    "QmlSkins/QmlStartupSmokeTest.Starts/LateNightQML"
    "QmlSkins/QmlStartupSmokeTest.Starts/NewUi")
fi
cpp=0
for filter in "${filters[@]}"; do
  echo "=== C++ tests ($filter)"
  start=$(wc -l < "$log")
  run_cpp "$filter" || cpp=1
  tail -n +"$((start + 1))" "$log" | tr -d '\r' \
    | grep -E "^\[ *(OK|FAILED|PASSED|SKIPPED) *\]|^\[==========\]|error:|Expected|Which is" \
    | grep -v -E "^\[ *OK *\]" | grep -v "^\[  FAILED  \] .*, listed below" || true
done
[ $cpp -ne 0 ] && status=1
exit $status
