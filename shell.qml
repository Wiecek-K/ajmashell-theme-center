//@ pragma AppId ajmashell-theme-center
// Ajmashell Theme Center, palette tuning (faza E, ADR 0019): shows, for every carousel wallpaper, the palette the
// system gives it.
// Layout = variant D of the prototype (branch prototype/faza-e-karta-ui): strip of all wallpapers on the left, the
// selected one with its candidates and the full token table in the middle, panel on the right with the controls of the
// trial recipe (ticket 05), and the desktop and kitty mock-ups of both recipes (ticket 06) between the table and
// the panel, or under the candidates when the window is too narrow for both. Colours come from helper/tuner.py (real
// matugen through the Ajmashell palette_recipe.py); this file only holds the state and the protocol. The paths of the
// helper are set in the Settings panel (ticket 09): a change restarts the helper, the window stays.
// Start: qs -n -p ~/Projects/ajmashell-theme-center (the .desktop entry does the same).
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    QtObject {
        id: app

        property var items: []          // [{fileName, path, thumb}] in carousel index order
        property string current: ""     // fileName of the system's current wallpaper
        property int sel: 0
        readonly property var it: items.length ? items[sel] : null
        property var recipe: null       // current recipe (the system file, validated by the helper)
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
        readonly property bool trialEdited: JSON.stringify(trial) !== JSON.stringify(recipe)
        property string copied: ""
        // Settings (ticket 09): settings = settings.status() of the paths in use, problems = what each missing path
        // stops (shown in the panel and, without wallpapers, in the middle); the panel edits draft {key: text}, the
        // helper checks it ("checked" = status of the draft) and, on apply, saves it and restarts (restarting)
        property var settings: []
        property string settingsFile: ""
        property string recipeFile: ""  // named by the recipe module, not a setting (user, 2026-10-21)
        property string settingsWarning: ""
        property var problems: []
        property bool settingsOpen: false
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

        readonly property var ui: ({ bg: "#141416", panel: "#1d1d21", line: "#2e2e34", text: "#e6e6ea", dim: "#9a9aa4",
                                     accent: "#8ab4f8", trial: "#ffb74d", error: "#ff8a80", font: "Inter" })

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

        // A path typed in the Settings panel: the helper checks the draft after 300 ms without typing.
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

        // closing the panel (button or Ctrl+,) drops what was typed and not applied
        function toggleSettings() {
            if (settingsOpen) discardSettings();
            settingsOpen = !settingsOpen;
        }

        function restore() {
            trial = JSON.parse(JSON.stringify(recipe));
            trialAll = false;
            debounce.stop();
            request();
        }

        function onMessage(m) {
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
                problems = m.problems;
                discardSettings();
                recipe = m.recipe;
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
        // the Settings panel: one check for the last text typed
        id: checkDebounce
        interval: 300
        onTriggered: app.checkDraft()
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

    FloatingWindow {
        id: win
        title: "Ajmashell Theme Center"
        implicitWidth: 1600
        implicitHeight: 1000
        color: app.ui.bg
        onVisibleChanged: if (!visible) Qt.quit()

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            // the strip is vertical: ↑ ↓ follow it, ← → do the same
            Keys.onUpPressed: app.select(app.sel - 1)
            Keys.onDownPressed: app.select(app.sel + 1)
            Keys.onLeftPressed: app.select(app.sel - 1)
            Keys.onRightPressed: app.select(app.sel + 1)
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Comma && e.modifiers & Qt.ControlModifier) app.toggleSettings();
                else if (e.key === Qt.Key_Home) app.select(0);
                else if (e.key === Qt.Key_End) app.select(app.items.length - 1);
            }

            Strip {
                id: strip
                app: app
                width: 200
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left; margins: 8 }
            }

            SidePanel {
                id: side
                app: app
                width: 300
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            }

            // Mock-ups beside the token table while the table keeps its two columns (980 px, TokenTable) and the
            // mock-ups get at least 420 px (prototype); otherwise inside the view, under the candidates (tiled window).
            readonly property real centre: width - strip.width - 2 * 8 - side.width - 2 * 16
            readonly property bool mockupsBeside: centre - 980 - 16 >= 420

            WallpaperView {
                app: app
                mockups: !parent.mockupsBeside
                anchors { top: parent.top; bottom: parent.bottom; left: strip.right; right: parent.mockupsBeside ? beside.left : side.left; margins: 16 }
            }

            Flickable {
                id: beside
                visible: parent.mockupsBeside
                width: visible ? Math.min(900, parent.centre - 980 - 16) : 0
                anchors { top: parent.top; bottom: parent.bottom; right: side.left; topMargin: 16; bottomMargin: 16; rightMargin: 12 }
                clip: true
                contentHeight: besidePreviews.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Previews { id: besidePreviews; app: app; width: beside.width }
            }

            SettingsPanel {
                app: app
                visible: app.settingsOpen
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: side.left }
                // a closed panel gives the keys back to the strip
                onVisibleChanged: if (!visible) keys.forceActiveFocus()
            }
        }
    }
}
