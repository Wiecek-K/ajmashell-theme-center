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
- Keys: `↑` `↓` (and `←` `→`) change the wallpaper, `Home` / `End` the first / last one. A click on a swatch copies its hex.
- The controls (panel on the right) change the trial recipe: seed choice, scheme, contrast, dark palette lightness.
  Their lists and ranges come from `palette_recipe.options()`; the dark lightness has no lower limit in matugen (−∞),
  so its slider starts at −1. A request goes to the helper after 300 ms without changes (debounce). The trial is
  computed for the selected wallpaper only (and for each one you select later); "compute all wallpapers" computes the
  rest of the folder. "restore current" goes back to the system palette recipe file. Strip: "seed" / "palette" = what
  the trial changes on that wallpaper; the second dot is the trial seed.
- "save as system recipe" writes the trial through `palette_recipe.save()` (atomic, no commit), then runs `indexer.py`
  and `wpapply.sh` on the current wallpaper in the background; the steps show under the button. The saved recipe
  becomes the current one.

## Layout

| File | Role |
|---|---|
| `shell.qml` | window state and the protocol with the helper; `//@ pragma AppId` gives the window class `ajmashell-theme-center` |
| `Strip.qml`, `WallpaperView.qml`, `TokenTable.qml`, `SidePanel.qml` (with `Chip.qml`, `TrialSlider.qml`) | layout of variant D of the prototype (branch `prototype/faza-e-karta-ui`): strip on the left, preview with the candidates and the token table in the middle, panel on the right |
| `Previews.qml` (with `DesktopMock.qml`, `KittyMock.qml`) | desktop (Bar + control centre) and kitty mock-ups for the current and the trial recipe side by side; next to the table when the window is wide (table in two columns + at least 420 px), otherwise under the candidates |
| `Mockups.js` | the one place that maps tokens to parts of the mock-ups, with a note on where each comes from (roles of the Ajmashell `Theme.qml` in the look `fancy2`; kitty and the border from the system's files, see below) |
| `helper/tuner.py` | the helper: real matugen, the recipe module and the colour categories from the dotfiles (imported by path, not copied) |

The protocol (JSON, one message per line) is described in the header of `helper/tuner.py`.
Result cache: `~/.cache/ajmashell-theme-center/results` (key: wallpaper path, mtime, size, recipe fingerprint); safe to
delete at any time. Delete it after a matugen update (the fingerprint does not cover the matugen version).

The texts of the desktop mock-up (control centre, volume, …) copy the real Ajmashell, whose interface is Polish, so
they stay Polish. Everything else in the window is English.

## Dependencies on the dotfiles (ADR 0019, consequences)

A change of these paths in Ajmashell breaks the tool without a warning:

- `~/.config/quickshell/ajmashell/wallpaper/palette_recipe.py` (`load`, `save`, `seed_flags`, `palette_flags`,
  `fingerprint`, `options`) and `indexer.py` (`color_bucket`, the colour category),
- `~/.config/matugen/przepis-palety.json` (the system palette recipe; written through `palette_recipe.save`; renamed to
  `palette-recipe.json` in ticket 10),
- `~/.config/hypr/scripts/wpapply.sh` (applies the palette after a save; `indexer.py` runs too),
- `~/.cache/ajmashell/wallpapers/index.json` (wallpaper list and thumbnails),
- `~/.config/hypr/current_wallpaper` (the current wallpaper),
- the mock-ups read on start (`system_look()` in the helper): the template `~/.config/matugen/templates/kitty-colors.conf`
  (lines `key {{ colors.TOKEN.default.hex }}`), `active_border` from `~/.config/hypr/configs/looknfeel.lua` and the
  opacity of the kitty window rule from `~/.config/hypr/configs/rules.lua`. Whatever it cannot recognise shows in red
  above the mock-ups, and a missing colour is grey. The Ajmashell roles (Bar islands, control centre) are copied by
  hand into `Mockups.js`: after a change of `Theme.qml`, fix them there,
- the window rule `theme-center-opaque` (class `ajmashell-theme-center`) in `~/.config/hypr/configs/rules.lua`
  (`opacity 1.0 override`).

The palette is computed as in the system: the seed from the thumbnail with the recipe's flags (as the indexer), the
palette from the seed through `matugen color hex` with the palette flags (as `wpapply.sh`), dark mode. For the current
wallpaper the result equals `~/.local/state/ajmashell/colors.json` (checked 2026-10-20, 50 tokens).

## Tests

No automated tests yet (user decision 2026-10-20; helper tests come with ticket 09). Checked by screenshots of the
window in full screen 2560×1440 and tiled on half the screen, the window found by PID (rule from the migration
project's `CLAUDE.md`).
