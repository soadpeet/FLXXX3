// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// Tests of the DDJ-FLX10 mapping (res/controllers/Pioneer-DDJ-FLX10-scripts.js and
// .midi.xml) without Mixxx: the script runs against the stand-in engine of mixxxmock.js.
// With two decks (the default) the mapping must not touch decks 3 and 4.
// Run: tools/run_tests.sh
import QtQuick
import QtTest
import "mixxxmock.js" as Mock

TestCase {
    name: "FLX10Script"

    readonly property string controllersUrl: Qt.resolvedUrl("../../../res/controllers/")
    property var engine
    property var midi
    property var flx10

    function init() {
        const loaded = Mock.loadMapping(controllersUrl, "Pioneer-DDJ-FLX10-scripts.js",
                "PioneerDDJFLX10");
        engine = loaded.engine;
        midi = loaded.midi;
        flx10 = loaded.object;
    }

    function isDeck3or4(group) {
        return group.indexOf("[Channel3]") >= 0 || group.indexOf("[Channel4]") >= 0;
    }

    function test_mappingFunctionsExist() {
        const xml = Mock.readFile(controllersUrl + "Pioneer-DDJ-FLX10.midi.xml");
        const re = /<key>PioneerDDJFLX10\.([A-Za-z0-9_.]+)<\/key>/g;
        let match;
        let count = 0;
        while ((match = re.exec(xml)) !== null) {
            let target = flx10;
            match[1].split(".").forEach(function(part) {
                target = target === undefined ? undefined : target[part];
            });
            verify(typeof target === "function", "PioneerDDJFLX10." + match[1] + " is not a function");
            count++;
        }
        verify(count > 40, "only " + count + " script functions found in the mapping");
    }

    function test_mappingHasAllFourDecks() {
        const xml = Mock.readFile(controllersUrl + "Pioneer-DDJ-FLX10.midi.xml");
        for (let d = 1; d <= 4; d++)
            verify(xml.indexOf("[Channel" + d + "]") >= 0, "deck " + d);
    }

    // UTILITY > DECKS 4: the mapping also serves decks 3 and 4.
    function test_initWithFourDecks() {
        engine.set("[App]", "num_decks", 4);
        flx10.init();
        compare(flx10.numDecks, 4);
        verify(engine.connections.some(function(c) { return c.group === "[Channel4]"; }));
        flx10.shutdown();
    }

    // MASTER and HEADPHONES LEVEL are set in the controller; [Master] gain is the
    // app's MASTER HEADROOM and must not be overwritten.
    function test_masterLevelIsLeftToTheController() {
        const xml = Mock.readFile(controllersUrl + "Pioneer-DDJ-FLX10.midi.xml");
        verify(!/<group>\[Master\]<\/group>\s*<key>gain<\/key>/.test(xml), "[Master] gain is mapped");
        verify(!/<key>headGain<\/key>/.test(xml), "headGain is mapped");
    }

    function test_twoDecksInitUsesOnlyDecks1And2() {
        flx10.init();
        verify(midi.sent.length > 0, "init sends the lights");
        verify(engine.connections.length > 0);
        engine.runTimers();
        flx10.shutdown();
        engine.connections.forEach(function(c) {
            verify(!isDeck3or4(c.group), "connected to " + c.group + " " + c.key);
        });
        engine.writes.forEach(function(w) {
            verify(!isDeck3or4(w.group) && !isDeck3or4(w.key), "wrote " + w.group + " " + w.key);
        });
    }

    // SOUND COLOR FX buttons choose the Color FX of the app and switch it on and off.
    function test_colorFxButtons() {
        flx10.soundColorFx(6, 0x02, 0x7F, 0x96, "[Master]");   // CRUSH pressed
        compare(engine.getValue("[AndroidDJ]", "color_fx"), 2);
        compare(engine.getValue("[AndroidDJ]", "color_fx_on"), 1);
        flx10.soundColorFx(6, 0x02, 0x00, 0x86, "[Master]");   // CRUSH off
        flx10.soundColorFx(6, 0x05, 0x7F, 0x96, "[Master]");   // FILTER on
        compare(engine.getValue("[AndroidDJ]", "color_fx"), 5);
        compare(engine.getValue("[AndroidDJ]", "color_fx_on"), 1);
        flx10.soundColorFx(6, 0x05, 0x00, 0x86, "[Master]");   // FILTER pressed again
        compare(engine.getValue("[AndroidDJ]", "color_fx_on"), 0);
    }

    // The small display of the Beat FX: name and beat as rekordbox sends them (USB capture).
    function test_beatFxDisplay() {
        const g = "[EffectRack1_EffectUnit1_Effect1]";
        engine.set("[AndroidDJ]", "beat_fx_pos2", 2);
        midi.sysex = [];
        flx10.beatFxPad(4, 0x21, 0x7F, 0x94, g);   // position 2: ECHO
        const names = midi.sysex.filter(function(m) { return m[10] === 0x0A; });
        compare(names.length, 1);
        compare(names[0].length, 54);
        compare(names[0].slice(16, 21), [0x0A, 0x0D, 0x42, 0x74, 0x09]);
        engine.set(g, "parameter1", 0.0);
        midi.sysex = [];
        flx10.sendFxBeat("1/4");
        compare(midi.sysex[0].slice(11, 17), [0x31, 0x5E, 0x50, 0x01, 0x00, 0x00]);
        midi.sysex = [];
        flx10.sendFxBeat("50%");
        compare(midi.sysex[0].slice(11, 17), [0x35, 0x60, 0x14, 0x01, 0x00, 0x00]);
        midi.sysex = [];
        flx10.sendFxBeat("1/16");
        compare(midi.sysex[0].slice(11, 17), [0x31, 0x5E, 0x44, 0x31, 0x03, 0x00]);
    }

    // ENIGMA JET: signed times like rekordbox, BEAT < along the ring: -4, -8 ... -64, +64 ... +1/16, -1/16 ...
    function test_signedBeatRing() {
        const g = "[EffectRack1_EffectUnit1_Effect1]";
        engine.set("[AndroidDJ]", "beat_fx_pos7", 12);
        flx10.beatFxPad(4, 0x26, 0x7F, 0x94, g);
        engine.runTimers();
        compare(flx10.fxBeatText(12), "-4");
        const seen = [];
        for (let i = 0; i < 22; i++) {
            flx10.beatFxLeftPressed(4, 0x4A, 0x7F);
            seen.push(flx10.fxBeatText(12));
        }
        compare(seen.slice(0, 5), ["-8", "-16", "-32", "-64", "+64"]);
        compare(seen[15], "-1/16");
        compare(seen[21], "-4");
        flx10.beatFxRightPressed(4, 0x4B, 0x7F);
        compare(flx10.fxBeatText(12), "-2");
    }

    // FX PART SELECT: DRUMS / VOCAL / INST switch the low / mid / high band of the Beat FX.
    function test_fxPartSelectBands() {
        const u = "[EffectRack1_EffectUnit1]";
        engine.set(u, "bands", 7);
        flx10.masterEqKill(6, 0x1C, 0x00, 0x96, "[Master]");   // DRUMS off: low off
        compare(engine.getValue(u, "bands"), 6);
        flx10.masterEqKill(6, 0x1D, 0x00, 0x96, "[Master]");   // INST off: high off
        compare(engine.getValue(u, "bands"), 2);
        flx10.masterEqKill(6, 0x1B, 0x00, 0x96, "[Master]");   // the last band stays on
        compare(engine.getValue(u, "bands"), 2);
        flx10.masterEqKill(6, 0x1C, 0x7F, 0x96, "[Master]");   // DRUMS on again
        compare(engine.getValue(u, "bands"), 3);
    }

    // A position taken from ADVANCED SETTINGS > BEAT FX.
    function test_beatFxPositionFromSettings() {
        const g = "[EffectRack1_EffectUnit1_Effect1]";
        engine.set("[AndroidDJ]", "beat_fx_pos11", 3);   // SLIP ROLL position now PING PONG
        flx10.beatFxPad(4, 0x2A, 0x7F, 0x94, g);
        compare(engine.getValue(g, "loaded_effect"), 3);
    }

    // The BEAT FX selector loads the Beat FX of the app; ON/OFF switches it.
    function test_beatFxSelectorAndOnOff() {
        const g = "[EffectRack1_EffectUnit1_Effect1]";
        const defaults = [11, 2, 1, 4, 6, 9, 12, 7, 8, 13, 17, 16, 14, 15];
        for (let i = 0; i < 14; i++)
            engine.set("[AndroidDJ]", "beat_fx_pos" + (i + 1), defaults[i]);
        flx10.beatFxPad(4, 0x24, 0x7F, 0x94, g);   // position 5: REVERB
        compare(engine.getValue(g, "loaded_effect"), 6);
        flx10.beatFxOnOff(4, 0x47, 0x7F, 0x94, g);
        compare(engine.getValue(g, "enabled"), 1);
        flx10.beatFxPad(4, 0x2A, 0x7F, 0x94, g);   // position 11: SLIP ROLL (an effect of the app, 17)
        compare(engine.getValue(g, "loaded_effect"), 17);
        compare(engine.getValue(g, "enabled"), 1);
        compare(engine.getValue("[AndroidDJ]", "beat_fx_selected"), 11);
        flx10.beatFxPad(4, 0x21, 0x7F, 0x94, g);   // position 2: ECHO, still on
        compare(engine.getValue(g, "loaded_effect"), 2);
        compare(engine.getValue(g, "enabled"), 1);
        engine.set("[AndroidDJ]", "beat_fx_tail", 1);
        // The FLX10 answers the new LED with a press of its own a few ms later: no change.
        flx10.beatFxOnOff(4, 0x47, 0x7F, 0x94, g);
        compare(engine.getValue(g, "enabled"), 1);
        flx10._beatFxLedAt = 0;                    // a real press later sends the new state
        flx10.beatFxOnOff(4, 0x47, 0x7F, 0x94, g); // "on" while on: no change
        compare(engine.getValue(g, "enabled"), 1);
        flx10.beatFxOnOff(4, 0x47, 0x00, 0x94, g); // OFF, ECHO rings out
        compare(engine.getValue(g, "meta"), 0);
        engine.runTimers();
        compare(engine.getValue(g, "enabled"), 0);
    }

    // Headphones like rekordbox: MASTER CUE off = only the cued channels, whatever the
    // MIXING knob says; MASTER CUE on = the knob mixes CUE and master.
    function test_masterCueGatesMasterInHeadphones() {
        flx10.init();
        flx10.headphonesMixing(6, 0x0C, 0x7F, 0xB6, "[Master]");   // knob fully to MASTER
        flx10.headphonesMixing(6, 0x2C, 0x7F, 0xB6, "[Master]");
        compare(engine.getValue("[Master]", "headMix"), -1);
        flx10.masterCue(6, 0x63, 0x7F, 0x96, "[Master]");          // MASTER CUE on
        compare(engine.getValue("[Master]", "headMix"), 1);
        flx10.headphonesMixing(6, 0x0C, 0x40, 0xB6, "[Master]");   // knob to the middle
        flx10.headphonesMixing(6, 0x2C, 0x00, 0xB6, "[Master]");
        verify(Math.abs(engine.getValue("[Master]", "headMix")) < 0.01);
        flx10.masterCue(6, 0x63, 0x00, 0x96, "[Master]");          // release: no change
        verify(Math.abs(engine.getValue("[Master]", "headMix")) < 0.01);
        flx10.masterCue(6, 0x63, 0x7F, 0x96, "[Master]");          // MASTER CUE off
        compare(engine.getValue("[Master]", "headMix"), -1);
        verify(midi.sent.some(function(m) { return m[0] === 0x96 && m[1] === 0x63 && m[2] === 0x7F; }),
            "MASTER CUE light");
        flx10.shutdown();
    }

    // The jog displays and level LEDs only get values that changed: playposition arrives on
    // every engine cycle and flooded the MIDI port.
    function test_unchangedDisplayValuesAreNotSent() {
        const before = midi.sent.length;
        engine.set("[Channel1]", "volume", 1);
        engine.set("[Channel1]", "vu_meter", 0.6);
        for (let n = 0; n < 50; n++) {
            flx10.jogMarker(0.5, "[Channel1]", "playposition");
            flx10.LedVuMeterCH1(0.6);
        }
        compare(midi.sent.length - before, 3);   // marker MSB + LSB, one level
        engine.set("[Channel1]", "vu_meter", 0.9);
        flx10.LedVuMeterCH1(0.9);
        compare(midi.sent.length - before, 4);
    }

    // Level LEDs: after the channel fader (cut = off), on rekordbox's scale and steps
    // (-19 dB = 65, about -15 dB = 87..94), the top LED when the deck clips.
    function test_levelLedsFollowFaderAndDb() {
        engine.set("[Channel1]", "volume", 1);
        engine.set("[Channel1]", "vu_meter", 0.860);            // -14.4 dB: 8-9 rows like rekordbox
        compare(Math.round(flx10.vuLevel(1) * 127), 108);
        engine.set("[Channel1]", "vu_meter", 0.45);             // -25 dB: dim, but lit
        const quiet = Math.round(flx10.vuLevel(1) * 127);
        verify(quiet > 58 && quiet < 90, quiet);
        engine.set("[Channel1]", "vu_meter", 0.03);             // about -50 dB: off
        compare(flx10.vuLevel(1), 0);
        engine.set("[Channel1]", "vu_meter", 0.834);
        engine.set("[Channel1]", "peak_indicator", 1);
        compare(flx10.vuLevel(1), 1);
        engine.set("[Channel1]", "peak_indicator", 0);
        engine.set("[Channel1]", "peak_indicator", 0);
        engine.set("[Channel1]", "vu_meter", 0.834);
        const up = flx10.vuLevel(1);
        engine.set("[Channel1]", "volume", 0);                  // fader cut: level stays (rekordbox)
        compare(flx10.vuLevel(1), up);
    }

    // Hot cue pads: the rekordbox colors of the app go to the pad values read off the pads.
    function test_hotcueColorsToPadValues() {
        compare(flx10._hotcueColorToPad(0x305AFF), 1);    // blue
        compare(flx10._hotcueColorToPad(0x50B4FF), 3);    // light blue
        compare(flx10._hotcueColorToPad(0xE62828), 42);   // red
        compare(flx10._hotcueColorToPad(0xE0641B), 37);   // orange
        compare(flx10._hotcueColorToPad(0xFF0000), 42);   // other red: nearest
        compare(flx10._hotcueColorToPad(0xFFFFFF), 127);  // white
    }

    // A saved loop pad is lit solid; it blinks only while that loop plays.
    function test_savedLoopBlinksOnlyWhenActive() {
        const g = "[Channel1]";
        engine.set(g, "hotcue_2_position", 1000);
        engine.set(g, "loop_start_position", 1000);
        engine.set(g, "loop_enabled", 0);
        verify(!flx10._hotcueLoopActive(1, 2));
        engine.set(g, "loop_enabled", 1);
        verify(flx10._hotcueLoopActive(1, 2));
        engine.set(g, "loop_start_position", 5000);
        verify(!flx10._hotcueLoopActive(1, 2));
    }

    // Jog scrolling: SHIFT + jog slower, a SEARCH key held + jog faster, both smooth like
    // turning the jog (scratch while touched); the jog takes over from the key's search.
    function test_jogScrollSpeeds() {
        const g = "[Channel1]";
        const ticks = [];
        const scratchTick = engine.scratchTick;
        const isScratching = engine.isScratching;
        engine.isScratching = function() { return true; };
        engine.scratchTick = function(deck, value) { ticks.push(value); };
        flx10.wheelTurn(0, 0x22, 64 + 8, 0xB0, g);               // touched jog
        flx10.wheelSeek(0, 0x26, 64 + 8, 0xB0, g);               // SHIFT + touched jog
        flx10.searchButton(0, 0x71, 0x7F, 0x90, g);
        compare(engine.getValue(g, "fwd"), 1);
        flx10.wheelFastSeek(0, 0x29, 64 + 8, 0xB0, g);           // SEARCH key + jog
        compare(engine.getValue(g, "fwd"), 0);
        flx10.searchButton(0, 0x71, 0x00, 0x90, g);
        engine.scratchTick = scratchTick;
        engine.isScratching = isScratching;
        compare(ticks.length, 3);
        verify(ticks[1] < ticks[0] && ticks[2] > ticks[0], ticks);
    }

    // Jog screens in rekordbox mode: rekordbox's SysEx, start reports for 4 decks, deck state
    // xx 21 (elapsed time, length, key), BPM SysEx and the waveform upload request.
    function test_rekordboxJogScreens() {
        engine.set("[AndroidDJ]", "hid_screens", 1);
        engine.set("[AndroidDJ]", "master_deck", 1);
        flx10.rb.UPLOAD_PARTS = 7;
        const g = "[Channel1]";
        engine.set(g, "duration", 200);
        engine.set(g, "playposition", 0.5);   // 100 s = 1:40.000
        engine.set(g, "rate_ratio", 1);
        engine.set(g, "bpm", 163);
        engine.set(g, "key", 18);             // F minor = 4A
        engine.set(g, "play", 1);
        flx10.init();
        verify(midi.sysex.some(function(m) { return m[10] === 0x0b && m[11] === 0x35; }),
            "rekordbox init SysEx");
        engine.runTimers();   // handshake again + start reports, then the timers
        engine.runTimers();
        const reports = midi.sysex.filter(function(m) {
            return m[1] === 0x7D && m[2] === 0x46 && m[3] === 0x48;
        }).map(function(m) { return m.slice(4, m.length - 1); });
        verify(reports.some(function(r) { return r[0] === 0x40 && r[1] === 0x2c; }), "xx 2c deck 4");
        const state = reports.filter(function(r) { return r[0] === 0x10 && r[1] === 0x21; }).pop();
        compare(state[5], 0x81);              // playing
        compare(state[11], 1);                // 1:40.000
        compare(state[12], 40);
        compare(state[15], 3);                // length 3:20
        compare(state[16], 20);
        compare(state[60], 0x92);             // 4A
        verify(midi.sysex.some(function(m) {
            return m[9] === 0x11 && m[12] === 0x3 && m[13] === 0xF && m[14] === 0xA && m[15] === 0xC;
        }), "BPM 163.00 of deck 1");
        verify(midi.sysex.some(function(m) { return m[3] === 0x52 && m[4] === 1; }), "upload");
        flx10.shutdown();
    }

    // Without HID (Windows): no screen reports, the MIDI jog display as before.
    function test_noHidScreensWithoutAndroid() {
        engine.set("[Channel1]", "duration", 200);
        flx10.init();
        engine.runTimers();
        verify(!midi.sysex.some(function(m) { return m[1] === 0x7D; }));
        flx10.shutdown();
    }

    // DECK 1/3 and 2/4: note 0x3C on the new deck's channel tells the screen which deck
    // each side controls; the "off" of the old deck changes nothing.
    function test_deckSelect() {
        flx10.deckSelect(0, 0x3C, 0x00, 0x90, "[Channel1]");
        flx10.deckSelect(2, 0x3C, 0x7F, 0x92, "[Channel3]");
        compare(engine.getValue("[AndroidDJ]", "deck_left"), 3);
        flx10.deckSelect(3, 0x3C, 0x7F, 0x93, "[Channel4]");
        compare(engine.getValue("[AndroidDJ]", "deck_right"), 4);
        flx10.deckSelect(1, 0x3C, 0x7F, 0x91, "[Channel2]");
        compare(engine.getValue("[AndroidDJ]", "deck_right"), 2);
        compare(engine.getValue("[AndroidDJ]", "deck_left"), 3);
    }

    // The ring pointer of the jog screen turns once per bar (4 beats); the grid start is
    // taken once, later beat_distance values (not in step with the position) change nothing.
    function test_ringPointerTurnsOncePerBar() {
        const g = "[Channel1]";
        engine.set(g, "duration", 120);
        engine.set(g, "file_bpm", 120);       // a beat every 0.5 s, first beat at 0.1 s
        engine.set(g, "beat_distance", 0.25); // at 2.725 s: 0.1 s + 5.25 beats
        verify(Math.abs(flx10.barPhase(g, 2.725 / 120) - 1.25 / 4) < 1e-6);
        engine.set(g, "beat_distance", 0.9);  // out of step: ignored now
        verify(Math.abs(flx10.barPhase(g, 4.35 / 120) - 0.5 / 4) < 1e-6);   // 8.5 beats
        verify(Math.abs(flx10.barPhase(g, 4.0999 / 120) - 3.9998 / 4) < 1e-3);
        engine.set(g, "file_bpm", 0);         // no grid: place in the track
        compare(flx10.barPhase(g, 0.3), 0.3);
    }

    // CALL only calls memory cues (hotcue 17..36), never hotcues A..H (1..8).
    function test_callOnlyMemoryCues() {
        const g = "[Channel1]";
        engine.set(g, "track_samples", 1000000);
        engine.set(g, "track_samplerate", 44100);
        engine.set(g, "playposition", 0.5);
        engine.set(g, "hotcue_2_status", 1);          // hotcue B just after: not called
        engine.set(g, "hotcue_2_position", 600000);
        engine.set(g, "hotcue_18_status", 1);         // memory cue further on
        engine.set(g, "hotcue_18_position", 800000);
        flx10.memCueNext(0, 0x52, 0x7F, 0x90, g);
        compare(engine.getValue(g, "cue_point"), 800000);
        verify(!engine.writes.some(function(w) { return w.key === "hotcue_2_goto"; }));
    }

    // EQ and TRIM are absolute knobs: "selectknob" (relative) made them jump to the maximum.
    // Only the BROWSE knobs are relative.
    function test_onlyBrowseKnobIsRelative() {
        const xml = Mock.readFile(controllersUrl + "Pioneer-DDJ-FLX10.midi.xml");
        const re = /<control>[\s\S]*?<\/control>/g;
        let match;
        while ((match = re.exec(xml)) !== null) {
            if (match[0].indexOf("<selectknob/>") >= 0)
                verify(match[0].indexOf("<key>MoveVertical</key>") >= 0, match[0]);
        }
    }
}
