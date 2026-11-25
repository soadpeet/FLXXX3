import "../AdvSettings"
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// JOGWHEEL window (opened with the JOGWHEEL button on the lower waveform, it
// covers the button). VINYL SPEED ADJUST (TOUCH) for both decks together:
// STOP is the time that a touched deck needs to slow down to a stop, START the
// time that it needs to speed up again when it is released (a slider, 0 - 5 s;
// 0 seconds = off). (BACK SPIN is switched on or off in the UTILITY menu; its length,
// sensitivity and limits are in ADVANCED SETTINGS > JOGWHEEL.) The settings are saved and used by
// the FLX4 and FLX10 scripts. The window closes itself a moment after the last touch.
Popup {
    id: root

    // Size unit of the texts and controls.
    readonly property real u: Math.max(7, Math.floor(Math.min(root.width / 33, root.height / 16.8)))

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

    Mixxx.ControlProxy { id: backspinOn; group: "[AndroidDJ]"; key: "backspin_on" }
    Mixxx.ControlProxy { id: vinylStop; group: "[AndroidDJ]"; key: "vinyl_stop_sec" }
    Mixxx.ControlProxy { id: vinylStart; group: "[AndroidDJ]"; key: "vinyl_start_sec" }

    // Saved settings.
    readonly property var proxies: [backspinOn, vinylStop, vinylStart]
    readonly property var keys: ["backspin_on", "vinyl_stop_sec", "vinyl_start_sec"]
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

        interval: Math.round(AdvSettings.values.windowCloseSec * 1000)

        onTriggered: root.close()
    }

    contentItem: Item {
        // A touch inside keeps the window open.
        PointHandler {
            onActiveChanged: idleTimer.restart()
        }

        // The two settings in the middle of the window, large (there is room for it).
        Column {
            anchors {
                left: parent.left
                leftMargin: root.u * 0.9
                right: parent.right
                rightMargin: root.u * 0.9
                verticalCenter: parent.verticalCenter
            }
            spacing: root.u * 1.2

            // VINYL SPEED ADJUST (TOUCH): STOP = a touched deck slows down in this
            // time, START = it speeds up again in this time (0 seconds = off).
            Repeater {
                model: [
                    { label: "VINYL SPEED ADJUST  -  STOP TIME (PLAY \u2192 PAUSE)", index: 1 },
                    { label: "VINYL SPEED ADJUST  -  START TIME (PAUSE \u2192 PLAY)", index: 2 }
                ]

                Item {
                    id: vinyl

                    required property var modelData
                    readonly property var proxy: root.proxies[modelData.index]

                    height: root.u * 7.4
                    width: parent.width

                    FieldLabel {
                        font.pixelSize: root.u * 1.25
                        text: vinyl.modelData.label
                    }
                    // The value: OFF or the seconds.
                    Text {
                        anchors.right: parent.right
                        color: vinyl.proxy.value > 0 ? "#1fb0f0" : "#8a8a8a"
                        font.bold: true
                        font.pixelSize: root.u * 1.5
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
                        height: root.u * 5
                        snapMode: Slider.SnapAlways
                        stepSize: 0.1
                        to: 5
                        value: vinyl.proxy.value

                        background: Rectangle {
                            color: "#2a2a2a"
                            height: root.u * 1.6
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
                            height: root.u * 5
                            radius: width / 2
                            width: root.u * 5
                            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                            y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        }

                        onMoved: {
                            vinyl.proxy.value = Math.round(slider.value * 10) / 10;
                            root.save(vinyl.modelData.index);
                            root.keep();
                        }
                    }
                }
            }
        }
    }
}
