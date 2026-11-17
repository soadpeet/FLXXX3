import Mixxx 1.0 as Mixxx
import QtQuick 2.12

// Bars from the play position to the next hot cue or memory cue ahead of it (CDJ view).
// Hot cues A..H are hotcue 1..8, the Rekordbox memory cues and memory loops hotcue 17..36
// (see rekordboxfeature.cpp). `bars` is -1 when no cue lies ahead.
Item {
    id: root

    property string group: "[Channel1]"
    readonly property var cueNumbers: [1, 2, 3, 4, 5, 6, 7, 8,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]
    // Positions (engine samples) of all set cues, sorted.
    property var cuePositions: []
    readonly property real bars: {
        const total = samples.value;
        const bpm = fileBpm.value;
        if (loaded.value <= 0 || total <= 0 || bpm <= 1 || duration.value <= 0) {
            return -1;
        }
        // Slightly ahead, so that a cue the deck stands on (or just left) is not taken.
        const pos = playPos.value * total + total / duration.value * 0.05;
        const list = cuePositions;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] > pos) {
                // Samples -> seconds of the file -> beats of the file -> bars.
                return (list[i] - pos) / total * duration.value * bpm / 240;
            }
        }
        return -1;
    }

    function rescan() {
        const list = [];
        for (let i = 0; i < cues.count; ++i) {
            const it = cues.itemAt(i);
            if (it && it.pos >= 0) {
                list.push(it.pos);
            }
        }
        list.sort((a, b) => a - b);
        cuePositions = list;
    }

    visible: false

    Mixxx.ControlProxy { id: loaded; group: root.group; key: "track_loaded" }
    Mixxx.ControlProxy { id: samples; group: root.group; key: "track_samples" }
    Mixxx.ControlProxy { id: duration; group: root.group; key: "duration" }
    Mixxx.ControlProxy { id: fileBpm; group: root.group; key: "file_bpm" }
    Mixxx.ControlProxy { id: playPos; group: root.group; key: "playposition" }

    // Collects the changes of many cues (track load) into one rescan.
    Timer {
        id: rescanTimer

        interval: 30
        onTriggered: root.rescan()
    }
    Repeater {
        id: cues

        model: root.cueNumbers

        Item {
            id: cueItem

            required property int modelData
            readonly property real pos: cuePos.value

            onPosChanged: rescanTimer.restart()

            Mixxx.ControlProxy {
                id: cuePos

                group: root.group
                key: "hotcue_" + cueItem.modelData + "_position"
            }
        }
    }
}
