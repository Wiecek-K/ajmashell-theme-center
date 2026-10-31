// SPDX-License-Identifier: AGPL-3.0-or-later
// Saved settings in a tab's panel (ticket E18): "Save as" with a name for the trial, the list of saved names, a click
// loads one into the trial, "×" deletes. An existing name and a delete ask with a second click on the same button
// ("overwrite?", "delete?"; user, 2026-10-31), no dialog; it forgets the question after 4 s or at any other action.
// No rename: load, save under the new name, delete the old one. The filled chip: the trial still equals the setting
// it was loaded from or saved as. State: SavedStore.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Column {
    id: s
    property var app        // the tab's state (its ui)
    property var store      // SavedStore
    property var trial      // what "Save as" keeps
    property bool active    // the trial equals store.data
    property Item keys      // gets the keys back after a save (the arrows of the Palette strip, the frame's shortcuts)
    property string ask: "" // "overwrite" | "delete:<name>": the button waits for its second click
    spacing: 6

    readonly property string typed: field.text.trim()
    readonly property bool exists: !!s.store.names && s.store.names.includes(s.typed)

    function forget() { ask = ""; }

    // the keys back to the tab: a chip takes no focus, so the name field would keep the arrows of the Palette strip
    function release() {
        if (keys) keys.forceActiveFocus();
    }

    function saveAs() {
        if (!typed || store.busy || !trial) return;
        if (exists && ask !== "overwrite") {
            ask = "overwrite";
            timer.restart();
            return;
        }
        store.saveAs(typed, trial, exists);
        ask = "";
        field.text = "";
        release();
    }

    Timer { id: timer; interval: 4000; onTriggered: s.forget() }

    Text { text: "Saved (click to load into the trial)"; color: s.app.ui.dim; font { family: s.app.ui.font; pixelSize: 11 } }

    Text {
        visible: s.store.names === null
        width: s.width
        wrapMode: Text.Wrap
        text: "Nothing to save: no module of this kind in the Ajmashell directory (see Settings)."
        color: s.app.ui.error
        font { family: s.app.ui.font; pixelSize: 11 }
    }

    Row {
        visible: s.store.names !== null
        spacing: 8
        TextField {
            id: field
            width: s.width - save.width - 8
            height: 24
            padding: 4
            leftPadding: 8
            placeholderText: "name"
            maximumLength: 64
            selectByMouse: true
            font { family: s.app.ui.font; pixelSize: 12 }
            color: s.app.ui.text
            placeholderTextColor: s.app.ui.dim
            background: Rectangle { color: s.app.ui.panel; radius: 12; border.color: s.app.ui.line }
            onTextChanged: s.forget()
            onAccepted: s.saveAs()
            Keys.onEscapePressed: {
                text = "";
                s.release();
            }
        }
        Chip {
            id: save
            app: s.app
            label: s.ask === "overwrite" ? "overwrite?" : "Save as"
            tone: s.ask === "overwrite" ? s.app.ui.warn : s.app.ui.trial
            selected: s.ask === "overwrite"
            enabled: !!s.typed && !s.store.busy && !!s.trial
            onClicked: s.saveAs()
        }
    }

    Flow {
        width: s.width
        spacing: 6
        Repeater {
            model: s.store.names || []
            Row {
                id: item
                required property string modelData
                readonly property bool deleting: s.ask === "delete:" + item.modelData
                spacing: 2
                Chip {
                    app: s.app
                    label: item.modelData
                    selected: s.active && s.store.name === item.modelData
                    enabled: !s.store.busy
                    onClicked: {
                        s.forget();
                        s.release();
                        s.store.load(item.modelData);
                    }
                }
                Chip {
                    app: s.app
                    label: item.deleting ? "delete?" : "×"
                    tone: s.app.ui.error
                    selected: item.deleting
                    enabled: !s.store.busy
                    onClicked: {
                        s.release();
                        if (item.deleting) {
                            s.forget();
                            s.store.remove(item.modelData);
                        } else {
                            s.ask = "delete:" + item.modelData;
                            timer.restart();
                        }
                    }
                }
            }
        }
    }
    Text {
        visible: !!s.store.names && !s.store.names.length
        text: "none yet: type a name and click Save as"
        color: s.app.ui.dim
        font { family: s.app.ui.font; pixelSize: 11 }
    }
    Repeater {
        model: s.store.error ? ["Not done: " + s.store.error] : s.store.warnings
        Text {
            required property string modelData
            width: s.width
            wrapMode: Text.Wrap
            text: modelData
            color: s.store.error ? s.app.ui.error : s.app.ui.warn
            font { family: s.app.ui.font; pixelSize: 11 }
        }
    }
}
