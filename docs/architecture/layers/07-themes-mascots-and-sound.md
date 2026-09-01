# L7 · Themes, Mascots & Sound

_status: draft · updated 2026-09-01 · lead: open ("not creative enough for themes" — we need an artist) · primary evidence: report 05 §4, report 01 §4_

## Purpose

Make a seven-year-old giggle in minute one — and make the desktop readable for early readers — using Omarchy's
own theme system, so kid themes install through the stock menu and can never carry code.

## What we know (verified)

- **Theme anatomy (4.x):** `colors.toml` (24-colour semantic palette; `mode = "light"`), `shell.toml`
  (`[spacing] scale`, `[font] base-size`, control states, bar sizes — **exactly the knobs for big targets and large
  type**), `icons.theme` (Yaru variants), `backgrounds/`, `btop.theme`, `neovim.lua`, `vscode.json`,
  `keyboard.rgb`, `preview.png`, `unlock.png` + `preview-unlock.png` (the LUKS unlock screen art). Terminal,
  Chromium, Hyprland, Neovim, Helix, VSCode, Obsidian and the whole shell are **generated** from `colors.toml`.
  `~/.config/omarchy/shell.toml` is a machine-level override that survives theme switches. [R01-S37][R01-S38][R05-S8][R05-S15]
- **Git-installed themes are colours-only** — any `.lua`, terminal config or `vscode.json` is stripped (4.0.1+).
  For kids this is perfect: safe to share, impossible to weaponise. Naming `omarchy-<name>-theme`; install via
  _Install > Style > Theme_ or `omarchy theme install <url>`; catalog omarchy.org/themes via PR to `omarchy-site`;
  Aether GUI theme builder is bundled. [R01-S7][R01-S38][R01-S43]
- **Fonts:** Atkinson Hyperlegible is in Arch `extra`; Lexend via AUR; OpenDyslexic must be vendored. [R05-S19][R05-S20][R05-S59]
- **Mascot licences:** Tux (Larry Ewing, attribution; CC0 SVGs by Garrett LeSage), Konqi (CC BY-SA 4.0 / LGPL),
  Wilber (CC BY-SA 4.0) are clean; Kiki, Freedo, GNU, Suzanne, Puffy, Xue unverified; Beastie — avoid. [R05-S17][R05-S18][R05-S39]
- **Sound:** Omarchy 4 notifications are in-shell; a sound theme needs a small `service` plugin. [R05-S15]

## Principles

- **Character choice, not gender choice.** The onboarding fork is "pick your guide" from 3–5 characters; the
  default is a neutral explorer (Tux). Never a boy/girl branch.
- **Readable first.** WCAG AA 4.5:1 minimum; 7:1 for the 3–7 preset; colour-blind-safe accents (Okabe–Ito-style);
  `spacing.scale` 1.4 (3–7) / 1.2 (8–12); base font bumped; ≥44 px-equivalent hit targets.
- **Two moods per character:** *Low-stimulation* (light, muted, no animated backgrounds — base on
  `flexoki-light`/`catppuccin-latte`) and *Playful* (saturated primaries — base on community NES/`retro-82`).
- **Per-age presets:** `kids-3-7` (light, huge, few colours), `kids-8-12` (either mood), `teen` (any stock theme +
  Hyperlegible). Fonts are a per-child toggle, not a theme fork.
- **Licence-safe art:** backgrounds from Wikimedia Commons (CC/PD) and NASA (PD), every file credited in
  `CREDITS.md`; avatars generated from the mascot SVGs (hats/colours) to avoid third-party licensing; sounds CC0
  (Kenney, freesound CC0 filter).
- **The unlock screen is part of the experience.** `unlock.png` on the LUKS prompt is the first thing the kid
  sees — make it the mascot.

## Deliverables

| Repo | Contents |
| --- | --- |
| `omarchy-kids-tux-theme` (first) | `colors.toml` (light, AA 7:1), `shell.toml` spacing 1.4, Hyperlegible, CC0/PD backgrounds + credits, `unlock.png`, preview |
| `omarchy-kids-konqi-theme`, `-wilber-theme` | playful palettes; share-alike notes |
| `kids-theme-lint` | contrast + licence + required-file checker for theme PRs (CI for the theme repos) |
| Sound theme `service` plugin | CC0 cues for open/close/level-up/time-warning |
| Mascot licence registry | verified SVG sources + attributions (Kiki, Freedo, GNU, Suzanne, Puffy, Xue to verify) |
| Printable key poster + optional key-cap sticker sheet | ties to L5's "physical anchor" rule; left-handed / non-QWERTY variants |

## Interfaces

Consumes character choice (L6), preset (L6); provides theme to L5 plugins automatically (they read `Style`);
sound cues consumed by L5/L9. Packaged by L11 via the themes catalog.

## Workstreams & backlog seeds

THEME-01 Tux theme (good first issue) · THEME-02 Konqi/Wilber · THEME-03 kids-theme-lint · THEME-04 sound service
plugin · THEME-05 mascot licence registry · THEME-06 key poster · THEME-07 original CC0 character (call for artists).

## Open questions

Which mascots beyond Tux/Konqi/Wilber are worth the licence legwork? Any artist willing to draw an original
Kids Mode character under CC0? Multilingual voice lines/fortunes from day one?
