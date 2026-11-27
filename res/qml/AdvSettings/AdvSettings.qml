pragma Singleton
import Mixxx 1.0 as Mixxx
import QtQuick 2.12

// Advanced settings of the FLXXX3 (UTILITY -> ADVANCED SETTINGS).
// One place for all fine settings: the definitions (area, label, range, steps and the
// FACTORY value, which is how the app behaved before the settings existed), the current
// values, presets (save / apply / delete) and the reset to the factory state.
// Values that belong to a control of the engine ("control") are read from and written
// to it (and saved under the key that the JOGWHEEL window uses, too).
// (An Item and not a QtObject: a QtObject with ControlProxy children crashes Mixxx on load.)
Item {
    id: root

    // A list of the library loads a track into a deck (LOAD of the controller, LOAD TO DECK of
    // the track menu). The main window closes the library on it. (The LOAD control of the
    // controller and the trackLoading signal of the deck did not always reach the window.)
    signal trackLoadRequested(string group)

    readonly property var areas: ["AUDIO", "WAVEFORM", "WINDOW", "BEAT FX", "JOGWHEEL", "START", "INFO", "ABOUT"]

    // kind: "number" (min, max, step, fine, decimals, unit) or "choice" (choices: [{t, v}])
    readonly property var defs: [
        // ---- AUDIO (buffer and sample rate are read when the app starts: restart needed) ----
        { key: "audioBuffer", area: "AUDIO", label: "USB AUDIO BUFFER (RESTART NEEDED)", kind: "choice", choices: [{ t: "128 (2.7 ms)", v: 2 }, { t: "256 (5.3 ms)", v: 3 }, { t: "512 (10.7 ms)", v: 4 }, { t: "1024 (21 ms)", v: 5 }], def: 3, mirror: "adv_audio_buffer" },
        { key: "audioRate", area: "AUDIO", label: "SAMPLE RATE (RESTART NEEDED)", kind: "choice", choices: [{ t: "44.1 kHz", v: 44100 }, { t: "48 kHz", v: 48000 }], def: 48000, mirror: "adv_audio_rate" },
        // AUTO GAIN: every track is measured once (loudness, EBU R128) and played at about the same
        // loudness. Switched in UTILITY (area "UTILITY" is not shown in ADVANCED SETTINGS).
        { key: "autoGain", area: "UTILITY", label: "AUTO GAIN (SAME LOUDNESS FOR EVERY TRACK)", kind: "choice", choices: [{ t: "ON", v: 1 }, { t: "OFF", v: 0 }], def: 1, mirror: "adv_auto_gain" },
        // LIMITER: catches peaks above -0.3 dBFS on the master (two loud tracks, EQ boost)
        // instead of letting them distort; below that it does nothing.
        { key: "limiter", area: "AUDIO", label: "MASTER LIMITER (NO DISTORTION ON PEAKS)", kind: "choice", choices: [{ t: "ON", v: 1 }, { t: "OFF", v: 0 }], def: 1 },
        { key: "headroom", area: "AUDIO", label: "MASTER HEADROOM (LOWERS THE MASTER OUTPUT)", kind: "number", min: 0, max: 12, step: 0.5, fine: 0.1, decimals: 1, unit: "dB", def: 0 },
        // ---- START (values the app starts with) ----
        { key: "stickAuto", area: "START", label: "READ REKORDBOX STICKS", kind: "choice", choices: [{ t: "AUTOMATIC", v: 1 }, { t: "ON REQUEST", v: 0 }], def: 1, mirror: "adv_stick_auto" },
        { key: "startScreen", area: "START", label: "SCREEN (MONITOR) THE APP STARTS ON (WINDOWS)", kind: "choice", choices: [{ t: "MONITOR 1", v: 1 }, { t: "MONITOR 2", v: 2 }, { t: "MONITOR 3", v: 3 }], def: 2, mirror: "adv_start_screen" },
        { key: "startTempoRange", area: "START", label: "TEMPO RANGE AT START", kind: "choice", choices: [{ t: "LAST USED", v: 0 }, { t: "6%", v: 0.06 }, { t: "10%", v: 0.10 }, { t: "16%", v: 0.16 }, { t: "WIDE", v: 1.0 }], def: 0.06 },
        // ---- WAVEFORM ----
        { key: "waveFps", area: "WAVEFORM", label: "WAVEFORM FRAME RATE", kind: "choice", choices: [{ t: "30", v: 30 }, { t: "45", v: 45 }, { t: "60", v: 60 }], def: 60 },
        // Size of the four layers of the waveform (see the example above the list): from the outside
        // in blue (low), orange (mid), brown (inner part of mid), white (high).
        { key: "wave_size_low", area: "WAVEFORM", label: "LAYER SIZE: BLUE (LOW, OUTSIDE)", kind: "number", min: 0.2, max: 2, step: 0.05, fine: 0.01, decimals: 2, unit: "x", def: 1, control: true },
        { key: "wave_size_mid", area: "WAVEFORM", label: "LAYER SIZE: ORANGE (MID)", kind: "number", min: 0.2, max: 2, step: 0.05, fine: 0.01, decimals: 2, unit: "x", def: 1, control: true },
        { key: "wave_size_brown", area: "WAVEFORM", label: "LAYER SIZE: BROWN (INNER PART OF MID)", kind: "number", min: 0.2, max: 2, step: 0.05, fine: 0.01, decimals: 2, unit: "x", def: 1, control: true },
        { key: "wave_size_high", area: "WAVEFORM", label: "LAYER SIZE: WHITE (HIGH, INSIDE)", kind: "number", min: 0.2, max: 2, step: 0.05, fine: 0.01, decimals: 2, unit: "x", def: 1, control: true },
        { key: "waveGain", area: "WAVEFORM", label: "WAVEFORM HEIGHT (SCALE)", kind: "number", min: 0.5, max: 1.5, step: 0.05, fine: 0.01, decimals: 2, unit: "x", def: 1 },
        { key: "overviewGap", area: "WAVEFORM", label: "CDJ VIEW: GAP BETWEEN DECK FIELD AND OVERVIEW", kind: "number", min: 0, max: 60, step: 2, fine: 1, decimals: 0, unit: "px", def: 10 },
        { key: "beatGridAlpha", area: "WAVEFORM", label: "BEAT GRID LINES BRIGHTNESS", kind: "number", min: 0, max: 100, step: 5, fine: 1, decimals: 0, unit: "%", def: 90 },
        { key: "zoomStart", area: "WAVEFORM", label: "ZOOM AFTER START", kind: "number", min: 0.3, max: 30, step: 0.5, fine: 0.1, decimals: 1, unit: "", def: 3 },
        { key: "zoomMin", area: "WAVEFORM", label: "ZOOM LIMIT: MOST DETAIL", kind: "number", min: 0.1, max: 5, step: 0.1, fine: 0.05, decimals: 2, unit: "", def: 0.3 },
        { key: "zoomMax", area: "WAVEFORM", label: "ZOOM LIMIT: MOST OVERVIEW", kind: "number", min: 5, max: 60, step: 1, fine: 0.5, decimals: 1, unit: "", def: 30 },
        // ---- WINDOW ----
        { key: "windowCloseSec", area: "WINDOW", label: "WINDOWS CLOSE AFTER (FILTER, BEAT FX, JOGWHEEL, BRIGHTNESS)", kind: "number", min: 1, max: 60, step: 0.5, fine: 0.1, decimals: 1, unit: "s", def: 10 },
        { key: "menuIdleSec", area: "WINDOW", label: "LIBRARY / MENU CLOSE AFTER IDLE", kind: "number", min: 10, max: 900, step: 10, fine: 1, decimals: 0, unit: "s", def: 180 },
        { key: "afterLoadMs", area: "WINDOW", label: "LIBRARY CLOSES AFTER LOAD", kind: "number", min: 0, max: 3000, step: 50, fine: 10, decimals: 0, unit: "ms", def: 250 },
        { key: "longPressSec", area: "WINDOW", label: "LONG PRESS (TRACK MENU)", kind: "number", min: 0.2, max: 2, step: 0.1, fine: 0.05, decimals: 2, unit: "s", def: 0.5 },
        // ---- BEAT FX: the effect of each of the 14 positions of the DDJ-FLX10 selector. The DDJ-FLX4 steps through
        // the same list with FX SELECT (empty positions and repeats are skipped). ----
        { key: "beat_fx_tail", area: "BEAT FX", label: "RING OUT AFTER OFF (ECHO, DELAY, PING PONG, SPIRAL, LOW CUT ECHO, REVERB)", kind: "choice", choices: [{ t: "OFF", v: 0 }, { t: "ON", v: 1 }], def: 1, control: true },
        { key: "beat_fx_pos1", area: "BEAT FX", label: "POSITION 1 (FLX10: LOW CUT ECHO)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 11, control: true },
        { key: "beat_fx_pos2", area: "BEAT FX", label: "POSITION 2 (FLX10: ECHO)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 2, control: true },
        { key: "beat_fx_pos3", area: "BEAT FX", label: "POSITION 3 (FLX10: MT DELAY)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 1, control: true },
        { key: "beat_fx_pos4", area: "BEAT FX", label: "POSITION 4 (FLX10: SPIRAL)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 4, control: true },
        { key: "beat_fx_pos5", area: "BEAT FX", label: "POSITION 5 (FLX10: REVERB)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 6, control: true },
        { key: "beat_fx_pos6", area: "BEAT FX", label: "POSITION 6 (FLX10: TRANS)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 9, control: true },
        { key: "beat_fx_pos7", area: "BEAT FX", label: "POSITION 7 (FLX10: ENIGMA JET)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 12, control: true },
        { key: "beat_fx_pos8", area: "BEAT FX", label: "POSITION 8 (FLX10: FLANGER)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 7, control: true },
        { key: "beat_fx_pos9", area: "BEAT FX", label: "POSITION 9 (FLX10: PHASER)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 8, control: true },
        { key: "beat_fx_pos10", area: "BEAT FX", label: "POSITION 10 (FLX10: STRETCH)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 13, control: true },
        { key: "beat_fx_pos11", area: "BEAT FX", label: "POSITION 11 (FLX10: SLIP ROLL)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 17, control: true },
        { key: "beat_fx_pos12", area: "BEAT FX", label: "POSITION 12 (FLX10: ROLL)", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 16, control: true },
        { key: "beat_fx_pos13", area: "BEAT FX", label: "POSITION 13 (FLX10: MOBIUS (SAW))", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 14, control: true },
        { key: "beat_fx_pos14", area: "BEAT FX", label: "POSITION 14 (FLX10: MOBIUS (TRIANGLE))", kind: "choice", choices: [{ t: "NONE", v: 0 }, { t: "DELAY", v: 1 }, { t: "ECHO", v: 2 }, { t: "PING PONG", v: 3 }, { t: "SPIRAL", v: 4 }, { t: "HELIX", v: 5 }, { t: "REVERB", v: 6 }, { t: "FLANGER", v: 7 }, { t: "PHASER", v: 8 }, { t: "TRANS", v: 9 }, { t: "FILTER", v: 10 }, { t: "LOW CUT ECHO", v: 11 }, { t: "ENIGMA JET", v: 12 }, { t: "STRETCH", v: 13 }, { t: "MOBIUS SAW", v: 14 }, { t: "MOBIUS TRIANGLE", v: 15 }, { t: "ROLL", v: 16 }, { t: "SLIP ROLL", v: 17 }], def: 15, control: true },
        // ---- JOGWHEEL (controls of the engine, used by the FLX4 script) ----
        // Both factors: 1 = as before, more = more movement per turn. The scratch factor applies at the next touch of the platter.
        { key: "jog_scratch_sens", area: "JOGWHEEL", label: "JOG SENSITIVITY: TOP (SCRATCH, PLATTER TOUCHED)", kind: "number", min: 0.2, max: 4, step: 0.1, fine: 0.01, decimals: 2, unit: "x", def: 1, control: true },
        { key: "jog_bend_sens", area: "JOGWHEEL", label: "JOG SENSITIVITY: SIDE (PITCH BEND)", kind: "number", min: 0.2, max: 4, step: 0.1, fine: 0.01, decimals: 2, unit: "x", def: 1, control: true },
        { key: "backspin_length", area: "JOGWHEEL", label: "BACK SPIN LENGTH (DDJ-FLX4; THE DDJ-FLX10 FOLLOWS ITS PLATTER)", kind: "choice", choices: [{ t: "SHORT", v: 0 }, { t: "NORMAL", v: 1 }, { t: "LONG", v: 2 }], def: 1, control: true },
        // BACK SPIN depends on how hard the jog was turned (speeds in times of the normal speed of the wheel)
    ]

    // Current value of every key.
    property var values: ({})
    // Saved presets: [{ name, values }]
    property var presets: []

    function definition(key) {
        for (let i = 0; i < root.defs.length; ++i) {
            if (root.defs[i].key === key)
                return root.defs[i];
        }
        return null;
    }
    function inArea(area) {
        return root.defs.filter(d => d.area === area);
    }
    function get(key) {
        return root.values[key];
    }
    function clamp(def, v) {
        if (def.kind === "choice") {
            return def.choices.some(c => c.v === v) ? v : def.def;
        }
        const n = Math.max(def.min, Math.min(def.max, Number(v)));
        const f = Math.pow(10, def.decimals);
        return isNaN(n) ? def.def : Math.round(n * f) / f;
    }
    function proxyFor(key) {
        switch (key) {
        case "backspin_length":
            return pBackspinLength;
        case "vinyl_stop_sec":
            return pVinylStop;
        case "vinyl_start_sec":
            return pVinylStart;
        case "backspin_sens":
            return pBackspinSens;
        case "backspin_min_rate":
            return pBackspinMin;
        case "backspin_max_rate":
            return pBackspinMax;
        }
        // The other control settings (jog sensitivity, Beat FX positions): the proxy is made when it is first needed.
        if (!root.dynProxies[key]) {
            root.dynProxies[key] = Qt.createQmlObject(
                    'import Mixxx 1.0 as Mixxx; Mixxx.ControlProxy { group: "[AndroidDJ]"; key: "' + key + '" }', root);
        }
        return root.dynProxies[key];
    }
    property var dynProxies: ({})
    function store() {
        const own = {};
        root.defs.forEach(d => {
            if (!d.control)
                own[d.key] = root.values[d.key];
        });
        Mixxx.Config.setAndroidSetting("adv_values", JSON.stringify(own));
        root.defs.forEach(d => {
            if (d.mirror)
                Mixxx.Config.setAndroidSetting(d.mirror, String(root.values[d.key]));
        });
        root.applyHeadroom();
        root.applyLimiter();
        root.applyAutoGain();
    }
    // AUTO GAIN on or off for the decks (the analysis reads adv_auto_gain itself).
    function applyAutoGain() {
        if (root.values.autoGain === undefined)
            return;
        pReplayGainEnabled.value = root.values.autoGain ? 1 : 0;
    }
    function applyLimiter() {
        if (root.values.limiter === undefined)
            return;
        pMasterLimiter.value = root.values.limiter ? 1 : 0;
    }
    // Master headroom: a fixed gain below 0 dB on the master output.
    function applyHeadroom() {
        const db = root.values.headroom;
        if (db === undefined)
            return;
        pMasterGain.value = Math.pow(10, -db / 20);
    }
    function set(key, value) {
        const d = root.definition(key);
        if (!d)
            return;
        const v = root.clamp(d, value);
        const copy = Object.assign({}, root.values);
        copy[key] = v;
        root.values = copy;
        if (d.control) {
            const p = root.proxyFor(key);
            if (p) {
                p.value = v;
                Mixxx.Config.setAndroidSetting("jog_" + key, String(v));
            }
        } else {
            root.store();
        }
    }
    // The state of the app before the settings existed.
    function factoryReset() {
        root.defs.forEach(d => root.set(d.key, d.def));
    }
    function savePresets() {
        Mixxx.Config.setAndroidSetting("adv_presets", JSON.stringify(root.presets));
    }
    function savePreset() {
        let n = root.presets.length + 1;
        const names = root.presets.map(p => p.name);
        while (names.indexOf("PRESET " + n) >= 0)
            ++n;
        const list = root.presets.slice();
        list.push({ name: "PRESET " + n, values: Object.assign({}, root.values) });
        root.presets = list;
        root.savePresets();
        return list.length - 1;
    }
    function applyPreset(index) {
        const p = root.presets[index];
        if (!p)
            return;
        root.defs.forEach(d => {
            if (p.values[d.key] !== undefined)
                root.set(d.key, p.values[d.key]);
        });
    }
    function renamePreset(index, name) {
        const clean = String(name).trim().substring(0, 24);
        if (clean === "" || !root.presets[index])
            return;
        const list = root.presets.slice();
        list[index] = { name: clean, values: list[index].values };
        root.presets = list;
        root.savePresets();
    }
    function deletePreset(index) {
        const list = root.presets.slice();
        list.splice(index, 1);
        root.presets = list;
        root.savePresets();
    }
    // The controls of the JOGWHEEL window change by themselves: take their value over.
    function takeControl(key) {
        const p = root.proxyFor(key);
        const d = root.definition(key);
        if (!p || !d)
            return;
        const copy = Object.assign({}, root.values);
        copy[key] = root.clamp(d, p.value);
        root.values = copy;
    }

    // ---- PLAYED TRACKS ----
    // A track counts as played after it was heard for PLAYED_SECONDS on a deck. The library marks
    // played tracks with a dot. The list of the file URLs is kept in the settings ("played_tracks").
    readonly property int playedSeconds: 20
    property var playedMap: ({})
    // changes with every new played track, so that the library list evaluates its dots again
    property int playedRevision: 0
    property var playedCounter: ({})
    property var playedLastUrl: ({})

    function isPlayed(url) {
        return root.playedMap[String(url)] === true;
    }
    function markPlayed(url) {
        const key = String(url);
        if (key === "" || root.playedMap[key] === true)
            return;
        root.playedMap[key] = true;
        root.playedRevision++;
        const keys = Object.keys(root.playedMap);
        // at most 20000 entries (the oldest go first)
        if (keys.length > 20000) {
            keys.slice(0, keys.length - 20000).forEach(k => delete root.playedMap[k]);
        }
        Mixxx.Config.setAndroidSetting("played_tracks", JSON.stringify(Object.keys(root.playedMap)));
    }
    function countPlayed(deck, playing) {
        const player = Mixxx.PlayerManager.getPlayer("[Channel" + deck + "]");
        const track = player ? player.currentTrack : null;
        const url = track ? String(track.trackLocationUrl) : "";
        if (!playing || url === "") {
            root.playedCounter[deck] = 0;
            return;
        }
        if (root.playedLastUrl[deck] !== url) {
            root.playedLastUrl[deck] = url;
            root.playedCounter[deck] = 0;
        }
        root.playedCounter[deck] = (root.playedCounter[deck] || 0) + 1;
        if (root.playedCounter[deck] === root.playedSeconds)
            root.markPlayed(url);
    }
    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered: {
            root.countPlayed(1, pPlay1.value > 0);
            root.countPlayed(2, pPlay2.value > 0);
            root.countPlayed(3, pPlay3.value > 0);
            root.countPlayed(4, pPlay4.value > 0);
        }
    }

    data: [
        Mixxx.ControlProxy {
            id: pPlay1

            group: "[Channel1]"
            key: "play"
        },
        Mixxx.ControlProxy {
            id: pPlay2

            group: "[Channel2]"
            key: "play"
        },
        Mixxx.ControlProxy {
            id: pPlay3

            group: "[Channel3]"
            key: "play"
        },
        Mixxx.ControlProxy {
            id: pPlay4

            group: "[Channel4]"
            key: "play"
        },
        Mixxx.ControlProxy {
            id: pMasterLimiter

            group: "[Main]"
            key: "limiter"
        },
        Mixxx.ControlProxy {
            id: pMasterGain

            group: "[Main]"
            key: "gain"
        },
        Mixxx.ControlProxy {
            id: pReplayGainEnabled

            group: "[ReplayGain]"
            key: "ReplayGainEnabled"
        },
        Mixxx.ControlProxy {
            id: pBackspinLength

            group: "[AndroidDJ]"
            key: "backspin_length"
            onValueChanged: root.takeControl("backspin_length")
        },
        Mixxx.ControlProxy {
            id: pVinylStop

            group: "[AndroidDJ]"
            key: "vinyl_stop_sec"
            onValueChanged: root.takeControl("vinyl_stop_sec")
        },
        Mixxx.ControlProxy {
            id: pBackspinSens

            group: "[AndroidDJ]"
            key: "backspin_sens"
            onValueChanged: root.takeControl("backspin_sens")
        },
        Mixxx.ControlProxy {
            id: pBackspinMin

            group: "[AndroidDJ]"
            key: "backspin_min_rate"
            onValueChanged: root.takeControl("backspin_min_rate")
        },
        Mixxx.ControlProxy {
            id: pBackspinMax

            group: "[AndroidDJ]"
            key: "backspin_max_rate"
            onValueChanged: root.takeControl("backspin_max_rate")
        },
        Mixxx.ControlProxy {
            id: pVinylStart

            group: "[AndroidDJ]"
            key: "vinyl_start_sec"
            onValueChanged: root.takeControl("vinyl_start_sec")
        }
    ]

    Component.onCompleted: {
        let own = {};
        try {
            own = JSON.parse(Mixxx.Config.androidSetting("adv_values", "{}")) || {};
        } catch (e) {
        }
        const v = {};
        root.defs.forEach(d => {
            if (d.control) {
                const p = root.proxyFor(d.key);
                // the value that was saved last time (the engine starts with its default)
                const saved = parseFloat(Mixxx.Config.androidSetting("jog_" + d.key, ""));
                if (p && !isNaN(saved))
                    p.value = saved;
                v[d.key] = p ? root.clamp(d, p.value) : d.def;
            } else {
                v[d.key] = own[d.key] !== undefined ? root.clamp(d, own[d.key]) : d.def;
            }
        });
        root.values = v;
        try {
            const played = JSON.parse(Mixxx.Config.androidSetting("played_tracks", "[]"));
            const map = {};
            if (Array.isArray(played))
                played.forEach(u => map[u] = true);
            root.playedMap = map;
        } catch (e) {
        }
        root.applyHeadroom();
        root.applyLimiter();
        root.applyAutoGain();
        try {
            const list = JSON.parse(Mixxx.Config.androidSetting("adv_presets", "[]"));
            if (Array.isArray(list))
                root.presets = list;
        } catch (e) {
        }
    }
}
