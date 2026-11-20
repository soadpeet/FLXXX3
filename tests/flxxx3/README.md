<!-- AI disclaimer: this text was written autonomously by an AI agent (Claude). -->
# Automated tests of FLXXX3

Run everything (in WSL): `tools/run_tests.sh` — exit code 0 when all tests pass.

On GitHub the workflow `.github/workflows/flxxx3-tests.yml` runs the QML tests on every push
(Linux, Qt 6.10.3, `tests/flxxx3/run_qml_tests.sh`) and checks that the mapping XML is
well-formed. The C++ tests need the self-built dependencies and only run locally.

| Part | What | Needs |
|---|---|---|
| `controllers/tst_flx4script.qml` | DDJ-FLX4 mapping: every script function named in `Pioneer-DDJ-FLX4.midi.xml` exists, `init`/`shutdown` run, CUE/LOOP CALL (memory cues, memory loops, loop halve/double), LOAD and INSTANT DOUBLES. The script runs against a stand-in engine (`controllers/mixxxmock.js`) with a test clock. | Only the Windows dependency package (qmltestrunner), no build |
| `src/test/rekordboxfeature_test.cpp` | Rekordbox import with the demo export in `data/rekordbox-demo`: finding `export.pdb`, tracks and paths in the library tables, the device playlist, beat grid and 3-band waveform from the analysis files, a missing analysis file. | The test build `X:\Dev\FLXXX3-win\build-test` (see `tools/run_tests.sh`) |

`tools/run_tests.sh --all` also runs all unit tests of Mixxx. Status 2026-11-20: all 1231
pass (1227) or are skipped on purpose (4), exit code 0. Before, 41 of 1229 failed; every one
was checked:

### Test environment (fixed in `tools/run_tests.sh`)

| Tests | Cause | Fix |
|---|---|---|
| `CoverArtCacheTest.loadCoverFromFile*`, `CoverArtUtilTest.extractEmbeddedCover`/`searchImage`, `TrackUpdateTest.parseModified*` (8) | `qjpeg.dll` needs `jpeg62.dll`, which is only in the `bin` folder of the dependency package, not in `build-test`: JPEG did not load or save. | `PATH` gets the `bin` folder of the dependency package. |
| `LateNightLayoutStateTest.*`, `HidMappings/...Dummy_Device_Screen_hid_xml` (2) | QML modules (`QtQuick.Window`, `QtQuick.Controls`) not found. | `QML_IMPORT_PATH` points to `Qt6\qml` of the dependency package. |
| `QmlSkins/QmlStartupSmokeTest.*`, `QmlLibraryProxyTest.*` (3) | They build the whole application (`CoreServices`); after another instance in the same process they crash (access violation). Alone they pass. Mixxx runs them with ctest, one process per test. | They run in processes of their own. |

The skins and controller files were not the cause: the repository still has all Mixxx skins
(`res/skins/LateNightQML` too) and all controller files.

### Faults in the tests of Mixxx (fixed in the test, no product change)

| Tests | Cause | Fix |
|---|---|---|
| `TrackMetadataExportTest.keepWithespaceKey` | `ControllerScriptEngineLegacyTest.JavascriptPlayerProxy_KeyNotation*` set a custom key notation (`B_FLAT_MINOR` ...) that is global and stayed for the later tests. Alone the test passes. | `TearDown` of `ControllerScriptEngineLegacyTest` resets the notation. |
| `ControllerScriptEngineLegacyTimerTest.beginTimer_singleShot*` (4) | The control `[Test],coTimerId` was a potmeter from -10 to 50; the Qt timer ids on Windows are far higher, so `timerId + 10` was clamped. Not a timing problem. | A plain `ControlObject` without range. |

### Intended FLXXX3 behaviour (test adapted under `#ifdef FLXXX3` or skipped)

| Tests | FLXXX3 behaviour | Change |
|---|---|---|
| `CueControlTest.LoadUnloadTrack`, `LoadTrackWithDetectedCues`, `LoadAutodetectedCues_*` (3), `SeekOnLoadDefault`, `SeekOnSetCueCDJ`, `SeekOnSetCuePlay` | Without AUTO CUE a loaded track waits on the first beat of its grid and the CUE point is set there (`CueControl::trackLoaded`); cues snap to the QUANTIZE BEAT VALUE grid (default 1/4 beat). | Expected load position/CUE point = first beat (`expectedLoadCue`), intro end 3.75 and outro end 15.5 beats. |
| `CueControlTest.SeekOnLoadMainCue`, `DontSeekOnLoadMainCue`, `SeekOnLoadDefault_CueInPreroll`, `FollowCueOnQuantize` | The CueRecall preference of Mixxx is not used and a finished analysis does not move the track. | `GTEST_SKIP` with this reason. |
| `EngineBufferE2ETest.*` (8) | Without ReplayGain value (or AUTO GAIN off) a deck plays at the -6 dB reference (`EnginePregain::process`); the output was exactly half of the golden buffers. | The fixture sets +6 dB pregain; the rest of the signal path is compared unchanged. |
| `AdjustReplayGainTest.AdjustReplayGainUpdatesPregain` | The deck `replaygain` holds the AUTO GAIN target, 4 dB above ReplayGain 2.0 (-14 LUFS, `ReplayGainSettings::deckRatio`). The audible level stays the same when the pregain is folded in. | Expected deck value 1.2 × 4 dB. |
| `EngineSyncTest.QuantizeHotCueActivate` | QUANTIZE snaps to the own grid only; matching the phase of another deck is part of SYNC (Rekordbox-like, `EngineBuffer::processSeek`). | Expected: the hot cue preview starts at the cue like without quantize. |
| `QmlWaveformOverviewTest.MonoRgbColorUsesBothChannels` | The mono overview uses the band colours of the scrolling waveform (`drawScheme`): red + blue gives about 255/142/253, not pure magenta. | Colour check: red and blue high, green clearly lower. |

New tests for the FLXXX3 load behaviour: `CueControlTest.Flxxx3LoadWaitsOnFirstBeat` (grid
from frame 1000: the track and the CUE point wait there, a stored main cue is replaced) and
`CueControlTest.Flxxx3AutoCueDoesNotWaitOnFirstBeat` (AUTO CUE: start at the first sound,
stored CUE point kept).

Decided 2026-11-20 (owner): without AUTO CUE, loading a track writes the first beat as main
cue into the track (`setMainCuePosition`), so a CUE point of an earlier session is not kept,
like on CDJs (memory cues are kept). Writing it into the track is needed: the control is set
from the track again whenever its cues change.

Failed engine tests write `src/test/reference_buffers/*.actual` (not in git); delete them
after looking.

Not covered yet: memory cues and hot cues from analysis files (the demo tracks have none; a
small export with cues would be needed), the QML interface, audio and MIDI with the device.
