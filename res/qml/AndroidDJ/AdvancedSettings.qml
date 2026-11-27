import "../AdvSettings"
import "../Library" as Lib
import Mixxx 1.0 as Mixxx
import QtQuick 2.12
import QtQuick.Controls 2.12

// ADVANCED SETTINGS (opened from UTILITY): six areas on the left, the settings of the chosen
// area on the right (exact values with coarse and fine steps; keep a step button pressed
// to repeat), and a bar with the PRESETS (save, apply, delete) and the FACTORY RESET.
Rectangle {
    id: root

    property string area: "WINDOW"
    // Example for the waveform preview (saved in the settings).
    property var waveExample: {
        try {
            const saved = Mixxx.Config.androidSetting("wave_example", "");
            return saved === "" ? null : JSON.parse(saved);
        } catch (e) {
            return null;
        }
    }
    function takeWaveExample() {
        const e = Mixxx.Config.waveformExample("[Channel1]", 16, 480);
        if (!e.columns)
            return;
        Mixxx.Config.setAndroidSetting("wave_example", JSON.stringify(e));
        root.waveExample = e;
    }
    property int selectedPreset: -1
    property string renameText: ""
    readonly property real u: Math.max(7, Math.floor(Math.min(width / 66, height / 26)))

    signal closeRequested

    color: "#0a0a0a"

    // Blocks touches for the main window below (BEAT FX etc.).
    MouseArea {
        acceptedButtons: Qt.AllButtons
        anchors.fill: parent
        preventStealing: true
        onWheel: wheel => wheel.accepted = true
    }

    // ---- small building blocks ----
    component Btn: Rectangle {
        id: btn

        property bool active: false
        property bool danger: false
        property alias text: btnText.text
        signal clicked
        signal longPressed

        border.color: btn.danger ? "#e05050" : (btn.active ? "#27a8e0" : "#4a4a4a")
        color: btnTap.pressed ? "#3a3a3a" : (btn.active ? Qt.alpha("#27a8e0", 0.18) : "#202020")
        height: root.u * 2.6
        width: Math.max(root.u * 4.2, btnText.implicitWidth + root.u * 1.6)

        Text {
            id: btnText

            anchors.centerIn: parent
            color: btn.danger ? "#e05050" : (btn.active ? "#27a8e0" : "#ffffff")
            font.bold: true
            font.pixelSize: root.u * 1.05
        }
        TapHandler {
            id: btnTap

            longPressThreshold: 0.6

            onLongPressed: btn.longPressed()
            onTapped: btn.clicked()
        }
    }
    // A step button: one step at once, repeats while it is held.
    component StepBtn: Rectangle {
        id: sb

        property alias text: sbText.text
        signal step

        border.color: "#4a4a4a"
        color: sbArea.pressed ? "#3a3a3a" : "#202020"
        height: root.u * 2.6
        width: root.u * 3.6

        Text {
            id: sbText

            anchors.centerIn: parent
            color: "#ffffff"
            font.bold: true
            font.pixelSize: root.u * 1.05
        }
        MouseArea {
            id: sbArea

            anchors.fill: parent
            preventStealing: true

            onCanceled: repeat.stop()
            onPressed: {
                sb.step();
                repeat.interval = 450;
                repeat.restart();
            }
            onReleased: repeat.stop()
        }
        Timer {
            id: repeat

            repeat: true
            onTriggered: {
                interval = 70;
                sb.step();
            }
        }
    }


    // ---- header ----
    Text {
        id: title

        color: "#ffffff"
        font.bold: true
        font.pixelSize: root.u * 1.4
        text: "ADVANCED SETTINGS"

        anchors {
            left: parent.left
            leftMargin: root.u
            top: parent.top
            topMargin: root.u * 0.5
        }
    }
    Btn {
        text: "BACK"
        onClicked: root.closeRequested()

        anchors {
            right: parent.right
            rightMargin: root.u
            top: parent.top
            topMargin: root.u * 0.4
        }
    }

    // ---- areas (left) ----
    Column {
        id: areaColumn

        spacing: root.u * 0.4
        width: root.u * 13

        anchors {
            left: parent.left
            leftMargin: root.u
            top: parent.top
            topMargin: root.u * 3.2
        }

        Repeater {
            model: AdvSettings.areas

            Btn {
                required property string modelData

                active: root.area === modelData
                text: modelData
                width: areaColumn.width
                onClicked: root.area = modelData
            }
        }
    }

    // ---- settings of the chosen area (right) ----
    Flickable {
        id: settingsView

        clip: true
        contentHeight: settingsColumn.height
        boundsBehavior: Flickable.StopAtBounds

        anchors {
            bottom: presetBar.top
            bottomMargin: root.u * 0.6
            left: areaColumn.right
            leftMargin: root.u
            right: parent.right
            rightMargin: root.u
            top: areaColumn.top
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: settingsColumn

            spacing: root.u * 0.7
            width: settingsView.width

            // WAVEFORM: example of the four layers with the sizes below.
            WaveformPreview {
                id: wavePreview

                height: root.u * 9
                visible: root.area === "WAVEFORM"
                width: parent.width
                example: root.waveExample
            }
            // The example is a piece of the track on deck 1: from the play position, 16 beats.
            Btn {
                text: "TAKE EXAMPLE FROM DECK 1 (PLAY POSITION, 16 BEATS)"
                visible: root.area === "WAVEFORM"
                width: root.u * 34
                onClicked: root.takeWaveExample()
            }
            // Settings of the area.
            Repeater {
                model: AdvSettings.inArea(root.area)

                Item {
                    id: row

                    required property var modelData
                    readonly property var def: modelData
                    readonly property var current: AdvSettings.values[def.key]

                    height: root.u * 3.2
                    width: settingsColumn.width

                    Text {
                        color: "#ffffff"
                        elide: Text.ElideRight
                        font.pixelSize: root.u * 1.0
                        text: row.def.label
                        verticalAlignment: Text.AlignVCenter
                        width: parent.width * 0.40

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                    }
                    // number: -- - value + ++
                    Row {
                        spacing: root.u * 0.3
                        visible: row.def.kind === "number"

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        StepBtn {
                            text: "−−"
                            onStep: AdvSettings.set(row.def.key, row.current - row.def.step)
                        }
                        StepBtn {
                            text: "−"
                            onStep: AdvSettings.set(row.def.key, row.current - row.def.fine)
                        }
                        Rectangle {
                            border.color: "#5a5a5a"
                            color: "#101010"
                            height: root.u * 2.6
                            width: root.u * 9

                            Text {
                                anchors.centerIn: parent
                                color: row.current === row.def.def ? "#ffffff" : "#27a8e0"
                                font.bold: true
                                font.pixelSize: root.u * 1.15
                                text: row.def.kind === "number" ? Number(row.current).toFixed(row.def.decimals) + (row.def.unit !== "" ? " " + row.def.unit : "") : ""
                            }
                        }
                        StepBtn {
                            text: "+"
                            onStep: AdvSettings.set(row.def.key, row.current + row.def.fine)
                        }
                        StepBtn {
                            text: "++"
                            onStep: AdvSettings.set(row.def.key, row.current + row.def.step)
                        }
                    }
                    // choice with many entries (BEAT FX positions): the current one with arrows, instead
                    // of a row of 18 buttons per setting.
                    Row {
                        readonly property int count: row.def.kind === "choice" ? row.def.choices.length : 0
                        readonly property int index: {
                            for (let i = 0; i < count; ++i)
                                if (row.def.choices[i].v === row.current)
                                    return i;
                            return 0;
                        }

                        spacing: root.u * 0.3
                        visible: row.def.kind === "choice" && count > 6

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        StepBtn {
                            text: "<"
                            onStep: AdvSettings.set(row.def.key, row.def.choices[(parent.index + parent.count - 1) % parent.count].v)
                        }
                        Rectangle {
                            border.color: "#5a5a5a"
                            color: "#101010"
                            height: root.u * 2.6
                            width: root.u * 15

                            Text {
                                anchors.centerIn: parent
                                color: row.current === row.def.def ? "#ffffff" : "#27a8e0"
                                font.bold: true
                                font.pixelSize: root.u * 1.05
                                text: row.def.kind === "choice" ? row.def.choices[parent.parent.index].t : ""
                            }
                        }
                        StepBtn {
                            text: ">"
                            onStep: AdvSettings.set(row.def.key, row.def.choices[(parent.index + 1) % parent.count].v)
                        }
                    }
                    // choice: segmented buttons
                    Row {
                        spacing: root.u * 0.3
                        visible: row.def.kind === "choice" && row.def.choices.length <= 6

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: row.def.kind === "choice" ? row.def.choices : []

                            Btn {
                                required property var modelData

                                active: row.current === modelData.v
                                text: modelData.t
                                onClicked: AdvSettings.set(row.def.key, modelData.v)
                            }
                        }
                    }
                }
            }
            // START: read the sticks that are plugged in now (for READ REKORDBOX STICKS = ON REQUEST).
            Btn {
                text: "READ STICKS NOW"
                visible: root.area === "START"
                width: root.u * 16
                onClicked: Mixxx.Config.setAndroidSetting("stick_scan_request", "1")
            }
            // Areas whose settings are still to come.
            Text {
                color: "#8a8a8a"
                font.pixelSize: root.u * 1.0
                text: "Settings for this area follow."
                visible: root.area !== "INFO" && root.area !== "ABOUT" && AdvSettings.inArea(root.area).length === 0
            }
            // INFO / DIAGNOSTICS (read only)
            Column {
                spacing: root.u * 0.5
                visible: root.area === "INFO"

                Repeater {
                    model: root.area === "INFO" ? root.infoLines() : []

                    Text {
                        required property var modelData

                        color: "#ffffff"
                        font.pixelSize: root.u * 1.0
                        text: modelData
                    }
                }
                // LOG: for problem reports. Android offers the log files with the share menu
                // (mail, messenger, cloud), the computer opens the folder.
                Item {
                    height: root.u * 0.6
                    width: 1
                }
                Text {
                    color: "#8a8a8a"
                    font.pixelSize: root.u * 1.0
                    text: "LOG:  " + (root.area === "INFO" ? Mixxx.DeviceStatus.logFilePath() : "")
                    width: settingsView.width - root.u
                    wrapMode: Text.WrapAnywhere
                }
                Btn {
                    text: Mixxx.Product.ui && Qt.platform.os === "android" ? "SHARE LOG" : "OPEN LOG FOLDER"
                    width: root.u * 16
                    onClicked: Mixxx.DeviceStatus.shareLog()
                }
            }
            // ABOUT: version, source code, licenses (the GPL asks for the license text and the
            // offer of the source code to come with the program).
            Column {
                spacing: root.u * 0.5
                visible: root.area === "ABOUT"
                width: settingsView.width - root.u

                Text {
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: root.u * 1.6
                    text: "FLXXX3 " + Mixxx.Product.version
                }
                Text {
                    color: "#cfcfcf"
                    font.pixelSize: root.u * 1.0
                    text: "Standalone DJ app for the Pioneer DJ DDJ-FLX4 and DDJ-FLX10, based on Mixxx (mixxx.org)."
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
                Text {
                    color: "#cfcfcf"
                    font.pixelSize: root.u * 1.0
                    text: "Free software under the GNU General Public License version 3. You may use, share and change it under its terms. There is NO WARRANTY."
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
                Text {
                    color: "#cfcfcf"
                    font.pixelSize: root.u * 1.0
                    text: "Source code: " + Mixxx.Product.sourceUrl
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                }
                Text {
                    color: "#8a8a8a"
                    font.pixelSize: root.u * 0.9
                    text: "Not affiliated with or endorsed by Pioneer DJ / AlphaTheta, rekordbox or the Mixxx project. Trademarks belong to their owners."
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
                Item {
                    height: root.u * 0.4
                    width: 1
                }
                Row {
                    spacing: root.u * 0.6

                    Btn {
                        active: root.aboutLicense === "GPL-3.0"
                        text: "LICENSE (GPL-3.0)"
                        width: root.u * 13
                        onClicked: root.aboutLicense = root.aboutLicense === "GPL-3.0" ? "" : "GPL-3.0"
                    }
                    Btn {
                        active: root.aboutLicense === "THIRD_PARTY"
                        text: "THIRD-PARTY LICENSES"
                        width: root.u * 15
                        onClicked: root.aboutLicense = root.aboutLicense === "THIRD_PARTY" ? "" : "THIRD_PARTY"
                    }
                }
                // The chosen license text (scrolls with the page).
                Text {
                    color: "#d8d8d8"
                    font.pixelSize: root.u * 0.8
                    text: root.aboutLicense !== "" ? Mixxx.Product.licenseText(root.aboutLicense) : ""
                    visible: root.aboutLicense !== ""
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // ABOUT: the license text that is shown ("" = none).
    property string aboutLicense: ""
    onAreaChanged: aboutLicense = ""

    // Lines of the INFO area (refreshed every second while it is shown).
    property int infoTick: 0
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.area === "INFO"

        onTriggered: root.infoTick++
    }
    function gigabytes(bytes) {
        return (Number(bytes) / 1073741824).toFixed(1) + " GB";
    }
    function infoLines() {
        const tick = root.infoTick; // re-evaluate
        const st = Mixxx.DeviceStatus;
        const lines = [];
        lines.push("CONTROLLER: " + (st.controllerConnected ? st.controllerName : "not connected"));
        lines.push("BATTERY: " + (st.batteryPercent >= 0 ? st.batteryPercent + " %" + (st.batteryCharging ? " (charging)" : "") : "not available"));
        lines.push("TRACK CACHE: " + st.cacheCopies + " copies");
        for (let slot = 1; slot <= 2; ++slot) {
            const info = st.stickInfo(slot);
            if (info.present) {
                lines.push("USB " + slot + ": " + (info.label || "-") + "   " + root.gigabytes(info.free) + " free of " + root.gigabytes(info.total) + (slot === 1 ? (st.stick1Busy ? "   (busy)" : "") : (st.stick2Busy ? "   (busy)" : "")));
            } else {
                lines.push("USB " + slot + ": -");
            }
        }
        return lines;
    }

    // ---- presets and factory reset (bottom) ----
    Rectangle {
        id: presetBar

        color: "#141414"
        height: root.u * 4.2

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        Text {
            id: presetLabel

            color: "#8a8a8a"
            font.bold: true
            font.pixelSize: root.u * 0.95
            text: "PRESETS"

            anchors {
                left: parent.left
                leftMargin: root.u
                verticalCenter: parent.verticalCenter
            }
        }
        ListView {
            id: presetList

            clip: true
            model: AdvSettings.presets
            orientation: ListView.Horizontal
            spacing: root.u * 0.4

            anchors {
                bottom: parent.bottom
                bottomMargin: root.u * 0.8
                left: presetLabel.right
                leftMargin: root.u
                right: presetButtons.left
                rightMargin: root.u
                top: parent.top
                topMargin: root.u * 0.8
            }

            delegate: Btn {
                required property int index
                required property var modelData

                active: root.selectedPreset === index
                text: modelData.name
                onClicked: {
                    root.selectedPreset = index;
                    AdvSettings.applyPreset(index);
                }
                // Holding a preset renames it.
                onLongPressed: {
                    root.selectedPreset = index;
                    root.renameText = modelData.name;
                    renamePopup.open();
                }
            }
        }
        Row {
            id: presetButtons

            spacing: root.u * 0.4

            anchors {
                right: parent.right
                rightMargin: root.u
                verticalCenter: parent.verticalCenter
            }

            Btn {
                text: "SAVE PRESET"
                onClicked: root.selectedPreset = AdvSettings.savePreset()
            }
            Btn {
                text: "DELETE"
                visible: root.selectedPreset >= 0 && root.selectedPreset < AdvSettings.presets.length
                onClicked: deleteConfirm.open()
            }
            Btn {
                danger: true
                text: "FACTORY RESET"
                onClicked: resetConfirm.open()
            }
        }
    }

    // Rename a preset (hold it): name and touch keyboard.
    Popup {
        id: renamePopup

        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape
        height: Math.min(root.height - root.u, root.u * 24)
        modal: true
        padding: root.u * 0.8
        width: Math.min(root.width - root.u * 2, root.u * 52)

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Item {
            anchors.fill: parent

            Text {
                id: renameTitle

                color: "#ffffff"
                font.bold: true
                font.pixelSize: root.u * 1.2
                text: "RENAME PRESET"
            }
            Btn {
                text: "CANCEL"
                onClicked: renamePopup.close()

                anchors {
                    right: parent.right
                    top: parent.top
                }
            }
            Rectangle {
                id: renameField

                border.color: "#27a8e0"
                color: "#0c0c0c"
                height: root.u * 3
                radius: 4

                anchors {
                    left: parent.left
                    right: parent.right
                    top: renameTitle.bottom
                    topMargin: root.u * 1.2
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: root.u * 0.8
                        verticalCenter: parent.verticalCenter
                    }
                    color: "#ffffff"
                    font.pixelSize: root.u * 1.4
                    text: root.renameText + "|"
                }
            }
            Lib.SearchKeyboard {
                narrowLabel: "OK"
                s: 1.0

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    top: renameField.bottom
                    topMargin: root.u * 0.8
                }

                onBackspace: root.renameText = root.renameText.slice(0, -1)
                onClearAll: root.renameText = ""
                onNarrowDown: {
                    AdvSettings.renamePreset(root.selectedPreset, root.renameText);
                    renamePopup.close();
                }
                onTyped: text => {
                    if (root.renameText.length < 24)
                        root.renameText += text;
                }
            }
        }
    }

    // Asks before a preset is deleted.
    Popup {
        id: deleteConfirm

        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: true
        padding: root.u

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            spacing: root.u

            Text {
                color: "#ffffff"
                font.pixelSize: root.u * 1.2
                text: "Delete the preset \"" + (AdvSettings.presets[root.selectedPreset] ? AdvSettings.presets[root.selectedPreset].name : "") + "\"?"
            }
            Row {
                spacing: root.u

                Btn {
                    danger: true
                    text: "DELETE"
                    onClicked: {
                        AdvSettings.deletePreset(root.selectedPreset);
                        root.selectedPreset = -1;
                        deleteConfirm.close();
                    }
                }
                Btn {
                    text: "CANCEL"
                    onClicked: deleteConfirm.close()
                }
            }
        }
    }

    Popup {
        id: resetConfirm

        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: true
        padding: root.u

        background: Rectangle {
            border.color: "#5a5a5a"
            color: "#141414"
        }

        Column {
            spacing: root.u

            Text {
                color: "#ffffff"
                font.pixelSize: root.u * 1.2
                text: "Reset all advanced settings to the factory state?"
            }
            Row {
                spacing: root.u

                Btn {
                    danger: true
                    text: "RESET"
                    onClicked: {
                        AdvSettings.factoryReset();
                        root.selectedPreset = -1;
                        resetConfirm.close();
                    }
                }
                Btn {
                    text: "CANCEL"
                    onClicked: resetConfirm.close()
                }
            }
        }
    }
}
