// SPDX-License-Identifier: AGPL-3.0-or-later
// Tab bar at the top of the window (ticket 12, ADR 0020): one chip per entry of the frame's tab list, the active one
// in the accent colour, " •" after a tab whose trial settings differ from the current ones, a red note after a tab
// that has a problem ("Settings · 2 missing"). Tabs marked "right" sit at the right edge. Before them the actions of
// the tab you are in (ticket E18, user 2026-10-31): Open and Save as (snapshots, the system file dialog), Save (the
// tab's own save: always the main file), Save all. Only buttons: what each does is in its tooltip, results in the toast.
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
            visible: !!parent.snap
            app: bar.frame
            tone: bar.frame.ui.accent
            label: parent.snap && parent.snap.busy ? "Open…" : "Open"
            usable: !!parent.snap && parent.snap.available && !parent.snap.busy
            tip: !parent.snap ? "" : parent.snap.warning ? parent.snap.warning
                 : "Open a snapshot into the trial " + parent.noun + " (Ctrl+O). Nothing changes in Ajmashell until you save."
            onClicked: bar.frame.openSnapshot()
        }
        Chip {
            visible: !!parent.snap
            app: bar.frame
            tone: bar.frame.ui.accent
            label: "Save as"
            usable: !!parent.snap && parent.snap.available && !parent.snap.busy
            tip: !parent.snap ? "" : parent.snap.warning ? parent.snap.warning
                 : "Save the trial " + parent.noun + " as a snapshot file, to open it again later (Ctrl+Shift+S). The main file stays."
            onClicked: bar.frame.saveSnapshot()
        }
        Chip {
            visible: typeof parent.st.save === "function"
            app: bar.frame
            tone: bar.frame.ui.trial
            label: parent.st.saving ? "saving…" : "Save"
            selected: bar.frame.canSaveTab
            usable: selected
            tip: "Save the trial " + parent.noun + " (Ctrl+S): " + (parent.st.effect || "") + "."
                 + (parent.st.edited ? "" : " Nothing to save: the trial equals the current one.")
            onClicked: bar.frame.saveTab()
        }
        Chip {
            app: bar.frame
            tone: bar.frame.ui.trial
            label: bar.frame.saveAllRunning ? "saving all…" : "Save all"
            selected: bar.frame.canSaveAll
            usable: selected
            tip: bar.frame.toSave.length
                 ? "Save every tab with a dot (" + bar.frame.toSave.map(t => t.title.toLowerCase()).join(", ") + "), after a confirmation."
                 : "Save every tab with a dot. Nothing to save now."
            onClicked: bar.frame.askSaveAll()
        }
        Item { width: 8; height: 1 }
        Repeater {
            model: bar.frame.tabs
            TabChip { id: rt; visible: !!rt.modelData.right }
        }
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: bar.frame.ui.line }
}
