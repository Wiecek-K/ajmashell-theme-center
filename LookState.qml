// SPDX-License-Identifier: AGPL-3.0-or-later
// State of the Look tab (ticket 13, ADR 0021), created by the frame (shell.qml) at start and alive until the window
// closes: the look of Ajmashell's big popups as parameters (background role, alpha, motion, lens flare, glass core,
// soft pills) and the gradient of their background (ticket 14: style, colours A and B, strength, angle, reaches; one
// for every look, so a preset keeps it). Current = the live file Ajmashell watches (~/.local/state/ajmashell/look.json, or the defaults without
// it); trial = what the builder shows. Roles, ranges, presets and defaults come from Ajmashell's look-options.json
// through the helper (look_settings.options()), never copied here. Saving writes only the live file; Ajmashell changes
// at once. The live file is watched: a change made outside the tool (by hand, a delete) becomes the current look, and
// the trial follows while it was not edited. Talks to the helper of PaletteState (send(), message). Not visible;
// LookTab.qml is the view.
// Tab interface of the frame: edited, busy, save(), saving, saveError, effect.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: app

    property var palette                // PaletteState: the helper and the colours of both palette recipes
    readonly property var ui: palette.ui

    property var options: null          // look_settings.options(): roles, alpha {min, max, step}, flags, gradient, presets, defaults
    property var current: null          // the look in the live file
    property var trial: null            // the builder's look: starts as a copy of the current one
    property string file: ""            // the live file
    property string gradientFill: ""    // Ajmashell's look/GradientFill.qml, "" without it (ticket 14): the previews load it
    property bool saving: false
    property string saveError: ""
    property bool saved: false          // the last save went through (the panel says so until the next change)

    // the look's fields in look-options.json order (the last one: gradient, an object of its parts)
    readonly property var fields: options ? Object.keys(options.defaults) : []
    readonly property var gradientParts: options ? Object.keys(options.defaults.gradient) : []

    // the fields of a in b (a preset has no gradient: it matches whatever gradient b has)
    function matches(a, b) {
        for (const f in a) {
            if (f === "gradient") {
                for (const p of gradientParts)
                    if (a.gradient[p] !== b.gradient[p]) return false;
            } else if (a[f] !== b[f]) {
                return false;
            }
        }
        return true;
    }

    function same(a, b) {
        return !!a && !!b && matches(a, b);
    }

    // the preset a look equals, else "custom"
    function presetOf(look) {
        if (!options || !look) return "";
        for (const name in options.presets)
            if (matches(options.presets[name], look)) return name;
        return "custom";
    }

    function copy(look) {
        const out = {};
        for (const f of fields) out[f] = look[f];
        out.gradient = Object.assign({}, look.gradient);
        return out;
    }

    // a click on a preset fills the builder, the gradient stays; any other change makes it "custom"
    function applyPreset(name) {
        trial = Object.assign(copy(trial), options.presets[name]);
        saved = false;
    }

    function set(field, value) {
        const t = copy(trial);
        t[field] = value;
        trial = t;
        saved = false;
    }

    // one part of the trial's gradient; a new style also sets the reaches to that style's defaults
    function setGradient(part, value) {
        const t = copy(trial);
        t.gradient[part] = value;
        if (part === "style")
            Object.assign(t.gradient, options.gradient.styles.find(s => s.name === value).reaches);
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

    FileView {
        // the helper reads it (look_settings.load, the same rules as Ajmashell); here only the change is seen
        path: app.file
        watchChanges: !!app.file
        printErrors: false
        onFileChanged: app.palette.send({ type: "readLook" })
    }

    Connections {
        target: app.palette

        function onMessage(m) {
            if (m.type === "ready") {
                // also after a settings change: maybe another Ajmashell directory
                app.options = m.lookSettings ? m.lookSettings.options : null;
                app.current = m.lookSettings ? m.lookSettings.current : null;
                app.file = m.lookSettings ? m.lookSettings.file : "";
                app.gradientFill = m.lookSettings && m.lookSettings.gradientFill ? m.lookSettings.gradientFill : "";
                app.trial = app.current ? app.copy(app.current) : null;
                app.saving = false;
                app.saveError = "";
                app.saved = false;
            } else if (m.type === "lookRead") {
                const follow = !app.edited;
                app.current = m.current;
                if (follow) app.trial = app.copy(app.current);
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
