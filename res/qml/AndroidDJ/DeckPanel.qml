import "../" as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import "." as DJ

// One deck panel modelled on the XDJ-RX3: deck number, title, time, tempo,
// BPM box and the overview waveform.
Rectangle {
    id: root

    required property string group
    required property int deckNumber
    property color accent: "#27a8e0"
    // Shared between both decks (set by MainWindow): remaining or elapsed time.
    property bool showRemain: true
    // Camelot (8A) instead of classic (Am) key names.
    property bool keyCamelot: true
    // MASTER (tempo reference): decided by MainWindow, shown in orange.
    property bool isMaster: false
    signal masterRequested()
    // Quantize beat value from the UTILITY menu (display; "1/8" .. "1").
    property string quantizeBeat: "1/4"

    readonly property var _camelotMinor: ({"Abm": 1, "G#m": 1, "Ebm": 2, "D#m": 2, "Bbm": 3, "A#m": 3, "Fm": 4, "Cm": 5, "Gm": 6, "Dm": 7, "Am": 8, "Em": 9, "Bm": 10, "F#m": 11, "Gbm": 11, "C#m": 12, "Dbm": 12})
    readonly property var _camelotMajor: ({"B": 1, "Cb": 1, "F#": 2, "Gb": 2, "Db": 3, "C#": 3, "Ab": 4, "G#": 4, "Eb": 5, "D#": 5, "Bb": 6, "A#": 6, "F": 7, "C": 8, "G": 9, "D": 10, "A": 11, "E": 12})
    readonly property var _classicMinor: ["", "Abm", "Ebm", "Bbm", "Fm", "Cm", "Gm", "Dm", "Am", "Em", "Bm", "F#m", "C#m"]
    readonly property var _classicMajor: ["", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C", "G", "D", "A", "E"]

    // Converts the key text of the track to the selected notation. Unknown
    // texts are shown unchanged.
    function formatKey(rawText) {
        if (!rawText)
            return "";
        // Mixxx writes sharps and flats as special characters (F\u266fm).
        const text = rawText.replace(/\u266f/g, "#").replace(/\u266d/g, "b");
        const pretty = name => name.replace(/#/g, "\u266f").replace(/([A-G])b/g, "$1\u266d");
        const m = /^(\d{1,2})([ABab])$/.exec(text);
        if (m) {
            const n = parseInt(m[1]);
            if (root.keyCamelot || n < 1 || n > 12)
                return text;
            return pretty(m[2].toUpperCase() === "A" ? root._classicMinor[n] : root._classicMajor[n]);
        }
        if (!root.keyCamelot)
            return rawText;
        const minor = root._camelotMinor[text];
        if (minor !== undefined)
            return minor + "A";
        const major = root._camelotMajor[text];
        if (major !== undefined)
            return major + "B";
        return rawText;
    }

    // Tap on the BPM shows buttons that correct a wrongly detected tempo
    // (half / double / 3:2 relations), closes itself after a few seconds.
    property bool bpmFixOpen: false

    // Tempo range steps like the Pioneer players: +-6 %, 10 %, 16 %, WIDE.
    readonly property var tempoRanges: [0.06, 0.10, 0.16, 1.0]
    readonly property string tempoRangeText: rateRangeControl.value >= 0.99
                                             ? "WIDE" : "\u00b1" + Math.round(rateRangeControl.value * 100) + "%"

    function cycleTempoRange() {
        let next = 0;
        for (let i = 0; i < tempoRanges.length; ++i) {
            if (Math.abs(tempoRanges[i] - rateRangeControl.value) < 0.005) {
                next = (i + 1) % tempoRanges.length;
                break;
            }
        }
        rateRangeControl.value = tempoRanges[next];
    }

    signal timeModeToggled

    Component.onCompleted: {
        // Start with one of the four steps (the saved range may be anything).
        for (let i = 0; i < tempoRanges.length; ++i) {
            if (Math.abs(tempoRanges[i] - rateRangeControl.value) < 0.005) {
                return;
            }
        }
        rateRangeControl.value = tempoRanges[0];
    }

    readonly property var player: Mixxx.PlayerManager.getPlayer(group)
    readonly property var track: player ? player.currentTrack : null
    readonly property bool loaded: player ? player.isLoaded : false
    readonly property real elapsed: durationControl.value * playPositionControl.value
    readonly property real remaining: durationControl.value - elapsed
    readonly property real tempoPercent: (rateRatioControl.value - 1) * 100
    readonly property real unit: Math.max(8, root.height / 14)

    // "mm:ss" and ".mmm" are shown in different sizes, like on the RX3.
    function formatTime(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0) {
            seconds = 0;
        }
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }
    function formatMillis(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0) {
            seconds = 0;
        }
        const ms = Math.floor((seconds - Math.floor(seconds)) * 1000);
        return "." + (ms < 10 ? "00" : (ms < 100 ? "0" : "")) + ms;
    }

    border.color: "#2a2a2a"
    border.width: 1
    color: "#0c0c0c"

    Mixxx.ControlProxy { id: bpmControl; group: root.group; key: "bpm" }
    Mixxx.ControlProxy { id: rateRatioControl; group: root.group; key: "rate_ratio" }
    Mixxx.ControlProxy { id: playPositionControl; group: root.group; key: "playposition" }
    Mixxx.ControlProxy { id: durationControl; group: root.group; key: "duration" }
    Mixxx.ControlProxy { id: rateRangeControl; group: root.group; key: "rateRange" }
    Mixxx.ControlProxy { id: fixHalve; group: root.group; key: "beats_set_halve" }
    Mixxx.ControlProxy { id: fixTwoThirds; group: root.group; key: "beats_set_twothirds" }
    Mixxx.ControlProxy { id: fixThreeHalves; group: root.group; key: "beats_set_threehalves" }
    Mixxx.ControlProxy { id: fixDouble; group: root.group; key: "beats_set_double" }
    Mixxx.ControlProxy { id: fixUndo; group: root.group; key: "beats_undo_adjustment" }
    Timer {
        id: bpmFixTimer

        interval: 8000
        onTriggered: root.bpmFixOpen = false
    }
    Mixxx.ControlProxy { id: autoCueControl; group: root.group; key: "auto_cue" }
    Mixxx.ControlProxy { id: playControl; group: root.group; key: "play" }
    Mixxx.ControlProxy { id: playIndicatorControl; group: root.group; key: "play_indicator" }
    Mixxx.ControlProxy { id: cueIndicatorControl; group: root.group; key: "cue_indicator" }
    Mixxx.ControlProxy { id: quantizeControl; group: root.group; key: "quantize" }
    Mixxx.ControlProxy { id: syncControl; group: root.group; key: "sync_enabled" }
    Mixxx.ControlProxy { id: keylockControl; group: root.group; key: "keylock" }
    Mixxx.ControlProxy { id: loopControl; group: root.group; key: "loop_enabled" }

    // Left column: deck number.
    Rectangle {
        id: deckColumn

        // Only a little lighter while the deck plays.
        color: playControl.value > 0 ? "#383838" : "#181818"
        width: Math.round(root.unit * 3.2)

        anchors {
            bottom: parent.bottom
            left: parent.left
            top: parent.top
        }

        Text {
            id: deckLabel

            color: playControl.value > 0 ? "#b8b8b8" : "#8a8a8a"
            font.pixelSize: Math.round(root.unit * 0.8)
            text: "DECK"

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: Math.round(root.unit * 0.4)
            }
        }
        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: deckLabel.bottom
            }
            color: "#ffffff"
            font.bold: true
            font.pixelSize: Math.round(root.unit * 2.4)
            text: root.deckNumber
        }
        // Track number and quantize setting at the bottom of the column.
        Column {
            spacing: 0

            anchors {
                bottom: parent.bottom
                bottomMargin: Math.round(root.unit * 0.3)
                horizontalCenter: parent.horizontalCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: playControl.value > 0 ? "#b8b8b8" : "#8a8a8a"
                font.pixelSize: Math.round(root.unit * 0.6)
                text: "TRACK"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(root.unit * 1.1)
                text: root.loaded && root.track && root.track.trackNumber ? root.track.trackNumber : "--"
            }
            Item { height: Math.round(root.unit * 0.3); width: 1 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: playControl.value > 0 ? "#b8b8b8" : "#8a8a8a"
                font.pixelSize: Math.round(root.unit * 0.6)
                text: "QUANTIZE"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: quantizeControl.value > 0 ? "#ffffff" : "#6a6a6a"
                font.bold: true
                font.pixelSize: Math.round(root.unit * 1.0)
                text: quantizeControl.value > 0 ? root.quantizeBeat : "OFF"
            }
        }
    }
    // Title row with key.
    Item {
        id: titleRow

        height: Math.round(root.unit * 3.2)

        anchors {
            left: deckColumn.right
            leftMargin: 6
            right: parent.right
            rightMargin: 4
            top: parent.top
        }

        Rectangle {
            id: keyBox

            border.color: "#4a4a4a"
            color: "transparent"
            visible: root.loaded
            width: Math.round(titleRow.height * 1.5)

            anchors {
                bottom: parent.bottom
                bottomMargin: 3
                right: parent.right
                top: parent.top
                topMargin: 3
            }

            Text {
                anchors.centerIn: parent
                color: root.track && root.track.color && root.track.keyText ? "#7fe0a0" : "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(titleRow.height * 0.5)
                text: root.track ? root.formatKey(root.track.keyText) : ""
            }
        }
        Text {
            id: titleText

            color: "#ffffff"
            elide: Text.ElideRight
            font.bold: true
            font.pixelSize: Math.round(root.unit * 1.15)
            text: root.loaded && root.track ? "\u266a " + root.track.title : ""

            anchors {
                left: parent.left
                right: keyBox.left
                rightMargin: 6
                top: parent.top
                topMargin: 1
            }
        }
        Text {
            color: "#9a9a9a"
            elide: Text.ElideRight
            font.pixelSize: Math.round(root.unit * 0.85)
            text: root.loaded && root.track ? root.track.artist : ""

            anchors {
                left: titleText.left
                right: titleText.right
                top: titleText.bottom
            }
        }
    }
    // Middle row: switches, time, tempo, BPM box.
    Item {
        id: metrics

        anchors {
            bottom: infoRow.top
            left: deckColumn.right
            leftMargin: 6
            right: parent.right
            rightMargin: 4
            top: titleRow.bottom
        }

        Column {
            id: switchColumn

            spacing: 4

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

            DJ.StatusChip {
                // Skip the silence at the start of a track when loading.
                active: autoCueControl.value > 0
                activeColor: "#ff9a2e"
                fontSize: root.unit * 0.8
                text: "AUTO CUE"
                width: quantizeChip.width

                onClicked: autoCueControl.value = autoCueControl.value > 0 ? 0 : 1
            }
            DJ.StatusChip {
                id: quantizeChip

                active: quantizeControl.value > 0
                fontSize: root.unit * 0.8
                text: "QUANTIZE"

                onClicked: quantizeControl.value = quantizeControl.value > 0 ? 0 : 1
            }
        }
        // Time: tap to switch between remaining and elapsed.
        Item {
            id: timeBlock

            width: Math.max(timeText.implicitWidth + millisText.implicitWidth + 4, timeLabel.width)

            anchors {
                bottom: parent.bottom
                left: switchColumn.right
                leftMargin: 10
                top: parent.top
            }

            // "REMAIN / TIME": the selected mode is highlighted.
            Row {
                id: timeLabel

                spacing: 4

                Text {
                    color: root.showRemain ? "#ffffff" : "#5a5a5a"
                    font.bold: root.showRemain
                    font.pixelSize: Math.round(root.unit * 0.75)
                    text: "REMAIN"
                }
                Text {
                    color: root.showRemain ? "#5a5a5a" : "#ffffff"
                    font.bold: !root.showRemain
                    font.pixelSize: Math.round(root.unit * 0.75)
                    text: "/ TIME"
                }
            }
            Text {
                id: timeText

                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(Math.min(metrics.height * 0.62,
                        (metrics.width - switchColumn.width - tempoBlock.width - bpmBox.width - 40) / 4.7))
                text: root.loaded ? root.formatTime(root.showRemain ? root.remaining : root.elapsed) : "00:00"

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                }
            }
            Text {
                id: millisText

                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(timeText.font.pixelSize * 0.58)
                text: root.loaded ? root.formatMillis(root.showRemain ? root.remaining : root.elapsed) : ".000"

                anchors {
                    baseline: timeText.baseline
                    left: timeText.right
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8

                onClicked: root.timeModeToggled()
            }
        }
        // BPM box (tap: tempo correction).
        Rectangle {
            id: bpmBox

            border.color: root.isMaster ? "#ff9a2e" : "#cfcfcf"
            border.width: 2
            color: "transparent"
            width: Math.round(root.unit * 7.6)

            anchors {
                bottom: parent.bottom
                right: parent.right
                top: parent.top
                topMargin: Math.round(root.unit * 0.3)
            }

            Text {
                color: root.isMaster ? "#ff9a2e" : "#8a8a8a"
                font.pixelSize: Math.round(root.unit * 0.7)
                text: "BPM"

                anchors {
                    left: parent.left
                    leftMargin: 4
                    top: parent.top
                }
            }
            // Top right: orange MASTER = tempo reference of the other deck, green
            // SYNC = follows the master.
            Text {
                color: root.isMaster ? "#ff9a2e" : "#27e07a"
                font.bold: true
                font.pixelSize: Math.round(root.unit * 0.7)
                text: root.isMaster ? "MASTER" : "SYNC"
                visible: root.isMaster || syncControl.value > 0

                anchors {
                    right: parent.right
                    rightMargin: 4
                    top: parent.top
                }
            }
            MouseArea {
                height: parent.height * 0.4
                width: parent.width * 0.55

                anchors {
                    right: parent.right
                    top: parent.top
                }

                onClicked: root.masterRequested()
            }
            Text {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 2
                    horizontalCenter: parent.horizontalCenter
                }
                color: root.isMaster ? "#ff9a2e" : "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(bpmBox.height * 0.46)
                text: root.loaded && bpmControl.value > 0 ? bpmControl.value.toFixed(1) : ""
            }
            MouseArea {
                enabled: root.loaded

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: parent.height * 0.4
                }

                // Tap on the BPM box chooses this deck as the MASTER.
                onClicked: root.masterRequested()
            }
        }
        // Tempo: range chip and percentage.
        Item {
            id: tempoBlock

            anchors {
                bottom: parent.bottom
                right: bpmBox.left
                rightMargin: 8
                top: parent.top
            }
            width: Math.round(root.unit * 7)

            Text {
                id: tempoLabel

                color: "#8a8a8a"
                font.pixelSize: Math.round(root.unit * 0.75)
                text: "TEMPO"
            }
            DJ.StatusChip {
                active: true
                activeColor: "#ff6a3d"
                fontSize: root.unit * 0.8
                text: root.tempoRangeText

                anchors {
                    left: tempoLabel.right
                    leftMargin: 6
                    verticalCenter: tempoLabel.verticalCenter
                }

                onClicked: root.cycleTempoRange()
            }
            Text {
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                }
                color: Math.abs(root.tempoPercent) < 0.005 ? "#cfcfcf" : "#7fe0a0"
                font.pixelSize: Math.round(metrics.height * 0.36)
                text: (root.tempoPercent >= 0 ? "" : "-") + Math.abs(root.tempoPercent).toFixed(2) + "%"
            }
        }
    }
    // Indicators (or the tempo correction while open).
    Item {
        id: infoRow

        // Only used for "Not Loaded." and the tempo correction.
        height: root.loaded && !root.bpmFixOpen ? 0 : Math.round(root.unit * 1.9)

        anchors {
            bottom: overview.top
            bottomMargin: 2
            left: deckColumn.right
            leftMargin: 6
            right: parent.right
            rightMargin: 4
        }

        // Like the RX3 without a track: red "Not Loaded." instead of the indicators.
        Text {
            color: "#ff5a4d"
            font.pixelSize: Math.round(root.unit * 1.3)
            text: "Not Loaded."
            visible: !root.loaded

            anchors {
                left: parent.left
                leftMargin: Math.round(root.unit * 6)
                verticalCenter: parent.verticalCenter
            }
        }
        Row {
            spacing: 4
            visible: root.bpmFixOpen

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "#8a8a8a"
                font.pixelSize: root.unit * 0.8
                text: "BPM"
            }
            DJ.StatusChip {
                fontSize: root.unit * 0.85
                text: "\u00f72"

                onClicked: { fixHalve.trigger(); bpmFixTimer.restart(); }
            }
            DJ.StatusChip {
                fontSize: root.unit * 0.85
                text: "\u00d72/3"

                onClicked: { fixTwoThirds.trigger(); bpmFixTimer.restart(); }
            }
            DJ.StatusChip {
                fontSize: root.unit * 0.85
                text: "\u00d73/2"

                onClicked: { fixThreeHalves.trigger(); bpmFixTimer.restart(); }
            }
            DJ.StatusChip {
                fontSize: root.unit * 0.85
                text: "\u00d72"

                onClicked: { fixDouble.trigger(); bpmFixTimer.restart(); }
            }
            DJ.StatusChip {
                active: true
                activeColor: "#ff9a2e"
                fontSize: root.unit * 0.85
                text: "UNDO"

                onClicked: { fixUndo.trigger(); bpmFixTimer.restart(); }
            }
        }
    }
    // Overview of the whole track at the bottom of the panel.
    Skin.WaveformOverview {
        id: overview

        group: root.group
        height: Math.round(root.height * 0.4)

        anchors {
            bottom: parent.bottom
            left: deckColumn.right
            right: parent.right
        }
    }
}
