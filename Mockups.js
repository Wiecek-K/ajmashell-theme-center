// SPDX-License-Identifier: AGPL-3.0-or-later
.pragma library
// The one place that says which matugen token paints which part of the mock-ups (ticket 06, story 41).
// Change it together with the system file named in each section, or the mock-ups drift from the real desktop.
//
// - Ajmashell (Bar, popup): roles of ~/.config/quickshell/ajmashell/singletons/theme/Theme.qml, which reads the
//   tokens written by the matugen template ajmashell-colors.json. Theme.qml is QML bindings, so its roles are
//   copied here by hand (with the alphas); the popup is the control centre in the look `fancy2`
//   (singletons/look/Look.qml, the look a shell restart starts with).
// - kitty: not copied. The helper reads the matugen template kitty-colors.conf on start (tuner.py system_look())
//   and sends {kitty key: token}; kitty() below only turns a kitty key into a colour.
// - Hyprland: the tokens and the angle of `active_border` (configs/looknfeel.lua) and the opacity of the kitty
//   window rule (configs/rules.lua) also come from the helper; border_size is copied (see below).

// Theme.qml: Qt.alpha(colour, a) as a QML colour string #AARRGGBB
function alpha(hex, a) {
    if (!hex || hex[0] !== "#") return "transparent";
    const aa = Math.round(a * 255).toString(16).padStart(2, "0");
    return "#" + aa + hex.slice(1);
}

// Bar and the control centre for one palette c = {token: hex}
function desktop(c) {
    const g = token => c && c[token] ? c[token] : "transparent"; // no palette yet: nothing drawn, no warnings
    return {
        // Theme.bar
        island: alpha(g("surface_container"), 0.75),    // bar.island (blurred by Hyprland on the real Bar)
        text: g("secondary"),                           // bar.text: clock, media, volume, icons
        connected: g("primary_fixed"),                  // bar.connected: BT icon with a device connected
        separator: g("secondary"),                      // bar.separator
        wsActive: alpha(g("primary_fixed"), 0.75),      // bar.workspace.activeBackground (focused: full circle)
        wsActiveText: g("background"),                  // bar.workspace.activeText
        wsOccupied: g("secondary"),                     // bar.workspace.occupied
        wsEmpty: g("outline"),                          // bar.workspace.empty
        // Theme.control in the look fancy2 (opaque, softPills)
        popup: g("on_primary_fixed"),                   // control.backgroundOpaque = launcher.backgroundOpaque
        popupText: g("on_surface"),                     // control.text = orbit.text
        popupSubtext: g("on_surface_variant"),          // control.subtext
        track: alpha(g("on_surface"), 0.07),            // control.track (orbit.softPill.idle)
        fill: g("primary"),                             // control.fill = orbit.tab (slider, switch on)
        pillOn: alpha(g("primary"), 0.25),              // soft pill of a switch that is on (orbit.softPill.active)
        pillOnText: g("primary"),
        pillOff: alpha(g("on_surface"), 0.07),          // soft pill, idle
        pillOffText: g("on_surface"),
        separatorLine: alpha(g("on_surface"), 0.12),    // control.separator
        critical: g("error")                            // notifications.critical
    };
}

// kitty key (kitty-colors.conf: background, color0..15, active_tab_background, …) -> colour; grey when the
// template has no such key, so a missing line shows instead of passing silently
function kitty(c, map, key) {
    const token = map ? map[key] : "";
    return token && c[token] ? c[token] : "#808080";
}

// active_border: colours spread evenly along the angle, as in Hyprland's border shader (getColorForCoord):
// progress = x·(1−sin a) + y·sin a over the normalised box, with the box flipped for angles past 90°.
// Returns the end points of an equivalent QML LinearGradient in pixels of a w×h box.
function borderLine(angleDeg, w, h) {
    let a = ((angleDeg % 360) + 360) % 360 * Math.PI / 180;
    let flipX = false, flipY = false;
    if (a > 3 * Math.PI / 2) { flipY = true; a = 2 * Math.PI - a; }
    else if (a > Math.PI) { flipX = flipY = true; a = a - Math.PI; }
    else if (a > Math.PI / 2) { flipX = true; a = Math.PI - a; }
    const s = Math.sin(a);
    const gx = (1 - s) / w, gy = s / h;    // progress gradient per pixel
    const k = 1 / (gx * gx + gy * gy);       // the point at progress 1 lies along (gx, gy)
    let x1 = 0, y1 = 0, x2 = gx * k, y2 = gy * k;
    if (flipX) { x1 = w - x1; x2 = w - x2; }
    if (flipY) { y1 = h - y1; y2 = h - y2; }
    return { x1: x1, y1: y1, x2: x2, y2: y2 };
}

// colour at t (0..1) of n colours spread evenly over 0..1, mixed linearly in sRGB like a gradient
function sample(colours, t) {
    if (!colours || !colours.length) return "#808080";
    if (colours.length === 1) return colours[0];
    const f = t * (colours.length - 1), i = Math.min(colours.length - 2, Math.floor(f)), u = f - i;
    let out = "#";
    for (let ch = 1; ch < 7; ch += 2) {
        const a = parseInt(colours[i].substr(ch, 2), 16), b = parseInt(colours[i + 1].substr(ch, 2), 16);
        out += Math.round(a + (b - a) * u).toString(16).padStart(2, "0");
    }
    return out;
}

// border_size of looknfeel.lua (copied); the corners are smaller than its rounding = 16, since the mock-up
// window is about a fifth of the real one
var borderSize = 3;
var rounding = 10;

// Theme.font.family of Ajmashell and font_family of kitty.conf (the same font)
var font = "AtkinsonHyperlegibleMono Nerd Font";
