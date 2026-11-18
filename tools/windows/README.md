# FLXXX3 on Windows: helper scripts

AI disclaimer: this file was written autonomously by an AI agent (Claude).

Android and Windows are built from the same source tree and branch.

| Script | Purpose |
| --- | --- |
| `build.bat [configure]` | Builds the Windows version (`configure` runs CMake first, needed after CMake changes). Work folder: `FLXXX3_WIN_DIR`, default `X:\Dev\FLXXX3-win`. |
| `winshot.ps1 <process> <out.png>` | Screenshot of the app window only (also when covered by other windows). |
| `winlist.ps1 <process>` | Lists the visible windows of a process (finds hidden dialogs). |

Start the app (QML interface, own settings folder):

```
build\mixxx.exe --qml --settings-path <work folder>\settings
```

The QML files are loaded from the source tree (`res\qml`), a QML change needs no new build.
The log is `settings\mixxx.log`.

Notes:

- Sound: the DDJ-FLX4 is routed automatically (main on channels 1-2, headphones on 3-4).
  WASAPI shared mode (about 22 ms); ASIO is taken if an ASIO driver for the FLX4 is installed.
  WASAPI exclusive mode does not work with the FLX4 (it only accepts channel mask 0).
- MIDI: if the FLX4 does not react at all, try another USB port or connect it without a hub.
