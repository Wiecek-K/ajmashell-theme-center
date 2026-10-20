// The selected wallpaper: large preview, its Kandydaci with the Seed marked, the colour bucket of the carousel and
// the full token table. Wide window: preview left, table right; half-screen tile: table under the preview.
import QtQuick
import QtQuick.Controls

Item {
    id: v
    property var app
    readonly property var it: app.it
    readonly property var res: it ? app.result(it.fileName) : null
    readonly property bool wide: width >= 1700

    Flickable {
        id: flick
        anchors { fill: parent; margins: 16 }
        clip: true
        contentWidth: width
        contentHeight: v.wide ? height : info.height + 20 + table.height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: info
            // narrow: the preview takes at most ~45 % of the height, so part of the table stays in view
            width: v.wide ? Math.min(flick.width * 0.5, (flick.height - 230) * 16 / 9) : Math.min(flick.width, flick.height * 0.45 * 16 / 9)
            spacing: 12

            Item {
                width: parent.width
                height: width * 9 / 16
                // thumbnail at once, the full image over it when decoded (no blank frame while switching)
                Image {
                    anchors.fill: parent
                    source: v.it ? "file://" + v.it.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Image {
                    anchors.fill: parent
                    source: v.it ? "file://" + v.it.path : ""
                    sourceSize.width: width
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Text {
                width: parent.width
                elide: Text.ElideMiddle
                text: v.it ? v.it.fileName : ""
                color: v.app.ui.text
                font { family: v.app.ui.font; pixelSize: 15; bold: true }
            }
            Text {
                text: !v.res ? "Liczenie…"
                      : v.res.error ? "Błąd matugena: " + v.res.error
                      : "Seed " + v.res.seed + " · kategoria karuzeli " + v.res.bucket
                      + (v.it.fileName === v.app.current ? " · bieżąca tapeta systemu" : "")
                color: v.res && v.res.error ? v.app.ui.error : v.app.ui.dim
                font { family: v.app.ui.font; pixelSize: 13 }
            }

            Text { text: "Kandydaci (od najbardziej dominującego)"; color: v.app.ui.dim; font { family: v.app.ui.font; pixelSize: 12 } }
            Row {
                spacing: 16
                Repeater {
                    model: v.res && v.res.candidates ? v.res.candidates : []
                    Column {
                        id: k
                        required property string modelData
                        readonly property bool isSeed: modelData === v.res.seed
                        spacing: 4
                        Rectangle {
                            width: 64; height: 40; radius: 6
                            color: k.modelData
                            border.width: k.isSeed ? 3 : 1
                            border.color: k.isSeed ? v.app.ui.text : v.app.ui.line
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: v.app.copy(k.modelData) }
                        }
                        Text { text: k.modelData; color: v.app.ui.text; font { family: "monospace"; pixelSize: 11 } }
                        Text { text: k.isSeed ? "Seed" : " "; color: v.app.ui.accent; font { family: v.app.ui.font; pixelSize: 11; bold: true } }
                    }
                }
            }
        }

        TokenTable {
            id: table
            app: v.app
            res: v.res
            x: v.wide ? info.width + 32 : 0
            y: v.wide ? 0 : info.height + 20
            width: v.wide ? flick.width - x : flick.width
            columnHeight: v.wide ? flick.height : 0
        }
    }
}
