import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// SOURCE screen (modelled on the XDJ-RX3): the devices on the left (USB 1,
// USB 2, TABLET), INFO about the selected device on the right. The own music
// folders of the tablet are managed here (ADD FOLDER / REMOVE).
Rectangle {
    id: root

    // 0 = USB 1, 1 = USB 2, 2 = TABLET
    property int selected: 0
    property var info: ({ present: false })
    property var folders: []
    property string pickerPath: "/storage/emulated/0"
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

    signal openRequested(string kind, string title)
    // A stick was selected: the sticks are the shown source again.
    signal sticksSelected()

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0)
            return "-";
        const gb = bytes / (1024 * 1024 * 1024);
        return gb >= 100 ? Math.round(gb) + " GB" : gb.toFixed(1) + " GB";
    }
    function refresh() {
        root.info = root.selected === 2
                ? Mixxx.AndroidStatus.tabletInfo()
                : Mixxx.AndroidStatus.stickInfo(root.selected + 1);
        root.folders = Mixxx.Library.libraryDirectories();
    }
    function slotLabel(slot) {
        if (slot === 2)
            return "TABLET";
        return "USB " + (slot + 1);
    }
    // Name of the device: the label of the stick (e.g. BIGGO 2), else USB 1 / 2.
    function slotTitle(slot) {
        if (slot === 2)
            return "TABLET";
        const present = slot === 0 ? Mixxx.AndroidStatus.stick1Present : Mixxx.AndroidStatus.stick2Present;
        if (present) {
            const details = Mixxx.AndroidStatus.stickInfo(slot + 1);
            if (details.label)
                return details.label;
        }
        return "USB " + (slot + 1);
    }
    function slotSubtitle(slot) {
        if (slot === 2)
            return "Internal storage";
        const present = slot === 0 ? Mixxx.AndroidStatus.stick1Present : Mixxx.AndroidStatus.stick2Present;
        return present ? "USB " + (slot + 1) : "NO DEVICE";
    }
    function enterPicker(name) {
        root.pickerPath = root.pickerPath + "/" + name;
        root.pickerFolders = Mixxx.AndroidStatus.subDirectories(root.pickerPath);
        root.pickerMessage = "";
    }
    function pickerUp() {
        if (root.pickerPath === "/storage/emulated/0" || root.pickerPath === "/storage")
            return;
        const cut = root.pickerPath.lastIndexOf("/");
        root.pickerPath = cut > 0 ? root.pickerPath.substring(0, cut) : "/storage/emulated/0";
        root.pickerFolders = Mixxx.AndroidStatus.subDirectories(root.pickerPath);
        root.pickerMessage = "";
    }
    function openPicker() {
        root.pickerPath = "/storage/emulated/0";
        root.pickerFolders = Mixxx.AndroidStatus.subDirectories(root.pickerPath);
        root.pickerMessage = "";
        folderPicker.open();
    }
    function addCurrentFolder() {
        // Result codes of the library: 0 = ok
        const result = Mixxx.Library.addSource("file://" + root.pickerPath);
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
    onVisibleChanged: if (visible) refresh()

    Connections {
        function onChanged() {
            if (root.visible)
                root.refresh();
        }

        target: Mixxx.AndroidStatus
    }

    // ---- Devices ----
    Column {
        id: deviceColumn

        spacing: 8
        width: root.width * 0.38

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
                        (index === 0 ? Mixxx.AndroidStatus.stick1Present : Mixxx.AndroidStatus.stick2Present)

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

                    onTapped: {
                        root.selected = deviceRow.index;
                        if (deviceRow.index !== 2)
                            root.sticksSelected();
                    }
                }
            }
        }
    }

    // ---- INFO ----
    Rectangle {
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
                text: "The tracks of this stick are read automatically and shown in BROWSE."
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
                width: 220

                Text {
                    anchors.centerIn: parent
                    color: "#1fb0f0"
                    font.bold: true
                    font.pixelSize: 20
                    text: "ADD FOLDER"
                }
                TapHandler {
                    id: addTap

                    onTapped: root.openPicker()
                }
            }
            Rectangle {
                border.color: "#5a5a5a"
                color: root.anyFolderActive ? (openTap.pressed ? "#1f8fe0" : "#1f6fe0") : "#202020"
                height: 56
                visible: root.selected === 2
                width: 220

                Text {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: 20
                    text: "OPEN"
                }
                TapHandler {
                    id: openTap

                    enabled: root.anyFolderActive
                    onTapped: root.openRequested("TABLET", root.slotTitle(2))
                }
            }
        }
    }

    // ---- Folder picker ----
    Popup {
        id: folderPicker

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape
        height: 560
        modal: true
        width: 720

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
    Popup {
        id: confirmRemove

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape
        height: 230
        modal: true
        width: 560

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
