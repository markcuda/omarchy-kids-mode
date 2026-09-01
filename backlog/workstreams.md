# Workstreams — chunks with an owner slot

_status: draft · updated 2026-09-01 — each of these is big enough for its own repo or a multi-week effort. Claim one
with a 🧩 Workstream issue. Smaller items live in `backlog.md`._

| ID | Workstream | Layer | Phase | Skills | First deliverable | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| WS-A | **Platform watch & test image** | L11 | 0 | Arch, VMs | Weekly note on 4.1/multi-user/`agent-accounts`; an unattended-install `cidata` VM image of 4.0.2 for contributors | _open_ |
| WS-B | **Coordinate with `omarchy-kids`** | community | 0 | diplomacy | Conversation with the author; agreed split or merge written up as ADR (OQ-15) | @markcuda |
| WS-C | **Web safety pack** (`omarchy-kids-web-safety`) | L3 | 2 | shell, systemd-resolved, browser policy | `omarchy dns` Family preset PR upstream; Chromium + Firefox policy JSON; `omarchy-kids-check` | _open_ — p0 quick win |
| WS-D | **Setup tool** (`omarchy-kids-setup`) | L1, L6, L11 | 2 | bash/Rust, polkit, Snapper | `enable/disable/status` TUI: snapshot → de-privilege → policy → preset | _open_ |
| WS-E | **Threat model & hardening recipes** | L2, L1 | 1–2 | security, Limine, logind | BOOT-01..06 answered on a real 4.0.2 install; hardening tiers doc; acceptance tests | _open_ |
| WS-F | **Kid theme packs** (`omarchy-kids-<mascot>-theme`) | L7 | 2 | design | Tux theme (light, 7:1, spacing 1.4, Hyperlegible, credited backgrounds, `unlock.png`) | _open_ — needs an artist |
| WS-G | **Progressive shell** (`omarchy-kids-shell`) | L5 | 3 | Hyprland Lua, QML | Level 1/2/3 Lua overlays + window rules; kids bar plugin; kid launcher | _open_ |
| WS-H | **Onboarding** (`omarchy-kids-onboarding`) | L6 | 3 | UX, QML/TUI | Parent five-screen flow prototype + 5-parent usability test; kid first-run with guide | _open_ (Pete interested) |
| WS-I | **Starter packs** (`omarchy-kids-packs`) | L8 | 3 | curation, packaging | Pack manifests per preset; availability audit script in CI; kid fortune file | _open_ |
| WS-J | **Sandbox & kid shell** (`omarchy-kids-sandbox`) | L4 | 3 | bwrap, Flatpak, btrfs | Working bwrap GUI profile; `noexec` kid home; Bashcrawl quest | _open_ |
| WS-K | **Screen time & ask-parent** (`omarchy-kids-time`) | L9 | 4 | systemd, Rust/Python, QML | timekpr-next spike → policy schema → countdown widget + soft-lock overlay → ntfy ask-parent | _open_ (likely with omarchy-kids agentd) |
| WS-L | **Games** (`omarchy-kids-games`) | L5, L8 | 4 | QML, game design | Shortcut Target Practice overlay; home-row hint overlay | _open_ ("make a game!") |
| WS-M | **Pedagogy & presets spec** | L6 | 1 | education, writing | `presets/*.yaml` schema; level-unlock criteria; anti-dark-pattern checklist | _open_ |
| WS-N | **Voice Command RFC** | L10 | parked | — | RFC: in or out of v1; if in, the spec | _none_ |
| WS-O | **Docs, catalog & community** | community | always | writing | Marketplace/theme listings; Discord digest; monthly CHANGELOG; kid-test process | @markcuda |
