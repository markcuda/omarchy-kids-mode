# GCompris first-run dialog and its config/quit controls — proposal

Status: **approved 2026-09-21 and implemented** — the live check it waited on ran 2026-09-22 (below)
and the seeding is on branch `feat/gcompris-preseed` (`lib/provision-add.sh` +
`install_kids_gcompris_config` in `bin/omarchy-kids-provision`, `docs/apps.md`, and the
assertions in `test/shell.d/provision-test.sh`). This document keeps the proposal as written and
records what the check found.

## The live findings (2026-09-21, try-omarchy VM)

The fable live review of the Level 1 screenshots (`docs/dogfood-2026-09-21.md`, items 5-6) found:

- On a kid's **first** launch, GCompris shows its own welcome dialog: a paragraph about
  "application settings" and "the language is American English (en_US)", dismissed only by a red X
  that a six-year-old has to find. (2026-09-22: not *only* -- Escape dismisses it too, and the
  changelog and dataset prompt that follow an update are keyboard-operable as well; see the check
  below.)
- GCompris's own bottom bar shows a **wrench** (its configuration) and a **power/quit** button to
  the kid.

## What is on disk (evidence, same VM)

After the first launch, the app writes `~/.config/gcompris/gcompris-qt.conf` (Qt QSettings INI):

- `[%General]`: `fullscreen=true`, `exitConfirmation=false`, **`kiosk=false`**, `locale=system`,
  `baseFontSize=0`, `defaultCursor=false`, `noCursor=false`, `sectionVisible=true`,
  `homeButtonVisible=true`, audio volumes.
- `[Internal]`: `exeCount`, `lastGCVersionRan` — run counters, written after the first launch.
- `[Admin]`, `[Teacher]`: paths and teacher settings.

So the welcome dialog is tied to "has this app ever run" state, not to a user-visible setting, and
the app's own config/quit chrome is controlled by `kiosk` among other keys.

## Options

1. **Pre-seed the per-kid config at provisioning (recommended; the live check below settled what
   it writes).** During `omarchy-kids-provision` (or the account step of the wizard), write the
   kid's `~/.config/gcompris/gcompris-qt.conf` before the app first runs: `fullscreen=true`,
   `kiosk=true` for the wrench/quit, and the `[Internal] lastGCVersionRan` marker — which the check
   pinned as what suppresses the post-upgrade changelog and dataset prompt, the config existing
   being what suppresses the "first time" welcome.
   - Precedent: the wizard already owns the kid's account creation, so writing one app's first-run
     state is a provisioning concern, not a new mechanism.
   - Honest boundary: this is **configuration, not enforcement** — it sets the app's own options,
     and the app's controls remain app-owned. `kiosk` may not hide everything, and the app can be
     updated to rename it; the docs must say so (I-6).
2. **Do nothing and document it.** The welcome dialog is one-time and harmless; the wrench/quit
   are the app's own affordances, not our fences. Cheapest, and the docs simply say so.
3. **Wrap the app in a launcher script** that seeds the config on first run. More moving parts than
   provisioning, same result; only worth it if GCompris is installed outside the wizard.

## Recommendation

Option 1, whose live check ran on 2026-09-22 — see the results section below: `kiosk=true` hides
the wrench and the quit button and our `Super+Q` still closes the app, so it is adopted rather than
documented away.

## What it would touch (when approved)

- `lib/provision-add.sh` (or the wizard's account step): a small, per-app seeding block, keyed by
  account, writing into the kid's own home; a comment naming the app and version it was verified
  against.
- `docs/packs.md` or `docs/apps.md`: one line per app we seed this way, stating that it is
  configuration, not a lock.
- `test/shell.d/provision-test.sh`: a fixture asserting the seeded file exists and is owned by the
  kid, for a stubbed config path (no real GCompris).

## Owner decision

1. Approve provisioning writing per-kid app configuration before first login (option 1), or keep
   to documentation only (option 2)?
2. If option 1: is one live VM check enough to adopt `kiosk=true`, or should we stay with just
   fullscreen/first-run seeding and document the rest?

## Owner decision (2026-09-21): approved

Pre-seed the config at provisioning, as proposed. Implementation waits on the one VM check
(what `kiosk=true` hides; what suppresses the welcome dialog), then ships with a provisioning
test asserting the seeded file exists and is kid-owned.

## Live check, 2026-09-22 (try-omarchy VM, gcompris-qt 26.1-1) — done

Reset and re-seeded `kid-ada`'s config between launches; what the check found, by state:

| config state at launch | what the kid sees |
| --- | --- |
| no config at all | "Welcome to GCompris! … for the first time … Your current language is American English (en_US)." with a red X |
| config without `[Internal] lastGCVersionRan` | a "GCompris has been updated!" changelog, then a "Some activities have new dataset available" prompt with Apply/Cancel |
| seeded: `fullscreen=true`, `kiosk=true`, `lastGCVersionRan=260100` | no dialog at all; the app opens straight to its home screen |

- **The marker is `lastGCVersionRan`**, written as the app's own number (`major*10000 + minor*100 +
  patch`: 26.1 -> 260100, read back from what the app itself wrote), not `exeCount`.
- **`kiosk=true` hides the kill switch and the workshop**: the bottom bar loses its power/quit
  button, the wrench and the menu; the home, help, favourites hint and search stay. Closing still
  belongs to us — `Super+Q` ended the app even with a modal up, so the kiosk chrome cannot trap a
  kid — and the app kept writing its own state (our two keys survived its rewrite, `exeCount`
  advanced).
- **The check also corrected the premise**: the finding above said the welcome dialog is dismissed
  *only* by its red X. It is not — Escape dismissed the welcome and the changelog, and Tab then
  Enter dismissed the dataset prompt. All of them are keyboard-operable; the dialogs are a nuisance
  a kid can clear, not a mouse-only trap.
- A minimal seeded file is enough: GCompris keeps our keys and fills in its own on first run, so the
  provisioner does not have to write the app's full default set.

What shipped with it: the seeding is conditional (`fullscreen`, `kiosk`, the marker when the
packaged version can be read) and **never rewrites a config the app has already written**; a
version that cannot be read is said out loud rather than guessed. `docs/apps.md` has the same facts
for a reader who starts there.
