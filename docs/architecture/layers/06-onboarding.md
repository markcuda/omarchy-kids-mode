# L6 · Onboarding (parent and kid)

_status: draft · updated 2026-09-01 · lead: open (Pete expressed interest, Discord 2026-09-01) · primary evidence: reports 07, 02, 01_

## Purpose

**Parent:** boot → choose Kid Mode → five screens → done in five minutes, no terminal.
**Kid:** first login → meet the guide → learn three keys → giggle.

## What we know (verified)

- Every mainstream parent tool converges on: per-child profile → age preset → allow/block → budget + bedtime →
  approvals → weekly digest → remote pause → PIN. Loudest complaints: bypasses, alert fatigue, lag, supervision
  evaporating at 13. [R07-S47]–[R07-S53][R02-S45]–[R02-S51]
- Restrictive rules are the strongest predictor of preschoolers meeting limits; active mediation and co-use matter
  more for older kids; AAP 2026 favours "quality, context and conversation" over hour counts, screen-free hour
  before bed. [R07-S26][R07-S31][R07-S32]
- Omarchy supports "install for another owner" (deferred provisioning) and unattended `cidata` installs — a
  first-boot hook can apply Kids Mode before the child ever sees the desktop. [R01-S41][R01-S40]
- GitHub and Discord require users to be 13+; children never participate directly in the project — parents do,
  via a kid-test report form. [R06-S51][R06-S52]

## Presets and age bands (proposal — from report 07's matrix; refine in an RFC)

| Band | Reading / motor | Suggested preset | Starting level | Web | Shell | Voice |
| --- | --- | --- | --- | --- | --- | --- |
| 3–5 | Pre-reader; 64 px targets; no drag | **Guided** | 1 (only) | none | none | off |
| 5–7 | Emergent reader; home row from ~6–7 | **Guided** | 1 → 2 | curated allowlist only | playground optional | off |
| 8–10 | Fluent; formal typing OK | **Supported** | 1 → 3 | filtered + report | sandboxed real shell | opt-in, transcripts |
| 11–13 | Adult-level | **Independent** | 1 → 3+ | filtered, summary-only report | real shell, no sudo | opt-in |
| 13+ | — | **Trusted** | 3+ | blocklist only | full user path | opt-in |

Preset names are parent-facing and non-judgemental; rank names (Explorer → Tinkerer → Navigator → Wizard) are
kid-facing and role-based, never age-labelled — a late starter is never shamed. No gender field, ever.

## The parent flow (five screens)

1. **Who?** Child's first name + birth year (stored locally as a *band*, or not at all — OQ) → suggests a preset
   with a one-line explanation; parent may override.
2. **How much?** Two sliders pre-filled from the preset: daily budget (weekday/weekend) and bedtime window
   (default includes the AAP's screen-free hour). Toggle: "creating apps don't count" (off, explained).
3. **What?** Starter pack for the band (L8) with OARS/PEGI badges; web = none / curated / filtered; "ask to
   install" on/off.
4. **Extras?** Voice command (off, one paragraph why), sandboxed terminal (on for Supported+), weekly digest
   (local only by default).
5. **Lock it.** Parent's Linux password is the root of trust; 4–6-digit quick PIN for in-session approvals;
   PIN recovery = parent password. Show the "three ways to pause right now" card.

Starting level is always **1** on first login; the preset controls unlock speed.

Where it runs: today (single-user Omarchy) as `omarchy-kids-setup` (TUI first, Quickshell `panel` later) run by
the parent before hand-over; with deferred provisioning, as a first-boot hook. After 4.1 multi-user, as an
"Add a kid" entry in Setup.

## The kid flow

- **Meet the guide.** Non-human, non-gendered default character; the child picks a look (L7 character packs).
  The guide *teaches the machine*, never *relates* ("Press Super+Space to open something" — never "I missed you").
- **Three keys, one at a time.** Open (`Super+Space`), close (`Super+W`), home (`Super+Home`). Physical/on-screen
  anchor for each. Immediate, reversible feedback. Mastery badge, no streak.
- **First app.** From the starter pack; full-screen; the guide fades.
- **Level-up moments.** Presented as a poster of "the next keys"; unlocked by demonstrated skill and (per preset)
  a parent's confirmation.
- **Mistake safety.** "Oops", never "wrong"; Home and Undo one keystroke away; nothing the child does is
  unrecoverable; "Reset my desktop" restores layout, never files.
- **Anti-dark-pattern rules** (5Rights / EU DSA minors guidelines): rewards for mastery only; no streaks,
  daily-login bait, loss-aversion timers or variable rewards; badges never expire.

## Recovery flows

Forgot PIN → parent password. Forgot parent password → LUKS/Omarchy's own recovery (out of scope). Kid locked
out by bedtime → "ask a grown-up" → PIN in place or ntfy remote grant (L9). Broken desktop → Reset my desktop.
Everything gone wrong → Snapper "before kids mode" snapshot (L11) or Omarchy factory reset.

## Interfaces

Produces the **preset** consumed by L3/L4/L5/L8/L9; consumes character packs (L7), packs (L8); packaged by L11.

## Workstreams & backlog seeds

UX-01 parent five-screen flow prototype (TUI/Quickshell) + usability test with 5 parents (time-to-done) ·
UX-02 Level-1 kiosk study with 4–7-year-olds (parent present, no recordings) · UX-04 mascot/guide brief ·
UX-05 reward spec + dark-pattern checklist · PED-01 presets schema (`presets/*.yaml`) · PED-02 unlock criteria ·
ONB-01 first-boot hook for deferred provisioning · ONB-02 kid-test report process (parent proxy).

## Open questions

OQ-7, OQ-10, OQ-11; store birth year or just band? how to run child usability tests ethically as an OSS community?
