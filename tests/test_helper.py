# SPDX-License-Identifier: AGPL-3.0-or-later
# Tests of the helper's protocol (helper/tuner.py, JSON lines on stdin/stdout), run as the window runs it.
# Everything lives in a temporary directory: settings, cache, palette recipe file, wallpaper index and stand-in
# Ajmashell directories, each with a copy of the real palette_recipe.py (the recipe logic is Ajmashell's, never copied
# into this repo) whose DEFAULT_PATH points to a file in the temporary directory, and a stub indexer.py. Nothing here
# calls matugen: the index is empty, so no palette is computed.
# The real palette_recipe.py comes from $AJMASHELL_DIR or ~/.config/quickshell/ajmashell; without it the tests skip.
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest

HELPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "helper", "tuner.py")
RECIPE_MODULE = os.path.join(os.environ.get("AJMASHELL_DIR") or os.path.expanduser("~/.config/quickshell/ajmashell"),
                             "wallpaper", "palette_recipe.py")

# Stand-in indexer: the colour category the helper imports, and a run that leaves a trace for the save test
STUB_INDEXER = '''import os, sys
def color_bucket(hex_str):
    return "stub"
if __name__ == "__main__":
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "indexer-ran"), "w").close()
'''

VIBRANT = {"seed": {"rule": "darkness"},
           "palette": {"scheme": "scheme-vibrant", "contrast": 0.5, "lightnessDark": 0.0}}


@unittest.skipUnless(os.path.isfile(RECIPE_MODULE), f"no {RECIPE_MODULE}")
class Helper(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.recipe_file = self.path("palette-recipe.json")
        self.write(self.recipe_file, VIBRANT)
        self.shell = self.stand_in("ajmashell", self.recipe_file)
        self.index = self.path("index.json")
        self.write(self.index, {"items": []})
        self.settings = {"ajmashellDir": self.shell, "wallpaperIndex": self.index,
                         "currentWallpaper": self.path("current_wallpaper"), "kittyTemplate": self.path("kitty.conf"),
                         "looknfeel": self.path("looknfeel.lua"), "windowRules": self.path("rules.lua"),
                         "wpapply": self.path("wpapply.sh")}
        self.proc = None
        self.bin = self.path("bin")  # stand-in programs, first on PATH
        os.makedirs(self.bin)
        self.only_bin = False  # PATH = only self.bin (a program missing from the system)

    def tearDown(self):
        if self.proc:
            self.proc.kill()
            self.proc.wait()
            self.proc.stdin.close()
            self.proc.stdout.close()
        shutil.rmtree(self.tmp)

    def stand_in(self, name, recipe_file):
        """An Ajmashell directory whose palette_recipe.py reads and saves recipe_file. Without the DEFAULT_PATH line
        the test stops here: the copy would save into the real palette recipe file."""
        folder = self.path(name)
        os.makedirs(os.path.join(folder, "wallpaper"))
        with open(RECIPE_MODULE) as f:
            code, n = re.subn(r"^DEFAULT_PATH = .*$", f"DEFAULT_PATH = {recipe_file!r}", f.read(), flags=re.M)
        if n != 1:
            self.fail(f"{RECIPE_MODULE}: no single DEFAULT_PATH line to point at the temporary directory")
        with open(os.path.join(folder, "wallpaper", "palette_recipe.py"), "w") as f:
            f.write(code)
        with open(os.path.join(folder, "wallpaper", "indexer.py"), "w") as f:
            f.write(STUB_INDEXER)
        return folder

    def path(self, name):
        return os.path.join(self.tmp, name)

    def write(self, file, data):
        os.makedirs(os.path.dirname(file), exist_ok=True)
        with open(file, "w") as f:
            json.dump(data, f)

    def start(self):
        self.write(self.path("config/ajmashell-theme-center/settings.json"), self.settings)
        env = dict(os.environ, XDG_CONFIG_HOME=self.path("config"), XDG_CACHE_HOME=self.path("cache"),
                   PATH=self.bin if self.only_bin else self.bin + os.pathsep + os.environ.get("PATH", ""))
        self.proc = subprocess.Popen([sys.executable, HELPER], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, text=True, env=env)
        self.lines = queue.Queue()
        threading.Thread(target=lambda: [self.lines.put(json.loads(ln)) for ln in self.proc.stdout],
                         daemon=True).start()
        ready = self.expect("ready")
        # A helper that does not report its settings does not read them either: it would save into the real
        # palette recipe file and run the real indexer and wpapply.sh. Stop before any test sends anything.
        if "settings" not in ready:
            self.proc.kill()
            self.fail("the helper does not read settings.json; no message sent")
        return ready

    def stub_matugen(self, version_line):
        """A matugen on PATH that only answers --version."""
        stub = os.path.join(self.bin, "matugen")
        with open(stub, "w") as f:
            f.write(f"#!/bin/sh\necho '{version_line}'\n")
        os.chmod(stub, 0o755)

    def send(self, msg):
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()

    def expect(self, type_):
        """The next message of this type (others are skipped); fails after 10 s."""
        while True:
            try:
                msg = self.lines.get(timeout=10)
            except queue.Empty:
                self.fail(f"no {type_!r} message")
            if msg["type"] == type_:
                return msg

    def test_ready_reads_the_recipe_file_of_the_module(self):
        ready = self.start()
        self.assertEqual(ready["recipe"], VIBRANT)
        self.assertEqual(ready["recipeFile"], self.recipe_file)  # shown in the Settings panel
        self.assertEqual(ready["items"], [])
        self.assertIn("scheme-vibrant", ready["options"]["schemes"])

    def test_two_recipes_validated_by_the_module(self):
        self.start()
        wrong = {"seed": {"rule": "dominant"},
                 "palette": {"scheme": "scheme-content", "contrast": 5, "lightnessDark": 0.0}}
        self.send({"type": "compute", "recipes": [None, wrong], "orders": [[], []]})
        accepted = self.expect("accepted")
        self.assertEqual(accepted["recipes"][0], VIBRANT)  # null = the palette recipe file
        # contrast out of range: the module's starting value, the rest as given
        self.assertEqual(accepted["recipes"][1]["palette"], {"scheme": "scheme-content", "contrast": 0.0,
                                                             "lightnessDark": 0.0})
        self.assertEqual(len(set(accepted["fingerprints"])), 2)
        self.assertEqual(self.expect("progress")["total"], 0)

    def test_settings_and_missing_paths_in_ready(self):
        os.remove(self.index)
        ready = self.start()
        found = {s["key"]: s["found"] for s in ready["settings"]}
        self.assertTrue(found["ajmashellDir"])
        self.assertFalse(found["wallpaperIndex"])
        self.assertFalse(found["kittyTemplate"])
        self.assertIsNone(ready["settingsWarning"])
        self.assertTrue(any("Super + W" in p for p in ready["problems"]))
        self.assertTrue(any("kitty mock-up is off" in p for p in ready["problems"]))

    def test_missing_recipe_file_is_a_message_and_starting_values(self):
        os.remove(self.recipe_file)
        ready = self.start()
        self.assertEqual(ready["recipe"]["palette"]["scheme"], "scheme-tonal-spot")
        self.assertTrue(any(self.recipe_file in p and "starting values" in p for p in ready["problems"]))

    def test_missing_ajmashell_directory_is_a_message_not_a_crash(self):
        self.settings["ajmashellDir"] = self.path("nowhere")
        ready = self.start()
        self.assertIsNone(ready["recipe"])
        self.assertIsNone(ready["options"])
        self.assertTrue(any("Ajmashell directory" in p for p in ready["problems"]))
        self.send({"type": "compute", "recipes": [None, None], "orders": [[], []]})
        self.send({"type": "save", "recipe": VIBRANT})
        self.assertIn("Ajmashell directory", self.expect("saved")["error"])

    def test_matugen_other_than_4_2_is_a_warning(self):
        self.stub_matugen("matugen 4.3.0")
        warning = self.start()["matugenWarning"]
        self.assertIn("matugen 4.3.0", warning)
        self.assertIn("tested with matugen 4.2.0, results may differ", warning)

    def test_matugen_4_2_gives_no_warning(self):
        self.stub_matugen("matugen 4.2.7")
        self.assertIsNone(self.start()["matugenWarning"])

    def test_unrecognised_matugen_version_is_a_warning(self):
        self.stub_matugen("something else")
        self.assertIn("tested with matugen 4.2.0", self.start()["matugenWarning"])

    def test_missing_matugen_is_a_warning_not_a_crash(self):
        self.only_bin = True
        ready = self.start()
        self.assertIn("matugen not found", ready["matugenWarning"])
        self.assertEqual(ready["recipe"], VIBRANT)  # the rest still starts

    def test_broken_settings_file_gives_defaults_and_a_warning(self):
        self.start()
        self.proc.kill()
        self.proc.wait()
        with open(self.path("config/ajmashell-theme-center/settings.json"), "w") as f:
            f.write("{broken")
        env = dict(os.environ, XDG_CONFIG_HOME=self.path("config"), XDG_CACHE_HOME=self.path("cache"))
        out = subprocess.run([sys.executable, HELPER], input="", capture_output=True, text=True, env=env, timeout=30)
        ready = json.loads(out.stdout.splitlines()[0])
        self.assertIn("settings.json", ready["settingsWarning"])
        self.assertEqual(ready["settings"][0]["value"], os.path.expanduser("~/.config/quickshell/ajmashell"))

    def test_check_reports_paths_without_saving(self):
        self.start()
        self.send({"type": "check", "paths": {"ajmashellDir": self.path("nowhere"), "wallpaperIndex": ""}})
        checked = {s["key"]: s for s in self.expect("checked")["settings"]}
        self.assertFalse(checked["ajmashellDir"]["found"])
        # empty = the default path
        self.assertEqual(checked["wallpaperIndex"]["value"],
                         os.path.expanduser("~/.cache/ajmashell/wallpapers/index.json"))
        with open(self.path("config/ajmashell-theme-center/settings.json")) as f:
            self.assertEqual(json.load(f)["ajmashellDir"], self.shell)

    def test_new_settings_apply_without_restarting_the_window(self):
        self.start()
        pid = self.proc.pid
        other = self.path("other-recipe.json")
        self.write(other, {"seed": {"rule": "value"},
                           "palette": {"scheme": "scheme-fidelity", "contrast": 0.0, "lightnessDark": 0.0}})
        other_shell = self.stand_in("other-ajmashell", other)
        self.send({"type": "settings", "paths": dict(self.settings, ajmashellDir=other_shell)})
        ready = self.expect("ready")
        self.assertEqual(ready["recipe"]["palette"]["scheme"], "scheme-fidelity")
        self.assertEqual(self.proc.pid, pid)  # same process for the window: the helper restarted itself
        self.assertIsNone(self.proc.poll())
        with open(self.path("config/ajmashell-theme-center/settings.json")) as f:
            self.assertEqual(json.load(f)["ajmashellDir"], other_shell)

    def test_bad_settings_are_refused(self):
        self.start()
        self.send({"type": "settings", "paths": {"nope": "/x"}})
        self.assertIn("nope", self.expect("settingsSaved")["error"])

    def test_save_writes_the_recipe_file_and_runs_the_steps(self):
        wallpaper = self.path("wall.png")
        open(wallpaper, "w").close()
        os.symlink(wallpaper, self.settings["currentWallpaper"])
        trace = self.path("wpapply-arg")
        with open(self.settings["wpapply"], "w") as f:
            f.write(f'#!/bin/sh\nprintf %s "$1" > {trace}\n')
        os.chmod(self.settings["wpapply"], 0o755)
        self.start()
        trial = dict(VIBRANT, seed={"rule": "lightness"})
        self.send({"type": "save", "recipe": trial})
        self.assertEqual(self.expect("saved")["recipe"], trial)
        self.assertEqual(self.expect("apply")["stage"], "indexer")
        self.assertEqual(self.expect("apply")["stage"], "wallpaper")
        self.assertEqual(self.expect("apply")["stage"], "done")
        with open(self.recipe_file) as f:
            self.assertEqual(json.load(f), trial)
        self.assertTrue(os.path.exists(os.path.join(self.shell, "wallpaper", "indexer-ran")))
        with open(trace) as f:
            self.assertEqual(f.read(), wallpaper)


if __name__ == "__main__":
    unittest.main()
