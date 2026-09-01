# Threat Model (v0)

_status: draft · updated 2026-09-01 · boot/sandbox specifics verified in research report 03. Every layer doc
lists its own residual risks; this page is the cross-cutting view. Public docs describe classes of attack, never
step-by-step bypasses (see `SECURITY.md`)._

## Framing

> "It's not real security: a determined user will always be able to find a way around it… It should prevent the
> average child from doing things they're not supposed to do, though." — Philip Withnall, author of GNOME's
> parental controls [R02-S8]

Kids Mode is a **deterrent and a scaffold for a curious child, not a security boundary against a determined
teenager with physical access**. We say so in every parent-facing screen. What raises the bar, in order: no
`sudo`/`wheel` for the kid; root-owned policy; full-disk encryption (Omarchy default); a firmware password and
locked boot order; a locked boot menu; no recovery entry without a password.

## Assets

1. The child's wellbeing (exposure to harmful content or contact).
2. The integrity of the parent's rules (filters, limits, allowlists).
3. The parent's account, data and the machine itself.
4. The child's privacy and dignity (no surveillance creep).
5. The child's own work (never lost by a reset).

## Adversary tiers (used in the safety issue form)

| Tier | Who | Typical moves |
| --- | --- | --- |
| **T1** | Any kid who can click | Opens the wrong site, drags a window off-screen, closes the launcher, mashes keys |
| **T2** | A curious 10-year-old with YouTube | Incognito, another browser, DoH in settings, an extension "VPN", a portable AppImage, edits their own config files, the user switcher |
| **T3** | A Linux-savvy teen | TTY switch, `sudo`, editing the shell/plugin files, killing daemons, snapshot rollback from the boot menu, kernel cmdline edits, live USB |
| **T4** | Physical access + tools | Removes the drive, resets firmware, boots from USB |

Out of scope: adults attacking the machine; malware; nation-states. Those are upstream Omarchy's threat model.

## Trust boundaries (Omarchy 4.x — verified in report 01)

- **LUKS passphrase** gates the disk; on a single-user install it is effectively the login. A kid who knows it can
  boot the machine — that is the intended situation for "the kid's own machine".
- **Root-owned** (`/etc`, `/usr`, system services, polkit rules, browser managed policies, NM/resolved config,
  sudoers, Snapper): the kid cannot change these without privilege. **All enforcement must live here.**
- **Kid-owned** (`~/.config/omarchy/**`, `~/.config/hypr/*.lua`, plugins, `shell.json`): editable and therefore
  **experience only** — never a control (OQ-16).
- **Boot chain** (UEFI → Limine (editor on, no password) → UKI on an unencrypted ESP → LUKS → SDDM permanent
  autologin → Hyprland → omarchy-shell): every step before LUKS is reachable with a keyboard unless firmware is
  locked; **Omarchy sets root's password = the owner's and enables `getty@tty1`**, so a VT is a real door until
  L2's TTY kit is applied.

## Threats × mitigations (condensed)

| # | Threat | Tier | Layer | Mitigation | Residual risk |
| --- | --- | --- | --- | --- | --- |
| 1 | Explicit content via the browser | T1–2 | L3 | Family DNS (strict DoT) + managed policy (SafeSearch, YouTube restricted, DoH off, no incognito/extensions) + allowlist-only for Guided | Explicit images on allowed domains; provider category gaps; Tor-over-443 |
| 2 | Switch to another network's DNS | T2 | L3 | Local pinning travels with the laptop (NM global-dns + resolved; v2 local resolver) | — |
| 3 | Run a downloaded binary/AppImage/script | T2 | L4 | `noexec,nosuid,nodev` bind-remount of the kid home + tmp dirs; launcher allowlist; sandboxed apps with curated `PATH` | Interpreters and `ld.so ./bin`; fapolicyd does not exist on Arch |
| 4 | Edit own Hyprland/shell config to escape Level or hide widgets | T2–3 | L5 | Accept — cosmetic only; enforcement elsewhere | None if L3/L4/L9 hold |
| 5 | Disable/kill the screen-time daemon | T3 | L9/L1 | Root-owned system service; logind-based enforcement; no `wheel` | — |
| 6 | Use `sudo` / passwordless-sudo window / polkit prompts / guess the parent's password until faillock locks them out | T2–3 | L1 | Kid not in `wheel`; polkit **deny** rules (no prompt shown → no guessing, no lockout DoS); `passwd -l root`; parent avoids keepalive/passwordless sudo and unplugs FIDO2 keys while a child is present | Parent leaves a root shell open; `NOPASSWD` file outliving its timer after a reboot |
| 7 | Ctrl+Alt+Fn → TTY login as parent or root | T3 | L2 | Hyprland hardcodes VT switching → XKB `srvrkeys:none` in the kid session; `NAutoVTs=0`, `ReserveVT=0`, mask `getty@tty1`; `passwd -l root`; persistent faillock | Parent needs a documented recovery path (SSH / live USB) |
| 8 | Boot-menu tricks: Limine editor (`init=/bin/bash`?), boot a pre-Kids-Mode Snapper snapshot (autologs into the parent's session) | T3 | L2 | `editor_enabled: no` re-applied by a post-update hook (`omarchy-refresh-limine` overwrites the file); prune pre-hardening snapshots; Direct Boot + firmware password; Kids Mode re-locks on first boot after a rollback; (Fortress) config-hash enrollment | Limine has **no password**; whether the editor can inject `init=` into a UKI entry is untested (OQ-20) |
| 9 | Live USB / firmware reset | T3–4 | L2 | UEFI admin password; boot order locked; LUKS makes the disk unreadable — **but a child who boots the machine alone knows the passphrase**, so this is the single most important parent action | ESP is unencrypted regardless; CMOS reset; Secure Boot must be off for Omarchy |
| 10 | Undo everything via `Setup > Reset Computer` or `limine-snapper-restore` | T3 | L2/L11 | Both run through sudo → the parent's password; Kids Mode re-applies on first boot via hook | — |
| 11 | Sign out / other browser profile to dodge account-bound controls | T2 | L3 | Policy is machine-wide, not account-bound; `BrowserSignin`, no other browsers installed | Parent installs a second browser family without policies |
| 12 | Voice tool used as a "friend"; transcripts leak | T1 | L10 | Off by default; no persona; offline; network denied; mutual-visibility transcripts; retention | — |
| 13 | Monitoring creep harms trust | (us) | L9 | No keystrokes/screenshots; summary-only; child sees what parent sees | — |
| 14 | Kid loses work on a reset/session kill | T1 | L9/L11 | Warnings before termination; resets restore layout not files; Snapper before enabling | — |
| 15 | Plugin from the marketplace runs arbitrary code in the kid's shell | T2 | L4/L11 | `omarchy plugin add` is an unprivileged user action → the kid session runs a **fixed** shell/plugin set from root-owned config, and the kid has no terminal/`omarchy` CLI to add more | Plugins are unsandboxed by design; UX-only surface |
| 16 | Upstream update breaks or removes a control silently | (time) | L11 | `post-update.d` re-assertion + daemon self-check + `omarchy-kids-check` green/red | 17-day release cadence |

## What we will not do

MITM HTTPS inspection, keyloggers, screenshots, covert monitoring, cloud dashboards by default, "unbypassable"
claims. See `docs/vision.md` → Non-goals and `PRIVACY.md`.

## Process

Each row above should become a test (`omarchy-kids-check` and the satellite repos' acceptance tests). New threats:
open a **🛡️ Safety concern** issue (non-sensitive) or report privately (`SECURITY.md`).
