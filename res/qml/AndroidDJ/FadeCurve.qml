import QtQuick 2.12
import QtQuick.Shapes 1.12

// Small icon of a channel fader curve (slow start, linear, fast start). Drawn as a vector shape
// (the Canvas before was painted once and then stretched: blurry and of a different size).
Item {
    id: curve

    property int kind: 0
    property bool selected: false

    // Corners of the drawing (inner margin 6 px).
    readonly property real x0: 6
    readonly property real y0: height - 6
    readonly property real x1: width - 6
    readonly property real y1: 6

    Shape {
        anchors.fill: parent
        // Smooth edges.
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: curve.selected ? "#ffffff" : "#e0e0e0"
            startX: curve.x0
            startY: curve.y0
            strokeColor: "transparent"

            // 0: slow start (rises late), 1: straight, 2: fast start (the mirror image of 0).
            PathQuad {
                controlX: curve.kind === 0 ? curve.x0 + (curve.x1 - curve.x0) * 0.75
                        : (curve.kind === 1 ? (curve.x0 + curve.x1) / 2 : curve.x0 + (curve.x1 - curve.x0) * 0.25)
                controlY: curve.kind === 0 ? curve.y0
                        : (curve.kind === 1 ? (curve.y0 + curve.y1) / 2 : curve.y1)
                x: curve.x1
                y: curve.y1
            }
            PathLine {
                x: curve.x1
                y: curve.y0
            }
            PathLine {
                x: curve.x0
                y: curve.y0
            }
        }
    }
}
