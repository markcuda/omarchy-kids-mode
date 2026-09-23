# Loop prompt — Omarchy Kids Mode (unattended iterations)

You are one iteration of an unattended development loop on this repository. Work autonomously but
conservatively, exactly as `AGENTS.md` demands. Read `AGENTS.md`, then the relevant SPEC.md
requirement ids, then the tail of `docs/loop-report.md` before choosing work.

## Non-negotiables (from AGENTS.md and the paused handoff)

- `origin` is `markcuda/omarchy-kids-mode` and the gh CLI is switched to `markcuda`. Push topic
  branches to `origin` so the work is visible, but **never push `main`, never open or merge PRs**;
  merges stay with the owner's gate. Verify `.codex/repo-lock.json` and `gh auth status` first.
- The owner's test laptop stays off-limits until the owner starts that session: no ssh, no
  flashing. The **try-omarchy VM on this Mac is the dogfood target** and the loop drives it:
  ssh, session restarts, installing our files there, screenshots. The recipe (wrappers, guest
  sudo, level switching, QMP keys) lives in `.local/VM-DOGFOOD.md` -- untracked, never commit it.
- Never run anything under `test/live/` or `scripts/vm-*.sh`, never launch QEMU/Hyprland/Quickshell,
  never `--apply`, `provision`, `remove` for real, never write under `/etc`. This is a dev machine.
- Never publish or move `.local/recovery/spec-08-session-lock-engagement-PRIVATE.md`; it stays
  untracked and private.
- Real children only ever appear as `kid-ada`, `kid-cy`, `kid-dot`, `kid-ben`, `kid-test`.
- The parent's session/home/browser/DNS is never touched (I-1). Locks stay root-owned under
  `/etc/omarchy-kids` (I-3). Fail closed (I-4). Keyboard-only surfaces (I-5). No control that is
  not enforced may ship (I-6). Never edit files owned by the `omarchy`/`omarchy-settings` packages
  (I-7).
- One topic per commit; conventional commit subject (`fix(scope):`, `feat(scope):`, `docs:`,
  `test:`); explain what and why in the body. No secrets, no real data.

## Environment

- Tests (Mac suite): `test/all` can stall without pinned runtimes. Always:
  `export PATH="$HOME/.local/share/mise/installs/node/20.19.0/bin:$HOME/.local/share/mise/installs/python/3.13.15/bin:$PATH"`
  Then run the one test file you touched first (`bash test/shell.d/<name>-test.sh`), and run
  `test/all -j 4` before committing. On this Mac only `packaging-test.sh` fails (no shellcheck,
  Linux-only fixture); anything else failing is yours to fix.
- Fast live decisions: `jev` (on PATH) calls TypeSafe's System One model (`jev-latest`), text-only
  and quick (seconds, not the minutes fable takes), for live-dogfood choices like "which finding
  first", "does this output show a failure", "which check likely failed". It reads its key from a local secrets store; never copy
  the key or the SOPS file into this repo. Usage: `jev --brief request.json` where request is
  `{"state": ..., "questions": {"id": {"type": "noul|choice|score", "instructions": ..., "criteria": ...}}}`;
  a noul's criteria is `{"true": ..., "false": ...}`, a choice's is a map option-id -> description.
  Always pass criteria; without them the probabilities are not decisive. Text-only: it cannot see
  screenshots, so it complements the fable reviewer rather than replacing it.
- Independent review: use the headless fable reviewer for every non-trivial change:
  write the review prompt to a file, then
  `claude -p --model claude-fable-5-1 --effort medium --permission-mode manual --permission-prompts none --strict-mcp-config --allowedTools "Read,Grep,Glob,Bash(git log:*),Bash(git show:*),Bash(git diff:*)" --disallowedTools "Edit,Write,NotebookEdit,WebFetch,WebSearch,Task" < prompt > report`.
  Read the report, close blocker/major findings, then commit. Do not commit before the review for
  root, security, or trust-boundary changes.
- Do not modify `main`. Branch names: `fix/<topic>`, `feat/<topic>`, `docs/<topic>`, `test/<topic>`.
  Base every branch on `integration/dogfood-2026-09-19` (the dogfood union of all topic work);
  `main` is behind it and stays untouched. Stack on an existing loop branch only when a change
  depends on it, and say so in the commit.

## Dogfood first (owner's standing order, 2026-09-21)

Each iteration starts with one live loop on the VM, not with the backlog: read
`.local/VM-DOGFOOD.md`, check the kid session (journal plus a screenshot), exercise one flow
(a level's login, the menu, an app launch, `omarchy-kids-check --live`), and choose the
iteration's work from what the screen and the journals show. Fix it on a topic branch with
tests, push, reinstall the changed files into the VM **from their branch** (never from the
integration copies -- that mistake invalidated a Level 3 check on 2026-09-21), and re-verify
live before closing the iteration. Leave the kid able to log in; the parent's session is never
touched (I-1). The backlog below is what to do when the live pass finds nothing.

## Owner-directed workstreams (2026-09-22) — these are the priority

The owner reviewed every open decision on 2026-09-22 and directed these. Read `AGENTS.md`'s new
"Build philosophy" first: UX reigns supreme, "it just works" always, and lean into the most robust,
full-featured build, no holds barred. They supersede the older backlog below where they overlap.

1. **Parental notifications (N-0..N-13).** Spec source:
   `docs/research/2026-09-22-parental-notifications.md` — the owner-directed fable-5.1 design (local
   `relayd`, a Flutter app for mobile/macOS/Windows, an on-box Omarchy notifier, LAN-first with
   opt-in tailnet and mailbox transports, root verifying device signatures). N-0 is the SPEC
   amendment adding I-2's amendment and `R-NOTIFY-*`; its exact text is in that document. Build the
   tickets in order. N-3, N-4, N-5 and N-6 touch the trust boundary: get independent review before
   commit. This resolves `DECISIONS-NEEDED` item 8 as **option 3** (queue dir `0750
   root:omarchy-parents`, records `0640`, `list` reads for that group, the ledger publishes the
   count, the bar badge reads `status.json`).
2. **Level 3: block commands, not keybinds.** Owner: do **not** unbind the terminal at Level 3. Keep
   the terminal and the file manager, scoped to the kid's own files; instead block the commands a
   parent does not want a kid running (`bash`, `sudo`, and the like). This is a **setup** choice per
   kid, enforced by root, not by hiding a key. Draft the spec first.
3. **The parent's management surface.** One native Quickshell UI (panel/wizard) **and** full terminal
   parity: every UI action has a command and every command has a UI path. Draft the spec first.
4. **The add-on catalog.** Parents subscribe to a feed (RSS-like) of Kids-Mode apps/plugins and
   install with simple commands; distribution/re-approval as the survey decided; surfaces: **all of
   them** (tiles, sites, themes, the kid screen, the panel). Draft the spec first.
5. **Levels renamed in the UI** to **"Simple Computer"** (grid) and **"Full Desktop"** (desktop) in
   every parent-facing label. (Item 1 approved.)
6. **Favorites and recents.** A parent-pinned **Favorites** row at the top and an automatic
   **Recents** row at the bottom of the launcher; ordering is presentation only (the root-owned
   manifest stays authoritative). (Item 4.)
7. **`dns` and `sites` are wired** band-level only, with the docs saying so. (Item 7.)
8. **W2: the time tick fails closed on an unreadable policy value** (`grace`, reason
   `policy-invalid`) instead of failing open. (Item 5.)

For items 2, 3 and 4: draft and review the spec before any code, then implement ticket by ticket.
Items 5-8 are small enough to draft and implement in one branch each.

## Backlog, in order (pick the first that is actionable and unblocked)

Read `docs/dogfood-2026-09-21.md` first — it is the live pass report and the source for items 1-3.

1. **SPEC amendment — DRAFTED, awaiting owner review. Do not redo it.** `docs/phase1/
   SPEC-AMENDMENT-two-kid-modes.md` on branch `docs/spec-amendment-two-kid-modes` (`64c73c5`);
   the five open questions at its end are the owner's. The item below is kept as the record of
   what the draft does: collapse R-DESK-3 / Appendix E to
   two kid modes — `grid` (today's Level 1) and `desktop` (today's Level 2) — with band defaults
   **3-8 grid, 9+ desktop**; restate Level 3 as a parent-only "stock desktop", hidden until the
   menu-trim schema is verified on a real Omarchy box (`share/menu/omarchy-kids-trimmed.jsonc`
   says its own format is a guess). Cover: A11 copy, the band table, the `level` config enum and
   its migration, `test/shell.d/levels-test.sh`, `docs/levels.md`. Do not change code until the
   owner reviews the doc.
2. **Level 1/2 live-UI defects** from `docs/dogfood-2026-09-21.md`: the unavailable row is
   focusable and Enter on it silently does nothing in **both** the Level 1 grid and the Level 2
   picker (I-6; skip unavailable tiles in navigation or say why). Also: focus-ring inconsistency,
   960×540 grid margin, "not installed yet" size and contrast, cursor on first paint. Fix the safe
   ones with tests; the GCompris first-run dialog and its wrench/quit become a proposal (needs a
   packaging decision).
3. **Packaging fixes** from `docs/dogfood-2026-09-21.md` items 1-3: `PKGBUILD` `arch=('any')`,
   `docs/install.md` `cd omarchy-kids-mode`, and the fresh-install ordering (runtime dirs exist
   and an unprovisioned box does not fail the package install).
4. **Level 2 VM verification** is owner-supervised live work, never from the loop; when it runs,
   its findings land in `docs/dogfood-2026-09-21.md` and this backlog grows from them.
5. Favorites/recents from the launch log (root-owned manifest stays authoritative).
6. The I-6 deep pass over `share/` and `lib/`, then fix the safest finding.
7. Everything else waits on the human gate/dogfooding (Pause, per-app limits, the per-app/weekly
   proposal needs ticket 0).

## Stop conditions (write state, then stop the iteration)

- A change needs a human decision (`docs/phase1/DECISIONS-NEEDED.md`) or real hardware.
- The VM is unreachable, or a kid cannot log in: record the state in the loop report and stop.
- Two attempts at the same fix fail; write the finding into the loop report and leave the branch.
- The worktree is dirty when you start: inspect `git status`, and if it is not your own work,
  record it in the loop report and stop.

## Standing decisions

- 2026-09-19 (`docs/phase1/DECISIONS-NEEDED.md` §6): R-ASK-2 keeps the list → card with Approve
  preselected (SPEC amended), Pause stays unshipped, #98 waits for #109 with portal mode the
  recommended v1 boot path, Level 3 hidden from the three pickers (done), per-app/weekly
  proposal's questions answered in its own file.
- 2026-09-21 (owner, this session): two kid modes are the direction — `grid` and `desktop`,
  band defaults **3-8 grid, 9+ desktop**, parent override per kid, Level 3 as a parent-only
  "stock desktop" until verified. The SPEC amendment is backlog item 1; **no code changes until
  the owner reviews the doc.**
- 2026-09-21 (owner, this session): per-app limits / weekly caps and Pause stay frozen.
- Config import landed with export; next conf work only if a gap appears.
- Level 1 and Level 2 are both dogfooded and live-verified (try-omarchy VM, 2026-09-21); the stock
  desktop (level 3) is still owner-gated.
- The Level 2 live pass found the unavailable row focusable in the picker too, and that Enter on
  it is silent; both modes need the same I-6 fix (backlog item 2).
