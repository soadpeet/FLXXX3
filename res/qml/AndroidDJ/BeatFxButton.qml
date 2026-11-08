import "../AdvSettings"
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// Beat FX button at the right edge of the upper waveform: the name of the
// selected Beat FX stands vertically on it (blue while the effect is on, grey
// while it is off). The window with all Beat FX settings (the FX panel) lies
// over the button: it opens with a tap on the button. FX SELECT of the controller shows
// only the list of the effects (the window closes with it). It closes again 3 seconds
// after the last change or touch.
Rectangle {
    id: root

    // Size of the window.
    property real panelWidth: 260
    property real panelHeight: 400
    property bool presetMode: false
    signal presetModeRequested(bool mode)

    // Not shown as on during the first seconds (the effect system loads its first effect
    // enabled and the controller script switches it off again).
    readonly property bool active: root.windowEnabled && enabledProxy.value > 0
    // False for the first seconds after the start (the effect system sets up
    // its first effect then).
    property bool windowEnabled: false
    // All windows of the touch interface close 3 seconds after the last change
    // (controller) or touch.
    // True while the window was opened by FX SELECT (not by a tap): only the list of the
    // effects is shown then and the window closes with the list.
    property bool listOnly: false
    function activity() {
        if (!root.windowEnabled)
            return;
        if (!win.opened) {
            root.listOnly = true;
            win.open();
        }
        autoCloseTimer.restart();
    }
    function touched() {
        autoCloseTimer.restart();
    }

    // Like the USB status chips: thin outline and a faint tint in the active colour and
    // the text in the active colour (not a solid blue fill).
    readonly property color activeColor: "#27a8e0"

    border.color: root.active ? root.activeColor : "#4a4a4a"
    border.width: 1
    // Solid (not see-through): the waveform behind must not shine through the text.
    color: root.active ? "#10303f" : "#202020"
    opacity: 1.0

    Mixxx.ControlProxy { id: enabledProxy; group: "[EffectRack1_EffectUnit1_Effect1]"; key: "enabled" }

    Component.onCompleted: enableTimer.start()
    Timer {
        id: enableTimer

        interval: 12000

        onTriggered: root.windowEnabled = true
    }
    Timer {
        id: autoCloseTimer

        interval: Math.round(AdvSettings.values.windowSec * 1000)

        onTriggered: win.close()
    }

    // The name of the effect stands in the middle of the button (vertical).
    Text {
        id: nameText

        // Length of the name on the button (the free space left and right of it is
        // shared by the two small numbers: each stands in the middle of its gap).
        readonly property real nameLength: Math.min(nameText.implicitWidth,
                root.height - 2 * Math.round(root.width * 1.0))
        readonly property real gap: (root.height - nameText.nameLength) / 2

        anchors.centerIn: parent
        color: root.active ? root.activeColor : "#c0c0c0"
        elide: Text.ElideRight
        font.bold: true
        font.pixelSize: Math.round(root.width * 0.5)
        horizontalAlignment: Text.AlignHCenter
        rotation: -90
        text: panel.effectName.toUpperCase()
        // leaves the lower and upper edge to the two small numbers
        width: nameText.nameLength
    }
    // The deck(s) the effect works on: small, at the lower edge (before the name).
    Item {
        anchors {
            bottom: parent.bottom
            bottomMargin: nameText.gap / 2 - deckText.implicitWidth / 2
            horizontalCenter: parent.horizontalCenter
        }
        height: deckText.implicitWidth
        width: root.width

        Text {
            id: deckText

            anchors.centerIn: parent
            color: root.active ? root.activeColor : "#8a8a8a"
            font.bold: true
            font.pixelSize: Math.round(root.width * 0.3)
            rotation: -90
            text: panel.fxChannelShortTexts[panel.fxChannel]
        }
    }
    // The beat (1/2, 1, ...): small, at the upper edge (behind the name).
    Item {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: nameText.gap / 2 - beatText.implicitWidth / 2
        }
        height: beatText.implicitWidth
        visible: beatText.text.length > 0
        width: root.width

        Text {
            id: beatText

            anchors.centerIn: parent
            color: root.active ? root.activeColor : "#8a8a8a"
            font.bold: true
            font.pixelSize: Math.round(root.width * 0.3)
            rotation: -90
            text: panel.beatEffect ? panel.valueText : ""
        }
    }
    TapHandler {
        onTapped: {
            if (win.opened) {
                win.close();
            } else {
                root.listOnly = false;
                win.open();
                root.touched();
            }
        }
    }

    Popup {
        id: win

        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        height: root.panelHeight
        padding: 0
        // Right edge on the right edge of the button: the window covers it.
        x: root.width - win.width
        y: 0
        width: root.panelWidth

        background: Item {
        }
        contentItem: Item {
            FxPanel {
                id: panel

                height: win.height
                presetMode: root.presetMode
                width: win.width

                onActivity: root.activity()
                onPresetModeRequested: mode => root.presetModeRequested(mode)
            }
            // Opened by FX SELECT: the window closes together with the list of effects.
            Connections {
                function onListOpenChanged() {
                    if (!panel.listOpen && root.listOnly)
                        win.close();
                }

                target: panel
            }
            // A touch inside the window keeps it open.
            PointHandler {
                onActiveChanged: root.touched()
            }
        }
    }
}
