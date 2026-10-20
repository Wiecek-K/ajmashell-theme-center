// Mock-ups of the selected wallpaper for the current recipe and the trial recipe side by side (ticket 06, as the
// previews of variant D in the prototype): desktop (Bar + control centre) above kitty in each column.
// While a result is still computing, a column keeps the last palette it had and says "computing…", so moving a
// control or the strip never shows an empty or grey frame.
pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: p
    property var app
    spacing: 8

    Repeater {
        // problems of the helper's system_look(): a template or rule it could not read
        model: p.app.look ? p.app.look.problems : []
        Text {
            required property string modelData
            width: p.width
            wrapMode: Text.Wrap
            text: "Mock-ups: " + modelData
            color: p.app.ui.error
            font { family: p.app.ui.font; pixelSize: 12 }
        }
    }

    Row {
        id: cols
        width: p.width
        spacing: 12

        Repeater {
            model: [false, true] // trial?
            Column {
                id: col
                required property bool modelData
                readonly property bool trial: modelData
                readonly property var res: p.app.it ? p.app.result(p.app.it.fileName, trial ? p.app.trialFingerprint : p.app.fingerprint) : null
                readonly property bool ready: !!(res && res.colors)
                // last palette with colours (see the header); from res itself: `ready` may still be stale here
                property var shown: ({})
                onResChanged: if (res && res.colors) shown = res.colors
                Component.onCompleted: if (res && res.colors) shown = res.colors

                width: (cols.width - cols.spacing) / 2
                spacing: 6

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (col.trial ? "Trial" : "Current") + (col.ready ? " · seed " + col.res.seed
                          : col.res && col.res.error ? " · matugen error" : " · computing…")
                    color: col.trial ? p.app.ui.trial : p.app.ui.accent
                    font { family: p.app.ui.font; pixelSize: 12; bold: true }
                }
                DesktopMock {
                    width: col.width; height: Math.round(width * 9 / 16)
                    c: col.shown
                    thumb: p.app.it ? p.app.it.thumb : ""
                }
                KittyMock {
                    width: col.width; height: Math.round(width * 9 / 16)
                    c: col.shown
                    look: p.app.look
                    thumb: p.app.it ? p.app.it.thumb : ""
                }
            }
        }
    }
}
