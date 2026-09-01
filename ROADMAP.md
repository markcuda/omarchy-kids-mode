# Roadmap

_status: draft · updated 2026-09-01 — phases, not dates. This is a volunteer project run by people with kids;
each phase ends when its exit criteria are met, not when a calendar says so._

## Phase 0 — Ground truth (now)

Replace assumptions with verified facts about Omarchy and the problem space; give the community one place to
look.

- [x] Repo scaffold, governance, templates, CI
- [x] Seven research reports (`research/reports/`) and a verified source registry (`research/sources.md`)
- [x] Layer model (L1–L11), threat model v0, open-questions register, seeded backlog
- [ ] Community review of the layer model and vision in Discord + Discussions (1–2 weeks)
- [x] OQ-3 (extension mechanism) and OQ-4 (boot lock-down) answered from upstream sources (reports 01, 03)
- [ ] Confirm on a real 4.0.2 install: second-user SDDM session, Limine editor + UKI (OQ-20), tmpfs exec flags,
      Flatpak override precedence (OQ-21), timekpr-next under omarchy-shell (OQ-18) — needs a volunteer with a spare
      machine or VM (backlog V-01…V-11)

**Exit:** the three architecture-shaping questions have evidence, not opinions.

## Phase 1 — Align (RFC round one)

Five decisions, each an RFC → ADR:

1. Account model (separate kid user vs. mode toggle)
2. Extension mechanism (theme + tools + config overlay vs. plugin, if a plugin system exists)
3. Default web-safety stack (DNS provider, egress lock, browser policy)
4. Age presets and the Level 1/2/3 definitions
5. Naming and namespace (org vs personal; "Omarchy" in the name — ask upstream)

**Exit:** ADRs merged; `projects/README.md` lists claimed workstreams with owners.

## Phase 2 — The quick win

The thing parents asked for first: **"stop the pop-up."**

- `omarchy-kids-web-safety` (L3): filtered DNS + DoH lock + browser policy + SafeSearch/YouTube-restricted,
  installable and removable in one command, with a "pause 15 minutes" parent action
- `omarchy-kids-setup` v0 (L1): creates the kid account with the right groups/polkit rules and applies a
  preset — even if the UI is a TUI for now
- First kid theme pack (L7) — because fun ships in the same release as safety, or it isn't Kids Mode

**Exit:** three parents in Discord ran it on real machines with real kids and filed what broke.

## Phase 3 — Progressive desktop

- `omarchy-kids-shell` (L5): Level 1 → 2 → 3 Hyprland configs, kid bar, input lock-down, crash safety
- Parent onboarding flow (L6) — the five-minute promise
- Kid first-run with mascot (L6/L7)
- Starter packs per preset (L8) and the sandboxed launcher (L4)

**Exit:** a 7-year-old asks how to make two windows.

## Phase 4 — Rhythm and play

- Screen time / bedtime / budgets with a kid-visible, parent-visible local summary (L9)
- Shortcut-trainer game and typing play (L5/L8)
- Optional voice helper — only if the L10 RFC is accepted, off by default

## Always

- Kid testing before "done"; safety bypass reports handled per `SECURITY.md`
- Weekly link check; sources verified; reports refreshed when Omarchy releases

## Not planned

See `docs/vision.md` → Non-goals.
