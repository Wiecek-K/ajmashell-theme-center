// SPDX-License-Identifier: AGPL-3.0-or-later
// The Palette tab (ticket 12): the palette tuning tool, layout = variant D of the prototype (branch
// prototype/faza-e-karta-ui, ADR 0019). Strip of all wallpapers on the left, the selected one with its candidates and
// the full token table in the middle, panel on the right with the controls of the trial recipe (ticket 05), and the
// desktop and kitty mock-ups of both recipes (ticket 06) between the table and the panel, or under the candidates when
// the window is too narrow for both. Only the view: the state is PaletteState.qml in the frame.
import QtQuick

Item {
    id: tab
    property var app    // PaletteState
    property var frame

    // the strip is vertical: ↑ ↓ follow it, ← → do the same; keys with Ctrl go on to the frame
    Keys.onUpPressed: app.select(app.sel - 1)
    Keys.onDownPressed: app.select(app.sel + 1)
    Keys.onLeftPressed: app.select(app.sel - 1)
    Keys.onRightPressed: app.select(app.sel + 1)
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Home) app.select(0);
        else if (e.key === Qt.Key_End) app.select(app.items.length - 1);
        else e.accepted = false;
    }

    Strip {
        id: strip
        app: tab.app
        width: 200
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; margins: 8 }
    }

    SidePanel {
        id: side
        app: tab.app
        frame: tab.frame
        width: 300
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
    }

    // Mock-ups beside the token table while the table keeps its two columns (980 px, TokenTable) and the
    // mock-ups get at least 420 px (prototype); otherwise inside the view, under the candidates (tiled window).
    readonly property real centre: width - strip.width - 2 * 8 - side.width - 2 * 16
    readonly property bool mockupsBeside: centre - 980 - 16 >= 420

    WallpaperView {
        app: tab.app
        mockups: !tab.mockupsBeside
        anchors { top: parent.top; bottom: parent.bottom; left: strip.right; right: tab.mockupsBeside ? beside.left : side.left; margins: 16 }
    }

    Flickable {
        id: beside
        visible: tab.mockupsBeside
        width: visible ? Math.min(900, tab.centre - 980 - 16) : 0
        anchors { top: parent.top; bottom: parent.bottom; right: side.left; topMargin: 16; bottomMargin: 16; rightMargin: 12 }
        clip: true
        contentHeight: besidePreviews.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Previews { id: besidePreviews; app: tab.app; width: beside.width }
    }
}
