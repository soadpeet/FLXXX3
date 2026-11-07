import "." as Skin
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import "Theme"

Item {
    id: root

    required property string group

    states: [
        State {
            when: passthroughControl.value == 0

            PropertyChanges {
                target: waveformContainer
                opacity: 1
                visible: true
            }

            PropertyChanges {
                target: passthroughContainer
                opacity: 0
                visible: false
            }

        },
        State {
            when: passthroughControl.value != 0

            PropertyChanges {
                target: waveformContainer
                opacity: 0
                visible: false
            }

            PropertyChanges {
                target: passthroughContainer
                opacity: 1
                visible: true
            }
        }
    ]
    transitions: [
        Transition {
            enabled: passthroughContainer.visible

            SequentialAnimation {
                PropertyAction {
                    target: waveformContainer
                    property: "visible"
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: waveformContainer
                        property: "opacity"
                        duration: 150
                    }

                    NumberAnimation {
                        target: passthroughContainer
                        property: "opacity"
                        duration: 150
                    }
                }

                PropertyAction {
                    target: passthroughContainer
                    property: "visible"
                }
            }

        },
        Transition {
            enabled: waveformContainer.visible

            SequentialAnimation {
                PropertyAction {
                    target: passthroughContainer
                    property: "visible"
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: waveformContainer
                        property: "opacity"
                        duration: 150
                    }

                    NumberAnimation {
                        target: passthroughContainer
                        property: "opacity"
                        duration: 150
                    }
                }

                PropertyAction {
                    target: waveformContainer
                    property: "visible"
                }
            }
        }
    ]

    Mixxx.ControlProxy {
        id: passthroughControl

        group: root.group
        key: "passthrough"
    }

    Rectangle {
        id: waveformContainer

        anchors.fill: parent
        color: Theme.deckBackgroundColor

        MixxxControls.WaveformOverview {
            anchors.fill: parent
            channels: Mixxx.WaveformOverview.Channels.BothChannels
            minuteMarkers: Mixxx.Config.waveformOverviewMinuteMarkers
            normalized: Mixxx.Config.waveformOverviewNormalized
            renderer: Mixxx.Config.waveformOverviewType === 0 ? Mixxx.WaveformOverview.Renderer.Filtered : Mixxx.Config.waveformOverviewType === 1 ? Mixxx.WaveformOverview.Renderer.HSV : Mixxx.WaveformOverview.Renderer.RGB
            // Android edition: one upper half instead of mirrored left/right.
            stereo: Qt.platform.os === "android" ? false : Mixxx.Config.waveformOverviewStereo
            colorHigh: Theme.white
            colorMid: Theme.blue
            colorLow: Theme.green
            group: root.group
            // Android edition: no moving by touch while the track plays.
            interactive: Qt.platform.os !== "android" || overviewPlayControl.value <= 0
        }
    }
    Mixxx.ControlProxy {
        id: overviewPlayControl

        group: root.group
        key: "play"
    }

    Rectangle {
        id: passthroughContainer

        anchors.fill: parent
        color: "transparent"

        Skin.SectionText {
            anchors.centerIn: parent
            text: "Passthrough Enabled"
        }
    }
}
