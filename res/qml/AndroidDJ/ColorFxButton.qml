import "../AdvSettings"
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

    // While the list is open: orange frame and tint (like the chosen button of the top bar).
    border.color: list.opened ? "#ff6a3d" : (root.active ? root.activeColor : "#4a4a4a")
    border.width: list.opened ? 2 : 1
    // Solid (not see-through): the waveform behind must not shine through the text.
    color: list.opened ? "#3a2016" : (root.active ? "#10303f" : "#202020")
    opacity: 1.0

    Mixxx.ControlProxy { id: colorFx; group: "[AndroidDJ]"; key: "color_fx" }
    Mixxx.ControlProxy { id: colorFxOn; group: "[AndroidDJ]"; key: "color_fx_on" }
    Mixxx.ControlProxy { id: colorFxQuiet; group: "[AndroidDJ]"; key: "color_fx_quiet" }

    // Time of the last touch or change in this window: it is not closed by the controller
    // while the user is still setting something here.
    property double keptAt: 0
    function keep() {
        root.keptAt = Date.now();
        autoCloseTimer.restart();
    }
    function closeWindow() {
        if (Date.now() - root.keptAt < 1500)
            return;
        list.close();
    }

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

        // Same time as the other windows (ADVANCED SETTINGS > WINDOW).
        interval: Math.round(AdvSettings.values.windowCloseSec * 1000)

        onTriggered: list.close()
    }
    Connections {
        function onValueChanged() {
            Mixxx.Config.setAndroidSetting("colorFx", String(root.selected));
            // Changed by SMART FADER (not by a tap on the list): show the list.
            if (root.listEnabled && !list.tapped && colorFxQuiet.value <= 0) {
                if (!list.opened)
                    list.open();
                root.keep();
            }
        }

        target: colorFx
    }

    Text {
        anchors.centerIn: parent
        color: root.active ? root.activeColor : "#c0c0c0"
        elide: Text.ElideRight
        font.bold: true
        // Smaller on low screens (phones), so that the whole name fits.
        font.pixelSize: Math.round(Math.min(root.width * 0.5, (root.height - 8) / Math.max(1, text.length * 0.66)))
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
                root.keep();
            }
        }
    }

    Popup {
        id: list

        // True while an entry is being selected by a tap.
        property bool tapped: false

        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        // Modal: a touch beside the window only closes it (it must not move the waveform);
        // a touch on the button at the edge closes it that way, too.
        modal: true
        dim: false
        padding: 4
        // Next to the button: its name stays visible, a tap on it closes the list.
        x: root.width
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
