# The screen-time engine (SPEC.md R-TIME-1..5, R-TIMEAUTH-1..4, Appendix F)

Budget and lights-out per kid, accounted while their session is active and unlocked. The root tick
owns elapsed-time calculation, the `allowed`/`warning`/`grace`/`finishing` decision, session
locking, and session finish. This is issue #23 plus issue #68, ticket 1, issue #69, ticket 2,
and issue #70, ticket 3.

See "Verified live" below for what has run in the QEMU test VM, and "What's unverified" for the
rest.

## The trust boundary — read this first

A kid's own session cannot be the thing that decides how many minutes they've used. Everything
that *runs as the kid* in this feature only ever **reads**:

| Piece | Runs as | Can write? |
| --- | --- | --- |
| `bin/omarchy-kids-time-ledger tick` | root, via `systemd/omarchy-kids-time.timer` | yes — the only writer of usage, grants remain separate, runtime state, and enforcement records |
| `bin/omarchy-kids-time grant` | must be root (checked; refuses otherwise) | yes — the only writer of `usage/<day>.grant` |
| `bin/omarchy-kids-time daemon` / `status` | the kid | no — read-only |

`/var/lib/omarchy-kids/<kid>/usage/` is root-owned, created `0755`; every file in it is written
`0644` (world-readable, so `status` and the daemon can read it as the kid, same as a kid's own
profile file under `/etc/omarchy-kids/kids/`) but only ever *written* by the root helper above. A
kid can kill their own `omarchy-kids-time daemon` — the warnings and the Time's Up screen just
stop appearing — but there is no code path in anything that runs as the kid that writes a minute,
a grant, or a lower "used" number into this tree. The root tick also writes
`/run/omarchy-kids/time/<kid>.json` atomically. Its directory is `0750 root:omarchy-kids`, and each
document is `0640 root:omarchy-kids`, so the kid-side process can display the decision but cannot
change it.

## Pieces

| File | What it is |
| --- | --- |
| `lib/time.sh` | Shared bash helpers: the clock, day-boundary/weekend, budget/lights-out resolution, ledger/grant reads and (root-only) writes |
| `lib/time.py` | The one place this needs real calendar math — day rollover and weekday, portable across the dev machine's BSD `date` and the target's GNU `date` (same reasoning as `lib/conf.py`) |
| `bin/omarchy-kids-time-ledger` | Root: `tick` accounts monotonic active seconds, writes each kid's runtime state, and refreshes `/run/omarchy-kids/status.json` (R-BAR-3) |
| `systemd/omarchy-kids-time.timer` + `omarchy-kids-time-ledger.service` | Runs `tick` every 30 seconds |
| `bin/omarchy-kids-time` | The kid-side daemon, plus `status`/`grant` |
| `share/time/toast.qml` | The small "N minutes left" warning (R-TIME-3) |
| `share/time/timesup.qml` | The full-screen "Time's up" overlay (R-TIME-4) |

The root runtime document contains `kid`, `logical_day`, `last_wall`, `state`, `reason`,
`remaining_seconds`, `grace_deadline`, `last_tick`, `active_seconds_remainder`,
`warnings_fired`, and an `enforcement` record. That record has `action` (`none`, `lock`, or
`finish`), `reason`, `result` (`none`, `success`, `failed`, or `not-needed`), and wall-clock `at`.
`last_tick` and `grace_deadline` use monotonic seconds; `last_wall` lets a logical-day rollover
split the active interval at 04:00. `warnings_fired` stores the threshold values `10`, `5`, and `1`
in minutes. Writes use a temporary file and rename, so the display reader sees one complete decision.

## Budget, lights-out, and the day (R-TIME-2, Appendix F)

Nothing new in `omarchy-kids-conf`: this reads Appendix B's existing `budget_min` /
`budget_min_weekend` and `lights_out` / `lights_out_weekend` keys (`docs/conf.md`), resolved the
usual way (a kid's override, else their band's default from `bands.toml`). There is no per-day-
of-week override beyond the weekday/weekend split — that split *is* R-TIME-2's "weekend variants".

The day rolls at **04:00 local**: a session still running at 03:59 is still spending yesterday's
budget, and one still running at 04:01 has started spending a fresh day's (Appendix F). Weekend is
Saturday and Sunday of the *logical* day, not the wall-clock day, for the same reason. Both are
computed once per read by `lib/time.py logical-day`, never by shelling out to `date -d`/`date -v`.

Root commands use a fixed build-time `TIME_NOW_FILE` seam in copied test commands and the real
local clock when installed. Root elapsed time uses the monotonic uptime source, with the same
build-time seam for deterministic tests. No inherited value selects the root clock.

## `bin/omarchy-kids-time-ledger tick` (root, existing timer entry point)

1. Reads today's logical day, weekend flag, and one monotonic timestamp.
2. Lists every session (`loginctl list-sessions --no-legend`), keeping the ones whose account has
   a root-owned profile and whose session is the account's own graphical session (`Class=user`,
   `Type=wayland|x11`) with `Active=yes`, `LockedHint=no`, and not paused. logind also creates a
   `Class=manager` session per user; it is neither a lock target nor active time.
3. For every known kid, initializes or validates `/run/omarchy-kids/time/<kid>.json`. A first tick
   records the timestamp without adding time. Later active intervals add whole minutes to
   `usage/<day>` and retain the sub-minute remainder in runtime state. Inactive intervals add zero.
4. Recomputes `allowed`, `warning`, `grace`, or `finishing` from the current budget, grant, logical
   day, and lights-out schedule. Warning thresholds are retained in the state document.
5. On entry to `grace`, asks `loginctl` to lock each active, unlocked graphical session for that
   kid, then waits a bounded moment for every target to report `LockedHint=yes`. The request and
   the *verified* result are recorded; a session that never reports the lock counts as failed, and
   a failed lock never changes the state to `allowed`. The grace deadline runs either way.
6. At the monotonic grace deadline, calls the resolved sibling `omarchy-kids-exit --finish --kid
   <account>`. A failed call remains `finishing` and is retried on the next tick. A successful call
   is recorded and is not repeated for the same enforcing state.
7. Refreshes `/run/omarchy-kids/status.json` and folds launch logs. Those auxiliary writes remain
   best-effort; a runtime-state or ledger write failure does not become `allowed`.

Tickets 1 and 2 moved accounting, decisions, locking, and finishing into the root tick. Ticket 3
leaves the kid-side path as a compatibility display adapter; killing it no longer prevents root
enforcement or changes the authority state.

Requires root, through `lib/kids.sh`'s `is_root`. There is no environment escape: nothing a kid
can set may decide whether a root check happens (`AGENTS.md` rule 9). A test that has to be root
stubs `id` (`test/shell.d/tree.sh`'s `kids_id_stub`, `$KIDS_TEST_UID=0`).

The runtime remainder prevents the old whole-minute tick from fabricating usage. Historical usage
and grant files remain integer-minute records. A boundary decision uses the remaining seconds after
the retained remainder, so a tick cannot turn a warning or grace decision back into `allowed`.

## `bin/omarchy-kids-time` (the kid)

```text
omarchy-kids-time daemon           # started detached by omarchy-kids-session-start
omarchy-kids-time status [<kid>]   # minutes used, left, and when they run out
omarchy-kids-time grant <kid> <n>  # root only: +n minutes to <kid>'s budget, today only
```text

`status` (default `<kid>`: this account) keeps the parent-facing two-line format used by the panel:

```text
$ omarchy-kids-time status kid-ada
kid-ada: 23 min used, 37 min left today (budget 60)
budget runs out at 10:37
```text

The used, budget, and grant numbers still come from the read-only ledger and profile resolution.
When a current, validated root runtime document exists, its published remaining seconds and
deadline supply the left and boundary values. Before the first root tick, or when the document is
absent/stale, status falls back to the old read-only ledger calculation so the panel still shows
facts. Its output remains `lights-out at HH:MM` or `budget runs out at HH:MM` on the second line.

`grant` adds to a *separate* `usage/<day>.grant` file and remains root-only. The root tick is the
only code that recomputes budget, lights-out, and enforcement state.

`daemon` polls every 30 s (`OMARCHY_KIDS_TIME_POLL_INTERVAL`) while *this session*
The daemon remains for compatibility with existing logged-in sessions. It reads only the current
account's validated root document. It compares the root-published `warnings_fired` list with the
list it has already displayed, then sends the newest published threshold to `toast.qml`. It never
derives a threshold from remaining time. For root state `grace` or `finishing`, it asks
`timesup.qml` to display; for `allowed` or `warning`, it hides that display. A missing or malformed
state produces no display action.


## Warnings and Time's Up (R-TIME-3, R-TIME-4)

`share/time/toast.qml`: small, anchored top-right below the Level 1/2 launcher's own top-right
clock (`share/launcher/shell.qml`) — a 96px top margin instead of the clock's 24px, clearing its
roughly 40px height (issue #40; UNVERIFIED, see "What's unverified" below) — auto-dismiss (6 s, down
from 8 s), **no keyboard grab** — deliberately not layer-shell-exclusive, so a kid mid-task never
loses focus to it.

`share/time/timesup.qml` is full-screen and keyboard-exclusive (the same `PanelWindow` +
`WlrLayershell` pattern as `share/exit-modal/shell.qml`). It reads the fixed root-state path,
validates `grace`/`finishing`, and displays the countdown represented by root's
`grace_deadline - last_tick`. Its one action is **Ask a grown-up for more time**. The local timer
only animates that already-published deadline; it never finishes, grants, unlocks, or changes
authority state. Root performs the 60-second finish transition independently.

### "Ask a grown-up" is R-ASK-1's own modal

The button runs `omarchy-kids-ask time 15` (`docs/ask.md`): the "Ask a grown-up" modal is wired to
open over the Time's Up overlay, and a parent's password grants the minutes on the spot through
`omarchy-kids-authd`, or "Ask later" queues the request for the panel. Either way the grant lands
in the ledger, the daemon's next poll sees minutes left, and `dismiss_timesup` closes this overlay.
The button still says "ask", not "get" (I-6): asking is the kid's part, granting is the parent's.

Until 2026-09-03 this ran `omarchy-kids-time ask-grownup`, a placeholder from before
`omarchy-kids-ask` existed that showed the R-DESK-2 "this desktop can't start safely" screen with
"time 15" as the failed check. That subcommand is gone. The ask modal opening *over* the Time's Up
overlay (two keyboard-exclusive layer surfaces) has not been watched live yet; the modal alone,
opened over the launcher, has (`docs/ask.md` "Verified live").

## Pause-awareness (R-TIME-2)

`/var/lib/omarchy-kids/<kid>/paused`: if this file exists, `tick` does not count that kid's time,
full stop, regardless of what `loginctl` says about their session. Nothing in this issue creates
this file — `bin/omarchy-kids-exit --pause` is itself not implemented yet (see its own header and
`docs/phase1/V1.md`) — it exists so the ledger is ready the moment something does. Until then, "no
counting while paused or locked" (R-TIME-2) is already covered by the `Active`/`LockedHint` check
alone.

## Not built in this issue

- **Ticket 4 is not included here.** The systemd interval remains unchanged, and assert/live proof
  for the new runtime directory and root enforcement remain future work.

- **The pre-reader full-screen countdown** (R-TIME-3's second half: "plus a full-screen countdown
  for pre-readers with icon and sound"). `share/time/toast.qml` is the same for every band today.
- **Pushing lights-out for tonight only** (R-TIME-4). `grant` only ever extends the *budget*.
- **`/run/omarchy-kids/status.json` has no reader yet** — it's written (R-BAR-3's shape) for the
  future parent-bar widget, R-BAR, which is a separate ticket.

Each of these is a real gap, not an oversight — I-6 says don't claim a control that isn't there,
so this list is exactly the set of R-TIME/R-ASK behaviors this issue's "Done when" doesn't cover.

## File locations

| What | Installed path | Test seam |
| --- | --- | --- |
| Kid overrides directory | `/etc/omarchy-kids/kids/` | copied command constant |
| `bands.toml` | `/usr/share/omarchy-kids/` | copied command constant |
| Ledger/grant/paused files | `/var/lib/omarchy-kids/<kid>/` | copied `SYSROOT` constant |
| Runtime state | `/run/omarchy-kids/time/<kid>.json` | copied `SYSROOT` constant |
| `status.json` | `/run/omarchy-kids/status.json` | copied `SYSROOT` constant |
| `omarchy-kids-time`'s runtime log | `$XDG_RUNTIME_DIR/omarchy-kids/session-<uid>.log` | copied command constant |

Tests relocate copied commands at build time, the same way `PKGBUILD` relocates package paths.
Runtime environment variables cannot select an authority path, clock, account, command, or root
check.

## What's unverified (check in the VM before this ships)

Written before the 2026-09-21/22 VM runs. For any item here, check `docs/loop-report.md` -- and
which branch the observation was made on -- before relying on it: the VM runs installed branch
files, so live evidence can describe code this branch does not have yet.

- Every Quickshell-specific name in `share/time/toast.qml` and `share/time/timesup.qml`, including
  the `FileView` status reader and the fixed root-state path. The card's keyboard-only ask action
  reuses the detached-command shape verified in `share/ask/shell.qml`.
- `share/time/toast.qml`'s 96px top margin actually clearing `share/launcher/shell.qml`'s clock,
  and the 6 s auto-dismiss (issue #40) — arithmetic from both files' own anchors/font sizes, never
  checked against a real rendered frame of either. `fix/toast-clock-overlap` exists because the
  live check of this file found the window sitting over the clock; it is not merged here.
- Whether a background `&`'d `omarchy-kids-time daemon`, started from
  `omarchy-kids-session-start` before it `exec`s the launcher/shell, actually survives that `exec`
  and keeps running for the life of the session. The VM's own session log shows it does (started
  02:19, still logging toasts at 03:18 on 2026-09-22; the lines are quoted in `docs/loop-report.md`
  that day); what is still open is a repo-side test -- `test/shell.d/session-start-test.sh`'s time
  stub exits 0 and asserts nothing about the daemon.
- The kid adapter reflecting a live root warning/grace document and hiding the card after a root
  grant; the shell test covers the fixed state fixtures, but a kid seeing those surfaces in a real
  session is still unconfirmed.
- The Ask modal opening over the Time's Up overlay (two keyboard-exclusive layer surfaces); the
  modal alone, opened over the launcher, has been watched (`docs/ask.md` "Verified live"), and
  Enter on the Time's Up card opening the Ask modal over it is recorded on
  `fix/launcher-time-left-refresh`, not here.
- The launcher's own time-left line (`share/launcher/shell.qml` reading
  `/run/omarchy-kids/time/<kid>.json` with a `FileView`, rendered through
  `GridNav.remainingLabel`): the label logic is node-tested and the wiring is static-tested, but
  the real file watch against root's live state has only been reasoned about, not watched. That
  watch was recorded frozen across ticks and a grant on `fix/launcher-time-left-refresh`, which
  fixes it and live-verified the fix; on this branch the `FileView` still has no `onFileChanged`
  reload.
- Whether the lock step engages: the VM's ticks reported the lock `not-needed` while a kid was
  live, and `finishing`/`omarchy-kids-exit --finish` ran live; a Level 1/2 session going
  `LockedHint=yes` under `lock_kid_sessions` is unproven (`fix/time-lock-engagement`).

One item is verified live on this branch: the tick's own `loginctl` calls. It queries the VM's
real `systemd-logind` every 30 s (`loginctl list-sessions --no-legend` and one
`loginctl show-session <id> -p <prop>` per property -- `Class`, `Type`, `Active`, `LockedHint`),
and the usage accounting depends on parsing that output; `test/shell.d/time-test.sh` stubs the
calls as well. (This bullet used to name a four-property `show-session` form and say the repo had
never run against a real logind.)


## Verified live (2026-09-02, QEMU test VM; ticket 2)

The evidence below predates ticket 3 and records the former kid-side display/finish behavior. The
root enforcement proof remains valid; the new display-only adapter and root-state-reading card
still need a fresh VM run.

The kid-side daemon starts with the session (`omarchy-kids-session-start` line in the session
log). The lights-out rule fired the full-screen Time's Up overlay at login for a 6-8 kid at
22:29 (band lights-out 19:30): owl avatar, "Time's up, kid-ada!", a "Finishing in N s" countdown,
"Ask a grown-up for more time" and "Finish". With no answer it ran Finish after 60 s and the
portal came back. Two packaging slips found live and fixed: the timer unit did not name its
ledger service, and the units lock enabled the timers without starting them. The budget path
(ledger tick, warnings at 10/5/1, Time's Up at 0) is the next live check.

Budget path, same night: with the timer running the ledger counted real minutes ("2 min used"
after two ticks), the 5-minute toast fired at login with 3 minutes left, and a grant from the
Ask modal moved the boundary. Two small things to tidy (issue #40): the toast overlapped the
launcher's clock, and a later "10 minutes left" toast fired again after the grant raised the
remaining time. Later the same night the budget itself ran out live: the ledger counted 9
minutes down one per tick, "Time's up, kid-ada!" appeared at 0 with the fox avatar and the
countdown, and the 60 s auto-Finish returned a fresh greeter. Whether the 1-minute toast showed
was unconfirmed.

**Issue #40's fix, not yet re-verified live:** the toast now anchors below the launcher's clock
instead of under it (a 96px top margin, up from 24px) and
auto-dismisses in 6 s instead of 8; the threshold logic moved into a pure function,
`lib/time.sh`'s `time_toast_thresholds` (table-tested in `test/shell.d/time-test.sh`), that fires
10/5/1 only on `previous > threshold ≥ current` and un-fires a threshold the moment a grant raises
`current` back above it, so the stale-refire-after-a-grant bug above can't recur; and every check
— fired or not — is logged as `toast-check: ... previous=N current=M fired={...} firing={...}` so
a live run can show, from the log alone, exactly what the daemon saw at the 1-minute mark and at
budget-exhausted-Time's-Up, closing both of this "Verified live" note's open questions. The live
runs since showed the warnings firing (10/5/1 in the 2026-09-22 session) and the clock clearance
*not* holding — the window sat over the clock, which is what `fix/toast-clock-overlap` corrects —
so read this paragraph's "not yet re-verified live" as "not on this branch"; see "What's
unverified" above for the per-item state.

The following source-header blocks are historical snapshots retained for review. Their old
environment-variable test seams do not describe the ticket-1 implementation above.

## Source header (moved from `bin/omarchy-kids-time`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-time: the kid-side half of the screen-time engine
(SPEC.md R-TIME-1..5, R-ASK-1, Appendix F). Started detached from the
kid's own session by bin/omarchy-kids-session-start; also the CLI a
parent (or a future panel/bar widget, R-BAR-2) uses to check or grant
time.

Trust boundary: this whole command runs as the kid. It NEVER decides
how many minutes a kid has used -- it only reads
/var/lib/omarchy-kids/<kid>/usage/, which only
bin/omarchy-kids-time-ledger (root, via systemd/omarchy-kids-time.timer)
ever writes. A kid can kill this process (the warnings and the Time's
Up screen stop appearing) but cannot make it lie about the ledger,
because it has no write path into it -- see lib/time.sh's header for
the full argument. The one command below that DOES write
(`grant`) refuses to run as anyone but root, same as
omarchy-kids-time-ledger.

  daemon           Runs until the session ends: every 30s (poll
                    interval below), while this session is Active and
                    unlocked (`loginctl show-session $XDG_SESSION_ID`),
                    shows a small toast the first time remaining
                    minutes crosses 10/5/1 downward (SPEC.md R-TIME-3;
                    lib/time.sh's time_toast_thresholds is the pure
                    decision, issue #40 -- a grant that raises
                    remaining minutes back above a threshold lets it
                    fire again next time it's crossed), and a
                    full-screen "Time's Up" overlay at 0 remaining or
                    at lights-out (R-TIME-4). Meant to be started
                    once, detached, from bin/omarchy-kids-session-start
                    -- not run twice in one session.
  status [<kid>]    Minutes used, minutes left, and when they run out
                    (budget running out, or lights-out) for <kid>
                    (default: this account). Read-only; any account
                    can run this for any kid (the ledger files are
                    world-readable, same as a kid's own .conf).
  grant <kid> <n>   Adds <n> minutes to <kid>'s budget for today only
                    (R-TIME-4: "'More time' extends today's budget
                    only"). Root only.

Every path is overridable for tests, same convention as
bin/omarchy-kids-session-start and lib/time.sh:
  OMARCHY_KIDS_ETC      kid overrides root (default /etc/omarchy-kids)
  OMARCHY_KIDS_SHARE    bands.toml, time/ (default /usr/share/omarchy-kids)
  OMARCHY_KIDS_ROOT     scratch prefix for /var/lib/omarchy-kids
  OMARCHY_KIDS_RUN      runtime state root (default $XDG_RUNTIME_DIR/omarchy-kids)
  OMARCHY_KIDS_ACCOUNT  kid account (default: this process's own user)
  OMARCHY_KIDS_NOW      "YYYY-MM-DD HH:MM:SS" clock override (tests)
  OMARCHY_KIDS_TIME_POLL_INTERVAL  daemon's sleep, seconds (default 30)
  OMARCHY_KIDS_TIME_DAEMON_ONESHOT=1  run one daemon iteration and
                        return instead of looping forever (test hook)
```

## Source header (moved from `bin/omarchy-kids-time-ledger`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-time-ledger: the ONLY thing that ever writes a kid's
screen-time usage (SPEC.md R-TIME-1..2, Appendix F). Root, run from
systemd/omarchy-kids-time.timer (every 30 seconds) via
omarchy-kids-time-ledger.service.

Trust boundary (see lib/time.sh's header for the long version): the
per-session daemon (bin/omarchy-kids-time) runs as the kid and can
only read what's under here -- if this script only ran as the kid,
the "ledger" would just be a kid-writable file with extra steps. It
runs as root instead, and the only thing that decides what counts is
what `loginctl` reports about a session it doesn't own, plus a
root-owned paused flag (lib/time.sh's time_paused_file) -- never
anything a kid process could write into.

  tick    Lists every session with `loginctl list-sessions`, and for
          each one belonging to a known kid account (one with a
          profile under $OMARCHY_KIDS_ETC/kids/) whose session is
          Active=yes, LockedHint=no, and not paused (R-TIME-2: "Paused
          or locked time does not count"), adds one minute to that
          kid's ledger for today's logical day (Appendix F: the day
          rolls at 04:00). A kid with more than one such session only
          gets one minute added, not one per session. Also refreshes
          /run/omarchy-kids/status.json (R-BAR-3) for every known kid,
          whether or not they're live right now -- best-effort; a
          failure to write it never fails the tick itself, since the
          ledger write is the part that actually matters. Finally,
          for every known kid, folds any new lines from their own
          kid-writable runtime launches log into their root-owned
          launches.log (lib/data.sh's data_fold_launches, R-DATA-1's
          "app launches" -- see that file's header for the trust
          boundary this mirrors from screen time one level up).
          Same best-effort rule: a fold failure never fails the tick.

Every path is overridable for tests, same convention as
bin/omarchy-kids-apps and lib/time.sh:
  OMARCHY_KIDS_ROOT    scratch prefix for /var/lib/omarchy-kids and
                       /run/omarchy-kids
  OMARCHY_KIDS_ETC     kid overrides root (default /etc/omarchy-kids)
  OMARCHY_KIDS_NOW     "YYYY-MM-DD HH:MM:SS" clock override (tests)
  OMARCHY_KIDS_RUN_USER_BASE  lib/data.sh's launch-log fold source
                       (default /run/user; see that file's header)
```

## Source header (moved from `lib/time.sh`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
lib/time.sh — shared helpers for the screen-time engine (SPEC.md
R-TIME-1..5, Appendix F): bin/omarchy-kids-time-ledger (root, writes)
and bin/omarchy-kids-time (the kid, reads).

Trust boundary. `bin/omarchy-kids-time` runs as the kid, in the kid's
own session -- so it can never be the thing that decides how many
minutes a kid has used today; a kid could just kill it, or a copy of
it, and print whatever it wanted. The authoritative ledger is written
only by bin/omarchy-kids-time-ledger, run as root by
systemd/omarchy-kids-time.timer, never invoked from a kid session.
Every function in this file that *writes* under $TIME_ROOT
(time_ledger_add, time_grant_add) is only ever called by that root
helper (or by `omarchy-kids-time grant`, which itself refuses to run
as anyone but root -- see that command). Everything
bin/omarchy-kids-time itself calls here is read-only: it can show a
kid a stale or wrong number if it's buggy, but it cannot make the
ledger say something that isn't true, because it has no code path
that writes to it (I-3: locks live outside every home, root-owned;
R-TIME-1 puts that root ownership on /var/lib/omarchy-kids/<kid>/
itself, not just on the profile).

Clock. Every "now" here is OMARCHY_KIDS_NOW when set -- a local
wall-clock string, "YYYY-MM-DD HH:MM:SS" -- or the real clock
otherwise (`date '+%Y-%m-%d %H:%M:%S'`). This system has no notion of
timezone anywhere (budget/lights-out are plain HH:MM, same as
bands.toml), so nothing here ever converts a zone, only reads local
fields. Tests set OMARCHY_KIDS_NOW so the whole suite is independent
of the host's own clock and of GNU-vs-BSD `date` differences (see
lib/time.py's header for why day-rollover math is Python, not bash).

Not meant to be executed directly; source it from a command:
  source "$LIB/time.sh"

Every path below is overridable the same way bin/omarchy-kids-apps
and bin/omarchy-kids-assert already are:
  OMARCHY_KIDS_ROOT  scratch prefix for /var/lib/omarchy-kids
```

## The overlays are tracked by pidfile (issue #58)

`show_toast`, `show_timesup` and `dismiss_timesup` used `pgrep -f "quickshell -p <path>"` and
`pkill -f` on the same string. A kid with a terminal (bands 9-12 and 13+ ship one) could start any
process whose argv contained that string — `exec -a "quickshell -p …/timesup.qml" sleep 99999` —
and lights-out would think it was already on screen and never draw it (review §2.6).

They now use `lib/kids.sh`'s `modal_already_open` / `modal_write_pid` / `modal_close`, the pidfile
pair `omarchy-kids-exit` and `omarchy-kids-ask` already used: `$OMARCHY_KIDS_RUN/toast.pid` and
`timesup.pid`, written by the daemon with the overlay's own pid, checked against
`/proc/<pid>/comm`, and killed by pid rather than by argv match.

Note what this does *not* fix: the overlay still runs in the kid's own session, so a kid who kills
it (or never lets the daemon start) sees no Time's Up screen. That only removes the display. The
root tick still locks at the boundary and calls the root-side finish path after the grace deadline.

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
