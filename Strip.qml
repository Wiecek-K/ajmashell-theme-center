// Strip of all carousel wallpapers (thumbnails from the carousel cache). ← → move the selection (shell.qml);
// a click selects. Marks: selection frame, "bieżąca" = the system's current wallpaper, Seed dot, error badge.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: s
    property var app
    color: app.ui.panel

    ListView {
        id: list
        anchors { fill: parent; margins: 10 }
        orientation: ListView.Horizontal
        spacing: 8
        clip: true
        model: s.app.items
        currentIndex: s.app.sel
        // keep the selection in the middle, scrolled smoothly
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: width / 2 - (height * 16 / 9) / 2
        preferredHighlightEnd: width / 2 + (height * 16 / 9) / 2
        highlightMoveDuration: 150
        cacheBuffer: 2000
        boundsBehavior: Flickable.StopAtBounds
        // the highlight range applies only when the selection moves: re-centre after a resize and on load
        onWidthChanged: positionViewAtIndex(currentIndex, ListView.Center)
        onCountChanged: positionViewAtIndex(currentIndex, ListView.Center)
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        // the mouse wheel scrolls the strip sideways
        WheelHandler {
            onWheel: e => list.flick((e.angleDelta.y || e.angleDelta.x) * 12, 0)
        }

        delegate: Item {
            id: d
            required property var modelData
            required property int index
            readonly property var res: s.app.result(modelData.fileName)
            readonly property bool selected: index === s.app.sel
            height: list.height - 12
            width: height * 16 / 9

            Image {
                anchors { fill: parent; margins: 3 }
                source: "file://" + d.modelData.thumb
                sourceSize.height: 160
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: d.res ? 1 : 0.55
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 4
                border.width: 3
                border.color: d.selected ? s.app.ui.accent : "transparent"
            }
            Rectangle {
                visible: d.modelData.fileName === s.app.current
                anchors { left: parent.left; top: parent.top; margins: 8 }
                width: cur.implicitWidth + 12; height: 18; radius: 9
                color: s.app.ui.accent
                Text { id: cur; anchors.centerIn: parent; text: "bieżąca"; color: "#101010"; font { family: s.app.ui.font; pixelSize: 11; bold: true } }
            }
            Rectangle {
                visible: !!(d.res && d.res.seed)
                anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                width: 16; height: 16; radius: 8
                color: d.res && d.res.seed ? d.res.seed : "transparent"
                border.color: "white"
            }
            Rectangle {
                visible: !!(d.res && d.res.error)
                anchors { right: parent.right; top: parent.top; margins: 8 }
                width: 20; height: 20; radius: 10
                color: s.app.ui.error
                Text { anchors.centerIn: parent; text: "!"; color: "#101010"; font { pixelSize: 13; bold: true } }
            }
            MouseArea { anchors.fill: parent; onClicked: s.app.select(d.index) }
        }
    }
}
