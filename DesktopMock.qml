// SPDX-License-Identifier: AGPL-3.0-or-later
// Desktop mock-up for one palette: the wallpaper with the Ajmashell Bar (islands as in NOTES.md "Bar look and
// layout": tray left; media, clock on the axis and workspaces in the centre; volume, mic, separator and the
// BT / Wi-Fi / bell pill right) and the control centre open under the bell. Colours: Mockups.desktop().
// The texts copy the real Ajmashell, whose interface is Polish, so they stay Polish (mock-up content, ticket 08).
// Built on MockPulpit.qml of the prototype (branch prototype/faza-e-karta-ui), laid out after the real Bar.
pragma ComponentBehavior: Bound
import QtQuick
import "Mockups.js" as Mockups

Item {
    id: m
    property var c: ({})         // palette {token: hex}
    property string thumb
    readonly property var d: Mockups.desktop(m.c)
    clip: true

    // inline components do not see this file's ids: colours and the font come in through properties
    component Island: Rectangle {
        default property alias content: row.data
        property var d
        property real pad: 5
        width: row.implicitWidth + 2 * pad
        height: 15
        radius: height / 2
        color: d.island
        Row { id: row; anchors.centerIn: parent; spacing: 3 }
    }
    component BarText: Text {
        property var d
        color: d.text
        font { family: Mockups.font; pixelSize: 8; bold: true }
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
    component Slider: Column {
        id: sl
        property var d
        property string label
        property real level
        spacing: 2
        Text { text: sl.label; color: sl.d.popupSubtext; font { family: Mockups.font; pixelSize: 7 } }
        Rectangle {
            width: sl.width; height: 6; radius: 3; color: sl.d.track
            Rectangle { width: sl.width * sl.level; height: 6; radius: 3; color: sl.d.fill }
        }
    }

    // same source size as the strip: the thumbnail is already in Qt's image cache, no blank frame on a switch
    Image { anchors.fill: parent; source: m.thumb ? "file://" + m.thumb : ""; sourceSize.width: 400; fillMode: Image.PreserveAspectCrop; asynchronous: true }

    // --- Bar ---
    Island {
        d: m.d
        anchors { left: parent.left; top: parent.top; margins: 4 }
        // tray: app icons, not palette colours; dots in the islands' text colour
        Repeater { model: 3; Rectangle { width: 6; height: 6; radius: 3; color: m.d.text; opacity: 0.8 } }
    }
    Island {
        d: m.d
        id: media
        anchors { right: clock.left; rightMargin: clock.width * 2 / 3; top: clock.top }
        Rectangle { width: 9; height: 9; radius: 2; color: m.d.wsEmpty; anchors.verticalCenter: parent.verticalCenter }
        BarText { d: m.d; text: "WESOŁE MIASTECZKO \u{f04c}" }
    }
    Island {
        d: m.d
        id: clock
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 4 }
        BarText { d: m.d; text: "\u{f017} 10:34" }
    }
    Island {
        d: m.d
        anchors { left: clock.right; leftMargin: 4; top: clock.top }
        pad: 2
        Repeater {
            model: 5 // fewer than the real 7: the mock-up Bar is about a sixth of the real one
            Item {
                id: ws
                required property int index
                width: 10; height: 10
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: width / 2; visible: ws.index === 0; color: m.d.wsActive }
                Text {
                    anchors.centerIn: parent
                    text: ws.index + 1
                    color: ws.index === 0 ? m.d.wsActiveText : ws.index === 2 || ws.index === 3 ? m.d.wsEmpty : m.d.wsOccupied
                    font { family: Mockups.font; pixelSize: 6; bold: true }
                }
            }
        }
    }
    Row {
        id: rightIslands
        anchors { right: parent.right; top: parent.top; margins: 4 }
        spacing: 4
        Island { d: m.d; BarText { d: m.d; text: "\u{f027} 33%" } }
        // mic and separator only in a wide mock-up: in a narrow one they would run into the workspaces
        Island { d: m.d; visible: m.width >= 520; BarText { d: m.d; text: "\u{f130} 100%" } }
        Text { visible: m.width >= 520; text: "\u{e621}"; color: m.d.separator; font.family: Mockups.font; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
        Island {
        d: m.d
            id: group
            BarText { d: m.d; text: "\u{f00b1}"; color: m.d.connected }
            BarText { d: m.d; text: "\u{f0928}" }
            BarText { d: m.d; text: "\u{f0a2}" }
        }
    }

    // --- control centre, under the bell ---
    Rectangle {
        anchors { right: parent.right; top: rightIslands.bottom; margins: 4 }
        width: Math.min(150, parent.width * 0.42)
        height: popup.implicitHeight + 16
        radius: 10
        color: m.d.popup
        Column {
            id: popup
            anchors { fill: parent; margins: 8 }
            spacing: 5
            Text { text: "Centrum sterowania"; color: m.d.popupText; font { family: Mockups.font; pixelSize: 8; bold: true } }
            Slider { d: m.d; width: popup.width; label: "Głośnik · 33%"; level: 0.33 }
            Slider { d: m.d; width: popup.width; label: "Jasność · 70%"; level: 0.7 }
            Row {
                spacing: 3
                Repeater {
                    model: [["Wi-Fi", true], ["BT", true], ["Cisza", false]]
                    Rectangle {
                        id: pill
                        required property var modelData
                        width: pt.implicitWidth + 10; height: 13; radius: 7
                        color: pill.modelData[1] ? m.d.pillOn : m.d.pillOff
                        Text { id: pt; anchors.centerIn: parent; text: pill.modelData[0]; color: pill.modelData[1] ? m.d.pillOnText : m.d.pillOffText; font { family: Mockups.font; pixelSize: 7; bold: true } }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: m.d.separatorLine }
            Text { text: "Powiadomienie · teraz"; color: m.d.popupText; font { family: Mockups.font; pixelSize: 7 } }
            Text { text: "Bateria: 8%"; color: m.d.critical; font { family: Mockups.font; pixelSize: 7 } }
        }
    }
}
