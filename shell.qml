// SPDX-License-Identifier: AGPL-3.0-or-later
pragma ComponentBehavior: Bound
//@ pragma AppId ajmashell-theme-center
// Ajmashell Theme Center: the frame (ticket 12, ADR 0020). Tab bar at the top, the tabs below, "Save all" with its
// modal. The tab list below drives all of it; a tab = a view file and a state object (or the state of another tab).
// The states are created here at start and live until the window closes, together with the helper of PaletteState;
// a view is created when its tab opens first, then stays alive hidden.
// Tab state interface (read only for the frame): edited (trial differs from current), busy, save(), saving, saveError,
// effect (one sentence for the modal), optional saveFirst, note and alert (bar), leave() (called when the tab is left).
// Start: qs -n -p ~/Projects/ajmashell-theme-center (the .desktop entry does the same).
import QtQuick
import Quickshell

ShellRoot {
    id: root

    PaletteState { id: palette; ui: center.ui }
    LookState { id: look; palette: palette }
    SettingsState { id: settings; palette: palette }

    QtObject {
        id: center

        readonly property var ui: ({ bg: "#141416", panel: "#1d1d21", line: "#2e2e34", text: "#e6e6ea", dim: "#9a9aa4",
                                     accent: "#8ab4f8", trial: "#ffb74d", error: "#ff8a80", warn: "#ffd54f", scrim: "#a0000000",
                                     font: "Inter" })

        // in bar order; "right" tabs at the end. The window starts on the first one.
        readonly property var tabs: [
            { title: "Palette", source: "PaletteTab.qml", state: palette },
            { title: "Look", source: "LookTab.qml", state: look },
            { title: "Settings", source: "SettingsTab.qml", state: settings, right: true }
        ]
        property int current: 0
        property int previous: 0

        function select(i) {
            if (i < 0 || i >= tabs.length) return;
            if (i !== current) {
                const left = tabs[current].state;
                if (left.leave) left.leave();
                previous = current;
                current = i;
            }
            area.open(i);
        }

        // Ctrl+1, Ctrl+2…: the n-th tab of the bar, not counting the right ones
        function selectNth(n) {
            const i = tabs.findIndex(t => !t.right && n-- === 0);
            if (i >= 0) select(i);
        }

        // Ctrl+,: Settings, or back to the tab before it
        function toggleSettings() {
            const s = tabs.findIndex(t => t.state === settings);
            select(current === s ? previous : s);
        }

        // "Save all": the edited tabs, the palette first (longest, fails most often), then in bar order
        readonly property var toSave: tabs.filter(t => t.state.edited)
        readonly property var saveOrder: toSave.filter(t => t.state.saveFirst).concat(toSave.filter(t => !t.state.saveFirst))
        property bool askingSaveAll: false
        property bool saveAllRunning: false
        readonly property bool canSaveAll: toSave.length > 0 && !saveAllRunning && !tabs.some(t => t.state.busy)
        property var queue: []
        property var step: null      // the tab whose save runs
        property var log: []
        property string saveAllMessage: ""
        property bool saveAllFailed: false

        function askSaveAll() {
            if (canSaveAll) askingSaveAll = true;
        }

        function cancelSaveAll() {
            askingSaveAll = false;
            area.open(current); // keys back to the tab
        }

        function saveAll() {
            askingSaveAll = false;
            area.open(current);
            if (!canSaveAll) return;
            queue = saveOrder.slice();
            log = [];
            saveAllMessage = "";
            saveAllFailed = false;
            saveAllRunning = true;
            next();
        }

        // One tab after the other; a save that answers later (saving) goes on from the Connections below. Background
        // steps after a save (the palette's indexer and wallpaper) do not hold the next tab.
        function next() {
            while (queue.length) {
                step = queue[0];
                step.state.save();
                if (step.state.saving) return;
                if (!stepDone(false)) return;
            }
            finish();
        }

        // false = stop: the save failed, or did not start (started = it was saving; a tab still edited after a
        // finished save only had a control moved meanwhile)
        function stepDone(started) {
            const t = step;
            const name = t.title.toLowerCase();
            step = null;
            queue = queue.slice(1);
            const failed = t.state.saveError ? "error " + t.state.saveError : !started && t.state.edited ? "not saved (busy)" : "";
            if (!failed) {
                log = log.concat([name + ": saved"]);
                return true;
            }
            log = log.concat([name + ": " + failed], queue.map(q => q.title.toLowerCase() + ": not saved"));
            saveAllFailed = true;
            queue = [];
            finish();
            return false;
        }

        function afterStep() {
            if (step && !step.state.saving && stepDone(true)) next();
        }

        function finish() {
            saveAllRunning = false;
            saveAllMessage = log.join(", ");
        }
    }

    Connections {
        target: center.step ? center.step.state : null
        // later, not here: a tab may set saving = false before its error or its new current value
        function onSavingChanged() {
            if (center.step && !center.step.state.saving) Qt.callLater(center.afterStep);
        }
    }

    FloatingWindow {
        title: "Ajmashell Theme Center"
        implicitWidth: 1600
        implicitHeight: 1000
        color: center.ui.bg
        onVisibleChanged: if (!visible) Qt.quit()

        Item {
            // keys the active tab does not take: the frame's shortcuts
            anchors.fill: parent
            Keys.onPressed: e => {
                if (!(e.modifiers & Qt.ControlModifier)) return;
                if (e.key === Qt.Key_Comma) center.toggleSettings();
                else if (e.key === Qt.Key_Backtab) center.select((center.current + center.tabs.length - 1) % center.tabs.length);
                else if (e.key === Qt.Key_Tab) center.select((center.current + 1) % center.tabs.length);
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) center.selectNth(e.key - Qt.Key_1);
                else return;
                e.accepted = true;
            }

            TabBar {
                id: bar
                frame: center
                anchors { top: parent.top; left: parent.left; right: parent.right }
            }

            Item {
                id: area
                anchors { top: bar.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }

                // creates the tab's view the first time, then gives it the keys
                function open(i) {
                    const l = views.itemAt(i) as Loader;
                    if (!l) return;
                    if (!l.item) l.setSource(Qt.resolvedUrl(center.tabs[i].source), { app: center.tabs[i].state, frame: center });
                    if (l.item) (l.item as Item).forceActiveFocus();
                }

                Repeater {
                    id: views
                    model: center.tabs
                    Loader {
                        required property int index
                        anchors.fill: parent
                        visible: index === center.current
                    }
                }
                Component.onCompleted: open(center.current)
            }

            SaveAllDialog {
                frame: center
                anchors.fill: parent
            }
        }
    }
}
