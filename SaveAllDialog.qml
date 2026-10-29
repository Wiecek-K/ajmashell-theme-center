// SPDX-License-Identifier: AGPL-3.0-or-later
// Modal of "Save all" (ticket 12, ADR 0020): a layer over the window that lists the tabs it saves, in the order it saves
// them, each with what its save does, and warns that the trial settings of other tabs are saved too. Esc and a click
// beside the box cancel; Enter does not confirm (only the button does).
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: d
    property var frame
    visible: frame.askingSaveAll
    color: "#a0000000"
    onVisibleChanged: if (visible) forceActiveFocus()

    // every key stays here while the modal is open: no tab or frame shortcut behind it
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Escape) d.frame.cancelSaveAll();
        e.accepted = true;
    }

    MouseArea { anchors.fill: parent; onClicked: d.frame.cancelSaveAll() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(560, parent.width - 32)
        height: col.implicitHeight + 48
        radius: 8
        color: d.frame.ui.panel
        border.color: d.frame.ui.line

        MouseArea { anchors.fill: parent } // a click in the box does not cancel

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
            spacing: 12

            Text { text: "Save all trial settings?"; color: d.frame.ui.text; font { family: d.frame.ui.font; pixelSize: 16; bold: true } }
            Repeater {
                model: d.frame.saveOrder // in the order of saving
                Text {
                    required property var modelData
                    width: col.width
                    wrapMode: Text.Wrap
                    text: "<b>" + modelData.title + "</b>: " + modelData.state.effect + "."
                    textFormat: Text.StyledText
                    color: d.frame.ui.text
                    font { family: d.frame.ui.font; pixelSize: 13 }
                }
            }
            Text {
                width: col.width
                wrapMode: Text.Wrap
                text: "The unsaved trial settings of every tab above are saved, not only those of the tab you are in."
                color: d.frame.ui.warn
                font { family: d.frame.ui.font; pixelSize: 12 }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Chip {
                    app: d.frame
                    label: "Cancel"
                    tone: d.frame.ui.accent
                    onClicked: d.frame.cancelSaveAll()
                }
                Chip {
                    app: d.frame
                    label: "Save all"
                    tone: d.frame.ui.trial
                    selected: true
                    onClicked: d.frame.saveAll()
                }
            }
        }
    }
}
