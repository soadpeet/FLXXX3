<!-- AI disclaimer: this text was written autonomously by an AI agent (Claude). -->
# Rekordbox analysis files with cues (test data)

The analysis files (`ANLZ0000.DAT`, `ANLZ0000.EXT`, unchanged, no audio and no `export.pdb`)
of one track of the owner's Rekordbox export, used by
`src/test/rekordboxfeature_test.cpp` (`ReadsCuesAndLoops`). Contents, read independently of
FLXXX3 from the PCO2 sections:

| Rekordbox | Time | Kind | Colour |
|---|---|---|---|
| Hot cue A | 0.601 s | cue | green (26, 255, 0) |
| Hot cue E | 131.101 – 132.601 s | loop | orange (255, 140, 0) |
| Hot cue F | 228.601 – 230.101 s | loop | orange (255, 140, 0) |
| Memory cue | 24.601 s | cue | – |
| Memory cue | 48.601 s | cue | – |

Beat grid: 705 beats at 160.00 BPM. The path inside the files names the track; the audio
file is not part of the repository.
