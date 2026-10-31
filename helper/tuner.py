#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Helper of Ajmashell Theme Center, palette tuning (faza E, ADR 0019): computes, with the real matugen, the palette the
# system would give each carousel wallpaper for a given palette recipe. Long-lived; talks to the QML window by JSON
# messages, one per line. The recipe logic (validation, matugen flags, fingerprint) and the colour categories are
# imported from the Ajmashell install by path, never copied, so the tool shows exactly what wpapply.sh and the
# carousel indexer would do. Every path comes from the settings (settings.py, ticket 09), except the palette recipe
# file: the module's own path (palette_recipe.DEFAULT_PATH, the live file; without it the module's default recipe),
# read the same way by wpapply.sh and the indexer. A missing path
# is a message in the window, never a crash: without the Ajmashell directory nothing is computed or saved, the rest
# still starts.
#
# Window -> helper (stdin):
#   {"type": "compute", "recipes": [{...} | null, ...], "orders": [[fileName, ...], ...]}
#       recipes = current recipe and trial recipe (null = the system palette recipe); orders[i] = wallpapers to
#       compute for recipes[i], the selected one first (the trial gets only the selected one until the user asks for
#       all).
#       Jobs run wallpaper by wallpaper in the order of the longest list. A new request replaces the queue of the
#       previous one: jobs it no longer names are dropped, the rest follow the new order.
#   {"type": "save", "recipe": {...}}
#       write the recipe into the live palette recipe file (palette_recipe.save: strict validation, atomic), then
#       in the background the carousel indexer and wpapply.sh on the current wallpaper (ticket 07). Saves run one at
#       a time.
#   {"type": "saveLook", "look": {...}}
#       write the look as Ajmashell's live look file (look_settings.save: strict validation, atomic); Ajmashell watches
#       the file and changes at once (ticket 13).
#   {"type": "readLook"}   the live look file again: the window saw it change (a hand edit, a delete)
#   {"type": "readRecipe"}   the palette recipe again: the window saw its live file change (a hand edit, a delete)
#   {"type": "saveAs", "kind": "look" | "palette", "name": text, "data": {...}, "overwrite": bool}
#       keep a look or a palette recipe under a name (ticket E18, saved.py): the module's strict save into
#       <live file's folder>/saved/<kind>/<name>.json; an existing name only with "overwrite". The live file stays.
#   {"type": "loadSaved", "kind", "name"}   read a saved setting the way the module reads its live file (lenient)
#   {"type": "deleteSaved", "kind", "name"}
#   {"type": "check", "paths": {key: text}}   status of paths typed in the Settings panel, nothing saved
#   {"type": "settings", "paths": {key: text}}
#       save the settings (settings.save: atomic, an empty path = the default), then the helper restarts itself in the
#       same process (exec), so the window keeps its pipe and gets a new "ready". The window sends nothing more until
#       then.
# Helper -> window (stdout):
#   {"type": "ready", "items": [{fileName, path, thumb}], "current": fileName | null,
#    "recipe": {...} | null, "fingerprint": fp | null,   (null: no recipe module, see "problems")
#    "recipeWarnings": [text],   (palette_recipe.load's warnings: a bad field of the live file or the default recipe)
#    "options": {rules, schemes, contrast: [lo, hi], lightnessDark: [lo, hi]} | null,   (palette_recipe.options())
#    "look": {"kitty": {key: token}, "border": [token], "borderAngle": deg, "kittyOpacity": a, "problems": [text]},
#       (system_look(): what the mock-ups read from the system's own files, see there)
#    "settings": [{key, label, value, own, default, found, problem}],   (settings.status())
#    "recipeFile": path | null,   (palette_recipe.DEFAULT_PATH of the module in use; null without the module)
#    "settingsFile": path, "settingsWarning": text | null,   (a broken settings.json: the defaults are used)
#    "problems": [text],   (each missing path with what it stops; shown in the window)
#    "matugenWarning": text | null,   (matugen missing or not 4.2.x: shown in the window, nothing blocked)
#    "lookSettings": {"options": {...}, "current": {...}, "file": path, "gradientFill": path | null} | null}
#       (the Look tab, ticket 13: look_settings.options() and load() of <ajmashellDir>/singletons/look; null without
#       the module, see "problems"; ticket 14: <ajmashellDir>/look/GradientFill.qml, which the previews load to draw
#       the gradient, null without it)
#    "saved": {"look": [name] | null, "palette": [name] | null}   (saved settings, ticket E18; null without the module)
#   {"type": "savedAs", "kind", "name", "data": {...}} | {"type": "savedAs", "kind", "name", "error": text}
#       (the validated setting, or why it was not saved; on success a "savedList" follows)
#   {"type": "savedLoaded", "kind", "name", "data": {...}, "warnings": [text]} | {…, "error": text}
#   {"type": "savedList", "kind", "names": [name]} | {…, "error": text}   (after a save and a delete)
#   {"type": "checked", "settings": [...]}   (settings.status() of the paths of a "check")
#   {"type": "settingsSaved", "error": text}   (settings not saved; on success a new "ready" comes instead)
#   {"type": "accepted", "recipes": [{...}], "fingerprints": [fp]}   (validated, in the order of the request)
#   {"type": "result", "fingerprint", "fileName", "candidates": [hex], "seed": hex, "category", "colors": {token: hex}}
#   {"type": "error", "fingerprint", "fileName", "message"}
#   {"type": "progress", "fingerprint", "done": n, "total": n}   (per recipe; total = all wallpapers)
#   {"type": "saved", "recipe": {...}, "fingerprint"} | {"type": "saved", "error": text}   (file written or not)
#   {"type": "apply", "stage": "indexer" | "wallpaper" | "done"} | {"type": "apply", "stage": "error", "message"}
#   {"type": "lookSaved", "look": {...}} | {"type": "lookSaved", "error": text}   (live look file written or not)
#   {"type": "lookRead", "current": {...}}   (look_settings.load() after "readLook"; nothing without the module)
#   {"type": "recipeRead", "recipe": {...}, "fingerprint", "recipeWarnings": [text]}   (palette_recipe.load() after
#       "readRecipe"; nothing without the module)
#
# Results are cached per (wallpaper path, mtime, size, recipe fingerprint) in $XDG_CACHE_HOME/ajmashell-theme-center
# (default ~/.cache), so a second start is instant. At most half the cores, like the indexer (the CPU is this
# machine's bottleneck).

import contextlib
import hashlib
import importlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor

sys.dont_write_bytecode = True  # no __pycache__ in the Ajmashell install
import saved  # noqa: E402
import settings  # noqa: E402

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
                     "ajmashell-theme-center", "results")
WORKERS = max(1, (os.cpu_count() or 2) // 2)
TESTED_MATUGEN = "4.2.0"  # any 4.2.x is fine; another version gives a warning in the window
TESTED_NOTE = f"tested with matugen {TESTED_MATUGEN}, results may differ"
NO_MODULE = "the Ajmashell directory has no palette recipe module (see Settings)"
NO_LOOK_MODULE = "the Ajmashell directory has no look module (singletons/look/look_settings.py; see Settings)"

PATHS = {}              # settings.load(): key -> path
palette_recipe = None   # <ajmashellDir>/wallpaper/palette_recipe.py, imported in main()
indexer = None          # <ajmashellDir>/wallpaper/indexer.py (color_bucket: carousel thresholds = colour category)
look_settings = None    # <ajmashellDir>/singletons/look/look_settings.py (the Look tab), imported in main()

out_lock = threading.Lock()


def send(msg):
    with out_lock:
        sys.stdout.write(json.dumps(msg, separators=(",", ":")) + "\n")
        sys.stdout.flush()


def matugen(args):
    r = subprocess.run(["matugen", *args], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        # first line of matugen's (colour-coded) error report; the rest is a backtrace hint
        lines = [re.sub(r"\x1b\[[0-9;]*m", "", ln).strip() for ln in (r.stderr or r.stdout).splitlines()]
        raise RuntimeError(next((ln for ln in lines if ln), f"matugen exit {r.returncode}"))
    return r.stdout


def system_recipe():
    """(recipe, warnings): the recipe as the system reads it now and the module's warnings about bad fields, for the
    window (ticket E15)."""
    warnings = []
    return palette_recipe.load(warnings=warnings), warnings


def validated(recipe):
    """The recipe as the system would read it: through palette_recipe.load, so validation stays in one place."""
    if recipe is None:
        return palette_recipe.load()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(recipe, f)
    try:
        return palette_recipe.load(f.name)
    finally:
        os.unlink(f.name)


def system_look():
    """Colour sources of the kitty and window mock-ups, read from the system's files on every start (ticket 06,
    story 41), so a changed template shows up in the mock-ups instead of drifting from them:
    - kitty: every `key {{ colors.TOKEN.default.hex }}` line of the matugen kitty template,
    - border: the tokens and angle of `active_border` in Hyprland's looknfeel.lua,
    - kittyOpacity: the active opacity of the kitty window rule in rules.lua.
    A line that cannot be recognised lands in `problems` (shown in the window); the mock-up then uses its fallback
    from Mockups.js. A missing file is no problem here: settings.status() reports it with what it stops. The
    Ajmashell colours (Bar, popup) are QML bindings and stay mapped in Mockups.js."""
    look = {"kitty": {}, "border": [], "borderAngle": 0, "kittyOpacity": None, "problems": []}

    def read(key):
        """The file's text, or None when it is missing or unreadable."""
        try:
            with open(PATHS[key], encoding="utf-8") as f:
                return f.read()
        except FileNotFoundError:
            return None
        except OSError as e:
            look["problems"].append(f"{PATHS[key]}: {e.strerror}")
            return None

    text = read("kittyTemplate")
    if text is not None:
        for m in re.finditer(r"^\s*(\w+)\s+\{\{\s*colors\.(\w+)\.default\.hex\s*\}\}", text, re.M):
            look["kitty"][m.group(1)] = m.group(2)
        if not look["kitty"]:
            look["problems"].append(f"{PATHS['kittyTemplate']}: no colour lines")
    text = read("looknfeel")
    if text is not None:
        m = re.search(r"active_border\s*=\s*\{\s*colors\s*=\s*\{([^}]*)\}\s*,\s*angle\s*=\s*(-?\d+)", text)
        if m:
            look["border"] = re.findall(r"c\.(\w+)", m.group(1))
            look["borderAngle"] = int(m.group(2))
        if not look["border"]:
            look["problems"].append(f"{PATHS['looknfeel']}: active_border not recognised")
    text = read("windowRules")
    if text is not None:
        m = re.search(r'class\s*=\s*"\^\(kitty\)\$"[^\n]*opacity\s*=\s*"([0-9.]+)', text)
        if m:
            look["kittyOpacity"] = float(m.group(1))
        else:
            look["problems"].append(f"{PATHS['windowRules']}: kitty window rule (opacity) not recognised")
    return look


def compute(item, recipe):
    """Same steps as the system: the indexer picks the seed from the thumbnail with the recipe's flags, wpapply.sh
    builds the palette from the seed with `matugen color hex` and the palette flags (dark = the system's mode)."""
    thumb = item["thumb"]
    candidates = matugen(["image", "--show-source-colors", thumb]).split()
    seed_flags = palette_recipe.seed_flags(recipe)
    palette_flags = palette_recipe.palette_flags(recipe)
    img = json.loads(matugen(["image", "--dry-run", "-q", "-j", "hex", *seed_flags, *palette_flags, thumb]))
    seed = img["colors"]["source_color"]["dark"]["color"].lower()
    pal = json.loads(matugen(["color", "hex", seed, "--dry-run", "-q", "-j", "hex", *palette_flags]))
    colors = {k: v["dark"]["color"].lower() for k, v in sorted(pal["colors"].items())}
    return {"candidates": [c.lower() for c in candidates], "seed": seed,
            "category": indexer.color_bucket(colors["primary"]), "colors": colors}


def cache_file(item, fingerprint):
    key = f"{item['path']}:{item['mtime']}:{item['size']}:{fingerprint}"
    return os.path.join(CACHE, hashlib.sha256(key.encode()).hexdigest()[:24] + ".json")


def cached(item, fingerprint):
    try:
        with open(cache_file(item, fingerprint)) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def store(item, fingerprint, result):
    path = cache_file(item, fingerprint)
    tmp = path + ".tmp"
    try:
        with open(tmp, "w") as f:
            json.dump(result, f)
        os.replace(tmp, path)
    except OSError:
        pass


def load_items():
    """Wallpapers and thumbnails from the carousel index; mtime and size of the file itself for the cache key."""
    try:
        with open(PATHS["wallpaperIndex"]) as f:
            entries = json.load(f).get("items", [])
    except (OSError, ValueError):
        entries = []
    items = []
    for e in entries:
        try:
            st = os.stat(e["path"])
        except (OSError, KeyError):
            continue
        items.append({"fileName": e["fileName"], "path": e["path"], "thumb": e.get("thumb") or e["path"],
                      "mtime": int(st.st_mtime), "size": int(st.st_size)})
    return items


class Queue:
    """Jobs (fingerprint, fileName) of the newest request only. Workers take the first waiting job; what a recipe has
    done is kept for the whole run, so going back to an earlier recipe only computes what it is still missing."""

    def __init__(self, items):
        self.by_name = {i["fileName"]: i for i in items}
        self.cond = threading.Condition()
        self.waiting = []
        self.recipes = {}   # fingerprint -> validated recipe
        self.done = {}      # fingerprint -> fileNames with a result or an error
        self.running = set()

    def request(self, recipes, orders):
        fingerprints = [palette_recipe.fingerprint(r) for r in recipes]
        send({"type": "accepted", "recipes": recipes, "fingerprints": fingerprints})
        wanted = {}  # fingerprint -> fileNames asked for (the same recipe twice: the union)
        for fp, order in zip(fingerprints, orders):
            wanted.setdefault(fp, set()).update(n for n in order if n in self.by_name)
        names = [n for n in max(orders, key=len, default=[]) if n in self.by_name]
        for fp, recipe in zip(fingerprints, recipes):
            if fp in self.done:
                continue
            with self.cond:
                self.recipes[fp], self.done[fp] = recipe, set()
            for n in self.by_name:  # first time this recipe is seen: what the disk cache already has
                r = cached(self.by_name[n], fp)
                if r is not None:
                    self.finish(fp, n, {"type": "result", "fingerprint": fp, "fileName": n, **r})
            if not self.by_name:
                send({"type": "progress", "fingerprint": fp, "done": 0, "total": 0})
        with self.cond:
            self.waiting = [(fp, n) for n in names for fp in wanted
                            if n in wanted[fp] and n not in self.done[fp] and (fp, n) not in self.running]
            self.cond.notify_all()

    def finish(self, fingerprint, name, msg):
        send(msg)
        with self.cond:
            if name in self.done[fingerprint]:
                return
            self.done[fingerprint].add(name)
            send({"type": "progress", "fingerprint": fingerprint, "done": len(self.done[fingerprint]),
                  "total": len(self.by_name)})

    def take(self):
        with self.cond:
            while not self.waiting:
                self.cond.wait()
            job = self.waiting.pop(0)
            self.running.add(job)
            return job, self.recipes[job[0]]

    def work(self):
        while True:
            (fingerprint, name), recipe = self.take()
            item = self.by_name[name]
            try:
                r = compute(item, recipe)
            except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as e:
                self.finish(fingerprint, name, {"type": "error", "fingerprint": fingerprint, "fileName": name,
                                                "message": str(e)})
            else:
                store(item, fingerprint, r)
                self.finish(fingerprint, name, {"type": "result", "fingerprint": fingerprint, "fileName": name, **r})
            with self.cond:
                self.running.discard((fingerprint, name))


def run_step(cmd):
    """None when the command succeeded, else the last line it printed on stderr."""
    try:
        r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=600)
    except (OSError, subprocess.SubprocessError) as e:
        return str(e)
    if r.returncode == 0:
        return None
    lines = [re.sub(r"\x1b\[[0-9;]*m", "", ln).strip() for ln in r.stderr.splitlines()]
    return next((ln for ln in reversed(lines) if ln), f"exit {r.returncode}")


def save(recipe):
    """Story 51-55: the trial becomes the system palette recipe. The file first (the window takes it over as the
    current recipe at once), then the carousel index (seeds and colour categories of the new recipe, thumbnails
    kept) and wpapply.sh on the current wallpaper, so the desktop shows the new colours. wpapply.sh would run the
    indexer itself for a stale entry, but only for the current wallpaper's folder and without a report; here every
    step reports to the window."""
    if palette_recipe is None:
        send({"type": "saved", "error": NO_MODULE})
        return
    try:
        valid = palette_recipe.save(recipe)
        fingerprint = palette_recipe.fingerprint(valid)
    except Exception as e:  # noqa: BLE001  (any failure must reach the window, else it waits for "saved" forever)
        send({"type": "saved", "error": str(e) or type(e).__name__})
        return
    send({"type": "saved", "recipe": valid, "fingerprint": fingerprint})
    send({"type": "apply", "stage": "indexer"})
    err = run_step(["python3", os.path.join(PATHS["ajmashellDir"], "wallpaper", "indexer.py")])
    if err is None:
        current = current_wallpaper()
        if current is None:
            err = f"{PATHS['currentWallpaper']}: no current wallpaper"
        else:
            send({"type": "apply", "stage": "wallpaper"})
            err = run_step([PATHS["wpapply"], current])
    send({"type": "apply", "stage": "error", "message": err} if err else {"type": "apply", "stage": "done"})


def save_look(look):
    """The Look tab's trial becomes Ajmashell's look: the live file only (ADR 0021); Ajmashell applies it itself."""
    if look_settings is None:
        send({"type": "lookSaved", "error": NO_LOOK_MODULE})
        return
    try:
        valid = look_settings.save(look)
    except Exception as e:  # noqa: BLE001  (any failure must reach the window, else it waits for "lookSaved" forever)
        send({"type": "lookSaved", "error": str(e) or type(e).__name__})
        return
    send({"type": "lookSaved", "look": valid})


def read_look(path):
    """look_settings.load() of a saved look, its warnings (stderr in the module) as a list for the window. Only the
    main loop calls it; the workers print nothing on stderr (their failures go to the window as messages)."""
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        data = look_settings.load(path)
    return data, [ln.removeprefix("look_settings: ") for ln in err.getvalue().splitlines() if ln]


def read_recipe(path):
    warnings = []
    data = palette_recipe.load(path, warnings=warnings)
    return data, [w.removeprefix("palette_recipe: ") for w in warnings]


def saved_kinds():
    """{kind: (strict save, lenient read, folder)} of the saved settings (ticket E18), for the modules in use."""
    out = {}
    if look_settings:
        out["look"] = (look_settings.save, read_look, saved.folder(look_settings.DEFAULT_PATH, "look"))
    if palette_recipe:
        out["palette"] = (palette_recipe.save, read_recipe, saved.folder(palette_recipe.DEFAULT_PATH, "palette"))
    return out


def saved_names():
    kinds = saved_kinds()
    return {kind: saved.names(kinds[kind][2]) if kind in kinds else None for kind in ("look", "palette")}


def saved_list(kind, where):
    try:
        return {"type": "savedList", "kind": kind, "names": saved.names(where)}
    except OSError as e:
        return {"type": "savedList", "kind": kind, "error": str(e)}


def saved_message(msg):
    """saveAs, loadSaved, deleteSaved: the answer always comes, an error included; after a save or a delete the
    list follows."""
    type_, kind, name, kinds = msg["type"], msg.get("kind"), msg.get("name"), saved_kinds()
    answer = {"saveAs": "savedAs", "loadSaved": "savedLoaded", "deleteSaved": "savedList"}[type_]
    try:
        if kind not in kinds:
            raise ValueError(f"no {kind} module in the Ajmashell directory (see Settings)")
        write, read, where = kinds[kind]
        file = saved.path(where, name)
        name = saved.check_name(name)
        if type_ == "saveAs":
            if os.path.exists(file) and not msg.get("overwrite"):
                raise ValueError(f"{name!r} exists already")
            reply = {"data": write(msg.get("data"), file)}
        elif not os.path.isfile(file):
            raise ValueError(f"no saved {kind} {name!r}")
        elif type_ == "loadSaved":
            data, warnings = read(file)
            reply = {"data": data, "warnings": warnings}
        else:
            saved.delete(where, name)
            reply = None  # the list is the answer
    except Exception as e:  # noqa: BLE001  (any failure must reach the window, else it waits for the answer)
        send({"type": answer, "kind": kind, "name": name, "error": str(e) or type(e).__name__})
        return
    if reply is not None:
        send({"type": answer, "kind": kind, "name": name, **reply})
    if type_ != "loadSaved":
        send(saved_list(kind, where))


def look_state():
    """The Look tab's part of "ready": options, the look in the live file (defaults without it), the file, and
    Ajmashell's gradient drawing that the previews load (ticket 14; None for an Ajmashell without it)."""
    fill = os.path.join(PATHS["ajmashellDir"], "look", "GradientFill.qml")
    return {"options": look_settings.options(), "current": look_settings.load(), "file": look_settings.DEFAULT_PATH,
            "gradientFill": fill if os.path.isfile(fill) else None}


def matugen_warning():
    """None for matugen 4.2.x, else the text for the window (ticket 11). Other versions may build other palettes from
    the same flags; the tool still runs (no block), and without matugen only the computing stops."""
    try:
        r = subprocess.run(["matugen", "--version"], capture_output=True, text=True, timeout=10)
    except FileNotFoundError:
        return f"matugen not found: install matugen {TESTED_MATUGEN} (pacman -S matugen); no palette can be computed"
    except (OSError, subprocess.SubprocessError) as e:
        return f"matugen --version failed ({e}); {TESTED_NOTE}"
    found = re.search(r"\b(\d+)\.(\d+)\.\d+\b", r.stdout)
    if found and found.group(1, 2) == tuple(TESTED_MATUGEN.split(".")[:2]):
        return None
    version = f"matugen {found.group(0)}" if found else f"matugen of unknown version ({r.stdout.strip()!r})"
    return f"{version}: {TESTED_NOTE}"


def current_wallpaper():
    link = PATHS["currentWallpaper"]
    return os.path.realpath(link) if os.path.exists(link) else None


def load_look_module():
    """Import look_settings from the Ajmashell directory of the settings; None, or the reason it is missing. Apart from
    the palette: an Ajmashell from before ticket 13 still has its palette tuned."""
    global look_settings
    folder = os.path.join(PATHS["ajmashellDir"], "singletons", "look")
    if not os.path.isfile(os.path.join(folder, "look_settings.py")):
        return NO_LOOK_MODULE if os.path.isdir(PATHS["ajmashellDir"]) else None  # no directory: status() says it
    sys.path.insert(0, folder)
    try:
        look_settings = importlib.import_module("look_settings")
        look_settings.options()  # look-options.json next to it
    except Exception as e:  # noqa: BLE001  (a broken module of another version must not stop the window)
        look_settings = None
        return f"{folder}: the look module cannot be loaded ({type(e).__name__}: {e}); the Look tab is off"
    return None


def load_modules():
    """Import palette_recipe and indexer from the Ajmashell directory of the settings; None and the reason if not."""
    global palette_recipe, indexer
    folder = os.path.join(PATHS["ajmashellDir"], "wallpaper")
    if not all(os.path.isfile(os.path.join(folder, n)) for n in settings.RECIPE_MODULES):
        return None  # settings.status() already says what is missing
    sys.path.insert(0, folder)
    try:
        palette_recipe = importlib.import_module("palette_recipe")
        indexer = importlib.import_module("indexer")
    except Exception as e:  # noqa: BLE001  (a broken module of another version must not stop the window)
        palette_recipe = indexer = None
        return f"{folder}: the palette recipe module cannot be loaded ({type(e).__name__}: {e}); nothing is computed"
    return None


def restart():
    """New settings: the same process starts over (exec keeps the window's pipes), so every path and the recipe
    module are read again. Running matugen calls finish on their own; their results are dropped."""
    sys.stdout.flush()
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)])


def main():
    global PATHS
    PATHS, warning = settings.load()
    status = settings.status(PATHS)
    problems = [s["problem"] for s in status if s["problem"]]
    module_error = load_modules()
    if module_error:
        problems.append(module_error)
    look_error = load_look_module()
    if look_error:
        problems.append(look_error)
    os.makedirs(CACHE, exist_ok=True)
    items = load_items()
    current = current_wallpaper()
    recipe, recipe_warnings = system_recipe() if palette_recipe else (None, [])
    send({"type": "ready",
          "items": [{k: i[k] for k in ("fileName", "path", "thumb")} for i in items],
          "current": next((i["fileName"] for i in items if i["path"] == current), None),
          "recipe": recipe, "recipeWarnings": recipe_warnings, "fingerprint": palette_recipe.fingerprint(recipe) if recipe else None,
          "options": palette_recipe.options() if palette_recipe else None, "look": system_look(),
          "settings": status, "settingsFile": settings.default_file(), "settingsWarning": warning,
          "recipeFile": palette_recipe.DEFAULT_PATH if palette_recipe else None,
          "problems": problems, "matugenWarning": matugen_warning(),
          "lookSettings": look_state() if look_settings else None, "saved": saved_names()})
    queue = Queue(items)
    pool = ThreadPoolExecutor(max_workers=WORKERS)
    for _ in range(WORKERS):
        pool.submit(queue.work)
    saver = ThreadPoolExecutor(max_workers=1)  # in the background, one save after another
    for line in sys.stdin:
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if msg.get("type") == "compute" and palette_recipe:
            recipes = msg.get("recipes") or [None]
            orders = msg.get("orders") or []
            queue.request([validated(r) for r in recipes], [*orders, *[[]] * (len(recipes) - len(orders))])
        elif msg.get("type") == "save":
            saver.submit(save, msg.get("recipe"))
        elif msg.get("type") == "readRecipe" and palette_recipe:
            live, warnings = system_recipe()
            send({"type": "recipeRead", "recipe": live, "fingerprint": palette_recipe.fingerprint(live),
                  "recipeWarnings": warnings})
        elif msg.get("type") == "readLook" and look_settings:
            send({"type": "lookRead", "current": look_settings.load()})
        elif msg.get("type") == "saveLook":
            save_look(msg.get("look"))  # one small file: at once, not behind a palette save
        elif msg.get("type") in ("saveAs", "loadSaved", "deleteSaved"):
            saved_message(msg)  # small files: at once, like saveLook
        elif msg.get("type") == "check":
            try:
                send({"type": "checked", "settings": settings.status(settings.resolve(msg.get("paths") or {}))})
            except ValueError:
                pass  # the window only sends the keys it got in "ready"
        elif msg.get("type") == "settings":
            try:
                settings.save(msg.get("paths") or {})
            except (ValueError, OSError) as e:
                send({"type": "settingsSaved", "error": str(e)})
            else:
                restart()
    os._exit(0)  # window closed: drop the queue, do not wait for running matugen calls


if __name__ == "__main__":
    main()
