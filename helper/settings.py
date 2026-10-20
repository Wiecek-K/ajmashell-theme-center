# Settings of Ajmashell Theme Center (faza E ticket 09): every path the tool needs from the Ajmashell install and the
# system, with its default in one place (DEFAULTS, the paths of the dotfiles), so a user with Ajmashell elsewhere only
# sets their own. The file holds only the paths that differ from the default:
# $XDG_CONFIG_HOME/ajmashell-theme-center/settings.json (default ~/.config/...). No file = all defaults.

import json
import os

# key -> default ("~" for the home directory, shown as it is in the window)
DEFAULTS = {
    "ajmashellDir": "~/.config/quickshell/ajmashell",   # wallpaper/palette_recipe.py, wallpaper/indexer.py
    "recipeFile": "~/.config/matugen/przepis-palety.json",
    "wallpaperIndex": "~/.cache/ajmashell/wallpapers/index.json",
    "currentWallpaper": "~/.config/hypr/current_wallpaper",
    "kittyTemplate": "~/.config/matugen/templates/kitty-colors.conf",
    "looknfeel": "~/.config/hypr/configs/looknfeel.lua",
    "windowRules": "~/.config/hypr/configs/rules.lua",
    "wpapply": "~/.config/hypr/scripts/wpapply.sh",
}

LABELS = {
    "ajmashellDir": "Ajmashell directory",
    "recipeFile": "Palette recipe file",
    "wallpaperIndex": "Carousel wallpaper index",
    "currentWallpaper": "Current wallpaper link",
    "kittyTemplate": "kitty colour template",
    "looknfeel": "Hyprland looknfeel.lua",
    "windowRules": "Hyprland rules.lua",
    "wpapply": "wpapply.sh",
}

# What stops working while the path is missing (shown in the window with the path)
EFFECTS = {
    "recipeFile": "the palette recipe shows its starting values; a save creates the file",
    "wallpaperIndex": "no wallpapers. Open the wallpaper carousel (Super + W) once to build the index",
    "currentWallpaper": "no wallpaper is marked as on desktop, and a save cannot apply the palette",
    "kittyTemplate": "the kitty mock-up is off",
    "looknfeel": "the window border of the kitty mock-up is grey",
    "windowRules": "the kitty mock-up is drawn opaque",
    "wpapply": "a save writes the palette recipe file but cannot apply it to the desktop",
}

RECIPE_MODULES = ("palette_recipe.py", "indexer.py")  # in <ajmashellDir>/wallpaper


def default_file():
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(config, "ajmashell-theme-center", "settings.json")


def _expand(path):
    return os.path.expanduser(path.strip())


def load(file=None):
    """(paths, warning): every key of DEFAULTS with its path ("~" expanded). A broken file or value falls back to the
    default and gives a warning for the window; a missing file is no warning."""
    file = file or default_file()
    paths = {k: _expand(v) for k, v in DEFAULTS.items()}
    try:
        with open(file, encoding="utf-8") as f:
            given = json.load(f)
    except FileNotFoundError:
        return paths, None
    except (OSError, ValueError) as e:
        return paths, f"{file}: cannot be read ({e}); using the default paths"
    if not isinstance(given, dict):
        return paths, f"{file}: not a JSON object; using the default paths"
    wrong = []
    for key, value in given.items():
        if key not in DEFAULTS:
            continue  # a key of a later version: ignored, dropped by the next save
        if isinstance(value, str) and value.strip():
            paths[key] = _expand(value)
        else:
            wrong.append(key)
    return paths, f"{file}: {', '.join(wrong)} not a path; using the default" if wrong else None


def _check(given):
    for key, value in given.items():
        if key not in DEFAULTS:
            raise ValueError(f"unknown setting {key!r}")
        if not isinstance(value, str):
            raise ValueError(f"{key}: not a path")


def resolve(given):
    """Paths typed in the window (key -> text, an empty or absent one = the default) as load() returns them.
    An unknown key or a value that is not text: ValueError."""
    _check(given)
    return {k: _expand(given.get(k, "").strip() or v) for k, v in DEFAULTS.items()}


def save(paths, file=None):
    """Write the paths that differ from their default (an empty one = the default). Atomic: a temporary file next to
    it, then one rename. An unknown key or a value that is not text: ValueError, the file stays as it was."""
    file = file or default_file()
    _check(paths)
    stored = {k: v.strip() for k, v in paths.items()
              if v.strip() and _expand(v) != _expand(DEFAULTS[k])}
    os.makedirs(os.path.dirname(file), exist_ok=True)
    tmp = f"{file}.{os.getpid()}.tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(json.dumps(stored, indent=2) + "\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, file)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def status(paths):
    """For the Settings panel, in the order of DEFAULTS: [{key, label, value, own, default, found, problem}]:
    own = the path when it is not the default, else "" (the field shows it; empty = the default), problem = the text
    the window shows for a missing path (None when found)."""
    out = []
    for key, default in DEFAULTS.items():
        value = paths[key]
        if key == "ajmashellDir":
            absent = [n for n in RECIPE_MODULES if not os.path.isfile(os.path.join(value, "wallpaper", n))]
            problem = (f"{value}: no wallpaper/{' or wallpaper/'.join(absent)}; the palette cannot be computed and "
                       "nothing can be saved. Set the Ajmashell directory in Settings") if absent else None
        elif not os.path.isfile(value):
            problem = f"{value} not found: {EFFECTS[key]}"
        elif key == "wpapply" and not os.access(value, os.X_OK):
            problem = f"{value} is not executable: {EFFECTS[key]}"
        else:
            problem = None
        out.append({"key": key, "label": LABELS[key], "value": value,
                    "own": value if value != _expand(default) else "", "default": default,
                    "found": problem is None, "problem": problem})
    return out
