//@ pragma AppId matugen-ajmashell-tool
// Palette tuning tool (faza E, ADR 0019): shows, for every carousel wallpaper, the palette the system gives it.
// Layout = variant D of the prototype (branch prototype/faza-e-karta-ui): one wallpaper at a time, a strip of all
// wallpapers at the bottom, the full token table next to the preview. Colours come from helper/tuner.py (real
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
        // results[fingerprint][fileName] = {seed, candidates, bucket, colors} or {error}; rev changes on every write,
        // so bindings that read results depend on rev
        property var results: ({})
        property int rev: 0
        property int done: 0
        property int total: 0
        property string helperError: ""
        property string copied: ""

        readonly property var ui: ({ bg: "#141416", panel: "#1d1d21", line: "#2e2e34", text: "#e6e6ea", dim: "#9a9aa4",
                                     accent: "#8ab4f8", error: "#ff8a80", font: "Inter" })

        function result(fileName, fp) {
            rev; // dependency
            const r = results[fp || fingerprint];
            return r ? r[fileName] || null : null;
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
            helper.write(JSON.stringify({ type: "compute", recipe: recipe, order: order() }) + "\n");
        }

        function select(i) {
            if (i < 0 || i >= items.length || i === sel) return;
            sel = i;
            if (done < total) request(); // same recipe: the helper only moves the selected one to the front
        }

        function onMessage(m) {
            if (m.type === "ready") {
                recipe = m.recipe;
                fingerprint = m.fingerprint;
                current = m.current || "";
                items = m.items;
                sel = Math.max(0, items.findIndex(x => x.fileName === current));
                total = items.length;
                request();
            } else if (m.type === "result" || m.type === "error") {
                const r = results[m.fingerprint] || (results[m.fingerprint] = {});
                r[m.fileName] = m.type === "error" ? { error: m.message } : m;
                rev++;
            } else if (m.type === "progress" && m.fingerprint === fingerprint) {
                done = m.done;
                total = m.total;
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
            Keys.onLeftPressed: app.select(app.sel - 1)
            Keys.onRightPressed: app.select(app.sel + 1)
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Home) app.select(0);
                else if (e.key === Qt.Key_End) app.select(app.items.length - 1);
            }

            Header {
                id: header
                app: app
                anchors { top: parent.top; left: parent.left; right: parent.right }
            }

            WallpaperView {
                app: app
                anchors { top: header.bottom; bottom: strip.top; left: parent.left; right: parent.right }
            }

            Strip {
                id: strip
                app: app
                height: 150
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            }
        }
    }
}
