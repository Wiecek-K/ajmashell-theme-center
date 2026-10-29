// SPDX-License-Identifier: AGPL-3.0-or-later
// State of the Settings tab (ticket 12, ADR 0020): the paths live in PaletteState (the helper's protocol); this gives
// the frame the tab interface. Nothing to save with "Save all": a path is applied in the tab itself. Leaving the tab
// drops what was typed and not applied, as closing the panel did before (ticket 09).
import QtQuick

QtObject {
    property var palette
    readonly property bool edited: false
    readonly property bool busy: false
    readonly property int missing: palette.settings.filter(s => !s.found).length
    readonly property string note: missing ? missing + " missing" : ""
    readonly property bool alert: missing > 0 || palette.settingsWarning !== ""

    function leave() { palette.discardSettings(); }
}
