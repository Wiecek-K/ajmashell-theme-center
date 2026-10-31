// SPDX-License-Identifier: AGPL-3.0-or-later
// Gradient section of the Look tab's builder (faza E ticket 14, ADR 0021): the gradient of the big popups' background,
// one for every look (a preset keeps it). Style, colours A and B (roles of look-options.json, each a select that opens
// its list), strength, angle and the reaches A and B. A new style sets the reaches to its defaults; a reach the style
// does not use is greyed out, the select of colour B is hidden in a style without B (`uses` in look-options.json), the
// angle is greyed out in a style without a direction (`angle: false`). Styles conic … aurora: ticket E16 (prototype). Styles, ranges and the roles come from Ajmashell's look-options.json through the helper;
// the drawing is Ajmashell's look/GradientFill.qml (LookMock.qml). A blue frame or mark = the current value.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Column {
    id: s
    property var app    // LookState
    spacing: 14

    readonly property var o: app.options ? app.options.gradient : null
    readonly property var t: app.trial ? app.trial.gradient : null
    readonly property var cur: app.current ? app.current.gradient : null
    readonly property bool on: !!t && t.style !== "off"
    readonly property var style: o && t ? o.styles.find(st => st.name === t.style) || null : null // its uses and reaches
    readonly property var reaches: style ? style.reaches : ({})
    readonly property var uses: style ? style.uses : []
    readonly property var colours: app.palette.trialColors || app.palette.currentColors
    readonly property var styleNames: ({
        off: "none", linear: "linear", corner: "corner glow", bands: "bands", duo: "two-colour", conic: "conic",
        mirror: "mirror", glow: "centre glow", spotlight: "spotlight", vignette: "vignette", stripes: "stripes", aurora: "aurora"
    })
    // what the reaches mean in each style
    readonly property var reachHelp: ({
        linear: "Reach A: where colour A fades into the background.",
        corner: "Reach A: the glow of A from the corner, a share of the diagonal. Reach B above 0: a second glow of B from the opposite corner.",
        bands: "Reach A and B: how far each colour goes in from its own end; between them the plain background.",
        duo: "Reach A: where A turns into B half way.",
        conic: "Colours turn around the centre from the angle. Reach A: where along the turn B is at its fullest; then back to A.",
        mirror: "A at both ends, B in the middle. Reach A: how wide the middle of B is.",
        glow: "A glows from the centre. Reach A: how far, a share of the way to a corner. No angle.",
        spotlight: "A shines in from the edge, in the direction of the angle. Reach A: how far, a share of the diagonal.",
        vignette: "A frames the edges, the middle stays plain. Reach A: how thick the frame is. No angle.",
        stripes: "Stripes of A across the angle. Reach A: how wide one stripe and one gap are. Reach B: how soft their edges are.",
        aurora: "Soft blobs of A and B around the centre; the angle turns them. Reach A: how big they are. In a look with motion they drift (the preview stands still)."
    })

    // one role: a select (the chosen role; a click opens the list under it)
    component RoleSelect: Column {
        id: rs
        property string label
        property string part // "a" or "b"
        property bool open: false
        readonly property string value: s.t ? s.t[part] : ""
        readonly property string current: s.cur ? s.cur[part] : ""
        width: parent.width
        spacing: 6
        enabled: s.on

        Row {
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                text: rs.label
                color: rs.value !== rs.current ? s.app.ui.trial : s.app.ui.dim
                font { family: s.app.ui.font; pixelSize: 11 }
            }
            Chip {
                app: s.app
                label: "     " + rs.value + (rs.open ? "  ▴" : "  ▾")
                border.color: rs.value !== rs.current ? s.app.ui.trial : s.app.ui.accent
                onClicked: rs.open = !rs.open
                Dot { role: rs.value }
            }
        }
        Flow {
            visible: rs.open
            width: parent.width
            spacing: 6
            Repeater {
                model: rs.open && s.app.options ? s.app.options.roles : []
                Chip {
                    id: rc
                    required property string modelData
                    app: s.app
                    label: "     " + rc.modelData
                    selected: rs.value === rc.modelData
                    border.color: rc.selected ? rc.tone : rs.current === rc.modelData ? s.app.ui.accent : s.app.ui.line
                    onClicked: {
                        s.app.setGradient(rs.part, rc.modelData);
                        rs.open = false;
                    }
                    Dot { role: rc.modelData }
                }
            }
        }
    }

    // the role's colour in the trial palette, at the left of a chip
    component Dot: Rectangle {
        property string role
        anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
        width: 10; height: 10; radius: 5
        color: s.colours && s.colours[role] ? s.colours[role] : "transparent"
        border.color: s.app.ui.line
    }

    // one number of the gradient: shown as `unit` (percent: value × 100), mark of the current value
    component PartSlider: Column {
        id: ps
        property string label
        property string part
        property var range: null // {min, max, step} of look-options.json
        property bool percent: true
        readonly property real value: s.t ? s.t[part] : 0
        readonly property real current: s.cur ? s.cur[part] : 0
        function shown(v) {
            return percent ? Math.round(v * 100) + "%" : Math.round(v) + "°";
        }
        width: parent.width
        spacing: 4
        opacity: enabled ? 1 : 0.4

        Text {
            text: ps.label + "  " + ps.shown(ps.value) + (ps.value !== ps.current ? "   (current " + ps.shown(ps.current) + ")" : "")
            color: ps.value !== ps.current ? s.app.ui.trial : s.app.ui.dim
            font { family: s.app.ui.font; pixelSize: 11 }
        }
        Slider {
            id: sl
            width: ps.width
            height: 24
            from: ps.range ? ps.range.min : 0
            to: ps.range ? ps.range.max : 1
            stepSize: ps.range ? ps.range.step : 0.01
            snapMode: Slider.SnapAlways
            focusPolicy: Qt.NoFocus
            value: ps.value
            // rounded to the step (float noise), so the file holds 0.35, not 0.35000000000000003
            onMoved: s.app.setGradient(ps.part, ps.percent ? Math.round(value * 100) / 100 : Math.round(value))
            background: Rectangle {
                x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: sl.availableWidth; height: 4; radius: 2
                color: s.app.ui.line
                Rectangle {
                    // mark of the current value
                    x: (ps.current - sl.from) / (sl.to - sl.from) * parent.width - 1
                    y: -4; width: 2; height: 12
                    color: s.app.ui.accent
                }
            }
            handle: Rectangle {
                x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7
                color: sl.pressed ? s.app.ui.text : s.app.ui.trial
            }
        }
    }

    Text {
        text: "Gradient (one for every look; presets keep it)"
        color: s.app.ui.dim
        font { family: s.app.ui.font; pixelSize: 11 }
    }
    Flow {
        width: parent.width
        spacing: 6
        Repeater {
            model: s.o ? s.o.styles.map(st => st.name) : [] // a list: the order of look-options.json
            Chip {
                id: sc
                required property string modelData
                app: s.app
                label: s.styleNames[sc.modelData] || sc.modelData
                selected: !!s.t && s.t.style === sc.modelData
                border.color: sc.selected ? sc.tone : s.cur && s.cur.style === sc.modelData ? s.app.ui.accent : s.app.ui.line
                onClicked: s.app.setGradient("style", sc.modelData)
            }
        }
    }

    RoleSelect { label: "Colour A"; part: "a" }
    RoleSelect { label: "Colour B"; part: "b"; visible: s.uses.includes("b") } // only where the style draws B (user, 2026-10-30)

    PartSlider { label: "Strength"; part: "strength"; range: s.o ? s.o.strength : null; enabled: s.on }
    PartSlider { label: "Angle"; part: "angle"; range: s.o ? s.o.angle : null; percent: false; enabled: s.on && s.style.angle !== false }
    PartSlider { label: "Reach A"; part: "reachA"; range: s.o ? s.o.reach : null; enabled: "reachA" in s.reaches }
    PartSlider { label: "Reach B"; part: "reachB"; range: s.o ? s.o.reach : null; enabled: "reachB" in s.reaches }
    Text {
        visible: text !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: s.on ? s.reachHelp[s.t.style] || "" : "Off: the popups have the plain background."
        color: s.app.ui.dim
        font { family: s.app.ui.font; pixelSize: 11 }
    }
}
