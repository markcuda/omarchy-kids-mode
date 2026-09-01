# L5 · Desktop Shell & Progressive UI

_status: draft · updated 2026-09-01 · lead: open · primary evidence: reports 01 (platform), 07 (pedagogy), 05 (games/toolkit), 03 (input lock-down — pending)_

## Purpose

The kid's desktop: how it looks, what keys do, and how it grows from **one thing at a time** to **the real Omarchy**.
This layer is *experience*; enforcement lives in L1/L2/L4 (see the root-owned/user-owned line in L11).

## What we know (verified)

- Omarchy 4's desktop is one Quickshell process, `omarchy-shell`; bar, launcher/menu (`Super+Space`),
  notifications, OSD, lock screen and polkit dialog are all plugins. We can ship a **`bar`-kind replacement bar**,
  **`bar-widget`s**, **`overlay`/`menu`/`panel`** surfaces and headless **`service`s** as third-party plugins with
  reverse-domain ids; they hot-reload and inherit the theme. [R01-S14][R01-S21]
- Hyprland config is **Lua** (`~/.config/hypr/bindings.lua`, `looknfeel.lua`, `input.lua`, …) with an
  `o.bind("SUPER + SHIFT + W", …)` DSL; `Super+K` shows a cheat sheet **generated from the user's own bindings** —
  so a kid binding set produces a kid-sized cheat sheet for free. [R01-S6][R05-S12][R05-S49]
- Menu extensions (`omarchy-menu.jsonc`) can hide `Setup/Update/Remove/Install` and add `Play / Learn / Create`
  with `when` guards — no code. [R01-S42]
- Everything under the kid's `~/.config` is **kid-editable**; plugins run unsandboxed in the kid's shell. This
  layer therefore cannot be a security boundary (OQ-16). [R01-S14][R01-S26]
- Pedagogy (report 07): pre-operational children (≤7) attend to one attribute at a time, struggle with hierarchies,
  need 2–4× larger targets, and find **drag** harder than click-move-click; two-key chords fit 6–8-year-olds;
  formal typing from ~7–9. Practitioner reports show 7-year-olds learning four shell commands and tab-completion in
  an hour. DoudouLinux's difficulty-ordered Activities Menu is near-exact prior art. [R07-S33][R07-S35][R07-S42][R07-S46]
- No Hyprland/tiling shortcut trainer exists anywhere; a QML `overlay` "Shortcut Target Practice" is novel and
  feasible (`hyprctl` reports window geometry). [R05-S70][R05-S15]

## Two axes, not one ladder (report 07's correction to the blueprint)

- **Capability level** — what the desktop can do, earned by the kid: **Level 1 → 2 → 3 → 3+**.
- **Freedom preset** — what the parent allows, set in L6: **Guided → Supported → Independent → Trusted**.

A 6-year-old and a 12-year-old both start at Level 1 on day one; the preset decides how fast levels unlock
(Guided: parent confirms each level; Trusted: kid self-serves).

| Level | Rank (kid-facing) | Desktop behaviour | Keys introduced | Unlock evidence (proposal) |
| --- | --- | --- | --- | --- |
| **1 · One thing** | Explorer | Every app full-screen; open or closed; no float/drag/minimise/workspaces; launcher is a big icon grid (icon + audio for pre-readers) | `Super+Space` open, `Super+W` close, `Super+Home` "go home" (close-all-to-launcher), `Super+Z` undo-last-window-thing | 5 apps opened and closed by keyboard across 3 sessions |
| **2 · Two things** | Tinkerer | Second app splits **50/50**; no overlap; focus moves with `Super+←/→`; swap with `Super+Shift+←/→` | arrows + Super; nothing needs >2 keys | Shortcut Target Practice level cleared; parent confirms (Guided) |
| **3 · The real thing** | Navigator | Omarchy's tiling, workspaces 1–3 (then more), resize, full `Super+K` sheet minus dangerous binds | the standard Omarchy set | timed mini-game: focus, swap, resize, close |
| **3+ · Shell** | Wizard | Real terminal (sandboxed per L4), `Super+Enter`, dotfiles as a hobby | terminal keys | parent gate; preset ≥ Supported |

Design rules (report 07): every shortcut has a visual/physical anchor (on-screen key overlay, optional key-cap
stickers); no chord >2 keys before Level 3; every keyboard action reversible; tiling never hides a window before
Level 3; the terminal is a playground first.

## Mechanics (proposal)

| Concern | Mechanism | Notes |
| --- | --- | --- |
| Level behaviour | Per-level Hyprland Lua overlays (`kids-level-1.lua` … `-3.lua`) sourced from the kid's `hyprland.lua`; window rules force fullscreen/tiled/no-float | Align with `omarchy-kids` `tiers/` (OQ-15) |
| Kid bar | `bar`-kind plugin: workspaces as big coloured dots, clock, battery, time-left, "Ask a grown-up" button; large hit targets via `shell.toml` spacing scale | id e.g. `io.github.<owner>.kids-bar` |
| Kid launcher | `overlay`/`menu` plugin reading the L8 allowlist; icon + audio; DoudouLinux-style ordering | `Super+Space` override in Lua |
| Hiding the machine | Menu extension hides Setup/Update/Remove/Install; adds Play/Learn/Create | zero code |
| Disabled inputs | Remove binds for exit/reload/VT-switch/screenshot-to-clipboard as appropriate; disable mouse drag/resize at L1–2 | VT/TTY and "exit compositor" hardening belongs to L2/L1 (report 03) |
| Crash/exit safety | If `omarchy-shell` dies the bar/launcher vanish but the session continues → a `post-boot.d`/watchdog restarts it; if Hyprland dies, SDDM autologin returns to the session — verify behaviour | open |
| Level-up moments | `overlay` with the mascot; mastery badges only (no streaks) | L6/L7 |
| Games | Shortcut Target Practice (`overlay` + `hyprctl` geometry); home-row hint overlay; **don't** rebuild a typing tutor (KTouch exists) | flagship mini-game |
| Toolkit | QML/Quickshell for anything in the shell (inherits theme); Godot/TIC-80/web for bigger games | OQ-13 leaning answered |

## Interfaces

Consumes preset + level policy (L6), theme (L7), allowlist (L8), budget state (L9). Depends on L1/L2/L4 for
anything that must hold. Packaged by L11 as `omarchy-kids-shell` (+ `-games`).

## Residual risks

Kid edits `~/.config/hypr/*.lua` or disables the plugin in `shell.json` → cosmetic escape only if L3/L4/L9 hold;
`omarchy update` restarts the shell unconditionally → re-assert via hooks; upstream plugin API is 17 days old.

## Workstreams & backlog seeds

SHELL-01 Level 1/2/3 Lua overlays + window rules · SHELL-02 Kids bar plugin · SHELL-03 Kid launcher plugin ·
SHELL-04 Menu extension pack · SHELL-05 Shortcut Target Practice · SHELL-06 Home-row hint overlay ·
SHELL-07 crash/exit behaviour test on 4.0.2 · SHELL-08 Super+Arrow split usability test with 6–9-year-olds (UX-03) ·
SHELL-09 level-unlock criteria + parent confirmation UI (PED-02).

## Open questions

OQ-7, OQ-13, OQ-16; the "Home" and "Undo" key choices; how many workspaces at Level 3.
