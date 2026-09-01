# Architecture Decision Records

Short, numbered records of decisions that shape the project — the **what and why**, not the debate
(that lives in the RFC or issue linked from each record). Format is MADR-style, kept minimal.

- New decision → copy `0000-template.md` to `NNNN-short-slug.md` (next number), open a PR.
- Reversing a decision → write a *new* ADR that supersedes the old one; never edit history.
- Statuses: `proposed` · `accepted` · `deprecated` · `superseded by NNNN`.

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions as ADRs | accepted |
| [0002](0002-planning-repo-and-satellite-repos.md) | This repo is the plan; code ships in satellite repos | accepted |
| [0003](0003-verification-standard-for-sources.md) | Every cited source must be verified by a human; AI-generated links are quarantined | accepted |
