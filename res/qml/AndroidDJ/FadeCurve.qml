import QtQuick 2.12

// Small icon of a channel fader curve (slow start, linear, fast start).
Canvas {
    id: curve

    property int kind: 0
    property bool selected: false

    onKindChanged: requestPaint()
    onSelectedChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = selected ? "#ffffff" : "#e0e0e0";
        ctx.beginPath();
        const w = width, h = height, m = 6;
        ctx.moveTo(m, h - m);
        if (kind === 0) {
            ctx.quadraticCurveTo(w * 0.7, h - m, w - m, m);
        } else if (kind === 1) {
            ctx.lineTo(w - m, m);
        } else {
            ctx.quadraticCurveTo(w * 0.3, m, w - m, m);
        }
        ctx.lineTo(w - m, h - m);
        ctx.closePath();
        ctx.fill();
    }
}
