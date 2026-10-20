// The selected wallpaper, as in variant D of the prototype: preview with the candidates next to it (seed of each
// recipe marked), the colour category of the carousel for both, the mock-ups when the window is narrow (shell.qml),
// and the full token table below.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Flickable {
    id: v
    property var app
    property bool mockups: false // the mock-ups of both recipes here, under the candidates (narrow window)
    readonly property var it: app.it
    readonly property var res: it ? app.result(it.fileName) : null
    readonly property var trialRes: it ? app.result(it.fileName, app.trialFingerprint) : null

    function category(r) {
        return !r ? "computing…" : r.error ? "matugen error" : r.category;
    }

    clip: true
    contentHeight: main.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    Column {
        id: main
        width: v.width
        spacing: 14

        Text {
            // no wallpapers (index missing or empty): why, from the helper's problems (ticket 09)
            visible: !v.it && v.app.settings.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            text: "No wallpapers to show." + (v.app.problems.length ? "\n\n" + v.app.problems.join("\n\n") : "")
            color: v.app.ui.text
            font { family: v.app.ui.font; pixelSize: 14 }
        }

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
                id: info
                width: Math.min(460, main.width)
                spacing: 8
                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: v.it ? v.it.fileName + (v.it.fileName === v.app.current ? "  · on desktop" : "") : ""
                    color: v.app.ui.text
                    font { family: v.app.ui.font; pixelSize: 16; bold: true }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    readonly property bool moved: !!(v.res && v.trialRes && v.res.category && v.res.category !== v.trialRes.category)
                    text: "Colour category: current " + v.category(v.res) + " · trial " + v.category(v.trialRes)
                          + (moved ? "   ← different" : "")
                    color: moved ? v.app.ui.trial : v.app.ui.dim
                    font { family: v.app.ui.font; pixelSize: 12 }
                }
                Repeater {
                    // matugen error of either recipe
                    model: [["current", v.res], ["trial", v.trialRes]].filter(x => x[1] && x[1].error)
                    Text {
                        required property var modelData
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "matugen error (" + modelData[0] + "): " + modelData[1].error
                        color: v.app.ui.error
                        font { family: v.app.ui.font; pixelSize: 12 }
                    }
                }
                Text { text: "Candidates (most dominant first)"; color: v.app.ui.dim; font { family: v.app.ui.font; pixelSize: 12 } }
                Repeater {
                    // candidates depend on the thumbnail only: the same for both recipes
                    model: v.res && v.res.candidates ? v.res.candidates : v.trialRes && v.trialRes.candidates ? v.trialRes.candidates : []
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
                            width: info.width - 46
                            wrapMode: Text.Wrap
                            readonly property bool isTrial: !!(v.trialRes && k.modelData === v.trialRes.seed)
                            text: "Candidate " + (k.index + 1) + "  " + k.modelData
                                  + (v.res && k.modelData === v.res.seed ? "   ← current seed" : "")
                                  + (isTrial ? "   ← trial seed" : "")
                            color: isTrial && !(v.res && k.modelData === v.res.seed) ? v.app.ui.trial : v.app.ui.text
                            font { family: "monospace"; pixelSize: 13 }
                        }
                    }
                }
            }
        }

        Previews {
            visible: v.mockups
            app: v.app
            width: Math.min(main.width, 900)
        }

        TokenTable {
            app: v.app
            res: v.res
            trialRes: v.trialRes
            width: main.width
        }
    }
}
