import "../AdvSettings"
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// JOGWHEEL window (opened with the JOGWHEEL button on the lower waveform, it
// covers the button). VINYL SPEED ADJUST (TOUCH) for both decks together:
// STOP is the time that a touched deck needs to slow down to a stop, START the
// time that it needs to speed up again when it is released (a slider, 0 - 5 s;
// 0 seconds = off). BACK SPIN LENGTH: how long the track spins back (BACK SPIN itself is
// switched on or off in the UTILITY menu). The settings are saved and used by
// the FLX4 script. The window closes itself a moment after the last touch.
Popup {
    id: root

    // Size unit of the texts and controls.
    readonly property real u: Math.max(7, Math.floor(Math.min(root.width / 33, root.height / 16.8)))

    function openWindow() {
        root.open();
        idleTimer.restart();
    }

    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
    modal: false
    padding: 0

    background: Rectangle {
        border.color: "#5a5a5a"
        color: "#141414"
    }

    Mixxx.ControlProxy { id: backspinOn; group: "[AndroidDJ]"; key: "backspin_on" }
    Mixxx.ControlProxy { id: backspinLength; group: "[AndroidDJ]"; key: "backspin_length" }
    Mixxx.ControlProxy { id: vinylStop; group: "[AndroidDJ]"; key: "vinyl_stop_sec" }
    Mixxx.ControlProxy { id: vinylStart; group: "[AndroidDJ]"; key: "vinyl_start_sec" }

    // Saved settings.
    readonly property var proxies: [backspinOn, backspinLength, vinylStop, vinylStart]
    readonly property var keys: ["backspin_on", "backspin_length", "vinyl_stop_sec", "vinyl_start_sec"]
    function save(index) {
        Mixxx.Config.setAndroidSetting("jog_" + root.keys[index], String(root.proxies[index].value));
    }
    Component.onCompleted: {
        for (let i = 0; i < root.keys.length; ++i) {
            const saved = parseFloat(Mixxx.Config.androidSetting("jog_" + root.keys[i], ""));
            if (!isNaN(saved))
                root.proxies[i].value = saved;
        }
    }
    Timer {
        id: idleTimer

        interval: Math.round(AdvSettings.values.windowSec * 1000)

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
            spacing: root.u * 0.35

            FieldLabel { font.pixelSize: root.u * 0.95; text: "BACK SPIN LENGTH" }
            Segmented {
                currentIndex: Math.round(backspinLength.value)
                fontSize: root.u * 1.0
                height: root.u * 2.3
                labels: ["SHORT", "NORMAL", "LONG"]
                width: parent.width

                onActivated: index => {
                    backspinLength.value = index;
                    root.save(1);
                    idleTimer.restart();
                }
            }
            // VINYL SPEED ADJUST (TOUCH): STOP = a touched deck slows down in this
            // time, START = it speeds up again in this time (0 seconds = off).
            Repeater {
                model: [
                    { label: "VINYL SPEED ADJUST  -  STOP", index: 2 },
                    { label: "VINYL SPEED ADJUST  -  START", index: 3 }
                ]

                Item {
                    id: vinyl

                    required property var modelData
                    readonly property var proxy: root.proxies[modelData.index]

                    height: root.u * 4.6
                    width: parent.width

                    FieldLabel {
                        font.pixelSize: root.u * 0.95
                        text: vinyl.modelData.label
                    }
                    // The value: OFF or the seconds.
                    Text {
                        anchors.right: parent.right
                        color: vinyl.proxy.value > 0 ? "#1fb0f0" : "#8a8a8a"
                        font.bold: true
                        font.pixelSize: root.u * 1.1
                        text: vinyl.proxy.value > 0 ? vinyl.proxy.value.toFixed(1) + " sec" : "OFF"
                    }
                    Slider {
                        id: slider

                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        from: 0
                        height: root.u * 3.2
                        snapMode: Slider.SnapAlways
                        stepSize: 0.1
                        to: 5
                        value: vinyl.proxy.value

                        background: Rectangle {
                            color: "#2a2a2a"
                            height: root.u * 1.0
                            radius: height / 2
                            width: slider.availableWidth
                            x: slider.leftPadding
                            y: slider.topPadding + slider.availableHeight / 2 - height / 2

                            Rectangle {
                                color: "#1fb0f0"
                                height: parent.height
                                radius: height / 2
                                width: slider.visualPosition * parent.width
                            }
                        }
                        handle: Rectangle {
                            border.color: "#ffffff"
                            color: slider.pressed ? "#1fb0f0" : "#e0e0e0"
                            height: root.u * 3.2
                            radius: width / 2
                            width: root.u * 3.2
                            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                            y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        }

                        onMoved: {
                            vinyl.proxy.value = Math.round(slider.value * 10) / 10;
                            root.save(vinyl.modelData.index);
                            idleTimer.restart();
                        }
                    }
                }
            }
        }
    }
}
