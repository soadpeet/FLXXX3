@ECHO OFF
REM FLXXX3 Windows build (same source tree and branch as the Android version).
REM Usage: build.bat [configure]   - "configure" runs CMake first, otherwise only the build.
REM The source tree is the repository this script lies in (tools\windows\..\..).
REM The work folder (dependencies, tools, build output) is FLXXX3_WIN_DIR, default X:\Dev\FLXXX3-win:
REM   buildenv\mixxx-deps-2.7-x64-windows-1c20f84a   Mixxx dependencies (vcpkg)
REM   tools\cmake-3.31.6-windows-x86_64, tools\ninja.exe
REM Needs Visual Studio 2022 Build Tools (MSVC 14.44, Windows SDK 10.0.22621).
REM AI disclaimer: this file was written autonomously by an AI agent (Claude).

SETLOCAL
IF "%FLXXX3_WIN_DIR%"=="" (SET "W=X:\Dev\FLXXX3-win") ELSE (SET "W=%FLXXX3_WIN_DIR%")
FOR %%I IN ("%~dp0..\..") DO SET "SRC=%%~fI"
SET "BUILD=%W%\build"
SET "MIXXX_VCPKG_ROOT=%W%\buildenv\mixxx-deps-2.7-x64-windows-1c20f84a"
SET "VCPKG_DEFAULT_TRIPLET=x64-windows"
SET "X_VCPKG_APPLOCAL_DEPS_INSTALL=ON"

CALL "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >NUL || EXIT /B 1
SET "PATH=%W%\tools\cmake-3.31.6-windows-x86_64\bin;%W%\tools;%PATH%"

IF /I "%~1"=="configure" (
    cmake -S "%SRC%" -B "%BUILD%" -G Ninja ^
        -DCMAKE_BUILD_TYPE=RelWithDebInfo ^
        -DMIXXX_VCPKG_ROOT="%MIXXX_VCPKG_ROOT%" ^
        -DCMAKE_TOOLCHAIN_FILE="%MIXXX_VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake" ^
        -DVCPKG_TARGET_TRIPLET=x64-windows ^
        -DQML=ON -DPORTMIDI=ON -DWARNINGS_FATAL=OFF ^
        -DSTEM=OFF -DBROADCAST=OFF -DVINYLCONTROL=OFF -DENGINEPRIME=OFF -DLILV=OFF -DMODPLUG=OFF -DBUILD_TESTING=OFF -DBUILD_BENCH=OFF || EXIT /B 1
)
cmake --build "%BUILD%" --parallel 24 -- -k 0 || EXIT /B 1
ENDLOCAL
