# Governance

_status: draft · updated 2026-09-01 — founding structure; expect this to be revised by RFC once there are
more than three regular contributors._

## What this project is

**Omarchy Kids Mode** is an **independent community project** building child-safe, fun and educational
features *for* Omarchy. **It is not affiliated with, endorsed by, or maintained by David Heinemeier Hansson,
37signals/Basecamp, the Omacom Foundation, or the Omarchy project.** Where members of the Omarchy team
participate, they do so as community members. Anything we hope to see upstream is proposed through upstream's own
process (Discussions > Suggestions), on upstream's terms. Omarchy has no published trademark/naming policy
(report 06); we follow the Rust-style rule — never appear official — and will rename if asked.

## Roles

| Role | Who | Does |
| --- | --- | --- |
| **Maintainers (council of 3–5)** | @markcuda (founding); seats filled by nomination + no objection in 7 days; path: two merged RFCs/notes or sustained triage | Triage, merge, shepherd RFCs, resolve deadlocks, hold the security inbox, keep the roadmap honest |
| **Layer leads** | Whoever claims a layer or workstream and keeps it moving | CODEOWNER for that path; first reviewer for its RFCs |
| **Contributors** | Anyone with a merged PR, a triaged idea, or a verified source | Everything else |
| **Kid testers** | Children of contributors, via their parent | The only people whose opinion actually matters; never identified in the repo |

## How decisions get made

- **Small things** (typos, sources, backlog grooming): just do it; one maintainer approval.
- **Substantial things**: an RFC (`rfcs/README.md`). Lazy consensus after ≥ 7 days; blocking objections must
  come with a reason and, ideally, an alternative.
- **RFCs** have a **champion** (the author or a volunteer who owns it — no champion after 30 days → parked) and a
  **shepherd** (a maintainer who is not the author) who may call a **7-day Final Comment Period** with a stated
  disposition (merge / close / park) once discussion stops being constructive. Objections during FCP are written
  in the PR and propose an alternative.
- **Deadlocks**: maintainers decide by simple majority; if tied, the founding maintainer decides for the first
  12 months and records why in an ADR; a governance review ADR is scheduled at month 6. We'd rather ship a
  documented imperfect decision than stall.
- **Discord is for exploring; GitHub is for deciding.** Nothing decided in Discord binds until the champion
  summarises it into the issue/RFC.
- **Safety trumps velocity.** Any maintainer may pause a merge that plausibly weakens child safety or privacy
  until it has a threat-model entry.

## Namespaces and naming

- This repo: `omarchy-kids-mode` (planning). Satellite repos: `omarchy-kids-<thing>` (e.g. `omarchy-kids-dns`,
  `omarchy-kids-theme-<name>`), following Omarchy's `omarchy-*` convention.
- **Recommendation (report 06): a GitHub org `omarchy-kids`** with this hub repo plus `omarchy-kids-*` code repos
  and an org-level `.github` for shared health files — bus factor, teams for CODEOWNERS, org-wide Projects.
  **Blockers:** the name is already used by `jfuerwentsches/omarchy-kids` (OQ-15) and needs a courtesy post in the
  Omarchy Discord (OQ-9). Until both are settled the repo lives under a personal namespace.

## Money

There is none. If sponsorship ever appears, it goes through a transparent process decided by RFC first.

## Changing this document

By RFC, like everything else substantial.
