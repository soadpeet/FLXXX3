import Mixxx 1.0 as Mixxx
import QtQuick 2.12

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// CDJ view: the panels of the BEAT LOOP, KEY SHIFT and BEAT JUMP buttons of a deck. They lie over
// the top of the waveform of the deck (like on the CDJ-3000), orange = active.
Rectangle {
    id: root

    // "[Channel1]" or "[Channel2]".
    required property string group
    // "LOOP", "KEY" or "JUMP".
    required property string kind
    // Notation of the keys and the track key (raw text, e.g. "Am" or "8A") for KEY SHIFT.
    property bool keyCamelot: true
    property string keyText: ""
    // Helper of the deck panel: key moved by semitones, written in the selected notation.
    property var shiftedKey: (text, semitones) => text
    // Scale of the texts (one unit of the deck panel).
    property real u: 16

    signal activity

    // BEAT LOOP sizes and the BEAT JUMP sizes of its two pages.
    readonly property var loopSizes: [0.25, 0.5, 1, 2, 4, 8, 16, 32]
    readonly property var jumpPages: [[0.25, 0.5, 1, 2], [4, 8, 16, 32]]
    property int jumpPage: 0

    function sizeText(size) {
        if (size === 0.25)
            return "1/4";
        if (size === 0.5)
            return "1/2";
        return String(size);
    }

    border.color: "#2a2a2a"
    color: "#101010"

    // Swallows touches so that the waveform below is not moved.
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        onWheel: wheel => wheel.accepted = true
    }
    Mixxx.ControlProxy { id: loopEnabled; group: root.group; key: "loop_enabled" }
    Mixxx.ControlProxy { id: loopSize; group: root.group; key: "beatloop_size" }
    Mixxx.ControlProxy { id: pitchAdjust; group: root.group; key: "pitch_adjust" }
    Mixxx.ControlProxy { id: resetKey; group: root.group; key: "reset_key" }
    Mixxx.ControlProxy { id: keylock; group: root.group; key: "keylock" }
    Mixxx.ControlProxy { id: jumpSize; group: root.group; key: "beatjump_size" }
    Mixxx.ControlProxy { id: jumpForward; group: root.group; key: "beatjump_forward" }
    Mixxx.ControlProxy { id: jumpBackward; group: root.group; key: "beatjump_backward" }

    // ---- BEAT LOOP: 1/4 ... 32, the running loop is orange ----
    Item {
        anchors.fill: parent
        visible: root.kind === "LOOP"

        Row {
            id: loopRow

            spacing: 4

            anchors {
                bottom: parent.bottom
                bottomMargin: 4
                left: parent.left
                leftMargin: 4
                right: parent.right
                rightMargin: 4
                top: parent.top
                topMargin: Math.round(root.u * 1.4)
            }

            Repeater {
                model: root.loopSizes

                Rectangle {
                    id: loopButton

                    required property real modelData
                    // The loop of this size is running (and no other size).
                    readonly property bool running: loopEnabled.value > 0 && Math.abs(loopSize.value - modelData) < 0.0001

                    border.color: "#ff9a2e"
                    border.width: 1
                    color: running ? "#ff9a2e" : (loopTap.pressed ? "#3a3a3a" : "#262626")
                    height: parent.height
                    width: (loopRow.width - 7 * loopRow.spacing) / 8

                    Text {
                        anchors.centerIn: parent
                        color: loopButton.running ? "#000000" : "#ffffff"
                        font.bold: true
                        font.pixelSize: Math.round(root.u * 1.4)
                        text: root.sizeText(loopButton.modelData)
                    }
                    TapHandler {
                        id: loopTap

                        onTapped: {
                            root.activity();
                            if (loopButton.running) {
                                loopEnabled.value = 0;
                            } else {
                                loopSize.value = loopButton.modelData;
                                // Sets a loop of this size at the playing position.
                                activateProxy.trigger();
                            }
                        }
                    }
                    Mixxx.ControlProxy { id: activateProxy; group: root.group; key: "beatloop_activate" }
                }
            }
        }
        // Loop symbol and size of the running loop.
        Text {
            color: "#ff9a2e"
            font.bold: true
            font.pixelSize: Math.round(root.u * 1.1)
            text: loopEnabled.value > 0 ? "↺ " + root.sizeText(loopSize.value) : ""

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 2
            }
        }
    }

    // ---- KEY SHIFT: - / + in semitones, the keys next to the shifted one, RESET ----
    Item {
        anchors.fill: parent
        visible: root.kind === "KEY"

        readonly property real shift: Math.round(pitchAdjust.value)

        function change(delta) {
            root.activity();
            // The shift only works with MASTER TEMPO (key lock) on.
            if (keylock.value <= 0)
                keylock.value = 1;
            pitchAdjust.value = Math.max(-12, Math.min(12, Math.round(pitchAdjust.value) + delta));
        }

        // Key one semitone down, with the minus button.
        Rectangle {
            id: downButton

            border.color: "#6a6a6a"
            color: downTap.pressed ? "#3a3a3a" : "#262626"
            height: parent.height - 8
            width: Math.round(root.u * 7)

            anchors {
                left: parent.left
                leftMargin: 4
                verticalCenter: parent.verticalCenter
            }

            Text {
                color: "#cfcfcf"
                font.pixelSize: Math.round(root.u * 1.2)
                text: root.shiftedKey(root.keyText, parent.parent.shift - 1)

                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
            }
            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(root.u * 2)
                text: "−"

                anchors {
                    right: parent.right
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
            }
            TapHandler {
                id: downTap

                onTapped: parent.parent.change(-1)
            }
        }
        // The key now, the shift and RESET.
        Item {
            id: centre

            height: parent.height - 8
            width: Math.round(root.u * 9)

            anchors.centerIn: parent

            Rectangle {
                id: keyNow

                color: "#262626"
                height: parent.height * 0.65
                width: parent.width / 2

                anchors {
                    left: parent.left
                    top: parent.top
                }

                Text {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(root.u * 1.3)
                    text: root.shiftedKey(root.keyText, parent.parent.parent.shift)
                }
            }
            Rectangle {
                color: "#ffffff"
                height: keyNow.height
                width: parent.width / 2

                anchors {
                    right: parent.right
                    top: parent.top
                }

                Text {
                    anchors.centerIn: parent
                    color: "#000000"
                    font.bold: true
                    font.pixelSize: Math.round(root.u * 1.3)
                    text: (parent.parent.parent.shift > 0 ? "+" : "") + parent.parent.parent.shift
                }
            }
            Rectangle {
                color: resetTap.pressed ? "#9a9a9a" : "#7a7a7a"
                height: parent.height - keyNow.height
                width: parent.width

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                }

                Text {
                    anchors.centerIn: parent
                    color: "#000000"
                    font.pixelSize: Math.round(root.u * 0.9)
                    text: "RESET"
                }
                TapHandler {
                    id: resetTap

                    onTapped: {
                        root.activity();
                        pitchAdjust.value = 0;
                        resetKey.trigger();
                    }
                }
            }
        }
        // Key one semitone up, with the plus button.
        Rectangle {
            id: upButton

            border.color: "#6a6a6a"
            color: upTap.pressed ? "#3a3a3a" : "#262626"
            height: parent.height - 8
            width: Math.round(root.u * 7)

            anchors {
                right: parent.right
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(root.u * 2)
                text: "+"

                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
            }
            Text {
                color: "#cfcfcf"
                font.pixelSize: Math.round(root.u * 1.2)
                text: root.shiftedKey(root.keyText, parent.parent.shift + 1)

                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
            }
            TapHandler {
                id: upTap

                onTapped: parent.parent.change(1)
            }
        }
    }

    // ---- BEAT JUMP: back / forward for four sizes, two pages ----
    Item {
        anchors.fill: parent
        visible: root.kind === "JUMP"

        Row {
            id: jumpRow

            spacing: 10

            anchors {
                bottom: parent.bottom
                bottomMargin: 4
                left: parent.left
                leftMargin: 4
                right: pageSwitch.left
                rightMargin: 6
                top: parent.top
                topMargin: 4
            }

            Repeater {
                model: root.jumpPages[root.jumpPage]

                Row {
                    id: jumpPair

                    required property real modelData

                    spacing: 3

                    Repeater {
                        model: ["backward", "forward"]

                        Rectangle {
                            id: jumpButton

                            required property string modelData

                            border.color: "#6a6a6a"
                            color: jumpTap.pressed ? "#5a5a5a" : "#262626"
                            height: jumpRow.height
                            width: (jumpRow.width - 3 * jumpRow.spacing) / 8 - 1.5

                            Text {
                                anchors.centerIn: parent
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: Math.round(root.u * 1.3)
                                text: root.sizeText(jumpPair.modelData)
                            }
                            // Direction mark in the corner.
                            Text {
                                color: "#9a9a9a"
                                font.pixelSize: Math.round(root.u * 0.8)
                                text: jumpButton.modelData === "forward" ? "▸▸" : "◂◂"

                                anchors {
                                    right: parent.right
                                    rightMargin: 3
                                    top: parent.top
                                    topMargin: 1
                                }
                            }
                            TapHandler {
                                id: jumpTap

                                onTapped: {
                                    root.activity();
                                    jumpSize.value = jumpPair.modelData;
                                    if (jumpButton.modelData === "forward")
                                        jumpForward.trigger();
                                    else
                                        jumpBackward.trigger();
                                }
                            }
                        }
                    }
                }
            }
        }
        // Page switch "1 | 2".
        Row {
            id: pageSwitch

            anchors {
                bottom: parent.bottom
                bottomMargin: 4
                right: parent.right
                rightMargin: 4
                top: parent.top
                topMargin: 4
            }
            width: Math.round(root.u * 4.4)

            Repeater {
                model: [0, 1]

                Rectangle {
                    required property int modelData

                    border.color: "#6a6a6a"
                    color: root.jumpPage === modelData ? "#7a7a7a" : "#1a1a1a"
                    height: parent.height
                    width: parent.width / 2

                    Text {
                        anchors.centerIn: parent
                        color: root.jumpPage === parent.modelData ? "#ffffff" : "#8a8a8a"
                        font.bold: true
                        font.pixelSize: Math.round(root.u * 1.3)
                        text: parent.modelData + 1
                    }
                    TapHandler {
                        onTapped: {
                            root.activity();
                            root.jumpPage = parent.modelData;
                        }
                    }
                }
            }
        }
    }
}
