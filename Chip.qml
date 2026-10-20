// Small button / choice in the controls (as Chip.qml of the prototype, branch prototype/faza-e-karta-ui).
import QtQuick

Rectangle {
    id: chip
    property var app
    property string label
    property bool selected
    property color tone: app.ui.trial
    signal clicked
    implicitWidth: t.implicitWidth + 16
    implicitHeight: 24
    radius: 12
    color: selected ? tone : "transparent"
    border.color: selected ? tone : app.ui.line
    opacity: enabled ? 1 : 0.4
    Text {
        id: t
        anchors.centerIn: parent
        text: chip.label
        color: chip.selected ? "#101010" : chip.app.ui.text
        font { family: chip.app.ui.font; pixelSize: 12 }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
}
