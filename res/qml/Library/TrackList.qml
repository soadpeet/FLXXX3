import ".." as Skin
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
            view.loadSelectedTrack(group, play);
        }
        onLoadSelectedTrackIntoNextAvailableDeck: play => {
            view.loadSelectedTrackIntoNextAvailableDeck(play);
        }
        onMoveVertical: offset => {
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
    property string menuTitle: ""
    property string menuArtist: ""
    property bool menuLock1: false
    property bool menuLock2: false

    function openTrackMenu(row) {
        const track = view.model.getTrack ? view.model.getTrack(row) : null;
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
        height: 380
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

            implicitHeight: columnName.contentHeight + 5
            implicitWidth: columnName.contentWidth + 5

            MouseArea {
                id: columnMouseHandler

                acceptedButtons: Qt.LeftButton
                anchors.fill: parent

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
                anchors.leftMargin: 15
                color: Theme.textColor
                elide: Text.ElideRight
                font.capitalization: Font.Capitalize
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignLeft
                text: display
                verticalAlignment: Text.AlignVCenter
            }
            Item {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    leftMargin: 5
                    top: parent.top
                }
                Label {
                    id: sortIndicator

                    anchors.centerIn: parent
                    color: "red"
                    elide: Text.ElideRight
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.buttonFontPixelSize
                    horizontalAlignment: Text.AlignRight
                    rotation: horizontalHeader.sortingOrder == Qt.AscendingOrder ? 90 : -90
                    text: "▶"
                    verticalAlignment: Text.AlignVCenter
                    visible: horizontalHeader.sortingColumn == index
                }
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
            implicitHeight: 54

            // PREVIEW placeholder (the waveform of the track follows later).
            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                color: "#242424"
                height: 28
                visible: liteCell.column === 0
                width: 70

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#3a3a3a"
                    height: 2
                    width: parent.width
                }
            }
            Text {
                anchors.fill: parent
                anchors.leftMargin: liteCell.column === 0 ? 90 : 10
                color: liteCell.column === 0 ? "#ffffff" : (liteCell.column === 1 ? "#b8b8b8" : "#ffffff")
                elide: Text.ElideRight
                font.bold: liteCell.column === 0
                font.pixelSize: liteCell.column === 0 ? 18 : 16
                text: liteCell.column === 5 ? root.formatKey(liteCell.display ?? "") : (liteCell.display ?? "")
                verticalAlignment: Text.AlignVCenter
            }
            TapHandler {
                // A tap only selects the track (INFO); holding it for a moment
                // opens the menu with LOAD TO DECK 1 / LOAD TO DECK 2. (Default
                // gesture policy: the list can still be flicked.)
                longPressThreshold: 0.5

                onLongPressed: {
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
            if (model == null) {
                return;
            }
            for (let c = 0; c < model.columns.length; c++) {
                if (model.columns[c].hidden || model.columns[c].autoHideWidth > view.width) {
                    continue;
                } else if (model.columns[c].preferredWidth > 0) {
                    usedWidth += model.columns[c].preferredWidth;
                } else {
                    dynamicColumnCount += model.columns[c].fillSpan || 1;
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
            if (columnDef.hidden) {
                return 0;
            }
            if (columnDef.autoHideWidth > 0 && columnDef.autoHideWidth > view.width) {
                return 0;
            }
            if (columnDef.preferredWidth >= 0) {
                return columnDef.preferredWidth;
            }
            const span = columnDef.fillSpan || 1;
            return span * (view.width - view.usedWidth) / view.dynamicColumnCount;
        }
        keyNavigationEnabled: false
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
                const oldRow = (selected.length == 0) ? 0 : selected[0].row;
                this.selectRow(oldRow + value);
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
