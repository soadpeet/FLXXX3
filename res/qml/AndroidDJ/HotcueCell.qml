import "../" as Skin
import QtQuick 2.12

// One hotcue pad (A..H). Shows set/empty state and colour, tap = trigger.
Rectangle {
    id: root

    required property string group
    required property int hotcueNumber
    readonly property string letter: String.fromCharCode(64 + hotcueNumber)

    border.color: hotcue.isSet ? hotcue.color : "#3a3a3a"
    border.width: 1
    color: hotcue.isSet ? Qt.alpha(hotcue.color, 0.35) : "#1c1c1c"
    radius: 2

    Skin.Hotcue {
        id: hotcue

        group: root.group
        hotcueNumber: root.hotcueNumber
    }
    Text {
        anchors.centerIn: parent
        color: hotcue.isSet ? "#ffffff" : "#6a6a6a"
        font.bold: true
        font.pixelSize: Math.max(9, root.height * 0.45)
        text: root.letter
    }
    TapHandler {
        onTapped: hotcue.activate = 1
    }
}
