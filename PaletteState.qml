// SPDX-License-Identifier: AGPL-3.0-or-later
// State of the Palette tab (ticket 12, ADR 0020), created by the frame (shell.qml) at start and alive until the window
// closes: the current and the trial palette recipe, the results of every wallpaper, the protocol with helper/tuner.py
// (real matugen through the Ajmashell palette_recipe.py) and the paths of the helper, which the Settings tab edits (a
// change restarts the helper, the window stays). Not visible; PaletteTab.qml is the view.
// For the frame and the other tabs (read only): edited, busy, save(), saving, saveError, effect, saveFirst, and the colours
// of both recipes for the selected wallpaper (currentColors, trialColors, wallpaperName). The Look tab (LookState) talks to the
// same helper: send() and the signal message (every message of the helper). Snapshots (ticket E18, SnapshotStore.qml):
// a recipe in a file the user picks, "Open" fills the trial recipe. Tab interface also: noun, status (toast), snapshots.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: app

    property var ui                     // colours of the window, from the frame
    signal message(var m)               // every message of the helper, after this state took it (LookState)

    property var items: []          // [{fileName, path, thumb}] in carousel index order
    property string current: ""     // fileName of the system's current wallpaper
    property int sel: 0
    readonly property var it: items.length ? items[sel] : null
    property var recipe: null       // current recipe (the live file over Ajmashell's default recipe, validated by the helper)
    property var recipeWarnings: [] // what the recipe module said about a bad field, as the side panel shows it
    property string fingerprint: ""
    property var trial: null        // trial recipe: starts as a copy of the current one, changed by the controls
    property string trialFingerprint: ""
    // The trial is computed for the selected wallpaper only; the rest of the folder after the button
    // "compute all wallpapers" (user, 2026-10-20). A new trial value goes back to the selected one only.
    property bool trialAll: false
    property var options: null      // palette_recipe.options(): rules, schemes, number ranges
    property var look: null         // tuner.py system_look(): what the mock-ups read from the system's files
    // results[fingerprint][fileName] = {seed, candidates, category, colors, key} or {error}; done[fingerprint] = n.
    // Messages write them at once, rev follows at most every 80 ms (pending): one rebind of the strip and the
    // summary per batch, not per message, so moving a control does not stall the window.
    property var results: ({})
    property var done: ({})
    property int rev: 0
    property bool pending: false
    property string helperError: ""
    // Saving the trial as the system palette recipe (ticket 07): saving = the file is being written;
    // applyStage = the background steps after it ("indexer", "wallpaper", "done", "error"), shown in the panel
    property bool saving: false
    property string saveError: ""
    property string applyStage: ""
    property string applyError: ""
    readonly property bool applying: applyStage === "indexer" || applyStage === "wallpaper"
    readonly property bool trialEdited: !sameRecipe(trial, recipe)
    property string copied: ""
    // Settings (ticket 09): settings = settings.status() of the paths in use, problems = what each missing path
    // stops (shown in the Palette panel and, without wallpapers, in the middle); the Settings tab edits draft {key: text}, the
    // helper checks it ("checked" = status of the draft) and, on apply, saves it and restarts (restarting)
    property var settings: []
    property string settingsFile: ""
    property string recipeFile: ""  // named by the recipe module, not a setting (user, 2026-10-21)
    property string settingsWarning: ""
    property string matugenWarning: ""   // matugen missing or not 4.2.x (ticket 11): a warning, nothing blocked
    property var problems: []
    property var draft: ({})
    property var checked: null
    property bool restarting: false
    property string settingsError: ""
    // a field holds the path only when it is not the default (s.own); empty = the default
    readonly property bool draftEdited: {
        for (const s of settings)
            if ((draft[s.key] ?? "") !== s.own) return true;
        return false;
    }
    readonly property bool canApply: draftEdited && !restarting && !saving && !applying

    readonly property bool trialDiffers: fingerprint !== trialFingerprint
    readonly property int total: items.length
    // the folder summary: wallpapers with both results, of them how many get another seed / only another palette
    readonly property var summary: {
        rev; // dependency
        let both = 0, seed = 0, palette = 0;
        for (const x of items) {
            const d = diff(x.fileName);
            if (d === "") continue;
            both++;
            if (d === "seed") seed++;
            else if (d === "palette") palette++;
        }
        return { both: both, seed: seed, palette: palette };
    }

    function result(fileName, fp) {
        rev; // dependency
        const r = results[fp || fingerprint];
        return r ? r[fileName] || null : null;
    }

    function doneOf(fp) {
        rev; // dependency
        return done[fp] || 0;
    }

    // What the trial changes on one wallpaper: "seed", "palette" (same seed, other tokens), "same", or "" while
    // either result is missing or failed.
    function diff(fileName) {
        const a = result(fileName, fingerprint), b = result(fileName, trialFingerprint);
        if (!a || !b || a.error || b.error) return "";
        return a.seed !== b.seed ? "seed" : a.key !== b.key ? "palette" : "same";
    }

    // Selected wallpaper first, then its neighbours outwards: the strip is browsed with the arrows.
    function order() {
        const out = [];
        for (let d = 0; out.length < items.length; d++) {
            if (sel + d < items.length) out.push(items[sel + d].fileName);
            if (d > 0 && sel - d >= 0) out.push(items[sel - d].fileName);
        }
        return out;
    }

    function request() {
        if (!items.length || !recipe || restarting) return;
        const all = order();
        helper.write(JSON.stringify({ type: "compute", recipes: [recipe, trial],
                                      orders: [all, trialAll ? all : all.slice(0, 1)] }) + "\n");
    }

    function select(i) {
        if (i < 0 || i >= items.length || i === sel) return;
        sel = i;
        // same recipes: the helper moves the selected one to the front (and adds it to the trial's list)
        if (doneOf(fingerprint) < total || doneOf(trialFingerprint) < total) request();
    }

    function computeAll() {
        trialAll = true;
        debounce.stop();
        request();
    }

    // A control changed one field of the trial: the request waits for the control to settle (debounce).
    function setTrial(section, key, value) {
        const t = JSON.parse(JSON.stringify(trial));
        t[section][key] = value;
        trial = t;
        trialAll = false;
        debounce.restart();
    }

    // The trial becomes the system palette recipe; the helper writes it through palette_recipe.save and answers
    // "saved"
    function saveTrial() {
        if (saving || applying || !trialEdited) return;
        saving = true;
        saveError = "";
        applyStage = "";
        applyError = "";
        helper.write(JSON.stringify({ type: "save", recipe: trial }) + "\n");
    }

    // A path typed in the Settings tab: the helper checks the draft after 300 ms without typing.
    function setDraft(key, text) {
        const d = Object.assign({}, draft);
        d[key] = text;
        draft = d;
        settingsError = "";
        checkDebounce.restart();
    }

    function checkDraft() {
        if (!restarting) helper.write(JSON.stringify({ type: "check", paths: draft }) + "\n");
    }

    // The helper saves the settings and starts over in the same process; a new "ready" resets the window.
    // Not while a save runs: the restart would cut its steps off.
    function applySettings() {
        if (!canApply) return;
        debounce.stop();
        restarting = true;
        checkDebounce.stop();
        helper.write(JSON.stringify({ type: "settings", paths: draft }) + "\n");
    }

    function discardSettings() {
        const d = {};
        for (const s of settings) d[s.key] = s.own;
        draft = d;
        checked = null;
        settingsError = "";
        checkDebounce.stop();
    }

    // snapshots (ticket E18): "Open" fills the trial, as the controls do; the live file stays
    readonly property SnapshotStore snapshots: SnapshotStore {
        kind: "palette"
        noun: app.noun
        palette: app
        onLoaded: data => {
            app.trial = JSON.parse(JSON.stringify(data));
            app.trialAll = false;
            debounce.stop();
            app.request();
        }
    }

    // the snapshot the trial was opened from or saved as, while the trial still equals it; else ""
    readonly property string trialName: snapshots.name && sameRecipe(trial, snapshots.data) ? snapshots.name : ""

    // equal recipes whatever the order of their keys (the helper sends them sorted, a recipe file keeps its own order)
    function sameRecipe(a, b) {
        return canonical(a) === canonical(b);
    }

    // sections and fields sorted by name (JSON.stringify of the QML engine ignores the order of a key list)
    function canonical(recipe) {
        if (!recipe) return "";
        return Object.keys(recipe).sort().map(section => section + ":" + Object.keys(recipe[section]).sort()
            .map(key => key + "=" + JSON.stringify(recipe[section][key])).join(",")).join(";");
    }

    function restore() {
        trial = JSON.parse(JSON.stringify(recipe));
        trialAll = false;
        debounce.stop();
        request();
    }

    function send(m) {
        helper.write(JSON.stringify(m) + "\n");
    }

    function onMessage(m) {
        handle(m);
        message(m);
    }

    function handle(m) {
        if (m.type === "ready") {
            // also after a settings change: everything computed so far belonged to the old paths, and the
            // trial starts again from the (maybe other) recipe file; the selected wallpaper stays if it is there
            const before = it ? it.fileName : "";
            results = {};
            done = {};
            pending = false;
            rev++;
            trialAll = false;
            helperError = "";
            saving = false;
            saveError = "";
            applyStage = "";
            applyError = "";
            restarting = false;
            settings = m.settings;
            settingsFile = m.settingsFile;
            recipeFile = m.recipeFile || "";
            settingsWarning = m.settingsWarning || "";
            matugenWarning = m.matugenWarning || "";
            problems = m.problems;
            discardSettings();
            recipe = m.recipe;
            recipeWarnings = m.recipeWarnings || [];
            fingerprint = m.fingerprint || "";
            trial = JSON.parse(JSON.stringify(m.recipe));
            trialFingerprint = m.fingerprint || "";
            options = m.options;
            look = m.look;
            current = m.current || "";
            items = m.items;
            const kept = items.findIndex(x => x.fileName === before);
            sel = kept >= 0 ? kept : Math.max(0, items.findIndex(x => x.fileName === current));
            request();
        } else if (m.type === "recipeRead") {
            // the live file changed outside the tool (a hand edit, a delete): the trial follows unless it was edited
            const follow = !trialEdited;
            recipe = m.recipe;
            recipeWarnings = m.recipeWarnings || [];
            fingerprint = m.fingerprint;
            if (follow) {
                trial = JSON.parse(JSON.stringify(m.recipe));
                trialFingerprint = m.fingerprint;
            }
            request();
        } else if (m.type === "accepted") {
            fingerprint = m.fingerprints[0];
            trialFingerprint = m.fingerprints[1];
        } else if (m.type === "result" || m.type === "error") {
            const r = results[m.fingerprint] || (results[m.fingerprint] = {});
            if (m.type === "error")
                r[m.fileName] = { error: m.message };
            else {
                m.key = Object.values(m.colors).join(","); // tokens come sorted: equal palettes, equal keys
                r[m.fileName] = m;
            }
            pending = true;
        } else if (m.type === "saved") {
            saving = false;
            if (m.error) {
                saveError = m.error;
            } else {
                // story 54: the saved recipe is the current recipe now, so the differences and the summary go;
                // the trial stays as it is (equal to it, unless a control moved after the click)
                recipe = m.recipe;
                fingerprint = m.fingerprint;
                request();
            }
        } else if (m.type === "apply") {
            applyStage = m.stage;
            applyError = m.message || "";
        } else if (m.type === "checked") {
            checked = m.settings;
        } else if (m.type === "settingsSaved") {
            restarting = false;
            settingsError = m.error;
        } else if (m.type === "progress") {
            done[m.fingerprint] = m.done;
            pending = true;
        }
    }

    function copy(hex) {
        Quickshell.clipboardText = hex;
        copied = hex;
    }

    function contrastText(hex) {
        if (!hex) return "#f2f2f2";
        const c = Qt.color(hex);
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.55 ? "#111111" : "#f2f2f2";
    }

    // the tab interface of ADR 0020
    readonly property bool edited: trialEdited
    readonly property bool busy: saving || applying || restarting
    readonly property bool saveFirst: true   // "Save all" saves the palette first: longest, fails most often
    readonly property string effect: "writes the palette recipe file, rebuilds the carousel index and recolours the current wallpaper"
    readonly property string noun: "palette recipe"
    // the save and the steps after it for the toast; null = nothing to say
    readonly property var status: saving ? { text: "Saving the palette recipe…", level: "busy" }
                                  : saveError ? { text: "Palette recipe not saved: " + saveError, level: "error" }
                                  : applyStage === "indexer" ? { text: "Palette recipe saved. Rebuilding the carousel index…", level: "busy" }
                                  : applyStage === "wallpaper" ? { text: "Applying the new recipe to the current wallpaper…", level: "busy" }
                                  : applyStage === "done" ? { text: "Palette recipe saved and applied to the desktop. No commit in the dotfiles.", level: "info" }
                                  : applyStage === "error" ? { text: "Palette recipe saved, but applying it failed: " + applyError, level: "error" }
                                  : null
    readonly property string wallpaperName: it ? it.fileName : ""
    readonly property var currentColors: colorsOf(fingerprint)
    readonly property var trialColors: colorsOf(trialFingerprint)

    function save() { saveTrial(); }

    function colorsOf(fp) {
        const r = it ? result(it.fileName, fp) : null;
        return r && !r.error ? r.colors : null;
    }

    Timer {
        // results to bindings in batches (see app.pending)
        interval: 80
        repeat: true
        running: app.pending
        onTriggered: {
            app.pending = false;
            app.rev++;
        }
    }

    Timer {
        // debounce of the controls: one request for the last value, not one per slider step
        id: debounce
        interval: 300
        onTriggered: app.request()
    }

    Timer {
        // the Settings tab: one check for the last text typed
        id: checkDebounce
        interval: 300
        onTriggered: app.checkDraft()
    }

    FileView {
        // the live palette recipe file (ticket E15, as the Look tab): the helper reads it (palette_recipe.load, the
        // same rules as Ajmashell); here only the change is seen. A delete = Ajmashell's default recipe.
        path: app.recipeFile
        watchChanges: !!app.recipeFile
        printErrors: false
        onFileChanged: app.send({ type: "readRecipe" })
    }

    Process {
        id: helper
        command: ["python3", Quickshell.shellDir + "/helper/tuner.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    app.onMessage(JSON.parse(data));
                } catch (e) {
                    console.warn("tuner: bad message", e, data.slice(0, 200));
                }
            }
        }
        stderr: SplitParser { onRead: data => console.warn("tuner.py:", data) }
        onExited: code => {
            app.helperError = "The helper exited (code " + code + "), nothing is computed any more. Details: journal / terminal.";
            // a save in flight gets no answer any more: say so instead of "saving…" for good
            if (app.saving) app.saveError = "the helper did not answer; check the palette recipe file";
            else if (app.applying) app.applyError = "the helper did not finish";
            if (app.applying) app.applyStage = "error";
            app.saving = false;
            app.restarting = false;
        }
    }
}
