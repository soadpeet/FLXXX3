import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import "." as DJ

// Utility ("SHORTCUT") screen modelled on the XDJ-RX3. For now it only shows
// the controls; the functions are added step by step.
Rectangle {
    id: root

    // Sized so that both columns (34 u and 28 u wide) fit next to each other.
    readonly property real u: Math.max(7, Math.floor(Math.min(width / 66, height / 26)))

    // Shared with the main window (two-way through the signals below).
    property bool showRemain: true
    property bool keyCamelot: true
    property bool autoCue: false
    property string quantizeBeat: "1/4"

    signal showRemainSelected(bool remain)
    signal keyCamelotSelected(bool camelot)
    signal autoCueSelected(bool on)
    signal quantizeBeatSelected(string beat)

    color: "#0a0a0a"

    Mixxx.ControlProxy { id: headSplit; group: "[Master]"; key: "headSplit" }
    Mixxx.ControlProxy { id: monoMixdown; group: "[Master]"; key: "mono_mixdown" }

    Text {
        color: "#ffffff"
        font.bold: true
        font.pixelSize: root.u * 1.4
        text: "SHORTCUT"

        anchors {
            left: parent.left
            leftMargin: root.u
            top: parent.top
            topMargin: root.u * 0.5
        }
    }
    // Left column: deck settings and vinyl speed.
    Column {
        id: leftColumn

        spacing: root.u * 0.35
        width: root.u * 34

        anchors {
            left: parent.left
            leftMargin: root.u
            top: parent.top
            topMargin: root.u * 2.6
        }

        DJ.SectionTitle { u: root.u; text: "DECK SETTING"; width: parent.width }
        Row {
            spacing: root.u * 1.2

            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "TIME" }
                DJ.Segmented {
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    currentIndex: root.showRemain ? 1 : 0
                    labels: ["TIME", "REMAIN"]
                    width: root.u * 11

                    onActivated: index => root.showRemainSelected(index === 1)
                }
            }
            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "AUTO CUE" }
                DJ.Segmented {
                    currentIndex: root.autoCue ? 0 : 1
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["ON", "OFF"]
                    width: root.u * 8

                    onActivated: index => root.autoCueSelected(index === 0)
                }
            }
            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "LOAD LOCK" }
                DJ.Segmented {
                    // LOCK: no track can be loaded into a deck that plays.
                    currentIndex: Mixxx.Config.androidSetting("loadLock", "1") === "1" ? 0 : 1
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["LOCK", "UNLOCK"]
                    width: root.u * 11

                    onActivated: index => Mixxx.Config.setAndroidSetting("loadLock", index === 0 ? "1" : "0")
                }
            }
        }
        Row {
            spacing: root.u * 1.2

            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "QUANTIZE BEAT VALUE" }
                DJ.Segmented {
                    currentIndex: Math.max(0, ["1/8", "1/4", "1/2", "1"].indexOf(root.quantizeBeat))
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["1/8", "1/4", "1/2", "1"]
                    width: root.u * 17

                    onActivated: index => root.quantizeBeatSelected(labels[index])
                }
            }
            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "HOT CUE AUTO LOAD" }
                DJ.Segmented {
                    currentIndex: 1
                    fontSize: root.u * 0.85
                    height: root.u * 2.5
                    labels: ["ON", "SETTING", "OFF"]
                    width: root.u * 15
                }
            }
        }
        Column {
            spacing: 3

            DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "KEY DISPLAY" }
            DJ.Segmented {
                fontSize: root.u * 0.95
                height: root.u * 2.5
                currentIndex: root.keyCamelot ? 1 : 0
                labels: ["CLASSIC", "CAMELOT"]
                width: root.u * 17

                onActivated: index => root.keyCamelotSelected(index === 1)
            }
        }
        Item { height: root.u * 0.4; width: 1 }
        DJ.SectionTitle { u: root.u; text: "DISPLAY BRIGHTNESS / CONTRAST"; width: parent.width }
        // Left: gentle on the eyes in the dark, middle: normal, right: strong
        // contrast for direct sunlight.
        DJ.Segmented {
            currentIndex: 1
            fontSize: root.u * 0.95
            height: root.u * 2.5
            labels: ["NIGHT", "NORMAL", "OUTDOOR"]
            width: root.u * 26
        }
        Item { height: root.u * 0.4; width: 1 }
        DJ.SectionTitle { u: root.u; text: "VINYL SPEED ADJUST (TOUCH)"; width: parent.width }
        Row {
            spacing: root.u * 1.5

            Repeater {
                model: 2

                Row {
                    id: brake

                    required property int index
                    // Brake time shown in seconds (display only for now).
                    property real seconds: 1.0

                    spacing: root.u * 0.8

                    Column {
                        spacing: 3

                        DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "DECK " + (brake.index + 1) }
                        DJ.Segmented {
                            currentIndex: 1
                            fontSize: root.u * 0.95
                            height: root.u * 2.5
                            labels: ["ON", "OFF"]
                            width: root.u * 8
                        }
                        DJ.Segmented {
                            currentIndex: -1
                            fontSize: root.u * 1.2
                            height: root.u * 2.3
                            labels: ["<", ">"]
                            width: root.u * 8

                            onActivated: index => {
                                brake.seconds = Math.max(0.1, Math.min(5.0, brake.seconds + (index === 0 ? -0.1 : 0.1)));
                                currentIndex = -1;
                            }
                        }
                    }
                    Rectangle {
                        border.color: "#4a4a4a"
                        color: "#111111"
                        height: root.u * 5.6
                        width: root.u * 5.6

                        anchors.bottom: parent.bottom

                        Column {
                            anchors.centerIn: parent

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: root.u * 1.8
                                text: brake.seconds.toFixed(1)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: "#8a8a8a"
                                font.pixelSize: root.u * 0.9
                                text: "sec"
                            }
                        }
                    }
                }
            }
        }
    }
    // Right column: folders, waveform colour, mixer.
    Column {
        id: rightColumn

        spacing: root.u * 0.35
        width: root.u * 28

        anchors {
            right: parent.right
            rightMargin: root.u
            top: parent.top
            topMargin: root.u * 2.6
        }

        // Folders that are read in addition to the USB stick.
        Rectangle {
            border.color: "#2a2a2a"
            color: "#111111"
            height: root.u * 5.6
            width: parent.width

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: root.u * 1.1
                text: "LIBRARY FOLDERS"

                anchors {
                    left: parent.left
                    leftMargin: root.u * 0.6
                    top: parent.top
                    topMargin: root.u * 0.4
                }
            }
            Text {
                color: "#9a9a9a"
                font.pixelSize: root.u * 0.9
                text: "USB stick (automatic)"

                anchors {
                    left: parent.left
                    leftMargin: root.u * 0.6
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: root.u * 0.4
                }
            }
            Rectangle {
                border.color: "#cfcfcf"
                color: "#2a2a2a"
                height: root.u * 2.2
                width: root.u * 8

                anchors {
                    bottom: parent.bottom
                    bottomMargin: root.u * 0.4
                    right: parent.right
                    rightMargin: root.u * 0.6
                }

                Text {
                    anchors.centerIn: parent
                    color: "#e0e0e0"
                    font.bold: true
                    font.pixelSize: root.u * 0.9
                    text: "ADD FOLDER"
                }
            }
        }
        DJ.SectionTitle { u: root.u; text: "WAVEFORM COLOR"; width: parent.width }
        Row {
            id: colorRow

            // BLUE = simple one-colour signal, RGB = colour by frequency,
            // 3BAND = low/mid/high drawn in three colours.
            readonly property int current: Mixxx.Config.waveformType === Mixxx.WaveformDisplay.Type.Simple ? 0 : (Mixxx.Config.waveformType === Mixxx.WaveformDisplay.Type.Filtered ? 2 : 1)
            readonly property var types: [Mixxx.WaveformDisplay.Type.Simple, Mixxx.WaveformDisplay.Type.RGB, Mixxx.WaveformDisplay.Type.Filtered]

            Repeater {
                model: [
                    { name: "BLUE", colors: ["#0b3fd9", "#2a9dff", "#bfe6ff"] },
                    { name: "RGB", colors: ["#ff2d2d", "#2fe05a", "#2f7bff"] },
                    { name: "3BAND", colors: ["#2154d7", "#97632d", "#d5c2a2"] }
                ]

                Rectangle {
                    id: colorTile

                    required property int index
                    required property var modelData

                    border.color: "#cfcfcf"
                    color: colorRow.current === index ? "#1fb0f0" : "#2a2a2a"
                    height: root.u * 3.2
                    width: root.u * 8

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: root.u * 0.4

                        Repeater {
                            model: colorTile.modelData.colors

                            Rectangle {
                                required property string modelData

                                color: modelData
                                height: root.u * 1.1
                                width: root.u * 1.4
                            }
                        }
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: root.u * 0.8
                        text: colorTile.modelData.name
                    }
                    TapHandler {
                        onTapped: Mixxx.Config.waveformType = colorRow.types[colorTile.index]
                    }
                }
            }
        }
        DJ.SectionTitle { u: root.u; text: "MIXER SETTING"; width: parent.width }
        Row {
            spacing: root.u * 1.2

            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "EQ / ISO" }
                DJ.Segmented {
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["EQ", "ISO"]
                    width: root.u * 11
                }
            }
            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "QUANTIZE (EFFECT)" }
                DJ.Segmented {
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["ON", "OFF"]
                    width: root.u * 11
                }
            }
        }
        Row {
            spacing: root.u * 1.2

            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "HEADPHONES" }
                DJ.Segmented {
                    // MONO SPLIT: master on the left ear, cue on the right.
                    currentIndex: headSplit.value > 0 ? 0 : 1
                    fontSize: root.u * 0.8
                    height: root.u * 2.5
                    labels: ["MONO SPLIT", "STEREO"]
                    width: root.u * 13

                    onActivated: index => headSplit.value = index === 0 ? 1 : 0
                }
            }
            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "MASTER" }
                DJ.Segmented {
                    currentIndex: monoMixdown.value > 0 ? 0 : 1
                    fontSize: root.u * 0.8
                    height: root.u * 2.5
                    labels: ["MONO", "STEREO"]
                    width: root.u * 13

                    onActivated: index => monoMixdown.value = index === 0 ? 1 : 0
                }
            }
        }
        Column {
            spacing: 3

            DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "CHANNEL FADER CURVE" }
            Row {
                id: curveRow

                property int current: 1

                Repeater {
                    model: 3

                    Rectangle {
                        id: curveTile

                        required property int index

                        border.color: "#cfcfcf"
                        color: curveRow.current === index ? "#1fb0f0" : "#2a2a2a"
                        height: root.u * 2.8
                        width: root.u * 5

                        DJ.FadeCurve {
                            anchors.fill: parent
                            kind: curveTile.index
                            selected: curveRow.current === curveTile.index
                        }
                        TapHandler {
                            onTapped: curveRow.current = curveTile.index
                        }
                    }
                }
            }
        }
    }
}
