#!/usr/bin/env python3
# Helper of the palette tuning tool (faza E, ADR 0019): computes, with the real matugen, the palette the system would
# give each carousel wallpaper for a given Przepis palety. Long-lived; talks to the QML window by JSON messages, one
# per line. The Przepis logic (validation, matugen flags, fingerprint) and the colour buckets are imported from the
# dotfiles by path, never copied, so the tool shows exactly what wpapply.sh and the carousel indexer would do.
#
# Window -> helper (stdin):
#   {"type": "compute", "recipe": {...} | null, "order": [fileName, ...]}
#       recipe null = the system Przepis file. order = wallpapers to compute, the selected one first. A request with
#       another recipe drops the queue of the previous one; the same recipe only reorders what is still waiting.
# Helper -> window (stdout):
#   {"type": "ready", "items": [{fileName, path, thumb}], "current": fileName | null, "recipe": {...}, "fingerprint"}
#   {"type": "result", "fingerprint", "fileName", "candidates": [hex], "seed": hex, "bucket", "colors": {token: hex}}
#   {"type": "error", "fingerprint", "fileName", "message"}
#   {"type": "progress", "fingerprint", "done": n, "total": n}
#
# Results are cached per (wallpaper path, mtime, size, recipe fingerprint) in ~/.cache/matugen-ajmashell-tool, so a
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
CACHE = os.path.join(HOME, ".cache/matugen-ajmashell-tool/results")
WORKERS = max(1, (os.cpu_count() or 2) // 2)

sys.dont_write_bytecode = True  # no __pycache__ in the dotfiles
sys.path.insert(0, DOTFILES_WALLPAPER)
import indexer  # noqa: E402  (color_bucket: the carousel's own thresholds)
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


def compute(item, recipe):
    """Same steps as the system: the indexer picks the Seed from the thumbnail with the recipe's flags, wpapply.sh
    builds the palette from the Seed with `matugen color hex` and the palette flags (dark = the system's mode)."""
    thumb = item["thumb"]
    candidates = matugen(["image", "--show-source-colors", thumb]).split()
    seed_flags = palette_recipe.seed_flags(recipe)
    palette_flags = palette_recipe.palette_flags(recipe)
    img = json.loads(matugen(["image", "--dry-run", "-q", "-j", "hex", *seed_flags, *palette_flags, thumb]))
    seed = img["colors"]["source_color"]["dark"]["color"].lower()
    pal = json.loads(matugen(["color", "hex", seed, "--dry-run", "-q", "-j", "hex", *palette_flags]))
    colors = {k: v["dark"]["color"].lower() for k, v in sorted(pal["colors"].items())}
    return {"candidates": [c.lower() for c in candidates], "seed": seed,
            "bucket": indexer.color_bucket(colors["primary"]), "colors": colors}


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
    """Jobs of the newest request only. Workers take the first waiting job; a new recipe replaces the list."""

    def __init__(self, items):
        self.by_name = {i["fileName"]: i for i in items}
        self.cond = threading.Condition()
        self.waiting = []
        self.recipe = None
        self.fingerprint = None
        self.done = set()
        self.total = 0

    def request(self, recipe, order):
        fingerprint = palette_recipe.fingerprint(recipe)
        names = [n for n in order if n in self.by_name]
        with self.cond:
            if fingerprint == self.fingerprint:
                pending = set(self.waiting)
                self.waiting = [n for n in names if n in pending]
                return
            self.recipe, self.fingerprint = recipe, fingerprint
            self.done, self.total, self.waiting = set(), len(names), []
        misses = []
        for n in names:
            r = cached(self.by_name[n], fingerprint)
            if r is None:
                misses.append(n)
            else:
                self.finish(fingerprint, n, {"type": "result", "fingerprint": fingerprint, "fileName": n, **r})
        with self.cond:
            self.waiting = misses
            self.cond.notify_all()
        if not names:
            send({"type": "progress", "fingerprint": fingerprint, "done": 0, "total": 0})

    def finish(self, fingerprint, name, msg):
        send(msg)
        with self.cond:
            if fingerprint != self.fingerprint or name in self.done:
                return
            self.done.add(name)
            send({"type": "progress", "fingerprint": fingerprint, "done": len(self.done), "total": self.total})

    def take(self):
        with self.cond:
            while not self.waiting:
                self.cond.wait()
            return self.waiting.pop(0), self.recipe, self.fingerprint

    def work(self):
        while True:
            name, recipe, fingerprint = self.take()
            item = self.by_name[name]
            try:
                r = compute(item, recipe)
            except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as e:
                self.finish(fingerprint, name, {"type": "error", "fingerprint": fingerprint, "fileName": name,
                                                "message": str(e)})
                continue
            store(item, fingerprint, r)
            self.finish(fingerprint, name, {"type": "result", "fingerprint": fingerprint, "fileName": name, **r})


def main():
    os.makedirs(CACHE, exist_ok=True)
    items = load_items()
    current = os.path.realpath(CURRENT) if os.path.exists(CURRENT) else None
    recipe = palette_recipe.load()
    send({"type": "ready",
          "items": [{k: i[k] for k in ("fileName", "path", "thumb")} for i in items],
          "current": next((i["fileName"] for i in items if i["path"] == current), None),
          "recipe": recipe, "fingerprint": palette_recipe.fingerprint(recipe)})
    queue = Queue(items)
    pool = ThreadPoolExecutor(max_workers=WORKERS)
    for _ in range(WORKERS):
        pool.submit(queue.work)
    for line in sys.stdin:
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if msg.get("type") == "compute":
            queue.request(validated(msg.get("recipe")), msg.get("order") or [])
    os._exit(0)  # window closed: drop the queue, do not wait for running matugen calls


if __name__ == "__main__":
    main()
