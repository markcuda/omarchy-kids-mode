# Ask a parent: `omarchy-kids-ask`, the modal, the queue, and the timer (SPEC.md R-ASK-1..3, Appendix D; issue #25)

One verb — "Ask a grown-up" — for more time, an app, a plugin, or a site. A kid opens the modal
(`share/ask/shell.qml`), it either applies the request right then (parent password typed into the
modal itself) or files it for later, and a parent decides the rest from the panel.

## The trust boundary (read this before touching any of it)

- **A kid can only ever write a claim about themself.** `bin/omarchy-kids-ask submit` (what the
  modal calls) writes one JSON record into the kid's *own* `$XDG_RUNTIME_DIR/omarchy-kids/
  ask-outbox/` — nothing new had to be made writable for this; that directory is already
  systemd-logind's own, per-user, mode-0700 territory. Nothing here enforces anything, and nothing
  a kid does here can touch another kid's outbox, the real queue, or any lock.
- **A grant is a parent's decision**, made one of two ways: typing the parent's password into the
  modal (`by: "keyboard"`), or a keystroke on the panel (`by: "panel"`). Both are "parent decided
  this", not "the kid decided this" — the queue record's `by` field is who accepted responsibility.
- **Only root applies anything.** `omarchy-kids-ask collect` (root) is the one place a kid's claim
  becomes a real queue record (`/var/lib/omarchy-kids/queue/`, Appendix D) and the one place a
  decided "approved" record turns into an actual `omarchy-kids-conf`/`-web`/`-time` call. A kid's
  session never becomes root just because a password matched — see "Why 'on the spot' isn't
  instant" below for what that means in practice.

## Commands

```text
omarchy-kids-ask time <minutes>
omarchy-kids-ask app <package-or-desktop-id>
omarchy-kids-ask plugin <plugin-id>
omarchy-kids-ask site <host>
omarchy-kids-ask submit <kind> <what> [--minutes N]
omarchy-kids-ask grant <kind> <what> [--minutes N]
omarchy-kids-ask collect [--apply]
omarchy-kids-ask list [<kid>]
omarchy-kids-ask approve <id> [--by panel|keyboard|widget|device:<id>] [--reply TEXT] [--apply]
omarchy-kids-ask decline <id> [--by panel|keyboard|widget|device:<id>] [--reply TEXT] [--apply]
```text

### Kid-side: `time` / `app` / `plugin` / `site`

Each execs `/usr/bin/quickshell -p /usr/share/omarchy-kids/ask/shell.qml` (a no-op if the modal already looks
open, same `pgrep -f` check `bin/omarchy-kids-exit` uses), first exporting what's being asked in
kid words:

| Env | Example |
| --- | --- |
| `OMARCHY_KIDS_ASK_KIND` | `time` |
| `OMARCHY_KIDS_ASK_WHAT` | `15` (the raw argument — minutes as a string, an app/plugin id, or a host) |
| `OMARCHY_KIDS_ASK_DESC` | `15 more minutes of screen time` (the kid-words sentence the modal shows) |
| `OMARCHY_KIDS_ASK_MINUTES` | `15` (only for `time`) |
| `OMARCHY_KIDS_ASK_BIN` | path back to this command, for the modal's own callbacks |

`time` refuses a non-positive, non-integer argument (exit 2) before ever opening the modal — there
is no "ask for negative screen time".

### `submit` — internal, what the modal calls back into

```text
omarchy-kids-ask submit <kind> <what> --state open|approved --by keyboard [--minutes N]
```text

Writes one Appendix D record into `/run/user/<uid>/omarchy-kids/ask-outbox/<unix-ts>-<account>-<kind>.json`
(`lib/ask.py write` does the actual JSON, atomically). Never gated by `DRY_RUN` — it only ever
touches the kid's own runtime directory, same reasoning `bin/omarchy-kids-super-tap` already gives
for never gating its own runtime-dir writes.

### `collect [--apply]` — root

For every `<uid>/omarchy-kids/ask-outbox/*.json` under `/run/user` (the root-side runtime tree),
`/run/user`, i.e. every logged-in kid's real `$XDG_RUNTIME_DIR`), moves the file into
`/var/lib/omarchy-kids/queue/` (Appendix D's real home), keeping the same filename. Any record
that already arrived decided (`state: "approved"`, from the modal's "A grown-up is here" path) is
applied right here, via the same dispatch `approve` uses. An `"open"` record is left exactly as it
is, for a human to `approve`/`decline` later. `DRY_RUN=1` by default (AGENTS.md rule 8): it only
previews what it would collect; `--apply` (or `DRY_RUN=0`) does it for real. Run by the panel
whenever a parent is looking, and by `systemd/omarchy-kids-ask-collect.timer` every minute
otherwise (see below).

### `list [<kid>]` — root

Every **open** (undecided) request, all kids or one, one line each: id, kid, kind, what (minutes
for `time`), and when it was asked. Nothing decided ever shows here — that's the whole point of a
one-keystroke panel. The command requires `is_root` before reading the queue.

### `approve <id>` / `decline <id>` — root

`approve` decides the record first — atomically, write-once — and only then performs the action
(dispatch below); a failed action still leaves the record `approved` with a warning, the same
graceful degradation as before. `decline` marks it `declined` and never performs the action. `--by`
records who decided: `panel` (a human at the panel, the default), `keyboard`, `widget`, or
`device:<id>` (a paired device's signed decision, which authd forwards). Both take an optional
`--reply TEXT` (at most 80 printable characters), the parent's own line — signed when it arrives
through a paired device, typed otherwise — which the record then carries. Both refuse (exit 2)
on an id that's already decided or doesn't exist — Appendix D's "approvers append, never rewrite
history" is read here as *a record is decided exactly once*; nothing ever flips a decision back or
edits `kid`/`kind`/`what`/`minutes`/`asked_at` after they're first written (`lib/ask.py decide`
enforces this, not just this script). Both subcommands perform the root check at entry, before
opening or changing a queue record. `DRY_RUN=1` by default; `--apply` makes either real.

## Dispatch: what "applying a grant" actually does

| Kind | Action |
| --- | --- |
| `time` | `omarchy-kids-time grant <kid> <minutes>`, resolved beside `omarchy-kids-ask` itself (`kids_bin`, never `PATH`) — it ships in the same package. |
| `app`, `plugin` | Appends `<what>` to the kid's `apps.extra` through `omarchy-kids-conf get`/`set` (same mechanism `omarchy-kids-apps hide`/`show` use for `apps.hidden`). Idempotent — asking for the same id twice is a no-op the second time. A plugin is recorded the same way an app is: R-APPS-7 says "no plugin may enforce anything", and `apps.extra` is exactly that — a launcher allow-only list, never a lock. |
| `site` | Appends `<what>` to `/etc/omarchy-kids/kids/<kid>/allow.txt` (created if missing), then re-runs `omarchy-kids-web install <band> --allow /etc/omarchy-kids/kids/<kid>/allow.txt --apply` for the kid's band. |

## Judgment calls made in this implementation

- **The queue lives at the exact path Appendix D names**, but this issue does *not* make the
  kid-writable half of the pipeline live there. A kid write to a root-owned, shared directory
  would need either a special group + sticky bit or a root-setuid helper — both more moving parts,
  and both weaker than the answer actually available for free: `$XDG_RUNTIME_DIR` is already a
  kid-only, root-readable directory that systemd-logind manages, so a kid claim lives there until
  root (`collect`) reads it. Nothing about I-3 ("locks are root-owned") is affected — a request
  isn't a lock, it's a claim, and the claim can never become an actual grant without `collect`.
- **"Approvers append, never rewrite history" (Appendix D) is read as write-once-decided**, not
  "the file's bytes never change" — a record legitimately needs its `state`/`decided_at`/`by`
  filled in once, by whoever decides it. What never happens: a second decision on the same record,
  or an edit to `kid`/`kind`/`what`/`minutes`/`asked_at` after the fact.
- **A "decision" and its "execution" are still separate records**: `lib/ask.py decide` writes
  `state`/`decided_at`/`by`, and `apply_record` then performs the action. `apply_time` used to
  carry a "if `omarchy-kids-time` isn't on this box yet" branch from before that command existed;
  it ships in this same package now, so it is resolved as a sibling (`kids_bin`) and simply run,
  like every other one (2026-09-03 maintainer-eye review, 1.3).
- **A site grant is band-wide, not truly per-kid, today.** `omarchy-kids-web install <band>
  --allow FILE` (built in a separate issue) only knows how to render one Chromium policy file per
  *band*, shared by every kid in that band's group. This keeps a genuinely per-kid record
  (`/etc/omarchy-kids/kids/<kid>/allow.txt`) for audit and for a future per-kid policy, but until
  `omarchy-kids-web` grows real per-kid policies, approving `roblox.com` for one 6-8 kid makes it
  visible to every 6-8 kid on the machine. This is disclosed here, not hidden — a future ticket for
  per-kid Chromium profiles/groups is the real fix.
- **`omarchy-kids-blocked` is untouched.** It already exists (issue #11, R-DESK-2's
  fail-closed "a check failed before your desktop could start" message) under a very similar name,
  with its own, unrelated command-line contract. R-BUILD-4 names this feature's command `-ask`
  (i.e. `omarchy-kids-ask`), so that's what got built; renaming or merging the two is out of scope
  here and would break `-grownup`'s existing callers for no reason.

## Why "on the spot" isn't instant

R-ASK-1 says a parent's password in the modal means "granted on the spot". Read literally in the
kid's own session, that's not something this design can offer honestly: nothing a kid's process
does — typing a password into a custom Qt modal, then having a helper verify it against
`omarchy-kids-authd` — makes that process root. The only two things that actually apply a grant are
`omarchy-kids-conf`/`-web`/`-time` themselves, and those write root-owned files. Two paths were
considered and rejected before landing on the one shipped here:

- **A new daemon, like `omarchy-kids-authd` but for actions** (verify a password, then perform a
  parameterized grant, all inside one root process). Real, but a second security-sensitive root
  service is a lot of new surface for one feature, and R-SEC-1/2's whole design is "one narrow
  oracle, nothing else" — duplicating that shape felt like the wrong lesson to draw from it.
- **A scoped polkit rule** letting a kid's own `systemctl start` reach one specific root oneshot
  unit. Plausible, but polkit's actual behavior for a *non-interactive* `systemctl start` from an
  unprivileged, non-admin account is genuinely unverified here (no live polkit/systemd session was
  available while writing this) — shipping a security boundary on a guess is exactly what AGENTS.md
  rule 8 (never assume, always verify) is warning against.

What shipped instead: the modal writes the decided record into the kid's outbox and says so
honestly — "Got it! ... will be ready very soon", never "Done" — and `omarchy-kids-ask collect`
is what actually performs it, the next time it runs. That is:

- **Immediately**, if a parent happens to be at the panel (the panel is expected to call `collect
  --apply` itself whenever it's open, or a parent can run it by hand).
- **Within about a minute otherwise**, via `systemd/omarchy-kids-ask-collect.timer`.

`omarchy-kids-assert` also enables the timer as one of its own `units_ok`/`units_fix` checks
(alongside the boot-login units and the authd socket), so a fresh `omarchy-kids-assert` run — by
hand, the wizard, or the pacman hook (R-TRUST-5) — is enough to make sure it's on.

## Paths and environment

| Var | Default | What |
| --- | --- | --- |
The kid-facing command uses build-time constants: `ETC=/etc/omarchy-kids`,
`SHARE=/usr/share/omarchy-kids`, `SYSROOT=`, and `RUN=/run/user/<uid>/omarchy-kids`.
Tests substitute these in a copied command tree with `kids_set_const`; inherited path variables are
ignored. `collect` remains root-side and may use its explicit scratch-root test seam.
| `DRY_RUN` | `1` | gates `collect`/`approve`/`decline`; `submit` and the kid-side commands are never gated (they only ever touch the kid's own runtime dir) |

## What's unverified — check in the VM

Everything `share/ask/shell.qml` shares with `share/exit-modal/shell.qml` (`PanelWindow` +
`WlrLayershell.layer: WlrLayer.Overlay`, `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`,
the `Process`/stdin verifier shape, `Quickshell.execDetached` before `Qt.quit()`) was already
confirmed live for the exit modal (`docs/exit.md`'s "Verified live" section, 2026-09-02) and is
reused here unchanged — but this specific file has not itself been run against a real Quickshell.
Before trusting it in front of a kid:

1. Open each of `time`/`app`/`plugin`/`site` from a kid session and confirm the modal appears on
   top, focused, with the right kid-words description.
2. "A grown-up is here" with the parent's real password: confirm the outbox record is written
   (`ls $XDG_RUNTIME_DIR/omarchy-kids/ask-outbox/`), then run `omarchy-kids-ask collect --apply`
   as root and confirm the grant actually lands (allowlist entry, allow.txt, or a time grant).
3. "A grown-up is here" with a wrong password three times: confirm the shake/hint/30s-lockout
   behavior (same code path as the exit modal's own, already verified there).
4. "Ask later": confirm the exact text "Asked. Your grown-up will see it." appears, and that the
   outbox record is `state: "open"`.
5. Esc at any point: confirm nothing is written at all.
6. Enable `omarchy-kids-ask-collect.timer`, wait past a minute with something sitting open in an
   outbox from an on-the-spot approval, and confirm it gets applied without anyone touching the
   panel.

## Verified live (2026-09-02, QEMU test VM)

`omarchy-kids-ask time 15` in Cy's session opened the overlay over the launcher: "Ask a
grown-up", "15 more minutes of screen time", a focused password field, "A grown-up is here"
and "Ask later". The parent password and Enter wrote the request to the outbox as
`state: approved`, and within the minute `omarchy-kids-time status` showed "budget 3 + 15
granted" with the grant file in the kid's usage directory. Not yet exercised live: "Ask later"
followed by the parent approving from the panel, and the app and site kinds.
## Security fix, 2026-09-03: root decides, the kid's session only asks

The antagonistic review (`docs/reviews/2026-09-03-antagonistic.md`, S1-S3) found that a kid
could grant themselves anything. `submit` wrote `--state approved` into the kid's own outbox, a
directory the kid owns, and `collect` -- running as root from `omarchy-kids-ask-collect.timer`
every minute -- applied any record it found already approved. No password gated the chain, and
the `kid` field was trusted verbatim, so one hand-written JSON file granted screen time, an app,
a plugin or a site, to any account, at any path. That is fixed here by moving the decision, not
by adding a check: `submit` has no `--state` and no `--by` (`lib/ask.py`'s writer refuses them
too), and `collect` is now a mover only -- it promotes every record it finds to `open`, drops
anything that fails `lib/ask.py`'s `validate_grant` allowlist (no slashes, no leading dot,
bounded lengths, minutes in 1..1440), re-derives the `kid` field from the uid that owns the
outbox rather than reading it out of the file, and skips outboxes whose owner has no profile in
`/etc/omarchy-kids/kids/`. On-the-spot approval is the new `grant` subcommand: it reads the
typed parent password from stdin and sends `GRANT <json>\n<password>\n` to root's
`omarchy-kids-authd` socket, which verifies the password, checks the connecting peer's uid
(SO_PEERCRED) against the request's `kid`, runs the same allowlist, and calls back into
`omarchy-kids-ask apply-grant` -- as root -- which performs the request through the same
`apply_record` the panel's approve path uses. `grant`'s own exit code grants nothing; a kid who
fakes it fakes only the message their own modal shows them. The modal's `--open` guard is a
pidfile under the kid's runtime dir now, not a `pgrep -f` substring match that any process could
satisfy (review §1.9).

After the security review (2026-09-03): a forged `approved` record in the kid's outbox only
became an open request and granted nothing; a socket redirect from the kid's environment was
ignored; the real on-the-spot grant through `omarchy-kids-ask grant` and authd's `GRANT`
line added minutes from the modal after three live fixes (the time request's minutes, the
verifier's line reader keeping its remainder, and writable state paths in the service unit).

## Source header (moved from `bin/omarchy-kids-ask`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-ask -- "Ask a parent" for more time, an app, a plugin, or a
site (SPEC.md R-ASK-1..3, Appendix D; issue #25). One verb, four kinds.

NOTE on the name: this is the `-ask` command R-BUILD-4 lists.
bin/omarchy-kids-blocked already exists under a similar name but is
a different, already-shipped thing (issue #11's full-screen message
for a fail-closed check at login, R-DESK-2) -- it is not touched here.

Kid-side (unprivileged, run inside the kid's session):

  time <minutes>            Opens the modal asking for more screen time.
  app <package-or-id>       Opens the modal asking for one app.
  plugin <plugin-id>        Opens the modal asking for one launcher plugin.
  site <host>                Opens the modal asking for one website.

    Each execs `/usr/bin/quickshell -p /usr/share/omarchy-kids/ask/shell.qml`
    (share/ask/shell.qml), exporting what's being asked in kid words.
    The modal itself calls back into this command's `submit`:

  submit <kind> <what> [--minutes N]
    Writes one Appendix D record, always state=open, into the *kid's
    own* outbox -- /run/user/<uid>/omarchy-kids/ask-outbox/<ts>-<account>-<kind>.json.
    A kid can only ever write a *claim*, never a decision (review S1):
    there is deliberately no --state and no --by here.

  grant <kind> <what> [--minutes N]     (parent password on stdin)
    The "A grown-up is here" path. Sends GRANT plus the typed password
    to root's omarchy-kids-authd socket and exits 0 only if *root*
    verified the password, matched the peer uid to this account, and
    applied the request itself. Nothing in the kid's session decides
    anything; this command's own exit code grants nothing.

Root-side (run by the parent, from the panel, or by
systemd/omarchy-kids-ask-collect.timer):

  collect [--apply]          For every kid account, moves whatever is
                              sitting in that kid's outbox into the
                              real queue (/var/lib/omarchy-kids/queue/,
                              Appendix D). It promotes records to
                              `open` and NOTHING ELSE: it never applies
                              anything, never honours a state a kid
                              wrote, and re-attributes every record to
                              the account that actually owned the
                              outbox (review S1/S2/S3). On-the-spot
                              approval is `grant` above, decided by
                              root in omarchy-kids-authd.
  apply-grant --kid K --kind KIND --what W [--minutes N] --apply
                              Root only, invoked by omarchy-kids-authd
                              once it has verified the parent password
                              and the peer uid. Records the decision in
                              the queue and performs it, through the
                              same apply_record every other path uses.
  list [<kid>]                Every open (undecided) request, all kids
                              or one.
  approve <id> [--apply]      Performs the action, then marks the
                              record approved (by=panel).
  decline <id> [--apply]      Marks the record declined (by=panel).
                              Never performs the action.

                              The kid-facing paths are build-time constants:
                              ETC=/etc/omarchy-kids, SHARE=/usr/share/omarchy-kids,
                              SYSROOT=, RUN=/run/user/<uid>/omarchy-kids. Tests use
                              copied commands and `kids_set_const`; inherited path
                              variables are ignored. Root-side `collect` may use
                              an explicit scratch-root test seam. `DRY_RUN` remains
                              the preview setting for root-side mutations.
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
