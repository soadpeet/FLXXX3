#!/usr/bin/env python3
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
"""Puts together the folder that the Windows installer of FLXXX3 installs.

Run in WSL after tools/windows/build.bat (the build folder X:\\Dev\\FLXXX3-win\\build):

    python3 tools/windows/stage_windows.py

The result is X:\\Dev\\FLXXX3-win\\stage\\FLXXX3 (made new every time):

    FLXXX3.exe, qt.conf     the program; qt.conf makes Qt find its parts next to it
    *.dll                   only the libraries the program and its plugins load
                            (from the import tables), plus the Visual C++ runtime
    platforms/ styles/ ...  Qt plugins (Qt also looks for them next to the program)
    Qt6/qml/                the QML modules of Qt, without the unused styles
    qml/ controllers/ ...   the resources (res/): only what FLXXX3 uses, like the
                            Android package (cmake/scripts/android_assets.cmake)

Not copied: debug files (.pdb), import libraries (.lib), the libraries of the
build options that are off (STEM, LILV, ...), PostgreSQL and FFmpeg multimedia
plugins of Qt, the Qt Quick styles other than Basic and Fusion. (The QML module
QtMultimedia stays: the Mixxx QML files that are loaded import it.)
"""

import glob
import os
import re
import shutil
import subprocess
import sys

# Defaults: the development computer (WSL). The GitHub workflow (Windows) sets the folders
# with FLXXX3_SRC, FLXXX3_BUILD_DIR, FLXXX3_STAGE, FLXXX3_DEPS_BIN and VC_REDIST.
SRC = os.environ.get("FLXXX3_SRC", "/mnt/x/Dev/FLXXX3")
BUILD = os.environ.get("FLXXX3_BUILD_DIR", "/mnt/x/Dev/FLXXX3-win/build")
STAGE = os.environ.get("FLXXX3_STAGE", "/mnt/x/Dev/FLXXX3-win/stage/FLXXX3")
# Libraries the build folder does not have (some QML modules of Qt need them).
DEPS_BIN = os.environ.get(
    "FLXXX3_DEPS_BIN",
    "/mnt/x/Dev/FLXXX3-win/buildenv/mixxx-deps-2.7-x64-windows-1c20f84a/installed/x64-windows/bin")
VC_REDIST = os.environ.get(
    "VC_REDIST", "/mnt/c/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Redist/MSVC")

# Qt plugin folders next to the program (copied by the build) and what is left out.
PLUGIN_DIRS = ["platforms", "styles", "imageformats", "sqldrivers", "tls", "iconengines"]
PLUGIN_SKIP = re.compile(r"qsqlpsql|qsqlodbc|qsqlmysql|qsqlibase|qsqloci", re.I)

# QML modules of Qt: everything in Qt6/qml except these paths.
QML_SKIP = re.compile(
    r"(^|/)(NativeStyle|designer)(/|$)"
    r"|^QtQuick/Controls/(FluentWinUI3|Imagine|Material|Universal|Windows)(/|$)"
    r"|\.(pdb|lib)$", re.I)

# Resources (res/): the same choice as the Android package.
RES_SKIP_TOP = {"translations", "osx", "linux", "Mixxx-Keyboard-Shortcuts.pdf", "skins",
                "controllers", "mixxx.qrc"}
CONTROLLER_FILES = ["Pioneer-DDJ-FLX4.midi.xml", "Pioneer-DDJ-FLX4-script.js",
                    "Pioneer-DDJ-FLX10.midi.xml", "Pioneer-DDJ-FLX10-scripts.js",
                    "common-controller-scripts.js", "lodash.mixxx.js", "midi-components-0.0.js"]


def pe_imports(path):
    """Names of the DLLs a Windows program or library loads (lower case)."""
    if shutil.which("objdump"):
        out = subprocess.run(["objdump", "-p", path], capture_output=True, text=True).stdout
        return [m.lower() for m in re.findall(r"DLL Name: (\S+)", out)]
    # Windows without binutils: dumpbin of Visual Studio (in the PATH after vcvars64.bat).
    out = subprocess.run(["dumpbin", "/nologo", "/dependents", path],
                         capture_output=True, text=True).stdout
    return [m.lower() for m in re.findall(r"^\s+(\S+\.dll)\s*$", out, re.M | re.I)]


def copy_file(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def main():
    if not os.path.isfile(os.path.join(BUILD, "mixxx.exe")):
        sys.exit("no mixxx.exe in " + BUILD + " (run tools/windows/build.bat first)")
    if os.path.isdir(STAGE):
        shutil.rmtree(STAGE)
    os.makedirs(STAGE)

    # The program.
    copy_file(os.path.join(BUILD, "mixxx.exe"), os.path.join(STAGE, "FLXXX3.exe"))
    with open(os.path.join(STAGE, "qt.conf"), "w", newline="\r\n") as f:
        f.write("[Paths]\nPrefix=.\nPlugins=.\nQml2Imports=Qt6/qml\n")

    # Qt plugins.
    binaries = [os.path.join(STAGE, "FLXXX3.exe")]
    for d in PLUGIN_DIRS:
        for p in glob.glob(os.path.join(BUILD, d, "*.dll")):
            if PLUGIN_SKIP.search(os.path.basename(p)):
                continue
            dst = os.path.join(STAGE, d, os.path.basename(p))
            copy_file(p, dst)
            binaries.append(dst)

    # QML modules of Qt.
    qml_root = os.path.join(BUILD, "Qt6", "qml")
    for dirpath, _dirs, files in os.walk(qml_root):
        for name in files:
            rel = os.path.relpath(os.path.join(dirpath, name), qml_root).replace(os.sep, "/")
            if QML_SKIP.search(rel):
                continue
            dst = os.path.join(STAGE, "Qt6", "qml", rel)
            copy_file(os.path.join(dirpath, name), dst)
            if name.lower().endswith(".dll"):
                binaries.append(dst)

    # Libraries: everything the program and the plugins load, found in the build folder.
    # (Some libraries end in ".DLL".)
    available = {}
    for folder in [DEPS_BIN, BUILD]:  # the build folder wins
        for p in glob.glob(os.path.join(folder, "*")):
            if p.lower().endswith(".dll"):
                available[os.path.basename(p).lower()] = p
    needed = set()
    todo = list(binaries)
    while todo:
        for dll in pe_imports(todo.pop()):
            if dll in available and dll not in needed:
                needed.add(dll)
                dst = os.path.join(STAGE, os.path.basename(available[dll]))
                copy_file(available[dll], dst)
                todo.append(dst)

    # Visual C++ runtime and its OpenMP library next to the program (no separate installation
    # needed).
    for part in ["Microsoft.VC143.CRT", "Microsoft.VC143.OpenMP"]:
        found = sorted(glob.glob(os.path.join(VC_REDIST, "*", "x64", part)))
        if not found:
            sys.exit(part + " not found in " + VC_REDIST)
        for p in glob.glob(os.path.join(found[-1], "*.dll")):
            copy_file(p, os.path.join(STAGE, os.path.basename(p)))

    # Resources.
    res = os.path.join(SRC, "res")
    for entry in os.listdir(res):
        if entry in RES_SKIP_TOP:
            continue
        s = os.path.join(res, entry)
        if os.path.isdir(s):
            shutil.copytree(s, os.path.join(STAGE, entry), symlinks=False)
        else:
            copy_file(s, os.path.join(STAGE, entry))
    # Skins: LateNight (styles for the QML library) and the style sheets; symlinks are copied
    # as files (Windows cannot read the links WSL made).
    shutil.copytree(os.path.join(res, "skins", "LateNight"),
                    os.path.join(STAGE, "skins", "LateNight"), symlinks=False)
    for p in glob.glob(os.path.join(res, "skins", "*.qss")):
        copy_file(p, os.path.join(STAGE, "skins", os.path.basename(p)))
    for name in CONTROLLER_FILES:
        copy_file(os.path.join(res, "controllers", name), os.path.join(STAGE, "controllers", name))

    size = sum(os.path.getsize(os.path.join(d, f)) for d, _s, fs in os.walk(STAGE) for f in fs)
    print("staged %s: %d libraries, %.1f MB" % (STAGE, len(needed), size / 1e6))


if __name__ == "__main__":
    main()
