# The kid theme collection (`share/themes-kids/`)

Fifteen kid-friendly themes, adapted by **OldJobobo** for Omarchy and offered upstream in
[omacom/omarchy#12488](https://github.com/omacom/omarchy/pull/12488). Each theme keeps its own
permission and credit record: read that theme's `ATTRIBUTION.md`, `CREDITS.md` and `README.md`.

| Theme | Ages (upstream label) |
| --- | --- |
| `cozy-night`, `paper-harbor`, `weather-parade`, `lantern-menagerie` | 5–7 |
| `far-horizon`, `small-wonders` | 5–8 |
| `dino-dawn`, `tidepool-workshop`, `fossil-field-notes`, `festival-loom` | 8–10 |
| `pocket-arcade` | 9–12 |
| `kinetic-zine`, `signal-garden`, `night-transit`, `bubblegum` | 11–12 |

## What ships, and what does not

Each theme here carries its **config** (`colors.toml`, `<theme>-base24.yaml`, `shell.toml`,
`hyprland.lua`, `icons.theme`, `unlock.png`, and `btop.theme`/`chromium.theme` where the theme
had them) and **one compressed wallpaper** (`backgrounds/*.webp`, the theme's first, downscaled
to 2560px and re-encoded). The upstream collection's remaining wallpapers and its multi-megabyte
`preview.png` are **not** shipped: the full set is ~393 MB, which has no place in the package.
The task's own note says the same (`docs/loop-report.md`, 2026-09-24 dogfood triage). The
wallpapers are the theme authors' / creators' art; a fuller set is an optional download, not a
build dependency.

## How the rest of the package sees it

`lib/theme.sh` lists two roots in `theme_list_installed` — `$OMARCHY_PATH/themes` (Omarchy's,
`/usr/share/omarchy/themes`) and `$KIDS_THEMES_DIR` (ours, installed to
`/usr/share/omarchy-kids/themes-kids`) — de-duplicated by name, so an upstream theme of the same
name wins. `theme_apply_for` resolves a name from either root. The wizard and panel Desktop
screens offer whatever the two roots list, so these themes appear with no further wiring.

Themes are presentation, not a lock: `theme_apply_for` copies the chosen theme into the kid's own
`~/.local/state/omarchy/current/theme` as root, and the `theme:<account>` assert lock re-applies it
on drift (`docs/theming.md`). Bundling these themes does not change who may switch a kid's theme.

## Provenance (T47)

The configs are OldJobobo's kids adaptation, contributed under the Omarchy PR above. Several
themes' wallpapers are the work of other creators (for example `dino-dawn` adapts **NobleDoodle**'s
Primeval Dawn with permission), credited per theme. No theme here states a blanket redistribution
licence in its own README, so this collection stays in-repo for the owner to decide its final
licence and, if any wallpaper's terms are unclear, drop that wallpaper before a public release.
