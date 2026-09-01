# Research

_status: living · updated 2026-09-01_

Everything we know, and how well we know it.

| Folder / file | What it is |
| --- | --- |
| `sources.md` | **The source registry.** Every citable source with status, accessed date, verifier, and layer tags. Cite as `[S-nnn]`. |
| `reports/` | Deep-dive reports (01–07) produced 2026-09-01 by AI research agents with live web verification, then reviewed. Each has a *Blueprint claims checked* table and a *Sources* list with statuses. |
| `prior-art/` | Short notes on specific precedents (one distro/product/tool per file). |
| `community/` | Synthesised signal from Discord/Discussions — what people asked for, in their words. |
| `sources-audit/` | Automated HTTP audit of the original blueprint's 257-entry bibliography (198 unique URLs). |
| `archive/` | Inputs we started from, kept verbatim with a warning header. Not citable. |
| `tools/` | Generators: `merge_sources.py` rebuilds `sources.md`/`sources.csv` from the reports; `audit_blueprint_bibliography.py` produced the blueprint audit. |

## Reports

| # | Report | Layers | Read it for |
| --- | --- | --- | --- |
| 01 | Omarchy platform: current state & extension points | L11, L5 | What Omarchy actually is today; how to extend it |
| 02 | Prior art: kids/educational Linux & parental-control tooling | all | What worked, what died, what's reusable on Arch + Hyprland |
| 03 | System hardening, privilege separation & sandboxing | L1, L2, L4 | Account model options; boot lock-down; the anti-bypass matrix |
| 04 | Network, DNS & browser safety | L3 | The quick-win stack and its limits |
| 05 | Apps, games, learning tools & themes | L7, L8 | Starter packs; theme guidelines; the "top 3 apps" answer |
| 06 | OSS planning-repo & governance best practices | community | Why this repo is shaped the way it is |
| 07 | Pedagogy, age bands, kid/parent UX, AI & policy | L5, L6, L10 | Age-band → Level → preset mapping; the AI stance; regulation |

## Adding a research note

1. Copy the header from any report; set `status: draft`.
2. Put it in `prior-art/` (single subject) or `reports/` (multi-source deep dive).
3. Register every source in `sources.md` (or via the 📚 issue form) — with the date you opened it.
4. Label claims: **verified** (you read it), **inferred** (your reasoning), **opinion**.
5. Open a PR; mention in Discord.
