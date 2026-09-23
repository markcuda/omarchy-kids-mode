# Re-reviewing an add-on whose surface changed: `bin/omarchy-kids-review` (SPEC.md R-NOTIFY-12)

When a parent approves an app for a kid, that approval is for a *specific thing*: the app's desktop
file — the launcher surface the kid sees and the `Exec` behind it. A package update can change that
file without the parent agreeing to the new one. R-NOTIFY-12 says the parent is told and may
approve, deny, or have it checked.

## The model

An **approved add-on** is an app id in a kid's `apps.extra` (the parent-added apps; the band pack is
Omarchy's own and reviewed by its pack definition, `docs/apps.md`). Its **surface** is the system
`.desktop` file the launcher resolves for that id (the same search `omarchy-kids-apps` uses); the
fingerprint is the sha256 of that file, so both the surface and the `Exec` are covered. No file
resolves any more → the fingerprint is `missing` (the package was removed).

## Commands

```
omarchy-kids-review scan [--kid KID] [--apply]
omarchy-kids-review list [--kid KID] [--json]
omarchy-kids-review approve <kid> <id> [--apply]
omarchy-kids-review deny <kid> <id> [--apply]
```

- `scan` stamps any id it has not seen before (so the first run records the approvals that predate
  this command rather than flagging all of them), opens a review for one whose fingerprint changed,
  and clears a review for one that changed back. Best-effort per id.
- `approve` re-stamps the current surface and clears its review — the parent accepts the update.
- `deny` asks `omarchy-kids-apps hide <kid> <id>` to hide it again, and only once that succeeds
drops the stamp and clears the review (a failed hide leaves the review open to retry). The hide
lands in the kid's launcher at the next sign-in, like every `hide` (`docs/apps.md`).
- Root only; `DRY_RUN=1` prints the plan (`--apply` makes it real, AGENTS.md rule 8).

## Where it lives

| Path | Mode / owner |
| --- | --- |
| `/var/lib/omarchy-kids/reviews/baseline/<kid>.json` | `0640 root:omarchy-parents`, one id → fingerprint map |
| `/var/lib/omarchy-kids/reviews/open/<kid>-<id>.json` | `0640 root:omarchy-parents`, `{kid, id, was, now, detected_at, state}` |

One writer at a time: the command takes a mutex under the review directory, so a `scan` cannot
interleave with an `approve` or `deny` and resurrect a review the parent just answered. An `open`
review is cleared when the surface changes back, when an id leaves `apps.extra`, when `approve`
restamps it, or when a `deny` hides it. Nothing here is a lock (I-3 exempts nothing, but this is a
record, not enforcement): hiding the app again is the only action, and a kid cannot reach any of it
(root-owned, outside every home).

## What is not built yet

- **The third answer, "ask your onboard agent to check it", is not built.** There is no
  onboard-agent action; the parent approves or denies.
- **Open reviews are not yet surfaced** in the panel or the desktop notifier. The records are
  written and `omarchy-kids-review list` shows them, but the Notifications/Requests screens do not
  read them yet — the next slice wires reviews into the same path requests use. Until then, R-NOTIFY-12
  is detected and answerable from the command line only.
- The scan is not on a timer yet; run `omarchy-kids-review scan --apply` after updates (or by hand),
  until the ledger tick or a timer drives it.

## Tests

`test/shell.d/review-test.sh` drives a first-sight stamp, a changed `Exec` opening a review, approve
clearing it, deny hiding the app through a stubbed `omarchy-kids-apps`, and a removed desktop reading
as `missing`.
