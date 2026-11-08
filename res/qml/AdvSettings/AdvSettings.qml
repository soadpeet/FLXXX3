pragma Singleton
import Mixxx 1.0 as Mixxx
import QtQuick 2.12

// Advanced settings of the Android edition (UTILITY -> ADVANCED SETTINGS).
// One place for all fine settings: the definitions (area, label, range, steps and the
// FACTORY value, which is how the app behaved before the settings existed), the current
// values, presets (save / apply / delete) and the reset to the factory state.
// Values that belong to a control of the engine ("control") are read from and written
// to it (and saved under the key that the JOGWHEEL window uses, too).
// (An Item and not a QtObject: a QtObject with ControlProxy children crashes Mixxx on load.)
Item {
    id: root

    readonly property var areas: ["AUDIO", "WAVEFORM", "WINDOW", "JOGWHEEL", "START", "INFO"]

    // kind: "number" (min, max, step, fine, decimals, unit) or "choice" (choices: [{t, v}])
    readonly property var defs: [
        // ---- AUDIO (buffer and sample rate are read when the app starts: restart needed) ----
        { key: "audioBuffer", area: "AUDIO", label: "USB AUDIO BUFFER (RESTART NEEDED)", kind: "choice", choices: [{ t: "128 (2.7 ms)", v: 2 }, { t: "256 (5.3 ms)", v: 3 }, { t: "512 (10.7 ms)", v: 4 }, { t: "1024 (21 ms)", v: 5 }], def: 3, mirror: "adv_audio_buffer" },
        { key: "audioRate", area: "AUDIO", label: "SAMPLE RATE (RESTART NEEDED)", kind: "choice", choices: [{ t: "44.1 kHz", v: 44100 }, { t: "48 kHz", v: 48000 }], def: 48000, mirror: "adv_audio_rate" },
        { key: "headroom", area: "AUDIO", label: "MASTER HEADROOM (LOWERS THE MASTER OUTPUT)", kind: "number", min: 0, max: 12, step: 0.5, fine: 0.1, decimals: 1, unit: "dB", def: 0 },
        // ---- START (values the app starts with) ----
        { key: "stickAuto", area: "START", label: "READ REKORDBOX STICKS", kind: "choice", choices: [{ t: "AUTOMATIC", v: 1 }, { t: "ON REQUEST", v: 0 }], def: 1, mirror: "adv_stick_auto" },
        { key: "startTempoRange", area: "START", label: "TEMPO RANGE AT START", kind: "choice", choices: [{ t: "LAST USED", v: 0 }, { t: "6%", v: 0.06 }, { t: "10%", v: 0.10 }, { t: "16%", v: 0.16 }, { t: "WIDE", v: 1.0 }], def: 0.06 },
        // ---- WAVEFORM ----
        { key: "waveGain", area: "WAVEFORM", label: "WAVEFORM HEIGHT (SCALE)", kind: "number", min: 0.5, max: 1.5, step: 0.05, fine: 0.01, decimals: 2, unit: "x", def: 1 },
        { key: "beatGridAlpha", area: "WAVEFORM", label: "BEAT GRID LINES BRIGHTNESS", kind: "number", min: 0, max: 100, step: 5, fine: 1, decimals: 0, unit: "%", def: 90 },
        { key: "zoomStart", area: "WAVEFORM", label: "ZOOM AFTER START", kind: "number", min: 0.3, max: 30, step: 0.5, fine: 0.1, decimals: 1, unit: "", def: 3 },
        { key: "zoomMin", area: "WAVEFORM", label: "ZOOM LIMIT: MOST DETAIL", kind: "number", min: 0.1, max: 5, step: 0.1, fine: 0.05, decimals: 2, unit: "", def: 0.3 },
        { key: "zoomMax", area: "WAVEFORM", label: "ZOOM LIMIT: MOST OVERVIEW", kind: "number", min: 5, max: 60, step: 1, fine: 0.5, decimals: 1, unit: "", def: 30 },
        // ---- WINDOW ----
        { key: "windowSec", area: "WINDOW", label: "WINDOWS CLOSE AFTER (BEAT FX, JOGWHEEL, BRIGHTNESS)", kind: "number", min: 1, max: 30, step: 0.5, fine: 0.1, decimals: 1, unit: "s", def: 3 },
        { key: "menuIdleSec", area: "WINDOW", label: "LIBRARY / MENU CLOSE AFTER IDLE", kind: "number", min: 10, max: 900, step: 10, fine: 1, decimals: 0, unit: "s", def: 180 },
        { key: "afterLoadMs", area: "WINDOW", label: "LIBRARY CLOSES AFTER LOAD", kind: "number", min: 0, max: 3000, step: 50, fine: 10, decimals: 0, unit: "ms", def: 250 },
        { key: "longPressSec", area: "WINDOW", label: "LONG PRESS (TRACK MENU)", kind: "number", min: 0.2, max: 2, step: 0.1, fine: 0.05, decimals: 2, unit: "s", def: 0.5 },
        // ---- JOGWHEEL (controls of the engine, used by the FLX4 script) ----
        { key: "backspin_length", area: "JOGWHEEL", label: "BACK SPIN LENGTH", kind: "choice", choices: [{ t: "SHORT", v: 0 }, { t: "NORMAL", v: 1 }, { t: "LONG", v: 2 }], def: 1, control: true },
        { key: "vinyl_stop_sec", area: "JOGWHEEL", label: "VINYL SPEED ADJUST - STOP TIME (PLAY -> PAUSE, 0 = OFF)", kind: "number", min: 0, max: 5, step: 0.1, fine: 0.01, decimals: 2, unit: "s", def: 0, control: true },
        { key: "vinyl_start_sec", area: "JOGWHEEL", label: "VINYL SPEED ADJUST - START TIME (PAUSE -> PLAY, 0 = OFF)", kind: "number", min: 0, max: 5, step: 0.1, fine: 0.01, decimals: 2, unit: "s", def: 0, control: true },
        // BACK SPIN depends on how hard the jog was turned (speeds in times of the normal speed of the wheel)
        { key: "backspin_sens", area: "JOGWHEEL", label: "BACK SPIN SENSITIVITY (START SPEED PER TURN SPEED)", kind: "number", min: 0.1, max: 3, step: 0.1, fine: 0.01, decimals: 2, unit: "x", def: 1, control: true },
        { key: "backspin_min_rate", area: "JOGWHEEL", label: "BACK SPIN: SLOWEST START SPEED", kind: "number", min: 0.5, max: 10, step: 0.5, fine: 0.1, decimals: 1, unit: "x", def: 2, control: true },
        { key: "backspin_max_rate", area: "JOGWHEEL", label: "BACK SPIN: FASTEST START SPEED", kind: "number", min: 2, max: 30, step: 1, fine: 0.5, decimals: 1, unit: "x", def: 12, control: true }
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
        return null;
    }
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

    data: [
        Mixxx.ControlProxy {
            id: pMasterGain

            group: "[Main]"
            key: "gain"
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
        root.applyHeadroom();
        try {
            const list = JSON.parse(Mixxx.Config.androidSetting("adv_presets", "[]"));
            if (Array.isArray(list))
                root.presets = list;
        } catch (e) {
        }
    }
}
