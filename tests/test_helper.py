# SPDX-License-Identifier: AGPL-3.0-or-later
# Tests of the helper's protocol (helper/tuner.py, JSON lines on stdin/stdout), run as the window runs it.
# Everything lives in a temporary directory: settings, cache, palette recipe file, wallpaper index and stand-in
# Ajmashell directories, each with a copy of the real palette_recipe.py (the recipe logic is Ajmashell's, never copied
# into this repo) whose DEFAULT_PATH (the live file) points to a file in the temporary directory, next to it a default
# recipe (NEUTRAL, so a test sees which file was read; Ajmashell ticket E15), and a stub indexer.py. Nothing here
# calls matugen: the index is empty, so no palette is computed.
# The same for the look (ticket 13): a copy of the real look_settings.py and look-options.json, its DEFAULT_PATH (the
# live file) in the temporary directory.
# The real modules come from $AJMASHELL_DIR or ~/.config/quickshell/ajmashell; without them the tests skip.
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
AJMASHELL = os.environ.get("AJMASHELL_DIR") or os.path.expanduser("~/.config/quickshell/ajmashell")
RECIPE_MODULE = os.path.join(AJMASHELL, "wallpaper", "palette_recipe.py")
LOOK_MODULE = os.path.join(AJMASHELL, "singletons", "look", "look_settings.py")

# Stand-in indexer: the colour category the helper imports, and a run that leaves a trace for the save test
STUB_INDEXER = '''import os, sys
def color_bucket(hex_str):
    return "stub"
if __name__ == "__main__":
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "indexer-ran"), "w").close()
'''

VIBRANT = {"seed": {"rule": "darkness"},
           "palette": {"scheme": "scheme-vibrant", "contrast": 0.5, "lightnessDark": 0.0}}
# the default recipe of the stand-in Ajmashell directories (palette-recipe-default.json)
NEUTRAL = {"seed": {"rule": "value"},
           "palette": {"scheme": "scheme-neutral", "contrast": 0.0, "lightnessDark": 0.0}}


# a look other than the defaults (fancy2), so a test sees the file was read
# (and a gradient other than the defaults, ticket 14)
GRADIENT = {"style": "linear", "a": "primary", "b": "tertiary_container", "strength": 0.4, "angle": 90, "reachA": 0.6,
            "reachB": 0.5}
STILL = {"background": "on_primary_fixed", "alpha": 0.9, "motion": False, "flare": True, "glass": True,
         "softPills": True, "blur": False, "gradient": GRADIENT}


@unittest.skipUnless(os.path.isfile(RECIPE_MODULE) and os.path.isfile(LOOK_MODULE), f"no {RECIPE_MODULE} or {LOOK_MODULE}")
class Helper(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.recipe_file = self.path("palette-recipe.json")
        self.write(self.recipe_file, VIBRANT)
        self.look_file = self.path("state/look.json")
        self.write(self.look_file, STILL)
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
        self.write(os.path.join(folder, "wallpaper", "palette-recipe-default.json"), NEUTRAL)
        with open(os.path.join(folder, "wallpaper", "indexer.py"), "w") as f:
            f.write(STUB_INDEXER)
        look_dir = os.path.join(folder, "singletons", "look")
        os.makedirs(look_dir)
        shutil.copy(os.path.join(os.path.dirname(LOOK_MODULE), "look-options.json"), look_dir)
        with open(LOOK_MODULE) as f:
            code, n = re.subn(r"^DEFAULT_PATH = .*$", f"DEFAULT_PATH = {self.look_file!r}", f.read(), flags=re.M)
        if n != 1:
            self.fail(f"{LOOK_MODULE}: no single DEFAULT_PATH line to point at the temporary directory")
        with open(os.path.join(look_dir, "look_settings.py"), "w") as f:
            f.write(code)
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

    def test_missing_live_recipe_file_gives_the_default_recipe_without_a_message(self):
        # no live file is normal: Ajmashell uses its default recipe (ticket E15)
        os.remove(self.recipe_file)
        ready = self.start()
        self.assertEqual(ready["recipe"], NEUTRAL)
        self.assertFalse(any(self.recipe_file in p for p in ready["problems"]), ready["problems"])

    def test_bad_field_of_the_live_recipe_is_a_warning_in_the_window(self):
        self.write(self.recipe_file, {"palette": {"scheme": "scheme-vibrnat"}})
        ready = self.start()
        self.assertEqual(ready["recipe"], NEUTRAL)  # the default recipe's value
        self.assertTrue(any("palette.scheme" in w for w in ready["recipeWarnings"]), ready["recipeWarnings"])
        self.write(self.recipe_file, VIBRANT)  # fixed by hand: the warning goes
        self.send({"type": "readRecipe"})
        self.assertEqual(self.expect("recipeRead")["recipeWarnings"], [])

    def test_read_recipe_follows_a_change_made_outside_the_tool(self):
        self.assertEqual(self.start()["recipe"], VIBRANT)
        os.remove(self.recipe_file)  # deleted by hand: the system is on the default recipe now
        self.send({"type": "readRecipe"})
        read = self.expect("recipeRead")
        self.assertEqual(read["recipe"], NEUTRAL)
        self.assertEqual(len(read["fingerprint"]), 16)

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

    def test_ready_has_the_look_and_its_options(self):
        look = self.start()["lookSettings"]
        self.assertEqual(look["current"], STILL)
        self.assertEqual(look["file"], self.look_file)
        self.assertEqual(list(look["options"]["presets"]), ["basic", "fancy", "fancy2", "still"])
        self.assertIn("on_primary_fixed", look["options"]["roles"])

    def test_no_live_file_gives_the_defaults(self):
        os.remove(self.look_file)
        look = self.start()["lookSettings"]
        self.assertEqual(look["current"], look["options"]["defaults"])

    def test_ready_names_the_gradient_drawing_of_ajmashell(self):
        fill = os.path.join(self.shell, "look", "GradientFill.qml")
        os.makedirs(os.path.dirname(fill))
        open(fill, "w").close()
        self.assertEqual(self.start()["lookSettings"]["gradientFill"], fill)

    def test_an_ajmashell_from_before_ticket_14_has_no_gradient_drawing(self):
        self.assertIsNone(self.start()["lookSettings"]["gradientFill"])

    def test_ajmashell_without_the_look_module_is_a_message_not_a_crash(self):
        os.remove(os.path.join(self.shell, "singletons", "look", "look_settings.py"))
        ready = self.start()
        self.assertIsNone(ready["lookSettings"])
        self.assertIsNotNone(ready["recipe"])  # the palette still works
        self.assertTrue(any("look" in p for p in ready["problems"]))
        self.send({"type": "saveLook", "look": STILL})
        self.assertIn("look", self.expect("lookSaved")["error"])

    def test_save_look_writes_the_live_file(self):
        self.start()
        basic = {"background": "surface_container", "alpha": 0.8, "motion": False, "flare": False, "glass": False,
                 "softPills": False, "blur": True, "gradient": dict(GRADIENT, style="corner", reachB=0.25)}
        self.send({"type": "saveLook", "look": basic})
        self.assertEqual(self.expect("lookSaved")["look"], basic)
        with open(self.look_file) as f:
            self.assertEqual(json.load(f), basic)

    def test_a_bad_look_is_refused_and_the_file_stays(self):
        self.start()
        self.send({"type": "saveLook", "look": dict(STILL, alpha=0.2)})
        self.assertIn("alpha", self.expect("lookSaved")["error"])
        with open(self.look_file) as f:
            self.assertEqual(json.load(f), STILL)

    def test_read_look_follows_a_change_made_outside_the_tool(self):
        defaults = self.start()["lookSettings"]["options"]["defaults"]
        os.remove(self.look_file)  # deleted by hand: Ajmashell is on its defaults now
        self.send({"type": "readLook"})
        self.assertEqual(self.expect("lookRead")["current"], defaults)

    # Saved settings (ticket E18): a look or a palette recipe under a name, next to the module's live file

    def restart_helper(self):
        """The window closed and opened again: a new helper, a new "ready"."""
        self.proc.kill()
        self.proc.wait()
        self.proc.stdin.close()
        self.proc.stdout.close()
        return self.start()

    def test_save_as_keeps_a_look_under_its_name_after_a_restart(self):
        self.assertEqual(self.start()["saved"], {"look": [], "palette": []})
        self.send({"type": "saveAs", "kind": "look", "name": "violet vignette", "data": STILL})
        self.assertEqual(self.expect("savedAs"), {"type": "savedAs", "kind": "look", "name": "violet vignette",
                                                  "data": STILL})
        self.assertEqual(self.expect("savedList")["names"], ["violet vignette"])
        with open(self.path("state/saved/look/violet vignette.json")) as f:
            self.assertEqual(json.load(f), STILL)
        with open(self.look_file) as f:
            self.assertEqual(json.load(f), STILL)  # the live file is not touched
        self.assertEqual(self.restart_helper()["saved"]["look"], ["violet vignette"])

    def test_an_existing_name_is_overwritten_only_when_asked(self):
        self.write(self.path("state/saved/look/mine.json"), STILL)
        self.start()
        other = dict(STILL, alpha=0.7)
        self.send({"type": "saveAs", "kind": "look", "name": "mine", "data": other})
        self.assertIn("exists", self.expect("savedAs")["error"])
        self.send({"type": "saveAs", "kind": "look", "name": "mine", "data": other, "overwrite": True})
        self.assertEqual(self.expect("savedAs")["data"], other)
        with open(self.path("state/saved/look/mine.json")) as f:
            self.assertEqual(json.load(f)["alpha"], 0.7)

    def test_a_bad_look_is_not_saved_under_a_name(self):
        self.start()
        self.send({"type": "saveAs", "kind": "look", "name": "mine", "data": dict(STILL, alpha=0.2)})
        self.assertIn("alpha", self.expect("savedAs")["error"])
        self.assertFalse(os.path.exists(self.path("state/saved/look/mine.json")))

    def test_a_name_that_is_no_file_name_is_refused(self):
        self.start()
        for name in ["", "   ", "../look", "a/b", ".hidden", "x" * 65, "tab\there"]:
            self.send({"type": "saveAs", "kind": "look", "name": name, "data": STILL})
            self.assertIn("error", self.expect("savedAs"), name)
        self.assertFalse(os.path.exists(self.path("state/look.json.json")))
        self.assertEqual(os.listdir(self.path("state")), ["look.json"])

    def test_the_list_leaves_out_files_no_name_gives_and_sorts_without_case(self):
        for f in ["b.json", "A.json", ".x.json", ".look.json.1a2b", "notes.txt"]:
            self.write(self.path("state/saved/look/" + f), STILL)
        self.assertEqual(self.start()["saved"]["look"], ["A", "b"])

    def test_a_saved_look_loads_leniently_like_the_live_file(self):
        defaults = self.start()["lookSettings"]["options"]["defaults"]
        old = {k: v for k, v in STILL.items() if k not in ("gradient", "blur")}  # before tickets 14 and the blur flag
        old["alpha"] = 3
        self.write(self.path("state/saved/look/old.json"), old)
        self.send({"type": "loadSaved", "kind": "look", "name": "old"})
        loaded = self.expect("savedLoaded")
        self.assertEqual(loaded["data"], dict(STILL, alpha=defaults["alpha"], blur=defaults["blur"],
                                              gradient=defaults["gradient"]))
        self.assertEqual(len(loaded["warnings"]), 1)
        self.assertIn("alpha", loaded["warnings"][0])

    def test_loading_a_missing_name_is_an_error(self):
        self.start()
        self.send({"type": "loadSaved", "kind": "look", "name": "gone"})
        self.assertIn("gone", self.expect("savedLoaded")["error"])

    def test_delete_removes_the_file_and_sends_the_list(self):
        self.write(self.path("state/saved/look/a.json"), STILL)
        self.write(self.path("state/saved/look/b.json"), STILL)
        self.start()
        self.send({"type": "deleteSaved", "kind": "look", "name": "a"})
        self.assertEqual(self.expect("savedList"), {"type": "savedList", "kind": "look", "names": ["b"]})
        self.send({"type": "deleteSaved", "kind": "look", "name": "a"})
        self.assertIn("error", self.expect("savedList"))

    def test_a_palette_recipe_is_saved_and_loaded_apart_from_the_look(self):
        self.start()
        self.send({"type": "saveAs", "kind": "palette", "name": "vibrant", "data": VIBRANT})
        self.assertEqual(self.expect("savedAs")["data"], VIBRANT)
        self.assertEqual(self.expect("savedList"), {"type": "savedList", "kind": "palette", "names": ["vibrant"]})
        self.assertTrue(os.path.isfile(self.path("saved/palette/vibrant.json")))  # next to the live recipe file
        # an older recipe without the dark lightness: the default recipe's value
        self.write(self.path("saved/palette/old.json"), {"seed": {"rule": "darkness"}, "palette": {"scheme": "scheme-vibrant"}})
        self.send({"type": "loadSaved", "kind": "palette", "name": "old"})
        self.assertEqual(self.expect("savedLoaded")["data"],
                         {"seed": {"rule": "darkness"},
                          "palette": dict(NEUTRAL["palette"], scheme="scheme-vibrant")})
        self.assertEqual(self.restart_helper()["saved"], {"look": [], "palette": ["old", "vibrant"]})

    def test_without_the_look_module_saved_looks_are_off_not_a_crash(self):
        os.remove(os.path.join(self.shell, "singletons", "look", "look_settings.py"))
        self.assertEqual(self.start()["saved"], {"look": None, "palette": []})
        self.send({"type": "saveAs", "kind": "look", "name": "mine", "data": STILL})
        self.assertIn("look", self.expect("savedAs")["error"])


if __name__ == "__main__":
    unittest.main()
