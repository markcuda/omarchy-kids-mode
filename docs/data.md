# Recorded data and transparency: `omarchy-kids-data` (SPEC.md R-DATA-1..5, I-2, I-6; issue #27)

Mutual transparency, local only: what this package records about how a kid uses the computer, one
command to read it (a parent, through the panel) and to explain it (the kid, through their own
screen), and one command to prune it once it's past its retention window.

## What's recorded, where, and for how long (R-DATA-1)

| What | Where | Kept | Read by |
| --- | --- | --- | --- |
| Active minutes per day | `/var/lib/omarchy-kids/<kid>/usage/<day>` — `lib/time.sh`'s own tree, R-TIME-1 | 1 year | `omarchy-kids-data summary`/`retention` (this issue only reads/prunes it — the ledger itself is docs/time.md's) |
| App launches (Level 1 tiles only) | `/var/lib/omarchy-kids/<kid>/launches.log` | 90 days | `omarchy-kids-data launches`/`summary`/`retention` |
| Ask-a-parent requests | `/var/lib/omarchy-kids/queue/*.json` (Appendix D, `lib/ask.py`) | 90 days | `omarchy-kids-data retention` prunes it; docs/panel.md/docs/ask.md read it |
| The kid's own copy of each decided request | `/var/lib/omarchy-kids/<kid>/decisions/<id>.json` (R-NOTIFY-6, `lib/ask.py`) | 90 days, with the queue | `omarchy-kids-ask outcome`, which the ask overlay shows (docs/ask.md) |
| Ask-a-parent requests | `/var/lib/omarchy-kids/queue/*.json` (Appendix D, `lib/ask.py`) | 90 days | `omarchy-kids-data retention` prunes it; docs/panel.md and docs/ask.md read it |
| Browsing history | the kid's own `~/.config/chromium/Default/History` (Chromium's own SQLite db) | the browser's own retention — R-WEB-2 already sets `SavingBrowserHistoryDisabled: false` and `AllowDeletingBrowserHistory: false`, so this package never prunes it | `omarchy-kids-data sites`/`summary`, gated by `history_visible` (below) |

**Never recorded, anywhere in this package (R-DATA-2):** keystrokes, screenshots, file contents,
message contents. There is no code path here or anywhere else in this repo that reads any of those.

## `omarchy-kids-data`

```text
omarchy-kids-data launches <kid> [--since DAYS]
omarchy-kids-data sites <kid> [--since DAYS]
omarchy-kids-data summary <kid> [--week]
omarchy-kids-data mine
omarchy-kids-data retention [--apply]
```

- **`launches`** reads the root-owned `launches.log` (below), most recent first. World-readable, so
  this needs no privilege — same convention as every other read-only figure in this package
  (docs/time.md, docs/panel.md).
- **`sites`** copies the kid's Chromium `History` db (and its `-wal`/`-shm` sidecars, if present —
  Chromium keeps it open and WAL-locked while running, so this never reads the live file) to a temp
  file, reads *that* read-only, and prints one line per visit. Needs root, unless run as the kid
  themselves — see "Who can read what" below.
- **`summary`** prints today's (or, with `--week`, the last 7 days') minutes, launch count, top
  apps, and top sites — the same figures the panel's Data screen shows (docs/panel.md).
- **`mine`** is K5, "What my grown-ups can see" (Appendix A): run as the kid, it explains exactly
  R-DATA-1 for that kid, in plain words, plus their last day's summary. See "The kid's screen"
  below for how it's reached.
- **`retention`** prunes usage days older than 1 year, `launches.log` lines, queue records and their
  kid copies older than 90 days. Root only. `DRY_RUN` is the default shape everywhere else in this package
  (AGENTS.md rule 8) — `retention` alone (no `--apply`) prints what it would remove; `--apply` makes
  it real. **Never touches the Chromium History db** — that's the browser's own retention, not this
  package's to manage (I-2/I-6).

No timer unit installs `retention` on a schedule — that's a real gap (see "Not built here").

## Who can read what

- **Minutes and launches**: unprivileged, for anyone who can read `/var/lib/omarchy-kids/` — same
  as `omarchy-kids-time status` and everything the panel already reads without a password
  (docs/panel.md's "Root and the one sudo prompt").
- **Sites**: a kid's Chromium profile lives under *their own home*, which the parent account can't
  otherwise reach. `sites` (and the sites half of `summary`) needs root, unless the caller *is* the
  kid whose data it is — a kid reading their own history needs no elevation. The panel calls this
  through `sudo` (`read_priv`, docs/panel.md) the one time it's actually needed; `mine` never needs
  root at all, since a kid is always reading their own.
- **`history_visible=no`** (Appendix B) short-circuits all of the above before anything is ever
  touched: `sites`, `summary`, and `mine` all check it first and say so in plain words — R-DATA-4,
  "off means the panel shows none and the kid's screen says so" — never a silent empty list, and
  never a privilege check that would otherwise ask for a password it wouldn't use.

## App launches: the kid-writable half (issue #27's own note on where a launch is logged)

A kid's own processes can never write into `/var/lib/omarchy-kids/` (I-3) — so, same shape as the
screen-time ledger (docs/time.md's "trust boundary"), recording a launch is two pieces:

1. **`bin/omarchy-kids-launcher-ctl log <id>`** — new in this issue. `share/launcher/shell.qml`'s
   `launchCurrent()` calls this, fire-and-forget, every time a Level 1 tile is opened. It appends
   one `"<local-timestamp> <id>"` line to *this account's own* `$XDG_RUNTIME_DIR/omarchy-kids/
   launches.log` — writable by the kid, because it's theirs; never the root-owned log a parent or
   the kid's own `mine` screen actually reads. The timestamp is naive local time,
   `"YYYY-MM-DDTHH:MM:SS"`, one token with no embedded space — this package never converts a
   timezone anywhere (a single-user desktop has exactly one to worry about), matching every other
   timestamp this file's own format produces.
2. **`bin/omarchy-kids-time-ledger tick`** — already runs once a minute as root (docs/time.md).
   This issue adds one step to it: `lib/data.sh`'s `data_fold_launches`, which appends whatever's
   new in each known kid's own runtime log onto their root-owned `launches.log`, then remembers how
   far it got (`launches.offset`, `"<inode> <byte-offset>"`) so the same line is never folded twice.
   A fresh login gets a fresh runtime tmpfs at the same path — a new inode, and often a smaller
   file; either one on its own means "this is a new file", so the fold starts over from the
   beginning rather than treating it as corruption or silently skipping already-there-looking bytes.
   `systemd/omarchy-kids-time-ledger.service` deliberately does not set `ProtectHome=yes` for the
   same reason `omarchy-kids-ask-collect.service` doesn't (docs/ask.md): it hides `/run/user/*`
   from the unit, which is exactly where a kid's own runtime log lives.

**Only Level 1 tile launches are recorded.** Levels 2/3 run Omarchy's own app grid (R-DESK-4's
trimmed menu, `docs/apps.md`), which this package doesn't own — there's no launch hook to add one
to without editing a core Omarchy file (I-7). A real gap, not an oversight — see "Not built here".

Every append is one short `printf`, well under `PIPE_BUF`; `data_fold_launches` folds whatever
bytes exist each tick rather than trying to be exact against a line torn mid-write at that instant
— the same order of slop docs/time.md's own ledger already accepts for its resolution note.

## The kid's screen (K5, "What my grown-ups can see")

`omarchy-kids-data mine`, run as the kid, prints what this file's "What's recorded" table says, in
plain first-person words, plus "Since: <the earliest day on file>" and the kid's own last day's
summary. It's wired into the Kids launcher's tile grid (Levels 1 and 2; both bands below default to
Level 2) as **"What grown-ups see"**, but only for
bands **9-12 and 13+** — the two bands the starter-pack table already gives a terminal to
(R-BAND's own Terminal column), i.e. old enough to read the screen unsupervised. This is gated on
**band**, not level: a 9-12/13+ kid moved to Level 1 by a `level` override still gets the tile in
that grid. 3-5/6-8 kids aren't denied the data — I-6 is about not showing a control that doesn't
work, not about withholding the data itself — a grown-up can run `omarchy-kids-data mine` with them
directly; this issue just doesn't add a tile a pre-reader or early reader couldn't use alone.

The tile's `exec` opens Omarchy's own `omarchy-launch-floating-terminal-with-presentation` — the
same helper `bin/omarchy-kids-bar` opens a grant in — running `omarchy-kids-data mine` and waiting
for Enter. It used to walk `kitty`/`alacritty`/`foot`/`wezterm`/`xterm` and omit the tile if none
was installed; a stock 4.0.2 box has the helper and `foot`, not `alacritty`, so the walk was a
guess where a convention already existed (review 1.4).

## The panel's Data screen (P2, docs/panel.md)

Read-only: today's and this week's minutes/launches/top-apps/top-sites, via `omarchy-kids-data
summary`. Reading a kid's sites needs root — the panel's own `read_priv` (a dedicated `sudo`, once
per run, separate from every *write* screen's `run_priv`/`DRY_RUN` dance, since a read has nothing
useful for `--dry-run` to preview) — except when `history_visible=no`, which needs no password at
all, since `omarchy-kids-data` already refuses to touch Chromium in that case.

## Judgment calls

- **The terminal is Omarchy's own helper, not a guess.** `bin/omarchy-kids-session-start`'s
  `kids-data` tile and `bin/omarchy-kids-bar`'s grant/end both open
  `omarchy-launch-floating-terminal-with-presentation`, trusted the same way this package already
  trusts `/usr/bin/omarchy-launch-shell` (review 1.4).
- **Retention numbers are the issue's own v1.1 update comment, not the "30 days" fallback the
  original brief offered as a default.** SPEC.md's R-DATA-1 does state numbers (1 year / 90 days /
  browser's own) as of spec v1.1 — AGENTS.md's "spec wins" rule applies directly, no ticket comment
  needed.
- **`summary`'s "today"/"this week" launch-and-site windows are pinned to the exact same 04:00
  logical-day boundary "minutes used" is already measured against** (Appendix F), not a rolling
  24h/7d window — so every figure on one screen agrees about what "today" means, even though the
  underlying `--since N days` filter (used by `launches`/`sites` directly) is a plain rolling window.
- **`sites`/`summary`'s top-sites grouping is by host (`urlsplit(url).netloc`), not full URL.** A
  parent or a kid asking "what sites" almost always means "which sites", not "which exact pages" —
  `launches`'s own per-visit `sites` output still shows the full page title per row for anyone who
  wants that detail.
- **Chromium's `urls` table is read directly, no join against `visits`.** `last_visit_time` and
  `visit_count` already live on `urls` itself (this issue's own "Chromium facts") — a `visits` join
  would give per-visit rows instead of per-URL summaries, which nothing here needs.

## Not built here

- **No timer runs `retention` automatically.** A parent (or a future daily systemd timer, mirroring
  `systemd/omarchy-kids-time.timer`) has to run `omarchy-kids-data retention --apply` themselves for
  now.
- **Level 2/3 app launches aren't recorded at all** — only Level 1 tiles are (see above). A future
  issue would need either a real Omarchy launch hook or a menu-extension-side log call, neither of
  which exists yet.
- **The `kids-data` tile is unverified against a real session** — the launcher itself now runs live
  (its grid, picker and app tiles were exercised on the VM 2026-09-21/22), but this tile is offered
  only to bands 9-12 and 13+, and the loop's kid is 6-8, so its floating-terminal launch
  (`omarchy-launch-floating-terminal-with-presentation omarchy-kids-data mine`) has not been
  pressed. It uses the same helper the bar's `grant`/`end` do (docs/bar.md).
- **No export command.** A parent who wants a copy of a kid's recorded data today reads it through
  the panel or runs `omarchy-kids-data summary`/`launches`/`sites` themselves and copies the output;
  there's no `--json`/`--csv` flag.
- **No `PRIVACY.md`.** R-DATA-5 ("`PRIVACY.md` states all of this in plain words") isn't delivered
  by this issue — there's no `PRIVACY.md` anywhere in this checkout, and `AGENTS.md`'s own file-
  layout table doesn't list one either, so it isn't clear where it belongs. This doc (`docs/
  data.md`) carries R-DATA-5's content in the meantime — what's recorded, where, who can read it,
  retention, and export/delete, all below — until that's settled.

## How a parent exports or deletes

**Export:** everything `omarchy-kids-data` reads is plain text on stdout — `omarchy-kids-data
summary <kid> --week > week.txt`, or `sudo omarchy-kids-data sites <kid> > sites.txt`, is the whole
export story today (see "Not built here" above for why there's no dedicated flag).

**Delete:**

- **A kid's browsing history**: `sudo omarchy-kids-provision remove <kid> --apply` (R-FND-6,
  docs/provision.md) moves that kid's whole home — Chromium profile included — under
  `~parent/Kids Mode/<name>/`. It does not delete it — moves, same as every other removal in this
  package (R-TRUST-4's "keeps every kid's files").
- **A kid's usage/launches under `/var/lib/omarchy-kids/<kid>/` is not touched by `provision
  remove` at all** — that command only moves the home directory (verified by reading its own
  `cmd_remove`). A real gap: today, removing a kid leaves their `usage/`, `launches.log`, and
  `launches.offset` behind under `/var/lib/omarchy-kids/<kid>/` with no account left to own them.
  Until a future issue folds this into `provision remove` (or a `retention --forget <kid>`), a
  parent who wants it gone runs `sudo rm -rf /var/lib/omarchy-kids/<kid>/` themselves.
- **Just what's past retention**: `sudo omarchy-kids-data retention --apply` (above).
- **Just browsing history**: R-WEB-2 sets `AllowDeletingBrowserHistory: false` on purpose (a kid
  can't quietly clear their own trail) — a parent clears it themselves from inside Chromium on the
  kid's account (`chrome://history` → Clear browsing data), the same as clearing anyone's Chromium
  history; nothing in this package manages that db's contents directly (I-2/I-6, same reasoning as
  "never pruned by `retention`" above).

## File locations (overridable for tests, same convention as `docs/time.md`/`docs/panel.md`)

| What | Default path | Env override |
| --- | --- | --- |
| Kid overrides directory (`history_visible`, Appendix B) | `/etc/omarchy-kids/kids/` | `OMARCHY_KIDS_ETC` |
| Usage, launches, launches.offset, the ask queue | `/var/lib/omarchy-kids/` | `OMARCHY_KIDS_ROOT` (scratch prefix) |
| A kid's runtime launches log (`launcher-ctl log`'s target) | `$XDG_RUNTIME_DIR/omarchy-kids/launches.log` | `OMARCHY_KIDS_LAUNCHES_LOG`, or `XDG_RUNTIME_DIR` |
| A kid's runtime log, as seen by root folding it | `/run/user/<uid>/omarchy-kids/launches.log` | `OMARCHY_KIDS_RUN_USER_BASE` (default `/run/user`) + `OMARCHY_KIDS_ROOT` |
| A kid's home (for `sites`) | `/home/<kid>` | `OMARCHY_KIDS_HOMES_BASE` (default `/home`) |
| `lib/data.py` | `lib/` beside `bin/`, else `/usr/lib/omarchy-kids` | `OMARCHY_KIDS_DATA_PY` / `OMARCHY_KIDS_LIB` |
| `omarchy-kids-data` (called by the panel and the Level 1 tile) | resolved beside the caller, else `PATH` | `OMARCHY_KIDS_DATA_BIN` |

`test/shell.d/data-test.sh` covers `launches`/`sites`/`summary`/`mine`/`retention`, the
`history_visible` gate, the root-vs-self check on `sites`, `launcher-ctl log`, and the ledger's
launch-log fold (including the dedup-by-offset and fresh-login-reset cases) — a fixture launches
log, a small fixture Chromium `History` db built by python3 (this issue's own "Chromium facts"),
and a temp root throughout; no real Unix accounts, per AGENTS.md rule 8.

## Verified live (2026-09-03, QEMU test VM)

`launches`, `summary` and `sites` answered honestly for a kid; the launch fold only started
working once the ledger unit stopped hiding `/run/user` (ProtectHome) and the offset file
carried the runtime file's inode: after that a tile launched from the launcher appeared in the
root-owned log at the next tick and in `omarchy-kids-data launches`.

## Source header (moved from `bin/omarchy-kids-data`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-data — recorded data and transparency (SPEC.md R-DATA-1..5,
I-2, I-6; issue #27). Read-only except `retention`, which prunes.

What's recorded, where, and for how long (R-DATA-1, spec v1.1's issue
comment): active minutes per day, kept one year (lib/time.sh's own
usage/<day> tree, R-TIME-1 -- this command only reads and, for
`retention`, prunes it); app launches (Level 1 tiles only -- see
lib/data.sh's header), kept ninety days; browsing history read
straight from the kid's own Chromium profile, kept for as long as the
browser itself keeps it -- `retention` never touches that db at all
(I-2/I-6: this package doesn't manage that data, only reads it).
R-DATA-2's never-list (keystrokes, screenshots, file contents, message
contents) has no code path here or anywhere else in this package.

Commands:
  omarchy-kids-data launches <kid> [--since DAYS]
  omarchy-kids-data sites <kid> [--since DAYS]
  omarchy-kids-data summary <kid> [--week]
  omarchy-kids-data mine
  omarchy-kids-data retention [--apply]

`launches`/`summary`'s minutes-and-apps parts read only root-owned-
but-world-readable files (lib/time.sh's usage/<day>, lib/data.sh's
launches.log — same convention every other unprivileged read in this
package already uses, docs/time.md and docs/panel.md). `sites`, and the
top-sites part of `summary`, read a kid's own Chromium profile under
their home, which this account can't reach unless it *is* that kid or
is root — see require_root_or_self below. `mine` is meant to be run
by the kid themselves (K5, "What my grown-ups can see" — Appendix A);
`retention` is meant to be run by root, once a day (no timer unit is
added by this issue — see docs/data.md).

R-DATA-4: "History visibility is a per-kid cell; off means the panel
shows none and the kid's screen says so." `sites`, `summary`, and
`mine` all read Appendix B's `history_visible` key (lib/data.sh's
data_history_visible) before ever touching a Chromium profile, and say
so in plain words when it's off — never silently empty (I-6).

Chromium's History db is locked (WAL) while the browser is running:
every read here copies it (and its -wal/-shm sidecars, if present)
to a temp file first, then reads *that* with lib/data.py's own
read-only/immutable sqlite3 connection — never the live file.

Every path is overridable for tests, same convention as
bin/omarchy-kids-time-ledger:
  OMARCHY_KIDS_ETC             kid overrides root (default /etc/omarchy-kids)
  OMARCHY_KIDS_ROOT             scratch prefix for /var/lib/omarchy-kids
  OMARCHY_KIDS_HOMES_BASE       lib/data.sh: default /home
  OMARCHY_KIDS_RUN_USER_BASE    lib/data.sh: default /run/user
  OMARCHY_KIDS_NOW              "YYYY-MM-DD HH:MM:SS" clock override (tests)
  OMARCHY_KIDS_ACCOUNT          this account's name, for `mine` and the
                                require_root_or_self check (default: `id -un`)
```

## Source header (moved from `lib/data.sh`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
lib/data.sh — shared helpers for recorded data (SPEC.md R-DATA-1..5,
issue #27): bin/omarchy-kids-data (reads and prunes) and the
launch-log folding step bin/omarchy-kids-time-ledger runs once a
minute alongside its own screen-time tick.

Three things live under /var/lib/omarchy-kids/<kid>/ (spec 5.1) that
this file touches:
  usage/<day>        screen-time minutes — lib/time.sh's own tree
                      (R-TIME-1); this file only *reads* it (for
                      summaries) and prunes old days for retention.
  launches.log        one "<timestamp> <app id>" line per Level 1
                       tile launch (R-DATA-1's "app launches"). Root-
                       owned, append-only in normal operation.
  launches.offset      "<inode> <byte-offset>" of the kid's own
                       *runtime* launches log (below): how much of it
                       has already been folded into launches.log, and
                       which incarnation of that path the offset was
                       measured against (a fresh login gets a fresh
                       $XDG_RUNTIME_DIR tmpfs at the same path -- a new
                       inode). Root housekeeping, not itself recorded
                       data. [Updated post-issue-#49: was a plain byte
                       count until the ProtectHome/inode-tracking fix.]

The trust boundary is the same shape lib/time.sh's own header
describes for screen-time minutes, one level up: a kid's own Level 1
launcher can only ever write to *its own* runtime dir
($XDG_RUNTIME_DIR/omarchy-kids/launches.log, via
`omarchy-kids-launcher-ctl log`) — never to the root-owned copy under
/var/lib. data_fold_launches below is the one thing that promotes a
kid's own unverified claim ("I opened gcompris at 10:02") into the
log a parent's panel and the kid's own "what my grown-ups can see"
screen both read; it is only ever called by bin/omarchy-kids-time-
ledger's tick (root, once a minute), never by anything that runs as
the kid.

Folding is deliberately simple, not byte-exact-safe against a torn
write: each fold takes every byte written to the runtime file since
the last fold, full stop. A launch line is one short `printf` append
(bin/omarchy-kids-launcher-ctl's cmd_log), well under PIPE_BUF, so a
line torn mid-write at the exact instant a tick runs is not a
realistic risk here — this repo already accepts comparable slop
elsewhere (lib/time.sh's own R-TIME-1 resolution note).

Not meant to be executed directly; source it from a command:
  source "$DIR/lib/data.sh"

Every path is overridable for tests, same convention as lib/time.sh:
  OMARCHY_KIDS_ROOT           scratch prefix for /var/lib/omarchy-kids and /run
  OMARCHY_KIDS_RUN_USER_BASE  default /run/user (a kid's own XDG_RUNTIME_DIR
                               is assumed to be <base>/<uid>, systemd-logind's
                               own convention)
  OMARCHY_KIDS_HOMES_BASE     default /home (a kid's home is <base>/<kid>)
```

## Root reading a kid's own file (issue #58)

`data_fold_launches` is the one place root reads a path a kid controls: their
`$XDG_RUNTIME_DIR/omarchy-kids/launches.log`. It used to be a shell `[[ -r "$src" ]]` followed by
`tail -c "+$off" "$src" >> "$dest"` — both of which follow symlinks. A kid who replaced that file
with a link to `/etc/shadow` had the parent's password hash copied into their own 0644
`/var/lib/omarchy-kids/<kid>/launches.log` on the next ledger tick (review §3.3).

The read now happens in `lib/data.py`'s `fold-launches`, which opens the source `O_NOFOLLOW` and
then checks the *open descriptor*: regular file, owned by that kid's uid, one link. Anything else
is refused with a one-line reason and the tick moves on. The destination is opened `O_NOFOLLOW`
too and created 0640 root:`omarchy-parents` — like `status.json` — because it is a record about a
kid for their parent, and it was world-readable to every sibling (review §3.7). `omarchy-kids-data
launches` is root-or-self for the same reason, and answers "which account am I?" with `id -un`,
never `$OMARCHY_KIDS_ACCOUNT`.

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
