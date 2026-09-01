# Project Catalog — satellite repos

_status: draft · updated 2026-09-01 — per ADR-0002, code ships in its own repo; this page is the map._

Everything below is **proposed** until someone claims it. Names follow Omarchy's `omarchy-*` convention.
Status ladder: `proposed` → `claimed` → `prototype` → `alpha` (parents testing) → `released` → `archived`.

| Project | Layer(s) | What it ships | Status | Owner | Repo |
| --- | --- | --- | --- | --- | --- |
| **omarchy-kids-mode** (this repo) | all | Research, architecture, RFCs, backlog, this catalog | active | @markcuda | — |
| **omarchy-kids-web-safety** | L3 | Filtered DNS config, DNS/DoH egress lock, Chromium/Firefox managed policies, SafeSearch + YouTube-restricted enforcement, parent "pause" command | proposed (Phase 2 quick win) | _open_ | — |
| **omarchy-kids-setup** | L1, L6 | Parent commissioning tool: kid account, groups, polkit rules, preset selection, apply/remove | proposed (Phase 2) | _open_ | — |
| **omarchy-kids-shell** | L5 | Level 1/2/3 Hyprland configs, kid bar/launcher config, input lock-down, crash-safe session | proposed (Phase 3) | _open_ | — |
| **omarchy-kids-sandbox** | L4 | Launcher wrappers (bubblewrap/Flatpak overrides), `noexec` home setup, restricted kid shell with a curated fun-binary set | proposed | _open_ | — |
| **omarchy-kids-theme-<name>** | L7 | One theme pack per character/palette, built on Omarchy's theme format; large fonts, high contrast, sounds | proposed — several wanted | _open_ | — |
| **omarchy-kids-packs** | L8 | Starter-pack manifests per preset (packages, Flatpaks, web apps, Kiwix ZIMs) and the install script | proposed | _open_ | — |
| **omarchy-kids-onboarding** | L6 | Kid first-run experience: mascot, name, first keys, level-up moments | proposed (Phase 3) | _open_ (Pete expressed interest in onboarding, Discord 2026-09-01) | — |
| **omarchy-kids-time** | L9 | Daily budgets, bedtime, per-app limits, local summary visible to kid and parent | proposed (Phase 4) | _open_ | — |
| **omarchy-kids-games** | L5, L8 | Shortcut trainer ("target practice" with `Super+Arrows`), typing play, keybinding quests | proposed (Phase 4) | _open_ ("make a game!" — Harris) | — |
| **omarchy-kids-voice** | L10 | Optional offline push-to-talk helper with guardrails | parked pending RFC | — | — |

## Related projects (not ours — coordinate, don't duplicate)

| Project | What it is | Relationship |
| --- | --- | --- |
| [`jfuerwentsches/omarchy-kids`](https://github.com/jfuerwentsches/omarchy-kids) | Started 2026-08-27. "A configuration layer on top of Omarchy that grows with a child — age-tiered desktop profiles plus tooling for parental controls and screen time. Not a fork." Rust agent/daemon on the child machine (budgets, pre-warnings, app wrapper, polkit policy), C++/Qt parent control centre + Quickshell headerbar plugin on the parent machine over SSH, `tiers/` per-age Hyprland config, setup wizard, omarchy-kids.com. Status per its README: early concept, not usable yet. | **OQ-15 — open, urgent.** Natural split if both continue: this repo = research, architecture, themes, launcher/bar plugins, browser-policy packs; omarchy-kids = agent/control plane. Reach out before Phase 1. |
| [`omacom/omarchy`](https://github.com/omacom/omarchy) Discussion #532 "Support Multiple Users" | The upstream thread for the family-PC use case; single-user by design today; "multi-user in 4.1" claimed second-hand (the `agent-accounts` branch is about AI-provider subscription accounts, not Unix users — report 03) | Track; ask maintainers about 4.1 design intent |
| [plugins.omarchy.org](https://plugins.omarchy.org/) / [omarchy.org/themes](https://omarchy.org/themes/) | Upstream catalogs for community plugins and themes | Where our plugins/themes get listed (PR to `omacom/omarchy-plugin-marketplace` / `omarchy-site`) |

## Naming notes

- Repos: `omarchy-kids-<thing>` for tools, `omarchy-<name>-theme` for themes (upstream's convention).
- **Plugin ids** must be reverse-domain and must **not** start with `omarchy.` (reserved; `omarchy plugin validate` refuses it). Until an org/domain is settled, use `io.github.<owner>.kids-<thing>`.
- "Omarchy" trademarks are held by the Omacom Foundation (Aug 2026). Using the name in a community project follows upstream's lead; ask before creating an org named with it (OQ-9).

## The satellite-repo contract

A repo listed here must:

1. Have a README that states its **layer**, **status**, **owner**, and links back to this catalog and the
   relevant layer doc/RFC.
2. Carry a `LICENSE` (MIT recommended, matching Omarchy), the project `CODE_OF_CONDUCT.md`, and inherit
   `SECURITY.md` (copy it or link it).
3. Document how it is **installed, removed, and how it survives `omarchy-update`**.
4. State what it stores about the child (default: nothing beyond local config) in its README.
5. Add a row here via PR when it changes status.

## Claiming one

Open a **🧩 Workstream** issue, or comment on the existing one. A maintainer updates the row and adds you as
CODEOWNER for the matching layer path if you want it.
