// SPDX-License-Identifier: AGPL-3.0-or-later
// Presets and builder of the Look tab (ticket 13, ADR 0021): a click on a preset fills the builder; any change of a
// field makes it "custom". Builder: effects (motion, lens flare, glass core, soft pills; right under the presets,
// user 2026-10-30), background role, alpha. Lists and the
// alpha range come from Ajmashell's look-options.json through the helper; nothing is saved under a name here (a new
// preset or other defaults are a manual change in Ajmashell, docs/wyglady-ajmashella.md of the project). A blue frame
// marks the current value. A preset has no gradient (one for every look): GradientSection.qml under it in LookTab.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Column {
    id: p
    property var app    // LookState
    spacing: 14

    readonly property var o: app.options
    readonly property var t: app.trial
    readonly property var cur: app.current
    readonly property var flagNames: ({ motion: "motion", flare: "lens flare", glass: "glass core", softPills: "soft pills" })

    Text {
        text: "Presets"
        color: p.app.ui.dim
        font { family: p.app.ui.font; pixelSize: 11 }
    }
    Flow {
        width: parent.width
        spacing: 6
        Repeater {
            model: p.o ? Object.keys(p.o.presets) : []
            Chip {
                id: pc
                required property string modelData
                app: p.app
                label: pc.modelData
                selected: p.app.presetOf(p.t) === pc.modelData
                border.color: pc.selected ? pc.tone : p.app.presetOf(p.cur) === pc.modelData ? p.app.ui.accent : p.app.ui.line
                onClicked: p.app.applyPreset(pc.modelData)
            }
        }
    }
    Text {
        text: "Trial: " + p.app.presetOf(p.t) + "   ·   current: " + p.app.presetOf(p.cur)
        color: p.app.edited ? p.app.ui.trial : p.app.ui.dim
        font { family: p.app.ui.font; pixelSize: 12 }
    }

    Column {
        width: parent.width
        spacing: 6
        Text { text: "Effects (click to switch)"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: p.o ? p.o.flags : []
                Chip {
                    id: fc
                    required property string modelData
                    app: p.app
                    label: (p.flagNames[fc.modelData] || fc.modelData) + (p.t && p.t[fc.modelData] ? " on" : " off")
                    selected: !!p.t && p.t[fc.modelData]
                    border.color: fc.selected ? fc.tone : p.cur && p.cur[fc.modelData] ? p.app.ui.accent : p.app.ui.line
                    onClicked: p.app.set(fc.modelData, !p.t[fc.modelData])
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: p.app.ui.line }

    Column {
        width: parent.width
        spacing: 6
        Text { text: "Background"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: p.o ? p.o.roles : []
                Chip {
                    id: rc
                    required property string modelData
                    readonly property var colours: p.app.palette.trialColors || p.app.palette.currentColors
                    app: p.app
                    label: "     " + rc.modelData
                    selected: !!p.t && p.t.background === rc.modelData
                    border.color: rc.selected ? rc.tone : p.cur && p.cur.background === rc.modelData ? p.app.ui.accent : p.app.ui.line
                    onClicked: p.app.set("background", rc.modelData)
                    Rectangle {
                        // the role's colour in the trial palette
                        anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                        width: 10; height: 10; radius: 5
                        color: rc.colours && rc.colours[rc.modelData] ? rc.colours[rc.modelData] : "transparent"
                        border.color: p.app.ui.line
                    }
                }
            }
        }
    }

    Column {
        id: alpha
        width: parent.width
        spacing: 4
        readonly property real value: p.t ? p.t.alpha : 1
        readonly property real current: p.cur ? p.cur.alpha : 1
        Text {
            text: "Alpha  " + alpha.value.toFixed(2) + (alpha.value !== alpha.current ? "   (current " + alpha.current.toFixed(2) + ")" : "")
                  + (alpha.value >= 1 ? "   opaque, no blur" : "")
            color: alpha.value !== alpha.current ? p.app.ui.trial : p.app.ui.dim
            font { family: p.app.ui.font; pixelSize: 11 }
        }
        Slider {
            id: sl
            width: alpha.width
            height: 24
            from: p.o ? p.o.alpha.min : 0.5
            to: p.o ? p.o.alpha.max : 1
            stepSize: p.o ? p.o.alpha.step : 0.01
            snapMode: Slider.SnapAlways
            focusPolicy: Qt.NoFocus
            value: alpha.value
            // rounded to two places (float noise of the steps), so a preset's 0.8 is matched again
            onMoved: p.app.set("alpha", Math.round(value * 100) / 100)
            background: Rectangle {
                x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: sl.availableWidth; height: 4; radius: 2
                color: p.app.ui.line
                Rectangle {
                    // mark of the current value
                    x: (alpha.current - sl.from) / (sl.to - sl.from) * parent.width - 1
                    y: -4; width: 2; height: 12
                    color: p.app.ui.accent
                }
            }
            handle: Rectangle {
                x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7
                color: sl.pressed ? p.app.ui.text : p.app.ui.trial
            }
        }
    }
}
