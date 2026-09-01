# Sources — the master registry

_status: living · updated 2026-09-01 · **Cite as `[R01-S14]`** (report 01, its source S14). Only rows marked `verified` may be cited from `docs/`; see ADR-0003._

How to read: every research report keeps its own `Sources` table with per-report keys. This page merges them all, de-duplicated by URL, grouped by subject. **`verified`** = a research agent fetched the page on 2026-09-01 and the content matched the claim it is cited for; **`search-only`** = surfaced in search results but not opened; **`dead/unverifiable`** = 404, blocked, or could not be confirmed. The original blueprint's bibliography is audited separately in `sources-audit/` and is **not** citable.

**Totals:** 474 unique sources from 493 citations · dead/unverifiable: 17 · search-only: 196 · verified: 261

## Add a source

Open a **📚 Add a source** issue, or PR a row into the right group below **and** into the report/note that cites it. Include the date you opened it. Don't paste a link you haven't opened.

## Contents

- [Omarchy — official (repo, manual, releases, site)](#omarchy--official-repo-manual-releases-site) (113)
- [Omarchy — community & ecosystem](#omarchy--community--ecosystem) (23)
- [Arch Linux (packages, AUR, ArchWiki)](#arch-linux-packages-aur-archwiki) (36)
- [Hyprland / Wayland / Quickshell](#hyprland--wayland--quickshell) (8)
- [Sandboxing, hardening & privilege (bubblewrap, polkit, Flatpak, fapolicyd, Limine, systemd)](#sandboxing-hardening--privilege-bubblewrap-polkit-flatpak-fapolicyd-limine-systemd) (9)
- [DNS, network & browser policy](#dns-network--browser-policy) (37)
- [Parental-control tools (Linux)](#parental-control-tools-linux) (19)
- [Kids / educational distributions & prior art](#kids--educational-distributions--prior-art) (31)
- [Mainstream parental-control benchmarks (Apple, Google, Microsoft, Nintendo, Amazon)](#mainstream-parental-control-benchmarks-apple-google-microsoft-nintendo-amazon) (15)
- [Apps, games, learning content & themes](#apps-games-learning-content--themes) (11)
- [Pedagogy, child development, AI & policy](#pedagogy-child-development-ai--policy) (22)
- [OSS governance, process & repo practice](#oss-governance-process--repo-practice) (34)
- [Other / secondary coverage](#other--secondary-coverage) (116)

## Omarchy — official (repo, manual, releases, site)

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R01-S30 | .github/ISSUE_TEMPLATE/{bug.yml,config.yml} (raw) | <https://github.com/omacom/omarchy/tree/quattro/.github/ISSUE_TEMPLATE> | verified | L11, L5 | "open source gift"; blank issues disabled; support → Discord |
| R03-S25 | bin/omarchy-apply-lock; bin/omarchy-system-lock; bin/omarchy-hyprland-session-locked; bin/omarchy-system-logout; default/systemd/user/omarchy-crash-watch.service | <https://raw.githubusercontent.com/omacom/omarchy/quattro/bin/omarchy-apply-lock> | verified | L1, L2, L4 | Lock PAM, logout via uwsm stop, crash watcher |
| R01-S55 | bin/omarchy-plugin-catalog (raw) | <https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-plugin-catalog> | verified | L11, L5 | Manifest discovery in $OMARCHY_PATH/shell/plugins and ~/.config/omarchy/plugins |
| R03-S12 | bin/omarchy-provision-owner | <https://raw.githubusercontent.com/omacom/omarchy/quattro/bin/omarchy-provision-owner> | verified | L1, L2, L4 | useradd -G wheel; root password = user password; sudoers drop-in; SDDM autologin permanent on encrypted installs; LUKS key slots |
| R03-S27 | bin/omarchy-provision-user | <https://raw.githubusercontent.com/omacom/omarchy/quattro/bin/omarchy-provision-user> | verified | L1, L2, L4 | Per-user finalisation; OMARCHY_PATH=/usr/share/omarchy |
| R03-S17 | bin/omarchy-refresh-limine; bin/omarchy-setup-direct-boot; bin/omarchy-snapshot | <https://raw.githubusercontent.com/omacom/omarchy/quattro/bin/omarchy-refresh-limine> | verified | L1, L2, L4 | Overwrites /boot/limine.conf; EFI entry to UKI; sudo limine-snapper-restore |
| R01-S56 | bin/omarchy-setup-direct-boot (raw) | <https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-setup-direct-boot> | verified | L11, L5 | EFI boot entry for the UKI (efibootmgr) |
| R03-S28 | bin/omarchy-setup-security-fido2 | <https://raw.githubusercontent.com/omacom/omarchy/quattro/bin/omarchy-setup-security-fido2> | verified | L1, L2, L4 | pam_u2f sufficient for sudo/polkit |
| R03-S15 | bin/omarchy-sudo-passwordless; bin/omarchy-sudo-keepalive | <https://raw.githubusercontent.com/omacom/omarchy/quattro/bin/omarchy-sudo-passwordless> | verified | L1, L2, L4 | 15-min NOPASSWD ALL; timestamp keepalive |
| R01-S47 | Branch compare quattro...agent-accounts (gh API) | <https://github.com/omacom/omarchy/compare/quattro...agent-accounts> | verified | L11, L5 | Adds omarchy-agent-account-{list,login,logout,switch}; touches provision-user |
| R03-S24 | config/hypr/bindings.lua; default/hypr/bindings/utilities.lua; default/hypr/windows.lua | <https://raw.githubusercontent.com/omacom/omarchy/quattro/config/hypr/bindings.lua> | verified | L1, L2, L4 | hl.unbind, omarchy_default_bindings, system menu binds, window rules |
| R01-S28 | default/agents/skills/omarchy/contributing.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/default/agents/skills/omarchy/contributing.md> | verified | L11, L5 | Issue/suggestion/support routing; AGENTS.md authority; ./test/all |
| R01-S29 | default/agents/skills/omarchy/hooks.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/default/agents/skills/omarchy/hooks.md> | verified | L11, L5 | Six hook events; `omarchy hook install` |
| R03-S16 | default/limine/limine.conf, default.conf; etc/limine-entry-tool.d/*.conf | <https://raw.githubusercontent.com/omacom/omarchy/quattro/default/limine/limine.conf> | verified | L1, L2, L4 | No editor_enabled; UKI; ESP_PATH=/boot; BOOT_ORDER incl. Snapshots |
| R01-S21 | Develop a Plugin guide | <https://plugins.omarchy.org/develop.html> | verified | L11, L5 | Manifest fields, kinds table, IPC commands, theming access |
| R03-S31 | Discussion #3540 Auto-login potential security issue? | <https://github.com/omacom/omarchy/discussions/3540> | verified | L1, L2, L4 | greetd suggestion; no maintainer reply |
| R03-S32 | Discussion #3953 multiple users with proper lock screen | <https://github.com/omacom/omarchy/discussions/3953> | verified | L1, L2, L4 | Request only |
| R01-S23, R03-S30 | Discussion #532 "Support Multiple Users" | <https://github.com/omacom/omarchy/discussions/532> | verified | L1, L2, L4, L11, L5 | Single-user by design; LUKS gate; "coming in 4.1" comment 2026-08-18 |
| R01-S26 | docs/file-layout.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/docs/file-layout.md> | verified | L11, L5 | Package split; seed/finalize/resync; installed paths; deferred provisioning |
| R01-S42 | docs/menu.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/docs/menu.md> | verified | L11, L5 | Menu JSONC schema; user extension overlay; guards |
| R01-S27 | docs/update-process.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/docs/update-process.md> | verified | L11, L5 | Update pipeline; per-user migrations; pacman guard |
| R03-S19 | etc/mkinitcpio.conf.d/omarchy_hooks.conf (quattro); install/login/limine-snapper.sh (master) | <https://raw.githubusercontent.com/omacom/omarchy/quattro/etc/mkinitcpio.conf.d/omarchy_hooks.conf> | verified | L1, L2, L4 | `encrypt` + `btrfs-overlayfs` hooks; limine-mkinitcpio-hook; quota disabled |
| R01-S34 | etc/mkinitcpio.conf.d/omarchy_hooks.conf (raw) | <https://github.com/omacom/omarchy/blob/quattro/etc/mkinitcpio.conf.d/omarchy_hooks.conf> | verified | L11, L5 | plymouth, encrypt, btrfs-overlayfs hooks |
| R03-S14 | etc/sudoers.d/* | <https://raw.githubusercontent.com/omacom/omarchy/quattro/etc/sudoers.d/omarchy-dns> | verified | L1, L2, L4 | Narrow wheel NOPASSWD rules |
| R03-S26 | etc/systemd/logind.conf.d/10-ignore-power-button.conf | <https://raw.githubusercontent.com/omacom/omarchy/quattro/etc/systemd/logind.conf.d/10-ignore-power-button.conf> | verified | L1, L2, L4 | HandlePowerKey=ignore |
| R05-S11 | Gaming | <https://omarchy.org/manual/gaming/> | verified | L7, L8 | Install > Gaming list incl. Minecraft; Fortnite/Rocket League anti-cheat caveat. |
| R05-S12 | Hotkeys | <https://omarchy.org/manual/hotkeys/> | verified | L7, L8 | Super+K; theme/background/menu keys; bindings.lua. |
| R05-S2 | Hotkeys · Omarchy 3 Manual | <https://learn.omacom.io/2/the-omarchy-manual/53/themes> | verified | L7, L8 | URL resolves to the hotkeys page; theme hotkeys, backgrounds dir. |
| R03-S22 | install/config/firewall.sh | <https://raw.githubusercontent.com/omacom/omarchy/quattro/install/config/firewall.sh> | verified | L1, L2, L4 | ufw policy |
| R01-S31 | install/config/firewall.sh (raw) | <https://github.com/omacom/omarchy/blob/quattro/install/config/firewall.sh> | verified | L11, L5 | ufw deny-in/allow-out; 53317; ufw-docker |
| R03-S13 | install/config/increase-lockout-limit.sh; etc/security/faillock.conf | <https://raw.githubusercontent.com/omacom/omarchy/quattro/install/config/increase-lockout-limit.sh> | verified | L1, L2, L4 | deny=10 unlock_time=120; sddm-autologin PAM |
| R01-S33 | install/config/snapper.sh (raw) | <https://github.com/omacom/omarchy/blob/quattro/install/config/snapper.sh> | verified | L11, L5 | Snapper root config; limine-snapper-sync |
| R03-S18 | install/config/snapper.sh; default/snapper/root | <https://raw.githubusercontent.com/omacom/omarchy/quattro/install/config/snapper.sh> | verified | L1, L2, L4 | Root-only, limit 5, no timeline |
| R01-S32 | install/helpers/browser-policy.sh (raw) | <https://github.com/omacom/omarchy/blob/quattro/install/helpers/browser-policy.sh> | verified | L11, L5 | Managed policy dirs for Chromium/Chrome/Edge/Brave; Firefox/Zen distribution dirs |
| R03-S20 | install/login/sddm.sh (quattro & master); etc/sddm.conf.d/10-wayland.conf; default/wayland-sessions/omarchy.desktop; default/sddm/hyprland.lua | <https://raw.githubusercontent.com/omacom/omarchy/quattro/install/login/sddm.sh> | verified | L1, L2, L4 | Greeter = Hyprland `--config`; session = uwsm |
| R01-S35 | install/login/sddm.sh + etc/sddm.conf.d/10-wayland.conf (raw) | <https://github.com/omacom/omarchy/tree/quattro/install/login> | verified | L11, L5 | SDDM present; ISO owns autologin state |
| R01-S36 | install/omarchy-base.packages + omarchy-other.packages (raw) | <https://github.com/omacom/omarchy/tree/quattro/install> | verified | L11, L5 | hyprland, quickshell, foot, chromium, limine, btrfs-progs, snapper, networkmanager, ufw, uwsm, sddm, plymouth; no apparmor/iwd/grub |
| R03-S23 | install/omarchy-base.packages; install/omarchy-other.packages | <https://raw.githubusercontent.com/omacom/omarchy/quattro/install/omarchy-base.packages> | verified | L1, L2, L4 | Package inventory |
| R05-S9 | Making your own theme | <https://omarchy.org/manual/making-your-own-theme/> | verified | L7, L8 | colors.toml, mode=light, icons.theme, themed/*.tpl, naming convention, install path. |
| R01-S41 | manual/02-getting-started.md (raw, grep) | <https://github.com/omacom/omarchy/blob/quattro/manual/02-getting-started.md> | verified | L11, L5 | "Installing for another owner" |
| R01-S37 | manual/06-themes.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/manual/06-themes.md> | verified | L11, L5 | 22 themes; what a theme styles; unlock images |
| R01-S15 | manual/11-text-extraction-dictation.md (quattro, raw) | <https://github.com/omacom/omarchy/blob/quattro/manual/11-text-extraction-dictation.md> | verified | L11, L5 | Voxtype; F9 / Super+Ctrl+X; Tesseract |
| R01-S39 | manual/23-browsers.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/manual/23-browsers.md> | verified | L11, L5 | Chromium default; policy dirs; extensions; alternatives |
| R01-S14 | manual/32-shell-plugins.md (quattro, raw) | <https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md> | verified | L11, L5 | Plugin model, kinds, commands, reserved namespace, security warning |
| R01-S38 | manual/43-making-your-own-theme.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/manual/43-making-your-own-theme.md> | verified | L11, L5 | colors.toml; code-stripping rule; naming; templates; catalog PR |
| R01-S25 | manual/48-security.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/manual/48-security.md> | verified | L11, L5 | Source of S24 |
| R01-S40 | manual/51-unattended-installs.md (raw) | <https://github.com/omacom/omarchy/blob/quattro/manual/51-unattended-installs.md> | verified | L11, L5 | cidata NoCloud; defer-provisioning; SSH/Tailscale keys |
| R03-S9 | Manual: Dotfiles; Hotkeys | <https://raw.githubusercontent.com/omacom/omarchy/quattro/manual/31-dotfiles.md> | verified | L1, L2, L4 | Lua config file layout |
| R03-S6 | Manual: Getting started | <https://raw.githubusercontent.com/omacom/omarchy/quattro/manual/02-getting-started.md> | verified | L1, L2, L4 | Secure Boot/TPM off; prepare-for-another-owner; no-encryption option |
| R03-S10 | Manual: Hardware authentication | <https://raw.githubusercontent.com/omacom/omarchy/quattro/manual/37-hardware-authentication.md> | verified | L1, L2, L4 | FIDO2 covers sudo/polkit, not unlock |
| R03-S5 | Manual: Manual installation | <https://learn.omacom.io/2/the-omarchy-manual/96/manual-installation> | verified | L1, L2, L4 | archinstall: Limine, btrfs default structure, LUKS, auto-login |
| R03-S3 | Manual: Security | <https://learn.omacom.io/2/the-omarchy-manual/93/security> | verified | L1, L2, L4 | LUKS mandatory, two passwords, Reset Computer, passwordless sudo, ufw |
| R03-S4 | Manual: System snapshots | <https://learn.omacom.io/2/the-omarchy-manual/101/system-snapshots> | verified | L1, L2, L4 | Limine-only, /home preserved, Direct Boot |
| R03-S8 | Manual: Toggles, idle & screensaver | <https://raw.githubusercontent.com/omacom/omarchy/quattro/manual/13-toggles-idle-screensaver.md> | verified | L1, L2, L4 | Lock screen behaviour |
| R03-S7 | Manual: Troubleshooting | <https://raw.githubusercontent.com/omacom/omarchy/quattro/manual/45-troubleshooting.md> | verified | L1, L2, L4 | Ctrl+Alt+F2 root login for faillock reset |
| R03-S11 | Manual: Unattended installs | <https://raw.githubusercontent.com/omacom/omarchy/quattro/manual/51-unattended-installs.md> | verified | L1, L2, L4 | LUKS passphrase typed at first boot; cidata |
| R03-S21 | migrations/1758487660_change_dm_to_sddm.sh (master) | <https://raw.githubusercontent.com/omacom/omarchy/master/migrations/1758487660_change_dm_to_sddm.sh> | verified | L1, L2, L4 | seamless-login → SDDM; enables getty@tty1 |
| R01-S11 | Omacom Foundation launches | <https://omarchy.org/news/2026/08/omacom-foundation-launches-with-8-million> | verified | L11, L5 | $12.6M pledged; trademarks/infrastructure; no grant program described |
| R01-S46 | omacom org repository list (gh API) | <https://github.com/omacom> | verified | L11, L5 | omarchy-iso, omarchy-pkgs, aether, marketplace, registry, retired omakub/omamac |
| R01-S4, R03-S1, R06-S31 | omacom/omarchy repo (gh API: metadata, branches, tree, releases) | <https://github.com/omacom/omarchy> | verified | L1, L2, L4, L11, L5, community | Default branch `quattro`; 36,693 stars; MIT; 2,015 paths; 444 bin scripts |
| R01-S54 | omacom/omarchy-iso README (raw) | <https://github.com/omacom/omarchy-iso> | verified | L11, L5 | Configurator → archinstall; `--quattro` builds; edge mirror |
| R01-S22 | omacom/omarchy-plugin-marketplace registry.json | <https://github.com/omacom/omarchy-plugin-marketplace> | verified | L11, L5 | 22 `sources`; keys retiredPluginIds/repositoryMigrations/sources |
| R01-S24 | Omarchy 4 manual: Security | <https://omarchy.org/manual/security/> | verified | L11, L5 | LUKS mandatory; ufw; reset computer; passwordless sudo; signing key |
| R04-S37 | Omarchy bin/omarchy-default-browser | <https://github.com/omacom/omarchy/blob/master/bin/omarchy-default-browser> | verified | L3 | supported browsers list |
| R04-S85 | Omarchy bin/omarchy-install-chromium-google-account | <https://github.com/omacom/omarchy/blob/master/bin/omarchy-install-chromium-google-account> | verified | L3 | Adds OAuth client flags to chromium-flags.conf |
| R04-S35 | Omarchy bin/omarchy-launch-webapp | <https://github.com/omacom/omarchy/blob/master/bin/omarchy-launch-webapp> | verified | L3 | `--app=` launch, browser fallback |
| R04-S30 | Omarchy bin/omarchy-setup-dns | <https://github.com/omacom/omarchy/blob/master/bin/omarchy-setup-dns> | verified | L3 | Writes resolved.conf; UseDNS=no lock |
| R04-S36 | Omarchy bin/omarchy-webapp-install | <https://github.com/basecamp/omarchy/blob/master/bin/omarchy-webapp-install> | verified | L3 | .desktop writer, favicon fetch |
| R04-S38 | Omarchy config/chromium-flags.conf | <https://github.com/omacom/omarchy/blob/master/config/chromium-flags.conf> | verified | L3 | `--load-extension` copy-url |
| R04-S44 | Omarchy discussion #2468 (Firefox as web-app browser) | <https://github.com/omacom/omarchy/discussions/2468> | verified | L3 | Dedicated Firefox profile approach |
| R01-S43, R05-S22 | Omarchy extra themes catalog | <https://omarchy.org/themes/> | verified | L11, L5, L7, L8 | ~300+ themes; Install > Style > Theme; PR to omarchy-site |
| R01-S1 | Omarchy homepage | <https://omarchy.org/> | verified | L11, L5 | Version 4.0.2, links to omacom repo, Discord, manual, plugins site, foundation news |
| R04-S31 | Omarchy install/config/hardware/network.sh | <https://github.com/omacom/omarchy/blob/master/install/config/hardware/network.sh> | verified | L3 | Enables iwd; masks networkd-wait-online |
| R04-S32 | Omarchy install/first-run/dns-resolver.sh | <https://github.com/omacom/omarchy/blob/master/install/first-run/dns-resolver.sh> | verified | L3 | stub-resolv.conf symlink |
| R04-S33 | Omarchy install/first-run/firewall.sh | <https://github.com/omacom/omarchy/blob/master/install/first-run/firewall.sh> | verified | L3 | ufw deny in / allow out |
| R04-S34 | Omarchy install/omarchy-base.packages | <https://github.com/omacom/omarchy/blob/master/install/omarchy-base.packages> | verified | L3 | chromium, iwd, impala, ufw, polkit-gnome; no NetworkManager |
| R04-S39 | Omarchy install/packaging/webapps.sh | <https://github.com/omacom/omarchy/blob/master/install/packaging/webapps.sh> | verified | L3 | Stock web apps incl. YouTube, X, Discord |
| R04-S43 | Omarchy issue #1384 (separate Chromium profile per web app) | <https://github.com/omacom/omarchy/issues/1384> | verified | L3 | Closed 2025-09-01 |
| R04-S42 | Omarchy issue #8495 (javascript:/file: URLs in --app) | <https://github.com/omacom/omarchy/issues/8495> | verified | L3 | Closed 2026-08-27 |
| R06-S30 | Omarchy LICENSE | <https://github.com/basecamp/omarchy/blob/master/LICENSE> | verified | community | MIT; "Copyright (c) David Heinemeier Hansson"; renders under omacom/omarchy |
| R01-S20 | Omarchy Plugin Marketplace | <https://plugins.omarchy.org/> | verified | L11, L5 | omarchyplugins.com 301s here; MIT; HANCORE; submit via GitHub |
| R04-S45 | Omarchy releases | <https://github.com/omacom/omarchy/releases> | verified | L3 | v4.0.2, 2026-08-31 |
| R05-S3 | Omarchy themes directory | <https://github.com/basecamp/omarchy/tree/master/themes> | verified | L7, L8 | Redirects to omacom/omarchy; 20 theme dirs; 36.7k stars. |
| R05-S15 | omarchy-shell.md (quattro) | <https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md> | verified | L7, L8 | Plugin manifest/kinds/dirs, shell.toml keys, IPC commands. |
| R01-S12 | omarchy.org/security | <https://omarchy.org/security/> | verified | L11, L5 | Vulnerability reporting only (security@omarchy.org) |
| R01-S9, R05-S46 | PR #6231 "Omarchy Quattro" | <https://github.com/omacom/omarchy/pull/6231> | verified | L11, L5, L7, L8 | Opened 2026-07-17; 1,998 commits; layout migration notes |
| R01-S6, R05-S7 | Release v4.0.0 "The Quattro Release" | <https://github.com/omacom/omarchy/releases/tag/v4.0.0> | verified | L11, L5, L7, L8 | 2026-08-14; full feature list; Quickshell; Foot; Lua; plugin system |
| R01-S7 | Release v4.0.1 "Fast-Follow Fixes" | <https://github.com/omacom/omarchy/releases/tag/v4.0.1> | verified | L11, L5 | 2026-08-25; security fixes incl. theme code stripping, plugin-add guards |
| R01-S8 | Release v4.0.2 | <https://github.com/omacom/omarchy/releases/tag/v4.0.2> | verified | L11, L5 | 2026-08-31; signed packages required; browser policy dir hardening |
| R03-S29 | Repo tree & branches (GitHub API) | <https://api.github.com/repos/omacom/omarchy/git/trees/quattro?recursive=1> | verified | L1, L2, L4 | hooks dir `config/omarchy/hooks/post-update.d`; `agent-accounts` branch = provider accounts |
| R05-S16 | Text Extraction & Dictation | <https://omarchy.org/manual/text-extraction-dictation/> | verified | L7, L8 | Voxtype; F9 hold / Super+Ctrl+X; tesseract OCR. |
| R01-S2, R03-S2 | The Omarchy 3 Manual (legacy index) | <https://learn.omacom.io/2/the-omarchy-manual/> | verified | L1, L2, L4, L11, L5 | Labels itself legacy v3; v4 has separate manual; Waybar-era content |
| R01-S5, R05-S4 | The Omarchy 4 Manual index | <https://omarchy.org/manual/> | verified | L11, L5, L7, L8 | 51 chapters incl. Shell Plugins, Security, Unattended Installs |
| R04-S40 | The Omarchy Manual: Browsers | <https://omarchy.org/manual/browsers/> | verified | L3 | Chromium default; web apps run in it |
| R04-S41 | The Omarchy Manual: Web Apps | <https://omarchy.org/manual/web-apps/> | verified | L3 | Install > Web App; shared logins |
| R05-S10 | Themes | <https://omarchy.org/manual/themes/> | verified | L7, L8 | Built-ins, hotkeys, Extra themes page reference. |
| R05-S8 | themes/tokyo-night | <https://github.com/omacom/omarchy/tree/master/themes/tokyo-night> | verified | L7, L8 | Exact theme file list. |
| R01-S16 | v3 manual: Text Extraction & Dictation | <https://learn.omacom.io/2/the-omarchy-manual/116/text-extraction-dictation> | verified | L11, L5 | Same content as S15 |
| R06-S58 | basecamp/omarchy-basecamp-plugin | <https://github.com/basecamp/omarchy-basecamp-plugin> | search-only | community | Official plugin naming precedent |
| R01-S17 | Blueprint URL ".../58/dictation" | <https://learn.omacom.io/2/the-omarchy-manual/58/dictation> | dead/unverifiable | L11, L5 | Page 58 is "Shell Functions" |
| R01-S58 | Discussion #3540 "Auto-login potential security issue?" | <https://github.com/basecamp/omarchy/discussions/3540> | search-only | L11, L5 | Autologin threat discussion |
| R05-S71 | Extra themes · Omarchy 3 Manual | <https://learn.omacom.io/2/the-omarchy-manual/90/extra-themes> | search-only | L7, L8 | . |
| R01-S59 | Issue #2880 "Add a matching SDDM login screen theme" | <https://github.com/basecamp/omarchy/issues/2880> | search-only | L11, L5 | SDDM theme (now shipped) |
| R03-S67 | omacom/omarchy discussion #2296 Dual-Boot Secure Boot Setup (Custom Keys) | <https://github.com/omacom/omarchy/discussions/2296> | search-only | L1, L2, L4 | Secure Boot precedent |
| R06-S57 | omacom/omarchy-pkgs | <https://github.com/omacom/omarchy-pkgs> | search-only | community | Confirms `omacom` org and `omarchy-*` naming |
| R01-S48 | Omarchy 4 manual: Networking | <https://omarchy.org/manual/networking/> | search-only | L11, L5 | `omarchy dns`; Setup > Network > DNS; Cloudflare/Google/custom |
| R05-S6 | omarchy-shell.md (master) | <https://github.com/omacom/omarchy/blob/master/docs/omarchy-shell.md> | dead/unverifiable | L7, L8 | 404 on master; see S15. |
| R01-S61 | omarchy-site repo (theme catalog PR target) | <https://github.com/omacom-io/omarchy-site> | search-only | L11, L5 | Linked from manual; omacom org also lists `omarchy-site` |
| R05-S47 | PR #5856 Omarchy goes Quickshell | <https://github.com/omacom/omarchy/pull/5856> | search-only | L7, L8 | . |
| R03-S64 | PR basecamp/omarchy#5723 Hyprland lua conversion | <https://github.com/basecamp/omarchy/pull/5723> | search-only | L1, L2, L4 | Lua migration |
| R01-S19 | shell/plugins/bar/README.md (omacom) | <https://github.com/omacom/omarchy/blob/quattro/shell/plugins/bar/README.md> | search-only | L11, L5 | Appeared in search; blueprint's omarchy/omarchy variant 404s |
| R04-S83 | The Omarchy 3 Manual: Web Apps (learn.omacom.io) | <https://learn.omacom.io/2/the-omarchy-manual/63/web-apps> | search-only | L3 | Mirror of S41 |
| R06-S56 | The Omarchy Manual (Getting Started; Omarchy on...) | <https://omarchy.org/manual/getting-started/> | search-only | community | Discord channels #omarchy-help, #omarchy-on-other |

## Omarchy — community & ecosystem

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R01-S45 | GitHub repo search results (omarchy kids/parental/school/kiosk; omarchy-theme; omarchy plugin) | <https://github.com/search?q=omarchy+kids&type=repositories> | verified | L11, L5 | Only omarchy-kids matched; 50+ theme repos; ~15 plugin repos sampled |
| R01-S3, R05-S1 | github.com/omarchy/omarchy | <https://github.com/omarchy/omarchy> | verified | L11, L5, L7, L8 | Unrelated 3-star personal profile repo — not Omarchy |
| R01-S44 | jfuerwentsches/omarchy-kids (README + tree via gh API) | <https://github.com/jfuerwentsches/omarchy-kids> | verified | L11, L5 | Created 2026-08-27; Rust agent + Qt control + tiers; "not usable yet" |
| R01-S10, R03-S65 | Phoronix: Omarchy 4.0 Released | <https://www.phoronix.com/news/Omarchy-4.0-Released> | verified | L1, L2, L4, L11, L5 | Confirms date and Quickshell consolidation |
| R01-S50 | "Omarchy: Any User Process Can Escalate to Root" | <https://0xcc.io/posts/omarchy-root-creds/> | dead/unverifiable | L11, L5 | HTTP 403; title only |
| R03-S69 | akitaonrails: Installing Omarchy 2.0 from Scratch | <https://akitaonrails.com/en/2025/08/29/new-omarchy-2-0-install/> | search-only | L1, L2, L4 | @/@home/@log/@pkg subvolumes |
| R05-S24 | aorumbayev/awesome-omarchy | <https://github.com/aorumbayev/awesome-omarchy> | search-only | L7, L8 | Community index. |
| R01-S18 | Blueprint URL omarchy/omarchy .../32-shell-plugins.md | <https://github.com/omarchy/omarchy/blob/quattro/manual/32-shell-plugins.md> | dead/unverifiable | L11, L5 | 404 — wrong org |
| R01-S57 | codetocloud.io: Omarchy 4 Quattro what's new | <https://codetocloud.io/blog/omarchy-4-quattro-whats-new/> | search-only | L11, L5 | Secondary coverage |
| R01-S60 | deepakness/omarchy-hub | <https://github.com/deepakness/omarchy-hub> | search-only | L11, L5 | Unofficial resource library |
| R01-S63 | Lunduke: Omarchy 2.0 | <https://lunduke.substack.com/p/omarchy-20-the-arch-based-hyprland> | search-only | L11, L5 | Old (Discord >6,000 members at 2 months) |
| R05-S45 | Omarchy 4.0 (desdelinux) | <https://blog.desdelinux.net/en/omarchy-4.0-release-new-features-quickshell-omakase/> | search-only | L7, L8 | Quickshell rewrite summary. |
| R05-S50 | Omarchy cheat sheet | <https://acrogenesis.com/omarchy-cheat-sheet/> | search-only | L7, L8 | Printable reference. |
| R05-S49 | Omarchy has 227 shortcuts | <https://www.pacyfist.dev/posts/omarchy-has-227-shortcuts-heres-how-i-remember-them/> | search-only | L7, L8 | Super+K popup generated from user config. |
| R06-S55 | Omarchy News | <https://omarchynews.com/posts/60-v205> | search-only | community | "not affiliated with 37signals" |
| R06-S54 | Omarchy Themes | <https://omarchythemes.com/> | search-only | community | "not affiliated with 37signals" |
| R03-S62 | Omarchy user docs (docuwriter): Auto-login and Plymouth splash | <https://docs.docuwriter.ai/omarchy-user-docs/78789> | search-only | L1, L2, L4 | Describes the retired seamless-login helper |
| R05-S25 | omarchy-themes topic | <https://github.com/topics/omarchy-themes> | search-only | L7, L8 | GitHub topic listing. |
| R05-S48 | Quattro upgrade checklist | <https://omarchypulse.com/articles/upgrading-to-quattro> | search-only | L7, L8 | . |
| R01-S51 | r/omarchy "Installing Omarchy on school computers" (blueprint URL) | <https://www.reddit.com/r/omarchy/comments/1vnklrc/installing_omarchy_on_school_computers/> | dead/unverifiable | L11, L5 | reddit blocked from tool; not surfaced by 3 searches |
| R06-S53 | themartiano/try-omarchy | <https://github.com/themartiano/try-omarchy> | search-only | community | "not official or affiliated... not endorsed by Basecamp" |
| R05-S23 | Wheel-Smith/awesome-omarchy | <https://github.com/Wheel-Smith/awesome-omarchy> | search-only | L7, L8 | Community index. |
| R06-S61 | Wikipedia: Omarchy | <https://en.wikipedia.org/wiki/Omarchy> | search-only | community | MIT; v4.0 Aug 2026 (per search snippet) |

## Arch Linux (packages, AUR, ArchWiki)

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R02-S1 | Arch Linux package search: malcontent | <https://archlinux.org/packages/?q=malcontent> | verified | L1, L9, all | libmalcontent / malcontent / malcontent-docs 0.14.0-4 in extra, updated 2026-04-11 |
| R04-S23 | Arch package chromium | <https://archlinux.org/packages/extra/x86_64/chromium/> | verified | L3 | 152.0.7977.64, extra |
| R04-S21 | Arch package dnscrypt-proxy | <https://archlinux.org/packages/extra/x86_64/dnscrypt-proxy/> | verified | L3 | 2.1.18, extra, updated 2026-07-21 |
| R05-S19 | Arch package JSON API | <https://archlinux.org/packages/search/json/> | verified | L7, L8 | (curl, 90 names) — Official repo versions/dates in the catalog. |
| R04-S22 | Arch package nftables | <https://archlinux.org/packages/extra/x86_64/nftables/> | verified | L3 | 1.1.6, extra |
| R03-S52 | Arch package pages | <https://archlinux.org/packages/extra/x86_64/malcontent/> | verified | L1, L2, L4 | Versions as of 2026-09-01; fortune-mod has no off/ DB |
| R03-S40 | ArchWiki: AppArmor | <https://wiki.archlinux.org/title/AppArmor> | verified | L1, L2, L4 | lsm= parameter, service, profiling |
| R03-S46 | ArchWiki: Btrfs; fstab | <https://wiki.archlinux.org/title/Btrfs> | verified | L1, L2, L4 | Subvolume mount semantics; user/users imply noexec |
| R03-S35 | ArchWiki: Bubblewrap; Bubblewrap/Examples | <https://wiki.archlinux.org/title/Bubblewrap> | verified | L1, L2, L4 | Wayland/PipeWire/DRI examples, `--symlink usr/lib /lib64` |
| R03-S37 | ArchWiki: Firejail | <https://wiki.archlinux.org/title/Firejail> | verified | L1, L2, L4 | setuid, profiles, firecfg, force-nonewprivs |
| R03-S45 | ArchWiki: Flatpak; Flatpak docs: Sandbox Permissions | <https://wiki.archlinux.org/title/Flatpak> | verified | L1, L2, L4 | override syntax; sandbox caveats |
| R03-S42 | ArchWiki: Getty | <https://wiki.archlinux.org/title/Getty> | verified | L1, L2, L4 | Autologin drop-in, NAutoVTs |
| R03-S51 | ArchWiki: Keyboard shortcuts (SysRq) | <https://wiki.archlinux.org/title/Keyboard_shortcuts> | verified | L1, L2, L4 | kernel.sysrq=16 default |
| R03-S34 | ArchWiki: Limine | <https://wiki.archlinux.org/title/Limine> | verified | L1, L2, L4 | limine-entry-tool, enroll-config, snapper sync, UKI, Secure Boot tip |
| R03-S50 | ArchWiki: NetworkManager | <https://wiki.archlinux.org/title/NetworkManager> | verified | L1, L2, L4 | Polkit prefix rule |
| R02-S2, R03-S49 | ArchWiki: Parental control | <https://wiki.archlinux.org/title/Parental_control> | verified | L1, L2, L4, L1, L9, all | Full page summarised in §3 |
| R03-S38 | ArchWiki: Polkit | <https://wiki.archlinux.org/title/Polkit> | verified | L1, L2, L4 | rules.d, addRule examples, admin identities |
| R03-S41 | ArchWiki: Security | <https://wiki.archlinux.org/title/Security> | verified | L1, L2, L4 | Mount options, faillock, userns, SUID risks, ptrace |
| R03-S47 | ArchWiki: Snapper | <https://wiki.archlinux.org/title/Snapper> | verified | L1, L2, L4 | ALLOW_USERS, read-only snapshot boot issues |
| R03-S44 | ArchWiki: Sudo | <https://wiki.archlinux.org/title/Sudo> | verified | L1, L2, L4 | sudoers.d, timestamp_timeout |
| R03-S39 | ArchWiki: systemd-homed | <https://wiki.archlinux.org/title/Systemd-homed> | verified | L1, L2, L4 | Storage backends, caveats |
| R03-S48 | ArchWiki: Users and groups | <https://wiki.archlinux.org/title/Users_and_groups> | verified | L1, L2, L4 | Group semantics |
| R05-S20 | AUR RPC v5 | <https://aur.archlinux.org/rpc/v5/> | verified | L7, L8 | (curl, ~90 names) — AUR versions, last-modified, votes, out-of-date flags. |
| R03-S53 | AUR RPC: fapolicyd | <https://aur.archlinux.org/rpc/v5/info/fapolicyd> | verified | L1, L2, L4 | 0 results |
| R02-S3 | AUR: timekpr-next (RPC v5 info) | <https://aur.archlinux.org/packages/timekpr-next> | verified | L1, L9, all | 0.5.10-1, maint SanskritFritz, co-maint Mjasnik, updated 2026-08-17, 9 votes; deps gtk3/polkit/libappindicator/psutil |
| R03-S36 | bwrap(1) | <https://man.archlinux.org/man/bwrap.1> | verified | L1, L2, L4 | Flag semantics |
| R03-S43 | logind.conf(5) | <https://man.archlinux.org/man/logind.conf.5> | verified | L1, L2, L4 | KillUserProcesses, NAutoVTs, ReserveVT |
| R03-S58 | sddm.conf(5) | <https://man.archlinux.org/man/sddm.conf.5> | verified | L1, L2, L4 | Relogin default false |
| R02-S33 | Arch package sugar-toolkit-gtk3 0.121-2 | <https://archlinux.org/packages/extra/x86_64/sugar-toolkit-gtk3/> | search-only | L1, L9, all | GTK3 toolkit packaged |
| R04-S24 | ArchWiki: dnscrypt-proxy | <https://wiki.archlinux.org/title/Dnscrypt-proxy> | dead/unverifiable | L3 | Anubis anti-bot wall blocked fetch |
| R04-S25 | ArchWiki: systemd-resolved | <https://wiki.archlinux.org/title/Systemd-resolved> | dead/unverifiable | L3 | Anubis wall |
| R05-S37 | AUR fortune-mod-off | <https://aur.archlinux.org/packages/fortune-mod-off> | search-only | L7, L8 | /VERIFIED via RPC — Offensive DB lives here only. |
| R05-S55 | AUR scratchjr-desktop-git | <https://aur.archlinux.org/packages/scratchjr-desktop-git> | search-only | L7, L8 | /RPC — 2021, 0 votes. |
| R04-S74 | AUR: e2guardian | <https://aur.archlinux.org/packages/e2guardian> | search-only | L3 | Packaged in AUR |
| R05-S38 | fortune(6) | <https://man.archlinux.org/man/fortune.6.en> | search-only | L7, L8 | `-o`/`-a` semantics. |
| R05-S36 | FS#76593 fortune-mod | <https://bugs.archlinux.org/task/76593> | search-only | L7, L8 | Background on removing offensive DB from Arch package. |

## Hyprland / Wayland / Quickshell

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R02-S26 | cage-kiosk/cage | <https://github.com/cage-kiosk/cage> | verified | L1, L9, all | Wayland kiosk compositor, wlroots 0.20, active |
| R03-S55 | Hyprland source: src/keybinds/Manager.cpp | <https://raw.githubusercontent.com/hyprwm/Hyprland/main/src/keybinds/Manager.cpp> | verified | L1, L2, L4 | `handleVT` hardcoded, runs in `handleInternalKeybinds` before user binds |
| R02-S25 | HyprTile | <https://hyprtile.org/> | verified | L1, L9, all | v0.16 2026-07-29; Child Lock / Kiosk Mode; GPL-3 |
| R02-S43 | ActivityWatch/aw-watcher-window-wayland | <https://github.com/ActivityWatch/aw-watcher-window-wayland> | search-only | L1, L9, all | Needs wlr-foreign-toplevel + ext-idle-notify; sway/niri/phosh |
| R02-S44 | bobvanderlinden/aw-watcher-window-hyprland | <https://github.com/bobvanderlinden/aw-watcher-window-hyprland> | search-only | L1, L9, all | Hyprland IPC watcher incl. workspace |
| R05-S70 | Hyprland cheatz | <https://cheatography.com/paulie421/cheat-sheets/hyprland-cheatz/> | search-only | L7, L8 | Search for a Hyprland keybind trainer game returned only cheat sheets; none found. |
| R02-S58 | Hyprland issue #799 "security: implement ext-session-lock-v1" | <https://github.com/hyprwm/Hyprland/issues/799> | search-only | L1, L9, all | Session lock protocol history |
| R03-S60 | Linuxiac: Hyprland 0.49 Introduces Fine-Grained Permissions | <https://linuxiac.com/hyprland-0-49-introduces-fine-grained-permissions/> | search-only | L1, L2, L4 | Version attribution |

## Sandboxing, hardening & privilege (bubblewrap, polkit, Flatpak, fapolicyd, Limine, systemd)

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R02-S7 | openSUSE Security: malcontent disk-space DoS (CVE-2026-44931) | <https://security.opensuse.org/2026/05/11/malcontent-disk-space-dos.html> | verified | L1, L9, all | 0.14.0, RecordUsage, no upstream fix, timeline Feb–May 2026 |
| R04-S26 | resolved.conf(5) (Debian manpages mirror) | <https://manpages.debian.org/unstable/systemd/resolved.conf.5.en.html> | verified | L3 | DNS= `#sni` syntax, DNSOverTLS, Domains=~., precedence |
| R03-S59 | Upstream polkit policies: udisks2, systemd login1, systemd1, Flatpak | <https://raw.githubusercontent.com/storaged-project/udisks/master/data/org.freedesktop.UDisks2.policy.in> | verified | L1, L2, L4 | Action IDs |
| R03-S56 | xkeyboard-config: symbols/srvr_ctrl; rules/base.xml | <https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config/-/raw/master/symbols/srvr_ctrl> | verified | L1, L2, L4 | `fkey2vt` vs `no_srvr_keys`; option `srvrkeys:none` |
| R07-S61 | freedesktop AppStream — `ContentRating` API and metadata spec (content_rating, oars-1.0/1.1) | <https://www.freedesktop.org/software/appstream/docs/api/class.ContentRating.html> | search-only | L5, L6, L10 | ; https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html —  (fetch 403) · 2026-09-01. |
| R02-S65 | malcontent upstream (freedesktop GitLab) | <https://gitlab.freedesktop.org/pwithnall/malcontent> | dead/unverifiable | L1, L9, all | Anubis anti-bot block; GitHub mirror used |
| R02-S61 | oss-security list, May 2026 | <https://www.openwall.com/lists/oss-security/2026/05/> | search-only | L1, L9, all | CVE-2026-44931 announcement venue |
| R04-S27 | resolved.conf(5) freedesktop | <https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html> | dead/unverifiable | L3 | HTTP 403 to fetcher |
| R04-S29 | slatecave: NetworkManager group permissions via polkit | <https://slatecave.net/blog/networkmanager-group-using-polkit/> | search-only | L3 | settings.modify.system default auth_admin_keep |

## DNS, network & browser policy

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R04-S8 | AdGuard DNS KB overview | <https://adguard-dns.io/kb/public-dns/overview/> | verified | L3 | Family blocks adult + enforces safe search |
| R04-S7 | AdGuard DNS public servers | <https://adguard-dns.io/en/public-dns.html> | verified | L3 | Family Protection IPs/DoH/DoT/DoQ/DNSCrypt; "enable Safe Search and Safe Mode, where possible" |
| R04-S50 | Chromium: DNS over HTTPS (design/FAQ) | <https://www.chromium.org/developers/dns-over-https/> | verified | L3 | Same-provider auto-upgrade; managed opt-out; no canary support |
| R04-S48 | Chromium: Linux Quick Start (policies) | <https://www.chromium.org/administrators/linux-quick-start/> | verified | L3 | /etc/chromium/policies/managed; /etc/opt/chrome |
| R01-S13, R04-S46 | Cloudflare: Supporting the future of the open web | <https://blog.cloudflare.com/supporting-the-future-of-the-open-web/> | verified | L11, L5, L3 | 2025-09-22, Sam Rhea; CDN/R2/DDoS for Omarchy |
| R04-S19 | dnscrypt-proxy example-blocked-names.txt | <https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-blocked-names.txt> | verified | L3 | Pattern syntax; `@time-to-sleep` |
| R04-S18 | dnscrypt-proxy example-cloaking-rules.txt | <https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-cloaking-rules.txt> | verified | L3 | SafeSearch cloaking examples |
| R04-S17 | dnscrypt-proxy example-dnscrypt-proxy.toml | <https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-dnscrypt-proxy.toml> | verified | L3 | blocked_names, allowed_names, schedules, cloaking, forwarding |
| R04-S20 | dnscrypt-resolvers public-resolvers.md | <https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md> | verified | L3 | cloudflare-family, adguard-dns-family-doh, cleanbrowsing-family-doh, nextdns, quad9-* present |
| R04-S52 | Firefox admin docs: DNSOverHTTPS | <https://firefox-admin-docs.mozilla.org/reference/policies/dnsoverhttps/> | verified | L3 | Enabled/ProviderURL/Locked/ExcludedDomains/Fallback |
| R04-S54 | Firefox admin docs: ExtensionSettings | <https://firefox-admin-docs.mozilla.org/reference/policies/extensionsettings/> | verified | L3 | `*` blocked; force_installed uBO example |
| R04-S55 | Firefox admin docs: policies index | <https://firefox-admin-docs.mozilla.org/reference/policies/> | verified | L3 | Policy list |
| R04-S53 | Firefox admin docs: WebsiteFilter | <https://firefox-admin-docs.mozilla.org/reference/policies/websitefilter/> | verified | L3 | 1000-entry limit; match patterns |
| R04-S56 | mozilla/policy-templates README | <https://github.com/mozilla/policy-templates> | verified | L3 | Deprecated → admin docs |
| R04-S2 | Network operators · Cloudflare 1.1.1.1 docs | <https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/> | verified | L3 | Two tiers; "contact us"/Zero Trust for customization |
| R04-S4 | NextDNS homepage (features) | <https://nextdns.io/> | verified | L3 | Parental control, SafeSearch, YouTube Restricted, Recreation Time, log retention |
| R04-S60 | nftables wiki: Quick reference (10 minutes) | <https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes> | verified | L3 | output hook, meta skuid, dport 53, verdicts |
| R04-S61 | nftables wiki: Simple ruleset for a workstation | <https://wiki.nftables.org/wiki-nftables/index.php/Simple_ruleset_for_a_workstation> | verified | L3 | table inet filter example |
| R04-S64 | Pi-hole API docs | <https://docs.pi-hole.net/api/> | verified | L3 | Auth; /api/dns/blocking; self-hosted OpenAPI |
| R04-S3 | Quad9 service addresses & features | <https://quad9.net/service/service-addresses-and-features/> | verified | L3 | Malware blocking only; no adult filtering |
| R04-S1 | Set up 1.1.1.1 · Cloudflare 1.1.1.1 docs | <https://developers.cloudflare.com/1.1.1.1/setup/> | verified | L3 | Families IPs, DoH/DoT endpoints; returns 0.0.0.0 for blocked |
| R04-S49 | Chrome Enterprise policy list | <https://chromeenterprise.google/policies/> | dead/unverifiable | L3 | JS-only render; used S47 instead |
| R04-S77 | chromium net-dev: DoH same-provider auto-upgrade | <https://groups.google.com/a/chromium.org/g/net-dev/c/lIm9esAFjQ0/m/vJ93oMbAAgAJ> | search-only | L3 | Auto-upgrade semantics |
| R04-S81 | Cloudflare One: DNS policies | <https://developers.cloudflare.com/cloudflare-one/traffic-policies/dns-policies/> | search-only | L3 | Customizable alternative to public Families |
| R04-S73 | e2guardian GitHub (repo + releases) | <https://github.com/e2guardian/e2guardian> | search-only | L3 | v5.5.9r 2025-08-22 |
| R04-S59 | Firefox admin docs: Configuring policies | <https://firefox-admin-docs.mozilla.org/guides/policies-configuration/> | search-only | L3 | policies.json locations |
| R04-S66 | HA community: Pi-hole v6 REST API temporarily disable | <https://community.home-assistant.io/t/use-pi-hole-v6-rest-api-to-temporarily-disable-blocking/811609> | search-only | L3 | timer in seconds |
| R04-S57 | Mozilla: Canary domain use-application-dns.net | <https://support.mozilla.org/en-US/kb/canary-domain-use-application-dnsnet> | dead/unverifiable | L3 | Page did not render for fetcher; behavior from snippets |
| R04-S78 | Mozilla: DNS over HTTPS FAQs | <https://support.mozilla.org/en-US/kb/dns-over-https-doh-faqs> | search-only | L3 | Default-on regions; manual DoH ignores canary |
| R04-S58 | Mozilla: Managing policies on Linux desktops | <https://support.mozilla.org/en-US/kb/managing-policies-linux-desktops> | search-only | L3 | /etc/firefox/policies |
| R04-S79 | NextDNS Help: parental-control (guessed URL) | <https://help.nextdns.io/t/g9hdkhh/parental-control> | dead/unverifiable | L3 | 404 |
| R04-S5 | NextDNS Help: What happens after 300k queries? | <https://help.nextdns.io/t/p8hmvaw/what-happens-after-300k-queries> | search-only | L3 | Becomes non-filtering resolver after quota |
| R04-S6 | NextDNS Pricing | <https://nextdns.io/pricing> | search-only | L3 | Pro $1.99/mo unlimited |
| R04-S10 | OpenDNS community: What is the default filtering? | <https://support.opendns.com/hc/en-us/community/posts/220039227-What-is-the-default-filtering> | search-only | L3 | FamilyShield categories |
| R04-S11 | OpenDNS FamilyShield router instructions | <https://support.opendns.com/hc/en-us/articles/228006487-FamilyShield-Router-Configuration-Instructions> | dead/unverifiable | L3 | 301 → Cisco community landing page |
| R04-S82 | Pi-hole discourse: NXDOMAIN for use-application-dns.net | <https://discourse.pi-hole.net/t/support-for-returning-nxdomain-for-use-application-dns-net-to-disable-firefox-doh/23243> | search-only | L3 | Canary handling |
| R04-S65 | pi-hole/FTL issue #1845 (timer ignored) | <https://github.com/pi-hole/FTL/issues/1845> | search-only | L3 | Timer bug report |

## Parental-control tools (Linux)

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R02-S6, R07-S62 | endlessm/malcontent README (GitHub mirror) | <https://github.com/endlessm/malcontent> | verified | L1, L9, all, L5, L6, L10 | Components, deps, "not a MAC system" |
| R02-S9 | GNOME gnome-shell issue #9194 "Parental control screen time limit bypass" | <https://gitlab.gnome.org/GNOME/gnome-shell/-/work_items/9194> | verified | L1, L9, all | User-switcher bypass of time limit |
| R07-S60 | Hughes, R. — "Age Ratings in GNOME Software: Introducing OARS?" (2016) | <https://blogs.gnome.org/hughsie/2016/03/07/age-ratings-in-gnome-software-introducing-oars/> | verified | L5, L6, L10 | · 2026-09-01 · rationale: upstream self-description + per-country rule engine. |
| R02-S4 | Launchpad: timekpr-next | <https://launchpad.net/timekpr-next> | verified | L1, L9, all | 0.5.10 released 2026-08-03; 0.5.9 2025-12-22; author Eduards Bezverhijs |
| R02-S10 | Linux Mint discussion #1269 | <https://github.com/orgs/linuxmint/discussions/1269> | verified | L1, L9, all | Opened 2025-12-23, Ideas category, no dev response |
| R02-S23 | marcus67/little_brother | <https://github.com/marcus67/little_brother> | verified | L1, L9, all | 0.5.6 Dec 2024; process kill; Arch tested |
| R02-S5 | Timekpr-nExT documentation | <https://mjasnik.gitlab.io/timekpr-next/> | verified | L1, L9, all | logind-based, X11/Wayland/Mir sessions, PlayTime, restriction types, Arch via AUR |
| R02-S24 | valueerrorx/LiFE-Parental-Control | <https://github.com/valueerrorx/LiFE-Parental-Control> | verified | L1, L9, all | Root daemon + Electron UI; GRUB hardening; hosts/dnsmasq; beta |
| R02-S27 | Veyon | <https://veyon.io/> | verified | L1, L9, all | Features; no Wayland statement |
| R02-S28 | Veyon docs: Platform specific notes | <https://docs.veyon.io/en/latest/admin/platform-notes.html> | verified | L1, L9, all | No Wayland section |
| R02-S8, R07-S63 | Withnall, "Parental controls in GNOME" notes (GUADEC 2020-07-23) | <https://events.gnome.org/event/1/contributions/78/attachments/11/29/presentation_notes.pdf> | verified | L1, L9, all, L5, L6, L10 | Architecture, OARS, accounts-service, 2% uptake, "not real security", screen-time future |
| R02-S59 | GNOME admin guide: single-application mode | <https://help.gnome.org/admin/system-admin-guide/stable/lockdown-single-app-mode.html.en> | search-only | L1, L9, all | Kiosk reference on GNOME |
| R03-S71 | GNOME blog: Age rating data for Flathub apps | <https://blogs.gnome.org/wjjt/2019/08/08/age-rating-data-for-flathub-apps/> | search-only | L1, L2, L4 | OARS/malcontent mechanism |
| R02-S57 | GNOME wiki: Parental Controls and Metered Data hackfest 2019 | <https://wiki.gnome.org/Hackfests/ParentalAndMetered2019> | search-only | L1, L9, all | Upstreaming event |
| R02-S55 | Linux Mint Forums: Parental control made easy | <https://forums.linuxmint.com/viewtopic.php?t=468768> | search-only | L1, L9, all | Community demand |
| R02-S54 | linuxmint/linuxmint issue #720 "No Parental Controls available" | <https://github.com/linuxmint/linuxmint/issues/720> | search-only | L1, L9, all | Earlier request |
| R02-S30 | Medium: Bypassing the Elementary OS Screen time feature | <https://medium.com/@jamiechamberlain01356/bypassing-the-elementary-os-screen-time-feature-f76869fa9df4> | search-only | L1, L9, all | GRUB → recovery → root → adduser |
| R02-S52 | Repology: malcontent-parental-controls versions | <https://repology.org/project/malcontent-parental-controls/versions> | search-only | L1, L9, all | KDE neon packages 0.10.x |
| R02-S29 | Veyon issue #860 "wayland fedora 36" | <https://github.com/veyon/veyon/issues/860> | search-only | L1, L9, all | No image under Wayland |

## Kids / educational distributions & prior art

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R02-S14 | About the ubermix | <https://www.ubermix.org/about.html> | verified | L1, L9, all | UnionFS three-slice design, Restore Factory Settings, philosophy |
| R02-S16 | Debian Edu wiki | <https://wiki.debian.org/DebianEdu> | verified | L1, L9, all | Bullseye current, Bookworm skipped, Trixie upcoming, LTSP |
| R02-S17 | Debian Junior (Pure Blend) | <https://blends.debian.org/junior/> | verified | L1, L9, all | Ages up to 8 then 7–12; no dated activity |
| R07-S46 | DoudouLinux — "The Activities Menu" | <https://www.doudoulinux.org/web/english/documentation-7/configuration-14/article/the-activities-menu.html> | verified | L5, L6, L10 | · 2026-09-01 · parent ticks activities; single choice auto-launches; hidden "Whole" via typing "tux". |
| R02-S11 | Edubuntu 26.04 LTS Released | <https://discourse.ubuntu.com/t/edubuntu-26-04-lts-released/80831> | verified | L1, L9, all | GNOME 50, age-group profiles, rewritten tools, RPi5, to Apr 2029 |
| R02-S22 | Endless Global: Operating System | <https://www.endlessglobal.com/foundation/access/operating-system> | verified | L1, L9, all | Debian + OSTree, offline, target users |
| R02-S18 | PrimTux | <https://primtux.fr/> | verified | L1, L9, all | PrimTux 9, age sessions, parental control, QwantJunior, SILL |
| R02-S19 | Sugar Labs wiki: Sugar on a Stick | <https://wiki.sugarlabs.org/go/Sugar_on_a_Stick> | verified | L1, L9, all | Says Sugar 0.118 / Fedora 35; last edited 2022-02-16 |
| R07-S45 | Tech Age Kids — "Make and Code your own Laptop with Kano Computer Kit Complete" (2017) | <https://www.techagekids.com/2017/12/kano-computer-kit-complete-hands-on-review.html> | verified | L5, L6, L10 | · 2026-09-01 · Story Mode; 6+; terminal-style setup a 7-year-old coped with; touch/left-hand criticisms. |
| R02-S15 | Ubermix Changelog | <https://wiki.ubermix.org/index.php/Ubermix_Changelog> | verified | L1, L9, all | Newest 6.06, July 2022, Ubuntu 22.04 |
| R02-S13 | ubermix home | <https://www.ubermix.org/> | verified | L1, L9, all | "20 second quick recovery", 60+ apps |
| R02-S12 | Zorin OS Education | <https://zorin.com/os/education/> | verified | L1, L9, all | 18.1 Education; Veyon; Kolibri; no parental controls listed |
| R06-S50 | Debian LLM contribution rules / vote (opensourceforu; resultsense) | <https://www.opensourceforu.com/2026/07/debian-eyes-project-wide-rules-for-llm-contributions/> | search-only | community | 2026 trend toward disclosure |
| R02-S64 | Debian wiki: DebianJunior | <https://wiki.debian.org/DebianJunior> | dead/unverifiable | L1, L9, all | HTTP 404; blends page used instead |
| R02-S60 | Distroscout: Best Linux Distros for Kids (2026) | <https://distroscout.com/usage/kids/> | search-only | L1, L9, all | No new entrants; recycled list |
| R02-S31 | DistroWatch: DoudouLinux | <https://distrowatch.com/doudou> | search-only | L1, L9, all | Discontinued |
| R02-S62 | DistroWatch: Endless OS | <https://distrowatch.com/endlessos> | search-only | L1, L9, all | Release tracking |
| R02-S39 | Endless community: Idea — Add Time Limits to Parental Controls | <https://community.endlessos.com/t/idea-add-time-limits-to-parental-controls/22724> | search-only | L1, L9, all | Real thread id 22724 (blueprint used /12345) |
| R02-S37 | Endless community: Release Endless OS 6.0.0 and 5.1.3 | <https://community.endlessos.com/t/release-endless-os-6-0-0-and-5-1-3/22661> | search-only | L1, L9, all | 2024-05-14, Debian 12 |
| R02-S38 | Endless community: Release Endless OS 6.0.7 | <https://community.endlessos.com/t/release-endless-os-6-0-7/23609> | search-only | L1, L9, all | Nov 2025 point release |
| R02-S56 | endlessm/eos-parental-controls (superseded) | <https://github.com/endlessm/eos-parental-controls> | search-only | L1, L9, all | Predecessor of malcontent |
| R06-S47 | Fedora approves AI-assisted contribution policy (ostechnix; The Register) | <https://ostechnix.com/fedora-ai-contribution-policy/> | search-only | community | Approval reported 2025-10-22/23 |
| R02-S32 | Fedora Sugar on a Stick Spin download | <https://fedora.gitlab.io/websites-apps/fedora-websites/fedora-websites-3.0/spins/soas/download/> | search-only | L1, L9, all | SoaS 43, 2025-10-28 |
| R02-S53 | Kubuntu Forums: Parental Controls re-visited | <https://www.kubuntuforums.net/showthread.php/53433-Parental-Controls-re-visited> | search-only | L1, L9, all | KDE area "neglected" |
| R02-S40 | LVUSD Ubermix Guides | <https://docs.lvusd.org/student-laptops/ubermix/> | search-only | L1, L9, all | District build 7.0lv3 |
| R02-S36 | OMG! Ubuntu: Zorin OS 18.1 released | <https://www.omgubuntu.co.uk/2026/04/zorin-os-18-1-released> | search-only | L1, L9, all | 2026-04-15, Ubuntu 24.04, Lite = Xfce 4.20 |
| R02-S42 | PrimTux forum: CTParental thread | <https://forum.primtux.fr/showthread.php?tid=1545&pid=17588> | search-only | L1, L9, all | e2guardian + privoxy, per-user, HTTPS, schedules |
| R02-S41 | PrimTux wiki: présentation du système | <https://wiki.primtux.fr/doku.php/presentation_du_systeme> | search-only | L1, L9, all | mini/super/maxi/prof sessions |
| R02-S34 | Sugar Labs GSoC 2026 project list (PDF) | <https://lists.sugarlabs.org/archives/list/sugar-devel@lists.sugarlabs.org/message/XZOFRW3ZFCCNHJHUJZK3HR47ZTKCGLTW/attachment/4/gsoc2026.pdf> | search-only | L1, L9, all | GTK4 transition project |
| R02-S63 | Sugar Labs home | <https://www.sugarlabs.org/> | dead/unverifiable | L1, L9, all | Fetch returned no content |
| R02-S35 | Wikipedia: Edubuntu | <https://en.wikipedia.org/wiki/Edubuntu> | search-only | L1, L9, all | Discontinuation and 2023 revival |

## Mainstream parental-control benchmarks (Apple, Google, Microsoft, Nintendo, Amazon)

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R02-S45, R07-S48 | Apple Support: Use Screen Time to manage your child's iPhone or iPad | <https://support.apple.com/en-us/108806> | verified | L1, L9, all, L5, L6, L10 | Downtime, App Limits, Communication Limits, Ask to Buy |
| R04-S13 | Google Workspace: Control YouTube content available to users | <https://knowledge.workspace.google.com/admin/youtube/control-youtube-content-available-to-users?hl=en> | verified | L3 | Redirect target of support.google.com/a/answer/6214622; five CNAME hosts; header alternative |
| R07-S47 | Google — "Get started with Family Link" | <https://support.google.com/families/answer/7101025?hl=en> | verified | L5, L6, L10 | · 2026-09-01. |
| R04-S69 | Google: Chrome & your child's Google Account | <https://support.google.com/families/answer/7087030?hl=en> | verified | L3 | Linux Chrome controls; sign-out caveat; request flow |
| R04-S12 | Google: Keep SafeSearch on for your network (forcesafesearch) | <https://support.google.com/websearch/answer/186669?hl=en> | verified | L3 | CNAME www.google.com → forcesafesearch.google.com; HTTPS preserved (SafeSearch VIP) |
| R04-S67 | Google: Watch YouTube Kids on the web | <https://support.google.com/youtubekids/answer/9406390?hl=en> | verified | L3 | Sign-in optional; content level; web limitations |
| R07-S49 | Nintendo (AU) — "Parental Controls for Nintendo Switch 2 and Nintendo Switch: Overview & FAQ" | <https://www.nintendo.com/au/support/articles/parental-controls-for-nintendo-switch-2-and-nintendo-switch-overview-faq/> | verified | L5, L6, L10 | · 2026-09-01. |
| R02-S50, R07-S51 | About Amazon: Set parental controls with the Parent Dashboard | <https://www.aboutamazon.com/news/devices/set-parental-controls-using-amazon-parent-dashboard> | search-only | L1, L9, all, L5, L6, L10 | Educational goals gate, bedtime, remote dashboard |
| R02-S46 | Apple Support: Respond to a child's Screen Time request | <https://support.apple.com/guide/ipad/respond-to-a-screen-time-request-ipadde65d7c3/ipados> | search-only | L1, L9, all | Exception request flow |
| R04-S80 | Bing help (SafeSearch) | <https://help.bing.microsoft.com/#apex/18/en-US/10003/0> | dead/unverifiable | L3 | Rendered only nav |
| R04-S68 | Google: YouTube Kids system requirements (computers) | <https://support.google.com/youtubekids/answer/9597907> | search-only | L3 | Browser versions |
| R02-S47, R07-S50 | Microsoft Family Safety | <https://www.microsoft.com/en-us/microsoft-365/family-safety> | search-only | L1, L9, all, L5, L6, L10 | Cross-device limits, filters, spending |
| R04-S15 | Microsoft: Blocking explicit content with SafeSearch | <https://support.microsoft.com/en-us/bing/blocking-explicit-content-with-safesearch> | search-only | L3 | strict.bing.com mapping |
| R02-S48 | Microsoft: Family Safety activity reporting | <https://support.microsoft.com/en-us/family-safety/view-device-and-app-use-with-family-safety-activity-reporting> | search-only | L1, L9, all | Weekly reports |
| R02-S49 | Nintendo Support: Parental Controls Features | <https://en-americas-support.nintendo.com/app/topics/detail/p/989/c/271> | search-only | L1, L9, all | Play-time limit, suspend software, bedtime alarm, ratings, PIN |

## Apps, games, learning content & themes

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R05-S21 | Flathub appstream API | <https://flathub.org/api/v2/appstream/> | verified | L7, L8 | (curl, ~70 ids) — Flathub presence/versions; 404 = not found under guessed id. |
| R07-S39 | MIT News — "ScratchJr: Coding for kindergarten" (2014) | <https://news.mit.edu/2014/scratchjr-coding-kindergarten> | verified | L5, L6, L10 | · 2026-09-01 · ages 5-7; pre-readers; MIT/Tufts/PICO. |
| R05-S43 | Best Kiwix ZIMs | <https://ostechnix.com/best-kiwix-zim-files/> | search-only | L7, L8 | Sizes/examples. |
| R05-S63 | Classroom mod | <https://forum.luanti.org/viewtopic.php?t=23715> | search-only | L7, L8 | . |
| R05-S62 | ContentDB education mods | <https://content.luanti.org/packages/?page=1&tag=education&type=mod> | search-only | L7, L8 | . |
| R05-S42 | Kiwix catalog | <https://get.kiwix.org/en/solutions/catalog/> | search-only | L7, L8 | Wikipedia, Khan, TED, PhET, Gutenberg. |
| R05-S44 | Kiwix Hub | <https://hub.kiwix.org/> | search-only | L7, L8 | Download hub. |
| R05-S61 | Luanti for Education | <https://www.luanti.org/en/education/> | search-only | L7, L8 | . |
| R05-S65 | minetest-edutest-ui | <https://github.com/apienk/minetest-edutest-ui> | search-only | L7, L8 | . |
| R05-S64 | modpack4Edu | <https://github.com/minetest4edu/modpack4Edu> | search-only | L7, L8 | . |
| R05-S57 | PICO-8 for schools | <https://www.lexaloffle.com/pico-8.php?page=schools> | search-only | L7, L8 | $3/seat blocks of 10. |

## Pedagogy, child development, AI & policy

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R07-S57 | 5Rights Foundation — "Updated report: Disrupted Childhood: The cost of persuasive design" (2023) | <https://5rightsfoundation.com/resource/updated-report-disrupted-childhood-the-cost-of-persuasive-design/> | verified | L5, L6, L10 | · 2026-09-01. |
| R07-S27 | AAP — "Understanding the New AAP Digital Media Guidelines" (Center of Excellence on Social Media and Youth Mental Health; page updated 20 Jan 2026) | <https://www.aap.org/en/patient-care/media-and-children/center-of-excellence-on-social-media-and-youth-mental-health/understanding-the-new-AAP-digital-media-guidelines/> | verified | L5, L6, L10 | · 2026-09-01 · socio-ecological framing; note: exact publication date of the policy differs between AAP pages (Jan vs Jun 2026) — treat as "2026". |
| R07-S1 | Common Sense Media — "AI Companions Decoded: … Recommends AI Companion Safety Standards" (30 Apr 2025) | <https://www.commonsensemedia.org/press-releases/ai-companions-decoded-common-sense-media-recommends-ai-companion-safety-standards> | verified | L5, L6, L10 | · 2026-09-01 · "No social AI companions for young people under 18"; Character.AI/Nomi/Replika tested. |
| R07-S29 | Common Sense Media — "The 2025 Common Sense Census: Media Use by Kids Zero to Eight" (26 Feb 2025) | <https://www.commonsensemedia.org/research/the-2025-common-sense-census-media-use-by-kids-zero-to-eight> | verified | L5, L6, L10 | · 2026-09-01. |
| R07-S12 | European Commission — "Commission publishes guidelines on the protection of minors" (14 Jul 2025) | <https://digital-strategy.ec.europa.eu/en/library/commission-publishes-guidelines-protection-minors> | verified | L5, L6, L10 | · 2026-09-01 · age assurance, private defaults, streaks/autoplay/push off, parental controls, AV app prototype. |
| R07-S40 | Raspberry Pi Foundation — "2025 highlights from the Raspberry Pi Computing Education Research Centre" | <https://www.raspberrypi.org/blog/2025-highlights-from-the-raspberry-pi-computing-education-research-centre/> | verified | L5, L6, L10 | · 2026-09-01 · EPICS; PRIMM Debug; younger learners' trial-and-error debugging. |
| R07-S28 | AAP — "Media and Young Minds", Pediatrics 138(5) 2016 | <https://publications.aap.org/pediatrics/article/138/5/e20162591/60503/Media-and-Young-Minds> | search-only | L5, L6, L10 | · 2026-09-01 · ≤1 h/day for 2-5; video-chat only <18 mo; revised version DOI 10.1542/peds.2025-075320 noted in search. |
| R07-S58 | ACM — "Growing Up With Dark Patterns: How Children Perceive Malicious…" (2024) | <https://dl.acm.org/doi/fullHtml/10.1145/3679318.3685358> | search-only | L5, L6, L10 | (fetch 403) · 2026-09-01 · ~half spot trick questions/emotional manipulation; confirmshaming less. |
| R07-S30 | Common Sense Media press release — "Digital Childhood Starts at Age Two…" | <https://www.commonsensemedia.org/press-releases/digital-childhood-starts-at-age-two-landmark-study-shows-evolution-of-young-childrens-media-use> | search-only | L5, L6, L10 | · 2026-09-01 · 51% own device by 8; 1 in 5 use devices for bedtime/meals/emotions; ~⅓ used AI for learning. |
| R07-S65 | Common Sense Media — "How We Rate and Review" (+ by-age pages) | <https://www.commonsensemedia.org/about-us/our-mission/about-our-ratings> | search-only | L5, L6, L10 | · 2026-09-01. |
| R07-S3 | Common Sense Media — AI Risk Assessment: AI Toys (14 Jan 2026) + press release | <https://www.commonsensemedia.org/sites/default/files/ai-ratings/csm-ai-risk-assessment-ai-toys-01142026.pdf> | search-only | L5, L6, L10 | ; https://www.commonsensemedia.org/press-releases/common-sense-media-warns-against-ai-toy-companions-after-research-reveals-safety-risks —  · 2026-09-01 · "Unacceptable"; avoid ≤5, caution 6-12; 27% inappropriate outputs. |
| R07-S2 | Common Sense Media — AI Risk Assessment: Social AI Companions (PDF) | <https://www.commonsensemedia.org/sites/default/files/pug/csm-ai-risk-assessment-social-ai-companions_final.pdf> | search-only | L5, L6, L10 | · 2026-09-01 · full report behind S1. |
| R07-S4 | Common Sense Media — Meta AI risk assessment (15 Aug 2025) | <https://www.commonsensemedia.org/sites/default/files/featured-content/files/csm-ai-risk-assessment-metaai-08152025.pdf> | search-only | L5, L6, L10 | · 2026-09-01. |
| R07-S67 | Druin, A. — "Cooperative inquiry: developing new technologies for children with children", CHI '99; HCIL KidsTeam | <https://dl.acm.org/doi/10.1145/302979.303166> | search-only | L5, L6, L10 | ; https://hcil.umd.edu/children-as-design-partners/ —  · 2026-09-01 · design partners ~7-11. |
| R07-S16 | eSafety Commissioner (AU) — "Social media age restrictions" | <https://www.esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions> | search-only | L5, L6, L10 | (fetch timed out) · 2026-09-01 · from 10 Dec 2025; 4.7 M accounts removed. |
| R07-S17 | eSafety — "Social media 'ban' or delay FAQs" | <https://www.esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions/faqs> | search-only | L5, L6, L10 | (timed out) · 2026-09-01 · no penalties for under-16s or parents. |
| R07-S5 | FTC — "FTC Launches Inquiry into AI Chatbots Acting as Companions" (11 Sep 2025) | <https://www.ftc.gov/news-events/news/press-releases/2025/09/ftc-launches-inquiry-ai-chatbots-acting-companions> | search-only | L5, L6, L10 | (fetch 403) · 2026-09-01 · seven companies named. |
| R07-S54 | ICO — "Introduction to the Children's code" / Age appropriate design code | <https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/introduction-to-the-childrens-code/> | search-only | L5, L6, L10 | (fetch 403) · 2026-09-01 · 15 standards; in force 2 Sep 2021; bands 0-5/6-9/10-12/13-15/16-17. |
| R07-S66 | NAEYC/Fred Rogers Center — "Technology and Interactive Media as Tools in Early Childhood Programs Serving Children from Birth through Age 8" (2012) + Key Messages | <https://www.naeyc.org/sites/default/files/globally-shared/downloads/PDFs/resources/position-statements/ps_technology.pdf> | search-only | L5, L6, L10 | ; https://www.naeyc.org/files/naeyc/file/positions/KeyMessages_Technology.pdf —  (fetch 403) · 2026-09-01. |
| R07-S41 | Raspberry Pi Foundation — "Teaching programming in schools: a review of approaches and strategies" (2021, PDF) | <https://www.raspberrypi.org/app/uploads/2021/11/Teaching-programming-in-schools-pedagogy-review-Raspberry-Pi-Foundation.pdf> | search-only | L5, L6, L10 | · 2026-09-01. |
| R07-S18 | Reed Smith — "UK Online Safety Act: Ofcom updates children's codes and guidance"; Ofcom statement vol. 1 (24 Apr 2025) | <https://www.reedsmith.com/articles/uk-online-safety-act-ofcom-updates-childrens-codes-and-guidance/> | search-only | L5, L6, L10 | ; https://www.ofcom.org.uk/siteassets/resources/documents/consultations/category-1-10-weeks/statement-protecting-children-from-harms-online/main-document/volume-1-overview-scope-and-regulatory-approach.pdf?v=396663 —  · 2026-09-01 · risk assessments by 24 Jul 2025; duties from 25 Jul 2025. |
| R07-S56 | UNICEF Innocenti — "Policy guidance on AI for children 2.0" (2021) and "Guidance on AI and Children (v3): Checklist" (2025) | <https://www.unicef.org/innocenti/media/1341/file/UNICEF-Global-Insight-policy-guidance-AI-children-2.0-2021.pdf> | search-only | L5, L6, L10 | ; https://www.unicef.org/innocenti/media/11996/file/UNICEF-Innocenti-Guidance-on-AI-and-Children-3-Checklist-2025.pdf —  (fetch 403) · 2026-09-01 · nine requirements (2.0); ten in v3. |

## OSS governance, process & repo practice

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R06-S27 | choosealicense: CC-BY-4.0 | <https://choosealicense.com/licenses/cc-by-4.0/> | verified | community | "Not recommended for software"; SPDX CC-BY-4.0 |
| R06-S24 | Contributor Covenant 3.0 | <https://www.contributor-covenant.org/version/3/0/code_of_conduct/> | verified | community | Sections; enforcement ladder; CC BY-SA 4.0 |
| R06-S25 | Contributor Covenant homepage | <https://www.contributor-covenant.org/> | verified | community | Nav labels 3.0 "Latest Version"; 40+ translations |
| R06-S26 | Developer Certificate of Origin 1.1 | <https://developercertificate.org/> | verified | community | Four certifications; sign-off record kept indefinitely |
| R06-S15 | GitHub Docs: about code owners | <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners> | verified | community | Locations; last match wins; 3 MB; any-owner approval |
| R06-S19 | GitHub Docs: about discussions | <https://docs.github.com/en/discussions/collaborating-with-your-community-using-discussions/about-discussions> | verified | community | Open-ended; convert issues; pin/lock/labels |
| R06-S16 | GitHub Docs: about rulesets | <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets> | verified | community | Stackable; Active/Disabled; plan wording ambiguous for Free public repos |
| R06-S18 | GitHub Docs: adding a security policy | <https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository> | verified | community | Supported versions + how to report |
| R06-S21 | GitHub Docs: community profiles | <https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories> | verified | community | Checklist items; Insights → Community Standards |
| R06-S17 | GitHub Docs: creating rulesets for a repository | <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository> | verified | community | Evaluate status for metadata rules; org rulesets Team/Enterprise |
| R06-S10 | GitHub Docs: default community health file | <https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file> | verified | community | Supported files; precedence; org .github; no default LICENSE |
| R06-S12 | GitHub Docs: discussion category forms | <https://docs.github.com/en/discussions/managing-discussions-for-your-community/creating-discussion-category-forms> | verified | community | `.github/DISCUSSION_TEMPLATE/<slug>.yml`; no polls |
| R06-S20 | GitHub Docs: managing categories for discussions | <https://docs.github.com/en/discussions/managing-discussions-for-your-community/managing-categories-for-discussions> | verified | community | Six defaults; formats; 25-category cap |
| R06-S13 | GitHub Docs: private vulnerability reporting | <https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-a-repository> | verified | community | Enable path; reporter flow; notifications |
| R06-S11 | GitHub Docs: syntax for issue forms | <https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms> | verified | community | Keys, body types, attributes, config.yml |
| R06-S14 | GitHub Docs: understanding fields (Projects) | <https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields> | verified | community | Text/number/date/single-select/iteration; issue type; sub-issue progress |
| R06-S7 | home-assistant/architecture adr/ | <https://github.com/home-assistant/architecture/tree/master/adr> | verified | community | 0001–0022 sequential ADRs |
| R06-S6 | home-assistant/architecture README | <https://github.com/home-assistant/architecture/blob/master/README.md> | verified | community | Discussions → ADR; stay on topic |
| R06-S3 | kubernetes/enhancements keps/README | <https://github.com/kubernetes/enhancements/blob/master/keps/README.md> | verified | community | kep.yaml statuses; number = tracking issue |
| R06-S22 | MADR homepage | <https://adr.github.io/madr/> | verified | community | MADR 4.0.0 (2024-09-17); NNNN naming; MIT/CC0 |
| R06-S28 | opensource.guide: Leadership and Governance | <https://opensource.guide/leadership-and-governance/> | verified | community | BDFL/meritocracy/liberal; write GOVERNANCE.md early |
| R06-S32 | QEMU: Code provenance (AI-generated content) | <https://www.qemu.org/docs/master/devel/code-provenance.html> | verified | community | Declines AI-generated contributions; DCO rationale |
| R06-S2 | reactjs/rfcs README | <https://github.com/reactjs/rfcs/blob/main/README.md> | verified | community | 0000 placeholder; 3-day FCP; list of non-RFC changes |
| R06-S1 | rust-lang/rfcs README | <https://github.com/rust-lang/rfcs/blob/master/README.md> | verified | community | 10-day FCP; PR-number naming; sub-team sign-off; "postponed" |
| R06-S4 | TC39 Process Document | <https://tc39.es/process-document/> | verified | community | Stages 0–4 incl. 2.7; champions; consensus |
| R06-S8 | withastro/roadmap README | <https://github.com/withastro/roadmap/blob/main/README.md> | verified | community | 4 stages; Discussions→Issues→PRs; TSC vote |
| R06-S45 | all-contributors bot usage | <https://allcontributors.org/docs/en/bot/usage> | search-only | community | `@all-contributors please add` |
| R06-S46 | all-contributors specification | <https://allcontributors.org/specification/> | search-only | community | Emoji key |
| R06-S67 | Contributor Covenant 3.0 Markdown | <https://www.contributor-covenant.org/version/3/0/code_of_conduct/code_of_conduct.md> | search-only | community | Linked from S24; not fetched |
| R06-S60 | DavidAnson/markdownlint-cli2 | <https://github.com/DavidAnson/markdownlint-cli2> | search-only | community | `.markdownlint-cli2.jsonc` recommended |
| R06-S63 | GitHub Community Code of Conduct | <https://docs.github.com/en/site-policy/github-terms/github-community-code-of-conduct> | search-only | community | Platform-level baseline |
| R06-S38 | GitHub Docs: about fields (Projects) | <https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-fields> | dead/unverifiable | community | HTTP 404; superseded by S14 |
| R06-S49 | Linuxiac: QEMU may relax AI ban | <https://linuxiac.com/qemu-may-relax-its-ban-on-ai-generated-contributions/> | search-only | community | Disclosure-based relaxation under discussion |
| R06-S59 | lycheeverse/lychee-action README; .lycheeignore | <https://github.com/lycheeverse/lychee-action/blob/master/README.md> | search-only | community | Regex per line; workingDirectory |

## Other / secondary coverage

| Key(s) | Title | URL | Status | Layers | Note |
|---|---|---|---|---|---|
| R04-S63 | AdGuard Home openapi.yaml | <https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/openapi/openapi.yaml> | verified | L3 | /control/protection duration; clients; safesearch; blocked_services schedule; querylog |
| R07-S14 | Alston & Bird — "Challenge to Utah's App Store Accountability Act Voluntarily Dismissed…" | <https://www.alstonprivacy.com/challenge-to-utahs-app-store-accountability-act-voluntarily-dismissed-following-statutory-amendments/> | verified | L5, L6, L10 | · 2026-09-01 · HB 498; effective 6 May 2027; dismissal 21 Apr 2026. |
| R03-S57 | Bash Reference Manual — The Restricted Shell (bashref.texi) | <https://git.savannah.gnu.org/cgit/bash.git/plain/doc/bashref.texi> | verified | L1, L2, L4 | Restriction list and script caveat |
| R04-S47 | Chromium policy_definitions (YAML source) | <https://github.com/chromium/chromium/tree/main/components/policy/resources/templates/policy_definitions> | verified | L3 | DnsOverHttpsMode, ForceYouTubeRestrict, ForceGoogleSafeSearch, URLBlocklist/Allowlist, Incognito, DevTools, ExtensionInstall*, DownloadRestrictions, BrowserSignin, SafeBrowsingProtectionLevel |
| R04-S9 | CleanBrowsing filters | <https://cleanbrowsing.org/filters/> | verified | L3 | Family/Adult/Security IPs, DoH/DoT; SafeSearch + YT restricted; VPN/proxy blocking |
| R07-S9 | Cooley — "NetChoice v. Bonta: Ninth Circuit Narrows Injunction…" (30 Mar 2026) | <https://www.cooley.com/news/insight/2026/2026-03-30-netchoice-v-bonta-ninth-circuit-narrows-injunction-against-californias-ageappropriate-design-code-act> | verified | L5, L6, L10 | · 2026-09-01 · 12 Mar 2026 decision; which provisions enjoined/cleared. |
| R06-S29 | Diátaxis | <https://diataxis.fr/> | verified | community | Four doc types |
| R07-S6 | DLA Piper — "AI companion bots: Top points from recent FTC and government actions" (Sep 2025) | <https://www.dlapiper.com/en-us/insights/publications/2025/09/ftc-ai-chatbots> | verified | L5, L6, L10 | · 2026-09-01 · lists 6(b) topics, SB 243 summary, 44-AG letter. |
| R04-S14 | DuckDuckGo Safe Search help | <https://duckduckgo.com/duckduckgo-help-pages/features/safe-search/> | verified | L3 | safe.duckduckgo.com CNAME; kp param |
| R07-S55 | euCONSENT — "Digital Age of Consent under the GDPR" | <https://euconsent.eu/digital-age-of-consent-under-the-gdpr/> | verified | L5, L6, L10 | · 2026-09-01 · per-state 13-16 table. |
| R07-S31 | Fitzpatrick, Cristini, Bernard & Garon-Carrier (2023) — "Meeting preschool screen time recommendations: which parental strategies matter?", Frontiers in Psychology | <https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1287396/full> | verified | L5, L6, L10 | · 2026-09-01 · restrictive OR 4.07; co-viewing OR 0.20. |
| R05-S13 | Free Software Mascots | <https://jxself.org/mascots.shtml> | verified | L7, L8 | Lists GNU, Freedo, Wilber, Konqi; no license detail. |
| R07-S25 | GitHub — peteonrails/voxtype | <https://github.com/peteonrails/voxtype> | verified | L5, L6, L10 | · 2026-09-01 · Rust, MIT, local-by-default, whisper.cpp + 8 other engines, Hyprland/Niri/Sway/River/GNOME/KDE, `omarchy-plugin` dir, v0.7.0 referenced. |
| R07-S26 | HealthyChildren.org (AAP) — "Helping Kids Thrive in a Digital World: AAP Policy Explained" | <https://www.healthychildren.org/English/family-life/Media/Pages/helping-kids-thrive-in-a-digital-world-AAP-policy-explained.aspx> | verified | L5, L6, L10 | · 2026-09-01 · policy "Digital Ecosystems, Children, and Adolescents"; page dated 3 Jun 2026; no restated hour cap; hour-before-bed; co-use; delay personal devices. |
| R07-S33 | Hourcade, J. P. — *Child-Computer Interaction*, 1st ed. (2015), PDF | <https://jphourcade.com/book/child-computer-interaction-first-edition.pdf> | verified | L5, L6, L10 | (redirect from homepage.divms.uiowa.edu) —  (PDF downloaded, text extracted locally) · 2026-09-01 · Piaget stages pp. 10-11; Wyeth & Purchase; Appendix A motor skills pp. 130-137 (targets 64/32/16 px; drag vs click-move-click; typing/spelling). |
| R07-S7 | Hunton — "COPPA Rule Amendment Compliance Deadline Approaches" | <https://www.hunton.com/privacy-and-cybersecurity-law-blog/coppa-rule-amendment-compliance-deadline-approaches> | verified | L5, L6, L10 | · 2026-09-01 · compliance 22 Apr 2026; three key changes. |
| R03-S54 | Hyprland wiki (source: hyprwm/hyprland-wiki) — Permissions, Binds, Flags, Submaps, Dispatchers, Window rules, Config options, Lua utilities, Global binds | <https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/> | verified | L1, L2, L4 | Lua API; permission types; option defaults |
| R05-S17 | Konqi by Tyson Tan | <https://commons.wikimedia.org/wiki/File:KDE_Mascot_Konqi_by_Tyson_Tan.png> | verified | L7, L8 | CC BY-SA 4.0 / LGPL 2.1+. |
| R03-S33 | Limine CONFIG.md (v12.x) | <https://github.com/Limine-Bootloader/Limine/blob/v12.x/CONFIG.md> | verified | L1, L2, L4 | editor_enabled, hash_mismatch_panic; no password option |
| R06-S35 | Linux kernel: AI Coding Assistants | <https://docs.kernel.org/process/coding-assistants.html> | verified | community | `Assisted-by: LLM [TOOL]`; AI must not sign off DCO |
| R06-S36 | LWN: Fedora floats AI-assisted contributions policy | <https://lwn.net/Articles/1039623/> | verified | community | Three principles; opt-in AI features; draft status as of Oct 2025 |
| R06-S23 | MADR template (develop) | <https://github.com/adr/madr/blob/develop/template/adr-template.md> | verified | community | Full template text captured |
| R04-S28 | NetworkManager nm-settings-nmcli | <https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html> | verified | L3 | ipv4.dns, ignore-auto-dns, dns-priority, connection.permissions |
| R06-S9 | NixOS/rfcs README | <https://github.com/NixOS/rfcs/blob/master/README.md> | verified | community | Shepherd team; SC; FCP motion to end unproductive debate |
| R04-S75 | NSFW Filter extension | <https://github.com/nsfw-filter/nsfw-filter> | verified | L3 | Local TF.js; ViT-384; v3.0.0; Chrome |
| R06-S5 | PEP 1 | <https://peps.python.org/pep-0001/> | verified | community | Vet ideas publicly first; sponsors; statuses; required sections |
| R04-S71 | Pinchflat README | <https://github.com/kieraneglin/pinchflat> | verified | L3 | yt-dlp; single container; Plex/Jellyfin/Kodi; stability caveat |
| R07-S13 | Privacy World (Squire Patton Boggs) — "Federal Judge Enjoins Enforcement of Texas App Store Age Verification Law" (Dec 2025) | <https://www.privacyworld.blog/2025/12/federal-judge-enjoins-enforcement-of-texas-app-store-age-verification-law/> | verified | L5, L6, L10 | · 2026-09-01 · injunction 23 Dec 2025; SB 2420 effective 1 Jan 2026. |
| R06-S34 | REUSE tutorial | <https://reuse.software/tutorial/> | verified | community | SPDX headers; LICENSES/; reuse lint |
| R06-S33 | Rust Foundation Trademark Policy | <https://rustfoundation.org/policy/rust-trademark-policy/> | verified | community | Repo names OK for compatibility; no appearance of official status |
| R05-S14 | Sober site | <https://sober.vinegarhq.org/> | verified | L7, L8 | flatpak id org.vinegarhq.Sober; unofficial, closed-source, may be discontinued. |
| R07-S42 | thejavaguy.org — "My 7½ year old learned 4 bash (Linux) commands in one hour" | <https://thejavaguy.org/posts/008-my-kid-learned-bash-in-one-hour/> | verified | L5, L6, L10 | · 2026-09-01 · echo/ls/touch/rm; up-arrow; tab completion. |
| R05-S18 | Tux.svg | <https://commons.wikimedia.org/wiki/File:Tux.svg> | verified | L7, L8 | Ewing permission with attribution; LeSage CC0. |
| R07-S35 | Typing.com — "At What Age Are Kids Developmentally Ready for Typing?" | <https://www.typing.com/blog/age-kids-developmentally-reading-typing/> | verified | L5, L6, L10 | · 2026-09-01 · familiarity in K; formal grades 2-3; wpm benchmarks (vendor blog). |
| R05-S5 | vinegarhq/sober | <https://github.com/vinegarhq/sober> | verified | L7, L8 | Issue-tracker repo; "Not affiliated with Roblox"; 1.1k stars. |
| R06-S37 | W3C WAI: Developing an Accessibility Statement | <https://www.w3.org/WAI/planning/statements/> | verified | community | Minimum contents; plain-language guidance |
| R02-S21 | Wikipedia: DoudouLinux | <https://en.wikipedia.org/wiki/DoudouLinux> | verified | L1, L9, all | Debian/LXDE, DansGuardian, 2.1 Dec 2013, inactive |
| R02-S20 | Wikipedia: Sugar (desktop environment) | <https://en.wikipedia.org/wiki/Sugar_(desktop_environment)> | verified | L1, L9, all | 0.121 2024-02-06; Journal; Home/Group/Neighborhood; Sugarizer; SFC |
| R04-S70 | YouTube Terms of Service | <https://www.youtube.com/t/terms> | verified | L3 | No download/automated access without permission |
| R05-S33 | 3 command line games | <https://opensource.com/article/19/10/learn-bash-command-line-games> | search-only | L7, L8 | Bashcrawl description. |
| R05-S35 | 5 games for learning Linux | <https://devopschops.com/blog/games-for-learning-linux/> | search-only | L7, L8 | Bashcrawl → Command Challenge → Bandit → CLI Murders path. |
| R05-S68 | Abandonware | <https://en.wikipedia.org/wiki/Abandonware> | search-only | L7, L8 | No legal abandonware status. |
| R06-S48 | All Things Open: "Assisted-by" trailer standard | <https://allthingsopen.org/articles/open-source-ai-contributions-assisted-by-git-trailer-standard> | search-only | community | Survey of project policies |
| R06-S64 | assisted-by.dev | <https://assisted-by.dev/> | search-only | community | Tracks kernel Assisted-by adoption |
| R05-S59 | Best dyslexia fonts 2026 | <https://focusflowapp.in/blog/best-dyslexia-fonts-for-web> | search-only | L7, L8 | OFL for OpenDyslexic/Lexend; Atkinson under Braille Institute license. |
| R07-S34 | Betts et al. (2006) — "The Development of Sustained Attention in Children: The Effect of Age and Task Load" (ResearchGate/Academia listings) | <https://www.researchgate.net/publication/6949000_The_Development_of_Sustained_Attention_in_Children_The_Effect_of_Age_and_Task_Load> | search-only | L5, L6, L10 | · 2026-09-01 · rapid 5-6→8-9, plateau to 11-12. |
| R07-S20 | Bloomberg Law — "Character.AI, Google Agree to Settle Teen Chatbot Harm Lawsuits" | <https://news.bloomberglaw.com/litigation/character-ai-google-agree-to-settle-teen-chatbot-harm-lawsuits> | search-only | L5, L6, L10 | · 2026-09-01 · five families. |
| R07-S52 | Boomerang — "Family Link: What Parents Need to Know in 2026"; Mobicip — "Bypass Google Family Link" | <https://useboomerang.com/article/family-link/> | search-only | L5, L6, L10 | ; https://www.mobicip.com/blog/how-do-kids-bypass-google-family-link —  · 2026-09-01 · competitor blogs; bypass via settings/safe mode/factory reset; ends at 13. |
| R04-S51 | Brave: Group Policy | <https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy> | search-only | L3 | /etc/brave/policies/managed; Chromium policies supported |
| R03-S66 | CachyOS forum: Prevent Ctrl+Alt+F1 … disable VT switch | <https://discuss.cachyos.org/t/prevent-ctrl-alt-f1-from-freezing-screen-disable-vt-switch-completely/10173> | search-only | L1, L2, L4 | Community precedent |
| R07-S24 | California SB 243 (leginfo); FPF "Understanding the New Wave of Chatbot Legislation"; MoFo "New York and California Enact Landmark AI Companion Laws" | <https://leginfo.legislature.ca.gov/faces/billNavClient.xhtml?bill_id=202520260SB243> | search-only | L5, L6, L10 | ; https://fpf.org/blog/understanding-the-new-wave-of-chatbot-legislation-california-sb-243-and-beyond/ ; https://www.mofo.com/resources/insights/251120-new-york-and-california-enact-landmark-ai —  · 2026-09-01 · signed 13 Oct 2025; effective 1 Jan 2026. |
| R05-S40 | Category:Free software mascots | <https://commons.wikimedia.org/wiki/Category:Free_software_mascots> | search-only | L7, L8 | Source for further mascot license checks. |
| R04-S16 | CleanBrowsing: How to enforce SafeSearch with DNS filtering | <https://cleanbrowsing.org/articles/how-to-enforce-safesearch-with-dns-filtering> | search-only | L3 | Bing/edgeservices mapping |
| R07-S23 | CNBC — "OpenAI to launch ChatGPT for teens with parental controls" (16 Sep 2025); TechCrunch (19 Dec 2025) | <https://www.cnbc.com/2025/09/16/openai-chatgpt-teens-parent.html> | search-only | L5, L6, L10 | ; https://techcrunch.com/2025/12/19/openai-adds-new-teen-safety-rules-to-models-as-lawmakers-weigh-ai-standards-for-minors/ —  · 2026-09-01. |
| R07-S22 | CNN — "After a wave of lawsuits, Character.AI will no longer let teens…" (29 Oct 2025); TechCrunch same day; CNBC (24 Nov 2025) | <https://www.cnn.com/2025/10/29/tech/character-ai-teens-under-18-app-changes> | search-only | L5, L6, L10 | ; https://techcrunch.com/2025/10/29/character-ai-is-killing-the-chatbot-experience-for-minors/ ; https://www.cnbc.com/2025/11/24/characterai-to-ban-teens-from-open-ended-chats-human-interaction-is-crucial-psychotherapist-says.html —  · 2026-09-01 · open-ended chat ended for <18 from 24-25 Nov 2025. |
| R07-S19 | CNN — "Character.AI and Google agree to settle lawsuits over teen mental health" (7 Jan 2026) | <https://www.cnn.com/2026/01/07/business/character-ai-google-settle-teen-suicide-lawsuit> | search-only | L5, L6, L10 | (fetch 451) · 2026-09-01. |
| R07-S32 | Computers & Education (2016) — "Active and restrictive parental mediation over time: Effects on…" | <https://www.sciencedirect.com/science/article/abs/pii/S0360131516300756> | search-only | L5, L6, L10 | · 2026-09-01 · active mediation reduces risks; over-restriction can backfire. |
| R06-S42 | dcoapp/app README | <https://github.com/dcoapp/app/blob/main/README.md> | search-only | community | DCO GitHub App; `.github/dco.yml` |
| R01-S53 | DHH on X: "Omarchy Quattro is out!!" | <https://x.com/dhh/status/2088304854603047019> | search-only | L11, L5 | Launch announcement |
| R01-S52, R03-S68 | DHH on X: "The road map for Omarchy 4.1 is already several man years..." | <https://x.com/dhh/status/2089630095010889953> | search-only | L1, L2, L4, L11, L5 | 4.1 roadmap; multi-user claim relies on #532 comment |
| R06-S52 | Discord Terms of Service | <https://discord.com/terms> | search-only | community | ≥13 and local minimum age |
| R06-S39 | EndBug/label-sync | <https://github.com/EndBug/label-sync> | search-only | community | Action; YAML/JSON config; global+local sets |
| R05-S69 | ExOv5 on Internet Archive | <https://archive.org/details/exov5_2> | search-only | L7, L8 | Gray-area distribution; do not bundle. |
| R07-S59 | Fairplay — petition to FTC on dark patterns and children (2021) | <https://fairplayforkids.org/wp-content/uploads/2021/05/darkpatterns.pdf> | search-only | L5, L6, L10 | · 2026-09-01. |
| R06-S41 | Financial-Times/github-label-sync | <https://github.com/Financial-Times/github-label-sync> | search-only | community | Underlying CLI |
| R07-S15 | Future of Privacy Forum — TX/UT/LA App Store Accountability Act comparison chart (Jun 2026) | <https://fpf.org/wp-content/uploads/2026/06/FPF-Legislation-TX-UT-LA-App-Store-Accountability-Act-Comparison-Chart.pdf> | search-only | L5, L6, L10 | · 2026-09-01. |
| R05-S39 | GIMP linking page | <https://www.gimp.org/about/linking.html> | search-only | L7, L8 | Wilber SVG CC BY-SA 4.0 (Aryeom Han). |
| R06-S44 | GitHub Changelog: require sign-off on web commits | <https://github.blog/changelog/2022-06-07-admins-can-require-sign-off-on-web-based-commits/> | search-only | community | Repo setting |
| R06-S51 | GitHub Community discussion: 13-year minimum age | <https://github.com/orgs/community/discussions/44742> | search-only | community | GitHub ToS: users must be ≥13 |
| R07-S44 | Hacker News — "Bashcrawl: Learn Linux commands by playing a simple text adventure" | <https://news.ycombinator.com/item?id=28819387> | search-only | L5, L6, L10 | · 2026-09-01 · commenter learned on Kano OS at 12. |
| R07-S43 | Hacker News — "How many Linux commands can a 7 year old learn?" | <https://news.ycombinator.com/item?id=31285143> | search-only | L5, L6, L10 | · 2026-09-01. |
| R05-S60 | Highly legible fonts | <https://chris.bur.gs/highly-legible-fonts/> | search-only | L7, L8 | . |
| R01-S49, R03-S63 | HN comment on Omarchy login (no display manager, LUKS as password) | <https://news.ycombinator.com/item?id=45247299> | search-only | L1, L2, L4, L11, L5 | v3-era description of "seamless login" |
| R07-S69 | Hunton — "European Commission Issues Guidelines on the Protection of Minors" | <https://www.hunton.com/privacy-and-information-security-law/european-commission-issues-guidelines-on-the-protection-of-minors> | search-only | L5, L6, L10 | · 2026-09-01. |
| R07-S38 | Int. J. Child-Computer Interaction — "ScratchJr design in practice: Low floor, high ceiling" | <https://www.sciencedirect.com/science/article/abs/pii/S2212868923000387> | search-only | L5, L6, L10 | · 2026-09-01. |
| R05-S51 | Jellyfin "max parental rating does not filter NR" | <https://forum.jellyfin.org/t-solved-maximum-allowed-parental-rating-does-not-filter-nr-content> | search-only | L7, L8 | Block-unrated fixed in 10.11.0. |
| R05-S53 | Jellyfin issue #13338 | <https://github.com/jellyfin/jellyfin/issues/13338> | search-only | L7, L8 | Custom rating vs parental rating. |
| R05-S52 | Jellyfin multi-user & parental controls guide 2026 | <https://jellywatch.app/blog/jellyfin-multi-user-parental-controls-guide-2026> | search-only | L7, L8 | Tag blocking. |
| R05-S54 | jfo8000/ScratchJr-Desktop | <https://github.com/jfo8000/ScratchJr-Desktop/> | search-only | L7, L8 | Community Mac/Win port. |
| R07-S8 | Latham & Watkins — "FTC Publishes Updates to COPPA Rule" | <https://www.lw.com/en/insights/ftc-publishes-updates-to-coppa-rule> | search-only | L5, L6, L10 | · 2026-09-01 · Fed. Reg. 22 Apr 2025; effective 23 Jun 2025. |
| R07-S36 | Learning.com — "When Should Children Start Learning Keyboarding" | <https://www.learning.com/blog/when-should-children-start-learning-keyboarding/> | search-only | L5, L6, L10 | · 2026-09-01 · palms rest on keyboard ~6-7; grade-3 finger placement (vendor blog). |
| R07-S71 | LearnTechLib — "A Usability Study with Children: Testing OLPC (One Laptop per Child)" | <https://www.learntechlib.org/noaccess/30696/> | search-only | L5, L6, L10 | · 2026-09-01 · icon/navigation effectiveness on XO. |
| R07-S70 | LWN — "DoudouLinux: You know, for kids"; DoudouLinux Quick start | <https://lwn.net/Articles/450503/> | search-only | L5, L6, L10 | ; https://www.doudoulinux.org/web/english/documentation-7/article/quick-start.html —  · 2026-09-01 · ages 2-7; activity order and per-app ages. |
| R05-S29 | mcpelauncher releases | <https://github.com/minecraft-linux/mcpelauncher-manifest/releases> | search-only | L7, L8 | v1.7.6 2026-06-25. |
| R05-S28 | mcpelauncher-manifest issue #1707 | <https://github.com/minecraft-linux/mcpelauncher-manifest/issues/1707> | search-only | L7, L8 | "cave full of tnt" DRM warning (2026-02-22); latest Play version unsupported. |
| R04-S62 | Netgate forum: Blocking DNS over HTTPS ("shotgun") | <https://forum.netgate.com/topic/157500/blocking-dns-over-https-seems-the-only-way-is-to-fire-a-shotgun-at-it> | search-only | L3 | Anycast/shared-IP problem |
| R07-S11 | Ninth Circuit opinion, NetChoice v. Bonta (12 Mar 2026, PDF) | <https://netchoice.org/wp-content/uploads/2026/03/NetChoiice-v-Bonta-Ruling-Ninth-Circuit-March-12-2026.pdf> | search-only | L5, L6, L10 | · 2026-09-01. |
| R05-S34 | notklaatu/bashcrawl | <https://github.com/notklaatu/bashcrawl> | search-only | L7, L8 | GitHub mirror. |
| R04-S76 | nsfwjs | <https://github.com/infinitered/nsfwjs> | search-only | L3 | Client-side classifier |
| R05-S56 | Offline Hedy wiki | <https://github.com/hedyorg/hedy/wiki/Offline-Hedy> | search-only | L7, L8 | Offline zip is Windows. |
| R06-S43 | open-gitops discussion: DCO app shutdown warning | <https://github.com/open-gitops/project/discussions/27> | search-only | community | Reason to keep a fallback Action |
| R07-S72 | OpenAI — "Building more helpful ChatGPT experiences for everyone" (Sep 2025) | <https://openai.com/index/building-more-helpful-chatgpt-experiences-for-everyone/> | search-only | L5, L6, L10 | · 2026-09-01 · age prediction; under-18 default. |
| R06-S66 | OpenSSF wg-vulnerability-disclosures: AI-slop best practices issue | <https://github.com/ossf/wg-vulnerability-disclosures/issues/178> | search-only | community | AI-generated report handling |
| R03-S61 | Phoronix: Hyprland 0.49 Released | <https://www.phoronix.com/news/Hyprland-0.49-Released> | search-only | L1, L2, L4 | Version attribution |
| R05-S58 | PICO-8 Education Edition for Web | <https://www.lexaloffle.com/bbs/?tid=47278> | search-only | L7, L8 | Free browser edition; $15 desktop. |
| R05-S30 | Playing Minecraft on Linux | <https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux> | search-only | L7, L8 | Bedrock requires Google Play purchase. |
| R06-S40 | r7kamura/github-label-sync-action | <https://github.com/r7kamura/github-label-sync-action> | search-only | community | `.github/labels.yml`; `allow_added_labels` |
| R07-S37 | Resnick, M. — "Designing for Wide Walls" (Medium) | <https://medium.com/@mres/designing-for-wide-walls-323bdb4e7277> | search-only | L5, L6, L10 | (fetch 403) · 2026-09-01 · Papert low floor/high ceiling + wide walls. |
| R05-S26 | Roblox on Linux 2026 guide | <https://caniplayonlinux.com/guides/roblox-on-linux/> | search-only | L7, L8 | Sober wraps Android build; x86 only; no Studio. |
| R06-S65 | Rocky Linux AI-assisted contribution policy | <https://docs.rockylinux.org/10/guides/contribute/ai-contribution-policy/> | search-only | community | Disclosure model |
| R05-S67 | ROMs and abandonware law | <https://www.somethingawful.com/video-game-article/rom-abandonware-law/> | search-only | L7, L8 | . |
| R07-S53 | SafeWise — "Bark App Review"; AllAboutCookies — "Bark vs. Qustodio 2026" | <https://www.safewise.com/kids-safety/parental-control-apps/bark/> | search-only | L5, L6, L10 | ; https://allaboutcookies.org/bark-vs-qustodio —  · 2026-09-01 · false positives, alert fatigue, lag, VPN bypass. |
| R07-S68 | Sage, J. Educ. Computing Research — "Designing and Learning With Pedagogical Agents: An Umbrella Review" (2024); Schroeder, Adesope & Gilbert — "How Effective are Pedagogical Agents for Learning? A Meta-Analytic Review" | <https://journals.sagepub.com/doi/10.1177/07356331241288476> | search-only | L5, L6, L10 | ; https://journals.sagepub.com/doi/10.2190/EC.49.1.a —  · 2026-09-01 · small positive effects; function/design matter. |
| R05-S66 | ScummVM Games | <https://www.scummvm.org/games/> | search-only | L7, L8 | 11 freeware titles. |
| R05-S27 | Sober issues | <https://github.com/vinegarhq/sober/issues> | search-only | L7, L8 | Active bug flow Aug 2026. |
| R02-S51 | Starry Hope: Family Link on a Chromebook (2026) | <https://www.starryhope.com/chromebooks/family-link-chromebook-parental-controls-2026/> | search-only | L1, L9, all | Per-device limits, app approval, three filter postures |
| R05-S31 | Steam Families guide | <https://steamdb.com/en/articles/steam-family-sharing-complete-guide> | search-only | L7, L8 | Child accounts, playtime limits. |
| R05-S32 | Steam parental controls | <https://www.internetmatters.org/parental-controls/gaming-consoles/steam/> | search-only | L7, L8 | Family View PIN steps. |
| R03-S70 | tecnocode: Parental controls web filtering backend (2025-11) | <https://tecnocode.co.uk/2025/11/27/parental-controls-web-filtering-backend/> | search-only | L1, L2, L4 | malcontent direction |
| R04-S72 | Tube Archivist | <https://git.tubearchivist.com/tubearchivist/tubearchivist> | search-only | L3 | Three containers; kids-use anecdotes |
| R05-S41 | Tyson Tan | <https://en.wikipedia.org/wiki/Tyson_Tan> | search-only | L7, L8 | Konqi/Kiki artist; free-licensed work. |
| R01-S62 | Voxtype | <https://voxtype.io/> | search-only | L11, L5 | Linked from manual |
| R06-S62 | W3C WAI accessibility statement generator | <https://www.w3.org/WAI/planning/statements/generator/> | search-only | community | Linked from S37 |
| R07-S64 | Wikipedia — "International Age Rating Coalition"; Internet Matters — "Video games age ratings explained" | <https://en.wikipedia.org/wiki/International_Age_Rating_Coalition> | search-only | L5, L6, L10 | ; https://www.internetmatters.org/resources/video-games-age-ratings-explained/ —  · 2026-09-01 · PEGI 3/7/12/16/18; ESRB E/E10+/T/M/AO. |
| R07-S21 | Wikipedia — "Raine v. OpenAI" | <https://en.wikipedia.org/wiki/Raine_v._OpenAI> | search-only | L5, L6, L10 | · 2026-09-01 · filed Aug 2025; pretrial as of mid-2026. |
| R07-S10 | Wiley — "Injunction on California AADC Partially Vacated—Key Provisions May Take Effect on April 2" | <https://www.wiley.law/alert-Injunction-on-California-AADC-Partially-Vacated-Key-Provisions-May-Take-Effect-on-April-2> | search-only | L5, L6, L10 | · 2026-09-01 · mandate 3 Apr 2026. |
