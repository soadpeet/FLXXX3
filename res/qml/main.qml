import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Window 2.12
import "Theme"
import "AndroidDJ" as AndroidDJ

ApplicationWindow {
    id: root

    readonly property bool isMobile: Qt.platform.os === "android" || Qt.platform.os === "ios"
    readonly property int designWidth: 1792
    readonly property int designHeight: 1008

    color: Theme.backgroundColor
    height: isMobile ? Screen.height : designHeight
    menuBar: content.item ? content.item.menuBar : null
    // The FLXXX3 interface on the desktop needs room for two decks side by side.
    minimumHeight: isMobile ? 0 : (Mixxx.Product.ui ? 560 : 300)
    minimumWidth: isMobile ? 0 : (Mixxx.Product.ui ? 960 : 680)
    visible: true
    width: isMobile ? Screen.width : designWidth

    function updateVisibility() {
        if (!Mixxx.Core.ready) {
            return;
        }
        // FLXXX3 on Android: the activity is full screen from its start (MainActivity.onCreate).
        // Switching the window to full screen here, about 5 s after the start while Qt was
        // drawing, laid the Android window out again, which crashed the app now and then in the
        // system graphics (libgui / RenderThread), mostly at the first start after an installation.
        if (isMobile && Mixxx.Product.ui) {
            return;
        }
        // FLXXX3 starts full screen everywhere (desktop: F11 switches to a maximized window).
        root.visibility = Mixxx.Config.configStartInFullscreenKey || isMobile || Mixxx.Product.ui
                ? Window.FullScreen
                : Window.Windowed;
    }
    // FLXXX3 on the desktop: F11 switches between full screen and a maximized window.
    Shortcut {
        enabled: Mixxx.Product.ui && !root.isMobile
        sequence: "F11"
        onActivated: root.visibility = root.visibility === Window.FullScreen ? Window.Maximized : Window.FullScreen
    }

    Connections {
        target: Mixxx.Core
        function onReadyChanged() {
            root.updateVisibility();
        }
    }

    Component.onCompleted: root.updateVisibility()

    Loader {
        id: content

        anchors.fill: parent

        active: Mixxx.Core.ready
        asynchronous: true
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load the Mixxx main window")
                Qt.quit()
            }
        }
        // FLXXX3 (Android and Windows) uses the single-view touch UI (res/qml/AndroidDJ).
        sourceComponent: Mixxx.Product.ui ? androidMainWindow : desktopMainWindow
        Component {
            id: desktopMainWindow

            MainWindow {
                applicationWindow: root
            }
        }
        Component {
            id: androidMainWindow

            AndroidDJ.MainWindow {
                applicationWindow: root
            }
        }
    }
    Rectangle {
        id: splash
        visible: opacity > 0
        color: Mixxx.Product.ui ? "#0b0f14" : Theme.backgroundColor
        anchors.fill: parent

        property bool ready: false

        Component.onCompleted: {
            ready = true
        }

        states: [
            State {
                when: splash.ready && content.status != Loader.Ready

                PropertyChanges {
                    text.opacity: 1
                    logo.opacity: 1
                    logo.y: root.height / 2 - logo.height / 2
                }
            },
            State {
                when: content.status == Loader.Ready && content.active

                PropertyChanges {
                    splash.opacity: 0
                }
            }
        ]
        // FLXXX3: the name instead of the Mixxx logo.
        Row {
            anchors.centerIn: parent
            visible: Mixxx.Product.ui

            Text {
                color: "#ffffff"
                font.bold: true
                font.letterSpacing: 4
                font.pixelSize: Math.round(root.height * 0.14)
                text: "FL"
            }
            Text {
                color: "#27a8e0"
                font.bold: true
                font.letterSpacing: 4
                font.pixelSize: Math.round(root.height * 0.14)
                text: "XXX"
            }
            Text {
                color: "#ffffff"
                font.bold: true
                font.letterSpacing: 4
                font.pixelSize: Math.round(root.height * 0.14)
                text: "3"
            }
        }
        Image {
            id: logo
            visible: !Mixxx.Product.ui
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/images/mixxx-icon-logo-symbolic.svg"
            // height: 64
            opacity: 0
            y: root.height / 2

            Behavior on opacity {
                NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad }
            }

            Behavior on y {
                NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad }
            }
        }
        Text {
            id: text
            visible: !Mixxx.Product.ui
            opacity: 0
            y: logo.y + logo.height*2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 20
            font.pixelSize: 12
            color: Theme.lightGray3
            text: "DJ your way"
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 1000 }
                    NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
        }
    }
}
