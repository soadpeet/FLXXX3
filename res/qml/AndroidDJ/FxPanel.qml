import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import "." as DJ

// Right-hand side panel next to the waveforms (modelled on the RX3 BEAT FX
// panel): effect name, master BPM / beat length, waveform zoom. The effect
// selection itself follows with the Beat FX work; it is shown dimmed until then.
Rectangle {
    id: root

    // Sized so that all parts (about 20 units high) fit into the panel.
    readonly property real unit: Math.max(7, root.height / 21)
    // Master tempo: the BPM of the master deck (or of the deck that is loaded);
    // 120.0 while no track is loaded.
    readonly property bool anyLoaded: loaded1.value > 0 || loaded2.value > 0
    readonly property real masterBpm: {
        const masterDeck = Math.round(masterDeckControl.value);
        if (masterDeck === 1 && loaded1.value > 0 && bpm1.value > 0)
            return bpm1.value;
        if (masterDeck === 2 && loaded2.value > 0 && bpm2.value > 0)
            return bpm2.value;
        if (loaded1.value > 0 && bpm1.value > 0)
            return bpm1.value;
        if (loaded2.value > 0 && bpm2.value > 0)
            return bpm2.value;
        return 120.0;
    }
    // STATUS shows the hotcue row, BEAT FX the row of Beat FX presets.
    property bool presetMode: false
    signal presetModeRequested(bool mode)
    // Beat value of the effect (1/8 .. 2 beats, as the time parameter of the
    // delay effects) and the time that it makes. For the delay effects it
    // follows the parameter (BEAT buttons of the controller).
    readonly property var beatValues: [0.0625, 0.125, 0.25, 0.5, 0.75, 1, 2, 4, 8]
    readonly property var beatTexts: ["1/16", "1/8", "1/4", "1/2", "3/4", "1", "2", "4", "8"]
    property int storedBeatIndex: 5
    // Effects whose first parameter is a time in beats (0 - 8): the delay
    // effects, flanger and phaser. The filter has no tempo parameter (the beat
    // value is only kept for it). Reverb uses percent.
    readonly property string effectIdText: effectSlot && effectSlot.loaded ? effectSlot.effectId : ""
    readonly property bool delayFamily: root.effectIdText === "org.mixxx.effects.delay" ||
            root.effectIdText === "org.mixxx.effects.echo" ||
            root.effectIdText === "org.mixxx.effects.pingpong" ||
            root.effectIdText === "org.mixxx.effects.flanger" ||
            root.effectIdText === "org.mixxx.effects.phaser"
    readonly property bool beatEffect: root.delayFamily || root.effectIdText === "org.mixxx.effects.filter"
    readonly property int beatIndex: {
        if (!root.delayFamily)
            return root.storedBeatIndex;
        const beats = fxParameter1.parameter * 8;
        let nearest = 0;
        for (let i = 1; i < root.beatValues.length; ++i) {
            if (Math.abs(root.beatValues[i] - beats) < Math.abs(root.beatValues[nearest] - beats))
                nearest = i;
        }
        return nearest;
    }
    // Other effects (reverb, flanger ...): the first parameter in percent.
    readonly property int effectPercent: Math.round(fxParameter1.parameter * 100)
    readonly property string valueText: root.beatEffect ? root.beatTexts[root.beatIndex] : String(root.effectPercent)
    readonly property string valueUnit: root.beatEffect ? "BEAT" : "%"
    // LOW / MID / HI: bands the effect works on (all on by default).
    property bool bandLow: true
    property bool bandMid: true
    property bool bandHigh: true
    // The effect chain only works on the selected bands (1 low, 2 mid, 4 high).
    readonly property int bandMask: (root.bandLow ? 1 : 0) | (root.bandMid ? 2 : 0) | (root.bandHigh ? 4 : 0)
    onBandMaskChanged: fxBands.value = root.bandMask
    readonly property real effectMsec: root.anyLoaded
            ? 60000 / root.masterBpm * root.beatValues[root.beatIndex]
            : 2000
    // Channel the effect is applied to: 0 = 1, 1 = 2, 2 = MASTER.
    readonly property int fxChannel: fxChannel1.value > 0 && fxChannel2.value > 0 ? 2 : (fxChannel2.value > 0 ? 1 : 0)
    readonly property var fxChannelTexts: ["1", "2", "BOOTH"]
    function cycleChannel() {
        const next = (root.fxChannel + 1) % 3;
        fxChannel1.value = next === 0 || next === 2 ? 1 : 0;
        fxChannel2.value = next === 1 || next === 2 ? 1 : 0;
    }
    // Beat FX unit 1: the slot that the controller currently focuses.
    readonly property int focusedSlot: Math.max(1, Math.min(3, Math.round(focusedEffectControl.value)))
    readonly property var effectSlot: Mixxx.EffectsManager.getEffectSlot(1, focusedSlot)
    readonly property string effectName: effectSlot && effectSlot.loaded ? effectSlot.effectName : "---"

    // All Beat FX in the order of the Pioneer players. The list opens over the
    // panel whenever the effect changes (FX SELECT on the controller) and
    // closes itself after a moment; tapping an entry loads that effect.
    readonly property var effectList: [
        { name: "DELAY", id: "org.mixxx.effects.delay" },
        { name: "ECHO", id: "org.mixxx.effects.echo" },
        { name: "PING PONG", id: "org.mixxx.effects.pingpong" },
        { name: "REVERB", id: "org.mixxx.effects.reverb" },
        { name: "FLANGER", id: "org.mixxx.effects.flanger" },
        { name: "PHASER", id: "org.mixxx.effects.phaser" },
        { name: "FILTER", id: "org.mixxx.effects.filter" }
    ]
    property bool listOpen: false
    // Ignores the effect change of the start-up default.
    property bool ready: false

    property double listOpenedAt: 0
    function openList() {
        root.listOpen = true;
        root.listOpenedAt = Date.now();
        listTimer.interval = 1500;
        listTimer.restart();
    }
    // Moving any control (knob, button) closes the list at once.
    function closeListSoon() {
        if (root.listOpen && Date.now() - root.listOpenedAt > 500)
            root.listOpen = false;
    }

    Connections {
        function onEffectIdChanged() {
            if (root.ready) {
                root.openList();
                // Defaults: 1 beat for the effects with a time, 50 % for reverb;
                // the filter keeps its own cutoff.
                const id = root.effectSlot ? root.effectSlot.effectId : "";
                root.storedBeatIndex = 5;
                if (id === "org.mixxx.effects.filter") {
                    // nothing to set
                } else if (id === "org.mixxx.effects.reverb") {
                    fxParameter1.parameter = 0.5;
                } else {
                    fxParameter1.parameter = 1.0 / 8;
                }
            }
        }

        target: root.effectSlot
    }
    Connections {
        function onValueChanged() {
            root.closeListSoon();
        }

        target: fxParameter1
    }
    Connections {
        function onValueChanged() {
            root.closeListSoon();
        }

        target: fxMixControl
    }
    Connections {
        function onValueChanged() {
            root.closeListSoon();
        }

        target: fxEnabled
    }
    Timer {
        id: readyTimer

        interval: 4000
        running: true

        onTriggered: {
            root.ready = true;
            // Start with 1 beat for the delay effects (a value saved by the
            // effect from the last session is replaced).
            if (root.delayFamily)
                fxParameter1.parameter = 1.0 / 8;
            // Beat FX start switched off (the effect system loads it enabled).
            fxEnabled.value = 0;
        }
    }
    Timer {
        id: listTimer

        interval: 1500

        onTriggered: root.listOpen = false
    }

    Component.onCompleted: {
        // LOW / MID / HI are all on after every start.
        root.bandLow = true;
        root.bandMid = true;
        root.bandHigh = true;
        fxBands.value = root.bandMask;
        // Start with the first effect of the list (Delay) in slot 1.
        const first = Mixxx.EffectsManager.getEffectSlot(1, 1);
        if (first && !first.loaded) {
            first.effectId = "org.mixxx.effects.delay";
            // Default: 1 beat (the time parameter of the delay effects is 0 - 2 beats).
            fxParameter1.parameter = 1.0 / 8;
        }
    }

    border.color: "#2a2a2a"
    border.width: 1
    color: "#0c0c0c"

    Mixxx.ControlProxy { id: masterDeckControl; group: "[AndroidDJ]"; key: "master_deck" }
    Mixxx.ControlProxy { id: bpm1; group: "[Channel1]"; key: "bpm" }
    Mixxx.ControlProxy { id: bpm2; group: "[Channel2]"; key: "bpm" }
    Mixxx.ControlProxy { id: loaded1; group: "[Channel1]"; key: "track_loaded" }
    Mixxx.ControlProxy { id: loaded2; group: "[Channel2]"; key: "track_loaded" }
    Mixxx.ControlProxy { id: fxBands; group: "[EffectRack1_EffectUnit1]"; key: "bands" }
    Mixxx.ControlProxy { id: fxEnabled; group: "[EffectRack1_EffectUnit1_Effect1]"; key: "enabled" }
    Mixxx.ControlProxy { id: fxMixControl; group: "[EffectRack1_EffectUnit1]"; key: "mix" }
    Mixxx.ControlProxy { id: fxChannel1; group: "[EffectRack1_EffectUnit1]"; key: "group_[Channel1]_enable" }
    Mixxx.ControlProxy { id: fxChannel2; group: "[EffectRack1_EffectUnit1]"; key: "group_[Channel2]_enable" }
    Mixxx.ControlProxy { id: fxParameter1; group: "[EffectRack1_EffectUnit1_Effect1]"; key: "parameter1" }
    Mixxx.ControlProxy { id: focusedEffectControl; group: "[EffectRack1_EffectUnit1]"; key: "focused_effect" }
    Mixxx.ControlProxy { id: zoomIn1; group: "[Channel1]"; key: "waveform_zoom_down" }
    Mixxx.ControlProxy { id: zoomOut1; group: "[Channel1]"; key: "waveform_zoom_up" }
    Mixxx.ControlProxy { id: zoomIn2; group: "[Channel2]"; key: "waveform_zoom_down" }
    Mixxx.ControlProxy { id: zoomOut2; group: "[Channel2]"; key: "waveform_zoom_up" }

    Column {
        spacing: Math.round(root.unit * 0.4)

        anchors {
            fill: parent
            margins: 6
        }

        Text {
            color: "#cfcfcf"
            font.pixelSize: Math.round(root.unit * 0.8)
            horizontalAlignment: Text.AlignHCenter
            text: "BEAT FX"
            width: parent.width
        }
        // Effect name: tap to choose another effect.
        // Blue while the effect is on, grey (like the band switches) while off.
        Rectangle {
            border.color: fxEnabled.value > 0 ? "#1f8fe0" : "#4a4a4a"
            color: fxEnabled.value > 0 ? "#1f6fe0" : "#202020"
            height: Math.round(root.unit * 2.4)
            width: parent.width

            TapHandler {
                onTapped: root.openList()
            }

            Text {
                anchors.centerIn: parent
                color: fxEnabled.value > 0 ? "#ffffff" : "#8a8a8a"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: Math.round(root.unit * 1.2)
                horizontalAlignment: Text.AlignHCenter
                text: root.effectName.toUpperCase()
                width: parent.width - 8
            }
        }
        Text {
            color: "#9a9a9a"
            font.pixelSize: Math.round(root.unit * 0.7)
            horizontalAlignment: Text.AlignHCenter
            text: "CH SELECT"
            width: parent.width
        }
        // Channel of the effect: tap to switch 1 / 2 / MASTER.
        Rectangle {
            border.color: "#3a3a3a"
            color: "#101010"
            height: Math.round(root.unit * 2.0)
            width: parent.width

            TapHandler {
                onTapped: root.cycleChannel()
            }

            Text {
                anchors.centerIn: parent
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(root.unit * 1.2)
                text: root.fxChannelTexts[root.fxChannel]
            }
        }
        // Tempo, time and beat value of the effect.
        Rectangle {
            border.color: "#3a3a3a"
            color: "#101010"
            height: Math.round(root.unit * 6.6)
            width: parent.width

            TapHandler {
                // Tap: next beat value (1/8 ... 16).
                onTapped: {
                    if (root.beatEffect) {
                        const next = (root.beatIndex + 1) % root.beatValues.length;
                        root.storedBeatIndex = next;
                        if (root.delayFamily)
                            fxParameter1.parameter = root.beatValues[next] / 8;
                    } else {
                        // 10 % steps, back to 0 after 100 %
                        fxParameter1.parameter = ((Math.round(fxParameter1.parameter * 10) + 1) % 11) / 10;
                    }
                }
            }

            Column {
                anchors {
                    fill: parent
                    margins: 4
                }
                spacing: 0

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Text {
                        color: "#ffffff"
                        font.pixelSize: Math.round(root.unit * 1.5)
                        text: root.masterBpm.toFixed(1)
                    }
                    Text {
                        anchors.baseline: parent.children[0].baseline
                        color: "#9a9a9a"
                        font.pixelSize: Math.round(root.unit * 0.6)
                        text: "BPM"
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Text {
                        color: "#ffffff"
                        font.pixelSize: Math.round(root.unit * 1.2)
                        text: Math.round(root.effectMsec)
                    }
                    Text {
                        anchors.baseline: parent.children[0].baseline
                        color: "#9a9a9a"
                        font.pixelSize: Math.round(root.unit * 0.6)
                        text: "msec"
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Text {
                        color: "#ffffff"
                        font.pixelSize: Math.round(root.unit * 1.2)
                        text: root.valueText
                    }
                    Text {
                        anchors.baseline: parent.children[0].baseline
                        color: "#9a9a9a"
                        font.pixelSize: Math.round(root.unit * 0.6)
                        text: root.valueUnit
                    }
                }
                Text {
                    color: "#9a9a9a"
                    font.pixelSize: Math.round(root.unit * 0.7)
                    horizontalAlignment: Text.AlignHCenter
                    text: "QUANTIZE"
                    width: parent.width
                }
            }
        }
        // LOW / MID / HI: bands of the effect (each can be switched off).
        Row {
            height: Math.round(root.unit * 1.8)
            spacing: 3
            width: parent.width

            Repeater {
                model: [
                    { name: "LOW", key: "bandLow" },
                    { name: "MID", key: "bandMid" },
                    { name: "HI", key: "bandHigh" }
                ]

                Rectangle {
                    required property var modelData

                    border.color: root[modelData.key] ? "#1f8fe0" : "#4a4a4a"
                    color: root[modelData.key] ? "#1f6fe0" : "#202020"
                    height: parent.height
                    width: (parent.width - 6) / 3

                    Text {
                        anchors.centerIn: parent
                        color: root[parent.modelData.key] ? "#ffffff" : "#8a8a8a"
                        font.bold: true
                        font.pixelSize: Math.round(root.unit * 0.8)
                        text: parent.modelData.name
                    }
                    TapHandler {
                        onTapped: {
                            // At least one band stays on.
                            const others = (root.bandLow ? 1 : 0) + (root.bandMid ? 1 : 0) + (root.bandHigh ? 1 : 0) -
                                    (root[parent.modelData.key] ? 1 : 0);
                            if (root[parent.modelData.key] && others === 0)
                                return;
                            root[parent.modelData.key] = !root[parent.modelData.key];
                            Mixxx.Config.setAndroidSetting(parent.modelData.key, root[parent.modelData.key] ? "1" : "0");
                        }
                    }
                }
            }
        }
        // STATUS (hotcue row) / BEAT FX (row of effect presets).
        Row {
            height: Math.round(root.unit * 2.0)
            width: parent.width

            Rectangle {
                border.color: "#5a5a5a"
                color: root.presetMode ? "#202020" : "#1f6fe0"
                height: parent.height
                width: parent.width / 2

                Text {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.pixelSize: Math.round(root.unit * 0.8)
                    text: "STATUS"
                }
                TapHandler {
                    onTapped: root.presetModeRequested(false)
                }
            }
            Rectangle {
                border.color: "#5a5a5a"
                color: root.presetMode ? "#1f6fe0" : "#202020"
                height: parent.height
                width: parent.width / 2

                Text {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.pixelSize: Math.round(root.unit * 0.8)
                    text: "BEAT FX"
                }
                TapHandler {
                    onTapped: root.presetModeRequested(true)
                }
            }
        }
    }
    // Effect list over the panel.
    Rectangle {
        border.color: "#3a3a3a"
        color: "#0c1622"
        visible: root.listOpen

        anchors.fill: parent

        Column {
            anchors {
                fill: parent
                margins: 4
            }

            Repeater {
                model: root.effectList

                Rectangle {
                    id: entry

                    required property var modelData
                    readonly property bool current: root.effectSlot && root.effectSlot.effectId === modelData.id

                    color: current ? "#1fb0f0" : "transparent"
                    height: parent.height / root.effectList.length
                    width: parent.width

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        color: entry.current ? "#ffffff" : "#cfcfcf"
                        font.bold: entry.current
                        font.pixelSize: Math.min(root.unit * 1.3, entry.height * 0.7)
                        text: entry.modelData.name
                    }
                    TapHandler {
                        onTapped: {
                            if (root.effectSlot) {
                                root.effectSlot.effectId = entry.modelData.id;
                            }
                            // The list closes quickly after a choice.
                            listTimer.interval = 350;
                            listTimer.restart();
                        }
                    }
                }
            }
        }
    }
}
