# Contributing

You do not need to be a developer. This is a **planning and research repo** — the most valuable contributions
right now are parents describing real moments, teachers describing classrooms, kids (with a grown-up) telling
us what's fun, and anyone who can open a link and check whether it says what we think it says.

If you've ever felt gatekept by a Linux community: not here. Ask the "dumb" question.

## Five ways to contribute in under 30 minutes

| You want to… | Do this |
| --- | --- |
| Share a real moment with your kid and a computer | **Discussions → Parent stories** (anonymised — no names, faces, or usernames of children) |
| Report what your child did with a prototype | **Issue → 🧒 Kid-test report** (parent-filed; age bands only) |
| Float a half-formed idea | **Discussions → Ideas** |
| Propose something concrete | **Issue → 💡 Idea** (pick the layer; we'll triage) |
| Add a link, paper, product, or prior art | **Issue → 📚 Add a source** — or PR a row into `research/sources.md` |
| Check whether something is true | Pick a `status: needs-verification` issue, open the links, report back |

Bigger chunks: claim a **🔬 Research task**, write an **RFC** (`rfcs/README.md`), or propose a
**🧩 Workstream** that becomes its own satellite repo (`projects/README.md`).

## Ground rules

1. **Verify before you cite.** Only link things you've personally opened. Mark claims as *verified*,
   *inferred*, or *opinion*. See ADR-0003.
2. **Disclose AI help.** Using Claude/ChatGPT/Codex to draft is fine and normal here. Say so in the PR **and add
   an `Assisted-by: <tool>` trailer to the commit** (the Linux-kernel/Fedora convention). You own every line —
   the model is a pen. AI agents never add `Signed-off-by`; only humans can certify the DCO. Safety reports must
   include human-reproduced steps — AI-generated bug reports without reproduction are closed.
3. **No data about real children.** Ever. Not in issues, not in screenshots, not in test fixtures.
4. **Safety bypasses go private first.** Read `SECURITY.md` before posting anything a kid could follow.
5. **Be kind, be brief.** Contributors have kids and jobs. Lead with the conclusion; link the detail.
6. **Neutral by default.** Mascots, colours, names and flows must not assume a child's gender. Offer choices;
   never a boy/girl fork.
7. **Upstream respect.** Omarchy is an opinionated project with its own rules. We build *alongside* it;
   we don't lobby it. Anything proposed for upstream inclusion follows upstream's contribution norms.

## Repo map

```text
README.md              what this is, one screen
docs/vision.md         mission, principles, non-goals
docs/architecture/     the layer model (L1–L11), one doc per layer
docs/threat-model.md   what we defend against, and what we don't
docs/decisions/        ADRs — short records of what we decided
docs/open-questions.md the running register of unknowns
rfcs/                  substantial proposals and their discussion
research/              reports, prior-art notes, community signal, sources registry
backlog/               seeded backlog & workstreams (GitHub Issues/Projects are canonical once live)
projects/              catalog of satellite repos (the actual code lives there)
```

## Writing conventions

- Markdown, wrapped naturally, `.editorconfig` respected; CI runs markdownlint and a link checker.
- Every doc starts with a one-line italic status: `_status: draft | reviewed | accepted · updated YYYY-MM-DD_`.
- Layer references use `L3` etc.; age bands use the preset names from `docs/architecture/layers/06-onboarding.md`.
- Cite sources as `[S-nnn]` keys from `research/sources.md`.
- Prefer tables over prose for comparisons; prefer a diagram over a table for flows.

## PR flow

1. Fork → branch → change → PR using the template. Small PRs merge fast.
2. A maintainer (see `GOVERNANCE.md`) or CODEOWNER reviews within ~7 days. Docs PRs need **one** approval;
   RFCs follow their own window.
3. We sign off commits with the Developer Certificate of Origin (`git commit -s`) — it just says you have the
   right to contribute what you contribute. No CLA. (Enable "require sign-off on web commits" in repo settings;
   a DCO check runs in CI once the repo is on GitHub.)

## Licence

Prose and documentation are **CC-BY-4.0** (`LICENSE`); code samples, configs and scripts are **MIT**
(`LICENSE-CODE`), matching upstream Omarchy so snippets can flow both ways. By contributing you agree to that split.
Satellite repos are MIT only.
