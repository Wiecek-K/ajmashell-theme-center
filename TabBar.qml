// SPDX-License-Identifier: AGPL-3.0-or-later
// Tab bar at the top of the window (ticket 12, ADR 0020): one chip per entry of the frame's tab list, the active one
// in the accent colour, " •" after a tab whose trial settings differ from the current ones, a red note after a tab
// that has a problem ("Settings · 2 missing"). Tabs marked "right" sit at the right edge. Before them the actions of
// the tab you are in (ticket E18, user 2026-10-31): Set (the tab's own save: always the main file, "Set" so it is not
// mixed up with the snapshots), Set all, then Save as and Open (snapshots, the system file dialog). Only buttons: what
// each does is in its tooltip, results in the toast.
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: bar
    property var frame
    implicitHeight: 40
    color: frame.ui.panel

    component TabChip: Chip {
        id: c
        required property var modelData
        required property int index
        readonly property var st: modelData.state
        app: bar.frame
        tone: bar.frame.ui.accent
        label: modelData.title + (st.edited ? " •" : "") + (st.note ? " · " + st.note : "")
        selected: bar.frame.current === index
        border.color: st.alert ? bar.frame.ui.error : selected ? tone : bar.frame.ui.line
        tip: modelData.tip || ""
        onClicked: bar.frame.select(index)
    }

    Row {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 8
        Repeater {
            model: bar.frame.tabs
            TabChip { id: lt; visible: !lt.modelData.right }
        }
    }
    Row {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 8
        readonly property var st: bar.frame.tab
        readonly property var snap: st.snapshots || null
        readonly property string noun: st.noun || ""
        Chip {
            visible: typeof parent.st.save === "function"
            app: bar.frame
            tone: bar.frame.ui.trial
            label: parent.st.saving ? "setting…" : "Set"
            selected: bar.frame.canSaveTab
            usable: selected
            tip: "Set the trial " + parent.noun + " (Ctrl+S): " + (parent.st.effect || "") + "."
                 + (parent.st.edited ? "" : " Nothing to set: the trial equals the current one.")
            onClicked: bar.frame.saveTab()
        }
        Chip {
            app: bar.frame
            tone: bar.frame.ui.trial
            label: bar.frame.saveAllRunning ? "setting all…" : "Set all"
            selected: bar.frame.canSaveAll
            usable: selected
            tip: bar.frame.toSave.length
                 ? "Set every tab with a dot (" + bar.frame.toSave.map(t => t.title.toLowerCase()).join(", ") + "), after a confirmation."
                 : "Set every tab with a dot. Nothing to set now."
            onClicked: bar.frame.askSaveAll()
        }
        Item { visible: !!parent.snap; width: 8; height: 1 }
        Chip {
            visible: !!parent.snap
            app: bar.frame
            tone: bar.frame.ui.accent
            label: "Save as"
            usable: !!parent.snap && parent.snap.available && !parent.snap.busy
            tip: !parent.snap ? "" : parent.snap.warning ? parent.snap.warning
                 : "Save the trial " + parent.noun + " as a snapshot file, to open it again later (Ctrl+Shift+S). Ajmashell does not change."
            onClicked: bar.frame.saveSnapshot()
        }
        Chip {
            visible: !!parent.snap
            app: bar.frame
            tone: bar.frame.ui.accent
            label: parent.snap && parent.snap.busy ? "Open…" : "Open"
            usable: !!parent.snap && parent.snap.available && !parent.snap.busy
            tip: !parent.snap ? "" : parent.snap.warning ? parent.snap.warning
                 : "Open a snapshot into the trial " + parent.noun + " (Ctrl+O). Nothing changes in Ajmashell until you set it."
            onClicked: bar.frame.openSnapshot()
        }
        Item { width: 8; height: 1 }
        Repeater {
            model: bar.frame.tabs
            TabChip { id: rt; visible: !!rt.modelData.right }
        }
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: bar.frame.ui.line }
}
