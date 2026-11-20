<!-- AI disclaimer: this text was written autonomously by an AI agent (Claude). -->
# Automated tests of FLXXX3

Run everything (in WSL): `tools/run_tests.sh` — exit code 0 when all tests pass.

| Part | What | Needs |
|---|---|---|
| `controllers/tst_flx4script.qml` | DDJ-FLX4 mapping: every script function named in `Pioneer-DDJ-FLX4.midi.xml` exists, `init`/`shutdown` run, CUE/LOOP CALL (memory cues, memory loops, loop halve/double), LOAD and INSTANT DOUBLES. The script runs against a stand-in engine (`controllers/mixxxmock.js`) with a test clock. | Only the Windows dependency package (qmltestrunner), no build |
| `src/test/rekordboxfeature_test.cpp` | Rekordbox import with the demo export in `data/rekordbox-demo`: finding `export.pdb`, tracks and paths in the library tables, the device playlist, beat grid and 3-band waveform from the analysis files, a missing analysis file. | The test build `X:\Dev\FLXXX3-win\build-test` (see `tools/run_tests.sh`) |

`tools/run_tests.sh --all` also runs all unit tests of Mixxx. Status 2026-11-20: 1188 of
1229 pass. The 41 others fail because of FLXXX3 behaviour (seek on load, auto gain reference)
or the test environment (image formats, QML skins that FLXXX3 does not ship); not checked
one by one yet.

Not covered yet: memory cues and hot cues from analysis files (the demo tracks have none; a
small export with cues would be needed), the QML interface, audio and MIDI with the device.
