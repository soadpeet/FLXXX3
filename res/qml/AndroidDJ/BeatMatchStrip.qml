import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import "../" as Skin

// Beat-matching aid above the main waveform (CDJ view only), like the CDJ-3000:
//  - mode 1, WAVEFORM: small waveform of the OTHER deck on the same time axis (same zoom,
//    playhead in the middle): equal transients one above the other mean both songs are in phase.
//  - mode 2, PHASE METER: two rows, the other deck (orange) above this deck (blue). Each row
//    shows the beats of its deck around the playhead (the line in the middle), every 4th beat
//    (start of a bar) tall and thick. When both rows look the same, the decks are in phase.
Item {
    id: root

    // Group of the deck whose waveform this strip belongs to, e.g. "[Channel1]".
    property string group: "[Channel1]"
    // Group of the other deck.
    property string otherGroup: "[Channel2]"
    // 0 = off, 1 = WAVEFORM, 2 = PHASE METER.
    property int mode: 1
    // This deck is the MASTER: it shows the tag MASTER PLAYER instead of the aid.
    property bool isMaster: false
    readonly property bool otherActive: otherLoaded.value > 0 && otherBpm.value > 1
    readonly property bool ownActive: ownLoaded.value > 0
    // Size of the text of the MASTER PLAYER tag (set by the main window).
    property real tagFont: 14
    // Room at the left edge that is covered by the side buttons (deck 1).
    property real leftInset: 0
    // Width of the column with the remaining bars on the left.
    // Sizes after page 2 of the layout: the numbers about 2.4 %, "Bars" 1.4 % of the deck width.
    readonly property real barsFont: Math.max(11, Math.round(width * 0.024))
    readonly property real barsUnitFont: Math.max(8, Math.round(width * 0.014))
    readonly property real barsWidth: Math.round(barsFont * 5.2)
    // Bars to the next hot cue or memory cue of this deck and of the other deck (the MASTER).
    readonly property real ownBarsLeft: ownCueBars.bars
    readonly property real otherBarsLeft: otherCueBars.bars
    // Real seconds per beat of the other deck (BPM of the engine already contains the pitch).
    readonly property real otherBeatSec: otherBpm.value > 1 ? 60 / otherBpm.value : 1
    // Beat distance (0..1) of the other / this deck, advanced between two engine updates.
    property real phase: 0
    property real ownPhase: 0
    // Position in the bar (0..3) of the last beat of the other / this deck.
    property int phaseBar: 0
    property int ownBarPos: 0

    clip: true
    visible: isMaster ? ownActive : otherActive

    Mixxx.ControlProxy { id: ownLoaded; group: root.group; key: "track_loaded" }
    NextCueBars { id: ownCueBars; group: root.group }
    NextCueBars { id: otherCueBars; group: root.otherGroup }
    Mixxx.ControlProxy { id: otherBpm; group: root.otherGroup; key: "bpm" }
    Mixxx.ControlProxy { id: otherLoaded; group: root.otherGroup; key: "track_loaded" }
    Mixxx.ControlProxy { id: otherBar; group: root.otherGroup; key: "beat_in_bar" }
    Mixxx.ControlProxy { id: ownBar; group: root.group; key: "beat_in_bar" }
    Mixxx.ControlProxy { id: ownBpm; group: root.group; key: "bpm" }
    Mixxx.ControlProxy { id: otherPlay; group: root.otherGroup; key: "play" }
    Mixxx.ControlProxy { id: ownPlay; group: root.group; key: "play" }
    Mixxx.ControlProxy { id: ownDistance; group: root.group; key: "beat_distance" }
    Mixxx.ControlProxy { id: otherDistance; group: root.otherGroup; key: "beat_distance" }

    // beat_distance only changes once per audio buffer: between two changes it is advanced by
    // the elapsed time so the rows move smoothly (at most a quarter beat). Only the PHASE METER
    // needs it. The linear animation of `clock` is driven by the render loop (once per frame,
    // in step with the waveforms), a Timer would not be.
    QtObject {
        id: tick

        property real lastOther: -1
        property real lastOwn: -1
        property double tOther: 0
        property double tOwn: 0
    }
    property double clock: 0

    NumberAnimation on clock {
        duration: 10000000
        from: 0
        loops: Animation.Infinite
        running: root.visible && root.mode === 2 && !root.isMaster
        to: 10000000
    }
    onClockChanged: {
        if (mode !== 2) {
            return;
        }
        const now = Date.now();
        const o = otherDistance.value;
        if (o !== tick.lastOther) { tick.lastOther = o; tick.tOther = now; }
        const w = ownDistance.value;
        if (w !== tick.lastOwn) { tick.lastOwn = w; tick.tOwn = now; }
        phase = o + (otherPlay.value > 0 && otherBeatSec > 0
                ? Math.min(0.25, (now - tick.tOther) / 1000 / otherBeatSec) : 0);
        ownPhase = w + (ownPlay.value > 0 && ownBpm.value > 1
                ? Math.min(0.25, (now - tick.tOwn) / 1000 / (60 / ownBpm.value)) : 0);
        phaseBar = otherBar.value;
        ownBarPos = ownBar.value;
    }
    // The MASTER deck: only the tag.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: root.isMaster

        // In the middle of the deck.
        Rectangle {
            anchors.centerIn: parent
            color: "#ff9a2e"
            height: Math.round(root.tagFont * 1.6)
            width: masterText.implicitWidth + 16

            Text {
                id: masterText

                anchors.centerIn: parent
                color: "#000000"
                font.bold: true
                font.pixelSize: root.tagFont
                text: "MASTER PLAYER"
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: !root.isMaster && root.mode === 1

        Loader {
            active: root.mode === 1
            anchors.fill: parent

            sourceComponent: Skin.WaveformDisplay {
                enabled: false
                group: root.otherGroup
                zoomGroupOverride: root.group
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: !root.isMaster && root.mode !== 1

        Item {
            id: meter

            readonly property real beatsShown: 16
            readonly property real beatPx: width / beatsShown

            height: parent.height * 0.86
            visible: root.mode === 2
            width: parent.width - root.barsWidth - root.leftInset - 12
            x: root.barsWidth + root.leftInset
            y: parent.height * 0.02

            Repeater {
                model: 2

                Item {
                    required property int index
                    readonly property real dist: index === 0 ? root.phase : root.ownPhase

                    height: meter.height / 2 - 2
                    width: meter.width
                    y: index * (meter.height / 2 + 2)

                    Repeater {
                        model: 18

                        Rectangle {
                            required property int index
                            readonly property int n: index - 9

                            // Beat nearest to the playhead lights up, the others fade out to the sides.
                            readonly property real off: Math.abs(x + width / 2 - meter.width / 2)
                            readonly property bool bar: (((n + (parent.index === 0 ? root.phaseBar : root.ownBarPos)) % 4) + 4) % 4 === 0

                            color: off < meter.beatPx * 0.5 ? "#ffffff" : (parent.index === 0 ? "#ff9a1f" : "#2e8bff")
                            height: parent.height * (bar ? 0.9 : 0.45)
                            opacity: Math.max(0.2, 1 - off / (meter.width / 2) * 0.8)
                            width: bar ? 4 : 3
                            x: meter.width / 2 + (n - parent.dist) * meter.beatPx - width / 2
                            y: (parent.height - height) / 2
                            visible: x >= 0 && x <= meter.width
                        }
                    }
                }
            }
            Rectangle {
                color: "#ffffff"
                height: meter.height + 4
                width: 3
                x: meter.width / 2 - 1.5
                y: -2
            }
        }
    }
    // Bars to the next cue: orange = the other deck (the MASTER), blue = this deck.
    Rectangle {
        color: "#cc000000"
        height: parent.height
        width: root.barsWidth
        x: root.leftInset

        Column {
            anchors.centerIn: parent

            Row {
                spacing: 3

                Text {
                    color: "#ff9a2e"
                    font.bold: true
                    font.pixelSize: root.barsFont
                    text: root.otherBarsLeft >= 0 ? root.otherBarsLeft.toFixed(1) : "--"
                }
                Text {
                    anchors.baseline: parent.children[0].baseline
                    color: "#ff9a2e"
                    font.pixelSize: root.barsUnitFont
                    text: "Bars"
                }
            }
            Row {
                spacing: 3

                Text {
                    color: "#2e8bff"
                    font.bold: true
                    font.pixelSize: root.barsFont
                    text: root.ownBarsLeft >= 0 ? root.ownBarsLeft.toFixed(1) : "--"
                }
                Text {
                    anchors.baseline: parent.children[0].baseline
                    color: "#2e8bff"
                    font.pixelSize: root.barsUnitFont
                    text: "Bars"
                }
            }
        }
    }
}
