import "../" as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// SOURCE screen (modelled on the XDJ-RX3): the devices on the left (USB 1,
// USB 2, TABLET), INFO about the selected device on the right. The own music
// folders of the tablet are managed here (ADD FOLDER / REMOVE). OPEN chooses the
// device as the source of BROWSE, PLAYLIST and SEARCH.
Rectangle {
    id: root

    // 0 = USB 1, 1 = USB 2, 2 = TABLET
    // Blocks touches for the main window below (BEAT FX etc.).
    MouseArea {
        acceptedButtons: Qt.AllButtons
        anchors.fill: parent
        preventStealing: true
        onWheel: wheel => wheel.accepted = true
    }
    property int selected: 0
    // Source that BROWSE shows (set by the main window): "", "USB1", "USB2" or "TABLET".
    property string chosenSource: ""
    // The sizes below are made for the tablet (about 540 high): smaller screens (phones)
    // get the whole screen scaled down, so that nothing is cut off.
    readonly property real s: Math.max(0.5, Math.min(1.0, root.height / 540, root.width / 480))
    property var info: ({ present: false })
    property var folders: []
    property string pickerPath: ""
    // Root of the device's own storage (Android: internal storage, Windows: the user folder)
    // and its name (TABLET / PC), from the platform layer.
    readonly property var ownStorage: Mixxx.DeviceStatus.tabletInfo()
    property var pickerFolders: []
    property string pickerMessage: ""
    property string removePath: ""
    // Folders switched on for this session (all off after every start: the
    // sticks are the main source).
    property var activeFolders: ({})
    readonly property bool anyFolderActive: Object.keys(root.activeFolders).length > 0

    function toggleFolder(path) {
        const copy = Object.assign({}, root.activeFolders);
        if (copy[path])
            delete copy[path];
        else
            copy[path] = true;
        root.activeFolders = copy;
    }

    // OPEN: kind is "USB1", "USB2" or "TABLET".
    signal openRequested(string kind, string title)

    // FLX4: BROWSE knob turned / pressed while SOURCE is shown.
    function step(delta) {
        root.selected = ((root.selected + delta) % 3 + 3) % 3;
    }
    function openSelected() {
        if (root.selected !== 2 || root.anyFolderActive)
            root.openRequested(root.kindOf(root.selected), root.slotTitle(root.selected));
    }

    function kindOf(slot) {
        return slot === 2 ? "TABLET" : "USB" + (slot + 1);
    }

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0)
            return "-";
        const gb = bytes / (1024 * 1024 * 1024);
        return gb >= 100 ? Math.round(gb) + " GB" : gb.toFixed(1) + " GB";
    }
    function refresh() {
        root.info = root.selected === 2
                ? Mixxx.DeviceStatus.tabletInfo()
                : Mixxx.DeviceStatus.stickInfo(root.selected + 1);
        root.folders = Mixxx.Library.libraryDirectories();
    }
    function slotLabel(slot) {
        if (slot === 2)
            return root.ownStorage.name;
        return "USB " + (slot + 1);
    }
    // Name of the device: the label of the stick (e.g. BIGGO 2), else USB 1 / 2.
    function slotTitle(slot) {
        if (slot === 2)
            return root.ownStorage.name;
        const present = slot === 0 ? Mixxx.DeviceStatus.stick1Present : Mixxx.DeviceStatus.stick2Present;
        if (present) {
            const details = Mixxx.DeviceStatus.stickInfo(slot + 1);
            if (details.label)
                return details.label;
        }
        return "USB " + (slot + 1);
    }
    function slotSubtitle(slot) {
        if (slot === 2)
            return root.ownStorage.name === "PC" ? "This computer" : "Internal storage";
        const present = slot === 0 ? Mixxx.DeviceStatus.stick1Present : Mixxx.DeviceStatus.stick2Present;
        return present ? "USB " + (slot + 1) : "NO DEVICE";
    }
    function enterPicker(name) {
        root.pickerPath = root.pickerPath + "/" + name;
        root.pickerFolders = Mixxx.DeviceStatus.subDirectories(root.pickerPath);
        root.pickerMessage = "";
    }
    function pickerUp() {
        if (root.pickerPath === root.ownStorage.path)
            return;
        const cut = root.pickerPath.lastIndexOf("/");
        root.pickerPath = cut > 0 ? root.pickerPath.substring(0, cut) : root.ownStorage.path;
        root.pickerFolders = Mixxx.DeviceStatus.subDirectories(root.pickerPath);
        root.pickerMessage = "";
    }
    function openPicker() {
        root.pickerPath = root.ownStorage.path;
        root.pickerFolders = Mixxx.DeviceStatus.subDirectories(root.pickerPath);
        root.pickerMessage = "";
        folderPicker.open();
    }
    function addCurrentFolder() {
        // Result codes of the library: 0 = ok
        // file:// + /storage/... on Android, file:/// + C:/... on Windows.
        const result = Mixxx.Library.addSource(
                (root.pickerPath.startsWith("/") ? "file://" : "file:///") + root.pickerPath);
        if (result === 0) {
            Mixxx.Library.rescanLibrary();
            folderPicker.close();
            root.refresh();
        } else if (result === 1) {
            root.pickerMessage = "This folder is already in the library.";
        } else {
            root.pickerMessage = "This folder cannot be added.";
        }
    }

    color: "#101010"
    onSelectedChanged: refresh()
    onVisibleChanged: {
        if (visible) {
            // Show the device that is the source now.
            const slot = ["USB1", "USB2", "TABLET"].indexOf(root.chosenSource);
            if (slot >= 0)
                root.selected = slot;
            refresh();
        }
    }

    Connections {
        function onChanged() {
            if (root.visible)
                root.refresh();
        }

        target: Mixxx.DeviceStatus
    }

    // Everything except the popups, scaled down on small screens.
    Item {
        id: page

        height: root.height / root.s
        scale: root.s
        transformOrigin: Item.TopLeft
        width: root.width / root.s

    // ---- Devices ----
    Column {
        id: deviceColumn

        spacing: 8
        width: page.width * 0.38

        anchors {
            left: parent.left
            leftMargin: 14
            top: parent.top
            topMargin: 14
        }

        Text {
            color: "#ffffff"
            font.bold: true
            font.pixelSize: 26
            text: "SOURCE"
        }
        Repeater {
            model: 3

            Rectangle {
                id: deviceRow

                required property int index
                readonly property bool present: index === 2 ||
                        (index === 0 ? Mixxx.DeviceStatus.stick1Present : Mixxx.DeviceStatus.stick2Present)

                border.color: root.selected === index ? "#1fb0f0" : "#3a3a3a"
                border.width: root.selected === index ? 3 : 1
                color: root.selected === index ? "#10293f" : "#1a1a1a"
                height: 92
                width: parent.width

                // device icon: a small drive
                Rectangle {
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    border.color: deviceRow.present ? "#ffffff" : "#5a5a5a"
                    border.width: 2
                    color: deviceRow.index === 2 ? "#1f6fe0" : (deviceRow.present ? "#27a8e0" : "transparent")
                    height: 44
                    radius: 4
                    width: 60

                    Text {
                        anchors.centerIn: parent
                        color: "#000000"
                        font.bold: true
                        font.pixelSize: 18
                        text: deviceRow.index === 2 ? "T" : "USB"
                    }
                }
                // The device that BROWSE shows now.
                Rectangle {
                    color: "#ff9a2e"
                    height: 22
                    visible: root.chosenSource === root.kindOf(deviceRow.index)
                    width: inUseText.implicitWidth + 12

                    anchors {
                        right: parent.right
                        rightMargin: 8
                        top: parent.top
                        topMargin: 8
                    }

                    Text {
                        id: inUseText

                        anchors.centerIn: parent
                        color: "#000000"
                        font.bold: true
                        font.pixelSize: 13
                        text: "SOURCE"
                    }
                }
                Column {
                    anchors {
                        left: parent.left
                        leftMargin: 98
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                    Text {
                        color: deviceRow.present ? "#ffffff" : "#6a6a6a"
                        font.bold: true
                        font.pixelSize: 24
                        text: root.slotTitle(deviceRow.index)
                    }
                    Text {
                        color: deviceRow.present ? "#9a9a9a" : "#6a6a6a"
                        elide: Text.ElideRight
                        font.pixelSize: 17
                        text: root.slotSubtitle(deviceRow.index)
                        width: parent.width
                    }
                }
                TapHandler {
                    gesturePolicy: TapHandler.WithinBounds

                    onTapped: root.selected = deviceRow.index
                }
            }
        }
    }

    // ---- INFO ----
    Rectangle {
        id: infoPanel

        // Width of the two buttons at the bottom (both fit next to each other).
        readonly property real buttonWidth: Math.min(220, Math.floor((width - 2 * 14 - 12) / 2))

        border.color: "#3a3a3a"
        color: "#141414"

        anchors {
            bottom: parent.bottom
            bottomMargin: 14
            left: deviceColumn.right
            leftMargin: 14
            right: parent.right
            rightMargin: 14
            top: parent.top
            topMargin: 14
        }

        Text {
            id: infoTitle

            color: "#8a8a8a"
            font.bold: true
            font.pixelSize: 20
            text: "INFO"

            anchors {
                left: parent.left
                leftMargin: 14
                top: parent.top
                topMargin: 10
            }
        }
        // Nothing connected.
        Text {
            anchors.centerIn: parent
            color: "#6a6a6a"
            font.bold: true
            font.pixelSize: 30
            text: "NO DEVICE"
            visible: !root.info.present
        }
        Column {
            spacing: 10
            visible: root.info.present

            anchors {
                left: parent.left
                leftMargin: 14
                right: parent.right
                rightMargin: 14
                top: infoTitle.bottom
                topMargin: 10
            }

            Text {
                color: "#ffffff"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: 26
                text: root.info.label ? root.info.label : root.slotTitle(root.selected)
                width: parent.width
            }
            Text {
                color: "#9a9a9a"
                elide: Text.ElideMiddle
                font.pixelSize: 16
                text: root.info.path ? root.info.path : ""
                width: parent.width
            }
            // Capacity
            Rectangle {
                border.color: "#4a4a4a"
                color: "#101010"
                height: 14
                width: parent.width

                Rectangle {
                    color: "#27a8e0"
                    height: parent.height
                    width: root.info.total > 0 ? parent.width * (1 - root.info.free / root.info.total) : 0
                }
            }
            Text {
                color: "#cfcfcf"
                font.pixelSize: 17
                text: root.formatBytes(root.info.free) + " free of " + root.formatBytes(root.info.total)
            }
            Text {
                color: "#8a8a8a"
                font.pixelSize: 16
                text: "OPEN makes this stick the source: BROWSE, PLAYLIST and SEARCH show its tracks."
                visible: root.selected !== 2
                width: parent.width
                wrapMode: Text.WordWrap
            }
            // Own music folders of the tablet.
            Text {
                color: "#8a8a8a"
                font.bold: true
                font.pixelSize: 18
                text: "MUSIC FOLDERS"
                visible: root.selected === 2
            }
            Repeater {
                model: root.selected === 2 ? root.folders : []

                Rectangle {
                    id: folderRow

                    required property var modelData

                    border.color: "#3a3a3a"
                    color: "#1a1a1a"
                    height: 46
                    width: parent.width

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            right: activeButton.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        color: root.activeFolders[folderRow.modelData.path] ? "#ffffff" : "#8a8a8a"
                        elide: Text.ElideMiddle
                        font.pixelSize: 16
                        text: folderRow.modelData.path + "  (" + folderRow.modelData.trackCount + ")"
                    }
                    Rectangle {
                        id: activeButton

                        readonly property bool on: root.activeFolders[folderRow.modelData.path] === true

                        border.color: on ? "#1fb0f0" : "#5a5a5a"
                        color: on ? "#1f6fe0" : "#202020"
                        height: 34
                        width: 100

                        anchors {
                            right: removeButton.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            anchors.centerIn: parent
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 15
                            text: activeButton.on ? "ACTIVE" : "OFF"
                        }
                        TapHandler {
                            onTapped: root.toggleFolder(folderRow.modelData.path)
                        }
                    }
                    Rectangle {
                        id: removeButton

                        border.color: "#8a3a3a"
                        color: removeTap.pressed ? "#5a2a2a" : "#2a1a1a"
                        height: 34
                        width: 90

                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            anchors.centerIn: parent
                            color: "#ffffff"
                            font.pixelSize: 15
                            text: "REMOVE"
                        }
                        TapHandler {
                            id: removeTap

                            onTapped: {
                                root.removePath = folderRow.modelData.path;
                                confirmRemove.open();
                            }
                        }
                    }
                }
            }
        }
        // Buttons at the bottom of the INFO panel.
        Row {
            spacing: 12
            visible: root.info.present

            anchors {
                bottom: parent.bottom
                bottomMargin: 14
                horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                border.color: "#1f8fe0"
                border.width: 2
                color: addTap.pressed ? "#10293f" : "#141414"
                height: 56
                visible: root.selected === 2
                width: infoPanel.buttonWidth

                Text {
                    anchors.centerIn: parent
                    color: "#1fb0f0"
                    font.bold: true
                    font.pixelSize: Math.min(20, Math.floor(infoPanel.buttonWidth / 8))
                    text: "ADD FOLDER"
                }
                TapHandler {
                    id: addTap

                    onTapped: root.openPicker()
                }
            }
            Rectangle {
                readonly property bool usable: root.selected !== 2 || root.anyFolderActive

                border.color: "#5a5a5a"
                color: usable ? (openTap.pressed ? "#1f8fe0" : "#1f6fe0") : "#202020"
                height: 56
                width: infoPanel.buttonWidth

                Text {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.min(20, Math.floor(infoPanel.buttonWidth / 8))
                    text: "OPEN"
                }
                TapHandler {
                    id: openTap

                    enabled: parent.usable
                    onTapped: root.openRequested(root.kindOf(root.selected), root.slotTitle(root.selected))
                }
            }
        }
    }

    }

    // ---- Folder picker ----
    Skin.FitPopup {
        id: folderPicker

        closePolicy: Popup.CloseOnEscape
        designHeight: 500
        modal: true
        designWidth: 720

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            anchors.fill: parent
            spacing: 10

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 22
                text: "Choose a music folder"
            }
            Text {
                color: "#1fb0f0"
                elide: Text.ElideMiddle
                font.pixelSize: 17
                text: root.pickerPath
                width: parent.width
            }
            ListView {
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                clip: true
                flickDeceleration: 2500
                height: 340
                maximumFlickVelocity: 6000
                width: parent.width

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                }

                header: Rectangle {
                    border.color: "#3a3a3a"
                    color: "#1a1a1a"
                    height: 46
                    width: ListView.view.width

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        color: "#9a9a9a"
                        font.pixelSize: 18
                        text: "↑  .."
                    }
                    TapHandler {
                        onTapped: root.pickerUp()
                    }
                }
                model: root.pickerFolders

                delegate: Rectangle {
                    required property string modelData

                    border.color: "#2a2a2a"
                    color: "#141414"
                    height: 46
                    width: ListView.view.width

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            right: parent.right
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        color: "#ffffff"
                        elide: Text.ElideRight
                        font.pixelSize: 18
                        text: parent.modelData
                    }
                    TapHandler {
                        onTapped: root.enterPicker(parent.modelData)
                    }
                }
            }
            Text {
                color: "#ff8a6a"
                font.pixelSize: 16
                text: root.pickerMessage
                visible: root.pickerMessage.length > 0
            }
            Row {
                spacing: 12

                Rectangle {
                    color: "#1f6fe0"
                    height: 50
                    width: 280

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 18
                        text: "SELECT THIS FOLDER"
                    }
                    TapHandler {
                        onTapped: root.addCurrentFolder()
                    }
                }
                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#202020"
                    height: 50
                    width: 160

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.pixelSize: 18
                        text: "CANCEL"
                    }
                    TapHandler {
                        onTapped: folderPicker.close()
                    }
                }
            }
        }
    }

    // ---- Confirm removing a folder ----
    Skin.FitPopup {
        id: confirmRemove

        closePolicy: Popup.CloseOnEscape
        designHeight: 230
        modal: true
        designWidth: 560

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            anchors.fill: parent
            spacing: 14

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 22
                text: "Remove this folder?"
            }
            Text {
                color: "#cfcfcf"
                elide: Text.ElideMiddle
                font.pixelSize: 16
                text: root.removePath
                width: parent.width
            }
            Text {
                color: "#9a9a9a"
                font.pixelSize: 15
                text: "Its tracks disappear from the library. The files stay on the tablet."
                width: parent.width
                wrapMode: Text.WordWrap
            }
            Row {
                spacing: 12

                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#c0392b"
                    height: 50
                    width: 160

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 18
                        text: "REMOVE"
                    }
                    TapHandler {
                        onTapped: {
                            Mixxx.Library.removeLibraryDirectory(root.removePath);
                            confirmRemove.close();
                            root.refresh();
                        }
                    }
                }
                Rectangle {
                    border.color: "#5a5a5a"
                    color: "#202020"
                    height: 50
                    width: 160

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.pixelSize: 18
                        text: "CANCEL"
                    }
                    TapHandler {
                        onTapped: confirmRemove.close()
                    }
                }
            }
        }
    }
}
