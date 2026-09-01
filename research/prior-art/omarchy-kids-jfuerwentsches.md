# Prior art: `jfuerwentsches/omarchy-kids`

_status: verified 2026-09-01 (via report 01, [R01-S44]) · updated 2026-09-01_

**What:** An independent GitHub project created **2026-08-27** (last push 2026-08-30 at time of research; 4 stars; MIT). Self-description: *"A configuration layer on top of Omarchy that grows with a child — age-tiered desktop profiles plus tooling for parental controls and screen time. Not a fork."* Status per README: **early concept / development-environment setup; not usable yet.** Has `CONTRIBUTING.md` and CI. Website planned at omarchy-kids.com (EN + DE).

**Architecture (from its tree):**

| Side | Component | Notes |
| --- | --- | --- |
| Child machine | Omarchy + config layer + local **Rust agent** (`omarchy-kids-agent` CLI, `omarchy-kids-agentd` daemon) | Modules: budget, pre-warning, security, ticker; app wrapper; override-helper; repair-helper; pairing over mDNS/QR; PKGBUILD; polkit policy `net.omarchykids.agent.policy`; systemd unit |
| Child machine | `tiers/` | Per-age Hyprland config, Quickshell modules, wallpaper/branding, `omarchy-kids-set-tier` |
| Child machine | `setup-wizard/` | First-boot flow |
| Parent machine | **C++/Qt control centre** (GUI + TUI) and a **Quickshell headerbar plugin** | Talks to the child's agent over **SSH** |

**Why it matters:** It already has the right *shape* — unprivileged child config layer + privileged root daemon + parent-side control — the same split LiFE Parental Control uses and the one report 02 recommends. It also owns the obvious name and domain. It is four days older than this repo.

**Overlap with our layer model:** L1 (setup wizard, tiers), L5 (tiered Hyprland config, Quickshell modules), L9 (budget/pre-warning/ticker), L11 (PKGBUILD, systemd, polkit).

**Not covered there (yet), as far as the tree shows:** research/prior-art, network & browser policy (L3), sandboxing (L4), themes/mascots (L7), app/content curation (L8), pedagogy/age-band evidence (L6/L7), threat model.

**Recommended action (OQ-15):** contact the author before Phase 1 and propose either (a) merging this research/planning repo into their project as its `docs/`/RFC space, or (b) an explicit split — this repo as the community research/architecture home plus themes, launcher/bar plugins and policy packs; `omarchy-kids` as the agent/control plane. Either way, agree naming (`omarchy-kids-*` repos; plugin id namespace) so contributors aren't confused.

**Source:** <https://github.com/jfuerwentsches/omarchy-kids> — verified via GitHub API 2026-09-01 [R01-S44].
