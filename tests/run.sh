#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# All helper tests (ticket 09): tests/test_settings.py and tests/test_helper.py. The QML window has no automated
# tests. test_helper.py needs the palette recipe module of an Ajmashell install ($AJMASHELL_DIR, default
# ~/.config/quickshell/ajmashell) and skips without it; nothing touches the real files of the install.
cd "$(dirname "$0")/.." && exec python3 -B -m unittest discover -s tests "$@"
