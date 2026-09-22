# Branch conflict map, 2026-09-22

For the owner's merge gate: which of the branches ahead of `integration/dogfood-2026-09-19`
touch the same files, so a merge order can put the collisions where they can be seen. This is a
read-only analysis (no branch was merged), and the counts are potential conflicts -- merging
sequentially decides the actual ones.

Method: for every remote branch not merged into integration, the files it changes versus its own
merge-base are collected and counted per file. 58 branches, 252 file entries.

## What this means

The collisions cluster by topic: **panel** (7 branches share `panel-test.sh`), **time/toast**
(5 share `time-test.sh`), **launcher** (4 share `launcher/shell.qml`), **data** (3 share
`lib/data.py`, `bin/omarchy-kids-data` and `data-test.sh` together), **packaging** (3 share
`PKGBUILD`, and two share the systemd units and `assert-test.sh`), and **levels/Level 2** (4 share
`share/hyprland/L2.lua`). Merges inside a cluster will conflict in that cluster's files; take those
clusters one branch at a time and re-run the suite after each. Outside the clusters the branches are
disjoint, so an arbitrary order is safe there.

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
