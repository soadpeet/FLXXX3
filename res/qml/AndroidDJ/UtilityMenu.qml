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

    // Blocks touches for the main window below (BEAT FX etc.).
    MouseArea {
        acceptedButtons: Qt.AllButtons
        anchors.fill: parent
        preventStealing: true
        onWheel: wheel => wheel.accepted = true
    }

    signal advancedRequested
    signal showRemainSelected(bool remain)
    signal keyCamelotSelected(bool camelot)
    signal autoCueSelected(bool on)
    signal quantizeBeatSelected(string beat)

    color: "#0a0a0a"

    Mixxx.ControlProxy { id: headSplit; group: "[Master]"; key: "headSplit" }
    Mixxx.ControlProxy { id: monoMixdown; group: "[Master]"; key: "mono_mixdown" }
    Mixxx.ControlProxy { id: eqMode; group: "[AndroidDJ]"; key: "eq_mode" }
    Mixxx.ControlProxy { id: faderCurve; group: "[AndroidDJ]"; key: "fader_curve" }
    Mixxx.ControlProxy { id: quantize1; group: "[Channel1]"; key: "quantize" }
    Mixxx.ControlProxy { id: quantize2; group: "[Channel2]"; key: "quantize" }
    Mixxx.ControlProxy { id: orientation1; group: "[Channel1]"; key: "orientation" }
    Mixxx.ControlProxy { id: orientation2; group: "[Channel2]"; key: "orientation" }
    // Crossfader: off by default (both channels in the middle position, the
    // crossfader does not act), on = channel 1 left, channel 2 right.
    property bool crossfaderOn: false
    onCrossfaderOnChanged: {
        orientation1.value = crossfaderOn ? 0 : 1;
        orientation2.value = crossfaderOn ? 2 : 1;
    }
    Component.onCompleted: {
        // TRACK END WARNING is OFF by default (Mixxx starts with 30 s): set it once, after that
        // the choice of the user stays.
        if (Mixxx.Config.androidSetting("endWarnInit", "") !== "1") {
            Mixxx.Config.waveformEndOfTrackWarningTime = 0;
            Mixxx.Config.setAndroidSetting("endWarnInit", "1");
        }
        const curve = parseInt(Mixxx.Config.androidSetting("faderCurve", "1"));
        faderCurve.value = isNaN(curve) ? 1 : curve;
        root.crossfaderOn = Mixxx.Config.androidSetting("crossfader", "0") === "1";
        // set once more: the value may not have changed from the default of the property
        orientation1.value = root.crossfaderOn ? 0 : 1;
        orientation2.value = root.crossfaderOn ? 2 : 1;
    }
    Mixxx.ControlProxy { id: brightnessProxy; group: "[AndroidDJ]"; key: "brightness" }

    // Opens ADVANCED SETTINGS.
    Rectangle {
        border.color: advancedTap.pressed ? "#1f8fe0" : "#4a4a4a"
        color: advancedTap.pressed ? "#3a3a3a" : "#202020"
        height: root.u * 2.4
        width: root.u * 17

        anchors {
            bottom: parent.bottom
            bottomMargin: root.u * 0.8
            left: parent.left
            leftMargin: root.u
        }

        Text {
            anchors.centerIn: parent
            color: "#ffffff"
            font.bold: true
            font.pixelSize: root.u * 1.0
            text: "ADVANCED SETTINGS"
        }
        TapHandler {
            id: advancedTap

            onTapped: root.advancedRequested()
        }
    }
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

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "QUANTIZE" }
                DJ.Segmented {
                    currentIndex: quantize1.value > 0 ? 0 : 1
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["ON", "OFF"]
                    width: root.u * 8

                    onActivated: index => {
                        quantize1.value = index === 0 ? 1 : 0;
                        quantize2.value = index === 0 ? 1 : 0;
                    }
                }
            }
        }
        // Warning before the end of the track (the waveform blinks red behind the waves, the
        // closer the end the stronger).
        Column {
            spacing: 3

            DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "TRACK END WARNING (WAVEFORM BLINKS)" }
            DJ.Segmented {
                readonly property var values: [0, 10, 20, 30, 60]

                currentIndex: values.indexOf(Mixxx.Config.waveformEndOfTrackWarningTime)
                fontSize: root.u * 0.95
                height: root.u * 2.5
                labels: ["OFF", "10 s", "20 s", "30 s", "60 s"]
                width: root.u * 26

                onActivated: index => Mixxx.Config.waveformEndOfTrackWarningTime = values[index]
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
            currentIndex: Math.round(brightnessProxy.value)
            fontSize: root.u * 0.95
            height: root.u * 2.5
            labels: ["NIGHT", "NORMAL", "OUTDOOR"]
            width: root.u * 26

            onActivated: index => brightnessProxy.value = index
        }
        Item { height: root.u * 0.4; width: 1 }
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
                // ISO (default): the bands are killed at the end stop. EQ: at most -26 dB.
                DJ.Segmented {
                    currentIndex: eqMode.value > 0.5 ? 0 : 1
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["EQ", "ISO"]
                    width: root.u * 11

                    onActivated: index => {
                        eqMode.value = index === 0 ? 1 : 0;
                        Mixxx.Config.setAndroidSetting("eqMode", index === 0 ? "1" : "0");
                    }
                }
            }
            Column {
                spacing: 3

                DJ.FieldLabel { font.pixelSize: root.u * 0.85; text: "CROSSFADER" }
                DJ.Segmented {
                    currentIndex: root.crossfaderOn ? 0 : 1
                    fontSize: root.u * 0.95
                    height: root.u * 2.5
                    labels: ["ON", "OFF"]
                    width: root.u * 11

                    onActivated: index => {
                        root.crossfaderOn = index === 0;
                        Mixxx.Config.setAndroidSetting("crossfader", index === 0 ? "1" : "0");
                    }
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

                readonly property int current: Math.round(faderCurve.value)

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
                            onTapped: {
                                faderCurve.value = curveTile.index;
                                Mixxx.Config.setAndroidSetting("faderCurve", String(curveTile.index));
                            }
                        }
                    }
                }
            }
        }
    }
}
