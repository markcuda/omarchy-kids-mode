# OSS Planning-Repo & Governance Best Practices

_Research report · Omarchy Kids Mode · 2026-09-01 · status: draft_

Scope: how to run a **planning / research / RFC repository** for a community satellite project of Omarchy, using GitHub features as they exist today, with concrete, copy-ready recommendations. No code is proposed here; this is the operating system for deciding what to build.

---

## TL;DR

- **Upstream facts (verified):** Omarchy is MIT-licensed, copyright David Heinemeier Hansson; the canonical repo now lives at **`omacom/omarchy`** (`basecamp/omarchy` redirects there); 36.7k stars; tagline "Beautiful, Modern & Opinionated Linux". The README/manual contain **no trademark or naming guidance** for community projects [S30][S31]. Existing community projects (try-omarchy, omarchythemes.com, omarchynews.com) all carry a "not affiliated with 37signals/Basecamp" disclaimer [S53][S54][S55]. Do the same.
- **Process model:** borrow Astro's four-stage funnel (Discussion → Issue → RFC PR → Ship) [S8], Kubernetes' "number = tracking-issue number" [S3], Nix's shepherd-led discussion with authority to call a Final Comment Period [S9], and Rust's 10-day FCP with explicit disposition [S1]. Champions are mandatory from Stage 1 (TC39, Astro, PEP sponsor) [S4][S5][S8].
- **Two record types, not one:** RFCs (forward-looking, "should we build X") and ADRs in MADR 4.0 format (backward-looking, "we decided Y because") [S22][S23]. Home Assistant runs exactly this split: Discussions for debate, `adr/NNNN-*.md` for outcomes [S6][S7].
- **GitHub surfaces (verified 2026):** Discussions for Stage 0 ideas/Q&A/show-and-tell (six default categories, max 25) [S19][S20]; YAML issue forms for structured proposals/research requests [S11]; Discussion category forms for the Ideas category [S12]; Projects v2 with single-select/iteration/number custom fields for the backlog [S14]; org-level public `.github` repo for shared health files (not LICENSE) [S10]; private vulnerability reporting for "safety bypass" reports [S13].
- **Licensing:** CC-BY-4.0 for prose, MIT for code samples/configs, expressed with SPDX identifiers and a REUSE-style `LICENSES/` directory [S27][S34]. DCO sign-off (`Signed-off-by:`), not a CLA [S26]. AI-assisted contributions allowed with an `Assisted-by:` trailer and full human accountability (Fedora/Linux-kernel model) [S35][S36]; QEMU-style blanket bans are the minority path and a poor fit for a docs repo [S32].
- **Governance:** "maintainers council + lazy consensus + BDFL-lite tie-break", written in a one-page GOVERNANCE.md, plus an explicit **relationship-to-upstream statement** [S28]. Use a GitHub **org** (`omarchy-kids`) with a hub planning repo and `omarchy-kids-*` code repos catalogued in `PROJECTS.md`.
- **Child-safety specifics:** treat kid-found bypasses as security vulnerabilities (private report, coordinated disclosure, credit to the parent account, never the child); a no-telemetry/local-only PRIVACY.md; Contributor Covenant 3.0 (current "Latest Version") with its four-step enforcement ladder [S24][S25]; both GitHub and Discord require users to be 13+ [S51][S52], so children participate only via a parent-proxy "kid-test report" form; an ACCESSIBILITY.md following W3C WAI statement structure [S37]; a gender-neutral defaults rule in the style guide.

---

## Findings

### 1. Exemplar planning / RFC repositories

| Repo | Where ideas start | Formal artifact | Numbering | Lifecycle / statuses | Decision authority | Graduation to implementation | Anti-bikeshedding device |
|---|---|---|---|---|---|---|---|
| **rust-lang/rfcs** [S1] | Zulip / forum pre-RFC | PR adding `text/NNNN-*.md` | PR number | Open → FCP (10 calendar days, ≥5 business) → merged "active" / closed / postponed | Relevant sub-team; all members sign off before FCP | Tracking issue in `rust-lang/rust`; RFC is "active", not "implemented" | Sub-team triage labels; FCP with stated disposition; "postponed" label |
| **reactjs/rfcs** [S2] | Informal | `text/0000-my-feature.md` → renamed to PR # | PR number | Active → implementation → FCP (3 days) | Core team | Follow-up PRs amend the RFC as design evolves | Explicit list of what does *not* need an RFC |
| **kubernetes/enhancements (KEP)** [S3] | Tracking issue | `keps/sig-x/NNNN-title/README.md` + `kep.yaml` | Tracking-issue number ("easy breadcrumb") | provisional → implementable → implemented / deferred / rejected / withdrawn / replaced; stage alpha/beta/stable | Owning SIG; reviewers + approvers in metadata | Graduation Criteria + milestones per stage | Goals / Non-Goals sections; Risks & Mitigations; PRR gate |
| **TC39 proposals** [S4] | Stage 0 strawperson | Public proposal repo + spec text | Stage number | 0 → 1 → 2 → 2.7 → 3 → 4 | Committee consensus at every stage | Stage 4 = two shipping implementations + tests | Champion required at Stage 1; "committee has chosen a preferred solution" at Stage 2 freezes scope |
| **python/peps (PEP 1)** [S5] | Discourse Ideas category ("vetting an idea publicly... is meant to save the potential author time") | PEP in RST with headers | PEP editor assigns | Draft → Accepted → Final (or Provisional / Deferred / Rejected / Withdrawn / Superseded) | Steering Council or PEP-Delegate | Reference Implementation section | Sponsor/champion required; PEP editors review form, not merit; "Rejected Ideas" and "Open Issues" sections |
| **home-assistant/architecture** [S6][S7] | GitHub Discussion per topic | `adr/NNNN-title.md` once decided | Sequential 0001–0022 | Discussion → ADR | Core maintainers | ADR binds core repo policy (e.g. 0008 Code Owners, 0022 Integration Quality Scale) | "Please do not go off-topic, create a new topic instead" |
| **withastro/roadmap** [S8] | Stage 1 Discussion (no requirements) | Stage 3 RFC PR from template | Stage number + issue | 1 Proposal → 2 Accepted (Issue, champion) → 3 RFC & dev (PR, living doc) → 4 Ship (FCP) | TSC (L2+ maintainers) vote | "Development can begin before approval"; stale Stage-2 items can be rejected | Stage gates move quickly from "should we?" to "how do we?" |
| **NixOS/rfcs** [S9] | PR + nomination window | `rfcs/NNNN-*.md` | PR number | Draft → shepherd nomination → discussion → FCP (10 days) → merge / close / withdraw | RFC Steering Committee picks 3–4 shepherds (author excluded); SC commits decision | Accepted RFC is the mandate; implementation tracked elsewhere | Shepherds "shall step in with a motion for FCP" when discussion stops being constructive |

**What works, distilled**

1. **Cheap front door, expensive back door.** Every exemplar makes Stage 0 free (a Discussion, a Discourse post, a Zulip thread) and raises the bar per stage. Astro states it plainly: "Requirements: None!" for Stage 1 [S8].
2. **A named human owns each proposal.** TC39 champions, PEP sponsors, Astro champions, Nix shepherds. Proposals without a champion die on purpose.
3. **Number = tracking issue.** KEP's rationale is the strongest: the number is a "breadcrumb for people to find the issue where the current state of the KEP is being updated" [S3]. Rust/React use PR numbers, which is fine but the PR closes; the issue lives.
4. **Time-boxed close.** FCP of 3 (React) to 10 (Rust, Nix) days with a stated disposition (merge / close / postpone). Without an FCP, threads never end.
5. **Explicit non-goals.** KEP's Goals/Non-Goals and PEP's Rejected Ideas / Open Issues sections pre-empt re-litigation.
6. **Separate "we agreed in principle" from "it shipped".** Rust's "active" and Astro's "Accepted Proposal" both mean "we like it; nobody has built it". Track build status elsewhere (Projects board / PROJECTS.md).
7. **Write down what does NOT need an RFC.** React's list (refactors, warnings, perf, invisible changes) prevents process creep [S2].

**What doesn't work / traps**

- PEP-style editor gatekeeping and RST tooling is heavy for a volunteer community; keep Markdown and issue forms.
- Rust's "all sub-team members must sign off before FCP" is safe but slow; with 3–5 maintainers, use lazy consensus (silence = assent) with a minimum of two approvals.
- TC39's six stages are overkill; four stages (Astro) is the sweet spot.

### 2. GitHub mechanics (verified against docs.github.com, 2026-09-01)

- **Community health files.** Supported defaults: CODE_OF_CONDUCT.md, CONTRIBUTING.md, FUNDING.yml, SECURITY.md, SUPPORT.md, issue/PR templates + `config.yml`, and discussion category forms. Lookup precedence: `.github/` → root → `docs/`. Issue templates must be in `.github/ISSUE_TEMPLATE`, discussion forms in `.github/DISCUSSION_TEMPLATE`, FUNDING.yml in `.github/`. An org-level **public** `.github` repository supplies defaults to every repo lacking its own file. "You cannot create a default license file." [S10] GOVERNANCE.md is not in the inherited list; put it in each repo root.
- **Community Standards checklist** (Insights → Community Standards) checks Description, README, Code of conduct, Contributing, License, Security policy, Issue templates, PR template [S21]. Target 8/8 on day one.
- **Issue forms (YAML).** Required top-level keys `name`, `description`, `body`; optional `assignees`, `labels` (must pre-exist), `title`, `type` (org issue type), `projects` (`OWNER/NUMBER`). Body element types: `markdown`, `input`, `textarea` (supports `render` for code blocks), `dropdown` (`multiple: true`), `checkboxes`. Common attributes: `label`, `description`, `placeholder`, `value`, `options`, `default`, `validations.required`. Files live at `.github/ISSUE_TEMPLATE/*.yml`; `config.yml` sets `blank_issues_enabled` and `contact_links` [S11].
- **Discussion category forms.** `.github/DISCUSSION_TEMPLATE/<category-slug>.yml`, same form schema; one per category; not supported for polls; must be on the default branch [S12].
- **Discussions vs Issues.** Discussions are for "conversations about the project's direction and future in an open-ended format"; open-ended issues can be converted to discussions; discussions can be pinned, locked, labelled [S19]. Default categories: Announcements, General, Ideas, Polls, Q&A, Show and tell; formats: open-ended, question/answer, announcement (plus polls); **max 25 categories**; announcements cannot be transferred between repos [S20]. Rule of thumb: *Discussion = not yet actionable; Issue = someone owns a next action.*
- **Projects v2 fields.** Custom: text, number, date, single select (options with colour + description), iteration. Built-in/special: issue type, parent issue & sub-issue progress, linked PRs, reviewers, plus org-level "issue fields" for priority/effort/dates [S14]. The dedicated `about-fields` URL is now 404 [S38]; the parent `understanding-fields` page is the live one.
- **CODEOWNERS.** Searched in `.github/`, root, `docs/` (first found wins); gitignore-style patterns, `@user` / `@org/team` / verified email; **last matching pattern wins**; `!` negation and `\#` escaping unsupported; file < 3 MB; must exist on the PR base branch; with "Require review from Code Owners", approval from *any* listed owner suffices [S15].
- **SECURITY.md.** Created via Security → Policy; should state supported versions and how to report [S18]. **Private vulnerability reporting** is enabled per repo (Settings → Advanced Security → Private vulnerability reporting) or org-wide; reporters get a "Report a vulnerability" button on the Advisories page; admins and security managers are notified [S13].
- **Rulesets vs classic branch protection.** Rulesets are named, stackable, viewable by anyone with read access, and toggleable (Active / Disabled; "Evaluate" exists for metadata-restriction testing) [S16][S17]. The docs' lead sentence ties rulesets to Team/Enterprise for *organization-level* use; the fetched pages did not conclusively state Free-plan availability for public repositories at repo level [S16][S17]. **Action:** open Settings → Rules; if "Rulesets" is present, use it; otherwise classic branch protection delivers the same core needs (require PR, 1–2 approvals, status checks, block force-push, restrict deletion).
- **Labels-as-code.** Both `EndBug/label-sync` (YAML/JSON config; can merge "global" + "local" sets) and `r7kamura/github-label-sync-action` (wraps Financial-Times `github-label-sync`; `.github/labels.yml`; deletes unlisted labels unless `allow_added_labels: true`) are current [S39][S40][S41]. Pick one and commit `.github/labels.yml`.
- **DCO enforcement.** The Probot DCO app (now `dcoapp/app`) checks `Signed-off-by` on every commit and supports `.github/dco.yml` [S42]; a 2025–26 community thread warned of a possible shutdown of the hosted app [S43], so keep a fallback Action. GitHub also has a repo setting to require sign-off on web-based commits [S44].
- **all-contributors.** Bot updates README on `@all-contributors please add @user for docs, ideas, review` using the emoji key [S45][S46]. Good for a docs-heavy project where "contribution" ≠ "commit".
- **Dependabot for Actions.** Add `.github/dependabot.yml` with `package-ecosystem: github-actions`, weekly. (Standard practice; not separately fetched.)

### 3. Documentation patterns

- **ADRs: MADR 4.0.0** (2024-09-17), "Markdown Any Decision Records", files `NNNN-title-with-dashes.md`, full template: YAML front matter `status` (proposed | rejected | accepted | deprecated | superseded by ADR-0123), `date`, `decision-makers`, `consulted`, `informed`; sections Context and Problem Statement → Decision Drivers → Considered Options → Decision Outcome (+ Consequences, + Confirmation) → Pros and Cons of the Options → More Information. Dual-licensed MIT/CC0, so copying the template is unencumbered [S22][S23]. Home Assistant's 22 ADRs are a working example of this exact shape in a community repo [S7].
- **RFC template.** Merge Rust's headings [S1] with KEP's gates [S3] and PEP's honesty sections [S5]: Summary · Motivation · Goals / Non-Goals · Guide-level explanation (what a *parent* sees) · Reference-level explanation (what a *maintainer* builds) · Safety & Privacy considerations (kids-specific, mandatory) · Drawbacks · Alternatives · Prior art · Unresolved questions · Future possibilities · Graduation criteria (what "done" means, which sub-repo owns it).
- **Research note + source registry.** Every research note carries a front-matter block (`title`, `author`, `date`, `status: draft|reviewed|superseded`, `question`, `confidence`) and a **Sources** table with `id`, `title`, `url`, `accessed`, `status: VERIFIED|SEARCH-ONLY|DEAD`, `note` — precisely the format used in this report. Keep a repo-wide `research/SOURCES.md` index so links are checked by CI once, not per note.
- **Open-questions register.** A single `OPEN-QUESTIONS.md` table: `id`, `question`, `raised-in`, `owner`, `status`, `resolved-by (ADR/RFC link)`. PEP's "Open Issues" section is the per-document version [S5]; the register is the cross-cutting view.
- **Glossary.** `GLOSSARY.md`; one line per term; link from templates. Kids-mode has domain terms (age band, guardian, allowlist, bypass, kiosk, session) that will otherwise be defined five different ways.
- **Roadmap.** `ROADMAP.md` = human-readable narrative per horizon (Now / Next / Later / Not planned) generated from the Projects board; GitHub Milestones for dated targets only. Astro keeps roadmap = the RFC repo itself [S8]; for a small team a single file plus the board is enough.
- **CHANGELOG for docs.** Yes, but lightweight: `CHANGELOG.md` with one line per merged RFC/ADR/research note, newest first. It doubles as the "what happened this month" Discord post.
- **Diátaxis.** Organise any user-facing docs into tutorials, how-to guides, reference, explanation [S29]. For the planning repo itself: `docs/explanation/` (why kids mode), `docs/how-to/` (how to write an RFC, how to run a kid test), `docs/reference/` (templates, labels, glossary).
- **Docs CI.** `markdownlint-cli2` (config in `.markdownlint-cli2.jsonc` — the recommended, comment-friendly format) [S60]; `lycheeverse/lychee-action` with a root `.lycheeignore` (one regex per line) on PRs and a weekly schedule [S59]; `cspell` with a project dictionary (`.cspell.json`) for names like Omarchy, Hyprland, Waybar; Prettier for Markdown formatting (or rely on markdownlint alone — pick one to avoid fights); `.editorconfig` (utf-8, lf, final newline, 2-space YAML).

### 4. Licensing

- **Omarchy:** MIT, "Copyright (c) David Heinemeier Hansson" [S30]; repo `omacom/omarchy` [S31]; related official repos `omacom/omarchy-pkgs` and `basecamp/omarchy-basecamp-plugin` [S57][S58].
- **Docs repo licence.** choosealicense: CC-BY-4.0 "Permits almost any use subject to providing credit and license notice... Not recommended for software"; SPDX `CC-BY-4.0` [S27]. Therefore **dual**: prose under CC-BY-4.0, code samples/configs/scripts under MIT (matching upstream so snippets can flow to and from Omarchy without relicensing).
- **Expressing it.** REUSE: per-file `SPDX-FileCopyrightText:` and `SPDX-License-Identifier:` headers (or a `REUSE.toml` for bulk paths), a `LICENSES/` directory containing `CC-BY-4.0.txt` and `MIT.txt` named by SPDX identifier, verified with `reuse lint` [S34]. Keep a root `LICENSE` (CC-BY-4.0 full text, so GitHub's licence detector and the Community Standards checklist see it) plus `LICENSE-CODE` (MIT) and a README "License" section stating the split.
- **DCO, not CLA.** DCO 1.1 has contributors certify origin, licence rights, and that the record "is maintained indefinitely" [S26]; sign with `git commit -s`. A CLA needs a legal entity to receive it; this project has none. Enforce with the DCO app [S42] or an Action; also require sign-off on web commits [S44].
- **AI-assisted contributions — the 2025–26 landscape.**
  - *Ban:* QEMU "declines all contributions believed to include or derive from AI-generated content" because contributors cannot certify DCO for it; the policy "may evolve as AI tools mature" [S32]; Gentoo and NetBSD are in the same camp, and QEMU has been reported to be considering a disclosure-based relaxation [S49].
  - *Disclose:* Fedora's policy (approved Oct 2025 per press coverage [S47]; principles: contributor accountability, transparency, "AI should not make the final determination on whether a contribution is accepted" [S36]) recommends an `Assisted-by:` trailer. The Linux kernel formalised `Assisted-by: LLM [TOOL1] [TOOL2]`, "AI agents MUST NOT add Signed-off-by tags. Only humans can legally certify the Developer Certificate of Origin", and the human "Taking full responsibility for the contribution" [S35]. Rocky Linux and Debian are following the disclose model [S65][S50]; the `Assisted-by` trailer is becoming a de-facto standard [S48].
  - *Reports, not just code:* the flood of AI-generated security reports is what pushed curl to end its bug bounty (Jan 2026, per coverage) and prompted an OpenSSF working-group thread on "AI slop" [S66]. A kids-safety project will attract exactly this; require human reproduction steps in every safety report.

### 5. Governance for a satellite of an opinionated upstream

- **Models** (opensource.guide): BDFL, meritocracy, liberal contribution; "Establish a clear process for how someone can become a maintainer... and write it into your GOVERNANCE.md"; governance "needn't be comprehensive at launch" [S28]. For a 5–30 person volunteer project the workable hybrid is: **maintainers council (3–5) + lazy consensus + BDFL-lite tie-break** (founding lead breaks ties for the first 12 months, then the council votes).
- **Rough consensus, written down.** Decisions happen in the RFC/ADR PR, never in Discord. Discord is for synchronous exploration; anything that should survive must be summarised into the issue by the champion.
- **Relationship to upstream.** No Omarchy trademark or naming policy exists publicly [S31]. The Rust Foundation policy is the best analog: using the name "in the name of crates or code repositories... is allowed when referring to use with or compatibility with" the language, but never in ways that "appear (to a casual observer) official, affiliated, or endorsed" — words like "official" are out [S33]. Existing Omarchy community projects already converge on "independent, not affiliated with 37signals/Basecamp" wording [S53][S54][S55]. Adopt the same and, as a courtesy, post the intent in the Omarchy Discord (the manual points users to `#omarchy-help` and `#omarchy-on-other` [S56]) so DHH/maintainers can object early.
- **Org vs personal repo.** Org: shared ownership (bus factor), teams for CODEOWNERS, org-wide Projects, org `.github` defaults, transferable if upstream ever adopts the work. Personal: none of that. **Use an org.**
- **Naming.** Org `omarchy-kids`; hub repo `omarchy-kids/omarchy-kids` (planning + catalogue); code repos prefixed `omarchy-kids-<thing>` so they are searchable and self-describing when forked (ecosystem precedent: `omarchy-docker`, `omarchy-pkgs`, `omarchy-basecamp-plugin` [S57][S58]). Avoid "mode" in repo names (it's a feature label, not a project name); keep "Omarchy Kids Mode" as the human-facing programme name.
- **Monorepo-of-docs + multi-repo-for-code.** The hub holds research, RFCs, ADRs, roadmap, catalogue. Each accepted RFC's Graduation Criteria names the sub-repo; the sub-repo README links back to the RFC; the hub's `PROJECTS.md` lists it with a status badge and the RFC number. This mirrors Rust (rfcs → rust-lang/rust tracking issue) and KEP (kep → SIG repos) [S1][S3].

### 6. Child-safety-specific practices

- **Safety-bypass disclosure.** Extend SECURITY.md: "A way for a child to leave Kids Mode, reach unfiltered content, or disable a guardian control is a security vulnerability." Route via private vulnerability reporting [S13]; 7-day acknowledgement, 90-day coordinated disclosure (shorter if actively exploited); publish an advisory and an ADR when fixed; credit the *reporting adult's* GitHub handle only.
- **Privacy stance.** `PRIVACY.md`: no telemetry, no accounts, no cloud, all state local under the guardian's control; any future opt-in network feature requires its own RFC with a Safety & Privacy section (mirrors Fedora's "strictly opt-in" rule for AI features [S36]).
- **Code of conduct.** Contributor Covenant **3.0** is the site's "Latest Version" [S25]: pledge, Encouraged/Restricted Behaviors, Reporting, "Addressing and Repairing Harm" with a Warning → Temporarily Limited Activities → Temporary Suspension → Permanent Ban ladder; CC BY-SA 4.0; Markdown at the version page [S24][S67]. 2.1 remains widespread and has 40+ translations; 3.0 is preferable here because the repair-oriented ladder is exactly what a parent-heavy community needs.
- **Age gates.** GitHub requires users to be at least 13 [S51]; Discord likewise [S52]. Consequences: children never post directly; no child names, photos, voices, or exact ages in any channel; feedback arrives through a **parent-proxy "kid-test report"** issue form using age *bands*; screenshots must be scrubbed. Write this into `MODERATION.md` for both Discord and GitHub and enforce with the CoC ladder.
- **Accessibility.** `ACCESSIBILITY.md` following W3C WAI: commitment, standard applied (WCAG 2.2 for any UI), contact, known limitations in plain language ("videos do not have captions" rather than success-criterion numbers) [S37]; the WAI generator can draft it [S62].
- **Gendered defaults.** Style-guide rule: neutral avatars, colours, names and pronouns in examples and templates; "grown-up/guardian" not "mom/dad"; age-band, not gender, drives defaults.
- **"kid-tested" label.** Applied by a maintainer only after a parent-proxy kid-test report exists for that RFC/feature; it is evidence, not opinion.

---

## Recommended repo blueprint

### File tree (hub repo `omarchy-kids/omarchy-kids`)

```text
.
├── README.md                  # Front door: what/why, status, how to join, upstream disclaimer, licence split
├── GOVERNANCE.md              # Council, lazy consensus, FCP rules, tie-break, how to become a maintainer
├── CONTRIBUTING.md            # Stages, templates, DCO sign-off, Assisted-by rule, style guide link
├── CODE_OF_CONDUCT.md         # Contributor Covenant 3.0 + contact address
├── SECURITY.md                # Safety-bypass = vulnerability; private reporting; timelines; credit rules
├── PRIVACY.md                 # No telemetry / local-only stance for everything the programme ships
├── ACCESSIBILITY.md           # WAI-structured statement for docs + future UIs
├── MODERATION.md              # Discord + GitHub norms; no child PII; enforcement ladder
├── SUPPORT.md                 # Where to ask (Q&A Discussions, Discord channel), what not to ask here
├── LICENSE                    # CC-BY-4.0 full text (GitHub detector + Community Standards)
├── LICENSE-CODE               # MIT full text for code samples/configs
├── LICENSES/                  # REUSE layout: CC-BY-4.0.txt, MIT.txt
├── REUSE.toml                 # Bulk SPDX annotations (docs → CC-BY-4.0, code → MIT)
├── ROADMAP.md                 # Now / Next / Later / Not planned, regenerated from the board
├── PROJECTS.md                # Catalogue of sub-repos: name, RFC #, status badge, maintainer, last release
├── CHANGELOG.md               # One line per merged RFC/ADR/research note
├── GLOSSARY.md                # Domain terms (age band, guardian, allowlist, bypass, kiosk, session)
├── OPEN-QUESTIONS.md          # Cross-cutting register with owner + resolving ADR/RFC
├── rfcs/
│   ├── 0000-template.md       # RFC template (sections in §3)
│   └── NNNN-title.md          # Number = tracking issue number
├── adr/
│   ├── 0000-template.md       # MADR 4.0 template
│   ├── 0001-record-decisions-as-adrs.md
│   ├── 0002-licensing-split.md
│   └── 0003-relationship-to-upstream.md
├── research/
│   ├── README.md              # How to write a research note; status meanings
│   ├── SOURCES.md             # Repo-wide source registry (id, title, url, accessed, status, note)
│   ├── notes/NN-topic.md      # Individual research notes with front matter
│   └── reports/               # Longer reports (this file lives here)
├── docs/
│   ├── explanation/           # Why Kids Mode; threat model; design principles
│   ├── how-to/                # Write an RFC; run a kid test; spin out a sub-repo; triage
│   └── reference/             # Labels, board fields, templates, style guide
├── .github/
│   ├── ISSUE_TEMPLATE/        # YAML forms (list below) + config.yml
│   ├── DISCUSSION_TEMPLATE/ideas.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS             # rfcs/ adr/ → @omarchy-kids/maintainers; research/ → @omarchy-kids/researchers
│   ├── labels.yml             # Labels-as-code, synced by workflow
│   ├── dependabot.yml         # github-actions, weekly
│   ├── dco.yml                # DCO app config (if used)
│   ├── FUNDING.yml            # Omit until a legal recipient exists
│   └── workflows/
│       ├── docs-lint.yml      # markdownlint-cli2 + cspell + prettier --check
│       ├── links.yml          # lychee on PR + weekly cron
│       ├── labels.yml         # label-sync on push to main
│       ├── dco.yml            # Fallback Signed-off-by check
│       └── rfc-meta.yml       # Validates RFC/ADR front matter and numbering
├── .markdownlint-cli2.jsonc
├── .lycheeignore
├── .cspell.json
├── .editorconfig
└── .prettierrc
```

Org-level `omarchy-kids/.github` (public) carries CODE_OF_CONDUCT.md, CONTRIBUTING.md, SECURITY.md, SUPPORT.md and the PR template as defaults for every `omarchy-kids-*` code repo; each code repo still needs its own LICENSE [S10].

### Label taxonomy (`.github/labels.yml`)

| Prefix | Values | Notes |
|---|---|---|
| `type:` | idea, proposal, rfc, adr, research, task, bug, docs, meta | One per item; set by issue form |
| `stage:` | 0-idea, 1-explore, 2-research, 3-rfc, 4-accepted, 5-building, 6-shipped | Mirrors lifecycle; moves forward only via FCP |
| `status:` | needs-triage, needs-champion, needs-research, in-fcp, blocked, parked, rejected, superseded | Orthogonal to stage |
| `area:` | guardian-controls, content-filter, session-kiosk, theme-ui, launcher-apps, education, install-setup, accessibility, privacy, community, upstream | Extend via ADR only |
| `age:` | 3-5, 6-8, 9-12, 13+ | Multi-select allowed |
| `priority:` | p0-safety, p1-high, p2-normal, p3-low | p0 reserved for safety/privacy |
| `effort:` | xs, s, m, l, xl | T-shirt; hub work only |
| flags | `good first issue`, `help wanted`, `kid-tested`, `safety`, `needs-parent-feedback`, `upstream-blocked` | Standard GitHub names for the first two |

Colours: one hue per prefix family; `p0-safety` and `safety` red.

### Issue forms (`.github/ISSUE_TEMPLATE/`)

| Form | Auto labels | Fields |
|---|---|---|
| `proposal.yml` — Stage 1 proposal | `type:proposal`, `stage:1-explore`, `status:needs-champion` | Title; one-paragraph summary; problem for guardians/kids; age bands (dropdown, multiple); area (dropdown); link to originating Discussion (required); champion (checkbox "I volunteer"); safety/privacy impact (dropdown none/low/high); non-goals |
| `research-request.yml` | `type:research`, `stage:2-research` | Question to answer; why it blocks a proposal; links; desired deadline; volunteer |
| `adr-request.yml` | `type:adr` | Decision to record; options considered; who must be consulted |
| `kid-test-report.yml` — parent proxy | `type:task`, `needs-parent-feedback` → maintainer adds `kid-tested` | RFC/feature; age band (dropdown, required); what the child tried; what worked; what confused; what delighted; **no names/photos** notice in markdown block; consent checkbox |
| `sub-project.yml` — register a repo | `type:meta` | Repo URL; RFC number; maintainer; status; licence confirmation (MIT) |
| `docs-bug.yml` | `type:bug`, `type:docs` | Page; what is wrong; suggested fix |
| `config.yml` | — | `blank_issues_enabled: false`; contact links → Ideas Discussion, Q&A Discussion, **Report a safety bypass (private)**, Discord |

`PULL_REQUEST_TEMPLATE.md`: type of change; linked issue; checklist (DCO signed, `Assisted-by:` added if applicable, lint passes, sources registered, no child PII).

### Discussions categories (≤ 25 allowed [S20])

| Category | Format | Form | Purpose |
|---|---|---|---|
| Announcements | announcement | — | Merged RFCs, ADRs, monthly digest |
| Ideas | open-ended | `ideas.yml` (one-line pitch, who benefits, age band, prior art) | Stage 0; graduate by converting to a `proposal` issue |
| Q&A | question/answer | — | How does the process work; how does Omarchy X work |
| Research | open-ended | — | Share findings before writing a note |
| Show and tell | open-ended | — | Prototypes, themes, screenshots (scrubbed) |
| Polls | poll | not supported [S12] | Non-binding temperature checks only; decisions still go through FCP |
| Guardians' lounge | open-ended | — | Parents/teachers; strict no-child-PII rule pinned |

### Projects v2 board fields

| Field | Type | Values |
|---|---|---|
| Status | single select | Triage · Exploring · Researching · RFC drafting · In FCP · Accepted · Building (sub-repo) · Shipped · Parked · Rejected |
| Stage | single select | 0–6 (mirrors labels) |
| Area | single select | as label taxonomy |
| Age band | single select | 3-5 · 6-8 · 9-12 · 13+ · all |
| Priority | single select | p0-safety … p3-low |
| Effort | single select | xs … xl |
| Champion | text | GitHub handle |
| Sub-repo | text | `omarchy-kids/omarchy-kids-<x>` |
| FCP ends | date | set when FCP called |
| Target | iteration | monthly cadence |
| Kid-tested | single select | no · yes (link in issue) |

Views: "Triage" (Status = Triage), "Roadmap" (group by Stage), "Safety" (Priority = p0), "Needs champion".

### Proposal lifecycle

| Stage | Surface | Entry gate | Exit gate | Who |
|---|---|---|---|---|
| 0 Idea | Discussion (Ideas) | none | Anyone opens a `proposal` issue linking the thread | anyone |
| 1 Explore | Issue `type:proposal` | Summary, age band, safety impact filled | A champion volunteers; two maintainers agree it is in scope (lazy consensus, 7 days) | champion + maintainers |
| 2 Research | Issue + `research/notes/*` PR | Open questions listed | Research note(s) merged with VERIFIED sources; open questions moved to register | champion / researchers |
| 3 RFC | PR adding `rfcs/NNNN-title.md` (NNNN = issue #) | Template complete incl. Safety & Privacy and Graduation Criteria | Shepherd (a maintainer not the author) calls **FCP: 7 calendar days**, disposition stated (merge / close / park); no unresolved substantive objection; ≥2 maintainer approvals | shepherd |
| 4 Accepted | Merged RFC; ADR if a cross-cutting decision was made | — | Sub-repo created and registered in `PROJECTS.md` | maintainers |
| 5 Building | Sub-repo | RFC linked from README | Graduation criteria met | sub-repo maintainer |
| 6 Shipped | `PROJECTS.md` badge, CHANGELOG, Announcement | — | Superseded by later RFC | — |

Rules that keep it moving: no champion after 30 days → `status:parked`; any maintainer may call FCP; objections in FCP must be written in the PR and propose an alternative; Discord conversations are non-binding until summarised into the issue by the champion; "postponed/parked" is a first-class, non-shameful outcome (Rust) [S1].

### CI checks

| Workflow | Tool | Trigger | Gate? |
|---|---|---|---|
| docs-lint | markdownlint-cli2, cspell, prettier --check | PR | required |
| links | lychee-action + `.lycheeignore` | PR (changed files) + weekly cron (all) | required on PR; cron opens an issue |
| dco | dcoapp/app or fallback Action grepping `Signed-off-by` | PR | required |
| rfc-meta | small script: front matter present, `NNNN` matches linked issue, status ∈ allowed set | PR touching `rfcs/` or `adr/` | required |
| labels | label-sync from `.github/labels.yml` | push to main | — |
| dependabot | github-actions ecosystem, weekly | schedule | — |
| reuse-lint (optional) | `reuse lint` | PR | advisory until headers are backfilled |

Branch rules on `main`: require PR; 1 approval for `research/` and `docs/`, 2 for `rfcs/` and `adr/` (via CODEOWNERS + "require review from Code Owners"); required status checks; block force-push; restrict deletion; maintainers not exempt.

---

## Implications & recommendations

**Governance**
1. Ship `GOVERNANCE.md` v0 on day one: 3–5 named maintainers, lazy consensus with 7-day windows, FCP mechanics, founding-lead tie-break for 12 months, path to maintainership (two merged RFCs/notes + nomination + no objection in 7 days), and a scheduled review ADR at month 6. opensource.guide is explicit that early, incomplete governance beats none [S28].
2. Record the relationship to upstream as **ADR-0003** and in the README: "Omarchy Kids Mode is an independent community project. It is not affiliated with, endorsed by, or maintained by David Heinemeier Hansson, 37signals/Basecamp, or the Omarchy project." Post the intent in the Omarchy Discord before publicising; be prepared to rename if asked (Rust-style "no appearance of official status" is the safe interpretation absent a policy) [S33].
3. Decide in Discord, record on GitHub — never the reverse. Add a pinned Discord message linking the stage table.

**Licensing**
4. CC-BY-4.0 (prose) + MIT (code) with REUSE headers and `LICENSES/`; say so in README with SPDX expressions; require DCO sign-off; `Assisted-by:` trailer for AI-assisted work, human accountable, AI never the final reviewer [S26][S27][S34][S35][S36].
5. Sub-repos: MIT only (identical to upstream) so contributions can be offered upstream without friction [S30].

**Naming & structure**
6. GitHub org `omarchy-kids`; hub `omarchy-kids/omarchy-kids`; code repos `omarchy-kids-<thing>`; org `.github` for shared health files; `PROJECTS.md` as the catalogue with status badges and RFC numbers.
7. Number RFCs and ADRs by their tracking-issue number (KEP breadcrumb) [S3]; MADR 4.0 for ADRs [S23]; keep RFC and ADR as separate folders and separate templates.

**Child safety**
8. Enable private vulnerability reporting before the repo is announced; SECURITY.md defines "safety bypass" as a vulnerability class with timelines and credit rules [S13][S18].
9. Contributor Covenant 3.0 with a named, two-person reporting contact; `MODERATION.md` covering Discord + GitHub with the CC 3.0 ladder; no child PII anywhere; parent-proxy kid-test form; `kid-tested` label is maintainer-applied evidence [S24][S51][S52].
10. PRIVACY.md and ACCESSIBILITY.md are first-class, linked from README, and every RFC template carries a mandatory Safety & Privacy section.

---

## Open questions for the community

1. **Upstream blessing:** Will DHH / the Omarchy maintainers object to an org named `omarchy-kids`? Who asks, where, and what is the fallback name?
2. **Plugin surface:** Omarchy 4 "Quattro" ships a plugin concept (`omarchy-basecamp-plugin` exists [S58]). Is Kids Mode best delivered as one plugin, several plugins, a theme + install script, or a fork? This decides the sub-repo naming pattern.
3. **Council seats:** Who are the first 3–5 maintainers, and is a founding-lead tie-break acceptable to the Discord group?
4. **FCP length:** 7 days (recommended) vs Rust/Nix 10 vs React 3?
5. **AI policy strictness:** Disclosure-only (recommended) or disclosure + "AI-assisted RFCs must be under N words and the author must answer every review question in their own words"?
6. **Rulesets availability:** Confirm in Settings → Rules whether rulesets are offered on this Free-plan public repo; otherwise classic branch protection [S16][S17].
7. **DCO tooling:** Is the hosted DCO app still operating [S43]? If not, adopt the fallback Action from day one.
8. **Contributor Covenant 3.0 vs 2.1:** 3.0 is "Latest" [S25] but has fewer translations; does the community need non-English CoC text now?
9. **Age bands:** Are 3-5 / 6-8 / 9-12 / 13+ the right bands for labels and board fields, and should there be a "mixed household" value?
10. **Where do guardians talk?** A GitHub "Guardians' lounge" category, a Discord channel, or both, and who moderates it?
11. **Funding:** Leave `FUNDING.yml` out until a legal recipient exists — agreed?
12. **Research-source policy:** Should SEARCH-ONLY sources be allowed to support a recommendation in an RFC, or must every load-bearing claim be VERIFIED?

---

## Sources

Status key: **VERIFIED** = fetched and read on 2026-09-01; **SEARCH-ONLY** = URL appeared in search results, content not fetched; **DEAD-UNVERIFIABLE** = fetch failed.

| ID | Title | URL | Status | Accessed | Note |
|---|---|---|---|---|---|
| S1 | rust-lang/rfcs README | https://github.com/rust-lang/rfcs/blob/master/README.md | VERIFIED | 2026-09-01 | 10-day FCP; PR-number naming; sub-team sign-off; "postponed" |
| S2 | reactjs/rfcs README | https://github.com/reactjs/rfcs/blob/main/README.md | VERIFIED | 2026-09-01 | 0000 placeholder; 3-day FCP; list of non-RFC changes |
| S3 | kubernetes/enhancements keps/README | https://github.com/kubernetes/enhancements/blob/master/keps/README.md | VERIFIED | 2026-09-01 | kep.yaml statuses; number = tracking issue |
| S4 | TC39 Process Document | https://tc39.es/process-document/ | VERIFIED | 2026-09-01 | Stages 0–4 incl. 2.7; champions; consensus |
| S5 | PEP 1 | https://peps.python.org/pep-0001/ | VERIFIED | 2026-09-01 | Vet ideas publicly first; sponsors; statuses; required sections |
| S6 | home-assistant/architecture README | https://github.com/home-assistant/architecture/blob/master/README.md | VERIFIED | 2026-09-01 | Discussions → ADR; stay on topic |
| S7 | home-assistant/architecture adr/ | https://github.com/home-assistant/architecture/tree/master/adr | VERIFIED | 2026-09-01 | 0001–0022 sequential ADRs |
| S8 | withastro/roadmap README | https://github.com/withastro/roadmap/blob/main/README.md | VERIFIED | 2026-09-01 | 4 stages; Discussions→Issues→PRs; TSC vote |
| S9 | NixOS/rfcs README | https://github.com/NixOS/rfcs/blob/master/README.md | VERIFIED | 2026-09-01 | Shepherd team; SC; FCP motion to end unproductive debate |
| S10 | GitHub Docs: default community health file | https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file | VERIFIED | 2026-09-01 | Supported files; precedence; org .github; no default LICENSE |
| S11 | GitHub Docs: syntax for issue forms | https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms | VERIFIED | 2026-09-01 | Keys, body types, attributes, config.yml |
| S12 | GitHub Docs: discussion category forms | https://docs.github.com/en/discussions/managing-discussions-for-your-community/creating-discussion-category-forms | VERIFIED | 2026-09-01 | `.github/DISCUSSION_TEMPLATE/<slug>.yml`; no polls |
| S13 | GitHub Docs: private vulnerability reporting | https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-a-repository | VERIFIED | 2026-09-01 | Enable path; reporter flow; notifications |
| S14 | GitHub Docs: understanding fields (Projects) | https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields | VERIFIED | 2026-09-01 | Text/number/date/single-select/iteration; issue type; sub-issue progress |
| S15 | GitHub Docs: about code owners | https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners | VERIFIED | 2026-09-01 | Locations; last match wins; 3 MB; any-owner approval |
| S16 | GitHub Docs: about rulesets | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets | VERIFIED | 2026-09-01 | Stackable; Active/Disabled; plan wording ambiguous for Free public repos |
| S17 | GitHub Docs: creating rulesets for a repository | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository | VERIFIED | 2026-09-01 | Evaluate status for metadata rules; org rulesets Team/Enterprise |
| S18 | GitHub Docs: adding a security policy | https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository | VERIFIED | 2026-09-01 | Supported versions + how to report |
| S19 | GitHub Docs: about discussions | https://docs.github.com/en/discussions/collaborating-with-your-community-using-discussions/about-discussions | VERIFIED | 2026-09-01 | Open-ended; convert issues; pin/lock/labels |
| S20 | GitHub Docs: managing categories for discussions | https://docs.github.com/en/discussions/managing-discussions-for-your-community/managing-categories-for-discussions | VERIFIED | 2026-09-01 | Six defaults; formats; 25-category cap |
| S21 | GitHub Docs: community profiles | https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories | VERIFIED | 2026-09-01 | Checklist items; Insights → Community Standards |
| S22 | MADR homepage | https://adr.github.io/madr/ | VERIFIED | 2026-09-01 | MADR 4.0.0 (2024-09-17); NNNN naming; MIT/CC0 |
| S23 | MADR template (develop) | https://github.com/adr/madr/blob/develop/template/adr-template.md | VERIFIED | 2026-09-01 | Full template text captured |
| S24 | Contributor Covenant 3.0 | https://www.contributor-covenant.org/version/3/0/code_of_conduct/ | VERIFIED | 2026-09-01 | Sections; enforcement ladder; CC BY-SA 4.0 |
| S25 | Contributor Covenant homepage | https://www.contributor-covenant.org/ | VERIFIED | 2026-09-01 | Nav labels 3.0 "Latest Version"; 40+ translations |
| S26 | Developer Certificate of Origin 1.1 | https://developercertificate.org/ | VERIFIED | 2026-09-01 | Four certifications; sign-off record kept indefinitely |
| S27 | choosealicense: CC-BY-4.0 | https://choosealicense.com/licenses/cc-by-4.0/ | VERIFIED | 2026-09-01 | "Not recommended for software"; SPDX CC-BY-4.0 |
| S28 | opensource.guide: Leadership and Governance | https://opensource.guide/leadership-and-governance/ | VERIFIED | 2026-09-01 | BDFL/meritocracy/liberal; write GOVERNANCE.md early |
| S29 | Diátaxis | https://diataxis.fr/ | VERIFIED | 2026-09-01 | Four doc types |
| S30 | Omarchy LICENSE | https://github.com/basecamp/omarchy/blob/master/LICENSE | VERIFIED | 2026-09-01 | MIT; "Copyright (c) David Heinemeier Hansson"; renders under omacom/omarchy |
| S31 | omacom/omarchy repository | https://github.com/omacom/omarchy | VERIFIED | 2026-09-01 | MIT; 36.7k stars; no trademark/naming guidance in README |
| S32 | QEMU: Code provenance (AI-generated content) | https://www.qemu.org/docs/master/devel/code-provenance.html | VERIFIED | 2026-09-01 | Declines AI-generated contributions; DCO rationale |
| S33 | Rust Foundation Trademark Policy | https://rustfoundation.org/policy/rust-trademark-policy/ | VERIFIED | 2026-09-01 | Repo names OK for compatibility; no appearance of official status |
| S34 | REUSE tutorial | https://reuse.software/tutorial/ | VERIFIED | 2026-09-01 | SPDX headers; LICENSES/; reuse lint |
| S35 | Linux kernel: AI Coding Assistants | https://docs.kernel.org/process/coding-assistants.html | VERIFIED | 2026-09-01 | `Assisted-by: LLM [TOOL]`; AI must not sign off DCO |
| S36 | LWN: Fedora floats AI-assisted contributions policy | https://lwn.net/Articles/1039623/ | VERIFIED | 2026-09-01 | Three principles; opt-in AI features; draft status as of Oct 2025 |
| S37 | W3C WAI: Developing an Accessibility Statement | https://www.w3.org/WAI/planning/statements/ | VERIFIED | 2026-09-01 | Minimum contents; plain-language guidance |
| S38 | GitHub Docs: about fields (Projects) | https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-fields | DEAD-UNVERIFIABLE | 2026-09-01 | HTTP 404; superseded by S14 |
| S39 | EndBug/label-sync | https://github.com/EndBug/label-sync | SEARCH-ONLY | 2026-09-01 | Action; YAML/JSON config; global+local sets |
| S40 | r7kamura/github-label-sync-action | https://github.com/r7kamura/github-label-sync-action | SEARCH-ONLY | 2026-09-01 | `.github/labels.yml`; `allow_added_labels` |
| S41 | Financial-Times/github-label-sync | https://github.com/Financial-Times/github-label-sync | SEARCH-ONLY | 2026-09-01 | Underlying CLI |
| S42 | dcoapp/app README | https://github.com/dcoapp/app/blob/main/README.md | SEARCH-ONLY | 2026-09-01 | DCO GitHub App; `.github/dco.yml` |
| S43 | open-gitops discussion: DCO app shutdown warning | https://github.com/open-gitops/project/discussions/27 | SEARCH-ONLY | 2026-09-01 | Reason to keep a fallback Action |
| S44 | GitHub Changelog: require sign-off on web commits | https://github.blog/changelog/2022-06-07-admins-can-require-sign-off-on-web-based-commits/ | SEARCH-ONLY | 2026-09-01 | Repo setting |
| S45 | all-contributors bot usage | https://allcontributors.org/docs/en/bot/usage | SEARCH-ONLY | 2026-09-01 | `@all-contributors please add` |
| S46 | all-contributors specification | https://allcontributors.org/specification/ | SEARCH-ONLY | 2026-09-01 | Emoji key |
| S47 | Fedora approves AI-assisted contribution policy (ostechnix; The Register) | https://ostechnix.com/fedora-ai-contribution-policy/ ; https://www.theregister.com/2025/10/23/fedora_agrees_policy_allowing_ai_assisted_code_contribs/ | SEARCH-ONLY | 2026-09-01 | Approval reported 2025-10-22/23 |
| S48 | All Things Open: "Assisted-by" trailer standard | https://allthingsopen.org/articles/open-source-ai-contributions-assisted-by-git-trailer-standard | SEARCH-ONLY | 2026-09-01 | Survey of project policies |
| S49 | Linuxiac: QEMU may relax AI ban | https://linuxiac.com/qemu-may-relax-its-ban-on-ai-generated-contributions/ | SEARCH-ONLY | 2026-09-01 | Disclosure-based relaxation under discussion |
| S50 | Debian LLM contribution rules / vote (opensourceforu; resultsense) | https://www.opensourceforu.com/2026/07/debian-eyes-project-wide-rules-for-llm-contributions/ ; https://www.resultsense.com/news/2026-08-31-debian-generative-ai-contribution-vote/ | SEARCH-ONLY | 2026-09-01 | 2026 trend toward disclosure |
| S51 | GitHub Community discussion: 13-year minimum age | https://github.com/orgs/community/discussions/44742 | SEARCH-ONLY | 2026-09-01 | GitHub ToS: users must be ≥13 |
| S52 | Discord Terms of Service | https://discord.com/terms | SEARCH-ONLY | 2026-09-01 | ≥13 and local minimum age |
| S53 | themartiano/try-omarchy | https://github.com/themartiano/try-omarchy | SEARCH-ONLY | 2026-09-01 | "not official or affiliated... not endorsed by Basecamp" |
| S54 | Omarchy Themes | https://omarchythemes.com/ | SEARCH-ONLY | 2026-09-01 | "not affiliated with 37signals" |
| S55 | Omarchy News | https://omarchynews.com/posts/60-v205 | SEARCH-ONLY | 2026-09-01 | "not affiliated with 37signals" |
| S56 | The Omarchy Manual (Getting Started; Omarchy on...) | https://omarchy.org/manual/getting-started/ ; https://omarchy.org/manual/omarchy-on/ | SEARCH-ONLY | 2026-09-01 | Discord channels #omarchy-help, #omarchy-on-other |
| S57 | omacom/omarchy-pkgs | https://github.com/omacom/omarchy-pkgs | SEARCH-ONLY | 2026-09-01 | Confirms `omacom` org and `omarchy-*` naming |
| S58 | basecamp/omarchy-basecamp-plugin | https://github.com/basecamp/omarchy-basecamp-plugin | SEARCH-ONLY | 2026-09-01 | Official plugin naming precedent |
| S59 | lycheeverse/lychee-action README; .lycheeignore | https://github.com/lycheeverse/lychee-action/blob/master/README.md ; https://github.com/lycheeverse/lychee-action/blob/master/.lycheeignore | SEARCH-ONLY | 2026-09-01 | Regex per line; workingDirectory |
| S60 | DavidAnson/markdownlint-cli2 | https://github.com/DavidAnson/markdownlint-cli2 | SEARCH-ONLY | 2026-09-01 | `.markdownlint-cli2.jsonc` recommended |
| S61 | Wikipedia: Omarchy | https://en.wikipedia.org/wiki/Omarchy | SEARCH-ONLY | 2026-09-01 | MIT; v4.0 Aug 2026 (per search snippet) |
| S62 | W3C WAI accessibility statement generator | https://www.w3.org/WAI/planning/statements/generator/ | SEARCH-ONLY | 2026-09-01 | Linked from S37 |
| S63 | GitHub Community Code of Conduct | https://docs.github.com/en/site-policy/github-terms/github-community-code-of-conduct | SEARCH-ONLY | 2026-09-01 | Platform-level baseline |
| S64 | assisted-by.dev | https://assisted-by.dev/ | SEARCH-ONLY | 2026-09-01 | Tracks kernel Assisted-by adoption |
| S65 | Rocky Linux AI-assisted contribution policy | https://docs.rockylinux.org/10/guides/contribute/ai-contribution-policy/ | SEARCH-ONLY | 2026-09-01 | Disclosure model |
| S66 | OpenSSF wg-vulnerability-disclosures: AI-slop best practices issue | https://github.com/ossf/wg-vulnerability-disclosures/issues/178 | SEARCH-ONLY | 2026-09-01 | AI-generated report handling |
| S67 | Contributor Covenant 3.0 Markdown | https://www.contributor-covenant.org/version/3/0/code_of_conduct/code_of_conduct.md | SEARCH-ONLY | 2026-09-01 | Linked from S24; not fetched |

Counts: VERIFIED 37 · SEARCH-ONLY 29 · DEAD-UNVERIFIABLE 1.
