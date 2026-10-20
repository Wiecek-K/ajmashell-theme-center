//@ pragma AppId matugen-ajmashell-tool
// Palette tuning tool (faza E, ADR 0019): shows, for every carousel wallpaper, the palette the system gives it.
// Layout = variant D of the prototype (branch prototype/faza-e-karta-ui): strip of all wallpapers on the left, the
// selected one with its Kandydaci and the full token table in the middle, panel on the right with the controls of the
// Przepis próbny (ticket 05; mock-ups between the table and the panel come in ticket 06). Colours come from helper/tuner.py (real
// matugen through the dotfiles' palette_recipe.py); this file only holds the state and the protocol.
// Start: qs -n -p ~/Projects/matugen-ajmashell-tool (the .desktop entry does the same).
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
        property var recipe: null       // Przepis obecny (the system file, validated by the helper)
        property string fingerprint: ""
        property var trial: null        // Przepis próbny: starts as a copy of the current one, changed by the controls
        property string trialFingerprint: ""
        // The trial is computed for the selected wallpaper only; the rest of the folder after the button
        // "przelicz wszystkie" (user, 2026-10-20). A new trial value goes back to the selected one only.
        property bool trialAll: false
        property var options: null      // palette_recipe.options(): rules, schemes, number ranges
        // results[fingerprint][fileName] = {seed, candidates, bucket, colors, key} or {error}; done[fingerprint] = n.
        // Messages write them at once, rev follows at most every 80 ms (pending): one rebind of the strip and the
        // summary per batch, not per message, so moving a control does not stall the window.
        property var results: ({})
        property var done: ({})
        property int rev: 0
        property bool pending: false
        property string helperError: ""
        property string copied: ""

        readonly property bool trialDiffers: fingerprint !== trialFingerprint
        readonly property int total: items.length
        // the folder summary: wallpapers with both results, of them how many get another Seed / only another palette
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

        // What the trial changes on one wallpaper: "seed", "palette" (same Seed, other tokens), "same", or "" while
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
            if (!items.length) return;
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

        function restore() {
            trial = JSON.parse(JSON.stringify(recipe));
            trialAll = false;
            debounce.stop();
            request();
        }

        function onMessage(m) {
            if (m.type === "ready") {
                recipe = m.recipe;
                fingerprint = m.fingerprint;
                trial = JSON.parse(JSON.stringify(m.recipe));
                trialFingerprint = m.fingerprint;
                options = m.options;
                current = m.current || "";
                items = m.items;
                sel = Math.max(0, items.findIndex(x => x.fileName === current));
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
        onExited: code => app.helperError = "Pomocnik zakończył pracę (kod " + code + "), liczenie stoi. Szczegóły: journal / terminal."
    }

    FloatingWindow {
        id: win
        title: "Strojenie palety matugena"
        implicitWidth: 1600
        implicitHeight: 1000
        color: app.ui.bg
        onVisibleChanged: if (!visible) Qt.quit()

        Item {
            anchors.fill: parent
            focus: true
            // the strip is vertical: ↑ ↓ follow it, ← → do the same
            Keys.onUpPressed: app.select(app.sel - 1)
            Keys.onDownPressed: app.select(app.sel + 1)
            Keys.onLeftPressed: app.select(app.sel - 1)
            Keys.onRightPressed: app.select(app.sel + 1)
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Home) app.select(0);
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

            WallpaperView {
                app: app
                anchors { top: parent.top; bottom: parent.bottom; left: strip.right; right: side.left; margins: 16 }
            }
        }
    }
}
