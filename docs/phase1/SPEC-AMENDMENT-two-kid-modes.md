# SPEC amendment: two kid modes (`grid` and `desktop`)

Status: **proposed — owner review required**. Doc only; no code changes until the owner approves.
Requested by the owner on 2026-09-21, after the Level 1 live dogfood pass
(`docs/dogfood-2026-09-21.md`) and the Level 2/3 questions it raised.

Amends: SPEC.md R-DESK-3, R-DESK-4, R-DESK-5, Appendix A (A11), Appendix B.2, Appendix E, and the
R-BAND table. Does not touch R-BAND-1/R-BAND-2 (the table stays data; profiles stay overrides).

## Why

- The spec has three levels but only two kid-facing choices. Level 1 (App grid) and Level 2
  (Simplified desktop) are both shipped bespoke surfaces; Level 3 is the stock Omarchy desktop,
  hidden from every picker because its menu-trim extension format is an unverified guess
  (`share/menu/omarchy-kids-trimmed.jsonc`) and its binds/sudo path are unverified on a real box
  (`docs/phase1/DECISIONS-NEEDED.md` §6 item 4).
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
| **Desktop** | `level = 2` | normal tiled windows, searchable allowed-app picker, `Super+Space`, `Super+arrows` | 9-12, 13+ |
| **Stock desktop** | `level = 3` | the real Omarchy desktop (menu `full` unless overridden) | none — parent-only, hidden from every picker |

- The parent's Desktop row offers **Grid** and **Desktop** only, with the band's default marked.
  This is the one mode control; it stays an override that survives a band change (R-BAND-2).
- When the parent has not overridden the mode, a band change re-marks the new band's default.
- `menu` gains an explicit meaning: `trimmed` for Grid and Desktop, `full` for Stock desktop,
  still overridable. **No mode reads `menu` today** (`docs/conf.md`:74 says so and the wizard
  hides the row), so this bullet is a code change that must ship with the rename — otherwise the
  label is a lie (I-6). Until it ships, the row stays hidden.
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
  the VM. Level 2 has never run against a real Hyprland/Quickshell (`docs/levels.md`), so the
  Desktop default for 9-12/13+ is not truthful until that pass. Stock desktop stays gated on the
  real-box menu-extension check (R-DESK-4).
- Docs and data to update when the amendment lands: `docs/levels.md`, `docs/wizard.md` (A11 copy),
  `docs/conf.md` (the `level` row, the `menu` row, and the band table around line 165),
  `share/config/schema.toml` (the `level` label, "Desktop level"), `share/bands/bands.toml`
  (6-8 `level` 2→1), and `test/shell.d/levels-test.sh` gains the band→mode default assertion it
  has none of today. The repo README changes only if it names levels.

## Open questions for the owner

1. Keep the numeric `level` key (recommended: yes, no migration) or rename to `mode` and migrate
   profiles in the same change?
2. Confirm 6-8 defaults to Grid, not Desktop. The current docs/levels.md says 3-5 only.
3. A 6-8 Grid kid still has the band's garden browser; the browser appears as a grid tile. Keep
   that (recommended) or keep the browser out of the Grid until 9-12?
4. Label in the parent UI: "Grid" and "Desktop" (recommended) or "App grid" and "Simplified
   desktop"?
5. Should 13+ ever default to Stock desktop in v1, or does Stock stay parent-only until the
   menu-extension check passes (recommended: parent-only)?
