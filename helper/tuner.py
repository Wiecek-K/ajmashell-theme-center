#!/usr/bin/env python3
# Helper of Ajmashell Theme Center, palette tuning (faza E, ADR 0019): computes, with the real matugen, the palette the
# system would give each carousel wallpaper for a given palette recipe. Long-lived; talks to the QML window by JSON
# messages, one per line. The recipe logic (validation, matugen flags, fingerprint) and the colour categories are
# imported from the dotfiles by path, never copied, so the tool shows exactly what wpapply.sh and the carousel
# indexer would do.
#
# Window -> helper (stdin):
#   {"type": "compute", "recipes": [{...} | null, ...], "orders": [[fileName, ...], ...]}
#       recipes = current recipe and trial recipe (null = the system palette recipe file); orders[i] = wallpapers to
#       compute for recipes[i], the selected one first (the trial gets only the selected one until the user asks for
#       all).
#       Jobs run wallpaper by wallpaper in the order of the longest list. A new request replaces the queue of the
#       previous one: jobs it no longer names are dropped, the rest follow the new order.
#   {"type": "save", "recipe": {...}}
#       write the recipe as the system palette recipe (palette_recipe.save: strict validation, atomic, no commit), then
#       in the background the carousel indexer and wpapply.sh on the current wallpaper (ticket 07). Saves run one at
#       a time.
# Helper -> window (stdout):
#   {"type": "ready", "items": [{fileName, path, thumb}], "current": fileName | null, "recipe": {...}, "fingerprint",
#    "options": {rules, schemes, contrast: [lo, hi], lightnessDark: [lo, hi]},   (palette_recipe.options())
#    "look": {"kitty": {key: token}, "border": [token], "borderAngle": deg, "kittyOpacity": a, "problems": [text]}}
#       (system_look(): what the mock-ups read from the system's own files, see there)
#   {"type": "accepted", "recipes": [{...}], "fingerprints": [fp]}   (validated, in the order of the request)
#   {"type": "result", "fingerprint", "fileName", "candidates": [hex], "seed": hex, "category", "colors": {token: hex}}
#   {"type": "error", "fingerprint", "fileName", "message"}
#   {"type": "progress", "fingerprint", "done": n, "total": n}   (per recipe; total = all wallpapers)
#   {"type": "saved", "recipe": {...}, "fingerprint"} | {"type": "saved", "error": text}   (file written or not)
#   {"type": "apply", "stage": "indexer" | "wallpaper" | "done"} | {"type": "apply", "stage": "error", "message"}
#
# Results are cached per (wallpaper path, mtime, size, recipe fingerprint) in ~/.cache/ajmashell-theme-center, so a
# second start is instant. At most half the cores, like the indexer (the CPU is this machine's bottleneck).

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser("~")
DOTFILES_WALLPAPER = os.path.join(HOME, ".config/quickshell/ajmashell/wallpaper")  # palette_recipe.py, indexer.py
INDEX = os.path.join(HOME, ".cache/ajmashell/wallpapers/index.json")
CURRENT = os.path.join(HOME, ".config/hypr/current_wallpaper")
CACHE = os.path.join(HOME, ".cache/ajmashell-theme-center/results")
KITTY_TEMPLATE = os.path.join(HOME, ".config/matugen/templates/kitty-colors.conf")
LOOKNFEEL = os.path.join(HOME, ".config/hypr/configs/looknfeel.lua")
RULES = os.path.join(HOME, ".config/hypr/configs/rules.lua")
INDEXER = os.path.join(DOTFILES_WALLPAPER, "indexer.py")
WPAPPLY = os.path.join(HOME, ".config/hypr/scripts/wpapply.sh")
WORKERS = max(1, (os.cpu_count() or 2) // 2)

sys.dont_write_bytecode = True  # no __pycache__ in the dotfiles
sys.path.insert(0, DOTFILES_WALLPAPER)
import indexer  # noqa: E402  (color_bucket: the carousel's own thresholds = the colour category)
import palette_recipe  # noqa: E402

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
    A file or line that cannot be read lands in `problems` (shown in the window); the mock-up then uses its
    fallback from Mockups.js. The Ajmashell colours (Bar, popup) are QML bindings and stay mapped in Mockups.js."""
    look = {"kitty": {}, "border": [], "borderAngle": 0, "kittyOpacity": None, "problems": []}

    def read(path):
        try:
            with open(path, encoding="utf-8") as f:
                return f.read()
        except OSError as e:
            look["problems"].append(f"{path}: {e.strerror}")
            return ""

    for m in re.finditer(r"^\s*(\w+)\s+\{\{\s*colors\.(\w+)\.default\.hex\s*\}\}", read(KITTY_TEMPLATE), re.M):
        look["kitty"][m.group(1)] = m.group(2)
    if not look["kitty"]:
        look["problems"].append(f"{KITTY_TEMPLATE}: no colour lines")
    m = re.search(r"active_border\s*=\s*\{\s*colors\s*=\s*\{([^}]*)\}\s*,\s*angle\s*=\s*(-?\d+)", read(LOOKNFEEL))
    if m:
        look["border"] = re.findall(r"c\.(\w+)", m.group(1))
        look["borderAngle"] = int(m.group(2))
    if not look["border"]:
        look["problems"].append(f"{LOOKNFEEL}: active_border not recognised")
    m = re.search(r'class\s*=\s*"\^\(kitty\)\$"[^\n]*opacity\s*=\s*"([0-9.]+)', read(RULES))
    if m:
        look["kittyOpacity"] = float(m.group(1))
    else:
        look["problems"].append(f"{RULES}: kitty window rule (opacity) not recognised")
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
        with open(INDEX) as f:
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
    try:
        valid = palette_recipe.save(recipe)
        fingerprint = palette_recipe.fingerprint(valid)
    except Exception as e:  # noqa: BLE001  (any failure must reach the window, else it waits for "saved" forever)
        send({"type": "saved", "error": str(e) or type(e).__name__})
        return
    send({"type": "saved", "recipe": valid, "fingerprint": fingerprint})
    send({"type": "apply", "stage": "indexer"})
    err = run_step(["python3", INDEXER])
    if err is None:
        current = os.path.realpath(CURRENT) if os.path.exists(CURRENT) else None
        if current is None:
            err = f"{CURRENT}: no current wallpaper"
        else:
            send({"type": "apply", "stage": "wallpaper"})
            err = run_step([WPAPPLY, current])
    send({"type": "apply", "stage": "error", "message": err} if err else {"type": "apply", "stage": "done"})


def main():
    os.makedirs(CACHE, exist_ok=True)
    items = load_items()
    current = os.path.realpath(CURRENT) if os.path.exists(CURRENT) else None
    recipe = palette_recipe.load()
    send({"type": "ready",
          "items": [{k: i[k] for k in ("fileName", "path", "thumb")} for i in items],
          "current": next((i["fileName"] for i in items if i["path"] == current), None),
          "recipe": recipe, "fingerprint": palette_recipe.fingerprint(recipe), "options": palette_recipe.options(), "look": system_look()})
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
        if msg.get("type") == "compute":
            recipes = msg.get("recipes") or [None]
            orders = msg.get("orders") or []
            queue.request([validated(r) for r in recipes], [*orders, *[[]] * (len(recipes) - len(orders))])
        elif msg.get("type") == "save":
            saver.submit(save, msg.get("recipe"))
    os._exit(0)  # window closed: drop the queue, do not wait for running matugen calls


if __name__ == "__main__":
    main()
