# Glossary

_status: draft · updated 2026-09-01_

| Term | Meaning here |
| --- | --- |
| **Omarchy** | DHH's opinionated Arch Linux + Hyprland setup (omarchy.org; repo `omacom/omarchy`; 4.0.2 as of 2026-08-31). Upstream. We build alongside it. |
| **Omacom** | The GitHub org (`omacom`) and Foundation (Aug 2026) behind Omarchy; holds the trademarks. |
| **Quattro** | Omarchy 4.x (2026-08-14+): shell rewritten in Quickshell, official plugin system, Hyprland config in Lua, internals moved to Arch packages under `/usr/share/omarchy`. |
| **Quickshell / omarchy-shell** | The QML-based desktop shell process that draws Omarchy 4's bar, menu, notifications, lock screen, polkit dialog — all as plugins. |
| **Plugin (shell plugin)** | A `manifest.json` + QML bundle in `~/.config/omarchy/plugins/<id>/`; kinds: `bar-widget`, `panel`, `overlay`, `menu`, `service`, `bar`. Ids are reverse-domain; `omarchy.*` is reserved. Runs unsandboxed in the user's shell process. |
| **Menu extension** | `~/.config/omarchy/extensions/omarchy-menu.jsonc` — overlay that adds/hides/retitles entries in the Omarchy menu (`Super+Space`) with no code. |
| **Hooks** | `~/.config/omarchy/hooks/<event>.d/` scripts run on `post-boot`, `post-update`, `theme-set`, etc. |
| **omarchy-kids (jfuerwentsches)** | An independent project started 2026-08-27: age-tiered config layer + Rust agent on the child machine + Qt/Quickshell parent control over SSH. Early concept. We coordinate with it (OQ-15). |
| **Hyprland** | The Wayland tiling compositor Omarchy runs. In Omarchy 4 the config is **Lua** (`~/.config/hypr/{hyprland,bindings,input,looknfeel,monitors,autostart}.lua`); keybinds, window rules, submaps. |
| **Limine** | Omarchy's bootloader (with a UKI). Not GRUB. |
| **Snapper / limine-snapper-sync** | btrfs snapshot tooling Omarchy ships; snapshots appear in the boot menu — relevant to the kid-rolls-back-a-snapshot threat. |
| **Deferred provisioning** | Omarchy's supported "install for another owner" flow (Ctrl+C on the installer, or an unattended `cidata` drive with `defer-provisioning`) — the natural hook for "gift a kid a computer". |
| **Factory reset** | `Setup > Reset Computer`: wipes `/home`, restores the baseline snapshot. |
| **Wayland** | The display protocol. Matters because many old parental-control and kiosk tools assume X11. |
| **Tiling** | Windows fill the screen in a grid without overlapping. Level 3 is full tiling; Level 2 is a fixed 50/50 split. |
| **Submap** | A Hyprland keybinding mode (like Vim modes). Used to lock inputs at lower Levels. |
| **Level 1/2/3** | Kids Mode's progressive desktop complexity (one thing / two things / the real thing). Defined in L5. |
| **Age preset** | A bundle of defaults (Level, allowlist, time budget, theme) named for an age band. Defined in L6. |
| **Layer (L1–L11)** | The eleven architectural slices in `docs/architecture/overview.md`. |
| **Commissioning** | The parent's one-time setup of the machine for a child (L1). |
| **Allowlist / blocklist** | Allowlist: only listed things permitted (safer, stricter). Blocklist: everything except listed things. We prefer allowlists for younger presets. |
| **FDE / LUKS** | Full-disk encryption. Protects data at rest; does not by itself stop a booted system being misused. |
| **polkit** | The Linux authorisation framework that decides whether a user may install packages, mount drives, change network settings, etc. Rules live in `/etc/polkit-1/rules.d/`. |
| **bubblewrap (bwrap)** | Unprivileged sandboxing tool used by Flatpak. Lets us run an app with a throwaway home and no network. |
| **Flatpak** | App packaging with sandboxing and permission portals; the basis of Endless/GNOME parental controls (malcontent). |
| **noexec** | Mount option that refuses to run binaries from a filesystem — used on the kid's home so downloads can't execute. |
| **DoH / DoT** | DNS-over-HTTPS / DNS-over-TLS. Encrypt DNS; also the standard way kids bypass DNS filters. |
| **Filtered DNS** | A resolver that refuses to answer for adult/malware domains (Cloudflare 1.1.1.3, NextDNS, OpenDNS FamilyShield…). |
| **SafeSearch enforcement** | DNS CNAME tricks (`forcesafesearch.google.com`, `restrict.youtube.com`) or browser policies that lock search engines/YouTube into restricted mode. |
| **Browser policy** | Enterprise-style managed settings (`policies.json`, `/etc/chromium/policies/managed/`) that users cannot change. |
| **OARS** | Open Age Ratings Service — content descriptors in AppStream metadata; used by malcontent to filter apps by age. |
| **malcontent** | GNOME's parental-controls library/daemon (app filtering by OARS, session limits). Packaged in Arch `extra`; policy lives in accounts-service but enforcement is GNOME/Flatpak-only, so on Hyprland it enforces nothing. `malcontent-timerd` has an unfixed local DoS (CVE-2026-44931). |
| **timekpr-next** | Screen-time daemon (AUR, actively maintained) enforcing via systemd-logind; Wayland-aware. Best current fit for L9. |
| **ActivityWatch** | Local, private usage tracker; a Hyprland IPC watcher exists. Candidate for kid-visible activity summaries — no screenshots, no keylogging. |
| **Satellite repo** | A separate repository that holds shippable code/config for one workstream (ADR-0002). |
| **RFC** | A written proposal that goes through review before it becomes a decision (`rfcs/`). |
| **ADR** | Architecture Decision Record — the short record of a decision (`docs/decisions/`). |
| **Verified source** | A source a named human opened and confirmed says what we cite it for (ADR-0003). |
| **Kid tester** | A contributor's child, via their parent, who tries things. Never identified in the repo. |
