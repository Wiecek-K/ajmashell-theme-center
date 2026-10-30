// SPDX-License-Identifier: AGPL-3.0-or-later
// Mock-up of one look for one palette (Look tab, ticket 13): on a blurred piece of the wallpaper (so the look's alpha
// shows), the two shapes Ajmashell's big popups take: the Orbita (almost square, wider than high: core, nodes on the
// orbit, lens flare at a fixed angle, no lightning; BT nodes in every state: connected, known, unknown, chosen;
// Wi-Fi / BT tabs as pills) and the Centrum sterowania (upright: sliders, module switches, pills). A still frame: no
// motion is drawn (CPU), the caption says "motion". Colours: Mockups.look(); sizes scaled from Theme.orbit (900×660,
// core 260, nodes 220×48). Own drawing after Ajmashell's orbit/Orbit.qml, orbit/OrbitBackdrop.qml and
// control/ControlCenter.qml, copied here like the roles in Mockups.js. The texts copy the real (Polish) shell.
// The gradient of the background (ticket 14) is not copied: Ajmashell's own look/GradientFill.qml, loaded from its
// directory (`fill`), draws it in both boxes; without that file the boxes keep the plain background.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "Mockups.js" as Mockups

Item {
    id: m
    property var c: ({})         // palette {token: hex}
    property var look: null      // {background, alpha, motion, flare, glass, softPills, gradient}
    property string thumb
    property string fill         // Ajmashell's look/GradientFill.qml, "" without it
    readonly property bool gradientOn: m.fill !== "" && !!m.look && !!m.look.gradient && m.look.gradient.style !== "off"
    readonly property var d: Mockups.look(m.c, m.look)
    readonly property bool soft: !!m.look && m.look.softPills
    clip: true

    // a piece of the wallpaper (the middle, twice as large), blurred like Hyprland's blur under a popup
    Image {
        id: wall
        anchors.centerIn: parent
        width: parent.width * 2; height: parent.height * 2
        source: m.thumb ? "file://" + m.thumb : ""
        sourceSize.width: 400 // as the strip: already in Qt's image cache
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: wall
        source: wall
        blurEnabled: true
        blur: 1
        blurMax: 32
    }

    readonly property real pad: 12
    readonly property real h: height - 2 * pad
    // the Orbita 900×660, the Centrum about 2:5 beside it
    readonly property real k: Math.min(h / 660, (width - 3 * pad) / (900 + 0.5 * 660))

    // the look's gradient over the box's background (Ajmashell's GradientFill.qml); the box itself is then transparent
    component GradientLayer: Loader {
        id: gl
        property real radius
        anchors.fill: parent
        active: m.gradientOn
        source: active ? "file://" + m.fill : ""
        // GradientFill's properties (a file loaded at run time: no type for qmllint, so by name)
        Binding { target: gl.item; property: "settings"; value: m.look ? m.look.gradient : null; when: gl.item !== null }
        Binding { target: gl.item; property: "colorA"; value: m.look ? m.c[m.look.gradient.a] || "transparent" : "transparent"; when: gl.item !== null }
        Binding { target: gl.item; property: "colorB"; value: m.look ? m.c[m.look.gradient.b] || "transparent" : "transparent"; when: gl.item !== null }
        Binding { target: gl.item; property: "base"; value: m.d.background; when: gl.item !== null }
        Binding { target: gl.item; property: "radius"; value: gl.radius; when: gl.item !== null }
    }

    // pill of a look with or without softPills (Pill.qml)
    component MockPill: Rectangle {
        id: pill
        property var d
        property bool soft
        property bool active
        property string label
        property real k
        width: pl.implicitWidth + 24 * k; height: 34 * k; radius: height / 2
        color: soft ? (active ? d.softActive : d.softIdle) : active ? d.tab : d.button
        Text {
            id: pl
            anchors.centerIn: parent
            text: pill.label
            color: pill.soft ? (pill.active ? pill.d.selected : pill.d.text) : pill.active ? pill.d.tabText : pill.d.buttonText
            font { family: Mockups.font; pixelSize: Math.max(7, 16 * pill.k); bold: true }
        }
    }

    // radial wash (OrbitBackdrop.qml Wash): stops [[position, colour, alpha]] out to reach, inside a rounded box
    component Wash: Shape {
        id: wash
        property real cx
        property real cy
        property real reach
        property real radius
        property var stops: []
        function stop(i: int): var {
            const s = stops[Math.min(i, stops.length - 1)] ?? [1, "transparent", 0];
            return { position: s[0], color: Mockups.alpha(s[1], s[2]) };
        }
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: wash.cx; centerY: wash.cy; centerRadius: wash.reach
                focalX: wash.cx; focalY: wash.cy
                GradientStop { position: wash.stop(0).position; color: wash.stop(0).color }
                GradientStop { position: wash.stop(1).position; color: wash.stop(1).color }
                GradientStop { position: wash.stop(2).position; color: wash.stop(2).color }
                GradientStop { position: wash.stop(3).position; color: wash.stop(3).color }
            }
            PathRectangle { width: wash.width; height: wash.height; radius: wash.radius }
        }
    }

    // lens flare at the still angle (Theme.orbit.flare: orbit 0.42, phase −2.3 rad, reach 140), source glow and two ghosts
    component Flare: Item {
        id: fl
        property var d
        property real k
        property real radius
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real sx: cx + Math.cos(-2.3) * width * 0.42
        readonly property real sy: cy + Math.sin(-2.3) * height * 0.42
        Wash {
            cx: fl.sx; cy: fl.sy; reach: 140 * fl.k; radius: fl.radius
            stops: [[0, fl.d.flareSource, 0.7], [0.12, fl.d.flareSource, 0.35], [0.4, fl.d.flareGlow, 0.15], [1, fl.d.flareGlow, 0]]
        }
        Repeater {
            model: [{ t: 0.55, size: 26, color: fl.d.flareGhost, alpha: 0.22 }, { t: 1.35, size: 70, color: fl.d.flareGlow, alpha: 0.12 },
                    { t: 1.85, size: 110, color: fl.d.flareAccent, alpha: 0.1 }]
            Wash {
                required property var modelData
                cx: fl.sx + (fl.cx - fl.sx) * modelData.t; cy: fl.sy + (fl.cy - fl.sy) * modelData.t
                reach: modelData.size * fl.k; radius: fl.radius
                stops: [[0, modelData.color, modelData.alpha * 0.5], [0.8, modelData.color, modelData.alpha], [1, modelData.color, 0]]
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: m.pad

        // --- Orbita ---
        Rectangle {
            id: orbit
            width: Math.round(900 * m.k); height: Math.round(660 * m.k)
            radius: 16 * m.k
            color: m.gradientOn ? "transparent" : m.d.background
            readonly property real cx: width / 2
            readonly property real cy: (height - 34 * m.k) / 2 // the field above the tab row

            GradientLayer { radius: orbit.radius }
            Flare { anchors.fill: parent; visible: !!m.look && m.look.flare; d: m.d; k: m.k; radius: orbit.radius }

            // glass: a fade under the core (orbit.fadeStops over 1.7 × core)
            Wash {
                visible: !!m.look && m.look.glass
                cx: orbit.cx; cy: orbit.cy; reach: 1.7 * 260 * m.k / 2; radius: orbit.radius
                stops: [[0, m.d.fade, 0.75], [0.45, m.d.fade, 0.6], [1, m.d.fade, 0]]
            }
            Rectangle {
                id: core
                width: 260 * m.k; height: width; radius: width / 2
                x: orbit.cx - width / 2; y: orbit.cy - height / 2
                color: !!m.look && m.look.glass ? m.d.glassCore : m.d.core
                Column {
                    anchors.centerIn: parent
                    spacing: 4 * m.k
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\u{f00af}"; color: m.d.text; font { family: Mockups.font; pixelSize: 34 * m.k } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Bluetooth"; color: m.d.text; font { family: Mockups.font; pixelSize: Math.max(7, 16 * m.k); bold: true } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "2 połączone"; color: m.d.subtext; font { family: Mockups.font; pixelSize: Math.max(6, 13 * m.k) } }
                }
            }

            // nodes on the ellipse (radii 270 × 215, unknown ones 50 px further out): every state once
            Repeater {
                model: [
                    { name: "Słuchawki", state: "connected", a: -1.9 },
                    { name: "Klawiatura", state: "connected", a: -0.35 },
                    { name: "Głośnik", state: "known", a: 0.75 },
                    { name: "Telefon", state: "chosen", a: 2.2 },
                    { name: "Nieznane", state: "unknown", a: 3.3 }
                ]
                Rectangle {
                    id: node
                    required property var modelData
                    readonly property bool unknown: modelData.state === "unknown"
                    readonly property bool connected: modelData.state === "connected"
                    readonly property real rx: (270 + (unknown ? 50 : 0)) * m.k
                    readonly property real ry: (215 + (unknown ? 50 : 0)) * m.k
                    width: 220 * m.k; height: 48 * m.k; radius: height / 2
                    x: orbit.cx + Math.cos(modelData.a) * rx - width / 2
                    y: orbit.cy + Math.sin(modelData.a) * ry - height / 2
                    color: connected ? m.d.connected : unknown ? "transparent" : m.d.node
                    border.width: modelData.state === "chosen" ? 2 : unknown ? 1 : 0
                    border.color: modelData.state === "chosen" ? m.d.selected : m.d.unknownBorder
                    Text {
                        anchors.centerIn: parent
                        text: node.modelData.name
                        color: node.connected ? m.d.connectedText : node.unknown ? m.d.unknownText : m.d.text
                        font { family: Mockups.font; pixelSize: Math.max(6, 15 * m.k); bold: node.connected }
                    }
                }
            }

            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 * m.k }
                spacing: 8 * m.k
                MockPill { d: m.d; soft: m.soft; k: m.k; label: "Wi-Fi" }
                MockPill { d: m.d; soft: m.soft; k: m.k; label: "Bluetooth"; active: true }
            }
        }

        // --- Centrum sterowania ---
        Rectangle {
            id: control
            width: Math.round(0.5 * 660 * m.k); height: orbit.height
            radius: 16 * m.k
            color: m.gradientOn ? "transparent" : m.d.background

            GradientLayer { radius: control.radius }
            Flare { anchors.fill: parent; visible: !!m.look && m.look.flare; d: m.d; k: m.k; radius: control.radius }

            Column {
                anchors { fill: parent; margins: 16 * m.k }
                spacing: 12 * m.k
                Item {
                    width: parent.width; height: 34 * m.k
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "czwartek, 30 października"; color: m.d.text; font { family: Mockups.font; pixelSize: Math.max(6, 14 * m.k) } }
                    MockPill { anchors.right: parent.right; d: m.d; soft: m.soft; k: m.k; label: "\u{f0425}" }
                }
                Flow {
                    width: parent.width
                    spacing: 8 * m.k
                    Repeater {
                        model: [["Wi-Fi", true], ["Bluetooth", true], ["Cisza", false]]
                        MockPill { required property var modelData; d: m.d; soft: m.soft; k: m.k; label: modelData[0]; active: modelData[1] }
                    }
                }
                Repeater {
                    model: [["Głośnik", 0.6], ["Mikrofon", 0.8], ["Jasność", 0.45]]
                    Rectangle {
                        id: slider
                        required property var modelData
                        width: parent.width; height: 36 * m.k; radius: height / 2
                        color: m.d.track
                        Rectangle { width: parent.width * slider.modelData[1]; height: parent.height; radius: parent.radius; color: m.d.tab }
                        Text { anchors { left: parent.left; leftMargin: 14 * m.k; verticalCenter: parent.verticalCenter } text: slider.modelData[0]; color: m.d.tabText; font { family: Mockups.font; pixelSize: Math.max(6, 13 * m.k); bold: true } }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: m.d.separator }
                Text { text: "Powiadomienia"; color: m.d.subtext; font { family: Mockups.font; pixelSize: Math.max(6, 13 * m.k) } }
                Rectangle {
                    width: parent.width; height: 60 * m.k; radius: 12 * m.k
                    color: m.d.softIdle
                    Text { anchors { fill: parent; margins: 10 * m.k } text: "Karuzela tapet · teraz\nNowa paleta"; color: m.d.text; font { family: Mockups.font; pixelSize: Math.max(6, 12 * m.k) } }
                }
            }
        }
    }
}
