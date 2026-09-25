# Boot and startup (R-BOOT)

How Kids Mode gets from "power on" to the right desktop, the exact files involved, the
fail-safe list, how to verify the hook is actually in the image, and how to remove it.

## Startup, end to end

1. **Firmware → Limine → UKI.** Limine loads the UKI built by `mkinitcpio -P`. The kernel
   cmdline (baked into the UKI, contributed by drop-ins under `/etc/limine-entry-tool.d/*.conf`)
   carries `cryptdevice=PARTUUID=<uuid>:root` and `root=/dev/mapper/root`.
2. **Early boot, our hook, before `encrypt`.** `omarchy-kids-unlock` runs. It parses
   `cryptdevice` the same way the stock `encrypt` hook does and, unless it steps aside (see
   Fail-safe below), prompts for the passphrase exactly like `encrypt` does — plymouth
   `ask-for-password` with a `--command`, or a plain console loop if plymouth isn't up. The
   `--command` (and the console loop) both run `/usr/lib/initcpio/omarchy-kids-open`, which
   pipes the passphrase straight into `cryptsetup open --key-file=-` and, on success, reads
   which key slot unlocked the volume out of cryptsetup's own `Key slot N unlocked.` message
   and writes `N` to `/run/omarchy-kids/boot-slot`.
3. **Early boot, stock `encrypt` hook.** Sees `/dev/mapper/root` already exists (our hook made
   it) and returns immediately — `Device root already exists, not doing any crypt setup.` If our
   hook gave up for any reason, nothing exists yet and `encrypt` prompts fresh, exactly as it
   would if our hook weren't installed at all.
4. **`switch_root`.** `/run` (with `boot-slot` in it, if we wrote one) carries over from the
   initramfs into the booted system.
5. **`omarchy-kids-boot-login.service`, before `display-manager.service`.** It reads the trusted
   `boot=` setting first. Portal mode is a no-op. In disk mode a missing
   `/run/omarchy-kids/boot-slot` writes an empty `User=`, so the machine falls to the portal -- a
   kid who opened the disk after the hook stepped aside never lands on the parent's autologin. In
   disk mode with a recorded slot, it maps the slot through
   `/etc/omarchy-kids/luks-slots`, and writes `/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf`
   with `[Autologin] User=<account>` (and `Session=<session>`) for the mapped account — the
   parent's slot maps to the parent and the stock session, unchanged from today. The `0=<parent>`
   line that makes that mapping exist is written by `omarchy-kids-conf machine set parent <name>`
   (`lib/kids.sh`'s `luks_slots_record_parent`, docs/conf.md) the moment `machine.conf`'s `parent=`
   is — the wizard's Apply step, first thing it does, on a fresh install, and again on every
   provision after "Remove Kids Mode" deletes the whole `$ETC` tree; nothing else in this repo
   ever writes it. Without that line, a boot unlocked with the parent's own disk password maps to
   nothing and lands on the portal below instead of their desktop. An unmapped slot writes an
   empty `User=` so the portal shows instead of guessing. Malformed disk input does the same
   where possible and returns nonzero, but the unit ignores that status so SDDM still starts.
6. **SDDM starts**, reads its `conf.d` in order, and autologs whoever `zz-omarchy-kids-autologin.conf`
   says (or shows the portal if `User=` is empty).
7. **`omarchy-kids-boot-login-cleanup.service`, after `display-manager.service`, 20s later.**
   In disk mode, it removes only the drop-in whose inode boot-login marked under `/run` on this
   boot. Portal mode writes nothing. A later logout therefore never re-autologs anyone.

## The exact files

| File | What |
| --- | --- |
| `initcpio/hooks/omarchy-kids-unlock` → `/usr/lib/initcpio/hooks/omarchy-kids-unlock` | The runtime hook (ash, R-BOOT-1) |
| `initcpio/install/omarchy-kids-unlock` → `/usr/lib/initcpio/install/omarchy-kids-unlock` | mkinitcpio install file: pulls in `dm-crypt`, `cryptsetup`, the helper, same as upstream's `install/encrypt` |
| `initcpio/omarchy-kids-open` → `/usr/lib/initcpio/omarchy-kids-open` | The passphrase-reading helper the hook shells out to |
| `share/boot/omarchy_kids.conf` → `/usr/share/omarchy-kids/boot/omarchy_kids.conf` | Package-owned inactive template; disk mode copies it to the transition-owned `/etc/mkinitcpio.conf.d/omarchy_kids.conf` (R-BOOT-2) |
| `bin/omarchy-kids-boot-login` → `/usr/bin/omarchy-kids-boot-login` | Selects or cleans the disk-mode SDDM autologin drop-in |
| `systemd/omarchy-kids-boot-login.service` | Writes the drop-in, before `display-manager.service` |
| `systemd/omarchy-kids-boot-login-cleanup.service` | Removes it, after `display-manager.service` |
| `/run/omarchy-kids/boot-slot` | root 0600, dir 0755 — the slot number that unlocked root this boot |
| `/etc/omarchy-kids/luks-slots` | root 0600 — `slot=account`, or `slot=account:session` (R-SEC-4) |
| `/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf` | Written only for a recorded disk-mode slot, removed ~20s after the display manager starts |
| `/run/omarchy-kids/boot-login-dropin` | root 0600 inode marker proving cleanup owns the current drop-in |

### `luks-slots` format

One mapping per line, `slot=account` or the legacy `slot=account:session`. Blank lines and `#`
comments are ignored; no whitespace around `=` or `:`. Duplicate slots or accounts invalidate
the map. Boot-login parses and validates a legacy session suffix but never trusts it to choose a
session. The parent recorded in trusted `machine.conf` selects `omarchy.desktop`; an account with
a root-owned `0644` profile under the root-owned kids directory selects `omarchy-kids.desktop`.
Anything else is an invalid mapping and selects the portal. Example:

```text
0=mark
2=kid-ada
3=kid-ben
```text

## Fail-safe list (I-9: never a machine that will not boot)

`omarchy-kids-unlock` does nothing and returns success — leaving the stock `encrypt` hook to
run exactly as it always has — whenever:

- there is no `cryptdevice=` on the kernel cmdline;
- the target device is not a LUKS volume (`cryptsetup isLuks` fails);
- `/dev/mapper/<name>` already exists (something already unlocked it);
- a keyfile boot is configured (`cryptkey=` is set — e.g. the test laptop's auto-unlock);
- the helper binary (`/usr/lib/initcpio/omarchy-kids-open`) is missing from the image;
- three password attempts fail (`--number-of-tries=3` under plymouth, or three tries in the
  console fallback loop).

`omarchy-kids-boot-login.service` runs on every boot. Portal mode changes nothing, so Omarchy's
stock autologin remains byte-for-byte; in disk mode a missing `boot-slot` writes an empty `User=`
and the machine falls to the portal. An unrecognized numeric slot writes
an empty `User=`, showing the portal rather than guessing. A mapped account with no trusted parent
or kid role, unsafe input, or malformed input also tries that safe override, returns 1 for
diagnosis, and cannot block SDDM startup.

`omarchy-kids-boot-login` itself never writes the passphrase anywhere; it only ever sees a slot
*number*. The helper (`omarchy-kids-open`) never writes the passphrase anywhere either — it goes
straight from stdin into `cryptsetup --key-file=-`, and the file it captures cryptsetup's
stdout/stderr into is deleted immediately after the slot number is parsed out of it.

R-BOOT-5's safety check (verifying the current initramfs still contains the hook after every
kernel/mkinitcpio update, and rebuilding it if not) is a separate command, not part of this
change.

## Verifying the hook is actually in the built image

```sh
# Pull the initramfs (or UKI's .initrd section) apart and confirm the hook's runscript made it in
objcopy -O binary --only-section=.initrd /boot/EFI/Linux/arch-linux.efi initrd.img
lsinitcpio initrd.img | grep omarchy-kids-unlock
# Expect to see the hook's runtime script and the helper:
#   usr/lib/initcpio/hooks/omarchy-kids-unlock  (or the compiled runscript form)
#   usr/lib/initcpio/omarchy-kids-open
```text

If a plain (non-UKI) initramfs is in use instead, skip the `objcopy` step and run `lsinitcpio`
directly on `/boot/initramfs-linux.img`.

## Removing the hook

1. Remove `omarchy-kids-unlock` from `HOOKS` — delete the transition-owned
   `/etc/mkinitcpio.conf.d/omarchy_kids.conf` or, in
   `/etc/mkinitcpio.conf` itself, take `omarchy-kids-unlock` back out if it was ever hand-added
   there.
2. `sudo mkinitcpio -P` to rebuild every installed kernel's image without it.
3. Confirm with the verification command above that `omarchy-kids-unlock` is gone from the
   rebuilt image.
4. `systemctl disable --now omarchy-kids-boot-login.service omarchy-kids-boot-login-cleanup.service`
   and remove `/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf` if present — Omarchy's own
   autologin drop-in (if any) then applies again, unchanged.

Remove Kids Mode (R-FND-6 / §5.2 Remove flow) does all four steps before the package is removed;
plain package removal leaves runtime state in place, as documented in `docs/packaging.md`.

## Why the drop-in uses an underscore

R-BOOT-2 names the drop-in `/etc/mkinitcpio.conf.d/omarchy_kids.conf` (SPEC.md, underscore on
purpose) and requires it to rebuild `HOOKS` with the Kids Mode hook before `encrypt` and do
nothing when `encrypt` is absent. Why the underscore: `/etc/mkinitcpio.conf.d/*.conf`
is sourced in lexical (byte) order, and on the reference machine `HOOKS` is *assigned* (not
appended to) by `/etc/mkinitcpio.conf.d/omarchy_hooks.conf`. A hyphen (`0x2D`) sorts before an
underscore (`0x5F`), so a literal `omarchy-kids.conf` would be sourced *before*
`omarchy_hooks.conf` runs, see no `HOOKS` array worth editing yet, insert nothing, and then have
that (nonexistent) edit thrown away the moment `omarchy_hooks.conf` assigns `HOOKS` afterward.
Every real boot would silently end up with the hook never added — exactly the failure mode I-9
exists to rule out. Naming it `omarchy_kids.conf` sorts it immediately after
`omarchy_hooks.conf`, which is what R-BOOT-2 actually needs to work. `test/shell.d/mkinitcpio-conf-test.sh`
and this section are the record of why.

## `boot-login` decides by trusted role, not the map (2026-09-04)

The slot map records which account unlocked the disk. It does not authorize a session. Boot-login
derives that from package-owned records: the exact `parent=` account in trusted `machine.conf`
gets the stock session, and an account with a trusted provisioned profile gets the kid session.
An explicit `:omarchy` suffix cannot send a kid to the stock session or bless an unknown account.
`test/shell.d/boot-login-test.sh` proves both cases and gives the stock-session case a fixture whose
recorded parent really is `kid-test`.

## Fixed root paths

Boot-login accepts no path environment variables. It resolves `lib/` from its own installed
location and uses fixed `/run` and `/etc` paths. Tests copy the command and libraries, then
substitute those constants in the copy. This keeps an empty-environment systemd run working
without letting caller-controlled state choose boot files or code.

## Shared mode-transition lock

Ticket #93's shared root-created mode-transition lock exists (`lib/boot-mode.sh`'s
`boot_mode_lock_acquire`), but boot-login still reads the trusted mode without holding it
(`bin/omarchy-kids-boot-login`), so the review's read-then-act/report race remains open. Closing it
means boot-login's one
mode-read/action boundary and check's one mode-read/section-dispatch boundary will hold that shared
lock. This ticket does not add a second lock contract.
