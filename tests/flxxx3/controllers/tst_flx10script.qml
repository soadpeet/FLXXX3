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

    // The BEAT FX selector loads the Beat FX of the app; ON/OFF switches it.
    function test_beatFxSelectorAndOnOff() {
        const g = "[EffectRack1_EffectUnit1_Effect1]";
        flx10.beatFxPad(4, 0x24, 0x7F, 0x94, g);   // position 5: REVERB
        compare(engine.getValue(g, "loaded_effect"), 6);
        flx10.beatFxOnOff(4, 0x47, 0x7F, 0x94, g);
        compare(engine.getValue(g, "enabled"), 1);
        flx10.beatFxPad(4, 0x2A, 0x7F, 0x94, g);   // position 11: SLIP ROLL, not in the app
        compare(engine.getValue(g, "enabled"), 0);
        flx10.beatFxPad(4, 0x21, 0x7F, 0x94, g);   // position 2: ECHO, still on
        compare(engine.getValue(g, "loaded_effect"), 2);
        compare(engine.getValue(g, "enabled"), 1);
        flx10.beatFxOnOff(4, 0x47, 0x7F, 0x94, g); // OFF: ECHO rings out
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
