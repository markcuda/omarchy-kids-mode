# 0002: This repo is the plan; code ships in satellite repos

- **Status:** accepted
- **Date:** 2026-09-01
- **Deciders:** @markcuda (founding)

## Context

The community wants one place for research, ideas, a backlog and a plan of attack — but the actual
deliverables (setup tool, shell/UI, themes, DNS config, games) have different owners, languages, release
cadences and upstream relationships. Omarchy's own ecosystem favours small, single-purpose repos
(themes, tools) over monoliths.

## Decision

`omarchy-kids-mode` (this repo) holds **only** research, architecture, RFCs, decisions, the backlog and a
catalog of projects. Every buildable thing lives in its **own satellite repo**, listed in `projects/README.md`
with a status. Satellite repos link back here for design context and inherit `SECURITY.md` and the
Code of Conduct unless they explicitly override.

## Consequences

- Positive: people can chunk off work without stepping on each other; a theme author never needs to
  understand the DNS stack; this repo stays readable.
- Negative: cross-repo coordination costs; mitigated by the catalog, shared labels and RFCs for interfaces.
- Follow-ups: decide org vs personal namespace (see `GOVERNANCE.md` open questions); define the minimal
  README/contract a satellite repo must carry.
