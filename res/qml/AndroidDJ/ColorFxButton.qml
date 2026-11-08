import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// Color FX button at the left edge of the upper waveform: the name of the
// selected Color FX stands vertically on it. Blue while the Color FX is on
// (SMART CFX of the controller), grey while it is off. Tapping it opens the
// list of the Color FX. The controller's SMART FADER selects the next one (down
// the list), SHIFT + SMART FADER the previous one. The effects themselves do not
// exist yet: this is the operation only.
Rectangle {
    id: root

    readonly property var names: ["SPACE", "DUB ECHO", "CRUSH", "SWEEP", "NOISE", "FILTER"]
    readonly property int selected: Math.max(0, Math.min(root.names.length - 1, Math.round(colorFx.value)))
    readonly property bool active: colorFxOn.value > 0

    // Like the USB status chips: thin outline and a faint tint in the active colour,
    // the text in the active colour (not a solid blue fill).
    readonly property color activeColor: "#27a8e0"

    border.color: root.active ? root.activeColor : "#4a4a4a"
    border.width: 1
    color: root.active ? Qt.alpha(root.activeColor, 0.18) : "#202020"
    opacity: 0.92

    Mixxx.ControlProxy { id: colorFx; group: "[AndroidDJ]"; key: "color_fx" }
    Mixxx.ControlProxy { id: colorFxOn; group: "[AndroidDJ]"; key: "color_fx_on" }

    // False for the first moments after the start: restoring the saved selection
    // must not open the list.
    property bool listEnabled: false

    // The selection is kept over restarts.
    Component.onCompleted: {
        const saved = parseInt(Mixxx.Config.androidSetting("colorFx", "5"));
        if (!isNaN(saved) && saved >= 0 && saved < root.names.length)
            colorFx.value = saved;
        enableTimer.start();
        // The Color FX is off after every start (SMART CFX switches it on).
        colorFxOn.value = 0;
    }
    Timer {
        id: enableTimer

        interval: 3000

        onTriggered: root.listEnabled = true
    }
    // The list closes 3 seconds after the last change or touch.
    Timer {
        id: autoCloseTimer

        interval: 3000

        onTriggered: list.close()
    }
    Connections {
        function onValueChanged() {
            Mixxx.Config.setAndroidSetting("colorFx", String(root.selected));
            // Changed by SMART FADER (not by a tap on the list): show the list.
            if (root.listEnabled && !list.tapped) {
                if (!list.opened)
                    list.open();
                autoCloseTimer.restart();
            }
        }

        target: colorFx
    }

    Text {
        anchors.centerIn: parent
        color: root.active ? root.activeColor : "#c0c0c0"
        elide: Text.ElideRight
        font.bold: true
        font.pixelSize: Math.round(root.width * 0.5)
        horizontalAlignment: Text.AlignHCenter
        rotation: -90
        text: root.names[root.selected]
        width: root.height - 8
    }
    TapHandler {
        onTapped: {
            if (list.opened) {
                list.close();
            } else {
                list.open();
                autoCloseTimer.restart();
            }
        }
    }

    Popup {
        id: list

        // True while an entry is being selected by a tap.
        property bool tapped: false

        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        padding: 4
        // The list covers the button (more of the waveform stays visible).
        x: 0
        y: 0

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        // A touch on the list keeps it open.
        PointHandler {
            onActiveChanged: autoCloseTimer.restart()
        }

        Column {
            spacing: 3

            Repeater {
                model: root.names

                Rectangle {
                    id: entry

                    required property int index
                    required property string modelData

                    border.color: root.selected === index ? "#1f8fe0" : "#3a3a3a"
                    color: root.selected === index ? "#1f6fe0" : (entryTap.pressed ? "#3a3a3a" : "#202020")
                    height: Math.round(root.width * 1.1)
                    width: Math.round(root.width * 4.2)

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: Math.round(root.width * 0.5)
                        text: entry.modelData
                    }
                    TapHandler {
                        id: entryTap

                        onTapped: {
                            list.tapped = true;
                            colorFx.value = entry.index;
                            list.tapped = false;
                            list.close();
                        }
                    }
                }
            }
        }
    }
}
