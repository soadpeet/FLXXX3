import "." as Skin
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick 2.12
import "Theme"

Item {
    // FLXXX3: the CDJ view draws the overview on black.
    property color backgroundColor: Theme.deckBackgroundColor

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
        color: root.backgroundColor

        MixxxControls.WaveformOverview {
            anchors.fill: parent
            channels: Mixxx.WaveformOverview.Channels.BothChannels
            minuteMarkers: Mixxx.Config.waveformOverviewMinuteMarkers
            // FLXXX3: always normalized, so that every track fills the overview the same way.
            normalized: Mixxx.Product.ui ? true : Mixxx.Config.waveformOverviewNormalized
            renderer: Mixxx.Config.waveformOverviewType === 0 ? Mixxx.WaveformOverview.Renderer.Filtered : Mixxx.Config.waveformOverviewType === 1 ? Mixxx.WaveformOverview.Renderer.HSV : Mixxx.WaveformOverview.Renderer.RGB
            // FLXXX3: one upper half instead of mirrored left/right.
            stereo: Mixxx.Product.ui ? false : Mixxx.Config.waveformOverviewStereo
            colorHigh: Theme.white
            colorMid: Theme.blue
            colorLow: Theme.green
            group: root.group
            // FLXXX3: no moving by touch while the track plays and the
            // channel fader is up (20 % or more).
            interactive: !Mixxx.Product.ui ||
                    !(overviewPlayControl.value > 0 && overviewVolumeControl.value >= 0.2)
        }
    }
    Mixxx.ControlProxy {
        id: overviewPlayControl

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: overviewVolumeControl

        group: root.group
        key: "volume"
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
