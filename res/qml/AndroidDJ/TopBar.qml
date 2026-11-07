import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import "." as DJ

// Top bar modelled on the XDJ-RX3: browse buttons on the left, controller and
// USB status on the right.
Rectangle {
    id: root

    // Name of the button whose view is currently shown ("" = none).
    property string activeButton: ""
    readonly property var buttons: ["SOURCE", "BROWSE", "TAG LIST", "PLAYLIST", "SEARCH", "UTILITY"]
    // Buttons without a counterpart in Mixxx yet are shown dimmed.
    readonly property var disabledButtons: ["TAG LIST"]

    signal buttonClicked(string name)

    color: "#161616"

    Row {
        spacing: 6

        anchors {
            bottom: parent.bottom
            bottomMargin: 3
            left: parent.left
            leftMargin: 6
            top: parent.top
            topMargin: 3
        }

        Repeater {
            model: root.buttons

            Rectangle {
                id: button

                required property string modelData
                readonly property bool enabledButton: root.disabledButtons.indexOf(modelData) < 0
                readonly property bool selected: root.activeButton === modelData

                border.color: selected ? "#ff6a3d" : "#4a4a4a"
                border.width: selected ? 2 : 1
                color: selected ? Qt.alpha("#ff6a3d", 0.22) : (tap.pressed ? "#2a2a2a" : "#1e1e1e")
                height: parent.height
                radius: 3
                // Narrower buttons on narrow screens (tablet): they must not run
                // into the status chips on the right.
                width: Math.max(40, Math.min(Math.round(root.height * 2.6),
                        (root.width - indicators.width - 30 - 5 * 6) / 6))

                Text {
                    anchors.centerIn: parent
                    color: !button.enabledButton ? "#555555" : (button.selected ? "#ff6a3d" : "#e0e0e0")
                    font.bold: true
                    font.pixelSize: Math.round(root.height * 0.38)
                    text: button.modelData
                }
                TapHandler {
                    id: tap

                    enabled: button.enabledButton

                    onTapped: root.buttonClicked(button.modelData)
                }
            }
        }
    }
    Row {
        id: indicators

        spacing: 8

        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }

        // Green while the controller is connected, red while it is not.
        DJ.StatusChip {
            active: true
            activeColor: Mixxx.AndroidStatus.controllerConnected ? "#27e07a" : "#ff4d4d"
            anchors.verticalCenter: parent.verticalCenter
            fontSize: root.height * 0.36
            text: Mixxx.AndroidStatus.controllerConnected && Mixxx.AndroidStatus.controllerName
                  ? Mixxx.AndroidStatus.controllerName : "DDJ-FLX4"
        }
        // USB1 / USB2: grey = no stick, blue = plugged in, red = being accessed
        // (do not remove); the chip blinks while it is accessed.
        DJ.StatusChip {
            id: usb1Chip

            active: Mixxx.AndroidStatus.stick1Present
            activeColor: Mixxx.AndroidStatus.stick1Busy ? "#ff4d4d" : "#27a8e0"
            anchors.verticalCenter: parent.verticalCenter
            fontSize: root.height * 0.36
            text: "USB1"

            // Blinks while the stick is being accessed.
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: Mixxx.AndroidStatus.stick1Busy

                NumberAnimation { duration: 250; to: 0.25 }
                NumberAnimation { duration: 250; to: 1.0 }

                onStopped: usb1Chip.opacity = 1.0
            }
        }
        DJ.StatusChip {
            id: usb2Chip

            active: Mixxx.AndroidStatus.stick2Present
            activeColor: Mixxx.AndroidStatus.stick2Busy ? "#ff4d4d" : "#27a8e0"
            anchors.verticalCenter: parent.verticalCenter
            fontSize: root.height * 0.36
            text: "USB2"

            // Blinks while the stick is being accessed.
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: Mixxx.AndroidStatus.stick2Busy

                NumberAnimation { duration: 250; to: 0.25 }
                NumberAnimation { duration: 250; to: 1.0 }

                onStopped: usb2Chip.opacity = 1.0
            }
        }
    }
}
