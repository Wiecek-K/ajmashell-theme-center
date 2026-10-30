// SPDX-License-Identifier: AGPL-3.0-or-later
// Settings tab (ticket 09, a tab since ticket 12): every path the helper needs, with its field, its default and
// "found" / "missing". The fields edit the draft of PaletteState (the helper's protocol); the helper checks the draft
// while typing (the markers follow it) and, on "apply", saves settings.json and restarts itself, so the new paths work
// without restarting the window. An empty field means the default. Leaving the tab drops the draft (SettingsState).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: p
    property var app    // SettingsState
    property var frame
    readonly property var paletteState: app.palette
    color: paletteState.ui.bg

    Flickable {
        anchors { fill: parent; margins: 24 }
        clip: true
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: col
            width: Math.min(parent.width, 900)
            spacing: 14

            Text { text: "Settings"; color: p.paletteState.ui.accent; font { family: p.paletteState.ui.font; pixelSize: 18; bold: true } }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Paths the tool reads from Ajmashell and the system. The defaults are those of an Ajmashell "
                      + "install from the dotfiles; change a path only if yours lives elsewhere. An empty field means "
                      + "the default. Saved in " + p.paletteState.settingsFile + "."
                color: p.paletteState.ui.dim
                font { family: p.paletteState.ui.font; pixelSize: 12 }
            }
            Text {
                visible: p.paletteState.settingsWarning !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: p.paletteState.settingsWarning
                color: p.paletteState.ui.error
                font { family: p.paletteState.ui.font; pixelSize: 12 }
            }

            Repeater {
                // the paths in use: the model changes only with a new "ready", so a field keeps its focus while typing
                model: p.paletteState.settings
                Column {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string key: modelData.key
                    // status of the draft once the helper checked it (same order), else of the path in use
                    readonly property var st: p.paletteState.checked ? p.paletteState.checked[index] : modelData
                    readonly property string typed: p.paletteState.draft[row.key] ?? ""
                    width: col.width
                    spacing: 4

                    Row {
                        spacing: 10
                        Text {
                            text: row.modelData.label
                            color: p.paletteState.ui.text
                            font { family: p.paletteState.ui.font; pixelSize: 13; bold: true }
                        }
                        Text {
                            text: row.st.found ? "found" : "missing"
                            color: row.st.found ? p.paletteState.ui.dim : p.paletteState.ui.error
                            font { family: p.paletteState.ui.font; pixelSize: 12; bold: !row.st.found }
                        }
                    }
                    TextField {
                        width: row.width
                        text: row.typed
                        placeholderText: row.modelData.default
                        selectByMouse: true
                        font { family: "monospace"; pixelSize: 13 }
                        color: p.paletteState.ui.text
                        placeholderTextColor: p.paletteState.ui.dim
                        background: Rectangle {
                            color: p.paletteState.ui.panel
                            radius: 4
                            border.color: row.st.found ? p.paletteState.ui.line : p.paletteState.ui.error
                        }
                        onTextEdited: p.paletteState.setDraft(row.key, text)
                    }
                    Row {
                        spacing: 10
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "default: " + row.modelData.default
                            color: p.paletteState.ui.dim
                            font { family: "monospace"; pixelSize: 11 }
                        }
                        Chip {
                            visible: row.typed !== ""
                            app: p.paletteState
                            label: "use default"
                            tone: p.paletteState.ui.accent
                            onClicked: p.paletteState.setDraft(row.key, "")
                        }
                    }
                    Text {
                        visible: !row.st.found
                        width: row.width
                        wrapMode: Text.Wrap
                        text: row.st.problem || ""
                        color: p.paletteState.ui.error
                        font { family: p.paletteState.ui.font; pixelSize: 12 }
                    }
                }
            }

            Column {
                // not a setting: the file the recipe module of the Ajmashell directory names, the same file
                // indexer.py and wpapply.sh read (user, 2026-10-21)
                width: col.width
                spacing: 4
                Text {
                    text: "Palette recipe file"
                    color: p.paletteState.ui.text
                    font { family: p.paletteState.ui.font; pixelSize: 13; bold: true }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: p.paletteState.recipeFile ? p.paletteState.recipeFile + "   (named by palette_recipe.py of the Ajmashell directory)"
                          : "unknown: no palette recipe module in the Ajmashell directory"
                    color: p.paletteState.recipeFile ? p.paletteState.ui.dim : p.paletteState.ui.error
                    font { family: "monospace"; pixelSize: 12 }
                }
            }

            Row {
                spacing: 8
                Chip {
                    app: p.paletteState
                    label: p.paletteState.restarting ? "applying…" : "apply"
                    tone: p.paletteState.ui.accent
                    selected: p.paletteState.canApply
                    enabled: selected
                    onClicked: p.paletteState.applySettings()
                }
                Chip {
                    app: p.paletteState
                    label: "discard changes"
                    tone: p.paletteState.ui.accent
                    enabled: p.paletteState.draftEdited && !p.paletteState.restarting
                    onClicked: p.paletteState.discardSettings()
                }
            }
            Text {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: p.paletteState.settingsError ? "Not saved: " + p.paletteState.settingsError
                      : p.paletteState.saving || p.paletteState.applying ? "A save of the palette recipe is running; apply after it." : ""
                color: p.paletteState.settingsError ? p.paletteState.ui.error : p.paletteState.ui.dim
                font { family: p.paletteState.ui.font; pixelSize: 12 }
            }
        }
    }
}
