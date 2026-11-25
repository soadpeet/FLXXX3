// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// A stand-in for the parts of the Mixxx controller script API that the FLX4 mapping uses
// (engine, midi), so that the mapping script runs without Mixxx in qmltestrunner.
// Controls are plain values: getValue returns what setValue (or the test) stored, 0 for
// unknown controls. Every setValue is also recorded in "writes" (group, key, value).
.pragma library

function createEngine() {
    const values = {};
    const engine = {
        values: values,
        writes: [],
        scratching: {},
        scratchTicks: [],
        timers: [],
        connections: [],
        nextTimerId: 1,
        // The clock the script sees through Date (milliseconds); tests move it forward.
        clockMs: 1000000,

        set: function(group, key, value) {
            values[group + "," + key] = value;
        },
        getValue: function(group, key) {
            const v = values[group + "," + key];
            return v === undefined ? 0 : v;
        },
        setValue: function(group, key, value) {
            values[group + "," + key] = value;
            engine.writes.push({group: group, key: key, value: value});
        },
        getParameter: function(group, key) {
            return engine.getValue(group, key);
        },
        setParameter: function(group, key, value) {
            engine.setValue(group, key, value);
        },
        // The values written to group/key, in order.
        written: function(group, key) {
            return engine.writes.filter(function(w) {
                return w.group === group && w.key === key;
            }).map(function(w) {
                return w.value;
            });
        },
        makeConnection: function(group, key, callback) {
            const connection = {
                group: group, key: key, callback: callback, connected: true,
                disconnect: function() {
                    connection.connected = false;
                    return true;
                },
                trigger: function() {
                    callback(engine.getValue(group, key), group, key);
                },
            };
            engine.connections.push(connection);
            return connection;
        },
        connectControl: function() {
            return true;
        },
        trigger: function() {},
        softTakeover: function() {},
        softTakeoverIgnoreNextValue: function() {},
        isScratching: function(deck) {
            return engine.scratching[deck] === true;
        },
        scratchEnable: function(deck) {
            engine.scratching[deck] = true;
        },
        scratchDisable: function(deck) {
            engine.scratching[deck] = false;
        },
        scratchTick: function(deck, ticks) {
            engine.scratchTicks.push([deck, ticks]);
        },
        brake: function() {},
        spinback: function() {},
        beginTimer: function(ms, callback, oneShot) {
            const id = engine.nextTimerId++;
            engine.timers.push({id: id, ms: ms, callback: callback, oneShot: !!oneShot, active: true});
            return id;
        },
        stopTimer: function(id) {
            engine.timers.forEach(function(t) {
                if (t.id === id) {
                    t.active = false;
                }
            });
        },
        // Runs every active timer once (one-shot timers are then stopped).
        runTimers: function() {
            engine.timers.slice().forEach(function(t) {
                if (t.active) {
                    if (t.oneShot) {
                        t.active = false;
                    }
                    t.callback();
                }
            });
        },
        activeTimers: function() {
            return engine.timers.filter(function(t) {
                return t.active;
            });
        },
    };
    return engine;
}

function createMidi() {
    const midi = {
        sent: [],
        sysex: [],
        sendShortMsg: function(status, data1, data2) {
            midi.sent.push([status, data1, data2]);
        },
        sendSysexMsg: function(data, length) {
            midi.sysex.push(data.slice(0, length));
        },
        makeInputHandler: function() {
            return {disconnect: function() {}};
        },
    };
    return midi;
}

function readFile(url) {
    const request = new XMLHttpRequest();
    request.open("GET", url, false);
    request.send();
    return request.responseText;
}

// Loads common-controller-scripts.js and the mapping script with fresh engine and midi
// objects and the test clock (engine.clockMs) as Date. Returns {engine, midi, object} where object is the script's global (for
// example PioneerDDJFLX4).
function loadMapping(controllersUrl, scriptFile, objectName) {
    const engine = createEngine();
    const midi = createMidi();
    const source = readFile(controllersUrl + "common-controller-scripts.js") + "\n" +
        readFile(controllersUrl + scriptFile) + "\nreturn " + objectName + ";";
    // Date with the test clock: Date.now() and new Date() give engine.clockMs.
    const RealDate = Date;
    const TestDate = function() {
        return new RealDate(engine.clockMs);
    };
    TestDate.now = function() {
        return engine.clockMs;
    };
    const object = new Function("engine", "midi", "Date", source)(engine, midi, TestDate);
    return {engine: engine, midi: midi, object: object};
}
