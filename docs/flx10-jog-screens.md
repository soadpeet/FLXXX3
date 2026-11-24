# DDJ-FLX10 jog screens: notes

AI disclaimer: written by an AI agent (Claude) from its own analysis.

How FLXXX3 drives the jog screens of the DDJ-FLX10, and what a USB capture of
rekordbox showed. Protocol knowledge for Serato mode after the reverse engineering of
Victor Pineda (Veezuhz), github.com/Veezuhz/Mixxx_FLX10_Controller_Mapping.

## Now: Serato mode (working)

- Mapping script (`Pioneer-DDJ-FLX10-scripts.js`, `PioneerDDJFLX10.screen`) builds the
  reports; the app sends them to HID interface 5 (`src/controllers/midi/flx10jogscreen.cpp`:
  Android through the own USB audio driver, Windows through hidapi). The script reaches
  the app with SysEx `F0 7D 46 …` that the MIDI controllers keep from the MIDI port.
- SysEx: session start `F0 00 20 7F …`, `… 00 03 01`, deck init `11`–`14 … 02 0E 0E 05`,
  `0B 31 …`, `0C … 00 01`, keepalive `… 00 50 31` every 340 ms.
- `xx 27` state report (every 10 ms): elapsed time (b5–8: min, s, ms), length (b9–12),
  BPM (b13, b14 high nibble = 1/16), tempo (b15–17), key (b29), ring pointer:
  b22 = step (15 per turn, 0 = top), b21 = fine place (0..255) — measured on the device.
  FLXXX3 turns it once per bar. Open: a short twitch when b22 goes 14 → 0.
- On track load: `xx 30` (length), 3 × `xx 39`, 3 × `xx 35` (entries = length × 150),
  `xx 2F`; the app uploads the waveform (PWV5, `xx 36`) and the beat grid (`xx 2F`).
- Only one view. SHIFT + PAGE does nothing in this mode.

## rekordbox capture (2026-11-22, Windows, USBPcap)

File: `X:\Dev\FLXXX3-captures\flx10-rekordbox.pcap` (not in the repo; first 300 bytes of
each packet). FLX10 plugged in at 79 s (device address 17), rekordbox started at
about 133 s, track on deck 1, play, SHIFT + PAGE through the views, jog, deck 2.

Endpoints: 0x01 / 0x81 audio, 0x03 bulk OUT MIDI, 0x82 bulk IN MIDI, 0x05 interrupt OUT
screens (22926 reports), 0x84 interrupt IN (acknowledgements, 175504).

**Views:** the user saw four with SHIFT + PAGE: whole waveform + pointer, waveform section
+ pointer, pointer only, pointer + rekordbox logo. rekordbox sends nothing for SHIFT +
PAGE (no SysEx, no change in `xx 21`): the firmware switches the views itself, in
rekordbox mode. So the views need the rekordbox mode, not a command.

**SysEx of rekordbox** (MIDI OUT, in order):
- keepalive `F0 00 40 05 00 00 04 01 00 50 00 F7` about every 200 ms (Serato: `50 31`)
- `… 00 0B 35 60 14 01 00 00`, `… 00 0C 00 00 02 0E 0E 00 00 00`
- `… 00 0A 00 28 00 26 00 24 15 32 55 48 14 21 00 …` (long, mode config)
- `… 00 03 01` (4 ×)
- deck init `… 00 11`–`14 0F 0F 0F 0F 0F 0F`
- `… 00 0B 00 …`, `… 00 0A … 26 41 4A 24 2A 10 26 …`, `… 00 0B 31 5E 50 01 00 00`,
  `… 00 0B 31 00 00 00 00 00` (94 ×)
- per track: `… 00 11 00 00 03 0F 0A 0C` (deck), `… 00 0C 00 00 03 0F 0A 02 00 00`
  (master): BPM × 100 as nibbles (0x3FAC = 163.00); changes with the tempo fader.

**Screen reports of rekordbox** (counts): `xx 21` 16858 + 2333 (deck metadata, about
97 per second per deck, no `xx 27`), `xx 38` (3-band waveform), `xx 37` (overview),
`xx 2C` (70 per deck), `xx 2F`, `xx 39`, `xx 3B`, `xx 3C`, `xx 30`, `xx 2D`, `xx 3E`,
`xx 33`, `xx 2B`. No `xx 27`, no `xx 36`, no `00 3D`.

Start: `xx 21` with `00 02 10 01 00 00 80 10` (empty decks), then per deck `xx 39`,
`xx 3E`, `xx 2C` (`01 00 23`), `xx 2F`, `xx 30`, `xx 2D` (all `01 00 01`), later `xx 3B`
(`01 00 05`), `xx 3C` (`01 00 01 00 09`).

`xx 21` of a loaded deck (example):
`10 21 00 0a 14 01 00 02 80 b4 00 00 00 03 00 04 2c ac 00 00 00 a3 00 00 00 00 00 80 …`;
bytes that change: 2–5, 7, 9, 12 (60 values), 13 (256), 14–17, 21, 27, 31, 43 (129),
44, 55, 58, 60, 61.

Decoded so far (deck 1 playing from 250 s, deck 2 from about 290 s):
- b0 deck (10/20/30/40), b1 0x21, b7 02 loaded / 01, b8–9 `80 B4` loaded / `80 10` empty.
- b12 = elapsed seconds, b13 + 256 × b14 = milliseconds (1.802 s = 1, 34, 3); b11 probably
  minutes (not reached in the capture).
- b5: 0x01 → 0x81 when deck 1 started (deck 2 played with 0x01: maybe master / on air).
- b2–3 change while the jog is touched (scratch).
- b43 counts down about 2.7 a second (beats at 163 BPM): beat countdown, `FF FF` = none.
- b15 minutes, b16 seconds, b17 + 256 × b18 ms: length at the current tempo (deck 2
  4:27.306 = 04:27.3; deck 1 changed with the tempo fader).
- b60 key, same code as Serato's b29 (deck 2 0x94 = 11A; deck 1 4A shown shifted: tempo
  without master tempo).
- b31–32 = b55–56 (deck 2 0x166, deck 1 2 / 3), b21 A0 / A3 / A7: unknown.
- Tracks of the capture: deck 1 163 BPM, 4A, 3:46.7; deck 2 167 BPM, 11A, 4:27.3.
- BPM is not in `xx 21`: SysEx `… 00 11..14 00 00 <4 nibbles>` per deck and
  `… 00 0C 00 00 <4 nibbles> 00 00` master, BPM × 100 (0x3FAC = 163.00, 0x413C = 167.00).

**Replay test (2026-11-22):** FLXXX3 sent rekordbox's start SysEx and screen reports from
the capture (temporary `Pioneer-DDJ-FLX10-rbtest.js`): the firmware went into rekordbox
mode, SHIFT + PAGE switched the views. With one frozen `xx 21` repeated, everything
twitched (expected: no running time).

**Waveforms of rekordbox** (deck 1, at load 175.3 s and again 246.5 s):
- `xx 37` overview: 30 reports `<deck> 37 <seg 1..30> 00 1E 00` + 122 bytes: 1220 entries
  of 3 bytes (low, mid, high), not doubled.
- `xx 38` detail: `<deck> 38 <seg 1..255> <pass 0..4> <19 or 27> 04` + 122 bytes; the stream
  starts with the entry count (LE16, then 2 bytes), then 3 bytes per entry (low, mid,
  high), not doubled; 150 entries per second of the length at the current tempo
  (deck 1: 42626 = 284.17 s × 150).
- `xx 2C`: 35 × 2 reports `01..23 00 23 00`, all zero (empty overview) per deck at start.

**Own rekordbox mode (2026-11-22):** script `PioneerDDJFLX10.rb` (SysEx, start reports,
`xx 21`, BPM) and native `xx 37` / `xx 2F` / `xx 38` (flx10jogscreen.cpp). The first run
showed the views (they switched), but the device had been prepared by earlier SysEx (Serato
handshake, the replay). From a freshly plugged in FLX10 it stays on its logo — also with
the exact replay of rekordbox's start, also with Serato's handshake before it. Something
of rekordbox's start is still missing. (Solved later: the Serato mode was removed.)
Ideas: compare the device's MIDI and HID IN answers in the capture (EP 0x82, 0x84) with
ours; capture rekordbox once more from plugging in, with rekordbox already running.

**Solved (2026-11-22): the trigger is on MIDI channel 16.** Right after its first keepalive
rekordbox sends `9F 70 00`, after the SysEx a set of channel 16 messages (`9F 40 7F`,
`9F 41 00`, `9F 42 7F`, `BF 46 10`, `BF 3E 00`, `9F 3F 7F`, `BF 0D 00`, notes `00`–`07`,
`24`–`27` with 0, the first seven again). With them a freshly plugged in FLX10 goes into
rekordbox mode (views, SHIFT + PAGE). Also: Serato's request `F0 00 20 7F 03 01 F7` must
not be sent in rekordbox mode. The device keeps its mode until it is unplugged; it also
keeps the chosen view of each side.

**Waveforms (2026-11-22):** overview `xx 37`, beat grid `xx 2F` and detail `xx 38` made
from Mixxx's waveform (flx10jogscreen.cpp) show on the screens (tested one at a time).

## Next

Rebuild the rekordbox mode: its SysEx, the start reports, `xx 21` and the waveform
reports (`xx 38`, `xx 37`, `xx 2C`). Then the firmware shows its views and switches them
with SHIFT + PAGE itself.
