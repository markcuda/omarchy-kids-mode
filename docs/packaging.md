# Packaging (R-FND-1, R-BUILD-2, R-BUILD-4, R-TRUST-5)

`omarchy-kids` is one Arch package, built by the root `PKGBUILD` from this checkout. `source=()`
is empty by design (`PKGBUILD:8-10,34`), and `package()` reads files from `$startdir`. An AUR
(Arch User Repository) checkout must therefore contain the whole source tree, not only `PKGBUILD`.

## Building on the test laptop

Build only on the test laptop or in a VM. Do not build or install as root, and do not run this on
a development machine (`AGENTS.md`). From the checkout, as the normal user:

```sh
makepkg -sf
```

`-s` asks pacman to install missing declared dependencies. `-f` rebuilds an existing package with
the same version. The current package is `0.1.0-1`, so the result is
`omarchy-kids-0.1.0-1-x86_64.pkg.tar.zst`.

Install that package on the test system:

```sh
sudo pacman -U omarchy-kids-0.1.0-1-x86_64.pkg.tar.zst
```

The package's install scriptlet then creates its groups and reloads systemd when systemd is
running. It does not create a kid or apply Kids Mode locks. The installed pacman hook invokes
`omarchy-kids-assert --quiet` after the transaction; the wizard's Apply step also enables and
starts the required units, sockets, and timers.

On upgrade, `pre_upgrade` captures a regular legacy boot drop-in that contains the Kids Mode hook
before pacman replaces package files. `post_upgrade` preserves an explicit valid `boot=disk` or
`boot=portal` setting; when the setting is missing, it chooses disk only for a configured parent
and kid on a LUKS root with that legacy drop-in evidence, and chooses portal otherwise. It writes
the result through the trusted configuration command, reads it back, and restores the captured
drop-in only for disk mode. This preserves existing disk boots while making unconfigured,
unencrypted, or incomplete installations fail safe to portal mode as ownership of the active
drop-in moves from the package to the disk transition. The scriptlet delegates that decision to
`omarchy-kids-conf machine migrate boot`. It holds the shared boot-mode lock across the mode read,
any initial mode write and readback, and restoration or removal of the captured drop-in.

## AUR readiness (issue #32, R-BUILD-2)

The package is not ready for a first AUR upload yet. The local packaging pieces are mostly here,
but these items still need to happen:

- **Regenerate `.SRCINFO` on Arch.** The checked-in file has the current fields and dependencies,
  but it was written by hand. Run `makepkg --printsrcinfo > .SRCINFO`, review the diff, and keep
  the generated result. Compare `PKGBUILD:15-35` with `.SRCINFO:1-27`.
- **Build and inspect a clean package on Arch.** Run `makepkg -sf` from a clean clone that contains
  the whole checkout, inspect the package contents, and install it in the test VM before
  publishing. The file list comes from `PKGBUILD:37-123`; this checkout has no recorded clean
  Arch build here.
- **Run the package lint checks.** `namcap`, Arch's package linter, should check `PKGBUILD` and
  the built package. Resolve or consciously accept its findings. This is maintainer validation,
  not something the install scriptlet provides (`PKGBUILD:15-35,37-123`).
- **Create and upload the AUR package repository.** No AUR repository or first upload exists yet
  (`docs/install.md:19-31`).
  Because `source=()` is empty, that repository must include every path read by `package()`,
  including `bin/`, `lib/`, `initcpio/`, `systemd/`, `share/`, `desktop/`, `pacman/`, and
  `LICENSE` (`PKGBUILD:34,37-123`).
- **Choose the public scope.** `pkgver=0.1.0` describes this as an early build, and the runtime
  gaps remain documented in `docs/install.md` and the command docs. Decide whether the first AUR
  entry is an explicitly early package or wait for those checks before publishing
  (`PKGBUILD:15-18`, `docs/install.md:104-125`).

Already done in this checkout:

- `PKGBUILD` declares the package name, version, release, architecture, license, URL, required
  and optional dependencies, install scriptlet, and empty source list
  (`PKGBUILD:15-35`).
- `.SRCINFO` contains the matching package metadata and dependency lists (`.SRCINFO:1-27`). It
  still needs regeneration as described above.
- `package()` installs the commands, support libraries, mkinitcpio files, all `.service`,
  `.socket`, and `.timer` units, shared data, the SDDM theme, pacman hook, desktop entries, and
  license (`PKGBUILD:37-123`).
- `omarchy-kids.install` exists and defines `post_install`, `post_upgrade`, and `post_remove`
  (`omarchy-kids.install:23-36`).
- The pacman hook is present and triggers after install, upgrade, and removal of any package, then
  runs `/usr/bin/omarchy-kids-assert --quiet` (`pacman/omarchy-kids.hook:7-18`).

## What gets installed where

This table follows `package()` rather than every path listed in the specification. Some runtime
files are created later by the commands.

| Repo path | Installed to | Mode | Note |
| --- | --- | --- | --- |
| `bin/omarchy-kids`, `bin/omarchy-kids-*` | `/usr/bin/` | 755 | All command files present in `bin/` |
| `lib/*.sh`, `lib/*.py` | `/usr/lib/omarchy-kids/` | 644 | Shared command libraries and helpers |
| `initcpio/hooks/*` | `/usr/lib/initcpio/hooks/` | 755 | mkinitcpio runtime hooks |
| `initcpio/install/*` | `/usr/lib/initcpio/install/` | 755 | mkinitcpio install hooks |
| `initcpio/omarchy-kids-open` | `/usr/lib/initcpio/omarchy-kids-open` | 755 | Boot-time cryptsetup helper |
| `share/boot/omarchy_kids.conf` | `/usr/share/omarchy-kids/boot/omarchy_kids.conf` | 644 | Package-owned inactive template; the disk transition copies it to `/etc/mkinitcpio.conf.d/omarchy_kids.conf` |
| `systemd/*.service`, `systemd/*.socket`, `systemd/*.timer` | `/usr/lib/systemd/system/` | 644 | Auth, Wi-Fi, boot/login, assertion, screen-time, request, and app-install units |
| `systemd/*.user.service` | `/usr/lib/systemd/user/` (the `.user` suffix dropped) | 644 | The parent's desktop notifier (N-9); the package installs it, `omarchy-kids-bar notify-enable` enables it per session, and the package never enables it |
| `/etc/systemd/system/omarchy-kids-relayd.service.d/away.conf` | created at runtime | 644 | Not shipped: `omarchy-kids-notify away tailnet` (N-10) writes it to widen the relay's fence to the parent's VPN range; `away off` removes it, and `omarchy-kids-remove` removes it with everything else |
| `share/**` | `/usr/share/omarchy-kids/` | source modes | Bands, packs, desktop data, policy, avatars, menus, the kid theme collection (`share/themes-kids/`, offered by `theme_list_installed`), the data-entry template (`share/applications/omarchy-kids-data.desktop`), and QML |
| `share/sddm-theme/**` | `/usr/share/sddm/themes/omarchy-kids/` | source modes | The SDDM greeter theme is copied there separately |
| `pacman/omarchy-kids.hook` | `/usr/share/libalpm/hooks/omarchy-kids.hook` | 644 | Post-transaction lock check |
| `desktop/omarchy-kids.desktop` | `/usr/share/applications/omarchy-kids.desktop` | 644 | App-drawer entry |
| `desktop/omarchy-kids-session.desktop` | `/usr/share/wayland-sessions/omarchy-kids.desktop` | 644 | Kid Wayland session entry |
| `LICENSE` | `/usr/share/licenses/omarchy-kids/LICENSE` | 644 | MIT license text |

The package does not create these runtime paths itself: `/etc/omarchy-kids/kids/<account>.conf`,
`/etc/omarchy-kids/machine.conf`, `/etc/omarchy-kids/luks-slots`, the transition-owned
`/etc/mkinitcpio.conf.d/omarchy_kids.conf`, Chromium policy files,
polkit and PAM changes, SDDM runtime configuration, `/run/omarchy-kids/`, or
`/var/lib/omarchy-kids/`. The wizard, provisioning, web, assertion, and removal commands create
or remove them as their jobs require.

### Groups

`post_install` and `post_upgrade` call `groupadd -f` for six groups, so repeating an install or
upgrade is safe (`omarchy-kids.install:8-14`):

- `omarchy-kids` for kid accounts
- `omarchy-kids-3-5`, `omarchy-kids-6-8`, `omarchy-kids-9-12`, and `omarchy-kids-13plus` for age bands
- `omarchy-parents` for the parent account

The package does not add accounts to these groups. `omarchy-kids-provision` does that when a
parent applies a kid setup. The scriptlet also runs `systemctl daemon-reload` when
`/run/systemd/system` exists (`omarchy-kids.install:16-21`). It enables and starts
`omarchy-kids-authd.socket` at that point so the first wizard run has a verifier available; this
is the one unit exception. It does not enable the other units itself.

`post_remove` only prints a notice. It leaves the groups, kid accounts, homes, disk slots, and
runtime configuration in place (`omarchy-kids.install:34-36`).

## The pacman hook

The installed hook runs after every pacman transaction, including transactions unrelated to Kids
Mode (`pacman/omarchy-kids.hook:7-18`). It calls `omarchy-kids-assert --quiet`, which checks and
repairs the locks that have been provisioned. The hook is a trigger; it does not replace the
wizard's Apply step or Remove Kids Mode.

## Removing

First run Remove Kids Mode from the app, or run `omarchy-kids remove-kids-mode`. That command
removes the kid accounts and machine locks, and by default moves each home to the parent's
`Kids Mode/<name>/` directory. Use `--delete-homes` only when deleting those files is intended.

Then remove the package:

```sh
sudo pacman -R omarchy-kids
```

`pacman -R` removes the files installed by `package()`, subject to pacman's normal `backup=` file
rules, and runs `post_remove`. It does not remove the groups, kid accounts, homes, disk slots, or
runtime paths. Removing the package first is not the same as Remove Kids Mode and leaves the
machine partially configured.
