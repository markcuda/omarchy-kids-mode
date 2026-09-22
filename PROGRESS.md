# Progress and handoff

## Current — September 21, 2026: dogfooding loop state

**Branch:** `integration/dogfood-2026-09-19` is the union of all topic work, in sync with
`origin`. Never push `main`; topic branches go to `origin`.

**Dogfooded live on the try-omarchy VM** (Arch aarch64, 875x492): the wizard, Level 1 (grid),
Level 2 (desktop + picker, two apps tiled 50/50) and Level 3 (stock desktop) all run; the Ask
request path was exercised end to end (kid `submit` -> collect -> `approve` ->
`omarchy-kids-time grant`). `omarchy-kids-check --live` is **never** green on this box -- 46 PASS,
4 FAIL, 3 WARN -- and the four FAILs are that machine's history, not product defects:
`account:kid-ada:band-group` and `lock:groups:kid-ada` (the kid predates the band group the
provisioner now creates), `lock:hyprland-configs` (the hand-installed dogfood `L2.lua`), and
`firmware:password` (a physical step, marked done by hand). Live evidence is also
**branch-specific**: the guest runs files installed by hand from topic branches, and
`.local/VM-PROVENANCE-2026-09-22.md` (untracked) resolves which branch each one came from.

**Fixed from the live passes and merged:** the unavailable tile no longer takes focus; the grid
fits short screens (height-aware cells, content scaled and clipped); the idle cursor hides; the
exit modal and Ask modal say "Your password"; the launcher refuses a close request so `Super+Q`
cannot blank the desktop; Level 3's menu trim uses omarchy-menu's real extension
(`~/.config/omarchy/extensions/omarchy-menu.jsonc`, `when: "false"` per id) and no longer runs
Omarchy's first-run provisioning. Full Mac suite green (52 files, five environment skips).

**Fixed on topic branches awaiting the merge gate:** 39 local branches carry commits the
integration line does not have, each test-green alone (recount with
`git rev-list --count integration/dogfood-2026-09-19..<branch>`; as of 2026-09-22, 35 are rebased
on its current tip and four hang off older commits: `fix/install-packaging`, superseded by
`fix/fresh-install-ordering` below, `style/shfmt`, `docs/levels-live-status` (already superseded),
`fix/launcher-insets-simplify`).
They are the live-pass fixes (time-status freshness after a grant, the Level
2 duplicate cursor rule, the toast icon per message, the picker no longer slicing the desktop hint,
the panel's reset claims, the time read diagnostics, the WARNs for unreadable files, the doc
references and stale live claims), plus `fix/portal-key-hints` (the greeter's footer no longer
names a key that cannot act, with a qmllint check for the one surface no dogfood screenshot can
reach), plus `feat/gcompris-preseed` (the seed of GCompris's own config that the owner approved on
2026-09-21, whose live check ran 2026-09-22, together with the rule-9 refusal of a kid-planted
symlink under a kept home), plus `docs/amendment-l3-evidence` (the SPEC amendment's "until the
menu-trim schema is verified" gate, now checked against the box's own Omarchy source and the live
Level 3 pass), plus `fix/stale-threshold-name`, which now carries the
trust-boundary work: the denylist named `time_toast_thresholds`, a function that does not exist (it
is `time_warning_thresholds`), and has since been extended to every kid overlay enumerated from
`share/`, the dispatcher exit spelling, and `lib/kids.sh`'s `modal_*` helpers.

The packaging fixes are deliberately **not** in the merged list above, though earlier revisions of
this paragraph claimed them: the integration line still pins `arch=('x86_64')`, its units name
runtime paths that do not exist before the first provisioning, and its assert exits 1 on a box with
no kid and no boot mode, so the pacman hook aborts a clean install.
`fix/fresh-install-ordering` re-lands all of it from the stale `fix/install-packaging`
(`docs/loop-report.md`, 2026-09-22).

The append-only
`PROGRESS.md`/`docs/loop-report.md` conflict as keep-both; `docs/levels.md`, `docs/time.md` and
`share/hyprland/L2.lua` need a human ordering, so the gate is the owner's.

**The loop (restart and use):** the unattended protocol is `.opencode/loop-prompt.md` (dogfood
first, then the backlog); the VM recipe (ssh wrapper, guest sudo, level switching, QMP keys,
install rules, "components are file sets") is untracked in `.local/VM-DOGFOOD.md`. After
restarting OpenCode:

```
/loop --safe --ask-never --no-overlap --progress-file PROGRESS.md --prompt-file .opencode/loop-prompt.md devam et
```

or headless: `opencode-loopd --project . --every 5m --prompt-file .opencode/loop-prompt.md --timeout 30m`
(Loop 0.5.38 is installed globally; the mise global node is pinned so the shim resolves).

**Waiting on the owner:** the two-mode SPEC amendment's five questions
(`docs/phase1/SPEC-AMENDMENT-two-kid-modes.md`); the GCompris pre-seed (approved, needs one VM
check of `kiosk=true`); the add-on model's five questions
(`docs/research/2026-09-21-discord-plugin-survey.md`); whether Level 3 keeps the file-manager
bind (`Super+Shift+F`) under `menu=trimmed`.

**Next work without owner input:** none the loop can reach. The mechanical sweeps came back clean
(docs links, docs-cited functions and paths, test-grep alternations, command/doc/test inventory,
SPEC-id traceability, conventions and file modes, repo-wide `shellcheck -x -S warning`, the
ignore/untracked audit, and this iteration's installed-file provenance reconstruction);
`docs/loop-report.md` is current through this iteration. Everything left is behind an owner
decision (above), the merge gate, the test laptop's hardware (Wi-Fi join, captive portal, a
band-3-5 kid, the portal's wrong-password path), or a real boot on the laptop.

## Paused — September 11, 2026

Work is paused at Mark's request. Start with
`docs/handoffs/PAUSED-2026-09-11.md`; it supersedes the older takeover status below.
Private machine evidence is retained locally under `.local/recovery/` and is intentionally
excluded from Git.

Written 2026-09-05 for whoever picks this up next. `docs/GOAL.md` is the standing order and
`docs/loop-report.md` is the running account; this file is the shortest path from cold start to
useful work.

## Where the project is

**Latest takeover status, September 5 evening:** #110 merged through PR #113 at
`bd679f9`. Keyboard guidance now appears before the parent answers. Independent review, VM
formatter, Mac suite, VM suite, and live welcome/input/back/cancel on both machines passed.
The merged-main gate also passed: formatter, both full suites, and the same live navigation
scenario on both machines. Screenshots are `docs/media/dogfood/main-footer-*.png`.

Reviewed drafts awaiting their ordered gates: #103 at `cd93325` (PR #114, cleanup correction
on `fix/103-session-cleanup`), #111 at `a78d413` (PR #115, current desktop-launch theme), and
#112 at `99a4ba5` (PR #116, readable parent portal label). The original `media-driver` remote
branch is unchanged; PR #114 carries the rebased driver plus its reviewed correction. Real
dogfood screenshots now exist in `docs/media/dogfood/`; the complete media-driver output is
still pending.

New screenshot-backed issues: #117 empty More apps instructions, #118 unclear password owner
on the exit card, #119 faint wizard keyboard help, and #120 resize corruption. The missing
launcher apps were already #91; its ticket now has live evidence. A separate screen-time
finding has an independently reviewed patch awaiting its ordered gate, with no public
reproduction or merge. #123 records the parent panel losing preview mode when opening setup;
its narrow correction is drafted and awaiting independent review.

#117 has an independently reviewed compact empty shelf with a clickable Back control (PR #122).
Its watched laptop preview passed Escape and actual pointer-click checks; the full gate remains.
#111's exact candidate desktop entry passed real laptop launches in Tokyo Night and Catppuccin
Latte, including the wizard child's theme environment. The original theme was restored.

#98 still has no human ship decision. #97 remains blocked on #98. No laptop boot changes or
full package upgrades were performed during this pass because #109 remains open. The wizard
live gate used exact staged source with `--dry-run`; it proves rendering/navigation only.

Quickshell previews must clear inherited `QS_DISABLE_FILE_WATCHER`; same-process live reload
was proven on the laptop. See `docs/live-tests.md`. The local gate runner, logs, private work
and current machine state are under `~/.omarchy-kids-loop/`, including `takeover-state.md`.

The following sections retain the earlier boot-work handoff and machine instructions.

Four spec-07 tickets merged today, plus two real-hardware fixes found within minutes of the first
install on the test laptop. The product works end to end in the VM: a parent runs the wizard, a
kid appears on the login portal, logs into their own desktop, is held to a screen-time budget, can
ask for more, and the parent ends the session with their own password.

**Merged (spec 07, the boot-mode work)**

| Ticket | What landed |
| --- | --- |
| #92 | `boot=disk\|portal` in `machine.conf` behind a trusted reader |
| #93 | Assert honours the mode; one root-owned lock serialises assert, the mode setter and the install scriptlet |
| #94 | Boot-login resolves the account to a trusted role, so a malformed record can never put a kid in the parent's session |
| #95 | Provisioning and removal honour the mode; portal mode makes no LUKS, UKI or Limine calls |
| #104 | The portal shows kid tiles again when a machine has two or more kids |

**In flight on branches, both mid-round when this was written**

- `boot-7` (#98, mode transitions). Gate green once; the confirmation review closed four of six
  findings, including the security one: two children can no longer be given the same disk
  password. Round three addresses the last real blocker, a power cut during the boot-image rebuild
  leaving a machine unbootable, plus a rollback that continued after failing to restore authority.
- `media-driver` (#103, the screenshot driver). Confirmation review closed four of six, including
  both honesty findings. Round three gives every surface the render-verification that only the
  Time's Up capture had, and captures the parent bar from a real session instead of excluding it.
- `boot-6` (#97, wizard boot row). Drafted, **must not merge before #98**; its own author flagged
  the dependency.

**Not started:** #99 (prove both modes in the VM), the last spec-07 ticket.

**The one decision that belongs to a person.** #98's transitions no longer touch the boot image,
but the conversion now asks the parent to run the rebuild by hand, and a power cut during that can
still leave this single-UKI laptop unbootable with no firmware-bootable fallback. Its author said
plainly it cannot be called power-cut safe and returned the ship decision rather than merging
quietly. Decide it together with #109, which is the same single-image weakness seen from the
install side. Do not merge #98 without making that call explicitly.

## The two real-hardware findings

The VM could not have shown either. Both are why the laptop matters.

1. **#109: installing the package rebuilds the boot image and rewrites the boot menu**, even in
   portal mode whose whole promise is that it leaves the boot path alone. Kids Mode's own hook
   behaves correctly and changes nothing; the rebuild is Arch's `90-mkinitcpio-install.hook`,
   which fires because the package ships a file under `/usr/lib/initcpio/hooks/`. The fix has the
   same shape as #98's inactive drop-in: ship the hook as a template the distro does not watch and
   install it only when a parent chooses the disk path.
2. **The app entry did not open a terminal.** `omarchy-kids` is a gum TUI; with `Terminal=false` a
   parent clicking Kids Mode got a launch toast and then nothing. Fixed on main with a test that
   says why. Omarchy's own TUI entries (btop, nvim) were the reference.

## The machines

- **The test laptop, `omarky-air`** (2019 MacBook Air, T2), over Tailscale:
  `ssh -i ~/.ssh/omarchy_kids_ed25519 omarky-air@omarky-air`. Kids Mode is **installed** on it now
  in portal mode with `omarky-air` recorded as the owner. Rollback state is at
  `/root/omarchy-kids-preflight` (host files as a tar, package list, boot fingerprints) plus
  `phase1-strays/`, two hand-installed binaries from Phase 1 that had to be moved aside before the
  package would install. `~/kids-install.sh` and `~/kids-rollback.sh` are on the box.
  Boot fingerprints for the install gate: `~/before-fingerprints.txt`.
- **Driving its desktop remotely**, which is how the app-entry bug was found:

      export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1
      export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1)
      hyprctl dispatch "hl.dsp.exec_cmd(\"foot -e omarchy-kids\")"   # Hyprland 0.56 dispatch is Lua
      grim /tmp/shot.png                                              # then scp it back and look at it

  The laptop's terminal is `foot`. There is no alacritty or ghostty on it.
- **The QEMU VM on that laptop** is where boot-level checks run, never the laptop's own disk.
  `docs/vm.md` has the recipe and the ssh stanza. It is reached from a Mac through the laptop:
  `ssh -F ~/.ssh/omarchy-kids-vm-config vm`.

## How work gets done

Read `AGENTS.md` first, especially **"Before you call a ticket done"**: six failure shapes that
every blocking review finding so far has taken. Drafts that walk that list honestly need fewer
rounds; drafts that assert they walked it need the same number as before.

The loop that produced the merges above:

1. Write a brief from the issue plus the spec. Say in its first line that the agent must never run
   anything under `test/live/`, never run `scripts/vm-*.sh` and never ssh anywhere — a drafting
   agent once rebooted the shared VM under three running gates.
2. The agent drafts on its own branch in its own clone, and **attacks its own diff** before handing
   over: for each test it adds, what production line could be deleted and leave that test green?
3. An **independent** agent reviews it, one that did not write it, with a fresh clone and the
   branch as its only context. Blocking findings only, ending in MERGE or FIX FIRST.
4. Gate: the test box's formatter first (seconds), then the unit suite on the Mac, then the same
   suite on the VM, then any live scenario the spec names.
5. Merge, then gate the merged main once, because four branches that each pass alone can still
   conflict together.

**Order matters: review first, gate second.** Reviews are cheap and parallel; the gate is one slot
and its cycles were repeatedly spent on code a reviewer then changed.

Measured over about twenty rounds: eleven found real defects, five were environment problems now
fixed structurally, four were rebases and scope. The eleven are why the review step is not
optional. They caught two children able to unlock each other's accounts, a conversion that could
leave a machine dead, and a screenshot driver that would have published a frozen interface labelled
as live.

## Tooling notes that cost time to learn

- `~/.omarchy-kids-loop/` on the Mac holds `gate.sh`, the live-harness `config.env`, and the Air
  runbooks, deliberately outside `/tmp`: a power cut and later a workspace change each wiped the
  scratch directory. **Push a branch as soon as it has one working commit.**
- The Mac cannot host `shfmt` honestly — Homebrew's 3.14 disagrees with the test box's 3.13 on
  files that are already clean. The gate ships changed files to the box and runs its formatter.
- The unit suite runs files in parallel on the Mac and **serially on the VM**, which has two cores
  and is the correctness gate. A file that fails in parallel is re-run alone and named in the
  summary; two files still do that (#106).
- Never edit a runner while a copy of it is running. bash reads scripts incrementally and a gate
  re-entered mid-run.
- One VM driver at a time, and never more than one gate on the Mac at once. Two gates plus two
  agents drove the load average past thirty-five and stalled both.
- Keep Spotlight out of working trees (`.metadata_never_index`). Indexing thousands of scratch
  files was burning more CPU than the agents.

## What is left

Nearest first:

1. Land #98 and #103, then #97, then #99. That completes spec 07.
2. #109, the boot rebuild at install: it makes a documented promise false.
3. Capture the demo media with the merged driver: every surface under a dark and a light theme,
   plus the three walkthrough videos (`docs/GOAL.md` item 3).
4. Dogfood the portal path on the laptop end to end and prove a clean removal.
5. #107, one crash-resumable transaction record for adding and removing a kid. Three rounds of
   patching narrowed its windows without closing them, which is why it became its own ticket with a
   design rather than more patches.
6. Specs 03 to 06 (#73-#87) are internal shape, invisible to a parent or a kid. They can land after
   a demo without changing what anyone sees.
