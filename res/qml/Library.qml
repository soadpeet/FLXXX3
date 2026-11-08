import "." as Skin
import Mixxx 1.0 as Mixxx
import Qt.labs.qmlmodels
import QtQml
import QtQuick
import QtQml.Models
import QtQuick.Layouts
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.6
import "Theme"
import "Library" as LibraryComponent

Item {
    id: root

    property var sidebar: librarySources.sidebar()
    // Key notation of the UTILITY menu (set by the main window).
    property bool keyCamelot: true
    // False while the library is closed (set by the main window).
    property bool scrollEnabled: true

    // Android edition (BROWSE screen like the XDJ-RX3): name of the shown source
    // (stick or tablet), set by the main window.
    property string sourceTitle: ""
    readonly property bool touchUi: Qt.platform.os === "android"
    // Android edition: shown screen (BROWSE, PLAYLIST, SEARCH, TAG LIST, set by the
    // main window) and the lists that the app keeps (tag list, history, my lists).
    property string mode: "BROWSE"
    readonly property var store: listStore

    LibraryComponent.ListStore {
        id: listStore
    }

    function applySearch() {
        if (!root.touchUi && root.sidebar && root.sidebar.tracklist) {
            root.sidebar.tracklist.search(desktopLoader.item ? desktopLoader.item.searchText : "");
        }
    }
    function focusSearch() {
        if (root.touchUi || !desktopLoader.item) {
            return;
        }
        root.applySearch();
        desktopLoader.item.focusSearchField();
    }
    // Back to the first level of the BROWSE screen (category TRACK).
    function resetBrowse() {
        if (browseLoader.item) {
            browseLoader.item.selectCategory("TRACK");
        }
    }

    // Android: the desktop Browser (which activates row 0 "All..." when it is
    // created) does not exist. The sticks (row 1, Rekordbox) are the main
    // source, so activate them here; the tablet folders only on demand.
    Component.onCompleted: {
        if (root.touchUi && root.sidebar) {
            root.sidebar.activate(root.sidebar.index(1, 0));
        }
    }

    LibraryComponent.SourceTree {
        id: librarySources
    }
    Loader {
        id: desktopLoader

        active: !root.touchUi
        anchors.fill: parent
        sourceComponent: desktopComponent
    }
    Loader {
        id: browseLoader

        active: root.touchUi
        anchors.fill: parent
        sourceComponent: browseComponent
    }
    Component {
        id: browseComponent

        LibraryComponent.BrowseScreen {
            library: root
        }
    }
    Component {
        id: desktopComponent

        Item {
            property alias searchText: searchField.text

            function focusSearchField() {
                searchField.forceActiveFocus(Qt.ShortcutFocusReason);
                searchField.selectAll();
            }

    TextField {
        id: searchField

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        placeholderText: qsTranslate("WSearchLineEdit", "Search...")

        onTextChanged: root.applySearch()
    }
    SplitView {
        id: librarySplitView

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchField.bottom
        orientation: Qt.Horizontal

        handle: Rectangle {
            id: handleDelegate

            property color handleColor: SplitHandle.pressed || SplitHandle.hovered ? Theme.panelSplitterHandleActive : Theme.panelSplitterHandle
            property int handleSize: SplitHandle.pressed || SplitHandle.hovered ? 6 : 5

            clip: true
            color: Theme.panelSplitterBackground
            implicitHeight: 8
            implicitWidth: 8

            containmentMask: Item {
                height: librarySplitView.height
                width: 8
                x: (handleDelegate.width - width) / 2
            }

            ColumnLayout {
                anchors.centerIn: parent

                Repeater {
                    model: 3

                    Rectangle {
                        color: handleColor
                        height: handleSize
                        radius: handleSize
                        width: handleSize
                    }
                }
            }
        }

        SplitView {
            id: sideBarSplitView

            SplitView.maximumWidth: 550
            SplitView.minimumWidth: Qt.platform.os === "android" ? 125 : 150
            // Narrow source list on the Android touch UI: more room for titles.
            SplitView.preferredWidth: root.width * (Qt.platform.os === "android" ? 0.14 : 0.15)
            orientation: Qt.Vertical

            handle: Rectangle {
                id: handleDelegate

                property color handleColor: SplitHandle.pressed || SplitHandle.hovered ? Theme.panelSplitterHandleActive : Theme.panelSplitterHandle
                property int handleSize: SplitHandle.pressed || SplitHandle.hovered ? 6 : 5

                clip: true
                color: Theme.panelSplitterBackground
                implicitHeight: 8
                implicitWidth: 8

                containmentMask: Item {
                    height: 8
                    width: sideBarSplitView.width
                    x: (handleDelegate.width - width) / 2
                }

                RowLayout {
                    anchors.centerIn: parent

                    Repeater {
                        model: 3

                        Rectangle {
                            color: handleColor
                            height: handleSize
                            radius: handleSize
                            width: handleSize
                        }
                    }
                }
            }

            LibraryComponent.Browser {
                SplitView.fillHeight: true
                SplitView.minimumHeight: 200
                SplitView.preferredHeight: 500
                model: root.sidebar
            }
            Skin.PreviewDeck {
                // Placeholder only; not shown in the Android touch UI.
                visible: Qt.platform.os !== "android"
                SplitView.maximumHeight: 200
                SplitView.minimumHeight: 100
                SplitView.preferredHeight: 100
            }
        }
        LibraryComponent.TrackList {
            SplitView.fillHeight: true

            // FIXME: this is necessary to prevent the header label to render outside of the table when horizontally scrolling: https://github.com/mixxxdj/mixxx/pull/14514#issuecomment-3311914346
            clip: true
            model: root.sidebar.tracklist
        }
    }
    }
    }
}
