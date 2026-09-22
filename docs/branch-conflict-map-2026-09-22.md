# Branch conflict map, 2026-09-22

For the owner's merge gate: which of the branches ahead of `integration/dogfood-2026-09-19`
touch the same files, so a merge order can put the collisions where they can be seen. This is a
read-only analysis (no branch was merged), and the counts are potential conflicts -- merging
sequentially decides the actual ones.

Method: for every remote branch not merged into integration, the files it changes versus its own
merge-base are collected and counted per file. 58 branches, 252 file entries.

## What this means

A shared file is not a conflict. Testing every overlapping pair with `git merge-tree` shows only
**7 pairs conflict outside the shared docs**, in just two code areas: the packaging pair
(`fix/fresh-install-ordering` × `fix/install-packaging`) and `fix/launcher-insets-simplify` against
each of the other three `share/launcher/shell.qml` branches. Everything else that names the same
file auto-merges -- including all seven panel branches on `panel-test.sh`, and the data, time and
levels clusters. Those were file-name overlaps only, not line collisions. The one real constraint
is the shared running docs: `docs/loop-report.md` (52 branches) and `PROGRESS.md` (31) conflict on
nearly any pair and want a union.

## Real conflicts (pairwise `git merge-tree`, shared docs excluded)

| branches | conflicting files |
| --- | --- |
| `fix/fresh-install-ordering` × `fix/install-packaging` | `bin/omarchy-kids-assert`, `systemd/omarchy-kids-authd.service`, `systemd/omarchy-kids-time-ledger.service`, `test/shell.d/assert-test.sh` |
| `fix/launcher-insets-simplify` × `fix/launcher-time-left-refresh` | `share/launcher/shell.qml` |
| `fix/launcher-insets-simplify` × `fix/picker-slices-desktop-hint` | `share/launcher/shell.qml` |
| `fix/launcher-insets-simplify` × `fix/tile-labels-fit` | `share/launcher/shell.qml` |
| `fix/fresh-install-ordering` × `fix/python-shebang-absolute` | `docs/packaging.md` |
| `fix/launcher-time-left-refresh` × `fix/toast-icon-match` | `docs/time.md` |
| `fix/toast-clock-overlap` × `fix/toast-icon-match` | `docs/time.md` |

The two code areas and their resolutions are below; the `docs/time.md` and `docs/packaging.md`
pairs are prose.

### The launcher conflicts are one stale branch

All three `share/launcher/shell.qml` conflicts pair `fix/launcher-insets-simplify` with one of the
other launcher branches; those other three (`fix/launcher-time-left-refresh`,
`fix/picker-slices-desktop-hint`, `fix/tile-labels-fit`) are all based on the union and auto-merge
with each other. `fix/launcher-insets-simplify` branches from `07edb37` -- a merge commit one
minute before its own -- and its single change, dropping the duplicate `shortScreen` inset variant
for flat insets under the compact `root.margin`, is already in the union, which then added the
`minFitCell` fit mechanism the branch lacks. Merging it conflicts with the union-based branches and
adds nothing (a rebase would be an empty change): drop it.

### The packaging pair: one supersedes the other

`fix/fresh-install-ordering` is a strict superset of `fix/install-packaging`: the same
`arch=('any')` and the same `cd omarchy-kids-mode`, but its `bin/omarchy-kids-assert` falls through
to the no-kids branch so the machine-level **units** lock is still asserted (the other exits 0
early, skipping it), and its units add `StateDirectory`/`ConfigurationDirectory` plus `-` on *both*
`ReadWritePaths` (the other only relaxes the first path, and does not make the directory exist, so
the first GRANT on a fresh box still hits EROFS under `ProtectSystem=strict`). Merge
`fix/fresh-install-ordering` and drop `fix/install-packaging`; resolve the conflict by taking its
side wholesale, not by hand-unioning the two assert bodies.

## Shared running docs (nearly every loop branch edits these)

| file | branches |
| --- | --- |
| `docs/loop-report.md` | 52 |
| `PROGRESS.md` | 31 |
| `CHANGELOG.md` | 1 |

Resolve these by union, not by picking a side.

## Code, config and test files touched by more than one branch

| file | # | branches |
| --- | --- | --- |
| `test/shell.d/panel-test.sh` | 7 | `origin/docs/loop-dogfood-clean` `origin/fix/ask-list-empty-minutes-shift` `origin/fix/panel-apps-not-installed` `origin/fix/panel-docs-live-status` `origin/fix/panel-machine-root-note` `origin/fix/panel-reset-claims` `origin/test/panel-wifi-mode-label` |
| `test/shell.d/time-test.sh` | 5 | `origin/fix/stale-threshold-name` `origin/fix/time-read-diagnostics` `origin/fix/time-status-fresh-grant` `origin/fix/timesup-key-hint` `origin/fix/toast-icon-match` |
| `share/launcher/shell.qml` | 4 | `origin/fix/launcher-insets-simplify` `origin/fix/launcher-time-left-refresh` `origin/fix/picker-slices-desktop-hint` `origin/fix/tile-labels-fit` |
| `share/hyprland/L2.lua` | 4 | `origin/docs/levels-l2-cheat-sheet-inert` `origin/docs/levels-two-apps-verified` `origin/docs/wifi-picker-verified` `origin/fix/l2-duplicate-cursor-rule` |
| `test/shell.d/trust-boundary-test.sh` | 3 | `origin/fix/python-shebang-absolute` `origin/fix/stale-threshold-name` `origin/fix/toast-icon-match` |
| `test/shell.d/levels-test.sh` | 3 | `origin/fix/apps-docs-manifest` `origin/fix/l2-duplicate-cursor-rule` `origin/fix/show-missing-regression` |
| `test/shell.d/launcher-grid-test.sh` | 3 | `origin/fix/launcher-time-left-refresh` `origin/fix/picker-slices-desktop-hint` `origin/fix/tile-labels-fit` |
| `test/shell.d/data-test.sh` | 3 | `origin/fix/data-browse-empty-title` `origin/fix/data-corrupt-history-traceback` `origin/fix/data-grants-in-summary` |
| `share/time/toast.qml` | 3 | `origin/fix/launcher-time-left-refresh` `origin/fix/toast-clock-overlap` `origin/fix/toast-icon-match` |
| `PKGBUILD` | 3 | `origin/fix/fresh-install-ordering` `origin/fix/install-packaging` `origin/fix/python-shebang-absolute` |
| `lib/data.py` | 3 | `origin/fix/data-browse-empty-title` `origin/fix/data-corrupt-history-traceback` `origin/fix/data-grants-in-summary` |
| `bin/omarchy-kids-data` | 3 | `origin/fix/data-browse-empty-title` `origin/fix/data-corrupt-history-traceback` `origin/fix/data-grants-in-summary` |
| `test/shell.d/session-manifest-test.sh` | 2 | `origin/fix/apps-docs-manifest` `origin/fix/show-missing-regression` |
| `test/shell.d/pkgbuild-test.sh` | 2 | `origin/fix/fresh-install-ordering` `origin/fix/install-packaging` |
| `test/shell.d/check-test.sh` | 2 | `origin/fix/boot-no-kid-luks-slots` `origin/fix/check-unreadable-warns` |
| `test/shell.d/assert-test.sh` | 2 | `origin/fix/fresh-install-ordering` `origin/fix/install-packaging` |
| `test/shell.d/ask-test.sh` | 2 | `origin/fix/ask-list-empty-minutes-shift` `origin/fix/modal-key-hints` |
| `systemd/omarchy-kids-time-ledger.service` | 2 | `origin/fix/fresh-install-ordering` `origin/fix/install-packaging` |
| `systemd/omarchy-kids-authd.service` | 2 | `origin/fix/fresh-install-ordering` `origin/fix/install-packaging` |
| `lib/wizard-advanced.sh` | 2 | `origin/fix/dns-control-honesty` `origin/fix/garden-sources-agree` |
| `lib/time.sh` | 2 | `origin/fix/time-read-diagnostics` `origin/fix/time-status-fresh-grant` |
| `lib/provision-add.sh` | 2 | `origin/feat/gcompris-preseed` `origin/style/shfmt` |
| `lib/panel-kid.sh` | 2 | `origin/fix/panel-apps-not-installed` `origin/fix/panel-reset-claims` |
| `lib/launcher-map.sh` | 2 | `origin/fix/apps-docs-manifest` `origin/fix/show-missing-regression` |
| `bin/omarchy-kids-time` | 2 | `origin/fix/time-status-fresh-grant` `origin/fix/toast-icon-match` |
| `bin/omarchy-kids-plugins` | 2 | `origin/fix/plugins-shelf-field-shift` `origin/style/shfmt` |
| `bin/omarchy-kids-assert` | 2 | `origin/fix/fresh-install-ordering` `origin/fix/install-packaging` |
