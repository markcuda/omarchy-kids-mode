# The VM acceptance harness: `test/live/`

SPEC.md R-BUILD-3, the V1-V7 checks (§7), and the §8 acceptance list. Issue #31.

`test/live/` runs from the developer's own machine and drives the test laptop's VM over SSH and
QMP — the same recipe docs/vm.md, docs/laptop-runbook.md, and the reference drivers under
`scripts/` (`v1-two-sessions.sh`, `v6-limine.sh`) already use. It is not a unit test suite: it is
a set of scenario scripts, each one a slice of §8's acceptance list, that build the real package,
install it on the real VM, and drive real logins through real QMP keystrokes. Nothing in here runs
in CI (there is no VM there); `test/all`/CI only runs the pure helpers and isolated behavioral
fixtures, in
`test/shell.d/live-lib-test.sh`. The one scenario that *does* run the unit suite is
`05-unit-tests-on-vm.sh`, and only because a few of those tests can only really run on Arch.

## Setup, on a fresh laptop

Install the Mac-side `jq` utility before running the harness; portal cleanup uses it to validate
the live Hyprland instance inventory.

1. Follow `docs/laptop-runbook.md` end to end: firmware, the stock install, Tailscale, the
   `test/verify-phase1.sh` sanity pass.
2. Build the VM once with `scripts/vm-build.sh` (see `docs/vm.md`) — an encrypted 40G disk with a
   `cidata` drive answering the installer unattended, owner account `kid-vm`, password `omarchy`
   by default.
3. Run `scripts/vm-run.sh install` to install the stock ISO into that disk, then
   `scripts/vm-run.sh boot` once by hand and confirm you can `ssh -p 2222 kid-vm@127.0.0.1` from
   the laptop.
4. On your own machine, add the `air`/`vm` Host aliases docs/vm.md's "Driving it from the Mac"
   section shows (either to `~/.ssh/config` or a separate file — either way, point
   `LIVE_SSH_CFG` at it).
5. `cp test/live/config.env.example test/live/config.env` and fill it in: the ssh config path,
   the owner's password, and the persistent test kid's account/name/password. If the VM has no
   kid provisioned yet, provision one by hand first (`docs/provision.md`) or run
   `bash test/live/60-wizard-easy.sh` once and copy what it creates into `LIVE_KID1_*`.
6. `bash test/live/10-cold-boot-kid.sh` on its own first, to confirm the whole chain (build,
   install, boot, QMP, ssh) actually works before trusting `all`.

`config.env` is gitignored on purpose (it holds test-box passwords) — `config.env.example` is the
checked-in template; nothing under `test/live/out/` (screenshots, `report.md`) is committed
either.

## Running it

```text
bash test/live/all          # every scenario, in order, stops at the first FAIL
bash test/live/all -k       # keep going after a FAIL instead of stopping
bash test/live/30-portal-login-and-finish.sh   # any single scenario, on its own
```

Every scenario is idempotent: run it once, run it twice in a row, get the same result either way
(the exceptions are called out below). `test/live/all` writes `$LIVE_OUT_DIR/report.md` — a
Markdown table of scenario, PASS/FAIL, and the screenshots it took — plus the screenshots
themselves, all under `test/live/out/` by default.

## Release screenshots

`scripts/media-driver.sh` is the Mac-side driver for docs/GOAL.md item 3. It uses this harness's
boot, portal, session, QMP, and screenshot helpers, but it is not a numbered acceptance scenario
and `test/live/all` never runs it. The package already installed in the VM must match the checkout;
the driver does not build or install it.

```text
bash scripts/media-driver.sh
bash scripts/media-driver.sh nord catppuccin-latte
bash scripts/media-driver.sh --surface ask catppuccin-latte
```

With no theme arguments it captures the ten supported surfaces under `tokyo-night` and
`catppuccin-latte`. `--surface` reshoots one surface. Successful files land directly in
`docs/media/<surface>-<theme>.png`; each one is staged beside that directory first, so a failed
copy cannot replace a good image. A failed surface prints `FAILED`, the driver tries the next
surface, and the run exits 1 after the pass.

Every Mac-side VM driver takes `/tmp/omarchy-kids-vm-driver.lock` through `flock`. This includes
the acceptance harness, media driver, and V1/V6 reference drivers. A second driver refuses to
start and names the PID and command holding the lock. Drafting agents do not run the media driver.
It boots the owner, records both current themes, sets the
owner through `omarchy-theme-set` with `OMARCHY_PATH=/usr/share/omarchy`, sets the test kid through
the governed `omarchy-kids-conf` theme writer, runs `omarchy-kids-assert`, and restarts SDDM before
the portal shot. Its EXIT trap restores changed state, restarts SDDM even when the assert step
fails, verifies both test accounts have no seat session, and confirms the greeter.

Time's Up and Wi-Fi need temporary test-kid settings. The driver records whether each theme,
weekday/weekend lights-out value, and Wi-Fi mode is an override. Cleanup restores an override with
`set` and an inherited value with `unset`, so a run never pins a band or parent-theme default. A
failed restore keeps the first saved value until a later cleanup restores it. SIGINT and SIGTERM
run the same cleanup. Inspect the VM after SIGKILL, power loss, or any run whose final cleanup
checks fail.

Every shot polls disposable frames until macOS Vision sees that surface's required text, then
checks the separate release PNG for the same text before moving it into `docs/media/`. Time's Up
also waits on the running QML card's `timesUpReady` IPC result. That result stays false until the
grace document is loaded, the card is visible, and its countdown has rendered a tick. A failed
readiness or release-image check leaves the previous image untouched.

The bar shot requires an already-enabled widget. On the real owner desktop, the driver starts a
temporary kid login through systemd's `PAMName=login`, leaves the screen-time timer running, and
waits for a fresh ledger tick to report that kid as live and unpaused. It then opens the widget
through the owner's `omarchy-shell` IPC and verifies `live` plus `Open Kids Mode` in both the probe
and release frames. Cleanup ends the temporary login and ticks the ledger again. It never edits the
parent's bar, stops status updates, or removes either account's compositor.

The driver does not record the three walkthrough videos in docs/GOAL.md item 3. Those remain a
separate gate-runner recording step using QMP frames and ffmpeg.

## Safety rules

These are AGENTS.md's rules, restated for this specific harness:

- **Never reboot the laptop itself.** Every scenario's `boot_with`/`portal_reset` operates on the
  VM only, through `scripts/vm-run.sh`/`scripts/vm-qmp.sh` run *inside* an `air '...'` ssh call —
  never a bare `reboot`/`shutdown` on `air` itself. The VM is only ever stopped with
  `vm-run.sh stop` (ACPI powerdown), never a hard `quit` — docs/vm.md notes a quit right after a
  disk write has, once, left zero-length files.
- **Test users only.** `LIVE_KID1_*` and `LIVE_WIZARD_KID_*` name test fixtures on a test VM's
  disk, never a real child (AGENTS.md rule 9) — the defaults (`Cy`, `Ada`) are the repo's own
  placeholder names, not anyone's.
- **Nothing here writes to this machine's own `/etc`** (AGENTS.md rule 8): every real write
  happens on the VM, as root, only through `vmroot`'s explicit `sudo`, fed a password on stdin,
  never on argv or in a log line.
- **90-remove's real (non-dry-run) step is gated on `LIVE_DESTRUCTIVE=1`.** Its dry-run half
  always runs and never writes anything; the real half only ever removes the *wizard-made* kid
  (never `LIVE_KID1_ACCOUNT`) — see that scenario's own header comment for why
  `omarchy-kids-remove` itself is never run for real here.

## What each scenario checks

| Script | Covers | What it does |
| --- | --- | --- |
| `05-unit-tests-on-vm.sh` | R-BUILD-3 | Copies this checkout to the VM and runs `test/all` there as a normal user; fails if authd's live password checks or wifi section B still skip. |
| `10-cold-boot-kid.sh` | 2 (second half) | Boots with the test kid's disk password; expects straight into that kid's `omarchy-kids` session. |
| `20-cold-boot-owner.sh` | 2 (first half) | Boots with the owner's disk password; expects the owner's own desktop, no kid session (R-BOOT fail-safe). |
| `30-portal-login-and-finish.sh` | 3 | From the portal: navigate to the kid's tile, log in, triple-tap Super, Finish with the parent password, confirm the portal comes back. |
| `40-time-lights-out.sh` | 5 | Sets `lights_out` in the past, logs the kid in, confirms the Time's Up overlay auto-Finishes with no answer. |
| `50-ask-grant.sh` | 6 | `omarchy-kids-ask time 15` from the kid's session, approved on the spot with the parent password, confirms the ledger reflects the grant. |
| `60-wizard-easy.sh` | 1 | Drives the Easy wizard's fifteen screens over `ssh -tt` with an answers file, Applies for real, cold boots as the kid it provisions. |
| `70-notify-pair-and-approve.sh` | R-NOTIFY-1/4/5 (N-6) | Enables notifications, starts the relay, pairs the scripted `test/live/clients/notify-client.py` through `/v1/pair`, queues a request root-side, approves it from the client's signed decision, and confirms the grant in the ledger. |
| `71-notify-idle-exit.sh` | R-NOTIFY-1 (N-7) | With no kid live and no request open, starts the relay and confirms `ss` shows port 8447 closing within the not-in-use bound. |
| `72-notify-review-decide.sh` | R-NOTIFY-12 | Writes a desktop file root-side and adds its id to the kid's `apps.extra`, scans (approval stamped), changes the Exec, scans again (a review opens), pairs the scripted client, and approves the review from its signed `REVIEW` frame; confirms the review clears and the list is empty of it. |
| `73-notify-act.sh` | R-NOTIFY-13 | Pairs the client, has it grant 15 minutes through the `ACT` frame and confirms the day's grant ledger shows +15, then has it end the session and confirms the frame is accepted (with no session live, the command's own outcome is exit 0; scenario 30 covers a live end). |
| `90-remove.sh` | 8 | `omarchy-kids-remove --dry-run` (always); under `LIVE_DESTRUCTIVE=1`, a real `omarchy-kids-provision remove` of just the wizard kid. |

`05-unit-tests-on-vm.sh` is the answer to a green `test/all` on the Mac that hid four skipped
suites (`test/all`'s own header comment). `test/shell.d/authd-test.sh`'s live-daemon password
checks need a loadable `libcrypt`, and `test/shell.d/wifi-test.sh` section B needs `SO_PEERCRED`
— neither exists on macOS, so both print a `SKIP` line and the only tests of the password verifier
and of the Wi-Fi daemon's authorization boundary never run. The scenario tars the working checkout
(no `.git`, no `test/live/out/`, no `config.env`), unpacks it in `/tmp/omarchy-kids-unit` on the
VM, runs `bash test/all` there over `vm` (the unprivileged owner account — it asserts the uid is
not 0, since root would pass the peer-uid checks for the wrong reason), and greps the captured run
for those two exact `SKIP` lines: either one present is a FAIL, not a pass with an asterisk. The
full remote output lands in `$LIVE_OUT_DIR/05-unit-tests-on-vm.log`. It needs no package
installed, so it boots the VM itself only if it finds it down.

Not covered yet: §8 items 4 (browser walled garden / DoH), 7 (`omarchy update` + a kernel update),
and 9 (changing the parent's login password) — each needs its own scenario and its own care about
what state it leaves the VM in; left for a follow-on issue rather than guessed at here. Scenarios 70
through 73 are **new drafts no gate has run yet** (AGENTS.md rule 11): review them on
the first VM run before trusting their PASS. 70, 72 and 73 share `lib.sh`'s `notify_pair_client`
(enable, start the relay, open a pairing window, pair the client, check the registry) so their setup
cannot drift.

Scenario 05 also runs `shfmt -i 2 -ci -l` over every bash file when the VM has `shfmt` (the Mac
does not), and fails on any file the formatter would change.

## How to add a scenario

1. Pick the next free `NN` (leave gaps between the existing numbers if you expect to insert one
   later — the loop in `test/live/all` just globs `[0-9][0-9]-*.sh` in sort order, no registry to
   update).
2. Start from an existing scenario closest in shape to what you're adding (`10-cold-boot-kid.sh`
   for a boot-and-check; `30-portal-login-and-finish.sh` for anything that logs a kid in first).
3. `source "$DIR/lib.sh"` at the top, same as every other scenario, and end with exactly one call
   to `scenario_result "<script-name-without-.sh>"` — that's what emits the `PASS`/`FAIL` line
   `test/live/all` parses into the report.
4. Use `ok "<label>"`/`fail "<label>"` for each assertion inside the scenario (same contract as
   `test/shell.d`'s own `check()` functions), and `check GOT WANT LABEL` when you're comparing two
   values directly.
5. Every wait should be one of the `assert_*` helpers (a polling loop with a deadline) rather than
   a fixed `sleep`, unless the thing you're waiting on genuinely isn't pollable yet (the ~35s
   before the disk prompt is the one case in `lib.sh` itself — there's no ssh and no QMP query
   that reports "the disk prompt is up").
6. If it needs a screenshot, call `shot "<name>"` and let its own `echo "<name>.png"` reach
   `test/live/all`'s report — don't redirect or re-echo it yourself.
7. If any pure logic in it (index math, string parsing, anything with no ssh call in it) is worth
   testing without the VM, add cases to `test/shell.d/live-lib-test.sh` rather than a new test
   file — that's the one place `test/all`/CI actually exercises this directory.
8. Run the new scenario on its own against the real VM before adding it to a PR, and run it twice
   in a row to confirm it's actually idempotent.

## Known gaps, read before trusting a run

### Quickshell UI iteration

The test laptop's desktop can export `QS_DISABLE_FILE_WATCHER=1`. Clear that variable with
`env -u QS_DISABLE_FILE_WATCHER` when launching a Kids Mode development preview. Quickshell
0.3.1 defaults `Quickshell.watchFiles` to true; a disabled watcher inherited from the desktop
otherwise prevents saved QML edits from appearing. See the [upstream property](https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/).

Verified on the laptop on 2026-09-05 with a separate copy of the installed More apps QML:
changing its visible title updated the screenshot while the Quickshell PID stayed the same.
The title was restored and the preview closed. Use this for iteration; release screenshots
must still show the actual reviewed product and the named live scenario must still pass.

### Existing harness gaps

- **`portal_login`'s navigation math is read from `share/sddm-theme/Main.qml`'s source, not yet
  confirmed live with more than two kid tiles.** `lib.sh`'s own comment on `portal_login` has the
  full reasoning (the Left/Right clamp, the "overshoot Left, then Right to the target index"
  trick) and the citation.
- **`portal_reset` now treats seat0 as the state machine it is, bounded at three rounds: a greeter
  is done once it answers; an empty seat gets an SDDM restart; a session is exited with the clean
  compositor exit (`SwitchToGreeter` fails on 4.0.2 and revoked the laptop's input devices once —
  the same D-Bus call V1 verified, docs/phase1/V1.md).** Verified live on the try-omarchy VM,
  2026-09-26 (issue #21): a clean exit returned the greeter within 5s, a `loginctl
  terminate-session` left seat0 **empty with no greeter at all**, and a restart with an autologin
  in place handed the seat to that session — which is exactly why the old single greeter wait hung.
  Two traps for anything else driving this VM: resolve the Hyprland signature from
  `hyprctl instances -j` rather than that user's `hypr/` directory (it held 18 stale ones, and a
  dispatch at a dead socket prints "Couldn't connect" and *still exits 0*), and a scenario after a
  crashed prior run may still find an orphaned session — `state` (called on most failures) shows it.
- **`50-ask-grant.sh`'s in-session command** (harvesting the launcher process's Wayland/D-Bus
  environment to run `omarchy-kids-ask` "as" the kid) is the same technique docs/ask.md's own
  "Verified live" section used — it hasn't been re-verified against this exact harness script yet.

## Runs so far

- 2026-09-02, first run: 10, 20, 60, 90 passed; 30, 40, 50 failed on the harness's own reset
  and navigation (fixed the same night: clean compositor exit, sorted account order, newest
  Hyprland instance dir).
- 2026-09-03, second full run after the theme, packs, launcher and wizard-look merges: all seven
  scenarios passed in one `test/live/all -k` run.
- 2026-09-03, third full run after the security fixes, the verifier's reader fix and the unit's
  writable paths: all seven passed again.
- 2026-09-03, fourth full run against the structural refactor (shared helpers, dispatchers,
  strict mode): all seven passed.
- 2026-09-03, run 6, `05-unit-tests-on-vm.sh` on its own — the first time `test/all` had been run
  on a VM that already has `omarchy-kids` *installed*. 61 checks in 16 files failed there and
  passed on the Mac, none of them about the code under test: `stat -f '%Lp' … || stat -c '%a'`
  reads GNU coreutils' *filesystem* status and succeeds with junk; and every case that needs a
  command absent (`limine`, `omarchy-theme-color`, the floating-terminal helper, `getent`,
  `lsblk`, `/usr/bin/omarchy-kids-*`) found the real one. `test/shell.d/lib.sh` now owns
  `kids_file_mode` and `kids_base_path` (stubs plus a base toolset, nothing else), and the tests
  build the PATH they claim to have. It also turned up four things that only misbehave on Linux —
  `omarchy-kids-check --live` aborting mid-report on pkcheck's "not authorized" exit status,
  `omarchy-kids-wifi` swallowing its own "no reply" line wherever `socat` is installed,
  `theme_color` handing a themeless account one derived black tile, and `kids_bin`'s `/usr/bin`
  fallback hiding "not installed yet" — all fixed here. Result: `test/all` green on both,
  32 files, 0 FAIL, one skip on the VM (`unlock-hook-test.sh`: no ash/busybox there).
- 2026-09-03, run 7, `test/live/all -k` — all eight scenarios green in one run, on main with the
  day's merges: the suite on Arch (05), the parent's recorded LUKS slot (20 now really lands on
  the owner's desktop, with the seat-session assert), `start-hyprland -- --config` in the kid
  session (30), the panel polish, the two-space reformat, and the review fixes. Three scenario-30
  failures on the way there were all harness assumptions, now code: `portal_reset` waits for the
  owner's autologin, `wait_kid_ready` waits for the launcher before any keystroke, and Finish is
  the preselected button (no Tab).
- 2026-09-03, run 8, the eight scenarios one per invocation (two full `all -k` runs were cut
  off mid-way by the driving tool, not by the VM) — all eight green on main at the end of the
  day: the readable captions, the parent-facing docs, the shfmt gate in scenario 05.
- 2026-09-26, hand probes on the try-omarchy VM (owner-sanctioned dogfooding, **not** a scenario
  run — rule 11 still keeps `test/live/` to the gate runner): the seat behaviour behind
  `portal_reset` was settled by hand because it is the one thing a stub cannot answer — clean exit
  vs `loginctl terminate-session` vs a restart with an autologin in place — and `portal_reset`
  became the bounded seat loop above (#21, `f0bb773`). The greeter-reset helper's false clean exit
  (#134, `6bc5391`) was fixed and stub-tested the same day. The scenarios themselves are unchanged
  and still await a gate-runner pass.
