import QtQuick 2.12

// Row of touch segments (one selected), like the buttons of the RX3 utility
// menu. Visual only: the selection is kept locally until it gets a function.
Row {
    id: root

    property var labels: []
    property int currentIndex: 0
    property real fontSize: 12
    property color selectedColor: "#1fb0f0"

    signal activated(int index)

    spacing: 0

    Repeater {
        model: root.labels

        Rectangle {
            id: segment

            required property int index
            required property string modelData

            border.color: "#cfcfcf"
            border.width: 1
            color: root.currentIndex === index ? root.selectedColor : (tap.pressed ? "#3a3a3a" : "#2a2a2a")
            height: root.height
            width: root.width / root.labels.length

            Text {
                anchors.centerIn: parent
                color: root.currentIndex === segment.index ? "#ffffff" : "#e0e0e0"
                font.bold: true
                font.pixelSize: root.fontSize
                horizontalAlignment: Text.AlignHCenter
                text: segment.modelData
            }
            TapHandler {
                id: tap

                onTapped: {
                    root.currentIndex = segment.index;
                    root.activated(segment.index);
                }
            }
        }
    }
}
