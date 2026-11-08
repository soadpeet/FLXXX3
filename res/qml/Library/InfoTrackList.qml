import ".." as Skin
import "." as LibraryComponent
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.15

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// List of tracks that the app stores itself (TAG LIST, HISTORY, MY LISTS): an
// array of maps { url, title, artist, key, bpm, duration }. A tap selects a row,
// a long press opens the track menu (load to a deck, tag). In the TAG LIST rows
// can be checked.
Rectangle {
    id: root

    property var entries: []
    property var store: null
    property real uiScale: 1.0
    property bool scrollEnabled: true
    property bool checkable: false
    // url -> true for the checked rows (TAG LIST)
    property var checked: ({})
    property int selectedIndex: -1
    property var formatKey: function(text) { return text; }
    readonly property int count: root.entries ? root.entries.length : 0

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const total = Math.round(seconds);
        const sec = total % 60;
        return Math.floor(total / 60) + ":" + (sec < 10 ? "0" : "") + sec;
    }
    function setAllChecked(on) {
        const map = {};
        if (on) {
            root.entries.forEach(e => map[String(e.url)] = true);
        }
        root.checked = map;
    }
    function checkedUrls() {
        return root.entries.filter(e => root.checked[String(e.url)]).map(e => e.url);
    }
    function loadSelected(group) {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.count)
            return;
        Mixxx.PlayerManager.getPlayer(group).loadTrackFromLocationUrl(root.entries[root.selectedIndex].url, false);
    }

    color: "#101010"
    onEntriesChanged: root.selectedIndex = -1

    // The BROWSE knob and the LOAD buttons of the controller act on this list while it is shown.
    LibraryComponent.Control {
        onLoadSelectedTrack: (group, play) => {
            if (root.visible && root.scrollEnabled)
                root.loadSelected(group);
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            if (!root.visible || !root.scrollEnabled || root.selectedIndex < 0)
                return;
            Mixxx.PlayerManager.loadLocationUrlIntoNextAvailableDeck(root.entries[root.selectedIndex].url, false);
        }
        onMoveVertical: offset => {
            if (!root.visible || !root.scrollEnabled || root.count === 0)
                return;
            root.selectedIndex = Math.max(0, Math.min(root.count - 1, root.selectedIndex + offset));
            list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }
    Mixxx.ControlProxy { id: play1; group: "[Channel1]"; key: "play" }
    Mixxx.ControlProxy { id: play2; group: "[Channel2]"; key: "play" }

    property int menuIndex: -1
    property bool menuLock1: false
    property bool menuLock2: false
    function openMenu(index) {
        root.menuIndex = index;
        const lock = Mixxx.Config.androidSetting("loadLock", "1") === "1";
        root.menuLock1 = lock && play1.value > 0;
        root.menuLock2 = lock && play2.value > 0;
        menu.open();
    }

    Text {
        anchors.centerIn: parent
        color: "#6a6a6a"
        font.pixelSize: Math.round(20 * root.uiScale)
        text: "No tracks"
        visible: root.count === 0
    }
    ListView {
        id: list

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.count

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOn
        }

        delegate: Rectangle {
            id: row

            required property int index
            readonly property var entry: root.entries[index]
            readonly property bool isChecked: !!root.checked[String(entry.url)]
            readonly property bool tagged: root.store ? (root.store.version >= 0 && root.store.isTagged(entry.url)) : false

            color: root.selectedIndex === index ? "#17324d" : (index % 2 === 0 ? "#141414" : "#1a1a1a")
            height: Math.round(56 * root.uiScale)
            width: ListView.view.width

            Rectangle {
                id: box

                border.color: "#8a8a8a"
                color: row.isChecked ? "#1f8fe0" : "transparent"
                height: Math.round(28 * root.uiScale)
                visible: root.checkable
                width: height

                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(20 * root.uiScale)
                    text: "✓"
                    visible: row.isChecked
                }
            }
            Column {
                anchors {
                    left: root.checkable ? box.right : parent.left
                    leftMargin: 14
                    right: keyText.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    color: "#ffffff"
                    elide: Text.ElideRight
                    font.pixelSize: Math.round(20 * root.uiScale)
                    text: row.entry.title ? row.entry.title : ""
                    width: parent.width
                }
                Text {
                    color: "#9a9a9a"
                    elide: Text.ElideRight
                    font.pixelSize: Math.round(15 * root.uiScale)
                    text: row.entry.artist ? row.entry.artist : ""
                    width: parent.width
                }
            }
            Text {
                id: keyText

                color: "#7fd18a"
                font.pixelSize: Math.round(18 * root.uiScale)
                horizontalAlignment: Text.AlignRight
                text: root.formatKey(row.entry.key ? row.entry.key : "")
                width: Math.round(60 * root.uiScale)

                anchors {
                    right: bpmText.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
            }
            Text {
                id: bpmText

                color: "#ffffff"
                font.pixelSize: Math.round(18 * root.uiScale)
                horizontalAlignment: Text.AlignRight
                text: row.entry.bpm > 0 ? row.entry.bpm.toFixed(1) : ""
                width: Math.round(64 * root.uiScale)

                anchors {
                    right: timeText.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
            }
            Text {
                id: timeText

                color: "#8a8a8a"
                font.pixelSize: Math.round(17 * root.uiScale)
                horizontalAlignment: Text.AlignRight
                text: root.formatTime(row.entry.duration)
                width: Math.round(52 * root.uiScale)

                anchors {
                    right: tagMark.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
            }
            Text {
                id: tagMark

                color: "#ffb020"
                font.pixelSize: Math.round(20 * root.uiScale)
                horizontalAlignment: Text.AlignHCenter
                text: row.tagged ? "★" : ""
                width: Math.round(30 * root.uiScale)

                anchors {
                    right: parent.right
                    rightMargin: 24
                    verticalCenter: parent.verticalCenter
                }
            }
            TapHandler {
                longPressThreshold: 0.5

                onLongPressed: {
                    root.selectedIndex = row.index;
                    root.openMenu(row.index);
                }
                onTapped: {
                    root.selectedIndex = row.index;
                    if (root.checkable) {
                        const map = Object.assign({}, root.checked);
                        const key = String(row.entry.url);
                        if (map[key])
                            delete map[key];
                        else
                            map[key] = true;
                        root.checked = map;
                    }
                }
            }
        }
    }

    Popup {
        id: menu

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        height: 450
        modal: true
        width: 520

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            anchors.fill: parent
            spacing: 14

            Text {
                color: "#ffffff"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: 22
                text: root.menuIndex >= 0 && root.menuIndex < root.count ? root.entries[root.menuIndex].title : ""
                width: parent.width
            }
            Text {
                color: "#9a9a9a"
                elide: Text.ElideRight
                font.pixelSize: 16
                text: root.menuIndex >= 0 && root.menuIndex < root.count ? root.entries[root.menuIndex].artist : ""
                width: parent.width
            }
            Repeater {
                model: [
                    { label: "LOAD TO DECK 1", deck: 1 },
                    { label: "LOAD TO DECK 2", deck: 2 }
                ]

                Rectangle {
                    id: loadButton

                    required property var modelData
                    readonly property bool locked: modelData.deck === 1 ? root.menuLock1 : root.menuLock2

                    border.color: "#5a5a5a"
                    color: locked ? "#202020" : (loadTap.pressed ? "#1f8fe0" : "#1f6fe0")
                    height: 64
                    width: parent.width

                    Text {
                        anchors.centerIn: parent
                        color: loadButton.locked ? "#6a6a6a" : "#ffffff"
                        font.bold: true
                        font.pixelSize: 22
                        text: loadButton.modelData.label + (loadButton.locked ? "  (PLAYING)" : "")
                    }
                    TapHandler {
                        id: loadTap

                        enabled: !loadButton.locked

                        onTapped: {
                            menu.close();
                            Mixxx.PlayerManager.getPlayer("[Channel" + loadButton.modelData.deck + "]")
                                    .loadTrackFromLocationUrl(root.entries[root.menuIndex].url, false);
                        }
                    }
                }
            }
            Rectangle {
                border.color: "#5a5a5a"
                color: tagTap.pressed ? "#3a3a3a" : "#202020"
                height: 56
                visible: !!root.store
                width: parent.width

                Text {
                    anchors.centerIn: parent
                    color: "#ffb020"
                    font.bold: true
                    font.pixelSize: 20
                    text: root.store && root.menuIndex >= 0 && root.menuIndex < root.count
                            && root.store.version >= 0 && root.store.isTagged(root.entries[root.menuIndex].url)
                            ? "REMOVE TAG" : "TAG"
                }
                TapHandler {
                    id: tagTap

                    onTapped: {
                        root.store.toggleTag(root.entries[root.menuIndex]);
                        menu.close();
                    }
                }
            }
            Rectangle {
                border.color: "#5a5a5a"
                color: "#202020"
                height: 56
                width: parent.width

                Text {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.pixelSize: 20
                    text: "CANCEL"
                }
                TapHandler {
                    onTapped: menu.close()
                }
            }
        }
    }
}
