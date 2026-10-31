# SPDX-License-Identifier: AGPL-3.0-or-later
# Saved settings of Theme Center (ticket E18): a look or a palette recipe kept under a name the user typed, one file
# <folder>/<name>.json each, so the Look and Palette tabs switch between a few of them quickly. The folder sits next
# to the module's live file (~/.local/state/ajmashell/saved/look, …/saved/palette): local, outside git. The content
# is written and read by the module of its kind (look_settings, palette_recipe: strict save, lenient load); here
# only the names and the files. Python standard library only.

import os

MAX_NAME = 64


def folder(live_file, kind):
    """The folder of the saved settings of one kind, next to the module's live file."""
    return os.path.join(os.path.dirname(live_file), "saved", kind)


def check_name(name):
    """The name without spaces around it, or ValueError: one file name, never a path or a hidden file."""
    if not isinstance(name, str):
        raise ValueError("the name is not text")
    name = name.strip()
    if not name:
        raise ValueError("type a name")
    if len(name) > MAX_NAME:
        raise ValueError(f"the name is longer than {MAX_NAME} characters")
    if "/" in name or "\\" in name or name.startswith(".") or any(ord(c) < 32 or ord(c) == 127 for c in name):
        raise ValueError("the name cannot contain / or \\, start with a dot or hold control characters")
    return name


def path(where, name):
    return os.path.join(where, check_name(name) + ".json")


def names(where):
    """The names in the folder, sorted without regard to case; files that no name gives (hidden, other
    extensions, the temporary files of a save) are left out. No folder = none."""
    try:
        files = os.listdir(where)
    except FileNotFoundError:
        return []
    out = []
    for f in files:
        if not f.endswith(".json") or not os.path.isfile(os.path.join(where, f)):
            continue
        try:
            if check_name(f[:-5]) == f[:-5]:
                out.append(f[:-5])
        except ValueError:
            pass
    return sorted(out, key=lambda n: (n.casefold(), n))


def delete(where, name):
    os.remove(path(where, name))
