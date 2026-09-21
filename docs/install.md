# Installing Kids Mode

These instructions describe the current checkout. It is an early build, not an AUR package yet.
If you'd rather read code than prose, `docs/packaging.md` covers the package side.

## Before you start

- **An Arch/Omarchy 4.0.x install and a parent account that can use `sudo`.** The package was
  built and tested against Omarchy 4.0.2. Nothing here has run on 4.1 or later.
- **Optional disk encryption.** On an encrypted disk, a kid password can also be added as a LUKS
  disk-unlock key. On an unencrypted disk, the package and account setup can still run, but boot
  cannot choose a session from a disk-unlock key.
- **Your own login password**, the one you type to unlock your account. Kids Mode never asks for
  anything else, no `root` password or separate admin password, and stores no password itself
  (SPEC.md I-8). Every parent-only prompt checks what you type against your own account.

## Install

There is no AUR package yet. Build from the complete checkout:

```sh
git clone https://github.com/markcuda/omarchy-kids-mode
cd omarchy-kids-sandbox
makepkg -si
```

`-s` asks pacman to resolve the package's declared dependencies. `-i` installs the package after
the build. Run `makepkg` as the normal parent account, never as root or with `sudo`. The package
uses the files in this checkout, so do not copy out only `PKGBUILD`.

After a future AUR upload, an AUR helper such as `yay` can install it with `yay -S omarchy-kids`.

## Start it

```sh
omarchy-kids
```

Or open **Kids Mode** from the app drawer. The first run opens the parent wizard. It asks for your
password, then takes you through one kid at a time: name, face, age band, Simple or Advanced
settings, a kid password, a summary, and Apply. With a provisioned kid, `omarchy-kids` opens the
parent panel. The panel is also where you add another kid and review settings or screen time.

The setup screens preview Kids Mode changes until you choose **Apply**. The wizard may start
downloading repository starter-pack packages after the age screen if your `sudo` credential is
already cached. It does not create the kid account or write Kids Mode's profiles and locks until
Apply. Apply also enables and starts the package's required systemd units, sockets, and timers.

## What changes on the machine

The package install and the wizard do different jobs. The package installs commands, support
files, systemd unit files, the boot hook, the pacman hook, desktop entries, and the license. Its
install scriptlet creates six groups and reloads systemd when systemd is running. It does not add
a kid or apply the machine locks.

Apply creates the account and runtime files below. `docs/assert.md` has the lock list and the
checks that repair it after updates and at boot.

**Per kid, once they're added:**

- A real Unix account, in the Kids Mode and age-band groups, with no `sudo` or `wheel` membership.
- A home bind mount with `noexec,nosuid,nodev`, plus private `/tmp` and `/dev/shm` mounts.
- On an encrypted disk, a LUKS passphrase slot, so the kid password can unlock the machine and
  select their desktop. No slot is added on an unencrypted disk.
- A face tile and display name on the login screen.
- A managed Chromium policy for the kid's age band.

**Machine-level changes after the first kid is added:**

- Polkit rules. Polkit is the system service that decides whether a desktop action needs approval.
  Kids Mode routes allowed parent approvals to the parent's password and denies selected actions.
- The Kids Mode login theme, PAM lines for the parent verifier, and masked text consoles tty2
  through tty6. PAM is Linux's login-authentication system.
- The package's boot/login units, password and Wi-Fi sockets, screen-time and request timers, and
  the mkinitcpio boot hook. The boot hook is relevant to the encrypted-disk path.
- A per-band Chromium policy file with mode 0640.
- If a Limine configuration exists, the default lock hides old Snapper snapshot entries from the
  boot menu. `omarchy-kids-conf`'s `boot.snapshot_entries` setting controls that lock.

Kids Mode never silently restricts the parent's home, browser, DNS, or session. A parent can
explicitly ask it to add its bar widget or hide Kids Mode apps in the parent's application menu;
those are the opt-in parent actions allowed by SPEC.md I-1. If an operation changes the parent's
account without that choice, stop and report it through this repository's `SECURITY.md`.

## Updating

`pacman -Syu` (or `omarchy update`) upgrades the package normally. The installed pacman hook
invokes `omarchy-kids-assert --quiet` after every package transaction. That command checks and
tries to repair Kids Mode locks. Run `omarchy-kids-assert` without `--quiet` for the full report,
or use `omarchy-kids-check` for a read-only check.

## Removing

Two separate steps:

1. **Remove Kids Mode** from the panel, or run `omarchy-kids remove-kids-mode`. This reverses the
   locks and removes the kid accounts. By default it keeps each home by moving it to
   `~/Kids Mode/<name>/` under your own home. `--delete-homes` deletes those homes instead. If
   Snapper is installed, the command offers a snapshot before it starts.
2. Run `sudo pacman -R omarchy-kids` to remove the package itself. Skipping straight to this step
   leaves the runtime locks, groups, and kid accounts in place. `pacman -R` alone is not Remove
   Kids Mode.

## What isn't ready yet

This is early: the spec is further along than the build. Read this before you hand a kid their
password.

- **Pause** is not built. The exit modal offers Finish only. Omarchy
  4.0.2 cannot open a second SDDM login screen while a session is live
  (`bin/omarchy-kids-exit:44-45,150-153`, `docs/phase1/V1.md`).
- **The firmware password** is outside Kids Mode. Set one in the machine's firmware before
  relying on the software locks; the package cannot set it for you (`SPEC.md I-9`,
  `docs/check.md`).
- **Wi-Fi** has only been checked in a VM without a wireless device. Real join, forget, picker,
  and captive-portal checks still need the test laptop (`docs/wifi.md:197-204`). A parent-mode
  kid's request opening the ask modal is not built (`docs/wifi.md:137-146`).
- **The portal and panel still have live gaps.** The portal's wrong-password and display-name/avatar
  paths need another live check (`docs/portal.md:272-291`); Requests, Web, Apps, Password, and
  Remove have not been exercised live (`docs/panel.md:156-164`).
- **Ask later**, plus app and site requests, have not been exercised live (`docs/ask.md:197-204`).
- Phase 1 still has failed or open checks. Read `docs/phase1/` before treating this as a finished
  product.

Each command's doc under `docs/` has a "Verified live" section. Use those notes for the current
test status.
