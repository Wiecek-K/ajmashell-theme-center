// SPDX-License-Identifier: AGPL-3.0-or-later
// Tab bar at the top of the window (ticket 12, ADR 0020): one chip per entry of the frame's tab list, the active one
// in the accent colour, " •" after a tab whose trial settings differ from the current ones, a red note after a tab
// that has a problem ("Settings · 2 missing"). Tabs marked "right" sit at the right edge.
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
        Repeater {
            model: bar.frame.tabs
            TabChip { id: rt; visible: !!rt.modelData.right }
        }
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: bar.frame.ui.line }
}
