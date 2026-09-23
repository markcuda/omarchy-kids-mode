# Working in omarchy-kids-mode

Read this, then `SPEC.md`, before touching anything. The spec is the source of truth; issues
reference its requirement ids (`R-WEB-3`). If a ticket and the spec disagree, the spec wins and
the ticket gets a comment.

## What this is

Kids Mode for Omarchy: an app on a normal Omarchy install. One real Unix account
per kid, the parent never restricted, one parent password. This is the one repository for the
project; the design records are `CORE.md`, `SPOKES.md` and `research/` here, plus
`PATH-SANDBOX.md`/`PATH-INSTALLER.md` on the `two-paths` branch.

## Default workflow (owner, 2026-09-22)

Every piece of work runs this loop, in this repo:

1. **Spec and tickets — fable 5.1 at high effort.** Use the Matt Pocock engineering skills
   (`/to-spec`, then `/to-tickets`); the spec is the source of truth and each ticket is
   tracer-bullet sized with its blockers declared. See "Agent skills" below.
2. **Implement — DS4.1 flash (deepseek).** `/implement` drives `/tdd` at the pre-agreed seams:
   small, deliberate steps, red-green-refactor, one vertical slice at a time.
3. **Review — fable 5.1.** `/code-review` on both axes (Standards and Spec). Root,
   trust-boundary and security changes also get the independent adversarial review this file
   already requires. Nothing commits unreviewed, and the implementer never reviews its own work.

Then `test/all`, then the VM live checks the spec names (rule 11). This is the default; say so in a
ticket if you deviate.

## Agent skills

The Matt Pocock engineering skills are installed globally (`npx skills@latest add mattpocock/skills
-a opencode -a claude-code -g`, 38 skills; `/setup-matt-pocock-skills` was run once for this repo).

### Issue tracker

Issues and specs are GitHub issues in `markcuda/omarchy-kids-mode`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context; `SPEC.md`, `AGENTS.md` and `docs/*.md` are the domain model today. See
`docs/agents/domain.md`.

## Rules that override everything

1. **The parent's account is never restricted** (spec I-1). If your change touches the parent's
   session, home, browser, or DNS, stop.
2. **Nothing about a child leaves the machine** (I-2). No network calls from anything but the
   package manager and the DoH template inside the kids browser policy.
3. **Locks are root-owned and live outside every home** (I-3). Never make a plugin, a dotfile, or
   anything user-writable responsible for enforcement.
4. **Fail closed at kid login, fail safe in early boot** (I-4, I-9).
5. **Keyboard-complete** (I-5). Every screen you build must work with no pointer.
6. **Honest UI** (I-6). Do not ship a control that is not enforced. Label fences as fences.
7. **Core untouched** (I-7). Never edit a file owned by the `omarchy` or `omarchy-settings`
   packages. Use drop-ins, hooks, session entries, themes, policy folders, our package.
8. **Never run `--apply`, `provision`, or anything that writes under `/etc` on a development
   machine.** Real runs happen on the test laptop or in a VM. Library commands (`provision`,
   `web`, `apps`, `remove`) default to `DRY_RUN=1`; `omarchy-kids-assert` runs for real because
   the pacman hook relies on it (R-TRUST-5); the interactive commands (`omarchy-kids`, `-panel`,
   `-wizard`) run for real when a human drives them (a tty or the desktop entry) and preview
   otherwise. `--dry-run` always forces the preview.
9. **The trust boundary: no environment variable, and nothing a kid can write, selects which
   code runs or whether a root check happens.** Every `bin/omarchy-kids-*` resolves `lib/` and
   its sibling commands from its own resolved location (`readlink -f "$0"`) or the installed
   prefix — never `$OMARCHY_KIDS_LIB`, never a `*_BIN`, `*_PY` or socket-path override. Root
   checks go through `lib/kids.sh`'s `is_root` and read nothing but `id -u`. Which account a
   command is, is `id -un`; which account it may act for is SO_PEERCRED or `id -u`. A value a
   kid can write (their outbox, their runtime log) is validated at read time — types, ranges,
   allowlists — and root opens a kid-owned path with `O_NOFOLLOW` plus a regular-file and owner
   check, never through the shell. The relocation seams are build-time constants the PKGBUILD
   rewrites (`KIDS_PY`, `TEST_SOCKET_ROOT`, `omarchy-kids-web`'s `SYSROOT`,
   `omarchy-kids-conf`'s `SCHEMA`, and `BOOT_MODE_MACHINE_CONF`); tests substitute them into a
   copy, or run the checkout, and never export a new override. `test/shell.d/trust-boundary-test.sh`
   enforces all of this and carries the allowlist of the data settings that stay
   (`OMARCHY_KIDS_TUI_ANSWERS`, `DRY_RUN`, the scratch-tree prefixes), one line of why each.

10. **Nothing about a real child.** No names, ages, photos, or transcripts in code, tests, docs,
   fixtures, or commit messages. Fixtures and test accounts use only these invented names:
   `kid-ada` (the default, band `6-8`), and where a second or third kid is genuinely needed
   `kid-cy`, `kid-dot`, `kid-ben`, `kid-test`. Nothing else, and never a name from the family
   this is built for.
11. Drafting agents never drive the test VM: nothing under `test/live/` and no `scripts/vm-*.sh` runs from a draft; the gate runner alone does, one scenario at a time, from a clone that holds `test/live/config.env`. Draft clones do not get that file. (A draft ran a live scenario and rebooted the VM under three other gates, 2026-09-04.)

## Before you call a ticket done

Every review round this project has run found its blocking defects in the same six shapes. Read
this list against your own diff before you hand it over; a round of review costs half an hour that
a minute here saves.

1. **A test that proves a command was not called must own that command as a stub.** Grepping a log
   that only stubs write proves nothing about a command with no stub: the real one runs, writes
   nothing to your log, and the check passes. Stub it, then assert.
2. **An assertion must own its fixture.** A check that pins a group's membership, a package's
   presence, or a path that exists only on the machine you happen to be on will pass here and fail
   on a real Omarchy box with the package installed. Build the fixture (`test/shell.d/lib.sh`'s
   `kids_base_path`, a `getent` stub, your own `mktemp` tree), or assert the shape rather than the
   machine's state.
3. **Do the irreversible thing after the record that lets a retry finish.** Killing a LUKS slot
   before rewriting the slot map leaves a run that cannot be resumed and a report that lies. Where
   the order cannot be changed, make the next run able to tell what happened and complete it.
   Never let `set -e` inside a conditional stand in for checking the status of a destructive step.
4. **Re-reading a value is not locking it.** If a decision must hold across a check and the action
   it authorises, take the lock both sides take. A narrowed window is still a window, and the test
   that changes the value before the guard rather than inside it does not test the race.
5. **Quoting is not escaping.** Anything you wrap in quotes for a parser must also escape what that
   parser treats specially, and every reader must reverse both. Values a parent types reach these
   files; assume a quote, a backslash, and a comma in every one of them.
6. **Say what the code does, not what it was meant to do.** `--help`, `docs/<command>.md` and the
   labels in the UI are claims. If a path exits early, if a mode skips a check, if a failure leaves
   state behind, that is what the docs say. This is the "label claims" rule and it is a blocking
   defect, not a polish item.

## Layout

| Path | What goes there |
| --- | --- |
| `bin/omarchy-kids-*` | Commands (spec R-BUILD-4). One file per command, bash, `set -euo pipefail`, `DRY_RUN=1` default where it writes |
| `lib/*.sh` | Shared shell: settings helpers (vendored from upstream's `install/helpers/parent.sh`), the `run` dry-run wrapper, logging |
| `share/bands/bands.toml`, `share/packs/<band>.toml` | Data (Appendix C) |
| `share/hyprland/L{1,2,3}.lua`, `share/hyprland/band-*.lua` | Root-owned level configs and band overlays (Appendix E) |
| `lib/tui.sh` | One screen renderer over gum, called from `lib/wizard-screens.sh`'s own per-screen functions (R-WIZ-9, Appendix A) |
| `share/policy/*.json` | Chromium policy templates (R-WEB-2, R-WEB-3) |
| `share/avatars/*.svg` | Twelve CC0 animals (Q18) |
| `share/menu/*.jsonc` | Trimmed-menu extension for Levels 1 and 2 (R-DESK-4) |
| `share/sddm-theme/` | The portal (R-LOGIN) |
| `share/qml/KidsTheme.qml`, `lib/theme.sh` | Per-theme colors/font, one resolver for QML and one for shell (docs/theming.md) |
| `initcpio/` | The early-boot hook and its install script (R-BOOT) |
| `systemd/` | Units and timers |
| `lib/posture.sh` | The polkit rules and sudoers drop-ins, as quoted heredocs — the writers *are* the templates. (There are no `polkit/`, `sudoers/` directories: they held two `.gitkeep` files and nothing else.) |
| `test/shell.d/*-test.sh` | One test file per command, Omarchy's `test/shell.d` style; `test/all` runs them. `trust-boundary-test.sh` is the cross-cutting one (rule 9); `tree.sh` (not a test) builds the scratch command tree a stub is placed in |
| `test/acceptance.d/` | VM-only tests (spec §8) |
| `docs/phase1/V*.md` | Results of the Phase 1 checks, one file each |
| `PKGBUILD`, `omarchy-kids.install` | The package and its post_install/post_upgrade/post_remove scriptlet; file paths in spec §5.1, walked in `docs/packaging.md` |
| `pacman/omarchy-kids.hook` | Template for `/usr/share/libalpm/hooks/omarchy-kids.hook`, the re-assert hook (R-TRUST-5) |
| `desktop/*.desktop` | Templates for the app entry and the kid Wayland session entry (R-FND-1, R-DESK-1) |

## How to work

- Pick an issue in milestone order. Read its spec ids. Post a one-line plan on the issue before
  a large change.
- Shell: bash 5, `shellcheck` clean, `shfmt -i 2 -ci` clean (Omarchy's two-space indent), quoted heredocs for anything root writes, passwords only
  ever on stdin, never argv, never logged.
- Every command supports `--help` and, where it writes, `DRY_RUN=1` (default) printing the plan.
- Tests before merge: `test/all`. Tests that need root use `unshare --user --map-root-user` when
  available and skip otherwise, as upstream does.
- Match Omarchy's look and idiom: gum, the installer's header, Esc back, Ctrl+C leave, the
  0/1/130 status contract from upstream's `install/provisioning/setup-form.sh`.
- Commit messages: what and why, one topic per commit. AI-assisted work is welcome; say so in
  the PR, and a human reads every line.
- Anything a kid could use to get around a lock is a security issue: report it privately per the
  repository's `SECURITY.md`, not in a public issue.

## Conventions

Match omacom/omarchy's own style, not just its tools. Full citations and gaps:
`docs/style.md`.

- Put `# omarchy:summary=<one line>` (and `# omarchy:args=`, `# omarchy:examples=` where useful)
  directly under the shebang of every `bin/omarchy-kids-*` command, before any prose.
- Shebang is always `#!/bin/bash`, never `#!/usr/bin/env bash`. Every command in `bin/` uses
  `set -euo pipefail` — no exceptions without a one-line note in that file's own header saying
  why (e.g. it `exec`s into another binary at every exit path).
- Comment density: explain the *why* in one line, not the *how* in paragraphs. A file-level
  rationale block belongs once, at the top of a shared `lib/*.sh`/`.lua`/`.qml` file (setup-form.sh-
  length is the ceiling); an individual command or function gets 0-2 lines, not an essay. Move
  mechanics, sourcing audits, and "confirmed vs. unverified" trails into that command's
  `docs/<command>.md` — leave one pointer comment in the source instead.
- Naming: hyphenated `omarchy-kids-*` commands, `lower_snake_case` functions and locals,
  `UPPER_SNAKE_CASE` constants. Keep any future purpose-prefix taxonomy (`refresh-`, `toggle-`,
  etc.) in exactly one table — never a second list that can drift.
- User-facing prompts: terse, concrete, second person implied. One accent color per screen,
  resolved from `omarchy-theme-color` (see `lib/tui.sh`), never a fresh hardcoded hex per caller.
- Root handling: no script re-derives its own `EUID`-or-`sudo` check. Share one `as_root`/
  `require_root` helper (add `lib/root.sh` if one doesn't exist yet) the way upstream's
  `install/helpers/as-root.sh` does.
- Config locations: locks stay root-owned under `/etc/omarchy-kids/` per spec rule I-3 — this is
  a deliberate inversion of upstream's `~/.config/omarchy/`, not a gap to "fix" by moving state
  into a home directory.
- Theme colour: QML never hardcodes a hex or `Qt.rgba(...)` literal for anything themeable — pull
  from `qs.Commons`' `Style`/`Color` singletons or an injected `bar.foreground`, the way
  `shell/Ui/BarWidget.qml` and `shell/plugins/panels/clock/BarWidget.qml` do upstream.
- Lua and QML: two-space indent, `lowerCamelCase` QML ids/functions, `lower_snake_case` Lua
  locals promoted onto a shared table (`o.foo = foo`).
- Tests: one `test/shell.d/<command>-test.sh` per command, opening with the SPEC.md requirement
  ids it covers, the same discipline upstream expects. VM-only checks stay in `test/acceptance.d/`.
- Every test must pass on a real Omarchy box with `omarchy-kids` installed and Omarchy's own tools
  on `PATH`, not only on a bare dev machine. A test that needs a command *absent* builds its own
  `PATH` (`test/shell.d/lib.sh`'s `kids_base_path`: its stubs plus a base toolset, nothing else),
  and reads a file's mode through that file's `kids_file_mode`, never `stat -f` first.

## Test machines

The test laptop (2019 MacBook Air, T2) is reached over Tailscale SSH; see
`docs/laptop-runbook.md`. Boot-level checks (disk prompt, portal, two sessions, the early-boot
hook) run in QEMU on that laptop, never on its real disk. Real-hardware checks (Wi-Fi, captive
portals, firmware) run on the laptop itself.

## GitHub Account Rule

This repository is locked to `markcuda/omarchy-kids-mode` using the `markcuda` GitHub account. Before pushes, PRs, or GitHub CLI operations, verify `.codex/repo-lock.json`, `git remote -v`, and `gh auth status`. Do not use another GitHub account for this repo unless the user explicitly changes the lock.
