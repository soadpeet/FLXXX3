import "../" as Skin
import "../AdvSettings"
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls
import "../Theme"
import "." as DJ

// Single-view touch UI for the Android edition, modelled on the XDJ-RX3
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
        Mixxx.AndroidStatus.setScreenBrightness(level === 2 ? 1.0 : -1.0);
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
        // Waveform zoom: only when ADVANCED SETTINGS changed it from the factory value (otherwise the
        // zoom of the last session stays).
        if (AdvSettings.values.zoomStart !== AdvSettings.definition("zoomStart").def) {
            pinchZoom1.value = AdvSettings.values.zoomStart;
            pinchZoom2.value = AdvSettings.values.zoomStart;
        }
        const savedBrightness = parseInt(Mixxx.Config.androidSetting("brightness", "1"));
        brightnessProxy.value = isNaN(savedBrightness) ? 1 : savedBrightness;
        root.applyBrightness();
        Mixxx.AndroidStatus.lockScreen();
        // Mixer: ISO (kill at the end stop) is the default, EQ is saved.
        eqModeProxy.value = Mixxx.Config.androidSetting("eqMode", "0") === "1" ? 1 : 0;
        // 3BAND is the default look: once, a look saved earlier (e.g. RGB) is replaced.
        if (Mixxx.Config.androidSetting("waveformDefault3band", "0") !== "1") {
            Mixxx.Config.waveformType = Mixxx.WaveformDisplay.Type.Filtered;
            Mixxx.Config.setAndroidSetting("waveformDefault3band", "1");
        }
        root.showRemain = Mixxx.Config.androidSetting("showRemain", "1") === "1";
        root.keyCamelot = Mixxx.Config.androidSetting("keyCamelot", "1") === "1";
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
    function topButton(name) {
        root.advancedOpen = false;
        if (name === "UTILITY") {
            browserIdle.stop();
            root.browserOpen = false;
            root.utilityOpen = !root.utilityOpen;
            return;
        }
        root.utilityOpen = false;
        if (root.browserOpen && root.browserMode === name) {
            browserIdle.stop();
            root.browserOpen = false;
            return;
        }
        root.browserMode = name;
        root.openBrowser();
        const lib = browser.item ? browser.item.library : null;
        if (lib) {
            lib.mode = name;
        }
        if (name === "PLAYLIST") {
            root.activateSource(1);
        }
    }
    function openBrowser() {
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
    readonly property real hotcueHeight: Math.max(12, Math.round(height * 0.035))
    readonly property real waveformHeight: Math.round(height * 0.27)

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
            } else if (value > 0) {
                zoomIn1.trigger();
                zoomIn2.trigger();
            } else if (value < 0) {
                zoomOut1.trigger();
                zoomOut2.trigger();
            }
        }
    }
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
                } else {
                    root.browserMode = "BROWSE";
                    root.openBrowser();
                    const lib = browser.item ? browser.item.library : null;
                    if (lib) {
                        lib.mode = "BROWSE";
                    }
                }
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Channel1]"
        key: "LoadSelectedTrack"

        onValueChanged: if (value > 0) root.closeBrowserSoon()
    }
    Mixxx.ControlProxy {
        group: "[Channel2]"
        key: "LoadSelectedTrack"

        onValueChanged: if (value > 0) root.closeBrowserSoon()
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
        onCloseRequested: quitDialog.open()
    }
    // Waveforms of both decks stacked on the left, FX panel on the right.
    Item {
        id: waveArea

        height: root.waveformHeight * 2

        anchors {
            left: parent.left
            right: parent.right
            top: topBar.bottom
        }

        Repeater {
            model: 2

            Skin.WaveformDisplay {
                required property int index

                // No touches for the waveforms below UTILITY / ADVANCED SETTINGS.
                enabled: !root.advancedOpen && !root.utilityOpen
                group: "[Channel" + (index + 1) + "]"
                height: root.waveformHeight
                width: parent.width
                y: index * root.waveformHeight
            }
        }
        // Two fingers: spread = zoom in, pinch = zoom out (both decks).
        PinchHandler {
            id: pinch

            property real startZoom: 3

            enabled: !root.advancedOpen && !root.utilityOpen
            maximumPointCount: 2
            minimumPointCount: 2
            target: null

            onActiveChanged: {
                if (active)
                    startZoom = pinchZoom1.value;
            }
            onActiveScaleChanged: {
                if (!active)
                    return;
                // Smaller zoom value = more detail (like the zoom buttons).
                const zoom = Math.max(AdvSettings.values.zoomMin, Math.min(AdvSettings.values.zoomMax, startZoom / activeScale));
                pinchZoom1.value = zoom;
                pinchZoom2.value = zoom;
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
            font.pixelSize: Math.round(parent.width * 0.5)
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
            font.pixelSize: Math.round(parent.width * 0.5)
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

        anchors {
            left: parent.left
            right: parent.right
            top: waveArea.bottom
            topMargin: 2
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

        anchors {
            left: parent.left
            right: parent.right
            top: waveArea.bottom
            topMargin: 2
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

        spacing: 2

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            top: hotcueBand.bottom
            topMargin: 2
        }

        DJ.DeckPanel {
            accent: "#27a8e0"
            deckNumber: 1
            group: "[Channel1]"
            height: parent.height
            keyCamelot: root.keyCamelot
            isMaster: root.masterDeck === 1
            quantizeBeat: root.quantizeBeat
            showRemain: root.showRemain
            width: (parent.width - 2) / 2

            onMasterRequested: root.setMaster(1)
            onTimeModeToggled: root.showRemain = !root.showRemain
        }
        DJ.DeckPanel {
            accent: "#e0a027"
            deckNumber: 2
            group: "[Channel2]"
            height: parent.height
            isMaster: root.masterDeck === 2
            keyCamelot: root.keyCamelot
            quantizeBeat: root.quantizeBeat
            showRemain: root.showRemain
            width: (parent.width - 2) / 2

            onMasterRequested: root.setMaster(2)
            onTimeModeToggled: root.showRemain = !root.showRemain
        }
    }
    DJ.UtilityMenu {
        id: utilityMenu

        autoCue: root.autoCue
        keyCamelot: root.keyCamelot
        quantizeBeat: root.quantizeBeat
        showRemain: root.showRemain
        visible: root.utilityOpen
        // Above the side buttons (z 20) of the waveforms.
        z: 30

        onAutoCueSelected: on => root.autoCue = on
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

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            top: topBar.bottom
        }

        onSticksSelected: root.activateSource(1)
        onOpenRequested: (kind, title) => {
            root.browserMode = "BROWSE";
            root.activateSource(kind === "USB" ? 1 : 0);
            const lib = browser.item ? browser.item.library : null;
            if (lib) {
                lib.mode = "BROWSE";
                lib.sourceTitle = title;
                // The tablet list shows only the folders that are ACTIVE in SOURCE.
                lib.folderFilter = kind === "TABLET" ? Object.keys(sourceScreen.activeFolders) : [];
                lib.resetBrowse();
            }
            root.openBrowser();
        }
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

        // Like the XDJ-RX3 browse screen: fills everything below the top bar.
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
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
    readonly property bool startupControllerOk: Mixxx.AndroidStatus.controllerConnected || root.startupElapsed >= 6000
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
                                    Mixxx.AndroidStatus.quitApp();
                            }
                        }
                    }
                }
            }
        }
    }
}
