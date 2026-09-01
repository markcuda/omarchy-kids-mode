# 0001: Record architecture decisions as ADRs

- **Status:** accepted
- **Date:** 2026-09-01
- **Deciders:** @markcuda (founding)

## Context

Kids Mode spans a dozen layers and many contributors with little free time. Decisions made in Discord
evaporate; newcomers re-litigate them. We need a durable, skimmable record.

## Decision

We keep Architecture Decision Records in `docs/decisions/`, MADR-style, one file per decision, numbered,
never edited after acceptance (superseded instead). Substantial proposals go through `rfcs/` first; the ADR
captures the outcome.

## Consequences

- Positive: newcomers can read ~10 short files and know why things are the way they are.
- Negative: slight ceremony; mitigated by the tiny template.
- Follow-ups: link ADRs from the relevant layer docs.
