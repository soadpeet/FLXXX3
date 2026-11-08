<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# FLX4_COMPATIBILITY

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05, Mixxx 2.7.0-alpha.

## Mapping
- [CODE] `res/controllers/Pioneer-DDJ-FLX4.midi.xml` (3851 Z.), `res/controllers/Pioneer-DDJ-FLX4-script.js` (1146 Z.). Kein FLX2/6/10-Mapping; kein gemeinsames Script (FLX4 ist Kopie/Anpassung des DDJ-400, Script Z. 3).
- [CODE] Autoren: Skript-Header Z. 1-5 „Warker, nschloe, dj3730, jusko, Robert904“; XML `author Robert904`, `mixxxVersion="2.6"`. Git: Stem-/KeyShift-/Pitch-Light-Commits Okt–Nov 2025, PR #12842 (2024). Zustand: aktiv gepflegt.

## Funktionen (Script-Header Z. 6-45)
- [CODE] Implementiert: Mixer (Fader, EQ, Filter, Gain, Cue), Browse/Load, Waveform-Zoom (Shift), Jog (Scratch/Bend/Loop-Adjust: `jogTurn` 598, `jogTouch` 631), Tempo-Range-Zyklus (577), Sync (`syncPressed` 563, Long-Press = Sync-Lock 571), Hotcue-, Beatloop-, Beatjump-, Sampler-, Keyshift-Pads, BeatFX auf Unit 1, 32-Beat-Jump, Quantize-Toggle, Stem-Auswahl über Keyboard-Pads (`stemMutePadPressed` 839 u. a.).
- [CODE] Nicht implementiert: -4BEAT-Autoloop, CUE/LOOP-CALL-Memory/Delete, Pad-FX1/FX2, Smart CFX, Smart Fader.
- [CODE] Rückmeldungen/LEDs: Lights-Tabelle Z. 50-170; Note-On `0x90..0x9F` für LEDs, VU-Meter CC `0xB0/0xB1 0x02` (`vuMeterUpdate` 337), `trackLoadedLED` 237, Blink-Logik Loop-Adjust 486-515. Jog-/Pad-LEDs über dieselben Muster (Details je Pad nicht einzeln aufgelistet).
- [CODE] Init/SysEx: `init` Z. 253; einziger SysEx `F0 00 40 05 00 00 04 05 00 50 02 F7` als Keep-Alive alle 200 ms (`sendKeepAlive` Z. 174, „mit Wireshark reverse-engineered“), zugleich Positions-Abfrage; Start-Animation `0x9F 0x00/0x01 0x7F`.

## Analyseabhängigkeit
- [CODE] Script liest weder `bpm`/`key` direkt noch Analysedaten. Nutzt Controls, die Beats brauchen: `beatsync`, `sync_enabled`, `beatjump`, `beatjump_size`, `beatloop_N_enabled`, `loop_scale`, `quantize`, `pitch_adjust`, `rate`.
- [CODE] Diese Controls sind bei fehlenden Beats null-gesichert (`bpmcontrol.cpp:299-306`, `quantizecontrol.cpp:110`, `synccontrol.cpp:376-390`); Beatloops fallen auf ein Fake-60-BPM-Grid zurück (`loopingcontrol.cpp:1295-1310`). → Siehe `SCOPE_REDUCTION.md`.
- Stems: Script enthält optionale Stem-Pads (Keyboard-Modus). [WAHRSCHEINLICH] bei `-DSTEM=OFF` ohne Wirkung/ohne Fehler, da `[ChannelN_StemM]`-Controls fehlen; **nicht getestet**.

## Anpassungen für Android
- [WAHRSCHEINLICH] Mapping selbst unverändert nutzbar, sobald ein Android-MIDI-Backend dieselben MIDI-Messages liefert (SysEx, Note-On-LED-Ausgabe, 200-ms-Timer im Script-Engine). `controllerscriptenginelegacy.cpp:57` deaktiviert Datei-Watching auf Android (Mapping muss aus `res/` geladen werden).
- [EXPERIMENT] Keep-Alive-Verhalten und LED-Rückkanal über Android-MIDI testen.

## USB-Audio
- Im Repo keine Aussage zu FLX4-Audio (grep „audio“ im Script/XML leer). Websuche 2026-11-05: Händler nennen „kein Audiotreiber am PC/Mac“; Kanalzahl unbekannt. Alles Weitere [EXPERIMENT] (siehe `AUDIO_ARCHITECTURE.md`).

<!-- Ende KI-generierter Text -->
