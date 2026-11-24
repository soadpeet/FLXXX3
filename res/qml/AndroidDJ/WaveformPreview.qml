// AI disclaimer: this file was written autonomously by an AI agent (Claude).

import QtQuick
import "../AdvSettings"

// Example waveform for ADVANCED SETTINGS > WAVEFORM: the four layers (blue = low, orange = mid,
// brown = inner part of mid, white = high) with the sizes of the settings, so that a change
// is seen at once. `example` is a piece of a real track (QmlConfigProxy::waveformExample: the
// layer heights as the renderer computes them); without one an invented example is drawn.
Item {
    id: root

    // { gain, columns, layers: [low, mid, high, brown] per column } or null
    property var example: null

    readonly property real sizeLow: AdvSettings.values.wave_size_low ?? 1
    readonly property real sizeMid: AdvSettings.values.wave_size_mid ?? 1
    readonly property real sizeBrown: AdvSettings.values.wave_size_brown ?? 1
    readonly property real sizeHigh: AdvSettings.values.wave_size_high ?? 1
    readonly property real gain: AdvSettings.values.waveGain ?? 1

    onExampleChanged: canvas.requestPaint()
    onSizeLowChanged: canvas.requestPaint()
    onSizeMidChanged: canvas.requestPaint()
    onSizeBrownChanged: canvas.requestPaint()
    onSizeHighChanged: canvas.requestPaint()
    onGainChanged: canvas.requestPaint()

    // Heights (0..255) of the four layers [low, mid, high, brown] of column i of n.
    function layersOf(i, n) {
        if (root.example && root.example.columns > 0) {
            const k = Math.min(root.example.columns - 1, Math.floor(i / n * root.example.columns)) * 4;
            return [root.example.layers[k], root.example.layers[k + 1], root.example.layers[k + 2], root.example.layers[k + 3]];
        }
        // invented example: kicks (low), a pad and a bass line (mid), hats (high)
        const x = i * 2;
        const beat = (x % 64) / 64;
        const kick = Math.exp(-beat * 5);
        const noise = 0.5 + 0.5 * Math.sin(x * 0.91) * Math.sin(x * 0.37);
        const low = 255 * Math.min(1, 0.25 + 0.75 * kick);
        const mid = 255 * Math.min(1, 0.3 + 0.35 * noise + 0.25 * Math.abs(Math.sin(x * 0.045)));
        const high = 255 * Math.min(1, ((x % 32) < 5 ? 0.9 : 0.2) * (0.6 + 0.4 * noise));
        const a1 = Math.min(204, mid * 1.3);
        return [Math.min(255, a1 + low * 0.3), a1, Math.min(high, a1 * 0.4), a1 * 0.7];
    }

    Rectangle {
        anchors.fill: parent
        color: "#0d0d0d"
        radius: 4
    }
    Canvas {
        id: canvas

        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            // a margin above and below: the layers never touch the edge
            const half = height / 2 * 0.86;
            const centre = height / 2;
            const n = Math.max(1, Math.floor(w / 2));
            const trackGain = root.example && root.example.gain ? root.example.gain : 0.9;
            const size = [root.sizeLow, root.sizeMid, root.sizeHigh, root.sizeBrown];
            // from the back to the front: blue, orange, brown, white
            const colors = {0: "#1f64f0", 1: "#ffa21f", 3: "#b7700f", 2: "#f6e8d4"};
            const order = [0, 1, 3, 2];
            const bars = [];
            for (let i = 0; i < n; ++i) {
                const a = root.layersOf(i, n);
                bars.push(a.map((v, k) => Math.min(half, Math.min(255, v * size[k]) / 255 * half * trackGain * root.gain)));
            }
            order.forEach(layer => {
                ctx.fillStyle = colors[layer];
                bars.forEach((b, i) => ctx.fillRect(i * 2, centre - b[layer], 2, b[layer] * 2));
            });
            ctx.fillStyle = "#a1a1a1";
            ctx.fillRect(0, centre - 0.5, w, 1);
        }
    }
}
