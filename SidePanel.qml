// Right panel (variant D of the prototype): controls of the Przepis próbny next to the Przepis obecny (the system
// file), "przywróć obecny", "zapisz jako Przepis systemu" with the steps after it, folder progress for both recipes,
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
    readonly property var ruleNames: ({ dominant: "najbardziej dominujący", darkness: "najciemniejszy",
                                        lightness: "najjaśniejszy", saturation: "najbardziej nasycony",
                                        "less-saturation": "najmniej nasycony", value: "największa jasność" })
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

            Text { text: "Przepis obecny"; color: p.app.ui.accent; font { family: p.app.ui.font; pixelSize: 14; bold: true } }
            Text { text: "plik Przepisu systemu"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
            Grid {
                columns: 2
                columnSpacing: 12
                rowSpacing: 6
                Repeater {
                    // label, value, label, value, …
                    model: p.r ? [
                        "Wybór Seeda", p.ruleName(p.r.seed.rule),
                        "Schemat", p.r.palette.scheme.replace("scheme-", ""),
                        "Kontrast", p.r.palette.contrast.toFixed(2),
                        "Jasność ciemnej", p.r.palette.lightnessDark.toFixed(2)
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
                    text: "Przepis próbny"
                    color: p.app.ui.trial
                    font { family: p.app.ui.font; pixelSize: 14; bold: true }
                }
                Chip {
                    anchors.right: parent.right
                    app: p.app
                    label: "przywróć obecny"
                    tone: p.app.ui.accent
                    enabled: p.app.trialDiffers || p.app.trialEdited
                    onClicked: p.app.restore()
                }
            }

            Column {
                width: parent.width
                spacing: 6
                Text { text: "Wybór Seeda"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
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
                Text { text: "Schemat palety"; color: p.app.ui.dim; font { family: p.app.ui.font; pixelSize: 11 } }
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
                label: "Kontrast"
                key: "contrast"
                range: p.o ? p.o.contrast : [-1, 1]
            }
            TrialSlider {
                width: parent.width
                app: p.app
                label: "Jasność palety ciemnej"
                key: "lightnessDark"
                range: p.o ? p.o.lightnessDark : [null, 1]
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Niebieska ramka i kreska: wartość Przepisu obecnego."
                color: p.app.ui.dim
                font { family: p.app.ui.font; pixelSize: 11 }
            }

            // story 51-55: one button, no commit; the steps after the file run in the helper's background
            Chip {
                app: p.app
                label: p.app.saving ? "zapisuję…" : "zapisz jako Przepis systemu"
                tone: p.app.ui.trial
                selected: p.app.trialEdited && !p.app.saving && !p.app.applying
                enabled: selected
                onClicked: p.app.saveTrial()
            }
            Text {
                readonly property var stages: ({ indexer: "Zapisano plik Przepisu. Przeliczam indeks karuzeli…",
                                                 wallpaper: "Nakładam nowy Przepis na bieżącą tapetę…",
                                                 done: "Zapisano i nałożono na pulpit. Bez commita w dotfiles.",
                                                 error: "Plik zapisany, ale nałożenie się nie udało: " })
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: p.app.saveError ? "Nie zapisano: " + p.app.saveError
                      : p.app.applyStage ? stages[p.app.applyStage] + (p.app.applyStage === "error" ? p.app.applyError : "") : ""
                color: p.app.saveError || p.app.applyStage === "error" ? p.app.ui.error
                       : p.app.applying ? p.app.ui.text : p.app.ui.dim
                font { family: p.app.ui.font; pixelSize: 12 }
            }

            Rectangle { width: parent.width; height: 1; color: p.app.ui.line }

            Repeater {
                model: [["obecny", p.app.fingerprint], ["próbny", p.app.trialFingerprint]]
                Text {
                    id: pr
                    required property var modelData
                    readonly property int n: p.app.doneOf(pr.modelData[1])
                    text: (pr.n < p.app.total ? "Liczenie " : "Policzone ") + pr.modelData[0] + " " + pr.n + "/" + p.app.total
                    color: pr.n < p.app.total ? p.app.ui.text : p.app.ui.dim
                    font { family: "monospace"; pixelSize: 13 }
                }
            }
            Chip {
                // the rest of the folder for the trial, on demand (user, 2026-10-20): moving a control computes
                // only the selected wallpaper
                visible: p.app.trialDiffers && p.app.doneOf(p.app.trialFingerprint) < p.app.total
                app: p.app
                label: p.app.trialAll ? "liczę pozostałe tapety…" : "przelicz wszystkie tapety ("
                       + (p.app.total - p.app.doneOf(p.app.trialFingerprint)) + " brakuje)"
                selected: p.app.trialAll
                onClicked: if (!p.app.trialAll) p.app.computeAll()
            }
            Column {
                id: sum
                width: parent.width
                spacing: 4
                readonly property var s: p.app.summary
                Text {
                    text: "Próba zmienia"
                    color: p.app.ui.dim
                    font { family: p.app.ui.font; pixelSize: 11 }
                }
                Text {
                    text: "Seed: " + sum.s.seed + " tapet"
                    color: sum.s.seed ? p.app.ui.trial : p.app.ui.text
                    font { family: p.app.ui.font; pixelSize: 13; bold: true }
                }
                Text {
                    text: "tylko paletę: " + sum.s.palette + " tapet"
                    color: sum.s.palette ? p.app.ui.trial : p.app.ui.text
                    font { family: p.app.ui.font; pixelSize: 13; bold: true }
                }
                Text {
                    text: "bez zmian: " + (sum.s.both - sum.s.seed - sum.s.palette)
                          + (sum.s.both < p.app.total ? "   (porównane " + sum.s.both + "/" + p.app.total + ")" : "")
                    color: p.app.ui.dim
                    font { family: p.app.ui.font; pixelSize: 12 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: p.app.ui.line }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: p.app.copied ? "Skopiowano " + p.app.copied : "Klik w hex kopiuje."
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
