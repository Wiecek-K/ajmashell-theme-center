// Settings panel (ticket 09): every path the helper needs, with its field, its default and "found" / "missing".
// The fields edit app.draft; the helper checks the draft while typing (the markers follow it) and, on "apply",
// saves settings.json and restarts itself, so the new paths work without restarting the window. An empty field
// means the default. Opened from the side panel; it covers the strip and the middle of the window.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: p
    property var app
    color: app.ui.bg

    MouseArea { anchors.fill: parent } // clicks stay in the panel

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

            Text { text: "Settings"; color: p.app.ui.accent; font { family: p.app.ui.font; pixelSize: 18; bold: true } }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Paths the tool reads from Ajmashell and the system. The defaults are those of an Ajmashell "
                      + "install from the dotfiles; change a path only if yours lives elsewhere. An empty field means "
                      + "the default. Saved in " + p.app.settingsFile + "."
                color: p.app.ui.dim
                font { family: p.app.ui.font; pixelSize: 12 }
            }
            Text {
                visible: p.app.settingsWarning !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: p.app.settingsWarning
                color: p.app.ui.error
                font { family: p.app.ui.font; pixelSize: 12 }
            }

            Repeater {
                // the paths in use: the model changes only with a new "ready", so a field keeps its focus while typing
                model: p.app.settings
                Column {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string key: modelData.key
                    // status of the draft once the helper checked it (same order), else of the path in use
                    readonly property var st: p.app.checked ? p.app.checked[index] : modelData
                    readonly property string typed: p.app.draft[row.key] ?? ""
                    width: col.width
                    spacing: 4

                    Row {
                        spacing: 10
                        Text {
                            text: row.modelData.label
                            color: p.app.ui.text
                            font { family: p.app.ui.font; pixelSize: 13; bold: true }
                        }
                        Text {
                            text: row.st.found ? "found" : "missing"
                            color: row.st.found ? p.app.ui.dim : p.app.ui.error
                            font { family: p.app.ui.font; pixelSize: 12; bold: !row.st.found }
                        }
                    }
                    TextField {
                        width: row.width
                        text: row.typed
                        placeholderText: row.modelData.default
                        selectByMouse: true
                        font { family: "monospace"; pixelSize: 13 }
                        color: p.app.ui.text
                        placeholderTextColor: p.app.ui.dim
                        background: Rectangle {
                            color: p.app.ui.panel
                            radius: 4
                            border.color: row.st.found ? p.app.ui.line : p.app.ui.error
                        }
                        onTextEdited: p.app.setDraft(row.key, text)
                    }
                    Row {
                        spacing: 10
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "default: " + row.modelData.default
                            color: p.app.ui.dim
                            font { family: "monospace"; pixelSize: 11 }
                        }
                        Chip {
                            visible: row.typed !== ""
                            app: p.app
                            label: "use default"
                            tone: p.app.ui.accent
                            onClicked: p.app.setDraft(row.key, "")
                        }
                    }
                    Text {
                        visible: !row.st.found
                        width: row.width
                        wrapMode: Text.Wrap
                        text: row.st.problem || ""
                        color: p.app.ui.error
                        font { family: p.app.ui.font; pixelSize: 12 }
                    }
                }
            }

            Row {
                spacing: 8
                Chip {
                    app: p.app
                    label: p.app.restarting ? "applying…" : "apply"
                    tone: p.app.ui.accent
                    selected: p.app.canApply
                    enabled: selected
                    onClicked: p.app.applySettings()
                }
                Chip {
                    app: p.app
                    label: "discard changes"
                    tone: p.app.ui.accent
                    enabled: p.app.draftEdited && !p.app.restarting
                    onClicked: p.app.discardSettings()
                }
                Chip {
                    app: p.app
                    label: "close"
                    tone: p.app.ui.accent
                    onClicked: p.app.toggleSettings()
                }
            }
            Text {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: p.app.settingsError ? "Not saved: " + p.app.settingsError
                      : p.app.saving || p.app.applying ? "A save of the palette recipe is running; apply after it." : ""
                color: p.app.settingsError ? p.app.ui.error : p.app.ui.dim
                font { family: p.app.ui.font; pixelSize: 12 }
            }
        }
    }
}
