// SPDX-License-Identifier: AGPL-3.0-or-later
// The Look tab (ticket 13, ADR 0021): the look of Ajmashell's big popups. Previews "current" above "trial" (a column:
// every control is in the panel on the right, so the previews take the rest; user, 2026-10-30)
// for the wallpaper selected in the Palette tab: current = the live look on the current palette recipe, trial = the
// builder's look on the trial palette recipe (colours from PaletteState), each in LookMock.qml. Panel on the right:
// presets and builder (LookPresets.qml), the gradient of the background under it (GradientSection.qml, ticket 14),
// "Save look", "Save all", and at the bottom the snapshots (SavedSection.qml, ticket E18).
// Only the view: the state is LookState.qml in the frame.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Item {
    id: tab
    property var app    // LookState
    property var frame
    readonly property var pal: app.palette // PaletteState

    Rectangle {
        id: side
        width: 320
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        color: tab.app.ui.panel

        Flickable {
            anchors { fill: parent; margins: 16 }
            clip: true
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: col
                width: parent.width
                spacing: 14

                Text {
                    visible: !tab.app.options
                    width: col.width
                    wrapMode: Text.Wrap
                    text: "No look to set: the Ajmashell directory has no singletons/look/look_settings.py (see Settings)."
                    color: tab.app.ui.error
                    font { family: tab.app.ui.font; pixelSize: 13 }
                }

                Item {
                    visible: !!tab.app.options
                    width: parent.width
                    height: 24
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Look of the big popups"
                        color: tab.app.ui.trial
                        font { family: tab.app.ui.font; pixelSize: 14; bold: true }
                    }
                    Chip {
                        anchors.right: parent.right
                        app: tab.app
                        label: "restore current"
                        tone: tab.app.ui.accent
                        enabled: tab.app.edited
                        onClicked: tab.app.restore()
                    }
                }
                Text {
                    visible: !!tab.app.options
                    width: col.width
                    wrapMode: Text.Wrap
                    text: "Orbita, launcher, Centrum sterowania, audio, calendar, media and Keybinds: one background. Current = " + tab.app.file
                    color: tab.app.ui.dim
                    font { family: tab.app.ui.font; pixelSize: 11 }
                }

                LookPresets {
                    visible: !!tab.app.options
                    width: col.width
                    app: tab.app
                }

                Rectangle { visible: !!tab.app.options; width: parent.width; height: 1; color: tab.app.ui.line }

                GradientSection {
                    visible: !!tab.app.options
                    width: col.width
                    app: tab.app
                }
                Text {
                    visible: !!tab.app.options && !tab.app.gradientFill
                    width: col.width
                    wrapMode: Text.Wrap
                    text: "The previews draw no gradient: the Ajmashell directory has no look/GradientFill.qml (see Settings)."
                    color: tab.app.ui.error
                    font { family: tab.app.ui.font; pixelSize: 11 }
                }

                Rectangle { width: parent.width; height: 1; color: tab.app.ui.line }

                Row {
                    spacing: 8
                    Chip {
                        app: tab.app
                        label: tab.app.saving ? "saving…" : "Save look"
                        tone: tab.app.ui.trial
                        selected: tab.app.edited && !tab.app.busy
                        enabled: selected
                        onClicked: tab.app.save()
                    }
                    SaveAllButton { frame: tab.frame; width: col.width - x }
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: tab.app.saveError ? "Not saved: " + tab.app.saveError
                          : tab.app.saved ? "Saved. Ajmashell shows the new look now. No commit in the dotfiles." : ""
                    color: tab.app.saveError ? tab.app.ui.error : tab.app.ui.dim
                    font { family: tab.app.ui.font; pixelSize: 12 }
                }

                Rectangle { visible: !!tab.app.options; width: parent.width; height: 1; color: tab.app.ui.line }

                SavedSection {
                    visible: !!tab.app.options
                    width: col.width
                    app: tab.app
                    store: tab.app.savedStore
                    trial: tab.app.trial
                    active: tab.app.same(tab.app.trial, tab.app.savedStore.data)
                    keys: tab
                    mainSave: "Save look"
                }
            }
        }
    }

    Flickable {
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: side.left; margins: 16 }
        clip: true
        contentHeight: previews.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: previews
            width: parent.width
            spacing: 16

            Repeater {
                model: [false, true] // trial?
                Column {
                    id: pv
                    required property bool modelData
                    readonly property bool trial: modelData
                    readonly property var look: trial ? tab.app.trial : tab.app.current
                    readonly property var colours: trial ? tab.pal.trialColors : tab.pal.currentColors
                    // last palette with colours: a computing palette keeps the frame instead of going blank
                    property var shown: ({})
                    onColoursChanged: if (colours) shown = colours
                    Component.onCompleted: if (colours) shown = colours
                    width: previews.width
                    spacing: 6

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (pv.trial ? "Trial" : "Current") + " · " + tab.app.nameOf(pv.look)
                              + (tab.pal.wallpaperName ? " · " + tab.pal.wallpaperName : "")
                              + (pv.trial && tab.pal.trialDiffers ? " · palette: " + (tab.pal.trialName || "trial") : "")
                              + (pv.look && pv.look.motion ? " · motion (still frame)" : "")
                              + (pv.colours ? "" : " · computing…")
                        color: pv.trial ? tab.app.ui.trial : tab.app.ui.accent
                        font { family: tab.app.ui.font; pixelSize: 12; bold: true }
                    }
                    LookMock {
                        width: pv.width
                        // two previews and their captions fill the height; never wider than 16:9
                        height: Math.min(Math.round(width * 9 / 16), Math.round((tab.height - 2 * 16 - previews.spacing) / 2 - 24))
                        c: pv.shown
                        look: pv.look
                        thumb: tab.pal.it ? tab.pal.it.thumb : ""
                        fill: tab.app.gradientFill
                    }
                }
            }
        }
    }
}
