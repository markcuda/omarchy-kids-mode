# SPEC amendment: what to take from upstream screen time (#11196)

Status: **proposed — owner decisions marked below.** From the owner's dogfooding notes, 2026-09-24:
"add in this ... #11196 — Screen Time first-party (jankeesvw) ... and see if his screentime
implement is better than ours ... this is a big one."

Amends: R-TIME-2/3/4, Appendix B/F, and `omarchy-kids-check` (coexistence). Does not change the
account model, the parent-never-restricted rule, or who may enforce.

## What #11196 is

A first-party rework of Omarchy's child screen time (omacom/omarchy#11196, stacked on the upstream
kids mode #9750). A root daemon counts active minutes from **logind's seat state**; lock state is
read **only from the shell**; the lock goes through the shell and retries, ending the compositor
after three failures. Parent controls sit behind a **PIN** in a separate `authentication`-capability
service; a settings window offers **Limits vs Agreement**, per-weekday minutes, blocked periods and
**math-to-earn** minutes.

## The honest comparison

| Axis | #11196 | This repo today | Call |
| --- | --- | --- | --- |
| Counting input | logind seat state; lock state from the shell only | trusts session-set lock state (`bin/omarchy-kids-time-ledger`) | **Take theirs** (private spec-08: a stated fence, now to be closed) |
| Lock engagement | shell lock, retry, then end the compositor | `loginctl lock-session`, which Quattro's shell ignores | **Take the retry/verify idea**; keep our 60 s finish |
| Schedules | per-weekday minutes, several blocked periods | weekday/weekend budgets, one lights-out each | **Take theirs** (T49) |
| Modes | Limits and Agreement | Limits only | **Take Agreement**, labeled "not enforced" (T50, I-6) |
| Parent secret | PIN behind an auth service | the parent password (I-8) | **Decide** (T52) |
| Parent/kid UI | GUI settings window, bar pill with a day view | TUI rows, a "N minutes left" line | **Take the kid day view** (T53); the parent GUI is a later question |
| Earn minutes | math problems | none | **Take, opt-in, with root-issued and root-checked problems** (T51) |
| Multi-kid, parent unrestricted, no kid sudo, no core edits, our Ask/notify/portal | — | yes | **This repo's model stands** |

## What this repo takes, and what it refuses

**Takes** (each its own ticket, each with the standard gate):

- **T9 — counting integrity (private, via SECURITY.md):** stop trusting a session-set lock signal;
  use logind's seat/Active state plus a shell-reported lock, and list the fence in Appendix G until
  it is closed.
- **T49 — per-weekday minutes and multiple blocked periods** (schema + `omarchy-kids-time` +
  wizard/panel rows).
- **T50 — Agreement mode:** no lock, and every label says it is not enforced (I-6).
- **T51 — earn minutes (opt-in):** the problem is issued and checked by **root**, so a kid cannot
  print the answer; the minutes land through the same `grant` path as a parent's.
- **T53 — a kid day view:** time left, tonight's bedtime, today's minutes, on the kid's own surface.

**Refuses, and says why:**

- **Its code.** #11196 edits ~15 Omarchy-owned files (I-7) and gives the kid's group a NOPASSWD sudo
  grant to a screen-time control verb (breaks R-FND-3/G). Neither can land here. We reimplement the
  ideas in our own root-owned units and, where a kid needs to act, through a socket helper that
  checks the caller (SO_PEERCRED), the authd/wifid pattern.
- **The engine swap.** Our ledger, its units and its state file stay.

**Owner decisions:**

1. **T52 — a PIN.** Adopt a separate, cheaper parent secret for low-stakes approvals (a PIN behind
   an auth-capability service), or keep one password (I-8)? The triage argues a PIN limits damage
   if a kid watches it typed; it also adds a second secret to manage. **Default if unanswered:** keep
   one password (no change).
2. **T51 scope.** Earn-minutes now, or after the current tickets? **Default if unanswered:** its own
   ticket, not in the first batch.

## Coexistence

If upstream ships #11196 and a parent turns it on for an account this package manages, both enforce.
`omarchy-parent screen-time` is upstream's name (R-BUILD-4). One new `omarchy-kids-check` row (T54)
warns when an upstream screen-time engine is active for a Kids Mode kid, so a parent is not told two
systems are one.
