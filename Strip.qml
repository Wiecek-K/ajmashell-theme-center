// Strip of all carousel wallpapers on the left (thumbnails from the carousel cache), as in variant D of the
// prototype. Arrows move the selection (shell.qml); a click selects. Marks: selection frame, "bieżąca" = the
// system's current wallpaper, Seed dot (a second one when the trial picks another Seed), error badge, and what the
// Przepis próbny changes there ("Seed" or "paleta").
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ListView {
    id: list
    property var app
    clip: true
    spacing: 6
    model: app.items
    currentIndex: app.sel
    // keep the selection in the middle, scrolled smoothly
    highlightRangeMode: ListView.ApplyRange
    preferredHighlightBegin: height / 2 - (width * 9 / 16) / 2
    preferredHighlightEnd: height / 2 + (width * 9 / 16) / 2
    highlightMoveDuration: 150
    cacheBuffer: 2000
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    // the highlight range applies only when the selection moves: re-centre after a resize and on load
    onHeightChanged: positionViewAtIndex(currentIndex, ListView.Center)
    onCountChanged: positionViewAtIndex(currentIndex, ListView.Center)

    delegate: Item {
        id: d
        required property var modelData
        required property int index
        readonly property var res: list.app.result(modelData.fileName)
        readonly property var trialRes: list.app.result(modelData.fileName, list.app.trialFingerprint)
        readonly property string diff: list.app.diff(modelData.fileName)
        readonly property bool selected: index === list.app.sel
        width: list.width - 10
        height: width * 9 / 16

        Image {
            anchors { fill: parent; margins: 3 }
            source: "file://" + d.modelData.thumb
            sourceSize.width: 400
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: d.res ? 1 : 0.55
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 3
            border.color: d.selected ? list.app.ui.accent : "transparent"
        }
        Rectangle {
            visible: d.modelData.fileName === list.app.current
            anchors { left: parent.left; top: parent.top; margins: 8 }
            width: cur.implicitWidth + 10; height: 16; radius: 8
            color: list.app.ui.accent
            Text { id: cur; anchors.centerIn: parent; text: "bieżąca"; color: "#101010"; font { family: list.app.ui.font; pixelSize: 10; bold: true } }
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
            spacing: 4
            Rectangle {
                visible: !!(d.res && d.res.seed)
                width: 14; height: 14; radius: 7
                color: d.res && d.res.seed ? d.res.seed : "transparent"
                border.color: "white"
            }
            Rectangle {
                visible: d.diff === "seed"
                width: 14; height: 14; radius: 7
                color: d.trialRes && d.trialRes.seed ? d.trialRes.seed : "transparent"
                border { color: list.app.ui.trial; width: 2 }
            }
        }
        Rectangle {
            visible: d.diff === "seed" || d.diff === "palette"
            anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
            width: chg.implicitWidth + 10; height: 16; radius: 8
            color: list.app.ui.trial
            Text { id: chg; anchors.centerIn: parent; text: d.diff === "seed" ? "Seed" : "paleta"; color: "#101010"; font { family: list.app.ui.font; pixelSize: 10; bold: true } }
        }
        Rectangle {
            visible: !!(d.res && d.res.error)
            anchors { right: parent.right; top: parent.top; margins: 8 }
            width: 18; height: 18; radius: 9
            color: list.app.ui.error
            Text { anchors.centerIn: parent; text: "!"; color: "#101010"; font { pixelSize: 12; bold: true } }
        }
        MouseArea { anchors.fill: parent; onClicked: list.app.select(d.index) }
    }
}
