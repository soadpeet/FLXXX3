import "../" as Skin
import "../AdvSettings"
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import QtQuick.Window
import "../Theme"
import "." as DJ

// Single-view touch UI for the FLXXX3, modelled on the XDJ-RX3
// performance screen: status bar, overview and main waveforms of both decks,
// a panel per deck. Pressing the controller's BROWSE knob lays the library over
// the waveform area, pressing it again closes it; turning it scrolls the list.
// The library also closes after a track was loaded or after a few seconds
// without browsing.
Item {
    id: root

    required property ApplicationWindow applicationWindow
    // main.qml reads this property; there is no menu bar on Android.
    readonly property var menuBar: null
    property bool browserOpen: false
    // Which part of the screen the library covers: 0 = all, 1 = left half, 2 = right half.
    property int browserSide: 0
    // Top button that opened the library ("BROWSE", "SOURCE", ...).
    property string browserMode: "BROWSE"
    // Utility ("SHORTCUT") screen open.
    property bool utilityOpen: false
    property bool advancedOpen: false
    // Waveform zoom after the start (ADVANCED SETTINGS); changing it applies it at once.
    readonly property real zoomStartValue: AdvSettings.values.zoomStart
    onZoomStartValueChanged: {
        pinchZoom1.value = zoomStartValue;
        pinchZoom2.value = zoomStartValue;
    }
    // Time display of both decks: remaining (true) or elapsed (false).
    property bool showRemain: true
    // Row below the waveforms: hotcues (false) or Beat FX presets (true).
    property bool fxPresetMode: false
    // Key display: classic notation (Am) or Camelot (8A).
    property bool keyCamelot: true
    // Screen layout (UTILITY): false = XDJ view (both waveforms stacked, a panel per
    // deck below), true = CDJ view (the screen is split in two halves, one per deck:
    // deck panel on top, the big waveform below, hotcues at the bottom).
    property bool cdjView: false
    // Beat match aid above the waveforms, CDJ view only (UTILITY): 0 = off, 1 = WAVEFORM of the
    // other deck, 2 = PHASE METER. The main waveform gets smaller by its height.
    property int beatMatchMode: 1
    readonly property int beatMatchEffective: cdjView ? beatMatchMode : 0
    // The row above the main waveform (bars, WAVEFORM / PHASE of the other deck or MASTER PLAYER)
    // exists in the CDJ view in every mode; OFF only shows the bars and the tag.
    readonly property real beatMatchHeight: cdjView ? Math.round(waveformHeight * (beatMatchMode === 1
            ? 0.5 : beatMatchMode === 2 ? 0.3 : 0.22)) : 0
    readonly property real beatMatchReserved: beatMatchHeight
    onBeatMatchModeChanged: saveSetting("beatMatchModeV2", beatMatchMode)
    onCdjViewChanged: saveSetting("cdjView", cdjView ? "1" : "0")
    // Quantize beat value shown on the decks (1/8, 1/4, 1/2, 1).
    property string quantizeBeat: "1/4"
    // AUTO CUE of both decks (UTILITY menu).
    property bool autoCue: false
    onAutoCueChanged: {
        saveSetting("autoCue", autoCue ? "1" : "0");
        autoCue1.value = autoCue ? 1 : 0;
        autoCue2.value = autoCue ? 1 : 0;
    }
    // Settings that survive a restart (stored in the Mixxx config file).
    property bool settingsReady: false
    function saveSetting(key, value) {
        if (root.settingsReady)
            Mixxx.Config.setAndroidSetting(key, String(value));
    }
    onShowRemainChanged: saveSetting("showRemain", showRemain ? "1" : "0")
    onKeyCamelotChanged: saveSetting("keyCamelot", keyCamelot ? "1" : "0")
    // Quantize beat value: grid steps per beat for the engine of both decks.
    function applyQuantizeBeat() {
        const steps = {"1/8": 8, "1/4": 4, "1/2": 2, "1": 1}[root.quantizeBeat] || 4;
        quantizeSteps1.value = steps;
        quantizeSteps2.value = steps;
    }
    Mixxx.ControlProxy { id: quantizeSteps1; group: "[Channel1]"; key: "quantize_subdivision" }
    Mixxx.ControlProxy { id: quantizeSteps2; group: "[Channel2]"; key: "quantize_subdivision" }
    onQuantizeBeatChanged: {
        saveSetting("quantizeBeat", quantizeBeat);
        applyQuantizeBeat();
    }
    Mixxx.ControlProxy {
        id: headSplitProxy

        group: "[Master]"
        key: "headSplit"

        onValueChanged: value => root.saveSetting("headSplit", value > 0 ? "1" : "0")
    }
    Mixxx.ControlProxy {
        id: monoMixdownProxy

        group: "[Master]"
        key: "mono_mixdown"

        onValueChanged: value => root.saveSetting("monoMixdown", value > 0 ? "1" : "0")
    }
    // MASTER (tempo reference): the deck that plays; with two playing decks the
    // one that is already master stays until it stops, then the other one
    // becomes master. A deck that is loaded while nothing plays becomes master.
    // BEAT SYNC on the controller makes a deck master as well (controller script).
    readonly property int masterDeck: masterDeckProxy.value
    function setMaster(deck) {
        masterDeckProxy.value = deck;
    }
    Mixxx.ControlProxy { id: masterDeckProxy; group: "[AndroidDJ]"; key: "master_deck" }
    // A deck that follows (SYNC on) takes the tempo of the MASTER deck: the
    // master is made the leader of the engine while the other deck has SYNC on.
    function updateSyncLeader() {
        const master = root.masterDeck;
        if (master !== 1 && master !== 2)
            return;
        const masterLeader = master === 1 ? masterLeader1 : masterLeader2;
        const otherLeader = master === 1 ? masterLeader2 : masterLeader1;
        const otherSync = (master === 1 ? syncEnabled2 : syncEnabled1).value > 0;
        if (otherLeader.value > 0)
            otherLeader.value = 0;
        if (otherSync && masterLeader.value <= 0)
            masterLeader.value = 1;
        else if (!otherSync && masterLeader.value > 0)
            masterLeader.value = 0;
    }
    onMasterDeckChanged: updateSyncLeader()
    Mixxx.ControlProxy { id: masterLeader1; group: "[Channel1]"; key: "sync_leader" }
    Mixxx.ControlProxy { id: masterLeader2; group: "[Channel2]"; key: "sync_leader" }
    Mixxx.ControlProxy {
        id: syncEnabled1

        group: "[Channel1]"
        key: "sync_enabled"

        onValueChanged: root.updateSyncLeader()
    }
    Mixxx.ControlProxy {
        id: syncEnabled2

        group: "[Channel2]"
        key: "sync_enabled"

        onValueChanged: root.updateSyncLeader()
    }
    function deckPlaying(deck) {
        return (deck === 1 ? masterPlay1.value : masterPlay2.value) > 0;
    }
    function masterPlayChanged(deck) {
        const other = deck === 1 ? 2 : 1;
        if (deckPlaying(deck)) {
            if (!deckPlaying(other))
                setMaster(deck);
        } else if (deckPlaying(other)) {
            setMaster(other);
        }
    }
    function masterTrackLoaded(deck) {
        if (!deckPlaying(1) && !deckPlaying(2))
            setMaster(deck);
    }
    Mixxx.ControlProxy {
        id: masterPlay1

        group: "[Channel1]"
        key: "play"

        onValueChanged: root.masterPlayChanged(1)
    }
    Mixxx.ControlProxy {
        id: masterPlay2

        group: "[Channel2]"
        key: "play"

        onValueChanged: root.masterPlayChanged(2)
    }
    Mixxx.ControlProxy {
        id: masterLoaded1

        group: "[Channel1]"
        key: "track_loaded"

        onValueChanged: value => {
            if (value > 0)
                root.masterTrackLoaded(1);
        }
    }
    Mixxx.ControlProxy {
        id: masterLoaded2

        group: "[Channel2]"
        key: "track_loaded"

        onValueChanged: value => {
            if (value > 0)
                root.masterTrackLoaded(2);
        }
    }
    // The output level that reaches the controller is fixed at 0 dB (master gain 1).
    Mixxx.ControlProxy { id: masterGainProxy; group: "[Master]"; key: "gain" }
    Mixxx.ControlProxy { id: eqModeProxy; group: "[AndroidDJ]"; key: "eq_mode" }
    // Screen brightness: 0 NIGHT (dim), 1 NORMAL (system setting), 2 OUTDOOR (brightest).
    Mixxx.ControlProxy { id: brightnessProxy; group: "[AndroidDJ]"; key: "brightness" }
    function applyBrightness() {
        const level = Math.round(brightnessProxy.value);
        Mixxx.DeviceStatus.setScreenBrightness(level === 2 ? 1.0 : -1.0);
    }
    Connections {
        function onValueChanged() {
            Mixxx.Config.setAndroidSetting("brightness", String(Math.round(brightnessProxy.value)));
            root.applyBrightness();
        }

        target: brightnessProxy
    }
    Component.onCompleted: {
        masterGainProxy.value = Math.pow(10, -(AdvSettings.values.headroom || 0) / 20);
        // Each deck zooms on its own (without this both waveforms use the zoom of deck 1).
        Mixxx.Config.waveformZoomSynchronization = false;
        // Waveform zoom: only when ADVANCED SETTINGS changed it from the factory value (otherwise the
        // zoom of the last session stays).
        if (AdvSettings.values.zoomStart !== AdvSettings.definition("zoomStart").def) {
            pinchZoom1.value = AdvSettings.values.zoomStart;
            pinchZoom2.value = AdvSettings.values.zoomStart;
        }
        const savedBrightness = parseInt(Mixxx.Config.androidSetting("brightness", "1"));
        brightnessProxy.value = isNaN(savedBrightness) ? 1 : savedBrightness;
        root.applyBrightness();
        Mixxx.DeviceStatus.lockScreen();
        // Mixer: ISO (kill at the end stop) is the default, EQ is saved.
        eqModeProxy.value = Mixxx.Config.androidSetting("eqMode", "0") === "1" ? 1 : 0;
        // 3BAND is the default look: once, a look saved earlier (e.g. RGB) is replaced.
        if (Mixxx.Config.androidSetting("waveformDefault3band", "0") !== "1") {
            Mixxx.Config.waveformType = Mixxx.WaveformDisplay.Type.Filtered;
            Mixxx.Config.setAndroidSetting("waveformDefault3band", "1");
        }
        root.showRemain = Mixxx.Config.androidSetting("showRemain", "1") === "1";
        root.keyCamelot = Mixxx.Config.androidSetting("keyCamelot", "1") === "1";
        root.cdjView = Mixxx.Config.androidSetting("cdjView", "0") === "1";
        root.beatMatchMode = parseInt(Mixxx.Config.androidSetting("beatMatchModeV2", "1"));
        root.quantizeBeat = Mixxx.Config.androidSetting("quantizeBeat", "1/4");
        root.autoCue = Mixxx.Config.androidSetting("autoCue", "0") === "1";
        root.applyQuantizeBeat();
        autoCue1.value = root.autoCue ? 1 : 0;
        autoCue2.value = root.autoCue ? 1 : 0;
        headSplitProxy.value = Mixxx.Config.androidSetting("headSplit", "0") === "1" ? 1 : 0;
        monoMixdownProxy.value = Mixxx.Config.androidSetting("monoMixdown", "0") === "1" ? 1 : 0;
        root.settingsReady = true;
    }
    Mixxx.ControlProxy { id: autoCue1; group: "[Channel1]"; key: "auto_cue" }
    Mixxx.ControlProxy { id: autoCue2; group: "[Channel2]"; key: "auto_cue" }

    // Activates a top-level entry of the library sidebar (0 = All..., 1 = Rekordbox).
    // The library activates row 1 (the sticks) itself when it is created.
    property int activeSourceRow: 1

    // Source chosen with OPEN on the SOURCE screen: "" (none yet), "USB1", "USB2" or "TABLET".
    // BROWSE, PLAYLIST and SEARCH show only this source; without one they open SOURCE.
    property string chosenSource: ""

    // Sets the library to the chosen source: the sticks list (row 1) limited to the files of
    // that stick, or the tablet folders (row 0) limited to the ACTIVE folders.
    function applySource() {
        const lib = browser.item ? browser.item.library : null;
        if (!lib || root.chosenSource === "")
            return;
        let folders = [];
        let stick = "TABLET";
        if (root.chosenSource === "TABLET") {
            folders = Object.keys(sourceScreen.activeFolders);
            // Folders with a Rekordbox export (e.g. a stick copied to the computer) are read like
            // a stick: if all active folders have one, the stick list shows them (Rekordbox
            // waveforms, BPM, cues, keys). Otherwise the own library as before.
            const exportFolders = sourceScreen.folders.filter(f => f.rekordbox).map(f => String(f.path));
            if (folders.length > 0 && folders.every(f => exportFolders.indexOf(f) >= 0)) {
                root.activateSource(1);
                // The device name of such a folder is its path.
                stick = folders.length === 1 ? folders[0] : "";
            } else {
                root.activateSource(0);
            }
        } else {
            const info = Mixxx.DeviceStatus.stickInfo(root.chosenSource === "USB1" ? 1 : 2);
            stick = info.present && info.id ? String(info.id) : "";
            root.activateSource(1);
            // Location filter: /<uuid>/ on Android (the files are below /storage or
            // /mnt/media_rw), the drive (E:/) on Windows.
            const path = String(info.path || "");
            folders = stick === "" ? [] : [path.startsWith("/") ? "/" + stick : path];
        }
        // Only on a change: a new filter starts the list at the top again.
        if (JSON.stringify(folders) !== JSON.stringify(lib.folderFilter))
            lib.folderFilter = folders;
        lib.stickFilter = stick;
    }
    function chooseSource(kind, title) {
        root.chosenSource = kind;
        root.browserMode = "BROWSE";
        const lib = browser.item ? browser.item.library : null;
        if (lib) {
            root.applySource();
            lib.mode = "BROWSE";
            lib.sourceTitle = title;
            lib.resetBrowse();
        }
        root.openBrowser(root.browserSide);
    }
    // The chosen stick was pulled out: no source any more.
    Connections {
        function onChanged() {
            if ((root.chosenSource === "USB1" && !Mixxx.DeviceStatus.stick1Present)
                    || (root.chosenSource === "USB2" && !Mixxx.DeviceStatus.stick2Present)) {
                root.chosenSource = "";
                if (root.browserOpen && root.browserMode !== "SOURCE" && root.browserMode !== "TAG LIST")
                    root.browserMode = "SOURCE";
            }
        }

        target: Mixxx.DeviceStatus
    }
    // Screens that need a chosen source.
    function needsSource(name) {
        return root.chosenSource === "" && (name === "BROWSE" || name === "PLAYLIST" || name === "SEARCH");
    }

    function activateSource(row) {
        // Activating a source rebuilds the whole table: do it only when the
        // source changes.
        if (row === root.activeSourceRow) {
            return;
        }
        const lib = browser.item ? browser.item.library : null;
        if (lib && lib.sidebar) {
            lib.sidebar.activate(lib.sidebar.index(row, 0));
            root.activeSourceRow = row;
        }
    }
    // CDJ view: the side on which a library button opens the library. Both decks empty: left;
    // one deck loaded: the empty one; both loaded: the side that is not the MASTER.
    function autoBrowserSide() {
        const loaded1 = masterLoaded1.value > 0;
        const loaded2 = masterLoaded2.value > 0;
        if (loaded1 && !loaded2)
            return 2;
        if (!loaded1 && loaded2)
            return 1;
        if (loaded1 && loaded2 && root.masterDeck === 1)
            return 2;
        return 1;
    }
    // side: 0 / undefined = by the rules above (CDJ view), 1 / 2 = chosen by a long press.
    function topButton(name, side) {
        root.advancedOpen = false;
        if (root.needsSource(name))
            name = "SOURCE";
        if (name === "UTILITY") {
            browserIdle.stop();
            root.browserOpen = false;
            root.utilityOpen = !root.utilityOpen;
            return;
        }
        root.utilityOpen = false;
        const wanted = root.cdjView ? (side ? side : root.autoBrowserSide()) : 0;
        // The same button again closes the library, whichever side it is on (a long press chooses
        // the side and opens it again there).
        if (root.browserOpen && root.browserMode === name && !side) {
            browserIdle.stop();
            root.browserOpen = false;
            return;
        }
        root.browserMode = name;
        root.openBrowser(wanted);
        const lib = browser.item ? browser.item.library : null;
        if (lib) {
            lib.mode = name;
        }
        if (name === "PLAYLIST") {
            root.activateSource(1);
        } else if (name === "BROWSE" || name === "SEARCH") {
            root.applySource();
        }
    }
    // side: 0 = the whole screen, 1 / 2 = only the half of deck 1 / 2 (CDJ view).
    function openBrowser(side) {
        root.browserSide = root.cdjView && side ? side : 0;
        root.utilityOpen = false;
        root.browserOpen = true;
        browserIdle.interval = Math.round(AdvSettings.values.menuIdleSec * 1000);
        browserIdle.restart();
    }
    // Turning the knob only keeps an already open library open.
    function keepBrowserOpen() {
        if (root.browserOpen) {
            browserIdle.interval = Math.round(AdvSettings.values.menuIdleSec * 1000);
            browserIdle.restart();
        }
    }
    // After LOAD the library only stays a moment (feedback), then the loaded
    // deck is visible. A longer delay was perceived as "loading takes long".
    function closeBrowserSoon() {
        browserIdle.interval = AdvSettings.values.afterLoadMs;
        browserIdle.restart();
    }

    readonly property real topHeight: Math.max(28, Math.round(height * 0.095))
    // Space below the top bar.
    readonly property real contentHeight: height - topHeight
    // CDJ view (like the CDJ-3000 screen): per deck one tall panel with the title on top,
    // the big waveform below it, then time / tempo / BPM and the overview.
    // The parts of the panel keep the size they have in the XDJ view.
    readonly property real cdjLayoutHeight: Math.round(height * 0.33)
    readonly property real cdjPanelHeight: contentHeight - hotcueHeight - 4
    // CDJ view: height of the block below the main waveform (TRACK, time, tempo, BPM, overview).
    // About 29 % of the width of a deck (the CDJ screen of the PDF is twice as wide as a deck here).
    readonly property real cdjLowerHeight: Math.round(width / 2 * 0.29)
    // The rest of the panel is the main waveform with the beat match row and the loop strip.
    readonly property real cdjGap: cdjPanelHeight - Math.round(3.2 * Math.max(8, cdjLayoutHeight / 14)) - cdjLowerHeight
    // Strip under the main waveform for the loop size (CDJ view).
    // Sizes after page 2 of the layout (relative to the deck width).
    readonly property real cdjLoopStrip: Math.max(16, Math.round(width / 2 * 0.032))
    // Height of the title row of the panel (same formula as DeckPanel).
    // Plus a little space so that the DECK number in the left column stays visible
    // above the side buttons.
    readonly property real cdjPad: 12
    readonly property real cdjTitleHeight: Math.round(3.2 * Math.max(8, cdjLayoutHeight / 14)) + cdjPad
    readonly property real hotcueHeight: cdjView
            ? Math.max(12, Math.round(contentHeight * 0.06))
            : Math.max(12, Math.round(height * 0.035))
    // Height of ONE waveform in the XDJ view; in the CDJ view half of the (side by side)
    // waveforms, so that the side buttons (two per edge) keep their size.
    readonly property real waveformHeight: cdjView
            ? Math.round((cdjGap - cdjPad) / 2)
            : Math.round(height * 0.27)

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    // Any touch keeps an open library / SOURCE screen open (passive handler).
    PointHandler {
        acceptedDevices: PointerDevice.TouchScreen

        onActiveChanged: root.keepBrowserOpen()
    }
    // The controller's BROWSE knob (rotate/press) and the LOAD buttons.
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveVertical"

        // Library closed: turning the BROWSE knob zooms the waveforms of both
        // decks (clockwise = zoom in), like on the XDJ-RX3. Library open: it
        // scrolls the list.
        onValueChanged: {
            if (root.browserOpen) {
                root.keepBrowserOpen();
            } else if (value !== 0) {
                // CDJ view, SHIFT of a deck held: only the waveform of that deck zooms.
                const only = root.cdjView ? shiftDeck.value : 0;
                const zoomIn = value > 0;
                if (only !== 2) {
                    (zoomIn ? zoomIn1 : zoomOut1).trigger();
                }
                if (only !== 1) {
                    (zoomIn ? zoomIn2 : zoomOut2).trigger();
                }
            }
        }
    }
    // Which SHIFT button of the controller is held: 0 = none, 1 = deck 1, 2 = deck 2.
    Mixxx.ControlProxy { id: shiftDeck; group: "[AndroidDJ]"; key: "shift_deck" }
    Mixxx.ControlProxy { id: zoomIn1; group: "[Channel1]"; key: "waveform_zoom_down" }
    Mixxx.ControlProxy { id: zoomOut1; group: "[Channel1]"; key: "waveform_zoom_up" }
    Mixxx.ControlProxy { id: zoomIn2; group: "[Channel2]"; key: "waveform_zoom_down" }
    Mixxx.ControlProxy { id: zoomOut2; group: "[Channel2]"; key: "waveform_zoom_up" }
    Mixxx.ControlProxy {
        group: "[Library]"
        key: "MoveFocusForward"

        // Pressing the knob toggles the library overlay.
        onValueChanged: {
            if (value > 0) {
                if (root.browserOpen) {
                    browserIdle.stop();
                    root.browserOpen = false;
                } else if (root.needsSource("BROWSE")) {
                    root.browserMode = "SOURCE";
                    root.openBrowser();
                } else {
                    root.browserMode = "BROWSE";
                    root.openBrowser();
                    const lib = browser.item ? browser.item.library : null;
                    if (lib) {
                        lib.mode = "BROWSE";
                        root.applySource();
                    }
                }
            }
        }
    }
    // LOAD of a deck: library open = it loads (the library closes soon after); library closed in
    // the CDJ view = the library opens on the side of that deck only.
    function loadPressed(deck) {
        if (root.browserOpen) {
            root.closeBrowserSoon();
        } else if (root.cdjView && root.needsSource("BROWSE")) {
            root.browserMode = "SOURCE";
            root.openBrowser(deck);
        } else if (root.cdjView) {
            root.browserMode = "BROWSE";
            root.openBrowser(deck);
            const lib = browser.item ? browser.item.library : null;
            if (lib) {
                lib.mode = "BROWSE";
                root.applySource();
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Channel1]"
        key: "LoadSelectedTrack"

        onValueChanged: if (value > 0) root.loadPressed(1)
    }
    Mixxx.ControlProxy {
        group: "[Channel2]"
        key: "LoadSelectedTrack"

        onValueChanged: if (value > 0) root.loadPressed(2)
    }
    Timer {
        id: browserIdle

        interval: 20000
        onTriggered: root.browserOpen = false
    }
    DJ.TopBar {
        id: topBar

        height: root.topHeight

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        activeButton: root.utilityOpen ? "UTILITY" : (root.browserOpen ? root.browserMode : "")

        onButtonClicked: name => root.topButton(name)
        onButtonLongPressed: name => {
            if (root.cdjView && name !== "UTILITY") {
                sidePicker.buttonName = name;
                sidePicker.open();
            }
        }
        onCloseRequested: quitDialog.open()
    }
    // Width of the side buttons at the left and right edge of the waveforms.
    readonly property real sideButtonWidth: 48
    // CDJ view: the panel that is open over each waveform ("" / "LOOP" / "KEY" / "JUMP") and the
    // INFO of a track. A panel closes itself after a few seconds without touches.
    property string popup1: ""
    property string popup2: ""
    property int infoDeck: 0
    function togglePopup(deck, kind) {
        if (deck === 1)
            root.popup1 = root.popup1 === kind ? "" : kind;
        else
            root.popup2 = root.popup2 === kind ? "" : kind;
        popupTimer.restart();
    }
    function popupActivity(deck) {
        popupTimer.restart();
    }
    Timer {
        id: popupTimer

        interval: Math.max(5000, Math.round(AdvSettings.values.windowSec * 1000) * 2)
        onTriggered: {
            root.popup1 = "";
            root.popup2 = "";
        }
    }
    // A deck whose waveform lies behind the library or a menu is not drawn at all: hidden
    // waveforms still cost GUI time (scene graph sync), which made the library lag.
    function waveCovered(deckIndex) {
        if (root.utilityOpen || root.advancedOpen)
            return true;
        return root.browserOpen && (root.browserSide === 0 || root.browserSide === deckIndex + 1);
    }
    // Waveforms of both decks stacked on the left, FX panel on the right.
    Item {
        id: waveArea

        height: root.waveformHeight * 2
        // CDJ view: lies over the gap of the deck panels.
        z: root.cdjView ? 5 : 0

        anchors {
            left: parent.left
            right: parent.right
            top: topBar.bottom
            topMargin: root.cdjView ? root.cdjTitleHeight + 2 : 0
        }

        Repeater {
            model: 2

            Skin.WaveformDisplay {
                required property int index

                // No touches for the waveforms below UTILITY / ADVANCED SETTINGS.
                enabled: !root.advancedOpen && !root.utilityOpen
                // The waveform next to an open library redraws more slowly: browsing gets the time.
                frameRateOverride: root.browserOpen ? 20 : 0
                visible: !root.waveCovered(index)
                group: "[Channel" + (index + 1) + "]"
                // XDJ view: stacked, full width. CDJ view: side by side, full height.
                height: (root.cdjView ? root.waveformHeight * 2 - root.cdjLoopStrip : root.waveformHeight) - root.beatMatchReserved
                width: root.cdjView ? Math.round(parent.width / 2) - 1 : parent.width
                x: root.cdjView ? index * (Math.round(parent.width / 2) + 1) : 0
                y: (root.cdjView ? 0 : index * root.waveformHeight) + root.beatMatchReserved
            }
        }
        // Beat-matching aid: strokes at the beats of the other deck above each waveform.
        Repeater {
            // CDJ view only: no strip objects (and no control connections) in the XDJ view.
            model: root.cdjView ? 2 : 0

            DJ.BeatMatchStrip {
                required property int index

                group: "[Channel" + (index + 1) + "]"
                isMaster: root.masterDeck === index + 1
                leftInset: index === 0 ? root.sideButtonWidth : 0
                tagFont: Math.max(9, Math.round(root.width / 2 * 0.016))
                visible: !root.waveCovered(index) && (isMaster ? ownActive : otherActive)
                height: root.beatMatchHeight
                mode: root.beatMatchMode
                otherGroup: "[Channel" + (2 - index) + "]"
                width: root.cdjView ? Math.round(parent.width / 2) - 1 : parent.width
                x: root.cdjView ? index * (Math.round(parent.width / 2) + 1) : 0
                y: root.cdjView ? 0 : index * root.waveformHeight
            }
        }
        // CDJ view: the loop size chosen with BEAT LOOP at the bottom of each main waveform
        // (orange while a loop runs).
        Repeater {
            model: root.cdjView ? 2 : 0

            Item {
                id: loopLabel

                required property int index

                height: loopLabelText.implicitHeight
                visible: !root.waveCovered(index) && loopLabelLoaded.value > 0
                width: Math.round(parent.width / 2) - 1
                x: index * (Math.round(parent.width / 2) + 1)
                y: parent.height - root.cdjLoopStrip + Math.round((root.cdjLoopStrip - height) / 2)

                Mixxx.ControlProxy { id: loopLabelSize; group: "[Channel" + (loopLabel.index + 1) + "]"; key: "beatloop_size" }
                Mixxx.ControlProxy { id: loopLabelEnabled; group: "[Channel" + (loopLabel.index + 1) + "]"; key: "loop_enabled" }
                Mixxx.ControlProxy { id: loopLabelLoaded; group: "[Channel" + (loopLabel.index + 1) + "]"; key: "track_loaded" }
                Text {
                    id: loopLabelText

                    anchors.horizontalCenter: parent.horizontalCenter
                    color: loopLabelEnabled.value > 0 ? "#ff9a2e" : "#9a9a9a"
                    font.pixelSize: Math.max(11, Math.round(root.width / 2 * 0.02))
                    text: loopLabelSize.value === 0.25 ? "1/4" : (loopLabelSize.value === 0.5 ? "1/2" : String(loopLabelSize.value))
                }
            }
        }
        // CDJ view: the panels of BEAT LOOP / KEY SHIFT / BEAT JUMP over the top of a waveform.
        Repeater {
            model: root.cdjView ? 2 : 0

            DJ.DeckPopup {
                required property int index

                group: "[Channel" + (index + 1) + "]"
                height: Math.round(root.waveformHeight * 0.5)
                keyCamelot: root.keyCamelot
                keyText: (index === 0 ? deckPanel1 : deckPanel2).track ? (index === 0 ? deckPanel1 : deckPanel2).track.keyText : ""
                kind: (index === 0 ? root.popup1 : root.popup2) || "LOOP"
                shiftedKey: (index === 0 ? deckPanel1 : deckPanel2).shiftedKey
                u: Math.round(root.cdjLayoutHeight / 14)
                visible: (index === 0 ? root.popup1 : root.popup2) !== "" && !root.waveCovered(index)
                // The side buttons (FILTER / JOGWHEEL left, DELAY / BRIGHTNESS right) keep their room.
                width: Math.round(parent.width / 2) - 1 - root.sideButtonWidth
                x: index * (Math.round(parent.width / 2) + 1) + (index === 0 ? root.sideButtonWidth : 0)
                y: 0
                z: 6

                onActivity: root.popupActivity(index + 1)
            }
        }
        // Two fingers: spread = zoom in, pinch = zoom out. Only the deck whose waveform
        // lies under the fingers when they touch down is zoomed.
        PinchHandler {
            id: pinch

            property int deck: 0
            property real startZoom: 3

            enabled: !root.advancedOpen && !root.utilityOpen
            maximumPointCount: 2
            minimumPointCount: 2
            target: null

            onActiveChanged: {
                if (!active)
                    return;
                const p = centroid.position;
                deck = root.cdjView ? (p.x < waveArea.width / 2 ? 0 : 1)
                                    : (p.y < root.waveformHeight ? 0 : 1);
                startZoom = (deck === 0 ? pinchZoom1 : pinchZoom2).value;
            }
            onActiveScaleChanged: {
                if (!active)
                    return;
                // Smaller zoom value = more detail (like the zoom buttons).
                const zoom = Math.max(AdvSettings.values.zoomMin, Math.min(AdvSettings.values.zoomMax, startZoom / activeScale));
                (deck === 0 ? pinchZoom1 : pinchZoom2).value = zoom;
            }
        }
        Mixxx.ControlProxy { id: pinchZoom1; group: "[Channel1]"; key: "waveform_zoom" }
        Mixxx.ControlProxy { id: pinchZoom2; group: "[Channel2]"; key: "waveform_zoom" }
    }
    // Color FX: the name of the selected one stands vertically at the left edge
    // of the upper waveform; tapping it opens the list.
    DJ.ColorFxButton {
        height: root.waveformHeight
        width: Math.max(28, Math.round(root.width * 0.034))
        z: 20

        anchors {
            left: parent.left
            top: waveArea.top
        }
    }
    // JOGWHEEL: below the Color FX button, on the lower waveform.
    Rectangle {
        border.color: jogTap.pressed ? "#1f8fe0" : "#4a4a4a"
        color: jogTap.pressed ? "#3a3a3a" : "#202020"
        height: root.waveformHeight
        // solid: the waveform behind must not shine through
        enabled: !root.advancedOpen && !root.utilityOpen
        opacity: 1.0
        width: Math.max(28, Math.round(root.width * 0.034))
        z: 20

        anchors {
            left: parent.left
            top: waveArea.top
            topMargin: root.waveformHeight
        }

        Text {
            anchors.centerIn: parent
            color: "#c0c0c0"
            elide: Text.ElideRight
            font.bold: true
            // Smaller on low screens (phones), so that the whole word fits.
            font.pixelSize: Math.round(Math.min(parent.width * 0.5, (parent.height - 8) / (text.length * 0.66)))
            horizontalAlignment: Text.AlignHCenter
            rotation: -90
            text: "JOGWHEEL"
            width: parent.height - 8
        }
        TapHandler {
            id: jogTap

            onTapped: jogwheelMenu.openWindow()
        }
    }
    // The window lies over the JOGWHEEL button (left edge of the lower waveform).
    DJ.JogwheelMenu {
        id: jogwheelMenu

        height: Math.round(root.waveformHeight * 1.1)
        width: Math.round(Math.min(root.width * 0.46, 540))
        x: 0
        y: waveArea.y + root.waveformHeight
    }
    // BRIGHTNESS: below the Beat FX button, on the lower waveform (right edge).
    Rectangle {
        border.color: brightnessTap.pressed ? "#1f8fe0" : "#4a4a4a"
        color: brightnessTap.pressed ? "#3a3a3a" : "#202020"
        height: root.waveformHeight
        // solid: the waveform behind must not shine through
        enabled: !root.advancedOpen && !root.utilityOpen
        opacity: 1.0
        width: Math.max(28, Math.round(root.width * 0.034))
        z: 20

        anchors {
            right: parent.right
            top: waveArea.top
            topMargin: root.waveformHeight
        }

        Text {
            anchors.centerIn: parent
            color: "#c0c0c0"
            elide: Text.ElideRight
            font.bold: true
            // Smaller on low screens (phones), so that the whole word fits.
            font.pixelSize: Math.round(Math.min(parent.width * 0.5, (parent.height - 8) / (text.length * 0.66)))
            horizontalAlignment: Text.AlignHCenter
            rotation: -90
            text: "BRIGHTNESS"
            width: parent.height - 8
        }
        TapHandler {
            id: brightnessTap

            onTapped: brightnessMenu.openWindow()
        }
    }
    // The window lies over the BRIGHTNESS button.
    DJ.BrightnessMenu {
        id: brightnessMenu

        height: root.waveformHeight
        width: Math.round(Math.min(root.width * 0.36, 420))
        x: root.width - width
        y: waveArea.y + root.waveformHeight
    }
    DJ.FxPresetBand {
        height: root.hotcueHeight
        visible: root.fxPresetMode

        // XDJ view: below the waveforms; CDJ view: at the bottom edge of the screen.
        y: root.cdjView ? root.height - height : waveArea.y + waveArea.height + 2

        anchors {
            left: parent.left
            right: parent.right
        }
    }
    // Beat FX: the name of the selected one stands vertically at the right edge
    // of the upper waveform; the window with the settings lies over the button.
    DJ.BeatFxButton {
        height: root.waveformHeight
        panelHeight: root.waveformHeight * 2
        panelWidth: Math.round(root.width * 0.2)
        presetMode: root.fxPresetMode
        width: Math.max(28, Math.round(root.width * 0.034))
        z: 20

        onPresetModeRequested: mode => root.fxPresetMode = mode

        anchors {
            right: parent.right
            top: waveArea.top
        }
    }
    // Hotcues of both decks in one row each (A..H side by side).
    Row {
        id: hotcueBand

        height: root.hotcueHeight
        spacing: 2
        visible: !root.fxPresetMode

        y: root.cdjView ? root.height - height : waveArea.y + waveArea.height + 2

        anchors {
            left: parent.left
            right: parent.right
        }

        Repeater {
            model: 2

            Row {
                id: deckHotcues

                required property int index

                height: parent.height
                spacing: 2
                width: (parent.width - 2) / 2

                Repeater {
                    model: 8

                    DJ.HotcueCell {
                        required property int index

                        group: "[Channel" + (deckHotcues.index + 1) + "]"
                        height: deckHotcues.height
                        hotcueNumber: index + 1
                        width: (deckHotcues.width - deckHotcues.spacing * 7) / 8
                    }
                }
            }
        }
    }
    Row {
        id: deckRow

        // XDJ view: from below the hotcues to the bottom edge. CDJ view: tall panels from the
        // top bar to the hotcues; the waveforms lie over their middle part.
        height: root.cdjView ? root.cdjPanelHeight : root.height - (hotcueBand.y + hotcueBand.height + 2) - 2
        spacing: 2

        anchors {
            left: parent.left
            right: parent.right
            top: root.cdjView ? topBar.bottom : hotcueBand.bottom
            topMargin: 2
        }

        DJ.DeckPanel {
            id: deckPanel1

            accent: "#27a8e0"
            cdjGap: root.cdjView ? root.cdjGap : 0
            cdjLowerHeight: root.cdjLowerHeight
            deckNumber: 1
            openPopup: root.popup1
            group: "[Channel1]"
            height: parent.height
            layoutHeight: root.cdjView ? root.cdjLayoutHeight : height
            keyCamelot: root.keyCamelot
            isMaster: root.masterDeck === 1
            quantizeBeat: root.quantizeBeat
            showRemain: root.showRemain
            width: (parent.width - 2) / 2

            onInfoRequested: root.infoDeck = 1
            onMasterRequested: root.setMaster(1)
            onPopupRequested: kind => root.togglePopup(1, kind)
            onTimeModeToggled: root.showRemain = !root.showRemain
        }
        DJ.DeckPanel {
            id: deckPanel2

            accent: "#e0a027"
            cdjGap: root.cdjView ? root.cdjGap : 0
            cdjLowerHeight: root.cdjLowerHeight
            deckNumber: 2
            openPopup: root.popup2
            group: "[Channel2]"
            height: parent.height
            layoutHeight: root.cdjView ? root.cdjLayoutHeight : height
            isMaster: root.masterDeck === 2
            keyCamelot: root.keyCamelot
            quantizeBeat: root.quantizeBeat
            showRemain: root.showRemain
            width: (parent.width - 2) / 2

            onInfoRequested: root.infoDeck = 2
            onMasterRequested: root.setMaster(2)
            onPopupRequested: kind => root.togglePopup(2, kind)
            onTimeModeToggled: root.showRemain = !root.showRemain
        }
    }
    DJ.UtilityMenu {
        id: utilityMenu

        autoCue: root.autoCue
        beatMatchMode: root.beatMatchMode
        cdjView: root.cdjView
        keyCamelot: root.keyCamelot
        quantizeBeat: root.quantizeBeat
        showRemain: root.showRemain
        visible: root.utilityOpen
        // Above the side buttons (z 20) of the waveforms.
        z: 30

        onAutoCueSelected: on => root.autoCue = on
        onCdjViewSelected: on => root.cdjView = on
        onBeatMatchModeSelected: mode => root.beatMatchMode = mode
        onKeyCamelotSelected: camelot => root.keyCamelot = camelot
        onQuantizeBeatSelected: beat => root.quantizeBeat = beat
        onShowRemainSelected: remain => root.showRemain = remain
        onAdvancedRequested: root.advancedOpen = true

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            top: topBar.bottom
        }
    }
    // ADVANCED SETTINGS (from UTILITY): over the utility menu.
    DJ.AdvancedSettings {
        visible: root.advancedOpen
        z: 35

        onCloseRequested: root.advancedOpen = false

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            top: topBar.bottom
        }
    }
    // Library overlay, created only while it is open.
    // SOURCE screen: devices and own music folders.
    DJ.SourceScreen {
        id: sourceScreen

        visible: root.browserOpen && root.browserMode === "SOURCE"
        // Above the side buttons (z 20) of the waveforms.
        z: 30

        // CDJ view: only on the side that was chosen for the library, like the library itself.
        anchors {
            bottom: parent.bottom
            left: root.browserSide === 2 ? parent.horizontalCenter : parent.left
            right: root.browserSide === 1 ? parent.horizontalCenter : parent.right
            top: topBar.bottom
        }

        chosenSource: root.chosenSource
        onOpenRequested: (kind, title) => root.chooseSource(kind, title)
    }
    Loader {
        id: browser

        // Created right away (asynchronously) so that the first turn of the
        // controller's BROWSE knob does not wait for the library to be built.
        active: true
        asynchronous: true
        visible: root.browserOpen && root.browserMode !== "SOURCE"
        // Above the side buttons (z 20) of the waveforms.
        z: 30

        // Like the XDJ-RX3 browse screen: fills everything below the top bar. In the CDJ view
        // LOAD of a deck opens it on that deck's half only.
        anchors {
            bottom: parent.bottom
            left: root.browserSide === 2 ? parent.horizontalCenter : parent.left
            right: root.browserSide === 1 ? parent.horizontalCenter : parent.right
            top: topBar.bottom
        }

        sourceComponent: Rectangle {
            property alias library: lib

            color: "#101010"

            // Blocks touches for the main window below (BEAT FX etc.).
            MouseArea {
                acceptedButtons: Qt.AllButtons
                anchors.fill: parent
                preventStealing: true
                onWheel: wheel => wheel.accepted = true
            }
            Skin.Library {
                id: lib

                anchors.fill: parent
                keyCamelot: root.keyCamelot
                scrollEnabled: root.browserOpen
            }
        }
    }

    // ---- Start screen: shown until the app is really ready ----
    // Ready = at least 2 s, the controller found (or 6 s over), the first effect
    // loaded. There is no artificial waiting beyond that.
    property bool appReady: false
    property int startupElapsed: 0
    readonly property bool startupControllerOk: Mixxx.DeviceStatus.controllerConnected || root.startupElapsed >= 6000
    readonly property bool startupEffectOk: {
        const slot = Mixxx.EffectsManager.getEffectSlot(1, 1);
        return slot && slot.loaded;
    }
    Timer {
        interval: 250
        repeat: true
        running: !root.appReady

        onTriggered: {
            root.startupElapsed += 250;
            if (root.startupElapsed >= 2000 && root.startupControllerOk &&
                    (root.startupEffectOk || root.startupElapsed >= 8000))
                root.appReady = true;
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "#0b0f14"
        opacity: root.appReady ? 0.0 : 1.0
        visible: opacity > 0
        z: 10000

        Behavior on opacity {
            NumberAnimation { duration: 350 }
        }

        Column {
            anchors.centerIn: parent
            spacing: 18

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

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
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#8a8a8a"
                font.pixelSize: Math.round(root.height * 0.035)
                text: root.startupControllerOk ? (root.startupEffectOk ? "Starting ..." : "Loading effects ...")
                                               : "Looking for the controller ..."
            }
        }
        // Touches do not get through while the start screen is visible.
        MouseArea {
            anchors.fill: parent
        }
    }
    // The Android BACK key does not close the app at once: it asks first (the
    // same question as the X at the top right).
    focus: true
    Keys.onBackPressed: event => {
        event.accepted = true;
        quitDialog.open();
    }
    // NIGHT: the system brightness (never brighter than NORMAL, even when the system is
    // already at its dimmest in the dark) with a dark layer and a warm orange tint over everything
    // (touches pass through).
    Rectangle {
        anchors.fill: parent
        z: 9999
        color: "#000000"
        opacity: Math.round(brightnessProxy.value) === 0 ? 0.45 : 0
        visible: opacity > 0
    }
    Rectangle {
        anchors.fill: parent
        z: 10000
        color: "#ff6a00"
        opacity: Math.round(brightnessProxy.value) === 0 ? 0.10 : 0
        visible: opacity > 0
    }
    // Long press on a library button (CDJ view): on which side should it open?
    Popup {
        id: sidePicker

        property string buttonName: ""

        anchors.centerIn: parent
        modal: true
        padding: 16
        z: 20000

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#e0e0e0"
                font.bold: true
                font.pixelSize: Math.round(root.height * 0.04)
                text: sidePicker.buttonName + " ON"
            }
            Row {
                spacing: 14

                Repeater {
                    model: [1, 2]

                    Rectangle {
                        required property int modelData

                        border.color: "#cfcfcf"
                        color: pickTap.pressed ? "#3a3a3a" : "#202020"
                        height: Math.round(root.height * 0.1)
                        width: Math.round(root.height * 0.3)

                        Text {
                            anchors.centerIn: parent
                            color: "#e0e0e0"
                            font.bold: true
                            font.pixelSize: Math.round(root.height * 0.04)
                            text: "DECK " + parent.modelData
                        }
                        TapHandler {
                            id: pickTap

                            onTapped: {
                                sidePicker.close();
                                root.topButton(sidePicker.buttonName, parent.modelData);
                            }
                        }
                    }
                }
            }
        }
    }
    // INFO of the track of a deck (the "i" in the header of the CDJ view).
    Popup {
        id: infoPopup

        readonly property var panel: root.infoDeck === 1 ? deckPanel1 : deckPanel2
        readonly property var info: panel && panel.track ? panel.track : null

        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: true
        padding: 20
        visible: root.infoDeck > 0
        z: 20000

        onClosed: root.infoDeck = 0

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            spacing: 6
            width: Math.round(root.width * 0.6)

            Text {
                color: "#ffffff"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: Math.round(root.height * 0.045)
                text: infoPopup.info ? infoPopup.info.title : ""
                width: parent.width
            }
            Repeater {
                model: infoPopup.info ? [
                    { label: "ARTIST", value: infoPopup.info.artist },
                    { label: "ALBUM", value: infoPopup.info.album },
                    { label: "GENRE", value: infoPopup.info.genre },
                    { label: "YEAR", value: infoPopup.info.year },
                    { label: "KEY", value: infoPopup.panel.formatKey(infoPopup.info.keyText) },
                    { label: "LENGTH", value: infoPopup.panel.formatTime(infoPopup.info.duration) },
                    { label: "COMMENT", value: infoPopup.info.comment }
                ] : []

                Row {
                    required property var modelData

                    spacing: 12
                    visible: modelData.value !== undefined && String(modelData.value) !== ""

                    Text {
                        color: "#8a8a8a"
                        font.pixelSize: Math.round(root.height * 0.03)
                        text: parent.modelData.label
                        width: Math.round(root.width * 0.13)
                    }
                    Text {
                        color: "#e0e0e0"
                        elide: Text.ElideRight
                        font.pixelSize: Math.round(root.height * 0.032)
                        text: String(parent.modelData.value)
                        width: Math.round(root.width * 0.45)
                    }
                }
            }
        }
    }
    Popup {
        id: quitDialog

        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape
        modal: true
        padding: 20
        z: 20000

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#e0e0e0"
                font.bold: true
                font.pixelSize: Math.round(root.height * 0.05)
                text: "CLOSE FLXXX3?"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#9a9a9a"
                font.pixelSize: Math.round(root.height * 0.035)
                text: "Playback stops."
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Repeater {
                    model: ["CANCEL", "CLOSE"]

                    Rectangle {
                        required property string modelData

                        border.color: modelData === "CLOSE" ? "#ff6a6a" : "#5a5a5a"
                        color: btnTap.pressed ? "#3a3a3a" : "#202020"
                        height: Math.round(root.height * 0.1)
                        width: Math.round(root.height * 0.3)

                        Text {
                            anchors.centerIn: parent
                            color: parent.modelData === "CLOSE" ? "#ff6a6a" : "#e0e0e0"
                            font.bold: true
                            font.pixelSize: Math.round(root.height * 0.04)
                            text: parent.modelData
                        }
                        TapHandler {
                            id: btnTap

                            onTapped: {
                                quitDialog.close();
                                if (parent.modelData === "CLOSE")
                                    Mixxx.DeviceStatus.quitApp();
                            }
                        }
                    }
                }
            }
        }
    }
}
