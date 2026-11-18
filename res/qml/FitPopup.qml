import QtQuick 2.12
import QtQuick.Controls 2.12

// FLXXX3: a popup made for a fixed size (designWidth x designHeight, the tablet).
// On smaller screens (phones) the whole popup is scaled down so that it fits on the screen;
// the frame keeps its place in the middle, only the content inside is scaled.
// (Popup.scale cannot be used: the popup is then placed off the middle.)
Popup {
    id: root

    property real designWidth: 400
    property real designHeight: 300
    // Inner space around the content (like the padding of a normal popup).
    property real designPadding: 12
    readonly property real fit: Overlay.overlay
            ? Math.max(0.4, Math.min(1.0, (Overlay.overlay.width - 16) / designWidth,
                    (Overlay.overlay.height - 16) / designHeight))
            : 1.0
    default property alias content: inner.data

    anchors.centerIn: Overlay.overlay
    height: Math.round(designHeight * fit)
    padding: 0
    width: Math.round(designWidth * fit)

    contentItem: Item {
        Item {
            id: inner

            height: root.designHeight - 2 * root.designPadding
            scale: root.fit
            transformOrigin: Item.TopLeft
            width: root.designWidth - 2 * root.designPadding
            x: root.designPadding * root.fit
            y: root.designPadding * root.fit
        }
    }
}
