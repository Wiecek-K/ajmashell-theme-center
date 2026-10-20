// Right panel (variant D of the prototype): the Przepis shown, folder progress ("48/106"), the last copied hex.
// The controls of the trial Przepis come here in ticket 05.
import QtQuick

Rectangle {
    id: p
    property var app
    color: app.ui.panel

    readonly property var r: app.recipe

    Column {
        anchors { fill: parent; margins: 16 }
        spacing: 14

        Text { text: "Przepis obecny"; color: p.app.ui.accent; font { family: p.app.ui.font; pixelSize: 14; bold: true } }
        Text { text: "plik Przepisu systemu"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }

        Grid {
            columns: 2
            columnSpacing: 12
            rowSpacing: 6
            Repeater {
                // label, value, label, value, …
                model: p.r ? [
                    "Wybór Seeda", p.r.seed.rule === "dominant" ? "najbardziej dominujący" : p.r.seed.rule,
                    "Schemat", p.r.palette.scheme.replace("scheme-", ""),
                    "Kontrast", String(p.r.palette.contrast),
                    "Jasność ciemnej", String(p.r.palette.lightnessDark)
                ] : []
                Text {
                    required property string modelData
                    required property int index
                    text: modelData
                    color: index % 2 ? p.app.ui.text : p.app.ui.dim
                    font { family: p.app.ui.font; pixelSize: 12 }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: p.app.ui.line }

        Text {
            text: (p.app.done < p.app.total ? "Liczenie " : "Policzone ") + p.app.done + "/" + p.app.total
            color: p.app.done < p.app.total ? p.app.ui.text : p.app.ui.dim
            font { family: "monospace"; pixelSize: 13 }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: p.app.copied ? "Skopiowano " + p.app.copied : "Klik w hex kopiuje."
            color: p.app.ui.dim
            font { family: p.app.ui.font; pixelSize: 12 }
        }
        Text {
            visible: p.app.helperError !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: p.app.helperError
            color: p.app.ui.error
            font { family: p.app.ui.font; pixelSize: 12 }
        }
    }
}
