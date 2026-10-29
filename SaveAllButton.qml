// SPDX-License-Identifier: AGPL-3.0-or-later
// "Save all" (ticket 12, ADR 0020): one component for every tab, beside the tab's own save. Active while any tab has
// trial settings that differ from the current ones; the label names the tabs it saves. A click opens the frame's
// modal; under the button, what the last "Save all" saved and what not.
import QtQuick

Column {
    id: c
    property var frame
    spacing: 6

    Chip {
        app: c.frame
        tone: c.frame.ui.trial
        label: c.frame.saveAllRunning ? "saving all…"
               : "Save all" + (c.frame.toSave.length ? " (" + c.frame.toSave.map(t => t.title.toLowerCase()).join(", ") + ")" : "")
        selected: c.frame.canSaveAll
        enabled: selected
        onClicked: c.frame.askSaveAll()
    }
    Text {
        visible: text !== ""
        width: c.width
        wrapMode: Text.Wrap
        text: c.frame.saveAllMessage
        color: c.frame.saveAllFailed ? c.frame.ui.error : c.frame.ui.dim
        font { family: c.frame.ui.font; pixelSize: 12 }
    }
}
