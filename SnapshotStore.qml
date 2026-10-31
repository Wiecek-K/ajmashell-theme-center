// SPDX-License-Identifier: AGPL-3.0-or-later
// Snapshots of one tab (ticket E18): the trial look or the trial palette recipe in a file the user picks in the system
// file dialog (zenity, through the helper; ~/.local/state/ajmashell/snapshots/<kind> to start with). "Open" fills only
// the trial (signal loaded), as a preset does; Ajmashell changes with the tab's own save, which always writes the main
// (live) file (user, 2026-10-31). Created by LookState and PaletteState; the buttons are on the tab bar (TabBar.qml),
// the results in the toast (status). Talks to the helper of PaletteState (send(), message).
import QtQuick
import Quickshell

Scope {
    id: store

    property string kind                // "look" | "palette"
    property string noun                // "look" | "palette recipe", for the texts
    property var palette                // PaletteState: the helper
    property bool available: false      // the module of the kind and zenity are there
    property string warning: ""         // why not (zenity missing)
    property bool busy: false           // a file dialog is open
    property string name: ""            // the snapshot the trial was last opened from or saved as (file name)
    property var data: null             // its content as the helper validated it: the tab shows the name while the trial equals it
    property var status: null           // {text, level} of the last result, for the toast
    signal loaded(var data)

    function send(type, extra) {
        if (busy || !available) return;
        if (palette.helperError) {
            status = { text: "Snapshot: the helper is not running", level: "error" };
            return;
        }
        busy = true;
        palette.send(Object.assign({ type: type, kind: kind }, extra || {}));
    }

    function open() { send("openSnapshot"); }
    function saveAs(content) { send("saveSnapshot", { data: content }); }

    Connections {
        target: store.palette

        function onMessage(m) {
            if (m.type === "ready") {
                // also after a settings change: maybe another Ajmashell directory
                store.available = !!m.snapshots && !!m.snapshots[store.kind];
                store.warning = m.snapshotWarning || "";
                store.busy = false;
                store.name = "";
                store.data = null;
                return;
            }
            if (m.kind !== store.kind || (m.type !== "snapshotOpened" && m.type !== "snapshotSaved")) return;
            store.busy = false;
            const opened = m.type === "snapshotOpened";
            if (m.cancelled) return;
            if (m.error) {
                store.status = { text: (opened ? "Snapshot not opened: " : "Snapshot not saved: ") + m.error, level: "error" };
                return;
            }
            store.name = m.name;
            store.data = m.data;
            const warnings = m.warnings || [];
            store.status = opened
                ? { text: "Opened \"" + m.name + "\" into the trial " + store.noun + ". Nothing changes in Ajmashell until you save."
                          + (warnings.length ? " " + warnings.join("; ") : ""),
                    level: warnings.length ? "warn" : "info" }
                : { text: "Snapshot saved: " + m.file, level: "info" };
            if (opened) store.loaded(m.data);
        }

        // a dialog in flight gets no answer any more
        function onHelperErrorChanged() {
            if (store.palette.helperError && store.busy) {
                store.status = { text: "Snapshot: the helper did not answer", level: "error" };
                store.busy = false;
            }
        }
    }
}
