// FLXXX3: based on the DDJ-FLX10 mapping of Marc Zischka (Zim) and Victor Pineda
// (Veezuhz), Mixxx pull request 16539 (github.com/mixxxdj/mixxx/pull/16539, state of
// 2026-09-26, GPL like Mixxx). FLXXX3 changes: two or four decks (numDecks), BROWSE
// knobs like the DDJ-FLX4. The
// FLXXX3 changes are marked "FLXXX3" and were written by an AI agent (Claude).
// -------------------------------------------------------------------
// ------------------- DDJ-FLX10 script file v.1.1 ---------------------
// -------------------------------------------------------------------

// *************************************************************************
// * Mixxx mapping script file for the Pioneer DDJ-FLX10.
// * Mostly adapted from the DDJ-1000 mapping script from Arnold Kalambani
// * Author: Marc Zischka (Zim)
// * Contributions: Victor Pineda (Veezuhz)
// ****************************************************************************
//
//  Implemented (as per manufacturer's manual):
//      * Mixer Section (Faders, EQ, Filter, Gain, Cue)
//      * Browsing and loading 
//      * Jogwheels, Scratching, Bending, Loop adjust ?
//      * Cycle Tempo Range
//      * Beat Sync
//      * Hot Cue Mode
//      * Beat Loop Mode
//      * Beat Jump Mode
//      * Sampler Mode
//      * Toggle quantize
//      * Toggle slip
//		* Reverse play 
//++++++++++++++++++++++++++++++++++++++++++++++++++++
// Check :
//  Custom (Mixxx specific mappings):
//      * BeatFX: Assigned Effect Unit 1
//                v FX_SELECT focus EFFECT1.
//                < LEFT focus EFFECT2
//                > RIGHT focus EFFECT3
//                ON/OFF toggles focused effect slot
//                SHIFT + ON/OFF disables all three effect slots.
//                SHIFT + < loads previous effect
//                SHIFT + > loads next effect
//
//      * 32 beat jump forward & back (Shift + </> CUE/LOOP CALL arrows)
//      * Toggle quantize (Shift + channel cue)
//      * Pad FX1 (see mapping infos)
//      * Pad FX2
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// To fix
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// To develop ?
//      * Loop Section:
//        * -4BEAT auto loop (hacky---prefer a clean way to set a 4 beat loop
//                            from a previous position on long press)
//
//        * CUE/LOOP CALL - memory & delete (complex and not useful. Hot cues are sufficient)
//
//      * Secondary pad modes (trial attempts complex and too experimental)
//        * Keyboard mode

//        * Keyshift mode
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// DISCLAIMER: These additions were developed alongside Claude Code in VSCode.
// They are not part of the original mapping script and may not be fully tested.
// Please review the code and test it thoroughly before using it in a live setting.
//
// ════════════════ UPDATE LOG — NEWEST FIRST (date M-DD.HHMM) ════════════════
// Add new entries at the TOP of this block.
//
// 6-01.1830 — Veezuhz:
//   * Hot-cue pads: RGB LEDs color-matched to the cue colour, blink on saved loops
//   * Loop IN/OUT button LEDs: blink while setting/adjusting, solid while looping
//   * 4-beat loop button now loops the PREVIOUS 4 beats (end-anchored via loop_anchor)
//   * Shift+Loop Out reloops the last stored loop when none is active
//   * Needle-seek on the pressed jog (Shift = fast seek)
//   * Script-driven 14-bit tempo fader + TEMPO RESET hold-at-0% toggle
//   * KEY SYNC toggle + LED; BEAT SYNC LED
//   * EQ KILL on the per-deck stem buttons (Low/Mid/High, latching)
//   * Master stem buttons kill Low/Mid/High EQ across ALL decks at once
//   * Sound Color FX: intensity-knob soft-takeover fixed on all 4 decks (was CH1 only);
//                     deselecting a preset loads the empty '----' preset (no effect)
//   * Sampler pads trigger Sampler 1-8; pad LEDs lit when loaded, blink while playing
//   * BeatFX ON/OFF is press-to-toggle; bound for Serato (0x46) AND non-Serato (0x47) note modes
//   * All button LEDs re-pushed shortly after startup so they match Mixxx state on launch
//   * Note fixes: keylock 0x1C->0x4A, BeatFX 0x47->0x46
//
// 5-22.945 — Veezuhz:
//   * Tempo reset button management
//   * Time display mode (elapsed vs remaining) on Shift+Hot Cue
//   * connectControl -> makeConnection for high-frequency callbacks
//   * VuMeter -> vu_meter
//
// Earlier (undated) — Veezuhz:
//   * Beatgrid nudge (Shift + Jog)
//   * Waveform zoom (Shift + CH rotary)
//   * Memory cue navigation (Shift + Hot Cue pads)
//   * Beat Jump + Beat Jump Size (Shift + CUE/LOOP CALL arrows)
//   * Sound Color FX controls (Shift + Pad FX1/2)
//   * Crossfader assign A/THRU/B per channel (Shift + Channel Fader)
//   * Pioneer-like Play/Cue LED policy
//   * BeatFX effect scanner diagnostic (Shift + BeatFX ON)
//   * Loop in/out (Shift + Loop In/Out); Half & Double
// ════════════════════════════════════════════════════════════════════════════

// ─── TUNABLE PARAMETERS ──────────────────────────────────────────────────────
// Jog scratch sensitivity: how many encoder intervals equal one vinyl revolution.
// FLXXX3: the DDJ-FLX10 sends about 12900 intervals per turn of the platter. 1500 moved
// the track 8.6 times as far as a record, 12900 (1:1) was too little: one turn of the
// platter is now about 2.6 turns of a record (4.6 s of audio).
var SCRATCH_INTERVALS_PER_REV = 5000;

// Smoothing of the scratch filter of Mixxx (lower = smoother, a little more lag).
// FLXXX3: 1/16 instead of 1/8: on Android the many fine jog steps of the DDJ-FLX10 come in
// bursts, with 1/8 turning felt rough.
var JOG_ALPHA = 1.0 / 16;

// Jog pitch-bend divisor: how much a jog nudge shifts playback rate.
// Higher = smaller nudge. Lower = larger nudge.
var JOG_BEND_DIVISOR = 20;

// Loop adjust step: samples moved per jog unit when in loop in/out adjust mode.
// At 44.1 kHz, 100 samples ≈ 2.3 ms per minimum jog tick.
var LOOP_ADJUST_STEP = 4;
// FLXXX3: scrolling with the jog, as a factor on its intervals (smooth like normal
// turning, through the scratch of Mixxx). SHIFT + jog (CC 0x1F rim, 0x26 touched):
// four times slower. A SEARCH key held + jog (CC 0x29): about 7 times faster.
var SLOW_SCROLL_FACTOR = 0.25;
var FAST_SCROLL_FACTOR = 7;
// ─────────────────────────────────────────────────────────────────────────────

// Global variables
var PioneerDDJFLX10 = {};

// FLXXX3: the app always has four decks in its engine (UTILITY > DECKS 2 / 4 only
// switches the screen): the mapping serves all four ([App] num_decks, read when the
// mapping starts; 2 only if the engine has fewer, e.g. in plain Mixxx).
PioneerDDJFLX10.numDecks = 2;
PioneerDDJFLX10.deckNumbers = function() {
    var decks = [];
    for (var d = 1; d <= PioneerDDJFLX10.numDecks; d++) {
        decks.push(d);
    }
    return decks;
};

// Global state
PioneerDDJFLX10.shiftActive = false;
PioneerDDJFLX10._rateMSB = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._rateLSB = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._jogTouches = {1: false, 2: false, 3: false, 4: false};
PioneerDDJFLX10._jogLastValue = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._reverseSlipActive = {1: false, 2: false, 3: false, 4: false};
PioneerDDJFLX10._lastShiftPress = 0;
PioneerDDJFLX10._playCueBlinkTimer = {};
PioneerDDJFLX10._playCueBlinkState = {1: false, 2: false, 3: false, 4: false};
PioneerDDJFLX10._playCueShouldBlink = {1: false, 2: false, 3: false, 4: false};
PioneerDDJFLX10._cuePressed = {1: false, 2: false, 3: false, 4: false};
PioneerDDJFLX10._playShouldBlink = {1: false, 2: false, 3: false, 4: false};
PioneerDDJFLX10._trackDuration = {1: 0, 2: 0, 3: 0, 4: 0};

// Utility function to extract deck number from group
PioneerDDJFLX10._getDeckFromGroup = function(group) {
    var match = group.match(/\d+/);
    return match ? parseInt(match[0], 10) : 1;
};

// ─── Deferred LED state refresh ──────────────────────────────────────────────
// At launch Mixxx pushes initial LED (output) state, but the FLX10 isn't ready
// to receive yet and misses that burst; Mixxx's output handler then suppresses
// resends (it believes the LED already matches the value), so toggle LEDs stay
// wrong until their value next changes. Re-send the toggle LEDs (and re-render
// hot cues) directly a short delay after init, when the controller is ready.
// Writing MIDI here bypasses the handler's redundant-message guard.
var LED_REFRESH_DELAY_MS = 1200;
PioneerDDJFLX10._OUTPUT_LEDS = [
    {key: "play_indicator", note: 0x0B},
    {key: "cue_indicator",  note: 0x0C},
    {key: "quantize",       note: 0x35},
    {key: "keylock",        note: 0x4A},
    {key: "pfl",            note: 0x54},
    {key: "reverse",        note: 0x15},
    {key: "sync_enabled",   note: 0x58},
    {key: "slip_enabled",   note: 0x40}
];
PioneerDDJFLX10._refreshOutputLeds = function() {
    for (var deck = 1; deck <= PioneerDDJFLX10.numDecks; deck++) {
        var status = 0x90 + (deck - 1);
        var group = "[Channel" + deck + "]";
        for (var i = 0; i < PioneerDDJFLX10._OUTPUT_LEDS.length; i++) {
            var led = PioneerDDJFLX10._OUTPUT_LEDS[i];
            midi.sendShortMsg(status, led.note,
                engine.getValue(group, led.key) > 0.5 ? 0x7F : 0x00);
        }
        // Re-render hot-cue pad LEDs (same startup-timing vulnerability).
        if (PioneerDDJFLX10._hotcue && PioneerDDJFLX10._hotcue[deck]) {
            for (var pad = 1; pad <= 8; pad++) {
                PioneerDDJFLX10._renderHotcue(deck, pad);
            }
        }
        // Re-render loop in/out button LEDs.
        if (PioneerDDJFLX10._renderLoopLeds) {
            PioneerDDJFLX10._renderLoopLeds(deck);
        }
        // Re-render EQ kill LEDs (repurposed stem buttons).
        if (PioneerDDJFLX10._renderEqKillLed) {
            for (var k = 0; k < 3; k++) {
                PioneerDDJFLX10._renderEqKillLed(deck, k);
            }
        }
    }
    // Master EQ kill LEDs (once — these span all decks).
    if (PioneerDDJFLX10._renderMasterEqKillLed) {
        for (var mi = 0; mi < 3; mi++) {
            PioneerDDJFLX10._renderMasterEqKillLed(mi);
        }
    }
    // Sampler pad LEDs (once — Sampler1-8).
    if (PioneerDDJFLX10._renderSamplerLed) {
        for (var sn = 1; sn <= 8; sn++) {
            PioneerDDJFLX10._renderSamplerLed(sn);
        }
    }
};

// Initialization
PioneerDDJFLX10.init = function(id) {
    PioneerDDJFLX10.numDecks = engine.getValue("[App]", "num_decks") >= 4 ? 4 : 2;
    PioneerDDJFLX10.HID_SCREENS = engine.getValue("[AndroidDJ]", "hid_screens") === 1;
    PioneerDDJFLX10.masterCueOn = false;
    midi.sendShortMsg(0x96, 0x63, 0x00);
    PioneerDDJFLX10.applyHeadMix();
    // FLXXX3: ask the controller for the positions of all faders and knobs, so a channel
    // fader that is down at start is down in the app too.
    PioneerDDJFLX10.queryPositions();
    engine.beginTimer(500, PioneerDDJFLX10.queryPositions, true);
    // The touch arrows of the Beat FX window change the beat: the small display follows.
    engine.makeConnection("[AndroidDJ]", "beat_fx_signed", function(value) {
        var idx = PioneerDDJFLX10._signedRing.indexOf(value);
        if (idx >= 0 && PioneerDDJFLX10._signedIndex[PioneerDDJFLX10._fxCode] !== undefined) {
            PioneerDDJFLX10._signedIndex[PioneerDDJFLX10._fxCode] = idx;
        }
        PioneerDDJFLX10.updateFxDisplay(false);
    });
    engine.makeConnection(PioneerDDJFLX10._beatFxGroup, "parameter1", function() {
        PioneerDDJFLX10.updateFxDisplay(false);
    });
    // A newly loaded effect is switched on by the effect system a moment later: while the ON/OFF key
    // is off that is undone (not during a tail). Otherwise the key follows the effect (switched on
    // or off in the touch window): its LED is set and the state remembered.
    engine.makeConnection(PioneerDDJFLX10._beatFxGroup, "enabled", function(value) {
        var tail = PioneerDDJFLX10._beatFxTailTimer;
        if (tail) {
            // The effect rings out (switched off by the key). Switched off in the touch window now:
            // the ring out ends, the depth is back. (Otherwise the timer of the ring out would
            // switch the effect off again a moment after it was switched on by touch, with the
            // depth still at 0: blue, but no sound.)
            if (value <= 0) {
                PioneerDDJFLX10._cancelBeatFxTail(true);
                PioneerDDJFLX10._beatFxActive = false;
                PioneerDDJFLX10._setBeatFxLed(false);
            }
            return;
        }
        if (value > 0 && !PioneerDDJFLX10._beatFxActive && !tail &&
                Date.now() - PioneerDDJFLX10._beatFxSelectAt < 2000) {
            engine.setValue(PioneerDDJFLX10._beatFxGroup, "enabled", 0);
            return;
        }
        PioneerDDJFLX10._beatFxActive = value > 0 && !tail;
        PioneerDDJFLX10._setBeatFxLed(value > 0 && !tail);
    });
    // Beat FX: read the position of the selector at the start and set the effect again later.
    // After the start the app switches the Beat FX off (the effect system loads it on): the
    // ON/OFF key follows the real state then (it latches by itself and may still be lit from before).
    engine.beginTimer(16000, function() {
        var on = engine.getValue(PioneerDDJFLX10._beatFxGroup, "enabled") > 0;
        PioneerDDJFLX10._beatFxActive = on;
        PioneerDDJFLX10._setBeatFxLed(on, true);
    }, true);
    [3000, 8000, 14000].forEach(function(ms) {
        engine.beginTimer(ms, PioneerDDJFLX10.reapplyBeatFxPosition, true);
    });
    PioneerDDJFLX10._setBeatFxLed(false, true);
    engine.makeConnection("[AndroidDJ]", "color_fx_on", function() {
        PioneerDDJFLX10.renderColorFxLeds(false);
    });
    engine.makeConnection("[AndroidDJ]", "color_fx", function() {
        PioneerDDJFLX10.renderColorFxLeds(false);
    });
    [1000, 4000, 9000, 16000].forEach(function(ms) {
        engine.beginTimer(ms, function() {
            PioneerDDJFLX10.renderColorFxLeds(true);
        }, true);
    });
    // FLXXX3: repeats the last level every 40 ms (vu_meter changes only every 70-200 ms), so the
    // LEDs do not fall back; rekordbox sends it all the time. (Not checked whether needed.)
    engine.beginTimer(40, function() {
        for (var d = 1; d <= PioneerDDJFLX10.numDecks; d++) {
            var v = PioneerDDJFLX10._vuSent[0xB0 + d - 1];
            if (v) {
                midi.sendShortMsg(0xB0 + d - 1, 0x02, v);
            }
        }
    });
    console.log("Pioneer DDJ-FLX10 PROD - Initialisation");
    var initTimeMode = engine.getValue("[Controls]", "ShowDurationRemaining") !== 0 ? 0x7F : 0x00;
    // Plage de pitch par défaut (±16%)
    for (var i = 1; i <= PioneerDDJFLX10.numDecks; i++) {
        var grp = "[Channel" + i + "]";
        engine.setValue(grp, "rateRange", 0.16);
        // Seed the tempo fader to CENTER (0x40 MSB / 0 LSB ≈ rate 0) so
        // _sliderRate() returns ~0 before the fader is physically moved —
        // otherwise a 0/0 reading computes +1 (max) and releasing TEMPO RESET
        // before touching the fader would jump tempo to max.
        PioneerDDJFLX10._rateMSB[i] = 0x40;
        PioneerDDJFLX10._rateLSB[i] = 0x00;
        // Clear sync/tempo-reset button LEDs — the FLX10 powers up with these
        // lit and Mixxx doesn't proactively send the off state.
        midi.sendShortMsg(0x90 + (i - 1), 0x58, 0x00);   // beat sync off
        midi.sendShortMsg(0x90 + (i - 1), 0x65, 0x00);   // key sync off
        midi.sendShortMsg(0x90 + (i - 1), 0x41, 0x00);   // tempo reset off
        // Connect VU meters
        engine.makeConnection(grp, "vu_meter", PioneerDDJFLX10["LedVuMeterCH" + i]);
        // Force off au démarrage pour éviter LEDs fantômes
        midi.sendShortMsg(0xB0 + (i - 1), 0x02, 0x00);
        // FLXXX3: with the jog screens driven over HID (PioneerDDJFLX10.screen) the MIDI
        // jog display fields stay off: the firmware mixes both.
        if (PioneerDDJFLX10.HID_SCREENS) {
            continue;
        }
        // Jog display: enable visibility, set time mode, then connect data callbacks
        midi.sendShortMsg(JOG_DISPLAY_NOTE, 0x5C + i, 0x00);
        midi.sendShortMsg(JOG_DISPLAY_NOTE, _JOG_TIME_MODE[i - 1], initTimeMode);
        engine.makeConnection(grp, "playposition", PioneerDDJFLX10.jogMarker);
        engine.makeConnection(grp, "bpm",          PioneerDDJFLX10.jogBpm);
        engine.makeConnection(grp, "rate",         PioneerDDJFLX10.jogSpeed);
        engine.makeConnection(grp, "duration",     PioneerDDJFLX10.jogDuration);
        // Seed duration cache so jogTime works immediately at init
        PioneerDDJFLX10._trackDuration[i] = engine.getValue(grp, "duration");
        // Push initial values so displays start at correct state, not hardware defaults
        PioneerDDJFLX10.jogMarker(engine.getValue(grp, "playposition"), grp, "playposition");
        PioneerDDJFLX10.jogBpm(engine.getValue(grp, "bpm"), grp, "bpm");
        PioneerDDJFLX10.jogSpeed(engine.getValue(grp, "rate"), grp, "rate");
        PioneerDDJFLX10.jogTime(engine.getValue(grp, "playposition"), grp, "playposition");
    }
    // Poll all four decks every 250 ms and push time to jog displays.
    // Using a timer rather than a playposition callback because Mixxx throttles
    // high-frequency CO callbacks on some builds and the timer is unconditional.
    engine.beginTimer(250, function() {
        if (PioneerDDJFLX10.HID_SCREENS) {
            return;
        }
        var showRemaining = engine.getValue("[Controls]", "ShowDurationRemaining") !== 0;
        for (var d = 1; d <= PioneerDDJFLX10.numDecks; d++) {
            var duration = PioneerDDJFLX10._trackDuration[d];
            if (!(duration > 0)) { continue; }
            var pos = engine.getValue("[Channel" + d + "]", "playposition");
            var idx = d - 1;
            var elapsed = pos * duration;
            var displayTime = showRemaining ? (duration - elapsed) : elapsed;
            var min = Math.floor(displayTime / 60);
            var sec = Math.floor(displayTime % 60);
            if (min > 127) { min = 127; }
            midi.sendShortMsg(JOG_DISPLAY_CC, _JOG_TIME_MIN[idx], min);
            midi.sendShortMsg(JOG_DISPLAY_CC, _JOG_TIME_SEC[idx], sec);
        }
    });

    // LEDs Play/Cue avancées (Pioneer-like)
    PioneerDDJFLX10._initAdvancedLeds();

    // Hot-cue pad RGB LEDs (color-matched to Mixxx hot-cue colors, blink on loops)
    PioneerDDJFLX10._initHotcueLeds();
    for (var sd = 1; sd <= PioneerDDJFLX10.numDecks; sd++) {
        (function(group, deck) {
            engine.makeConnection(group, "playposition", function() {
                PioneerDDJFLX10._checkAdjustExit(deck);
            });
            engine.makeConnection(group, "loop_enabled", function(value) {
                if (value <= 0) {
                    PioneerDDJFLX10._slipRejoin(group);
                }
            });
        })("[Channel" + sd + "]", sd);
    }
    engine.makeConnection("[AndroidDJ]", "hid_jog_left", function(v) {
        PioneerDDJFLX10._hidJogMove("left", v);
    });
    engine.makeConnection("[AndroidDJ]", "hid_jog_right", function(v) {
        PioneerDDJFLX10._hidJogMove("right", v);
    });
    PioneerDDJFLX10._lightModePads();
    PioneerDDJFLX10._showPadMode(0, 0);
    PioneerDDJFLX10._showPadMode(1, 0);
    PioneerDDJFLX10._showPadMode(2, 0);
    PioneerDDJFLX10._showPadMode(3, 0);

    // Loop in/out button LEDs (blink while setting/adjusting, solid when active)
    PioneerDDJFLX10._initLoopLeds();

    // EQ kill switches on the repurposed STEM buttons (lit = band on)
    PioneerDDJFLX10._initEqKillLeds();

    // Master EQ kills (master stem buttons → kill a band on all decks)
    PioneerDDJFLX10._initMasterEqKillLeds();

    // Sampler pad LEDs (lit when a sampler is loaded, blink while playing)
    PioneerDDJFLX10._initSamplerLeds();

    // Re-push LED state once the controller is ready to receive — the FLX10
    // misses Mixxx's initial output burst at launch (see _refreshOutputLeds).
    engine.beginTimer(LED_REFRESH_DELAY_MS, function() {
        PioneerDDJFLX10._refreshOutputLeds();
    }, true);

    // The Color FX keys of the device select the effect: the list of the app stays closed.
    engine.setValue("[AndroidDJ]", "color_fx_quiet", 1);

    if (typeof PioneerDDJFLX10.screen !== "undefined") {
        PioneerDDJFLX10.screen.start();
    } else {
        console.log("FLX10 screen: module not loaded — HID interface may be unavailable");
    }

    return true;
};

// Tempo management (14-bit) — inversion Pioneer
PioneerDDJFLX10.rate_msb = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    PioneerDDJFLX10._rateMSB[deck] = value;
    PioneerDDJFLX10._updateRate(deck);
};

PioneerDDJFLX10.rate_lsb = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    PioneerDDJFLX10._rateLSB[deck] = value;
    PioneerDDJFLX10._updateRate(deck);
};

// Convert the deck's 14-bit pitch-fader position (_rateMSB/_rateLSB) to a
// Mixxx `rate` value (-1..+1, Pioneer-inverted).
PioneerDDJFLX10._sliderRate = function(deck) {
    var msb = PioneerDDJFLX10._rateMSB[deck] || 0;
    var lsb = PioneerDDJFLX10._rateLSB[deck] || 0;
    var value = (msb << 7) | lsb;                 // 0..16383
    var norm  = (value / 16383.0) * 2.0 - 1.0;    // -1..+1
    norm = -norm;                                 // inversion Pioneer
    if (norm > 1) norm = 1;
    if (norm < -1) norm = -1;
    return norm;
};

PioneerDDJFLX10._updateRate = function(deck) {
    // While TEMPO RESET is engaged the fader is disconnected: keep tracking its
    // position (_rateMSB/_rateLSB are still updated by the handlers) but DON'T
    // apply it, so the tempo stays pinned at 0%. Releasing the button picks up
    // the fader's then-current position.
    if (PioneerDDJFLX10._tempoResetEngaged &&
        PioneerDDJFLX10._tempoResetEngaged[deck]) {
        return;
    }
    // A deck that follows the master (SYNC on) takes its tempo from the master: its tempo
    // fader must not change the master's tempo.
    if (engine.getValue("[Channel" + deck + "]", "sync_enabled") > 0 &&
            Math.round(engine.getValue("[AndroidDJ]", "master_deck")) !== deck) {
        return;
    }
    // The fader sends a lot of messages when it is moved fast (MSB and LSB each): the tempo is
    // set at most every 25 ms (the last position always follows), otherwise the displays and the
    // screen could not keep up (lag, above all in WIDE).
    PioneerDDJFLX10._rateWanted[deck] = PioneerDDJFLX10._sliderRate(deck);
    if (PioneerDDJFLX10._rateTimer[deck]) {
        return;
    }
    PioneerDDJFLX10._applyRate(deck);
};
PioneerDDJFLX10._rateWanted = {1: null, 2: null, 3: null, 4: null};
PioneerDDJFLX10._rateTimer = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._applyRate = function(deck) {
    var wanted = PioneerDDJFLX10._rateWanted[deck];
    if (wanted === null) {
        return;
    }
    PioneerDDJFLX10._rateWanted[deck] = null;
    engine.setValue("[Channel" + deck + "]", "rate", wanted);
    PioneerDDJFLX10._rateTimer[deck] = engine.beginTimer(25, function() {
        PioneerDDJFLX10._rateTimer[deck] = 0;
        PioneerDDJFLX10._applyRate(deck);   // the position that came in meanwhile
    }, true);
};


// ---- Channel faders: the curve of the UTILITY menu ([AndroidDJ] fader_curve: 0 slow start,
// 1 linear, 2 fast start), like the DDJ-FLX4 script. 14 bit: MSB, then LSB.
PioneerDDJFLX10._faderMsb = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._faderLsb = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._applyFader = function(deck) {
    var x = ((PioneerDDJFLX10._faderMsb[deck] << 7) | PioneerDDJFLX10._faderLsb[deck]) / 16383;
    var curve = Math.round(engine.getValue("[AndroidDJ]", "fader_curve"));
    var y = x;
    if (curve === 0) {
        y = x * x;                    // slow start
    } else if (curve === 2) {
        y = Math.min(1, x * 1.6);     // fast start
    }
    // As a parameter (fader position): the volume control has the audio taper of a mixer fader.
    engine.setParameter("[Channel" + deck + "]", "volume", y);
};
PioneerDDJFLX10.channelFaderMSB = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    PioneerDDJFLX10._faderMsb[deck] = value;
    PioneerDDJFLX10._applyFader(deck);   // (not every channel sends the LSB)
};
PioneerDDJFLX10.channelFaderLSB = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    PioneerDDJFLX10._faderLsb[deck] = value;
    PioneerDDJFLX10._applyFader(deck);
};

// ---- LOAD: INSTANT DOUBLES. Pressing LOAD twice quickly loads the track of the other deck of
// the pair (1 + 2, 3 + 4), at the same position (and playing if it plays). A single press
// loads the selected track (and opens the library) only after the time for a second press has
// passed, so that the library does not open at the first press of a double press.
PioneerDDJFLX10._loadPressedAt = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._loadTimer = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10.DOUBLE_LOAD_MS = 350;
PioneerDDJFLX10.loadPressed = function(channel, control, value, status, group) {
    if (!value) {
        return;   // the release: the load is a pulse of its own
    }
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var otherDeck = deck % 2 === 1 ? deck + 1 : deck - 1;
    if (PioneerDDJFLX10._loadTimer[deck]) {
        // the second press: the copy of the other deck replaces the single load
        engine.stopTimer(PioneerDDJFLX10._loadTimer[deck]);
        PioneerDDJFLX10._loadTimer[deck] = 0;
        if (otherDeck <= PioneerDDJFLX10.numDecks &&
                engine.getValue("[Channel" + otherDeck + "]", "track_loaded")) {
            engine.setValue(group, "CloneFromDeck", otherDeck);
        } else {
            PioneerDDJFLX10._loadPulse(group);
        }
        return;
    }
    PioneerDDJFLX10._loadTimer[deck] = engine.beginTimer(PioneerDDJFLX10.DOUBLE_LOAD_MS, function() {
        PioneerDDJFLX10._loadTimer[deck] = 0;
        PioneerDDJFLX10._loadPulse(group);
    }, true);
};
// LOAD as a press that lasts a moment (the screen reads the control when it is told about the
// change: 1 and 0 in the same moment would be seen as 0 only).
PioneerDDJFLX10._loadPulse = function(group) {
    engine.setValue(group, "LoadSelectedTrack", 1);
    engine.beginTimer(120, function() {
        engine.setValue(group, "LoadSelectedTrack", 0);
    }, true);
};

// ---- SHIFT + BEAT SYNC (note 0x5C) makes the deck the MASTER (tempo reference), like rekordbox.
// BEAT SYNC alone is the sync of the deck. The MASTER deck cannot follow itself.
// FLXXX3: SLIP like rekordbox. The engine of Mixxx only jumps to the slip position when slip
// mode is switched OFF; rekordbox keeps slip on and jumps by itself when you let go of the jog
// or leave a loop. So after those moments slip is switched off (the engine jumps) and a moment
// later on again.
PioneerDDJFLX10._slipRejoin = function(group) {
    if (engine.getValue(group, "slip_enabled") <= 0) {
        return;
    }
    engine.setValue(group, "slip_enabled", 0);
    engine.beginTimer(40, function() {
        engine.setValue(group, "slip_enabled", 1);
    }, true);
};

// FLXXX3: BEAT SYNC and SLIP toggle (like rekordbox, the button stays lit). Before they were
// plain controls: the button set the control while pressed and cleared it on release, so a
// short tap did nothing. A deck cannot follow itself: the MASTER deck ignores BEAT SYNC.
PioneerDDJFLX10.syncToggle = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    if (engine.getValue("[AndroidDJ]", "master_deck") === deck) {
        return;
    }
    engine.setValue(group, "sync_enabled", engine.getValue(group, "sync_enabled") > 0 ? 0 : 1);
};
PioneerDDJFLX10.slipToggle = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    engine.setValue(group, "slip_enabled", engine.getValue(group, "slip_enabled") > 0 ? 0 : 1);
};

PioneerDDJFLX10.syncPressed = function(channel, control, value, status, group) {
    if (value > 0) {
        var deck = PioneerDDJFLX10._getDeckFromGroup(group);
        engine.setValue("[AndroidDJ]", "master_deck", deck);
        if (engine.getValue(group, "sync_enabled") > 0) {
            engine.setValue(group, "sync_enabled", 0);
        }
    }
};

// ─── TEMPO RESET button (note 0x41) — hold at 0% ─────────────────────────────
// 1st press (ENGAGE): force tempo to 0% (the track's original BPM) and light
//   the button. While engaged the pitch fader is DISCONNECTED — moving it does
//   nothing to the tempo (see _updateRate) — so you can physically slide the
//   fader back to 0 without the tempo jumping around.
// 2nd press (RELEASE): clear the light and snap the tempo to wherever the fader
//   now physically sits (so if you re-zeroed it, tempo stays at 0% smoothly).
PioneerDDJFLX10._tempoResetEngaged = {1: false, 2: false, 3: false, 4: false};

PioneerDDJFLX10.tempoResetToggle = function(channel, control, value, status, group) {
    if (value === 0) { return; }   // act on press only
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var engaged = !PioneerDDJFLX10._tempoResetEngaged[deck];
    PioneerDDJFLX10._tempoResetEngaged[deck] = engaged;
    if (engaged) {
        engine.setValue(group, "rate", 0.0);                        // hold at 0%
    } else {
        engine.setValue(group, "rate", PioneerDDJFLX10._sliderRate(deck)); // follow fader
    }
    midi.sendShortMsg(status, control, engaged ? 0x7F : 0x00);      // LED on note 0x41
};

// Nudge the active loop's in or out boundary in place (engine samples), without
// moving the playhead. loop_start_position / loop_end_position are writable COs
// that adjust the loop directly (Mixxx clamps to keep in < out). No-op if the
// boundary isn't set (cur < 0).
// FLXXX3: fine jog position from the HID reports (flx10jogscreen.cpp, Windows): a 16 bit
// counter per wheel in [AndroidDJ] hid_jog_left / hid_jog_right. Unlike the MIDI messages of the
// jog (which only come above a minimum speed) it follows the slowest movement. Used to adjust
// the loop boundary.
PioneerDDJFLX10._hidJog = {left: null, right: null};
PioneerDDJFLX10._hidJogSeen = 0;
PioneerDDJFLX10._hidJogMove = function(side, value) {
    var prev = PioneerDDJFLX10._hidJog[side];
    PioneerDDJFLX10._hidJog[side] = value;
    if (prev === null || prev === value) {
        return;
    }
    PioneerDDJFLX10._hidJogSeen = Date.now();
    var delta = value - prev;
    if (delta > 32767) { delta -= 65536; }
    if (delta < -32767) { delta += 65536; }
    var deck = engine.getValue("[AndroidDJ]", side === "left" ? "deck_left" : "deck_right");
    if (!(deck >= 1 && deck <= PioneerDDJFLX10.numDecks)) {
        deck = side === "left" ? 1 : 2;
    }
    if (PioneerDDJFLX10._loopAdjustMode[deck]) {
        PioneerDDJFLX10._nudgeLoop("[Channel" + deck + "]", deck, delta);
    }
};
// true while HID jog reports arrive: then the MIDI messages of the jog do not adjust the loop
// (it would move twice)
PioneerDDJFLX10._hidJogAlive = function() {
    return Date.now() - PioneerDDJFLX10._hidJogSeen < 1000;
};

// FLXXX3: leaves the loop boundary adjust mode (the waveform runs again). Any other action
// resets the view: CUE, SHIFT + CUE, a hot cue, a jump out of the loop.
PioneerDDJFLX10._endLoopAdjust = function(deck) {
    if (PioneerDDJFLX10._loopAdjustMode[deck]) {
        PioneerDDJFLX10._loopAdjustMode[deck] = null;
        PioneerDDJFLX10._renderLoopLeds(deck);
    }
};
PioneerDDJFLX10._checkAdjustExit = function(deck) {
    if (!PioneerDDJFLX10._loopAdjustMode[deck]) {
        return;
    }
    var g = "[Channel" + deck + "]";
    var samples = engine.getValue(g, "track_samples");
    var pos = engine.getValue(g, "playposition") * samples;
    var start = engine.getValue(g, "loop_start_position");
    var end = engine.getValue(g, "loop_end_position");
    var margin = 8192;
    if (!(start >= 0 && end > start) || pos < start - margin || pos > end + margin) {
        PioneerDDJFLX10._endLoopAdjust(deck);
    }
};

PioneerDDJFLX10._loopAdjustAccum = {1: 0, 2: 0, 3: 0, 4: 0};
PioneerDDJFLX10._loopAdjustTimer = 0;
// FLXXX3: the jog sends about 1000 messages per second with +-1..5 intervals (about 12900 per
// turn). The intervals are collected and applied every 25 ms: one interval = LOOP_ADJUST_STEP
// samples, a fast turn (more than 3 intervals per message) moves 3 times as far.
PioneerDDJFLX10._nudgeLoop = function(group, deck, newValue) {
    var gain = Math.abs(newValue) > 3 ? 3 : 1;
    PioneerDDJFLX10._loopAdjustAccum[deck] += newValue * gain;
    if (!PioneerDDJFLX10._loopAdjustTimer) {
        PioneerDDJFLX10._loopAdjustTimer = engine.beginTimer(25, function() {
            var any = false;
            for (var d = 1; d <= PioneerDDJFLX10.numDecks; d++) {
                var ticks = PioneerDDJFLX10._loopAdjustAccum[d];
                var mode = PioneerDDJFLX10._loopAdjustMode[d];
                if (ticks === 0 || !mode) {
                    PioneerDDJFLX10._loopAdjustAccum[d] = 0;
                    continue;
                }
                PioneerDDJFLX10._loopAdjustAccum[d] = 0;
                any = true;
                var g = "[Channel" + d + "]";
                var ctrl = mode === "in" ? "loop_start_position" : "loop_end_position";
                var cur = engine.getValue(g, ctrl);
                if (cur >= 0) {
                    // whole frames (2 samples each)
                    var delta = Math.round(ticks * LOOP_ADJUST_STEP / 2) * 2;
                    if (delta !== 0) {
                        engine.setValue(g, ctrl, cur + delta);
                    } else {
                        // too small for one frame: keep it for the next round
                        PioneerDDJFLX10._loopAdjustAccum[d] = ticks;
                    }
                }
            }
        });
    }
};

// SHIFT + jog (CC 0x1F). In loop-adjust mode it nudges the selected in/out
// boundary; otherwise it scrolls slowly through the track.
PioneerDDJFLX10.wheelSeek = function(channel, control, value, status, group) {
    var newValue = value - 64;
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    if (PioneerDDJFLX10._loopAdjustMode[deck]) {
        if (!PioneerDDJFLX10._hidJogAlive()) {
            PioneerDDJFLX10._nudgeLoop(group, deck, newValue);
        }
        return;
    }
    // FLXXX3: the controller sends CC 0x1F / 0x26 for SHIFT + jog: slow scrolling.
    PioneerDDJFLX10._jogMove(deck, group, newValue * SLOW_SCROLL_FACTOR);
};

// FLXXX3: moves the track like turning the jog, by `ticks` intervals: touched platter =
// scratch (smooth, 1:1 to the platter setting), otherwise the jog of Mixxx (bend while
// playing, search while stopped).
// ADVANCED SETTINGS > JOGWHEEL: sensitivity factors of the jog (top = scratch, side = bend).
PioneerDDJFLX10._jogSens = function(key) {
    var v = engine.getValue("[AndroidDJ]", key);
    return v > 0 ? v : 1;
};
PioneerDDJFLX10._jogMove = function(deck, group, ticks) {
    if (engine.isScratching(deck)) {
        engine.scratchTick(deck, ticks);
    } else {
        engine.setValue(group, "jog", ticks / JOG_BEND_DIVISOR * PioneerDDJFLX10._jogSens("jog_bend_sens"));
    }
};

// FLXXX3: SEARCH keys (0x70 back, 0x71 forward). Held alone they search like before
// (Mixxx back / fwd); turning the jog while one is held (CC 0x29) scrolls fast instead.
PioneerDDJFLX10._searchHeld = {1: null, 2: null, 3: null, 4: null};
PioneerDDJFLX10.searchButton = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var key = control === 0x70 ? "back" : "fwd";
    PioneerDDJFLX10._searchHeld[deck] = value > 0 ? key : null;
    engine.setValue(group, key, value > 0 ? 1 : 0);
};
PioneerDDJFLX10.wheelFastSeek = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var held = PioneerDDJFLX10._searchHeld[deck];
    if (held) {
        engine.setValue(group, held, 0);   // the jog takes over from the key
    }
    PioneerDDJFLX10._jogMove(deck, group, (value - 64) * FAST_SCROLL_FACTOR);
};

// ─── KEY SYNC button (note 0x65) — tap-to-toggle ─────────────────────────────
PioneerDDJFLX10._keySyncEngaged = {1: false, 2: false, 3: false, 4: false};

PioneerDDJFLX10._setKeySyncLed = function(deck, on) {
    midi.sendShortMsg(0x90 + (deck - 1), 0x65, on ? 0x7F : 0x00);
};

PioneerDDJFLX10.keySyncToggle = function(channel, control, value, status, group) {
    if (value === 0) { return; }   // act on press only; ignore the release
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var engaged = !PioneerDDJFLX10._keySyncEngaged[deck];
    PioneerDDJFLX10._keySyncEngaged[deck] = engaged;
    // sync_key / reset_key are edge-triggered: pulse 1 → 0 so a later press
    // can re-fire (setting 1 and leaving it would block the next trigger).
    var key = engaged ? "sync_key" : "reset_key";
    engine.setValue(group, key, 1);
    engine.setValue(group, key, 0);
    PioneerDDJFLX10._setKeySyncLed(deck, engaged);
};

// Shutdown
PioneerDDJFLX10.shutdown = function() {
    console.log("Pioneer DDJ-FLX10 PROD - Arrêt");
    engine.setValue("[AndroidDJ]", "color_fx_quiet", 0);
    if (typeof PioneerDDJFLX10.screen !== "undefined") {
        PioneerDDJFLX10.screen.stop();
    }
    
    // Turn off all LEDs
    for (var i = 1; i <= PioneerDDJFLX10.numDecks; i++) {
        var group = "[Channel" + i + "]";
        midi.sendShortMsg(0x90 + (i-1), 0x00, 0x00); // Cue LED off
        midi.sendShortMsg(0x90 + (i-1), 0x0B, 0x00); // Play LED off
        // Add other LEDs to turn off if needed
    }
};

// Jog Wheel Management
PioneerDDJFLX10._loopAdjustMode = {1: null, 2: null, 3: null, 4: null};

PioneerDDJFLX10.wheelTurn = function(channel, control, value, status, group) {
    var newValue = value - 64;
    var deckNumber = PioneerDDJFLX10._getDeckFromGroup(group);
    // Loop-adjust takes priority so a touched platter nudges the boundary
    // instead of scratching/seeking.
    if (PioneerDDJFLX10._loopAdjustMode[deckNumber]) {
        if (!PioneerDDJFLX10._hidJogAlive()) {
            PioneerDDJFLX10._nudgeLoop(group, deckNumber, newValue);
        }
    } else {
        if (engine.isScratching(deckNumber)) {
            // the last turns (time, ticks) for the speed of the BACK SPIN
            var st = PioneerDDJFLX10._jog[deckNumber];
            st.vel = st.vel * 0.6 + newValue * 0.4;
            st.time = Date.now();
            st.samples.push([st.time, newValue]);
            if (st.samples.length > 30) { st.samples.shift(); }
        }
        PioneerDDJFLX10._jogMove(deckNumber, group, newValue);
    }
};

// VU-meters (LEDs faders)
// FLXXX3: the channel level LEDs show the channel level before the channel fader (like rekordbox,
// fader up or down), in dB.
// vu_meter of Mixxx is measured before the fader, log10(32.767 * mean level + 1), and is at
// its maximum from a mean level of 0.27 (-11 dB) on, so quiet passages lit hardly any LED.
// The scale is rekordbox's (see vuLevel); top LED also when the deck clips.
PioneerDDJFLX10._vuSent = {};
PioneerDDJFLX10._sendVu = function(status, ctrl, value) {
    var v = Math.floor(Math.max(0, Math.min(1, value)) * 127);
    if (PioneerDDJFLX10._vuSent[status] === v) {
        return;
    }
    PioneerDDJFLX10._vuSent[status] = v;
    midi.sendShortMsg(status, ctrl, v);
};
PioneerDDJFLX10.vuLevel = function(deck) {
    var group = "[Channel" + deck + "]";
    var vu = Math.min(1, engine.getValue(group, "vu_meter"));
    var mean = (Math.pow(10, vu) - 1) / 32.767;
    if (!(mean > 0)) {
        return 0;
    }
    if (engine.getValue(group, "peak_indicator") > 0) {
        return 1;
    }
    var db = 20 * Math.log(mean) / Math.LN10;
    // The device lights its 9 LED rows from a value of about 51 on, one row per 7.2 (measured
    // by sending fixed values: 58 = 1 row, 65 = 2, 72 = 3, 90 = 5, 127 = 9). Level scale
    // matched to rekordbox with the TRIM of one deck at 12/11/10/9 o'clock (pre-fader level
    // -14.4/-18.1/-22.5/-28.4 dB, measured in FLXXX3): rekordbox 8-9/6-7/5-6/2 rows,
    // 3.5 per dB, 112 (8.5 rows) at -14.4 dB.
    var level = 112 + (db + 14.4) * 3.5;
    var rows = Math.min(9, Math.round((level - 51) / 7.2));
    if (rows <= 0) {
        return 0;
    }
    return Math.min(127, Math.floor(51 + 7.2 * rows)) / 127;
};
PioneerDDJFLX10.updateVu = function(deck) {
    PioneerDDJFLX10._sendVu(0xB0 + deck - 1, 0x02, PioneerDDJFLX10.vuLevel(deck));
};
PioneerDDJFLX10.LedVuMeterCH1 = function() { PioneerDDJFLX10.updateVu(1); };
PioneerDDJFLX10.LedVuMeterCH2 = function() { PioneerDDJFLX10.updateVu(2); };
PioneerDDJFLX10.LedVuMeterCH3 = function() { PioneerDDJFLX10.updateVu(3); };
PioneerDDJFLX10.LedVuMeterCH4 = function() { PioneerDDJFLX10.updateVu(4); };

// ---- JOGWHEEL settings (menu JOGWHEEL, like the DDJ-FLX4 script) -------------------------
// BACK SPIN: turning the jog fast backwards and letting go spins the track back, then it plays
// on. VINYL SPEED ADJUST: the start and stop time of PLAY (see playButton).
PioneerDDJFLX10._jog = {};
[1, 2, 3, 4].forEach(function(deck) {
    PioneerDDJFLX10._jog[deck] = {vel: 0, time: 0, ramp: 0, wasPlaying: false,
        backspinning: false, coasting: false, speed: 0, samples: [], playRamp: ""};
});

PioneerDDJFLX10._stopJogRamp = function(deck) {
    var state = PioneerDDJFLX10._jog[deck];
    if (state.ramp) {
        engine.stopTimer(state.ramp);
        state.ramp = 0;
    }
};

// Moves the speed of the deck (scratch2) from one rate to another in `seconds`.
PioneerDDJFLX10._rampJogSpeed = function(deck, group, fromRate, toRate, seconds, onDone) {
    var state = PioneerDDJFLX10._jog[deck];
    PioneerDDJFLX10._stopJogRamp(deck);
    var start = Date.now();
    state.ramp = engine.beginTimer(20, function() {
        var progress = seconds <= 0 ? 1 : Math.min(1, (Date.now() - start) / (seconds * 1000));
        state.speed = fromRate + (toRate - fromRate) * progress;
        engine.setValue(group, "scratch2", state.speed);
        if (progress >= 1) {
            PioneerDDJFLX10._stopJogRamp(deck);
            if (onDone) { onDone(); }
        }
    });
};

// BACK SPIN: the platters of the DDJ-FLX10 turn on after they are let go (mechanical, with
// weight), so the back spin needs no simulation: after letting go while turning back fast the
// deck keeps following the wheel (scratch) until it has stopped, then it plays on at its
// normal speed. (BACK SPIN LENGTH / SENSITIVITY of the menu are for the DDJ-FLX4.)
PioneerDDJFLX10.BACKSPIN_MIN_TIMES = 1.5;     // faster than this (times the normal speed, backwards)
PioneerDDJFLX10.BACKSPIN_END_MS = 200;        // the wheel is still when no turn came for this long
PioneerDDJFLX10._endCoasting = function(deck) {
    var state = PioneerDDJFLX10._jog[deck];
    PioneerDDJFLX10._stopJogRamp(deck);
    state.coasting = false;
    if (engine.isScratching(deck)) {
        engine.scratchDisable(deck, false);
    }
};
PioneerDDJFLX10._startCoasting = function(deck) {
    var state = PioneerDDJFLX10._jog[deck];
    state.coasting = true;
    PioneerDDJFLX10._stopJogRamp(deck);
    state.ramp = engine.beginTimer(50, function() {
        // ends when the wheel stands still or turns forward again (the track then plays on)
        var forward = state.samples.length > 0 &&
                state.samples[state.samples.length - 1][1] > 0;
        if (Date.now() - state.time > PioneerDDJFLX10.BACKSPIN_END_MS || forward) {
            PioneerDDJFLX10._endCoasting(deck);
        }
    });
};

// Speed of the jog in the 100 ms before the last tick, in times of the normal speed of the
// wheel (a record at 33 1/3 rpm); negative = backwards.
PioneerDDJFLX10._jogSpeedTimes = function(deck) {
    var samples = PioneerDDJFLX10._jog[deck].samples;
    if (samples.length === 0) { return 0; }
    var last = samples[samples.length - 1][0];
    var ticks = 0;
    for (var i = 0; i < samples.length; i++) {
        if (last - samples[i][0] <= 100) { ticks += samples[i][1]; }
    }
    var normalPerSecond = SCRATCH_INTERVALS_PER_REV / PioneerDDJFLX10._jogSens("jog_scratch_sens") * (100 / 3 / 60);
    return ticks * 10 / normalPerSecond;
};

PioneerDDJFLX10._cancelPlayRamp = function(deck, group) {
    var state = PioneerDDJFLX10._jog[deck];
    if (state.playRamp === "") { return; }
    PioneerDDJFLX10._stopJogRamp(deck);
    state.playRamp = "";
    engine.setValue(group, "scratch2_enable", 0);
};

// VINYL SPEED ADJUST: the time that the deck needs to start up when PLAY starts it (START) and
// to slow down to a standstill when PLAY pauses it (STOP), like a turntable; 0 seconds = off.
PioneerDDJFLX10.playButton = function(channel, control, value, status, group) {
    if (value === 0) { return; } // only the press
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var state = PioneerDDJFLX10._jog[deck];
    var stopSeconds = engine.getValue("[AndroidDJ]", "vinyl_stop_sec");
    var startSeconds = engine.getValue("[AndroidDJ]", "vinyl_start_sec");
    var tempo = engine.getValue(group, "rate_ratio");
    if (state.playRamp === "stop") {
        // pressed again while it slows down: it speeds up again from the speed it has now
        var nowSpeed = state.speed;
        var upSeconds = startSeconds * (tempo > 0 ? Math.max(0, 1 - nowSpeed / tempo) : 1);
        state.playRamp = "start";
        PioneerDDJFLX10._rampJogSpeed(deck, group, nowSpeed, tempo, upSeconds, function() {
            state.playRamp = "";
            engine.setValue(group, "scratch2_enable", 0);
        });
        return;
    }
    if (state.playRamp === "start") {
        // pressed again while it starts up: it slows down again from the speed it has now
        var curSpeed = state.speed;
        var downSeconds = stopSeconds * (tempo > 0 ? Math.max(0, curSpeed / tempo) : 1);
        state.playRamp = "stop";
        PioneerDDJFLX10._rampJogSpeed(deck, group, curSpeed, 0, downSeconds, function() {
            state.playRamp = "";
            engine.setValue(group, "play", 0);
            engine.setValue(group, "scratch2_enable", 0);
        });
        return;
    }
    var rate = engine.getValue(group, "rate_ratio");
    if (engine.getValue(group, "play") > 0) {
        if (stopSeconds > 0 && !engine.isScratching(deck)) {
            state.playRamp = "stop";
            state.speed = rate;
            engine.setValue(group, "scratch2_enable", 1);
            engine.setValue(group, "scratch2", rate);
            PioneerDDJFLX10._rampJogSpeed(deck, group, rate, 0, stopSeconds, function() {
                state.playRamp = "";
                engine.setValue(group, "play", 0);
                engine.setValue(group, "scratch2_enable", 0);
            });
        } else {
            engine.setValue(group, "play", 0);
        }
    } else if (startSeconds > 0 && !engine.isScratching(deck)) {
        state.playRamp = "start";
        state.speed = 0;
        engine.setValue(group, "scratch2_enable", 1);
        engine.setValue(group, "scratch2", 0);
        engine.setValue(group, "play", 1);
        PioneerDDJFLX10._rampJogSpeed(deck, group, 0, rate, startSeconds, function() {
            state.playRamp = "";
            engine.setValue(group, "scratch2_enable", 0);
        });
    } else {
        engine.setValue(group, "play", 1);
    }
};

PioneerDDJFLX10.wheelTouch = function(channel, control, value, status, group) {
    var deckNumber = PioneerDDJFLX10._getDeckFromGroup(group);
    // While adjusting a loop boundary, don't scratch — keep the loop playing.
    if (PioneerDDJFLX10._loopAdjustMode[deckNumber]) {
        return;
    }
    var state = PioneerDDJFLX10._jog[deckNumber];
    if (value === 0x7F) {
        state.vel = 0;
        state.samples = [];
        if (state.coasting) {
            // touching the wheel during a back spin: take over
            PioneerDDJFLX10._endCoasting(deckNumber);
        }
        // touching the jog ends a start or stop ramp of PLAY (the deck keeps playing)
        PioneerDDJFLX10._cancelPlayRamp(deckNumber, group);
        state.wasPlaying = engine.getValue(group, "play") > 0;
        engine.scratchEnable(deckNumber, SCRATCH_INTERVALS_PER_REV / PioneerDDJFLX10._jogSens("jog_scratch_sens"), 33+1/3, JOG_ALPHA, JOG_ALPHA / 32);
    } else {
        if (engine.isScratching(deckNumber) &&
                state.wasPlaying &&
                PioneerDDJFLX10._jogSpeedTimes(deckNumber) < -PioneerDDJFLX10.BACKSPIN_MIN_TIMES &&
                Date.now() - state.time < 120) {
            PioneerDDJFLX10._startCoasting(deckNumber);
            return;
        }
        engine.scratchDisable(deckNumber, false);
        PioneerDDJFLX10._slipRejoin(group);
    }
};

// Beatgrid nudge — triggered by CC 0x26 when Shift+Jog is used.
// Values are relative, centered on 64: below = earlier, above = later.
// Accumulate delta across ticks; fire one step per BEATGRID_THRESHOLD units
// so a slow spin doesn't trigger hundreds of nudges. Raise the threshold to
// slow down, lower it to speed up.
PioneerDDJFLX10._beatgridAccum = {1: 0, 2: 0, 3: 0, 4: 0};
var BEATGRID_THRESHOLD = 6;

// Jog wheel display — output on MIDI channel 16 (0xBF = CC, 0x9F = Note On)
var JOG_DISPLAY_CC   = 0xBF;
var JOG_DISPLAY_NOTE = 0x9F;
var _JOG_MARKER_MSB  = [0x10, 0x11, 0x12, 0x13];
var _JOG_MARKER_LSB  = [0x30, 0x31, 0x32, 0x33];
var _JOG_BPM_MSB     = [0x14, 0x15, 0x16, 0x17];
var _JOG_BPM_LSB     = [0x34, 0x35, 0x36, 0x37];
var _JOG_SPEED_MSB   = [0x18, 0x19, 0x1A, 0x1B];
var _JOG_SPEED_LSB   = [0x38, 0x39, 0x3A, 0x3B];
var _JOG_TIME_MIN    = [0x42, 0x44, 0x46, 0x48];
var _JOG_TIME_SEC    = [0x43, 0x45, 0x47, 0x49];
var _JOG_TIME_MODE   = [0x14, 0x15, 0x16, 0x17]; // Note on 0x9F: 0x00=elapsed, 0x7F=remaining (hardware renders minus sign)

PioneerDDJFLX10.beatgridAdjust = function(channel, control, value, status, group) {
    var delta = value - 64;
    if (delta === 0) return;
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var accum = PioneerDDJFLX10._beatgridAccum[deck];

    // Reset accumulator on direction change to avoid phantom steps
    if ((delta < 0 && accum > 0) || (delta > 0 && accum < 0)) {
        accum = 0;
    }
    accum += delta;

    if (Math.abs(accum) >= BEATGRID_THRESHOLD) {
        var ctrl = accum < 0 ? "beats_translate_earlier" : "beats_translate_later";
        engine.setValue(group, ctrl, 1);
        engine.setValue(group, ctrl, 0);
        accum = 0;
    }
    PioneerDDJFLX10._beatgridAccum[deck] = accum;
};

// Waveform zoom — triggered by Shift+CH rotary (0xB6, CC 0x64).
// Encoder uses two's complement: 1 = CW (zoom in), 127 = CCW (zoom out).
// waveform_zoom=1 is most zoomed in; higher values zoom out. CW decreases value.
// FLXXX3: SHIFT + a BROWSE knob scrolls the track list in big steps (10 tracks per
// click), like SHIFT + BROWSE on the DDJ-FLX4. (Both knobs send the same messages:
// which one was turned is not known, see ROADMAP.)
PioneerDDJFLX10.waveformZoom = function(channel, control, value, _status, _group) {
    var delta = value >= 0x40 ? value - 0x80 : value;
    engine.setValue("[Library]", "MoveVertical", delta * 10);
};

// ─── Jog wheel display ────────────────────────────────────────────────────────
// All data is sent to MIDI channel 16 (0xBF for CC, 0x9F for Note On).
// Protocol sourced from Loui1979 / community reverse-engineering of the FLX10.

// FLXXX3: only values that changed are sent. playposition calls jogMarker on every
// engine cycle; sending each time flooded the MIDI port, so the level LEDs came late
// and jumpy.
PioneerDDJFLX10._jogSent = {};
PioneerDDJFLX10._jogSend14 = function(msbCC, lsbCC, value14) {
    if (PioneerDDJFLX10._jogSent[msbCC] === value14) {
        return;
    }
    PioneerDDJFLX10._jogSent[msbCC] = value14;
    midi.sendShortMsg(JOG_DISPLAY_CC, msbCC, (value14 >> 7) & 0x7F);
    midi.sendShortMsg(JOG_DISPLAY_CC, lsbCC, value14 & 0x7F);
};

// Rotating marker. FLXXX3: one turn per bar (4 beats), like the CDJ: the angle is the
// place in the bar, from the position and the beat grid (one tempo; its first beat
// counts as beat 1 of a bar). Where the grid starts is taken once per track from
// beat_distance (it and the position are not updated at the same moment: taken each time
// the beat number flipped at every beat). Without a beat grid: the place in the track.
PioneerDDJFLX10._gridStart = {};
PioneerDDJFLX10.barPhase = function(group, position) {
    var duration = engine.getValue(group, "duration");
    var bpm = engine.getValue(group, "file_bpm");
    if (!(duration > 0) || !(bpm > 0)) {
        return position;
    }
    var beatLength = 60 / bpm;
    var seconds = position * duration;
    var grid = PioneerDDJFLX10._gridStart[group];
    if (!grid || grid.duration !== duration || grid.bpm !== bpm) {
        var beatStart = seconds - engine.getValue(group, "beat_distance") * beatLength;
        grid = {duration: duration, bpm: bpm,
            start: ((beatStart % beatLength) + beatLength) % beatLength};
        PioneerDDJFLX10._gridStart[group] = grid;
    }
    var beats = (seconds - grid.start) / beatLength;
    var bar = beats / 4;
    return bar - Math.floor(bar);
};
PioneerDDJFLX10.jogMarker = function(value, group, control) {
    var i = PioneerDDJFLX10._getDeckFromGroup(group) - 1;
    var deg = Math.round(PioneerDDJFLX10.barPhase(group, value) * 359);
    if (deg < 0) { deg = 0; }
    if (deg > 359) { deg = 359; }
    PioneerDDJFLX10._jogSend14(_JOG_MARKER_MSB[i], _JOG_MARKER_LSB[i], deg);
};

// BPM display: bpm * 10 as a 14-bit integer
PioneerDDJFLX10.jogBpm = function(value, group, control) {
    var i = PioneerDDJFLX10._getDeckFromGroup(group) - 1;
    var bpm10 = Math.round(value * 10);
    if (bpm10 < 0) { bpm10 = 0; }
    if (bpm10 > 16383) { bpm10 = 16383; }
    PioneerDDJFLX10._jogSend14(_JOG_BPM_MSB[i], _JOG_BPM_LSB[i], bpm10);
};

// Speed display: rate (-1..+1) → centered at 0% → (rate*100+100)*10, 14-bit
PioneerDDJFLX10.jogSpeed = function(value, group, control) {
    var i = PioneerDDJFLX10._getDeckFromGroup(group) - 1;
    var pct10 = Math.round((value * 100 + 100) * 10);
    if (pct10 < 0) { pct10 = 0; }
    if (pct10 > 16383) { pct10 = 16383; }
    PioneerDDJFLX10._jogSend14(_JOG_SPEED_MSB[i], _JOG_SPEED_LSB[i], pct10);
};

// Cache track duration when it changes (new track loaded).
// jogTime reads from this cache instead of calling engine.getValue("duration")
// on every playposition tick, which can return 0 mid-callback on some systems.
PioneerDDJFLX10.jogDuration = function(value, group, control) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    PioneerDDJFLX10._trackDuration[deck] = value;
};

// Time display: minutes and seconds sent as separate single-byte CCs.
// Respects [Controls]/ShowDurationRemaining: 0=elapsed, 1 or 2=remaining.
// value is playposition (0–1) passed directly from the callback — do not re-read it.
PioneerDDJFLX10.jogTime = function(value, group, control) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var i = deck - 1;
    var duration = PioneerDDJFLX10._trackDuration[deck];
    if (!(duration > 0)) { return; }
    var elapsed = value * duration;
    var showRemaining = engine.getValue("[Controls]", "ShowDurationRemaining") !== 0;
    var displayTime = showRemaining ? (duration - elapsed) : elapsed;
    var min = Math.floor(displayTime / 60);
    var sec = Math.floor(displayTime % 60);
    if (min > 127) { min = 127; }
    midi.sendShortMsg(JOG_DISPLAY_CC, _JOG_TIME_MIN[i], min);
    midi.sendShortMsg(JOG_DISPLAY_CC, _JOG_TIME_SEC[i], sec);
};

// Sensitivity functions
PioneerDDJFLX10.sensitivityMinimizer = function (value, factor) {
    return (value/factor);
};

PioneerDDJFLX10.sensitivityMaximizer = function (value, factor) {
    return (value*factor);
};

// ─── Memory cue navigation ───────────────────────────────────────────────────
// FLXXX3: the CALL buttons only call memory cues and memory loops (rekordbox's memory
// cues are hotcue 17..36 in the app, hotcues A..H 1..8), like the DDJ-FLX4 script: a
// memory loop starts its loop, a memory cue only jumps; the called point becomes the CUE.
// MEMORY saves a memory cue in the next free slot of 17..36, DELETE removes the nearest.
var FIRST_MEMORY_CUE = 17;
var LAST_MEMORY_CUE = 36;

PioneerDDJFLX10.memCueSave = function(channel, control, value, status, group) {
    if (value === 0) return;
    for (var i = FIRST_MEMORY_CUE; i <= LAST_MEMORY_CUE; i++) {
        if (!(engine.getValue(group, "hotcue_" + i + "_status") > 0)) {
            engine.setValue(group, "hotcue_" + i + "_set", 1);
            engine.setValue(group, "hotcue_" + i + "_set", 0);
            return;
        }
    }
};

PioneerDDJFLX10.callMemoryCue = function(group, direction) {
    var trackSamples = engine.getValue(group, "track_samples");
    if (!(trackSamples > 0)) {
        return;
    }
    var sampleRate = engine.getValue(group, "track_samplerate") || 44100;
    var now = engine.getValue(group, "playposition") * trackSamples;
    // A quarter of a second: a cue that was just called is not called again.
    var margin = sampleRate * 2 * 0.25;
    var best = -1;
    var bestPosition = 0;
    for (var i = FIRST_MEMORY_CUE; i <= LAST_MEMORY_CUE; i++) {
        if (!(engine.getValue(group, "hotcue_" + i + "_status") > 0)) {
            continue;
        }
        var position = engine.getValue(group, "hotcue_" + i + "_position");
        if (position < 0) {
            continue;
        }
        if (direction < 0 && position < now - margin && (best < 0 || position > bestPosition)) {
            best = i;
            bestPosition = position;
        } else if (direction > 0 && position > now + margin &&
                (best < 0 || position < bestPosition)) {
            best = i;
            bestPosition = position;
        }
    }
    if (best < 0) {
        return;
    }
    var isLoop = engine.getValue(group, "hotcue_" + best + "_type") === 4;
    var key = "hotcue_" + best + (isLoop ? "_gotoandloop" : "_goto");
    engine.setValue(group, key, 1);
    engine.setValue(group, key, 0);
    engine.setValue(group, "cue_point", bestPosition);
};

PioneerDDJFLX10.memCuePrev = function(channel, control, value, status, group) {
    if (value === 0) return;
    PioneerDDJFLX10.callMemoryCue(group, -1);
};

PioneerDDJFLX10.memCueNext = function(channel, control, value, status, group) {
    if (value === 0) return;
    PioneerDDJFLX10.callMemoryCue(group, 1);
};

PioneerDDJFLX10.memCueDelete = function(channel, control, value, status, group) {
    if (value === 0) return;
    var current = engine.getValue(group, "playposition") * engine.getValue(group, "track_samples");
    var best = Infinity, bestCue = -1;
    for (var i = FIRST_MEMORY_CUE; i <= LAST_MEMORY_CUE; i++) {
        if (engine.getValue(group, "hotcue_" + i + "_status") > 0) {
            var dist = Math.abs(engine.getValue(group, "hotcue_" + i + "_position") - current);
            if (dist < best) { best = dist; bestCue = i; }
        }
    }
    if (bestCue > 0) {
        engine.setValue(group, "hotcue_" + bestCue + "_clear", 1);
        engine.setValue(group, "hotcue_" + bestCue + "_clear", 0);
    }
};
// ─────────────────────────────────────────────────────────────────────────────

// FLXXX3: headphones like rekordbox. MASTER CUE off: only the channels with CUE are in the
// headphones (headMix -1). MASTER CUE on: the HEADPHONES MIXING knob mixes CUE and master.
// The knob sends 14 bits (MSB 0x0C, LSB 0x2C); the script keeps its position.
PioneerDDJFLX10.masterCueOn = false;
PioneerDDJFLX10._mixingMsb = 0x40;
PioneerDDJFLX10._mixingLsb = 0;
PioneerDDJFLX10.applyHeadMix = function() {
    var knob = ((PioneerDDJFLX10._mixingMsb << 7) | PioneerDDJFLX10._mixingLsb) / 16383;
    engine.setValue("[Master]", "headMix", PioneerDDJFLX10.masterCueOn ? knob * 2 - 1 : -1);
};
PioneerDDJFLX10.headphonesMixing = function(channel, control, value) {
    if (control === 0x0C) {
        PioneerDDJFLX10._mixingMsb = value;
    } else {
        PioneerDDJFLX10._mixingLsb = value;
    }
    PioneerDDJFLX10.applyHeadMix();
};
PioneerDDJFLX10.masterCue = function(channel, control, value, status) {
    if (value === 0) {
        return;
    }
    PioneerDDJFLX10.masterCueOn = !PioneerDDJFLX10.masterCueOn;
    midi.sendShortMsg(0x96, 0x63, PioneerDDJFLX10.masterCueOn ? 0x7F : 0x00);
    PioneerDDJFLX10.applyHeadMix();
};

// ─── FLXXX3: jog screens over HID ────────────────────────────────────────────
// The jog screens of the DDJ-FLX10 take 128 byte HID reports on interface 5 (the
// app's driver sends them: a SysEx F0 7D 46 48 <report> F7 does not go to the MIDI
// port). Only the rekordbox mode is used (PioneerDDJFLX10.rb below); the Serato mode
// was removed. Protocol after the reverse engineering of Victor Pineda (Veezuhz), notes
// in github.com/Veezuhz/Mixxx_FLX10_Controller_Mapping (README-SCREEN.md); this code is
// written for FLXXX3.
PioneerDDJFLX10.HID_SCREENS = true;
PioneerDDJFLX10.screen = {
    // byte 29: key, by the "key" control of Mixxx (1..12 major C..B, 13..24 minor C..B);
    // 0x80 = no key
    KEY_BYTE: [0x80,
        0x81, 0x83, 0x85, 0x87, 0x89, 0x8b, 0x8d, 0x8f, 0x91, 0x93, 0x95, 0x97,
        0x88, 0x8a, 0x8c, 0x8e, 0x90, 0x92, 0x94, 0x96, 0x98, 0x82, 0x84, 0x86],
    smooth: {},
};

PioneerDDJFLX10.screen.sendReport = function(report) {
    midi.sendSysexMsg([0xF0, 0x7D, 0x46, 0x48].concat(report, [0xF7]), report.length + 5);
};

// Position for the ring pointer, smooth between the updates of the position (they come
// with the audio buffers, the timer of the script not evenly either): moved on with the
// deck's measured speed; a jump (cue, loop, scratch) is taken over at once.
PioneerDDJFLX10.screen.smoothPosition = function(deck, group, duration) {
    var exact = Math.max(0, Math.min(1, engine.getValue(group, "playposition")));
    var now = Date.now();
    var st = this.smooth[deck];
    if (!st || !(duration > 0)) {
        this.smooth[deck] = {pos: exact, at: now, lastExact: exact, lastExactAt: now, speed: 0};
        return exact;
    }
    if (exact !== st.lastExact) {
        // speed in position per ms, from the updates (low pass)
        var dt = now - st.lastExactAt;
        if (dt > 0 && dt < 200) {
            var measured = (exact - st.lastExact) / dt;
            st.speed = st.speed * 0.7 + measured * 0.3;
        } else {
            st.speed = 0;
        }
        st.lastExact = exact;
        st.lastExactAt = now;
    }
    var guess = st.pos + st.speed * (now - st.at);
    // more than 60 ms off: take the exact position
    if (Math.abs(guess - exact) * duration > 0.06) {
        guess = exact;
    } else {
        // pull gently towards the exact position
        guess += (exact - guess) * 0.2;
    }
    if (engine.getValue(group, "play") <= 0 && !engine.isScratching(deck)) {
        guess = exact;
        st.speed = 0;
    }
    st.pos = guess;
    st.at = now;
    return Math.max(0, Math.min(1, guess));
};

// The cue list frames (xx 39, captured bytes with the text "HOT CUE") of a new track.
PioneerDDJFLX10.screen.XX39 = [
    "10390100030000484f54204355450000000000000000000000000000000000000000000000003f00000000" +
    "0000000000000000000000000000000000000000000000000000023f000000000000000000000000000000" +
    "000000000000000000000000000000023f00000000000000000000000000000000000000000000000000",
    "1039020003000000000000023f000000000000000000000000000000000000000000000000000000000000" +
    "023f000000000000000000000000000000000000000000000000000000000000023f000000000000000000" +
    "000000000000000000000000000000000000000000023f00000000000000000000000000000000000000",
    "1039030003000000000000000000000000023f000000000000000000000000000000000000000000000000" +
    "00000000000002000000000000000000000000000000000000000000000000000000000000000000000000" +
    "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
];
PioneerDDJFLX10.screen.zeros = function() {
    var p = [];
    for (var i = 0; i < 128; i++) {
        p[i] = 0;
    }
    return p;
};
// ─── FLXXX3: jog screens in rekordbox mode ───────────────────────────────────
// With the SysEx and reports of rekordbox (from a USB capture, docs/flx10-jog-screens.md)
// the firmware shows its own views (waveform, section, pointer, logo) and switches them
// with SHIFT + PAGE itself. The script sends the deck state (xx 21, about 100 a second),
// the BPM (SysEx) and the reports of a new track; the app uploads the waveform and beat
// grid (F0 7D 46 52 <deck> <rate> F7, flx10jogscreen.cpp).
PioneerDDJFLX10.rb = {
    STATE_MS: 10,
    SYSEX_INIT: [
        "f00040050000040100000b356014010000f7",
        "f00040050000040100000c0000020e0e000000f7",
        "f00040050000040100000a002800260024153255481421000000000000000000000000000000000000000000000000000000000000f7",
        "f000400500000401000301f7",
        "f00040050000040100110f0f0f0f0f0ff7",
        "f00040050000040100120f0f0f0f0f0ff7",
        "f00040050000040100130f0f0f0f0f0ff7",
        "f00040050000040100140f0f0f0f0f0ff7",
        "f00040050000040100000b000000000000f7",
        "f00040050000040100000a002800260026414a242a1026000000000000000000000000000000000000000000000000000000000000f7",
        "f00040050000040100000b315e50010000f7",
        "f00040050000040100000b310000000000f7"
    ],
    KEEPALIVE: [0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x01, 0x00, 0x50, 0x00, 0xF7],
    // MIDI channel 16 (the jog screens) at rekordbox's start, in its order: 9F 70 00 first
    // (right after the first keepalive), then the rest after the SysEx.
    CH16_FIRST: [0x9F, 0x70, 0x00],
    CH16: [[0x9F, 0x40, 0x7F], [0x9F, 0x41, 0x00], [0x9F, 0x42, 0x7F], [0xBF, 0x46, 0x10],
        [0xBF, 0x3E, 0x00], [0x9F, 0x3F, 0x7F], [0xBF, 0x0D, 0x00], [0x9F, 0x00, 0x00],
        [0x9F, 0x24, 0x00], [0x9F, 0x04, 0x00], [0x9F, 0x01, 0x00], [0x9F, 0x25, 0x00],
        [0x9F, 0x05, 0x00], [0x9F, 0x02, 0x00], [0x9F, 0x26, 0x00], [0x9F, 0x06, 0x00],
        [0x9F, 0x03, 0x00], [0x9F, 0x40, 0x7F], [0x9F, 0x41, 0x00], [0x9F, 0x42, 0x7F],
        [0xBF, 0x46, 0x10], [0xBF, 0x3E, 0x00], [0x9F, 0x3F, 0x7F], [0xBF, 0x0D, 0x00]],
    // deck state of rekordbox for an empty and a loaded deck (deck byte and fields set)
    EMPTY: "20210008140100018010000000000000000000000000000000000080000000000000000000000000" +
        "000000ffff000000000000000000000000000000800d",
    LOADED: "1021000a1401000280b40000000300042cac000000a3000000000080000000030000000000000000" +
        "000000ffff000000000000000000000300000100960d",
    XX2D: "102d01000100042cac000a009e2f2701009e2f2701009e2f2701009e2f2701009e2f2701009e2f2701" +
        "009e2f2701009e2f2701009e2f2701009e2f2701",
    timers: [],
    sent: {},
    loaded: {},
    bpmSent: {},
};

PioneerDDJFLX10.rb.report = function(hex, deck) {
    var p = PioneerDDJFLX10.screen.zeros();
    for (var i = 0; i * 2 + 1 < hex.length && i < 128; i++) {
        p[i] = parseInt(hex.substr(i * 2, 2), 16);
    }
    if (deck) {
        p[0] = deck * 0x10;
    }
    return p;
};

// A short report: <deck> <type> 01 00 <b4> 00 ...
PioneerDDJFLX10.rb.small = function(deck, type, b4, seg) {
    var p = PioneerDDJFLX10.screen.zeros();
    p[0] = deck * 0x10;
    p[1] = type;
    p[2] = seg || 1;
    p[4] = b4;
    return p;
};

// Length at the deck's tempo: minutes, seconds, milliseconds (LE16).
PioneerDDJFLX10.rb.lengthBytes = function(deck) {
    var group = "[Channel" + deck + "]";
    var rate = engine.getValue(group, "rate_ratio");
    if (!(rate > 0)) {
        rate = 1;
    }
    var ms = Math.round(engine.getValue(group, "duration") / rate * 1000);
    var sub = ms % 1000;
    return [Math.floor(ms / 60000) & 0xFF, Math.floor(ms / 1000) % 60, sub & 0xFF, sub >> 8];
};

PioneerDDJFLX10.rb.state = function(deck) {
    var self = PioneerDDJFLX10.rb;
    var group = "[Channel" + deck + "]";
    var duration = engine.getValue(group, "duration");
    if (!(duration > 0)) {
        return self.report(self.EMPTY, deck);
    }
    var p = self.report(self.LOADED, deck);
    var rate = engine.getValue(group, "rate_ratio");
    if (!(rate > 0)) {
        rate = 1;
    }
    var master = Math.round(engine.getValue("[AndroidDJ]", "master_deck")) === deck;
    var playing = engine.getValue(group, "play") > 0;
    p[3] = master ? 0x0a : 0x08;
    // bit 7: the MASTER deck playing (rekordbox: a second playing deck has 0x01)
    p[5] = master && playing ? 0x81 : 0x01;
    p[7] = master ? 0x02 : 0x01;
    if (engine.isScratching(deck)) {
        p[2] = 0x02;
        p[3] |= 0x10;
    }
    // smooth between the position updates: the firmware draws the pointer from this time
    var pos = PioneerDDJFLX10.screen.smoothPosition(deck, group, duration);
    var ms = Math.floor(duration * pos / rate * 1000);
    var sub = ms % 1000;
    p[11] = Math.floor(ms / 60000) & 0xFF;
    p[12] = Math.floor(ms / 1000) % 60;
    p[13] = sub & 0xFF;
    p[14] = sub >> 8;
    var length = self.lengthBytes(deck);
    for (var i = 0; i < 4; i++) {
        p[15 + i] = length[i];
    }
    // The key of the track as it is (rekordbox shows it unchanged while the tempo fader moves;
    // the "key" control of Mixxx follows the tempo and flipped between keys).
    var key = engine.getValue(group, "file_key") | 0;
    p[60] = PioneerDDJFLX10.screen.KEY_BYTE[key >= 1 && key <= 24 ? key : 0];
    // Tempo, as rekordbox sends it (read from a capture with moves of the tempo fader):
    // b21 = BPM (whole), b22 = tenth << 4, b23 + 256 * b24 = tempo in 1/100 % (signed),
    // b4 high nibble = tempo range (1 = 6 %, 2 = 10 %, 3 = 16 %, 4 = WIDE).
    var bpm = Math.max(0, engine.getValue(group, "bpm"));
    var whole = Math.min(255, Math.floor(bpm + 1e-6));
    p[21] = whole;
    p[22] = Math.min(9, Math.floor((bpm - whole) * 10 + 1e-6)) << 4;
    var hundredths = Math.max(-32768, Math.min(32767, Math.round((rate - 1) * 10000)));
    if (hundredths < 0) {
        hundredths += 65536;
    }
    p[23] = hundredths & 0xFF;
    p[24] = (hundredths >> 8) & 0xFF;
    var range = engine.getValue(group, "rateRange");
    var rangeCode = range >= 0.99 ? 4 : (range >= 0.15 ? 3 : (range >= 0.09 ? 2 : 1));
    p[4] = (rangeCode << 4) | (p[4] & 0x0F);
    return p;
};

// BPM as rekordbox sends it: x 100 in four nibbles.
PioneerDDJFLX10.rb.nibbles = function(bpm) {
    var v = Math.max(0, Math.min(0xFFFF, Math.round(bpm * 100)));
    return [(v >> 12) & 0x0F, (v >> 8) & 0x0F, (v >> 4) & 0x0F, v & 0x0F];
};
PioneerDDJFLX10.rb.sendBpm = function(deck) {
    var self = PioneerDDJFLX10.rb;
    var bpm = engine.getValue("[Channel" + deck + "]", "bpm");
    var key = Math.round(bpm * 100);
    if (self.bpmSent[deck] === key) {
        return;
    }
    self.bpmSent[deck] = key;
    var n = self.nibbles(bpm);
    var d = [0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x01, 0x00, 0x10 + deck, 0x00, 0x00]
            .concat(n, [0xF7]);
    midi.sendSysexMsg(d, d.length);
    if (Math.round(engine.getValue("[AndroidDJ]", "master_deck")) === deck) {
        var m = [0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x01, 0x00, 0x00, 0x0C, 0x00, 0x00]
                .concat(n, [0x00, 0x00, 0xF7]);
        midi.sendSysexMsg(m, m.length);
    }
};

PioneerDDJFLX10.rb.rateCode = function(deck) {
    var rate = engine.getValue("[Channel" + deck + "]", "rate_ratio");
    // WIDE (+-100 %): the fader end gives the tempo 0 (rate_ratio 0): shown as 0, not as 100 %.
    var v = Math.max(0, Math.min(0x1FFFFF, Math.round((rate >= 0 ? rate : 1) * 10000)));
    return [v & 0x7F, (v >> 7) & 0x7F, (v >> 14) & 0x7F];
};

PioneerDDJFLX10.rb.trackLoaded = function(deck) {
    var self = PioneerDDJFLX10.rb;
    var screen = PioneerDDJFLX10.screen;
    var length = self.lengthBytes(deck);
    var x30 = self.small(deck, 0x30, 0x01);
    for (var i = 0; i < 4; i++) {
        x30[6 + i] = length[i];
    }
    screen.sendReport(x30);
    for (var s = 0; s < screen.XX39.length; s++) {
        screen.sendReport(self.report(screen.XX39[s], deck));
    }
    var x2d = self.report(self.XX2D, deck);
    for (var k = 0; k < 4; k++) {
        x2d[6 + k] = length[k];
    }
    screen.sendReport(x2d);
    for (var b = 1; b <= 5; b++) {
        screen.sendReport(self.small(deck, 0x3b, 0x05, b));
    }
    screen.sendReport(self.small(deck, 0x2b, 0x01));
    screen.sendReport(self.small(deck, 0x33, 0x01));
    self.bpmSent[deck] = undefined;
    self.sendBpm(deck);
    self.upload(deck);
};

// Which parts of the waveform are uploaded (1 overview, 2 beat grid, 4 detail).
PioneerDDJFLX10.rb.UPLOAD_PARTS = 7;
PioneerDDJFLX10.rb.upload = function(deck) {
    if (!PioneerDDJFLX10.rb.UPLOAD_PARTS) {
        return;
    }
    var d = [0xF0, 0x7D, 0x46, 0x52, deck].concat(PioneerDDJFLX10.rb.rateCode(deck),
        [PioneerDDJFLX10.rb.UPLOAD_PARTS, 0xF7]);
    midi.sendSysexMsg(d, d.length);
};

PioneerDDJFLX10.rb.startReports = function() {
    var self = PioneerDDJFLX10.rb;
    var screen = PioneerDDJFLX10.screen;
    for (var deck = 1; deck <= 4; deck++) {
        for (var s = 0; s < screen.XX39.length; s++) {
            screen.sendReport(self.report(screen.XX39[s], deck));
        }
        screen.sendReport(self.small(deck, 0x3e, 0x01));
        for (var seg = 1; seg <= 35; seg++) {
            screen.sendReport(self.small(deck, 0x2c, 0x23, seg));
        }
        screen.sendReport(self.small(deck, 0x2f, 0x01));
        screen.sendReport(self.small(deck, 0x30, 0x01));
        screen.sendReport(self.small(deck, 0x2d, 0x01));
        for (var b = 1; b <= 5; b++) {
            screen.sendReport(self.small(deck, 0x3b, 0x05, b));
        }
        var x3c = self.small(deck, 0x3c, 0x01);
        x3c[6] = 0x09;
        screen.sendReport(x3c);
        screen.sendReport(self.small(deck, 0x2b, 0x01));
        screen.sendReport(self.small(deck, 0x33, 0x01));
        screen.sendReport(self.small(deck, 0x2e, 0x01));
    }
    self.sent = {};
    self.loaded = {};
};

PioneerDDJFLX10.rb.tick = function() {
    var self = PioneerDDJFLX10.rb;
    for (var deck = 1; deck <= 4; deck++) {
        var duration = engine.getValue("[Channel" + deck + "]", "duration");
        if (duration > 0 && self.loaded[deck] !== duration) {
            self.loaded[deck] = duration;
            self.trackLoaded(deck);
        } else if (!(duration > 0)) {
            self.loaded[deck] = 0;
        }
        var p = self.state(deck);
        var key = p.join(",");
        if (self.sent[deck] !== key) {
            self.sent[deck] = key;
            PioneerDDJFLX10.screen.sendReport(p);
        }
    }
};

// Every second: BPM (tempo fader) and the waveform again (once analysed; again at another
// tempo, like rekordbox).
// The waveform of the jog screens is sent again at another tempo, but only when the tempo stood
// still for a moment: while the tempo fader is moved, an upload every second filled the USB
// connection of the controller with screen data and its MIDI messages came late (the tempo
// fader hung, the tempo changed with a delay).
PioneerDDJFLX10.rb.STABLE_MS = 1500;
PioneerDDJFLX10.rb.rateSeen = {};
PioneerDDJFLX10.rb.rateSeenAt = {};
PioneerDDJFLX10.rb.slowTick = function() {
    var self = PioneerDDJFLX10.rb;
    for (var deck = 1; deck <= 4; deck++) {
        if (engine.getValue("[Channel" + deck + "]", "duration") > 0) {
            self.sendBpm(deck);
            var code = Math.round(engine.getValue("[Channel" + deck + "]", "rate_ratio") * 10000);
            if (self.rateSeen[deck] === undefined) {
                self.rateSeen[deck] = code;
                self.rateSeenAt[deck] = 0;
            } else if (self.rateSeen[deck] !== code) {
                self.rateSeen[deck] = code;
                self.rateSeenAt[deck] = Date.now();
            }
            if (Date.now() - self.rateSeenAt[deck] >= self.STABLE_MS) {
                self.upload(deck);
            }
        }
    }
};

PioneerDDJFLX10.rb.handshake = function() {
    var self = PioneerDDJFLX10.rb;
    var hex = function(h) {
        var out = [];
        for (var i = 0; i + 1 < h.length; i += 2) {
            out.push(parseInt(h.substr(i, 2), 16));
        }
        return out;
    };
    midi.sendSysexMsg(self.KEEPALIVE, self.KEEPALIVE.length);
    midi.sendShortMsg(self.CH16_FIRST[0], self.CH16_FIRST[1], self.CH16_FIRST[2]);
    self.SYSEX_INIT.forEach(function(h) {
        var b = hex(h);
        midi.sendSysexMsg(b, b.length);
    });
    self.CH16.forEach(function(m) {
        midi.sendShortMsg(m[0], m[1], m[2]);
    });
};

PioneerDDJFLX10.rb.start = function() {
    var self = PioneerDDJFLX10.rb;
    // The MIDI output may not be open right after the start: again a bit later.
    self.handshake();
    engine.beginTimer(600, function() {
        self.handshake();
        self.startReports();
    }, true);
    engine.beginTimer(1500, function() {
        self.timers.push(engine.beginTimer(self.STATE_MS, self.tick));
        self.timers.push(engine.beginTimer(1000, self.slowTick));
    }, true);
    self.timers.push(engine.beginTimer(200, function() {
        midi.sendSysexMsg(self.KEEPALIVE, self.KEEPALIVE.length);
    }));
};

PioneerDDJFLX10.rb.stop = function() {
    var self = PioneerDDJFLX10.rb;
    for (var i = 0; i < self.timers.length; i++) {
        engine.stopTimer(self.timers[i]);
    }
    self.timers = [];
};

PioneerDDJFLX10.screen.start = function() {
    // Only where the app can send the reports (HID); elsewhere the MIDI jog display.
    if (engine.getValue("[AndroidDJ]", "hid_screens") !== 1) {
        PioneerDDJFLX10.HID_SCREENS = false;
    }
    if (!PioneerDDJFLX10.HID_SCREENS) {
        return;
    }
    PioneerDDJFLX10.rb.start();
};

PioneerDDJFLX10.screen.stop = function() {
    PioneerDDJFLX10.rb.stop();
};

// FLXXX3: DECK 1/3 (left) and 2/4 (right): which deck each side controls, for the screen
// ([AndroidDJ] deck_left / deck_right).
PioneerDDJFLX10.deckSelect = function(channel, control, value, status) {
    if (value === 0) {
        return;
    }
    var deck = (status & 0x0F) + 1;
    engine.setValue("[AndroidDJ]", deck % 2 === 1 ? "deck_left" : "deck_right", deck);
};

PioneerDDJFLX10.queryPositions = function() {
    midi.sendSysexMsg([0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x01, 0x00, 0x03, 0x01, 0xF7], 12);
    // No Serato request (F0 00 20 7F ...): it puts the FLX10 into Serato mode until it
    // is unplugged, and its jog screens then no longer take rekordbox mode.
};

// Shift buttons management
// FLXXX3: which SHIFT is held (deck 1: status 0x90, deck 2: 0x91), also for the app
// ([AndroidDJ] shift_deck: 0 = none, 1 / 2 = that deck), like the DDJ-FLX4 script.
PioneerDDJFLX10.shiftDown = {};
// FLXXX3: pads of BEAT JUMP (notes 0x20..0x27) and BEAT LOOP (0x60..0x67) are lit all the time
// (the device only shows the pads of the selected mode). All other pad modes stay dark.
PioneerDDJFLX10._lightModePads = function() {
    for (var deck = 1; deck <= PioneerDDJFLX10.numDecks; deck++) {
        var status = PioneerDDJFLX10._HOTCUE_STATUS[deck];
        for (var pad = 0; pad < 8; pad++) {
            midi.sendShortMsg(status, 0x20 + pad, 21);   // BEAT JUMP: green
            midi.sendShortMsg(status, 0x60 + pad, 37);   // BEAT LOOP: orange
        }
    }
};

// FLXXX3: PAD MODE buttons (HOT CUE/KEYBOARD 0x1B, PAD FX1/2 0x1E, BEAT JUMP/LOOP 0x20,
// SAMPLER/KEY SHIFT 0x22, with SHIFT 0x69 KEYBOARD, 0x6B PAD FX2, 0x6D BEAT LOOP, 0x6F KEY SHIFT; one status per deck 0x90..0x93). The device only reports the press,
// the app has to light the button.
PioneerDDJFLX10.PAD_MODE_NOTES = [0x1B, 0x1E, 0x20, 0x22, 0x69, 0x6B, 0x6D, 0x6F];
PioneerDDJFLX10.padMode = [0, 0, 0, 0];
PioneerDDJFLX10._showPadMode = function(deckIndex, mode) {
    PioneerDDJFLX10.padMode[deckIndex] = mode;
    for (var i = 0; i < PioneerDDJFLX10.PAD_MODE_NOTES.length; i++) {
        midi.sendShortMsg(0x90 + deckIndex, PioneerDDJFLX10.PAD_MODE_NOTES[i], i === mode ? 0x7F : 0x00);
    }
};
PioneerDDJFLX10.padModeButton = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    var mode = PioneerDDJFLX10.PAD_MODE_NOTES.indexOf(control);
    if (mode >= 0) {
        PioneerDDJFLX10._showPadMode(status & 0x0F, mode);
    }
};

PioneerDDJFLX10.shiftHandler = function(channel, control, value, status, group) {
    PioneerDDJFLX10.shiftDown[(status & 0x0F) + 1] = value === 0x7F;
    PioneerDDJFLX10.shiftActive = PioneerDDJFLX10.shiftDown[1] || PioneerDDJFLX10.shiftDown[2] || false;
    engine.setValue("[AndroidDJ]", "shift_deck",
        PioneerDDJFLX10.shiftDown[1] ? 1 : (PioneerDDJFLX10.shiftDown[2] ? 2 : 0));
    var now = new Date().getTime();
    
    // Detect double-click (within 300ms)
    PioneerDDJFLX10._lastShiftPress = now;
};

// Whether the BeatFX ON button is currently active
PioneerDDJFLX10._beatFxActive = false;
PioneerDDJFLX10._beatFxFadeTimer = 0;

// Last activated preset position (so ON button can re-apply it)
PioneerDDJFLX10._lastPreset = null;


// ─────────────────────────────────────────────────────────────────────────────
// BeatFX pad handler — pad positions 1–14 map directly to the first 14 chain
// presets in Mixxx Preferences → Effects (in list order). Configure your
// presets there to match the 14 BEAT FX labels printed on the controller.
// ─────────────────────────────────────────────────────────────────────────────
// ─── Small display of the Beat FX (name and beat) ────────────────────────────
// Like rekordbox (USB capture 2026-11-24): SysEx F0 00 40 05 00 00 04 01 00 00 0A 00 28 00 26 00
// <name> F7 (name: ASCII bytes behind one zero bit, packed LSB first into 7 bit bytes, padded to 37
// bytes) and F0 00 40 05 00 00 04 01 00 00 0B <beat text> F7 (first character as it is, the rest
// packed like the name, padded to 6 bytes), e.g. "3/4", "1/16", "50%", "+4".
PioneerDDJFLX10._packText = function(text) {
    var bits = [0];
    for (var i = 0; i < text.length; i++) {
        var c = text.charCodeAt(i) & 0xFF;
        for (var b = 0; b < 8; b++) {
            bits.push((c >> b) & 1);
        }
    }
    var out = [];
    for (var k = 0; k < bits.length; k += 7) {
        var v = 0;
        for (var j = 0; j < 7 && k + j < bits.length; j++) {
            v |= bits[k + j] << j;
        }
        out.push(v);
    }
    return out;
};
PioneerDDJFLX10.sendFxName = function(name) {
    var data = PioneerDDJFLX10._packText(name);
    while (data.length < 37) {
        data.push(0);
    }
    var msg = [0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x01, 0x00, 0x00, 0x0A, 0x00, 0x28, 0x00,
        0x26, 0x00].concat(data.slice(0, 37), [0xF7]);
    midi.sendSysexMsg(msg, msg.length);
};
PioneerDDJFLX10.sendFxBeat = function(text) {
    var data = [text.charCodeAt(0) & 0x7F].concat(PioneerDDJFLX10._packText(text.substr(1)));
    while (data.length < 6) {
        data.push(0);
    }
    var msg = [0xF0, 0x00, 0x40, 0x05, 0x00, 0x00, 0x04, 0x01, 0x00, 0x00, 0x0B].concat(
        data.slice(0, 6), [0xF7]);
    midi.sendSysexMsg(msg, msg.length);
};
// Names by effect code (ADVANCED SETTINGS > BEAT FX).
PioneerDDJFLX10._fxNames = [null, "MT DELAY", "ECHO", "PING PONG", "SPIRAL", "HELIX", "REVERB", "FLANGER",
    "PHASER", "TRANS", "FILTER", "LOW CUT ECHO", "ENIGMA JET", "STRETCH", "MOBIUS SAW", "MOBIUS TRI",
    "ROLL", "SLIP ROLL"];
PioneerDDJFLX10._fxCode = 0;
PioneerDDJFLX10._fxBeatTexts = ["1/16", "1/8", "1/4", "1/2", "3/4", "1", "2", "4", "8"];
// Beat text of the effect that is loaded: the time in beats, REVERB in percent, the
// ENIGMA JET and the MOBIUS with a "+" in front (like rekordbox).
// ENIGMA JET and MOBIUS (codes 12, 14, 15): the BEAT keys step through a ring of signed times
// (like rekordbox): the sign is the direction of the sweep, the number the time in beats. BEAT <
// goes along the ring, BEAT > back. At the start: ENIGMA JET -4, MOBIUS SAW +4, MOBIUS TRI -4.
PioneerDDJFLX10._signedRing = [-4, -8, -16, -32, -64, 64, 32, 16, 8, 4, 2, 1, 0.5, 0.25, 0.125, 0.0625,
    -0.0625, -0.125, -0.25, -0.5, -1, -2];
PioneerDDJFLX10._signedStart = {12: -4, 14: 4, 15: -4};
PioneerDDJFLX10._signedIndex = {12: 0, 14: 9, 15: 0};
PioneerDDJFLX10._signedText = function(value) {
    var mag = Math.abs(value);
    var text = mag >= 1 ? String(mag) : "1/" + Math.round(1 / mag);
    return (value < 0 ? "-" : "+") + text;
};
// Gives the effect the time, the range (16 to 64 beats) and the direction of the ring position.
PioneerDDJFLX10._applySigned = function(code) {
    var value = PioneerDDJFLX10._signedRing[PioneerDDJFLX10._signedIndex[code]];
    var mag = Math.abs(value);
    var group = PioneerDDJFLX10._beatFxGroup;
    engine.setParameter(group, "parameter1", Math.min(8, mag) / 8);
    engine.setParameter(group, "parameter4", (Math.max(1, mag / 8) - 1) / 7);
    engine.setParameter(group, "parameter5", value > 0 ? 1 : 0);
    engine.setValue("[AndroidDJ]", "beat_fx_signed", value);
};
PioneerDDJFLX10.fxBeatText = function(code) {
    if (PioneerDDJFLX10._signedIndex[code] !== undefined) {
        return PioneerDDJFLX10._signedText(
            PioneerDDJFLX10._signedRing[PioneerDDJFLX10._signedIndex[code]]);
    }
    var parameter = engine.getParameter(PioneerDDJFLX10._beatFxGroup, "parameter1");
    if (code === 6) {
        return Math.round(parameter * 100) + "%";
    }
    var beats = PioneerDDJFLX10.beatFxBeatValues;
    var current = parameter * 8;
    var nearest = 0;
    for (var i = 1; i < beats.length; i++) {
        if (Math.abs(beats[i] - current) < Math.abs(beats[nearest] - current)) {
            nearest = i;
        }
    }
    var text = PioneerDDJFLX10._fxBeatTexts[nearest];
    return (code === 12 || code === 14 || code === 15) ? "+" + text : text;
};
PioneerDDJFLX10.updateFxDisplay = function(withName) {
    var code = PioneerDDJFLX10._fxCode;
    if (!(code > 0)) {
        return;
    }
    if (withName) {
        PioneerDDJFLX10.sendFxName(PioneerDDJFLX10._fxNames[code] || "");
    }
    PioneerDDJFLX10.sendFxBeat(PioneerDDJFLX10.fxBeatText(code));
};

PioneerDDJFLX10.beatFxPad = function(channel, control, value, status, group) {
    if (value === 0) return;
    var position = control - 0x20 + 1;
    if (position < 1 || position > 14) return;
    engine.setValue("[EffectRack1_EffectUnit1]", "loaded_chain_preset", position);
    PioneerDDJFLX10._lastPreset = position;
};

// Reverse with slip mode management
PioneerDDJFLX10.reverse = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    
    if (value === 0x7F) { // Button pressed
        if (PioneerDDJFLX10.shiftActive) {
            // Toggle current state
            var currentReverse = engine.getValue(group, "reverse") || 0;
            engine.setValue(group, "reverse", currentReverse ? 0 : 1);
            engine.setValue(group, "slip_enabled", 0); // Disable slip mode
        } else {
            // Enable slip mode and reverse
            engine.setValue(group, "slip_enabled", 1);
            engine.setValue(group, "reverse", 1);
            PioneerDDJFLX10._reverseSlipActive[deck] = true;
        }
    } else if (value === 0x00 && PioneerDDJFLX10._reverseSlipActive[deck]) {
        // Button release with slip mode active
        engine.setValue(group, "reverse", 0);
        engine.setValue(group, "slip_enabled", 0);
        PioneerDDJFLX10._reverseSlipActive[deck] = false;
    }
};

// Loop functions with shift support - RESTORED for PROD version
PioneerDDJFLX10.LoopHalveShift = function(channel, control, value, status, group) {
    if (value === 0x7F) {
        if (PioneerDDJFLX10.shiftActive) {
            engine.setValue(group, "loop_halve", 1);
    } else {
            engine.setValue(group, "loop_in", 1);
        }
    }
};

PioneerDDJFLX10.LoopDoubleShift = function(channel, control, value, status, group) {
    if (value === 0x7F) {
        if (PioneerDDJFLX10.shiftActive) {
            engine.setValue(group, "loop_double", 1);
        } else {
            engine.setValue(group, "loop_out", 1);
        }
    }
};

// Rate range selector — like rekordbox: 6 / 10 / 16 % and WIDE (the app takes 1.0 as WIDE).
// The tempo changes at once with the range (the position of the fader x the new range).
PioneerDDJFLX10._rateRanges = [0.06, 0.10, 0.16, 1.0];
PioneerDDJFLX10.RangeSelector = function(channel, control, value, status, group) {
    if (value !== 0x7F) return;
    var current = engine.getValue(group, "rateRange");
    var idx = 0, best = 1e9;
    for (var i = 0; i < PioneerDDJFLX10._rateRanges.length; i++) {
        var d = Math.abs(current - PioneerDDJFLX10._rateRanges[i]);
        if (d < best) { best = d; idx = i; }
    }
    idx = (idx + 1) % PioneerDDJFLX10._rateRanges.length;
    engine.setValue(group, "rateRange", PioneerDDJFLX10._rateRanges[idx]);
    // The app keeps the playing tempo when the range changes: the tempo follows the position of
    // the fader at once (fader position x new range), not only when the fader is moved.
    var rangeDeck = PioneerDDJFLX10._getDeckFromGroup(group);
    if (PioneerDDJFLX10._rateTimer[rangeDeck]) {
        engine.stopTimer(PioneerDDJFLX10._rateTimer[rangeDeck]);
        PioneerDDJFLX10._rateTimer[rangeDeck] = 0;
    }
    PioneerDDJFLX10._updateRate(rangeDeck);
};

// Time display mode management — [Controls]/ShowDurationRemaining: 0=elapsed, 1=remaining, 2=both
PioneerDDJFLX10.TimeTypeChange = function(channel, control, value, status, group) {
    if (value !== 0x7F) { return; }
    var current = engine.getValue("[Controls]", "ShowDurationRemaining");
    var newMode = current === 0 ? 1 : 0;
    engine.setValue("[Controls]", "ShowDurationRemaining", newMode);
    var hwMode = newMode !== 0 ? 0x7F : 0x00;
    for (var d = 0; d < PioneerDDJFLX10.numDecks; d++) {
        midi.sendShortMsg(JOG_DISPLAY_NOTE, _JOG_TIME_MODE[d], hwMode);
    }
};

// ─── HOT CUE pad LEDs ─────────────────────────────────────────────────────────
// Light each hot-cue pad when a hot cue exists at that slot, dark when empty.
// Pads are RGB (value = palette color 1..127, 0x00 = off). Hot-cue mode pads:
//   deck N → status 0x97 + (N-1)*2  (0x97/0x99/0x9B/0x9D), pad P → note (P-1).
// "Light up if it exists" = a fixed color when hotcue_P_enabled; per-cue colors
// would need the FLX10's palette map (future).
PioneerDDJFLX10._HOTCUE_STATUS    = {1: 0x97, 2: 0x99, 3: 0x9B, 4: 0x9D};
PioneerDDJFLX10._HOTCUE_DEFAULT_COLOR = 0x7F;  // pad palette value until we map real colors
PioneerDDJFLX10._HOTCUE_LOOP_TYPE = 4;         // Mixxx CueType::Loop (needs Mixxx 2.4+)
PioneerDDJFLX10._hotcuePhase = false;          // shared blink phase for loop cues
PioneerDDJFLX10._hotcue = {};                  // _hotcue[deck][pad] = {on, loop, color}

// FLX10 hot-cue pad palette (discovered 2026-05-29 via _hotcuePaletteTest).
// The pad value is a HUE WHEEL: value 1 = blue, sweeping teal→green→yellow→
// orange→red→pink→magenta→purple by ~61; values >61 saturate to purple. So we
// map any Mixxx hot-cue color to the palette entry with the nearest hue.
// {v: pad value, h: approximate hue in degrees}
PioneerDDJFLX10._HOTCUE_PALETTE = [
  {v: 1,  h: 240}, // blue
  {v: 5,  h: 228}, // blue
  {v: 9,  h: 216}, // blue
  {v: 13, h: 200}, // blue
  {v: 17, h: 180}, // teal / cyan
  {v: 21, h: 120}, // green
  {v: 25, h: 85},  // green-yellow
  {v: 29, h: 60},  // yellow
  {v: 33, h: 45},  // yellow-orange
  {v: 37, h: 30},  // orange
  {v: 41, h: 0},   // red
  {v: 45, h: 350}, // red-pink
  {v: 49, h: 340}, // light pink
  {v: 53, h: 330}, // pink
  {v: 57, h: 300}, // magenta
  {v: 61, h: 275}  // purple
];

PioneerDDJFLX10._rgbToHue = function(r, g, b){
  r /= 255; g /= 255; b /= 255;
  var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  if (d === 0) { return -1; }   // gray / white: no hue
  var h;
  if (max === r)      { h = ((g - b) / d) % 6; }
  else if (max === g) { h = (b - r) / d + 2; }
  else                { h = (r - g) / d + 4; }
  h *= 60;
  if (h < 0) { h += 360; }
  return h;
};

PioneerDDJFLX10._hueDist = function(a, b){
  var d = Math.abs(a - b) % 360;
  return d > 180 ? 360 - d : d;
};

// Value 127 is the whitest the pads get (faintly pink — there's no pure white
// in this palette). Used for white / near-white / grayscale cues.
PioneerDDJFLX10._HOTCUE_WHITE_VALUE = 127;

// FLXXX3: the hot cue colors of the app are the 16 of rekordbox. The pad value is a
// continuous hue wheel (1 = blue, 3 = light blue, ~9 = turquoise, 21 = green, 29 = yellow,
// 37 = orange, 42 = red, 45 = pink, 61 = purple); the values for blue, light blue and red
// were read off the pads on 2026-11-21, the others follow the hue test above.
// Other colors take the nearest of the 16.
PioneerDDJFLX10._REKORDBOX_HOTCUE_COLORS = [
  0xDE44CF, 0xB432FF, 0xAA72FF, 0x6473FF, 0x305AFF, 0x50B4FF, 0x00E0FF, 0x1FA392,
  0x10B176, 0x28E214, 0xA5E116, 0xB4BE04, 0xC3AF04, 0xE0641B, 0xE62828, 0xFF127B
];
PioneerDDJFLX10._REKORDBOX_PAD_VALUES = [
  55,       60,       61,       1,        1,        3,        9,        15,
  18,       21,       26,       28,       30,       37,       42,       47
];
PioneerDDJFLX10._padValueOfRekordboxColor = function(index){
  return PioneerDDJFLX10._REKORDBOX_PAD_VALUES[index];
};

// Map a Mixxx hot-cue color (integer 0xRRGGBB from hotcue_X_color) to a pad
// palette value. Low-saturation colors (white/gray) → the white value.
PioneerDDJFLX10._hotcueColorToPad = function(rgb){
  if (!(rgb > 0)) { return PioneerDDJFLX10._HOTCUE_WHITE_VALUE; }
  var r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
  var max = Math.max(r, g, b), min = Math.min(r, g, b);
  // Saturation (HSV). Near-white (and Mixxx's faintly-tinted white) has low
  // saturation — treat as white instead of computing a misleading hue.
  var sat = (max === 0) ? 0 : (max - min) / max;
  if (sat < 0.18) { return PioneerDDJFLX10._HOTCUE_WHITE_VALUE; }
  var colors = PioneerDDJFLX10._REKORDBOX_HOTCUE_COLORS;
  var best = 0, bestD = Infinity;
  for (var i = 0; i < colors.length; i++) {
    var dr = r - ((colors[i] >> 16) & 0xFF);
    var dg = g - ((colors[i] >> 8) & 0xFF);
    var db = b - (colors[i] & 0xFF);
    var dist = dr * dr + dg * dg + db * db;
    if (dist < bestD) { bestD = dist; best = i; }
  }
  return PioneerDDJFLX10._padValueOfRekordboxColor(best);
};

PioneerDDJFLX10._hotcueLoopActive = function(deck, pad){
  var g = "[Channel" + deck + "]";
  return engine.getValue(g, "loop_enabled") > 0 &&
      Math.abs(engine.getValue(g, "loop_start_position") -
               engine.getValue(g, "hotcue_" + pad + "_position")) < 2;
};

PioneerDDJFLX10._renderHotcue = function(deck, pad){
  var s = PioneerDDJFLX10._hotcue[deck][pad];
  var val;
  if (!s.on)        { val = 0x00; }                                  // empty → off
  // FLXXX3: a saved loop is lit like a cue and only blinks while it is the active loop.
  else if (s.loop && PioneerDDJFLX10._hotcueLoopActive(deck, pad)) {
    val = PioneerDDJFLX10._hotcuePhase ? s.color : 0x00;
  } else            { val = s.color; }                               // cue / loop → solid
  midi.sendShortMsg(PioneerDDJFLX10._HOTCUE_STATUS[deck], pad - 1, val);
};

// ── PALETTE DISCOVERY ─────────────────────────────────────────────────────
// Set true and reload the mapping to light every pad with a DISTINCT value
// (also logged), so you can report which value = which color. Each pad gets
// value = 1 + index*4 across all 4 decks: deck1 = 1,5,9,…,29; deck2 = 33,…,61;
// deck3 = 65,…,93; deck4 = 97,…,125 (toggle decks to see decks 3/4). Tell me
// the color for the values you can read, then set this back to false.
PioneerDDJFLX10._HOTCUE_PALETTE_TEST = false;

PioneerDDJFLX10._hotcuePaletteTest = function(){
  console.log("FLX10 HOTCUE PALETTE TEST (round 2) — switch pads to HOT CUE mode; report colors:");
  for (var deck = 1; deck <= PioneerDDJFLX10.numDecks; deck++) {
    for (var pad = 1; pad <= 8; pad++) {
      var index = (deck - 1) * 8 + (pad - 1);   // 0..31
      var val = 3 + index * 4;                   // 3,7,11,…,127 (the gaps + the top end)
      midi.sendShortMsg(PioneerDDJFLX10._HOTCUE_STATUS[deck], pad - 1, val);
      console.log("  deck" + deck + " pad" + pad + " -> value " + val +
                  " (0x" + (val < 16 ? "0" : "") + val.toString(16) + ")");
    }
  }
};

PioneerDDJFLX10._initHotcueLeds = function(){
  if (PioneerDDJFLX10._HOTCUE_PALETTE_TEST) {
    PioneerDDJFLX10._hotcuePaletteTest();
    return;   // skip normal hot-cue LED wiring while discovering the palette
  }
  for (var deck = 1; deck <= PioneerDDJFLX10.numDecks; deck++) {
    PioneerDDJFLX10._hotcue[deck] = {};
    (function(deck){
      var g = "[Channel" + deck + "]";
      for (var pad = 1; pad <= 8; pad++) {
        (function(pad){
          PioneerDDJFLX10._hotcue[deck][pad] =
              {on: false, loop: false, color: PioneerDDJFLX10._HOTCUE_DEFAULT_COLOR};
          var s = PioneerDDJFLX10._hotcue[deck][pad];
          var refresh = function(){
            s.on    = engine.getValue(g, "hotcue_" + pad + "_enabled") > 0;
            s.loop  = engine.getValue(g, "hotcue_" + pad + "_type") ===
                      PioneerDDJFLX10._HOTCUE_LOOP_TYPE;
            s.color = PioneerDDJFLX10._hotcueColorToPad(
                          engine.getValue(g, "hotcue_" + pad + "_color"));
            PioneerDDJFLX10._renderHotcue(deck, pad);
          };
          engine.makeConnection(g, "hotcue_" + pad + "_enabled", refresh);
          engine.makeConnection(g, "hotcue_" + pad + "_type",    refresh);
          engine.makeConnection(g, "hotcue_" + pad + "_color",   refresh);
          refresh();   // seed current state at init
        })(pad);
      }
    })(deck);
  }
  // Blink timer — re-renders only the loop hot cues (~1 Hz).
  if (!PioneerDDJFLX10._hotcueBlinkTimer) {
    PioneerDDJFLX10._hotcueBlinkTimer = engine.beginTimer(500, function(){
      PioneerDDJFLX10._hotcuePhase = !PioneerDDJFLX10._hotcuePhase;
      for (var d = 1; d <= PioneerDDJFLX10.numDecks; d++) {
        for (var p = 1; p <= 8; p++) {
          var s = PioneerDDJFLX10._hotcue[d][p];
          if (s.on && s.loop) { PioneerDDJFLX10._renderHotcue(d, p); }
        }
      }
    });
  }
};

// Tempo reset button management
PioneerDDJFLX10.rate_reset = function(channel, control, value, status, group) {
    if (value === 0x7F) {
        engine.setValue(group, "rate_set_default", 1);
        
        // Reset internal values
        var deck = PioneerDDJFLX10._getDeckFromGroup(group);
        PioneerDDJFLX10._rateMSB[deck] = 0x40; // Center value (0x40 = 64)
        PioneerDDJFLX10._rateLSB[deck] = 0x00;
    }
};

// Cue button management
// FLXXX3: SHIFT + PLAY (note 0x47): stutter, play from the cue point.
PioneerDDJFLX10.shiftPlay = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    engine.setValue(group, "cue_gotoandplay", 1);
    engine.setValue(group, "cue_gotoandplay", 0);
};

// FLXXX3: SHIFT + 4 BEAT/EXIT (note 0x50): reloop, starts the last loop again (or leaves it).
PioneerDDJFLX10.shiftLoopExit = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    engine.setValue(group, "reloop_toggle", 1);
    engine.setValue(group, "reloop_toggle", 0);
};

// FLXXX3: SHIFT + QUANTIZE (note 0x68): moves the beat grid so that a beat is on the playhead.
PioneerDDJFLX10.shiftQuantize = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    engine.setValue(group, "beats_translate_curpos", 1);
    engine.setValue(group, "beats_translate_curpos", 0);
};

// FLXXX3: SHIFT + CUE (its own note 0x48) jumps to the start of the track and stops, like rekordbox.
PioneerDDJFLX10.shiftCue = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    PioneerDDJFLX10._endLoopAdjust(PioneerDDJFLX10._getDeckFromGroup(group));
    engine.setValue(group, "start_stop", 1);
    engine.setValue(group, "start_stop", 0);
};

PioneerDDJFLX10.cueButton = function(channel, control, value, status, group) {
    var pressed = (value === 0x7F);
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);

    if (pressed) {
        PioneerDDJFLX10._endLoopAdjust(deck);
        if (PioneerDDJFLX10.shiftActive) {
            // FLXXX3: SHIFT + CUE jumps to the start of the track, like rekordbox (it used to
            // delete the cue point).
            engine.setValue(group, "start", 1);
            engine.setValue(group, "start", 0);
        } else {
            // Cue standard : lecture tant que maintenu
            engine.setValue(group, "cue_default", 1);
        }
        PioneerDDJFLX10._cuePressed[deck] = true;
    } else if (!PioneerDDJFLX10.shiftActive) {
        // Relâchement : stop/retour au point cue
        engine.setValue(group, "cue_default", 0);
        PioneerDDJFLX10._cuePressed[deck] = false;
    } else {
        PioneerDDJFLX10._cuePressed[deck] = false;
    }
    PioneerDDJFLX10._updatePlayCueLEDs(group);
};

// Pilotage Play/Cue LEDs façon Pioneer (blink en pause sur cue)
PioneerDDJFLX10._sendPlayCue = function(deck, note, on) {
    var status = 0x90 + (deck - 1);
    midi.sendShortMsg(status, note, on ? 0x7F : 0x00);
};

PioneerDDJFLX10._updatePlayCueLEDs = function(group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var playing = engine.getValue(group, "play") > 0;
    var cueLit = engine.getValue(group, "cue_indicator") > 0;
    var cuePressed = PioneerDDJFLX10._cuePressed[deck];
    var hasTrack = engine.getValue(group, "track_samples") > 0;
    var atEnd = engine.getValue(group, "playposition") >= 0.999;

    // Modes :
    // - playing : Play ON, Cue OFF
    // - cuePressed : Cue ON fixe, Play OFF
    // - pause avec piste chargée (standby) : Play blink, Cue OFF
    // - fin de piste / pas de piste : tout OFF
    if (playing) {
        PioneerDDJFLX10._playCueShouldBlink[deck] = false;
        PioneerDDJFLX10._playShouldBlink[deck] = false;
        PioneerDDJFLX10._playCueBlinkState[deck] = false;
        PioneerDDJFLX10._sendPlayCue(deck, 0x0B, true);
        PioneerDDJFLX10._sendPlayCue(deck, 0x0C, false);
    } else if (cuePressed) {
        PioneerDDJFLX10._playCueShouldBlink[deck] = false;
        PioneerDDJFLX10._playShouldBlink[deck] = false;
        PioneerDDJFLX10._playCueBlinkState[deck] = false;
        PioneerDDJFLX10._sendPlayCue(deck, 0x0B, false);
        PioneerDDJFLX10._sendPlayCue(deck, 0x0C, true);
    } else if (hasTrack && !atEnd) {
        // Standby : Play blink, Cue off
        PioneerDDJFLX10._playCueShouldBlink[deck] = false;
        PioneerDDJFLX10._playShouldBlink[deck] = true;
    } else {
        PioneerDDJFLX10._playCueShouldBlink[deck] = false;
        PioneerDDJFLX10._playShouldBlink[deck] = false;
        PioneerDDJFLX10._playCueBlinkState[deck] = false;
        PioneerDDJFLX10._sendPlayCue(deck, 0x0B, false);
        PioneerDDJFLX10._sendPlayCue(deck, 0x0C, false);
    }
};

PioneerDDJFLX10._startPlayCueBlink = function(deck) {
    // Blink period ~ 500ms (2 Hz)
    PioneerDDJFLX10._playCueBlinkTimer[deck] = engine.beginTimer(500, function() {
        // Priorité au blink Play (standby). Si non, blink Cue (rarement utilisé ici).
        if (PioneerDDJFLX10._playShouldBlink[deck]) {
            PioneerDDJFLX10._playCueBlinkState[deck] = !PioneerDDJFLX10._playCueBlinkState[deck];
            PioneerDDJFLX10._sendPlayCue(deck, 0x0B, PioneerDDJFLX10._playCueBlinkState[deck]);
            PioneerDDJFLX10._sendPlayCue(deck, 0x0C, false);
            return;
        }
        if (PioneerDDJFLX10._playCueShouldBlink[deck]) {
            PioneerDDJFLX10._playCueBlinkState[deck] = !PioneerDDJFLX10._playCueBlinkState[deck];
            PioneerDDJFLX10._sendPlayCue(deck, 0x0B, false);
            PioneerDDJFLX10._sendPlayCue(deck, 0x0C, PioneerDDJFLX10._playCueBlinkState[deck]);
            return;
        }
        // Sinon: rien ne clignote
        PioneerDDJFLX10._playCueBlinkState[deck] = false;
        PioneerDDJFLX10._sendPlayCue(deck, 0x0B, false);
        PioneerDDJFLX10._sendPlayCue(deck, 0x0C, false);
    });
};

PioneerDDJFLX10._stopPlayCueBlink = function(deck) {
    if (PioneerDDJFLX10._playCueBlinkTimer[deck]) {
        engine.stopTimer(PioneerDDJFLX10._playCueBlinkTimer[deck]);
        PioneerDDJFLX10._playCueBlinkTimer[deck] = null;
    }
    PioneerDDJFLX10._playCueBlinkState[deck] = false;
    PioneerDDJFLX10._playCueShouldBlink[deck] = false;
};

// === Advanced Pioneer-like LED policy (Hotfix A) ===
PioneerDDJFLX10._adv = PioneerDDJFLX10._adv || {
  1:{play:0,cue:0,hold:false,phase:false},
  2:{play:0,cue:0,hold:false,phase:false},
  3:{play:0,cue:0,hold:false,phase:false},
  4:{play:0,cue:0,hold:false,phase:false},
};

PioneerDDJFLX10._noteStatus = PioneerDDJFLX10._noteStatus || (function(d){ return 0x90 + (d-1); });
PioneerDDJFLX10._sendLed = PioneerDDJFLX10._sendLed || function(d, note, on) {
    midi.sendShortMsg(PioneerDDJFLX10._noteStatus(d), note, on ? 0x7F : 0x00);
};

PioneerDDJFLX10._onCueHold = function(deck, pressed){
  PioneerDDJFLX10._adv[deck].hold = !!pressed;
  PioneerDDJFLX10._renderAdvanced(deck);
};

PioneerDDJFLX10._renderAdvanced = function(deck){
  var st = PioneerDDJFLX10._adv[deck];
  var playOn=0, cueOn=0;

  if (st.play) {
    playOn = 1;
    cueOn  = st.hold ? 1 : 0;
  } else {
    if (st.hold) {
      playOn = 0; cueOn = 1;
    } else if (st.cue) {
      playOn = st.phase ? 1 : 0;
      cueOn  = st.phase ? 0 : 1;
    } else {
      playOn = 0; cueOn = 0;
    }
  }

  PioneerDDJFLX10._sendLed(deck, 0x0B, playOn);
  PioneerDDJFLX10._sendLed(deck, 0x0C, cueOn);
};

PioneerDDJFLX10._connectAdvanced = function(deck){
  var g = "[Channel"+deck+"]";
  engine.makeConnection(g, "play_indicator", function(v){
    PioneerDDJFLX10._adv[deck].play = (v>=0.5)?1:0;
    PioneerDDJFLX10._renderAdvanced(deck);
  });
  engine.makeConnection(g, "cue_indicator", function(v){
    PioneerDDJFLX10._adv[deck].cue = (v>=0.5)?1:0;
    PioneerDDJFLX10._renderAdvanced(deck);
  });
};

if (!PioneerDDJFLX10._advTimer) {
  PioneerDDJFLX10._advTimer = engine.beginTimer(500, function(){
    PioneerDDJFLX10.deckNumbers().forEach(function(d){
      PioneerDDJFLX10._adv[d].phase = !PioneerDDJFLX10._adv[d].phase;
      PioneerDDJFLX10._renderAdvanced(d);
    });
  });
}

(function(){
  var _cue = PioneerDDJFLX10.cueButton;
  PioneerDDJFLX10.cueButton = function(ch, ctl, val, st, group){
    var m = /\[Channel(\d)\]/.exec(group||""); var deck = m ? parseInt(m[1],10) : 0;
    if (deck) PioneerDDJFLX10._onCueHold(deck, val>0);
    if (typeof _cue === "function") return _cue(ch, ctl, val, st, group);
  };
})();

PioneerDDJFLX10._initAdvancedLeds = PioneerDDJFLX10._initAdvancedLeds || function(){
  PioneerDDJFLX10.deckNumbers().forEach(PioneerDDJFLX10._connectAdvanced);
};

// ─────────────────────────────────────────────────────────────────────────────
// BeatFX Effect Scanner (diagnostic tool)
//
// Press SHIFT + BeatFX ON button to start the scan.
// Open Developer Tools → Log tab and watch the FX panel at the same time.
// Every 2.5 seconds a new effect loads and its index is printed to the log.
// Write down which effect name in the FX panel matches each index number.
// Press SHIFT + BeatFX ON again to stop early.
// ─────────────────────────────────────────────────────────────────────────────
PioneerDDJFLX10._scanIdx = 0;
PioneerDDJFLX10._scanTimer = null;

PioneerDDJFLX10._beatFxScanStart = function() {
    if (PioneerDDJFLX10._scanTimer) {
        engine.stopTimer(PioneerDDJFLX10._scanTimer);
        PioneerDDJFLX10._scanTimer = null;
        console.log("BeatFX Scan: stopped.");
        return;
    }
    var g = "[EffectRack1_EffectUnit1_Effect1]";
    for (var i = 0; i < 30; i++) { engine.setValue(g, "effect_selector", -1); }
    PioneerDDJFLX10._scanIdx = 0;
    console.log("BeatFX Scan: started — watch this Log tab + the FX panel");
    console.log("BeatFX Scan: Index 0");

    PioneerDDJFLX10._scanTimer = engine.beginTimer(2500, function() {
        PioneerDDJFLX10._scanIdx++;
        engine.setValue("[EffectRack1_EffectUnit1_Effect1]", "effect_selector", 1);
        console.log("BeatFX Scan: Index " + PioneerDDJFLX10._scanIdx);
        if (PioneerDDJFLX10._scanIdx >= 25) {
            engine.stopTimer(PioneerDDJFLX10._scanTimer);
            PioneerDDJFLX10._scanTimer = null;
            console.log("BeatFX Scan: complete.");
        }
    });
};

// Key Sync handler (protégé par SHIFT)
PioneerDDJFLX10.syncKeyHandler = function(channel, control, value, status, group) {
    if (value !== 0x7F) return;
    if (PioneerDDJFLX10.shiftActive) return; // ignore si SHIFT
    engine.setValue(group, "key_sync", 1);
};

// BeatFX ON/OFF — toggles the 3 effect slots on/off.
// SHIFT + ON/OFF triggers the effect index scan (prints to Log tab).
PioneerDDJFLX10.beatFxOnOff = function(channel, control, value, status, group) {
    // In non-Serato mode this button is a PULSE: a single press fires a Note ON
    // immediately followed by a Note OFF. Toggle on the press (Note ON) and
    // ignore the release (Note OFF), so one press = one on/off change instead of
    // flashing on then straight back off. (The 2.6/Serato mapping uses a
    // hold-to-activate variant because there the button is a true momentary.)
    if (value === 0) return;
    if (PioneerDDJFLX10.shiftActive) {
        PioneerDDJFLX10._beatFxScanStart();
        return;
    }
    PioneerDDJFLX10._beatFxActive = !PioneerDDJFLX10._beatFxActive;
    var on = PioneerDDJFLX10._beatFxActive;
    for (var slot = 1; slot <= 3; slot++) {
        engine.setValue("[EffectRack1_EffectUnit1_Effect" + slot + "]", "enabled", on ? 1 : 0);
        if (on) {
            engine.setValue("[EffectRack1_EffectUnit1_Effect" + slot + "]", "mix", 1.0);
        }
    }
};

// BeatFX channel routing — exclusive: selecting one group clears the others.
// NOTE: notes 0x10-0x16 on 0x93 may conflict with existing CH4 loop/transport
// mappings. Verify by pressing deck 4 Loop In and checking which MIDI note fires.
PioneerDDJFLX10._beatFxRouteGroups = ["[Channel1]", "[Channel2]", "[Channel3]", "[Channel4]", "[Master]", "[Microphone]"];

PioneerDDJFLX10._beatFxNoteToGroup = {
    0x10: "[Channel1]",
    0x11: "[Channel2]",
    0x12: "[Channel3]",
    0x13: "[Channel4]",
    0x14: "[Master]",
    0x15: "[Microphone]",
    0x16: null,          // SP — no direct Mixxx group equivalent
};

PioneerDDJFLX10.beatFxChannelSelect = function(channel, control, value, status, group) {
    if (value === 0) return;
    var target = PioneerDDJFLX10._beatFxNoteToGroup[control];
    var groups = PioneerDDJFLX10._beatFxRouteGroups;
    for (var i = 0; i < groups.length; i++) {
        engine.setValue("[EffectRack1_EffectUnit1]", "group_" + groups[i] + "_enable", 0);
    }
    if (target) {
        engine.setValue("[EffectRack1_EffectUnit1]", "group_" + target + "_enable", 1);
    }
};

// Crossfader assign — A (left), THRU (center), B (right) per channel.
// orientation: 0=A, 1=THRU, 2=B
PioneerDDJFLX10._crossfaderNoteToOrientation = {
    0x16: 0,  // A
    0x1D: 1,  // THRU
    0x18: 2   // B
};

PioneerDDJFLX10.crossfaderAssign = function(channel, control, value, status, group) {
    if (value === 0) return;
    var orientation = PioneerDDJFLX10._crossfaderNoteToOrientation[control];
    if (orientation !== undefined) {
        engine.setValue(group, "orientation", orientation);
    }
};

// Sound Color FX — exclusive toggle across all 4 channels via QuickEffect.
// Preset indices match the "Quick Effect Chain Presets" list order in Mixxx settings.
PioneerDDJFLX10._colorFxActive = -1;
PioneerDDJFLX10._colorFxChannels = ["[Channel1]", "[Channel2]", "[Channel3]", "[Channel4]"];
PioneerDDJFLX10._colorFxNoteToPreset = {
    0: 17,  // Space   → Reverb
    1: 10,  // D. Echo → Echo
    2: 8,   // Crush   → Bitcrusher
    3: 16,  // Pitch   → Pitch Shift
    4: 19,  // Noise   → White Noise
    5: 11   // Filter  → Filter
};

// The LEDs of the six Color FX keys (notes 0x00..0x05 on status 0x96) keep their state over a restart
// of the app: the key of the running Color FX blinks (0x7F), the others stay lit (0x00); the state
// is sent again a few times after the start.
PioneerDDJFLX10._colorFxLeds = [-1, -1, -1, -1, -1, -1];
PioneerDDJFLX10.renderColorFxLeds = function(force) {
    var on = engine.getValue("[AndroidDJ]", "color_fx_on") > 0;
    var selected = Math.round(engine.getValue("[AndroidDJ]", "color_fx"));
    for (var i = 0; i < 6; i++) {
        var value = (on && i === selected) ? 0x7F : 0x00;
        if (force || PioneerDDJFLX10._colorFxLeds[i] !== value) {
            PioneerDDJFLX10._colorFxLeds[i] = value;
            midi.sendShortMsg(0x96, i, value);
        }
    }
};
PioneerDDJFLX10.soundColorFx = function(channel, control, value, status, group) {
    var channels = PioneerDDJFLX10._colorFxChannels;
    var i;
    // One Sound Color FX selector shared by all decks. Radio-style latching
    // buttons: Note ON = preset selected, Note OFF = preset deselected. Switching
    // A→B sends A's Note OFF then B's Note ON, so the Note-OFF handler only acts
    // when that preset is STILL the active one — otherwise A's off would wipe the
    // B load that just happened. A lone Note OFF (deselect) loads the empty
    // '----' preset (index 0 = "no effect") on all decks, so the FX shows nothing.
    var on = ((status & 0xF0) === 0x90) && (value > 0);
    if (!on) {
        if (PioneerDDJFLX10._colorFxActive === control) {
            for (i = 0; i < channels.length; i++) {
                engine.setValue("[QuickEffectRack1_" + channels[i] + "]", "loaded_chain_preset", 0);
            }
            PioneerDDJFLX10._colorFxActive = -1;
        }
    } else {
        var preset = PioneerDDJFLX10._colorFxNoteToPreset[control];
        for (i = 0; i < channels.length; i++) {
            engine.setValue("[QuickEffectRack1_" + channels[i] + "]", "loaded_chain_preset", preset);
            engine.setValue("[QuickEffectRack1_" + channels[i] + "_Effect1]", "enabled", 1);
            // Block each channel's knob immediately with a sentinel that no physical
            // position can match, preventing any jump before the preset settles.
            PioneerDDJFLX10._colorFxSoftTakeover[i + 1] = true;
            PioneerDDJFLX10._colorFxSoftTakeoverTarget[i + 1] = -1;
        }
        // After 50 ms read each channel's actual settled super1 as the takeover target.
        var chSnapshot = channels.slice();
        engine.beginTimer(50, function() {
            for (var j = 0; j < chSnapshot.length; j++) {
                PioneerDDJFLX10._colorFxSoftTakeoverTarget[j + 1] = engine.getValue(
                    "[QuickEffectRack1_" + chSnapshot[j] + "]", "super1"
                );
            }
        }, true);
        PioneerDDJFLX10._colorFxActive = control;
    }
};

// Sound Color FX intensity knob — 14-bit absolute encoder, per-channel state.
// CC 0x17 (MSB) arrives first; CC 0x37 (LSB) completes the pair and drives the write.
// Keyed by deck number (1–4).
PioneerDDJFLX10._colorFxKnobMSB      = {1: 63,   2: 63,   3: 63,   4: 63};
PioneerDDJFLX10._colorFxKnobPosition = {1: 0.5,  2: 0.5,  3: 0.5,  4: 0.5};
PioneerDDJFLX10._colorFxSoftTakeover = {1: false, 2: false, 3: false, 4: false};
PioneerDDJFLX10._colorFxSoftTakeoverTarget = {1: -1, 2: -1, 3: -1, 4: -1};

PioneerDDJFLX10.soundColorFxKnobMSB = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    PioneerDDJFLX10._colorFxKnobMSB[deck] = value;
};

PioneerDDJFLX10.soundColorFxKnobLSB = function(channel, control, value, status, group) {
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    var position = (PioneerDDJFLX10._colorFxKnobMSB[deck] * 128 + value) / 16383.0;
    var prev = PioneerDDJFLX10._colorFxKnobPosition[deck];
    PioneerDDJFLX10._colorFxKnobPosition[deck] = position;

    if (PioneerDDJFLX10._colorFxSoftTakeover[deck]) {
        var target = PioneerDDJFLX10._colorFxSoftTakeoverTarget[deck];
        if ((prev <= target && position >= target) || (prev >= target && position <= target)) {
            PioneerDDJFLX10._colorFxSoftTakeover[deck] = false;
        } else {
            return;
        }
    }

    engine.setValue("[QuickEffectRack1_[Channel" + deck + "]]", "super1", position);
};

// Loop In / Halve and Loop Out / Double.
// If a loop is already active: halve (In button) or double (Out button).
// If no loop is active: set loop_in or loop_out as normal.
PioneerDDJFLX10.loopInOrHalve = function(channel, control, value, status, group) {
    if (value === 0) return;
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    if (PioneerDDJFLX10._loopAdjustMode[deck]) {
        PioneerDDJFLX10._loopAdjustMode[deck] = null;
        PioneerDDJFLX10._renderLoopLeds(deck);
        return;
    }
    var key = engine.getValue(group, "loop_enabled") ? "loop_halve" : "loop_in";
    if (key === "loop_in") {
        // A loop end that is left from an earlier loop would make IN start a loop at once
        // (when the new start lies before it): IN only sets the start (-1 = no end).
        engine.setValue(group, "loop_end_position", -1);
    }
    engine.setValue(group, key, 1);
    engine.setValue(group, key, 0);
};

PioneerDDJFLX10.loopOutOrDouble = function(channel, control, value, status, group) {
    if (value === 0) return;
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    if (PioneerDDJFLX10._loopAdjustMode[deck]) {
        PioneerDDJFLX10._loopAdjustMode[deck] = null;
        PioneerDDJFLX10._renderLoopLeds(deck);
        return;
    }
    var key = engine.getValue(group, "loop_enabled") ? "loop_double" : "loop_out";
    engine.setValue(group, key, 1);
    engine.setValue(group, key, 0);
};

// Loop point adjust mode — entered via Shift+LoopIn (0x4C) or Shift+LoopOut (0x4D).
// While active, the jog wheel moves the selected loop point by seeking the playhead
// and re-stamping loop_in / loop_out at the new position. Press again to exit.
PioneerDDJFLX10.loopInAdjust = function(channel, control, value, status, group) {
    if (value === 0) return;
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    PioneerDDJFLX10._loopAdjustMode[deck] = PioneerDDJFLX10._loopAdjustMode[deck] === "in" ? null : "in";
    PioneerDDJFLX10._renderLoopLeds(deck);
};

PioneerDDJFLX10.loopOutAdjust = function(channel, control, value, status, group) {
    if (value === 0) return;
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    // With no active loop this button reloops the last stored loop (matches
    // Serato's out-adjust button). While looping it toggles jog out-adjust mode.
    if (engine.getValue(group, "loop_enabled") <= 0) {
        engine.setValue(group, "reloop_toggle", 1);
        engine.setValue(group, "reloop_toggle", 0);
        return;
    }
    PioneerDDJFLX10._loopAdjustMode[deck] = PioneerDDJFLX10._loopAdjustMode[deck] === "out" ? null : "out";
    PioneerDDJFLX10._renderLoopLeds(deck);
};

// ─── Sampler pad LEDs ────────────────────────────────────────────────────────
// Deck-1 pad channel (status 0x97), notes 0x30-0x37 = Sampler1-8 in sampler pad
// mode. Lit when a sampler has a track loaded; blinks while it is playing.
PioneerDDJFLX10._SAMPLER_STATUS = 0x97;
PioneerDDJFLX10._SAMPLER_BASE_NOTE = 0x30;
PioneerDDJFLX10._SAMPLER_COUNT = 8;
PioneerDDJFLX10._samplerBlinkPhase = false;
var SAMPLER_BLINK_MS = 300;

PioneerDDJFLX10._renderSamplerLed = function(n) {   // n = 1..8
    var group = "[Sampler" + n + "]";
    var loaded = engine.getValue(group, "track_loaded") > 0;
    var playing = engine.getValue(group, "play") > 0;
    var val;
    if (!loaded)      { val = 0x00; }                                             // empty → off
    else if (playing) { val = PioneerDDJFLX10._samplerBlinkPhase ? 0x7F : 0x00; } // playing → blink
    else              { val = 0x7F; }                                             // loaded → solid
    midi.sendShortMsg(PioneerDDJFLX10._SAMPLER_STATUS,
                      PioneerDDJFLX10._SAMPLER_BASE_NOTE + (n - 1), val);
};

PioneerDDJFLX10._samplerIsBlinking = function(n) {
    var group = "[Sampler" + n + "]";
    return engine.getValue(group, "track_loaded") > 0 && engine.getValue(group, "play") > 0;
};

PioneerDDJFLX10._initSamplerLeds = function() {
    for (var n = 1; n <= PioneerDDJFLX10._SAMPLER_COUNT; n++) {
        (function(s){
            var g = "[Sampler" + s + "]";
            var refresh = function(){ PioneerDDJFLX10._renderSamplerLed(s); };
            engine.makeConnection(g, "track_loaded", refresh);
            engine.makeConnection(g, "play",         refresh);
            refresh();   // seed current state
        })(n);
    }
    if (!PioneerDDJFLX10._samplerBlinkTimer) {
        PioneerDDJFLX10._samplerBlinkTimer = engine.beginTimer(SAMPLER_BLINK_MS, function(){
            PioneerDDJFLX10._samplerBlinkPhase = !PioneerDDJFLX10._samplerBlinkPhase;
            for (var s = 1; s <= PioneerDDJFLX10._SAMPLER_COUNT; s++) {
                if (PioneerDDJFLX10._samplerIsBlinking(s)) {
                    PioneerDDJFLX10._renderSamplerLed(s);
                }
            }
        });
    }
};

// ─── EQ kill switches (repurposed STEM buttons) ─────────────────────────────
// The FLX10's per-deck STEM buttons (Drums/Vocal/Inst — notes 0x0D/0x0E/0x0F)
// are useless without stem separation, so map them to LOW / MID / HIGH EQ kills.
// Default = band ON (LED lit). Press toggles: kill that band (LED off) / restore.
// Kills live on [EqualizerRack1_[ChannelN]_Effect1] button_parameterN
// (1 = Low, 2 = Mid, 3 = High); value 1 = killed.
PioneerDDJFLX10._EQ_KILL = [
    {note: 0x0D, param: "button_parameter1"},  // Low
    {note: 0x0E, param: "button_parameter2"},  // Mid
    {note: 0x0F, param: "button_parameter3"}   // High
];
PioneerDDJFLX10._eqGroup = function(deck) {
    return "[EqualizerRack1_[Channel" + deck + "]_Effect1]";
};
PioneerDDJFLX10._renderEqKillLed = function(deck, idx) {
    var killed = engine.getValue(PioneerDDJFLX10._eqGroup(deck),
                                 PioneerDDJFLX10._EQ_KILL[idx].param) > 0;
    midi.sendShortMsg(0x90 + (deck - 1), PioneerDDJFLX10._EQ_KILL[idx].note,
                      killed ? 0x00 : 0x7F);   // lit when NOT killed
};
PioneerDDJFLX10.eqKill = function(channel, control, value, status, group) {
    if (value === 0) return;   // act on press only
    var deck = PioneerDDJFLX10._getDeckFromGroup(group);
    for (var i = 0; i < PioneerDDJFLX10._EQ_KILL.length; i++) {
        if (PioneerDDJFLX10._EQ_KILL[i].note === control) {
            var eq = PioneerDDJFLX10._eqGroup(deck);
            var p  = PioneerDDJFLX10._EQ_KILL[i].param;
            engine.setValue(eq, p, engine.getValue(eq, p) > 0 ? 0 : 1);  // toggle kill
            return;
        }
    }
};
PioneerDDJFLX10._initEqKillLeds = function() {
    for (var deck = 1; deck <= PioneerDDJFLX10.numDecks; deck++) {
        (function(d){
            var eq = PioneerDDJFLX10._eqGroup(d);
            for (var i = 0; i < PioneerDDJFLX10._EQ_KILL.length; i++) {
                (function(idx){
                    engine.makeConnection(eq, PioneerDDJFLX10._EQ_KILL[idx].param, function(){
                        PioneerDDJFLX10._renderEqKillLed(d, idx);
                    });
                    PioneerDDJFLX10._renderEqKillLed(d, idx);   // seed current LED state
                })(i);
            }
        })(deck);
    }
};

// ─── FX PART SELECT: the bands of the Beat FX ───────────────────────────────
// FLXXX3: the DRUMS / VOCAL / INST buttons (notes 0x1C / 0x1B / 0x1D on status 0x96) switch the
// LOW / MID / HIGH band of the Beat FX on and off ([EffectRack1_EffectUnit1] bands: 1 low, 2 mid,
// 4 high; the same as the LOW / MID / HI fields of the Beat FX window). The buttons latch: Note ON
// = lit = band on. One band always stays on.
PioneerDDJFLX10._MASTER_EQ_STATUS = 0x96;
PioneerDDJFLX10._MASTER_EQ_KILL = [
    {note: 0x1B, bit: 2},  // VOCAL -> mid
    {note: 0x1C, bit: 1},  // DRUMS -> low
    {note: 0x1D, bit: 4}   // INST  -> high
];
PioneerDDJFLX10._renderMasterEqKillLed = function(idx) {
    var mask = Math.round(engine.getValue("[EffectRack1_EffectUnit1]", "bands"));
    midi.sendShortMsg(PioneerDDJFLX10._MASTER_EQ_STATUS,
                      PioneerDDJFLX10._MASTER_EQ_KILL[idx].note,
                      (mask & PioneerDDJFLX10._MASTER_EQ_KILL[idx].bit) ? 0x7F : 0x00);
};
PioneerDDJFLX10.masterEqKill = function(channel, control, value, status, group) {
    var lit = ((status & 0xF0) === 0x90) && (value > 0);
    var unit = "[EffectRack1_EffectUnit1]";
    for (var i = 0; i < PioneerDDJFLX10._MASTER_EQ_KILL.length; i++) {
        if (PioneerDDJFLX10._MASTER_EQ_KILL[i].note === control) {
            var bit = PioneerDDJFLX10._MASTER_EQ_KILL[i].bit;
            var mask = Math.round(engine.getValue(unit, "bands"));
            var next = lit ? (mask | bit) : (mask & ~bit);
            if (next === 0) {
                // the last band stays on: the button is lit again
                PioneerDDJFLX10._renderMasterEqKillLed(i);
                return;
            }
            engine.setValue(unit, "bands", next);
            return;   // the LEDs follow the control
        }
    }
};
PioneerDDJFLX10._initMasterEqKillLeds = function() {
    engine.makeConnection("[EffectRack1_EffectUnit1]", "bands", function() {
        for (var i = 0; i < PioneerDDJFLX10._MASTER_EQ_KILL.length; i++) {
            PioneerDDJFLX10._renderMasterEqKillLed(i);
        }
    });
    for (var i = 0; i < PioneerDDJFLX10._MASTER_EQ_KILL.length; i++) {
        PioneerDDJFLX10._renderMasterEqKillLed(i);   // seed current LED state
    }
};

// 4-beat loop button (note 0x14). FLXXX3: like the CDJ, the loop STARTS at the press point
// (the 4 beats ahead of it; with QUANTIZE on at the nearest beat). The original mapping
// ended the loop there. Press again while looping to exit.
PioneerDDJFLX10.beatLoopBack4 = function(channel, control, value, status, group) {
    if (value === 0) return;
    if (engine.getValue(group, "loop_enabled") > 0) {
        engine.setValue(group, "reloop_toggle", 1);   // already looping -> exit
        engine.setValue(group, "reloop_toggle", 0);
        return;
    }
    engine.setValue(group, "loop_anchor", 0);   // 0 = the loop starts at the press point
    engine.setValue(group, "beatloop_4_activate", 1);
};

// ─── Loop in/out button LEDs ─────────────────────────────────────────────────
// IN button = note 0x10, OUT button = note 0x11 (status 0x90+(deck-1)). States:
//   • adjusting IN  (_loopAdjustMode "in")  → IN blink, OUT solid
//   • adjusting OUT (_loopAdjustMode "out") → IN solid, OUT blink
//   • loop active (loop_enabled)            → IN solid, OUT solid
//   • loop in set but not yet closed        → IN blink, OUT off
//   • otherwise                             → both off
PioneerDDJFLX10._LOOP_IN_NOTE  = 0x10;
PioneerDDJFLX10._LOOP_OUT_NOTE = 0x11;
PioneerDDJFLX10._loopBlinkPhase = false;
var LOOP_BLINK_MS = 300;

PioneerDDJFLX10._renderLoopLeds = function(deck) {
    // FLXXX3: the waveform stands still while a loop boundary is adjusted
    engine.setValue("[Channel" + deck + "]", "loop_adjust_view",
        PioneerDDJFLX10._loopAdjustMode[deck] ? 1 : 0);
    var status = 0x90 + (deck - 1);
    var group  = "[Channel" + deck + "]";
    var adjust = PioneerDDJFLX10._loopAdjustMode[deck];
    var active = engine.getValue(group, "loop_enabled") > 0;
    var inSet  = engine.getValue(group, "loop_start_position") >= 0;
    var outSet = engine.getValue(group, "loop_end_position") >= 0;
    var blink  = PioneerDDJFLX10._loopBlinkPhase ? 0x7F : 0x00;
    var inVal, outVal;
    if (adjust === "in")       { inVal = blink; outVal = 0x7F; }
    else if (adjust === "out") { inVal = 0x7F;  outVal = blink; }
    else if (active)           { inVal = 0x7F;  outVal = 0x7F; }
    else if (inSet && !outSet) { inVal = blink; outVal = 0x00; }  // started, not closed
    else                       { inVal = 0x00;  outVal = 0x00; }
    midi.sendShortMsg(status, PioneerDDJFLX10._LOOP_IN_NOTE,  inVal);
    midi.sendShortMsg(status, PioneerDDJFLX10._LOOP_OUT_NOTE, outVal);
};

// True when deck's loop LEDs are in a blinking state, so the blink timer knows
// to re-render it.
PioneerDDJFLX10._loopDeckBlinks = function(deck) {
    var adjust = PioneerDDJFLX10._loopAdjustMode[deck];
    if (adjust === "in" || adjust === "out") { return true; }
    var group  = "[Channel" + deck + "]";
    var active = engine.getValue(group, "loop_enabled") > 0;
    var inSet  = engine.getValue(group, "loop_start_position") >= 0;
    var outSet = engine.getValue(group, "loop_end_position") >= 0;
    return (!active && inSet && !outSet);
};

PioneerDDJFLX10._initLoopLeds = function() {
    for (var deck = 1; deck <= PioneerDDJFLX10.numDecks; deck++) {
        (function(d){
            var g = "[Channel" + d + "]";
            var refresh = function(){ PioneerDDJFLX10._renderLoopLeds(d); };
            engine.makeConnection(g, "loop_enabled",        refresh);
            engine.makeConnection(g, "loop_start_position", refresh);
            engine.makeConnection(g, "loop_end_position",   refresh);
            refresh();   // seed current state
        })(deck);
    }
    if (!PioneerDDJFLX10._loopBlinkTimer) {
        PioneerDDJFLX10._loopBlinkTimer = engine.beginTimer(LOOP_BLINK_MS, function(){
            PioneerDDJFLX10._loopBlinkPhase = !PioneerDDJFLX10._loopBlinkPhase;
            for (var d = 1; d <= PioneerDDJFLX10.numDecks; d++) {
                if (PioneerDDJFLX10._loopDeckBlinks(d)) {
                    PioneerDDJFLX10._renderLoopLeds(d);
                }
            }
        });
    }
};

// Function to expand playlists folder (currently disabled)
// This feature requires a different approach that will be implemented later

// ─── FLXXX3: Color FX and Beat FX like the app ───────────────────────────────
// (Written by an AI agent (Claude); replaces the handlers above, see ROADMAP.)

// SOUND COLOR FX buttons 0x96 0x00..0x05: SPACE, DUB ECHO, CRUSH, PITCH, NOISE,
// FILTER, the same order as the Color FX of the app ([AndroidDJ] color_fx: 0 SPACE,
// 1 DUB ECHO, 2 CRUSH, 3 SWEEP, 4 NOISE, 5 FILTER; PITCH takes SWEEP for now).
// The controller keeps the buttons itself: pressing one sends Note ON (selected),
// pressing it again or another one sends Note OFF for it (A -> B: OFF A, ON B).
// The COLOR knob of each channel stays the knob of the effect (super1).
PioneerDDJFLX10.soundColorFx = function(channel, control, value, status, _group) {
    if (control < 0 || control > 5) {
        return;
    }
    var on = ((status & 0xF0) === 0x90) && value > 0;
    if (on && Math.round(engine.getValue("[AndroidDJ]", "color_fx")) === control &&
            engine.getValue("[AndroidDJ]", "color_fx_on") > 0) {
        // the same key again: off (the key does not send a Note OFF when the app sets its LED)
        engine.setValue("[AndroidDJ]", "color_fx_on", 0);
    } else if (on) {
        engine.setValue("[AndroidDJ]", "color_fx", control);
        engine.setValue("[AndroidDJ]", "color_fx_on", 1);
    } else if (Math.round(engine.getValue("[AndroidDJ]", "color_fx")) === control) {
        engine.setValue("[AndroidDJ]", "color_fx_on", 0);
    }
};

// BEAT FX selector (14 positions, 0x94 0x20..0x2D) -> Beat FX of the app (position in
// its list: 1 DELAY, 2 ECHO, 3 PING PONG, 4 SPIRAL, 5 HELIX, 6 REVERB, 7 FLANGER,
// 8 PHASER, 9 TRANS, 10 FILTER; 0 = not in the app yet: the Beat FX is silent there).
// Positions as printed on the controller: LOW CUT ECHO, ECHO, MT DELAY, SPIRAL, REVERB,
// TRANS, ENIGMA JET, FLANGER, PHASER, STRETCH, SLIP ROLL, ROLL, MOBIUS (saw), MOBIUS
// (triangle); both MOBIUS take HELIX.
PioneerDDJFLX10.beatFxPositionToApp = [11, 2, 1, 4, 6, 9, 12, 7, 8, 13, 17, 16, 14, 15];
PioneerDDJFLX10.beatFxAvailable = true;
PioneerDDJFLX10._beatFxGroup = "[EffectRack1_EffectUnit1_Effect1]";
PioneerDDJFLX10._beatFxTailTimer = 0;
PioneerDDJFLX10._beatFxTailMeta = 1;

// The position of the selector (0..13, -1 = not known yet). It is read from the device at the
// start; the effect of the app is set again a few times then (the effect system sets up its
// first effects in the first seconds), as long as the BEAT keys were not used.
PioneerDDJFLX10._beatFxPosition = -1;
PioneerDDJFLX10._beatFxKeysUsed = false;
PioneerDDJFLX10.reapplyBeatFxPosition = function() {
    if (PioneerDDJFLX10._beatFxPosition >= 0 && !PioneerDDJFLX10._beatFxKeysUsed) {
        PioneerDDJFLX10.selectBeatFxPosition(PioneerDDJFLX10._beatFxPosition);
    }
};
PioneerDDJFLX10.beatFxPad = function(channel, control, value, _status, _group) {
    if (value === 0) {
        return;
    }
    var position = control - 0x20;
    if (position < 0 || position > 13) {
        return;
    }
    PioneerDDJFLX10._beatFxKeysUsed = false;
    PioneerDDJFLX10.selectBeatFxPosition(position);
};
PioneerDDJFLX10._beatFxSelectAt = 0;
PioneerDDJFLX10.selectBeatFxPosition = function(position) {
    PioneerDDJFLX10._beatFxPosition = position;
    PioneerDDJFLX10._beatFxSelectAt = Date.now();
    // The list of the app shows which position is chosen (also for ROLL and SLIP ROLL).
    engine.setValue("[AndroidDJ]", "beat_fx_selected", position + 1);
    // ADVANCED SETTINGS > BEAT FX: the effect of this position (0 = none).
    var target = engine.getValue("[AndroidDJ]", "beat_fx_pos" + (position + 1));
    if (target === undefined || isNaN(target)) {
        target = PioneerDDJFLX10.beatFxPositionToApp[position];
    }
    target = Math.round(target);
    var group = PioneerDDJFLX10._beatFxGroup;
    PioneerDDJFLX10._cancelBeatFxTail(true);
    PioneerDDJFLX10.beatFxAvailable = target > 0;
    engine.setValue("[EffectRack1_EffectUnit1]", "focused_effect", 1);
    if (target > 0 && engine.getValue(group, "loaded_effect") !== target) {
        engine.setValue(group, "loaded_effect", target);
    }
    engine.setValue(group, "enabled",
        PioneerDDJFLX10._beatFxActive && PioneerDDJFLX10.beatFxAvailable ? 1 : 0);
    // The small display: name now, the beat a moment later (the new effect sets its defaults).
    PioneerDDJFLX10._fxCode = target;
    if (PioneerDDJFLX10._signedIndex[target] === undefined) {
        engine.setValue("[AndroidDJ]", "beat_fx_signed", 0);
    }
    if (target > 0) {
        PioneerDDJFLX10.sendFxName(PioneerDDJFLX10._fxNames[target] || "");
        engine.beginTimer(150, function() {
            if (PioneerDDJFLX10._signedIndex[target] !== undefined) {
                PioneerDDJFLX10._signedIndex[target] = PioneerDDJFLX10._signedRing.indexOf(
                    PioneerDDJFLX10._signedStart[target]);
                PioneerDDJFLX10._applySigned(target);
            }
            PioneerDDJFLX10.updateFxDisplay(false);
        }, true);
    }
};

PioneerDDJFLX10._cancelBeatFxTail = function(restoreDepth) {
    if (PioneerDDJFLX10._beatFxTailTimer) {
        engine.stopTimer(PioneerDDJFLX10._beatFxTailTimer);
        PioneerDDJFLX10._beatFxTailTimer = 0;
        if (restoreDepth) {
            engine.setValue(PioneerDDJFLX10._beatFxGroup, "meta", PioneerDDJFLX10._beatFxTailMeta);
        }
    }
};

// How long an echo / delay / reverb rings out after OFF (like the DDJ-FLX4 script).
PioneerDDJFLX10._beatFxTailMs = function(loaded) {
    if (loaded === 6) {
        return 3000; // reverb
    }
    var master = Math.round(engine.getValue("[AndroidDJ]", "master_deck")) || 1;
    var bpm = engine.getValue("[Channel" + master + "]", "bpm") || 120;
    var delayMs = 60000 / bpm * engine.getValue(PioneerDDJFLX10._beatFxGroup, "parameter1");
    return Math.max(1500, Math.min(6000, 8 * delayMs));
};

// ON/OFF (0x94 0x46 / 0x47; one press = one change). OFF lets DELAY, ECHO, PING
// PONG, SPIRAL and REVERB ring out: no new sound goes in (depth 0), then it stops.
// The LED of the ON/OFF key (found out with the DDJ-FLX4 script): the value 0x7F makes it blink
// (by itself) = effect on, 0x00 makes it stay lit = effect off. It keeps the last state over a
// restart of the app, so the state is sent again a few times after the start.
PioneerDDJFLX10._beatFxLedValue = -1;
// The FLX10 answers a new LED value of the key with a press of its own (127 and 0, a few ms
// later). That is no press of the user: ignored for a moment after the LED was set (otherwise
// the effect would be switched back at once).
PioneerDDJFLX10._beatFxLedAt = 0;
PioneerDDJFLX10.BEAT_FX_LED_ECHO_MS = 150;
PioneerDDJFLX10._setBeatFxLed = function(on, force) {
    var value = on ? 0x7F : 0x00;
    if (!force && PioneerDDJFLX10._beatFxLedValue === value) {
        return;
    }
    PioneerDDJFLX10._beatFxLedValue = value;
    PioneerDDJFLX10._beatFxLedAt = Date.now();
    midi.sendShortMsg(0x94, 0x46, value);
    midi.sendShortMsg(0x94, 0x47, value);
};
PioneerDDJFLX10.beatFxOnOff = function(channel, control, value, status, _group) {
    // The key latches inside the FLX10: a press sends the new state, 0x7F = ON, 0x00 = OFF
    // (seen in the log: with the LED blinking = on, a press sends 0x00). The app sets that state
    // with the LED; the FLX10 then answers with the same value a few ms later, which is ignored.
    // A value that is already the state (also sent once after the start) changes nothing.
    if (Date.now() - PioneerDDJFLX10._beatFxLedAt < PioneerDDJFLX10.BEAT_FX_LED_ECHO_MS) {
        return;
    }
    var group = PioneerDDJFLX10._beatFxGroup;
    var running = engine.getValue(group, "enabled") > 0 && !PioneerDDJFLX10._beatFxTailTimer;
    if ((value > 0) === running) {
        return;
    }
    PioneerDDJFLX10._beatFxActive = !running;
    PioneerDDJFLX10._setBeatFxLed(PioneerDDJFLX10._beatFxActive);
    engine.setValue("[EffectRack1_EffectUnit1]", "focused_effect", 1);
    if (PioneerDDJFLX10._beatFxActive) {
        PioneerDDJFLX10._cancelBeatFxTail(true);
        engine.setValue(group, "enabled", PioneerDDJFLX10.beatFxAvailable ? 1 : 0);
        return;
    }
    var loaded = engine.getValue(group, "loaded_effect");
    // ADVANCED SETTINGS > BEAT FX > RING OUT AFTER OFF (on by default): otherwise the effect stops at once.
    if (engine.getValue("[AndroidDJ]", "beat_fx_tail") > 0 && engine.getValue(group, "enabled") > 0 &&
            ((loaded >= 1 && loaded <= 4) || loaded === 6 || loaded === 11)) {
        PioneerDDJFLX10._cancelBeatFxTail(true);
        PioneerDDJFLX10._beatFxTailMeta = engine.getValue(group, "meta");
        engine.setValue(group, "meta", 0);
        PioneerDDJFLX10._beatFxTailTimer = engine.beginTimer(PioneerDDJFLX10._beatFxTailMs(loaded), function() {
            PioneerDDJFLX10._beatFxTailTimer = 0;
            engine.setValue(group, "enabled", 0);
            engine.setValue(group, "meta", PioneerDDJFLX10._beatFxTailMeta);
        }, true);
        return;
    }
    PioneerDDJFLX10._cancelBeatFxTail(true);
    engine.setValue(group, "enabled", 0);
};

// BEAT < / > : the beat length of the Beat FX (REVERB: its amount in 10 % steps),
// like the DDJ-FLX4 script.
PioneerDDJFLX10.beatFxBeatValues = [0.0625, 0.125, 0.25, 0.5, 0.75, 1, 2, 4, 8];
PioneerDDJFLX10.stepBeatFxTime = function(direction) {
    var group = PioneerDDJFLX10._beatFxGroup;
    var loaded = engine.getValue(group, "loaded_effect");
    if (loaded < 1) {
        return;
    }
    PioneerDDJFLX10._beatFxKeysUsed = true;
    if (PioneerDDJFLX10._signedIndex[loaded] !== undefined) {
        var n = PioneerDDJFLX10._signedRing.length;
        // The arrows of the touch panel also change the value: continue from the control.
        var shown = PioneerDDJFLX10._signedRing.indexOf(engine.getValue("[AndroidDJ]", "beat_fx_signed"));
        if (shown >= 0) {
            PioneerDDJFLX10._signedIndex[loaded] = shown;
        }
        // BEAT < (direction -1) goes along the ring
        PioneerDDJFLX10._signedIndex[loaded] =
            (PioneerDDJFLX10._signedIndex[loaded] - direction + n) % n;
        PioneerDDJFLX10._applySigned(loaded);
        PioneerDDJFLX10.updateFxDisplay(false);
        return;
    }
    if (loaded === 6) {
        var percent = Math.round(engine.getParameter(group, "parameter1") * 10) + direction;
        engine.setParameter(group, "parameter1", Math.max(0, Math.min(10, percent)) / 10);
        PioneerDDJFLX10.updateFxDisplay(false);
        return;
    }
    var beats = PioneerDDJFLX10.beatFxBeatValues;
    var current = engine.getParameter(group, "parameter1") * 8;
    var nearest = 0;
    for (var i = 1; i < beats.length; i++) {
        if (Math.abs(beats[i] - current) < Math.abs(beats[nearest] - current)) {
            nearest = i;
        }
    }
    var next = Math.max(0, Math.min(beats.length - 1, nearest + direction));
    engine.setParameter(group, "parameter1", beats[next] / 8);
    PioneerDDJFLX10.updateFxDisplay(false);
};
PioneerDDJFLX10.beatFxLeftPressed = function(channel, control, value) {
    if (value > 0) {
        PioneerDDJFLX10.stepBeatFxTime(-1);
    }
};
PioneerDDJFLX10.beatFxRightPressed = function(channel, control, value) {
    if (value > 0) {
        PioneerDDJFLX10.stepBeatFxTime(1);
    }
};
