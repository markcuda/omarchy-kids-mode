# L1 · Commissioning & Accounts

_status: draft · updated 2026-09-01 · lead: open · primary evidence: `research/reports/03-system-hardening-and-sandboxing.md`, 01, 02_

## Purpose

The parent-run setup that turns an Omarchy machine into a child's machine: which account the child uses, what
that account may do, how the parent authenticates to change things, and how several kids share one box.

## What we know (verified)

- **Omarchy is single-user by design** ("not part of the design" — maintainer, Discussion #532; "multi-user coming
  in 4.1" is a second-hand community post). The `agent-accounts` branch concerns **AI-provider subscription
  accounts, not Unix users** (report 03 corrects report 01's guess). [R03-S30][R03-S29][R01-S23]
- **First boot (`omarchy-provision-owner`)** creates the owner with `useradd -m -G wheel … -s /bin/bash`, sets the
  user password **and the root password to the same value**, writes `%wheel ALL=(ALL:ALL) ALL`, and on encrypted
  installs keeps **SDDM autologin permanently** ("the LUKS prompt is the auth boundary"). The 3.x→SDDM migration
  also **enabled `getty@tty1`**. [R03-S12][R03-S21]
- **The packaging supports N users**: `/etc/skel` seed → `omarchy-provision-user` → per-user migrations;
  SDDM's greeter lists users with uid ≥ 1000; a second `wayland-sessions/*.desktop` entry is exactly how Omarchy
  launches its own session (`uwsm start … Hyprland`) and its greeter runs Hyprland with a **root-owned config via
  `--config`**. Community members already run multiple users via SDDM/ly. [R03-S20][R03-S27][R03-S58][R03-S30]
- **sudo/polkit facts:** wheel = polkit admin (a kid-triggered prompt asks for the *parent's* password; 10 wrong
  tries lock the parent for 2 minutes — a child-caused DoS); `omarchy-sudo-passwordless` opens a 15-minute
  `NOPASSWD: ALL` window; `omarchy-sudo-keepalive` refreshes the timestamp every 60 s; FIDO2 enrolment makes
  `pam_u2f` *sufficient* for sudo/polkit (a plugged-in key = no password). [R03-S38][R03-S13][R03-S15][R03-S28]
- **Groups:** never `wheel`, `docker` (root-equivalent), `adm`, `storage`, `disk`, `uucp`; also not
  `audio`/`video`/`input` — logind seat ACLs grant devices to the active session, and the `audio` group breaks
  user switching. [R03-S48][R03-S23]
- Prior art: age bands as **real users/sessions** (PrimTux, Edubuntu, DoudouLinux); enforcement as a logind/PAM/
  daemon property, never UI. malcontent's accounts-service policy schema is reusable; its enforcement is not. [R02-S41][R02-S11][R02-S9][R02-S6]
- Parents expect a PIN for in-session approvals with recovery via the parent's own credential, and "resets require
  the parent password". [R07-S47]–[R07-S49]

## Account model (OQ-2 → RFC-01) — report 03's verdict

| Option | How | Verdict |
| --- | --- | --- |
| **A · Separate `kid` Unix user + its own SDDM session** | `useradd -m -s /bin/bash kid` (no supplementary groups); session entry `/usr/local/share/wayland-sessions/omarchy-kid.desktop` → `uwsm start -- Hyprland --config /etc/omarchy-kids/hyprland.lua` (**root-owned** Lua; `package.path` pinned; `omarchy_default_bindings=false`); kid home bind-remounted `nosuid,nodev,noexec`; polkit deny pack; either keep the parent's autologin (parent logs out → greeter → kid) or **move autologin to `kid`** and the parent authenticates at the greeter | **Recommended — works on 4.0.2 today** |
| B · "Kid mode" toggle inside the parent's session | Same uid, same sudo timestamp (keepalive!), same polkit identity, same FIDO2, same browser profile, same `hyprctl` socket; a submap can't demand a password and `submap reset` undoes it | **UX only** — supervised co-use with toddlers, never a boundary |
| C · systemd-homed | Per-user LUKS home; can't autologin; isolation runs the wrong way for a kid (parent wants visibility) | Fortress-only, optional |
| D · "The kid's own machine" (whole install is the child's) | Deferred provisioning / `cidata`; parent has no account | Fine for a gift laptop — but then the child knows the LUKS passphrase and *is* the owner; apply A on top (parent as the wheel user, child as `kid`) |

Session switching = logout → greeter (no fast user switch in Hyprland); SDDM `Relogin=false` means a crashed kid
session returns to the greeter, not a TTY. [R03-S58]

## Commissioning steps (proposal for `omarchy-kids-setup enable`, Basic tier)

1. Snapper snapshot "before kids mode" (L11); print what will change.
2. `kid` user (or one per child): no groups; home bind-remount `nosuid,nodev,noexec` (L4); `omarchy-kids` group
   for polkit matching; skel seed; **no** agent-skill symlinks.
3. **Root of trust = the parent's wheel account.** `passwd -l root` (Omarchy set it to the owner's password);
   parent sudo hygiene (`timestamp_type=tty`, `timestamp_timeout=2`); warn about `omarchy-sudo-passwordless`,
   keepalive and FIDO2 keys while a child is present. Persistent faillock dir.
4. Polkit deny pack `/etc/polkit-1/rules.d/10-omarchy-kids.rules` (`root:polkitd`) for `subject.isInGroup("omarchy-kids")`:
   udisks2 `filesystem-mount*`, `encrypted-unlock*`, `loop-setup`; prefix `org.freedesktop.NetworkManager.`;
   `org.freedesktop.systemd1.manage-units`; Flatpak `app-install`/`runtime-install`/`modify-repo`/
   `install-bundle`/`override-parental-controls*`; optionally `login1.power-off*`/`reboot*` (or allow — a child
   powering off is a feature). Verify IDs with `pkaction` on the host. **Deny returns no prompt** — so the kid can't
   lock the parent out by guessing.
5. Kid session entry + root-owned Hyprland config (L5 consumes; L2 hardens: XKB `srvrkeys:none`, no gettys).
6. logind drop-in: `KillOnlyUsers=kid` (`KillUserProcesses` for leftovers).
7. Apply preset (L6) → L3 policy pack, L4 launchers/allowlist, L8 packs, L9 budgets.
8. Quick PIN (root-owned, hashed) for in-session approvals; recovery = parent password.
9. `omarchy-kids-check`; print the residual-risk card and the L2 tier reached.

`disable` reverses in order and keeps the child's files.

## Multiple kids (OQ-11)

One `kid-<name>` user per child, each with a preset; shared policy daemon with per-uid rules; per-uid DNS/egress
(L3). Profiles inside one user are weaker — avoid. Works today via the greeter; 4.1 may add a nicer switcher.

## Interfaces

Produces uid/group + preset for L3/L4/L5/L9; depends on L2 for boot/TTY trust; packaged by L11.

## Residual risks

A child who boots the machine alone knows the LUKS passphrase → live-USB root unless L2's firmware password is set
(the single biggest caveat to print on the parent card); parent leaves privilege lying around (keepalive,
passwordless window, FIDO2 key in the port); parent password reuse.

## Workstreams & backlog seeds

ACC-01 RFC account model · ACC-02 polkit deny pack + `pkcheck` tests · ACC-03 `omarchy-kids-user` script
(useradd, skel, bind-remount, group, optional kid autologin, uninstall) · ACC-04 quick-PIN design ·
ACC-05 parent hygiene guide · ACC-06 gift-a-kid-computer guide · ACC-07 track upstream 4.1 multi-user.

## Open questions

OQ-2, OQ-11, OQ-15, **OQ-19** (kid autologin vs parent autologin as the default family model), plus report 03's:
how should Kids Mode treat Omarchy's AI-agent tooling in the kid session (hard-disable vs age-gated)?
