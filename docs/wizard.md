# The parent wizard: `bin/omarchy-kids-wizard` (SPEC.md R-WIZ-1..9, Appendix A; issues #19, #20)

Five minutes, no terminal knowledge, sensible defaults: a parent types their kid's name, picks a
face and an age band, then either walks five one-choice screens with the band's default already
picked (**Simple**) or opens one grouped checklist over every setting (**Advanced**, issue #20),
sets a password, sees a plain-words summary of what's about to happen — with a **Change
something** button back into that same checklist, whichever path built the kid — and applies it.
Every screen is rendered by `lib/tui.sh` (issue #18, `docs/tui.md`) — this file never calls `gum`
directly — and `lib/wizard-advanced.sh` (issue #20) holds the Advanced-only screens, split out for
length rather than being a separately reusable library. Both drive entirely through
`OMARCHY_KIDS_TUI_ANSWERS` in tests, same as `lib/tui.sh`'s own demo and test suite.

## Running it

```text
omarchy-kids-wizard [--dry-run] [--help]
```text

`omarchy-kids` (the app entry point) opens this automatically when no kid has been provisioned
yet; `omarchy-kids wizard` always opens it, to add another kid (R-WIZ-7). `DRY_RUN=1` is the
default everywhere Apply would write something (AGENTS.md rule 8): every command Apply would run
is printed instead of run. There's no separate `--apply` confirmation flag on this command —
the summary screen (A13) *is* the confirmation; set `DRY_RUN=0` (or pass `--apply`) for the wizard
you launch to make a real run.

## The screens, in Appendix A order

Steps 1-6 and 12-15 are the same regardless of path; step 7 is either Simple's five one-choice
screens (A7-A11) or Advanced's one grouped checklist (A13a) — A6 picks which, and the driver loop
at the bottom of `bin/omarchy-kids-wizard` jumps straight from step 7 to step 12 either way.

| Step | Appendix A | Screen | What happens |
| --- | --- | --- | --- |
| 1 | A1 | Welcome | Omy's line and three bullets; **Begin** is the only choice. |
| 2 | A2 | Parent password | Right after Welcome. Verified against `omarchy-kids-authd` with the caller-bound `BOOTSTRAP` frame (`docs/authd.md`), kept in memory (never written anywhere), and used to establish and maintain Apply's noninteractive sudo authorization. |
| 3 | A3 | Name | Letters, spaces, and hyphens, 1-24 characters; previews the `kid-<slug>` account name via `omarchy-kids-conf slug`. |
| 4 | A4 | Face | One of the twelve `share/avatars/*.svg` animals (Q18), as a keyboard list — `lib/tui.sh` has no separate grid widget, and a list is exactly as keyboard-complete. |
| 5 | A5 | Age band | 3-5 / 6-8 / 9-12 / 13+, each with its `bands.toml` blurb as the reason line. **Prefetch starts here** (see below) and never blocks; so does `adv_init` (see "The Advanced path" below), seeding every Advanced-only cell to this band's default whether or not Advanced is ever opened. |
| 6 | A6 | Simple or Advanced | **Simple**: walk A7-A11 next. **Advanced** (issue #20): open the grouped checklist (A13a) next instead — see "The Advanced path" below. |
| 12 | A12 | Kid's password | Twice, masked. Band 3-5 gets an extra "set a password or not" choice first (R-BAND's `password_optional`); every other band always sets one. Explains what it unlocks. |
| 13 | A13 | Summary | A plain-words table — account, face, age band, desktop level, web mode, weekday/weekend screen-time and bedtime limits, Wi-Fi, starter apps, password, plus other customized Advanced settings — changed rows marked `(custom)` — then **Apply** or **Change something** (which opens the same grouped checklist, for a kid built either way, then redraws this summary). |
| 14 | A13b/A13c | Apply | A step-by-step progress dashboard (`tui_progress`, R-WIZ-5): the account (plus every cell, from either path, that overrides the band default), the web policy, the starter pack, and the safety check (A13c). |
| 15 | A14 | Done | Omy's line; **Return to my desktop** (R-WIZ-6). No live-preview button — there is no such switch (see below). |

### Step 7, Simple: A7-A11

| Screen | What happens |
| --- | --- |
| A7 Web | Two options, band-appropriate, band default preselected: 3-5 sees no-browser vs. a short allowed list; 6-8/9-12 see the walled garden vs. filtered open web; 13+ sees filtered open web vs. the walled garden. |
| A8 Screen time | The default shows the band's weekday limits and current weekend limits. "I'll set my own" edits weekday minutes and bedtime (each validated); weekend values are edited in Advanced. |
| A9 Apps | "The `<band>` starter pack" (every app), or "Let me pick" — a yes/no per app, one at a time (`apps_pick_walk`; there's no multi-select checklist widget in `lib/tui.sh` yet — Advanced's apps row, below, reuses this same walk). |
| A10 Wi-Fi | "Ask me first" (`parent`) vs. "On their own, safely" (`helper`), band default preselected. |
| A11 Desktop | App grid / Desktop, band default preselected; the same choices appear in the Advanced permissions checklist. Grid stores `level = 1`, Desktop stores `level = 3`. |

### Step 7, Advanced: A13a

See "The Advanced path" below.

Every screen up through the Summary is keyboard-complete: Esc goes back one screen (re-asking
whatever was there — from Advanced's checklist itself, back to A6; from one of its editors, back to
the checklist), Ctrl+C asks to confirm leaving and, if confirmed, exits `130` having run nothing.
Once Apply actually starts running commands, the run is committed — same as the installer's own
dashboard never lets you cancel mid-write. The apps checklist (A9's "Let me pick", also Advanced's
own apps row) is the one place Esc and "No" are genuinely the same outcome per app —
`tui_screen_confirm`'s own contract — since there's no meaningful "go back" mid-checklist; either
way just leaves that one app out and moves to the next.

## The Advanced path (A6 -> A13a; issue #20)

Picking **Advanced** at A6 opens `lib/wizard-advanced.sh`'s `screen_advanced_checklist`: one row
per Appendix B cell that isn't already collected by a screen both paths share — name/avatar/band
(A3-A5) and the kid's password (A12) — twelve rows in six groups, Appendix B order within each
group:

| Group | Rows |
| --- | --- |
| Web | Web access (`web`), Safe-search DNS (`dns`), Allowed sites (`sites`) |
| Screen time | Minutes a day, weekdays and weekends (`budget_min`, `budget_min_weekend`), Lights out, weekdays and weekends (`lights_out`, `lights_out_weekend`) |
| Apps | Starter apps (`allowlist`) |
| Wi-Fi | New Wi-Fi networks (`wifi`) |
| Desktop | Desktop (`level` — Grid or Desktop), Theme (`theme`) |
| Data | History you can see (`history_visible`) |

`theme`'s row (issue #53) is the one whose "default" isn't a band value at all — bands.toml has
no theme field — it's the parent's own current Omarchy theme (`lib/theme.sh`'s
`theme_current_name`, no `THEME_KIDS_HOME` override needed since the wizard always runs as the
parent), the same theme `omarchy-kids-provision add` already copies for the kid at Apply time
(`docs/theming.md`). Its editor is a `tui_screen_choose` over `theme_list_installed` — every name
under the system themes dir — not an enum baked into this file.

Every row shows its band default and its current choice (`adv_row_line`), and is marked
`(changed)` once the current choice no longer matches the default. Enter on a row opens the right
editor: a `tui_screen_choose` picker for an enum (web, dns, wifi, level, menu, history_visible —
dns's "Type my own" opens one more field for the address, `custom:<url>`), the same picker over
`theme_list_installed`'s own names for `theme` (issue #53, not a fixed enum), a validated
`tui_screen_input` for a number (the two budgets, `validate_budget_minutes`), a time
(`lights_out`/`_weekend`, `validate_lights_out`), or a comma-separated host list (`sites`,
`validate_sites_list`), and the same per-app walk A9's "Let me pick" uses for `allowlist`
(`apps_pick_walk`, shared rather than duplicated). Esc from an editor returns to the checklist with
that row untouched — nothing here is committed to a variable until the editor itself returns an
answer, and nothing is written to a kid's profile at all until Apply. A trailing **Done
customizing** row returns to whatever screen opened the checklist: A6's own Advanced choice sends
the wizard straight on to A12 (Simple's A7-A11 are skipped entirely, having been covered by this
one screen); the summary's **Change something** button (below) redraws the summary instead.

`bin/omarchy-kids-wizard`'s `screen_band` seeds every row to the chosen band's default
(`adv_init`) the moment the age band is picked (A5) — before Simple's own A7-A11 screens run. Simple
shows both weekday and weekend time values, while its custom path edits weekday minutes and bedtime
only; weekend values edited through Advanced or "Change something" are preserved. The remaining
Advanced-only cells (dns, sites, menu, theme, history_visible) stay at their band defaults unless
Advanced or "Change something" changes them. Apply's `maybe_override` calls (one per cell,
`apply_step_account`) write an override for every cell whose value no longer equals that default —
as required by R-BAND-2.

## Root and the one sudo prompt

The wizard itself never needs root — reading `bands.toml`/`packs/`/`avatars/` and rendering
screens is all unprivileged. Apply is the one place a real system change happens. After authd
accepts A2's caller-bound `BOOTSTRAP` request, the wizard uses `sudo -S -p '' -v` once to warm
sudo's credential cache (or, in `--dry-run`, just prints `sudo -v`). A background keeper refreshes
that ticket with `sudo -n -v` while the wizard remains open. That same first step then, before
anything else that depends on it, writes `machine.conf`'s `parent=` — `omarchy-kids-conf machine
set parent $INVOKING_USER` (issue #46 follow-up; `$INVOKING_USER` always comes from `id -un`, since
the wizard always runs unprivileged, as the parent) — since nothing else in this repo writes that line, and
without it `omarchy-kids-authd` answers "no" to every password and `omarchy-kids-provision`
refuses to add a kid at all. Only then does it enable the package's own units and start them —
`KIDS_UNITS`/`KIDS_SOCKETS`/`KIDS_TIMERS`, `lib/kids.sh`, the same list `omarchy-kids-assert`'s
`units` lock uses (`docs/assert.md`) — *before* provisioning (issue #46). It enables every unit but
starts all of them except the `omarchy-kids-assert.service` oneshot: Step 5 runs the assert once, and
`enable --now` on that oneshot blocked Apply for seconds with no output (the owner's 15-second hang,
T20). A
fresh install before the first kid, or right after `omarchy-kids-remove` disables them again, needs
the boot-time autologin and a working authd socket back before Step 2 (the account) and the *next*
wizard run both need them. Every subsequent Apply command (`run_priv`/`run_priv_stdin`/
`run_priv_as`, called from one of the five
`apply_step_*` functions) is then a noninteractive `sudo <command>`, which shouldn't prompt
again inside that cached window. If `sudo -n -v` fails before or during Apply, the wizard stops and
returns to Step 2 without prompting from Apply. The keeper stops when the wizard exits. This needs
the parent's account to actually be in
`sudoers`/`wheel` with the usual Arch/Omarchy defaults — verifying that assumption, and that the
single A2 password really does cover the whole Apply sequence with no surprise second prompt,
needs a real terminal (or the test laptop/VM): `test/shell.d/wizard-test.sh` exercises both
`--dry-run` (where `sudo` is never actually invoked) and `DRY_RUN=0` against a fake `sudo` that
really execs its argv, but neither one is a real `sudoers` file.

**A VM run once got past every command below with every dashboard row showing ✓, yet `kid-ben`
was never actually created.** Root cause: `DRY_RUN=0` in the wizard's own environment does not
cross `sudo` into the child process at all (a fresh `sudo` invocation starts a fresh environment
unless the target's `sudoers` config explicitly keeps a variable, which none here do), and every
downstream command — `omarchy-kids-provision`, `omarchy-kids-web install`, `omarchy-kids-apps
install` — defaults to `DRY_RUN=1` and only actually writes anything when it sees its own
`--apply` on argv. So every `run_priv`/`run_priv_stdin` call in this file passes `--apply`
literally, on the command line, to every one of those three commands (see `apply_step_account`,
`apply_step_web`, `apply_step_pkgs`) — never the environment, which is the one thing that reliably
survives a `sudo` boundary. `omarchy-kids-assert` doesn't need this (it defaults to *acting* for
real and only previews with its own `--dry-run`, the one command in `bin/` that inverts the usual
convention — see `docs/assert.md`), and `omarchy-kids-conf set` has no dry-run concept at all,
so neither of those two needed a fix here.

## Prefetch (R-WIZ-4)

Prefetch starts on the age screen after A2 has established the parent sudo ticket. In a real
(non-dry-run) run it first checks `sudo -n true`; when that succeeds it starts the background
`sudo -n pacman -Sw --noconfirm <band's repo packages>` and records its PID. The prefetch command
uses `/dev/null` for stdin and discards stdout and stderr, preventing the observed input overlap
while Gum owns raw mode. When the ticket is unavailable, it prints
a one-line note and skips prefetch; Apply then performs its normal install/download path.
Ctrl+C before Apply stops the recorded prefetch job through `stop_prefetch` on the `EXIT` trap.
Prefetch always downloads the whole band pack, regardless of the later A9 selection; the allowlist
override A9 writes still controls what the kid sees in the launcher.

## Apply's account mode

During a real Apply, the account step reads the active mode with `omarchy-kids-conf machine get
boot`. Portal mode passes only the kid password to `omarchy-kids-provision`; disk mode also passes
the parent password and the disk-only LUKS flags. A missing or invalid mode stops the account step.
The dry-run preview retains its existing disk-shaped command text and does not read the machine boot
mode, so it does not validate the portal invocation.

## Apply's five steps: exit codes, stopping on failure, and the technical log

Each of Apply's five dashboard rows is one function (`apply_step_getok`, `apply_step_account`,
`apply_step_web`, `apply_step_pkgs`, `apply_step_safety`), and `run_apply_step` is the one place
that runs one, decides ✓ or ✗, and does something about it:

- **✓/✗ is the step's own real exit code**, not "we got this far without the script itself
  crashing." `run_apply_step` captures it through `PIPESTATUS[0]`, which stays correct regardless
  of `pipefail`, even though the step's output is piped through `tee` on the way to the screen and
  the log (below) — a step that printed a happy-looking line but exited non-zero still shows ✗.
- **The dashboard stops at the first ✗** (real runs only — every `--dry-run` step "succeeds",
  there being nothing real to fail): the remaining rows print as `·` (never attempted, never
  claimed to be), the failing command's last ten lines print under the dashboard, and Done's
  headline names which step it was ("Setup stopped at ...") instead of claiming the desktop is
  ready.
- **The technical log** (R-WIZ-5's tip line, `$SETUP_LOG`, default `/var/log/omarchy-kids/setup.log`)
  is now actually written on a real run, not just named: `apply_step_getok` also writes
  machine.conf's `parent=`, enables and starts the package's own units (`sudo systemctl enable
  --now`, issue #46, see "Root and the one sudo prompt" above) and creates the log's own directory
  (`sudo install -d`, since a parent's own unprivileged wizard process can't create anything under
  `/var/log` itself), and every step's combined output is piped through `sudo tee -a "$SETUP_LOG"`
  on its way to the screen — a second, separate `sudo` call from the step's own (already-elevated)
  command, which the A2-warmed credential cache covers the same way it covers everything else. A
  `--dry-run` never touches this file at all; the tip line only mentions it after the real dashboard
  finishes.

## The safety check

Apply's last step (`apply_step_safety`) is labeled **Checking setup safeguards**. It runs
`omarchy-kids-assert` to reassert every root-owned lock, then
`sudo -u <account> omarchy-kids-session --check-setup` to check the child's profile, policy
readability, polkit denial, home mount, masked consoles and compositor configuration.
A missing account or any failed check stops setup. The account comes from `id -un` inside
the session command; the wizard checks that it exists before invoking `sudo -u`.

The private `/tmp` and `/dev/shm` mounts are established by PAM at child login, not by
`sudo -u`. The setup report therefore marks those two rows **SKIP — checked at child login**.
It does not read historical child-writable logs or write a session log. Done says setup is
complete and that final safety checks run at sign-in. Every real child login still checks
all session safeguards and refuses to start on any failure (`docs/session.md`).

## Why Done has no "Open `<Name>`'s desktop" button

R-WIZ-6 wants a switch to a live preview of the kid's desktop from the parent's own session. No
such switch exists on this box: `bin/omarchy-kids-exit --finish` ends a *kid's own* session from
inside it (`docs/exit.md`), there is nothing today that starts one as a preview from the parent's
side, and that file notes `Seat.SwitchToGreeter()` outright fails on Omarchy 4.0.2 while a session
is live. A button that only printed an apology would be a control that does nothing (I-6), so
Done offers only **Return to my desktop** and Omy's line says `<Name>` signs in from the login
screen next time the computer starts. Building a real preview switch is separate, later work.

## The answers-file layout

Every screen is driven by `lib/tui.sh`'s `OMARCHY_KIDS_TUI_ANSWERS` (`docs/tui.md`): one answer
per line, `@esc`/`@ctrlc` for the two keys a file can't press.

### Which token a choose screen (A1, A5-A11, A13, A14) accepts

Every one of this wizard's choice screens is `tui_screen_choose` (`docs/tui.md`), and it matches a
line against exactly four things for each option, in this order: the option's **value** (the short
id shown before `|` in this file's own `choices=(...)` arrays — e.g. Done has one option,
`parent|Return to my desktop|`), its **label** verbatim (e.g.
`Return to my desktop`, capital R, no trailing period), the **whole rendered line** verbatim
(`1) Return to my desktop`), or a bare **1-based number** (`1`). Nothing else matches — not a
lowercase or partial label, not the first word of one. Typing `return` for Done's first option
does **not** match anything (it's not the value, not the label, not the numbered line) and fails
the run with `tui: 'return' does not match any choice on 'Done'`; the value `parent` does. This
file's own examples always use each screen's **value**, since those are what's shortest and least
likely to collide with another screen's own value (Wi-Fi's A10 also happens to use `parent` as a
value, for "Ask me first" — a coincidence with Done's `parent`, not a bug: they're different
screens, so there's no ambiguity in an actual answers file, only when reading two screens' values
side by side out of context, as in the examples below).

A full happy-path run, band 6-8, with a password and every A7-A11 choice left at its band default:

```text
begin              # A1 Welcome
parentpw123        # A2 Parent password
Ada                # A3 Name
fox                # A4 Face
6-8                # A5 Age band
simple             # A6 Simple or Advanced
garden             # A7 Web (6-8's default)
default            # A8 Screen time ("the usual" — not "I'll set my own")
pack               # A9 Apps (the whole starter pack, not "let me pick")
parent             # A10 Wi-Fi (6-8's default)
1                  # A11 Desktop (App grid, 6-8's default)
secret1            # A12 Kid password
secret1            # A12 Kid password, again
apply              # A13 Summary: Apply (not "Change something")
parent             # A14 Done: "Return to my desktop"
```text

Band 3-5 inserts one extra line right after A11 (`yes`/`no`, for A12's "set a password?"):

```text
begin
parentpw123
Zoe
fox
3-5
simple
none
default
pack
parent
1
no                 # no password for this band
apply
parent
```text

Picking "I'll set my own" at A8 inserts two more lines (minutes, then lights-out); picking
"Let me pick" at A9 (or opening Advanced's own apps row) inserts one `yes`/`no` line per app in the
band's starter pack, in pack order. `test/shell.d/wizard-test.sh` builds every one of these
programmatically under `--dry-run` and checks the exact `[dry-run] sudo ...` lines Apply prints —
provision's flags (`--apply` and the face included), the `omarchy-kids-conf set` override lines for
any cell, from either path, that differs from the band default (and their absence when every cell
matches the default — R-BAND-2), the web install call (also with `--apply`), and the
`omarchy-kids-apps install <band> --now --apply` call (always the whole band pack, regardless of
A9's or Advanced's pick — see "Apply's five steps" above) — plus name validation, the A8/A9
branches, Esc-back, and that Ctrl+C right after Welcome prints no command at all. A separate block
of scenarios runs with `DRY_RUN=0` against a fake `sudo` that actually execs its argv, to check the
things `--dry-run` can't: a failing step showing ✗ and stopping the dashboard before any later step
runs, the failing command's tail on screen, the technical log actually gaining that same content,
and the safety check's account-existence guard.

### Driving the grouped checklist (A13a): row, then answer, then "done"

`screen_advanced_checklist` (`lib/wizard-advanced.sh`) is itself a loop over the same
`tui_screen_choose` contract as everything else here: each pass through it consumes **one line for
the row** — a checklist row's own value is just its Appendix B key (`web`, `dns`, `sites`,
`budget_min`, `budget_min_weekend`, `lights_out`, `lights_out_weekend`, `allowlist`, `wifi`,
`level`, `menu`, `history_visible`), never the group name or the rendered `[Group] Label` text —
then, unless the row was **`done`** (the trailing "Done customizing" row, which ends the loop),
whatever lines that row's own editor needs: one line for an enum row (`web`, `dns`, `wifi`,
`level`, `menu`, `history_visible` — `dns`'s `custom` answer needs one more line, the address, after
it), one validated line for a number or a time row (the two budgets, the two lights-out fields,
`sites`), or one `yes`/`no` line per app in the band's pack for `allowlist` (the same
`apps_pick_walk` A9's "Let me pick" uses). Answering `@esc` in place of a row's editor answer
returns to the checklist with that row untouched, consuming no further lines for it (the checklist
then reads its own next line as another row choice, same as any other pass through the loop).

Reached from A6 (Advanced), the checklist replaces steps 7-11 outright, so its answers sit right
where A7's would in the happy-path example above — band 6-8, changing `web` and `budget_min`
before finishing:

```text
begin
parentpw123
Ada
fox
6-8
advanced           # A6: Advanced, not Simple
web                # checklist: open the "Web access" row
filtered           # web's editor: pick "filtered"
budget_min         # checklist: open the "Minutes a day (weekdays)" row
75                 # budget_min's editor: type 75
done               # checklist: "Done customizing" — on to A12
secret1
secret1
apply
parent
```

Reached from A13's **Change something** (either path), the same row/answer/`done` sequence is
inserted right before the summary's own `apply`/`change` line, and afterward the summary is simply
asked again — so a `change` line is followed by one full pass through the checklist (row/answer
pairs, then `done`) and then another `apply`-or-`change` line for the redrawn summary:

```text
...
secret1
secret1
change             # A13 Summary: "Change something", not "Apply"
level              # checklist: open the "Desktop" row
2                  # level's editor: pick "Desktop" (stored level = 3)
done               # checklist: "Done customizing" — back to the summary
apply              # A13 Summary again, now showing "Desktop (custom)"
parent
```

## Every path is overridable, same convention as the rest of `bin/`

| Env var | Default | What |
| --- | --- | --- |
| `OMARCHY_KIDS_ETC` | `/etc/omarchy-kids` | kid profiles (only read, to preview slug collisions) |
| `OMARCHY_KIDS_SHARE` | `/usr/share/omarchy-kids` | `bands.toml`, `packs/<band>.toml`, `avatars/*.svg` |
| `OMARCHY_KIDS_SETUP_LOG` | `/var/log/omarchy-kids/setup.log` | Apply's technical log (see "Apply's five steps" above) — a real run writes it; `--dry-run` never does |
| `OMARCHY_KIDS_TUI_ANSWERS` | (unset — real terminal) | see `docs/tui.md` |
| `DRY_RUN` | `1` | `0` (or `--apply`) makes Apply real |

## Parent-password verification (A2, issue #46)

A2 sends the candidate through `omarchy-kids-parent-auth --bootstrap`, which sends the
`BOOTSTRAP` frame to authd. Authd binds the check to the kernel peer uid, requires that account to
be an eligible non-root `wheel` parent, and checks that account's own shadow entry. An unavailable
verifier or a failed check stops at Step 2. There is no sudo fallback, and passwordless sudo cannot
make a wrong candidate pass.

An incorrect candidate gets a plain "That wasn't it." and another try;
after three wrong tries in a row, `screen_parent_password` gives up and leaves with the same
`rc 130` ("nothing changed") the driver's own Ctrl+C handling uses — not a crash, and not a longer
lockout (that belongs to `omarchy-kids-authd`'s own rate limiter, `docs/authd.md`). The counting itself lives in
`screen_parent_password`'s own loop, not in a `lib/tui.sh` `VALIDATOR` — a validator runs inside
`tui_screen_input`'s command substitution, a subshell, so a counter kept there would never survive
between tries.

`--dry-run` skips real verification entirely and always accepts on the first try, as intended — a
dry run shouldn't need a real `omarchy-kids-authd` or a real `sudo` prompt on the box it's run from.
`omarchy-kids-provision add --parent-password-stdin` (at Apply) remains the backstop check whenever
a LUKS slot is actually in play (`docs/provision.md`).

## Verified live (2026-09-02, QEMU test VM)

Driven by an answers file over `ssh -tt` (sudo's ticket is per-tty): all fifteen screens
rendered, Apply provisioned Ben (account, LUKS slot 3, band 6-8, avatar owl, the portal
override file updated), and a cold boot with Ben's disk password went straight to Ben's
Level 1 launcher. Two things the first run taught: `DRY_RUN=0` does not cross `sudo`, so every
repo command gets its own `--apply` flag now, and the step marks follow real exit codes. The
last provisioning step, Omarchy's own `omarchy-provision-user`, fails on this VM (no offline
Node tarball) and is a warning with the migrations fallback since then.
Advanced path, 2026-09-03 (dry-run over `ssh -tt`): A6 Advanced opened the grouped checklist with
every band default, "Minutes a day (weekdays)" 90 → 45 and "Lights out (weekdays)" 20:30 →
21:00 were marked `(changed)`, Done customizing went straight to the password screen, and Apply
printed provision followed by exactly two `omarchy-kids-conf set` lines for the changed cells,
then the web and apps installs.

## Apply is real when a parent walks the wizard (2026-09-03)

Same change as the panel, same reason (review §1.5): a parent who reached A13, read the summary
and pressed Apply used to watch every command print with a `[dry-run]` prefix and end up with no
kid account. Walked by a human -- a tty, or the Kids Mode app entry, which sets
`OMARCHY_KIDS_LAUNCHED_BY` -- Apply now runs for real; with no terminal and no app entry (a
test, a script, CI) the default is still the preview AGENTS.md rule 8 asks for. `--dry-run`
forces the preview and `--apply` forces the real run, from either starting point.
`test/shell.d/wizard-test.sh`'s answers-file harness passes `--dry-run` explicitly wherever it
wants the preview, and has its own section proving that a run reaching Apply from the app entry
really executes `omarchy-kids-provision`. The wizard's `authd` socket client is now
`lib/sock.sh`'s single `kids_sock_request`, shared with `omarchy-kids-parent-auth` and
`omarchy-kids-wifi`, which had drifted into three copies with different fallbacks and timeouts.

## Source header (moved from `bin/omarchy-kids-wizard`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-wizard — the parent wizard's Easy path (SPEC.md R-WIZ-1..9,
Appendix A; issue #19). Bash + gum in Omarchy's floating terminal, every
screen rendered by lib/tui.sh (issue #18) — this file never calls gum
directly. See docs/wizard.md for the full screen list and the
answers-file layout tests drive it with.

This follows Appendix A screen by screen: Welcome (A1), parent password
(A2), name (A3), face (A4), age band (A5), Simple or Advanced (A6), the
five Simple one-choice screens (A7-A11: web, time, apps, Wi-Fi, level —
each with the band's default preselected and a one-line reason per
option) or Advanced's grouped checklist (A13a, issue #20 — every
Appendix B cell those five screens don't already cover, one screen,
lib/wizard-advanced.sh), the kid's password (A12), the summary (A13,
whose "Change something" opens that same checklist for either path),
Apply (A13b) with the safety check (A13c), and Done (A14).

Every screen is keyboard-complete (Esc back, Ctrl+C leave with nothing
changed — see lib/tui.sh) up to the moment Apply actually starts
running commands; once a system change has begun, stopping partway
would leave things half-done, so the run is committed at that point,
same as the installer's own dashboard (R-WIZ-5).

  omarchy-kids-wizard [--dry-run] [--help]

Walked by a human, Apply is real: the summary screen (A13) is itself the
confirmation (review §1.5). Run with no terminal — a test, a script, CI —
every command Apply would run is printed instead, `pacman`/`sudo`/
`omarchy-kids-*` included, and nothing runs. `--dry-run` forces the
preview, `--apply` forces the real run.

Every path is overridable for tests, same convention as the rest of
bin/ (test/shell.d/wizard-test.sh runs entirely against scratch trees
with a stub PATH for gum/pacman/sudo and stub omarchy-kids-provision/
-web/-assert/-session pointed at by their own env vars below):
  OMARCHY_KIDS_ETC             default /etc/omarchy-kids
  OMARCHY_KIDS_SHARE            default /usr/share/omarchy-kids
                                 KIDS_TIMERS list Apply shares with
                                 omarchy-kids-assert, issue #46)
  OMARCHY_KIDS_SETUP_LOG         the technical log Apply writes to (R-WIZ-5;
                                 default /var/log/omarchy-kids/setup.log). A
                                 real run creates it (`sudo install -d` then
                                 `sudo tee -a`, since a parent's own process
                                 can't append to a root-owned file); a
                                 --dry-run never writes it.
  OMARCHY_KIDS_TUI_ANSWERS       one answer per line; see lib/tui.sh / docs/tui.md
  DRY_RUN                        default 0 for a human on a tty or the
                                 app entry, 1 otherwise; --apply/--dry-run wins
```

## Advanced path source header (moved from `lib/wizard-advanced.sh`, issue #49)

```text
lib/wizard-advanced.sh — the wizard's Advanced path: a grouped checklist
over every Appendix B cell that isn't already collected by a shared
screen (SPEC.md R-WIZ-2, R-WIZ-3, R-BAND-2, Appendix B; issue #20).
Reachable from A6 ("Advanced") and from the Easy summary's "Change
something" (A13, for both paths — bin/omarchy-kids-wizard's
screen_summary calls the same screen_advanced_checklist this file
defines). Split out of bin/omarchy-kids-wizard for length, same reason
lib/tui.sh is its own file — not a generally reusable library, just
this command's Advanced-path code kept out of the main driver.

Sourced by bin/omarchy-kids-wizard, which by the time any function here
is actually called has already defined every global variable and
helper this file reads: $BAND, $DISPLAY_NAME, $SHARE, $PY, $PYHELPER,
band_field, pack_field, app_label_for, apps_pick_walk,
friendly_web_mode, friendly_wifi_mode, validate_budget_minutes,
validate_lights_out, and every lib/tui.sh tui_screen_* function. Not
meant to be executed or sourced on its own.

One row per key, twelve keys in six groups (Web, Screen time, Apps,
Wi-Fi, Desktop, Data), Appendix B order within each group. name/avatar/
band (A3-A5) and password (A12) are collected by their own screens
before either path reaches here, so they're not rows; onboarded is a
system-managed flag no screen ever offers a parent, so it isn't either.

Every row's value lives in the SAME plain variable Simple's own A7/A8/
A9/A10/A11 screens use (WEB_MODE, BUDGET_MIN, ALLOWLIST_IDS, ...) — one
source of truth regardless of which path set it — plus five variables
Simple never touches (DNS_MODE, SITES, HISTORY_VISIBLE,
BUDGET_MIN_WEEKEND, LIGHTS_OUT_WEEKEND). adv_varname maps a key to its
variable's name; adv_get/adv_set read and write it by that name (the
same indirect-by-name idiom lib/tui.sh's _tui_array_copy uses, for the
same reason: no namerefs, no associative arrays — bash 3.2 has neither,
and test/all has to run on the plain bash macOS ships). adv_init seeds
every one of them to this band's default; nothing here ever calls
omarchy-kids-conf itself — only Apply (apply_step_account's
maybe_override calls) ever writes anything.
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
