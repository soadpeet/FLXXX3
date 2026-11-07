pragma ComponentBehavior: Bound

import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Shapes 1.12

Item {
    id: root

    required property string group
    property int hotcueCount: 8
    property color cueColor: "red"
    property color loopColor: "green"
    property color introOutroColor: "blue"
    property color labelColor: "white"
    property color fallbackHotcueColor: cueColor
    property string cueText: "CUE"
    property string loopStartText: "LOOP"
    property string introStartText: "IN"
    property string outroStartText: "OUT"
    property string introOutroVisibilityGroup: "[Skin]"
    property string introOutroVisibilityKey: "show_intro_outro_cues"
    property string fontFamily: ""
    property int labelPixelSize: 10
    property bool labelBold: true
    property bool showHotcueLabels: true
    property bool showCueLabel: true
    property bool showLoopLabel: true
    property bool showIntroOutroLabels: true
    property real loopRangeOpacity: 0.7
    property real introOutroRangeOpacity: 0.6
    property int markerWidth: 1
    property int labelTopMargin: 2
    property int labelHorizontalMargin: 2
    // Android edition (RX3 style): size of the cue symbols, in pixels.
    readonly property bool rx3Style: Qt.platform.os === "android"
    readonly property real symbolSize: Math.max(9, Math.round(root.height * 0.17))

    function mapX(position) {
        if (trackSamplesProxy.value <= 0 || position < 0) {
            return -9999;
        }
        return (root.width * position) / trackSamplesProxy.value;
    }

    function clampedX(position, itemWidth) {
        return Math.max(0, Math.min(Math.max(0, root.width - itemWidth), position));
    }

    Mixxx.ControlProxy {
        id: trackSamplesProxy

        group: root.group
        key: "track_samples"
    }

    Mixxx.ControlProxy {
        id: cuePointProxy

        group: root.group
        key: "cue_point"
    }

    Mixxx.ControlProxy {
        id: loopStartProxy

        group: root.group
        key: "loop_start_position"
    }

    Mixxx.ControlProxy {
        id: loopEndProxy

        group: root.group
        key: "loop_end_position"
    }

    Mixxx.ControlProxy {
        id: loopEnabledProxy

        group: root.group
        key: "loop_enabled"
    }

    Mixxx.ControlProxy {
        id: introStartProxy

        group: root.group
        key: "intro_start_position"
    }

    Mixxx.ControlProxy {
        id: introEndProxy

        group: root.group
        key: "intro_end_position"
    }

    Mixxx.ControlProxy {
        id: outroStartProxy

        group: root.group
        key: "outro_start_position"
    }

    Mixxx.ControlProxy {
        id: outroEndProxy

        group: root.group
        key: "outro_end_position"
    }

    Mixxx.ControlProxy {
        id: showIntroOutroCuesProxy

        group: root.introOutroVisibilityGroup
        key: root.introOutroVisibilityKey
    }

    Repeater {
        model: root.hotcueCount

        delegate: Item {
            id: hotcueMarker

            required property int index
            readonly property int hotcueNumber: index + 1
            readonly property real markerX: root.mapX(positionProxy.value)
            readonly property color markerColor: colorProxy.value >= 0
                    ? "#" + Math.round(colorProxy.value).toString(16).padStart(6, "0")
                    : root.fallbackHotcueColor

            anchors.fill: parent
            visible: statusProxy.value > 0 && positionProxy.value >= 0
            z: 1

            Rectangle {
                x: root.clampedX(hotcueMarker.markerX, width)
                y: 0
                width: root.markerWidth
                height: parent.height
                color: hotcueMarker.markerColor
                visible: !root.rx3Style
            }
            // Square in the colour of the hotcue with its letter.
            Rectangle {
                color: hotcueMarker.markerColor
                height: root.symbolSize
                visible: root.rx3Style
                width: root.symbolSize
                x: root.clampedX(hotcueMarker.markerX - root.symbolSize / 2, width)
                y: 0

                Text {
                    anchors.centerIn: parent
                    color: "#000000"
                    font.bold: true
                    font.pixelSize: Math.round(root.symbolSize * 0.8)
                    text: String.fromCharCode(64 + hotcueMarker.hotcueNumber)
                }
            }

            Text {
                x: root.clampedX(hotcueMarker.markerX + root.labelHorizontalMargin, width)
                y: root.labelTopMargin
                width: 12
                height: Math.max(root.labelPixelSize + 2, 10)
                text: hotcueMarker.hotcueNumber
                color: root.labelColor
                font.family: root.fontFamily
                font.pixelSize: root.labelPixelSize
                font.bold: root.labelBold
                verticalAlignment: Text.AlignVCenter
                visible: root.showHotcueLabels && !root.rx3Style
            }

            Mixxx.ControlProxy {
                id: statusProxy

                group: root.group
                key: "hotcue_" + hotcueMarker.hotcueNumber + "_status"
            }

            Mixxx.ControlProxy {
                id: positionProxy

                group: root.group
                key: "hotcue_" + hotcueMarker.hotcueNumber + "_position"
            }

            Mixxx.ControlProxy {
                id: colorProxy

                group: root.group
                key: "hotcue_" + hotcueMarker.hotcueNumber + "_color"
            }
        }
    }

    // Memory cues (hotcue slots 17 and up, see the Rekordbox import): red
    // triangles above the waveform pointing at their position.
    Repeater {
        model: root.rx3Style ? 20 : 0

        delegate: Item {
            id: memoryCue

            required property int index
            readonly property int slot: index + 17
            readonly property real markerX: root.mapX(memoryPosition.value)

            anchors.fill: parent
            visible: memoryStatus.value > 0 && memoryPosition.value >= 0
            z: 1

            Shape {
                height: root.symbolSize
                width: root.symbolSize
                x: memoryCue.markerX - root.symbolSize / 2
                y: 0

                ShapePath {
                    fillColor: "#e03030"
                    strokeColor: "transparent"

                    startX: 0
                    startY: 0
                    PathLine { x: root.symbolSize; y: 0 }
                    PathLine { x: root.symbolSize / 2; y: root.symbolSize }
                    PathLine { x: 0; y: 0 }
                }
            }
            Mixxx.ControlProxy {
                id: memoryStatus

                group: root.group
                key: "hotcue_" + memoryCue.slot + "_status"
            }
            Mixxx.ControlProxy {
                id: memoryPosition

                group: root.group
                key: "hotcue_" + memoryCue.slot + "_position"
            }
        }
    }

    readonly property real loopStartX: mapX(loopStartProxy.value)
    readonly property real loopEndX: mapX(loopEndProxy.value)
    readonly property bool loopValid: loopStartProxy.value >= 0 &&
            loopEndProxy.value >= 0 &&
            loopEnabledProxy.value > 0
    readonly property real cueX: mapX(cuePointProxy.value)
    readonly property bool showIntroOutroCues: showIntroOutroCuesProxy.value > 0
    readonly property real introStartX: mapX(introStartProxy.value)
    readonly property real introEndX: mapX(introEndProxy.value)
    readonly property bool introValid: introStartProxy.value >= 0 &&
            introEndProxy.value >= 0 &&
            showIntroOutroCues
    readonly property real outroStartX: mapX(outroStartProxy.value)
    readonly property real outroEndX: mapX(outroEndProxy.value)
    readonly property bool outroValid: outroStartProxy.value >= 0 &&
            outroEndProxy.value >= 0 &&
            showIntroOutroCues

    Rectangle {
        x: Math.min(root.loopStartX, root.loopEndX)
        y: 0
        width: Math.max(root.markerWidth, Math.abs(root.loopEndX - root.loopStartX))
        height: parent.height
        color: root.loopColor
        opacity: root.loopRangeOpacity
        visible: root.loopValid
    }

    Rectangle {
        x: root.loopStartX
        y: 0
        width: root.markerWidth
        height: parent.height
        color: root.loopColor
        visible: loopStartProxy.value >= 0
    }

    Text {
        x: root.clampedX(root.loopStartX + root.labelHorizontalMargin, width)
        y: root.labelTopMargin
        text: root.loopStartText
        color: root.labelColor
        font.family: root.fontFamily
        font.pixelSize: root.labelPixelSize
        font.bold: root.labelBold
        visible: root.showLoopLabel && loopStartProxy.value >= 0
    }

    Rectangle {
        x: root.loopEndX
        y: 0
        width: root.markerWidth
        height: parent.height
        color: root.loopColor
        visible: loopEndProxy.value >= 0
    }

    Rectangle {
        x: root.cueX
        y: 0
        width: root.markerWidth
        height: parent.height
        color: root.cueColor
        visible: cuePointProxy.value >= 0 && !root.rx3Style
    }
    // Main cue (RX3 style): small white triangle under the waveform.
    Shape {
        height: root.symbolSize
        visible: root.rx3Style && cuePointProxy.value >= 0
        width: root.symbolSize
        x: root.cueX - root.symbolSize / 2
        y: root.height * 0.8

        ShapePath {
            fillColor: "#ffffff"
            strokeColor: "transparent"

            startX: 0
            startY: root.symbolSize
            PathLine { x: root.symbolSize; y: root.symbolSize }
            PathLine { x: root.symbolSize / 2; y: 0 }
            PathLine { x: 0; y: root.symbolSize }
        }
    }

    Text {
        x: root.clampedX(root.cueX + root.labelHorizontalMargin, width)
        y: root.labelTopMargin
        text: root.cueText
        color: root.labelColor
        font.family: root.fontFamily
        font.pixelSize: root.labelPixelSize
        font.bold: root.labelBold
        visible: root.showCueLabel && cuePointProxy.value >= 0 && !root.rx3Style
    }

    Rectangle {
        x: Math.min(root.introStartX, root.introEndX)
        y: 0
        width: Math.max(root.markerWidth, Math.abs(root.introEndX - root.introStartX))
        height: parent.height
        color: root.introOutroColor
        opacity: root.introOutroRangeOpacity
        visible: root.introValid
    }

    Rectangle {
        x: root.introStartX
        y: 0
        width: root.markerWidth
        height: parent.height
        color: root.introOutroColor
        visible: introStartProxy.value >= 0 && root.showIntroOutroCues
    }

    Rectangle {
        x: root.introEndX
        y: 0
        width: root.markerWidth
        height: parent.height
        color: root.introOutroColor
        visible: introEndProxy.value >= 0 && root.showIntroOutroCues
    }

    Text {
        x: root.clampedX(root.introEndX + root.labelHorizontalMargin, width)
        y: root.labelTopMargin
        text: root.introStartText
        color: root.labelColor
        font.family: root.fontFamily
        font.pixelSize: root.labelPixelSize
        font.bold: root.labelBold
        visible: root.showIntroOutroLabels &&
                introEndProxy.value >= 0 &&
                root.showIntroOutroCues
    }

    Rectangle {
        x: Math.min(root.outroStartX, root.outroEndX)
        y: 0
        width: Math.max(root.markerWidth, Math.abs(root.outroEndX - root.outroStartX))
        height: parent.height
        color: root.introOutroColor
        opacity: root.introOutroRangeOpacity
        visible: root.outroValid
    }

    Rectangle {
        x: root.outroStartX
        y: 0
        width: root.markerWidth
        height: parent.height
        color: root.introOutroColor
        visible: outroStartProxy.value >= 0 && root.showIntroOutroCues
    }

    Rectangle {
        x: root.outroEndX
        y: 0
        width: root.markerWidth
        height: parent.height
        color: root.introOutroColor
        visible: outroEndProxy.value >= 0 && root.showIntroOutroCues
    }

    Text {
        x: root.clampedX(root.outroStartX + root.labelHorizontalMargin, width)
        y: root.labelTopMargin
        text: root.outroStartText
        color: root.labelColor
        font.family: root.fontFamily
        font.pixelSize: root.labelPixelSize
        font.bold: root.labelBold
        visible: root.showIntroOutroLabels &&
                outroStartProxy.value >= 0 &&
                root.showIntroOutroCues
    }
}
