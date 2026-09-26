# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues in `markcuda/omarchy-kids-mode`. Use the `gh`
CLI for all operations, always as the `markcuda` account (see `AGENTS.md`'s GitHub Account Rule and
`.codex/repo-lock.json`).

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line
  bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also
  fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq
  '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with
  appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature
requests; `/triage` reads this flag.)_

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
  `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues
  endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put
  `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>`
  (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving
  dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation.
  Add an edge with `gh api --method POST
  repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where
  `<blocker-db-id>` is the blocker's numeric **database id** (`gh api
  repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports
  `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies
  aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A
  ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the
  map's sub-issues / task list), drop any with an open blocker
  (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an
  assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a
  context pointer (gist + link) to the map's Decisions-so-far.

## Where the older `#NN` citations resolve

Many comments in `docs/`, `bin/`, `lib/` and `share/` cite a bare `#NN` that does not resolve here:
this tracker's history starts at #4. Those numbers belong to **`markcuda/omarchy-kids-sandbox`**,
this project's development repo, which predates the public one. Spot-checked against their contexts
on 2026-09-26:

| cited | cited in | `omarchy-kids-sandbox` issue |
| --- | --- | --- |
| #28 | `lib/launcher-map.sh`, `bin/omarchy-kids-session-start` | Kids-plugins shelf from the marketplace Kids category |
| #37 | `docs/exit.md` | Parent bar widget: live and paused kids, minutes left, quick actions |
| #42, #43, #54 | `docs/levels.md` | Level 1 launcher: hidden uninstalled tiles, keyboard grid navigation, centred grid with real icons |
| #44 | `docs/web.md` | Web tile: launch Chromium without Omarchy's unpacked-extension flags |
| #46 | `AGENTS.md` | Wizard: parent-password screen fails when omarchy-kids-authd is not running |
| #58 | `docs/web.md` | Security round two: one trust boundary |

Read one with `gh issue view <NN> --repo markcuda/omarchy-kids-sandbox`. Cross-repo citations qualify
themselves (`omacom/omarchy#12488`); a bare number is this project's earlier tracker, not a missing
issue in this one. Nothing needs renumbering — but a comment written **now** that means an issue in
*this* tracker should say so, and one that means the sandbox issue should name the repo.
