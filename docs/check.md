# The safety report: `omarchy-kids-check` (SPEC.md R-TRUST-2, R-TRUST-3, R-DESK-2; issue #29)

R-TRUST-2 says `omarchy-kids-check` "runs at the end of the wizard, from the panel, and at every
kid login. Each check names what it proves and what it cannot." This is v2: a read-only report
across nine sections — Accounts, Locks, Boot, Login, PAM, Web, Time, Firmware, and (optionally)
Live tests — that never writes anything and never fixes anything. A FAIL here means "run
`omarchy-kids-assert`" or "ask a grown-up", never "already handled".

v1 (this repo's earlier stub, replaced by this issue) hardcoded a single `KID_USER` account and a
handful of checks against an installer-path layout (`resolved.conf.d`, a single Chromium policy,
`limine.conf`'s `editor_enabled`) that never matched this project's actual architecture —
per-kid accounts, per-band policy files, the LUKS-slot boot chain, the portal, PAM. v2 replaces
all of it.

## What it reuses, and how

`bin/omarchy-kids-assert` already has, and idempotently re-asserts, every lock this package
enforces (`docs/assert.md`'s own lock table). Re-implementing ~20 of those checks a second time
here — the exact trap `docs/assert.md`'s own "Judgment calls" section already flagged
(`group_for_band` "worth revisiting if a third command ever needs it too") — would just be a
second copy to keep in sync forever. Instead, `omarchy-kids-check` **sources**
`bin/omarchy-kids-assert` and calls its `*_ok` functions directly, never a `*_fix`. This works
because of one small addition to that file (its very last lines):

```sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
```

`main` (which calls `assert_one`, which writes by default — see `docs/assert.md`'s own
"`--dry-run` opts out of writing; there is no `--apply`" judgment call) only runs when the file is
executed directly; sourced, it just defines every `*_ok`/`*_fix` function and the
`ETC`/`SHARE`/`HOME_ROOT`/`KIDS_DIR`/`MACHINE_CONF` variables and stops there. `omarchy-kids-check`
sources it from inside a no-argument function (`source_assert`), so `omarchy-kids-assert`'s own
top-level `--quiet`/`--dry-run`/`--help` argument loop — which runs unconditionally, sourced or
not — sees an empty `"$@"` (a function's own positional parameters, not the calling script's) and
does nothing, instead of trying to reparse `omarchy-kids-check`'s own `--json`/`--live`. Every
existing `test/shell.d/assert-test.sh` call (`"$BIN"`, a direct execution) is unaffected: there,
`BASH_SOURCE[0]` and `$0` are the same path.

`lib/time.sh` (the screen-time paths) is sourced directly, the normal way — it has no CLI of its
own to guard against.

One function is duplicated rather than sourced: `detect_luks_device` from
`bin/omarchy-kids-provision`. That file is a script with its own `main "$@"` dispatch
(`add`/`remove`/`list`), not a library — the same reason `docs/assert.md` gives for duplicating
`group_for_band` instead of sourcing all of `omarchy-kids-provision` for one small, stable,
side-effect-free function.

## Sections

### Accounts (per kid)

`exists` (`id`), `no-wheel` (not in `wheel`/`docker` — R-FND-2's "no sudo grant of any kind"),
`no-sudo` (no entry in `/etc/sudoers`/`/etc/sudoers.d` — R-FND-3; WARN, not FAIL, if those files
aren't readable here, e.g. not running as root), `band-group` (`omarchy-kids` plus the band group —
reuses `groups_ok`), `home-noexec` (`findmnt`, live, not just `fstab` — reuses `mount_ok`), `gecos`
(matches the safe passwd fallback — reuses `gecos_ok`, WARN if there's no `getent` on this box at all).

### Locks

Every lock in `docs/assert.md`'s table, one line per lock, in the same order and with the same
lock ids (`fstab:<account>`, `polkit-admin`, `boot-hook`, `limine-snapshots`, ...) — a technical
catalog for cross-referencing against that doc, not narrative. Each line calls the matching `*_ok`
function only; a FAIL points at `docs/assert.md`'s own table for what the lock proves and what its
fix does, rather than repeating that here. The three boot-owned lock checks appear only in trusted
`boot=disk` mode. Portal and invalid mode never inspect the UKI or Limine.

Three rows go beyond the "one line per assert lock" rule (R-NOTIFY-11.2). `lock:devices` and
`lock:relay-away` are the assert locks above (registry modes; the away drop-in), standard shape.
`lock:relay-fence` has **no assert lock behind it**: the relay's `IPAddressAllow`/`IPAddressDeny`
fence lives in the package's own unit file, and assert never rewrites a packaged file (I-7). It is
verify-only — the unit file is present, root-owned, with exactly the packaged allow line and
`IPAddressDeny=any` in its `[Service]` section, and, live and without `--root`,
`systemctl show … -p FragmentPath` names that same file (a full override in `/etc/systemd/system`
shadows it and fails), the effective deny is `any` (systemd reports it as the two catch-all prefixes `0.0.0.0/0 ::/0`, which is accepted), and the effective allow set — over systemd's own
expansion of `localhost`/`link-local`/`multicast`, compared as a set — is exactly the packaged list
plus the CGNAT range if and only if the parent's `away.conf` is there. Absent unit (the package is
not installed) is a WARN. A FAIL means "reinstall `omarchy-kids` and remove any drop-in you did not
write", **not** "run `omarchy-kids-assert`", so this one row says so itself rather than reusing
`lock_check`'s standard text. What it proves: the packaged fence is intact and systemd applies it
(plus the away range only with the parent's consent). What it cannot: that the relay is running,
that the fence is a firewall (it binds one unit's sockets, not the machine), or that someone with
root has not replaced the packaged copy too.

Two more rows, `lock:relay-tls` and `lock:courier-conf`, are the assert locks of the same names
(R-NOTIFY-11.4), standard shape and standard fail text. They prove only that the relay's private key
(`/etc/omarchy-kids/relay/key.pem`, root `omarchy-parents` `0640`, its certificate `0644`, the
directory `0750` with nothing else in it) and the courier's mailbox file
(`/etc/omarchy-kids/courier.conf`, root `0600`, which carries the Gotify token or the ntfy reply
topic) are absent or closed to everyone but root and, for the key, the parent group. Neither row
opens either file: not that the key matches the certificate or the one a device pinned, not that the
token is valid or the server reachable, not that the relay or the courier is running, and not that
nobody read the secret while its mode was wrong. A warn on `lock:relay-tls` is the directory being
unreadable to this run, which is what a run outside `omarchy-parents` sees.

**One exception, not a FAIL:** `face:<account>` (the SDDM avatar icon, issue #39) is a WARN even
in this technical catalog. It is the one lock in the table that isn't a security fence at all —
missing or wrong, a kid still logs in exactly as fenced, just without their picture on the portal
tile. `lock_check_warn` is the same shape as `lock_check`, used for this one lock only.

### Boot

- `mode` always appears. It passes with the trusted `disk` or `portal` value. Missing, unsafe,
  duplicate, or invalid state fails here and runs no mode-specific check.
- Disk mode adds `unlock-hook` (R-BOOT-5): the current UKI's initramfs contains the hook.
  It uses a wider tool chain than
  `omarchy-kids-assert`'s own `boot-hook` lock (which the Locks section above already reuses
  as-is): tries a `lsinitcpio` new enough to analyze a UKI directly, then `objcopy` + `lsinitcpio`
  (the reference method), then `objcopy` + `bsdtar` (libarchive, ships on macOS by default — this
  repo's own dev box has neither `objcopy` nor `lsinitcpio`, both Arch/Linux-specific), then
  `bsdtar` straight on the UKI/ESP path. WARN, not FAIL, if none of the tools exist at all —
  nothing was disproven.
- Disk mode adds `luks-slots` (R-SEC-4, issue #29's new check): every numeric slot named in `luks-slots` is an
  *active* LUKS2 key slot on the device right now, via `cryptsetup luksDump`. LUKS2 reuses freed
  slot numbers (`docs/phase1/V4.md`), so a stale mapping pointing at a slot that was since freed
  and handed to someone else is exactly the failure this catches. WARN if there's no `luks-slots`
  file, no `cryptsetup`, or no LUKS device found (`OMARCHY_KIDS_LUKS_DEVICE` overrides detection,
  same var `omarchy-kids-provision remove` uses).
- Disk mode adds `limine-editor` / `snapshot-entries` (V6, issue #38): reuse `limine_editor_ok` /
  `limine_snapshots_ok` — narrative restatements of the same two locks the Locks catalog already
  lists, kept here too because the issue's own Boot section names them explicitly.
- Portal mode instead reports `no-kid-luks-slots`, `no-mkinitcpio-dropin`, and
  `stock-autologin`. These prove the Kids Mode slot map, active mkinitcpio drop-in, and temporary
  SDDM autologin override are absent. They do not claim that an unrecorded LUKS key belongs to a
  kid or that a stock autologin file must exist.

### Login

`theme-dropin` (the portal theme selection), `theme-conf-user` (lists every provisioned kid —
reuses `portal_conf_ok`), `face:<account>` per kid (same WARN-not-FAIL call as the Locks section's
`lock_check_warn`, for the same reason), and `autologin-dropin`: the per-boot
`zz-omarchy-kids-autologin.conf` should be **gone** by the time anyone runs this — R-BOOT-3's
cleanup unit removes it ~20s after the display manager starts. WARN if it's still there (stale
unless this ran right inside that window), never FAIL — it isn't itself a live security gap, just
worth a grown-up noticing.

### PAM

`parent-unlock:<stack>` for both `sddm` and whichever stack `posture_parent_unlock_lock_stack`
names (`omarchy-lock-password` on Omarchy 4.0.2) — WARN, not the misleading PASS
`parent_unlock_ok` alone would report, when the stack file doesn't exist at all (that function's
own "ok" there means "nothing to disprove", the right call for a *lock*, the wrong one for a
*report* that's supposed to say what it verified).

`faillock-order:<stack>` is a genuinely new check, not a restatement: `parent_unlock_ok` only
confirms the marker and `pam_exec` line are present *somewhere* in the file (`grep -qxF`); it
never re-checks that they still sit in the position `lib/posture.sh`'s own placement rule requires
— before the stack's first `auth` line, or right after a leading `pam_faillock.so ... preauth`
line if there is one. A hand-edit could reorder lines around the marker without removing it,
silently breaking the `[success=done ...]` short-circuit that placement exists for, and no lock in
`omarchy-kids-assert` would ever notice. This does.

### Web

Per existing `/etc/chromium/policies/managed/omarchy-kids-<band>.json`: `mode:<band>` (0640,
reuses `chromium_ok`), `owner:<band>` (group ownership matches the band group — **SKIP, not
FAIL, when not running as root**: every real writer of this file only ever `chown`s
best-effort, which only succeeds as root, exactly `docs/assert.md`'s own reasoning for why its
`chromium-policy` lock treats ownership the same way; a real run of this check is always root
(wizard, panel, pacman hook), at which point the file is already correct by construction — a
non-root dev/test run can't make `chown` true no matter what's "really" wrong on the target, so a
hard FAIL there would be noise about this process's own privilege, not the target's posture), and
`doh:<band>` (`DnsOverHttpsMode: secure`, R-WEB-2).

### Time

`timer`: `omarchy-kids-time.timer` is active, checked live via `systemctl is-active`. **SKIP, not
WARN, under a scratch `OMARCHY_KIDS_ROOT`** — there's no live systemd to ask there, the same gate
`omarchy-kids-assert`'s own `units_ok` uses for its "enabled is not running" live branch, and the
Locks section's `units` lock already covers *enablement* (the part `--root` can check) for the
same timer — there's nothing new a WARN here could honestly add under a scratch root.

`ledger:<account>`: `/var/lib/omarchy-kids/<account>/usage/` exists. WARN, not FAIL, if it doesn't
— `lib/time.sh` creates it lazily, on the first minute actually ticked, so a brand-new kid who
hasn't had a session yet is expected to be missing it.

### Firmware

R-TRUST-3: "a printed parent card; red in the check until marked done in `machine.conf`." A
firmware password lives entirely outside this machine's OS (SPEC.md §5.3: "the wall is the parent
password plus the firmware password") — nothing here can measure whether one is actually set. But
R-TRUST-3's own wording is a two-state "red / not red", not "red / warn forever": once a grown-up
has attested to it (`machine.conf`'s `firmware.card_done=yes`, the same `<category>.<field>` shape
`boot.snapshot_entries` already uses, `docs/conf.md`), this reports **PASS**, with the software
caveat kept in the detail text itself (R-TRUST-2: name what it proves — an attestation, not a
measurement — and what it doesn't). FAIL (the "red") while unset. Skipped entirely before any kid
is provisioned — the whole point of a firmware password is keeping a kid off other boot media,
which doesn't yet apply to a bare install.

Nothing writes `firmware.card_done` yet — reading it is this issue's job; a wizard/panel screen
that sets it (A13c's "Print the parent card", P4's firmware card) is a separate one.

### Live tests (`--live`, root only)

As root, briefly `runuser -u <kid>` for each provisioned kid and confirm, live, not just
configured:

- `sudo -n true` fails (R-FND-3).
- `pkcheck --action-id ... --process "$$"` (`$$` expanded *inside* the `runuser`'d shell, so
  polkit sees that process's own pid — the exact proof method
  `bin/omarchy-kids-session`'s own `check_polkit` uses at real login, `docs/session.md`, since
  `/etc/polkit-1/rules.d` itself is 0750 root:polkitd, unreadable to the kid) refuses both
  `org.freedesktop.NetworkManager.settings.modify` and `org.freedesktop.systemd1.manage-units`
  outright (R-FND-4).
- Writing an executable into `$HOME` and running it fails (`Permission denied`, exit 126 — noexec
  home, R-FND-2). `$HOME`'s own noexec mount is a persistent `/etc/fstab` bind line
  (`lock:fstab:<account>`), not a per-session `pam_namespace` mount, so `runuser` sees it
  correctly — unlike the two checks below.

`/tmp` and `/dev/shm` (issue #41, `live:<kid>:tmp-noexec` / `live:<kid>:shm-noexec`) are **not**
proven through `runuser`: `runuser`'s own PAM stack never opens a `pam_namespace` session, so a
`findmnt` run through it always sees the machine's global `/tmp`/`/dev/shm`, not the kid's private
one, even when the real session (`sddm` or `sddm-autologin`, both `pam_namespace` stacks per
R-FND-2a) is correctly fenced — see "Verified live" below. Instead, in order:

1. **A live session for this kid** (`loginctl list-sessions`, filtered by user): read the session
   leader's *own* `/proc/<pid>/mountinfo` — `bin/omarchy-kids-session`'s `do_start` execs Hyprland
   directly with no intermediate fork, so the leader is Hyprland itself, but any process logind
   considers the leader lives inside the session's real mount namespace, which is all this needs.
   A `tmpfs` at `/tmp`/`/dev/shm` carrying `noexec` is PASS; present but not `noexec` (or no tmpfs
   there at all) is FAIL — the mount table doesn't lie the way `runuser` did.
2. **No live session**: fall back to the kid's last `omarchy-kids-session --check` log
   (`$XDG_RUNTIME_DIR/omarchy-kids/session-<uid>.log`, `docs/session.md`) — its own
   `check=tmp_noexec name="private /tmp noexec" result=PASS|WARN ...` line (that check is a WARN,
   never a FAIL, until R-FND-2a is fully rolled out — see `check_tmp_noexec`'s own comment in
   `bin/omarchy-kids-session`) already answered this from inside a real session, so it's reused
   as-is (PASS stays PASS, WARN stays WARN). The log only ever records `/tmp`, not `/dev/shm`, so
   `shm-noexec` reports SKIP alongside it, pointing back at the `tmp-noexec` line.
3. **Neither**: WARN — "no live session to inspect" — naming the exact commands a parent can run
   (`loginctl list-sessions` to find the session, then `omarchy-kids-session --check` as the kid)
   to get a live answer. `shm-noexec` is a SKIP here too.

Skipped, not faked, when `--live` isn't passed or this process isn't root — the section always
appears, with a line naming why nothing ran.

## `--json`

For the panel and (per the section below) not the wizard. One object:

```json
{
  "generated_at": "2026-09-02T12:00:00Z",
  "verdict": "pass" | "warn" | "fail",
  "exit_code": 0 | 1 | 2,
  "sections": [
    {"name": "Accounts", "checks": [{"id": "account:kid-ada:exists", "status": "pass", "detail": "..."}]},
    ...
  ]
}
```

`status` is one of `pass`/`warn`/`fail`/`skip`; `skip` never affects `verdict`/`exit_code`. Built by
hand (no `jq` dependency — `bin/omarchy-kids-time-ledger` already uses `jq` best-effort for
`status.json`, but this command has to always produce output, including on a box with no `jq` at
all, so it isn't reused here).

## Exit codes

Deliberately not the usual 0-good/nonzero-bad shape — same kind of inversion `docs/assert.md`'s own
"Judgment calls" already documents for that command's `--dry-run` default:

- **0** — every check passed.
- **1** — no FAILs, but at least one WARN ("could not verify", or "worth a grown-up's attention" —
  never on its own a security gap).
- **2** — at least one FAIL.

## Judgment calls

- **Sourcing `omarchy-kids-assert`, not re-implementing its checks.** See "What it reuses, and
  how" above. The sourceable-main guard is the one change made to `bin/omarchy-kids-assert`
  itself for this issue; every existing call to it (direct execution, every test file) is
  unaffected.
- **`detect_luks_device` is duplicated from `bin/omarchy-kids-provision`, not sourced** — small,
  stable, side-effect-free, and `omarchy-kids-provision` is a script with its own dispatch, the
  exact call `docs/assert.md` already made for `group_for_band`.
- **The face icon is a WARN everywhere it appears (Locks and Login), never a FAIL.** It is the one
  lock in this whole report that isn't a security fence — see "Locks" above.
- **`parent_unlock_ok` alone would report a misleading PASS when a PAM stack file doesn't exist at
  all** (its own "ok" there means "nothing to disprove", correct for a *lock's* re-assert
  semantics, wrong for a *report* claiming to have verified something). The PAM section checks
  file existence itself before trusting that function, rather than repeating its raw answer.
- **Web's group-ownership check is a SKIP, not a WARN, when this process isn't root**, and
  **Time's timer-liveness check is a SKIP, not a WARN, under a scratch `OMARCHY_KIDS_ROOT`.** Both
  are facts this process, in this execution context, was never going to be able to check no matter
  what's true on the real target — the same reasoning `docs/assert.md` already gives for its
  `chromium-policy` lock's ownership handling. A WARN implies "checked, found questionable"; SKIP
  says "not checked here" instead, which is the honest thing when the gap is this process's own
  privilege or environment, not the target machine's posture. This is also what makes a fully
  green, exit-0 "clean tree" reachable at all from a non-root test suite (AGENTS.md rule 8) —
  `test/shell.d/check-test.sh`'s own clean-tree fixture is built with this in mind.
- **Firmware is a PASS, not a permanent WARN, once `firmware.card_done=yes`.** An earlier draft of
  this section reported WARN forever past that point (true to "can never be measured"), which
  would have made exit 0 unreachable for *any* real box, defeating the "safe to hand over" verdict
  the whole tool exists to give. R-TRUST-3's own "red / not red" wording reads more directly as
  PASS-with-a-caveat than as a permanent asterisk, so that's what this does — the caveat lives in
  the detail text itself, which is what R-TRUST-2 actually asks for ("names what it proves and
  what it cannot"), not a separate severity tier.
- **The wizard's safety step keeps the root `omarchy-kids-assert` call**, then runs the
  caller-bound `omarchy-kids-session --check-setup` report. That report checks facts available
  before login and explicitly defers the two PAM-private mounts to child login; it does not
  reuse this report's historical-log fallback. See `docs/wizard.md` and `docs/session.md`.
- **`tmp-noexec`/`shm-noexec` ask a live session's own `/proc/<pid>/mountinfo`, never `runuser`
  (issue #41).** `runuser`'s PAM stack has no `pam_namespace`, so a probe run through it can only
  ever see the machine's global `/tmp`/`/dev/shm` — it was structurally incapable of proving the
  thing R-FND-2a actually promises, no matter how the mount really looked in the kid's session
  (see "Verified live" below, and the Live tests section above for why the `$HOME` exec test is
  unaffected). Reading `/proc/<pid>/mountinfo` for a real process inside that session — the
  session leader `loginctl` reports, which `bin/omarchy-kids-session`'s `do_start` makes Hyprland
  itself — asks the kernel's own mount table instead of a process that was never inside the
  private mount namespace to begin with. The `omarchy-kids-session --check` log fallback exists
  for the gap between kid logins (nothing live to read yet, but a recent real answer on file); the
  final WARN exists for a machine that has genuinely never seen this kid log in — R-TRUST-2's own
  "name what it proves and what it cannot," applied to *how* it inspects, not just what it reports.

## Verified live (2026-09-02, QEMU test VM)

`omarchy-kids-check --live` as root on the VM: Accounts and Locks all PASS for three kids; the
firmware card is the one expected FAIL until a parent marks it done. The live `tmp-noexec` test
runs through `runuser`, which does not open a session with `pam_namespace`, so it reports the
global `/tmp` and FAILs even when the real session has its private mount; treat it as a WARN
or read the session's own `omarchy-kids-session --check` log instead (issue #41).

**Update:** issue #41's fix above replaces that `runuser`/`findmnt` probe with the session-leader
`/proc/<pid>/mountinfo` read (live session), the `omarchy-kids-session --check` log (no live
session), or a WARN naming the exact commands to run (neither) — `test/shell.d/check-test.sh`
exercises all three paths against fixture `mountinfo` and session-log files (root-simulated via
`unshare --user --map-root-user`, skipped where that isn't available, e.g. this repo's own macOS
dev box). Re-verifying against a real kid session on the QEMU VM — the false-FAIL this entry
originally recorded should now read PASS — is still open; nothing in this repo runs `--apply` or
provisions kids on a development machine (AGENTS.md rule 8), so that verification happens on the
laptop, not here.
After #41, same VM: `live:kid-cy:tmp-noexec` and `shm-noexec` PASS from the session leader's
mount table, kids without a session get a WARN naming the commands, and the firmware card is the
only FAIL until a parent marks it done.

## "Could not verify" is not a pass (2026-09-03)

`bin/omarchy-kids-assert`'s `*_ok` functions now return 2 for "I could not look" -- see
`docs/assert.md` for the full list and the reasoning (review S11). `lock_check` here honours
that third status: exit 2 becomes a `warn` result rather than a `pass`, so a machine this
command could not actually verify no longer reports green, and `omarchy-kids-check`'s existing
warn handling gives it exit code 1. A lock that genuinely does not hold is still a `fail` and
exit 2, unchanged.

## Source header (moved from `bin/omarchy-kids-check`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-check — v2: the green/red/yellow "is it safe?" report
(SPEC.md R-TRUST-2, R-TRUST-3, R-DESK-2; issue #29). Run at the end of
the wizard, from the panel, and (informally, by a grown-up) at kid
login when omarchy-kids-blocked points at it. Read-only: never
writes anything, never calls a lock's *_fix — see docs/check.md for
the full section list and every judgment call below.

Sections, in order: Accounts, Locks, Boot, Login, PAM, Web, Time,
Firmware, Live tests (only with --live). Each check prints one line —
PASS, WARN, or FAIL — and, per R-TRUST-2 ("names what it proves and
what it cannot"), a detail naming either what it proved or why it
couldn't. A WARN means "could not verify" or "not itself a lock, but
worth a grown-up's attention" — never a security gap on its own.

  omarchy-kids-check [--json] [--live] [--help]

Exit codes (SPEC.md R-TRUST-2's "is it safe?" contract, not the usual
0-good/nonzero-bad shape — same kind of deliberate inversion
docs/assert.md's own "Judgment calls" already documents for that
command's --dry-run default):
  0  every check passed
  1  no FAILs, but at least one WARN
  2  at least one FAIL

Reuses, never re-implements: every lock's own *_ok function from
bin/omarchy-kids-assert (sourced, guarded — see that file's own tail
comment), by way of lib/conf.sh and lib/posture.sh (which assert
itself sources), plus lib/time.sh for the screen-time ledger paths.
Nothing here ever calls a *_fix function — a FAIL here means "run
omarchy-kids-assert", never "let me fix that for you" (I-4's
verify-at-login role is a *check*, not a second copy of assert).

Boot mode and its mode-invariant files are exceptions: `lib/boot-mode.sh` reads the fixed
root-owned `/etc/omarchy-kids/machine.conf`, and the slot map, active mkinitcpio drop-in, and
temporary SDDM override also use fixed production paths. Tests substitute those build-time
constants in a copied tree.
Every path below is overridable for tests, same convention as
bin/omarchy-kids-assert and bin/omarchy-kids-session (this script
builds on both):
  OMARCHY_KIDS_ETC          kid profiles and non-authoritative report fixtures
                            (default /etc/omarchy-kids)
  OMARCHY_KIDS_SHARE        package data root (default /usr/share/omarchy-kids)
  OMARCHY_KIDS_ROOT         scratch prefix for every real machine path this
                            touches indirectly through the sourced
                            omarchy-kids-assert/lib/posture.sh/lib/time.sh
                            (see those files' own headers for the full list)
  OMARCHY_KIDS_HOME_ROOT    scratch prefix for /home/<account> (mount checks)
  OMARCHY_KIDS_UKI          overrides which UKI/initramfs the boot-hook
                            check inspects (same var omarchy-kids-assert uses)
  OMARCHY_KIDS_LUKS_DEVICE  overrides LUKS device auto-detection for the
                            boot:luks-slots check (same var
                            bin/omarchy-kids-provision's "remove" uses)
  OMARCHY_KIDS_PROC_ROOT    prefix for the /proc/<pid>/mountinfo path
                            that check reads (default: /proc; point at
                            a fixture tree of <pid>/mountinfo files in
                            tests, same idea as OMARCHY_KIDS_HOME_ROOT)
```

## Source header (moved from `bin/omarchy-kids-blocked`, issue #49)

Kept for reference; the file itself now carries a short pointer instead.

```text
omarchy-kids-blocked: the full-screen "Ask a grown-up" message shown
by omarchy-kids-session (SPEC.md R-DESK-2) when a fail-closed check
fails before a kid's desktop starts.

This is a placeholder, not the real thing: R-DESK-2 asks for "a
full-screen 'Ask a grown-up' naming the check", and at the point
omarchy-kids-session calls this, Hyprland hasn't started yet -- there is
no compositor, no Wayland surface, nothing graphical to draw into. All
this can honestly do today is print a big message to the tty and hold
it on screen for a while so it's the last thing visible before the
session exits. A real graphical modal (rendered by whatever runs the
portal/greeter, or a tiny standalone compositor client of its own)
is a separate ticket; this script is what that ticket should replace,
not extend.

Usage: omarchy-kids-blocked "<check name>"

Env:
  OMARCHY_KIDS_BLOCKED_SLEEP  seconds to hold the message on screen
                                  before exiting (default 15; tests set
                                  this to 0 so the suite doesn't sit
                                  through it)
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
