// SPDX-License-Identifier: AGPL-3.0-or-later
// Toast under the tab bar, at the right edge under its buttons (ticket E18, user 2026-10-31): the result of a save, a
// "Save all", a snapshot. The frame calls show() with a tab's status {text, level} and where it came from. "info" goes
// after 5 s; "busy" stays until the same source says more (or nothing); "error" and "warn" stay until a click.
import QtQuick

Rectangle {
    id: toast
    property var frame
    property var shown: null    // {text, level}
    property var source: null   // the object whose status is shown

    function show(status, from) {
        if (!status || !status.text) {
            // the source has nothing more to say: its "busy" goes, a result stays
            if (from === source && shown && shown.level === "busy") shown = null;
            return;
        }
        shown = status;
        source = from;
        if (status.level === "info") hide.restart();
        else hide.stop();
    }

    readonly property color tone: !shown ? frame.ui.line : shown.level === "error" ? frame.ui.error
                                  : shown.level === "warn" ? frame.ui.warn : shown.level === "busy" ? frame.ui.trial : frame.ui.accent
    visible: !!shown
    width: Math.min(560, msg.implicitWidth + 24)
    height: msg.implicitHeight + 16
    radius: 8
    color: frame.ui.panel
    border.color: tone

    Text {
        id: msg
        x: 12
        y: 8
        width: Math.min(implicitWidth, 560 - 24)
        wrapMode: Text.Wrap
        text: toast.shown ? toast.shown.text : ""
        color: toast.shown && toast.shown.level === "error" ? toast.frame.ui.error : toast.frame.ui.text
        font { family: toast.frame.ui.font; pixelSize: 12 }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toast.shown = null }
    Timer { id: hide; interval: 5000; onTriggered: toast.shown = null }
}
