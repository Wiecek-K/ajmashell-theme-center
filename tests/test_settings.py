# SPDX-License-Identifier: AGPL-3.0-or-later
# Tests of helper/settings.py: the paths the tool needs, read from settings.json (defaults, own values, a missing
# or broken file) and whether each one is found.
import json
import os
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "helper"))
import settings  # noqa: E402

HOME = os.path.expanduser("~")


class Load(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.file = os.path.join(self.dir.name, "settings.json")

    def tearDown(self):
        self.dir.cleanup()

    def write(self, text):
        with open(self.file, "w") as f:
            f.write(text)

    def test_no_file_gives_the_dotfiles_paths(self):
        paths, warning = settings.load(self.file)
        self.assertIsNone(warning)
        self.assertEqual(paths["ajmashellDir"], os.path.join(HOME, ".config/quickshell/ajmashell"))
        self.assertEqual(paths["wallpaperIndex"], os.path.join(HOME, ".cache/ajmashell/wallpapers/index.json"))
        self.assertEqual(paths["wpapply"], os.path.join(HOME, ".config/hypr/scripts/wpapply.sh"))

    def test_own_value_replaces_the_default_and_tilde_expands(self):
        self.write(json.dumps({"ajmashellDir": "~/elsewhere/ajmashell"}))
        paths, warning = settings.load(self.file)
        self.assertIsNone(warning)
        self.assertEqual(paths["ajmashellDir"], os.path.join(HOME, "elsewhere/ajmashell"))
        self.assertEqual(paths["currentWallpaper"], os.path.join(HOME, ".config/hypr/current_wallpaper"))

    def test_broken_file_gives_defaults_and_a_warning(self):
        self.write("{not json")
        paths, warning = settings.load(self.file)
        self.assertIn(self.file, warning)
        self.assertEqual(paths["ajmashellDir"], os.path.join(HOME, ".config/quickshell/ajmashell"))

    def test_wrong_value_type_falls_back_for_that_path_only(self):
        self.write(json.dumps({"ajmashellDir": 5, "wpapply": "/opt/wpapply.sh", "unknown": "/x"}))
        paths, warning = settings.load(self.file)
        self.assertIn("ajmashellDir", warning)
        self.assertEqual(paths["ajmashellDir"], os.path.join(HOME, ".config/quickshell/ajmashell"))
        self.assertEqual(paths["wpapply"], "/opt/wpapply.sh")


class Save(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.file = os.path.join(self.dir.name, "sub", "settings.json")

    def tearDown(self):
        self.dir.cleanup()

    def test_saved_values_load_back_and_only_changes_are_stored(self):
        settings.save({"ajmashellDir": "/opt/ajmashell", "wpapply": settings.DEFAULTS["wpapply"]}, self.file)
        with open(self.file) as f:
            self.assertEqual(json.load(f), {"ajmashellDir": "/opt/ajmashell"})
        paths, _ = settings.load(self.file)
        self.assertEqual(paths["ajmashellDir"], "/opt/ajmashell")

    def test_empty_value_means_the_default(self):
        settings.save({"ajmashellDir": "  "}, self.file)
        with open(self.file) as f:
            self.assertEqual(json.load(f), {})

    def test_unknown_key_is_refused_and_the_file_stays(self):
        settings.save({"wpapply": "/a"}, self.file)
        with self.assertRaises(ValueError):
            settings.save({"nope": "/b"}, self.file)
        with open(self.file) as f:
            self.assertEqual(json.load(f), {"wpapply": "/a"})
        self.assertEqual(os.listdir(os.path.dirname(self.file)), ["settings.json"])  # no temporary file left


class Status(unittest.TestCase):
    def test_found_and_missing(self):
        with tempfile.TemporaryDirectory() as d:
            shell = os.path.join(d, "ajmashell")
            os.makedirs(os.path.join(shell, "wallpaper"))
            for name in ("palette_recipe.py", "indexer.py"):
                open(os.path.join(shell, "wallpaper", name), "w").close()
            index = os.path.join(d, "index.json")
            open(index, "w").close()
            paths = settings.resolve({"ajmashellDir": shell, "wallpaperIndex": index,
                                      "currentWallpaper": os.path.join(d, "missing")})
            st = {s["key"]: s for s in settings.status(paths)}
            self.assertTrue(st["ajmashellDir"]["found"])
            self.assertTrue(st["wallpaperIndex"]["found"])
            self.assertFalse(st["currentWallpaper"]["found"])
            self.assertEqual(st["currentWallpaper"]["default"], "~/.config/hypr/current_wallpaper")
            self.assertEqual(st["ajmashellDir"]["own"], shell)
            self.assertEqual(st["wpapply"]["own"], "")  # the default: an empty field
            self.assertEqual([s["key"] for s in settings.status(paths)], list(settings.DEFAULTS))

    def test_a_directory_without_the_recipe_module_is_missing(self):
        with tempfile.TemporaryDirectory() as d:
            st = {s["key"]: s for s in settings.status(dict(settings.DEFAULTS, ajmashellDir=d))}
            self.assertFalse(st["ajmashellDir"]["found"])
            self.assertIn("palette_recipe.py", st["ajmashellDir"]["problem"])


if __name__ == "__main__":
    unittest.main()
