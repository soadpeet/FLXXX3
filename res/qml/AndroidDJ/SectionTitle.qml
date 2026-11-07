import QtQuick 2.12

// Section heading with a thin line below, used in the utility menu.
Item {
    id: root

    property real u: 12
    property string text: ""

    height: root.u * 1.6

    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        color: "#8a8a8a"
        font.pixelSize: root.u * 0.9
        text: root.text
    }
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        color: "#2a2a2a"
        height: 1
    }
}
