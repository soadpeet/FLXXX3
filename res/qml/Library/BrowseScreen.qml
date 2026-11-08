import Mixxx 1.0 as Mixxx
import ".." as Skin
import "." as LibraryComponent
import QtQuick 2.12
import QtQuick.Controls 2.15
import "../Theme"

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// Library screens of the touch UI (modelled on the XDJ-RX3). The mode comes from
// the top bar button (library.mode):
//   BROWSE    categories (TRACK, ARTIST, ALBUM, GENRE, KEY, BPM, STARS, HISTORY),
//             values of a category, tracks, SORT, alphabet jump, INFO
//   PLAYLIST  the playlists of the source (tree) and MY LISTS, tracks on the right
//   SEARCH    touch keyboard, NARROW DOWN, results
//   TAG LIST  the tagged tracks (max 100 per stick), check, remove, save as playlist
// Tapping the header goes one level back (like BACK on the player).
Rectangle {
    id: root

    // The Library item (gives the track list model of the current source).
    required property var library
    readonly property var tracklist: root.library.sidebar ? root.library.sidebar.tracklist : null
    readonly property var store: root.library.store
    readonly property string mode: root.library.mode

    // Screen size factor: the fixed sizes below are made for the tablet (about 540 high);
    // smaller screens (phone) get smaller texts and rows, so that more tracks fit.
    readonly property real s: Math.max(0.5, Math.min(1.0, root.height / 540))

    // ---- BROWSE state ----
    property string category: "TRACK"
    property string drillValue: ""
    property var values: []
    property bool infoOpen: false
    readonly property var categories: ["TRACK", "ARTIST", "ALBUM", "GENRE", "KEY", "BPM", "STARS", "HISTORY"]
    // field of the track model that the values of a category are read from
    readonly property var categoryDistinct: ({ ARTIST: "artist", ALBUM: "album", GENRE: "genre", KEY: "key", BPM: "bpm", STARS: "rating" })
    // search field to filter the tracks of a value
    readonly property var categoryField: ({ ARTIST: "artist", ALBUM: "album", BPM: "bpm", KEY: "key", GENRE: "genre", STARS: "rating" })
    readonly property bool historyView: root.mode === "BROWSE" && root.category === "HISTORY"
    readonly property bool browseTracks: root.mode === "BROWSE" && !root.historyView &&
            (root.category === "TRACK" || root.drillValue !== "")
    property int trackCount: 0
    function updateCount() {
        root.trackCount = root.tracklist ? root.tracklist.rowCount() : 0;
    }
    onTracklistChanged: root.updateCount()
    Connections {
        function onLayoutChanged() { root.updateCount(); }
        function onModelReset() { root.updateCount(); }
        function onRowsInserted() { root.updateCount(); }
        function onRowsRemoved() { root.updateCount(); }

        target: root.tracklist
    }
    property int sortColumn: -1
    property int sortOrder: Qt.AscendingOrder

    // ---- PLAYLIST state ----
    property var treeStack: []
    property var treeItems: []
    property bool inMyLists: false
    property int myListShown: -1

    // ---- SEARCH state ----
    property var terms: []
    property string input: ""

    // ---- TAG LIST ----
    property string confirmText: ""
    property var confirmAction: null

    readonly property bool tracksVisible: root.browseTracks ||
            (root.mode === "PLAYLIST" && root.myListShown < 0) || root.mode === "SEARCH"


    // ================= TRACK FILTER (BROWSE) =================
    // Filters the tracks by BPM, key, stars and colour. The MASTER buttons take the BPM and
    // the key of the master deck; keys that go with the chosen key are shown in green.
    property bool filterBpmOn: false
    property real filterBpm: 160
    property int filterBpmRange: 6
    property bool filterKeyOn: false
    property string filterKey: "8A"
    property int filterRating: 0
    property int filterColor: -1
    // Search text of the value that was opened (BPM / ARTIST ... category), without the filter.
    property string baseSearch: ""
    readonly property bool filterActive: root.filterBpmOn || root.filterKeyOn || root.filterRating > 0 || root.filterColor >= 0
    readonly property var filterColors: [
        { name: "PINK", rgb: 0xF870F8 }, { name: "RED", rgb: 0xF87090 }, { name: "ORANGE", rgb: 0xF8A030 },
        { name: "YELLOW", rgb: 0xF8E331 }, { name: "GREEN", rgb: 0x1EE000 }, { name: "AQUA", rgb: 0x16C0F8 },
        { name: "BLUE", rgb: 0x0150F8 }, { name: "PURPLE", rgb: 0x9808F8 }
    ]
    readonly property var camelotKeys: ["1A", "2A", "3A", "4A", "5A", "6A", "7A", "8A", "9A", "10A", "11A", "12A",
        "1B", "2B", "3B", "4B", "5B", "6B", "7B", "8B", "9B", "10B", "11B", "12B"]
    Mixxx.ControlProxy { id: filterMasterDeck; group: "[AndroidDJ]"; key: "master_deck" }
    Mixxx.ControlProxy { id: filterBpmDeck1; group: "[Channel1]"; key: "bpm" }
    Mixxx.ControlProxy { id: filterBpmDeck2; group: "[Channel2]"; key: "bpm" }
    // The deck whose BPM and key the MASTER buttons take (master, else the first loaded one).
    function filterMasterGroup() {
        const m = Math.round(filterMasterDeck.value);
        if (m === 1 || m === 2)
            return "[Channel" + m + "]";
        return filterBpmDeck1.value > 0 ? "[Channel1]" : (filterBpmDeck2.value > 0 ? "[Channel2]" : "");
    }
    function toCamelot(text) {
        if (!text)
            return "";
        const t = String(text).replace(/\u266f/g, "#").replace(/\u266d/g, "b");
        const m = /^(\d{1,2})([ABab])$/.exec(t);
        if (m)
            return parseInt(m[1]) + m[2].toUpperCase();
        // OpenKey (1d = C major = 8B, 1m = A minor = 8A)
        const o = /^(\d{1,2})([dm])$/.exec(t);
        if (o)
            return ((parseInt(o[1]) + 6) % 12 + 1) + (o[2] === "m" ? "A" : "B");
        if (trackList._camelotMinor[t] !== undefined)
            return trackList._camelotMinor[t] + "A";
        if (trackList._camelotMajor[t] !== undefined)
            return trackList._camelotMajor[t] + "B";
        return "";
    }
    function takeMasterBpm() {
        const g = root.filterMasterGroup();
        const bpm = g === "[Channel1]" ? filterBpmDeck1.value : (g === "[Channel2]" ? filterBpmDeck2.value : 0);
        if (bpm > 0) {
            root.filterBpm = Math.round(bpm * 10) / 10;
            root.filterBpmOn = true;
            root.applyFilter();
        }
    }
    function takeMasterKey() {
        const g = root.filterMasterGroup();
        if (g === "")
            return;
        const player = Mixxx.PlayerManager.getPlayer(g);
        const key = root.toCamelot(player && player.currentTrack ? player.currentTrack.keyText : "");
        if (key !== "") {
            root.filterKey = key;
            root.filterKeyOn = true;
            root.applyFilter();
        }
    }
    // The spellings of a Camelot key that the key column can hold (Camelot, classic with flats
    // and with sharps).
    function keySpellings(key) {
        const m = /^(\d{1,2})([AB])$/.exec(key);
        if (!m)
            return [key];
        const n = parseInt(m[1]);
        const classic = m[2] === "A" ? trackList._classicMinor[n] : trackList._classicMajor[n];
        const sharp = {"Abm": "G#m", "Ebm": "D#m", "Bbm": "A#m", "F#m": "Gbm", "C#m": "Dbm",
            "Db": "C#", "Ab": "G#", "Eb": "D#", "Bb": "A#", "F#": "Gb"};
        const names = [key, classic];
        if (sharp[classic] !== undefined)
            names.push(sharp[classic]);
        return names;
    }
    // Keys that go with a key (Camelot): the same, one step up / down, and the parallel key.
    function relatedKeys(key) {
        const m = /^(\d{1,2})([AB])$/.exec(key);
        if (!m)
            return [];
        const n = parseInt(m[1]);
        const up = n % 12 + 1;
        const down = (n + 10) % 12 + 1;
        const other = m[2] === "A" ? "B" : "A";
        return [n + m[2], up + m[2], down + m[2], n + other];
    }
    // The search text for the filter; the OR parts of the search syntax carry the keys
    // (the syntax has no brackets, so every key gets its own copy of the other conditions).
    function buildSearch() {
        const common = [];
        if (root.baseSearch !== "")
            common.push(root.baseSearch);
        if (root.filterBpmOn) {
            const lo = Math.max(1, root.filterBpm * (1 - root.filterBpmRange / 100));
            const hi = root.filterBpm * (1 + root.filterBpmRange / 100);
            common.push("bpm:" + lo.toFixed(1) + "-" + hi.toFixed(1));
        }
        if (root.filterRating > 0)
            common.push("rating:>=" + root.filterRating);
        if (root.filterColor >= 0)
            common.push("tc:" + root.filterColors[root.filterColor].rgb);
        if (!root.filterKeyOn)
            return common.join(" ");
        // Every key with every spelling in the key column (8A, Am, ...), exact matches.
        const groups = [];
        root.relatedKeys(root.filterKey).forEach(k => root.keySpellings(k).forEach(name =>
            groups.push(common.concat(["ktxt:\"" + name + "\""]).join(" "))));
        return groups.join(" | ");
    }
    // Taps on the filter buttons only restart this timer; the search (which rebuilds the
    // list behind the popup) runs once, shortly after the last tap.
    Timer {
        id: filterDebounce

        interval: 350
        onTriggered: {
            if (root.tracklist && root.tracksVisible) {
                root.tracklist.search(root.buildSearch());
                // The search drops the chosen sorting: apply it again.
                if (root.sortColumn >= 0)
                    root.tracklist.sort(root.sortColumn, root.sortOrder);
            }
        }
    }
    function applyFilter() {
        filterDebounce.restart();
    }
    function resetFilter() {
        root.filterBpmOn = false;
        root.filterKeyOn = false;
        root.filterRating = 0;
        root.filterColor = -1;
        root.applyFilter();
    }

    // Text of a value of the category (keys in the notation of UTILITY, stars as stars).
    function valueText(value) {
        if (root.category === "KEY")
            return trackList.formatKey(value);
        if (root.category === "STARS") {
            const n = parseInt(value);
            return n > 0 ? "\u2605".repeat(n) + "\u2606".repeat(Math.max(0, 5 - n)) : "NO RATING";
        }
        return value;
    }
    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const total = Math.round(seconds);
        const sec = total % 60;
        return Math.floor(total / 60) + ":" + (sec < 10 ? "0" : "") + sec;
    }

    // ---------------- BROWSE ----------------
    function selectCategory(name) {
        root.category = name;
        root.drillValue = "";
        root.baseSearch = "";
        if (root.tracklist) {
            root.tracklist.search(name === "TRACK" ? root.buildSearch() : "");
            if (root.categoryDistinct[name] !== undefined) {
                root.values = root.tracklist.distinctField(root.categoryDistinct[name]);
                // STARS: five stars first
                if (name === "STARS")
                    root.values = root.values.slice().reverse();
            }
            else
                root.values = [];
        }
    }
    function drill(value) {
        root.drillValue = value;
        if (root.tracklist) {
            const field = root.categoryField[root.category];
            if (root.category === "BPM") {
                const bpm = parseFloat(value);
                root.baseSearch = "bpm:" + (bpm - 0.5) + "-" + (bpm + 0.5);
            } else if (root.category === "STARS") {
                root.baseSearch = "rating:" + value;
            } else {
                root.baseSearch = field + ":\"" + value + "\"";
            }
            root.tracklist.search(root.buildSearch());
        }
    }
    // Index of the column with this label in the model (the hidden cover column in front
    // shifts the numbers, so they are looked up by name).
    function columnByLabel(label) {
        const cols = root.tracklist ? root.tracklist.columns : null;
        if (!cols)
            return 0;
        for (let i = 0; i < cols.length; ++i) {
            if (cols[i].label === label)
                return i;
        }
        return 0;
    }
    function sortBy(column) {
        if (root.sortColumn === column)
            root.sortOrder = root.sortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder;
        else {
            root.sortColumn = column;
            root.sortOrder = Qt.AscendingOrder;
        }
        if (root.tracklist)
            root.tracklist.sort(root.sortColumn, root.sortOrder);
    }
    function jumpToLetter(letter) {
        if (root.tracksVisible && !(root.mode === "BROWSE" && !root.browseTracks)) {
            trackList.jumpToLetter(letter);
            return;
        }
        for (let i = 0; i < root.values.length; ++i) {
            const first = String(root.values[i].value).trim().toUpperCase().charAt(0);
            const hit = letter === "#" ? (first >= "0" && first <= "9") : first === letter;
            if (hit) {
                valueList.positionViewAtIndex(i, ListView.Beginning);
                return;
            }
        }
    }

    // ---------------- PLAYLIST ----------------
    function treeBuild() {
        const items = [];
        const sb = root.library.sidebar;
        if (root.inMyLists) {
            for (let i = 0; i < root.store.myLists.length; ++i)
                items.push({ label: root.store.myLists[i].name + "  (" + root.store.myLists[i].tracks.length + ")", kind: "mylist", listIndex: i });
        } else if (sb && root.treeStack.length > 0) {
            const parentIdx = root.treeStack[root.treeStack.length - 1].idx;
            const n = sb.rowCount(parentIdx);
            for (let r = 0; r < n; ++r) {
                const idx = sb.index(r, 0, parentIdx);
                items.push({ label: String(sb.data(idx, Qt.DisplayRole)), idx: idx, kind: "node" });
            }
        } else if (sb) {
            // Top level: the playlists and folders of all sticks, without the
            // stick names (the sticks themselves are the first level of the tree).
            const sticksIdx = sb.index(1, 0);
            const sticks = sb.rowCount(sticksIdx);
            for (let k = 0; k < sticks; ++k) {
                const stickIdx = sb.index(k, 0, sticksIdx);
                let n = sb.rowCount(stickIdx);
                if (n === 0) {
                    // the children of a stick are read when it is opened
                    sb.activate(stickIdx);
                    n = sb.rowCount(stickIdx);
                }
                for (let r = 0; r < n; ++r) {
                    const idx = sb.index(r, 0, stickIdx);
                    items.push({ label: String(sb.data(idx, Qt.DisplayRole)), idx: idx, kind: "node" });
                }
            }
        }
        if (!root.inMyLists && root.treeStack.length === 0)
            items.push({ label: "MY LISTS", kind: "mylists" });
        root.treeItems = items;
    }
    // The playlist that is shown (path of the tree + name), highlighted in the tree.
    property string treeSelected: ""
    function treeKey(label) {
        return root.treeStack.map(e => e.label).join("/") + "/" + label;
    }
    function treeTap(item) {
        const sb = root.library.sidebar;
        if (item.kind === "mylists") {
            root.inMyLists = true;
            root.myListShown = -1;
            root.treeBuild();
        } else if (item.kind === "mylist") {
            root.myListShown = item.listIndex;
        } else if (sb) {
            root.myListShown = -1;
            root.treeSelected = root.treeKey(item.label);
            sb.activate(item.idx);
            root.library.sourceTitle = item.label;
            if (sb.rowCount(item.idx) > 0) {
                const stack = root.treeStack.slice();
                stack.push({ idx: item.idx, label: item.label });
                root.treeStack = stack;
                root.treeBuild();
            }
        }
    }
    function treeBack() {
        if (root.myListShown >= 0) {
            root.myListShown = -1;
        } else if (root.inMyLists) {
            root.inMyLists = false;
            root.treeBuild();
        } else if (root.treeStack.length > 0) {
            const stack = root.treeStack.slice();
            stack.pop();
            root.treeStack = stack;
            root.treeBuild();
        }
    }

    // ---------------- SEARCH ----------------
    function applySearch() {
        if (!root.tracklist)
            return;
        const parts = root.terms.slice();
        if (root.input.trim() !== "")
            parts.push(root.input.trim());
        root.tracklist.search(parts.join(" "));
    }

    // ---------------- BACK ----------------
    function back() {
        if (root.mode === "BROWSE") {
            if (root.drillValue !== "") {
                root.drillValue = "";
                if (root.tracklist)
                    root.tracklist.search("");
            } else if (root.category !== "TRACK") {
                root.selectCategory("TRACK");
            }
        } else if (root.mode === "PLAYLIST") {
            root.treeBack();
        } else if (root.mode === "SEARCH") {
            if (root.input !== "") {
                root.input = "";
            } else if (root.terms.length > 0) {
                const t = root.terms.slice();
                t.pop();
                root.terms = t;
            }
            root.applySearch();
        }
    }

    // Entering a mode starts at its first level.
    function enterMode() {
        root.infoOpen = false;
        if (root.mode === "BROWSE") {
            // BROWSE opens the list that was accessed last (playlist or folder).
            root.selectCategory(root.category);
        } else if (root.mode === "PLAYLIST") {
            root.myListShown = -1;
            if (root.tracklist)
                root.tracklist.search("");
            root.treeBuild();
        } else if (root.mode === "SEARCH") {
            root.terms = [];
            root.input = "";
            if (root.tracklist)
                root.tracklist.search("");
        } else if (root.mode === "TAG LIST") {
            tagList.setAllChecked(false);
        }
    }
    onModeChanged: root.enterMode()
    // The track list of another source was activated: start at the top again.
    Connections {
        function onTracklistChanged() {
            if (root.mode === "BROWSE")
                root.selectCategory("TRACK");
        }

        target: root
    }

    color: "#101010"

    // ---- Header: source, path, back, sort, info ----
    Rectangle {
        id: header

        color: "#161616"
        height: Math.round(56 * root.s)

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
            font.pixelSize: Math.round(18 * root.s)
            text: root.mode === "BROWSE" ? (root.library.sourceTitle !== "" ? root.library.sourceTitle : "BROWSE") : root.mode

            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
        }
        Text {
            color: "#ffffff"
            elide: Text.ElideRight
            font.pixelSize: Math.round(16 * root.s)
            text: {
                if (root.mode === "BROWSE")
                    return "›  " + root.category + (root.drillValue !== "" ? "  ›  " + root.valueText(root.drillValue) : "");
                if (root.mode === "PLAYLIST") {
                    let path = root.inMyLists ? "MY LISTS" : "";
                    root.treeStack.forEach(e => path += (path !== "" ? "  ›  " : "") + e.label);
                    if (root.myListShown >= 0 && root.store.myLists[root.myListShown])
                        path += "  ›  " + root.store.myLists[root.myListShown].name;
                    return path !== "" ? "›  " + path : "";
                }
                if (root.mode === "SEARCH")
                    return root.tracklist ? "›  " + root.trackCount + " tracks" : "";
                if (root.mode === "TAG LIST")
                    return "›  " + root.store.tags.length + " tagged";
                return "";
            }

            anchors {
                left: sourceText.right
                leftMargin: 8
                right: filterButton.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            id: filterButton

            border.color: root.filterActive ? "#27a8e0" : "#5a5a5a"
            border.width: 2
            color: filterTap.pressed ? "#3a3a3a" : (root.filterActive ? Qt.alpha("#27a8e0", 0.18) : "#202020")
            height: Math.round(34 * root.s)
            visible: root.tracksVisible && root.mode === "BROWSE"
            width: Math.round(124 * root.s)

            anchors {
                right: sortButton.left
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.centerIn: parent
                color: root.filterActive ? "#27a8e0" : "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(15 * root.s)
                text: "TRACK FILTER"
            }
            TapHandler {
                id: filterTap

                onTapped: filterPopup.open()
            }
        }
        Rectangle {
            id: sortButton

            border.color: "#5a5a5a"
            border.width: 2
            color: sortTap.pressed ? "#3a3a3a" : "#202020"
            height: Math.round(34 * root.s)
            visible: root.tracksVisible
            width: Math.round(76 * root.s)

            anchors {
                right: infoButton.left
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.centerIn: parent
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(15 * root.s)
                text: "SORT"
            }
            TapHandler {
                id: sortTap

                onTapped: sortPopup.open()
            }
        }
        Rectangle {
            id: infoButton

            border.color: root.infoOpen ? "#1fb0f0" : "#5a5a5a"
            border.width: 2
            color: root.infoOpen ? "#1f6fe0" : "#202020"
            height: Math.round(34 * root.s)
            visible: root.tracksVisible
            width: Math.round(76 * root.s)

            anchors {
                right: settingsButton.left
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.centerIn: parent
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(15 * root.s)
                text: "INFO"
            }
            TapHandler {
                onTapped: root.infoOpen = !root.infoOpen
            }
        }
        Rectangle {
            id: settingsButton

            border.color: "#5a5a5a"
            border.width: 2
            color: settingsTap.pressed ? "#3a3a3a" : "#202020"
            height: Math.round(34 * root.s)
            visible: root.tracksVisible
            width: Math.round(40 * root.s)

            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }

            // Gear: ring with eight teeth.
            Item {
                anchors.centerIn: parent
                height: Math.round(24 * root.s)
                width: height

                Repeater {
                    model: 8

                    Item {
                        required property int index

                        anchors.fill: parent
                        rotation: index * 45

                        Rectangle {
                            color: "#ffffff"
                            height: parent.height * 0.3
                            width: parent.width * 0.18
                            x: (parent.width - width) / 2
                            y: 0
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    border.color: "#ffffff"
                    border.width: Math.max(2, Math.round(parent.width * 0.14))
                    color: "transparent"
                    height: parent.width * 0.62
                    radius: width / 2
                    width: height
                }
            }
            TapHandler {
                id: settingsTap

                onTapped: viewPopup.open()
            }
        }
    }

    // ================= BROWSE: categories =================
    Column {
        id: categoryColumn

        readonly property real rowHeight: Math.min(Math.round(64 * root.s), (height - 2 * (root.categories.length - 1)) / root.categories.length)

        // Symbols of the categories (the width is just enough for the symbol and a short name).
        readonly property var symbols: ({ TRACK: "\u266A", ARTIST: "", ALBUM: "\u25C9", GENRE: "\u266C", KEY: "\u266F", BPM: "\u2669", STARS: "\u2605", HISTORY: "" })

        spacing: 2
        visible: root.mode === "BROWSE"
        width: Math.round(84 * root.s)

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
                height: categoryColumn.rowHeight
                width: parent.width

                // ARTIST: a person (head and shoulders), HISTORY: a clock. Drawn here because the
                // font of the tablet has no symbol for them.
                Item {
                    id: drawnIcon

                    readonly property color iconColor: root.category === parent.modelData ? "#ffffff" : "#c0c0c0"
                    readonly property real size: Math.round(Math.min(26 * root.s, categoryColumn.rowHeight * 0.44))

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Math.round(categoryColumn.rowHeight * 0.12)
                    }
                    height: size
                    visible: parent.modelData === "ARTIST" || parent.modelData === "HISTORY"
                    width: size

                    Rectangle {
                        color: drawnIcon.iconColor
                        height: drawnIcon.size * 0.42
                        radius: height / 2
                        visible: drawnIcon.parent.modelData === "ARTIST"
                        width: height
                        x: (drawnIcon.size - width) / 2
                        y: 0
                    }
                    Rectangle {
                        color: drawnIcon.iconColor
                        height: drawnIcon.size * 0.5
                        radius: drawnIcon.size * 0.22
                        visible: drawnIcon.parent.modelData === "ARTIST"
                        width: drawnIcon.size * 0.86
                        x: (drawnIcon.size - width) / 2
                        y: drawnIcon.size * 0.5
                    }
                    Rectangle {
                        border.color: drawnIcon.iconColor
                        border.width: Math.max(2, drawnIcon.size * 0.1)
                        color: "transparent"
                        height: drawnIcon.size
                        radius: height / 2
                        visible: drawnIcon.parent.modelData === "HISTORY"
                        width: height
                    }
                    Rectangle {
                        color: drawnIcon.iconColor
                        height: drawnIcon.size * 0.3
                        visible: drawnIcon.parent.modelData === "HISTORY"
                        width: Math.max(2, drawnIcon.size * 0.1)
                        x: drawnIcon.size / 2 - width / 2
                        y: drawnIcon.size * 0.2
                    }
                    Rectangle {
                        color: drawnIcon.iconColor
                        height: Math.max(2, drawnIcon.size * 0.1)
                        visible: drawnIcon.parent.modelData === "HISTORY"
                        width: drawnIcon.size * 0.26
                        x: drawnIcon.size / 2
                        y: drawnIcon.size / 2 - height / 2
                    }
                }
                Text {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Math.round(categoryColumn.rowHeight * 0.06)
                    }
                    color: root.category === parent.modelData ? "#ffffff" : "#c0c0c0"
                    font.bold: true
                    font.pixelSize: Math.round(Math.min(30 * root.s, categoryColumn.rowHeight * 0.5))
                    text: categoryColumn.symbols[parent.modelData]
                }
                Text {
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: Math.round(categoryColumn.rowHeight * 0.07)
                        horizontalCenter: parent.horizontalCenter
                    }
                    color: root.category === parent.modelData ? "#9fd8f5" : "#7a7a7a"
                    font.bold: true
                    font.pixelSize: Math.round(Math.min(11 * root.s, categoryColumn.rowHeight * 0.2))
                    text: parent.modelData
                }
                TapHandler {
                    onTapped: root.selectCategory(parent.modelData)
                }
            }
        }
    }

    // ---- Values of a category ----
    ListView {
        id: valueList

        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.values
        visible: root.mode === "BROWSE" && !root.browseTracks && !root.historyView

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOn
        }

        anchors {
            bottom: parent.bottom
            left: categoryColumn.right
            leftMargin: 6
            right: alphabet.left
            top: header.bottom
            topMargin: 4
        }

        delegate: Rectangle {
            required property var modelData
            required property int index

            color: index % 2 === 0 ? "#141414" : "#1a1a1a"
            height: Math.round(56 * root.s)
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
                font.pixelSize: Math.round(20 * root.s)
                text: root.valueText(parent.modelData.value)
            }
            Text {
                id: countText

                anchors {
                    right: parent.right
                    rightMargin: 24
                    verticalCenter: parent.verticalCenter
                }
                color: "#8a8a8a"
                font.pixelSize: Math.round(18 * root.s)
                text: parent.modelData.count
            }
            TapHandler {
                onTapped: root.drill(parent.modelData.value)
            }
        }
    }

    // ---- HISTORY ----
    LibraryComponent.InfoTrackList {
        id: historyList

        entries: root.store.history
        formatKey: trackList.formatKey
        scrollEnabled: root.library.scrollEnabled
        store: root.store
        uiScale: root.s
        visible: root.historyView

        anchors {
            bottom: parent.bottom
            left: categoryColumn.right
            leftMargin: 6
            right: parent.right
            top: header.bottom
            topMargin: 4
        }
    }

    // ================= PLAYLIST: tree =================
    Rectangle {
        id: treePanel

        color: "transparent"
        visible: root.mode === "PLAYLIST"
        width: Math.round(root.width * 0.2)

        anchors {
            bottom: parent.bottom
            left: parent.left
            top: header.bottom
            topMargin: 4
        }

        Text {
            anchors.centerIn: parent
            color: "#6a6a6a"
            font.pixelSize: Math.round(18 * root.s)
            text: root.inMyLists ? "No saved lists" : "No playlists"
            visible: root.treeItems.length === 0
        }
        ListView {
            anchors.fill: parent
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: root.treeItems
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOn
            }

            delegate: Rectangle {
                required property var modelData
                required property int index

                // same look as the categories of BROWSE
                readonly property bool chosen: (modelData.kind === "mylist" && root.myListShown === modelData.listIndex)
                        || (modelData.kind === "node" && root.myListShown < 0 && root.treeSelected === root.treeKey(modelData.label))

                border.color: chosen ? "#1fb0f0" : "#2a2a2a"
                border.width: chosen ? 2 : 1
                color: chosen ? "#10293f" : "#161616"
                height: Math.round(42 * root.s)
                // narrower than the list: the marking stays left of the scroll bar
                width: ListView.view.width - Math.round(16 * root.s)

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        right: arrow.left
                        rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    color: parent.modelData.kind === "mylists" || parent.chosen ? "#1fb0f0" : "#ffffff"
                    elide: Text.ElideRight
                    font.bold: parent.modelData.kind === "mylists" || parent.chosen
                    font.pixelSize: Math.round(16 * root.s)
                    text: parent.modelData.label
                }
                Text {
                    id: arrow

                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    color: "#6a6a6a"
                    font.pixelSize: Math.round(22 * root.s)
                    text: parent.modelData.kind === "mylists" ? "›" : ""
                }
                TapHandler {
                    longPressThreshold: 0.6

                    onLongPressed: {
                        // delete a saved list
                        if (parent.modelData.kind === "mylist") {
                            const at = parent.modelData.listIndex;
                            root.confirmText = "Delete the list \"" + root.store.myLists[at].name + "\"?";
                            root.confirmAction = function() {
                                root.myListShown = -1;
                                root.store.deleteList(at);
                                root.treeBuild();
                            };
                            confirmPopup.open();
                        }
                    }
                    onTapped: root.treeTap(parent.modelData)
                }
            }
        }
    }
    LibraryComponent.InfoTrackList {
        id: myListTracks

        entries: root.myListShown >= 0 && root.store.myLists[root.myListShown]
                ? root.store.myLists[root.myListShown].tracks : []
        formatKey: trackList.formatKey
        scrollEnabled: root.library.scrollEnabled
        store: root.store
        uiScale: root.s
        visible: root.mode === "PLAYLIST" && root.myListShown >= 0

        anchors {
            bottom: parent.bottom
            left: treePanel.right
            leftMargin: 6
            right: parent.right
            top: header.bottom
            topMargin: 4
        }
    }

    // ================= SEARCH: input line + keyboard =================
    Item {
        id: searchBar

        height: Math.round(52 * root.s)
        visible: root.mode === "SEARCH"
        width: parent.width - keyboardPanel.width - 10

        anchors {
            left: parent.left
            leftMargin: 6
            top: header.bottom
            topMargin: 4
        }

        Row {
            spacing: 6
            anchors.fill: parent

            Repeater {
                model: root.terms

                Rectangle {
                    required property string modelData
                    required property int index

                    border.color: "#1fb0f0"
                    color: "#10293f"
                    height: parent.height
                    radius: 4
                    width: chipText.width + crossIcon.width + 36

                    Text {
                        id: chipText

                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        color: "#ffffff"
                        font.pixelSize: Math.round(19 * root.s)
                        text: parent.modelData
                    }
                    // Cross to remove the term, drawn (the font of the tablet has no glyph for it).
                    Item {
                        id: crossIcon

                        height: width
                        width: Math.round(13 * root.s)

                        anchors {
                            left: chipText.right
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            color: "#c0c0c0"
                            height: 2
                            rotation: 45
                            width: parent.width * 1.3
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            color: "#c0c0c0"
                            height: 2
                            rotation: -45
                            width: parent.width * 1.3
                        }
                    }
                    TapHandler {
                        onTapped: {
                            const t = root.terms.slice();
                            t.splice(parent.index, 1);
                            root.terms = t;
                            root.applySearch();
                        }
                    }
                }
            }
            Rectangle {
                border.color: "#3a3a3a"
                color: "#0c0c0c"
                height: parent.height
                radius: 4
                width: Math.max(Math.round(120 * root.s), searchBar.width - x)

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    color: root.input === "" ? "#5a5a5a" : "#ffffff"
                    font.pixelSize: Math.round(22 * root.s)
                    text: root.input === "" ? "SEARCH" : root.input + "|"
                }
            }
        }
    }
    Item {
        id: keyboardPanel

        visible: root.mode === "SEARCH"
        width: Math.round(root.width * 0.47)

        anchors {
            bottom: parent.bottom
            bottomMargin: 6
            right: parent.right
            rightMargin: 6
            top: header.bottom
            topMargin: 6
        }

        LibraryComponent.SearchKeyboard {
            anchors.fill: parent
            s: root.s

            onBackspace: {
                root.input = root.input.slice(0, -1);
                root.applySearch();
            }
            onClearAll: {
                root.input = "";
                root.terms = [];
                root.applySearch();
            }
            onNarrowDown: {
                if (root.input.trim() !== "") {
                    const t = root.terms.slice();
                    t.push(root.input.trim());
                    root.terms = t;
                    root.input = "";
                    root.applySearch();
                }
            }
            onTyped: text => {
                root.input += text;
                root.applySearch();
            }
        }
    }

    // ================= TAG LIST =================
    Row {
        id: tagBar

        spacing: 8
        visible: root.mode === "TAG LIST"

        anchors {
            left: parent.left
            leftMargin: 6
            top: header.bottom
            topMargin: 6
        }

        Repeater {
            model: [
                { label: "ALL", action: "all" },
                { label: "NONE", action: "none" },
                { label: "REMOVE TAG", action: "remove" },
                { label: "SAVE AS PLAYLIST", action: "save" },
                { label: "DELETE ALL", action: "clear" }
            ]

            Rectangle {
                required property var modelData

                border.color: modelData.action === "clear" ? "#a04040" : "#5a5a5a"
                border.width: 2
                color: barTap.pressed ? "#3a3a3a" : "#202020"
                height: Math.round(44 * root.s)
                width: barText.width + Math.round(30 * root.s)

                Text {
                    id: barText

                    anchors.centerIn: parent
                    color: parent.modelData.action === "clear" ? "#ff7a7a" : "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(17 * root.s)
                    text: parent.modelData.label
                }
                TapHandler {
                    id: barTap

                    onTapped: {
                        switch (parent.modelData.action) {
                        case "all":
                            tagList.setAllChecked(true);
                            break;
                        case "none":
                            tagList.setAllChecked(false);
                            break;
                        case "remove":
                            root.store.removeTags(tagList.checkedUrls());
                            tagList.setAllChecked(false);
                            break;
                        case "save":
                            root.store.saveTagsAsList("TAGS " + Qt.formatDateTime(new Date(), "dd.MM. HH:mm"));
                            break;
                        case "clear":
                            root.confirmText = "Remove all tags?";
                            root.confirmAction = function() {
                                root.store.clearTags();
                            };
                            confirmPopup.open();
                            break;
                        }
                    }
                }
            }
        }
    }
    LibraryComponent.InfoTrackList {
        id: tagList

        checkable: true
        entries: root.store.tags
        formatKey: trackList.formatKey
        scrollEnabled: root.library.scrollEnabled
        store: root.store
        uiScale: root.s
        visible: root.mode === "TAG LIST"

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            top: tagBar.bottom
            topMargin: 6
        }
    }

    // ================= Tracks (BROWSE, PLAYLIST, SEARCH) =================
    Item {
        id: trackArea

        visible: root.tracksVisible
        x: root.mode === "PLAYLIST" ? treePanel.width + 6 : (root.mode === "SEARCH" ? 0 : categoryColumn.width + 6)
        y: header.height + 4 + (root.mode === "SEARCH" ? searchBar.height + 6 : 0)
        height: root.height - y
        width: root.width - x - (root.mode === "SEARCH" ? keyboardPanel.width + 10 : alphabet.width) -
                (infoPanel.visible ? infoPanel.width : 0)
    }
    LibraryComponent.TrackList {
        id: trackList

        anchors.fill: trackArea
        clip: true
        keyCamelot: root.library.keyCamelot
        listStore: root.store
        model: root.tracklist
        scrollEnabled: root.library.scrollEnabled
        uiScale: root.s
        viewKey: root.mode === "PLAYLIST" ? "list_view_playlist" : "list_view"
        visible: root.tracksVisible
    }

    // ---- Alphabet jump (BROWSE and PLAYLIST) ----
    Item {
        id: alphabet

        readonly property var letters: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
            "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"]

        visible: (root.mode === "BROWSE" && !root.historyView) || (root.mode === "PLAYLIST" && root.myListShown < 0)
        width: visible ? Math.round(34 * root.s) : 0

        anchors {
            bottom: parent.bottom
            right: infoPanel.visible ? infoPanel.left : parent.right
            top: header.bottom
            topMargin: 4
        }

        Column {
            anchors.fill: parent

            Repeater {
                model: alphabet.letters

                Text {
                    required property string modelData

                    color: "#8a8a8a"
                    font.bold: true
                    font.pixelSize: Math.max(8, Math.round(alphabet.height / 27 * 0.62))
                    height: alphabet.height / 27
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    verticalAlignment: Text.AlignVCenter
                    width: alphabet.width
                }
            }
        }
        MouseArea {
            function letterAt(y) {
                const i = Math.max(0, Math.min(26, Math.floor(y / (alphabet.height / 27))));
                return alphabet.letters[i];
            }

            anchors.fill: parent

            onPositionChanged: mouse => root.jumpToLetter(letterAt(mouse.y))
            onPressed: mouse => root.jumpToLetter(letterAt(mouse.y))
        }
    }

    // ---- INFO of the selected track ----
    Rectangle {
        id: infoPanel

        readonly property var track: trackList.selectedRow >= 0 && root.tracklist
                ? root.tracklist.getTrack(trackList.selectedRow) : null

        border.color: "#3a3a3a"
        color: "#141414"
        visible: root.infoOpen && root.tracksVisible
        width: Math.round(360 * root.s)

        anchors {
            bottom: parent.bottom
            right: parent.right
            top: header.bottom
            topMargin: 4
        }

        Text {
            anchors.centerIn: parent
            color: "#6a6a6a"
            font.pixelSize: Math.round(18 * root.s)
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
                font.pixelSize: Math.round(22 * root.s)
                text: infoPanel.track ? infoPanel.track.title : ""
                width: parent.width
            }
            Text {
                color: "#b8b8b8"
                elide: Text.ElideRight
                font.pixelSize: Math.round(18 * root.s)
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
                        font.pixelSize: Math.round(15 * root.s)
                        text: parent.modelData.label
                        width: Math.round(90 * root.s)
                    }
                    Text {
                        color: "#ffffff"
                        elide: Text.ElideRight
                        font.pixelSize: Math.round(16 * root.s)
                        text: String(parent.modelData.value)
                        width: parent.width - 100
                    }
                }
            }
        }
    }


    // ---- LIST SETTINGS (gear) ----
    Popup {
        id: viewPopup

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: true
        padding: 14
        width: Math.min(Overlay.overlay ? Overlay.overlay.width - 20 : 700, Math.round(700 * root.s))

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        component SButton: Rectangle {
            id: sb

            property bool active: false
            property alias text: sbText.text
            signal clicked

            border.color: sb.active ? "#27a8e0" : "#4a4a4a"
            color: sbTap.pressed ? "#3a3a3a" : (sb.active ? Qt.alpha("#27a8e0", 0.18) : "#202020")
            height: Math.round(44 * root.s)
            width: Math.max(Math.round(52 * root.s), sbText.implicitWidth + 24)

            Text {
                id: sbText

                anchors.centerIn: parent
                color: sb.active ? "#27a8e0" : "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(17 * root.s)
            }
            TapHandler {
                id: sbTap

                onTapped: sb.clicked()
            }
        }

        Column {
            spacing: Math.round(12 * root.s)
            width: parent.width

            Row {
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(22 * root.s)
                    text: root.mode === "PLAYLIST" ? "LIST SETTINGS \u2022 PLAYLIST" : "LIST SETTINGS"
                }
                SButton {
                    text: "RESET"
                    onClicked: trackList.resetView()
                }
                SButton {
                    text: "CLOSE"
                    onClicked: viewPopup.close()
                }
            }
            // Row height (how tight the songs stand together)
            Row {
                spacing: 8

                Text {
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(17 * root.s)
                    height: Math.round(44 * root.s)
                    text: "ROW HEIGHT"
                    verticalAlignment: Text.AlignVCenter
                    width: Math.round(170 * root.s)
                }
                Repeater {
                    model: [{"t": "SMALL", "v": 40}, {"t": "MEDIUM", "v": 54}, {"t": "LARGE", "v": 70}]

                    SButton {
                        required property var modelData

                        active: trackList.rowHeight === modelData.v
                        text: modelData.t
                        onClicked: {
                            trackList.rowHeight = modelData.v;
                            trackList.saveView();
                        }
                    }
                }
            }
            // Waveform width
            Row {
                spacing: 8

                Text {
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(17 * root.s)
                    height: Math.round(44 * root.s)
                    text: "WAVEFORM SIZE"
                    verticalAlignment: Text.AlignVCenter
                    width: Math.round(170 * root.s)
                }
                Repeater {
                    model: [{"t": "SMALL", "v": 90}, {"t": "MEDIUM", "v": 150}, {"t": "LARGE", "v": 220}]

                    SButton {
                        required property var modelData

                        active: trackList.waveWidth === modelData.v
                        text: modelData.t
                        onClicked: {
                            trackList.waveWidth = modelData.v;
                            trackList.saveView();
                        }
                    }
                }
            }
            // Which track information is shown
            Text {
                color: "#8a8a8a"
                font.pixelSize: Math.round(15 * root.s)
                text: "SHOW IN THE LIST"
            }
            Flow {
                spacing: 8
                width: parent.width

                Repeater {
                    model: ["Waveform", "Artist", "Album", "Year", "Bpm", "Key", "Stars", "File Type", "Bitrate"]

                    SButton {
                        required property string modelData

                        active: modelData === "Waveform" ? trackList.waveWidth > 0 : trackList.hiddenColumns.indexOf(modelData) < 0
                        text: modelData.toUpperCase()
                        onClicked: {
                            if (modelData === "Waveform") {
                                // on: the width chosen last (MEDIUM when none), off: width 0
                                if (trackList.waveWidth > 0) {
                                    trackList.lastWaveWidth = trackList.waveWidth;
                                    trackList.waveWidth = 0;
                                } else {
                                    trackList.waveWidth = trackList.lastWaveWidth > 0 ? trackList.lastWaveWidth : 150;
                                }
                                trackList.saveView();
                            } else {
                                trackList.toggleColumn(modelData);
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- TRACK FILTER ----
    Popup {
        id: filterPopup

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: true
        padding: 14
        width: Math.min(Overlay.overlay ? Overlay.overlay.width - 20 : 900, Math.round(900 * root.s))

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        // One small button (also the +/- steps).
        component FButton: Rectangle {
            id: fb

            property bool active: false
            property color activeColor: "#27a8e0"
            property alias text: fbText.text
            signal clicked

            border.color: fb.active ? fb.activeColor : "#4a4a4a"
            color: fbTap.pressed ? "#3a3a3a" : (fb.active ? Qt.alpha(fb.activeColor, 0.18) : "#202020")
            height: Math.round(44 * root.s)
            width: Math.max(Math.round(52 * root.s), fbText.implicitWidth + 24)

            Text {
                id: fbText

                anchors.centerIn: parent
                color: fb.active ? fb.activeColor : "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(17 * root.s)
            }
            TapHandler {
                id: fbTap

                onTapped: fb.clicked()
            }
        }

        Column {
            spacing: Math.round(10 * root.s)
            width: parent.width

            Row {
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(22 * root.s)
                    text: "TRACK FILTER"
                }
                FButton {
                    text: "RESET"
                    onClicked: root.resetFilter()
                }
                FButton {
                    text: "CLOSE"
                    onClicked: filterPopup.close()
                }
            }
            // BPM
            Row {
                spacing: 8

                FButton {
                    active: root.filterBpmOn
                    text: "BPM"
                    onClicked: {
                        root.filterBpmOn = !root.filterBpmOn;
                        root.applyFilter();
                    }
                }
                FButton {
                    text: "\u2212"
                    onClicked: {
                        root.filterBpm = Math.max(40, root.filterBpm - 1);
                        root.filterBpmOn = true;
                        root.applyFilter();
                    }
                }
                Text {
                    color: root.filterBpmOn ? "#ffffff" : "#8a8a8a"
                    font.bold: true
                    font.pixelSize: Math.round(22 * root.s)
                    height: Math.round(44 * root.s)
                    horizontalAlignment: Text.AlignHCenter
                    text: root.filterBpm.toFixed(1)
                    verticalAlignment: Text.AlignVCenter
                    width: Math.round(90 * root.s)
                }
                FButton {
                    text: "+"
                    onClicked: {
                        root.filterBpm = Math.min(250, root.filterBpm + 1);
                        root.filterBpmOn = true;
                        root.applyFilter();
                    }
                }
                Text {
                    color: "#8a8a8a"
                    font.pixelSize: Math.round(17 * root.s)
                    height: Math.round(44 * root.s)
                    leftPadding: 12
                    text: "RANGE"
                    verticalAlignment: Text.AlignVCenter
                }
                Repeater {
                    model: [3, 6, 10, 16]

                    FButton {
                        required property int modelData

                        active: root.filterBpmRange === modelData
                        text: "\u00b1" + modelData + "%"
                        onClicked: {
                            root.filterBpmRange = modelData;
                            root.applyFilter();
                        }
                    }
                }
                FButton {
                    text: "MASTER"
                    onClicked: root.takeMasterBpm()
                }
            }
            // KEY
            Row {
                spacing: 8

                FButton {
                    active: root.filterKeyOn
                    text: "KEY"
                    onClicked: {
                        root.filterKeyOn = !root.filterKeyOn;
                        root.applyFilter();
                    }
                }
                FButton {
                    text: "MASTER"
                    onClicked: root.takeMasterKey()
                }
                Text {
                    color: "#8a8a8a"
                    font.pixelSize: Math.round(15 * root.s)
                    height: Math.round(44 * root.s)
                    leftPadding: 8
                    text: "blue = chosen,  green = goes with it"
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Grid {
                columns: 12
                spacing: 4

                Repeater {
                    model: root.camelotKeys

                    Rectangle {
                        id: keyCell

                        required property string modelData
                        readonly property bool chosen: root.filterKey === modelData
                        readonly property bool related: root.filterKeyOn && !chosen && root.relatedKeys(root.filterKey).indexOf(modelData) >= 0

                        border.color: chosen ? "#27a8e0" : (related ? "#2fe05a" : "#4a4a4a")
                        color: chosen ? Qt.alpha("#27a8e0", 0.25) : (related ? Qt.alpha("#2fe05a", 0.22) : "#202020")
                        height: Math.round(44 * root.s)
                        width: Math.floor((filterPopup.width - 28 - 11 * 4) / 12)

                        Text {
                            anchors.centerIn: parent
                            color: keyCell.chosen ? "#27a8e0" : (keyCell.related ? "#2fe05a" : "#c0c0c0")
                            font.bold: true
                            font.pixelSize: Math.round(16 * root.s)
                            text: trackList.formatKey(keyCell.modelData)
                        }
                        TapHandler {
                            onTapped: {
                                // Tapping the chosen key again switches the key filter off.
                                if (keyCell.chosen && root.filterKeyOn) {
                                    root.filterKeyOn = false;
                                } else {
                                    root.filterKey = keyCell.modelData;
                                    root.filterKeyOn = true;
                                }
                                root.applyFilter();
                            }
                        }
                    }
                }
            }
            // STARS
            Row {
                spacing: 8

                Text {
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(17 * root.s)
                    height: Math.round(44 * root.s)
                    text: "STARS"
                    verticalAlignment: Text.AlignVCenter
                    width: Math.round(70 * root.s)
                }
                Repeater {
                    model: 6

                    FButton {
                        required property int index

                        active: root.filterRating === index
                        text: index === 0 ? "ANY" : "\u2605".repeat(index) + " +"
                        onClicked: {
                            root.filterRating = index;
                            root.applyFilter();
                        }
                    }
                }
            }
            // COLOR
            Row {
                spacing: 8

                Text {
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(17 * root.s)
                    height: Math.round(44 * root.s)
                    text: "COLOR"
                    verticalAlignment: Text.AlignVCenter
                    width: Math.round(70 * root.s)
                }
                FButton {
                    active: root.filterColor < 0
                    text: "ANY"
                    onClicked: {
                        root.filterColor = -1;
                        root.applyFilter();
                    }
                }
                Repeater {
                    model: root.filterColors

                    Rectangle {
                        required property int index
                        required property var modelData

                        border.color: root.filterColor === index ? "#ffffff" : "#4a4a4a"
                        border.width: root.filterColor === index ? 3 : 1
                        color: "#" + ("000000" + modelData.rgb.toString(16)).slice(-6)
                        height: Math.round(44 * root.s)
                        width: Math.round(60 * root.s)

                        TapHandler {
                            onTapped: {
                                root.filterColor = root.filterColor === parent.index ? -1 : parent.index;
                                root.applyFilter();
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- SORT menu ----
    Popup {
        id: sortPopup

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: true
        padding: 16
        width: Math.round(420 * root.s)

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            spacing: 8
            width: parent.width

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(22 * root.s)
                text: "SORT"
            }
            Repeater {
                model: [
                    { label: "TITLE", column: root.columnByLabel("Title") },
                    { label: "ARTIST", column: root.columnByLabel("Artist") },
                    { label: "ALBUM", column: root.columnByLabel("Album") },
                    { label: "YEAR", column: root.columnByLabel("Year") },
                    { label: "BPM", column: root.columnByLabel("Bpm") },
                    { label: "KEY", column: root.columnByLabel("Key") },
                    { label: "STARS", column: root.columnByLabel("Stars") }
                ]

                Rectangle {
                    required property var modelData

                    border.color: root.sortColumn === modelData.column ? "#1fb0f0" : "#3a3a3a"
                    color: sortItemTap.pressed ? "#3a3a3a" : (root.sortColumn === modelData.column ? "#10293f" : "#202020")
                    height: Math.round(52 * root.s)
                    width: parent.width

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: Math.round(20 * root.s)
                        text: parent.modelData.label
                    }
                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        color: "#1fb0f0"
                        font.pixelSize: Math.round(20 * root.s)
                        text: root.sortColumn !== parent.modelData.column ? ""
                                : (root.sortOrder === Qt.AscendingOrder ? "A → Z" : "Z → A")
                    }
                    TapHandler {
                        id: sortItemTap

                        onTapped: root.sortBy(parent.modelData.column)
                    }
                }
            }
        }
    }

    // ---- Confirmation ----
    Popup {
        id: confirmPopup

        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: true
        padding: 20
        width: Math.round(460 * root.s)

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            spacing: 18
            width: parent.width

            Text {
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Math.round(22 * root.s)
                horizontalAlignment: Text.AlignHCenter
                text: root.confirmText
                width: parent.width
                wrapMode: Text.WordWrap
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Repeater {
                    model: ["CANCEL", "YES"]

                    Rectangle {
                        required property string modelData

                        border.color: modelData === "YES" ? "#ff6a6a" : "#5a5a5a"
                        color: confirmTap.pressed ? "#3a3a3a" : "#202020"
                        height: Math.round(56 * root.s)
                        width: Math.round(160 * root.s)

                        Text {
                            anchors.centerIn: parent
                            color: parent.modelData === "YES" ? "#ff6a6a" : "#ffffff"
                            font.bold: true
                            font.pixelSize: Math.round(20 * root.s)
                            text: parent.modelData
                        }
                        TapHandler {
                            id: confirmTap

                            onTapped: {
                                confirmPopup.close();
                                if (parent.modelData === "YES" && root.confirmAction)
                                    root.confirmAction();
                            }
                        }
                    }
                }
            }
        }
    }
}
