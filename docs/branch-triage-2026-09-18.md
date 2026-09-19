# Stale branch triage (2026-09-18)

For the gate runner, before the next merge session. Method, on this checkout with no network:

- `git merge-base main origin/<branch>` then `git diff --name-only <base> origin/<branch>` to
  count the real change.
- `git merge-tree --write-tree main origin/<branch>` (git 2.50): exit 0 is a clean merge,
  non-zero a conflict.
- "Empty" means the branch's tip tree equals its own merge-base: its content is already in `main`
  (squash-merged under another PR). Confirm with `git log main..origin/<branch>` before deleting.

Remote refs are only as fresh as the last fetch — run `git fetch --prune` on the gate box first.

## Summary

| State | Branches | Meaning |
| --- | --- | --- |
| Already content-merged ("empty") | 45 | Safe to delete once `git log main..origin/<branch>` is silent. |
| Clean merge | 19 | Candidate for the ordered gate; no rebase needed. |
| Conflict | 15 | Rebase needed before a gate run. |

## Clean merges (19)

| Branch | Files | Last commit | Subject |
| --- | --- | --- | --- |
| `origin/boot-7` | 9 | 2026-09-05 | fix: recover additions by trusted boot authority |
| `origin/dogfood/air-final-sep7` | 37 | 2026-09-08 | docs: record reviewed Air delivery and remaining acceptance gaps |
| `origin/fix/111-current-parent-theme` | 4 | 2026-09-05 | Refresh parent TUI theme through Omarchy launcher |
| `origin/fix/112-parent-label-contrast` | 2 | 2026-09-05 | fix: improve parent portal label contrast |
| `origin/fix/117-empty-shelf` | 2 | 2026-09-05 | fix: make More apps back action clickable |
| `origin/fix/118-parent-password-label` | 2 | 2026-09-05 | fix: improve exit modal label contrast |
| `origin/fix/123-panel-preview-handoff` | 2 | 2026-09-05 | fix: preserve panel mode when opening wizard |
| `origin/fix/131-ask-guidance` | 1 | 2026-09-06 | fix: keep ask guidance layout stable |
| `origin/fix/137-lights-out-extension` | 1 | 2026-09-06 | docs: define combined exhaustion and immutable approval identity |
| `origin/fix/140-bar-reload` | 2 | 2026-09-06 | fix(bar): reload child status when the watched file changes |
| `origin/fix/148-wifi-success` | 3 | 2026-09-06 | fix(wifi): preserve joined-network confirmation after refresh |
| `origin/fix/155-parent-request-count-next` | 9 | 2026-09-06 | fix: complete public parent request count projection |
| `origin/fix/159-trusted-fixture-modes` | 4 | 2026-09-06 | test: pin check usage fixture mode |
| `origin/fix/162-preserve-name` | 5 | 2026-09-06 | fix(wizard): restore the name when returning from Face |
| `origin/fix/164-open-wifi-failure` | 2 | 2026-09-06 | fix: give open wifi failures actionable feedback |
| `origin/fix/178` | 2 | 2026-09-06 | fix: reject unsupported QMP text before typing |
| `origin/fix/182-card-confirm-prompt` | 2 | 2026-09-07 | test: isolate card confirm mode |
| `origin/integration/200-201-air` | 30 | 2026-09-08 | fix(launcher): dispatch focus objects through hyprctl |
| `origin/prototype/120-native-gum-header` | 3 | 2026-09-05 | fix: keep native wizard footer inside gum |

## Conflicts (15)

| Branch | Files | Last commit | Subject |
| --- | --- | --- | --- |
| `origin/boot-5` | 14 | 2026-09-04 | fix: harden parent auth against hostile PATH |
| `origin/boot-6` | 6 | 2026-09-04 | feat: add wizard boot mode selection |
| `origin/dogfood/welcome-evidence` | 575 | 2026-09-07 | docs: record Air first-child login blocker and correction |
| `origin/fix/103-fixture-lock-env` | 46 | 2026-09-05 | test: isolate media driver lock fixture |
| `origin/fix/103-session-cleanup` | 46 | 2026-09-06 | Merge readable wizard help into media capture branch |
| `origin/fix/128-password-label` | 1 | 2026-09-06 | test: keep portal suite focused |
| `origin/fix/143-empty-wifi-ui` | 3 | 2026-09-06 | fix: explain empty Wi-Fi scans and offer retry (#143) |
| `origin/fix/145-wifi-password-delivery` | 3 | 2026-09-06 | test(wifi): execute running and started delivery events |
| `origin/fix/174-desktop-words` | 4 | 2026-09-06 | test: pin desktop level wording independently |
| `origin/fix/176-current-input` | 7 | 2026-09-06 | test: cover current input card rendering |
| `origin/fix/91-respect-show-missing` | 9 | 2026-09-06 | docs: fix manifest producer attribution |
| `origin/fix/media-bar-wifi` | 62 | 2026-09-06 | feat: capture release media and improve bar and Wi-Fi interactions |
| `origin/media-driver` | 14 | 2026-09-05 | fix: capture bar from live owner session |
| `origin/parent-slot` | 11 | 2026-09-03 | docs: update the stale "luks-slots lives in lib/posture.sh" references |
| `origin/vmtests` | 29 | 2026-09-03 | The terminal is Omarchy's, and so is the sibling lookup (review 1.3, 1.4) |

## Already content-merged (45)

These are the branches whose diff against their own base is empty; their work is already in `main`
by another path (often a squash or a direct commit). They are deletion candidates, not gate work.

| Branch | Files | Last commit | Subject |
| --- | --- | --- | --- |
| `origin/arch-specs` | 0 | 2026-09-03 | docs: specify data-driven screens |
| `origin/aur-docs` | 0 | 2026-09-03 | docs: align install and packaging guides with package behavior |
| `origin/authd` | 0 | 2026-09-02 | authd: try libcrypt.so.2 first (Arch libxcrypt soname); test probe likewise |
| `origin/boot-1` | 0 | 2026-09-04 | docs: boot.md states R-BOOT-2's drop-in filename as SPEC names it |
| `origin/boot-2` | 0 | 2026-09-05 | test: drive packaging race through boot setter |
| `origin/boot-3` | 0 | 2026-09-04 | docs: record deferred boot mode locking |
| `origin/boot-4` | 0 | 2026-09-05 | fix: make kid removal power-loss recoverable |
| `origin/boot-hook` | 0 | 2026-09-02 | boot-login: run every boot (no slot means the portal); units wanted by multi-user; SPEC R-BOOT-2/3 corrected |
| `origin/feat/200-simplified-desktop` | 0 | 2026-09-08 | fix(launcher): dispatch focus objects through hyprctl |
| `origin/fix/110-visible-keyboard-help` | 0 | 2026-09-05 | Clarify indirect TUI test fixtures |
| `origin/fix/119-readable-keyboard-help` | 0 | 2026-09-05 | docs: align wizard footer color guidance |
| `origin/fix/136-empty-wifi-reply` | 0 | 2026-09-06 | fix: narrow wifi reply framing |
| `origin/fix/148-preserve-success-next` | 0 | 2026-09-06 | fix(wifi): preserve joined-network confirmation after refresh |
| `origin/fix/166-choice-default` | 0 | 2026-09-06 | test: cover non-tty gum default seam |
| `origin/fix/167-visible-summary` | 0 | 2026-09-06 | style: apply test-box formatting to summary regression |
| `origin/fix/170-weekend-label` | 0 | 2026-09-06 | docs: name all advanced-only settings |
| `origin/fix/172-advanced-app-row` | 0 | 2026-09-07 | style: match test-box shell formatting |
| `origin/fix/180-app-picker-stdin` | 0 | 2026-09-07 | style: apply test-box formatting to app picker fix |
| `origin/fix/185-prefetch-tty` | 0 | 2026-09-07 | test: distinguish prefetch EOF from timeout and tty input |
| `origin/fix/187-portal-provision-flags` | 0 | 2026-09-07 | fix(wizard): omit disk flags in portal mode |
| `origin/fix/195-apply-safety-namespace` | 0 | 2026-09-07 | test(namespace): isolate assertion probe |
| `origin/fix/197-prelogin-safety` | 0 | 2026-09-07 | style: apply session formatter spacing |
| `origin/fix/201-parent-theme-geometry` | 0 | 2026-09-07 | test(portal): include geometry helper in live library fixture |
| `origin/fix/session-time-reentry` | 0 | 2026-09-06 | style(time): apply VM formatter to state fixture |
| `origin/launcher-exec` | 0 | 2026-09-03 | test: cover trusted launcher activation |
| `origin/launcher-frame` | 0 | 2026-09-04 | fix: keep level 1 launcher edge to edge |
| `origin/lows` | 0 | 2026-09-03 | Keep the two evals: the dev Mac's /bin/bash is 3.2 and the suite runs there too |
| `origin/manifest-1` | 0 | 2026-09-03 | shfmt: lib/session-manifest.sh |
| `origin/manifest-2` | 0 | 2026-09-03 | session-test: the fake stat answers GNU formats too (the wrong-mode case only bit on the VM); shfmt |
| `origin/manifest-3` | 0 | 2026-09-03 | test: align web checks with session manifests |
| `origin/manifest-4` | 0 | 2026-09-03 | Prove the manifest-backed live launcher |
| `origin/manifest-4-land` | 0 | 2026-09-04 | shfmt: scenario 10 after the merge |
| `origin/modal-finish-only` | 0 | 2026-09-04 | docs: describe finish-only exit modal |
| `origin/panel-facts` | 0 | 2026-09-03 | panel-test: assert the fact ordering the way real gum renders it |
| `origin/parent-docs` | 0 | 2026-09-03 | parent-card: fix the fast-user-switch claim, drop spec jargon |
| `origin/portal-quote` | 0 | 2026-09-05 | shfmt: format the two files the real box's formatter rewrites |
| `origin/portal-tiles` | 0 | 2026-09-04 | test: observe finalized portal tile count |
| `origin/review3` | 0 | 2026-09-03 | Review 3: the maintainer's eye (docs/reviews/2026-09-03-maintainer-eye.md) |
| `origin/roottime-1` | 0 | 2026-09-03 | fix: preserve elapsed time on clock jumps |
| `origin/roottime-2` | 0 | 2026-09-03 | test: cover the root enforcement timestamp |
| `origin/roottime-3` | 0 | 2026-09-04 | shfmt: trust-boundary-test |
| `origin/roottime-4` | 0 | 2026-09-04 | test: prove root screen-time recovery live |
| `origin/schema-1` | 0 | 2026-09-04 | shfmt: conf-test |
| `origin/spec-07` | 0 | 2026-09-04 | spec 07: order the tickets for the Air (portal consumers before transitions); note the sudo tee root cause |
| `origin/trust-paths` | 0 | 2026-09-03 | wifi-test: section B gets its own quickshell stub (STUBS was unbound on the VM) |

## Local loop branches (not pushed, 2026-09-18)

The review-driven loop's branches exist only on this machine. Stack arrows mean the child contains
its parent's commits.

| Branch | Base | What |
| --- | --- | --- |
| `fix/time-lock-engagement` | `main` | Root lock engagement and manager-session filtering. |
| `docs/truth-pass-2026-09-18` | `main` | Docs truth pass. |
| `fix/wizard-honesty` | docs truth branch | Wizard honesty pass and its review round. |
| `fix/panel-write-results` | `main` | Panel write-result notices. |
| `feat/panel-machine` | panel write-results | P4 Machine screen. |
| `fix/panel-request-names` | panel machine | Request display names. |
| `test/theme-palette-parity` | `main` | Fallback palette parity test. |
| `docs/command-metadata` | docs truth branch | `omarchy:hidden` and header fixes. |
| `fix/kid-surface-words` | `main` | Time's Up / footer / exit-card wording. |
| `fix/launcher-empty-hints` | `main` | Level 1 hints and empty state. |
| `fix/qml-fonts` | `main` | One theme font across every surface. |
| `docs/loop-report-2026-09-18` | `main` | The running account for these rounds. |
