import "../AdvSettings"
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// BRIGHTNESS window (opened with the BRIGHTNESS button on the right edge of the
// lower waveform, it covers the button): NIGHT is gentle on the eyes in the dark,
// NORMAL uses the brightness of the system settings, OUTDOOR is the brightest
// (direct sunlight). The same setting is in the UTILITY menu. The window closes
// itself a moment after the last touch.
Popup {
    id: root

    readonly property real u: Math.max(7, Math.floor(Math.min(root.width / 24, root.height / 9)))

    // Time of the last touch or change in this window: it is not closed by the controller
    // while the user is still setting something here.
    property double keptAt: 0
    function keep() {
        root.keptAt = Date.now();
        idleTimer.restart();
    }
    function closeWindow() {
        if (Date.now() - root.keptAt < 1500)
            return;
        root.close();
    }
    function openWindow() {
        root.open();
        root.keep();
    }

    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
    // Modal: a touch beside the window only closes it (it must not move the waveform);
    // a touch on the button at the edge closes it that way, too.
    modal: true
    dim: false
    padding: 0

    background: Rectangle {
        border.color: "#5a5a5a"
        color: "#141414"
    }

    Mixxx.ControlProxy { id: brightness; group: "[AndroidDJ]"; key: "brightness" }

    Timer {
        id: idleTimer

        interval: Math.round(AdvSettings.values.windowCloseSec * 1000)

        onTriggered: root.close()
    }

    contentItem: Item {
        // A touch inside keeps the window open.
        PointHandler {
            onActiveChanged: idleTimer.restart()
        }

        Column {
            anchors {
                fill: parent
                margins: root.u * 0.7
            }
            spacing: root.u * 0.5

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: root.u * 1.2
                text: "BRIGHTNESS"
            }
            // Left: gentle on the eyes in the dark, middle: normal, right: the
            // brightest for direct sunlight.
            Segmented {
                currentIndex: Math.round(brightness.value)
                fontSize: root.u * 1.0
                height: root.u * 2.6
                labels: ["NIGHT", "NORMAL", "OUTDOOR"]
                width: parent.width

                onActivated: index => {
                    brightness.value = index;
                    root.keep();
                }
            }
        }
    }
}
