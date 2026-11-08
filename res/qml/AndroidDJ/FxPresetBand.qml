import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// Row of quick-access Beat FX presets that replaces the hotcue row (BEAT FX
// button of the panel): 8 slots, 4 above each deck. Tap a slot: select it and
// switch its effect on or off. Hold a slot: choose effect and beat (or percent)
// for it; the editor can also delete it (after a confirmation).
Item {
    id: root

    readonly property var effectList: [
        { name: "DELAY", id: "org.mixxx.effects.delay", beats: true },
        { name: "ECHO", id: "org.mixxx.effects.echo", beats: true },
        { name: "PING PONG", id: "org.mixxx.effects.pingpong", beats: true },
        { name: "REVERB", id: "org.mixxx.effects.reverb", beats: false },
        { name: "FLANGER", id: "org.mixxx.effects.flanger", beats: true },
        { name: "PHASER", id: "org.mixxx.effects.phaser", beats: true },
        { name: "FILTER", id: "org.mixxx.effects.sweepfilter", beats: true },
        // New ones are appended: saved presets store the index in this list.
        { name: "SPIRAL", id: "org.mixxx.effects.spiral", beats: true },
        { name: "HELIX", id: "org.mixxx.effects.helix", beats: true },
        { name: "TRANS", id: "org.mixxx.effects.trans", beats: true }
    ]
    readonly property var beatValues: [0.0625, 0.125, 0.25, 0.5, 0.75, 1, 2, 4, 8]
    readonly property var beatTexts: ["1/16", "1/8", "1/4", "1/2", "3/4", "1", "2", "4", "8"]
    readonly property var percentValues: [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    // Each preset: { effect: index in effectList, value: index in beatValues
    // (delay effects) or in percentValues (other effects) } or null.
    property var presets: [null, null, null, null, null, null, null, null]
    // Only a field with an effect can be selected (marked); editSlot is the
    // field of the editor (hold), which can also be an empty one.
    property int selected: -1
    property int editSlot: -1
    property int activeSlot: -1
    property int editEffect: 0
    property int editValue: 5
    readonly property var fxSlot: Mixxx.EffectsManager.getEffectSlot(1, 1)
    readonly property real fontSize: Math.max(8, root.height * 0.42)

    function load() {
        try {
            const stored = JSON.parse(Mixxx.Config.androidSetting("fxPresets", ""));
            if (Array.isArray(stored)) {
                const loaded = [];
                for (let i = 0; i < 8; ++i) {
                    const p = i < stored.length ? stored[i] : null;
                    if (!p) {
                        loaded.push(null);
                    } else if (p.value !== undefined) {
                        loaded.push(p);
                    } else {
                        // older format (beat index of a shorter list)
                        loaded.push({ effect: p.effect, value: (p.beat || 0) + 1 });
                    }
                }
                root.presets = loaded;
            }
        } catch (e) {
        }
    }
    function save() {
        Mixxx.Config.setAndroidSetting("fxPresets", JSON.stringify(root.presets));
    }
    function setPreset(slot, value) {
        const copy = root.presets.slice();
        copy[slot] = value;
        root.presets = copy;
        root.save();
    }
    function slotText(slot) {
        const p = root.presets[slot];
        if (!p)
            return "";
        const effect = root.effectList[p.effect];
        return effect.name + " " + (effect.beats ? root.beatTexts[p.value] : root.percentValues[p.value] + "%");
    }
    function applySlot(slot) {
        const p = root.presets[slot];
        if (!p)
            return;
        if (root.activeSlot === slot && fxEnabled.value > 0) {
            fxEnabled.value = 0;
            root.activeSlot = -1;
            return;
        }
        const effect = root.effectList[p.effect];
        if (root.fxSlot)
            root.fxSlot.effectId = effect.id;
        if (!effect.noParameter)
            fxParameter1.parameter = effect.beats ? root.beatValues[p.value] / 8 : root.percentValues[p.value] / 100;
        fxEnabled.value = 1;
        root.activeSlot = slot;
    }
    // Hold: edit this slot.
    function openSettings(slot) {
        root.editSlot = slot;
        const p = root.presets[slot];
        root.editEffect = p ? p.effect : 0;
        root.editValue = p ? p.value : 5;
        editor.open();
    }
    function defaultValue(effectIndex) {
        // 1 beat for the delay effects, 50 % for the others
        return root.effectList[effectIndex].beats ? 5 : 4;
    }

    Component.onCompleted: root.load()

    Mixxx.ControlProxy { id: fxEnabled; group: "[EffectRack1_EffectUnit1_Effect1]"; key: "enabled" }
    Mixxx.ControlProxy { id: fxParameter1; group: "[EffectRack1_EffectUnit1_Effect1]"; key: "parameter1" }

    // A slot that is switched off elsewhere (controller) is no longer active.
    Connections {
        function onValueChanged(value) {
            if (value <= 0)
                root.activeSlot = -1;
        }

        target: fxEnabled
    }

    Row {
        anchors.fill: parent
        spacing: 2

        // Left half (above deck 1): slots 1-4; right half (above deck 2): 5-8.
        Repeater {
            model: 2

            Row {
                id: half

                required property int index

                height: parent.height
                spacing: 2
                width: (parent.width - 2) / 2

                Repeater {
                    model: 4

                    Rectangle {
                        id: cell

                        readonly property int slot: half.index * 4 + index
                        required property int index

                        // The active preset: outline and faint tint like the USB status chips.
                        border.color: root.activeSlot === slot ? "#27a8e0" : (root.selected === slot ? "#1fb0f0" : "#4a4a4a")
                        border.width: root.selected === slot || root.activeSlot === slot ? 2 : 1
                        color: root.activeSlot === slot ? Qt.alpha("#27a8e0", 0.18) : (root.selected === slot ? "#10293f" : "#1a1a1a")
                        height: half.height
                        width: (half.width - half.spacing * 3) / 4

                        Text {
                            anchors.centerIn: parent
                            color: root.activeSlot === cell.slot ? "#27a8e0" : "#ffffff"
                            elide: Text.ElideRight
                            font.bold: true
                            font.pixelSize: root.fontSize
                            horizontalAlignment: Text.AlignHCenter
                            text: root.slotText(cell.slot)
                            width: parent.width - 4
                        }
                        TapHandler {
                            // Tap: select and switch on / off. Hold: edit. A tap counts
                            // as long as the finger stays on the field.
                            gesturePolicy: TapHandler.WithinBounds
                            longPressThreshold: 0.5

                            onLongPressed: root.openSettings(cell.slot)
                            onTapped: {
                                // empty fields cannot be selected
                                if (root.presets[cell.slot]) {
                                    root.selected = cell.slot;
                                    root.applySlot(cell.slot);
                                } else {
                                    root.selected = -1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Choose effect and beat for the selected slot.
    Popup {
        id: editor

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape
        height: 380
        modal: true
        width: 640

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            anchors.fill: parent
            spacing: 12

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 22
                text: "BEAT FX " + (root.editSlot + 1)
            }
            Flow {
                spacing: 8
                width: parent.width

                Repeater {
                    model: root.effectList

                    Rectangle {
                        required property int index
                        required property var modelData

                        border.color: "#5a5a5a"
                        color: root.editEffect === index ? "#1f6fe0" : "#202020"
                        height: 44
                        width: 120

                        Text {
                            anchors.centerIn: parent
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 16
                            text: parent.modelData.name
                        }
                        TapHandler {
                            onTapped: {
                                root.editEffect = parent.index;
                                root.editValue = root.defaultValue(parent.index);
                            }
                        }
                    }
                }
            }
            Text {
                color: "#cfcfcf"
                font.pixelSize: 16
                text: root.effectList[root.editEffect].beats ? "BEAT" : "%"
            }
            Row {
                spacing: 8

                Repeater {
                    model: root.effectList[root.editEffect].beats ? root.beatTexts : root.percentValues

                    Rectangle {
                        required property int index
                        required property var modelData

                        border.color: "#5a5a5a"
                        color: root.editValue === index ? "#1f6fe0" : "#202020"
                        height: 44
                        width: 50

                        Text {
                            anchors.centerIn: parent
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 15
                            text: parent.modelData
                        }
                        TapHandler {
                            onTapped: root.editValue = parent.index
                        }
                    }
                }
            }
            Row {
                spacing: 12

                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#1f6fe0"
                    height: 44
                    width: 140

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 18
                        text: "OK"
                    }
                    TapHandler {
                        onTapped: {
                            root.setPreset(root.editSlot, { effect: root.editEffect, value: root.editValue });
                            root.selected = root.editSlot;
                            editor.close();
                        }
                    }
                }
                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#202020"
                    height: 44
                    width: 140

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.pixelSize: 18
                        text: "CANCEL"
                    }
                    TapHandler {
                        onTapped: editor.close()
                    }
                }
                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#c0392b"
                    height: 44
                    opacity: root.editSlot >= 0 && root.presets[root.editSlot] ? 1.0 : 0.35
                    width: 140

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 18
                        text: "DELETE"
                    }
                    TapHandler {
                        onTapped: {
                            if (root.editSlot >= 0 && root.presets[root.editSlot]) {
                                editor.close();
                                confirmDelete.open();
                            }
                        }
                    }
                }
            }
        }
    }

    // Confirmation before a preset is deleted.
    Popup {
        id: confirmDelete

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape
        height: 190
        modal: true
        width: 460

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            anchors.fill: parent
            spacing: 18

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 22
                text: "Delete this effect?"
            }
            Text {
                color: "#cfcfcf"
                font.pixelSize: 18
                text: root.editSlot >= 0 ? root.slotText(root.editSlot) : ""
            }
            Row {
                spacing: 12

                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#c0392b"
                    height: 44
                    width: 140

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 18
                        text: "DELETE"
                    }
                    TapHandler {
                        onTapped: {
                            if (root.activeSlot === root.editSlot) {
                                fxEnabled.value = 0;
                                root.activeSlot = -1;
                            }
                            root.setPreset(root.editSlot, null);
                            // the deleted field is no longer marked
                            root.selected = -1;
                            confirmDelete.close();
                        }
                    }
                }
                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#202020"
                    height: 44
                    width: 140

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.pixelSize: 18
                        text: "CANCEL"
                    }
                    TapHandler {
                        onTapped: confirmDelete.close()
                    }
                }
            }
        }
    }
}
