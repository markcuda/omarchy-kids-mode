# Everything after the first kid: `bin/omarchy-kids-panel` (SPEC.md R-WIZ-7, R-WIZ-8, R-ASK-2, R-TIME-4/5, R-FND-6; issue #21)

Once at least one kid is provisioned, `omarchy-kids` opens this instead of the wizard
(`bin/omarchy-kids-wizard` stays reachable as `omarchy-kids wizard`, and as this panel's own "Add
a kid" row — R-WIZ-7). Every screen is rendered by `lib/tui.sh` (issue #18) — this file never calls
`gum` directly, and drives entirely through `OMARCHY_KIDS_TUI_ANSWERS` in tests, same as the wizard
and its own test suite.

## Running it

```text
omarchy-kids-panel [--dry-run] [--apply] [--help]
```

`DRY_RUN=1` is the default everywhere a screen would write something (AGENTS.md rule 8): every
command a write would run is printed instead of run. Pass `--apply` (or set `DRY_RUN=0`) for a real
run.

## Screens (Appendix A's P1-P7; P5 is not built here — see "Not built here" below)

| Screen | What's on it |
| --- | --- |
| **P1 Home** | One row per kid — name, band, minutes used/left today, `paused` if a kid's time isn't counting right now, and their open-request count (`kid_home_line`) — then **Add a kid**, **Requests (N)**, **Notifications**, **Reviews (N)**, **Machine safety**, **Remove Kids Mode**, **Quit**. |
| **P2 Kid** | **Screen time** (today's status, "give more minutes" via `omarchy-kids-time grant`, weekday and weekend daily budgets and lights-out, all validated), **Web** (the band's mode; a walled-garden kid also gets an allow-list editor), **Wi-Fi** (Ask me first / On their own, safely), **Apps** (hide/show the band's pack), **Data**, **Desktop** (level, theme — issue #53), **Password**, **Reset to band defaults**, **Remove this kid**, **Back**. |
| **P3 Requests** | Every open "Ask a parent" request, each shown as `<name> — <what> (<age>)`; Enter opens the reason line and **Approve**/**Decline**. A request card names the kid by their display name and keeps the account name beside it. |
| **P4 Machine** | The read-only safety report (R-TRUST-2, `docs/check.md`): runs `omarchy-kids-check --json` on every draw, shows the verdict, every FAIL and WARN with the check's own detail in full, and the passed/skipped counts. **Check again** reruns it; nothing here writes or fixes. The panel runs unprivileged, so checks needing root report as warnings, and the card says so. Appendix A's firmware card is one of the report's checks, not a separate screen. |
| **P7 Reviews** | An approved app whose surface (`docs/review.md`, R-NOTIFY-12) changed since the parent approved it: one row per review ("changed since you approved it" or "was removed"), then Enter for a detail card with **Approve**, **Deny** (hides the app) and **Check** (shows what changed and decides nothing). The records are root-owned and group-readable, so the screen lists them with no privilege; **Approve** and **Deny** go through `run_priv`, and **Check** through `read_priv` (so it spends the one password prompt, like P6's devices list). |
| **P6 Notifications** | The parent's switch for device notifications (R-NOTIFY-1/3/5, `docs/notify.md`): the on/off state, **Turn on notifications** / **Turn off notifications** (with a confirm), **Pair a device** (starts a single-use window and shows the code and the relay's fingerprint), and **Paired devices** (each row can be revoked, with a confirm). Every call goes through `run_priv`/`read_priv`; the warmed sudo prompt is the parent's own authentication, so there is no second password prompt. |

Every screen is keyboard-complete (I-5): Esc or a **Back**/**Quit** row goes back or leaves; Ctrl+C
leaves the whole panel immediately, same contract as `lib/tui.sh` everywhere else (`docs/tui.md`).

**A screen's facts are its card's body, never an echo above it (review §3.1).** Card mode clears
the terminal at every step, so the status lines this panel used to `echo` before each menu — the
kid's band and minutes, the allow list, the request being approved, the whole Data screen — were
wiped before a parent could read them; only file mode (the tests, and the live SSH run) ever
showed them. Every panel screen now passes them to `tui_screen_choose`'s body argument, so they
render inside the rounded card under the title, in the theme's colours, in both render modes. A
screen that has nothing left to draw of its own hands its one line to the screen it returns to
instead (`KID_NOTICE` in `lib/panel-kid.sh`, `REQ_NOTICE` in `lib/panel-requests.sh`) — a failed
app-pack read, a mistyped remove confirmation, a request that vanished while it was open. Write
results travel the same way through `PANEL_NOTICE`: `run_priv` records preview / applied / failed
(plus the command's own line) and the next card renders it once.

### Home (P1)

`kid_home_line` reads `omarchy-kids-time status <kid>` for the used/left numbers and the `paused:`
line, and the ask queue (see below) for that kid's open-request count — nothing here re-derives
either; both are read the same way P2 and P3 read them, so the numbers always agree. **Add a kid**
`exec`s the wizard directly (R-WIZ-7: "the same per-kid screens"); when it finishes, a parent
re-opens `omarchy-kids` to get back to the panel, same as the wizard's own Done screen already
sends a parent back through the app entry point today.

**Remove Kids Mode** describes what removal does on a card of its own — every lock reversed, every
kid account removed, their files kept under the parent's home, a snapshot offered — and only hands
off to `bin/omarchy-kids-remove` (docs/remove.md) if the parent picks **Continue**. That command
still prints its whole plan and asks its own confirmation before it touches anything; the panel's
dry-run posture is passed through as `--dry-run`.

### One kid (P2)

- **Screen time** shows `omarchy-kids-time status <kid>` verbatim, then three actions:
  "Give more minutes today" (`omarchy-kids-time grant <kid> <n>`, R-TIME-4: extends *today's*
  budget only), and editing `budget_min` / `lights_out` (`omarchy-kids-conf set`), each validated
  the same way the wizard validates them (1-1440 minutes; `HH:MM`, 24-hour).
- **Web** shows the band's mode (`omarchy-kids-conf get <kid> web`). A `none`/`filtered` kid gets an
  info screen only — R-WEB-3 says those modes take no allow list, and I-6 means this panel doesn't
  offer to edit one that wouldn't do anything; **Remove a site** is likewise only offered when the
  kid has a site of their own to remove. A `garden` kid gets the kid's own
  `/etc/omarchy-kids/kids/<kid>/allow.txt` (the same file `omarchy-kids-ask`'s `apply_site` writes
  to for an approved "ask for a site" request, docs/ask.md) as an add/remove list, editor-free (no
  `$EDITOR` — every line add/remove is its own screen); either edit re-runs
  `omarchy-kids-web install <band> --allow <file> --apply` so the change actually takes effect.
- **Apps** lists the band's starter pack (`omarchy-kids-apps list <kid> --json`, parsed with `jq`
  — review 2.6, no more column-offset `cut` on the human table) against the kid's effective
  allowlist (`omarchy-kids-apps allowlist <kid>`); Enter on an app toggles it via `omarchy-kids-apps
  hide`/`show`. Its **Plugins shelf** row reads `omarchy-kids-plugins shelf --band <band> --json`
  the same way.
- **Data** (R-DATA-1..5, issue #27): read-only. Prints `omarchy-kids-data summary <kid>` (today) and
  `summary <kid> --week` (last 7 days) — minutes, launches, top apps, and top sites, in that order.
  Minutes and launches are unprivileged reads, same as the rest of this panel; sites need root (a
  kid's Chromium profile lives in a home this panel's own account can't otherwise reach), so this
  screen is the one place in P2 that calls `read_priv` instead of `run_priv` — a real `sudo` read,
  once, the moment it's needed, never previewed by `--dry-run` (there's nothing to preview: a read
  changes nothing). Both summaries are captured into the screen's card body, so the one prompt is
  spent by `warm_sudo_read` in the screen's own shell first: a command substitution runs in a
  subshell that could neither remember the prompt was spent nor keep its own "needs your password"
  line out of the card. If `history_visible=no` for this kid, `omarchy-kids-data` already says so in
  plain words without touching Chromium at all (R-DATA-4), so this screen skips `read_priv` and
  asks for no password it wouldn't use. See docs/data.md for what's recorded, where, and for how
  long.
- **Desktop** (issue #53) is a small menu over two rows: **Desktop level** is the same 1/2/3 choice
  as the wizard's own A11, writing `level` only when it changed from the current value (same "only
  overrides" reasoning as R-BAND-2, applied one screen at a time instead of a whole Apply).
  **Theme** is a picker over `lib/theme.sh`'s `theme_list_installed` (the system themes dir only);
  writing `theme` here goes through `omarchy-kids-conf set <kid> theme <name>`, whose own `cmd_set`
  applies it to the kid's `$HOME` as root and best-effort reloads a live session — see
  `docs/theming.md`. Empty (no themes found under `$OMARCHY_PATH/themes`) shows a message instead
  of an empty picker.
- **Password**: `omarchy-kids-provision` has no `passwd` subcommand yet — only `add`/`remove`/`list`
  (docs/provision.md) — so this screen checks for one (future-proofing) and, finding none, names
  the exact command a parent runs themselves (`sudo passwd <kid>`) rather than claiming a control
  that doesn't exist (I-6).
- **Remove this kid** asks a parent to type the kid's name back, exactly, before running
  `omarchy-kids-provision remove <kid> --apply` (R-FND-6). A mismatch runs nothing at all — not
  even a dry-run print — and says so.

### Requests (P3)

R-ASK-3 calls the queue format "stable and documented for a future home-network approver"; this
panel is the first such approver, so it reads `lib/ask.py`'s own `list-open`/`show` directly
(0x1f-separated, exact fields; `minutes` is empty for non-time kinds) instead of parsing
`omarchy-kids-ask list`'s human-formatted columns,
which pad for a terminal, not a parser. Approve/decline themselves still go through
`omarchy-kids-ask approve|decline <id> --apply` — this panel never writes a queue record itself,
same "one thing writes the format" rule `docs/conf.md` applies to a kid's profile.

**Never arithmetic on an unchecked field (review §2.4).** Bash evaluates the *contents* of a
variable named inside `$(( ))` as an expression, and an array subscript there runs a command
substitution — so the age calculation in `lib/panel-requests.sh`'s `screen_requests` validates
`asked_at` against `^[0-9]+$` before it ever reaches `$(( $(date +%s) - asked_at ))`, even though
`lib/ask.py` already validates it on both sides of the queue. The panel doesn't trust that.

### Notifications (P6)

The parent's side of the device-notification system (R-NOTIFY, `docs/notify.md`): it drives
`omarchy-kids-notify` and never touches the certificate or the device registry itself. Because the
panel runs unprivileged, every call goes through `run_priv`/`read_priv`, and the warmed sudo prompt
is the parent's own authentication (R-NOTIFY-5) — `pair` therefore adds no second password prompt.
`notify_pair_show` captures the command's output rather than letting `run_priv` keep only its first
line, so the pairing code and the relay's SPKI fingerprint both survive onto the next card: a card
that let them scroll away would be a pairing window the parent could not read. That code is a
single-use credential, and `lib/tui.sh` now feeds every card body to `gum style` on **stdin**, not
argv, for exactly this reason — on argv another local session could read it from
`/proc/<pid>/cmdline`.

## Root and the one sudo prompt

Same shape as the wizard's own "Root and the one sudo prompt" (`docs/wizard.md`), but per-screen
instead of per-Apply: this panel runs as the parent and is never itself elevated. Every file it
*reads* — a kid's profile, the time ledger, the ask queue, a band's pack — is root-owned but
world-readable (docs/conf.md, docs/time.md, docs/ask.md), so Home and every P2/P3 screen render
with no privilege at all. The first time a screen would actually write something, `warm_sudo`
prints why on screen and spends one `sudo -v`; every write after that in the same run reuses sudo's
cached credential. `run_priv` is the one place a command is either printed (`--dry-run`, the
default) or run for real under `sudo`; its output (stderr folded in) is captured and reprinted
after it exits, so a long install shows nothing while it runs, and the result is carried to the
next card through `PANEL_NOTICE`. The Web screen's allow-list file is the other writer
(`write_root_file`), and a failure there carries its own notice. `--dry-run` always shows the
exact command a write would run, panel-wide, not just for Apply.

## Not built here

- **P5 Confirm remove**: the panel has no parent-password confirm screen; Home's row hands off to
  `bin/omarchy-kids-remove`, which prints its own plan and asks its own confirmation.
- **Weekend budget/lights-out variants** (`budget_min_weekend`, `lights_out_weekend`): editable
  through `omarchy-kids-conf set` directly today; the Screen Time screen only edits the weekday
  pair, matching the issue brief ("edit budget and lights-out").

## File locations (data settings and resolved paths)

| What | Default path | Seam |
| --- | --- | --- |
| Kid overrides directory, allow-list files | `/etc/omarchy-kids/kids/` | `OMARCHY_KIDS_ETC` (data setting) |
| `bands.toml`, `packs/` | `/usr/share/omarchy-kids/` | `OMARCHY_KIDS_SHARE` (read by the helper commands, not the panel itself) |
| The ask queue | `/var/lib/omarchy-kids/queue/` | `OMARCHY_KIDS_ROOT` (scratch-tree prefix) |
| `lib/ask.py` (read directly for Requests, see above) | `lib/` beside `bin/`, else `/usr/lib/omarchy-kids` | resolved beside the command; no override |
| `lib/panel-reviews.sh` (P7; reads the reviews under `OMARCHY_KIDS_ROOT`, drives `omarchy-kids-review`) | `lib/` beside `bin/`, else `/usr/lib/omarchy-kids` | resolved beside the command; no override |
| `lib/panel-notify.sh` (P6; drives `omarchy-kids-notify`, `docs/notify.md`) | `lib/` beside `bin/`, else `/usr/lib/omarchy-kids` | resolved beside the command; no override |
| Each helper binary (`omarchy-kids-conf`/`-time`/`-ask`/`-apps`/`-web`/`-provision`/`-wizard`/`-data`) | resolved beside this script (`kids_bin`); no fallback, no override | the `OMARCHY_KIDS_*_BIN`/`OMARCHY_KIDS_LIB` escapes were removed, `CHANGELOG.md` |

`test/shell.d/panel-test.sh` drives every screen above through `OMARCHY_KIDS_TUI_ANSWERS`, checking
both the exact `[dry-run] sudo ...` line a write prints and, in a real (`--apply`) run against a
pass-through `sudo` fake and a thin argv-logging "spy" in front of each real helper binary, that the
write actually happened (a budget really changed on disk, an app is really hidden, a request is
really marked approved) — and that a mistyped remove confirmation runs nothing at all.

## Verified live (2026-09-02, QEMU test VM)

Over `ssh -tt` with an answers file: `omarchy-kids` opened the panel (two kids exist), the Home
rows showed live minutes ("Cy · 6-8 · 17m used / 0m left today"), Cy → Screen time → "Give
more minutes today" → 10 printed the exact command in dry-run and, with `--apply`, ran
`sudo omarchy-kids-time grant kid-cy 10` after one warmed prompt; the status line updated to
"9 min left today (budget 1 + 25 granted)". Kid rows answer to their number (or the full
line), not the account name. Requests, Web, Apps, Password and Remove rows share the same
code path and are not yet exercised live.

## The panel runs for real when a human opens it (2026-09-03)

`DRY_RUN=1` used to be the unconditional default here, on the reading that AGENTS.md rule 8
applies to everything. Rule 8 is a rule for *developer machines*; applied to the shipped app
entry it made the product a no-op. A parent opened Kids Mode from the drawer, changed a
setting, pressed the button, watched `[dry-run] sudo ...` scroll past and had no change -- and
there was no argument the drawer could pass to fix it (review §1.5). The panel is interactive:
the screen a parent confirms *is* the confirmation. So the default is now a real run when a
human is driving -- a tty on stdin and stdout, or `OMARCHY_KIDS_LAUNCHED_BY` set, which
`desktop/omarchy-kids.desktop` does via `Exec=env OMARCHY_KIDS_LAUNCHED_BY=desktop
omarchy-kids` -- and `DRY_RUN=1` otherwise, so a test, a script or CI still gets a preview.
`--dry-run` and `--apply` both still win outright. The same rule is in `bin/omarchy-kids-wizard`
and documented in AGENTS.md rule 8 itself; `provision`, `assert`, `web`, `apps` and `remove` are
unchanged and still default to a preview.

## Source header (moved from `bin/omarchy-kids-panel`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead. This snapshot predates
`bin/omarchy-kids-remove` (Home's Remove row now hands off to it), the P4 Machine screen, and the
#58 removal of the `*_BIN`/`OMARCHY_KIDS_LIB` overrides it lists below.

```text
omarchy-kids-panel — everything after the first run (SPEC.md R-WIZ-7,
R-WIZ-8, R-ASK-2, R-TIME-4/5, R-FND-6, Appendix A's P1-P5; issue #21).
`bin/omarchy-kids` opens this once at least one kid exists; the wizard
(bin/omarchy-kids-wizard) stays reachable as `omarchy-kids wizard` and
as this panel's own "Add a kid" row (R-WIZ-7: "add-a-kid runs the
per-kid screens only").

Screens, in Appendix A's own numbering:

  P1 Home       One row per kid (name, band, minutes used/left today,
                paused, open requests), then Add a kid, Requests (N),
                Remove Kids Mode, Quit.
  P2 Kid        Screen time (budget/lights-out, "give more minutes"),
                Web (mode, and the allow-list editor for a walled
                garden), Apps (hide/show the band's pack), Data
                (R-DATA-1..5: today's and this week's minutes,
                launches, and sites — read-only, issue #27), Desktop
                level, Password, Remove this kid, Back.
  P3 Requests   Every open "Ask a parent" request, oldest first; Enter
                opens the reason and Approve/Decline.

P4 (Machine) and P5 (Confirm remove via the parent password) are not
built here: "Remove Kids Mode" (R-TRUST-4) hands off to omarchy-kids-remove
command (nothing in this checkout implements it — see docs/panel.md),
so the Home row for it explains that plainly instead of pretending to
offer it (I-6). Removing one kid at a time (P2's own row, confirmed by
typing that kid's name) is what this issue actually delivers.

Every screen is rendered by lib/tui.sh (issue #18) — this file never
calls gum directly, and OMARCHY_KIDS_TUI_ANSWERS drives it end to end
in tests (see docs/tui.md, docs/panel.md).

Root and the one sudo prompt (mirrors bin/omarchy-kids-wizard's own
"Root and the one sudo prompt", docs/wizard.md): this panel runs as
the parent and is never itself elevated. Reads (omarchy-kids-conf get,
omarchy-kids-time status, omarchy-kids-ask's queue, omarchy-kids-apps
list/allowlist, omarchy-kids-provision list) are all unprivileged --
every file involved is root-owned but world-readable (docs/conf.md,
docs/time.md, docs/ask.md). The first time a screen would actually
write something, `warm_sudo` explains why on screen and spends one
`sudo -v` prompt; every write after that in the same run reuses sudo's
cached credential. `run_priv` is the one place a real system change is
either run for real under sudo or printed, so `--dry-run` always shows
the exact command line. See "what no flag at all means here" below.

  omarchy-kids-panel [--dry-run] [--apply] [--help]

Every path is overridable for tests, same convention as the rest of
bin/ (test/shell.d/panel-test.sh runs entirely against scratch trees,
with a pass-through `sudo` fake and every helper binary below pointed
at a thin spy that logs its own argv and then runs the real thing):
  OMARCHY_KIDS_ETC            default /etc/omarchy-kids
  OMARCHY_KIDS_SHARE          default /usr/share/omarchy-kids
  OMARCHY_KIDS_ROOT           scratch prefix for /var/lib/omarchy-kids
                              (the ask queue), same convention as
                              bin/omarchy-kids-ask and -time
  OMARCHY_KIDS_ASK_BIN        path to omarchy-kids-ask (default: sibling, else PATH)
  OMARCHY_KIDS_TUI_ANSWERS    one answer per line; see lib/tui.sh / docs/tui.md
  DRY_RUN                     default 0 for a human on a tty or the app
                              entry, 1 otherwise; --apply/--dry-run wins

Reading the queue: R-ASK-3 says the queue format is "stable and
documented for a future home-network approver" -- this panel is the
first such approver, so the Requests screen reads
lib/ask.py's own `list-open`/`show` directly (0x1f-separated, exact
fields; `minutes` is empty for non-time kinds) instead of scraping
omarchy-kids-ask's human-formatted `list` output, which pads columns for
a terminal, not a parser.
```

## Source header (moved from `bin/omarchy-kids`, issue #49)

Kept for reference; the file itself now carries a short pointer instead.

```text
omarchy-kids: the app entry point (R-FND-1, R-WIZ-1 through R-WIZ-9).
Launched from the app drawer or Super+Shift+K. With no kid provisioned
yet, opens the parent wizard (bin/omarchy-kids-wizard, issue #19); once
at least one kid exists, `omarchy-kids` alone opens the panel
(bin/omarchy-kids-panel, issue #21) and `omarchy-kids wizard` always
opens the wizard (R-WIZ-7's "add a kid" runs the same per-kid screens).

One more subcommand lives beside the panel: `remove-kids-mode`, a thin,
no-argv-surprises dispatch to bin/omarchy-kids-remove (R-TRUST-4) -- see
docs/remove.md.

--requests (issue #37, the bar widget's "Open requests" menu row, R-ASK-2:
"the panel lists requests") -- omarchy-kids-panel (issue #21) has a real
Requests screen (P3) now, but no CLI flag to open straight to it, and a
bar-widget click wants something faster than launching the full
interactive panel. So this stays a quick, honest summary instead of a
deep link: omarchy-kids-ask list's own output, the same source of truth
the panel's Requests screen reads.
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
