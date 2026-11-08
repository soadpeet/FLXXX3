// Pioneer-DDJ-FLX4-script.js
// ****************************************************************************
// * Mixxx mapping script file for the Pioneer DDJ-FLX4.
// * Mostly adapted from the DDJ-400 mapping script
// * Authors: Warker, nschloe, dj3730, jusko, Robert904
// ****************************************************************************
//
//  Implemented (as per manufacturer's manual):
//      * Mixer Section (Faders, EQ, Filter, Gain, Cue)
//      * Browsing and loading + Waveform zoom (shift)
//      * Jogwheels, Scratching, Bending, Loop adjust
//      * Cycle Temporange
//      * Beat Sync
//      * Hot Cue Mode
//      * Beat Loop Mode
//      * Beat Jump Mode
//      * Sampler Mode
//      * Keyshift mode
//
//  Custom (Mixxx specific mappings):
//      * BeatFX: Assigned Effect Unit 1
//                v FX_SELECT Load next effect.
//                SHIFT + v FX_SELECT Load previous effect.
//                < LEFT Cycle effect focus leftward
//                > RIGHT Cycle effect focus rightward
//                ON/OFF toggles focused effect slot
//                SHIFT + ON/OFF disables all three effect slots.
//
//      * 32 beat jump forward & back (Shift + </> CUE/LOOP CALL arrows)
//      * Toggle quantize (Shift + channel cue)
//      * Stems selection using PADs (using controller's Keyboard mode)
//
//  Not implemented (after discussion and trial attempts):
//      * Loop Section:
//        * -4BEAT auto loop (hacky---prefer a clean way to set a 4 beat loop
//                            from a previous position on long press)
//
//        * CUE/LOOP CALL - memory & delete (complex and not useful. Hot cues are sufficient)
//
//      * Secondary pad modes (trial attempts complex and too experimental)
//        * Keyboard mode
//        * Pad FX1
//        * Pad FX2
//
//  Not implemented yet (but might be in the future):
//      * Smart CFX
//      * Smart fader

var PioneerDDJFLX4 = {};

PioneerDDJFLX4.lights = {
    beatFx: {
        status: 0x94,
        data1: 0x47,
    },
    shiftBeatFx: {
        status: 0x94,
        data1: 0x43,
    },
    deck1: {
        vuMeter: {
            status: 0xB0,
            data1: 0x02,
        },
        playPause: {
            status: 0x90,
            data1: 0x0B,
        },
        shiftPlayPause: {
            status: 0x90,
            data1: 0x47,
        },
        cue: {
            status: 0x90,
            data1: 0x0C,
        },
        shiftCue: {
            status: 0x90,
            data1: 0x48,
        },
        hotcueMode: {
            status: 0x90,
            data1: 0x1B,
        },
        keyboardMode: {
            status: 0x90,
            data1: 0x69,
        },
        padFX1Mode: {
            status: 0x90,
            data1: 0x1E,
        },
        padFX2Mode: {
            status: 0x90,
            data1: 0x6B,
        },
        beatJumpMode: {
            status: 0x90,
            data1: 0x20,
        },
        beatLoopMode: {
            status: 0x90,
            data1: 0x6D,
        },
        samplerMode: {
            status: 0x90,
            data1: 0x22,
        },
        keyShiftMode: {
            status: 0x90,
            data1: 0x6F,
        },
    },
    deck2: {
        vuMeter: {
            status: 0xB0,
            data1: 0x02,
        },
        playPause: {
            status: 0x91,
            data1: 0x0B,
        },
        shiftPlayPause: {
            status: 0x91,
            data1: 0x47,
        },
        cue: {
            status: 0x91,
            data1: 0x0C,
        },
        shiftCue: {
            status: 0x91,
            data1: 0x48,
        },
        hotcueMode: {
            status: 0x91,
            data1: 0x1B,
        },
        keyboardMode: {
            status: 0x91,
            data1: 0x69,
        },
        padFX1Mode: {
            status: 0x91,
            data1: 0x1E,
        },
        padFX2Mode: {
            status: 0x91,
            data1: 0x6B,
        },
        beatJumpMode: {
            status: 0x91,
            data1: 0x20,
        },
        beatLoopMode: {
            status: 0x91,
            data1: 0x6D,
        },
        samplerMode: {
            status: 0x91,
            data1: 0x22,
        },
        keyShiftMode: {
            status: 0x91,
            data1: 0x6F,
        },
    },
};

// Store timer IDs
PioneerDDJFLX4.timers = {};

// Keep alive timer
PioneerDDJFLX4.sendKeepAlive = function() {
    midi.sendSysexMsg([0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x05, 0x00, 0x50, 0x02, 0xf7], 12); // This was reverse engineered with Wireshark
};

PioneerDDJFLX4.queryPositions = function() {
    midi.sendSysexMsg([0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x05, 0x00, 0x03, 0x01, 0xF7], 12);
};

// Channel faders (14 bit): the curve of the UTILITY menu is applied here
// ([AndroidDJ] fader_curve: 0 slow start, 1 linear, 2 fast start).
PioneerDDJFLX4.faderMsb = {"[Channel1]": 0, "[Channel2]": 0};
PioneerDDJFLX4.channelFaderMSB = function(channel, control, value, status, group) {
    PioneerDDJFLX4.faderMsb[group] = value;
};
PioneerDDJFLX4.channelFaderLSB = function(channel, control, value, status, group) {
    const x = ((PioneerDDJFLX4.faderMsb[group] << 7) | value) / 16383;
    const curve = Math.round(engine.getValue("[AndroidDJ]", "fader_curve"));
    let y = x;
    if (curve === 0) {
        y = x * x; // slow start
    } else if (curve === 2) {
        y = Math.min(1, x * 1.6); // fast start
    }
    engine.setValue(group, "volume", y);
};

// Jog wheel constants
PioneerDDJFLX4.vinylMode = true;
PioneerDDJFLX4.alpha = 1.0/8;
PioneerDDJFLX4.beta = PioneerDDJFLX4.alpha/32;

// Multiplier for fast seek through track using SHIFT+JOGWHEEL
PioneerDDJFLX4.fastSeekScale = 150;
PioneerDDJFLX4.bendScale = 0.8;

// Android edition: steps like the Pioneer players (+-6 %, 10 %, 16 %, WIDE = +-100 %).
PioneerDDJFLX4.tempoRanges = [0.06, 0.10, 0.16, 1.0];

PioneerDDJFLX4.shiftButtonDown = [false, false];

// Jog wheel loop adjust
PioneerDDJFLX4.loopAdjustIn = [false, false];
PioneerDDJFLX4.loopAdjustOut = [false, false];
PioneerDDJFLX4.loopAdjustMultiply = 50;

// Beatjump pad (beatjump_size values)
PioneerDDJFLX4.beatjumpSizeForPad = {
    0x20: -1, // PAD 1
    0x21: 1,  // PAD 2
    0x22: -2, // PAD 3
    0x23: 2,  // PAD 4
    0x24: -4, // PAD 5
    0x25: 4,  // PAD 6
    0x26: -8, // PAD 7
    0x27: 8   // PAD 8
};

// Stems (KEYBOARD) pads mode status for deck 1 and 2, without or with SHIFT pressed
PioneerDDJFLX4.stemsPadsModesStatus = {
    "[Channel1]": [0x97, 0x98],
    "[Channel2]": [0x99, 0x9a],
};

// Stems (KEYBOARD) pad 1 control (pad control = [this value] + [pad  number] - 1)
PioneerDDJFLX4.stemMutePadsFirstControl = 0x40;

// Stems (KEYBOARD) pad 5 control (pad control = [this value] + [pad  number] - 1)
PioneerDDJFLX4.stemFxPadsFirstControl = 0x44;

// Pitch shift (KEY SHIFT) pads mode status for deck 1 and 2, without or with SHIFT pressed
PioneerDDJFLX4.pitchPadsModesStatus = {
    "[Channel1]": [0x97, 0x98],
    "[Channel2]": [0x99, 0x9a],
};

// Pitch shift (KEY SHIFT) pad 1 control (pad control = [this value] + [pad  number] - 1)
PioneerDDJFLX4.pitchPadsFirstControl = 0x70;

PioneerDDJFLX4.quickJumpSize = 32;

// Used for tempo slider
PioneerDDJFLX4.highResMSB = {
    "[Channel1]": {},
    "[Channel2]": {}
};

PioneerDDJFLX4.trackLoadedLED = function(value, group, _control) {
    midi.sendShortMsg(
        0x9F,
        group.match(script.channelRegEx)[1] - 1,
        value > 0 ? 0x7F : 0x00
    );
};

PioneerDDJFLX4.toggleLight = function(midiIn, active) {
    midi.sendShortMsg(midiIn.status, midiIn.data1, active ? 0x7F : 0);
};

//
// Init
//

PioneerDDJFLX4.init = function() {
    engine.setValue("[EffectRack1_EffectUnit1]", "show_focus", 1);
    // Android edition: Beat FX works like the Pioneer players, one effect at a
    // time (slot 1).
    engine.setValue("[EffectRack1_EffectUnit1]", "focused_effect", 1);

    engine.makeConnection("[Channel1]", "vu_meter", PioneerDDJFLX4.vuMeterUpdate);
    engine.makeConnection("[Channel2]", "vu_meter", PioneerDDJFLX4.vuMeterUpdate);

    PioneerDDJFLX4.toggleLight(PioneerDDJFLX4.lights.deck1.vuMeter, false);
    PioneerDDJFLX4.toggleLight(PioneerDDJFLX4.lights.deck2.vuMeter, false);

    engine.softTakeover("[Channel1]", "rate", true);
    engine.softTakeover("[Channel2]", "rate", true);
    engine.softTakeover("[EffectRack1_EffectUnit1_Effect1]", "meta", true);
    engine.softTakeover("[EffectRack1_EffectUnit1_Effect2]", "meta", true);
    engine.softTakeover("[EffectRack1_EffectUnit1_Effect3]", "meta", true);

    const samplerCount = 16;
    if (engine.getValue("[App]", "num_samplers") < samplerCount) {
        engine.setValue("[App]", "num_samplers", samplerCount);
    }
    for (let i = 1; i <= samplerCount; ++i) {
        engine.makeConnection("[Sampler" + i + "]", "play", PioneerDDJFLX4.samplerPlayOutputCallbackFunction);
    }

    engine.makeConnection("[Channel1]", "track_loaded", PioneerDDJFLX4.trackLoadedLED);
    engine.makeConnection("[Channel2]", "track_loaded", PioneerDDJFLX4.trackLoadedLED);

    // play the "track loaded" animation on both decks at startup
    midi.sendShortMsg(0x9F, 0x00, 0x7F);
    midi.sendShortMsg(0x9F, 0x01, 0x7F);

    PioneerDDJFLX4.setLoopButtonLights(0x90, 0x7F);
    PioneerDDJFLX4.setLoopButtonLights(0x91, 0x7F);

    engine.makeConnection("[Channel1]", "loop_enabled", PioneerDDJFLX4.loopToggle);
    engine.makeConnection("[Channel2]", "loop_enabled", PioneerDDJFLX4.loopToggle);

    for (i = 1; i <= 3; i++) {
        engine.makeConnection("[EffectRack1_EffectUnit1_Effect" + i +"]", "enabled", PioneerDDJFLX4.toggleFxLight);
    }
    engine.makeConnection("[EffectRack1_EffectUnit1]", "focused_effect", PioneerDDJFLX4.toggleFxLight);
    PioneerDDJFLX4.toggleFxLight();
    engine.makeConnection("[AndroidDJ]", "color_fx_on", PioneerDDJFLX4.updateColorFxLight);
    PioneerDDJFLX4.updateColorFxLight();
    // Watchdog: while the effect is on, its depth (the send of the effects)
    // must not stay at 0 unless it was turned down with SHIFT + LEVEL/DEPTH.
    engine.beginTimer(1000, function() {
        if (!PioneerDDJFLX4.fxOn || PioneerDDJFLX4.fxTailTimer || !PioneerDDJFLX4.fxSyncFromEffect) {
            return;
        }
        const group = PioneerDDJFLX4.focusedFxGroup();
        if (engine.getValue(group, "loaded_effect") !== 10 &&
                engine.getValue(group, "meta") < 0.01 &&
                Date.now() - PioneerDDJFLX4.lastDepthKnobTime > 3000) {
            engine.setValue(group, "meta", 1.0);
        }
    });
    // The effect is loaded (and enabled) by the screen shortly after the start:
    // force OFF a few times, then follow the effect.
    PioneerDDJFLX4.fxInitTimer = engine.beginTimer(2000, function() {
        PioneerDDJFLX4.fxInitCount = (PioneerDDJFLX4.fxInitCount || 0) + 1;
        PioneerDDJFLX4.fxOn = false;
        PioneerDDJFLX4.applyFxState();
        if (PioneerDDJFLX4.fxInitCount >= 4) {
            engine.stopTimer(PioneerDDJFLX4.fxInitTimer);
            PioneerDDJFLX4.fxSyncFromEffect = true;
        }
    });

    engine.makeConnection("[Channel1]", "sync_enabled", PioneerDDJFLX4.updateSyncLights);
    engine.makeConnection("[Channel2]", "sync_enabled", PioneerDDJFLX4.updateSyncLights);
    engine.makeConnection("[AndroidDJ]", "master_deck", PioneerDDJFLX4.updateSyncLights);
    PioneerDDJFLX4.updateSyncLights();

    // Register callbacks for each deck, when a file is loaded and the number of stems is available
    engine.makeConnection("[Channel1]", "stem_count", PioneerDDJFLX4.stemCountChanged);
    engine.makeConnection("[Channel2]", "stem_count", PioneerDDJFLX4.stemCountChanged);

    // Register callbacks for each stems of each decks, to change pad lights when muted/unmuted/FX
    for (let stem=1; stem<=4; stem++) {
        for (let deck=1; deck<=2; deck++) {
            engine.makeConnection(`[Channel${deck}_Stem${stem}]`, "mute", PioneerDDJFLX4.stemMuteChanged);
            engine.makeConnection(`[QuickEffectRack1_[Channel${deck}_Stem${stem}]]`, "enabled", PioneerDDJFLX4.stemFxChanged);
        }
    }

    // Register callbacks for each deck, when a file is loaded to reset pitch shift
    engine.makeConnection("[Channel1]", "track_loaded", PioneerDDJFLX4.pitchAdjusted);
    engine.makeConnection("[Channel2]", "track_loaded", PioneerDDJFLX4.pitchAdjusted);

    // Register callbacks for each deck, when the pitch shift is modified
    engine.makeConnection("[Channel1]", "pitch_adjust", PioneerDDJFLX4.pitchAdjusted);
    engine.makeConnection("[Channel2]", "pitch_adjust", PioneerDDJFLX4.pitchAdjusted);

    PioneerDDJFLX4.keepAliveTimer = engine.beginTimer(200, PioneerDDJFLX4.sendKeepAlive);

    // query the controller for current control positions on startup
    PioneerDDJFLX4.sendKeepAlive(); // the query seems to double as a keep alive message
    // Android edition: the position query of the Rekordbox app (found in its FLX4
    // section) makes the controller report all knobs, faders and the crossfader.
    // Sent at once and once more after the start-up has settled.
    PioneerDDJFLX4.queryPositions();
    engine.beginTimer(3000, PioneerDDJFLX4.queryPositions, true);
};

//
// Color FX (Android edition): SMART CFX switches the Color FX on / off, SMART
// FADER selects the next one (down the list), SHIFT + SMART FADER the previous
// one. The list: 0 SPACE, 1 DUB ECHO, 2 CRUSH, 3 SWEEP, 4 NOISE, 5 FILTER. The
// state lives in [AndroidDJ] color_fx / color_fx_on (the screen shows it).
//

PioneerDDJFLX4.colorFxCount = 6;

PioneerDDJFLX4.smartCfxPressed = function(_channel, _control, value) {
    if (value === 0) { return; }
    const on = engine.getValue("[AndroidDJ]", "color_fx_on") > 0;
    engine.setValue("[AndroidDJ]", "color_fx_on", on ? 0 : 1);
};

PioneerDDJFLX4.stepColorFx = function(direction) {
    const count = PioneerDDJFLX4.colorFxCount;
    const current = Math.round(engine.getValue("[AndroidDJ]", "color_fx"));
    engine.setValue("[AndroidDJ]", "color_fx", (current + direction + count) % count);
};

PioneerDDJFLX4.smartFaderPressed = function(_channel, _control, value) {
    if (value === 0) { return; }
    PioneerDDJFLX4.stepColorFx(1);
};

PioneerDDJFLX4.smartFaderShiftPressed = function(_channel, _control, value) {
    if (value === 0) { return; }
    PioneerDDJFLX4.stepColorFx(-1);
};

// The SMART CFX button blinks while the Color FX is on and is lit while it is
// off. (The LED knows only on / off: the value 0x7F lights it, every other value
// switches it off, so the blinking is made here.)
PioneerDDJFLX4.colorFxBlinkTimer = 0;
PioneerDDJFLX4.colorFxBlinkState = true;

PioneerDDJFLX4.sendColorFxLight = function(lit) {
    midi.sendShortMsg(0x96, 0x00, lit ? 0x7F : 0x00);
    midi.sendShortMsg(0x96, 0x08, lit ? 0x7F : 0x00);
};

PioneerDDJFLX4.updateColorFxLight = function() {
    if (PioneerDDJFLX4.colorFxBlinkTimer) {
        engine.stopTimer(PioneerDDJFLX4.colorFxBlinkTimer);
        PioneerDDJFLX4.colorFxBlinkTimer = 0;
    }
    PioneerDDJFLX4.colorFxBlinkState = true;
    PioneerDDJFLX4.sendColorFxLight(true);
    if (engine.getValue("[AndroidDJ]", "color_fx_on") > 0) {
        PioneerDDJFLX4.colorFxBlinkTimer = engine.beginTimer(500, function() {
            PioneerDDJFLX4.colorFxBlinkState = !PioneerDDJFLX4.colorFxBlinkState;
            PioneerDDJFLX4.sendColorFxLight(PioneerDDJFLX4.colorFxBlinkState);
        });
    }
};

//
// BROWSE knob
//

// Android edition: with SHIFT held the knob only zooms. Moving the library as
// well would select tracks (and read their data from the stick) on every step.
PioneerDDJFLX4.browseRotate = function(_channel, _control, value, _status, _group) {
    if (PioneerDDJFLX4.shiftButtonDown[0] || PioneerDDJFLX4.shiftButtonDown[1]) {
        return;
    }
    const delta = value >= 0x40 ? value - 0x80 : value;
    engine.setValue("[Library]", "MoveVertical", delta);
};

//
// Waveform zoom
//

// Android edition: SHIFT + BROWSE knob scrolls the track list in big steps
// (10 tracks per click). The knob alone zooms the waveforms while the library
// is closed and scrolls the list while it is open (see the main window).
PioneerDDJFLX4.browseRotateShift = function(_channel, _control, value, _status, _group) {
    const delta = value >= 0x40 ? value - 0x80 : value;
    engine.setValue("[Library]", "MoveVertical", delta * 10);
};

//
// Channel level lights
//

PioneerDDJFLX4.vuMeterUpdate = function(value, group) {
    const newVal = value * 127;

    switch (group) {
    case "[Channel1]":
        midi.sendShortMsg(0xB0, 0x02, newVal);
        break;

    case "[Channel2]":
        midi.sendShortMsg(0xB1, 0x02, newVal);
        break;
    }
};

//
// Effects
//

// Android edition: the BEAT FX ON/OFF button is lit while the effect is off and
// blinks while the effect is on.

// Own ON/OFF state of Beat FX: the effect system switches a freshly loaded
// effect on by itself, so for the first seconds the state is forced to OFF and
// only afterwards follows the effect (changes from the touch screen).
PioneerDDJFLX4.fxOn = false;
PioneerDDJFLX4.fxSyncFromEffect = false;

PioneerDDJFLX4.toggleFxLight = function(value, group, _control) {
    // While the effect runs out the effect is still enabled: no follow-up.
    if (PioneerDDJFLX4.fxSyncFromEffect && !PioneerDDJFLX4.fxTailTimer && typeof group === "string" &&
            group === PioneerDDJFLX4.focusedFxGroup()) {
        PioneerDDJFLX4.fxOn = value > 0;
    }
    PioneerDDJFLX4.updateFxLight();
};

// The LED of the button (found out by testing): the value 0x7F makes it blink
// (by itself), 0x00 makes it stay lit. Effect off = lit, effect on = blinking.
// The value is sent once when the state changes.
PioneerDDJFLX4.updateFxLight = function() {
    const value = PioneerDDJFLX4.fxOn ? 0x7F : 0x00;
    if (PioneerDDJFLX4.fxLastValue === value) {
        return;
    }
    PioneerDDJFLX4.fxLastValue = value;
    midi.sendShortMsg(0x94, 0x47, value);
    midi.sendShortMsg(0x94, 0x43, value);
};
PioneerDDJFLX4.fxLastValue = -1;

// Effect tail: when a delay / echo / ping pong / reverb is switched off, the
// signal into the effect is stopped (the DEPTH knob of the effect is the send)
// and the effect stays enabled for a while so that the repeats / the reverb
// die away. Then it is disabled and the depth is restored.
PioneerDDJFLX4.fxTailTimer = 0;
PioneerDDJFLX4.fxTailMeta = 1;

PioneerDDJFLX4.cancelFxTail = function(restoreDepth) {
    if (!PioneerDDJFLX4.fxTailTimer) { return; }
    engine.stopTimer(PioneerDDJFLX4.fxTailTimer);
    PioneerDDJFLX4.fxTailTimer = 0;
    if (restoreDepth) {
        engine.setValue(PioneerDDJFLX4.focusedFxGroup(), "meta", PioneerDDJFLX4.fxTailMeta);
    }
};

PioneerDDJFLX4.fxTailMs = function(loaded) {
    if (loaded === 6) { return 3000; } // reverb
    // Delay time in ms (first parameter: beats), 8 repeats, 1.5 - 6 s.
    const group = "[EffectRack1_EffectUnit1_Effect1]";
    const bpm = engine.getValue("[Channel" + (engine.getValue("[AndroidDJ]", "master_deck") === 2 ? 2 : 1) + "]", "bpm") || 120;
    const delayMs = 60000 / bpm * engine.getValue(group, "parameter1");
    return Math.max(1500, Math.min(6000, 8 * delayMs));
};

// Sets the effect to the own state. immediate = no tail.
PioneerDDJFLX4.applyFxState = function(immediate) {
    const focused = engine.getValue("[EffectRack1_EffectUnit1]", "focused_effect");
    const group = "[EffectRack1_EffectUnit1_Effect" + focused + "]";
    if (PioneerDDJFLX4.fxOn) {
        PioneerDDJFLX4.cancelFxTail(true);
    } else if (!immediate && PioneerDDJFLX4.fxSyncFromEffect && !PioneerDDJFLX4.fxTailTimer &&
            engine.getValue(group, "enabled") > 0 &&
            engine.getValue("[EffectRack1_EffectUnit1]", "mix") > 0.05) {
        const loaded = engine.getValue(group, "loaded_effect");
        // List positions: 1 Delay, 2 Echo, 3 Ping Pong, 4 Spiral, 6 Reverb (with tail).
        if ((loaded >= 1 && loaded <= 4) || loaded === 6) {
            PioneerDDJFLX4.fxTailMeta = engine.getValue(group, "meta");
            engine.setValue(group, "meta", 0);
            PioneerDDJFLX4.fxTailTimer = engine.beginTimer(PioneerDDJFLX4.fxTailMs(loaded), function() {
                PioneerDDJFLX4.fxTailTimer = 0;
                engine.setValue(group, "enabled", 0);
                engine.setValue(group, "meta", PioneerDDJFLX4.fxTailMeta);
            }, true);
            PioneerDDJFLX4.toggleFxLight();
            return;
        }
    }
    if (!PioneerDDJFLX4.fxOn && PioneerDDJFLX4.fxTailTimer && !immediate) {
        // already running out
        PioneerDDJFLX4.toggleFxLight();
        return;
    }
    if (immediate) {
        PioneerDDJFLX4.cancelFxTail(true);
    }
    for (let i = 1; i <= 3; i++) {
        engine.setValue("[EffectRack1_EffectUnit1_Effect" + i + "]", "enabled",
                (i === focused && PioneerDDJFLX4.fxOn) ? 1 : 0);
    }
    PioneerDDJFLX4.toggleFxLight();
};

PioneerDDJFLX4.focusedFxGroup = function() {
    const focusedFx = engine.getValue("[EffectRack1_EffectUnit1]", "focused_effect");
    return "[EffectRack1_EffectUnit1_Effect" + focusedFx + "]";
};

PioneerDDJFLX4.lastDepthKnobTime = 0;
PioneerDDJFLX4.beatFxLevelDepthRotate = function(_channel, _control, value) {
    if (PioneerDDJFLX4.shiftButtonDown[0] || PioneerDDJFLX4.shiftButtonDown[1]) {
        PioneerDDJFLX4.lastDepthKnobTime = Date.now();
    }
    if (PioneerDDJFLX4.shiftButtonDown[0] || PioneerDDJFLX4.shiftButtonDown[1]) {
        engine.softTakeoverIgnoreNextValue("[EffectRack1_EffectUnit1]", "mix");
        engine.setParameter(PioneerDDJFLX4.focusedFxGroup(), "meta", value / 0x7F);
    } else {
        engine.softTakeoverIgnoreNextValue(PioneerDDJFLX4.focusedFxGroup(), "meta");
        engine.setParameter("[EffectRack1_EffectUnit1]", "mix", value / 0x7F);
    }
};

PioneerDDJFLX4.changeFocusedEffectBy = function(numberOfSteps) {
    let focusedEffect = engine.getValue("[EffectRack1_EffectUnit1]", "focused_effect");

    // Convert to zero-based index
    focusedEffect -= 1;

    // Standard Euclidean modulo by use of two plain modulos
    const numberOfEffectsPerEffectUnit = 3;
    focusedEffect = (((focusedEffect + numberOfSteps) % numberOfEffectsPerEffectUnit) + numberOfEffectsPerEffectUnit) % numberOfEffectsPerEffectUnit;

    // Convert back to one-based index
    focusedEffect += 1;

    engine.setValue("[EffectRack1_EffectUnit1]", "focused_effect", focusedEffect);
};

// Android edition: a newly loaded effect is switched on by the effect system;
// ON/OFF of the player stays as it was.
PioneerDDJFLX4.changeEffectKeepState = function(control, value) {
    engine.setValue(PioneerDDJFLX4.focusedFxGroup(), control, value);
    PioneerDDJFLX4.applyFxState();
};

PioneerDDJFLX4.beatFxSelectPressed = function(_channel, _control, value) {
    if (value === 0) { return; }

    PioneerDDJFLX4.changeEffectKeepState("next_effect", value);
};

PioneerDDJFLX4.beatFxSelectShiftPressed = function(_channel, _control, value) {
    if (value === 0) { return; }

    PioneerDDJFLX4.changeEffectKeepState("prev_effect", value);
};

// Android edition: the BEAT < > buttons step through the effect time in beats
// (1/16 - 8 beats, like the Pioneer players). All effects have the time in
// beats as their first parameter (0 - 8), except the reverb (percent). List
// positions: 1 Delay, 2 Echo, 3 Ping Pong, 4 Spiral, 5 Helix, 6 Reverb,
// 7 Flanger, 8 Phaser, 9 Trans, 10 Filter.
PioneerDDJFLX4.beatFxBeatValues = [0.0625, 0.125, 0.25, 0.5, 0.75, 1, 2, 4, 8];

PioneerDDJFLX4.stepBeatFxTime = function(direction) {
    const group = "[EffectRack1_EffectUnit1_Effect1]";
    const loaded = engine.getValue(group, "loaded_effect");
    if (loaded < 1) { return; }

    if (loaded === 6) { // reverb: percent
        const percent = Math.round(engine.getParameter(group, "parameter1") * 10) + direction;
        engine.setParameter(group, "parameter1", Math.max(0, Math.min(10, percent)) / 10);
        return;
    }
    const beats = PioneerDDJFLX4.beatFxBeatValues;
    const current = engine.getParameter(group, "parameter1") * 8;
    let nearest = 0;
    for (let i = 1; i < beats.length; i++) {
        if (Math.abs(beats[i] - current) < Math.abs(beats[nearest] - current)) {
            nearest = i;
        }
    }
    const next = Math.max(0, Math.min(beats.length - 1, nearest + direction));
    engine.setParameter(group, "parameter1", beats[next] / 8);
};

PioneerDDJFLX4.beatFxLeftPressed = function(_channel, _control, value) {
    if (value === 0) { return; }

    PioneerDDJFLX4.stepBeatFxTime(-1);
};

PioneerDDJFLX4.beatFxRightPressed = function(_channel, _control, value) {
    if (value === 0) { return; }

    PioneerDDJFLX4.stepBeatFxTime(1);
};

PioneerDDJFLX4.beatFxOnOffPressed = function(_channel, _control, value) {
    if (value === 0) { return; }

    PioneerDDJFLX4.fxOn = !PioneerDDJFLX4.fxOn;
    PioneerDDJFLX4.applyFxState();
};

PioneerDDJFLX4.beatFxChannel1 = function(_channel, control, value, _status, group) {
    let enableChannel = 0;

    if (value === 0x7f) { enableChannel = 1; }

    engine.setValue(group, "group_[Channel1]_enable", enableChannel);
};

PioneerDDJFLX4.beatFxChannel2 = function(_channel, control, value, _status, group) {
    let enableChannel = 0;

    if (value === 0x7f) { enableChannel = 1; }

    engine.setValue(group, "group_[Channel2]_enable", enableChannel);
};

//
// Loop IN/OUT ADJUST
//

// Android edition: RELOOP/EXIT leaves an active loop; without a loop it makes a
// new 4 beat loop at the current position (no return to the old loop).
PioneerDDJFLX4.loopExitOrFourBeat = function(_channel, _control, value, _status, group) {
    if (value === 0) { return; }

    if (engine.getValue(group, "loop_enabled") > 0) {
        engine.setValue(group, "loop_enabled", 0);
    } else {
        engine.setValue(group, "beatloop_size", 4);
        engine.setValue(group, "beatloop_activate", 1);
        engine.setValue(group, "beatloop_activate", 0);
    }
};

// Android edition: LOOP IN / OUT.
//  - Inside an active loop the buttons do nothing.
//  - IN sets only a new start point.
//  - OUT sets the end point at the current position and makes the loop.
PioneerDDJFLX4.loopButtonForwarded = {};

PioneerDDJFLX4.loopButton = function(group, key, value) {
    const id = group + key;
    if (value > 0) {
        if (engine.getValue(group, "loop_enabled") > 0) {
            PioneerDDJFLX4.loopButtonForwarded[id] = false;
            return;
        }
        PioneerDDJFLX4.loopButtonForwarded[id] = true;
        engine.setValue(group, key, 1);
    } else if (PioneerDDJFLX4.loopButtonForwarded[id]) {
        PioneerDDJFLX4.loopButtonForwarded[id] = false;
        engine.setValue(group, key, 0);
    }
};

PioneerDDJFLX4.loopInPressed = function(_channel, _control, value, _status, group) {
    PioneerDDJFLX4.loopButton(group, "loop_in", value);
};

PioneerDDJFLX4.loopOutPressed = function(_channel, _control, value, _status, group) {
    PioneerDDJFLX4.loopButton(group, "loop_out", value);
};

PioneerDDJFLX4.toggleLoopAdjustIn = function(channel, _control, value, _status, group) {
    if (value === 0 || engine.getValue(group, "loop_enabled") === 0) {
        return;
    }
    PioneerDDJFLX4.loopAdjustIn[channel] = !PioneerDDJFLX4.loopAdjustIn[channel];
    PioneerDDJFLX4.loopAdjustOut[channel] = false;
};

PioneerDDJFLX4.toggleLoopAdjustOut = function(channel, _control, value, _status, group) {
    if (value === 0 || engine.getValue(group, "loop_enabled") === 0) {
        return;
    }
    PioneerDDJFLX4.loopAdjustOut[channel] = !PioneerDDJFLX4.loopAdjustOut[channel];
    PioneerDDJFLX4.loopAdjustIn[channel] = false;
};

// Two signals are sent here so that the light stays lit/unlit in its shift state too
PioneerDDJFLX4.setReloopLight = function(status, value) {
    midi.sendShortMsg(status, 0x4D, value);
    midi.sendShortMsg(status, 0x50, value);
};


PioneerDDJFLX4.setLoopButtonLights = function(status, value) {
    [0x10, 0x11, 0x4E, 0x4C].forEach(function(control) {
        midi.sendShortMsg(status, control, value);
    });
};

PioneerDDJFLX4.startLoopLightsBlink = function(channel, control, status, group) {
    let blink = 0x7F;

    PioneerDDJFLX4.stopLoopLightsBlink(group, control, status);

    PioneerDDJFLX4.timers[group][control] = engine.beginTimer(500, () => {
        blink = 0x7F - blink;

        // When adjusting the loop out position, turn the loop in light off
        if (PioneerDDJFLX4.loopAdjustOut[channel]) {
            midi.sendShortMsg(status, 0x10, 0x00);
            midi.sendShortMsg(status, 0x4C, 0x00);
        } else {
            midi.sendShortMsg(status, 0x10, blink);
            midi.sendShortMsg(status, 0x4C, blink);
        }

        // When adjusting the loop in position, turn the loop out light off
        if (PioneerDDJFLX4.loopAdjustIn[channel]) {
            midi.sendShortMsg(status, 0x11, 0x00);
            midi.sendShortMsg(status, 0x4E, 0x00);
        } else {
            midi.sendShortMsg(status, 0x11, blink);
            midi.sendShortMsg(status, 0x4E, blink);
        }
    });

};

PioneerDDJFLX4.stopLoopLightsBlink = function(group, control, status) {
    PioneerDDJFLX4.timers[group] = PioneerDDJFLX4.timers[group] || {};

    if (PioneerDDJFLX4.timers[group][control] !== undefined) {
        engine.stopTimer(PioneerDDJFLX4.timers[group][control]);
    }
    PioneerDDJFLX4.timers[group][control] = undefined;
    PioneerDDJFLX4.setLoopButtonLights(status, 0x7F);
};

PioneerDDJFLX4.loopToggle = function(value, group, control) {
    const status = group === "[Channel1]" ? 0x90 : 0x91,
        channel = group === "[Channel1]" ? 0 : 1;

    PioneerDDJFLX4.setReloopLight(status, value ? 0x7F : 0x00);

    // Android edition: a new loop sets the main CUE point at its start.
    if (value) {
        const loopStart = engine.getValue(group, "loop_start_position");
        if (loopStart >= 0) {
            engine.setValue(group, "cue_point", loopStart);
        }
    }

    if (value) {
        PioneerDDJFLX4.startLoopLightsBlink(channel, control, status, group);
    } else {
        PioneerDDJFLX4.stopLoopLightsBlink(group, control, status);
        PioneerDDJFLX4.loopAdjustIn[channel] = false;
        PioneerDDJFLX4.loopAdjustOut[channel] = false;
    }
};

//
// CUE/LOOP CALL
//

PioneerDDJFLX4.cueLoopCallLeft = function(_channel, _control, value, _status, group) {
    if (value) {
        engine.setValue(group, "loop_scale", 0.5);
    }
};

PioneerDDJFLX4.cueLoopCallRight = function(_channel, _control, value, _status, group) {
    if (value) {
        engine.setValue(group, "loop_scale", 2.0);
    }
};

//
// BEAT SYNC
//
// Note that the controller sends different signals for a short press and a long
// press of the same button.
//

PioneerDDJFLX4.syncPressed = function(channel, control, value, status, group) {
    // Android edition: a short press of BEAT SYNC makes this deck the MASTER
    // (tempo reference shown in orange on the screen).
    if (value > 0) {
        engine.setValue("[AndroidDJ]", "master_deck", group === "[Channel1]" ? 1 : 2);
    }
};

PioneerDDJFLX4.syncLongPressed = function(channel, control, value, status, group) {
    // Android edition: holding BEAT SYNC for a second switches the sync mode of
    // this deck on or off. Sync is off by default. The MASTER deck is the tempo
    // reference and cannot follow itself.
    if (value > 0) {
        const deck = group === "[Channel1]" ? 1 : 2;
        if (engine.getValue("[AndroidDJ]", "master_deck") === deck) {
            return;
        }
        engine.setValue(group, "sync_enabled", engine.getValue(group, "sync_enabled") ? 0 : 1);
    }
};

// The BEAT SYNC button is lit while the deck follows the master. The master
// deck is the leader of the engine as soon as another deck follows it, but its
// button stays dark.
PioneerDDJFLX4.updateSyncLights = function() {
    const master = engine.getValue("[AndroidDJ]", "master_deck");
    for (let deck = 1; deck <= 2; deck++) {
        const lit = engine.getValue("[Channel" + deck + "]", "sync_enabled") > 0 && master !== deck;
        const status = 0x90 + deck - 1;
        midi.sendShortMsg(status, 0x58, lit ? 0x7F : 0);
        midi.sendShortMsg(status, 0x60, lit ? 0x7F : 0);
    }
};

PioneerDDJFLX4.cycleTempoRange = function(_channel, _control, value, _status, group) {
    if (value === 0) { return; } // ignore release

    const currRange = engine.getValue(group, "rateRange");
    let idx = 0;

    for (let i = 0; i < this.tempoRanges.length; i++) {
        if (currRange === this.tempoRanges[i]) {
            // idx get the index of the value in tempoRanges following the currently configured one
            // or cycle back to 0 if the current is the last value of the list.
            idx = (i + 1) % this.tempoRanges.length;
            break;
        }
    }
    engine.setValue(group, "rateRange", this.tempoRanges[idx]);
};

//
// Jog wheels
//

PioneerDDJFLX4.jogTurn = function(channel, _control, value, _status, group) {
    const deckNum = channel + 1;
    // wheel center at 64; <64 rew >64 fwd
    let newVal = value - 64;

    // loop_in / out adjust
    const loopEnabled = engine.getValue(group, "loop_enabled");
    if (loopEnabled > 0) {
        if (PioneerDDJFLX4.loopAdjustIn[channel]) {
            newVal = newVal * PioneerDDJFLX4.loopAdjustMultiply + engine.getValue(group, "loop_start_position");
            engine.setValue(group, "loop_start_position", newVal);
            return;
        }
        if (PioneerDDJFLX4.loopAdjustOut[channel]) {
            newVal = newVal * PioneerDDJFLX4.loopAdjustMultiply + engine.getValue(group, "loop_end_position");
            engine.setValue(group, "loop_end_position", newVal);
            return;
        }
    }

    const jogState = PioneerDDJFLX4.jogState[channel];
    if (jogState.braking && newVal !== 0) {
        // turning the jog while it holds the slowed deck: scratch from here
        jogState.braking = false;
        PioneerDDJFLX4.stopJogRamp(channel);
        engine.scratchEnable(deckNum, 720, 33+1/3, this.alpha, this.beta);
    }
    if (engine.isScratching(deckNum)) {
        jogState.vel = jogState.vel * 0.6 + newVal * 0.4;
        jogState.time = Date.now();
        // the last turns (time, ticks) for the speed of the BACK SPIN
        jogState.samples.push([jogState.time, newVal]);
        if (jogState.samples.length > 30) { jogState.samples.shift(); }
        engine.scratchTick(deckNum, newVal);
    } else { // fallback
        engine.setValue(group, "jog", newVal * this.bendScale);
    }
};


PioneerDDJFLX4.jogSearch = function(_channel, _control, value, _status, group) {
    const newVal = (value - 64) * PioneerDDJFLX4.fastSeekScale;
    engine.setValue(group, "jog", newVal);
};

// ---- JOGWHEEL settings (Android edition, menu JOGWHEEL on the screen) --------
// VINYL SPEED ADJUST (TOUCH): touching the jog of a playing deck slows it down in
// the set time instead of stopping it at once; releasing it (without turning it)
// speeds it up again in that time. BACK SPIN: turning the jog fast backwards and
// letting go spins the track back, then it plays on.
PioneerDDJFLX4.jogState = [
    {vel: 0, time: 0, braking: false, ramp: 0, watch: 0, wasPlaying: false, backspinning: false, samples: []},
    {vel: 0, time: 0, braking: false, ramp: 0, watch: 0, wasPlaying: false, backspinning: false, samples: []}
];

PioneerDDJFLX4.stopJogRamp = function(channel) {
    const state = PioneerDDJFLX4.jogState[channel];
    if (state.ramp) {
        engine.stopTimer(state.ramp);
        state.ramp = 0;
    }
};

// Moves the speed of the deck (scratch2) from one rate to another in `seconds`.
PioneerDDJFLX4.rampJogSpeed = function(channel, group, fromRate, toRate, seconds, onDone) {
    const state = PioneerDDJFLX4.jogState[channel];
    PioneerDDJFLX4.stopJogRamp(channel);
    const start = Date.now();
    state.ramp = engine.beginTimer(20, function() {
        const progress = seconds <= 0 ? 1 : Math.min(1, (Date.now() - start) / (seconds * 1000));
        engine.setValue(group, "scratch2", fromRate + (toRate - fromRate) * progress);
        if (progress >= 1) {
            PioneerDDJFLX4.stopJogRamp(channel);
            if (onDone) { onDone(); }
        }
    });
};

// BACK SPIN, simulated here (the wheel of the FLX4 has no motor: it only turns as long as
// the hand moves it, so the slowing down must come from the software). The deck runs backwards
// at the start rate and slows down, passes the standstill and speeds up to its normal speed
// again, in the time of BACK SPIN LENGTH (SHORT / NORMAL / LONG). It uses the same ramp as
// VINYL SPEED ADJUST, which always ends by itself (time based).
PioneerDDJFLX4.endBackspin = function(channel, group) {
    const state = PioneerDDJFLX4.jogState[channel];
    PioneerDDJFLX4.stopJogRamp(channel);
    state.backspinning = false;
    engine.setValue(group, "scratch2_enable", 0);
};

// Speed of the jog in the 100 ms before the last tick, in times of the normal speed of the
// wheel (a record at 33 1/3 rpm = 400 ticks per second); negative = backwards.
PioneerDDJFLX4.jogSpeedTimes = function(channel) {
    const samples = PioneerDDJFLX4.jogState[channel].samples;
    if (samples.length === 0) { return 0; }
    const last = samples[samples.length - 1][0];
    let ticks = 0;
    for (let i = 0; i < samples.length; i++) {
        if (last - samples[i][0] <= 100) { ticks += samples[i][1]; }
    }
    return ticks * 10 / 400;
};

// The harder the jog was turned back, the faster the start and the longer the spin back:
// start speed = measured speed x BACK SPIN SENSITIVITY (between the set minimum and maximum),
// time = BACK SPIN LENGTH (0.5 / 2 / 4 s) x (measured speed / 6), between half and double.
PioneerDDJFLX4.startBackspin = function(channel, group, speedTimes) {
    const deckNum = channel + 1;
    const state = PioneerDDJFLX4.jogState[channel];
    const length = Math.max(0, Math.min(2, Math.round(engine.getValue("[AndroidDJ]", "backspin_length"))));
    const measured = Math.abs(speedTimes);
    const sens = engine.getValue("[AndroidDJ]", "backspin_sens");
    const minRate = engine.getValue("[AndroidDJ]", "backspin_min_rate");
    const maxRate = Math.max(minRate, engine.getValue("[AndroidDJ]", "backspin_max_rate"));
    const rate = Math.max(minRate, Math.min(maxRate, measured * sens));
    // SHORT: up to 1 s, NORMAL: up to 4 s, LONG: up to 8 s (the hardest turn).
    const seconds = [0.5, 2.0, 4.0][length] * Math.max(0.5, Math.min(2, measured / 6));
    const startRate = -rate;
    engine.setValue("[AndroidDJ]", "backspin_last_speed", measured);
    engine.setValue("[AndroidDJ]", "backspin_last_rate", rate);
    const target = engine.getValue(group, "rate_ratio");
    engine.scratchDisable(deckNum, false);
    engine.setValue(group, "scratch2_enable", 1);
    engine.setValue(group, "scratch2", startRate);
    state.backspinning = true;
    PioneerDDJFLX4.rampJogSpeed(channel, group, startRate, target, seconds, function() {
        PioneerDDJFLX4.endBackspin(channel, group);
    });
};

PioneerDDJFLX4.jogTouch = function(channel, _control, value) {
    const deckNum = channel + 1;
    const group = "[Channel" + deckNum + "]";
    const state = PioneerDDJFLX4.jogState[channel];

    // skip while adjusting the loop points
    if (PioneerDDJFLX4.loopAdjustIn[channel] || PioneerDDJFLX4.loopAdjustOut[channel]) {
        return;
    }

    const stopSeconds = engine.getValue("[AndroidDJ]", "vinyl_stop_sec");
    const startSeconds = engine.getValue("[AndroidDJ]", "vinyl_start_sec");
    // TEMP-DIAG jog: what the touch sees (bits: 1 touch, 2 stop time set, 4 deck playing,
    // 8 not scratching, 16 start time set); shown in ADVANCED SETTINGS -> JOGWHEEL.
    engine.setValue("[AndroidDJ]", "jog_dbg", (value !== 0 ? 1 : 0) +
        (stopSeconds > 0 ? 2 : 0) + (engine.getValue(group, "play") > 0 ? 4 : 0) +
        (!engine.isScratching(deckNum) ? 8 : 0) + (startSeconds > 0 ? 16 : 0));
    print("JOGDIAG ch=" + channel + " value=" + value + " stop=" + stopSeconds + " start=" + startSeconds +
        " play=" + engine.getValue(group, "play") + " scratching=" + engine.isScratching(deckNum));

    if (value !== 0 && this.vinylMode) {
        state.vel = 0;
        state.samples = [];
        if (state.backspinning) {
            // touching the jog during a spin back: take over
            PioneerDDJFLX4.endBackspin(channel, group);
        }
        state.wasPlaying = engine.getValue(group, "play") > 0;
        if (stopSeconds > 0 && state.wasPlaying && !engine.isScratching(deckNum)) {
            // slow down in the set time (VINYL SPEED ADJUST, stop)
            const startRate = engine.getValue(group, "rate_ratio");
            engine.setValue(group, "scratch2_enable", 1);
            engine.setValue(group, "scratch2", startRate);
            state.braking = true;
            PioneerDDJFLX4.rampJogSpeed(channel, group, startRate, 0, stopSeconds, null);
            return;
        }
        engine.scratchEnable(deckNum, 720, 33+1/3, this.alpha, this.beta);
    } else {
        const target = engine.getValue(group, "rate_ratio");
        if (state.braking) {
            // let go without turning: speed up again (VINYL SPEED ADJUST, start)
            state.braking = false;
            const current = engine.getValue(group, "scratch2");
            if (startSeconds > 0) {
                PioneerDDJFLX4.rampJogSpeed(channel, group, current, target, startSeconds, function() {
                    engine.setValue(group, "scratch2_enable", 0);
                });
            } else {
                PioneerDDJFLX4.stopJogRamp(channel);
                engine.setValue(group, "scratch2_enable", 0);
            }
            return;
        }
        if (engine.isScratching(deckNum) &&
                engine.getValue("[AndroidDJ]", "backspin_on") > 0 &&
                state.wasPlaying &&
                state.vel < -6 && Date.now() - state.time < 120) {
            PioneerDDJFLX4.startBackspin(channel, group, PioneerDDJFLX4.jogSpeedTimes(channel));
            return;
        }
        if (engine.isScratching(deckNum) && startSeconds > 0 && state.wasPlaying) {
            // after scratching: speed up in the set time
            engine.scratchDisable(deckNum, false);
            engine.setValue(group, "scratch2_enable", 1);
            engine.setValue(group, "scratch2", 0);
            PioneerDDJFLX4.rampJogSpeed(channel, group, 0, target, startSeconds, function() {
                engine.setValue(group, "scratch2_enable", 0);
            });
            return;
        }
        engine.scratchDisable(deckNum);
    }
};

//
// Shift button
//

PioneerDDJFLX4.shiftPressed = function(channel, _control, value, _status, _group) {
    PioneerDDJFLX4.shiftButtonDown[channel] = value === 0x7F;
};


//
// Tempo sliders
//
// The tempo option in Mixxx's deck preferences determine whether down/up
// increases/decreases the rate. Therefore it must be inverted here so that the
// UI and the control sliders always move in the same direction.
//

PioneerDDJFLX4.tempoSliderMSB = function(channel, control, value, status, group) {
    PioneerDDJFLX4.highResMSB[group].tempoSlider = value;
};

PioneerDDJFLX4.tempoSliderLSB = function(channel, control, value, status, group) {
    const fullValue = (PioneerDDJFLX4.highResMSB[group].tempoSlider << 7) + value;

    // Android edition: a deck that follows the master (SYNC on) takes its tempo
    // from the master. Its tempo fader must not change the master's tempo.
    const deck = group === "[Channel1]" ? 1 : 2;
    if (engine.getValue(group, "sync_enabled") > 0 &&
            engine.getValue("[AndroidDJ]", "master_deck") !== deck) {
        return;
    }

    engine.setValue(
        group,
        "rate",
        1 - (fullValue / 0x2000)
    );
};

//
// Beat Jump mode
//
// Note that when we increase/decrease the sizes on the pad buttons, we use the
// value of the first pad (0x21) as an upper/lower limit beyond which we don't
// allow further increasing/decreasing of all the values.
//

PioneerDDJFLX4.beatjumpPadPressed = function(_channel, control, value, _status, group) {
    if (value === 0) {
        return;
    }
    engine.setValue(group, "beatjump_size", Math.abs(PioneerDDJFLX4.beatjumpSizeForPad[control]));
    engine.setValue(group, "beatjump", PioneerDDJFLX4.beatjumpSizeForPad[control]);
};

PioneerDDJFLX4.increaseBeatjumpSizes = function(_channel, control, value, _status, group) {
    if (value === 0 || PioneerDDJFLX4.beatjumpSizeForPad[0x21] * 16 > 16) {
        return;
    }
    Object.keys(PioneerDDJFLX4.beatjumpSizeForPad).forEach(function(pad) {
        PioneerDDJFLX4.beatjumpSizeForPad[pad] = PioneerDDJFLX4.beatjumpSizeForPad[pad] * 16;
    });
    engine.setValue(group, "beatjump_size", PioneerDDJFLX4.beatjumpSizeForPad[0x21]);
};

PioneerDDJFLX4.decreaseBeatjumpSizes = function(_channel, control, value, _status, group) {
    if (value === 0 || PioneerDDJFLX4.beatjumpSizeForPad[0x21] / 16 < 1/16) {
        return;
    }
    Object.keys(PioneerDDJFLX4.beatjumpSizeForPad).forEach(function(pad) {
        PioneerDDJFLX4.beatjumpSizeForPad[pad] = PioneerDDJFLX4.beatjumpSizeForPad[pad] / 16;
    });
    engine.setValue(group, "beatjump_size", PioneerDDJFLX4.beatjumpSizeForPad[0x21]);
};

//
// Sampler mode
//

PioneerDDJFLX4.samplerPlayOutputCallbackFunction = function(value, group, _control) {
    if (value === 1) {
        const curPad = group.match(script.samplerRegEx)[1];
        let deckIndex = 0;
        let padIndex = 0;

        if (curPad >=1 && curPad <= 4) {
            deckIndex = 0;
            padIndex = curPad - 1;
        } else if (curPad >=5 && curPad <= 8) {
            deckIndex = 2;
            padIndex = curPad - 5;
        } else if (curPad >=9 && curPad <= 12) {
            deckIndex = 0;
            padIndex = curPad - 5;
        } else if (curPad >=13 && curPad <= 16) {
            deckIndex = 2;
            padIndex = curPad - 9;
        }

        PioneerDDJFLX4.startSamplerBlink(
            0x97 + deckIndex,
            0x30 + padIndex,
            group);
    }
};

PioneerDDJFLX4.padModeKeyPressed = function(_channel, _control, value, _status, _group) {
    const deck = (_status === 0x90 ? PioneerDDJFLX4.lights.deck1 : PioneerDDJFLX4.lights.deck2);

    if (_control === 0x1B) {
        PioneerDDJFLX4.toggleLight(deck.hotcueMode, true);
    } else if (_control === 0x69) {
        PioneerDDJFLX4.toggleLight(deck.keyboardMode, true);
    } else if (_control === 0x1E) {
        PioneerDDJFLX4.toggleLight(deck.padFX1Mode, true);
    } else if (_control === 0x6B) {
        PioneerDDJFLX4.toggleLight(deck.padFX2Mode, true);
    } else if (_control === 0x20) {
        PioneerDDJFLX4.toggleLight(deck.beatJumpMode, true);
    } else if (_control === 0x6D) {
        PioneerDDJFLX4.toggleLight(deck.beatLoopMode, true);
    } else if (_control === 0x22) {
        PioneerDDJFLX4.toggleLight(deck.samplerMode, true);
    } else if (_control === 0x6F) {
        PioneerDDJFLX4.toggleLight(deck.keyShiftMode, true);
    }
};

PioneerDDJFLX4.samplerPadPressed = function(_channel, _control, value, _status, group) {
    if (engine.getValue(group, "track_loaded")) {
        engine.setValue(group, "cue_gotoandplay", value);
    } else {
        engine.setValue(group, "LoadSelectedTrack", value);
    }
};

PioneerDDJFLX4.samplerPadShiftPressed = function(_channel, _control, value, _status, group) {
    if (engine.getValue(group, "play")) {
        engine.setValue(group, "cue_gotoandstop", value);
    } else if (engine.getValue(group, "track_loaded")) {
        engine.setValue(group, "eject", value);
    }
};

PioneerDDJFLX4.startSamplerBlink = function(channel, control, group) {
    let val = 0x7f;

    PioneerDDJFLX4.stopSamplerBlink(channel, control);
    PioneerDDJFLX4.timers[channel][control] = engine.beginTimer(250, () => {
        val = 0x7f - val;

        // blink the appropriate pad
        midi.sendShortMsg(channel, control, val);
        // also blink the pad while SHIFT is pressed
        midi.sendShortMsg((channel+1), control, val);

        const isPlaying = engine.getValue(group, "play") === 1;

        if (!isPlaying) {
            // kill timer
            PioneerDDJFLX4.stopSamplerBlink(channel, control);
            // set the pad LED to ON
            midi.sendShortMsg(channel, control, 0x7f);
            // set the pad LED to ON while SHIFT is pressed
            midi.sendShortMsg((channel+1), control, 0x7f);
        }
    });
};

PioneerDDJFLX4.stopSamplerBlink = function(channel, control) {
    PioneerDDJFLX4.timers[channel] = PioneerDDJFLX4.timers[channel] || {};

    if (PioneerDDJFLX4.timers[channel][control] !== undefined) {
        engine.stopTimer(PioneerDDJFLX4.timers[channel][control]);
        PioneerDDJFLX4.timers[channel][control] = undefined;
    }
};


PioneerDDJFLX4.toggleQuantize = function(_channel, _control, value, _status, group) {
    if (value) {
        script.toggleControl(group, "quantize");
    }
};

PioneerDDJFLX4.quickJumpForward = function(_channel, _control, value, _status, group) {
    if (value) {
        engine.setValue(group, "beatjump", PioneerDDJFLX4.quickJumpSize);
    }
};

PioneerDDJFLX4.quickJumpBack = function(_channel, _control, value, _status, group) {
    if (value) {
        engine.setValue(group, "beatjump", -PioneerDDJFLX4.quickJumpSize);
    }
};

//
// Stems mode
//

PioneerDDJFLX4.stemMutePadPressed = function(_channel, control, value, _status, group) {
    if (value !== 0x7f) {
        return;
    }

    const stemCount = Math.min(engine.getValue(group, "stem_count"), 4);

    if (control - PioneerDDJFLX4.stemMutePadsFirstControl + 1 > stemCount) {
        return;
    }

    const stemGroup = `[${group.substring(1, group.length-1)}_Stem${control - PioneerDDJFLX4.stemMutePadsFirstControl + 1}]`;

    if (engine.getValue(stemGroup, "mute")) {
        engine.setValue(stemGroup, "mute", 0);
    } else {
        engine.setValue(stemGroup, "mute", 1);
    }
};

PioneerDDJFLX4.stemMutePadShiftPressed = function(_channel, control, value, _status, group) {
    if (value !== 0x7f) {
        return;
    }

    const stemCount = Math.min(engine.getValue(group, "stem_count"), 4);

    if (control - PioneerDDJFLX4.stemMutePadsFirstControl + 1 > stemCount) {
        return;
    }

    for (let stemIdx=1; stemIdx<=stemCount; stemIdx++) {
        const stemGroup = `[${group.substring(1, group.length-1)}_Stem${stemIdx}]`;

        if (stemIdx + PioneerDDJFLX4.stemMutePadsFirstControl - 1 === control) {
            engine.setValue(stemGroup, "mute", 0);
        } else {
            engine.setValue(stemGroup, "mute", 1);
        }
    }
};

PioneerDDJFLX4.stemFxPadPressed = function(_channel, control, value, _status, group) {
    if (value !== 0x7f) {
        return;
    }

    if (control - PioneerDDJFLX4.stemFxPadsFirstControl + 1 > 4) {
        return;
    }

    const stemGroup = `[QuickEffectRack1_[${group.substring(1, group.length-1)}_Stem${control - PioneerDDJFLX4.stemFxPadsFirstControl + 1}]]`;

    if (engine.getValue(stemGroup, "enabled")) {
        engine.setValue(stemGroup, "enabled", 0);
    } else {
        engine.setValue(stemGroup, "enabled", 1);
    }
};

PioneerDDJFLX4.stemFxPadShiftPressed = function(_channel, control, value, _status, group) {
    if (value !== 0x7f) {
        return;
    }

    if (control - PioneerDDJFLX4.stemFxPadsFirstControl + 1 > 4) {
        return;
    }

    const stemGroup = `[QuickEffectRack1_[${group.substring(1, group.length-1)}_Stem${control - PioneerDDJFLX4.stemFxPadsFirstControl + 1}]]`;

    engine.setValue(stemGroup, "next_chain_preset", 1);
};

PioneerDDJFLX4.stemCountChanged = function(_value, group, _control) {

    for (let stem=1; stem<=4; stem++) {
        // Stem mute pads
        PioneerDDJFLX4.stemMuteChanged(
            engine.getValue(`[${group.substring(1, group.length-1)}_Stem${stem}]`, "mute"),
            `[${group.substring(1, group.length-1)}_Stem${stem}]`,
            _control,
        );

        // Stem FX pads
        PioneerDDJFLX4.stemFxChanged(
            engine.getValue(`[QuickEffectRack1_[${group.substring(1, group.length-1)}_Stem${stem}]]`, "enabled"),
            `[QuickEffectRack1_[${group.substring(1, group.length-1)}_Stem${stem}]]`,
            _control,
        );
    }
};

PioneerDDJFLX4.stemMuteChanged = function(value, group, _control) {
    const channelStem = group.match(/\[Channel(\d+)_Stem(\d+)\]/);
    const deck = Number(channelStem[1]);
    const stem = Number(channelStem[2]);
    const channel = `[Channel${deck}]`;

    if (stem > 4) {
        return;
    }

    const stemCount = engine.getValue(channel, "stem_count");

    let code = 0x00;
    if (stem <= stemCount && value <= 0.5) {
        code = 0x7f;
    }

    for (let i=0; i<PioneerDDJFLX4.stemsPadsModesStatus[channel].length; i++) {
        midi.sendShortMsg(
            PioneerDDJFLX4.stemsPadsModesStatus[channel][i],
            PioneerDDJFLX4.stemMutePadsFirstControl + stem -1,
            code,
        );
    }
};

PioneerDDJFLX4.stemFxChanged = function(value, group, _control) {
    const channelStem = group.match(/\[QuickEffectRack1_\[Channel(\d+)_Stem(\d+)\]\]/);
    const deck = Number(channelStem[1]);
    const stem = Number(channelStem[2]);
    const channel = `[Channel${deck}]`;

    if (stem > 4) {
        return;
    }

    for (let i=0; i<PioneerDDJFLX4.stemsPadsModesStatus[channel].length; i++) {
        midi.sendShortMsg(
            PioneerDDJFLX4.stemsPadsModesStatus[channel][i],
            PioneerDDJFLX4.stemFxPadsFirstControl + stem -1,
            value <= 0.5 ? 0x00 : 0x7f,
        );
    }
};

//
// Pitch Shift mode
//

PioneerDDJFLX4.pitchAdjusted = function(_value, group, _control) {
    const pitchAdjust = Math.round(engine.getValue(group, "pitch_adjust"));
    let lights = 0b00000000;

    if (pitchAdjust === 0) {
        lights = 0b10000001;
    } else if (pitchAdjust === 1) {
        lights = 0b01000000;
    } else if (pitchAdjust === 2) {
        lights = 0b00100000;
    } else if (pitchAdjust === 3) {
        lights = 0b00010000;
    } else if (pitchAdjust === 4) {
        lights = 0b10010000;
    } else if (pitchAdjust === 5) {
        lights = 0b01010000;
    } else if (pitchAdjust === 6) {
        lights = 0b00110000;
    } else if (pitchAdjust === 7) {
        lights = 0b10110000;
    } else if (pitchAdjust === 8) {
        lights = 0b01110000;
    } else if (pitchAdjust > 8) {
        lights = 0b11110000;
    } else if (pitchAdjust === -1) {
        lights = 0b00000010;
    } else if (pitchAdjust === -2) {
        lights = 0b00000100;
    } else if (pitchAdjust === -3) {
        lights = 0b00001000;
    } else if (pitchAdjust === -4) {
        lights = 0b00001001;
    } else if (pitchAdjust === -5) {
        lights = 0b00001010;
    } else if (pitchAdjust === -6) {
        lights = 0b00001100;
    } else if (pitchAdjust === -7) {
        lights = 0b00001101;
    } else if (pitchAdjust === -8) {
        lights = 0b00001110;
    } else if (pitchAdjust < -8) {
        lights = 0b00001111;
    } else {
        lights = 0b11111111;
    }

    for (let i=0; i<8; i++) {
        let code = 0x00;
        const pad = 0b10000000 >>> i;

        if (lights & pad) {
            code = 0x7f;
        } else {
            code = 0x00;
        }

        PioneerDDJFLX4.pitchPadsModesStatus[group].forEach(
            (padMode) => midi.sendShortMsg(
                padMode,
                PioneerDDJFLX4.pitchPadsFirstControl + i,
                code,
            )
        );
    }
};

PioneerDDJFLX4.pitchPadPressed = function(_channel, control, value, _status, group) {
    if (value !== 0x7f) {
        return;
    }

    const pad = control - this.pitchPadsFirstControl;
    let pitch = 0;

    if (pad === 0) {
        pitch = 0;
    } else if (pad === 1) {
        pitch = 1;
    } else if (pad === 2) {
        pitch = 2;
    } else if (pad === 3) {
        pitch = 3;
    } else if (pad === 4) {
        pitch = -3;
    } else if (pad === 5) {
        pitch = -2;
    } else if (pad === 6) {
        pitch = -1;
    } else if (pad === 7) {
        pitch = 0;
    }

    engine.setValue(group, "pitch_adjust", pitch);
};

PioneerDDJFLX4.pitchPadShiftPressed = function(_channel, control, value, _status, group) {
    if (value !== 0x7f) {
        return;
    }

    const pad = control - this.pitchPadsFirstControl;

    let currentPitch = engine.getValue(group, "pitch_adjust");

    if (pad === 0) {
        currentPitch += 1;
    } else if (pad === 1) {
        currentPitch += 2;
    } else if (pad === 2) {
        currentPitch += 3;
    } else if (pad === 3) {
        currentPitch += 4;
    } else if (pad === 4) {
        currentPitch += -4;
    } else if (pad === 5) {
        currentPitch += -3;
    } else if (pad === 6) {
        currentPitch += -2;
    } else if (pad === 7) {
        currentPitch += -1;
    }

    engine.setValue(group, "pitch_adjust", currentPitch);
};


//
// Shutdown
//

PioneerDDJFLX4.shutdown = function() {
    // reset vumeter
    PioneerDDJFLX4.toggleLight(PioneerDDJFLX4.lights.deck1.vuMeter, false);
    PioneerDDJFLX4.toggleLight(PioneerDDJFLX4.lights.deck2.vuMeter, false);

    // housekeeping
    // turn off all Sampler LEDs
    for (var i = 0; i <= 7; ++i) {
        midi.sendShortMsg(0x97, 0x30 + i, 0x00);    // Deck 1 pads
        midi.sendShortMsg(0x98, 0x30 + i, 0x00);    // Deck 1 pads with SHIFT
        midi.sendShortMsg(0x99, 0x30 + i, 0x00);    // Deck 2 pads
        midi.sendShortMsg(0x9A, 0x30 + i, 0x00);    // Deck 2 pads with SHIFT
    }
    // turn off all Hotcue LEDs
    for (i = 0; i <= 7; ++i) {
        midi.sendShortMsg(0x97, 0x00 + i, 0x00);    // Deck 1 pads
        midi.sendShortMsg(0x98, 0x00 + i, 0x00);    // Deck 1 pads with SHIFT
        midi.sendShortMsg(0x99, 0x00 + i, 0x00);    // Deck 2 pads
        midi.sendShortMsg(0x9A, 0x00 + i, 0x00);    // Deck 2 pads with SHIFT
    }

    // turn off loop in and out lights
    PioneerDDJFLX4.setLoopButtonLights(0x90, 0x00);
    PioneerDDJFLX4.setLoopButtonLights(0x91, 0x00);

    // turn off reloop lights
    PioneerDDJFLX4.setReloopLight(0x90, 0x00);
    PioneerDDJFLX4.setReloopLight(0x91, 0x00);

    // stop any flashing lights
    PioneerDDJFLX4.toggleLight(PioneerDDJFLX4.lights.beatFx, false);
    PioneerDDJFLX4.toggleLight(PioneerDDJFLX4.lights.shiftBeatFx, false);

    // stop the keepalive timer
    engine.stopTimer(PioneerDDJFLX4.keepAliveTimer);
};
