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

Each theme here carries its **config only**: `colors.toml`, `<theme>-base24.yaml`, `shell.toml`,
`hyprland.lua`, `icons.theme`, `unlock.png`, and `btop.theme`/`chromium.theme` where the theme had
them. **No wallpapers ship.** The upstream collection's wallpapers are the theme authors' and other
creators' art, several with no stated redistribution licence (for example `pocket-arcade`'s first
wallpaper is credited fan art with no licence), and the full upstream set is ~393 MB. Shipping them
under this package's MIT licence was wrong, so they are not shipped; a fuller set is an optional
download the parent arranges, not a build dependency. Each theme's own `README.md`/`ATTRIBUTION.md`
still describes its upstream wallpapers, which is where they live.

The theme still restyles the whole desktop -- bar, menus, notifications, launcher and the lock
screen all read `colors.toml`/`shell.toml` -- so a kid gets the look even without a new wallpaper.

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
