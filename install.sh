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
tested=4.2.0  # helper/tuner.py: TESTED_MATUGEN

if [ "${1:-}" = --uninstall ]; then
    [ -L "$link" ] && rm "$link" && echo "removed $link"
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
if command -v matugen >/dev/null 2>&1; then
    version=$(matugen --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1) || true
    case $version in
        4.2.*) ;;
        *) echo "warning: matugen ${version:-of unknown version} found, tested with matugen $tested; results may differ" >&2 ;;
    esac
else
    need "matugen not found: install matugen $tested (pacman -S matugen)"
fi

# The Ajmashell directory the tool will use: the one of its settings (default ~/.config/quickshell/ajmashell),
# read by helper/settings.py itself, so this check and the window always agree. Without Python only the default.
if command -v python3 >/dev/null 2>&1; then
    ajmashell=$(python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import settings
print(settings.load()[0]["ajmashellDir"])' "$here/helper")
else
    need "python3 not found: install Python 3 (pacman -S python)"
    ajmashell=$config/quickshell/ajmashell
fi
if [ ! -f "$ajmashell/wallpaper/palette_recipe.py" ] || [ ! -f "$ajmashell/wallpaper/indexer.py" ]; then
    need "Ajmashell not found in $ajmashell (no wallpaper/palette_recipe.py or wallpaper/indexer.py): install \
Ajmashell (https://github.com/Wiecek-K/arch-hyprland-ajmag), or put its directory as \"ajmashellDir\" into \
${XDG_CONFIG_HOME:-$HOME/.config}/ajmashell-theme-center/settings.json"
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
