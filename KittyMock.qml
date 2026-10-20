// kitty mock-up for one palette: a focused kitty window on the wallpaper. Colours by kitty key from the matugen
// template kitty-colors.conf (map from the helper, Mockups.kitty()), the border as Hyprland's active_border
// (tokens and angle from looknfeel.lua), the whole window at the opacity of the kitty window rule (rules.lua),
// border included, as Hyprland draws a window with its opacity.
// Built on MockKitty.qml of the prototype (branch prototype/faza-e-karta-ui); the prototype's hard-coded tokens
// became the template's keys.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "Mockups.js" as Mockups

Item {
    id: m
    property var c: ({})        // palette {token: hex}
    property var look: null     // helper's system_look(): kitty map, border, borderAngle, kittyOpacity
    property string thumb
    clip: true

    function k(key) { return Mockups.kitty(m.c, m.look ? m.look.kitty : null, key); }
    // ANSI names of the sample lines -> kitty keys (color0..15)
    readonly property var ansi: ({ black: "color0", red: "color1", green: "color2", yellow: "color3", blue: "color4",
                                   magenta: "color5", cyan: "color6", white: "color7", brblack: "color8" })

    Image { anchors.fill: parent; source: m.thumb ? "file://" + m.thumb : ""; sourceSize.width: 400; fillMode: Image.PreserveAspectCrop; asynchronous: true }

    Item {
        id: win
        anchors { fill: parent; margins: 10 }
        opacity: m.look && m.look.kittyOpacity !== null ? m.look.kittyOpacity : 1
        layer.enabled: opacity < 1 // one opacity for the window, not per element

        readonly property int b: Mockups.borderSize
        readonly property var stops: m.look ? m.look.border.map(t => m.c[t] || "#808080") : []
        readonly property var line: Mockups.borderLine(m.look ? m.look.borderAngle : 0, width, height)

        // terminal: kitty's background under its text, inside the border
        Rectangle {
            id: term
            anchors { fill: parent; margins: win.b }
            radius: Mockups.rounding - win.b
            color: m.k("background")
            clip: true

            // tab bar (tab_bar_edge top)
            Rectangle {
                id: tabs
                width: parent.width; height: 15
                color: m.k("tab_bar_background")
                Row {
                    Rectangle { width: 80; height: 15; color: m.k("active_tab_background")
                        Text { anchors.centerIn: parent; text: "1 nvim"; color: m.k("active_tab_foreground"); font { family: Mockups.font; pixelSize: 9 } } }
                    Rectangle { width: 80; height: 15; color: m.k("inactive_tab_background")
                        Text { anchors.centerIn: parent; text: "2 zsh"; color: m.k("inactive_tab_foreground"); font { family: Mockups.font; pixelSize: 9 } } }
                }
            }

            Column {
                anchors { top: tabs.bottom; left: parent.left; right: parent.right; margins: 5 }
                spacing: 1
                // one line = [text, ANSI name | "fg" | "sel" | "cursor"]
                Repeater {
                    model: [
                        [["ajmag@arch ", "green"], ["~/Projects ", "blue"], ["❯ ", "magenta"], ["git status", "fg"]],
                        [["On branch ", "fg"], ["ajmashell-wip", "cyan"]],
                        [["  modified:   ", "red"], ["wpapply.sh", "red"]],
                        [["  new file:   ", "green"], ["przepis-palety.json", "green"]],
                        [["ajmag@arch ", "green"], ["~/Projects ", "blue"], ["❯ ", "magenta"], ["ls", "fg"]],
                        [["hyprland/  ", "blue"], ["tools/  ", "blue"], ["check.sh  ", "green"], ["README.md", "fg"]],
                        [["# komentarz, ", "brblack"], ["ostrzeżenie ", "yellow"], ["zaznaczony tekst", "sel"]],
                        [["ajmag@arch ", "green"], ["~/Projects ", "blue"], ["❯ ", "magenta"], [" ", "cursor"]]
                    ]
                    Row {
                        id: ln
                        required property var modelData
                        Repeater {
                            model: ln.modelData
                            Rectangle {
                                id: span
                                required property var modelData
                                readonly property string kind: modelData[1]
                                width: t.implicitWidth; height: t.implicitHeight
                                color: kind === "sel" ? m.k("selection_background") : kind === "cursor" ? m.k("cursor") : "transparent"
                                Text {
                                    id: t
                                    text: span.modelData[0]
                                    font { family: Mockups.font; pixelSize: 10 }
                                    color: span.kind === "fg" ? m.k("foreground") : span.kind === "sel" ? m.k("selection_foreground")
                                         : span.kind === "cursor" ? m.k("cursor_text_color") : m.k(m.ansi[span.kind])
                                }
                            }
                        }
                    }
                }
            }
        }

        // active_border: a ring between the window edge and the terminal, filled with the gradient
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                fillGradient: LinearGradient {
                    x1: win.line.x1; y1: win.line.y1; x2: win.line.x2; y2: win.line.y2
                    // the n colours of active_border, spread evenly over 0..1 as in Hyprland, sampled at 9 fixed
                    // stops (exact for 2, 3, 5 and 9 colours)
                    GradientStop { position: 0; color: Mockups.sample(win.stops, 0) }
                    GradientStop { position: 0.125; color: Mockups.sample(win.stops, 0.125) }
                    GradientStop { position: 0.25; color: Mockups.sample(win.stops, 0.25) }
                    GradientStop { position: 0.375; color: Mockups.sample(win.stops, 0.375) }
                    GradientStop { position: 0.5; color: Mockups.sample(win.stops, 0.5) }
                    GradientStop { position: 0.625; color: Mockups.sample(win.stops, 0.625) }
                    GradientStop { position: 0.75; color: Mockups.sample(win.stops, 0.75) }
                    GradientStop { position: 0.875; color: Mockups.sample(win.stops, 0.875) }
                    GradientStop { position: 1; color: Mockups.sample(win.stops, 1) }
                }
                PathRectangle { width: win.width; height: win.height; radius: Mockups.rounding }
                PathRectangle { x: win.b; y: win.b; width: win.width - 2 * win.b; height: win.height - 2 * win.b; radius: Mockups.rounding - win.b }
            }
        }
    }
}
