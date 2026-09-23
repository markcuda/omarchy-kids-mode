# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the
codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root (if it exists), or
- **`CONTEXT-MAP.md`** at the repo root if it exists: it points at one `CONTEXT.md` per context.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest
creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and
`/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

This repo already carries deep written context — `SPEC.md` (the source of truth), `AGENTS.md` (the
working rules), `docs/*.md` (one per command/surface), and `docs/phase1/DECISIONS-NEEDED.md` (owner
decisions). Treat those as the domain model for now; a `CONTEXT.md`/`ADR` set can be added later via
`/grill-with-docs` if the vocabulary proves worth compressing.

## File structure

Single-context repo (this repo):

```
/
├── CONTEXT.md            (not yet; SPEC.md + docs/ serve this today)
├── docs/adr/             (not yet)
└── docs/                 (per-command and per-surface records)
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a
test name), use the term as defined in `SPEC.md` and `docs/*.md`. Don't drift to synonyms.

## Flag ADR conflicts

If your output contradicts an existing decision record (`docs/phase1/DECISIONS-NEEDED.md`, a
`docs/*.md` judgment call), surface it explicitly rather than silently overriding.
