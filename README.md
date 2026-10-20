# Ajmashell Theme Center

A Quickshell window for tuning the colours of Ajmashell. For every wallpaper of the Ajmashell carousel it shows the
palette the system gives it under the palette recipe, and lets you try another recipe before you save it as the
system one.

It needs Ajmashell: it reads the carousel index, imports the palette recipe module from the Ajmashell install and runs
its scripts after a save. There is no stand-alone mode.

Status: phase E of the Hyprland migration project (`~/Projects/hyprland-lua-migration`, ADR 0019, spec
`.scratch/faza-e/spec.md`). A local git repository without a remote for now; publishing and installing come with
ticket 11.

## Terms

| Term | Meaning |
|---|---|
| palette recipe | the settings that turn a wallpaper into a palette: how the seed is chosen and the matugen palette flags |
| current recipe | the system palette recipe file, as Ajmashell uses it now |
| trial recipe | a copy of the current recipe that the controls change; nothing in the system changes until you save it |
| candidate | one of the colours matugen finds in the wallpaper's thumbnail, most dominant first |
| seed | the candidate the recipe picks; matugen builds the whole palette from it |
| colour category | the carousel's colour filter for a wallpaper (from the indexer), taken from the palette's `primary` |

## Running it

- Launcher: "Ajmashell Theme Center" (`~/.local/share/applications/ajmashell-theme-center.desktop`, copy in this repo:
  `ajmashell-theme-center.desktop`; after a change: `install -Dm644 ajmashell-theme-center.desktop ~/.local/share/applications/`).
- By hand: `qs -n -p ~/Projects/ajmashell-theme-center` (`-n`: a second start does not open a second window).
- Keys: `↑` `↓` (and `←` `→`) change the wallpaper, `Home` / `End` the first / last one, `Ctrl+,` opens or closes
  Settings. A click on a swatch copies its hex.
- The controls (panel on the right) change the trial recipe: seed choice, scheme, contrast, dark palette lightness.
  Their lists and ranges come from `palette_recipe.options()`; the dark lightness has no lower limit in matugen (−∞),
  so its slider starts at −1. A request goes to the helper after 300 ms without changes (debounce). The trial is
  computed for the selected wallpaper only (and for each one you select later); "compute all wallpapers" computes the
  rest of the folder. "restore current" goes back to the system palette recipe file. Strip: "seed" / "palette" = what
  the trial changes on that wallpaper; the second dot is the trial seed.
- "save as system recipe" writes the trial through `palette_recipe.save()` (atomic, no commit), then runs `indexer.py`
  and `wpapply.sh` on the current wallpaper in the background; the steps show under the button. The saved recipe
  becomes the current one.
- "Settings" (top of the right panel) lists every path the tool reads, see "Settings" below.

## Layout

| File | Role |
|---|---|
| `shell.qml` | window state and the protocol with the helper; `//@ pragma AppId` gives the window class `ajmashell-theme-center` |
| `Strip.qml`, `WallpaperView.qml`, `TokenTable.qml`, `SidePanel.qml` (with `Chip.qml`, `TrialSlider.qml`) | layout of variant D of the prototype (branch `prototype/faza-e-karta-ui`): strip on the left, preview with the candidates and the token table in the middle, panel on the right |
| `Previews.qml` (with `DesktopMock.qml`, `KittyMock.qml`) | desktop (Bar + control centre) and kitty mock-ups for the current and the trial recipe side by side; next to the table when the window is wide (table in two columns + at least 420 px), otherwise under the candidates |
| `Mockups.js` | the one place that maps tokens to parts of the mock-ups, with a note on where each comes from (roles of the Ajmashell `Theme.qml` in the look `fancy2`; kitty and the border from the system's files, see below) |
| `SettingsPanel.qml` | the Settings panel: a field per path, its default, "found" / "missing" |
| `helper/tuner.py` | the helper: real matugen, the recipe module and the colour categories from the Ajmashell install (imported by path, not copied) |
| `helper/settings.py` | the paths: defaults (the one place they are written), `settings.json`, found / missing |
| `tests/` | helper tests, `tests/run.sh` |

The protocol (JSON, one message per line) is described in the header of `helper/tuner.py`.
Result cache: `~/.cache/ajmashell-theme-center/results` (`$XDG_CACHE_HOME` if set) (key: wallpaper path, mtime, size, recipe fingerprint); safe to
delete at any time. Delete it after a matugen update (the fingerprint does not cover the matugen version).

The texts of the desktop mock-up (control centre, volume, …) copy the real Ajmashell, whose interface is Polish, so
they stay Polish. Everything else in the window is English.

## Settings: the paths it needs

Every path comes from the Settings panel. The defaults are the paths of an Ajmashell install from the dotfiles, so
such an install needs no settings. Saved in `~/.config/ajmashell-theme-center/settings.json` (`$XDG_CONFIG_HOME` if
set), only the paths that differ from the default; no file = all defaults. A broken file gives the defaults and a
warning in the window. "apply" saves the file and restarts the helper (the window stays); "use default" empties a
field. While you type, each field shows "found" or "missing".

| Setting | Default | Without it |
|---|---|---|
| Ajmashell directory | `~/.config/quickshell/ajmashell` | needs `wallpaper/palette_recipe.py` (`load`, `save`, `seed_flags`, `palette_flags`, `fingerprint`, `options`) and `wallpaper/indexer.py` (`color_bucket`, the colour category; run after a save). Without them nothing is computed or saved |
| Palette recipe file | `~/.config/matugen/przepis-palety.json` | the starting values of the recipe are shown; a save creates the file. Renamed to `palette-recipe.json` in ticket 10 |
| Carousel wallpaper index | `~/.cache/ajmashell/wallpapers/index.json` | no wallpapers: open the wallpaper carousel (Super + W) once to build it |
| Current wallpaper link | `~/.config/hypr/current_wallpaper` | no wallpaper marked "on desktop"; a save cannot apply the palette |
| kitty colour template | `~/.config/matugen/templates/kitty-colors.conf` | the kitty mock-up is off (lines `key {{ colors.TOKEN.default.hex }}`) |
| Hyprland looknfeel.lua | `~/.config/hypr/configs/looknfeel.lua` | the window border of the kitty mock-up is grey (`active_border`) |
| Hyprland rules.lua | `~/.config/hypr/configs/rules.lua` | the kitty mock-up is opaque (opacity of the kitty window rule) |
| wpapply.sh | `~/.config/hypr/scripts/wpapply.sh` | a save writes the recipe file but does not apply it to the desktop |

Each missing path shows in red at the top of the right panel with what it stops; the rest of the tool works. A file
that is there but not recognised (template without colour lines, `active_border` in another form) shows in red above
the mock-ups. The Ajmashell roles (Bar islands, control centre) are copied by hand into `Mockups.js`: after a change
of `Theme.qml`, fix them there.

The palette recipe file setting tells the tool where to read and save the recipe. Ajmashell itself (`indexer.py`,
`wpapply.sh`) reads the path written in its `palette_recipe.py`, so set both to the same file.

The window rule `theme-center-opaque` (class `ajmashell-theme-center`, `opacity 1.0 override`) lives in the dotfiles
(`~/.config/hypr/configs/rules.lua`); without it the window is as transparent as other windows.

The palette is computed as in the system: the seed from the thumbnail with the recipe's flags (as the indexer), the
palette from the seed through `matugen color hex` with the palette flags (as `wpapply.sh`), dark mode. For the current
wallpaper the result equals `~/.local/state/ajmashell/colors.json` (checked 2026-10-20, 50 tokens).

## Tests

`tests/run.sh` runs every helper test (Python standard library, `unittest`):

- `tests/test_settings.py`: the settings: defaults, own paths, a broken file or value, atomic save, found / missing.
- `tests/test_helper.py`: the helper's protocol, run as the window runs it: the palette recipe file from the settings,
  two recipes in one request validated by the recipe module, the answers to `check` and `settings` (the helper
  restarts in the same process), missing paths as messages, a save with its steps. Everything runs in a temporary
  directory with a copy of the real `palette_recipe.py` (from `$AJMASHELL_DIR` or `~/.config/quickshell/ajmashell`;
  the tests skip without it) and stand-ins for `indexer.py` and `wpapply.sh`; matugen is not called. A helper that
  does not report its settings stops the test before any message, so a test never saves into the real recipe file.

The QML window has no automated tests: checked by hand, with screenshots of the window in full screen and tiled on
half the screen, the window found by PID (rule from the migration project's `CLAUDE.md`).
