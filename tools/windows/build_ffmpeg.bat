@echo off
rem AI disclaimer: this file was written autonomously by an AI agent (Claude).
rem
rem Builds FFmpeg for Windows like the Mixxx dependency package, but with the AAC decoder of
rem FFmpeg instead of libfdk-aac (GPL-incompatible license). The port is the FLXXX3 overlay
rem docs\android-port\build\overlay-ports\ffmpeg (the same as for Android).
rem
rem Needs (once):
rem   git clone https://github.com/mixxxdj/vcpkg.git X:\Dev\FLXXX3-win\vcpkg-src
rem   git -C X:\Dev\FLXXX3-win\vcpkg-src checkout 1c20f84aa1ffca2ef18a7d9c6bd7cdd1f5f2e265
rem   copy the overlay port to X:\Dev\FLXXX3-win\vcpkg-src\overlay\ports\ffmpeg
rem
rem Result: X:\Dev\FLXXX3-win\ffmpeg-noaac\x64-windows-release (bin\*.dll, lib\*.lib); copy
rem bin and lib into the dependency package with tools\windows\use_ffmpeg.sh.

setlocal
set WIN=X:\Dev\FLXXX3-win
set VCPKG_DISABLE_METRICS=1
"%WIN%\buildenv\mixxx-deps-2.7-x64-windows-1c20f84a\vcpkg.exe" install ^
  "ffmpeg[core,avcodec,avdevice,avfilter,avformat,swresample,swscale,fedora-ffmpeg-free-safe]:x64-windows-release" ^
  --classic ^
  --vcpkg-root=%WIN%\vcpkg-src ^
  --overlay-ports=%WIN%\vcpkg-src\overlay\ports ^
  --overlay-triplets=%WIN%\vcpkg-src\overlay\triplets ^
  --x-install-root=%WIN%\ffmpeg-noaac ^
  --x-buildtrees-root=%WIN%\ffmpeg-noaac-build ^
  --clean-after-build
exit /b %ERRORLEVEL%
