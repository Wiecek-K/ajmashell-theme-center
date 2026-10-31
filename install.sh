#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Install Ajmashell Theme Center from this clone (ticket 11): check what it needs, link the clone as the Quickshell
# config `ajmashell-theme-center` (start: qs -c ajmashell-theme-center) and add the launcher entry. Everything stays
# in your home directory, nothing runs with sudo. Run it again after moving the clone.
#   ./install.sh               check and install; exit 1 (nothing installed) when something is missing
#   ./install.sh --uninstall   remove the link and the launcher entry (the clone, settings and cache stay)
set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
config=${XDG_CONFIG_HOME:-$HOME/.config}
link=$config/quickshell/ajmashell-theme-center
desktop=${XDG_DATA_HOME:-$HOME/.local/share}/applications/ajmashell-theme-center.desktop

if [ "${1:-}" = --uninstall ]; then
    # only a link to this clone: another clone's link is that clone's to remove
    [ "$(readlink "$link" 2>/dev/null)" = "$here" ] && rm "$link" && echo "removed $link"
    [ -f "$desktop" ] && rm "$desktop" && echo "removed $desktop"
    exit 0
elif [ $# -gt 0 ]; then
    echo "usage: $0 [--uninstall]" >&2
    exit 2
fi

missing=0
need() {
    echo "$1" >&2
    missing=1
}

command -v qs >/dev/null 2>&1 || need "qs not found: install Quickshell (pacman -S quickshell)"
# the tested version is TESTED_MATUGEN in helper/tuner.py; the version check below is the helper's own
command -v matugen >/dev/null 2>&1 || need "matugen not found: install matugen 4.2.0 (pacman -S matugen)"
# snapshots open and save in the system file dialog through zenity (ticket E18): without it only they are off
command -v zenity >/dev/null 2>&1 || echo "warning: zenity not found: Open and Save as (snapshots) stay off; pacman -S zenity" >&2

# With Python: the helper's own checks, so this script and the window always agree: the Ajmashell directory of the
# settings (helper/settings.py, default ~/.config/quickshell/ajmashell) and the matugen version (a warning only).
# Without Python neither can run, and the run fails on python3 anyway.
if command -v python3 >/dev/null 2>&1; then
    if checks=$(python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import settings, tuner
paths, _ = settings.load()
if not next(s["found"] for s in settings.status(paths) if s["key"] == "ajmashellDir"):
    print("missing:" + paths["ajmashellDir"] + " (needs wallpaper/" + " and wallpaper/".join(settings.RECIPE_MODULES) + ")")
warning = tuner.matugen_warning()
if warning and not warning.startswith("matugen not found"):
    print("warning:" + warning)' "$here/helper" 2>&1); then
        while IFS= read -r line; do
            case $line in
                missing:*) need "Ajmashell not found in ${line#missing:}: install Ajmashell (https://github.com/Wiecek-K/arch-hyprland-ajmag), \
or put its directory as \"ajmashellDir\" into ${XDG_CONFIG_HOME:-$HOME/.config}/ajmashell-theme-center/settings.json" ;;
                warning:*) echo "warning: ${line#warning:}" >&2 ;;
            esac
        done <<EOT
$checks
EOT
    else
        need "the helper's checks failed (python3 $(python3 --version 2>&1)): $(printf '%s\n' "$checks" | tail -n 1)"
    fi
else
    need "python3 not found: install Python 3 (pacman -S python)"
fi

if [ -e "$link" ] && [ ! -L "$link" ]; then
    need "$link exists and is not a link: move it away, then run $0 again"
fi
[ "$missing" = 0 ] || { echo "nothing installed" >&2; exit 1; }

mkdir -p "$(dirname "$link")"
ln -sfn "$here" "$link"
echo "linked $link -> $here"
install -Dm644 "$here/ajmashell-theme-center.desktop" "$desktop"
echo "installed $desktop"
echo "start: \"Ajmashell Theme Center\" in the launcher, or qs -n -c ajmashell-theme-center"
