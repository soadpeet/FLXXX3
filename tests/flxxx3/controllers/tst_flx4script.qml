// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// Tests of the DDJ-FLX4 mapping (res/controllers/Pioneer-DDJ-FLX4-script.js and .midi.xml)
// without Mixxx: the script runs against the stand-in engine of mixxxmock.js.
// Run: tools/run_tests.sh
import QtQuick
import QtTest
import "mixxxmock.js" as Mock

TestCase {
    name: "FLX4Script"

    readonly property string controllersUrl: Qt.resolvedUrl("../../../res/controllers/")
    readonly property int sampleRate: 44100
    property var engine
    property var midi
    property var flx4

    // Position in a track as Mixxx counts it (samples of both channels).
    function seconds(s) {
        return s * sampleRate * 2;
    }

    function init() {
        const loaded = Mock.loadMapping(controllersUrl, "Pioneer-DDJ-FLX4-script.js", "PioneerDDJFLX4");
        engine = loaded.engine;
        midi = loaded.midi;
        flx4 = loaded.object;
    }

    // A 60 s track on deck 1 at 30 s with memory cues (hotcues 17..36).
    function loadTrackWithMemoryCues() {
        const g = "[Channel1]";
        engine.set(g, "track_loaded", 1);
        engine.set(g, "track_samples", seconds(60));
        engine.set(g, "track_samplerate", sampleRate);
        engine.set(g, "playposition", 0.5);
        const cues = [
            {n: 17, at: 10, type: 1},
            {n: 18, at: 40, type: 1},
            {n: 19, at: 30.1, type: 1},  // closer than 0.25 s: never called from 30 s
            {n: 20, at: 50, type: 4},    // memory loop
            {n: 21, at: 20, type: 1, unset: true},
        ];
        cues.forEach(function(c) {
            engine.set(g, "hotcue_" + c.n + "_status", c.unset ? 0 : 1);
            engine.set(g, "hotcue_" + c.n + "_position", seconds(c.at));
            engine.set(g, "hotcue_" + c.n + "_type", c.type);
        });
        // Hotcues A..H must not be called as memory cues.
        engine.set(g, "hotcue_1_status", 1);
        engine.set(g, "hotcue_1_position", seconds(35));
        return g;
    }

    function test_mappingFunctionsExist() {
        const xml = Mock.readFile(controllersUrl + "Pioneer-DDJ-FLX4.midi.xml");
        const re = /<key>PioneerDDJFLX4\.([A-Za-z0-9_.]+)<\/key>/g;
        let match;
        let count = 0;
        while ((match = re.exec(xml)) !== null) {
            let target = flx4;
            match[1].split(".").forEach(function(part) {
                target = target === undefined ? undefined : target[part];
            });
            verify(typeof target === "function", "PioneerDDJFLX4." + match[1] + " is not a function");
            count++;
        }
        verify(count > 40, "only " + count + " script functions found in the mapping");
    }

    function test_initAndShutdown() {
        flx4.init();
        verify(midi.sent.length > 0, "init sends the lights");
        verify(engine.connections.length > 0);
        if (typeof flx4.shutdown === "function") {
            flx4.shutdown();
        }
    }

    function test_memoryCueNext() {
        const g = loadTrackWithMemoryCues();
        flx4.cueLoopCallRight(0, 0, 0x7f, 0x90, g);
        compare(engine.written(g, "hotcue_18_goto"), [1, 0]);
        compare(engine.getValue(g, "cue_point"), seconds(40));
        compare(engine.written(g, "hotcue_19_goto"), []);
        compare(engine.written(g, "hotcue_1_goto"), []);
    }

    function test_memoryCuePrevious() {
        const g = loadTrackWithMemoryCues();
        flx4.cueLoopCallLeft(0, 0, 0x7f, 0x90, g);
        // 21 at 20 s is not set: 17 at 10 s.
        compare(engine.written(g, "hotcue_17_goto"), [1, 0]);
        compare(engine.written(g, "hotcue_21_goto"), []);
        compare(engine.getValue(g, "cue_point"), seconds(10));
    }

    function test_memoryLoopStartsLoop() {
        const g = loadTrackWithMemoryCues();
        engine.set(g, "playposition", 45 / 60);
        flx4.cueLoopCallRight(0, 0, 0x7f, 0x90, g);
        compare(engine.written(g, "hotcue_20_gotoandloop"), [1, 0]);
        compare(engine.written(g, "hotcue_20_goto"), []);
        compare(engine.getValue(g, "cue_point"), seconds(50));
    }

    function test_memoryCueNoneAfterLast() {
        const g = loadTrackWithMemoryCues();
        engine.set(g, "playposition", 55 / 60);
        engine.writes = [];
        flx4.cueLoopCallRight(0, 0, 0x7f, 0x90, g);
        compare(engine.writes.length, 0);
    }

    function test_memoryCueWithoutTrack() {
        const g = "[Channel1]";
        engine.set(g, "hotcue_17_status", 1);
        engine.set(g, "hotcue_17_position", seconds(10));
        flx4.cueLoopCallRight(0, 0, 0x7f, 0x90, g);
        compare(engine.writes.length, 0);
    }

    function test_loopCallScalesActiveLoop() {
        const g = loadTrackWithMemoryCues();
        engine.set(g, "loop_enabled", 1);
        flx4.cueLoopCallLeft(0, 0, 0x7f, 0x90, g);
        flx4.cueLoopCallRight(0, 0, 0x7f, 0x90, g);
        compare(engine.written(g, "loop_scale"), [0.5, 2.0]);
        compare(engine.written(g, "cue_point"), []);
    }

    function test_loopCallReleaseDoesNothing() {
        const g = loadTrackWithMemoryCues();
        flx4.cueLoopCallRight(0, 0, 0, 0x80, g);
        compare(engine.writes.length, 0);
    }

    function test_loadSingle() {
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        flx4.loadPressed(0, 0x46, 0, 0x96, "[Channel1]");
        compare(engine.written("[Channel1]", "LoadSelectedTrack"), [1, 0]);
        compare(engine.activeTimers().length, 0);
    }

    function test_instantDouble() {
        engine.set("[Channel2]", "track_loaded", 1);
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        flx4.loadPressed(0, 0x46, 0, 0x96, "[Channel1]");
        engine.clockMs += 300;
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        // The second press does not load the selected track again ...
        compare(engine.written("[Channel1]", "LoadSelectedTrack"), [1, 0]);
        // ... but copies deck 2 a moment later.
        compare(engine.written("[Channel1]", "CloneFromDeck"), []);
        compare(engine.activeTimers().length, 1);
        engine.runTimers();
        compare(engine.written("[Channel1]", "CloneFromDeck"), [2]);
    }

    function test_instantDoubleDeck2() {
        engine.set("[Channel1]", "track_loaded", 1);
        flx4.loadPressed(0, 0x47, 0x7f, 0x96, "[Channel2]");
        engine.clockMs += 200;
        flx4.loadPressed(0, 0x47, 0x7f, 0x96, "[Channel2]");
        engine.runTimers();
        compare(engine.written("[Channel2]", "CloneFromDeck"), [1]);
    }

    function test_slowSecondPressLoadsAgain() {
        engine.set("[Channel2]", "track_loaded", 1);
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        engine.clockMs += 600;
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        compare(engine.written("[Channel1]", "LoadSelectedTrack"), [1, 1]);
        compare(engine.activeTimers().length, 0);
    }

    function test_doublePressWithEmptyOtherDeck() {
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        engine.clockMs += 200;
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        compare(engine.written("[Channel1]", "LoadSelectedTrack"), [1, 1]);
        compare(engine.activeTimers().length, 0);
    }

    function test_tripleQuickPress() {
        // After an instant double the next quick press is a normal load again.
        engine.set("[Channel2]", "track_loaded", 1);
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        engine.clockMs += 200;
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        engine.clockMs += 200;
        flx4.loadPressed(0, 0x46, 0x7f, 0x96, "[Channel1]");
        compare(engine.written("[Channel1]", "LoadSelectedTrack"), [1, 1]);
    }
}
