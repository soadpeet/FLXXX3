import "." as Skin
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import "Theme"

Item {
    id: root

    enum MouseStatus {
        Normal,
        Bending,
        Scratching
    }

    required property string group
    property bool splitStemTracks: false
    readonly property int activeWaveformType: Mixxx.Config.waveformType === Mixxx.WaveformDisplay.Type.Simple || Mixxx.Config.waveformType === Mixxx.WaveformDisplay.Type.Filtered || Mixxx.Config.waveformType === Mixxx.WaveformDisplay.Type.HSV || Mixxx.Config.waveformType === Mixxx.WaveformDisplay.Type.RGB || Mixxx.Config.waveformType === Mixxx.WaveformDisplay.Type.Stacked ? Mixxx.Config.waveformType : Mixxx.WaveformDisplay.Type.RGB
    // Renderer factories are created once by QmlWaveformDisplay. Keep track
    // of the type that was used for the scene-graph stack so a change from
    // the legacy preferences dialog can recreate that stack explicitly.
    property int renderedWaveformType: -1
    // Android edition: fixed gain (the waveform data is already normalised).
    readonly property real visualGain: Qt.platform.os === "android" ? 1.0 : Mixxx.Config.waveformVisualGainAll
    readonly property string zoomGroup: Mixxx.Config.waveformZoomSynchronization ? "[Channel1]" : group

    Connections {
        target: Mixxx.Config

        function onWaveformTypeChanged() {
            // Defer until activeWaveformType has been reevaluated, then
            // rebuild the renderer list on the scene-graph thread.
            Qt.callLater(function() {
                if (root.activeWaveformType === root.renderedWaveformType) {
                    return;
                }
                root.renderedWaveformType = root.activeWaveformType;
                waveformDisplay.refreshRenderers();
            });
        }

        function onWaveformDefaultZoomChanged() {
            if (zoomControl.group === root.group) {
                zoomControl.value = Mixxx.Config.waveformDefaultZoom;
            }
        }
    }

    MixxxControls.WaveformDisplay {
        id: waveformDisplay

        anchors.fill: parent
        backgroundColor: "transparent"
        frameRate: Mixxx.Config.waveformFrameRate
        group: root.group
        options: Qt.platform.os === "android" ? Mixxx.WaveformDisplay.Option.None : Mixxx.Config.waveformOptions
        visible: Mixxx.Config.waveformEnabled
        zoom: zoomControl.value

        Behavior on zoom {
            SmoothedAnimation {
                // Android edition: follows the fingers almost directly.
                duration: Qt.platform.os === "android" ? 60 : 500
                velocity: -1
            }
        }

        Mixxx.WaveformRendererEndOfTrack {
            color: '#ff8872'
            endOfTrackWarningTime: Mixxx.Config.waveformEndOfTrackWarningTime
        }
        // No pre-roll arrows before the start of the track (Android edition).
        Mixxx.WaveformRendererMarkRange {
            // Loop
            Mixxx.WaveformMarkRange {
                color: Qt.platform.os === "android" ? '#ff8c1a' : '#00b400'
                disabledColor: '#FFFFFF'
                disabledOpacity: 0.6
                enabledControl: "loop_enabled"
                endControl: "loop_end_position"
                opacity: 0.7
                startControl: "loop_start_position"
            }
            // Intro
            Mixxx.WaveformMarkRange {
                color: '#2c5c9a'
                durationTextColor: '#ffffff'
                durationTextLocation: 'after'
                endControl: "intro_end_position"
                opacity: 0.6
                startControl: "intro_start_position"
            }
            // Outro
            Mixxx.WaveformMarkRange {
                color: '#2c5c9a'
                durationTextColor: '#ffffff'
                durationTextLocation: 'before'
                endControl: "outro_end_position"
                opacity: 0.6
                startControl: "outro_start_position"
            }
        }
        Mixxx.WaveformRendererFiltered {
            axesColor: '#a1a1a1a1'
            enabled: root.activeWaveformType === Mixxx.WaveformDisplay.Type.Filtered
            gainAll: root.visualGain
            gainHigh: Mixxx.Config.waveformVisualGainHigh
            gainLow: Mixxx.Config.waveformVisualGainLow
            gainMid: Mixxx.Config.waveformVisualGainMedium
            highColor: Qt.platform.os === "android" ? '#ffffff' : '#D5C2A2'
            lowColor: Qt.platform.os === "android" ? '#1e5bff' : '#2154D7'
            midColor: Qt.platform.os === "android" ? '#ff9a1f' : '#97632D'
        }
        Mixxx.WaveformRendererFiltered {
            axesColor: '#a1a1a1a1'
            enabled: root.activeWaveformType === Mixxx.WaveformDisplay.Type.Stacked
            gainAll: root.visualGain
            gainHigh: Mixxx.Config.waveformVisualGainHigh
            gainLow: Mixxx.Config.waveformVisualGainLow
            gainMid: Mixxx.Config.waveformVisualGainMedium
            highColor: '#D5C2A2'
            lowColor: '#2154D7'
            midColor: '#97632D'
            stacked: true
        }
        Mixxx.WaveformRendererSimple {
            axesColor: '#a1a1a1a1'
            color: Qt.platform.os === "android" ? '#1f8fe8' : '#D5C2A2'
            enabled: Qt.platform.os !== "android" && root.activeWaveformType === Mixxx.WaveformDisplay.Type.Simple
            gain: root.visualGain
        }
        Mixxx.WaveformRendererHSV {
            axesColor: '#a1a1a1a1'
            color: '#D5C2A2'
            enabled: root.activeWaveformType === Mixxx.WaveformDisplay.Type.HSV
            gainAll: root.visualGain
            gainHigh: Mixxx.Config.waveformVisualGainHigh
            gainLow: Mixxx.Config.waveformVisualGainLow
            gainMid: Mixxx.Config.waveformVisualGainMedium
        }
        Mixxx.WaveformRendererRGB {
            readonly property bool blueScheme: Qt.platform.os === "android" && root.activeWaveformType === Mixxx.WaveformDisplay.Type.Simple

            axesColor: '#a1a1a1a1'
            enabled: root.activeWaveformType === Mixxx.WaveformDisplay.Type.RGB || blueScheme
            gainAll: root.visualGain
            gainHigh: Mixxx.Config.waveformVisualGainHigh
            gainLow: Mixxx.Config.waveformVisualGainLow
            gainMid: Mixxx.Config.waveformVisualGainMedium
            // BLUE: dark blue bass, bright blue mids, pale highs. RGB: red
            // bass, green mids, blue highs.
            highColor: blueScheme ? '#ffffff' : '#2f7bff'
            lowColor: blueScheme ? '#2560ff' : '#ff2d2d'
            midColor: blueScheme ? '#6cc3ff' : '#2fe05a'
        }
        Mixxx.WaveformRendererStem {
            gainAll: root.splitStemTracks ? 2.0 : 1.0
            opacity: Mixxx.Config.waveformStemOpacity
            outlineOpacity: Mixxx.Config.waveformStemOutlineOpacity
            reorderOnChange: Mixxx.Config.waveformStemReorderOnChange
            splitStemTracks: root.splitStemTracks || Mixxx.Config.waveformStemSplitTracks
        }
        Mixxx.WaveformRendererBeat {
            color: Qt.rgba(161 / 255, 161 / 255, 161 / 255, Mixxx.Config.waveformBeatGridAlpha / 100)
        }
        Mixxx.WaveformRendererMark {
            playMarkerBackground: '#D9D9D9'
            playMarkerColor: '#D9D9D9'
            playMarkerPosition: Mixxx.Config.waveformPlayMarkerPosition
            untilMark.align: Mixxx.Config.waveformUntilMarkAlign === 0 ? Qt.AlignTop : Mixxx.Config.waveformUntilMarkAlign === 2 ? Qt.AlignBottom : Qt.AlignVCenter
            untilMark.showBeats: Mixxx.Config.waveformUntilMarkShowBeats
            untilMark.showTime: Mixxx.Config.waveformUntilMarkShowTime
            untilMark.textHeightLimit: Mixxx.Config.waveformUntilMarkTextHeightLimit
            untilMark.textSize: Mixxx.Config.waveformUntilMarkTextPointSize

            defaultMark: Mixxx.WaveformMark {
                // Android edition: hotcue squares / memory cue triangles above
                // the waveform.
                align: Qt.platform.os === "android" ? "top|hcenter" : "bottom|right"
                color: "#00d9ff"
                endIcon: Qt.resolvedUrl("images/jump_%1.svg")
                text: " %1 "
                textColor: "#1a1a1a"
            }

            Mixxx.WaveformMark {
                align: Qt.platform.os === "android" ? 'bottom|hcenter' : 'top|right'
                color: 'red'
                control: "cue_point"
                text: 'CUE'
                textColor: '#1a1a1a'
            }
            Mixxx.WaveformMark {
                align: 'top|left'
                color: 'green'
                control: "loop_start_position"
                text: '↻'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'bottom|right'
                color: 'green'
                control: "loop_end_position"
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|right'
                color: 'blue'
                control: "intro_start_position"
                text: '◢'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|left'
                color: 'blue'
                control: "intro_end_position"
                text: '◢'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|right'
                color: 'blue'
                control: "outro_start_position"
                text: '◣'
                textColor: '#FFFFFF'
            }
            Mixxx.WaveformMark {
                align: 'top|left'
                color: 'blue'
                control: "outro_end_position"
                text: '◣'
                textColor: '#FFFFFF'
            }
        }
    }
    Mixxx.ControlProxy {
        id: touchPlayControl

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: touchVolumeControl

        group: root.group
        key: "volume"
    }
    Mixxx.ControlProxy {
        id: scratchPositionEnableControl

        group: root.group
        key: "scratch_position_enable"
    }
    Mixxx.ControlProxy {
        id: scratchPositionControl

        group: root.group
        key: "scratch_position"
    }
    Mixxx.ControlProxy {
        id: wheelControl

        group: root.group
        key: "wheel"
    }
    Mixxx.ControlProxy {
        id: rateRatioControl

        group: root.group
        key: "rate_ratio"
    }
    Mixxx.ControlProxy {
        id: zoomControl

        group: root.zoomGroup
        key: "waveform_zoom"

        Component.onCompleted: {
            if (group == root.group) {
                value = Mixxx.Config.waveformDefaultZoom
            }
        }
    }
    // TEMP-DIAG: events that could make the waveform twitch while the track stands.
    Mixxx.ControlProxy { id: diagPos; group: root.group; key: "playposition" }
    Connections {
        function onValueChanged() { Mixxx.AndroidStatus.log(root.group + " zoom " + zoomControl.value); }
        target: zoomControl
    }
    Connections {
        function onValueChanged() { Mixxx.AndroidStatus.log(root.group + " scratchEnable " + scratchPositionEnableControl.value); }
        target: scratchPositionEnableControl
    }
    Connections {
        function onValueChanged() { Mixxx.AndroidStatus.log(root.group + " rate " + rateRatioControl.value); }
        target: rateRatioControl
    }
    Connections {
        function onValueChanged() { Mixxx.AndroidStatus.log(root.group + " pos " + diagPos.value + " play " + touchPlayControl.value); }
        target: diagPos
    }
    Connections {
        function onActiveChanged() { Mixxx.AndroidStatus.log(root.group + " touchDrag " + touchDrag.active); }
        target: touchDrag
    }
    // Android edition: move the track with one finger (scratch). The scratch
    // mode is always left when the finger lifts or a second finger arrives
    // (then the pinch zoom takes over).
    DragHandler {
        id: touchDrag

        acceptedDevices: PointerDevice.TouchScreen
        // Locked while the track plays (no moving by touch).
        // Locked only while the track plays AND the channel fader is up (20 % or more).
        enabled: Qt.platform.os === "android" && !(touchPlayControl.value > 0 && touchVolumeControl.value >= 0.2)
        maximumPointCount: 1
        target: null

        onActiveChanged: {
            if (active) {
                scratchPositionControl.value = -centroid.position.x * waveformDisplay.audioSamplePerPixel * 2;
                scratchPositionEnableControl.value = 1;
            } else {
                scratchPositionEnableControl.value = 0;
                scratchPositionControl.value = 0;
            }
        }
        onCentroidChanged: {
            if (active)
                scratchPositionControl.value = -centroid.position.x * waveformDisplay.audioSamplePerPixel * 2;
        }
    }
    MouseArea {
        // Android edition: no mouse scratching (it got stuck during pinch
        // zoom and kept the deck from playing).
        enabled: Qt.platform.os !== "android"
        property point mouseAnchor: Qt.point(0, 0)
        property int mouseStatus: WaveformDisplay.MouseStatus.Normal

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent

        onDoubleClicked: {
            if (mouse.button == Qt.RightButton) {
                root.splitStemTracks = !root.splitStemTracks;
            }
        }
        onPositionChanged: {
            const diff = mouse.x - mouseAnchor.x;
            switch (mouseStatus) {
            case WaveformDisplay.MouseStatus.Bending:
                {
                    // Start at the middle of [0.0, 1.0], and emit values based on how far
                    // the mouse has traveled horizontally. Note, for legacy (MIDI) reasons,
                    // this is tuned to 127.
                    const v = 0.5 + (diff / root.width);
                    // clamp to [0.0, 1.0]
                    wheelControl.parameter = Math.max(Math.min(v, 1), 0);
                    break;
                }
                ;
            case WaveformDisplay.MouseStatus.Scratching:
                scratchPositionControl.value = -mouse.x * waveformDisplay.audioSamplePerPixel * 2;
                break;
            }
        }
        onPressed: {
            mouseAnchor = Qt.point(mouse.x, mouse.y);
            if (mouse.button == Qt.LeftButton) {
                if (mouseStatus == WaveformDisplay.MouseStatus.Bending)
                    wheelControl.parameter = 0.5;

                mouseStatus = WaveformDisplay.MouseStatus.Scratching;
                scratchPositionControl.value = -mouse.x * waveformDisplay.audioSamplePerPixel * 2;
                scratchPositionEnableControl.value = 1;
            } else {
                if (mouseStatus == WaveformDisplay.MouseStatus.Scratching)
                    scratchPositionEnableControl.value = 0;

                wheelControl.parameter = 0.5;
                mouseStatus = WaveformDisplay.MouseStatus.Bending;
            }
        }
        onReleased: {
            switch (mouseStatus) {
            case WaveformDisplay.MouseStatus.Bending:
                wheelControl.parameter = 0.5;
                break;
            case WaveformDisplay.MouseStatus.Scratching:
                scratchPositionEnableControl.value = 0;
                scratchPositionControl.value = 0;
                break;
            }
            mouseStatus = WaveformDisplay.MouseStatus.Normal;
        }
        onWheel: mouse => {
            if (mouse.angleDelta.y < 0 && zoomControl.value > 1) {
                zoomControl.value -= 1;
            } else if (mouse.angleDelta.y > 0 && zoomControl.value < 10.0) {
                zoomControl.value += 1;
            }
        }
    }
}
