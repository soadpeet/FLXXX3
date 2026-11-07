import QtQuick 2.12

// Small boxed label that lights up when `active` is true (QUANTIZE, SYNC, ...).
Rectangle {
    id: root

    property bool active: false
    property color activeColor: "#ff6a3d"
    property string text: ""
    property real fontSize: 10

    signal clicked

    border.color: active ? activeColor : "#4a4a4a"
    border.width: 1
    color: active ? Qt.alpha(activeColor, 0.18) : "transparent"
    implicitHeight: label.implicitHeight + 6
    implicitWidth: label.implicitWidth + 12
    radius: 2

    Text {
        id: label

        anchors.centerIn: parent
        color: root.active ? root.activeColor : "#8a8a8a"
        font.bold: root.active
        font.pixelSize: root.fontSize
        text: root.text
    }
    TapHandler {
        onTapped: root.clicked()
    }
}
