# The portal: `share/sddm-theme/` (SPEC.md R-LOGIN-1..5, R-BOOT-3, R-SEC-3, I-5, I-7; issue #14, issue #39, issue #100)

An SDDM greeter theme: one big tile per kid, a smaller parent tile last, arrow keys to move,
Enter to select, a password field that appears under the highlighted tile (or logs straight in
for a "no password" 3-5 profile), Esc to back out, no session picker. Replaces Omarchy's own
password-only greeter (`userModel.lastUser` plus a text field — confirmed against
`omacom/omarchy`'s shipped theme, see below) with one theme selection drop-in, never a hand-edit
of Omarchy's own files (I-7).

## What's here

| Path | What |
| --- | --- |
| `share/sddm-theme/metadata.desktop` | `[SddmGreeterTheme]`: `Name`, `MainScript=Main.qml`, `ConfigFile=theme.conf`, `QtVersion=6` |
| `share/sddm-theme/theme.conf` | `[General]` color/font keys, read back in `Main.qml` as `config.<key>` |
| `share/sddm-theme/Main.qml` | The greeter itself — see its own header comment for exactly which SDDM/Qt APIs each piece rests on and where that was confirmed |
| `share/avatars/*.svg` | Twelve hand-written, flat, single-color 128×128 animal avatars (fox, owl, panda, frog, whale, cat, bear, bee, koala, otter, penguin, tiger), CC0 (`share/avatars/LICENSE`) |
| `lib/posture.sh`: `posture_write_sddm_theme_dropin` / `posture_remove_sddm_theme_dropin` | Writes/removes `/etc/sddm.conf.d/zz-omarchy-kids-theme.conf` (`[Theme]` `Current=omarchy-kids`) |
| `lib/posture.sh`: `posture_write_portal_conf` | Writes `/usr/share/sddm/themes/omarchy-kids/theme.conf.user` (root-owned 0644) — SDDM's own theme config override, read automatically, issue #39. It carries the profiled `kids=` list, the recorded parent plus `omarchy-parents`/`wheel` members in `parents=`, and nine color/font keys resolved from the parent's own current Omarchy theme (`lib/theme.sh`) — see `docs/theming.md` |
| `lib/posture.sh`: `posture_write_face_icon` / `posture_remove_face_icon` | Copies the chosen avatar SVG to `/usr/share/sddm/faces/<account>.face.icon` (root-owned 0644) — the file SDDM's `UserModel` actually reads for the avatar, issue #39 |
| `omarchy-kids-provision`: `usermod -c "<fallback>"` | Sets a passwd GECOS fallback when the display name is representable there, issue #39 |

Installed by the package to `/usr/share/sddm/themes/omarchy-kids/` (PKGBUILD's `package()`) —
**not** under `/usr/share/omarchy-kids/`, even though `share/sddm-theme/` also gets swept into
that dir along with every other `share/**` subtree (docs/packaging.md); SDDM only looks for
greeter themes under `/usr/share/sddm/themes/<name>/`, so the theme needs its own, separate
`install`/`cp -a` line in `package()` to land where SDDM can actually find it.

## How the theme gets selected

Omarchy's own installer writes `/etc/sddm.conf.d/10-theme.conf` (`[Theme]` `Current=omarchy`).
`Current=` is SDDM's own documented key (`data/man/sddm.conf.rst.in` upstream): every file under
`/etc/sddm.conf.d/` is read in filename order, later files' keys winning. `posture_write_sddm_theme_dropin`
writes `/etc/sddm.conf.d/zz-omarchy-kids-theme.conf` — `Current=omarchy-kids` — which, sorting
after Omarchy's `10-`, wins without ever touching `10-theme.conf` itself (I-7). This is the exact
same "`zz-` prefix wins by sorting last" convention `docs/boot.md`'s
`zz-omarchy-kids-autologin.conf` already uses.

The writer is called once from `omarchy-kids-provision add` (`bin/omarchy-kids-provision`,
alongside the polkit rules) and re-asserted by `omarchy-kids-assert` as the `sddm-theme` lock
(machine-level, alongside `polkit-admin`/`polkit-deny` — see `docs/assert.md`). Like those polkit
rules, it is a **machine-level** lock: `omarchy-kids-provision remove` leaves it in place
(R-FND-6) since the portal is still the right greeter as long as any other kid remains
provisioned; only Remove Kids Mode (§5.2) takes it out, by removing the package (and with it
`/usr/share/sddm/themes/omarchy-kids/`) — `posture_remove_sddm_theme_dropin` exists for that step
even though nothing currently calls it (a `TODO` for whichever issue wires up Remove Kids Mode's
full teardown).

## Display names, parent detection, and avatars (issues #39, #100)

V1's first live boot into the portal (docs/phase1/V1.md; this file's own "Verified live" section
below) found three things that only show up once real tiles actually render: tiles showed the
bare account suffix (`ada`, `cy`) instead of the profile's display name; the parent tile wasn't
distinguished when the machine's *owner* account happened to be named `kid-vm` (a VM test
fixture); and avatars never rendered, always falling back to the letter-circle.

**Display name.** `Main.qml`'s `displayNameFor()` reads the exact name from the root-owned
`theme.conf.user` profile first. SDDM's passwd GECOS `realName` role is only a fallback for old
configs. `omarchy-kids-provision add` keeps that fallback exact when possible. Because `:` is a
passwd field delimiter, colon-bearing names use an empty GECOS field instead. The account-name
fallback remains last. The `gecos:<account>` lock re-asserts this safe representation
(`docs/assert.md`).

**Parent detection.** `omarchy-kids-provision add`/`remove` write
`/usr/share/sddm/themes/omarchy-kids/theme.conf.user` (root-owned 0644, rewritten in full every
time from the current, known-correct set of kid profiles plus `machine.conf`'s `parent=` and the
members of `omarchy-parents` and `wheel` — the same "never append, always rewrite" shape
`luks-slots` already uses, via `lib/posture.sh`'s
`posture_write_portal_conf`):

```ini
[General]
parent=mark
parents="mark"
kids="kid-ada:Ada Lovelace:fox"
```

The `parents` and `kids` keys stay quoted. Each `kids` record field first percent-encodes `%`, `,`,
and `:` so names remain lossless inside the comma/colon payload. QSettings then applies the INI
file layer: named escapes for standard controls, hexadecimal escapes for other C0 controls, and
escaping for `\` and `"`. QSettings removes the outer layer before QML; `PortalConfig.js` removes
the field encoding after splitting. The shell acceptance-harness reader reverses the same layers.

An **earlier version of this fix** wrote a separate `/etc/omarchy-kids/portal.json` and had
`Main.qml` read it with a synchronous `XMLHttpRequest("file:///etc/omarchy-kids/portal.json")`.
Dropped, for two compounding reasons found only after the code was written: Qt 6's own QML
documentation (`doc.qt.io/qt-6/qml-qtqml-xmlhttprequest.html`, fetched 2026-09) states "By
default, you cannot use the `XMLHttpRequest` object to read files from your local file system,"
lifted only by the process environment variable `QML_XHR_ALLOW_FILE_READ=1` — and the only way
found to set that for the greeter process (a systemd drop-in on `sddm.service`) only takes effect
after `systemctl restart sddm`, which on an already-booted, already-logged-in machine re-fires the
owner's stock autologin. Not an acceptable cost for a display-name/avatar polish fix.

Used instead: **SDDM's own theme config override mechanism.** `ThemeConfig::setTo()`
(`sddm/sddm`'s `src/common/ThemeConfig.cpp`, fetched 2026-09, confirmed by reading it directly)
loads a theme's `theme.conf` into a `QSettings`, then loads a *second* `QSettings` from
`<path-to-theme.conf>.user` and overwrites every key that second file sets non-empty over the
first's. So `theme.conf.user`, sitting right next to the installed `theme.conf`, is read
automatically by SDDM itself before the greeter's QML ever runs — no XHR, no `file://` URL, no
extra process environment, and no `systemctl restart` needed beyond whatever a normal `add`/
`remove` already causes SDDM to pick up on its own next read of the theme. `Main.qml` reads
`config.parent`, `config.parents`, and `config.kids` through the exact same `config`
`QQmlPropertyMap` its own colors already come through (`ThemeConfig::setTo()`/`GreeterApp.cpp`'s
`setContextProperty("config", ...)`, same citation the top of this file already rests on), parses
`config.kids`' percent-encoded `<account>:<name>:<avatar>,...` value and the comma-separated
`config.parents` allowlist. Only those two allowlists may produce tiles; a stale Unix account is
intentionally invisible. Both are re-asserted together as the `portal-conf` lock (`docs/assert.md`).

After the user model is finalized, `Main.qml` writes one `console.error` line to stderr in the
form `portal: N tiles (kids=K parents=P)`. Scenario 30 reads that finalized count from the SDDM
journal and uses the config only for an independent expected-count check.

**Avatars.** `posture_write_accountsservice` already points AccountsService's `Icon=` at
`/usr/share/omarchy-kids/avatars/<avatar>.svg`, and `Main.qml`'s `avatarSourceFor()` still uses
that role (falling back to rebuilding the same path from `theme.conf.user`'s per-account avatar id
if the AccountsService role comes back empty) — but a second live VM finding showed
**AccountsService's `Icon=` isn't actually what SDDM's `UserModel` reads for the avatar on this
stack at all**. `UserModel`'s constructor (`sddm/sddm`'s `src/greeter/UserModel.cpp`, fetched
2026-09, confirmed by reading it directly) checks, in order: `<home>/.face.icon` first, then the
literal path `/var/lib/AccountsService/icons/<account>` (a cache file the real `accountsd` daemon
populates itself via its own D-Bus `SetIconFile` method — nothing in this repo ever calls that
method, so this file is never created here), then `<FacesDir>/<account>.face.icon` (`FacesDir`
defaults to `/usr/share/sddm/faces` — `/usr/lib/sddm/sddm.conf.d/default.conf` line 58). The third
path is the one that actually has to exist on disk for an avatar to render here, so
`omarchy-kids-provision add` now also calls `lib/posture.sh`'s `posture_write_face_icon`, copying
the chosen avatar SVG (byte-for-byte, root-owned 0644) to
`/usr/share/sddm/faces/<account>.face.icon` — never into the kid's own home, which stays untrusted
(I-3) and is also the *first* path `UserModel` checks, ahead of this one. Re-asserted as the
`face:<account>` lock. AccountsService's `Icon=` line is kept as-is regardless (it costs nothing
and may still matter to some other AccountsService client), it just isn't the file this greeter
reads.

Separately, whether the SVG actually rasterizes at all needs Qt's SVG image plugin, `qt6-svg` —
now listed explicitly in `PKGBUILD`'s `depends=` (unverified whether `sddm`/`qt6-declarative`
already pull it in transitively; there is no `pacman` on this dev machine to check with
`pacman -Si sddm`'s own dependency tree).

## Ground truth this was checked against (2026-09, no local SDDM/Qt install)

Everything below was fetched and read from source, not guessed, since this machine has no SDDM
or Qt to test against:

- `omacom/omarchy`'s own shipped theme (`default/sddm/omarchy/{metadata.desktop,theme.conf,Main.qml}`,
  `default/sddm/hyprland.lua`): password-only, `userModel.lastUser`, `sddm.login(user, password,
  sessionIndex)`, `QtVersion=6`, no `import SddmComponents` types actually used, and a greeter
  Hyprland config with no keybinds of its own (so nothing there should be catching our
  `Ctrl+Shift+P` first — not itself confirmed, see Main.qml's header).
- `sddm/sddm` upstream C++ (`src/greeter/UserModel.{h,cpp}`, `SessionModel.{h,cpp}`,
  `GreeterProxy.h`, `GreeterApp.cpp`, `src/common/{ThemeConfig,ThemeMetadata,Session}.cpp`,
  `data/man/sddm.conf.rst.in`): the exact role names on `userModel` (`name`, `realName`,
  `homeDir`, `icon`, `needsPassword`) and `sessionModel` (`directory`, `file`, `type`, `name`,
  `exec`, `comment`, plus `lastIndex`); that `file` is an *absolute path*, not a bare filename;
  that `config` is a `QQmlPropertyMap` of `theme.conf`'s `[General]` keys with no `General/`
  prefix (Qt's `QSettings` special-cases that one group name); `sddm.login`/`powerOff`/
  `canPowerOff` and the `loginFailed`/`loginSucceeded` signals; that `QQuickView` uses
  `SizeRootObjectToView` (so the root item is stretched full-screen regardless of the
  width/height it declares); and that `[Theme]` `Current=` is SDDM's own documented config key.

What none of that can confirm without a real engine: that this exact QML parses and renders,
that the avatar `Image`s actually rasterize the SVGs (needs Qt's SVG image plugin,
typically `qt6-svg` — not an explicit `depends=` here since SDDM/Qt normally pull it in already;
worth confirming in the VM), font availability, and real keyboard routing through the greeter's
Hyprland compositor. See "What is untested / unverified, in one place" below for the complete list.

## Deliberately not implemented here: R-LOGIN-5

> R-LOGIN-5 The parent password opens any kid's tile (R-SEC-2). No option to hide the parent
> tile in v1 (Q25).

`sddm.login(user, password, sessionIndex)` only ever authenticates `user`'s *own* password
through PAM — there is no QML-level way to say "also accept the parent's password for this
account." Making that true needs a PAM-level change: a `pam_exec` line ahead of `pam_unix` on kid
accounts' auth stack, calling the R-SEC-2 verifier (`omarchy-kids-authd` / a thin
`omarchy-kids-parent-auth` client, per SPEC.md's R-SEC-2) so a kid's login accepts *either* the
kid's own shadow hash or a parent-verified password. Grepped this checkout before writing this
file: no `authd`/`omarchy-kids-parent-auth` files exist yet, so there is nothing to wire this
theme into. This theme only ever submits whatever was typed for the tile's own account; R-LOGIN-5
is an open follow-up for whichever issue builds that PAM stack.

## How to test in the VM

Nothing here can be verified without a real SDDM/Qt engine. Once a VM is up (`docs/vm.md`) and at
least one kid is provisioned (`docs/provision.md`):

1. Build and copy the package over (never `pacman -U` from this dev checkout — build on the test
   machine, per AGENTS.md rule 8 and the PKGBUILD's own header):

   ```sh
   ssh vm 'cd ~/omarchy-kids-sandbox && git pull && makepkg -sf --noconfirm'
   ssh vm 'printf "omarchy\n" | sudo -S -p "" pacman -U --noconfirm ~/omarchy-kids-sandbox/omarchy-kids-*.pkg.tar.zst'
   ```text

2. Provision at least two kids (one 3-5 band with `--no-password`, one older band with a
   password) plus confirm the parent account exists, so the portal has something interesting to
   show (a "no password" tile, a password tile, and the smaller parent tile last).
3. Confirm the theme.conf.user, face icon, and GECOS landed and re-assert (issue #39 additions):

   ```sh
   ssh vm 'cat /etc/sddm.conf.d/zz-omarchy-kids-theme.conf'
   ssh vm 'cat /usr/share/sddm/themes/omarchy-kids/theme.conf.user'               # portal-conf
   ssh vm 'ls -l /usr/share/sddm/faces/kid-<slug>.face.icon'                      # face:<account>
   ssh vm 'getent passwd kid-<slug> | cut -d: -f5'                                # display name, or empty when it contains a colon
   ssh vm 'printf "omarchy\n" | sudo -S -p "" omarchy-kids-assert'
   # expect "ok      sddm-theme", "ok      portal-conf", "ok      face:<account>", "ok      gecos:<account>"
   # (or "fixed" the first time)
   ```text

4. Restart SDDM from the SSH session (this kills the active graphical session on the console —
   expected, that's the point). Unlike an earlier, dropped design (a systemd drop-in on
   `sddm.service` itself), `theme.conf.user` is read by SDDM's own `ThemeConfig` the next time it
   loads the theme — no `daemon-reload` needed, just a restart:

   ```sh
   ssh vm 'printf "omarchy\n" | sudo -S -p "" systemctl restart sddm'
   ```text

5. Screenshot the console over QMP from the Mac (`scripts/vm-qmp.sh`, `docs/vm.md`):

   ```sh
   VM_DIR=~/vm scripts/vm-qmp.sh shot portal.png
   ```text

   Confirm visually: one tile per kid (avatar or fallback letter-circle, name below), the parent
   tile last and visibly smaller, no session-picker dropdown or list anywhere, a clock.
6. Keyboard-complete (I-5), driven via `scripts/vm-qmp.sh key <qcode>...` (no mouse):
   - Left/Right move the highlight between tiles.
   - Enter on the "no password" 3-5 tile logs straight in with no password field ever appearing.
   - Enter on a password-required tile shows a password field under that tile only.
   - Typing a wrong password and pressing Enter: the tile shakes, the field clears, no login, and
     a line under the tiles says "That password didn't work. Try again."
   - Esc from the password field returns to plain tile navigation with the field gone.
   - The correct password logs in, and lands the account on the session AccountsService pinned
     it to (`omarchy-kids` for a kid, `omarchy` for the parent) — confirm with `loginctl
     show-session` or `who` after logging in, not by trusting this file's claim.
   - `Ctrl+Shift+P` powers the machine off (confirm on a VM you don't mind losing — or just
     confirm `sddm.canPowerOff` gates it and stop short of actually invoking it, by reading the
     journal for the greeter process instead of pressing it for real).
7. Confirm R-LOGIN-1's "last-used tile preselected": log in and back out (Ctrl+Alt+F-key or log
   out) as a kid other than the first-created one, restart sddm, screenshot again, confirm that
   kid's tile is the one highlighted on the fresh portal.
8. Confirm avatars: set a kid's `--avatar` to something other than the default and reprovision
   (or hand-edit `/usr/share/sddm/faces/<account>.face.icon` directly — that file, not
   AccountsService's `Icon=`, is what SDDM's `UserModel` actually reads, per the "Avatars"
   section above), restart sddm, screenshot, confirm that specific animal renders (not just the
   letter-circle fallback) — this is the one check that directly answers "does Qt's SVG plugin
   actually load these files," which nothing static in this repo can answer.

## What is untested / unverified, in one place

- The entire QML runtime behavior of `Main.qml` — parsing, rendering, focus routing through the
  greeter's own Hyprland compositor, the shake animation's timing/amplitude. See "Ground truth
  this was checked against" above for exactly what upstream source each API claim rests on.
- Whether `qt6-svg` (or equivalent) is actually present so the avatar SVGs rasterize, rather than
  always falling back to the letter-circle — `PKGBUILD` now depends on it explicitly (issue #39),
  which should settle this, but that dependency line itself is unverified against a real
  `pacman -Si sddm` dependency tree.
- Whether `JetBrainsMono Nerd Font` (theme.conf's default `fontFamily`) is available to the
  greeter's own fontconfig, separate from whatever's available inside a logged-in session.
- Whether `config.parent`/`config.parents`/`config.kids` (from `theme.conf.user`, `posture_write_portal_conf`)
  actually arrive in `Main.qml`'s `config` property the way `ThemeConfig::setTo()`'s source says
  they should — confirmed by reading upstream source, not by a real engine loading this exact
  theme's `theme.conf.user` and reporting back the three values. Lower risk than the dropped
  `XMLHttpRequest` approach (no extra process environment, no `daemon-reload`, same code path
  theme.conf's own colors already exercise), but still unverified until a real VM boot confirms it.
- Whether the `Qt5Compat.GraphicalEffects` `OpacityMask` import is present in the greeter runtime;
  the package now declares `qt6-5compat`, but the circular avatar mask still needs a VM render check.
- Whether `/usr/share/sddm/faces/<account>.face.icon` (`posture_write_face_icon`) is really the
  file this stack's `UserModel` reads — confirmed against `UserModel.cpp`'s source and against the
  live VM's own finding that AccountsService's `Icon=` line alone was insufficient, but not yet
  confirmed to actually fix the rendering (see "Avatars" above and step 8 below).
- R-LOGIN-5 (parent password overrides a kid's own) — not implemented in this theme at all; see
  above. Needs a PAM-level change in a follow-up issue.
- `posture_remove_sddm_theme_dropin` — written, unit-tested directly (`test/shell.d/portal-test.sh`),
  but not yet called from anywhere (no Remove Kids Mode command exists in this checkout to call it
  from). `posture_write_face_icon`'s own removal counterpart (`posture_remove_face_icon`) similarly
  has no caller wired into "Remove Kids Mode" teardown yet, though it *is* called by
  `omarchy-kids-provision remove` for the per-kid case.
- Whether Ctrl+Shift+P actually reaches this QML given the greeter's compositor config, rather
  than being consumed earlier — Omarchy's own `default/sddm/hyprland.lua` has no binds of its own
  (confirmed by reading it), but the greeter's overall input routing wasn't otherwise checked.

## Verified live (2026-09-02, QEMU test VM)

A boot with a disk password whose LUKS slot maps to no kid recorded slot 4, the boot-login
unit wrote no autologin, and SDDM started the greeter with this theme (journal: `Loading theme
configuration from /usr/share/sddm/themes/omarchy-kids/theme.conf`, no QML warnings). One
face tile per account, clock, keyboard highlight. By keyboard only: Left moved the highlight
to Cy, Enter opened the password field under the tile, the kid password logged in and SDDM
started `omarchy-kids-session` for kid-cy, whose Hyprland and Level 1 launcher came up.
The bottom of the screen names the keys — "← → Choose · Enter Sign in · Ctrl+Shift+P Power off",
switching to "Enter Sign in · Esc Back" while typing — and a failed password is worded, not only
shaken. Not yet exercised live: the wrong-password shake and wording, the power-off chord, the
parent password on a kid tile (needs #15), and the display-name and avatar polish in #39.
`sddm-greeter-qt6 --test-mode` aborts inside a Hyprland session (stock theme too), so a real boot
into the portal is the only way to see the theme.

**Issue #39's fixes (display name, parent detection via `theme.conf.user`, avatars via
`.face.icon`) have not yet been verified against this VM or any other real engine.** Step 8 of
"How to test in the VM" above covers the avatar check; confirming the display name shows instead
of the bare account suffix, and that the parent tile is correctly distinguished even when the
machine owner's account starts with `kid-`, both need a fresh boot after `pacman -U`ing a build
that includes this issue's changes. Unlike the dropped `portal.json`/XHR design, there is no
process-environment inheritance to separately confirm here — `theme.conf.user` either shows up in
`config.parent`/`config.kids` on the next theme load or it doesn't, and a screenshot after step 4
above settles it directly.
Later the same night (#15): the parent's password typed on Cy's tile opened Cy's session
(journal: "Authentication for user kid-cy successful" through the `sddm` stack's parent-unlock
line), so a parent can open any kid's desktop from the portal without knowing the kid's password.
**2026-09-03, keyboard focus.** Left/Right went dead after a password field had been opened and
closed once (Enter, Esc): the field kept keyboard focus. `selectTile()` now hands focus back to
the key scope, and the field's own Escape goes through it. Seen and fixed on the VM: Left, Enter,
Esc, Left moves the highlight again; the parent tile opens its field from the keyboard.

## Names that root interpolates are validated now (2026-09-03)

`posture_polkit_admin_rule_text` builds `40-omarchy-kids.rules` with an *unquoted* heredoc and
interpolates `return ["unix-user:$parent"];`. A `parent=` value in `machine.conf` containing a
quote or a `]` either breaks the admin rule outright -- polkit then falls back to asking for
**root's** password rather than the parent's, which is the opposite of R-FND-3 -- or injects
JavaScript into the highest-value file on the box (review S9). `lib/posture.sh` now has one
`posture_valid_account` predicate, and both that writer and `posture_portal_conf_text` refuse to
produce anything for a name that fails it. Kid display names may contain `:` and `,`: the payload
encoding keeps them from shifting later records, and the QSettings layer preserves quotes,
backslashes, and controls in the file itself. `test/shell.d/portal-test.sh` covers both layers.

## SDDM face-icon resolution forensics (moved from `lib/posture.sh`, issue #49)

```text
--- SDDM face icons (issue #39, live VM finding) --------------------------

AccountsService's own Icon= key (posture_accountsservice_text above) is
NOT what SDDM's UserModel actually reads for the "icon" role on this
stack. UserModel's constructor (sddm/sddm's src/greeter/UserModel.cpp,
fetched 2026-09, confirmed by reading it directly) checks, in this
order: "<home>/.face.icon" first, then the literal path
"/var/lib/AccountsService/icons/<account>" (a cache file the real
accountsd daemon populates itself via its own D-Bus SetIconFile method
-- nothing in this repo ever calls that method, so this file is never
created here and its existence check always fails), then
"<FacesDir>/<account>.face.icon" (FacesDir defaults to
/usr/share/sddm/faces -- /usr/lib/sddm/sddm.conf.d/default.conf line
58). The third path is the one that actually has to exist on disk for
an avatar to render on this stack; posture_accountsservice_text's own
Icon= line is kept as-is (it may still matter to a D-Bus-backed
AccountsService client elsewhere, and removing a working write is
needless churn), it just isn't what SDDM itself reads.

Copied, not symlinked, and never under the kid's own home: "~/.face.icon"
is the *first* path UserModel checks, ahead of this one, and the kid's
home must stay untrusted (I-3) -- writing there would also hand the kid
a way to swap their own avatar file for something else read by root's
greeter process. Copying instead of pointing straight at
share/avatars/<avatar>.svg keeps this file's content independent of
wherever the package happens to install avatars, matching
posture_accountsservice_text's own reasoning for using a fixed,
real path rather than a scratch one for the *destination* -- the
*source* is still caller-supplied here (unlike the Icon= line's plain
string) because copying needs a real, readable file to copy from, and
the real command (omarchy-kids-provision) and its tests use different
real/scratch source directories (OMARCHY_KIDS_SHARE) the way
omarchy-kids-assert's hyprland-configs lock already does for
share/hyprland/*.lua.
```
