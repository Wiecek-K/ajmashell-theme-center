// Full token table of the dark palette (all tokens matugen gives, as in ~/.local/state/ajmashell/colors.json),
// as in variant D of the prototype: groups in two columns when there is room, row = token name + swatch with hex.
// A click on a swatch copies the hex.
import QtQuick

Grid {
    id: t
    property var app
    property var res
    readonly property var colors: res && res.colors ? res.colors : null

    columns: width > 980 ? 2 : 1
    columnSpacing: 28
    rowSpacing: 14

    // Groups by role; a token matugen adds later lands in "Inne".
    readonly property var groups: {
        const g = [
            { name: "Akcent", tokens: ["primary", "on_primary", "primary_container", "on_primary_container", "primary_fixed",
                                        "primary_fixed_dim", "on_primary_fixed", "on_primary_fixed_variant", "inverse_primary", "surface_tint"] },
            { name: "Drugi", tokens: ["secondary", "on_secondary", "secondary_container", "on_secondary_container", "secondary_fixed",
                                       "secondary_fixed_dim", "on_secondary_fixed", "on_secondary_fixed_variant"] },
            { name: "Trzeci", tokens: ["tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container", "tertiary_fixed",
                                        "tertiary_fixed_dim", "on_tertiary_fixed", "on_tertiary_fixed_variant"] },
            { name: "Powierzchnie", tokens: ["background", "on_background", "surface", "surface_dim", "surface_bright",
                                              "surface_container_lowest", "surface_container_low", "surface_container",
                                              "surface_container_high", "surface_container_highest", "surface_variant",
                                              "inverse_surface", "inverse_on_surface"] },
            { name: "Tekst i linie", tokens: ["on_surface", "on_surface_variant", "outline", "outline_variant"] },
            { name: "Błąd", tokens: ["error", "on_error", "error_container", "on_error_container"] },
            { name: "Inne", tokens: ["source_color", "shadow", "scrim"] }
        ];
        if (colors) {
            const known = new Set(g.reduce((all, x) => all.concat(x.tokens), []));
            g[g.length - 1].tokens = g[g.length - 1].tokens.concat(Object.keys(colors).filter(k => !known.has(k)));
        }
        return g;
    }

    Repeater {
        model: t.colors ? t.groups : []
        Column {
            id: grp
            required property var modelData
            spacing: 3
            Text { text: grp.modelData.name; color: t.app.ui.accent; font { family: t.app.ui.font; pixelSize: 12; bold: true } }
            Row {
                spacing: 8
                Text { width: 230; text: "token"; color: t.app.ui.dim; font { family: t.app.ui.font; pixelSize: 10 } }
                Text { width: 110; text: "obecny"; color: t.app.ui.dim; font { family: t.app.ui.font; pixelSize: 10; bold: true } }
            }
            Repeater {
                model: grp.modelData.tokens
                Row {
                    id: row
                    required property string modelData
                    readonly property string hex: t.colors[modelData] || ""
                    spacing: 8
                    Text { width: 230; text: row.modelData; color: t.app.ui.text; font { family: "monospace"; pixelSize: 12 } }
                    Rectangle {
                        width: 110; height: 20; radius: 4
                        color: row.hex || "transparent"
                        border.color: t.app.ui.line
                        Text { anchors.centerIn: parent; text: row.hex || "—"; color: t.app.contrastText(row.hex); font { family: "monospace"; pixelSize: 11 } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: row.hex !== ""; onClicked: t.app.copy(row.hex) }
                    }
                }
            }
        }
    }
}
