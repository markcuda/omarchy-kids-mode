# RFCs — Requests for Comments

An RFC is how a substantial idea becomes a decision the community has actually agreed to. Small things
(a new source, a typo, a backlog item) don't need one. Use an RFC when a proposal:

- changes the **architecture** (a layer's responsibilities, the account model, the progressive-level model);
- commits the project to a **dependency or technology** (a DNS provider, a sandbox tool, a UI toolkit);
- affects **child safety or privacy** in a way that's hard to reverse;
- spins up a **new satellite repo** or retires one;
- changes **how we work** (this process, governance, licensing).

## Lifecycle

| Stage | Where it lives | Exit criteria |
| --- | --- | --- |
| **0 · Idea** | Discussion or `type: idea` issue | Someone volunteers to write it up |
| **1 · Draft** | PR adding `rfcs/0000-<slug>.md` | Template complete; linked prior art; safety section filled |
| **2 · Review** | Open PR; a **shepherd** (maintainer ≠ author) is assigned; when discussion settles the shepherd calls a **7-day Final Comment Period** with a disposition (merge / close / park) | FCP ends with no unresolved written objection; ≥ 2 maintainer approvals for anything touching safety/privacy, 1 otherwise |
| **3 · Accepted** | Merged; number = PR number; `status: accepted` | Backlog items / workstream issue created |
| **4 · Implemented** | Status updated with links to the satellite repo / release | Shipped and documented |
| — **Withdrawn / Rejected / Superseded** | Merged with that status so the reasoning is preserved | — |

Every RFC has a **champion** who owns it (no champion for 30 days → `status: parked`, a first-class,
non-shameful outcome). Decisions are by **lazy consensus**: silence after FCP is agreement. Maintainers (see
`GOVERNANCE.md`) resolve deadlocks and can fast-track trivial RFCs.

**Does not need an RFC:** typos, new sources, research notes, backlog grooming, theme colour tweaks, anything
reversible in an afternoon. Anyone can comment; **parents and
teachers are explicitly invited** — an RFC that only engineers understand isn't done.

## Writing one

1. Copy `rfcs/0000-template.md` to `rfcs/0000-my-slug.md` (keep `0000` until merge).
2. Fill every section. "Not applicable" is a valid answer if you say why.
3. Open a PR titled `RFC: <title>`. Add the `type: rfc` label.
4. When merged, a maintainer renames it to the PR number (`0042-my-slug.md`) and updates the index below.

Big accepted RFCs usually also produce an ADR in `docs/decisions/` (the *what we decided*, short) — the RFC
keeps the full discussion.

## Index

| # | Title | Status | Layer(s) |
| --- | --- | --- | --- |
| — | _none yet_ | | |
