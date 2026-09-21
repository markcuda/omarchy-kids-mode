# Favorites and recents in the launcher — proposal

Status: proposed. Needs one owner decision (ordering) before code. Source: the landscape note
(`docs/research/2026-09-18-kids-mode-landscape.md`) and a read of the existing launch-data path.

## What already exists (no new plumbing needed)

- A kid's tile launch is recorded by `bin/omarchy-kids-launcher-ctl log ID`, which appends to the
  kid's own `$XDG_RUNTIME_DIR/omarchy-kids/launches.log` — kid-writable, session-scoped.
- `lib/data.sh`'s `data_fold_launches` (root, run by the time-ledger service) promotes that file
  into the **root-owned** `/var/lib/omarchy-kids/<kid>/launches.log`, tracked by
  `launches.offset`. `lib/data.py fold-launches` already hardens the read: regular file, expected
  owner, single link, inode/offset resume, timestamp-shape filtering.
- The session manifest (`lib/session-manifest.sh`, sold by `omarchy-kids-session --manifest`) is
  built from the root-owned band packs; tile order today is the pack's order.

So a per-kid usage history already exists in a root-owned place, and nothing kid-writable needs to
be trusted beyond what the fold already validates (AGENTS rule 9).

## Options

**A. Recents-first ordering (recommended).** When the manifest is built, order tiles by the kid's
own launches: most recently launched first, then most frequently launched, then the pack order for
the rest. Ordering only — a tile's id, argv, installed state and allowlist never change, and an id
that is not in the pack is ignored.
- Kid-visible effect: the app they open most is usually first. Small, honest, and matches how the
  other launchers in the landscape survey behave.
- Cost: read `/var/lib/omarchy-kids/<kid>/launches.log` in the manifest builder (bounded lines,
  e.g. last 500) and a small comparator plus tests. No new files, no new daemon.

**B. A separate "Recent" row.** More UI (a second grid row / a section header), more layout work
in `share/launcher/shell.qml`, and it duplicates tiles. Not for v1.

**C. Parent-pinned favorites.** A profile key (`favorites = id,id`, root-owned like every other
key) whose ids sort first, ahead of recents. Cheap once A exists, and the parent is the only
writer, so the kid cannot reorder their own desktop. Worth doing after A if parents ask.

## Rules any version must keep

- **Ordering is cosmetic.** The manifest's argv/allowlist decide what can run (R-APPS-4); recents
  only move tiles. A forged launch log can reorder tiles and nothing else.
- **Read bounded and validated.** Reuse the fold's file/owner checks; cap lines read, drop lines
  whose timestamp or id does not parse, drop ids not in the pack, cap counts (no integer overflow
  games), and never let a log line select executable code.
- **Deterministic ties.** Equal recency/frequency falls back to pack order, so two kids with the
  same history see the same grid and screenshots stay reproducible.
- **Works offline and per kid.** The log is per uid; siblings never see each other's ordering.

## Recommendation

A now, C later if asked, B not in v1. A is a comparator and a bounded read in a file that already
exists, with no change to what the launcher will run.

## Tests and docs (when approved)

- `test/shell.d/session-manifest-test.sh`: fixtures for a fresh log (pack order), a recency log,
  a malformed line, an unknown id, a huge count, and a same-second tie.
- `test/shell.d/data-test.sh` (if the read moves near the fold): keep the owner/link/offset checks.
- `docs/levels.md` and `docs/data.md`: one line saying the manifest order may follow the kid's own
  launch history, and that this is presentation only.

## Owner decision

1. Adopt recents-first ordering (A), or leave the launcher in pack order?
2. If A: decay window for "recent" (recommended: 30 days) and how many recents lead (recommended:
   the whole pack, since packs are 8-12 tiles and moving one app to the front is the point).
3. Add parent-pinned favorites (C) in the same change or later?

## Owner decision (2026-09-21): not adopted

Keep pack order; tiles do not reorder by recent use. The launch log stays what it is (history and
the parent panel), and this proposal is kept for the record.
