# Loop prompt — Omarchy Kids Mode sandbox (unattended iterations)

You are one iteration of an unattended development loop on this repository. Work autonomously but
conservatively, exactly as `AGENTS.md` demands. Read `AGENTS.md`, then the relevant SPEC.md
requirement ids, then the tail of `docs/loop-report.md` before choosing work.

## Non-negotiables (from AGENTS.md and the paused handoff)

- Never push, never open or merge PRs, never `git push`, never use `gh`. All work stays local on a
  topic branch off `main`. The gh account lock is not satisfied on this machine.
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
- Independent review: use the headless fable reviewer for every non-trivial change:
  write the review prompt to a file, then
  `claude -p --model claude-fable-5-1 --effort medium --permission-mode manual --permission-prompts none --strict-mcp-config --allowedTools "Read,Grep,Glob,Bash(git log:*),Bash(git show:*),Bash(git diff:*)" --disallowedTools "Edit,Write,NotebookEdit,WebFetch,WebSearch,Task" < prompt > report`.
  Read the report, close blocker/major findings, then commit. Do not commit before the review for
  root, security, or trust-boundary changes.
- Do not modify `main`. Branch names: `fix/<topic>`, `feat/<topic>`, `docs/<topic>`, `test/<topic>`.
  Stack on an existing loop branch only when a change depends on it, and say so in the commit.

## Backlog, in order (pick the first that is actionable and unblocked)

1. **Panel P2 gaps (R-WIZ-8 "every setting")**: add Wi-Fi mode and weekend budget/lights-out rows,
   and a reset-to-defaults action with honest labels. Tests in `test/shell.d/panel-test.sh`.
2. **R-ASK-2 one-keystroke approve**: read the requirement first; today approving takes two screens.
3. **Remaining-time indicator** on the Level 1/2 launcher, bound to root's published status; use
   docs/time.md's status shape. Keep it display-only.
4. **Remove command's confirmation** through the shared card idiom (currently a plain `read`), while
   keeping piped `yes` working for scripts; `test/shell.d/remove-test.sh` owns it.
5. **Docs**: keep `docs/loop-report.md` current (add a dated entry per iteration), and fix any
   claim you find that the code contradicts (I-6).
6. **Research-derived features** (`docs/research/2026-09-18-kids-mode-landscape.md`): favorites and
   recents from the launch log; config export/import. Per-app limits and weekly caps need a SPEC
   amendment first — draft it as a doc, do not code it without the owner.
7. If the backlog is empty: run the deep-review style pass over `share/` and `lib/` for I-6 label
   violations and write up tickets as docs, then fix the safest one.

## Stop conditions (write state, then stop the iteration)

- A change needs a human decision (`docs/phase1/DECISIONS-NEEDED.md`), a VM run, or real hardware.
- Two attempts at the same fix fail; write the finding into the loop report and leave the branch.
- The worktree is dirty when you start: inspect `git status`, and if it is not your own work,
  record it in the loop report and stop.
