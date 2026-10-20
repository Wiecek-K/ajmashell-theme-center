# Strojenie palety matugena

Prywatne narzędzie fazy E projektu migracji Hyprlanda (`~/Projects/hyprland-lua-migration`, ADR 0019, spec
`.scratch/faza-e/spec.md`). Okno Quickshell poza Ajmashellem i poza dotfiles; lokalny git bez remote.
Pokazuje dla każdej tapety karuzeli paletę, którą da system według Przepisu palety.

## Start

- Launcher: „Strojenie palety matugena” (`~/.local/share/applications/matugen-ajmashell-tool.desktop`,
  kopia w repo: `matugen-ajmashell-tool.desktop`; po zmianie: `install -Dm644 matugen-ajmashell-tool.desktop ~/.local/share/applications/`).
- Ręcznie: `qs -n -p ~/Projects/matugen-ajmashell-tool` (`-n`: drugie uruchomienie nie otwiera drugiego okna).
- Klawisze: `↑` `↓` (i `←` `→`) zmieniają tapetę, `Home` / `End` pierwsza / ostatnia. Klik w próbkę kopiuje hex.
- Kontrolki (panel z prawej) zmieniają Przepis próbny: reguła Seeda, schemat, kontrast, jasność palety ciemnej.
  Listy i zakresy z `palette_recipe.options()`; jasność ciemnej nie ma dolnej granicy w matugenie (−∞), suwak
  zaczyna się od −1. Żądanie idzie do pomocnika po 300 ms spokoju (debounce). Próba liczy się tylko dla wybranej
  tapety (i każdej, którą potem wybierzesz); resztę folderu liczy przycisk „przelicz wszystkie tapety”. „przywróć obecny” wraca do pliku
  Przepisu systemu. Taśma: „Seed” / „paleta” = co próba zmienia na tej tapecie; drugi punkt = Seed próbny.

## Budowa

| Plik | Rola |
|---|---|
| `shell.qml` | stan okna i protokół z pomocnikiem; `//@ pragma AppId` daje klasę okna `matugen-ajmashell-tool` |
| `Strip.qml`, `WallpaperView.qml`, `TokenTable.qml`, `SidePanel.qml` (z `Chip.qml`, `TrialSlider.qml`) | układ wariantu D z prototypu (gałąź `prototype/faza-e-karta-ui`): taśma z lewej, podgląd z Kandydatami i tabela w środku, panel z prawej |
| `helper/tuner.py` | pomocnik: prawdziwy matugen, moduł Przepisu i kategorie z dotfiles (import po ścieżce, bez kopii) |

Protokół (JSON, jeden komunikat w linii) opisany w nagłówku `helper/tuner.py`.
Cache wyników: `~/.cache/matugen-ajmashell-tool/results` (klucz: ścieżka, mtime, rozmiar tapety, odcisk Przepisu);
można go usunąć w każdej chwili. Po aktualizacji matugena usuń go (odcisk nie obejmuje wersji matugena).

## Zależności od dotfiles (ADR 0019, skutki)

Zmiana tych ścieżek w Ajmashellu psuje narzędzie bez ostrzeżenia:

- `~/.config/quickshell/ajmashell/wallpaper/palette_recipe.py` (`load`, `seed_flags`, `palette_flags`, `fingerprint`,
  `options`)
  i `indexer.py` (`color_bucket`),
- `~/.config/matugen/przepis-palety.json` (Przepis systemu),
- `~/.cache/ajmashell/wallpapers/index.json` (lista tapet i miniatury),
- `~/.config/hypr/current_wallpaper` (bieżąca tapeta),
- reguła okna `matugen-ajmashell-tool` w `~/.config/hypr/configs/rules.lua` (`opacity 1.0 override`).

Paleta liczona jak w systemie: Seed z miniatury flagami Przepisu (jak indexer), paleta z Seeda przez
`matugen color hex` z flagami palety (jak `wpapply.sh`), tryb ciemny. Dla bieżącej tapety wynik jest równy
`~/.local/state/ajmashell/colors.json` (sprawdzone 2026-10-20, 50 tokenów).

## Testy

Bez testów automatycznych (decyzja użytkownika 2026-10-20). Weryfikacja: zrzuty okna w pełnym ekranie 2560×1440
i w kafelku na pół ekranu, okno szukane po PID (reguła z `CLAUDE.md` projektu migracji).
