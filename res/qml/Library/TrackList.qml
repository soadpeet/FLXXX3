import ".." as Skin
import "../AdvSettings"
import "." as LibraryComponent
import Mixxx 1.0 as Mixxx
import Qt.labs.qmlmodels
import QtQml
import QtQuick
import QtQml.Models
import QtQuick.Layouts
import QtQuick.Controls 2.15
import "../Theme"

Rectangle {
    id: root

    required property var model
    // Row of the selected track (-1: none); Android BROWSE shows its INFO.
    property int selectedRow: -1

    color: Theme.darkGray

    LibraryComponent.Control {
        id: libraryControl

        onFocusWidgetChanged: {
            switch (focusWidget) {
            case Skin.FocusedWidgetControl.WidgetKind.LibraryView:
                view.forceActiveFocus();
                break;
            }
        }
        onLoadSelectedTrack: (group, play) => {
            if (!root.visible)
                return;
            view.loadSelectedTrack(group, play);
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            if (!root.visible)
                return;
            view.loadSelectedTrackIntoNextAvailableDeck(play);
        }
        onMoveVertical: offset => {
            if (!root.visible)
                return;
            // Android: no scrolling (and no reading of track data from the
            // stick) while the library is closed.
            if (Qt.platform.os === "android" && !root.scrollEnabled)
                return;
            view.selectionModel.moveSelectionVertical(offset);
        }
    }
    // Camelot (8A) or classic (Am) key names (UTILITY setting).
    property bool keyCamelot: true
    // False while the library is closed: the knob does not move the selection.
    property bool scrollEnabled: true
    // Size factor of the rows and texts (smaller screens).
    property real uiScale: 1.0
    // Android edition: look of the list (SETTINGS gear in BROWSE), saved on the device.
    property int rowHeight: 54
    property int waveWidth: 150
    // The width before the waveform was switched off (SHOW IN THE LIST > WAVEFORM).
    property int lastWaveWidth: 150
    property var hiddenColumns: ["Album", "Year", "File Type", "Bitrate"]
    // Key of the saved list settings: BROWSE and PLAYLIST each have their own.
    property string viewKey: "list_view"
    function saveView() {
        if (Qt.platform.os !== "android")
            return;
        Mixxx.Config.setAndroidSetting(root.viewKey, JSON.stringify({
            "rowHeight": root.rowHeight,
            "waveWidth": root.waveWidth,
            "hidden": root.hiddenColumns
        }));
    }
    function loadView() {
        if (Qt.platform.os !== "android")
            return;
        // Without settings of its own, a list starts with those of BROWSE.
        let raw = Mixxx.Config.androidSetting(root.viewKey, "");
        if (raw === "")
            raw = Mixxx.Config.androidSetting("list_view", "");
        root.rowHeight = 54;
        root.waveWidth = 150;
        root.hiddenColumns = ["Album", "Year", "File Type", "Bitrate"];
        try {
            const v = JSON.parse(raw);
            // Fixed steps (SMALL / MEDIUM / LARGE): older free values snap to the nearest one.
            const nearest = (list, x) => list.reduce((best, c) => Math.abs(c - x) < Math.abs(best - x) ? c : best, list[0]);
            if (v.rowHeight > 0)
                root.rowHeight = nearest([40, 54, 70], v.rowHeight);
            if (v.waveWidth >= 0)
                root.waveWidth = nearest([0, 90, 150, 220], v.waveWidth);
            if (Array.isArray(v.hidden))
                root.hiddenColumns = v.hidden;
        } catch (e) {
        }
    }
    onViewKeyChanged: root.loadView()

    // ---- Preview by tapping the waveform (preview deck, heard in the headphones) ----
    property string previewUrl: ""
    property real previewFrac: 0
    Mixxx.ControlProxy {
        id: previewPlay

        group: "[PreviewDeck1]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: previewPos

        group: "[PreviewDeck1]"
        key: "playposition"
    }
    // The track that is loaded in the preview deck, and whether a finger is holding it.
    property bool previewActive: false
    property bool previewPending: false
    readonly property var previewPlayer: Mixxx.PlayerManager.getPlayer("[PreviewDeck1]")
    // Loaded, then jump to the tapped place, only then play (so the start of the track is
    // never heard first).
    function previewStart() {
        if (!root.previewPending)
            return;
        root.previewPending = false;
        previewSeek.stop();
        previewPos.value = root.previewFrac;
        if (root.previewActive)
            previewPlay.value = 1;
    }
    Connections {
        function onTrackLoaded() {
            root.previewStart();
        }

        target: root.previewPlayer
    }
    Timer {
        id: previewSeek

        // Fallback if the loaded signal does not come (the track was loaded already).
        interval: 800
        onTriggered: root.previewStart()
    }
    function previewTrack(url, frac) {
        if (url === "")
            return;
        root.previewFrac = Math.max(0, Math.min(0.999, frac));
        root.previewActive = true;
        if (url === root.previewUrl && !root.previewPending) {
            previewPos.value = root.previewFrac;
            previewPlay.value = 1;
            return;
        }
        previewPlay.value = 0;
        root.previewUrl = url;
        root.previewPending = true;
        root.previewPlayer.loadTrackFromLocationUrl(url, false);
        previewSeek.restart();
    }
    // Released: the preview stops (the track stays loaded, so the next press starts at once).
    function stopPreview() {
        previewSeek.stop();
        root.previewPending = false;
        root.previewActive = false;
        previewPlay.value = 0;
    }
    onVisibleChanged: {
        if (!visible && root.previewActive)
            root.stopPreview();
    }
    function resetView() {
        root.rowHeight = 54;
        root.waveWidth = 150;
        root.hiddenColumns = ["Album", "Year", "File Type", "Bitrate"];
        root.saveView();
    }
    function toggleColumn(label) {
        const list = root.hiddenColumns.slice();
        const i = list.indexOf(label);
        if (i >= 0)
            list.splice(i, 1);
        else
            list.push(label);
        root.hiddenColumns = list;
        root.saveView();
    }
    Component.onCompleted: root.loadView()
    onHiddenColumnsChanged: {
        if (typeof view !== "undefined" && view.model) {
            view.updateColumnSize();
            view.forceLayout();
        }
    }
    onWaveWidthChanged: {
        if (typeof view !== "undefined" && view.model)
            view.forceLayout();
    }
    onRowHeightChanged: {
        if (typeof view !== "undefined")
            view.forceLayout();
    }
    readonly property var _camelotMinor: ({"Abm": 1, "G#m": 1, "Ebm": 2, "D#m": 2, "Bbm": 3, "A#m": 3, "Fm": 4, "Cm": 5, "Gm": 6, "Dm": 7, "Am": 8, "Em": 9, "Bm": 10, "F#m": 11, "Gbm": 11, "C#m": 12, "Dbm": 12})
    readonly property var _camelotMajor: ({"B": 1, "Cb": 1, "F#": 2, "Gb": 2, "Db": 3, "C#": 3, "Ab": 4, "G#": 4, "Eb": 5, "D#": 5, "Bb": 6, "A#": 6, "F": 7, "C": 8, "G": 9, "D": 10, "A": 11, "E": 12})
    readonly property var _classicMinor: ["", "Abm", "Ebm", "Bbm", "Fm", "Cm", "Gm", "Dm", "Am", "Em", "Bm", "F#m", "C#m"]
    readonly property var _classicMajor: ["", "B", "F#", "Db", "Ab", "Eb", "Bb", "F", "C", "G", "D", "A", "E"]

    function formatKey(rawText) {
        if (!rawText)
            return "";
        const text = rawText.replace(/\u266f/g, "#").replace(/\u266d/g, "b");
        const pretty = name => name.replace(/#/g, "\u266f").replace(/([A-G])b/g, "$1\u266d");
        const m = /^(\d{1,2})([ABab])$/.exec(text);
        if (m) {
            const n = parseInt(m[1]);
            if (root.keyCamelot || n < 1 || n > 12)
                return text;
            return pretty(m[2].toUpperCase() === "A" ? root._classicMinor[n] : root._classicMajor[n]);
        }
        if (!root.keyCamelot)
            return rawText;
        const minor = root._camelotMinor[text];
        if (minor !== undefined)
            return minor + "A";
        const major = root._camelotMajor[text];
        if (major !== undefined)
            return major + "B";
        return rawText;
    }
    // ---- Track menu (Android touch UI, like the RX3 track menu) ----
    // Lists kept by the app (TAG LIST), set by the BROWSE screen.
    property var listStore: null
    property int menuRow: -1
    function jumpToLetter(letter) {
        // First row whose title (column 0) starts with the letter ("#": a digit).
        const model = view.model;
        if (!model)
            return;
        const rows = model.rowCount();
        for (let r = 0; r < rows; ++r) {
            const text = String(model.data(model.index(r, 0), Qt.DisplayRole)).trim().toUpperCase();
            if (text.length === 0)
                continue;
            const first = text.charAt(0);
            const hit = letter === "#" ? (first >= "0" && first <= "9") : first === letter;
            if (hit) {
                view.positionViewAtRow(r, Qt.AlignTop);
                view.selectionModel.selectRow(r);
                return;
            }
        }
    }
    property string menuTitle: ""
    property string menuArtist: ""
    property bool menuLock1: false
    property bool menuLock2: false

    function openTrackMenu(row) {
        const track = view.model.getTrack ? view.model.getTrack(row) : null;
        root.menuRow = row;
        root.menuTitle = track && track.title ? track.title : "";
        root.menuArtist = track && track.artist ? track.artist : "";
        // LOAD LOCK (UTILITY menu): no loading into a deck that plays.
        const lock = Mixxx.Config.androidSetting("loadLock", "1") === "1";
        root.menuLock1 = lock && trackMenuPlay1.value > 0;
        root.menuLock2 = lock && trackMenuPlay2.value > 0;
        trackMenu.open();
    }

    Mixxx.ControlProxy { id: trackMenuPlay1; group: "[Channel1]"; key: "play" }
    Mixxx.ControlProxy { id: trackMenuPlay2; group: "[Channel2]"; key: "play" }
    Mixxx.ControlProxy { id: trackMenuLoad1; group: "[Channel1]"; key: "LoadSelectedTrack" }
    Mixxx.ControlProxy { id: trackMenuLoad2; group: "[Channel2]"; key: "LoadSelectedTrack" }

    Popup {
        id: trackMenu

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
                text: root.menuTitle
                width: parent.width
            }
            Text {
                color: "#9a9a9a"
                elide: Text.ElideRight
                font.pixelSize: 16
                text: root.menuArtist
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
                            trackMenu.close();
                            if (loadButton.modelData.deck === 1)
                                trackMenuLoad1.trigger();
                            else
                                trackMenuLoad2.trigger();
                        }
                    }
                }
            }
            Rectangle {
                border.color: "#5a5a5a"
                color: tagTap.pressed ? "#3a3a3a" : "#202020"
                height: 56
                visible: !!root.listStore
                width: parent.width

                Text {
                    anchors.centerIn: parent
                    color: "#ffb020"
                    font.bold: true
                    font.pixelSize: 20
                    text: root.listStore && root.menuRow >= 0 && root.listStore.version >= 0
                            && root.listStore.isTagged(view.model.trackInfo(root.menuRow).url)
                            ? "REMOVE TAG" : "TAG"
                }
                TapHandler {
                    id: tagTap

                    onTapped: {
                        root.listStore.toggleTag(view.model.trackInfo(root.menuRow));
                        trackMenu.close();
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
                    onTapped: trackMenu.close()
                }
            }
        }
    }
    // Sort arrow drawn from bars (the font of the tablet shows the triangle glyph as a yellow
    // emoji). Points up for ascending, down for descending, in the accent colour.
    component SortArrow: Column {
        property bool up: true
        property color arrowColor: "#27a8e0"

        spacing: 0

        Repeater {
            model: 5

            Rectangle {
                required property int index

                anchors.horizontalCenter: parent.horizontalCenter
                color: parent.arrowColor
                height: Math.max(2, Math.round(2 * root.uiScale))
                width: Math.round((parent.up ? index * 3 + 3 : (5 - index) * 3) * root.uiScale)
            }
        }
    }
    HorizontalHeaderView {
        id: horizontalHeader

        property int sortingColumn: -1
        property var sortingOrder: Qt.Descending

        anchors.left: parent.left
        anchors.margins: 5
        anchors.right: parent.right
        anchors.top: parent.top
        syncView: view

        delegate: Item {
            id: column

            required property string display
            required property int index
            // Android: the title cell holds the waveform, the number and the title; the
            // header shows them as three windows of their own.
            readonly property bool split: Qt.platform.os === "android" && display === "Title"
            readonly property real numEnd: 8 + Math.round(34 * root.uiScale) + 2
            readonly property real waveEnd: 8 + Math.round(34 * root.uiScale) + 4 + Math.round(root.waveWidth * root.uiScale) + 4

            implicitHeight: columnName.contentHeight + (Qt.platform.os === "android" ? 18 : 5)
            implicitWidth: columnName.contentWidth + 5

            // "#": sorts by the number
            MouseArea {
                acceptedButtons: Qt.LeftButton
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    leftMargin: 0
                    top: parent.top
                }
                enabled: column.split && view.numberColumn >= 0
                visible: column.split
                width: column.numEnd

                onClicked: {
                    if (horizontalHeader.sortingColumn == view.numberColumn) {
                        horizontalHeader.sortingOrder = horizontalHeader.sortingOrder == Qt.DescendingOrder ? Qt.AscendingOrder : Qt.DescendingOrder;
                    } else {
                        horizontalHeader.sortingColumn = view.numberColumn;
                        horizontalHeader.sortingOrder = Qt.AscendingOrder;
                    }
                    view.model.sort(horizontalHeader.sortingColumn, horizontalHeader.sortingOrder);
                }
            }
            MouseArea {
                id: columnMouseHandler

                acceptedButtons: Qt.LeftButton
                anchors.fill: parent
                anchors.leftMargin: column.split ? column.waveEnd : 0

                onClicked: {
                    if (horizontalHeader.sortingColumn == index) {
                        horizontalHeader.sortingOrder = horizontalHeader.sortingOrder == Qt.DescendingOrder ? Qt.AscendingOrder : Qt.DescendingOrder;
                    } else {
                        horizontalHeader.sortingColumn = index;
                        horizontalHeader.sortingOrder = Qt.AscendingOrder;
                    }
                    view.model.sort(horizontalHeader.sortingColumn, horizontalHeader.sortingOrder);
                }
            }
            Text {
                id: columnName

                anchors.fill: parent
                // Android: the title column starts with the waveform and the number, the
                // header "Title" stands over the titles, "#" over the numbers.
                anchors.leftMargin: (Qt.platform.os === "android" && display === "Title") ? 8 + Math.round(root.waveWidth * root.uiScale) + 4 + Math.round(34 * root.uiScale) + 8 : 15
                color: Theme.textColor
                elide: Text.ElideRight
                font.capitalization: Font.Capitalize
                font.family: Theme.fontFamily
                font.pixelSize: Qt.platform.os === "android" ? Math.round(16 * root.uiScale) : 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignLeft
                text: display
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                color: Theme.textColor
                font.capitalization: Font.Capitalize
                font.family: Theme.fontFamily
                font.pixelSize: Qt.platform.os === "android" ? Math.round(16 * root.uiScale) : 12
                font.weight: Font.Medium
                height: parent.height
                horizontalAlignment: Text.AlignRight
                text: "#"
                verticalAlignment: Text.AlignVCenter
                visible: Qt.platform.os === "android" && display === "Title"
                width: Math.round(34 * root.uiScale)
                x: 8
            }
            Item {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    leftMargin: column.split ? column.waveEnd + 5 : 5
                    top: parent.top
                }
                SortArrow {
                    id: sortIndicator

                    anchors.centerIn: parent
                    up: horizontalHeader.sortingOrder == Qt.AscendingOrder
                    visible: horizontalHeader.sortingColumn == index
                }
            }
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    leftMargin: column.waveEnd
                    top: parent.top
                }
                color: Theme.darkGray2
                visible: column.split && root.waveWidth > 0
                width: 1
            }
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    leftMargin: column.numEnd
                    top: parent.top
                }
                color: Theme.darkGray2
                visible: column.split
                width: 1
            }
            SortArrow {
                anchors.verticalCenter: parent.verticalCenter
                up: horizontalHeader.sortingOrder == Qt.AscendingOrder
                visible: column.split && view.numberColumn >= 0 && horizontalHeader.sortingColumn == view.numberColumn
                x: 2
            }
            Text {
                color: Theme.textColor
                font.family: Theme.fontFamily
                font.pixelSize: Qt.platform.os === "android" ? Math.round(16 * root.uiScale) : 12
                font.weight: Font.Medium
                height: parent.height
                text: "Waveform"
                verticalAlignment: Text.AlignVCenter
                visible: column.split && root.waveWidth > 0
                x: column.numEnd + 6
            }
            Rectangle {
                id: columnResizer

                color: Theme.darkGray2
                width: 1

                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    top: parent.top
                }
                MouseArea {
                    id: columnResizeHandler

                    property int sizeOffset: 0

                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    preventStealing: true

                    onMouseXChanged: {
                        if (drag.active) {
                            column.width += mouseX;
                            sizeOffset += mouseX;
                        }
                    }

                    drag {
                        axis: Drag.XAxis
                        target: parent
                        threshold: 2

                        onActiveChanged: {
                            if (!drag.active && columnResizeHandler.sizeOffset !== 0) {
                                view.model.columns[index].preferredWidth = column.width;
                                columnResizeHandler.sizeOffset = 0;
                                view.updateColumnSize();
                                view.forceLayout();
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: fullDelegate

        Item {
            id: item

            required property url cover_art
            required property color decoration
            required property var display
            required property string file_url
            required property int row
            required property bool selected
            required property var track

            implicitHeight: 30

            Loader {
                id: loader

                property var capabilities: root.model ? root.model.getCapabilities() : Mixxx.LibraryTrackListModel.Capability.None
                property url cover_art: item.cover_art
                property color decoration: item.decoration
                property var display: item.display
                property url file_url: item.file_url
                property int row: item.row
                property bool selected: item.selected
                property var tableView: view
                property var track: item.track

                anchors.fill: parent
                focus: true
                sourceComponent: delegate

                onLoaded:
                // Workaround needed for WaveformOverview column to load the data
                //     if (track)
                //         Mixxx.Library.analyze(track)
                {}
            }
            // Workaround needed for WaveformOverview column to load the data
            // TableView.onReused: {
            //     if (track)
            //         Mixxx.Library.analyze(track)
            // }
        }
    }
    // Lean delegate for the Android touch UI: three objects per cell instead of
    // a Loader with the full desktop cell (drag handling, drag preview, ...).
    // That made opening a source take many seconds on weaker devices.
    Component {
        id: liteDelegate

        Rectangle {
            id: liteCell

            required property var display
            required property int row
            required property int column
            required property bool selected

            color: selected ? Theme.accentColor : (row % 2 == 0 ? Theme.sunkenBackgroundColor : Theme.backgroundColor)
            implicitHeight: Math.round(root.rowHeight * root.uiScale)

            // The waveform of the track is loaded a moment after the row came to rest
            // (reading it takes time while the list is flicked).
            property bool waveReady: false
            // The columns are told apart by their label (the cover column in front makes
            // the title the second column).
            readonly property string colLabel: view.model && view.model.columns[liteCell.column] ? view.model.columns[liteCell.column].label : ""
            readonly property bool isTitle: liteCell.colLabel === "Title"
            readonly property bool isArtist: liteCell.colLabel === "Artist"
            readonly property bool isKey: liteCell.colLabel === "Key"
            readonly property bool isStars: liteCell.colLabel === "Stars"
            // The track number of the file; without one the position in the list.
            readonly property string numberText: {
                if (!liteCell.isTitle || !view.model)
                    return "";
                if (view.numberColumn >= 0) {
                    const n = parseInt(view.model.data(view.model.index(liteCell.row, view.numberColumn), Qt.DisplayRole));
                    if (!isNaN(n) && n > 0)
                        return String(n);
                }
                return String(liteCell.row + 1);
            }

            Component.onCompleted: {
                if (liteCell.isTitle)
                    waveTimer.restart();
            }
            Timer {
                id: waveTimer

                // Staggered by row, so that all previews of a freshly sorted list do not
                // load in the same frame.
                interval: 200 + (liteCell.row % 12) * 45

                onTriggered: liteCell.waveReady = true
            }
            TableView.onPooled: {
                liteCell.waveReady = false;
                waveTimer.stop();
            }
            TableView.onReused: {
                liteCell.waveReady = false;
                if (liteCell.isTitle)
                    waveTimer.restart();
            }

            // The track number (left), the waveform of the track follows.
            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 8 + Math.round(34 * root.uiScale) + 4
                    verticalCenter: parent.verticalCenter
                }
                color: "transparent"
                height: Math.round(Math.max(14, root.rowHeight - 12) * root.uiScale)
                visible: liteCell.isTitle
                width: Math.round(root.waveWidth * root.uiScale)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#3a3a3a"
                    height: 2
                    visible: !liteCell.waveReady
                    width: parent.width
                }
                // Hold = listen into the track from this place (preview deck), release = stop.
                TapHandler {
                    enabled: liteCell.isTitle && root.waveWidth > 0

                    onPressedChanged: {
                        if (pressed)
                            root.previewTrack(String(view.model.getUrl(liteCell.row)), point.position.x / parent.width);
                        else
                            root.stopPreview();
                    }
                }
                // Play position of the preview.
                Rectangle {
                    color: "#ffffff"
                    height: parent.height
                    visible: root.previewActive && liteCell.isTitle && String(view.model.getUrl(liteCell.row)) === root.previewUrl
                    width: 2
                    x: previewPos.value * parent.width
                    z: 5
                }
                Loader {
                    active: liteCell.isTitle && liteCell.waveReady
                    anchors.fill: parent

                    sourceComponent: Component {
                        Mixxx.WaveformOverview {
                            channels: Mixxx.WaveformOverview.Channels.BothChannels
                            minuteMarkers: false
                            normalized: true
                            stereo: false
                            track: view.model.getTrack(liteCell.row)
                        }
                    }
                }
            }
            Text {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                color: "#8a8a8a"
                font.pixelSize: Math.round(15 * root.uiScale)
                horizontalAlignment: Text.AlignRight
                text: liteCell.numberText
                visible: liteCell.isTitle
                width: Math.round(34 * root.uiScale)
            }
            Text {
                anchors.fill: parent
                anchors.leftMargin: liteCell.isTitle ? 8 + Math.round(root.waveWidth * root.uiScale) + 4 + Math.round(34 * root.uiScale) + 8 : 10
                color: liteCell.isStars ? "#f5c542" : (liteCell.isTitle ? "#ffffff" : (liteCell.isArtist ? "#b8b8b8" : "#ffffff"))
                elide: Text.ElideRight
                font.bold: liteCell.isTitle
                font.pixelSize: Math.round((liteCell.isTitle ? 18 : 16) * root.uiScale)
                text: {
                    if (liteCell.isStars) {
                        const n = parseInt(liteCell.display);
                        return isNaN(n) || n <= 0 ? "" : "\u2605".repeat(Math.min(5, n)) + "\u2606".repeat(Math.max(0, 5 - n));
                    }
                    return liteCell.isKey ? root.formatKey(liteCell.display ?? "") : (liteCell.display ?? "");
                }
                verticalAlignment: Text.AlignVCenter
            }
            TapHandler {
                // A tap only selects the track (INFO); holding it for a moment
                // opens the menu with LOAD TO DECK 1 / LOAD TO DECK 2. (Default
                // gesture policy: the list can still be flicked.)
                longPressThreshold: AdvSettings.values.longPressSec

                onLongPressed: {
                    // Holding the waveform is a preview, not the menu.
                    if (root.previewActive)
                        return;
                    view.selectionModel.selectRow(liteCell.row);
                    root.openTrackMenu(liteCell.row);
                }
                onTapped: view.selectionModel.selectRow(liteCell.row)
            }
        }
    }
    TableView {
        id: view

        property int dynamicColumnCount: 0
        property int usedWidth: 0
        // Android edition: the columns of the track number and of the stars.
        property int numberColumn: -1
        property real flexWeightSum: 0
        property bool titleVisible: false
        property int starsColumn: -1

        // Android edition: loading by file location skips the track model, so
        // the Rekordbox data (waveform, beat grid, cues) would never be read.
        // Asking the model for the track does that (and keeps it in the cache
        // for the load that follows).
        function prepareSelectedTrack() {
            if (Qt.platform.os !== "android")
                return;
            const selected = this.selectionModel.selectedIndexes;
            if (selected.length > 0 && this.model.getTrack)
                this.model.getTrack(selected[0].row);
        }
        function loadSelectedTrack(group, play) {
            const urls = this.selectionModel.selectedTrackUrls();
            if (urls.length == 0)
                return;

            this.prepareSelectedTrack();
            // The deck shows the position in the list as TRACK.
            const rows = this.selectionModel.selectedIndexes;
            if (rows.length > 0)
                Mixxx.Config.setAndroidSetting("listPos" + group, String(rows[0].row + 1));
            Mixxx.PlayerManager.getPlayer(group).loadTrackFromLocationUrl(urls[0], play);
        }
        function loadSelectedTrackIntoNextAvailableDeck(play) {
            const urls = this.selectionModel.selectedTrackUrls();
            if (urls.length == 0)
                return;

            this.prepareSelectedTrack();
            Mixxx.PlayerManager.loadLocationUrlIntoNextAvailableDeck(urls[0], play);
        }
        function updateColumnSize() {
            const oldUsedWidth = usedWidth;
            const oldDynamicColumnCount = dynamicColumnCount;
            usedWidth = 0;
            dynamicColumnCount = 0;
            flexWeightSum = 0;
            titleVisible = false;
            if (model == null) {
                return;
            }
            numberColumn = -1;
            starsColumn = -1;
            for (let c = 0; c < model.columns.length; c++) {
                if (model.columns[c].label === "#")
                    numberColumn = c;
                else if (model.columns[c].label === "Stars")
                    starsColumn = c;
            }
            for (let c = 0; c < model.columns.length; c++) {
                if (model.columns[c].hidden || root.hiddenColumns.indexOf(model.columns[c].label) >= 0 || model.columns[c].autoHideWidth > view.width) {
                    continue;
                } else if (model.columns[c].preferredWidth > 0) {
                    usedWidth += model.columns[c].preferredWidth;
                } else {
                    dynamicColumnCount += model.columns[c].fillSpan || 1;
                    flexWeightSum += model.columns[c].label === "Title" ? 1.5 : (model.columns[c].fillSpan || 1);
                    if (model.columns[c].label === "Title")
                        titleVisible = true;
                }
            }
            return oldDynamicColumnCount != dynamicColumnCount || oldUsedWidth != usedWidth;
        }

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 5
        anchors.right: parent.right
        anchors.top: horizontalHeader.bottom
        clip: true
        columnWidthProvider: function (column) {
            const columnDef = view.model.columns[column];
            if (columnDef.hidden || root.hiddenColumns.indexOf(columnDef.label) >= 0) {
                return 0;
            }
            if (columnDef.autoHideWidth > 0 && columnDef.autoHideWidth > view.width) {
                return 0;
            }
            if (columnDef.preferredWidth >= 0) {
                return columnDef.preferredWidth;
            }
            const span = columnDef.fillSpan || 1;
            if (Qt.platform.os !== "android")
                return span * (view.width - view.usedWidth) / view.dynamicColumnCount;
            // Android: the space left by the fixed columns is shared by the flexible ones
            // (title, artist, album) by weight; the title cell also holds the waveform and
            // the number, which keep their room first. Showing or hiding a column
            // re-divides everything.
            const isTitle = columnDef.label === "Title";
            const fixedTitle = view.titleVisible ? Math.round((root.waveWidth + 34) * root.uiScale) + 20 : 0;
            const free = view.width - view.usedWidth - fixedTitle;
            const weight = isTitle ? 1.5 : span;
            const part = Math.max(Math.round(90 * root.uiScale), free * weight / Math.max(0.1, view.flexWeightSum));
            return isTitle ? fixedTitle + part : part;
        }
        keyNavigationEnabled: false
        // Android: fixed row height (SMALL / MEDIUM / LARGE of the list settings).
        rowHeightProvider: function (row) {
            return Qt.platform.os === "android" ? Math.round(root.rowHeight * root.uiScale) : -1;
        }
        model: root.model
        pointerNavigationEnabled: false
        reuseItems: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOn
        }
        delegate: Qt.platform.os === "android" ? liteDelegate : fullDelegate
        selectionModel: ItemSelectionModel {
            onSelectionChanged: {
                const selection = this.selectedIndexes;
                root.selectedRow = selection.length > 0 ? selection[0].row : -1;
            }
            function moveSelectionVertical(value) {
                if (value == 0)
                    return;

                const selected = this.selectedIndexes;
                // Nothing selected yet: the first turn selects the first track (not the second).
                if (selected.length == 0) {
                    this.selectRow(0);
                    return;
                }
                this.selectRow(selected[0].row + value);
            }
            function selectRow(row) {
                const rowCount = this.model.rowCount();
                if (rowCount == 0) {
                    this.clear();
                    return;
                }
                // Android edition: stay at the first / last track instead of
                // wrapping around, and keep the selection in view.
                const newRow = Qt.platform.os === "android" ? Math.max(0, Math.min(rowCount - 1, row)) : Mixxx.MathUtils.positiveModulo(row, rowCount);
                this.select(this.model.index(newRow, 0), ItemSelectionModel.Rows | ItemSelectionModel.Select | ItemSelectionModel.Clear | ItemSelectionModel.Current);
                if (Qt.platform.os === "android") {
                    view.positionViewAtRow(newRow, TableView.Contain);
                }
            }
            function selectedTrackUrls() {
                return this.selectedIndexes.map(index => {
                    return this.model.getUrl(index.row);
                });
            }

            model: view.model
        }

        Component.onCompleted: this.updateColumnSize()
        Keys.onDownPressed: this.selectionModel.moveSelectionVertical(1)
        Keys.onEnterPressed: this.loadSelectedTrackIntoNextAvailableDeck(false)
        Keys.onReturnPressed: this.loadSelectedTrackIntoNextAvailableDeck(false)
        Keys.onUpPressed: this.selectionModel.moveSelectionVertical(-1)
        onModelChanged: this.updateColumnSize()
        onWidthChanged: {
            if (view.updateColumnSize()) {
                // forceLayout is costly - only invoke if there was a change in the column layouts
                view.forceLayout();
            }
        }
    }
}
