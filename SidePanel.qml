// Right panel (variant D of the prototype): controls of the trial recipe next to the current recipe (the system
// file), "restore current", "save as system recipe" with the steps after it, folder progress for both recipes,
// the summary of what the trial changes, the last copied hex. Lists and ranges of the controls come from the helper
// (palette_recipe.options()), never copied here.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: p
    property var app
    color: app.ui.panel

    readonly property var r: app.recipe
    readonly property var t: app.trial
    readonly property var o: app.options
    // story 4 of the spec; a rule the module adds later shows its own name
    readonly property var ruleNames: ({ dominant: "most dominant", darkness: "darkest",
                                        lightness: "lightest", saturation: "most saturated",
                                        "less-saturation": "least saturated", value: "highest value" })
    function ruleName(rule) { return ruleNames[rule] || rule; }

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

            Text { text: "Current recipe"; color: p.app.ui.accent; font { family: p.app.ui.font; pixelSize: 14; bold: true } }
            Text { text: "the system palette recipe file"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
            Grid {
                columns: 2
                columnSpacing: 12
                rowSpacing: 6
                Repeater {
                    // label, value, label, value, …
                    model: p.r ? [
                        "Seed choice", p.ruleName(p.r.seed.rule),
                        "Scheme", p.r.palette.scheme.replace("scheme-", ""),
                        "Contrast", p.r.palette.contrast.toFixed(2),
                        "Dark lightness", p.r.palette.lightnessDark.toFixed(2)
                    ] : []
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData
                        color: index % 2 ? p.app.ui.text : p.app.ui.dim
                        font { family: p.app.ui.font; pixelSize: 12 }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: p.app.ui.line }

            Item {
                width: parent.width
                height: 24
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Trial recipe"
                    color: p.app.ui.trial
                    font { family: p.app.ui.font; pixelSize: 14; bold: true }
                }
                Chip {
                    anchors.right: parent.right
                    app: p.app
                    label: "restore current"
                    tone: p.app.ui.accent
                    enabled: p.app.trialDiffers || p.app.trialEdited
                    onClicked: p.app.restore()
                }
            }

            Column {
                width: parent.width
                spacing: 6
                Text { text: "Seed choice"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: p.o ? p.o.rules : []
                        Chip {
                            id: rc
                            required property string modelData
                            app: p.app
                            label: p.ruleName(rc.modelData)
                            selected: !!p.t && p.t.seed.rule === rc.modelData
                            border.color: rc.selected ? rc.tone : p.r && p.r.seed.rule === rc.modelData ? p.app.ui.accent : p.app.ui.line
                            onClicked: p.app.setTrial("seed", "rule", rc.modelData)
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6
                Text { text: "Palette scheme"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: p.o ? p.o.schemes : []
                        Chip {
                            id: sc
                            required property string modelData
                            app: p.app
                            label: sc.modelData.replace("scheme-", "")
                            selected: !!p.t && p.t.palette.scheme === sc.modelData
                            border.color: sc.selected ? sc.tone : p.r && p.r.palette.scheme === sc.modelData ? p.app.ui.accent : p.app.ui.line
                            onClicked: p.app.setTrial("palette", "scheme", sc.modelData)
                        }
                    }
                }
            }

            TrialSlider {
                width: parent.width
                app: p.app
                label: "Contrast"
                key: "contrast"
                range: p.o ? p.o.contrast : [-1, 1]
            }
            TrialSlider {
                width: parent.width
                app: p.app
                label: "Dark palette lightness"
                key: "lightnessDark"
                range: p.o ? p.o.lightnessDark : [null, 1]
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Blue frame and tick: value of the current recipe."
                color: p.app.ui.dim
                font { family: p.app.ui.font; pixelSize: 11 }
            }

            // story 51-55: one button, no commit; the steps after the file run in the helper's background
            Chip {
                app: p.app
                label: p.app.saving ? "saving…" : "save as system recipe"
                tone: p.app.ui.trial
                selected: p.app.trialEdited && !p.app.saving && !p.app.applying
                enabled: selected
                onClicked: p.app.saveTrial()
            }
            Text {
                readonly property var stages: ({ indexer: "Palette recipe file saved. Rebuilding the carousel index…",
                                                 wallpaper: "Applying the new recipe to the current wallpaper…",
                                                 done: "Saved and applied to the desktop. No commit in the dotfiles.",
                                                 error: "File saved, but applying it failed: " })
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: p.app.saveError ? "Not saved: " + p.app.saveError
                      : p.app.applyStage ? stages[p.app.applyStage] + (p.app.applyStage === "error" ? p.app.applyError : "") : ""
                color: p.app.saveError || p.app.applyStage === "error" ? p.app.ui.error
                       : p.app.applying ? p.app.ui.text : p.app.ui.dim
                font { family: p.app.ui.font; pixelSize: 12 }
            }

            Rectangle { width: parent.width; height: 1; color: p.app.ui.line }

            Repeater {
                model: [["current", p.app.fingerprint], ["trial", p.app.trialFingerprint]]
                Text {
                    id: pr
                    required property var modelData
                    readonly property int n: p.app.doneOf(pr.modelData[1])
                    text: (pr.n < p.app.total ? "Computing " : "Computed ") + pr.modelData[0] + " " + pr.n + "/" + p.app.total
                    color: pr.n < p.app.total ? p.app.ui.text : p.app.ui.dim
                    font { family: "monospace"; pixelSize: 13 }
                }
            }
            Chip {
                // the rest of the folder for the trial, on demand (user, 2026-10-20): moving a control computes
                // only the selected wallpaper
                visible: p.app.trialDiffers && p.app.doneOf(p.app.trialFingerprint) < p.app.total
                app: p.app
                label: p.app.trialAll ? "computing the other wallpapers…" : "compute all wallpapers ("
                       + (p.app.total - p.app.doneOf(p.app.trialFingerprint)) + " missing)"
                selected: p.app.trialAll
                onClicked: if (!p.app.trialAll) p.app.computeAll()
            }
            Column {
                id: sum
                width: parent.width
                spacing: 4
                readonly property var s: p.app.summary
                Text {
                    text: "The trial changes"
                    color: p.app.ui.dim
                    font { family: p.app.ui.font; pixelSize: 11 }
                }
                Text {
                    text: "Seed: " + sum.s.seed + " wallpapers"
                    color: sum.s.seed ? p.app.ui.trial : p.app.ui.text
                    font { family: p.app.ui.font; pixelSize: 13; bold: true }
                }
                Text {
                    text: "palette only: " + sum.s.palette + " wallpapers"
                    color: sum.s.palette ? p.app.ui.trial : p.app.ui.text
                    font { family: p.app.ui.font; pixelSize: 13; bold: true }
                }
                Text {
                    text: "unchanged: " + (sum.s.both - sum.s.seed - sum.s.palette)
                          + (sum.s.both < p.app.total ? "   (compared " + sum.s.both + "/" + p.app.total + ")" : "")
                    color: p.app.ui.dim
                    font { family: p.app.ui.font; pixelSize: 12 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: p.app.ui.line }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: p.app.copied ? "Copied " + p.app.copied : "Click a hex to copy it."
                color: p.app.ui.dim
                font { family: p.app.ui.font; pixelSize: 12 }
            }
            Text {
                visible: p.app.helperError !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: p.app.helperError
                color: p.app.ui.error
                font { family: p.app.ui.font; pixelSize: 12 }
            }
        }
    }
}
