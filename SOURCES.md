# Ajmashell Theme Center: license and sources

Copyright (C) 2026 Wiecek-K

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [`LICENSE`](LICENSE) for the full
text of the GNU Affero General Public License, version 3.

Every source file starts with `SPDX-License-Identifier: AGPL-3.0-or-later`.

## Code copied from other projects

None. Every file of this repository is our own code.

## Code used at run time, not copied

| Source | License | How the tool uses it |
|---|---|---|
| [Ajmashell](https://github.com/Wiecek-K/arch-hyprland-ajmag) (`.config/quickshell/ajmashell`) | AGPL-3.0-or-later | the helper imports `wallpaper/palette_recipe.py` (the palette recipe: validation, matugen flags, fingerprint, save) and `wallpaper/indexer.py` (`color_bucket`, the colour category) from the Ajmashell directory of the settings, and runs `indexer.py` and `wpapply.sh` after a save. They stay in Ajmashell, so the tool computes exactly what the system does. Ajmashell's own sources: its `SOURCES.md` |
| [InioX/matugen](https://github.com/InioX/matugen) | GPL-2.0-only | run as a program (`matugen image`, `matugen color hex`): candidates, seed and palette. Tested with 4.2.0 |
| [Quickshell](https://git.outfoxxed.me/quickshell/quickshell) | LGPL-3.0-only | runs the window (`qs -c ajmashell-theme-center`) |

## Ideas only (own implementation)

| Source | Idea used in |
|---|---|
| Ajmashell (same author) | the desktop mock-up (`DesktopMock.qml`, `Mockups.js`) draws the Bar and the control centre with the roles of Ajmashell's `Theme.qml` (look `fancy2`), and copies their Polish texts; the kitty mock-up reads the system's matugen kitty template and Hyprland rules |
