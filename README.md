# Omarchy Kids Mode — the plan

> **Kids deserve awesome computers too.**
> A community effort to make an [Omarchy](https://omarchy.org) laptop **safe by default, fun on day one, and able
> to grow with a child** — from one full-screen app at a time to the real keyboard-driven, tiled Omarchy.

_status: Phase 0 (ground truth) · updated 2026-09-01 · this repository is **research, architecture and planning
only** — no code ships from here (ADR-0002). It is the single source of truth for what we're building and why._

**Omarchy Kids Mode is an independent community project.** It is not affiliated with, endorsed by, or maintained
by David Heinemeier Hansson, 37signals/Basecamp, the Omacom Foundation, or the Omarchy project. Where members of
the Omarchy team take part, they do so as community members.

## What is "Omarchy kids"?

A set of **themes, shell plugins, policies and setup tools** — not a fork, not a new distro — that a parent can
turn on in five minutes so a child's Omarchy machine is:

| | |
| --- | --- |
| **Safe** | filtered web with no pop-up surprises, no way to `sudo`, sandboxed apps, honest about what a determined teen could still do |
| **Fun** | mascots, sound, games, a terminal that makes trains and rainbows |
| **Growing** | **Level 1** one thing at a time → **Level 2** two things side by side → **Level 3** real tiling → **Level 3+** the shell; parent-set presets (**Guided → Supported → Independent → Trusted**) decide how fast |
| **Private** | local-first; nothing about the child leaves the machine by default; the child sees everything the parent sees |

Read `docs/vision.md` for the why, `docs/architecture/overview.md` for the shape.

## Where we are (2026-09-01)

Seven research reports were produced on day one (`research/reports/`), each verified against live sources
(474 registered, 261 fetched-and-confirmed — `research/sources.md`). The headline corrections to our starting
assumptions:

- **Omarchy is 4.0.2 "Quattro"** (repo `omacom/omarchy`): the desktop is a Quickshell process with an **official
  plugin system**, Hyprland config is **Lua**, boot is **Limine + UKI**, disk is **btrfs + Snapper + mandatory
  LUKS**, browser is **Chromium with root-owned managed policies**, network is **NetworkManager + systemd-resolved
  plus ufw**. No AppArmor. **No content filtering ships.** (report 01)
- **Omarchy is single-user by design**; multi-user is rumoured for 4.1 — but a second Unix user with its own SDDM
  session and a **root-owned Hyprland config via `--config`** works today (it's how Omarchy's own greeter runs).
  The sharp edges: Omarchy sets **root's password equal to the owner's** and enables `getty@tty1`; **Limine has no
  password feature** (editor on by default, config overwritten on refresh); **Ctrl+Alt+Fn is hardcoded in Hyprland**
  (only XKB `srvrkeys:none` / no gettys neutralise it); a child who boots the machine alone knows the LUKS
  passphrase, so the firmware password is the parent's most important action. `fapolicyd` doesn't exist on Arch.
  (reports 01, 03)
- **A parallel project exists**: [`jfuerwentsches/omarchy-kids`](https://github.com/jfuerwentsches/omarchy-kids),
  four days older than this repo, with the right architecture (Rust agent + Qt parent control + age tiers).
  Coordinating is the first governance task. (`projects/README.md`, OQ-15)
- **No Linux tool ships parental controls that work on Hyprland**; GNOME's malcontent enforces nothing here and has
  an unfixed CVE. timekpr-next (logind-based) is the best screen-time fit. **No Linux tool has an "ask parent"
  flow** — that's our differentiator. Kids distros died of maintainer attrition, not bad ideas. (report 02)
- **The quick win is small**: a `Family` DNS preset in Omarchy's own `omarchy dns` (strict DoT, family upstream)
  plus a Chromium/Firefox **managed-policy pack** (DoH off, SafeSearch, YouTube restricted, no incognito/devtools/
  extensions). DoH bypass is closed by policy, not IP blocking; `youtube.com → youtubekids.com` DNS rewrites
  cannot work. (report 04)
- **Kids expect YouTube, Minecraft, Roblox.** We answer with a curated library + YouTube Kids, Luanti + one-click
  Minecraft Java, TurboWarp (Scratch) + SuperTuxKart; Roblox is a parent-gated opt-in. Arch `extra` already
  carries most of the educational catalog. Themes are colours-only when installed from git — perfect for kids.
  (report 05)
- **Two axes, not one ladder**: kid-earned capability levels vs parent-set freedom presets. Keyboard-first is
  realistic from ~7–8; under-7s get Level 1 only. **No AI "friend"**: if voice ships at all it's a nameless,
  offline, memoryless *tool*, off by default. (report 07)
- The AI-generated blueprint we started from had ~22 fabricated URLs and ~30 dead links; it's archived, never cited
  (`research/sources-audit/`, ADR-0003).

## The layers

| # | Layer | The question it answers | Doc |
| --- | --- | --- | --- |
| L1 | Commissioning & accounts | Separate kid user, or a mode? | [01](docs/architecture/layers/01-commissioning-and-accounts.md) |
| L2 | Boot & system hardening | Can a kid get root from the boot menu or a TTY? | [02](docs/architecture/layers/02-boot-and-system-hardening.md) |
| L3 | Network & content filtering | What's the boring, robust default that stops the pop-up? | [03](docs/architecture/layers/03-network-and-content-filtering.md) |
| L4 | App sandboxing & allowlisting | How do we allow GCompris but not `curl \| sh`? | [04](docs/architecture/layers/04-app-sandboxing-and-allowlisting.md) |
| L5 | Desktop shell & progressive UI | How does the desktop grow from one app to real tiling? | [05](docs/architecture/layers/05-desktop-shell-and-progressive-ui.md) |
| L6 | Onboarding | Can a non-technical parent finish in five minutes? | [06](docs/architecture/layers/06-onboarding.md) |
| L7 | Themes, mascots & sound | What makes a seven-year-old giggle in minute one? | [07](docs/architecture/layers/07-themes-mascots-and-sound.md) |
| L8 | Apps, games & learning | What's installed on day one, and what isn't? | [08](docs/architecture/layers/08-apps-games-and-learning.md) |
| L9 | Screen time & parent dashboard | How do limits work without spyware? | [09](docs/architecture/layers/09-screen-time-and-parent-dashboard.md) |
| L10 | Voice & local AI | Should this exist at all? | [10](docs/architecture/layers/10-voice-and-local-ai.md) |
| L11 | Packaging & distribution | How does a parent get it, and how does it survive `omarchy update`? | [11](docs/architecture/layers/11-packaging-and-distribution.md) |

Cross-cutting: `docs/threat-model.md`, `docs/open-questions.md`, `docs/personas.md`, `docs/glossary.md`.

## Get involved (you don't need to be a developer)

| You want to… | Do this |
| --- | --- |
| Tell us a real moment with your kid and a computer | Discussions → **Parent stories** (no names, faces or usernames of children) |
| Propose something | Issue → **💡 Idea** |
| Add a link or prior art | Issue → **📚 Add a source** |
| Check whether something is true | Take a `status: needs-verification` issue |
| Build a chunk | Pick a workstream in `backlog/workstreams.md`, open a **🧩 Workstream** issue |
| Report what your child did with a prototype | Issue → **🧒 Kid-test report** |

Full guide: `CONTRIBUTING.md`. Process: `rfcs/README.md`. Who decides what: `GOVERNANCE.md`.
Chat: the Omarchy Discord (link on omarchy.org) — find the kids-mode channel.

## The plan

`ROADMAP.md` — **Phase 0** ground truth (now) → **Phase 1** align (five RFCs: account model, extension mechanism,
web-safety stack, presets/levels, naming) → **Phase 2** the quick win (`omarchy-kids-web-safety`, `omarchy-kids-setup`
v0, first theme) → **Phase 3** the progressive desktop → **Phase 4** rhythm and play.

## Repo map

```text
docs/            vision · architecture (overview + 11 layer docs) · threat model · decisions (ADRs) · open questions · personas · glossary
rfcs/            proposal process + template
research/        7 reports · source registry (cite as [R01-S14]) · prior-art notes · community signal · blueprint audit & archive
backlog/         seeded backlog + claimable workstreams (GitHub Issues/Projects become canonical once live)
projects/        catalog of satellite repos and related projects
.github/         issue forms (idea, research, source, safety, workstream, kid-test) · discussion forms · CI (markdownlint, lychee, labels)
```

## Licence, conduct, safety

Prose is **CC-BY-4.0** (`LICENSE`); code samples and configs are **MIT** (`LICENSE-CODE`), matching upstream.
Contributor Covenant 3.0 (`CODE_OF_CONDUCT.md`). Kid-found bypasses are security issues (`SECURITY.md`).
Privacy stance: `PRIVACY.md`. Accessibility: `ACCESSIBILITY.md`.

## Credits

Kicked off in the Omarchy Discord on 2026-09-01 by the people in `research/community/`. Day-one research was
produced with AI research agents against live sources and then reviewed; every claim in `docs/` cites a verified
source (ADR-0003). Repo assumed at `github.com/markcuda/omarchy-kids-mode` until the org question (OQ-9) is settled.
