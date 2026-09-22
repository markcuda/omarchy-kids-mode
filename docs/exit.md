# The exit modal: Super+Shift+K, the triple-tap, and Finish (SPEC.md R-EXIT-1..6, I-5, I-6)

Every Kids Mode Hyprland level (`share/hyprland/L1.lua`, `L2.lua`, `L3.lua`) binds
**Super+Shift+K** to `omarchy-kids-exit`, and R-EXIT-1 additionally asks for **Super pressed
three times within 1.5 seconds**. Both gestures open the same thing: a modal asking for the
parent's password, then **Finish** the kid's session. This issue
builds the modal itself (`share/exit-modal/shell.qml`), the command it and the Hyprland binds
actually run (`bin/omarchy-kids-exit`, replacing its earlier stub), and the triple-tap counter
(`bin/omarchy-kids-super-tap`).

See "Verified live" below for what has run in the QEMU test VM, and "What's unverified" for the
rest.

## The pieces

| File | What it is |
| --- | --- |
| `share/exit-modal/shell.qml` | The modal itself: avatar, name, password field, and Finish action |
| `bin/omarchy-kids-exit` | `--open` shows the modal; `--finish` is what the modal runs after the parent's password verifies; `--pause` remains an unimplemented command; `--finish --kid <account>` (root) is the same idea from outside the session, added for issue #37's bar widget |
| `bin/omarchy-kids-super-tap` | Counts Super-key releases; three within the window calls `omarchy-kids-exit` |
| `bin/omarchy-kids-parent-auth` / `omarchy-kids-authd` | The verifier the modal calls (R-SEC-2; already built, `docs/authd.md`) — this issue is a *caller* of it, not a reimplementation |

## The modal (R-EXIT-1)

A centered card contains the kid's avatar and name, a focused masked password field, and one
action: **Finish for `<name>`**, which closes the kid's apps and returns to the portal.

Keyboard (I-5, keyboard-complete):

- **Enter** submits: verifies the typed password, then runs Finish.
- **Esc** closes the modal with no side effects.
- Three wrong passwords in a row disable the password field for 30 seconds (a client-side pacing
  layer on top of `omarchy-kids-authd`'s own, stricter lockout — `docs/authd.md`'s "the modal is
  a second line of defense, not the first"). A wrong password also shakes the card and clears the
  field.

Verification never happens in the modal itself: it runs `omarchy-kids-parent-auth` (a `Process`
with the typed password piped to its stdin, one line, then EOF) and reads its exit code — 0 is
"a parent typed their password", 1 is anything else, exactly the same contract
`/etc/pam.d/omarchy-lock-password`'s `pam_exec` line uses (R-SEC-2, `docs/authd.md`). The
password is never logged: not to a file, not to the console, not left in a QML property any
longer than the one verification call needs it for.

## `bin/omarchy-kids-exit`

```text
omarchy-kids-exit                        # same as --open
omarchy-kids-exit --open                 # show the modal (a no-op if one looks already up)
omarchy-kids-exit --finish               # end the kid's session (R-EXIT-3) -- run by the modal, not a kid
omarchy-kids-exit --finish --kid <acct>  # root: end <acct>'s session from outside it
omarchy-kids-exit --pause                # not implemented; prints why and exits 2
```text

`--open` execs `quickshell -p $OMARCHY_KIDS_SHARE/exit-modal/shell.qml`, first exporting
`OMARCHY_KIDS_ACCOUNT`/`OMARCHY_KIDS_NAME`/`OMARCHY_KIDS_AVATAR` read from `omarchy-kids-conf`
(name and avatar id; the avatar id is turned into
`$OMARCHY_KIDS_SHARE/avatars/<id>.svg`, the same path shape
`lib/posture.sh`'s AccountsService writer uses). "Already up" is checked with
`pgrep -f "quickshell -p <path>"` — a best-effort process-table check, since `--open` `exec`s
into Quickshell and so can never itself stay alive to track "still running" the way a
non-exec'd command could.

`--finish` (R-EXIT-3) asks Hyprland to exit cleanly first — `hyprctl dispatch 'hl.dsp.exit()'`
(Hyprland 0.56's Lua-config engine rejects the classic `dispatch exit`), best-effort, only if
`hyprctl` is on `PATH` — then polls (`pgrep -u "$(id -u)" -x Hyprland`, once a second, up to
`OMARCHY_KIDS_EXIT_WAIT` seconds, default 8) until it's actually gone, and only *then*
`loginctl terminate-session "$XDG_SESSION_ID"` as the last resort. **This order matters and is not
optional:** a hard `loginctl terminate-session`/`terminate-user` on a still-live session makes
`sddm-helper` exit 1, SDDM logs "Process crashed", and starts no greeter at all — a black screen
until `systemctl restart sddm` (found live 2026-09-02, "Verified live" below). Only a clean
Hyprland exit reliably brings the greeter back; loginctl is the fallback for a compositor that
ignored the request, not the normal path.

`--finish --kid <account>` (root only) is the same idea run from outside the session — the
parent's bar widget's "end session" action (issue #37, `bin/omarchy-kids-bar end`) and any future
panel end-session action call `sudo omarchy-kids-exit --finish --kid <account>`, never `loginctl`
directly, for exactly the crash risk above. This process has no session id, `XDG_RUNTIME_DIR`, or
`HYPRLAND_INSTANCE_SIGNATURE` for `<account>`'s session — those live in that session's own
environment, not this one's — so it finds them on disk instead: every directory under
`${OMARCHY_KIDS_RUN_USER_ROOT:-/run/user}/<uid>/hypr/` is one running Hyprland instance's
signature (normally just one, for a kid). For each one found, it runs the exit dispatch as the
account itself (`hyprctl` only works against its own compositor's socket in that instance's
runtime dir, so root can't call it directly):

```sh
runuser -u <account> -- env XDG_RUNTIME_DIR=/run/user/<uid> \
  HYPRLAND_INSTANCE_SIGNATURE=<signature> hyprctl dispatch 'hl.dsp.exit()'
```

then the same `OMARCHY_KIDS_EXIT_WAIT`-second wait, checked via `pgrep -u <uid> -x Hyprland` (the
target account's uid, not the caller's). If nothing is found under `hypr/` at all, it skips
straight to the fallback and says why on stderr. The fallback here is `loginctl terminate-user
<account>`, not `terminate-session <id>` — with no session id in hand, there is nothing else to
target, so this ends every session that account has rather than one specific scope. That
trade-off, and the exact `runuser`/`hyprctl` sequence, were never themselves run against a live
`systemd-logind`/multi-session box — see "What's unverified" below.

## `bin/omarchy-kids-super-tap`

Meant to run once per **Super key release** — bound via `o.bind("SUPER + SUPER_L", ..., { release
= true })` in all three level configs ("The triple-tap bind" above). Each run appends "now"
(milliseconds) to `$XDG_RUNTIME_DIR/omarchy-kids/super-taps`, drops entries older than 1.5s
(`OMARCHY_KIDS_SUPER_TAP_WINDOW_MS`), and — once three remain — clears the file and runs
`omarchy-kids-exit`, so the *next* three taps start counting fresh rather than firing on every
release once three have ever landed close together. `OMARCHY_KIDS_SUPER_TAP_NOW_MS` overrides
"now" for tests, so `test/shell.d/exit-test.sh` never needs to sleep for real time to pass.

## Why Pause is absent (R-EXIT-3, `docs/phase1/V1.md`, `docs/phase1/DECISIONS-NEEDED.md`)

R-EXIT-3 assumed Pause = lock the kid's session (hyprlock) and switch to the greeter via SDDM's
`Seat.SwitchToGreeter()`. Phase 1's V1 check found that call **fails outright** on Omarchy 4.0.2's
SDDM (Wayland-greeter mode): a second greeter cannot open while a session already holds the seat
(`HELPER_TTY_ERROR`, "Jumping to VT 1", display removed) — and on real hardware, the failed
attempt also revoked the parent's keyboard/trackpad until a manual `udevadm` re-trigger. **Do not
call `SwitchToGreeter` for Pause.** `docs/phase1/DECISIONS-NEEDED.md` leaves the real fix — most
likely a root helper that starts the parent's own session on a spare VT directly through PAM,
without SDDM — as its own future ticket with its own Phase 1 check. Until that exists,
`omarchy-kids-exit --pause` refuses (exit 2, a message pointing at `V1.md`). The modal does not
offer Pause until that mechanism exists, so it cannot imply that an unenforced action works.
The design note and the failed Phase 1 check remain in `docs/phase1/V1.md`.

## The triple-tap bind

Both gestures are wired into `share/hyprland/L1.lua`, `L2.lua`, and `L3.lua` now: `Super+Shift+K`
as a direct `omarchy-kids-exit` bind, and the triple-tap as a `release`-triggered bind next to it:

```lua
o.bind("SUPER + SHIFT + K", "Kids Mode: parent", "omarchy-kids-exit")
o.bind("SUPER + SUPER_L", "Kids Mode: exit (tap Super three times)", "omarchy-kids-super-tap", { release = true })
```text

The release-bind form is real, not a guess: `/usr/share/omarchy/default/hypr/bindings/voxtype.lua`
ships `o.bind("F9", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })`,
confirming `o.bind` takes a `{ release = true }` option, and Hyprland 0.56.2's Lua config engine
documents `release` alongside `ignore_mods`, `long_press`, `non_consuming`, `repeating`,
`separate`, and `transparent` as bind options. `SUPER_L` (the left-Super keysym) is what lets
`"SUPER + SUPER_L"` catch a bare Super tap at all, since Super is normally only the modifier half
of a combo. `bindr = SUPER, SUPER_L, exec, omarchy-kids-super-tap` is the Hyprland-native
(non-Lua) equivalent, for reference. `test/shell.d/levels-test.sh` greps for this bind in all
three level files; `bin/omarchy-kids-super-tap` itself is what does the counting/timing (its own
tests are in `test/shell.d/exit-test.sh`).

`bin/omarchy-kids-super-tap`'s `now_ms` needs millisecond timestamps to tell "three taps close
together" from "three taps spread out"; it isn't trying to be exact beyond that. GNU `date`
(Arch, the real target) supports `%s%N` (seconds and nanoseconds concatenated); BSD `date` (this
repo's macOS dev/test boxes) doesn't and echoes the literal `"N"` back, so that shape is detected
(a numeric result longer than 10 digits) and a whole-second fallback used instead when it isn't.

## What's unverified

The original issue's unverified list, with later live findings annotated:

- **`share/exit-modal/shell.qml` end to end.** Now verified live (see "Verified live" below):
  `PanelWindow` + `WlrLayershell.layer: WlrLayer.Overlay` (from `Quickshell.Wayland`) is real API
  on the target Quickshell version, `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive` is
  what gets keyboard focus to the password field on a layer-shell surface, and
  `Quickshell.Io.Process`'s `stdinEnabled`/`write()` deliver a clean EOF to
  `omarchy-kids-parent-auth`'s `cat -`. If a future Quickshell version drops
  `Quickshell.Wayland`/`PanelWindow`, the fallback is a plain fullscreen `Window` (matching
  `share/launcher/shell.qml`'s own choice) plus an explicit `hyprctl dispatch focuswindow` after
  showing it, the way `bin/omarchy-kids-launcher-ctl` does for the launcher.
- **The triple-tap bind itself.** `Hyprland --verify-config` and the live modal in the VM are
  what actually confirm `{ release = true }` and `SUPER_L` behave as documented once run against
  a real Hyprland 0.56.2 — **verified live 2026-09-02, see "Verified live" below (earlier draft
  note said "not run here").**
- **The "is the modal already open" check.** It uses `lib/kids.sh`'s pidfile pair
  (`modal_already_open`/`modal_write_pid`/`modal_close`), not `pgrep -f`; `test/shell.d/exit-test.sh`
  and the live run below cover it.
- **`--finish --kid <account>`, end to end (issue #37).** Whether
  `/run/user/<uid>/hypr/<signature>/` is really where a kid's Hyprland instance shows up (and
  whether there's ever more than one at a time), whether
  `runuser -u <account> -- env ... hyprctl dispatch 'hl.dsp.exit()'` actually reaches that
  instance's compositor socket from a root shell, and whether `loginctl terminate-user <account>`
  is meaningfully safer than `terminate-session` given the same "sddm-helper crashes on a hard
  terminate" finding above applies to *any* forced termination, not just `terminate-session`
  specifically — **verified live 2026-09-03, see "Verified live" below**.

## Testing in the VM

Once `share/exit-modal/`, the updated `bin/omarchy-kids-exit`, and `bin/omarchy-kids-super-tap`
are on the box (`docs/vm.md` has the SSH/VNC details):

1. SSH into the kid's session as the kid account (`ssh -p 2222 kid-ada@127.0.0.1` via the `vm`
   host, or whatever account is provisioned) — a plain SSH login has no Wayland/Hyprland
   environment of its own, so pull it from the live Hyprland process before running anything
   graphical:

   ```sh
   PID="$(pgrep -u "$(id -un)" -x Hyprland | head -1)"
   eval "$(tr '\0' '\n' < /proc/$PID/environ | grep -E '^(WAYLAND_DISPLAY|HYPRLAND_INSTANCE_SIGNATURE|XDG_RUNTIME_DIR)=' | sed 's/^/export /')"
   ```text

2. `omarchy-kids-exit --open` and confirm over VNC (`127.0.0.1:5905`, `scripts/vm-qmp.sh shot
   out.png` for a screenshot) that the modal actually appears **on top of** whatever the kid's
   desktop was already showing, centered, with the password field already focused (type
   immediately with no click needed).
3. Type the kid's own password, press Enter: should shake, clear, and show a hint — never
   succeed. Three wrong in a row: the field should visibly disable for 30 seconds.
4. Type the parent's real login password, with **Finish** highlighted as the only action, press
   Enter: the kid's session should end and SDDM's greeter should
   reappear (R-EXIT-3).
5. Re-login as the kid, `omarchy-kids-exit --open` again, this time press Esc: confirm the modal
   closes with no other effect (still logged in, nothing changed).
6. Press Super+Shift+K from inside a running app (not the launcher) at each level and confirm the
   modal reaches the top — this is the scenario the layer-shell-vs-plain-Window choice in
   `share/exit-modal/shell.qml`'s header is actually about.
7. Tap bare Super three times within 1.5 seconds and confirm the modal opens the same way
   Super+Shift+K does. `Hyprland --verify-config` against each level file, and this live check,
   are what actually confirm `{ release = true }` + `SUPER_L` behave as documented (verified live;
   see "Verified live" below).
   `omarchy-kids-super-tap` can also be exercised directly, without Hyprland at all:
   `omarchy-kids-super-tap; omarchy-kids-super-tap; omarchy-kids-super-tap` run three times within
   1.5 seconds should call `omarchy-kids-exit` the same way.

## Verified live (2026-09-02, QEMU test VM)

From the portal: Left to the kid tile, Enter, kid password, the Level 1 launcher. Three taps of
Super within 1.5 s (the `{ release = true }` bind in every level config) opened the modal as a
Quickshell overlay: fox avatar, the kid's name, a focused password field, and Finish as the only
action. Parent password, Enter: the verifier said yes, Hyprland exited cleanly, and SDDM started
a new greeter with the Kids theme.

Four things had to change to get there, all found live and now in the code:

- The overlay needs `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`; without it the
  keys went to the launcher underneath.
- `omarchy-kids-parent-auth` reads one line instead of waiting for EOF; the modal's Process
  kept stdin open and the helper hung.
- Finish runs through `Quickshell.execDetached`; a child `Process` started right before
  `Qt.quit()` died with the modal.
- `--finish` asks Hyprland to exit with `hyprctl dispatch 'hl.dsp.exit()'` (Hyprland 0.56 in
  Lua-config mode rejects `dispatch exit`) and waits for it. A hard
  `loginctl terminate-session` makes sddm-helper exit 1, SDDM logs "Process crashed" and starts
  no greeter at all: a black screen until `systemctl restart sddm`. It stays as the last resort
  only.

Exercised live 2026-09-22 (try-omarchy VM), closing the first two of the three: `Super+Shift+K`
opened the modal; a wrong password showed "That wasn't it."; the third miss turned the field red and
showed "Too many tries. Try again in 30 seconds." with the key footer hidden while locked; and Esc
closed the modal with the kid's Hyprland still running -- nothing written, no finish (the full entry
is in `docs/loop-report.md`, branch `docs/loop-exit-modal-live`). The shake is an animation a still
cannot capture. Still to check live: the parent password on a kid's tile at the portal (#15's PAM
line is installed; a portal login with the parent password is the next check).

Root-side finish, 2026-09-03: `omarchy-kids-exit --finish --kid kid-cy` run as root ended Cy's
session through the compositor's Lua exit and SDDM started a fresh greeter, which is the path
the bar widget's "end" action and the panel use.
## Two fixes from the 2026-09-03 review (§1.9)

`--finish` dispatched as `[[ -n "$kid" ]] && cmd_finish_kid "$kid" || cmd_finish`. Under
`--finish --kid` this command runs as root, so a `cmd_finish_kid` that ever returned non-zero
instead of exec'ing -- a `loginctl` that is not installed, some future early return -- would
fall through to `cmd_finish` and terminate root's own session. It is an `if` now.

`modal_already_open` matched `pgrep -f "quickshell -p $MODAL_QML"`, which any process whose argv
contained that string satisfied. A kid could start one and wedge the exit modal shut forever:
Super x3 and Super+Shift+K would both silently return 0, and the parent could not end the
session from the modal at all. The modal is tracked by a pidfile in the kid's own mode-0700
runtime dir now, and a pidfile only counts when the pid is live *and* `/proc/<pid>/comm` says
quickshell. The residual is honest and documented: a kid owns that directory and could write a
plausible pidfile, but so can they kill the modal outright -- what is gone is the ability to
block it with an arbitrary process's command line. `bin/omarchy-kids-super-tap` and the
exit-modal QML also name `/usr/bin/omarchy-kids-exit` absolutely rather than by bare name, since
the kid owns their session's `PATH` (review S12).

## Source header (moved from `bin/omarchy-kids-exit`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-exit: bound to Super+Shift+K at every level, and to three
Super taps within 1.5s via bin/omarchy-kids-super-tap (SPEC.md R-EXIT-1
.. R-EXIT-6; docs/exit.md has the full picture, including what's
UNTESTED here -- this has never run against a real Hyprland/Quickshell
session, so treat every claim below about what actually happens on
screen as unverified until it has).

--open (the default, and what Super+Shift+K/the triple-tap both run):
  if the modal looks like it's already up (a "quickshell -p .../exit-
  modal/shell.qml" process is running -- checked with `pgrep`, since
  this process --open execs into and therefore can't itself track
  "still running" once launched -- see docs/exit.md), do nothing;
  otherwise exec the modal (share/exit-modal/shell.qml) with the kid's
  name/avatar/account exported from omarchy-kids-conf.

--finish (SPEC.md R-EXIT-3, run by the modal's Finish button once the
  parent password verifies): ends the kid's session so SDDM returns to
  the greeter -- `hyprctl dispatch 'hl.dsp.exit()'` first, waiting up to
  OMARCHY_KIDS_EXIT_WAIT seconds for Hyprland to actually be gone, then
  `loginctl terminate-session "$XDG_SESSION_ID"` as the last resort only
  (see "Verified live" in docs/exit.md: a hard terminate-session makes
  sddm-helper exit 1 and SDDM shows nothing at all -- a clean compositor
  exit is what actually brings the greeter back).

--finish --kid <account> (root only; issue #37's bar widget "end
  session" action, and the panel's own end-session action if it has
  one): the same idea, done from outside the kid's session instead of
  from inside it, so it needs a different way to reach that session's
  Hyprland -- `runuser -u <account>` into the kid's own
  `HYPRLAND_INSTANCE_SIGNATURE` under /run/user/<uid>/hypr/<signature>/,
  found on disk rather than read from an env var this process was never
  given. Waits the same OMARCHY_KIDS_EXIT_WAIT, then falls back to
  `loginctl terminate-user <account>` (not terminate-session: there is
  no session id to hand it here, only the account). See docs/exit.md.

--pause (SPEC.md R-EXIT-3's other half): NOT IMPLEMENTED. Per
docs/phase1/V1.md and docs/phase1/DECISIONS-NEEDED.md, SDDM's
Seat.SwitchToGreeter() fails outright on Omarchy 4.0.2 while a session
holds the seat (HELPER_TTY_ERROR) and even revoked input devices on
real hardware until a manual udev re-trigger -- so this deliberately
refuses rather than guessing at a mechanism that was found unsafe to
even try. share/exit-modal/shell.qml no longer renders this unavailable
action (I-6: never offer a control that isn't enforced). The future
mechanism must land before Pause returns to the modal.
```

## Source header (moved from `bin/omarchy-kids-super-tap`, issue #49)

Kept for reference; the file itself now carries a short pointer instead.

```text
omarchy-kids-super-tap: the "Super pressed three times within 1.5s"
half of SPEC.md R-EXIT-1. Meant to be run once per Super *release* --
a Hyprland `bindr` (key-release) bind, not a `bind` (key-press) one,
so a normal Super+<other key> combo (Super+Home, Super+Shift+K, ...)
doesn't also count as a bare tap. See docs/exit.md for why no such
bind is actually wired into share/hyprland/L1.lua/L2.lua/L3.lua yet:
none of the Omarchy DSL reference material this repo had access to
showed a release-bind form (`o.bindr`/`hl.bindr` or otherwise) to
confirm the call against, so wiring it is left as a documented gap
rather than a guess that could silently do nothing -- or worse, bind
the wrong thing -- on a real Hyprland.

Each invocation appends "now" (milliseconds since the epoch) to a
small per-session file, drops any entries older than the window, and
-- once three remain -- clears the file and runs omarchy-kids-exit,
so the *next* three taps start a fresh count rather than firing on
every release once three have ever landed close together.
```
