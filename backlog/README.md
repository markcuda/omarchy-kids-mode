# Backlog

_status: draft · updated 2026-09-01_

**Once this repo is on GitHub, Issues + a Projects board are the canonical backlog.** The files here are the
**seed** — what the research surfaced, chunked so people can claim pieces — and the conventions that keep the
board legible.

- `backlog.md` — seeded items by layer, with a proposed priority and effort. Convert to issues as claimed.
- `workstreams.md` — larger chunks that deserve an owner and probably a satellite repo.

## Labels (proposed taxonomy)

| Group | Labels | Rule |
| --- | --- | --- |
| **type:** | `idea` · `research` · `source` · `safety` · `workstream` · `rfc` · `docs` · `kid-test` · `bug` | exactly one |
| **layer:** | `L1` … `L11` · `community` | one or more |
| **status:** | `triage` · `needs-verification` · `needs-champion` · `ready` · `in-progress` · `in-fcp` · `blocked` · `parked` · `done` · `wontfix` | exactly one; `triage` is the default |
| **priority:** | `p0-quick-win` · `p1` · `p2` · `later` | set at triage |
| **effort:** | `S` (an evening) · `M` (a weekend) · `L` (weeks) | set at triage |
| **age:** | `3-5` · `5-7` · `8-10` · `11-13` · `13+` | when relevant |
| flags | `good first issue` · `help wanted` · `kid-tested` (maintainer-applied evidence) · `needs-parent-input` · `needs-upstream` · `safety` | as they apply |

The canonical list is `.github/labels.yml` (synced by CI).

## Projects board (proposed fields)

Status (Triage → Ready → In progress → In review → Done) · Layer · Priority · Effort · Age · Owner ·
Phase (0–4 from `ROADMAP.md`).

## Triage rules

1. New issues get `status: triage`. A maintainer or layer lead labels type/layer/priority/effort within a week.
2. Anything citing an unverified claim gets `needs-verification` before `ready`.
3. `p0-quick-win` is reserved for things that reduce the "pop-up" risk or unblock Phase 1 decisions.
4. Claimed = assigned. Unassigned + `ready` = fair game. Say "I'm on it" in the issue.
5. Stale `in-progress` (30 days, no comment) politely returns to `ready`.
