import QtQuick 2.12

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// Touch keyboard of the SEARCH screen (German layout): all letter keys have the
// same size, the shorter rows are centred, the action keys are in the last row.
Item {
    id: root

    property real s: 1.0
    // Label of the key at the end of the last row (SEARCH: NARROW DOWN).
    property string narrowLabel: "NARROW DOWN"

    signal typed(string text)
    signal backspace
    signal clearAll
    signal narrowDown

    readonly property var rows: [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä"],
        ["Y", "X", "C", "V", "B", "N", "M", "-", ".", "&"]
    ]
    readonly property real gap: Math.round(6 * root.s)
    readonly property real keyWidth: (width - gap * 10) / 11
    readonly property real keyHeight: Math.min((height - gap * 4) / 5, keyWidth * 1.8)

    Column {
        spacing: root.gap
        y: 0
        width: root.width

        Repeater {
            model: root.rows

            Row {
                id: keyRow

                required property var modelData

                spacing: root.gap
                x: (root.width - width) / 2

                Repeater {
                    model: keyRow.modelData

                    Rectangle {
                        required property string modelData

                        border.color: keyTap.pressed ? "#5fc0ff" : "#34363c"
                        color: keyTap.pressed ? "#1f6fb0" : "#23252a"
                        height: root.keyHeight
                        radius: Math.round(7 * root.s)
                        width: root.keyWidth

                        Text {
                            anchors.centerIn: parent
                            color: "#f2f2f2"
                            font.pixelSize: Math.round(root.keyHeight * 0.44)
                            text: parent.modelData
                        }
                        TapHandler {
                            id: keyTap

                            onTapped: root.typed(parent.modelData.toLowerCase())
                        }
                    }
                }
            }
        }
        Row {
            spacing: root.gap
            x: (root.width - width) / 2

            Repeater {
                model: [
                    { label: "CLEAR", span: 2, action: "clear" },
                    { label: "SPACE", span: 4, action: "space" },
                    { label: "DEL", span: 2, action: "back" },
                    { label: "NARROW DOWN", span: 3, action: "narrow" }
                ]

                Rectangle {
                    required property var modelData

                    border.color: actionTap.pressed ? "#5fc0ff" : (modelData.action === "narrow" ? "#1fb0f0" : "#34363c")
                    color: actionTap.pressed ? "#1f6fb0" : (modelData.action === "narrow" ? "#12385a" : "#2f3137")
                    height: root.keyHeight
                    radius: Math.round(7 * root.s)
                    // the keys of the last row span 2, 4, 2 and 3 letter keys
                    width: root.keyWidth * modelData.span + root.gap * (modelData.span - 1)

                    Text {
                        anchors.centerIn: parent
                        color: "#f2f2f2"
                        font.pixelSize: Math.round(root.keyHeight * 0.3)
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 8
                        text: parent.modelData.action === "narrow" ? root.narrowLabel : parent.modelData.label
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                    TapHandler {
                        id: actionTap

                        onTapped: {
                            switch (parent.modelData.action) {
                            case "clear":
                                root.clearAll();
                                break;
                            case "space":
                                root.typed(" ");
                                break;
                            case "back":
                                root.backspace();
                                break;
                            case "narrow":
                                root.narrowDown();
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}
