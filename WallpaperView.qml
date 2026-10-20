// The selected wallpaper, as in variant D of the prototype: preview with the Kandydaci next to it (Seed marked),
// the colour bucket of the carousel, and the full token table below.
import QtQuick
import QtQuick.Controls

Flickable {
    id: v
    property var app
    readonly property var it: app.it
    readonly property var res: it ? app.result(it.fileName) : null

    clip: true
    contentHeight: main.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    Column {
        id: main
        width: v.width
        spacing: 14

        Flow {
            width: parent.width
            spacing: 16

            Item {
                width: Math.min(520, parent.width)
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
                    sourceSize.width: 1040
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column {
                width: Math.min(460, main.width)
                spacing: 8
                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: v.it ? v.it.fileName + (v.it.fileName === v.app.current ? "  · bieżąca" : "") : ""
                    color: v.app.ui.text
                    font { family: v.app.ui.font; pixelSize: 16; bold: true }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: !v.res ? "Liczenie…"
                          : v.res.error ? "Błąd matugena: " + v.res.error
                          : "Kategoria karuzeli: " + v.res.bucket
                    color: v.res && v.res.error ? v.app.ui.error : v.app.ui.dim
                    font { family: v.app.ui.font; pixelSize: 12 }
                }
                Text { text: "Kandydaci (od najbardziej dominującego)"; color: v.app.ui.dim; font { family: v.app.ui.font; pixelSize: 12 } }
                Repeater {
                    model: v.res && v.res.candidates ? v.res.candidates : []
                    Row {
                        id: k
                        required property string modelData
                        required property int index
                        spacing: 10
                        Rectangle {
                            width: 36; height: 36; radius: 6
                            color: k.modelData
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: v.app.copy(k.modelData) }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Kandydat " + (k.index + 1) + "  " + k.modelData + (k.modelData === v.res.seed ? "   ← Seed" : "")
                            color: v.app.ui.text
                            font { family: "monospace"; pixelSize: 13 }
                        }
                    }
                }
            }
        }

        TokenTable {
            app: v.app
            res: v.res
            width: main.width
        }
    }
}
