# The sandbox path

Kids Mode as an **app on a normal Omarchy install**. The parent keeps their own account and full
desktop; each kid gets a profile that is a real account underneath; a Super triple-tap and the
parent password get the parent back out. Core is untouched. Spoke:
[`omarchy-kids-sandbox`](https://github.com/markcuda/omarchy-kids-sandbox). Updated 2026-09-02.

The other path is the [installer path](PATH-INSTALLER.md): the machine is the kid's, one account,
two passwords, chosen at install. The two are complements, not rivals; they share the parent
command and its feature commands, and each carries pieces the other can use.

## Status

Design settled in a sixteen-question session on 2026-09-02 (below). Next: a spec in the spoke,
then one issue per buildable element, then code. The spoke's current scripts predate these
decisions and will be reshaped, not extended.

## Decisions

| # | Area | Decision |
| --- | --- | --- |
| 1 | Foundation | Kids Mode is an app on a Me install, no installer change. A kid profile is a real Unix account with the installer path's privilege posture (out of `wheel`, explicit grant that asks for the parent password, polkit admin rule naming root, masked consoles) plus our locks (noexec home, polkit denies, zero sudo credential cache). The parent's account is **never** restricted, not by policy, not by DNS, not while a kid is paused |
| 2 | Secrets | The household parent password is the owner's password (already root's on a Me install). One password per kid. No PIN. The parent password also opens any kid's tile and lock screen |
| 3 | Disk | Each kid's password gets its own LUKS key slot, so "your password opens your computer" holds at boot. Slot removed with the kid. "No password" profiles for 3-5 get no slot; a parent unlocks for them |
| 4 | Exit gesture | Super ×3 opens a modal: parent password, then **Pause Ada** (her apps stay open, you switch to your desktop) or **Finish for Ada** (closes her apps). Both ship in v1, so two live sessions under SDDM is a Phase 1 check |
| 5 | Login portal | Face tiles, then password, as an SDDM theme. Parent tile last and smaller. Per-profile "no password" for 3-5. Session picker hidden on kid tiles |
| 6 | Kid desktop | Levels 1, 2 and 3 all ship, parent-set, band defaults, plain-words descriptions. Run from a root-owned Hyprland config selected per account through a dedicated `omarchy-kids` session entry. Refuses to start if any lock is missing |
| 7 | Wizard shape | Easy path (chunked A-or-B choices, preselected by band) or Advanced (a table of toggles), chosen up front. Add-a-kid runs only the per-kid screens. The app's home screen has a settings gear into the management panel |
| 8 | Bands | 3-5, 6-8, 9-12, 13+. Band only, no second temperament knob. Every cell overridable. 13+ is outside upstream's "under 13 first" and ships with the loosest defaults and no special work |
| 9 | Web | Per band: walled garden, filtered open web, or no browser. **Chromium stays everyone's browser.** Kids policy files are root-owned, mode 0640, group `omarchy-kids`; Chromium skips files it cannot read (verified in `config_dir_policy_loader.cc`), so the parent's browser loads no policy. Family DNS lives inside the kids policy as a locked DoH template; machine DNS untouched. DNS provider never asked in Easy. Policy also blocks clearing or disabling history |
| 10 | Screen time | Our own engine as `omarchy-parent time`: accounts active logind sessions, counts nothing while paused or locked, shell-native warnings, ends the session at budget or bedtime, "ask for more time" is the parent password. Draws on Apple Screen Time, Family Link, Family Safety (report 02 matrix) |
| 11 | Apps | Native only (repos + AUR via the yay Omarchy ships). Starter packs by band from report 05. Installs run as a root unit the moment the screen is confirmed; the wizard never waits. A "hide kids' apps from my launcher" switch for the parent. A "parents only" fence (binary unexecutable for the kids group, re-asserted after updates) in Advanced. The marketplace already has a **Kids** category and Kids / Education / Games tags; a kids-plugins shelf reads it, verified listings only, parent-gated, and nothing that enforces Kids Mode ever lives in a plugin |
| 12 | Asking | One "ask a parent" modal for time, apps, plugins and sites. Answered at the keyboard with the parent password, or later in the panel. Root-owned local queue, built so a home-network approver can attach later. No cloud, ever |
| 13 | Wi-Fi | Parent-only for 3-5 and 6-8. Safe helper for 9-12 and 13+: joins with the network password only and forces the connection to ignore the network's DNS. Captive portals: the helper opens exactly the portal page with strict DNS briefly relaxed, then restores it |
| 14 | Recorded | Locally only: active time, app launches, requests, and browsing history. Shown identically to the parent and to the kid ("What my grown-ups can see"). Per-kid overridable. Report 07 argued against site history for pre-teens; we chose otherwise, on the record |
| 15 | Trust | Snapper snapshot before apply. Safety check at every kid login, failing closed. Firmware-password step required, red until marked done. Remove Kids Mode keeps every kid's files. Every lock is re-asserted by a pacman hook (both reviewed PRs fail open on update) |
| 16 | Build | Bash + gum for wizard and panel in Omarchy's floating terminal; QML only for the modal and the SDDM theme; everything keyboard-complete. Looks like the installer (Omy where the logo sits, colors from the parent's theme), with flow and presentation in separate files so the look can change later. Arch package from the spoke, AUR when stable, tested on the stock ISO in a VM. Commands in `omarchy-kids-*`; `time`, `dns`, `apps` exposed as `omarchy-parent-<feature>` so the installer path's dispatcher discovers them |

**Assumptions not asked:** the app is called Kids Mode; a second adult uses the same household
parent password; the app never creates anything the parent has to log into.

## Borrowed, with credit

| From | What | Why |
| --- | --- | --- |
| [omacom/omarchy#9750](https://github.com/omacom/omarchy/pull/9750) (Pete) | `omarchy-parent` dispatcher and naming, the visudo-checked sudoers writer and settings-file helpers, the per-account posture, the lock-screen parent unlock (needs `seteuid` before it touches SDDM), the child package list hook | Solved problems; convergence for free |
| [markcuda/omarchy-kids-sandbox#1](https://github.com/markcuda/omarchy-kids-sandbox/pull/1) (HxHippy) | The Wi-Fi helper that forces a joined network to ignore its DNS; the filtered system bus | Both stricter than what either path had. The PR itself belongs to the installer path (one uid) and is not merged here |
| [escherize gist](https://gist.github.com/escherize/c7e3afb637334a233fd5e5895cb984be) | The timekpr-next pointer and the honest-disclaimer tone | Its DNS and malcontent layers were not adopted (per-connection DNS vanishes on a new network; malcontent enforces nothing on Hyprland) |

Sent the other way: the ignore-DNS Wi-Fi fix (the installer path's kid grant lets a kid set
per-connection DNS); the finding that `pam_exec` without `seteuid` accepts any password once the
stack runs as root; the finding that kid faillock ahead of parent unlock locks the parent out.

## Phase 1 checks (verify on a real 4.0.2 install before the spec is final)

1. Two live Hyprland sessions under SDDM on one machine (Pause), and that logout/login switching survives `omarchy update`.
2. A 0640 root:`omarchy-kids` policy file: `chrome://policy` empty as the parent, full as a kid.
3. Chromium strict DoH behind a captive portal, and the helper's relax-then-restore.
4. Per-kid LUKS slots added and removed with `cryptsetup luksAddKey`/`luksRemoveKey`.
5. The PAM parent-unlock helper with `seteuid` on both the lock stack and SDDM.
6. The five checks already in [CORE.md](CORE.md): SDDM second user across updates, Limine editor injection, tmpfs exec, Flatpak override precedence, snapshot rollback.

## How to help

Argue with a row above in an issue on the spoke. Run a Phase 1 check and post the result.
Everything else waits for the spec.
