# Provisioning: `omarchy-kids-provision add` / `remove`

R-FND-2..6, R-SEC-3..5, R-LOGIN-3, R-DESK-1, R-BOOTMODE-3,
R-BOOTMODE-4, R-BOOTMODE-11, Appendix B.

`omarchy-kids-provision` is the one command that turns "a display name and a band" into a real
Unix account a kid can log into, and the one command that turns it back into nothing. Everything
it writes is listed below, in the order it writes it. `lib/posture.sh` holds the actual writers
(polkit rules, pam_namespace lines, the fstab line, the AccountsService pin) as small, idempotent
functions; the luks-slots parsing and rewrite live in `lib/kids.sh` instead (shared with
`bin/omarchy-kids-remove`'s "Remove Kids Mode", and with `omarchy-kids-conf machine set parent`'s
own use of it, docs/conf.md); `bin/omarchy-kids-provision` is the sequencing and the policy
(bands, passwords, LUKS).

`DRY_RUN=1` is the default everywhere (AGENTS.md rule 8): every action below is printed, not
run, unless `--apply` is passed or `DRY_RUN=0` is set. The few things that only *decide* what to
do — the slug collision check, LUKS device selection, reading `luks-slots` and
`machine.conf` — always happen for real, dry run or not, since reading never changes anything.
Before reading a password or changing state, `add` and `remove` read `boot=` through the fixed-path
trusted reader in `lib/boot-mode.sh`. Missing or unsafe mode state stops the command with exit 1.

## `add <display-name> --band <band> [--avatar ID] [--password-stdin | --no-password] [--parent-password-stdin | --parent-password-fd N] [--luks-device DEV]`

**Refused before anything is created or written: a symlink under the new kid's home.** A home can be
one an earlier account left behind (`remove --keep-home`), and a kid who has had a shell can plant a
link there. `add` resolves the account name, checks every path it is about to write under that home
(`kid_home_writable_paths` in `bin/omarchy-kids-provision`) and exits `2` naming the link, rather
than following it — root never writes or chowns through a kid-planted path (AGENTS.md rule 9). The
message says the account is gone but its home is still there; removing the leftover home (or just
the link) and adding again is the remedy. The same step seeds one app's own config for the new kid
(`docs/apps.md`, "Per-app config we seed at provisioning: GCompris").

1. **Account name** (Appendix B.1): `omarchy-kids-conf slug "<display-name>"` gives the base
   `kid-<slug>`; if a profile already exists for it (`$OMARCHY_KIDS_ETC/kids/<slug>.conf`), or
   `getent passwd` already knows it, `-2`, `-3`, ... is appended until one is free.
2. **A LUKS key slot** (R-SEC-4), only in `boot=disk` when a password was given. This runs before
   account creation. Disk mode requires an encrypted device (`--luks-device`, or the first
   `crypto_LUKS` device from `lsblk`) and the parent's passphrase. The command rejects a kid
   password that already unlocks the device, captures the occupied slots from `luksDump`, runs
   `luksAddKey`, then diffs a second `luksDump` to find the new slot number. This happens under the
   same root-owned slot-map lock removal uses. Only then does it atomically add the mapping. If the
   map write fails, it tries to kill the new slot and exits
   without creating the account. If that rollback also fails, the error names the exact slot for
   manual removal. Portal mode makes no LUKS call and rejects `--luks-device`,
   `--parent-password-stdin`, and `--parent-password-fd`.
3. **The account itself** (R-FND-2): `useradd -m -s /bin/bash -G omarchy-kids,<band-group>
   <account>`. Band groups: `omarchy-kids-3-5`, `omarchy-kids-6-8`, `omarchy-kids-9-12`,
   `omarchy-kids-13plus` (docs/packaging.md).
4. **Password** (R-SEC-3): with `--password-stdin`, the kid's password is the first line of
   stdin, piped straight into `chpasswd` as `<account>:<password>` — never on argv, never
   logged. With `--no-password` (3-5 only; refused for every other band, checking
   `password_optional` from `omarchy-kids-conf band <band>`), the account is locked instead
   (`usermod -L`).
5. **Display-name fallback** (R-LOGIN, issue #39): `usermod -c "<display-name>" <account>` sets
   passwd GECOS when the name has no colon. A colon delimits passwd fields, so colon-bearing names
   use an empty GECOS field. The root-owned portal config in step 15 keeps the exact profile name
   and wins over SDDM's `realName` role. Re-asserted as the `gecos:<account>` lock
   (`docs/assert.md`).
6. **Home, bind-mounted `nosuid,nodev,noexec`** (R-FND-2): a line is appended to
   `/etc/fstab` — `/home/<account> /home/<account> none bind,nosuid,nodev,noexec 0 0` — and then
   `mount -o remount,bind,nosuid,nodev,noexec /home/<account>` applies it immediately, without
   waiting for the next boot.
7. **The profile** (Appendix B): `omarchy-kids-conf set <account> name|avatar|band|password|onboarded ...`
   writes `name`, `avatar`, `band`, `password` (`set` or `none`), `onboarded=no` to
   `$OMARCHY_KIDS_ETC/kids/<account>.conf`.
8. **Polkit** (R-FND-3, R-FND-4): `/etc/polkit-1/rules.d/40-omarchy-kids.rules` (admin identity
   `["unix-user:<parent>"]` for `omarchy-kids` members — the parent's name comes from `parent=`
   in `$OMARCHY_KIDS_ETC/machine.conf`, written by machine setup before any kid exists) and
   `/etc/polkit-1/rules.d/41-omarchy-kids-deny.rules` (outright `polkit.Result.NO`, no prompt, for
   NetworkManager settings-modify, udisks2 mount/unlock/loop-setup, systemd1 manage-units,
   packagekit, flatpak, and any `org.omarchy.*` action). Both are written once and are
   idempotent: a second kid's `add` compares content and leaves an unchanged file alone, so
   there's never a duplicate rule block.
9. **Text consoles masked** (R-FND-5): `systemctl mask getty@tty2.service` .. `tty6.service`.
   Also idempotent (masking an already-masked unit is a no-op).
10. **A private noexec tmpfs for `/tmp` and `/dev/shm`** (R-FND-2a, issue #10 finding c): two
   lines appended to `/etc/security/namespace.conf` —
   `/tmp /tmp/kids-inst/ tmpfs:mntopts=nosuid,nodev,noexec ~<account>` and the same shape for
   `/dev/shm` — the fourth field is an exclusion list when bare, while `~<account>` selects only that kid for polyinstantiation — plus, in
   `/etc/pam.d/sddm` and `/etc/pam.d/systemd-user`, a marker comment
   (`# omarchy-kids: pam_namespace for kid sessions (R-FND-2a)`) followed by
   `session required pam_namespace.so`, appended once per file and never duplicated (the marker
   is the idempotence check).
11. **The parent-unlock verifier line** (R-SEC-2, R-SEC-3; `docs/authd.md`), machine-level and
   idempotent: `lib/posture.sh`'s `posture_ensure_parent_unlock_line` inserts the
   `pam_exec.so … omarchy-kids-parent-auth` line (a fixed `[success=done default=ignore]`
   control — "done" ends the stack on a verified parent password before pam_unix is ever
   consulted with it; "ignore" on anything else falls through to the stack's normal chain, which
   reuses the already-typed token via `try_first_pass`) into `/etc/pam.d/sddm` and
   `/etc/pam.d/omarchy-lock-password` (`posture_parent_unlock_lock_stack` — the only lock-screen
   PAM service Omarchy 4.0.2 actually writes; there is no `hyprlock` service on that box). The
   line lands right after each stack's own leading `auth … pam_faillock.so … preauth` line if it
   has one, else right before its first non-comment `auth` line — confirmed against real
   `/etc/pam.d/sddm` and `/etc/pam.d/omarchy-lock-password` content, neither of which has a
   `pam_unix.so` line worth jumping around (`lib/posture.sh`'s own header comment has the full
   placement rule). A stack that doesn't exist yet on this box (the lock screen hasn't been
   configured) is a warning, not a reason to fail the whole `add` — see "Judgment calls" below.
12. **AccountsService** (R-LOGIN-3): `/var/lib/AccountsService/users/<account>` gets
    `Session=omarchy-kids`, `XSession=omarchy-kids`, `Icon=/usr/share/omarchy-kids/avatars/<avatar>.svg`
    so the tile has no session picker at all.
13. **The SDDM face icon** (R-LOGIN, issue #39, a live VM finding): AccountsService's `Icon=`
    line above is *not* what SDDM's `UserModel` actually reads for the avatar on this stack —
    it checks `~/.face.icon`, then `/var/lib/AccountsService/icons/<account>` (a cache file
    nothing in this repo populates), then `<FacesDir>/<account>.face.icon` (`FacesDir` defaults
    to `/usr/share/sddm/faces`). `lib/posture.sh`'s `posture_write_face_icon` copies the chosen
    avatar SVG, byte-for-byte, to the third path — never into the kid's own home, which stays
    untrusted (I-3) and is also the *first* path checked. Re-asserted as the `face:<account>`
    lock (`docs/assert.md`); see `docs/portal.md` for the full `UserModel.cpp` citation.
14. **The SDDM portal theme selection** (R-LOGIN, issue #14): `/etc/sddm.conf.d/zz-omarchy-kids-theme.conf`
    selects the portal (`docs/portal.md`). Machine-level (R-FND-6): written once, left alone by
    `remove` until Remove Kids Mode takes the package out.
15. **theme.conf.user** (R-LOGIN, issue #39): `/usr/share/sddm/themes/omarchy-kids/theme.conf.user`
    (root-owned 0644) is rebuilt in full from every kid profile under `$OMARCHY_KIDS_ETC/kids/*.conf`
    plus `machine.conf`'s `parent=` and the `omarchy-parents`/`wheel` members — `[General]` keys
    `parent=<owner>`, `parents="<parent>,..."`, and `kids="<account>:<name>:<avatar>,..."` — so
    `Main.qml` can allow only profiled kids and parent accounts from the profile registry, never from the `kid-` username prefix (`docs/portal.md`'s
    "Verified live" section: a VM whose owner account happened to be named `kid-vm` broke that
    heuristic). SDDM's own `ThemeConfig` loads this file automatically next to `theme.conf`
    (`docs/portal.md` has the citation) — an earlier design wrote a separate `portal.json` and a
    systemd drop-in for `Main.qml` to read it via XHR; dropped because that drop-in only took
    effect after a `systemctl restart sddm`, which re-fires the owner's stock autologin on an
    already-booted machine.

    `lib/posture.sh` QSettings-encodes every value. It escapes backslashes and double quotes,
    quotes values containing `,`, `;`, `=`, or edge whitespace, and always quotes the two account
    lists so QSettings keeps each one scalar.
16. **Omarchy's own per-user setup** (issue #10 finding b): if `omarchy-provision-user` exists on
    the target, it's run with the new account. If it doesn't, `mark_migrations_done` writes a
    best-effort stand-in — see "Known gap" below.
17. **The launcher map and session manifest** (R-MANIFEST-1..3): the root-derived map is built at
    `/etc/omarchy-kids/launchers/<account>.json`, immediately followed by the atomic manifest at
    `/etc/omarchy-kids/sessions/<account>.json`. The manifest is the validated input for the next
    kid login; `omarchy-kids-assert` rebuilds it after package updates.

## `remove <account> [--keep-home] [--luks-device DEV]`

Reverses every account-level step `add` took, in reverse-ish order, then removes the account:

1. **LUKS slot** (R-SEC-4), disk mode only: looked up by *slot number* in `luks-slots` (a kid's own password
   isn't available to `remove`, so `--test-passphrase` isn't an option here — this is the one
   place slot number, not password, is the key), killed with
   the command writes and fsyncs `luks-slots.removing-<account>`, then calls
   `cryptsetup luksKillSlot --batch-mode DEVICE SLOT` (`--luks-device`, or auto-detection), rewrites
   `luks-slots`, and clears the intent. A failed kill leaves the mapping, intent, and profile in
   place. If the kill succeeded but the map write failed, a retry confirms the slot is empty and
   finishes the rewrite without killing it again. Portal mode makes no cryptsetup call and rejects
   `--luks-device`; if the map or an intent records this account, it refuses removal and preserves
   the account, profile, and home.
2. `pam_namespace` lines for the account removed from `namespace.conf` (the `pam.d/sddm` and
   `pam.d/systemd-user` marker lines stay — they're not per-account).
3. The AccountsService file removed.
4. **The SDDM face icon removed** (R-LOGIN, issue #39): `posture_remove_face_icon` deletes
   `/usr/share/sddm/faces/<account>.face.icon`.
5. **theme.conf.user rebuilt without this account** (R-LOGIN, issue #39): the same full-rewrite
   `posture_write_portal_conf` `add` uses, excluding the account being removed — never an
   in-place edit, for the same reason `luks-slots` is a full rewrite (see below).
6. The home unmounted (`umount /home/<account>`) and its `fstab` line dropped.
7. **The launcher map and session manifest** removed from
   `/etc/omarchy-kids/launchers/<account>.json` and
   `/etc/omarchy-kids/sessions/<account>.json`.
8. `userdel <account>` (no `-r`: the home is left on disk on purpose, for the next step).
9. Unless `--keep-home`, the home moves to `<parent home>/Kids Mode/<display name>/` — the
   parent's login name comes from `machine.conf`'s `parent=`, and their home directory from
   `getent passwd` (falling back to `/home/<parent>` where `getent` isn't available, e.g. this
   repo's macOS dev environment).
10. The profile is removed last. Until the account and home steps succeed, it remains the retry
    record for the account and display name.

**Left alone, on purpose** (R-FND-6: machine-level, only removed by Remove Kids Mode): the
`omarchy-kids*` groups, the console masks, both polkit rule files, the SDDM theme selection
(`lib/posture.sh` has `posture_remove_sddm_theme_dropin` for Remove Kids Mode to call later), and
the parent-unlock PAM lines on `sddm` and the lock-screen stack (`lib/posture.sh` has
`posture_remove_parent_unlock_line` for Remove Kids Mode to call later; `remove` itself doesn't,
since a parent should still be able to unlock the lock screen and SDDM even after the *last* kid
is removed).

## Why `luks-slots` is rewritten whole, not appended to (issue #10 finding a)

LUKS2 hands out a *freed* slot number to the next `luksAddKey`, not necessarily the next unused
one. If `remove` frees slot 3 and a later `add` gets slot 3 back for a different kid, an
append-only `luks-slots` would end up with two `3=...` lines — one stale, one current — and
whichever the boot-time reader (`docs/boot.md`) happens to read last decides who lands on whose
desktop. So every slot change — add or remove — rewrites the *entire* file from the current,
known-correct set of mappings: `posture_write_luks_slots` (`lib/kids.sh`) always takes the
verbatim parent `0=...` line plus the full list of surviving kid entries and writes that, and
nothing else, replacing the file outright. `add`/`remove` build that list by reading the
existing file (everyone else's mapping, already correct) and only changing the one line for the
account being added or removed — never assuming a slot number that wasn't just confirmed by
`cryptsetup` itself.

## Every path is overridable, for tests and for review before trusting a dry run

| Env var | Default | Affects |
| --- | --- | --- |
| `OMARCHY_KIDS_ETC` | `/etc/omarchy-kids` | profiles, `machine.conf`, `luks-slots` |
| `OMARCHY_KIDS_SHARE` | `/usr/share/omarchy-kids` | `omarchy-kids-conf`'s bands/packs (passed through); the avatar SVG `posture_write_face_icon` copies from (issue #39) |
| `OMARCHY_KIDS_ROOT` | (none — the real paths) | prefixes every path `lib/posture.sh` writes: `/etc/polkit-1`, `/etc/security`, `/etc/pam.d`, `/etc/fstab`, `/var/lib/AccountsService`, `/usr/share/sddm/themes/omarchy-kids` (`theme.conf.user`), `/usr/share/sddm/faces`; also passed to `systemctl --root=` for the console masks |
| `OMARCHY_KIDS_HOME_ROOT` | (none — the real `/home`) | prefixes `/home/<account>` for every `mount`/`umount`/`mv` this command itself runs (**not** in the spec's original env list — added here; see "Judgment calls" below) |
| `OMARCHY_MIGRATIONS_DIR` | `/usr/share/omarchy/migrations` | source list for `mark_migrations_done`'s guessed markers |

`test/shell.d/provision-test.sh` runs entirely against a scratch tree built from these, with a
stub `PATH` (fake `useradd`, `usermod`, `userdel`, `chpasswd`, `mount`, `umount`, `systemctl`,
`cryptsetup`, `omarchy-provision-user`) that only logs its own argv — see that file's `stub()`
helper.

## The "migration done" marker, as Omarchy 4.0.2 really keeps it (verified 2026-09-26)

`omarchy-provision-user` is called when it exists on the target, which is the right thing and
needs no guessing. When it doesn't (an older Omarchy, or a dev box), `mark_migrations_done`
(`bin/omarchy-kids-provision`) now marks a kid's migrations the way Omarchy itself does, read off
the real script on the try-omarchy VM instead of guessed:

- `omarchy-migrate`'s `migration_entries` walks `$OMARCHY_PATH/migrations/*.sh` and calls a
  migration **pending** while
  `${OMARCHY_MIGRATION_STATE:-$HOME/.local/state/omarchy/migrations}/<script basename>` does not
  exist; running one touches that marker. So the record is **one marker file per migration, named
  exactly like the script** — `~/.local/state/omarchy/migrations/1787815267.sh`, say.
- `omarchy-provision-user` keeps a separate, task-level marker of its own,
  `~/.local/state/omarchy/done/finalize-user`, checked by `omarchy-done check finalize-user` and
  set by that script itself when it runs.

So the writer emits per-migration markers and **not** the
`~/.local/state/omarchy/migrations.log` this repo had invented: nothing in Omarchy reads a file of
that name, which means a kid provisioned through the fallback would still have been shown
"Pending Omarchy Migrations" at login. The markers are staged and renamed rather than touched in
place, so a symlink a kid planted at a marker path is replaced rather than written through (rule
9), and `~/.local/state/omarchy/migrations` is in `kid_home_writable_paths`, so a link *there* is
refused outright. Upstream's `OMARCHY_MIGRATION_STATE` override is deliberately not read: a fixed
path under the kid's home is the smaller surface, and a kid's session does not set it.

The guess is gone, but the outcome still deserves one look on a fresh box: `add` a kid with
`omarchy-provision-user` hidden from `PATH`, then in that kid's session `omarchy-migrate --pending`
should print nothing and exit 1, and no "Pending Omarchy Migrations" toast should appear.

`omarchy-provision-user` itself can fail even when present: on a VM built from the ISO's offline
package set it failed on a missing bundled Node tarball (seen live 2026-09-02). `add` treats that
failure as a warning, not a failed provision — the account, slot, locks, and profile are already
in place by that point — and falls back to `mark_migrations_done`.

## Judgment calls made in this implementation

- **A missing lock-screen PAM stack only warns, never fails `add`** (issue #15, R-SEC-2).
  `sddm` should always exist on a real Omarchy box, but `omarchy-lock-password` might not yet —
  the lock screen may simply not be configured at the moment a kid is provisioned. Aborting the
  whole account creation over that would be worse than provisioning the account and letting
  `omarchy-kids-assert` (which re-asserts every lock idempotently, `docs/assert.md`) pick the
  lock back up automatically once that stack exists.
- **The real-world content of `/etc/pam.d/sddm` and `/etc/pam.d/omarchy-lock-password` is now
  confirmed** against an actual Omarchy 4.0.2 box (there is no `/etc/pam.d/hyprlock` there at
  all — an earlier version of this guessed one as a fallback; wrong, and removed). Neither real
  file has a `pam_unix.so` line worth anchoring on (sddm has none of its own; the lock-password
  stack's is three lines past the real anchor point), which is why
  `posture_ensure_parent_unlock_line`'s placement rule is anchor-based on the stack's first
  non-comment `auth` line, and its control is a fixed `[success=done default=ignore]` rather than
  a jump number computed off `pam_unix.so`'s own control (an earlier version did the latter; it
  matched neither real file). `lib/posture.sh`'s own header comment has the full rule and the
  reasoning; every fixture in `test/shell.d/parent-unlock-test.sh`,
  `test/shell.d/provision-test.sh`, and `test/shell.d/assert-test.sh` is now the verbatim real
  file content, not a guess.
- **`OMARCHY_KIDS_HOME_ROOT`** isn't in the issue's env-var list (`OMARCHY_KIDS_ETC`,
  `OMARCHY_KIDS_SHARE`, `OMARCHY_KIDS_LIB`, `OMARCHY_KIDS_ROOT`), but `mount`, `umount`, and the
  final `mv` to `Kids Mode/` all need *some* real path to act on, even a scratch one, and
  `/home` wasn't in `OMARCHY_KIDS_ROOT`'s list either (`/etc/polkit-1`, `/etc/security`,
  `/etc/fstab`, `/var/lib/AccountsService`, `/etc/systemd`). Added it rather than either
  skip-testing those three commands or write into the real `/home` from a test. The **text**
  written into the `fstab` line itself is always the real `/home/<account>` path regardless of
  this variable — that's what a real machine's `mount` needs to read at boot; only the
  *commands this script itself runs* honor the scratch prefix.
- **Default `--avatar`**: the issue's signature marks `--avatar ID` optional but names no
  default and no avatar SVGs are shipped yet (`share/avatars/` is empty but for `.gitkeep`).
  Defaulted to `fox`, matching the fixture avatar already used by `AGENTS.md` and
  `test/shell.d/conf-test.sh`'s `kid-ada`.
- **Password minimum enforcement**: not explicitly asked for in the issue's `add` signature, but
  R-SEC-3 sets it and `bands.toml` already carries `password_min`, so `add` reads it via
  `omarchy-kids-conf band <band>` and refuses a too-short `--password-stdin` password outright,
  rather than writing a weak key slot and finding out later.
- **`--parent-password-fd`**: added alongside `--parent-password-stdin` per the issue text ("...
  or from a file descriptor"), reading one line via `read -r pw <&"$FD"`. The rejection matrix
  opens an fd and proves portal mode rejects it before mutation; disk-mode success uses the stdin
  form.
- **`umount` and `userdel` as additional stub commands**: the issue lists `useradd`, `usermod`,
  `cryptsetup`, `mount`, `systemctl`, `gpasswd`, `chpasswd`, `omarchy-provision-user` as the
  fakes to build; `remove` also needs to unmount a home and delete the account, so
  `test/shell.d/provision-test.sh` stubs `umount` and `userdel` too (`gpasswd` is stubbed but
  currently unused — nothing in `add`/`remove` touches group membership beyond `useradd -G` at
  creation time and `userdel` at removal).
- **LUKS device auto-detection (`lsblk`)** is implemented (first `crypto_LUKS` device it finds).
  Tests use the disk-only `--luks-device` option so they never inspect the development Mac.
- **Ownership bits** (`root:root`, `root:polkitd`, etc.) on the files this writes are left
  alone — only permission bits are set. Actually running this always requires root in
  production (`useradd`, `mount`, `cryptsetup` all do), at which point everything it creates is
  already root-owned by virtue of the process; setting an explicit `chown` would only add a
  privileged operation that fails outright in the scratch trees this had to be built and tested
  against on a non-root Mac (AGENTS.md rule 8).

## Secrets and LUKS slots (2026-09-03 review, S6 and §1.10)

`add_luks_slot` used to be called through `run`, whose dry-run preview is `printf ' %q' "$@"`.
Since `DRY_RUN=1` is this command's documented default, the documented preview run printed both
the kid's password and the parent's LUKS passphrase onto stdout -- into SSH scrollback, into
captured reports, into any CI log -- in direct contradiction of AGENTS.md's "passwords only ever
on stdin, never argv, never logged". The function now takes the kid's passphrase on fd 3 and the
parent's on fd 4, is never handed to `run` at all, and prints its own preview with `<secret>`
placeholders in the two positions. `test/shell.d/provision-test.sh` greps the whole default
dry-run output, and every `[dry-run]` line in it, for either password.

The slot number is found by diffing `cryptsetup luksDump`'s occupied slots before and after
`luksAddKey`, not by running `cryptsetup open --test-passphrase` afterwards and parsing "Key
slot N unlocked". `--test-passphrase` reports the *first* slot that matches, so a kid who typed
the parent's own passphrase -- a six-year-old copying what they watched -- got slot 0 reported
and a second `0=` line landed in `luks-slots` under the parent's, after which `boot-login`'s
behaviour depended on line order in a regenerated file. That passphrase is now rejected up
front, before `luksAddKey` runs at all, and the `|| true` that used to swallow a failed test is
gone. `add` refuses tabs and newlines because the profile and internal entry are line-oriented.
Commas and colons are valid display-name text: `lib/posture.sh` percent-encodes the portal payload
delimiters before applying QSettings' separate file-format encoding.

## Source header (moved from `bin/omarchy-kids-provision`, issue #49)

Kept for reference; the file itself now carries a short pointer instead.

```text
omarchy-kids-provision — add and remove a kid account (SPEC.md R-FND-2..6,
R-SEC-3..5, R-LOGIN-3, R-DESK-1, Appendix B). See docs/provision.md for
what "add" and "remove" do, in order, with the exact files each touches.

DRY_RUN=1 by default (also the default with no DRY_RUN set at all):
every action that would change something is printed, nothing runs.
--apply (anywhere in the args) or DRY_RUN=0 in the environment turns
actions on for real. Reads that only decide *what* to do (the slug
collision check, LUKS device/slot detection, parsing luks-slots) always
happen for real, dry run or not, since they never change anything.

Data paths use scratch prefixes in tests. The boot-mode reader stays fixed, so
`test/shell.d/provision-test.sh` copies the command tree and rewrites its build-time constant.
The test runs entirely against scratch trees with a stub PATH:
  OMARCHY_KIDS_ETC        default /etc/omarchy-kids   (profiles, machine.conf, luks-slots)
  OMARCHY_KIDS_SHARE      default /usr/share/omarchy-kids   (bands/packs, avatars source)
  OMARCHY_KIDS_ROOT       scratch prefix for /etc/polkit-1, /etc/security,
                          /etc/pam.d, /etc/fstab, /var/lib/AccountsService,
                          /etc/sddm.conf.d (lib/posture.sh)
  OMARCHY_KIDS_HOME_ROOT  scratch prefix for /home/<account> itself (not
                          part of the spec's env list; added here because
                          mount/umount/mv all need somewhere real, if only
                          a scratch "real", to act on -- see docs/provision.md)
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
