# L2 · Boot & System Hardening

_status: draft · updated 2026-09-01 · lead: open · primary evidence: `research/reports/03-system-hardening-and-sandboxing.md`, 01_

## Purpose

Make sure the rules survive a reboot: nobody gets root from the boot menu, a TTY, a snapshot, or a USB stick
without the parent's credentials — and be honest about where that stops.

## What we know (verified — report 03 §1)

- **Boot chain:** UEFI → **Limine** booting a **UKI** (`ENABLE_UKI=yes`, `CUSTOM_UKI_NAME="omarchy"`) from an
  **unencrypted ESP at `/boot`** → `encrypt` initcpio hook (LUKS, mandatory; `cryptdevice=`) → single btrfs with
  subvolumes → **SDDM** (Wayland greeter running Hyprland with a root-owned `--config`) with **permanent autologin**
  on encrypted installs → uwsm → Hyprland → omarchy-shell. **Secure Boot and TPM must be off to install.**
  [R03-S16][R03-S19][R03-S6][R03-S12][R03-S20]
- **Limine has no password feature.** `editor_enabled` defaults to **yes** and Omarchy leaves it unset; the only
  locks are `editor_enabled: no` and config-hash enrollment (`limine-enroll-config`, which bricks boot if you edit
  and forget to re-enroll). `omarchy-refresh-limine` **overwrites `/boot/limine.conf`** — local hardening is lost
  on refresh unless re-applied by a hook. `Setup > Direct Boot` adds an EFI entry straight to the UKI (skips the
  menu; refused on AMI/Apple firmware). [R03-S33][R03-S34][R03-S16][R03-S17][R03-S4]
- **Snapshots:** Snapper `root` only (`NUMBER_LIMIT=5`, no timeline), synced into the Limine menu
  (`MAX_SNAPSHOT_ENTRIES=6`, `BOOT_ORDER="*, *fallback, Snapshots"`). Anyone at the menu can **boot** a snapshot
  (overlayfs, changes discarded) — including one from **before Kids Mode**, which autologs into the parent's session
  if that autologin predates hardening; **restore** needs `sudo limine-snapper-restore`. `/home` isn't snapshotted.
  `Setup > Reset Computer` restores the installer baseline (ISO installs only). [R03-S18][R03-S16][R03-S4][R03-S17][R03-S3]
- **TTYs:** the SDDM migration **enabled `getty@tty1`**; autovt gettys spawn on tty2–6 by default;
  `omarchy-provision-owner` set **root's password = owner's**; the manual tells locked-out users to `Ctrl+Alt+F2`,
  log in as root and `faillock --reset`. `pam_faillock` deny=10 / 120 s. [R03-S21][R03-S12][R03-S7][R03-S13]
- **Ctrl+Alt+Fn is hardcoded in Hyprland** (`CKeybindManager::handleVT`, checked before user binds; not
  configurable). Neutralise only via XKB (`kb_options = "srvrkeys:none"`, verified in `rules/base.xml` and
  `srvr_ctrl(no_srvr_keys)`) or by making VTs useless (`NAutoVTs=0`, `ReserveVT=0`, mask gettys, lock root).
  [R03-S55][R03-S56][R03-S43][R03-S42]
- Kernel: Arch `kernel.sysrq=16` (SysRq-K/B already off); unprivileged user namespaces on (bwrap works); Yama
  `ptrace_scope=1`. AppArmor is supported by the kernel and packaged but not shipped by Omarchy; enabling it means a
  `limine-entry-tool.d` cmdline drop-in + `limine-update`. [R03-S51][R03-S41][R03-S40]
- ufw deny-in/allow-out; egress is L3's job. [R03-S22]

## Threats × mitigations (Omarchy-specific)

| Threat | Mitigation | Residual |
| --- | --- | --- |
| Live USB | **UEFI admin password + boot order locked + USB/network boot off** (parent card; can't be automated). LUKS makes the disk unreadable — *unless the child knows the passphrase*, which on a machine they boot alone they do. | ESP is unencrypted regardless; CMOS reset; custom-key Secure Boot is the only ESP tamper-proofing and is unsupported by Omarchy |
| Limine editor / cmdline | `editor_enabled: no` in `/boot/limine.conf` **re-applied by a `post-update.d` hook**; Direct Boot + firmware password; (Fortress) config-hash enrollment | Whether the editor can inject `init=/bin/bash` into a UKI entry needs a hands-on test (OQ-20); any such trick still hits the LUKS prompt |
| Boot a pre-Kids-Mode snapshot | Prune pre-hardening snapshots; Kids Mode re-locks on first boot after any rollback via hook; optionally `MAX_SNAPSHOT_ENTRIES=0` / drop `Snapshots` from `BOOT_ORDER` (loses menu rollback); Direct Boot + firmware password | New snapshots after hardening are fine |
| VT switch → TTY login as parent/root | XKB `srvrkeys:none` in the kid session; `NAutoVTs=0`, `ReserveVT=0`; mask `getty@tty1`; `passwd -l root`; persistent faillock | Parent recovery path shrinks — document SSH or live-USB recovery |
| Session crash → unlocked state / TTY | SDDM `Relogin=false` → greeter, never a bare TTY (if gettys masked); `misc.allow_session_lock_restore=true`; disable `omarchy-crash-watch` (AI diagnosis terminal) in the kid session | — |
| Factory reset / snapshot restore | Both need sudo → the parent's password; gate confirmed by design | Verify on host |
| Kid knows the LUKS passphrase | Accepted on "the kid's own machine"; otherwise the parent types it | Shoulder-surfing; TPM2/PIN would need the unsupported `sd-encrypt` path |

## Hardening tiers (report 03)

| Tier | Contents | Who |
| --- | --- | --- |
| **Basic** (S) | `kid` user, no groups; polkit deny pack; noexec bind on kid home; root-owned kid session config with minimal binds; parent keeps autologin and types LUKS; `passwd -l root`; parent sudo hygiene | Young children; parent present at boot |
| **Standard** (M) | Basic + UEFI admin password & boot-order lock; **Direct Boot**; `editor_enabled: no` + post-update hook; prune pre-hardening snapshots; autologin moved to `kid` (parent at the greeter); `NAutoVTs=0`/`ReserveVT=0`/mask `getty@tty1`; XKB `srvrkeys:none`; Hyprland `enforce_permissions` with `plugin`/`screencopy` deny; bwrap launchers; flatpak absent or malcontent-filtered; disable crash-watch/agent tooling in kid session | Kids who boot the machine alone |
| **Fortress** (L) | Standard + custom-key Secure Boot with Limine config-hash enrollment; TPM2/PIN via `sd-encrypt` migration; AppArmor with authored profiles; rootless podman terminal; optional homed — **all unsupported upstream and update-fragile** | Shared machines with capable teens; accept maintenance |

**Update resilience:** `/etc/polkit-1/rules.d`, `/etc/systemd/logind.conf.d`, `/etc/sddm.conf.d`,
`/etc/limine-entry-tool.d`, `/usr/local/share/wayland-sessions`, `/etc/omarchy-kids/` survive `omarchy-refresh-*`;
**`/boot/limine.conf` does not** → hook it.

## Interfaces

Trusted base for L1/L3/L4/L9; verified by L11's `omarchy-kids-check` (prints the tier reached).

## Workstreams & backlog seeds

BOOT-01 `omarchy-kids-boot-harden` (editor off, snapshot entries, post-update hook, firmware/Direct-Boot checklist,
rollback) · BOOT-02 snapshot policy · BOOT-03 TTY/VT kit (logind drop-in, getty masking, root lock, recovery doc) ·
BOOT-04 crash/exit test · BOOT-05 firmware-password parent card · BOOT-06 UKI + Limine editor `init=` test (OQ-20) ·
BOOT-07 upstream asks: `editor_enabled: no` default + Limine post-refresh hook; Hyprland feature request for a VT-switch config switch.

## Open questions

OQ-4 (largely answered: no Limine password; use editor-off + Direct Boot + firmware password), OQ-19, OQ-20;
Secure Boot in v1? (no — Fortress only).
