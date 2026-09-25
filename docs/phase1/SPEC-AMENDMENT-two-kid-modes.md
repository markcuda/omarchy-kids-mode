# SPEC amendment: two kid modes (`grid` and `desktop`)

Status: **approved and built (owner, 2026-09-24)** — with one change to the proposed model below:
the second mode is **Desktop = `level = 3`** (the real Omarchy desktop, menu-trimmed), not the old
bespoke Simplified desktop (`level = 2`), which is retired. The owner's dogfooding notes asked for
"app grid + trimmed level 3" and "just two, not app grid + weird pseudo menu + desktop". Built in
`fix/kid-session-polish`.
Originally requested by the owner on 2026-09-21, after the Level 1 live dogfood pass
(`docs/dogfood-2026-09-21.md`) and the Level 2/3 questions it raised.

Amends: SPEC.md R-DESK-3, R-DESK-4, R-DESK-5, Appendix A (A11), Appendix B.2, Appendix E, and the
R-BAND table. Does not touch R-BAND-1/R-BAND-2 (the table stays data; profiles stay overrides).

## Why

- The spec has three levels but only two kid-facing choices. Level 1 (App grid) and Level 2
  (Simplified desktop) are both shipped bespoke surfaces; Level 3 is the stock Omarchy desktop,
  hidden from every picker while its menu-trim extension format was an unverified guess
  (`share/menu/omarchy-kids-trimmed.jsonc`) and its binds/sudo path were unverified on a real box
  (`docs/phase1/DECISIONS-NEEDED.md` §6 item 4). **Both were checked on 2026-09-22 — see "Level 3's
  verification status" below**, so this bullet is now history, not a live reason to hide it.
- Three names for two choices reads wrong on the parent screens and in the band table: "every
  older band defaults to Level 2" says a six-year-old gets a desktop, which the 6-8 starter pack
  (GCompris, KLettres, Kanagram, SuperTux, Blinky) does not look like.
- Mode is presentation only. `docs/levels.md` already says Level 2 "changes presentation and
  window controls, not the band's web, Wi-Fi, app, screen-time or terminal policy values". This
  amendment moves no policy value; it renames the two kid modes and moves which one each band
  gets by default.

## The model

| Mode label | Stored as | What the kid gets | Band default |
| --- | --- | --- | --- |
| **Grid** | `level = 1` | fullscreen big-tile launcher, `Super+Home`, nothing else bound | 3-5, 6-8 |
| **Desktop** | `level = 3` | the real Omarchy desktop, menu-trimmed, normal tiling and `Super+arrows` focus | 9-12, 13+ |
| **Retired** | `level = 2` | the old bespoke Simplified desktop (themed background, searchable picker). Still starts for a profile that names it; never offered | none |

- The parent's Desktop row offers **Grid** and **Desktop** only, with the band's default marked.
  This is the one mode control; it stays an override that survives a band change (R-BAND-2).
- When the parent has not overridden the mode, a band change re-marks the new band's default.
- `menu` gains an explicit meaning: `trimmed` for Grid and Desktop, `full` for an older kid who
  wants the full menu, still overridable. The Desktop mode already seeds the trimmed menu extension
  (`share/menu/omarchy-kids-trimmed.jsonc`, R-DESK-4).
- No other band value moves: web, dns, budget, lights-out, wifi, apps, terminal all stay as the
  R-BAND table has them.

## Exact SPEC edits (before → after)

The before-text below is condensed; the requirement id is the authority. The after-text is the
proposed wording.

### R-DESK-3

Before: "Levels per Appendix E. Level 1 (App grid): … Level 2 (Simplified desktop): … Level 3
(Full desktop): … Ages 3-5 default to Level 1; every older band defaults to Level 2. The parent
can override this in the permissions/settings Desktop row; changes apply at next login and
preserve the other age policies."

After: "Two kid modes, plus a hidden parent-only stock desktop, per Appendix E. **Grid**
(`level = 1`): fullscreen-only, big-tile launcher, `Super+Home`, no terminal or file manager.
**Desktop** (`level = 2`): a themed background teaching `Super+Space`, a searchable allowed-app
picker, normal tiling and `Super+arrows` focus; Escape or opening an installed app hides the
picker and it can be reopened repeatedly. **Stock desktop** (`level = 3`): the real Omarchy
desktop, parent-only and hidden from every picker until its menu-trim extension and binds are
verified on a real box. Bands 3-5 and 6-8 default to Grid; 9-12 and 13+ default to Desktop. The
parent can override the mode in the permissions/settings Desktop row; changes apply at next login
and preserve the other age policies."

### R-DESK-4

Before: "… under Levels 1 and 2 …; untouched under Level 3 (Q23)."
After: "… under Grid and Desktop …; untouched under Stock desktop unless the parent sets
`menu=trimmed` (Q23)."

### R-DESK-5

Before: "The Level 1 launcher is a standalone root-installed QML program …"
After: "The Grid launcher is a standalone root-installed QML program …" (same file; the Desktop
picker is a sibling window of the same program, which the spec should now say in R-DESK-3).

### Appendix A, A11

Before: "1 **One thing at a time** 2 **Two things side by side** … **3 Full desktop is hidden in
v1** …"
After: "**Grid** — one thing at a time · **Desktop** — apps in windows, side by side; band default
marked. **Stock desktop is hidden in v1** (unverified binds and menu extension,
`docs/phase1/DECISIONS-NEEDED.md` §6); existing `level = 3` profiles still start."

### Appendix B.2

`level` row: keep `1` `2` `3` as the stored values (no migration), but label them Grid, Desktop,
Stock desktop (schema label is "Desktop level" today; `reset = clear` stays). `menu` row default:
`by level` → `trimmed for Grid/Desktop, full for Stock; parent overrides` — and the mode configs
must start honoring the key, which they do not today (`docs/conf.md`:74).

### Appendix E

Rename the three tables Grid / Desktop / Stock desktop, keeping today's bind sets unchanged. Add
one line under Grid/Desktop: "Stock desktop's entry is not offered in v1."

### R-BAND table

The `Level` column becomes `Mode` with values: 3-5 **Grid**, 6-8 **Grid**, 9-12 **Desktop**,
13+ **Desktop**. No other cell changes.

## Storage and migration

- Keep the existing numeric `level` key and its validator (`1|2|3`). This is a label and
  default change, not a data migration; no `schema_version` bump, no profile rewrites.
- A later rename to a string `mode` key is a separate, owner-approved migration ticket; do not do
  both in one change (open question 1).
- The wizard's Level screen, the panel's Desktop row, and every `--help`/docs string change their
  labels; the hidden `3` value is refused by both pickers as it is today.

## Verification

- The binding sets do not change: `test/shell.d/levels-test.sh` keeps asserting them; it grows one
  assertion for the band→mode defaults (3-5 and 6-8 → `1`; 9-12 and 13+ → `2`).
- The rename is only true once a **Grid** kid and a **Desktop** kid have each been logged into on
  the VM. *(2026-09-22: both have been — Level 2's own live pass is in `docs/dogfood-2026-09-21.md`
  and `docs/levels.md`, and the loop has dogfooded it since; the sentence below is what was true
  when this was drafted.)* Level 2 has never run against a real Hyprland/Quickshell
  (`docs/levels.md`), so the Desktop default for 9-12/13+ is not truthful until that pass. Stock
  desktop's gate on the real-box menu-extension check (R-DESK-4) **is now met** — see below.
- Docs and data to update when the amendment lands: `docs/levels.md`, `docs/wizard.md` (A11 copy),
  `docs/conf.md` (the `level` row, the `menu` row, and the band table around line 165),
  `share/config/schema.toml` (the `level` label, "Desktop level"), `share/bands/bands.toml`
  (6-8 `level` 2→1), and `test/shell.d/levels-test.sh` gains the band→mode default assertion it
  has none of today. The repo README changes only if it names levels.

## Level 3's verification status (2026-09-22)

Written by the unattended loop, which re-checked both halves of the 2026-09-19 gap on the
try-omarchy aarch64 VM before any of this was proposed as a decision. (The image's own identity,
for the record, is `/usr/share/omarchy/version` = `4.0.0.alpha` with the files owned by
`try-omarchy-runtime 4.0.3-1`; the "Omarchy 4.0.2" other docs cite is the upstream release the
research compares against, not this image's build string.) Nothing here
changes code; it is what the owner's question 3 and question 5 now rest on.

**The menu-trim extension's format is verified, not a guess.**

- Source, read on the box: `shell/plugins/menu/MenuModel.js`'s `parseMenuJsonc` strips the JSONC
  comments and turns a **map keyed by id** into items (`for (var id in source) out.push(
  normalizeItem(id, entry))`); `mergeMenuSources` then merges the stock file and the user extension
  **by id**, field by field, the user file winning; `Menu.qml`'s `evaluateGuards` hides any item
  whose `when:` evaluates false ("Guarded items are hidden when their `when:` evaluates false").
  `Menu.qml` reads the extension from `userMenuPath` =
  `$HOME/.config/omarchy/extensions/omarchy-menu.jsonc`.
- The ids our file trims exist in the stock menu as top-level keys:
  `setup` (`/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc:23`), `install` (24), `remove`
  (25), `update` (26).
- Live: the Level 3 pass (`docs/dogfood-2026-09-21.md`) opened the menu and saw only
  Apps / Learn / Trigger / Style / About. The seeded extension is on the box
  (`/home/kid-ada/.config/omarchy/extensions/omarchy-menu.jsonc`, kid-owned) and
  `share/menu/omarchy-kids-trimmed.jsonc`'s header carries the same mechanism note.

**The "sudo path" worry is answered, and it was never a keybind.**

- `omarchy-sudo-passwordless` is a **menu row**, not a binding:
  `/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc:180` defines
  `setup.security.passwordless-sudo` (a child of `setup`) whose action runs the command. It lives
  under the `setup` id this extension hides, so a trimmed kid cannot reach it — and the command
  would fail for them anyway: the live check refuses `sudo -n true` for a kid account.
- The real sudo-path risk the open item named was the **umbrella autostart's**
  `omarchy-provision-first-run` (`/usr/share/omarchy/default/hypr/autostart.lua:7`).
  `fix/level3-no-parent-autostart` (verified live in that pass) requires the stock modules
  individually instead, and the kid's journal shows no provision-first-run.

**Still open, and honestly thin:** whether stock Omarchy ever bound `SUPER + RETURN` (the L3 check
can't separate "stock never bound it" from "the unbind worked"), and `hl.unbind`'s exact signature
(`docs/levels.md` items 1 and 4). Neither blocks offering Level 3: the first is a belt-and-braces
unbind, the second is exercised by every L3 boot that parses the file.

## Open questions for the owner

1. Keep the numeric `level` key (recommended: yes, no migration) or rename to `mode` and migrate
   profiles in the same change?
2. Confirm 6-8 defaults to Grid, not Desktop. The current docs/levels.md says 3-5 only.
3. A 6-8 Grid kid still has the band's garden browser; the browser appears as a grid tile. Keep
   that (recommended) or keep the browser out of the Grid until 9-12?
4. Label in the parent UI: "Grid" and "Desktop" (recommended) or "App grid" and "Simplified
   desktop"?
5. Should 13+ ever default to Stock desktop in v1, or does Stock stay parent-only until the
   menu-extension check passes (recommended: parent-only)? *(2026-09-22: that check has passed —
   see "Level 3's verification status" below — so this is now a preference question about the 13+
   band, not a verification gate.)*

## Owner decisions (2026-09-21)

1. **6-8 defaults to Grid** (3-8 grid, 9+ desktop). The parent can choose either mode for any kid
   at setup and change it at any time.
2. **Keep the numeric `level` key**; labels only (1=grid, 2=desktop, 3=stock). No migration.
3. **Level 3 is no longer hidden.** "Just make it work properly now": verify it on the real box
   (menu trim, binds, sudo path) and offer it, with the parent's permissions deciding what is
   hidden. This supersedes the 2026-09-19 "hidden in v1" decision.
