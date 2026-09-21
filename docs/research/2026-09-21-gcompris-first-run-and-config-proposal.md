# GCompris first-run dialog and its config/quit controls — proposal

Status: proposed, needs the owner's decision. No code changes in this document.

## The live findings (2026-09-21, try-omarchy VM)

The fable live review of the Level 1 screenshots (`docs/dogfood-2026-09-21.md`, items 5-6) found:

- On a kid's **first** launch, GCompris shows its own welcome dialog: a paragraph about
  "application settings" and "the language is American English (en_US)", dismissed only by a red X
  that a six-year-old has to find.
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

1. **Pre-seed the per-kid config at provisioning (recommended, needs one live check).** During
   `omarchy-kids-provision` (or the account step of the wizard), write the kid's
   `~/.config/gcompris/gcompris-qt.conf` with the settings we want before the app first runs:
   `fullscreen=true` and a `_firstRun`-style marker if one exists (the run counters suggest the
   dialog keys off `[Internal]`; the exact key needs one live verification), and evaluate
   `kiosk=true` for hiding the wrench/quit.
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

Option 1, gated on a 15-minute live check on the VM:

1. Create a throwaway account (or reset `kid-ada`'s GCompris state), write a candidate
   `gcompris-qt.conf` before first launch, launch the app, and confirm the welcome dialog is gone
   and which affordances `kiosk=true` actually hides.
2. If `kiosk=true` hides the wrench/quit in a way that still lets the app be closed with
   `Super+Q` (our bind) and does not break progress saving, adopt it; otherwise adopt only the
   fullscreen/first-run seeding and **document the wrench/quit as app-owned** (option 2's honesty).

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
