@echo off
rem AI disclaimer: this file was written autonomously by an AI agent (Claude).
rem
rem Runs the QML/JavaScript tests of FLXXX3 (tests\flxxx3, every tst_*.qml) with the
rem qmltestrunner of the Windows dependency package, without a window.
rem   run_qml_tests.bat [folder or tst_file.qml] [result file]
rem Usually called by tools/run_tests.sh. Exit code 0 when all tests pass.
setlocal
if "%FLXXX3_WIN_DIR%"=="" (set "W=X:\Dev\FLXXX3-win") else (set "W=%FLXXX3_WIN_DIR%")
for %%I in ("%~dp0..\..") do set "SRC=%%~fI"
set "D=%W%\buildenv\mixxx-deps-2.7-x64-windows-1c20f84a\installed\x64-windows"
set "INPUT=%~1"
if "%INPUT%"=="" set "INPUT=%SRC%\tests\flxxx3"
set "RESULT=%~2"
if "%RESULT%"=="" set "RESULT=%W%\qml-test-results.txt"
set "PATH=%D%\bin;%PATH%"
set "QT_PLUGIN_PATH=%D%\Qt6\plugins"
set "QT_QPA_PLATFORM=offscreen"
rem The tests read the mapping files with XMLHttpRequest.
set "QML_XHR_ALLOW_FILE_READ=1"
rem common-controller-scripts.js uses functions before their declaration (allowed in JavaScript).
set "QT_LOGGING_RULES=qt.qml.usedbeforedeclared=false"
"%D%\tools\Qt6\bin\qmltestrunner.exe" -import "%D%\Qt6\qml" -input "%INPUT%" -o "%RESULT%,txt"
exit /b %ERRORLEVEL%
