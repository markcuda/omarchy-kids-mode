# 0003: Every cited source must be verified by a human; AI-generated links are quarantined

- **Status:** accepted
- **Date:** 2026-09-01
- **Deciders:** @markcuda (founding)

## Context

The project's first input was an AI-generated blueprint whose 257-entry bibliography contained ~22
fabricated or placeholder URLs and ~30 dead links (see `research/sources-audit/`). Several architectural
claims in it (bootloader, plugin system, UI toolkit) turned out to be unverified. A child-safety project
cannot build on hallucinated foundations.

## Decision

1. `research/sources.md` is the **only** citable source registry. Every row carries a status
   (`verified` / `search-only` / `unverified` / `dead`), an accessed date, and who verified it.
2. Docs in `docs/` may cite only `verified` sources. Research notes may cite others but must label them.
3. AI-assisted writing is welcome and must be **disclosed in the PR**; the author is responsible for
   opening every link and checking every claim.
4. AI-generated inputs are kept in `research/archive/` with a warning header, never in `docs/`.

## Consequences

- Positive: trustworthy docs; newcomers can rely on what they read.
- Negative: slower; mitigated by the `📚 Add a source` issue form and by weekly link checks in CI.
