// Slider of one number of the trial recipe. Range from palette_recipe.options(); a missing low end (no limit, as
// lightnessDark: matugen takes -inf..1) gets the floor below. The value is rounded to 0.05 steps, so the fingerprint
// does not depend on float noise. No keyboard focus: the arrows keep moving the strip.
import QtQuick
import QtQuick.Controls

Column {
    id: s
    property var app
    property string label
    property string key            // field in recipe.palette
    property var range: [null, 1]  // [low, high], null = no limit
    readonly property real floor: -1
    readonly property real value: app.trial ? app.trial.palette[key] : 0
    readonly property real current: app.recipe ? app.recipe.palette[key] : 0
    spacing: 4

    Text {
        text: s.label + "  " + s.value.toFixed(2) + (s.value !== s.current ? "   (current " + s.current.toFixed(2) + ")" : "")
        color: s.value !== s.current ? s.app.ui.trial : s.app.ui.dim
        font { family: s.app.ui.font; pixelSize: 11 }
    }
    Slider {
        id: sl
        width: s.width
        height: 24
        from: s.range[0] === null ? s.floor : s.range[0]
        to: s.range[1] === null ? 1 : s.range[1]
        stepSize: 0.05
        snapMode: Slider.SnapAlways
        focusPolicy: Qt.NoFocus
        value: s.value
        onMoved: s.app.setTrial("palette", s.key, Math.round(value * 100) / 100)
        background: Rectangle {
            x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: sl.availableWidth; height: 4; radius: 2
            color: s.app.ui.line
            Rectangle {
                // mark of the current (system) value
                x: (s.current - sl.from) / (sl.to - sl.from) * parent.width - 1
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
