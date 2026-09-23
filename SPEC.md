# Omarchy Kids Mode: specification v1.1

Status: **draft for review**, 2026-09-02. Desktop defaults updated by Mark on 2026-09-07 (#200). Decisions come from the design record on the `two-paths` branch
([PATH-SANDBOX.md](https://github.com/markcuda/omarchy-kids-mode/blob/two-paths/PATH-SANDBOX.md)) plus
the thirty-question design session that followed. Requirement ids (`R-WEB-3`) are referenced by
the issues. Appendices A–G are the build-ready detail v1 lacked.

Changes from v1: one parent password verified against the parent's own account (no `rootpw`, no
kid sudo grant); startup lands on the desktop of whoever unlocked the disk (§R-BOOT); Super+Shift+K
as the gesture; welcome screen, name-first flow, Simple/Advanced after age; package prefetch during
the wizard; a parent bar widget; nine defaults from Q17–Q25; appendices.

## 1. Scope

**v1 (this spec):** the Kids Mode app on a normal Omarchy 4.0.x install: the parent wizard and
panel, per-kid provisioning, boot and login, the exit modal, the kid desktop at three levels, web
policy, screen time, apps, ask-a-parent, Wi-Fi, recorded data, trust and undo, packaging.

**Phase 2 (not this spec):** the kid onboarding wizard with Omy, earned level progression, Learn
with Omy. v1 leaves a hand-off contract (§6.1).

**Out, deliberately:** installer changes; any new parent login; cloud or remote anything; Flatpak;
malcontent; timekpr; machine-wide DNS or browser policy; localization (English first).

## 2. Definitions

- **Parent**: the owner account of the install, in `wheel`. Any adult in the house uses it.
- **Parent password**: the parent's login password. The only password a parent has. Every Kids Mode prompt checks it against the parent's own account, never root's.
- **Kid profile**: a real Unix account created by the app, member of `omarchy-kids` and one `omarchy-kids-<band>` group, never in `wheel`, no sudo grant of any kind.
- **Band**: 3-5, 6-8, 9-12, 13+. Picks defaults. Every default is overridable per kid.
- **Level**: 1 (one app, fullscreen), 2 (split), 3 (tiling). Parent-set in v1.
- **Lock**: a root-owned artifact that constrains a kid session. **Fence**: a lock that is a deterrent, not a wall; labeled as such in the UI.
- **Portal**: the login screen with face tiles.
- **Path**: this repository is the complete app; the installer-path record is on the `two-paths` branch (`PATH-INSTALLER.md`).

## 3. Invariants

- **I-1 The parent's account is never restricted.** No policy, resolver, firewall, launcher, or hook touches the parent's session, home, browser, or DNS, including while a kid is paused. Writes into the parent's own files happen only when the parent asks (bar widget, Super+Shift+K binding, hide kids' apps, parents-only fence).
- **I-2 Nothing about a child leaves the machine, except to a device the parent paired or a server the parent named, and only after the parent turned notifications on.** No telemetry, accounts, or cloud that is not the parent's own. The only network listener is `omarchy-kids-relayd`, fenced to the home network by its root-owned unit and running only while Kids Mode is in use and notifications are on; the parent may extend that fence, off by default, to the CGNAT range their own VPN uses (N-10), where the relay's authentication remains the lock. The only outbound connections are to the one address the parent typed, end-to-end encrypted for one paired device; nothing about a child reaches this project, its authors, or any push vendor, and a platform push service may carry at most an opaque, contentless wake after the parent enables it. (Amended 2026-09-22; `docs/phase1/SPEC-AMENDMENT-notifications.md`, R-NOTIFY.)
- **I-3 Every lock is root-owned and lives outside every home.** Nothing in `~` enforces anything.
- **I-4 Every lock is re-asserted after updates** by a pacman hook and verified at every kid login. A missing lock fails closed: the kid session does not start.
- **I-5 Keyboard-complete.** Every screen works with no pointer.
- **I-6 Honest UI.** No control is shown that is not enforced. Fences are labeled fences. The summary screen explains startup, in plain words.
- **I-7 Core untouched.** No file owned by `omarchy` or `omarchy-settings` is edited. Extension points only: drop-ins, hooks, session entries, themes, policy folders, our own package.
- **I-8 One parent password.** Kids Mode never asks a parent for anything but their login password, and never stores it.
- **I-9 Never a machine that will not boot.** Anything in early boot fails safe to the stock path.

## 4. Requirements

### R-FND Foundation

- R-FND-1 Kids Mode installs as one Arch package on a stock Omarchy 4.0.x Me install and appears as "Kids Mode" in the app drawer.
- R-FND-2 Adding a kid creates a Unix account `kid-<slug>` (Appendix B.1): `useradd -m`, shell `/bin/bash`, groups `omarchy-kids` and `omarchy-kids-<band>` only; home bind-mounted `nosuid,nodev,noexec`.
- R-FND-2a Kid sessions get a private `noexec` tmpfs for `/tmp` and `/dev/shm` through `pam_namespace` on both the SDDM and `systemd-user` PAM stacks (V6 found every shared tmpfs on 4.0.2 allows exec, so a noexec home alone is not a fence). `/run/user/<uid>` is a stated fence until the same treatment is verified.
- R-FND-3 Kid accounts have **no sudoers entry**. Privileged actions in a kid session go through polkit, and `/etc/polkit-1/rules.d/40-omarchy-kids.rules` returns `["unix-user:<parent>"]` as the admin identity for members of `omarchy-kids`, so the native dialog asks for the parent password and checks it against the parent's account.
- R-FND-4 Polkit denies for kid accounts, no prompt: NetworkManager settings modify (unless R-WIFI-2), udisks mount/unlock, systemd manage-units, package management, `omarchy-sudo-passwordless`.
- R-FND-5 Text consoles tty2..6 are masked while any kid profile exists; unmasked by Remove Kids Mode.
- R-FND-6 Removing a kid removes the account, its LUKS slot, its group memberships, and moves its home to `~parent/Kids Mode/<name>/`. Machine-level pieces stay until Remove Kids Mode (Q20).

### R-SEC Secrets and the verifier

- R-SEC-1 `omarchy-kids-authd` is a root, socket-activated verifier. It accepts a candidate on a local socket and answers yes only if it matches the parent's shadow hash (libxcrypt via `crypt(3)`, yescrypt-safe). It rate-limits itself: three misses → 30 s, ten → 5 min. It never touches the system's faillock for the parent's login.
- R-SEC-2 Every parent prompt in Kids Mode uses the verifier: the exit modal, the ask modal, the lock-screen line, the portal line, panel confirmations, the bar-widget actions. `pam_exec` lines call `omarchy-kids-parent-auth`, a thin client, with `expose_authtok`; they work identically whether the stack runs as root or as the kid, because verification happens in the daemon.
- R-SEC-3 One password per kid, stored in shadow. Minimum length 4 for 3-5 and 6-8, 6 for 9-12 and 13+. "No password" allowed only in 3-5.
- R-SEC-4 Each kid's password is a LUKS2 key slot on the root device: added at creation, changed with the password, removed with the kid. "No password" profiles get no slot. `/etc/omarchy-kids/luks-slots` (root 0600) maps slot → account.
- R-SEC-5 A kid changes their own password with the old one; a parent resets any kid's password from the panel. Both update the slot.
- R-SEC-6 Root's password is never read, set, or relied on.

### R-BOOT Startup

- R-BOOT-1 A mkinitcpio runtime hook, `omarchy-kids-unlock`, runs **before** `encrypt`. It prompts exactly as the stock hook does, opens the root device with `cryptsetup open --verbose`, records the unlocking slot to `/run/omarchy-kids/boot-slot`, and leaves the mapping under the name the stock hook expects. If anything is unexpected (no LUKS, unknown hook set, cryptsetup output not parsed, more than three misses) it exits without side effects and the stock hook prompts as today.
- R-BOOT-2 The hook is added by `/etc/mkinitcpio.conf.d/omarchy_kids.conf` (underscore on purpose: `conf.d` files are sourced in byte order and Omarchy's `omarchy_hooks.conf` *assigns* `HOOKS`, so ours must sort after it), which rebuilds `HOOKS` with ours inserted before `encrypt` and does nothing if `encrypt` is absent (e.g. a future `sd-encrypt` move).
- R-BOOT-3 `omarchy-kids-boot-login.service` (Before `display-manager.service`, runs on every boot, no condition) reads the slot, maps it through `luks-slots`, and writes `/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf` with that account and its session for this boot; the parent's slot maps to the parent and the stock session, preserving today's behavior. No slot file or no mapping → an empty `User=` → the portal, which is also what protects a kid whose password unlocked the disk while the hook had stepped aside. A cleanup unit removes the drop-in shortly after the display manager starts, so logout never re-autologs.
- R-BOOT-4 Omarchy's own autologin drop-in is superseded, not edited: ours sorts later.
- R-BOOT-5 The safety check verifies after every kernel or mkinitcpio update that the current initramfs contains the hook, and the pacman hook rebuilds it if not.

### R-LOGIN Portal

- R-LOGIN-1 An SDDM theme shows one tile per kid (avatar, name), then a password field; the parent tile last and smaller; the last-used tile preselected.
- R-LOGIN-2 "No password" profiles log in on Enter.
- R-LOGIN-3 Kid tiles show no session picker; kid accounts are pinned to the `omarchy-kids` session through AccountsService.
- R-LOGIN-4 Arrows between tiles, Enter selects, Esc back.
- R-LOGIN-5 The parent password opens any kid's tile (R-SEC-2). No option to hide the parent tile in v1 (Q25).

### R-EXIT Exit modal

- R-EXIT-1 In any kid session, **Super+Shift+K** or Super pressed three times within 1.5 s opens a root-owned overlay: the kid's avatar and name, a password field, and two actions: **Pause <name>** ("<possessive> apps stay open. You switch to your desktop.") and **Finish for <name>** ("Closes <possessive> apps. You return to the login screen."). Pause is preselected.
- R-EXIT-2 Verified through R-SEC-2.
- R-EXIT-3 Pause locks the kid session (hyprlock) and switches to the greeter. Finish sends SIGTERM to the session scope, then `loginctl terminate-session`, then the greeter.
- R-EXIT-4 A paused kid resumes at their own lock screen with their own password or the parent's.
- R-EXIT-5 The parent session locks itself when the parent switches away.
- R-EXIT-6 On the parent's desktop, Super+Shift+K opens the Kids Mode app. The binding is one line appended to the parent's `~/.config/hypr/bindings.lua`, shown verbatim, only if the parent says yes in the wizard.

### R-DESK Kid desktop

- R-DESK-1 `omarchy-kids.desktop` (Wayland session, root-owned) runs `omarchy-kids-session`, which reads the profile and execs `Hyprland --config /etc/omarchy-kids/hyprland/L<level>.lua` with the band overlay.
- R-DESK-2 Before the compositor starts, the launcher checks: profile present, policy file readable by this account, polkit drop-ins present, home noexec, private `/tmp` mounted noexec (R-FND-2a), consoles masked, initramfs hook present. Any miss → a full-screen "Ask a grown-up" naming the check, then exit.
- R-DESK-3 Levels per Appendix E. Level 1 (App grid): fullscreen-only, big-tile launcher, `Super+Home`, no terminal or file manager. Level 2 (Simplified desktop): a themed background teaching `Super+Space`, a searchable allowed-app picker, normal tiling and `Super+arrows` focus. Escape or opening an installed app hides the picker; it can be reopened repeatedly. Level 3 (Full desktop): an explicit advanced/manual choice with the existing Omarchy bindings and theme. Ages 3-5 default to Level 1; every older band defaults to Level 2. The parent can override this in the permissions/settings Desktop row; changes apply at next login and preserve the other age policies.
- R-DESK-4 Omarchy's menu is trimmed of Install/Update/Setup entries under Levels 1 and 2 through a root-owned menu extension; untouched under Level 3 (Q23).
- R-DESK-5 The Level 1 launcher is a standalone root-installed QML program started by the root-owned config, not a shell plugin (I-3).
- R-DESK-6 The kid's `~/.config/hypr` is never read.

### R-WIZ Wizard and panel

- R-WIZ-1 Flow (Appendix A): Welcome → Begin → parent password → kid's name → face → age → Simple or Advanced → per-choice screens (Simple) or the table (Advanced) → kid password → summary → Apply → Done with one action (R-WIZ-6's preview is not shipped).
- R-WIZ-2 Omy speaks on Welcome and Done; every other screen speaks plainly and uses the kid's name.
- R-WIZ-3 Simple shows one choice per screen: two options, one reason line each, the band default preselected. Advanced shows every cell as a grouped checklist with pickers.
- R-WIZ-4 Prefetch: from the age screen on, the band's starter pack downloads into the pacman cache (`pacman -Sw`) in the background through a root helper; changed selections need no undo. Apply installs from cache; AUR builds continue after Apply.
- R-WIZ-5 Apply renders like the installer's dashboard: header, one line per step with done marks, one bar, a tip; the technical log goes to a support file.
- R-WIZ-6 Done offers **Return to my desktop**. **Not shipped as of 2026-09-18:** Omarchy 4.0.2 has no way to start a live preview of the kid's session from the parent's session, so A14 offers no preview button; see `docs/wizard.md` "Why Done has no Open desktop button".
- R-WIZ-7 The app's home screen lists kids with a settings gear; add-a-kid runs the per-kid screens only (parent password, name, face, age, Simple/Advanced, choices, kid password, summary, apply).
- R-WIZ-8 Panel per kid: time today and this week, top apps, browsing history (if enabled), open requests, every setting, reset password, pause/finish if live, remove. Machine: safety status, firmware step, Remove Kids Mode.
- R-WIZ-9 Bash + gum in Omarchy's floating terminal. Screens are data (`tui/screens/*.toml`), the renderer is one library. Header where the logo sits (Omy placeholder), step counter, Esc back, Ctrl+C leaves with nothing changed, colors from the parent's theme.

### R-BAR Parent bar widget

- R-BAR-1 An optional Quickshell bar widget in the parent's session (installed only on consent) shows live or paused kids and minutes left ("Ada · paused · 32 min").
- R-BAR-2 Actions: give more time, end session, open Kids Mode. Each goes through a polkit-gated helper (parent password).
- R-BAR-3 Reads `/run/omarchy-kids/status.json`, root-written, group `omarchy-parents` readable. It carries each live kid's minutes-left and paused state and the open-request count and list (R-NOTIFY-7); the widget's badge reads the count from it rather than running any command. It also carries the pairing window's expiry (`pairing_open_until`), never the token, so the relay can keep itself up while a phone pairs (R-NOTIFY-2/5), and the open add-on review count (`reviews`, R-NOTIFY-12).

### R-BAND Bands and defaults

| Band | Level | Web | Budget / lights-out | Starter pack | Wi-Fi | Terminal |
| --- | --- | --- | --- | --- | --- | --- |
| 3-5 | 1 | No browser | 45 min / 19:00 | GCompris, Tux Paint, KTuberling, Blinken | Parent only | No |
| 6-8 | 2 | Walled garden | 60 min / 19:30 | plus SuperTux, SuperTuxKart, KLettres, Kanagram | Parent only | No |
| 9-12 | 2 | Walled garden | 90 min / 20:30 | plus TurboWarp, Luanti, KTouch, Pixelorama, Kiwix | Safe helper | Playground shell |
| 13+ | 2 | Filtered open web | 120 min / 21:30 | plus Sonic Pi, Thonny, KStars | Safe helper | Sandboxed shell |

- R-BAND-1 The table is data (Appendix C).
- R-BAND-2 The profile stores only overrides. Changing a band keeps overrides; "Reset to band defaults" clears them (Q19).

### R-WEB Web

- R-WEB-1 Chromium remains the browser for everyone. Kids policy lives in `/etc/chromium/policies/managed/omarchy-kids-<band>.json`, mode 0640, root:`omarchy-kids-<band>`. The parent is in no kids group.
- R-WEB-2 Every kids policy sets: `DnsOverHttpsMode: secure` with a family template (Cloudflare Family default; CleanBrowsing Family or custom in Advanced), `ForceGoogleSafeSearch`, `ForceYouTubeRestrict: 2`, `IncognitoModeAvailability: 1`, `DeveloperToolsAvailability: 2`, `ExtensionInstallBlocklist: ["*"]`, `BrowserSignin: 0`, `DownloadRestrictions: 1`, `SavingBrowserHistoryDisabled: false`, `AllowDeletingBrowserHistory: false`.
- R-WEB-3 Walled garden adds `URLBlocklist: ["*"]` plus a `URLAllowlist` from the band's starter list and the kid's approved sites. Filtered open web adds neither. No browser hides Chromium from the launcher and sets `URLBlocklist: ["*"]`.
- R-WEB-4 The kid launcher refuses to start Chromium if the kid's policy file is not readable.
- R-WEB-5 Kid web apps use `omarchy-webapp-install` in the kid's account.
- R-WEB-6 Machine DNS is never changed. Advanced may offer machine-wide family DNS as an opt-in belt with the I-1 warning.

### R-TIME Screen time

- R-TIME-1 `omarchy-kids-time` (also `omarchy-parent-time`) is a root service accounting active, unlocked kid sessions at 30 s resolution; per-day totals under `/var/lib/omarchy-kids/<name>/usage/`.
- R-TIME-2 Per kid: budget (minutes), lights-out (HH:MM), weekend variants. Day boundary 04:00; weekend is Saturday and Sunday (Q22). Paused or locked time does not count.
- R-TIME-3 Warnings at 10, 5, 1 minute via the kid session's notifications, plus a full-screen countdown for pre-readers with icon and sound.
- R-TIME-4 At budget or lights-out: lock, then terminate after 60 s unless a parent grants more. "More time" extends today's budget only; lights-out can be pushed by a parent for tonight only. State machine in Appendix F.
- R-TIME-5 A local weekly summary in the panel.

### R-APPS Apps

- R-APPS-1 Official repos and AUR via `omarchy-pkg-*`. No Flatpak.
- R-APPS-2 Starter packs per band as data (Appendix C).
- R-APPS-3 Prefetch per R-WIZ-4; at Apply, `omarchy-kids-install@<name>.service` installs from cache and builds AUR packages; journal, retry from the panel.
- R-APPS-4 Per-kid allowlist; launcher entries appear as installs land.
- R-APPS-5 "Hide kids' apps from my launcher" writes `Hidden=true` overrides into the parent's own launcher entries, only on request.
- R-APPS-6 "Parents only" marks a binary `0750 root:omarchy-parents`, re-asserted by the hook, labeled a fence.
- R-APPS-7 A kids-plugins shelf reads the marketplace catalog filtered to category Kids, verified listings only; install goes through R-ASK; no plugin may enforce anything.
- R-APPS-8 Offline: the wizard completes; installs are deferred and retried by a timer when online; the panel shows pending (Q21).

### R-ASK Ask a parent

- R-ASK-1 One modal, "Ask a parent", for more time, an app, a plugin, a site. Parent password there → granted on the spot. Otherwise a record in `/var/lib/omarchy-kids/queue/` (Appendix D) and "Asked. Your grown-up will see it."
- R-ASK-2 The panel lists requests; Enter opens the request's card with **Approve** preselected, and one more Enter approves and performs the action. (Decided 2026-09-19: a true one-keystroke approve from the list was rejected — approval performs a real action that cannot be undone from the panel; see `docs/phase1/DECISIONS-NEEDED.md` §6.)
- R-ASK-3 The queue format is stable and documented for a future home-network approver.

### R-NOTIFY Parental notifications

- R-NOTIFY-1 The only network listener is `omarchy-kids-relayd`, a root-owned system unit whose configuration fences it to loopback and the private LAN ranges. It runs only while Kids Mode is in use and notifications are enabled, and exits on its own when idle. No listener exists while notifications are off. The parent may opt in (N-10) to extend the fence to the CGNAT range their own VPN uses; off by default, one range only, and the relay's authentication remains the lock.
- R-NOTIFY-2 The relay never decides. Every decision is authenticated and applied by root (`omarchy-kids-authd` / `omarchy-kids-ask`), through the same `apply_record` path the panel uses. A compromised relay can, at worst, stop delivering notifications.
- R-NOTIFY-3 The device registry is root-owned under `/etc/omarchy-kids/devices/`. Each record holds a device's public keys, its scopes and its pairing provenance. Revocation is a root write and takes effect immediately.
- R-NOTIFY-4 A decision is accepted only after root verifies a signature from a paired, unrevoked device over the exact decision, within a bounded clock skew and with a single-use nonce, against the write-once queue record. A seen nonce, a stale timestamp, an unknown device, or an already-decided record is refused.
- R-NOTIFY-5 Pairing is gated by the parent password through the existing verifier. The pairing code is single-use and expires; no device key is established without it.
- R-NOTIFY-6 A kid learns the outcome through a root-written file under their own directory. The kid session holds no credential to the relay and gains no new way to act.
- R-NOTIFY-7 The queue is not world-readable: `/var/lib/omarchy-kids/queue/` is `0750 root:omarchy-parents` and each record is `0640`. `omarchy-kids-ask list` reads for root or a member of `omarchy-parents`; `omarchy-kids --requests` works for the parent.
- R-NOTIFY-8 `omarchy-kids-relay-courier` is the only process that may reach beyond the LAN, and only to the one server the parent named. Everything it sends is end-to-end encrypted for one paired device; no content reaches this project, its authors, or a push vendor.
- R-NOTIFY-9 Each device carries per-device scopes (`decide`, `act`). A decision or action without its scope is refused.
- R-NOTIFY-10 Every parent-facing label states what is enforced and what is not: the fence ("home network only", or the CGNAT range when away-from-home is on), the relay's inability to decide, and the platform limit on background delivery.
- R-NOTIFY-11 `omarchy-kids-assert` re-asserts the relay unit, its fence and the devices directory ownership on every update; `omarchy-kids-check` reports them.
- R-NOTIFY-12 Update re-approval rides the same system: when an approved add-on's surface set or exec changes, the parent is notified and may approve, deny, or ask their onboard agent to check it.

### R-WIFI Wi-Fi

- R-WIFI-1 Per kid: `parent` (default 3-5, 6-8) or `helper` (default 9-12, 13+).
- R-WIFI-2 `helper`: `omarchy-kids-wifi` → pkexec helper on the host: SSID and password only; joins; forces `ignore-auto-dns` and clears connection DNS. Never NetworkManager settings directly.
- R-WIFI-3 Captive portals: on `connectivity: portal` the helper opens the portal URL in a helper window with DoH relaxed to automatic for that window's profile, then restores strict on `connectivity: full`.
- R-WIFI-4 `parent`: the kid-side join opens the ask modal.

### R-DATA Recorded data and transparency

- R-DATA-1 Recorded, locally: active minutes per day (kept one year), app launches and requests (ninety days), browsing history read from the kid's Chromium profile (the browser's own retention). (Q24)
- R-DATA-2 Never: keystrokes, screenshots, file contents, message contents.
- R-DATA-3 Each kid session has a "What my grown-ups can see" screen showing exactly R-DATA-1 for that kid.
- R-DATA-4 History visibility is a per-kid cell; off means the panel shows none and the kid's screen says so.
- R-DATA-5 `PRIVACY.md` states all of this in plain words.

### R-TRUST Trust and undo

- R-TRUST-1 A Snapper snapshot "before Kids Mode" precedes the first apply.
- R-TRUST-2 `omarchy-kids-check` runs at the end of the wizard, from the panel, and at every kid login. Each check names what it proves and what it cannot.
- R-TRUST-3 Firmware-password step: a printed parent card; red in the check until marked done.
- R-TRUST-4 Remove Kids Mode reverses every lock, removes accounts and slots, keeps every kid's files, offers the snapshot.
- R-TRUST-5 `/etc/pacman.d/hooks/omarchy-kids.hook` and an Omarchy post-update hook run `omarchy-kids-assert`, which restores every lock idempotently and rebuilds the initramfs if the boot hook is missing.

### R-BUILD Build and packaging

- R-BUILD-1 Bash + gum for wizard and panel; QML for the exit overlay, the Level 1 launcher, the SDDM theme, the bar widget; C for the verifier if `crypt(3)` needs it, otherwise a tiny Python or Perl helper calling libxcrypt.
- R-BUILD-2 One Arch package `omarchy-kids`; AUR when stable.
- R-BUILD-3 Shell tests for every command; a VM acceptance run on the stock ISO via `cidata`.
- R-BUILD-4 Commands: `omarchy-kids` (app), `-provision`, `-session`, `-check`, `-assert`, `-conf`, `-authd`, `-parent-auth`, `-boot-login`, `-web`, `-time`, `-apps`, `-ask`, `-wifi`, `-remove`. `time`, `dns` (web), `apps` also as `omarchy-parent-<feature>` unless upstream ships that name.
- R-BUILD-5 Settings use the installer path's key=value format and helpers.

## 5. Architecture

### 5.1 File layout

| Path | Owner | What |
| --- | --- | --- |
| `/usr/bin/omarchy-kids-*` | package | commands |
| `/usr/share/omarchy-kids/{bands.toml,packs/,hyprland/,tui/,sddm-theme/,policy/,avatars/,menu/}` | package | data |
| `/usr/lib/initcpio/{install,hooks}/omarchy-kids-unlock`, `/etc/mkinitcpio.conf.d/omarchy-kids.conf` | package | boot hook (R-BOOT) |
| `/usr/share/wayland-sessions/omarchy-kids.desktop` | package | kid session entry |
| `/usr/share/applications/omarchy-kids.desktop` | package | the app |
| `/etc/omarchy-kids/kids/<account>.conf` | root 0644 | per-kid overrides (Appendix B) |
| `/etc/omarchy-kids/machine.conf` | root 0644 | firmware step, snapshot id, widget/binding consents |
| `/etc/omarchy-kids/luks-slots` | root 0600 | slot → account |
| `/etc/chromium/policies/managed/omarchy-kids-<band>.json` | root:omarchy-kids-<band> 0640 | kids policy |
| `/etc/polkit-1/rules.d/4x-omarchy-kids*.rules` | root | admin identity and denies |
| `/etc/sddm.conf.d/zz-omarchy-kids-*.conf` | root | theme selection; per-boot autologin |
| `/etc/pacman.d/hooks/omarchy-kids.hook` | root | re-assert |
| `/run/omarchy-kids/{boot-slot,status.json}` | root | boot slot; live status (group omarchy-parents readable) |
| `/var/lib/omarchy-kids/<account>/{usage/,launches.log}` | root, group kid 0750 | usage state |
| `/var/lib/omarchy-kids/queue/` | root | requests |

Groups: `omarchy-kids`, `omarchy-kids-<band>` (four), `omarchy-parents` (the owner).

### 5.2 Flows

**First run.** Drawer → floating terminal → Welcome (Omy) → Begin → parent password (verifier) → name → face → age (prefetch starts) → Simple/Advanced → choices → kid password → summary → Apply: snapshot, machine setup, boot hook + initramfs rebuild, provision kid, policy, LUKS slot, install from cache → check → Done (Omy) → Return to my desktop.

**Startup.** Power on → disk prompt → the slot that opened it → autologin that account for this boot → parent lands on their desktop as today; a kid lands on their Level desktop; unknown → portal.

**Kid login (portal).** Tile + password → `omarchy-kids-session` → R-DESK-2 checks → Hyprland `--config` → launcher. Accounting starts on `Active=yes`.

**Pause / Finish.** Super+Shift+K → password (verifier) → Pause: hyprlock, greeter. Finish: SIGTERM scope, terminate, greeter. Parent session locks on switch-away.

**Ask.** Kid action → modal → password on the spot, or queue → panel or bar widget approve → action.

**Update.** pacman transaction → hook → `omarchy-kids-assert` → locks restored, initramfs rebuilt if needed; kid login re-checks.

**Remove.** Panel → parent password → homes moved → accounts, slots, groups, drop-ins, policy, pins, theme, boot hook removed → initramfs rebuilt → consoles unmasked → snapshot offered.

### 5.3 Security model

Deterrent for a curious child; the wall is the parent password plus the firmware password. Kid processes run as their own uid, so the parent's data is kernel-isolated. Stated non-walls: a Level 3 kid with a shell can run installed binaries not fenced by R-APPS-6; a kid who knows any LUKS passphrase and can boot USB owns the disk; non-browser apps use machine DNS. Bypass matrix in Appendix G.

## 6. Contracts

### 6.1 Hand-off to Phase 2

Profile carries `band`, `level`, `avatar`, `name`, `onboarded=false`. Phase 2's kid wizard runs when `onboarded=false` at session start and flips it. Level progression writes `level` through `omarchy-kids-conf` only.

### 6.2 Convergence with the installer path

Feature commands are drop-ins for upstream's `omarchy-parent`. Settings helpers are vendored from upstream's `install/helpers/parent.sh`. The privilege model differs on purpose: upstream needs root's password because its only account is the kid's; ours has a parent account to check against.

## 7. Phase 1 verification (blocking the build order)

| # | Check | Pass |
| --- | --- | --- |
| V1 | Two live Hyprland sessions under SDDM; `SwitchToGreeter` both ways; both survive `omarchy update` | Both resume; no VT lands on an unlocked session |
| V2 | 0640 root:group policy file | `chrome://policy` empty as parent, full as kid; warning in syslog only |
| V3 | Strict DoH behind a captive portal | Portal reachable only via the helper window; strict restored after |
| V4 | LUKS slots | add/change/remove per kid; boot with kid password; three kids |
| V5 | Verifier + PAM lines | kid password → kid; parent password → same account; wrong → denied; on lock and SDDM stacks; rate limit holds |
| V6 | CORE.md's five | recorded either way |
| V7 | Boot slot → autologin | hook records the slot; each account lands on its own desktop; stock hook still works when ours steps aside; a broken hook file never blocks boot |

## 8. Acceptance for v1 done

1. Fresh stock 4.0.x VM: install the package, set up two kids (3-5 no-password, 9-12 with password) in under ten minutes, keyboard only.
2. Reboot: the parent's disk password lands on the parent's desktop; the 9-12 kid's lands on Level 2; the portal shows three tiles after logout.
3. Super+Shift+K Pause and Finish both work; the parent's desktop, browser, and DNS are unchanged throughout.
4. Kid browser: walled garden holds; family DoH active; history cannot be cleared.
5. Screen time: budget → warnings → lock → ask → parent grants → continues.
6. Ask for an app → queue → approve in panel and in the bar widget → installed and visible.
7. `omarchy update` and a kernel update: every check green, boot hook present; delete a lock by hand, kid login refuses.
8. Remove Kids Mode: files preserved, one tile, stock boot behavior back.
9. Change the parent's login password: every Kids Mode prompt follows.

## 9. Decided against, on the record

- `Defaults rootpw` for kid sudo (installer path): our parent has an account to verify against; root's password drifts from the login password after `passwd`.
- Site history hidden from parents (report 07): chosen otherwise; per-kid cell.
- Firefox for kids; session-hook policy swapping; family boot word; hidden parent tile; timekpr; malcontent; Flatpak.
- Any network listener other than `omarchy-kids-relayd`; any listener while notifications are off; any outbound connection from any command other than `omarchy-kids-relay-courier`; any server run by this project or a vendor as a content path; plaintext child data to any server, including the parent's own; data beyond the request and status fields Appendix H names; a kid session holding any credential to the relay; pairing without the parent password (R-NOTIFY-1..12).

---

## Appendix A. Screens and copy

Voice: Omy on A1 and A14; plain elsewhere. `<K>` is the kid's name, `<Kp>` the possessive. Every screen: header (Omy glyph, "Kids Mode", step "n of 12"), body, footer "Enter continue · Esc back · Ctrl+C leave (nothing changes)".

| # | Screen | Copy | Input |
| --- | --- | --- | --- |
| A1 | Welcome | "Hi, I'm Omy. Kids Mode turns this computer into one your kids can use on their own." Bullets: "Each kid gets their own desktop, at their own level." "You stay in charge with one password, yours." "Everything can be undone." Button **Begin** | Enter |
| A2 | Parent password | "First, your password. Kids Mode uses it for every grown-up decision. It's the same one you log in with." | password |
| A3 | Name | "What's your kid's name?" hint "First name or nickname. It's what they'll see." | text |
| A4 | Face | "Pick <Kp> face." grid of 12 avatars | arrows |
| A5 | Age | "How old is <K>?" tiles 3-5 · 6-8 · 9-12 · 13+, each with one line ("Pre-reader. One app at a time.") | arrows |
| A6 | Simple or Advanced | "How do you want to set up <Kp> computer?" **Simple** "A few clear choices with sensible defaults. About five minutes." **Advanced** "Every setting on one screen." | arrows |
| A7 | Web (Simple) | "What can <K> see on the web?" A **Only sites you choose** "A short list you can grow. Best for younger kids." B **Filtered open web** "Adult content blocked, safe search on." (3-5 also: **No browser**) | A/B |
| A8 | Time (Simple) | "How much screen time?" A shows the band's weekday limits and the current weekend limits; B "I'll set my own" → edit weekday minutes and bedtime (weekend values are edited in Advanced) | A/B |
| A9 | Apps (Simple) | "Which apps to start with?" A **The <band> starter pack** list of names B **Let me pick** → checklist | A/B |
| A10 | Wi-Fi (Simple) | "Can <K> join new Wi-Fi?" A **Ask me first** B **On their own, safely** "They can join school or café Wi-Fi. The network can't change what's blocked." | A/B |
| A11 | Level (Simple) | "How should <Kp> desktop work?" 1 **One thing at a time** 2 **Two things side by side** with a one-liner each; band default marked. **3 Full desktop is hidden in v1** (unverified binds and sudo path, `docs/phase1/DECISIONS-NEEDED.md` §6); existing level = 3 profiles still start | arrows |
| A12 | Kid password | "Now a password for <K>." hint by band; 3-5 adds **No password** | password ×2 |
| A13 | Summary | "Here's what happens next." bullets: account, desktop level, web, weekday/weekend screen-time and lights-out limits, apps, Wi-Fi; then "When the computer starts, whoever types their password lands on their own desktop. The youngest kids with no password get in after a grown-up starts it." Buttons **Apply** · **Change something** | Enter |
| A13a | Advanced table | groups Web / Time / Apps / Wi-Fi / Desktop / Data; space toggles, slash filters, Enter picks | checklist |
| A13b | Apply | one line per step with ✓, one bar, tip line; log to `/var/log/omarchy-kids/setup.log` | none |
| A13c | Safety check | green/red list; firmware step red with "Print the parent card" | Enter |
| A14 | Done | "<K>'s desktop is ready." Omy: "Next time the computer starts, <K> signs in from the login screen." One button **Return to my desktop** (the preview button is not shipped; the login-screen line is true in disk and portal mode and for no-password kids) | arrows |

Consents asked once, on A13 as two extra lines with defaults on: "Add Super+Shift+K to open Kids Mode on my desktop" and "Show my kids' status in my top bar".

Panel screens: P1 Home (kids list, gear, add a kid). P2 Kid (numbers, settings, requests, actions). P3 Requests. P4 Machine (safety, firmware card, remove). P5 Confirm remove (parent password).

Kid-side screens: K1 Level 1 launcher. K2 Exit modal (R-EXIT-1). K3 Ask a parent. K4 Time's up. K5 "What my grown-ups can see". K6 "Ask a grown-up" (failed check).

## Appendix B. Profile schema

B.1 Account name: `kid-` + slug of the display name (lowercase ASCII, transliterated, non-alphanumerics dropped, max 24); collisions get `-2`, `-3`.

B.2 `/etc/omarchy-kids/kids/<account>.conf`, key=value, only overrides present:

| Key | Values | Default |
| --- | --- | --- |
| `name` | text | required |
| `avatar` | id from `avatars/` | required |
| `band` | `3-5` `6-8` `9-12` `13+` | required |
| `level` | `1` `2` `3` | band |
| `web` | `garden` `filtered` `none` | band |
| `dns` | `cloudflare-family` `cleanbrowsing-family` `custom:<url>` | cloudflare-family |
| `budget_min`, `budget_min_weekend` | integer | band |
| `lights_out`, `lights_out_weekend` | HH:MM | band |
| `wifi` | `parent` `helper` | band |
| `history_visible` | `yes` `no` | yes |
| `menu` | `trimmed` `full` | by level |
| `allowlist` | comma-separated launcher ids | pack |
| `sites` | comma-separated hosts | pack |
| `password` | `set` `none` | set |
| `onboarded` | `yes` `no` | no |

## Appendix C. Bands and packs

`bands.toml`: one `[band."6-8"]` table per band with the R-BAND cells. `packs/<band>.toml`: a list of `[[app]]` with `pkg` (repo or `aur:` prefix), `id` (launcher entry), `label`, `category`, `age` (band floor), optional `web = "https://…"` for web apps; plus `[garden]` with `sites = [...]`.

## Appendix D. Queue record

`/var/lib/omarchy-kids/queue/<unix-ts>-<account>-<kind>.json`: `{ "kid": account, "kind": "time|app|plugin|site", "what": string, "minutes": int?, "asked_at": ts, "state": "open|approved|declined", "decided_at": ts?, "by": "keyboard|panel|widget|device", "device": string?, "reply": string? }`. `device` names the registry id that decided and `reply` is the parent's optional line (validated at read time: printable, bounded). Approvers append, never rewrite history.

## Appendix E. Binding tables

Level 1: `Super+Home` launcher · `Super+Enter` open selected · `Super+Q` close · `Super+Shift+K` exit modal · `Super+Shift+W` Wi-Fi picker (R-WIFI-1..2; the command itself refuses unless `wifi=helper`) · volume/brightness keys. Nothing else bound; every window rule forces fullscreen.

Level 2: Normal tiled app windows and a compact, centered, searchable allowed-app picker; no fullscreen rule for apps. Keeps the Level 1 controls plus `Super+arrows` focus · `Super+Shift+arrows` swap · `Super+K` cheat sheet · `Super+Space` launcher.

Level 3: Omarchy defaults minus: terminal-launching binds under `menu=trimmed` (kept under `full`), `omarchy-sudo-passwordless`, screenshot-to-clipboard of other users' windows (n/a), plus `Super+Shift+K` and `Super+Shift+W`.

## Appendix F. Screen-time state machine

States: `idle` (no active session) → `counting` (Active=yes, unlocked) → `warned10/5/1` → `grace` (locked, 60 s) → `ended` (terminated) ; `paused` (locked or inactive; no counting). Transitions: session Active → counting; lock or switch-away → paused; unlock → counting; `remaining ≤ 10/5/1` → warned; `remaining = 0` or `now ≥ lights_out` → grace; grant → counting with `budget += n` (budget) or `lights_out_tonight = t` (lights-out); grace timeout → ended. Suspend: wall clock jumps are ignored; only Active seconds count. Day rolls at 04:00 local; a session spanning the roll keeps counting against the new day.

## Appendix G. Bypass matrix

| Attempt | Result | Because |
| --- | --- | --- |
| Kid edits `~/.config/hypr` | No effect | `--config` root-owned |
| Kid deletes a launcher plugin | Cosmetic | plugins are never locks |
| Kid runs a downloaded binary | Blocked | noexec home |
| Kid runs `sudo` | No grant | not in sudoers; polkit asks parent |
| Kid opens Chromium with own profile dir | Still locked | policy is machine-level per group |
| Kid switches VT to parent's session | Lock screen | parent locks on switch-away |
| Kid guesses parent password at modal | Rate-limited | verifier |
| Kid boots USB knowing their LUKS passphrase | Owns the disk | firmware password is the wall; card says so |
| Package update removes a lock | Restored | pacman hook; login re-check fails closed |
| Kid changes DNS in NetworkManager | Denied | polkit; helper forces ignore-auto-dns |
| Kid reads sibling's files | Denied | separate uids, 0700 homes |
| Kid reads parent's files | Denied | separate uids |
| Level 3 kid runs any installed binary | Allowed unless fenced | stated fence |
| Kid connects to `relayd`'s TCP port | Pairing endpoint only | needs the parent password; the relay holds no decision power (R-NOTIFY-2); flooding delays notifications and nothing else |
| Paired device sends a decision | Root verifies the signature | root-owned key, bounded skew, single-use nonce, write-once record (R-NOTIFY-4) |

## Appendix H. Notification wire and file formats

```text
POST /v1/pair                       {id, name, platform, sign_pub, box_pub, proof} -> {reply}
GET  /v1/state                      -> {kids:[...], requests:[open...], recent:[decided<24h]}
GET  /v1/events                     SSE: state, request.opened, request.decided, kid.live, kid.paused, kid.timeup
POST /v1/requests/<id>/decision     {decision: approve|decline, reply?, signed:{...}}
POST /v1/kids/<account>/grant       {minutes, signed:{...}}      scope act
POST /v1/kids/<account>/end         {signed:{...}}               scope act
GET  /v1/avatars/<id>.svg
```

Authenticated requests carry `X-Kids-Device: <id>` and `X-Kids-Sig: <ts>.<nonce>.<sig>`; state changes carry an inner `signed` object that root re-verifies (R-NOTIFY-4). `proof` on `/v1/pair` is `HMAC-SHA256(token, sign_pub|box_pub|name)`, so the pairing token never travels; the `grant`/`end` routes are the ACT frame's and are not built yet.

Away envelopes (R-NOTIFY-8, N-11: the box-side courier that seals and carries them is built, `docs/courier.md`; the app that opens them is not) are `{v, device_id, eph_pub, nonce, ct}`: a fresh ephemeral X25519 key does ECDH with the device's `box_pub`, HKDF-SHA256 (salt `omarchy-kids-envelope-v1`, info `x25519-chacha20poly1305`) derives the key, and ChaCha20-Poly1305 seals the document with a 12-byte nonce and the device id as associated data. `lib/envelope.py` seals; the device opens with its private box key; `clients/parent/test-vectors/notify-vectors.json` carries the vectors the app must reproduce. The envelope is confidential, not authenticated: anyone holding the device's public key can seal one, so the app must treat a sealed state document as untrusted display data and never act on it -- the decisions it sends the other way are signed by the device and verified by root. A box identity key (or a timestamp) is a later version's job.

Files: `/etc/omarchy-kids/devices/<id>.conf` (root `0600`: name, platform, both public keys, `paired_at`, `paired_by`, scopes, `label_for_kids`); `/run/omarchy-kids/pairing/<id>` (root `0600`, single-use, expiring); `/var/lib/omarchy-kids/<kid>/decisions/<id>.json` (`0640 root:kid`, the result the kid's session reads).
