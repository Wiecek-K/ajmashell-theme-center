// SPDX-License-Identifier: AGPL-3.0-or-later
// Small button / choice in the controls (as Chip.qml of the prototype, branch prototype/faza-e-karta-ui). tip = the
// tooltip on hover (the tab bar's buttons, ticket E18: the bar shows no other text).
import QtQuick
import QtQuick.Controls

Rectangle {
    id: chip
    property var app
    property string label
    property bool selected
    property color tone: app.ui.trial
    property string tip
    property bool usable: true  // false: greyed out and no click, but the tooltip still shows (enabled: false hides it)
    signal clicked
    implicitWidth: t.implicitWidth + 16
    implicitHeight: 24
    radius: 12
    color: selected ? tone : "transparent"
    border.color: selected ? tone : app.ui.line
    opacity: enabled && usable ? 1 : 0.4
    Text {
        id: t
        anchors.centerIn: parent
        text: chip.label
        color: chip.selected ? "#101010" : chip.app.ui.text
        font { family: chip.app.ui.font; pixelSize: 12 }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: chip.tip !== ""
        cursorShape: Qt.PointingHandCursor
        onClicked: if (chip.usable) chip.clicked()
    }
    ToolTip {
        // in the window's colours, not the light default of the style
        visible: chip.tip !== "" && ma.containsMouse
        delay: 400
        text: chip.tip
        contentWidth: Math.min(tipWidth.width + 1, 380) // wraps a long tip
        TextMetrics { id: tipWidth; text: chip.tip; font { family: chip.app.ui.font; pixelSize: 12 } }
        contentItem: Text {
            text: chip.tip
            wrapMode: Text.Wrap
            color: chip.app.ui.text
            font { family: chip.app.ui.font; pixelSize: 12 }
        }
        background: Rectangle { color: chip.app.ui.panel; radius: 6; border.color: chip.app.ui.line }
    }
}
