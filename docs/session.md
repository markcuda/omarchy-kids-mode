# Session entry: `omarchy-kids-session` and `omarchy-kids-blocked` (R-DESK-1, R-DESK-2, R-WEB-4, R-FND-2a, I-3, I-4, I-9)

## Session manifest

`lib/session-manifest.sh` builds `/etc/omarchy-kids/sessions/<account>.json` from the effective
root-owned profile, band defaults, pack allowlist, policy state, and `lib/launcher-map.sh`. The
directory is `0750 root:omarchy-kids`; each manifest is atomically replaced as `0644 root:root`.
The schema is version 1 and carries the account, display data, band/level/theme, allowlist, web
mode and policy id, weekday/weekend budget and lights-out values, and tiles with fixed `argv`
arrays. Unavailable applications have `installed: false` and an empty `argv`; no tile contains a
shell command.

For example: `{"schema_version":1,"account":"kid-ada","name":"Display Name","avatar":"fox","band":"6-8","level":1,"theme":"tokyo-night","allowlist":["gcompris"],"web":"garden","policy_id":"omarchy-kids-6-8","budget_min":60,"budget_min_weekend":60,"lights_out":"19:30","lights_out_weekend":"20:00","tiles":[]}`.

Root-side provisioning builds the manifest immediately after the launcher map. Provision removal
removes both root-owned inputs. The assert caller writes manifests by calling `session_manifest
build <kid>` and may validate one with `session_manifest check <kid>`.

`omarchy-kids-session --manifest` is the caller-bound read verb. It derives the account from
`id -un`, then opens only `/etc/omarchy-kids/sessions/<account>.json` through the command's fixed
`ETC` constant. It refuses a missing, linked, non-regular, non-root-owned, or non-0644 document,
malformed JSON, a schema other than 1, a stale document, or an account mismatch. A refusal emits
one plain line on stderr and no stdout; success prints the validated JSON. It accepts no account or
path argument. Session startup and the launcher consume this validated document; assert checks and
rebuilds the same manifest for every provisioned kid after package updates or drift.

## Manifest-backed session startup

`bin/omarchy-kids-session-start` reads the caller's manifest once through the fixed sibling
`omarchy-kids-session --manifest` command. It parses the document as a whole, then exports its
account, band, level, theme, web mode, budget, and lights-out values to the session surfaces. It
creates only `/run/user/<uid>/omarchy-kids/launcher-control` for the existing keyboard activation
path. It does not read the profile, scan desktop files, or write launcher or allowlist JSON in the
kid's runtime directory.

It starts the detached `omarchy-kids-time daemon`, then executes the level surface directly from
an argv array: Levels 1 and 2 run `/usr/bin/quickshell -p
/usr/share/omarchy-kids/launcher/shell.qml`; Level 3 runs
`/usr/bin/omarchy-launch-shell`. Missing or invalid manifest output fails closed with one plain
stderr line and no launcher surface.

The kid session entry point. SDDM's `omarchy-kids` tile runs this through
`/usr/share/sddm/scripts/wayland-session` the same way Omarchy's own session runs
`uwsm start -g -1 -e -D Hyprland hyprland.desktop`; `desktop/omarchy-kids-session.desktop`
(`Exec=omarchy-kids-session`) is installed as `/usr/share/wayland-sessions/omarchy-kids.desktop`,
so this is the whole session command SDDM invokes for a kid tile.

## What it does

1. Figures out the account: `id -un`.
2. Runs every R-DESK-2 check below, in order.
3. On the first check that fails closed: shows a full-screen "Ask a grown-up" naming the check
   (`omarchy-kids-blocked "<check name>"`) and exits 1. **Fail closed** — a kid never lands
   on an unfenced desktop because a lock silently went missing (I-4, I-9).
4. Once every fail-closed check passes: exports `OMARCHY_KIDS_ACCOUNT`, `OMARCHY_KIDS_LEVEL`,
   `OMARCHY_KIDS_BAND`, `OMARCHY_KIDS_HYPRLAND_DIR` and `exec`s
   `Hyprland --config /etc/omarchy-kids/hyprland/L<level>.lua`. The kid's own `~/.config/hypr` is never read
   (R-DESK-6): `--config` picks the root-owned file exclusively.

Every check's result — PASS or FAIL — is logged, one line per check, to
`/run/user/<uid>/omarchy-kids/session-<uid>.log`
— deliberately *not* `/run/omarchy-kids`, which is root-owned and this process never is root).

## The checks (R-DESK-2), in order

| # | Check | Name (shown to a grown-up / in `--check`) | Fails closed? |
| --- | --- | --- | --- |
| a | Profile present at `/etc/omarchy-kids/kids/<account>.conf`, and `level`/`band`/`web` resolve | `profile present` | Yes |
| b | `/etc/chromium/policies/managed/omarchy-kids-<band>.json` readable by this account, **unless** the profile's `web` is `none` (R-WEB-4) | `browser policy readable` | Yes |
| c | `/etc/polkit-1/rules.d/40-omarchy-kids.rules` and `41-omarchy-kids-deny.rules` both exist | `polkit rules present` | Yes |
| d | The mount containing the home from `getent passwd "$(id -un)"` contains `noexec` | `home noexec` | Yes |
| e | `/tmp` is a private `tmpfs` with `nosuid,nodev,noexec` | `private /tmp noexec` | Yes |
| f | `getty@tty2.service` through `getty@tty6.service` are all masked | `consoles masked` | Yes |
| g | `/dev/shm` is a private `tmpfs` with `nosuid,nodev,noexec` | `private /dev/shm noexec` | Yes |
| h | `/etc/omarchy-kids/hyprland/L<level>.lua` exists | `level config present` | Yes |

The home, `/tmp`, and `/dev/shm` checks fail closed. Each mount must be private and carry all
three execution fences: `nosuid,nodev,noexec`. This prevents a kid from moving executable content
outside their home and avoids shared temporary-memory paths.

A missing profile ((a)) is also how a non-kid account gets refused: if `id -un` isn't a
provisioned kid, there's no profile, check (a) fails, and the session refuses to start — the same
fail-closed path as every other check, not a special case.

## `omarchy-kids-session --check`

Runs every check above (not stopping at the first failure — it always produces the full table)
and prints a `CHECK / RESULT / DETAIL` table instead of starting anything. Exits 0 if nothing
FAILed, 1 if anything did. Run this inside the child's actual login session: `sudo -u` does not establish
that session's private temporary mounts.

## `omarchy-kids-session --check-setup`

Used by the wizard before first login. Runs the same account, policy, polkit, home mount,
console and compositor-config checks, but reports the private `/tmp` and `/dev/shm` checks as
`SKIP`, with “checked at child login.” Those mounts belong to the child's PAM session; a plain
`sudo -u` process cannot prove them. Exits 1 on any other failed check, otherwise 0. It never
starts the desktop or writes a session log. Normal login and `--check` still require every
check, including both private temporary mounts.

## `omarchy-kids-session --install-configs`

Copies every `*.lua` under `/usr/share/omarchy-kids/hyprland/` (the package's
`/usr/share/omarchy-kids/hyprland/`) to `/etc/omarchy-kids/hyprland/`
with mode 0644. This is the root-owned copy that `L1.lua`/`L2.lua`/`L3.lua`'s band overlays
`dofile()` at Hyprland config-parse time (`docs/levels.md`) — it has to exist and stay current, or
check (h) above fails closed and every kid is locked out after an update that touched those Lua
files. Meant to be called by the package's `post_install`/`post_upgrade` hook
(`omarchy-kids.install`) and by `omarchy-kids-assert` (R-TRUST-5), so this copy can never go stale
after a pacman transaction — **neither of those exists yet** (`omarchy-kids-assert` is still a
stub from its own issue, and `omarchy-kids.install` doesn't call this flag). Wiring `--install-configs`
into them is that other work's job; this ticket only builds and tests the flag itself.

## Build-time paths

| Constant | Installed value | Purpose |
| --- | --- | --- |
| `ETC` | `/etc/omarchy-kids` | root-owned profiles and Hyprland configs |
| `SHARE` | `/usr/share/omarchy-kids` | packaged policy, Lua, and modal data |
| `SYSROOT` | empty | test-only scratch prefix substituted into copied commands |
| `RUN_DIR` | `/run/user/<uid>/omarchy-kids` | this account's session log |
| `OMARCHY_KIDS_BLOCKED_SLEEP` | 15 | (on `omarchy-kids-blocked`) seconds the message holds the screen before exiting — tests set this to 0 |

`test/shell.d/session-test.sh` copies the command and substitutes these constants with
`kids_set_const`; no inherited environment variable can redirect the check.

## `omarchy-kids-blocked`

`omarchy-kids-blocked "<check name>"` — the message shown on the first fail-closed check.
**This is a placeholder, not the real modal**: at the point `omarchy-kids-session` calls it,
Hyprland hasn't started, so there's no compositor and nothing graphical to draw into. All it can
honestly do today is print a message and hold the screen for a while:

- If `gum` is on `PATH`, a big centered `gum style` box.
- Otherwise, plain text between two banner lines.
- Either way, to the real tty if one is attached (falling back to stdout, e.g. in a test run with
  no controlling terminal), then `sleep 15` (override: `OMARCHY_KIDS_BLOCKED_SLEEP`) and exit 1.

A real graphical modal — rendered by whatever runs the portal/greeter, or a tiny standalone
compositor client — is a separate ticket; this script is what that ticket should replace, not
build on top of.

## Judgment calls made in this implementation

- **System paths are build-time constants.** Chromium policy and polkit paths use the empty
  packaged `SYSROOT`; tests substitute it, along with `ETC`, `SHARE`, and `RUN_DIR`, in a copied
  command. No inherited `OMARCHY_KIDS_*` path variable can redirect a login check.
- **`RUN_DIR` is fixed to `/run/user/<uid>/omarchy-kids`.** The session derives the uid from
  `id -u`, so the log stays in the account's own runtime directory without trusting
  `XDG_RUNTIME_DIR` or another environment-selected path.
- **`--install-configs` sets mode 0644 only, no `chown`** — the same call `docs/provision.md`
  makes for its own writers: a real run of this always happens as root already (package hooks,
  `omarchy-kids-assert`), at which point everything it creates is already root-owned by virtue of
  the process, and adding an explicit `chown` would only add a privileged call that fails outright
  in the scratch trees this had to be built and tested against on a non-root Mac (AGENTS.md rule 8).
- **No `DRY_RUN` gate on `--install-configs`**, unlike `omarchy-kids-provision`. It's a plain,
  idempotent file copy (no account creation, no LUKS, nothing destructive to reverse), the same
  risk class as `bin/omarchy-kids-boot-login`'s writes, which also has no `DRY_RUN`. Tests use a
  copied command with substituted build-time constants, not runtime path overrides.
- **No associative arrays.** The id → human check-name mapping is a `case` statement
  (`check_name()`), not a `declare -A` table, because this was built and tested on the same bash
  3.2 macOS box `bin/omarchy-kids-session-start`'s header comment calls out (`tr` instead of
  `${var,,}`) — bash 3.2 doesn't have associative arrays at all, and silently misparses
  `declare -A X=([foo]=...)` as an *indexed* array trying to evaluate `foo` as an arithmetic
  subscript, which fails with `foo: unbound variable` under `set -u`. Worth remembering for any
  future edit to this file: stick to indexed arrays, `case`, and plain variables.
- **`--check` always runs every check**, even after the first FAIL, instead of stopping early
  like a normal start does. The issue only says `--check` "prints a table"; running the full set
  makes that table an actual diagnostic (see every check's state at once), which is also what a
  tool like `omarchy-kids-check` needs from it — stopping at the first FAIL would just reproduce
  `omarchy-kids-session`'s own start behavior with extra steps.
- **`omarchy-kids-blocked`'s tty detection actually attempts the write** (`{ : > /dev/tty; }
  2>/dev/null`) rather than checking `[[ -w /dev/tty ]]` first. The permission-bit check can look
  writable with no controlling terminal attached (common in a test run, or a session started in
  an unusual way) and then fail with `ENXIO` on the real write — attempting the open directly and
  falling back to stdout on failure sidesteps that instead of trusting the permission bits.

## Verify in the VM

Live status (2026-09-21, try-omarchy aarch64 VM): the session entry has now run against a real
Hyprland, SDDM and `pam_namespace` setup. Both modes logged in through SDDM's
`omarchy-kids.desktop`, the R-DESK-2 preflight passed, and the private noexec `/tmp` and
`/dev/shm` checks passed in the child's PAM namespace (`docs/dogfood-2026-09-21.md`). The list
below is kept as the re-verification checklist for a fresh box:

1. Provision a kid (`docs/provision.md`) so `/etc/omarchy-kids/kids/<account>.conf` and every
   R-DESK-2 lock actually exist, then pin that account to the `omarchy-kids` session via
   AccountsService (`docs/provision.md`'s step 10 does this automatically for a kid `add`; to
   force it by hand, `Session=omarchy-kids` / `XSession=omarchy-kids` in
   `/var/lib/AccountsService/users/<account>`).
2. Run `omarchy-kids session --install-configs` (or run it manually as root once) so
   `/etc/omarchy-kids/hyprland/L<level>.lua` exists — check (h) fails closed without it.
3. Log in as the kid at the SDDM portal. Confirm: the level's Hyprland session starts, the kid's
   own `~/.config/hypr` is never touched, and `Super+Home`/the level's other binds
   (`docs/levels.md`) work.
4. Break one lock on purpose (e.g. `chmod 000` the browser policy file, or
   `systemctl unmask getty@tty2.service`), log in again, and confirm the "Ask a grown-up" message
   appears naming that check, then the session exits back to the portal after ~15s.
5. Read `$XDG_RUNTIME_DIR/omarchy-kids/session-<uid>.log` from a still-open terminal (or from the
   parent's session with sufficient access) and confirm every check's result is there.
6. `omarchy-kids-session --check` from a terminal in the kid's own session (or `su`'d to that
   account) and confirm the table matches what actually happened at login.

## Verified live (2026-09-02, QEMU test VM)

Cold boot with a kid's password → LUKS slot recorded → per-boot autologin into the `omarchy-kids`
session → every R-DESK-2 check passed (private `/tmp` and `/dev/shm` verified) → `Hyprland --config
/etc/omarchy-kids/hyprland/L1.lua` → `omarchy-kids-session-start` read the validated manifest and
started the Level 1 launcher (Quickshell): nine tiles for the 6-8 pack plus the web app, a clock,
keyboard highlight. Fixes that came out of the run: the polkit check goes through `pkcheck` (the
rules directory is 0750 root:polkitd), `Hyprland --verify-config` is a fail-closed check because
emergency mode binds a terminal, the level configs set their own Lua path, and launcher execution
data remains in the root-owned manifest rather than the kid's `XDG_RUNTIME_DIR`.

Confirmed again later the same night on a clean package install and a cold boot with no manual
step: slot recorded, `omarchy-kids-boot-login` wrote the drop-in, kid-cy on seat0, `Hyprland`
and `quickshell` running as the kid, the control file present. The owner's disk password on the
same machine lands on the owner's own desktop (R-BOOT fail-safe), not the portal. Two package
gaps found by this run are now assert locks: `units` (the package's units must be enabled) and
the earlier `limine-editor`.

## `omarchy-kids-session-start` source contract

The command runs once per kid Hyprland session from `share/hyprland/L1.lua`, `L2.lua`, or `L3.lua`.
Its only session input is the caller-bound manifest. The manifest's tile records already contain
labels, icons, installed state, and fixed argv arrays, so startup does not create a display JSON
file, read the root launcher map, scan desktop entries, or write an allowlist file. The test-only
`OMARCHY_KIDS_SESSION_START_NO_EXEC=1` hook prints the direct argv that would run and skips the
daemon and exec.

## Source header (moved from `bin/omarchy-kids-session`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-session: the kid session launcher (SPEC.md R-DESK-1,
R-DESK-2, R-WEB-4, R-FND-2a, I-3, I-4, I-9, §5.2 "Kid login").

Run by /usr/share/wayland-sessions/omarchy-kids.desktop
(desktop/omarchy-kids-session.desktop), which SDDM starts through
/usr/share/sddm/scripts/wayland-session the same way it starts
Omarchy's own `uwsm start -g -1 -e -D Hyprland hyprland.desktop`.

Sequence: derive the account (`id -un`), run every R-DESK-2 check in
order, and on the first fail-closed miss show a full-screen "Ask a
grown-up" (omarchy-kids-blocked) and exit 1 -- fail closed, never a
silent, unfenced desktop (I-4, I-9). Once every check passes, read the
caller-bound manifest, export the account/level/band, and exec Hyprland
with the level's root-owned config -- never the kid's own
`~/.config/hypr` (R-DESK-6, I-3).

--check runs every check and prints a PASS/FAIL table without
starting anything, for `omarchy-kids-check` to reuse.

--install-configs copies the level configs this package ships
(/usr/share/omarchy-kids/hyprland/*.lua) to the root-owned copy under
/etc/omarchy-kids/hyprland the level files' band overlays `dofile()`
at Hyprland config-parse time. Meant to be called by the package's
post_install/post_upgrade hook and by `omarchy-kids-assert`
(R-TRUST-5) so that copy can never silently go stale -- neither of
those callers exists yet (both are separate issues' stubs as of this
one); wiring this flag into them is that issue's job, not this one's.

Paths are build-time constants: `ETC=/etc/omarchy-kids`,
`SHARE=/usr/share/omarchy-kids`, `RUN_DIR=/run/user/<uid>/omarchy-kids`, and
`SYSROOT=`. Tests substitute these constants only in a copied command tree.
The sole runtime setting here is the test-only `OMARCHY_KIDS_BLOCKED_SLEEP`.
```

## Level and band are outputs, not inputs (issue #58)

`bin/omarchy-kids-session-start` now takes level, band, theme, web mode, budget, and lights-out
values from the caller-bound manifest returned by `omarchy-kids-session --manifest`. The account
is still derived from `id -un` inside that read command, and the session-start command cannot be
redirected to another account or path by its environment.

`bin/omarchy-kids-session` execs `/usr/bin/start-hyprland --config …` (Hyprland's own launcher since 0.5x; starting `/usr/bin/Hyprland` directly earns a red "started without start-hyprland" banner on every login, seen live 2026-09-03) after verifying the config with `/usr/bin/Hyprland --verify-config` (both constants, not `$OMARCHY_KIDS_HYPRLAND_BIN`
and not a bare name resolved through the kid's own `PATH`, which a kid can set through
`~/.config/environment.d/`). And `share/hyprland/L{1,2,3}.lua` set a fixed `package.path` instead
of `(os.getenv("OMARCHY_PATH") or …) .. package.path`, and `dofile` the band overlay from a fixed
`/etc/omarchy-kids/hyprland` — otherwise anything that seeded the session environment could make
`require("default.hypr.helpers")` load kid-authored Lua at config-parse time, which is the whole
Level 1 fence (review §3.5).

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.

## Desktop selection (#200)

`omarchy-kids-session-start` starts the owned launcher for Levels 1 and 2. Its validated
manifest chooses the visible Level 1 grid or Level 2 desktop with an on-demand searchable
picker. Only manually selected Level 3 starts `omarchy-launch-shell`. Age defaults and
parent overrides are described in `docs/levels.md`; startup does not infer a level from age
or from a child-controlled environment variable.
