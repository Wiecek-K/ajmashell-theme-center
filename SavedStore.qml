// SPDX-License-Identifier: AGPL-3.0-or-later
// Saved settings of one tab (ticket E18): the names the helper keeps for a kind ("look" or "palette", files in
// ~/.local/state/ajmashell/saved/<kind>/, helper/saved.py) and the one the trial was loaded from or saved as. A load
// fills the trial only (signal loaded); Ajmashell changes with the tab's own save, as after a preset. Created by
// LookState and PaletteState; SavedSection.qml is the view. Talks to the helper of PaletteState (send(), message).
import QtQuick
import Quickshell

Scope {
    id: store

    property string kind                // "look" | "palette"
    property var palette                // PaletteState: the helper
    property var names: []              // sorted by the helper; null = no module of this kind (see Settings)
    property string name: ""            // the saved setting the trial was last loaded from or saved as
    property var data: null             // its content as the helper validated it: the tab shows the name while the trial equals it
    property var warnings: []           // what the module said about a bad field of the loaded file
    property string error: ""
    property bool busy: false
    signal loaded(var data)

    function send(type, entry, extra) {
        if (palette.helperError) {
            // no helper: no answer would come and the buttons would stay off
            error = "the helper is not running";
            return;
        }
        busy = true;
        error = "";
        palette.send(Object.assign({ type: type, kind: kind, name: entry }, extra || {}));
    }

    function saveAs(entry, content, overwrite) { send("saveAs", entry, { data: content, overwrite: overwrite }); }
    function load(entry) { send("loadSaved", entry); }
    function remove(entry) { send("deleteSaved", entry); }

    Connections {
        target: store.palette

        function onMessage(m) {
            if (m.type === "ready") {
                // also after a settings change: maybe another Ajmashell directory
                store.names = m.saved ? m.saved[store.kind] : null;
                store.name = "";
                store.data = null;
                store.warnings = [];
                store.error = "";
                store.busy = false;
                return;
            }
            if (m.kind !== store.kind) return;
            if (m.type === "savedAs" || m.type === "savedLoaded") {
                store.busy = false;
                if (m.error) {
                    store.error = m.error;
                    return;
                }
                store.name = m.name;
                store.data = m.data;
                store.warnings = m.warnings || [];
                if (m.type === "savedLoaded") store.loaded(m.data);
            } else if (m.type === "savedList") {
                store.busy = false;
                if (m.error) {
                    store.error = m.error;
                    return;
                }
                store.names = m.names;
                if (!m.names.includes(store.name)) {
                    // deleted: the trial keeps its values, without the name
                    store.name = "";
                    store.data = null;
                    store.warnings = [];
                }
            }
        }

        // a request in flight gets no answer any more
        function onHelperErrorChanged() {
            if (store.palette.helperError && store.busy) {
                store.error = "the helper did not answer";
                store.busy = false;
            }
        }
    }
}
