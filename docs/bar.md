# The parent's bar widget: `bin/omarchy-kids-bar`, `share/bar/` (SPEC.md R-BAR, I-1; issue #37)

One dot per kid currently logged in, a badge with the count of open "ask a parent" requests, and
a click/Enter menu with quick actions -- installed only when the parent asks for it, never by the
wizard on its own (I-1: "Writes into the parent's own files happen only when the parent asks (bar
widget, ...)").

## The two pieces

| Piece | What it is |
| --- | --- |
| `share/bar/manifest.json`, `share/bar/KidsModule.qml` | The widget itself: an Omarchy shell plugin (see "Omarchy's real bar architecture" below) |
| `bin/omarchy-kids-bar` | `enable` / `disable` / `status` / `grant <kid> <minutes>` / `end <kid>` -- the only thing that ever touches the parent's own `~/.config/omarchy/shell.json` for this |

Nothing else in this package writes to either file. `bin/omarchy-kids-wizard`'s Done screen only
*mentions* `omarchy-kids-bar enable` in its Omy line -- see "Why this isn't a wizard yes/no
prompt" below.

Issue #37 also says the widget should be "removable from the panel". `bin/omarchy-kids-panel`
(issue #21) exists now but has no bar-widget row of its own yet, so `omarchy-kids-bar disable
[--apply]` remains the removal path; a future panel change can wire a row to it there. The panel
has no end-session action either, so the "call it instead of loginctl" half of this issue's
correction (below) only touches `bin/omarchy-kids-bar`.

## Omarchy's real bar architecture (confirmed against omacom/omarchy, tag v4.0.2)

Unlike most of this repo's Quickshell files, this one targets Omarchy 4.0.2's real, documented
plugin system, read directly from the upstream source while writing it (not guessed from general
Quickshell knowledge):

- `manual/32-shell-plugins.md`, `shell/README.md` -- the plugin/manifest contract. The bar is one
  long-running Quickshell process (`omarchy-shell`) hosting first-party plugins under
  `$OMARCHY_PATH/shell/plugins/` and third-party ones dropped into
  `~/.config/omarchy/plugins/<id>/`, "discovered the same way" by the same process. A plugin is a
  directory with a `manifest.json` (`schemaVersion`, `id`, `kinds`, `entryPoints`) plus QML. A bar
  widget is turned on or off by adding or removing its id from `bar.layout.<left|center|right>` in
  `~/.config/omarchy/shell.json`; the real `omarchy plugin enable/disable` and `omarchy bar
  put/move` commands do that mutation on a live box.
- `shell/Ui/BarWidget.qml`, `shell/Ui/Panel.qml`, `shell/Ui/KeyboardPanel.qml`,
  `shell/Ui/PanelKeyCatcher.qml` -- the base types `KidsModule.qml` extends/uses. `Panel` (not the
  lighter `BarWidget`) is the root type, because this widget needs a click-to-open popup, same
  shape as two first-party examples this file's structure mirrors:
  `shell/plugins/panels/clock/BarWidget.qml` (icon + popup) and
  `shell/plugins/panels/power/Panel.qml` (icon + `KeyboardPanel` + `PanelKeyCatcher` + a `Column`
  of action rows -- the exact shape of this widget's menu).

**Why `bin/omarchy-kids-bar` edits `shell.json` with `jq` instead of shelling out to the real
`omarchy plugin`/`omarchy bar` commands:** those are the sanctioned way to do this on a live,
installed Omarchy box, but this issue's tests need to run against fixture trees with no
`omarchy-shell` or `omarchy` CLI present at all, and need an exact contract (back up once, add the
widget, disable restores byte-for-byte) that a plain `omarchy plugin disable` was never asked to
give you (it removes the layout entry; it was never asked to restore an original file). `enable`
still calls `omarchy-shell shell rescanPlugins` best-effort afterward, and `disable` calls
`omarchy-shell shell reloadConfig` best-effort, so a running shell picks the change up without a
logout -- both are no-ops (never fail the command) when no shell is running, which is every test
and most of local development.

**What is not confirmed:** whether a *third-party* plugin under `~/.config/omarchy/plugins/` can
`import qs.Ui` / `import qs.Commons` the same way a first-party one under `$OMARCHY_PATH/shell/
plugins/` does. The docs say both are discovered "the same way" by the same process, which implies
yes, but no third-party plugin source was available to confirm the import resolves outside
`$OMARCHY_PATH`. If it doesn't, on a live box the fix is almost certainly vendoring the small
pieces of `qs.Ui` this widget needs (`Panel`, `KeyboardPanel`, `PanelKeyCatcher`) into
`share/bar/` itself instead of importing the shell's copy -- confirm this first (see "What's
unverified" below).

## `bin/omarchy-kids-bar`

```text
omarchy-kids-bar enable [--apply]
omarchy-kids-bar disable [--apply]
omarchy-kids-bar status
omarchy-kids-bar grant <kid> <minutes>
omarchy-kids-bar end <kid>
omarchy-kids-bar approve <id>
omarchy-kids-bar decline <id>
omarchy-kids-bar review-approve <kid> <id>
omarchy-kids-bar review-deny <kid> <id>
omarchy-kids-bar review-check <kid> <id>
omarchy-kids-bar notify-enable [--apply]
omarchy-kids-bar notify-disable [--apply]
omarchy-kids-bar notify-status
```

`enable`:

1. Installs `share/bar/{manifest.json,KidsModule.qml}` into
   `~/.config/omarchy/plugins/omarchy-kids.bar/`.
2. If `~/.config/omarchy/shell.json` already exists, backs it up once to
   `shell.json.omarchy-kids.bak`, then adds `{"id": "omarchy-kids.bar"}` to `bar.layout.right`
   (everything else in the file -- other widgets, `plugins[]`, `idle`, ... -- is left untouched).
3. If it does **not** exist yet, seeds a new one from `$OMARCHY_PATH/config/omarchy/shell.json`
   (Omarchy's own shipped defaults -- reading that file is not an I-7 core edit; nothing under
   `$OMARCHY_PATH` is written) and remembers that it did (a
   `~/.config/omarchy/.omarchy-kids-bar-created-shell-json` marker), so `disable` can delete the
   file it created instead of leaving a stray `shell.json` a fresh install never had.
4. If **neither** exists, refuses (exit 1) rather than invent a bar config from nothing -- I-1:
   never risk silently discarding whatever else would have been on the parent's real bar.
5. Idempotent: enabling twice adds nothing a second time and never re-backs-up.

`disable` is the exact inverse: restores the backup and deletes it, or deletes the `shell.json` it
created, or (if for some reason neither applies) surgically drops just this widget's layout
entries. The installed plugin files under `~/.config/omarchy/plugins/` are left in place -- same
as `omarchy plugin disable` on a first-party widget (`shell/README.md`: "leaving its component
available to add again"). Idempotent: disabling an already-disabled bar is a no-op.

`grant <kid> <minutes>` is what the widget's own "give N more minutes" menu row runs (see
"Actions" below) -- it is not something a parent normally types by hand. `end <kid>`, `approve
<id>` and `decline <id>` are the same shape for the widget's "end session" row and for the
desktop notification's Approve/Decline actions (N-9, R-NOTIFY): a floating terminal running
`sudo omarchy-kids-<time|exit|ask>` with the parent's own password. `review-approve`/`review-deny`
are the same shape for a changed add-on (`docs/review.md`, N-12): they run `sudo omarchy-kids-review
approve|deny <kid> <id>`. `review-check` shows the change (and decides nothing) with `sudo
omarchy-kids-review show <kid> <id>`.

`notify-enable` turns on the desktop notifier (`docs/notify.md`) on the same consent as the widget:
it refuses until the widget is on, then `systemctl --user enable --now
omarchy-kids-notify-watch.service` (the unit ships in `/usr/lib/systemd/user/`, so nothing is
copied). `notify-disable` stops and disables it; `notify-status` prints `enabled`/`disabled`.

DRY_RUN=1 is the default for `enable`/`disable`/`notify-enable`/`notify-disable` (AGENTS.md rule 8);
`--apply` (or `DRY_RUN=0`) makes them real. `grant`/`end`/`approve`/`decline`/`review-approve`/`review-deny`/`review-check` run for real by default
-- a parent clicked a button or a notification action, opening a terminal -- and `--dry-run` prints
the plan instead and opens no terminal. Disabling the widget also disables its notifier (the same
consent, both ways).

## `share/bar/KidsModule.qml`

- Reads `/run/omarchy-kids/status.json` (R-BAR-3) via a `FileView` with `watchChanges: true`
  and reloads its contents on `fileChanged`, as required by the
  [Quickshell FileView API](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/).
  Renders nothing when the file is missing, empty, or fails to parse (I-6: no control shown for
  data that isn't there).
- One dot per kid whose row has `"live": true`: the initial letter of the kid's slug (`kid-ada` →
  `A`), colored differently while `"paused": true`.
- A badge with the count of open requests, refreshed every 30s by running `omarchy-kids-ask list`
  in a `Process` and counting its output lines (that command prints a plain aligned table or the
  literal line `omarchy-kids-ask: no open requests` -- there is no `--json`/`--count` mode, so this
  counts lines rather than adding a new output mode to a command another issue owns).
- Click or Enter opens a menu: two-line "Give 15 more" and "End session" rows for each live kid,
  with the affected kid's status and minutes on the detail line (R-BAR-1's
  "Ada · paused · 32 min"), then "Open requests" and "Open Kids Mode".

### Actions (R-BAR-2: "give more time, end session, open Kids Mode")

| Menu row | Runs |
| --- | --- |
| `Give 15 more` / `<K> · live/paused · N min` | `omarchy-kids-bar grant <kid> 15` |
| `End session` / `<K> · live/paused · N min` | `omarchy-kids-bar end <kid>` |
| `Open requests` | `omarchy-kids --requests` |
| `Open Kids Mode` | `omarchy-kids` |

`Open requests` is a fourth row this widget carries beyond R-BAR-2's exact three, grounded in
SPEC.md's own Ask flow description ("Kid action → modal → password on the spot, or queue → panel
or bar widget approve → action") rather than invented -- see "Why 'Open requests' isn't a deep
link" below.

**Why "give more time"/"end session" aren't direct calls to `omarchy-kids-time grant` /
`omarchy-kids-exit`:** granting time and ending a session both need root, and this widget runs in
the parent's ordinary, unprivileged bar/shell process. `omarchy-kids-bar grant`/`end` open a real
terminal for a plain `sudo` prompt -- the parent's own login password (I-8), the same mechanism
`bin/omarchy-kids-wizard`'s own Apply step uses (plain `sudo`, not a `rootpw`), not a polkit
action, because none is defined for `omarchy-kids-time grant` or `omarchy-kids-exit --finish`
(R-FND-3's polkit rules cover NetworkManager/udisks/systemd-manage-units/pacman, not this). Both
open Omarchy's own `omarchy-launch-floating-terminal-with-presentation` helper (confirmed to exist
in `omacom/omarchy`'s `bin/` at v4.0.2), trusted the same way this package already trusts
`/usr/bin/omarchy-launch-shell` — the `alacritty -e` fallback this used to carry is not installed
on a stock 4.0.2 box at all (review 1.4).

**"End session" never calls `loginctl` directly -- this was a live-testing correction.** The first
version of this issue had `omarchy-kids-bar end` run `sudo loginctl terminate-user <kid>` itself.
Live testing of R-EXIT-3's Finish flow (`docs/exit.md`'s "Verified live") found that a hard
`loginctl terminate-session`/`terminate-user` on a still-live session makes `sddm-helper` exit 1 --
SDDM logs "Process crashed" and starts **no greeter at all**, a black screen until `systemctl
restart sddm`. Only a clean Hyprland exit reliably brings the greeter back. So `end <kid>` now runs
`sudo omarchy-kids-exit --finish --kid <kid>` (that command's own root-side mode, added alongside
this fix): it finds `<kid>`'s Hyprland instance(s) under `/run/user/<uid>/hypr/<signature>/` on
disk (this process has no session id or `HYPRLAND_INSTANCE_SIGNATURE` of its own for `<kid>`'s
session -- those live in that session's environment, not this process's), asks each to exit
cleanly via `runuser -u <kid> -- env ... hyprctl dispatch 'hl.dsp.exit()'`, waits up to
`OMARCHY_KIDS_EXIT_WAIT` seconds, and only falls back to `loginctl terminate-user <kid>` (not
`terminate-session`: no session id is known here, so this ends every session the account has) if
Hyprland never left. See `docs/exit.md` for the full mechanism and its own "What's unverified" --
the exact `runuser`/`hyprctl` sequence, and whether `terminate-user` is actually any safer than
`terminate-session` given the same crash finding, were never run against a live multi-session box.

**Why "Open requests" isn't a deep link into the panel's Requests screen:** `bin/omarchy-kids-panel`
(issue #21) has a real Requests screen (P3, R-ASK-2) now, but no CLI flag to open straight to it,
and a bar-widget click wants something faster than launching the full interactive panel anyway.
`omarchy-kids --requests` (added in this issue) prints `omarchy-kids-ask list`'s own output right
there instead -- a quick look, not a deep link, honestly scoped to what it actually is.

## `/run/omarchy-kids/status.json` permissions (R-BAR-3)

`bin/omarchy-kids-time-ledger`'s `write_status_json` already writes exactly what SPEC.md R-BAR-3
asks for: `chmod 0640` plus a best-effort `chgrp omarchy-parents` (never fails the tick if the
group doesn't exist or the chgrp fails for any other reason). `test/shell.d/bar-test.sh` asserts
this.

**A note on this issue's own instructions vs. the spec:** the task that produced this issue said to
make the file "world-readable... fix it to 0644 if it is not". SPEC.md R-BAR-3 says "group
`omarchy-parents` readable" (0640, not 0644) -- world-readable would let every kid account read
every other kid's live minutes-left and paused state, which nothing else in this spec does (R-DATA
carefully scopes what's visible to whom). Per AGENTS.md ("if a ticket and the spec disagree, the
spec wins and the ticket gets a comment"), this keeps the ledger's existing 0640/`omarchy-parents`
behavior unchanged rather than loosening it, and this paragraph is that comment.

## Why this isn't a wizard yes/no prompt

GitHub issue #37's own "Done when" list says the widget is "Enabled by the wizard's consent line
on the summary screen" (A13). SPEC.md's Appendix A row for A13 is just as exact as A14's, though:
a fixed bullet list ("Here's what happens next...") and exactly two Buttons ("Apply" / "Change
something") -- no third choice, same as A14 (Done). Either screen would mean adding a new
`tui_screen_confirm`/`tui_screen_choose` prompt that consumes its own answer in `TUI_MODE=file`,
which breaks every existing `answers_file(...)` sequence in `test/shell.d/wizard-test.sh` (each
currently ends `... apply parent`: the summary confirm, then Done's own choice, nothing in
between -- inserting a step anywhere in that chain shifts every answer after it).

Per AGENTS.md ("if a ticket and the spec disagree, the spec wins and the ticket gets a comment"),
neither A13 nor A14 gained a new prompt; Done's (A14) Omy line mentions `omarchy-kids-bar enable`
in its own text instead, once Apply has actually succeeded -- Done is the natural "one more thing,
now that you're set up" moment, and I-1's "only on consent" holds either way, since nothing runs
until the parent runs that command themselves. This paragraph, plus the status.json one above, are
this issue's two spec-vs-ticket comments.

## Env (every path overridable, per AGENTS.md rule 8)

| Var | Default | What |
| --- | --- | --- |
| `OMARCHY_KIDS_HOME` | `$HOME` | the parent's home |
| `OMARCHY_KIDS_SHARE` | `/usr/share/omarchy-kids` | `share/bar/manifest.json`, `KidsModule.qml` |
| `OMARCHY_PATH` | `/usr/share/omarchy` | Omarchy's own install root (a real Omarchy session var, confirmed against `etc/profile.d/omarchy.sh` / `default/bash/env-bootstrap` upstream -- not one of ours) |
| `DRY_RUN` | `1` | gates `enable`/`disable` |

`share/bar/KidsModule.qml` reads one env value at runtime (`Quickshell.env(...)`):
`OMARCHY_KIDS_STATUS_JSON` (default `/run/omarchy-kids/status.json`). The commands it runs are
absolute and hardcoded, not from the environment (AGENTS.md rule 9): `/usr/bin/omarchy-kids-ask`,
`/usr/bin/omarchy-kids-bar`, `/usr/bin/omarchy-kids`.

## What's unverified -- check in the VM

No Quickshell install, headless or otherwise, was available while writing `KidsModule.qml`.
In order of what to check first:

1. **Does the widget appear on the bar at all** once `omarchy-kids-bar enable --apply` runs and
   `omarchy-shell shell rescanPlugins`/a re-login picks it up. This is the load-bearing unknown:
   if `import qs.Ui` doesn't resolve for a plugin under `~/.config/omarchy/plugins/` the way it
   does for one under `$OMARCHY_PATH/shell/plugins/`, this file needs its own copy of `Panel` /
   `KeyboardPanel` / `PanelKeyCatcher` (see "What is not confirmed" above).
2. With a kid logged in (and paused, via `omarchy-kids-time` or `bin/omarchy-kids-panel`): does
   the dot appear, with the right initial, and does its color/label change when paused?
3. Click the widget, then Enter/arrows/Escape with no mouse (I-5): does the menu open, navigate,
   and close the way `PanelKeyCatcher` promises? Also unconfirmed: whether the bar itself can hand
   keyboard focus to this widget pre-click (e.g. Tab-cycling bar icons) -- harmless if it can't,
   since a mouse click always opens the menu too and I-5 holds from there.
4. "Give 15 more minutes" on a live kid: does a terminal open, prompt for the parent's own login
   password via plain `sudo`, and does `omarchy-kids-time status <kid>` reflect the grant
   afterward?
5. "End session" on a live kid: does `sudo omarchy-kids-exit --finish --kid <kid>` find the
   right `/run/user/<uid>/hypr/<signature>/`, does `runuser -u <kid> -- ... hyprctl dispatch
   'hl.dsp.exit()'` actually reach that Hyprland instance from a root shell, does the portal come
   back cleanly (not the "Process crashed" black screen docs/exit.md's Verified-live section
   describes), and does the `loginctl terminate-user` fallback ever actually get exercised (i.e.
   does the clean-exit path work often enough that it doesn't) -- see docs/exit.md's own "What's
   unverified" for this in detail.
6. "Open requests" / "Open Kids Mode": do they print/launch what `bin/omarchy-kids` now does for
   `--requests` / no args?
7. `omarchy-kids-bar disable --apply` on a bar that has other, unrelated customizations (a real
   parent's real `shell.json`, not a fixture): confirm nothing else moves.

## Test coverage

`test/shell.d/bar-test.sh`: `enable`/`disable`'s exact `shell.json` edits against fixtures (no
existing file + no defaults → refuses; no existing file + defaults present → seeds and marks
"created"; a pre-existing, already-customized file → backs up once, adds the widget alongside
what's there, idempotent, `disable` restores the exact original bytes and removes the backup),
`grant`/`end`'s terminal-helper selection and argument validation (`end`'s own stub confirms it
calls `omarchy-kids-exit --finish --kid`, never `loginctl` directly), and `status.json`'s mode
(R-BAR-3). `test/shell.d/exit-test.sh` covers `omarchy-kids-exit --finish --kid` itself: the root
check, `--kid` only valid with `--finish`, the `runuser`/`hyprctl` dispatch with stubbed
`id`/`runuser`/`pgrep`, Hyprland leaving on its own vs. the `loginctl terminate-user` fallback
(never `terminate-session`), no signature directory found, and an unknown account.
`KidsModule.qml`'s own JSON parsing is QML/JS inline in the plugin (not a separate bash/python
script), so there is no bash unit test for it here -- item 4 above is the VM check that covers it.

## Verified live (2026-09-02, QEMU test VM)

`omarchy-kids-bar enable --apply` as the owner installed the plugin under
`~/.config/omarchy/plugins/omarchy-kids.bar/` and added it to `shell.json`; Omarchy's shell loaded
`KidsModule.qml` without QML errors. It rendered nothing until the owner was a member of
`omarchy-parents` (status.json is 0640 for that group): the new `parent-group` lock in
`omarchy-kids-assert` adds the parent, and the membership takes effect at the next login. After
an SDDM restart the module showed its kid indicator at the right end of the bar. The popup
menu, grant and end actions are not yet exercised live.

## Source header (moved from `bin/omarchy-kids-bar`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-bar: the only thing that ever touches the parent's own bar
config for Kids Mode (SPEC.md R-BAR, I-1's "Writes into the parent's own
files happen only when the parent asks (bar widget, ...)"). See
docs/bar.md for the full picture; share/bar/KidsModule.qml is the widget
itself.

Omarchy 4.0.2's bar is a Quickshell "shell plugin" (confirmed against
omacom/omarchy at tag v4.0.2 -- shell/README.md, manual/32-shell-
plugins.md): a plugin is a directory with a manifest.json plus QML,
dropped into ~/.config/omarchy/plugins/<id>/, and turned on or off by
adding or removing its id from the `bar.layout.<section>` array in
~/.config/omarchy/shell.json. The real `omarchy plugin enable/disable`
and `omarchy bar put/move` commands are the sanctioned way to do that on
a live box; this script edits shell.json directly with jq instead, for
two reasons: it needs to work (and be testable against fixtures) without
a running `omarchy-shell` or the `omarchy` CLI at all, and it needs to
make the exact "back up, idempotent, disable restores" contract this
issue asks for (and that a plain `omarchy plugin disable` doesn't fully
give you: it removes the layout entry, but was never asked to restore a
byte-for-byte original).

  enable   Installs share/bar/{manifest.json,KidsModule.qml} into
           ~/.config/omarchy/plugins/omarchy-kids.bar/, then adds
           {"id": "omarchy-kids.bar"} to shell.json's bar.layout.right
           if it isn't already there. If ~/.config/omarchy/shell.json
           already exists, it is backed up first (once) to
           shell.json.omarchy-kids.bak. If it does not exist yet, this
           seeds a new one from $OMARCHY_PATH/config/omarchy/shell.json
           (Omarchy's own shipped defaults -- shell.json is per-user
           state, not a file "owned by the omarchy package", so this is
           not an I-7 core edit) and remembers that it did, so `disable`
           can remove the file it created rather than leaving a stray
           shell.json a fresh install never had. Refuses to invent a
           shell.json from nothing (I-1: never risk silently discarding
           whatever else is on the parent's real bar).
  disable  Removes the widget from shell.json: restores the backup (and
           deletes it) if enable made one, deletes the file entirely if
           enable created it, otherwise surgically drops just this
           plugin's layout entries. Idempotent: disabling twice, or a
           box that was never enabled, is a no-op. The installed plugin
           files under ~/.config/omarchy/plugins/ are left in place --
           same as `omarchy plugin disable` on a first-party widget
           (shell/README.md: "leaving its component available to add
           again").
  status   Prints "enabled" or "disabled" (for scripts/tests).
  grant <kid> <minutes>
           What the bar widget's "give N more minutes" menu row actually
           runs (bin/omarchy-kids-bar grant kid-ada 15, via a detached
           Quickshell Process -- KidsModule.qml never calls
           bin/omarchy-kids-time itself). `omarchy-kids-time grant`
           refuses to run as anyone but root, and this widget lives in
           the parent's own ordinary session, so this opens a real
           terminal for a plain `sudo` prompt -- the parent's own login
           password (I-8), same mechanism bin/omarchy-kids-wizard's own
           Apply step uses, not a polkit action (none is defined for
           `omarchy-kids-time grant` -- see bin/omarchy-kids-time's own
           header). Opens Omarchy's
           omarchy-launch-floating-terminal-with-presentation helper
           (confirmed to exist in omacom/omarchy's bin/ at v4.0.2).
  end <kid>
           R-BAR-2's "end session" action -- same terminal/sudo shape as
           grant, running `sudo omarchy-kids-exit --finish --kid <kid>`
           (that command's own root-side mode, added alongside this
           fix -- see its header and docs/exit.md). NEVER calls
           loginctl directly: a hard `loginctl terminate-user`/
           `terminate-session` on a still-live session makes
           sddm-helper exit 1 and SDDM show nothing at all until
           `systemctl restart sddm` (found live 2026-09-02, docs/
           exit.md) -- `omarchy-kids-exit --finish` asks the kid's own
           Hyprland to exit cleanly first and only falls back to
           loginctl if that doesn't work.

Every path is overridable for tests, same convention as every other
command here:
  OMARCHY_KIDS_HOME              parent's home (default $HOME)
  OMARCHY_KIDS_SHARE             default /usr/share/omarchy-kids
                                 (share/bar/manifest.json, KidsModule.qml)
  OMARCHY_PATH                   Omarchy's own install root -- this is a
                                 real Omarchy session env var (see
                                 /usr/share/omarchy/default/bash/env-
                                 bootstrap upstream), not one of ours;
                                 default /usr/share/omarchy
  DRY_RUN                        default 1 (AGENTS.md rule 8); --apply
                                  or DRY_RUN=0 makes enable/disable real.
                                  `grant` always runs for real (it is a
                                  parent clicking a button in their own
                                  session, same reasoning as
                                  bin/omarchy-kids-ask's submit/time/app/
                                  plugin/site -- there is no plan to dry-
                                  run, only a terminal to open).
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
