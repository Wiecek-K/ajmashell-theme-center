// SPDX-License-Identifier: AGPL-3.0-or-later
// State of the Look tab (ticket 13, ADR 0021), created by the frame (shell.qml) at start and alive until the window
// closes: the look of Ajmashell's big popups as parameters (background role, alpha, motion, lens flare, glass core,
// soft pills). Current = the live file Ajmashell watches (~/.local/state/ajmashell/look.json, or the defaults without
// it); trial = what the builder shows. Roles, ranges, presets and defaults come from Ajmashell's look-options.json
// through the helper (look_settings.options()), never copied here. Saving writes only the live file; Ajmashell changes
// at once. Talks to the helper of PaletteState (send(), message). Not visible; LookTab.qml is the view.
// Tab interface of the frame: edited, busy, save(), saving, saveError, effect.
import QtQuick
import Quickshell

Scope {
    id: app

    property var palette                // PaletteState: the helper and the colours of both palette recipes
    readonly property var ui: palette.ui

    property var options: null          // look_settings.options(): roles, alpha {min, max, step}, flags, presets, defaults
    property var current: null          // the look in the live file
    property var trial: null            // the builder's look: starts as a copy of the current one
    property string file: ""            // the live file
    property bool saving: false
    property string saveError: ""
    property bool saved: false          // the last save went through (the panel says so until the next change)

    // the look's fields in look-options.json order
    readonly property var fields: options ? Object.keys(options.defaults) : []

    function same(a, b) {
        if (!a || !b) return false;
        for (const f of fields)
            if (a[f] !== b[f]) return false;
        return true;
    }

    // the preset a look equals, else "custom"
    function presetOf(look) {
        if (!options || !look) return "";
        for (const name in options.presets)
            if (same(options.presets[name], look)) return name;
        return "custom";
    }

    function copy(look) {
        const out = {};
        for (const f of fields) out[f] = look[f];
        return out;
    }

    // a click on a preset fills the builder; any other change makes it "custom"
    function applyPreset(name) {
        trial = copy(options.presets[name]);
        saved = false;
    }

    function set(field, value) {
        const t = copy(trial);
        t[field] = value;
        trial = t;
        saved = false;
    }

    function restore() {
        trial = copy(current);
        saved = false;
    }

    function save() {
        if (saving || !edited) return;
        saving = true;
        saveError = "";
        saved = false;
        palette.send({ type: "saveLook", look: trial });
    }

    // the tab interface of ADR 0020
    readonly property bool edited: !!trial && !same(trial, current)
    readonly property bool busy: saving || palette.restarting
    readonly property string effect: "writes Ajmashell's live look file; its popups change at once"

    Connections {
        target: app.palette

        function onMessage(m) {
            if (m.type === "ready") {
                // also after a settings change: maybe another Ajmashell directory
                app.options = m.lookSettings ? m.lookSettings.options : null;
                app.current = m.lookSettings ? m.lookSettings.current : null;
                app.file = m.lookSettings ? m.lookSettings.file : "";
                app.trial = app.current ? app.copy(app.current) : null;
                app.saving = false;
                app.saveError = "";
                app.saved = false;
            } else if (m.type === "lookSaved") {
                if (m.error) {
                    app.saveError = m.error;
                } else {
                    app.current = m.look;
                    app.saved = true;
                }
                app.saving = false; // last: "Save all" reads saveError and current once saving ends
            }
        }

        // a save in flight gets no answer any more
        function onHelperErrorChanged() {
            if (app.palette.helperError && app.saving) {
                app.saveError = "the helper did not answer";
                app.saving = false;
            }
        }
    }
}
