import ".." as Skin
import "." as LibraryComponent
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.15
import "../Theme"

// BROWSE screen for the touch UI (modelled on the XDJ-RX3): the categories on
// the left, in the middle the values of the category (artists, albums, keys,
// BPM) or the tracks, on the right the INFO of the selected track. Tapping the
// header goes one level back (like BACK on the player).
Rectangle {
    id: root

    // The Library item (gives the track list model of the current source).
    required property var library
    readonly property var tracklist: root.library.sidebar ? root.library.sidebar.tracklist : null

    property string category: "TRACK"
    property string drillValue: ""
    property var values: []
    property bool infoOpen: false
    readonly property var categories: ["TRACK", "ARTIST", "ALBUM", "KEY", "BPM"]
    // position of the category in the columns of the track list
    readonly property var categoryColumn: ({ ARTIST: 1, ALBUM: 2, BPM: 4, KEY: 5 })
    readonly property var categoryField: ({ ARTIST: "artist", ALBUM: "album", BPM: "bpm", KEY: "key" })
    readonly property bool showTracks: root.category === "TRACK" || root.drillValue !== ""
    readonly property int trackCount: root.tracklist ? root.tracklist.rowCount() : 0

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const total = Math.round(seconds);
        const sec = total % 60;
        return Math.floor(total / 60) + ":" + (sec < 10 ? "0" : "") + sec;
    }
    function selectCategory(name) {
        root.category = name;
        root.drillValue = "";
        if (root.tracklist) {
            root.tracklist.search("");
            root.values = root.categoryColumn[name] !== undefined
                    ? root.tracklist.distinctValues(root.categoryColumn[name]) : [];
        }
    }
    function drill(value) {
        root.drillValue = value;
        if (root.tracklist)
            root.tracklist.search(root.categoryField[root.category] + ":\"" + value + "\"");
    }
    function back() {
        if (root.drillValue !== "") {
            root.drillValue = "";
            if (root.tracklist)
                root.tracklist.search("");
        } else if (root.category !== "TRACK") {
            root.selectCategory("TRACK");
        }
    }
    // The track list of another source was activated: start at the top again.
    Connections {
        function onTracklistChanged() {
            root.selectCategory("TRACK");
        }

        target: root
    }

    color: "#101010"

    // ---- Header: source, path, back, info ----
    Rectangle {
        id: header

        color: "#161616"
        height: 56

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        TapHandler {
            // tap on the title: one level back
            onTapped: root.back()
        }
        Text {
            id: sourceText

            color: "#27a8e0"
            font.bold: true
            font.pixelSize: 22
            text: root.library.sourceTitle !== "" ? root.library.sourceTitle : "BROWSE"

            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
        }
        Text {
            color: "#ffffff"
            elide: Text.ElideRight
            font.pixelSize: 20
            text: "›  " + root.category + (root.drillValue !== "" ? "  ›  " + root.drillValue : "")

            anchors {
                left: sourceText.right
                leftMargin: 8
                right: infoButton.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            id: infoButton

            border.color: root.infoOpen ? "#1fb0f0" : "#5a5a5a"
            border.width: 2
            color: root.infoOpen ? "#1f6fe0" : "#202020"
            height: 40
            width: 100

            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.centerIn: parent
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 18
                text: "INFO"
            }
            TapHandler {
                onTapped: root.infoOpen = !root.infoOpen
            }
        }
    }

    // ---- Categories ----
    Column {
        id: categoryColumn

        spacing: 2
        width: 210

        anchors {
            bottom: parent.bottom
            left: parent.left
            top: header.bottom
            topMargin: 4
        }

        Repeater {
            model: root.categories

            Rectangle {
                required property string modelData

                border.color: root.category === modelData ? "#1fb0f0" : "#2a2a2a"
                border.width: root.category === modelData ? 2 : 1
                color: root.category === modelData ? "#10293f" : "#161616"
                height: 64
                width: parent.width

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 18
                        verticalCenter: parent.verticalCenter
                    }
                    color: root.category === parent.modelData ? "#ffffff" : "#c0c0c0"
                    font.bold: true
                    font.pixelSize: 22
                    text: parent.modelData
                }
                TapHandler {
                    onTapped: root.selectCategory(parent.modelData)
                }
            }
        }
    }

    // ---- Values of a category (artists, albums, keys, BPM) ----
    ListView {
        id: valueList

        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.values
        visible: !root.showTracks

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOn
        }

        anchors {
            bottom: parent.bottom
            left: categoryColumn.right
            leftMargin: 6
            right: parent.right
            top: header.bottom
            topMargin: 4
        }

        delegate: Rectangle {
            required property var modelData
            required property int index

            color: index % 2 === 0 ? "#141414" : "#1a1a1a"
            height: 56
            width: ListView.view.width

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 16
                    right: countText.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                color: "#ffffff"
                elide: Text.ElideRight
                font.pixelSize: 20
                text: parent.modelData.value
            }
            Text {
                id: countText

                anchors {
                    right: parent.right
                    rightMargin: 24
                    verticalCenter: parent.verticalCenter
                }
                color: "#8a8a8a"
                font.pixelSize: 18
                text: parent.modelData.count
            }
            TapHandler {
                onTapped: root.drill(parent.modelData.value)
            }
        }
    }

    // ---- Tracks ----
    LibraryComponent.TrackList {
        id: trackList

        clip: true
        keyCamelot: root.library.keyCamelot
        scrollEnabled: root.library.scrollEnabled
        model: root.tracklist
        visible: root.showTracks

        anchors {
            bottom: parent.bottom
            left: categoryColumn.right
            leftMargin: 6
            right: infoPanel.visible ? infoPanel.left : parent.right
            top: header.bottom
            topMargin: 4
        }
    }

    // ---- INFO of the selected track ----
    Rectangle {
        id: infoPanel

        readonly property var track: trackList.selectedRow >= 0 && root.tracklist
                ? root.tracklist.getTrack(trackList.selectedRow) : null

        border.color: "#3a3a3a"
        color: "#141414"
        visible: root.infoOpen && root.showTracks
        width: 360

        anchors {
            bottom: parent.bottom
            right: parent.right
            top: header.bottom
            topMargin: 4
        }

        Text {
            anchors.centerIn: parent
            color: "#6a6a6a"
            font.pixelSize: 18
            text: "Select a track"
            visible: !infoPanel.track
        }
        Column {
            spacing: 8
            visible: !!infoPanel.track

            anchors {
                fill: parent
                margins: 14
            }

            Text {
                color: "#ffffff"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: 22
                text: infoPanel.track ? infoPanel.track.title : ""
                width: parent.width
            }
            Text {
                color: "#b8b8b8"
                elide: Text.ElideRight
                font.pixelSize: 18
                text: infoPanel.track ? infoPanel.track.artist : ""
                width: parent.width
            }
            Repeater {
                model: infoPanel.track ? [
                    { label: "ALBUM", value: infoPanel.track.album },
                    { label: "GENRE", value: infoPanel.track.genre },
                    { label: "KEY", value: trackList.formatKey(infoPanel.track.keyText) },
                    { label: "TIME", value: root.formatTime(infoPanel.track.duration) },
                    { label: "YEAR", value: infoPanel.track.year },
                    { label: "COMMENT", value: infoPanel.track.comment }
                ] : []

                Row {
                    required property var modelData

                    spacing: 10
                    visible: modelData.value !== undefined && String(modelData.value) !== ""
                    width: parent.width

                    Text {
                        color: "#8a8a8a"
                        font.pixelSize: 15
                        text: parent.modelData.label
                        width: 90
                    }
                    Text {
                        color: "#ffffff"
                        elide: Text.ElideRight
                        font.pixelSize: 16
                        text: String(parent.modelData.value)
                        width: parent.width - 100
                    }
                }
            }
        }
    }
}
