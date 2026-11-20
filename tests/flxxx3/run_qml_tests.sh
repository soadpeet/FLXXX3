#!/usr/bin/env bash
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
#
# Runs the QML/JavaScript tests of FLXXX3 (every tst_*.qml below tests/flxxx3) with a
# qmltestrunner of Qt 6 on Linux, without a window. Used by the GitHub workflow
# .github/workflows/flxxx3-tests.yml; on the development computer tools/run_tests.sh runs
# the same tests with the Windows Qt.
#   QTDIR=<Qt>/6.10.3/gcc_64 tests/flxxx3/run_qml_tests.sh [folder or tst_file.qml]
# Without QTDIR, qmltestrunner is taken from PATH. Exit code 0 when all tests pass.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RUNNER=qmltestrunner
if [ -n "${QTDIR:-}" ]; then
  RUNNER="$QTDIR/bin/qmltestrunner"
fi
export QT_QPA_PLATFORM=offscreen
# The tests read the mapping files with XMLHttpRequest.
export QML_XHR_ALLOW_FILE_READ=1
# common-controller-scripts.js uses functions before their declaration (allowed in JavaScript).
export QT_LOGGING_RULES="qt.qml.usedbeforedeclared=false"
exec "$RUNNER" -input "${1:-$HERE}"
