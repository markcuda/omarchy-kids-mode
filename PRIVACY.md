# Privacy Stance

_status: accepted (founding) · updated 2026-09-01 — inherited by every satellite repo unless it says otherwise._

**Nothing about a child leaves the machine by default.** Kids Mode is local-first: no accounts, no telemetry,
no cloud dashboards, no crash reports containing usernames, no "anonymous usage statistics".

## What Kids Mode stores (locally, under the parent's control)

- Configuration: preset, budgets, bedtime, allowlists, theme, character choice. A first name is optional; an age
  **band** is stored, not a birth date (open question whether to store birth year at all).
- Screen-time state and a **summary** of usage (app class, duration) for the local digest. **The child can see
  everything the parent can see.**
- Voice Command transcripts (only if a parent turned it on): visible to parent and child; auto-deleted after a
  default retention period.

## What Kids Mode will never do

- Log keystrokes, take screenshots, record audio/video, or capture page content.
- Send activity, transcripts, or identifiers to any server we or anyone else runs.
- Track location. Show ads. Build a profile.

## If a feature ever needs the network

It must: be **opt-in** per parent; go through an RFC with the Safety & Privacy section completed; pass the policy
checklist in `docs/architecture/layers/06-onboarding.md` (COPPA/GDPR-K/UK & CA design codes/DSA); default to the
highest privacy setting; document retention. Remote notifications (e.g. ntfy) go only to a destination the parent
configured.

## Community spaces

No data about real children in this repo, Discussions, Discord, or screenshots — no names, faces, usernames,
voices, exact ages. Parents speak for kids using age bands. See `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md`.

## Regulatory note

Because Kids Mode collects nothing, it sits outside COPPA, GDPR Art. 8, the UK Children's Code and California's
AADC as an *operator*. We still adopt their design defaults (private by default, no addictive design, best
interests of the child) as our ethic — see report 07 §6.
