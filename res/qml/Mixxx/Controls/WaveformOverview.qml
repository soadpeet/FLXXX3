import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12

Mixxx.WaveformOverview {
    id: root

    property color cueMarkerColor: "red"
    property color introOutroMarkerColor: "blue"
    property bool interactive: true
    property color loopMarkerColor: "green"
    // Android edition: thick white play position marker.
    property string playPositionMarkerColor: "white"
    property color analyzerStatusColor: "orangered"
    property bool showAnalyzerStatus: false
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    readonly property double playerAnalyzerProgress: root.player?.analyzerProgress ?? -1
    readonly property string analyzerStatusText: {
        if (!root.showAnalyzerStatus || !root.player?.isLoaded) {
            return "";
        }
        if (!root.player?.trackLoaded) {
            return qsTr("Loading track...");
        }
        if (root.playerAnalyzerProgress < 0 || root.playerAnalyzerProgress >= 1) {
            return "";
        }
        if (root.playerAnalyzerProgress <= 0.5) {
            return qsTr("Ready to play, analyzing...");
        }
        if (root.playerAnalyzerProgress >= 0.95) {
            return qsTr("Finalizing...");
        }
        return "";
    }

    minuteMarkers: Mixxx.Config.waveformOverviewMinuteMarkers
    analyzerProgress: root.playerAnalyzerProgress
    normalized: Mixxx.Config.waveformOverviewNormalized
    renderer: Mixxx.Config.waveformOverviewType === 0 ? Mixxx.WaveformOverview.Renderer.Filtered : Mixxx.Config.waveformOverviewType === 1 ? Mixxx.WaveformOverview.Renderer.HSV : Mixxx.WaveformOverview.Renderer.RGB
    stereo: Mixxx.Config.waveformOverviewStereo
    track: player?.currentTrack

    Mixxx.ControlProxy {
        id: trackLoadedControl

        group: root.group
        key: "track_loaded"

        onValueChanged: value => {
            markers.visible = value;
        }
    }
    Mixxx.ControlProxy {
        id: playPositionControl

        group: root.group
        key: "playposition"
    }
    Text {
        x: 10
        y: 0
        color: Qt.rgba(root.analyzerStatusColor.r,
                root.analyzerStatusColor.g,
                root.analyzerStatusColor.b,
                0.5)
        font.family: "Open Sans"
        font.pixelSize: 13
        text: root.analyzerStatusText
        visible: text.length > 0
    }
    Item {
        id: markers

        anchors.fill: parent
        visible: trackLoadedControl.value

        // Android edition: the part behind the play position (already played)
        // is darkened, the rest keeps the colours of the scrolling waveform.
        Rectangle {
            color: "#000000"
            height: parent.height * 0.82
            opacity: 0.5
            visible: Qt.platform.os === "android"
            width: parent.width * Math.min(1, Math.max(0, playPositionControl.value))
            x: 0
            y: 0
        }
        MixxxControls.WaveformOverviewMarkerLayer {
            anchors.fill: parent
            cueColor: root.cueMarkerColor
            cueText: Qt.platform.os === "android" ? "" : "C"
            group: root.group
            introOutroColor: root.introOutroMarkerColor
            introStartText: "IN"
            labelColor: "white"
            loopColor: root.loopMarkerColor
            loopStartText: "LOOP"
            outroStartText: "OUT"
            showHotcueLabels: false
            showIntroOutroLabels: false
            showLoopLabel: false
        }
        MixxxControls.WaveformOverviewMarker {
            id: playPositionMarker

            anchors.fill: parent
            color: root.playPositionMarkerColor
            group: root.group
            key: "playposition"
            lineWidth: Qt.platform.os === "android" ? 3 : 1
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.interactive
        hoverEnabled: true

        onPositionChanged: mouse => {
            if (this.containsPress)
                playPositionControl.value = mouse.x / this.width;
        }
        onPressed: mouse => {
            playPositionControl.value = mouse.x / this.width;
        }
    }
}
