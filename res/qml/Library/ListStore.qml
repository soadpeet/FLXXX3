import Mixxx 1.0 as Mixxx
import QtQuick 2.12

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// Lists that the app keeps itself (Android edition, like the XDJ-RX3):
//   tags     TAG LIST, at most 100 tracks per USB stick
//   history  the last 100 tracks that were loaded into a deck
//   myLists  tag lists that were saved as playlists ({ name, tracks })
// A track is a map { url, title, artist, album, genre, key, bpm, duration }.
// The lists are stored in the settings; `version` changes with every change.
Item {
    id: root

    property var tags: []
    property var history: []
    property var myLists: []
    property int version: 0
    readonly property int maxTagsPerStick: 100
    readonly property int maxHistory: 100

    visible: false

    // "USB id" of a track: the folder below /mnt/media_rw or /storage, else TABLET.
    function stickOf(url) {
        const m = /\/(?:mnt\/media_rw|storage)\/([^\/]+)\//.exec(decodeURIComponent(String(url)));
        return m && m[1] !== "emulated" && m[1] !== "self" ? m[1] : "TABLET";
    }
    function persist() {
        try {
            Mixxx.Config.setAndroidSetting("lists_tags", JSON.stringify(root.tags));
            Mixxx.Config.setAndroidSetting("lists_history", JSON.stringify(root.history));
            Mixxx.Config.setAndroidSetting("lists_my", JSON.stringify(root.myLists));
        } catch (e) {
        }
        root.version++;
    }
    function parse(text) {
        try {
            const value = JSON.parse(text);
            return Array.isArray(value) ? value : [];
        } catch (e) {
            return [];
        }
    }
    function isTagged(url) {
        const key = String(url);
        return root.tags.some(t => String(t.url) === key);
    }
    function tagCountOfStick(stick) {
        return root.tags.filter(t => root.stickOf(t.url) === stick).length;
    }
    // Tags a track, or removes the tag. Returns "added", "removed" or "full".
    function toggleTag(info) {
        const key = String(info.url);
        const list = root.tags.slice();
        const at = list.findIndex(t => String(t.url) === key);
        if (at >= 0) {
            list.splice(at, 1);
            root.tags = list;
            root.persist();
            return "removed";
        }
        if (root.tagCountOfStick(root.stickOf(key)) >= root.maxTagsPerStick) {
            return "full";
        }
        list.push(info);
        root.tags = list;
        root.persist();
        return "added";
    }
    function removeTags(urls) {
        const drop = {};
        urls.forEach(u => drop[String(u)] = true);
        root.tags = root.tags.filter(t => !drop[String(t.url)]);
        root.persist();
    }
    function clearTags() {
        root.tags = [];
        root.persist();
    }
    function addHistory(info) {
        if (!info || !info.url) {
            return;
        }
        const list = root.history.filter(t => String(t.url) !== String(info.url));
        list.unshift(info);
        root.history = list.slice(0, root.maxHistory);
        root.persist();
    }
    function clearHistory() {
        root.history = [];
        root.persist();
    }
    function saveTagsAsList(name) {
        if (root.tags.length === 0) {
            return;
        }
        const lists = root.myLists.slice();
        lists.push({ name: name, tracks: root.tags.slice() });
        root.myLists = lists;
        root.persist();
    }
    function deleteList(index) {
        const lists = root.myLists.slice();
        lists.splice(index, 1);
        root.myLists = lists;
        root.persist();
    }

    Component.onCompleted: {
        root.tags = root.parse(Mixxx.Config.androidSetting("lists_tags", "[]"));
        root.history = root.parse(Mixxx.Config.androidSetting("lists_history", "[]"));
        root.myLists = root.parse(Mixxx.Config.androidSetting("lists_my", "[]"));
        root.version++;
    }

    // HISTORY: every track that is loaded into a deck.
    Connections {
        function onTrackLoaded() {
            root.addHistory(Mixxx.PlayerManager.getPlayer("[Channel1]").loadedTrackInfo());
        }

        target: Mixxx.PlayerManager.getPlayer("[Channel1]")
    }
    Connections {
        function onTrackLoaded() {
            root.addHistory(Mixxx.PlayerManager.getPlayer("[Channel2]").loadedTrackInfo());
        }

        target: Mixxx.PlayerManager.getPlayer("[Channel2]")
    }
}
