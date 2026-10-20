// Top row: the Przepis shown, folder progress ("48/106") and the last copied hex.
import QtQuick

Rectangle {
    id: h
    property var app
    implicitHeight: 44
    color: app.ui.panel

    readonly property var r: app.recipe
    readonly property string recipeText: r ? "Seed: " + r.seed.rule + " · " + r.palette.scheme.replace("scheme-", "")
                                             + " · kontrast " + r.palette.contrast + " · jasność ciemnej " + r.palette.lightnessDark
                                           : "wczytywanie…"

    Row {
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 20
        Text { text: "Przepis obecny"; color: h.app.ui.accent; font { family: h.app.ui.font; pixelSize: 14; bold: true } }
        Text { text: h.recipeText; color: h.app.ui.text; font { family: h.app.ui.font; pixelSize: 13 } }
    }

    Row {
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 20
        Text {
            visible: h.app.helperError !== ""
            text: h.app.helperError
            color: h.app.ui.error
            font { family: h.app.ui.font; pixelSize: 13 }
        }
        Text {
            text: h.app.copied ? "Skopiowano " + h.app.copied : "Klik w próbkę kopiuje hex"
            color: h.app.ui.dim
            font { family: h.app.ui.font; pixelSize: 13 }
        }
        Text {
            text: (h.app.done < h.app.total ? "Liczenie " : "Policzone ") + h.app.done + "/" + h.app.total
            color: h.app.done < h.app.total ? h.app.ui.text : h.app.ui.dim
            font { family: "monospace"; pixelSize: 13 }
        }
    }
}
