import "../" as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// A folder chooser (popup): starts in the own storage of the device (or `startPath`),
// goes into sub folders by tap, UP goes one level up. SELECT THIS FOLDER emits chosen(path).
Item {
    id: root

    property string title: "Choose a folder"
    property string path: ""
    property var folders: []
    readonly property var ownStorage: Mixxx.DeviceStatus.tabletInfo()

    signal chosen(string path)

    function openAt(startPath) {
        root.path = startPath && startPath !== "" ? startPath : root.ownStorage.path;
        root.folders = Mixxx.DeviceStatus.subDirectories(root.path);
        popup.open();
    }
    function enter(name) {
        root.path = root.path + "/" + name;
        root.folders = Mixxx.DeviceStatus.subDirectories(root.path);
    }
    function up() {
        const cut = root.path.lastIndexOf("/");
        if (cut <= 0 || root.path === root.ownStorage.path)
            return;
        root.path = root.path.substring(0, cut);
        root.folders = Mixxx.DeviceStatus.subDirectories(root.path);
    }

    Skin.FitPopup {
        id: popup

        closePolicy: Popup.CloseOnEscape
        designHeight: 500
        designWidth: 720
        modal: true

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
                text: root.title
            }
            Text {
                color: "#1fb0f0"
                elide: Text.ElideMiddle
                font.pixelSize: 17
                text: root.path
                width: parent.width
            }
            ListView {
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                flickDeceleration: 2500
                flickableDirection: Flickable.VerticalFlick
                height: 340
                maximumFlickVelocity: 6000
                model: root.folders
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
                        text: "UP  .."
                    }
                    TapHandler {
                        onTapped: root.up()
                    }
                }
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
                        onTapped: root.enter(parent.modelData)
                    }
                }
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
                        onTapped: {
                            root.chosen(root.path);
                            popup.close();
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
                        onTapped: popup.close()
                    }
                }
            }
        }
    }
}
