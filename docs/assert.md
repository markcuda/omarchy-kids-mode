# Re-asserting locks: `omarchy-kids-assert`

SPEC.md I-4, R-TRUST-5, R-BOOT-5, R-BOOTMODE-6, R-BOOTMODE-11,
R-BOOTMODE-12, R-WEB-1, R-FND-2..6, §5.1.

I-4 says every lock must be re-asserted after updates and verified at every kid login, and
R-TRUST-5 names the two callers: the pacman hook and Omarchy's own post-update hook.
`omarchy-kids-assert` is the one command both call — and the boot unit besides — to put back
anything a package upgrade, a stray edit, or a snapshot rollback silently dropped. It never
*creates* a kid or a machine-level feature that was never provisioned in the first place: for
every check below, "nothing provisioned" means "nothing to assert", not "provision it now". That
job belongs to `omarchy-kids-provision` (`docs/provision.md`), which is also where every writer
this command calls (`lib/posture.sh`) is documented in full; this file only covers what
`omarchy-kids-assert` checks, when, and what it does when a check fails.

Before any check or repair, assert validates `boot=disk|portal` through the trusted reader in
`lib/boot-mode.sh`. Missing, unsafe, duplicate, or invalid state exits `1` before mutation — unless
no kid is provisioned, where there is nothing boot-related to lock yet: then assert falls
through to the no-kids path below, still asserts the machine-level `units` lock (issue #46), and
lets that decide the exit code, because the pacman hook runs assert on a box that has never had a
kid and must not fail the transaction. A kid present with an unreadable mode stays the refusal.
Assert then repairs mode-independent locks.

Before the boot section, assert waits up to five seconds for the root-owned
`/run/omarchy-kids/boot-mode.lock`, reads the mode again while holding it, and keeps the lock through
every UKI and Limine check and repair. A mode writer therefore cannot land between the read and a
boot action. If the lock cannot be acquired, assert reports `skip boot-locks:unavailable`, performs
no UKI or Limine access, and returns the result of its non-boot repairs. Portal mode reports
`skip boot-locks:portal` and performs no boot access. With zero kids, assert checks `units`, prints
the no-kids notice in normal output, and exits without a boot-lock status.

Every supported mode writer must use the same lock. The current
`omarchy-kids-conf machine set boot` writer does. Ticket #98's transition must acquire it before
its first authoritative mode read or boot-artifact mutation and hold it through convergence, the
final mode write, and readback. It must call the already-locked setter logic directly instead of
starting a second `omarchy-kids-conf` process. A root process that edits `machine.conf` directly
outside the supported command can bypass this contract, just as root can bypass the other locks.
The package upgrade migrator also holds this lock through its mode read, any write and readback,
and legacy drop-in restoration or removal.

The lock FD remains open in child processes. If a boot repair leaves a descendant running after
its direct command exits, that descendant keeps the critical section until it exits. This is
intentional: another mode transition must not overlap work started by the protected repair.

## When it runs

| Caller | How | Flags |
| --- | --- | --- |
| `pacman/omarchy-kids.hook` | After *every* pacman transaction (install, upgrade, or remove of any package) | `--quiet` |
| `systemd/omarchy-kids-assert.service` | At boot, `Before=display-manager.service`, `After=local-fs.target` | `--quiet` |
| Omarchy's own post-update hook | `omarchy hook install post-update omarchy-kids-assert` (a line to add to that hook's config, not something this repo runs — see "Omarchy's post-update hook" below) | `--quiet` |
| A parent, from the panel or a terminal | Directly | none, or `--dry-run` to preview |
| `omarchy-kids-session`'s R-DESK-2 preflight | Does **not** call this command — it checks the same facts read-only, at login, and fails closed (full-screen "Ask a grown-up") rather than trying to fix anything mid-login | — |

The five-second limit applies only while assert waits to enter the boot section. The pacman hook's
total runtime is unbounded: non-boot repairs and disk-mode tools such as `mkinitcpio` have no
timeout. This is deliberate because stopping a lock repair or initramfs rebuild midway can leave
the transaction with stale enforcement or an incomplete boot artifact. Pacman therefore waits
for those commands to finish or fail.

### Omarchy's post-update hook

Upstream Omarchy ships a mechanism for third-party packages to run something after `omarchy
update` finishes, independent of pacman's own per-transaction hook. Wiring this repo's package
into it is one line, added to that hook's install step (not part of this issue's deliverable —
recorded here so packaging picks it up):

```sh
omarchy hook install post-update omarchy-kids-assert
```text

This is a **note**, not something `omarchy-kids-assert` itself runs or depends on: the pacman
hook alone already satisfies R-TRUST-5 for every package transaction, `omarchy update` included.

## The lock list

One line per lock, `<status> <lock-id>`, status one of `ok` / `fixed` / `FAIL` / `skip`
(`would-fix` under `--dry-run`, see below). Per-kid locks run once for every account under
`/etc/omarchy-kids/kids/*.conf`; machine-level locks run once per invocation, after every kid.

### Per kid (`<account>` from the profile filename)

| Lock id | Checks | Fix |
| --- | --- | --- |
| `fstab:<account>` | The exact `/etc/fstab` bind line for this account's home (R-FND-2) | `lib/posture.sh`'s `posture_add_fstab_line` (already idempotent) |
| `mount:<account>` | The home is *actually* mounted `noexec,nosuid,nodev` right now, via `findmnt`, not just that `fstab` says it should be | `mount --bind` (only if not already a mountpoint) then `mount -o remount,bind,nosuid,nodev,noexec` |
| `namespace:<account>` | Both `/etc/security/namespace.conf` lines for `/tmp` and `/dev/shm`, using pam_namespace's `~<account>` exclusion syntax (R-FND-2a) | `posture_add_namespace_lines` |
| `accountsservice:<account>` | `/var/lib/AccountsService/users/<account>` matches exactly (R-LOGIN-3) | `posture_write_accountsservice` |
| `gecos:<account>` | The passwd GECOS field (read via `getent passwd`) matches the safe fallback: the exact profile name unless it contains passwd's `:` delimiter, then empty. "ok" if this box has no `getent` at all | `usermod -c "<fallback>" <account>` |
| `face:<account>` | `/usr/share/sddm/faces/<account>.face.icon` is byte-for-byte the profile's avatar SVG (R-LOGIN, issue #39 — SDDM's `UserModel` reads the avatar from this path, not from AccountsService's `Icon=` key; `docs/portal.md` has the full `UserModel.cpp` citation) | `posture_write_face_icon` |
| `groups:<account>` | Supplementary groups are exactly `omarchy-kids` and the account's band group (`omarchy-kids-3-5`/`6-8`/`9-12`/`13plus`); unrelated groups such as `wheel` or `docker` fail the lock | `usermod -G` replaces the supplementary list while preserving the primary group |
| `theme:<account>` | The account's own `.../current/theme.name` matches the profile's `theme` override (issue #53, `docs/theming.md`). "ok" (nothing to fix) if the profile carries no `theme` override at all — a box provisioned before issue #53, or a parent with no theme to copy at provision time | `lib/theme.sh`'s `theme_apply_for` — the same writer `omarchy-kids-conf set <kid> theme <name>` uses |
| `launcher-map:<account>` | `/etc/omarchy-kids/launchers/<account>.json` is mode 0644 and exactly matches the root-derived id-to-argv map | `lib/launcher-map.sh` rebuilds it atomically from the profile, pack, allowlist, and system desktop entries |
| `session-manifest:<account>` | `/etc/omarchy-kids/sessions/<account>.json` is a current, root-owned 0644 manifest rendered from the profile and launcher map (R-MANIFEST-7) | `lib/session-manifest.sh` rebuilds it atomically; a failed rebuild preserves the last valid document and reports `FAIL` |

### Machine-level (once per run, only while at least one kid is provisioned — except `units`, which is checked even with zero kids; see below)

| Lock id | Checks | Fix |
| --- | --- | --- |
| `polkit-admin` | `/etc/polkit-1/rules.d/40-omarchy-kids.rules` names the parent from `machine.conf` (R-FND-3) | `posture_write_polkit_admin_rule` |
| `polkit-deny` | `/etc/polkit-1/rules.d/41-omarchy-kids-deny.rules` (R-FND-4) | `posture_write_polkit_deny_rule` |
| `sddm-theme` | `/etc/sddm.conf.d/zz-omarchy-kids-theme.conf` selects the portal (`[Theme] Current=omarchy-kids`, R-LOGIN, issue #14) | `posture_write_sddm_theme_dropin` |
| `portal-conf` | `/usr/share/sddm/themes/omarchy-kids/theme.conf.user` matches exactly, rebuilt from every provisioned kid's profile plus `machine.conf`'s `parent=` and the `omarchy-parents`/`wheel` parent allowlists (R-LOGIN, issue #39/#100 — SDDM's own `ThemeConfig::setTo()` loads this file automatically, `docs/portal.md` has the citation; replaces an earlier `portal.json` + `sddm.service` XHR drop-in design, dropped because that drop-in only took effect after a `systemctl restart sddm` that re-fires the owner's stock autologin on a live machine) | `posture_write_portal_conf` |
| `pam:sddm`, `pam:systemd-user` | The `pam_namespace` marker + line in `/etc/pam.d/sddm` and `/etc/pam.d/systemd-user` (R-FND-2a) | `posture_ensure_pam_namespace`, seeding from `/usr/lib/pam.d` when needed |
| `parent-unlock:sddm`, `parent-unlock:omarchy-lock-password` | The parent-unlock marker + `pam_exec.so … omarchy-kids-parent-auth` line (fixed `[success=done default=ignore]` control), anchored on the stack's own first non-comment `auth` line — after it if that line is itself a leading `pam_faillock.so … preauth` line, else before it (R-SEC-2, R-SEC-3; `docs/authd.md`; `lib/posture.sh`'s own header comment has the full placement rule, confirmed against a real Omarchy 4.0.2 box). `omarchy-lock-password` is the only lock-screen stack Omarchy 4.0.2 actually writes — there is no `hyprlock` PAM service on that box; an earlier version of this guessed one and fell back to it, confirmed wrong and removed. "ok" if the stack file doesn't exist at all — nothing to disprove, same shape as `boot-hook` below | `posture_ensure_parent_unlock_line`; **fails** (reports `FAIL`, not `fixed`) if the stack exists but has lost its anchor line — this command never reconstructs a vendor PAM stack from nothing, only the one line it owns |
| `getty:tty2` .. `getty:tty6` | Each unit is masked — a symlink to `/dev/null` at `/etc/systemd/system/getty@ttyN.service` (R-FND-5), read directly rather than shelled out to `systemctl` | `systemctl mask getty@ttyN.service` |
| `units` | The package's units are enabled: `omarchy-kids-boot-login`, its cleanup unit and `omarchy-kids-assert` in `multi-user.target.wants`, `omarchy-kids-authd.socket` and `omarchy-kids-wifid.socket` in `sockets.target.wants`, `omarchy-kids-time.timer` and `omarchy-kids-ask-collect.timer` in `timers.target.wants` (R-BOOT-3, R-SEC-2, R-WIFI-2 — issue #26 added the second socket; R-ASK-1..3 — issue #25 added the timer), the list itself shared with `bin/omarchy-kids-wizard`'s own Apply-time `enable --now` via `lib/kids.sh` (issue #46). **Runs even with zero kids provisioned** — unlike every other lock in this table — since it's machine-level, not per-kid: a fresh install before the first kid, or right after `omarchy-kids-remove` disables these again, still needs them back so the *next* wizard run's A2 (`docs/authd.md`) and Apply both work; without the first the owner's stock autologin also wins every boot | `systemctl enable` of the whole list, then (on a live system, not under `--root`) `systemctl start` of the sockets and timers |
| `hyprland-configs` | Every `*.lua` under `/usr/share/omarchy-kids/hyprland` is byte-identical to its copy under `/etc/omarchy-kids/hyprland` (R-DESK-1) | `omarchy-kids-session --install-configs` |
| `chromium-policy:<band>` | *Only for policy files that already exist* — `/etc/chromium/policies/managed/omarchy-kids-<band>.json` is mode `0640` (R-WEB-1) | `chmod 0640`; group ownership (`root:omarchy-kids-<band>`) is attempted best-effort and never decides ok/fixed/FAIL (see "Judgment calls") |
| `boot-hook` | **Disk mode only.** If `/usr/lib/initcpio/hooks/omarchy-kids-unlock` is present, the current UKI's initramfs contains the hook (R-BOOT-5), via `objcopy -O binary --only-section=.initrd <uki> img && lsinitcpio img \| grep omarchy-kids-unlock` | `mkinitcpio -P` |
| `limine-editor` | **Disk mode only.** Limine's editor is disabled when Limine is present (V6, issue #38) | Atomically sets `editor_enabled: no` in `/boot/limine.conf` |
| `limine-snapshots` | **Disk mode only.** If `/etc/default/limine` exists, `boot.snapshot_entries` (`machine.conf`, docs/conf.md) selects whether Kids Mode hides snapshot entries (V6, issue #38) | Atomically sets or removes `MAX_SNAPSHOT_ENTRIES=0`, preserving the prior value, then runs `limine-snapper-sync` when installed on a real root |
| `boot-locks:portal` | **Portal mode only.** States that assert deliberately did not inspect or repair UKI or Limine state (R-BOOTMODE-6) | None; reported as `skip`, never `ok` |
| `boot-locks:unavailable` | The boot-mode transition lock failed its safety checks or was not available within five seconds | None; boot checks and repairs are skipped for this run and the line remains visible under `--quiet` |

## Exit codes

- **0** — every lock is (or now is) fine, or no kid is provisioned and the machine-level `units`
  lock is (or now is) fine.
- **1** — the trusted boot mode is unreadable while a kid is provisioned, or at least one selected
  lock could not be fixed. A busy transition lock does not add a failure; it skips only the boot
  section. One bad non-boot lock does not stop later checks.

`--quiet` prints `fixed`/`FAIL` lines and the exceptional `skip boot-locks:unavailable` line. It
suppresses `ok`, the expected portal skip, and the no-kids notice; the pacman hook and boot unit
both use it. Without `--quiet`, an all-clear run still prints one `ok` line per lock, and a no-kids
run prints one line explaining why it skipped everything else — after still asserting `units`
(see above), which is machine-level, not per-kid, and runs either way. `--dry-run` reports what
*would* change (`would-fix` instead of `fixed`) and writes nothing at all.

## `file_stat` tries GNU `stat` first (issue #49 live fix)

`lib/kids.sh`'s `file_stat FMT FILE`, used by several locks below and by `lib/check-web.sh`, is a
portable `stat(1)` wrapper. It tries the GNU form first, then falls back to BSD's. A BSD-first
order silently misbehaves on the real target: Linux's `stat -f` means "filesystem status", not
BSD's "format" flag, so the fallback path was quietly re-"fixing" an already-correct lock on
every single run — found live 2026-09-02, fixed by trying GNU first everywhere this helper is
used. `FMT` is always a GNU format letter (`a`/`G`/`i`/`u`); the BSD translation lives inside the
function, not at each call site.

## Judgment calls

- **`--dry-run` opts out of writing; there is no `--apply`.** Every other command in this repo
  defaults to `DRY_RUN=1` (AGENTS.md rule 8) and needs `--apply`/`DRY_RUN=0` to act for real. This
  command inverts that on purpose: it is the thing the pacman hook and the boot unit call with no
  flags but `--quiet`, and the entire point of R-TRUST-5 is that it self-heals without anyone
  passing a flag. Scratch roots are explicit root-side test seams; no kid-facing command reads
  them from its environment.
- **`group_for_band` is duplicated from `bin/omarchy-kids-provision`**, not sourced or moved into
  `lib/`. It is a stable, four-line, pure mapping (also documented in `docs/packaging.md`'s group
  list); `omarchy-kids-provision` is a script with its own `main "$@"`, not a library, so sourcing
  it to reuse the one function would run its whole CLI. Extracting it into `lib/` instead was
  considered and rejected as more churn than a fifth issue justifies for four lines; worth
  revisiting if a third command ever needs it too.
- **Group membership (`groups:<account>`) has no `lib/posture.sh` writer to reuse.**
  `omarchy-kids-provision` sets it once via `useradd -G` at account creation and never touches it
  again, so unlike every other per-kid lock here, this one is implemented directly in
  `bin/omarchy-kids-assert` rather than reusing an existing idempotent function, per the issue's
  own `usermod -G` exact-allowlist requirement.
- **Getty masking is checked as a symlink, not via `systemctl is-enabled`.** A masked unit *is* a
  symlink to `/dev/null` at the unit's path — that's the whole mechanism, and it's what
  `systemctl --root=DIR mask` itself does (a pure filesystem operation; `--root` never talks to a
  live systemd). Reading that symlink directly needs no `systemctl` at all and matches how every
  other lock here checks state (file content), reserving the stubbed `systemctl` call for the fix
  path only, same division `omarchy-kids-provision` already uses for masking.
- **Chromium policy files: mode only, ownership best-effort.** This mirrors
  `docs/provision.md`'s own stated reasoning for its writers: a real run is always root (the
  pacman hook, the boot unit, or a parent's polkit-elevated action), at which point `chown` always
  succeeds anyway; a `chown` failure in a non-root context (every test on this repo's dev machine,
  per AGENTS.md rule 8) is expected and silently ignored rather than turned into a `FAIL` that
  would make the test suite red on a laptop that was never supposed to run this as root in the
  first place. `chmod`, which *does* work as the file's own owner, is what ok/fixed/FAIL is based
  on.
- **`parent-unlock:*` can report `FAIL` forever if a PAM stack's own leading `auth` line is
  gone**, e.g. someone deletes `/etc/pam.d/sddm` outright (`test/shell.d/assert-test.sh` exercises
  exactly this). `posture_ensure_pam_namespace`'s own fix only ever restores the one
  `pam_namespace` session line it owns, never a full vendor stack, so once the anchor line is gone
  there is nothing left for `posture_ensure_parent_unlock_line` to insert before/after either —
  that's a human/package-reinstall problem, not one this command can self-heal, and it says so
  with `FAIL` rather than silently reporting `ok` for a lock it can't actually verify.
- **The Chromium policy and hyprland-config locks never create files that don't already exist.**
  No writer for `/etc/chromium/policies/managed/omarchy-kids-<band>.json`'s *content* exists in
  this repo yet (confirmed by grep before writing this: `bin/omarchy-kids-session-start` reads
  the path, nothing writes it) — that is a separate issue's deliverable (R-WEB-2/R-WEB-3). This
  command only fixes the mode of a file that's already there, exactly as the issue's own wording
  says ("if they exist").
- **`OMARCHY_KIDS_UKI`** is a new env var, not in the issue's original list
  (`OMARCHY_KIDS_ETC`/`OMARCHY_KIDS_SHARE`/`OMARCHY_KIDS_ROOT`), for the same reason
  `omarchy-kids-provision`'s `OMARCHY_KIDS_HOME_ROOT` isn't in R-FND-2's either: `objcopy`/
  `lsinitcpio` need a real path to act on, even a scratch one, and no existing env var names a
  UKI file. Without it (and without a real `/boot/EFI/Linux/*.efi`, i.e. on this dev machine),
  the first match under `$OMARCHY_KIDS_ROOT/boot/EFI/Linux/*.efi` is used instead; if neither
  exists there is nothing to check and `boot-hook` reports `ok` (fail-safe, matching I-9's stance
  elsewhere in this repo: absence of evidence is not treated as a broken lock).
- **`getty@ttyN.service` and the Chromium policy directory are also read under
  `OMARCHY_KIDS_ROOT`**, even though the issue's own env-var list only names `/etc/polkit-1`,
  `/etc/security`, `/etc/pam.d`, `/etc/fstab`, and `/var/lib/AccountsService` (`lib/posture.sh`'s
  header). Same reasoning as `OMARCHY_KIDS_HOME_ROOT` in `docs/provision.md`: these are more real
  machine paths this command has to act on from a non-root scratch tree, and `OMARCHY_KIDS_ROOT`
  is already the established "everything under `/etc` and `/var` this feature touches" prefix, so
  extending its reach here (rather than inventing yet another env var) keeps the surface small.
- **One line per file, not one line per feature, for `getty` and `chromium-policy`.** The issue's
  prose groups "getty@tty2..6 masked" as a single bullet and "the per-band Chromium policy files"
  as another, but reporting (and fixing) each unit/file as its own lock line makes the "delete
  each lock in turn, expect exactly that lock to report fixed" test meaningfully check that a
  broken `tty4` mask, say, doesn't get lost inside a coarser "getty" line, or reported as fixed
  when only `tty2` actually needed it.
- **`gecos:<account>` reports `ok` (never `FAIL`) when `getent` doesn't exist at all**, same
  reasoning as `docs/provision.md`'s own note on `lsblk` not existing on this repo's macOS dev
  machine: there's nothing to read the field back with, so there's nothing to disprove. A real
  Omarchy box always has `getent` (it's part of glibc), so this only ever matters here, never in
  production.
- **`portal-conf` replaces an earlier `sddm-xhr` + `portal-json` pair of locks.** That design
  wrote a separate `/etc/omarchy-kids/portal.json` and a systemd drop-in on `sddm.service` meant to
  let `Main.qml` read it via `XMLHttpRequest`; dropped once testing found the drop-in only takes
  effect after `systemctl restart sddm`, which on an already-booted, already-logged-in machine
  re-fires the owner's stock autologin — not an acceptable cost for a display-name/avatar polish
  fix. `portal-conf` re-asserts `theme.conf.user` instead, which SDDM's own `ThemeConfig` loads
  automatically (`docs/portal.md` has the `ThemeConfig::setTo()` citation) — no drop-in, no
  restart-triggered autologin risk.
- **`portal-conf` is machine-level but derived per-kid** (every provisioned kid's profile feeds
  into the one file), unlike every other machine-level lock in the table above, which is either a
  fixed rule or reads only `machine.conf`. It's still checked once per run, after the per-kid
  loop, because the file itself is one file, not one per kid — same shape `luks-slots` uses in
  `omarchy-kids-provision`, just read back here instead of written incrementally.
- **`face:<account>` copies a real file (`cmp -s`), not a text-content match** — the only
  per-kid lock here that isn't `posture_install_if_changed`-based, since an SVG being copied
  byte-for-byte matters more than the text-normalization that helper does (a trailing-newline
  difference is invisible in a config file, not in image bytes). `posture_write_face_icon`'s own
  header comment in `lib/posture.sh` has the full reasoning and the `UserModel.cpp` citation for
  why this file, not AccountsService's `Icon=`, is what needed fixing.

## Live findings folded back into the locks (2026-09-02)

- `pam:sddm-autologin`: a cold boot with a kid's disk password logs the kid in through SDDM's
  autologin PAM stack, not `sddm`, so the private `/tmp` and `/dev/shm` were missing on that
  path until the namespace line was added there too (the session's mount table now shows both
  as tmpfs with `noexec`).
- `parent-group`: the owner must be in `omarchy-parents` to read `/run/omarchy-kids/status.json`.
- `units`: enabled is not running; sockets and timers are started on a live system.
## Two fixes from the 2026-09-03 review

`limine-editor` was nested inside the `if [[ -f "$HOOK_FILE" ]]` guard -- indented as though it
were outside it, which is how it survived review -- so `editor_enabled: no` was asserted only on
machines that already had the early-boot unlock hook. The box without the hook is exactly the
box where an unlocked Limine editor lets a kid append `init=/bin/bash` and get a root shell
(review S5), so the assertion is machine-level now, run whether or not the hook exists.
`test/shell.d/assert-test.sh` moves the hook file away and expects `limine-editor` to still be
reported. The same section's writers (`limine_editor_fix`, `limine_snapshots_fix`) also stopped
doing `cat "$tmp" > "$f"` on the bootloader config: a truncate-then-write there leaves an
unbootable machine if the power goes at the wrong moment, so both now write a temp file in the
same directory and rename over the target, like every other writer in this repo.

A `*_ok` function's exit status is a three-way answer now, not a boolean: 0 is "this lock
holds", 2 is "I could not look" -- the tool is missing, or the file the lock lives in does not
exist on this box -- and anything else is "it does not hold". A can't-look reports `warn` and
attempts no fix, and `bin/omarchy-kids-check` turns the same signal into its own non-zero "not
fully verified" verdict. Review S11's complaint was that seven checks returned *ok* when they
could not see anything (`gecos` with no `getent`, `parent-unlock` with no PAM stack file,
`parent-group` with no `parent=`, `hyprland-configs`, `boot-hook`, `limine-editor`,
`limine-snapshots`), which is the opposite of AGENTS.md rule 4.

The `groups:<account>` lock compares supplementary groups against the exact allowlist
`omarchy-kids` plus the profile's band group. Repair uses `usermod -G`, preserving the primary
group while removing extras such as `wheel` or `docker`; `--dry-run` reports the repair without
writing it.

## Source header (moved from `bin/omarchy-kids-assert`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-assert — re-asserts every Kids Mode lock idempotently
(SPEC.md I-4, R-TRUST-5, R-BOOT-5, R-WEB-1, R-FND-2..6, §5.1). Called by
/usr/share/libalpm/hooks/omarchy-kids.hook after every pacman transaction,
by systemd/omarchy-kids-assert.service at boot, and (per docs/assert.md)
by Omarchy's own post-update hook -- see that doc for the full lock list,
when each caller runs it, and the exit codes.

Unlike most other omarchy-kids-* commands, this one applies fixes for
real *by default*: it exists precisely so an automatic caller (the
pacman hook, the boot unit) never has to pass --apply for a lock to
actually be restored. `--dry-run` opts into preview-only mode instead
(see "Judgment calls" in docs/assert.md for why this is the one command
that inverts AGENTS.md rule 8's usual DRY_RUN=1 default). Every real
path is still overridable so tests -- and a --dry-run reviewed before
trusting it -- can point the whole run at a scratch tree, and nothing
under this dev checkout's real /etc, /var, or /home is ever touched by
test/shell.d/assert-test.sh:
  OMARCHY_KIDS_ETC        default /etc/omarchy-kids   (kid profiles, machine.conf)
  OMARCHY_KIDS_SHARE      default /usr/share/omarchy-kids  (hyprland/*.lua and avatars source)
  OMARCHY_KIDS_ROOT       scratch prefix for every real machine path this
                          touches: /etc/polkit-1, /etc/security, /etc/pam.d,
                          /etc/fstab, /var/lib/AccountsService,
                          /etc/sddm.conf.d, /usr/share/sddm/themes/omarchy-kids
                          (theme.conf.user), /usr/share/sddm/faces
                          (lib/posture.sh), plus /etc/systemd/system
                          (getty masks), /etc/chromium/policies/managed
                          (kids policy files), /usr/lib/initcpio/hooks
                          and /boot (the boot hook)
  OMARCHY_KIDS_HOME_ROOT  scratch prefix for /home/<account> itself, for the
                          findmnt/mount calls this makes (matches
                          omarchy-kids-provision's own env var of the same name)
  OMARCHY_KIDS_UKI        overrides which UKI/initramfs image R-BOOT-5 checks,
                          instead of the first /boot/EFI/Linux/*.efi found
shellcheck disable=SC2329 # every *_ok/*_fix below is invoked indirectly through assert_one's "$check" "$@" / "$fix" "$@"
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
