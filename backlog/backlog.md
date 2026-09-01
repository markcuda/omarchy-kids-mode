# Seeded backlog

_status: draft · updated 2026-09-01 — distilled from the seven research reports. IDs are stable; convert to GitHub
Issues as claimed (keep the ID in the title). P = priority (p0 quick win / p1 / p2 / later); E = effort (S evening /
M weekend / L weeks). GFI = good first issue._

## Phase 0 — ground truth (verify on a real Omarchy 4.0.2 install)

| ID | Item | Layer | P | E | Source |
| --- | --- | --- | --- | --- | --- |
| V-01 | Confirm single-user behaviour: can a second Unix user log in via SDDM on 4.0.2 without breaking updates? What does `agent-accounts` do? | L1 | p0 | M | R01 |
| V-02 | Limine: password / editor lock / hidden menu support; behaviour of Snapper entries in the boot menu | L2 | p0 | M | R01, R03 |
| V-03 | Does `Setup > Reset Computer` require privilege? What survives? | L2 | p1 | S | R01 |
| V-04 | VT switching on Hyprland 0.56 + logind: can a kid reach a TTY; does the parent have a TTY login? | L2 | p1 | S | R03 |
| V-05 | `omarchy dns` on 4.x: confirm NM global-dns pinning and strict DoT; does per-connection DNS override it? | L3 | p0 | S | verified script; NET-14 |
| V-06 | Does Arch `flatpak` link `libmalcontent` (OQ-17)? | L4 | p1 | S | R02 |
| V-07 | timekpr-next on Omarchy 4: tray, lock hook, polkit agent, notifications under omarchy-shell (OQ-18) | L9 | p1 | M | R02 |
| V-08 | Is the r/omarchy "school computers" thread real; what did schools ask for? | community | p2 | S | R01 |
| V-09 | Family Link supervised profile in Arch Chromium with Omarchy OAuth flags — does the approve/deny flow work? | L3 | p2 | M | R04 |
| V-10 | Verify SEARCH-ONLY primary sources blocked today (FTC, ICO, UNICEF, NAEYC, ACM) and file excerpts (RES-01) | community | p2 | M | R07 |
| V-11 | Confirm `omarchy plugin add` privilege and whether kid plugin dirs can be root-overlaid (OQ-16) | L11 | p1 | S | R01 |

## Phase 1 — align (RFCs → ADRs)

| ID | Item | Layer | P | E | Source |
| --- | --- | --- | --- | --- | --- |
| RFC-01 | Account model: kid's own machine now, per-user profile later (OQ-2) | L1 | p0 | M | R01, R02, R03 |
| RFC-02 | Extension mechanism: plugins + menu extension + Lua overlays + colours-only themes + root policy (OQ-3/16) | L11 | p0 | S | R01 |
| RFC-03 | Web-safety default stack and DNS provider (OQ-6) | L3 | p0 | M | R04 |
| RFC-04 | Presets (Guided/Supported/Independent/Trusted) and Levels 1/2/3/3+ with unlock policy (OQ-7/10) | L5, L6 | p0 | M | R07 |
| RFC-05 | Naming & namespace; relationship to `omarchy-kids` and to upstream (OQ-9/15) | community | p0 | S | R06, R01 |
| RFC-06 | Voice Command: in or out of v1 (OQ-8) | L10 | later | S | R07 |
| RFC-07 | Activity summaries: what is acceptable (local, symmetric, no content) | L9 | p1 | S | R02, R07 |

## L1 · Commissioning & accounts

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| ACC-02 | polkit rule set for a kid uid (packages, NM system connections, udisks, systemd, power) — tested | p1 | M | R03 |
| ACC-03 | De-privilege script (wheel/adm/docker, passwordless-sudo off) + verification | p1 | S | R01 |
| ACC-04 | Quick-PIN design (hash, storage, recovery via parent password) | p2 | S | R07 |
| ACC-06 | "Gift a kid computer" guide (deferred provisioning + `cidata` + first-boot hook) | p2 | M | R01 |

## L2 · Boot & system hardening

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| BOOT-01 | Limine lock-down feasibility | p0 | M | R03 |
| BOOT-02 | Snapshot-rollback policy with `limine-snapper-sync`; re-lock on first boot after rollback | p1 | M | R01 |
| BOOT-03 | VT/TTY lockdown recipe | p1 | S | R03 |
| BOOT-05 | Firmware-password parent card for common laptops (GFI) | p2 | S | R02 |

## L3 · Network & content filtering

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| NET-01 | `omarchy dns` Family preset — PR upstream (Cloudflare/AdGuard/CleanBrowsing Family; strict DoT; `Domains=~.`) | p0 | S | R04 |
| NET-02 | Chromium-family managed policy pack (+ resolve `copy-url` unpacked-extension conflict) | p0 | S | R04 |
| NET-03 | Firefox/Zen `policies.json` twin | p1 | S | R04 |
| NET-07 | `omarchy-kids-check` green/red self-test | p0 | M | R04 |
| NET-08 | Kids web-app set: remove stock YouTube/ChatGPT/X/Discord/WhatsApp; add YouTube Kids + vetted sites; `https://`-only guard | p0 | S | R04 |
| NET-04 | dnscrypt-proxy kids profile (cloaking, schedules, blocked names, resolved hand-off) | p1 | M | R04 |
| NET-05 | nftables `kids` egress table coexisting with ufw; per-uid 53/853 lock; optional 80/443 allowlist | p1 | M | R04 |
| NET-06 | DoH/VPN-bypass hostname list + canary NXDOMAIN | p2 | S | R04 |
| NET-09 | Parent `pause/allow/report` CLI (polkit + timer; optional ntfy) | p2 | M | R04 |
| NET-11 | NSFW Filter extension force-install spike (CPU, false positives) | p2 | S | R04 |
| NET-12 | "Library" mode design note (Jellyfin/Kodi; ToS caveat) | later | S | R04, R05 |

## L4 · App sandboxing & allowlisting

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| SBX-01 | Working bwrap profile for a Wayland GUI app on Omarchy 4 | p1 | M | R03 |
| SBX-02 | `noexec,nosuid,nodev` kid home on Omarchy's btrfs layout | p1 | S | R03, R04 |
| SBX-03 | Flatpak override policy per preset | p1 | S | R02 |
| SBX-05 | Launcher allowlist format + launch wrapper | p1 | M | R02 |
| SBX-06 | Kid shell (`bwrap-term-shield`) + Bashcrawl-Omarchy quest | p2 | M | R05, R07 |
| SBX-08 | Kid fortune file: 300+ CC0 jokes/riddles/facts, `strfile` (GFI) | p2 | S | R05 |

## L5 · Desktop shell & progressive UI

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| SHELL-01 | Level 1/2/3 Hyprland Lua overlays + window rules (align with omarchy-kids `tiers/`) | p1 | M | R01, R07 |
| SHELL-02 | Kids bar (`bar`-kind plugin): big dots, clock, battery, time-left, "ask a grown-up" | p1 | M | R01 |
| SHELL-03 | Kid launcher (`overlay`/`menu`): icon + audio, allowlist-driven, DoudouLinux ordering | p1 | M | R01, R07 |
| SHELL-04 | Menu extension pack hiding Setup/Update/Remove/Install; Play/Learn/Create (GFI) | p1 | S | R01 |
| SHELL-05 | Shortcut Target Practice (`overlay` + `hyprctl` geometry) — flagship mini-game | p2 | L | R05 |
| SHELL-06 | Home-row hint overlay | later | S | R05 |
| SHELL-07 | Crash/exit behaviour test (shell dies / Hyprland dies) | p1 | S | R01 |
| SHELL-08 | Super+Arrow split usability test with 6–9-year-olds (parent present) | p2 | M | R07 |

## L6 · Onboarding

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| UX-01 | Parent five-screen flow prototype (TUI first) + 5-parent test, time-to-done | p1 | M | R07 |
| UX-02 | Level-1 kiosk paper study with 4–7-year-olds | p2 | M | R07 |
| UX-04 | Mascot/guide brief (teaches, never bonds; non-human default) | p1 | S | R07 |
| UX-05 | Reward spec + anti-dark-pattern checklist | p2 | S | R07 |
| PED-01 | `presets/*.yaml` schema (band, preset, permissions, starting level, unlock policy) | p0 | S | R07 |
| PED-02 | Level unlock criteria + parent confirmation UI | p1 | S | R07 |
| ONB-02 | Kid-test report process doc (ethics: consent, no recordings, parent present) | p1 | S | R06, R07 |

## L7 · Themes, mascots & sound

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| THEME-01 | `omarchy-kids-tux-theme` (GFI) | p1 | S | R05 |
| THEME-02 | Konqi / Wilber themes (share-alike notes) | p2 | S | R05 |
| THEME-03 | `kids-theme-lint` (contrast, licence, required files) | p2 | S | R05 |
| THEME-04 | Sound theme `service` plugin (CC0 cues) | later | M | R05 |
| THEME-05 | Mascot licence registry (Kiki, Freedo, GNU, Suzanne, Puffy, Xue) (GFI) | p2 | S | R05 |
| THEME-06 | Printable key poster + sticker sheet (left-handed/non-QWERTY variants) | p2 | S | R07 |
| THEME-07 | Call for an original CC0 character | p2 | — | R05 |

## L8 · Apps, games & learning

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| APPS-01 | Package-availability audit script (Arch/AUR/Flathub APIs) in CI monthly (GFI) | p1 | S | R05 |
| APPS-03 | Pack manifests per preset | p1 | M | R05 |
| APPS-04 | Curated web-app list (Blockly, MakeCode, Piskel, PuzzleScript, Bitsy, Turtle Blocks, Hedy, PBS Kids) (GFI) | p1 | S | R05 |
| APPS-06 | Luanti kids world (Classroom/EDU mods, LAN-only, chat off) | p2 | M | R05 |
| APPS-07 | Jellyfin/Kodi kid-profile playbook (test 10.11 regressions) | p2 | S | R05 |
| APPS-08 | Kiwix starter ZIM set + download script; check "Wikipedia for Schools" | p2 | S | R05 |
| APPS-09 | TIC-80 cartridge shelf (replaces PICO-8 idea) | later | M | R05 |
| APPS-11 | Parent guides: Roblox via Sober; Steam Family View (GFI) | p2 | S | R05 |
| APPS-12 | OARS ingestion → allowlist badges (PEGI/ESRB mapping) | p2 | M | R07 |

## L9 · Screen time & parent dashboard

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| TIME-02 | Policy schema: budgets, bedtime, app classes, education gate (align with omarchy-kids agentd; consider malcontent schema) | p1 | S | R02 |
| TIME-03 | Ask-parent flow design + ntfy prototype | p2 | M | R02 |
| TIME-04 | Activity summary via ActivityWatch Hyprland watcher; "My day" panel mock | p2 | M | R02 |
| TIME-05 | Education-gates-entertainment rule (kid-visible) | later | S | R02, R07 |
| TIME-01 | Time engine (bedtime, budget, bonus, creating-vs-consuming, weekly digest) | p2 | L | R07 |

## L10 · Voice & local AI

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| AI-02 | Parent explainer "Why there's no AI friend" (GFI) | p2 | S | R07 |
| AI-01 | Voice Command spec (only if RFC-06 accepts) | later | M | R07 |

## L11 · Packaging & distribution

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| PKG-02 | `omarchy-kids-setup {enable,disable,status}` skeleton + PKGBUILD | p0 | M | R01 |
| PKG-03 | Re-assertion hooks (`post-update.d`, `post-boot.d`) + daemon self-check | p1 | S | R01 |
| PKG-05 | Catalog presence: marketplace + themes PRs; Suggestions post for `Install > Kids` | p2 | S | R01 |

## Community / this repo

| ID | Item | P | E | Source |
| --- | --- | --- | --- | --- |
| COM-01 | Publish repo; enable Discussions (Ideas, Q&A, Parent stories, Show and tell), private vulnerability reporting, branch protection, label sync | p0 | S | R06 |
| COM-02 | Post the layer model + vision in Discord for review; collect objections for a week | p0 | S | — |
| COM-03 | Courtesy post to Omarchy maintainers about naming/org (OQ-9) | p0 | S | R06 |
| COM-04 | Reach out to `omarchy-kids` author (OQ-15) | p0 | S | R01 |
| COM-05 | Projects v2 board with fields from `backlog/README.md` | p1 | S | R06 |
| COM-06 | DCO check workflow; cspell dictionary | p2 | S | R06 |
| COM-07 | Monthly CHANGELOG/Discord digest | p2 | S | R06 |

## Added from report 03 (hardening) — 2026-09-01

| ID | Item | Layer | P | E | Source |
| --- | --- | --- | --- | --- | --- |
| V-12 | Which tmpfs mounts on a stock Omarchy host are `exec` (`/tmp`, `/var/tmp`, `/dev/shm`, `/run/user/<uid>`)? | L4 | p1 | S | R03 |
| V-13 | Flatpak `--user` override vs system override precedence (OQ-21) | L4 | p1 | S | R03 |
| V-14 | Does `hyprctl keyword ecosystem:enforce_permissions false` weaken permissions at runtime for the session owner? | L5 | p2 | S | R03 |
| V-15 | UKI + Limine editor: can `init=/bin/bash` be injected? (OQ-20) | L2 | p0 | M | R03 |
| ACC-03 | `omarchy-kids-user`: useradd (no groups), skel, `nosuid,nodev,noexec` bind-remount, `omarchy-kids` group, optional kid autologin drop-in, uninstall | L1 | p0 | S | R03 |
| ACC-05 | Parent hygiene guide: `timestamp_type=tty`, short timeout, FIDO2 caveat, passwordless/keepalive warnings, docker group, lock-on-leave | L1 | p1 | S | R03 |
| BOOT-01 | `omarchy-kids-boot-harden`: `editor_enabled: no`, snapshot entry policy, post-update hook re-apply, firmware/Direct-Boot checklist, rollback | L2 | p0 | S | R03 |
| BOOT-03 | TTY/VT kit: logind drop-in (`NAutoVTs=0`, `ReserveVT=0`, `KillOnlyUsers=kid`), mask `getty@tty1`, `passwd -l root`, documented recovery path | L2 | p0 | S | R03 |
| BOOT-07 | Upstream asks: `editor_enabled: no` default + Limine post-refresh hook (Omarchy); config switch for VT switching (Hyprland feature request) | L2 | p2 | S | R03 |
| SHELL-01b | Kid session: `omarchy-kid.desktop` + `/etc/omarchy-kids/hyprland.lua` (`package.path` pinning, `omarchy_default_bindings=false`, minimal binds, window rules `fullscreen_state`/`stay_focused`/`suppress_event`, `enforce_permissions`, `kb_options="srvrkeys:none"`, no Omarchy agents/crash-watch) | L5/L1 | p0 | M | R03 |
| SBX-01 | `kids-run` bwrap base profile (Wayland+PipeWire+DRI only, `--new-session`, `--die-with-parent`) + per-app overlays + smoke tests on Hyprland 0.56 | L4 | p1 | M | R03 |
| SBX-07 | Toy REPL prototype for 5–8 (virtual filesystem, quests) | L4 | p2 | M | R03 |
| SBX-09 | Hyprland permissions rule set (`plugin`/`screencopy` deny, keyboard last-rule deny) | L5 | p1 | S | R03 |
| PKG-06 | VM test harness: unattended QEMU install via `cidata` to run the anti-bypass matrix after each Omarchy release | L11 | p1 | L | R03 |
