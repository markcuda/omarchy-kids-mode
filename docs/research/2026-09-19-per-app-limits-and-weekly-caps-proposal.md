# Proposal: weekly caps and per-app daily limits ("PlayTime")

**Status: proposal awaiting the owner's decision. This is not part of `SPEC.md`, and nothing here is built.**

- The requirement ids `R-WEEKLY-*` and `R-APPTIME-*` are provisional. They exist only once the owner amends the spec (ticket 0).
- This document is modelled on `docs/specs/02-root-screen-time.md` and extends that state machine. It does not replace it.
- Drafted 2026-09-18 with AI assistance, from a read of the tree at `bfb6f35`. No code was run, no file was edited, and the network was not touched.

## Sources, and one that is missing

**What I read**

- The governing documents: `AGENTS.md` and `SPEC.md` (R-TIME-1..5, R-APPS-*, R-DATA-*, Appendices B, D, F, G).
- The specs and docs: `docs/specs/01`, `02`, `03`, `06`, and `docs/time.md`.
- The data: `share/bands/bands.toml`, `share/config/schema.toml`, `share/packs/9-12.toml`.
- The commands:
  - `bin/omarchy-kids-time-ledger`
  - `bin/omarchy-kids-time`
  - `bin/omarchy-kids-launcher-ctl`
  - `bin/omarchy-kids-data`
  - `bin/omarchy-kids-ask`
- The libraries:
  - `lib/time.sh`
  - `lib/session-manifest.sh`
  - `lib/launcher-map.sh`
  - `lib/data.sh`
  - `lib/panel-kid.sh`
  - `lib/assert-locks.sh`
- The launcher and timer: `share/launcher/shell.qml` and `systemd/omarchy-kids-time.timer`.

**What is missing**

- `docs/research/2026-09-18-kids-mode-landscape.md` (on this branch) is the landscape survey this
  proposal comes from; it covers timekpr-nExT's PlayTime and weekly limits and Cozy Kids
  Launcher's per-app schedules.
- The archived prior-art note `docs/archive/project-hub/research/02-prior-art-kids-linux-and-parental-controls.md:11,111` also covers timekpr-nExT; it calls PlayTime a process-based limiter built on logind.
- That landscape survey is second-hand from the projects' own READMEs, not from their source; this
  proposal makes no claim beyond it.

**The standing decision on timekpr**

- `SPEC.md:23` and `SPEC.md:280` rule out timekpr itself.
- Everything below is a native extension of the existing root tick. Nothing integrates timekpr.

## Constraints this proposal is held to

1. **Root alone decides and enforces.**
   - This is `docs/specs/02`'s model and AGENTS rule 9.
   - Nothing a kid can write selects, extends, or disables a limit.
   - The launcher may decline to open a tile as a courtesy. It is never the fence.
2. **The integer-minute ledgers and the 30-second tick keep working unchanged.**
   - A weekly total is derived from the existing per-day files on every tick.
   - No weekly ledger exists to drift from them.
3. **Nothing is built on an unenforced control.**
   - The `menu` key (`share/config/schema.toml:150-160`, `share/bands/bands.toml:30`) is being cleaned up.
   - No new key, comment, or ordering depends on it.
   - The header comment at `share/bands/bands.toml:8-13` uses `menu` to mark where profile keys end. Whoever removes `menu` rewrites that comment.
4. **Every new setting can be seen and edited in the parent panel (R-WIZ-8).**
5. **Where a kid-owned session makes enforcement partial, the UI says so in plain words (I-6).** Where enforcement is impossible, the control is not offered.

---

# Part 1. Weekly caps and a day-start window

## Goal

Give each kid an optional weekly allowance and an earliest-start time. Both are decided and enforced by the same root tick that already enforces the daily budget and lights-out. A kid cannot spend seven full daily budgets a week if the parent wants fewer, and cannot start at 04:01.

## Today

**The root tick**

- The tick computes one number. `time_remaining_minutes` is `budget + grant - used` for the current logical day (`lib/time.sh:181-190`).
- `tick_kid` turns that into seconds and takes off the carried remainder (`bin/omarchy-kids-time-ledger:292-294`).
- The state decision uses only that number and lights-out (`bin/omarchy-kids-time-ledger:299-326`).
- The reasons written today are `none`, `budget`, and `lights-out` (`:316`, `:320`).

**Lights-out after midnight**

- `time_is_lights_out` (`lib/time.sh:193-199`) compares minutes since midnight and nothing else.
- The logical day runs until 04:00. At 01:00, `now_min` is 60, which is below any evening lights-out, so the function answers `no`.
- A kid with budget left is therefore `allowed` between midnight and 04:00.
- No key sets an earliest start. At 04:00 the new day's full budget is usable.
- An "allowed hours" window closes both holes. The after-midnight behaviour is worth the owner's attention even if this proposal is declined.

**Weekly figures today**

- `omarchy-kids-data summary --week` sums the last seven per-day files for display only (`bin/omarchy-kids-data:206-218`).
- That is a rolling seven days, not a calendar week. Nothing enforces against it.
- This is R-TIME-5 and nothing more.

**Places that publish "minutes left" from the daily figure alone**

- `write_status_json` (`bin/omarchy-kids-time-ledger:135`, read by `share/bar/KidsModule.qml:78`).
- The fallback branch of `omarchy-kids-time status` (`bin/omarchy-kids-time:72-73`).
- `omarchy-kids-data summary` (`bin/omarchy-kids-data:222-225`).
- A weekly cap makes each of these wrong unless they change.

**Panel and wizard**

- The panel's Screen time screen offers two rows, `budget_min` and `lights_out` (`lib/panel-kid.sh:28-29, 45-57`).
- The panel has no weekend rows today. That is an R-WIZ-8 gap already. This work must not widen it.
- The wizard's Advanced table keeps its own key list (`lib/wizard-advanced.sh:9`).

**Timer interval**

- The timer already fires every 30 seconds (`systemd/omarchy-kids-time.timer:6-7`).
- `docs/time.md:39` and `:173-174`, and the ledger's own `--help` (`bin/omarchy-kids-time-ledger:38-42`), still say once a minute.
- That is a label-claims defect. Ticket W4 fixes it while it is in those files.

## Interface

### Settings

Three new profile keys go in `share/config/schema.toml`, group `Screen time`, placed after `lights_out_weekend`.

| Key | Type / validator | Range | `default_source` | `editor` | `reset` | Label |
| --- | --- | --- | --- | --- | --- | --- |
| `weekly_min` | integer / new `minutes-or-zero` | 0..10080, `0` = no weekly cap | band | number | clear | "Minutes a week (0 = no weekly limit)" |
| `day_start` | string / existing `time` | HH:MM | band | time | clear | "Earliest start (weekdays)" |
| `day_start_weekend` | string / existing `time` | HH:MM | band | time | clear | "Earliest start (weekends)" |

**Band defaults**

- Defaults go in `share/bands/bands.toml`.
- The recommended first values keep every existing kid's behaviour the same: `weekly_min = 0` in all four bands, and `day_start = "04:00"` for both variants.
- Real band defaults, for example 06:30 and 7 × the weekday budget, are an owner decision. See Open questions.

**The `minutes-or-zero` validator**

- It is one new allowlisted id in `lib/conf.py:50-66`, with a matching case in `bin/omarchy-kids-conf:116-174`.
- `budget_min` keeps `minutes` and its floor of 1.

**Why not a list of windows**

- The window is `[day_start, lights_out)`. It is deliberately not a list of windows.
- That shape reuses the `time` validator and editor. It needs no new escaping (AGENTS "before you call a ticket done" item 5).
- It stays inside R-TIME-2's weekday/weekend split.

### Derivations, all in `lib/time.sh`

Nothing new is stored.

**`time_week_days DAY`**

- Returns the seven logical-day names of the ISO week containing logical day `DAY`, Monday first.
- It runs through `lib/time.py`, for the same BSD/GNU reason as `logical-day`.
- The week rolls at Monday 04:00 local, because it is a week of logical days.
- Monday is fixed. It keeps R-TIME-2's Saturday and Sunday at the end of the week.

**`time_week_used_minutes KID DAY` and `time_week_granted_minutes KID DAY`**

- Sums of `time_used_minutes` and `time_granted_minutes` over those seven days.
- That is seven small reads per kid per tick.
- A missing file is 0, as today (`lib/time.sh:136-145`).

**`time_week_remaining_seconds KID DAY REMAINDER`**

- Formula: `(weekly_min + week_granted - week_used) * 60 - REMAINDER`, floored at 0.
- When `weekly_min` is 0 it returns "none".
- The remainder is the same `active_seconds_remainder` the daily figure uses. No second carry exists to disagree with it.

**`time_effective_remaining`**

- Returns the smaller of the daily and weekly figures, plus which one binds, as `budget` or `weekly`.
- Every consumer listed under Today switches to this.

**`time_window_state KID WEEKEND NOW`**

- Returns `open`, `early` (logical-day time is before `day_start`), or `lights-out`.
- It is evaluated on the logical clock: minutes since 04:00, not since midnight.
- That makes 00:00–03:59 lights-out.
- A `day_start` later than `lights_out` is rejected by `omarchy-kids-conf set`, which validates the pair before the atomic write.

### Grants

- `omarchy-kids-time grant <kid> <n>` is unchanged. It writes only `usage/<day>.grant` (`bin/omarchy-kids-time:90-102`).
- Weekly remaining includes the week's grants. One "more time" approval therefore lifts both limits by the same `n` minutes.
- No second approval path and no second file exist.
- A grant never opens the window. Pushing lights-out "for tonight only" (R-TIME-4) is still unbuilt (`docs/time.md:178`) and stays separate work.
- R-TIMEAUTH-5 already covers the rest: a grant clears enforcement only when the recomputed policy permits use.

### Root state

**Document**

- Path: `/run/omarchy-kids/time/<kid>.json`, still `0640 root:omarchy-kids` inside a `0750` directory.
- The changes are additive. `time_state_read` (`lib/time.sh:267-290`) does not reject unknown keys, so old readers keep working.

**New fields**

- `weekly`: either `null` or `{ "week_start": "YYYY-MM-DD", "cap_minutes": n, "used_minutes": n, "granted_minutes": n, "remaining_seconds": n }`.
- `window`: `{ "opens": "HH:MM", "closes": "HH:MM", "state": "open|early|lights-out" }`.
- `remaining_seconds`: becomes the effective figure.

**Reasons and states**

- `reason` gains two values: `weekly` and `early`.
- The four states and the 60-second grace are unchanged.
- `time_state_read` gains type checks for the two new objects when present.

**Dependent behaviour**

- The warning thresholds run on the effective remaining through the existing `time_warning_thresholds` (`lib/time.sh:246-264`). A weekly cap therefore warns at 10, 5, and 1 like a budget.
- `/run/omarchy-kids/status.json` keeps `minutes_left`, now effective, and adds `reason`. The bar widget keeps working without a change.

### Display

**Kid side**

- `bin/omarchy-kids-time daemon` and `share/time/timesup.qml` stay display-only (R-TIMEAUTH-6).
- `timesup.qml` shows the same card for every reason today. It gains one line per reason:
  - "That's all your screen time for this week."
  - "Too early. Screen time starts at 07:00."
  - The existing budget and lights-out wording.
- For `early` and `lights-out` the card hides **Ask a grown-up for more time**, because no grant can satisfy it (I-6). The exit modal remains available.

**Parent side, `omarchy-kids-time status`**

- One more line when a cap is set, for example: `this week: 212 of 420 min used, 208 left (week started Mon 2026-09-14)`.
- It also states the window.

**Panel (`lib/panel-kid.sh`)**

- Three new rows on the Screen time screen.
- The two missing weekend rows are added too.
- The weekly row's hint: "Counts Monday to Sunday. Extra time you grant also counts toward the week."

**Wizard**

- The Advanced table gains the same keys.
- Simple mode is unchanged. The summary screen A13 adds the weekly line only when a cap is set.

### Errors

- An invalid `weekly_min`, `day_start`, or `day_start_weekend` blocks login. The check joins `session_manifest_validate_time` (`lib/session-manifest.sh:83-99`). This is `docs/specs/02`'s "invalid profile time values block the kid session."
- Mid-session, an unresolvable value must not leave the kid unenforced. Today a failing `time_conf` inside `tick_kid` aborts that kid's subshell before `time_state_write` (`bin/omarchy-kids-time-ledger:180-187, 292, 372`). The state goes stale and the kid is not enforced.
- The new requirement: an invalid policy value puts the kid in `grace` with reason `policy-invalid`.
- The same gap exists for `budget_min` today. Ticket W2 fixes it for all keys.

## Requirements

- **R-WEEKLY-1**
  - A weekly cap is derived on every tick from the existing per-day usage and grant files for the Monday-to-Sunday week of logical days.
  - No weekly total is stored as a source of truth.
- **R-WEEKLY-2**
  - Root alone computes effective remaining time as the lesser of daily and weekly, with the same sub-minute remainder.
  - Root alone drives warning, grace, lock, and finish from it, with reason `weekly` when the week binds.
- **R-WEEKLY-3**
  - A kid is allowed only inside `[day_start, lights_out)` on the logical clock.
  - Before `day_start` the reason is `early`. From `lights_out` until 04:00 the reason is `lights-out`, including after midnight.
- **R-WEEKLY-4**
  - A root grant raises the daily and weekly allowance by the same minutes through the one existing grant file.
  - It never opens the window.
  - It clears enforcement only when the recomputed policy permits use.
- **R-WEEKLY-5**
  - Every published "minutes left" is the effective figure and carries its reason. That covers the state document, `status.json`, `omarchy-kids-time status`, and `omarchy-kids-data summary`.
  - The "ask for more time" action is absent when the binding reason cannot be granted away.
- **R-WEEKLY-6**
  - The three keys are schema entries with band defaults. They are root-only to set and cross-validated (`day_start` < `lights_out`).
  - They are editable in the panel and the Advanced table, and absent from every kid-writable path.
- **R-WEEKLY-7**
  - With `weekly_min = 0` and `day_start = 04:00`, every tick decision is identical to today's.
  - The one exception is the after-midnight lights-out correction, which is called out in the release note.
- **R-WEEKLY-8**
  - An invalid value blocks login.
  - Mid-session it yields an enforcing state, never `allowed` and never a skipped state write.

## Tests

### `test/shell.d` (stubs, fake clocks, copied build-time constants; no new environment override)

**`time-test.sh` — week arithmetic**

- Table-test `time_week_days` across a Monday 03:59 → 04:01 roll, a year boundary, and a DST change.
- A week with files on four of the seven days.
- A cap reached mid-tick with a remainder carried.
- Daily binding versus weekly binding, and the reason written in each case.
- Warnings fired once on the effective figure.

**`time-test.sh` — grants and windows**

- A grant lifting both limits.
- A grant during `early` leaving the state enforcing.
- The Monday roll clearing `weekly` while a session is live.
- `early` → `allowed` at `day_start` with no login.
- 01:00 with budget left is `lights-out`.

**`time-test.sh` — migration and failure**

- With `weekly_min = 0` and `day_start = 04:00`, a run over the existing fixtures produces documents that differ only by the additive fields (R-WEEKLY-7).
- The `policy-invalid` path writes state and locks. The `loginctl` stub is owned by the test (AGENTS "before you call a ticket done" item 1).

**Other shell test files**

- `conf-test.sh`:
  - Bounds and the zero case.
  - Pair validation both ways.
  - `--default`.
  - Schema completeness for the three keys.
- `session-manifest-test.sh`: an invalid new key fails the build and check. A valid one leaves the manifest unchanged.
- `panel-test.sh` and `wizard-test.sh`: rows present, scripted edits land through `omarchy-kids-conf set`, and the hint text is asserted verbatim.
- `status-publication-test.sh` and `bar-test.sh`: `minutes_left` is effective and `reason` is present.
- `trust-boundary-test.sh`:
  - No new override.
  - The kid-side daemon and `timesup.qml` contain no week arithmetic and no window comparison.

### `test/live`, on the VM only, run by the gate runner (AGENTS rule 11)

**`test/live/41-weekly-cap.sh`**

- Seeds six days of usage for `kid-ada` as root and sets `weekly_min` so that 3 minutes remain.
- Logs in and kills the display adapter.
- Watches for the root lock, then finish after 60 seconds.
- Grants 15 minutes from the parent path and logs in again.
- Captures `41-weekly-warning.png`, `41-weekly-locked.png`, and `41-weekly-granted.png`.

**An additional step in `test/live/40-time-lights-out.sh`**

- A login before `day_start` shows the `early` card with no ask button. Capture: `40-early-card.png`.

**What only the VM can show**

- Real `loginctl` output shapes. `docs/time.md:207-209` lists these as still unverified.
- The card's wording on a real frame.
- The ask modal being absent.
- Behaviour across a real suspend that spans Monday 04:00.

## Migration

- Existing kids need no profile rewrite. With the recommended band defaults their behaviour is unchanged, apart from the after-midnight correction.
- The first tick after upgrade rewrites each runtime document with the additive fields. No usage, grant, grace deadline, or warning history is reset (R-TIMEAUTH-7).
- The session manifest is untouched. The new keys are not added to it. The strict 15-key check at `lib/session-manifest.sh:231-234` and schema version 1 stand.
- `omarchy-kids-assert` needs no new lock. The files it already covers are the only files involved.
- Ledger compatibility is total. No file format changes and no new file is written.

## Out of scope

- Per-day-of-week budgets.
- Multiple windows per day.
- A configurable week start.
- Monthly caps.
- Carry-over of unused time.
- "Lights-out pushed for tonight".
- Any change to the grant file or the queue format.

## Tickets

| # | Ticket | Files | Acceptance | Satisfies |
| --- | --- | --- | --- | --- |
| 0 | Owner amends the spec (owner decision, no draft) | `SPEC.md`: R-TIME-2, Appendix B, Appendix F, the R-BAND table if defaults change | Ids assigned; Open questions 1–3 answered | — |
| W1 | Keys and week arithmetic | `share/config/schema.toml`, `share/bands/bands.toml`, `lib/conf.py`, `bin/omarchy-kids-conf`, `lib/time.py`, `lib/time.sh`, `conf-test.sh`, `time-test.sh` | Pure functions table-tested; no tick change | R-WEEKLY-1, -6 |
| W2 | Tick decides on the effective figure and the window | `bin/omarchy-kids-time-ledger`, `lib/time.sh`, `lib/session-manifest.sh`, `time-test.sh`, `session-manifest-test.sh` | Reasons `weekly`, `early`, `policy-invalid`; parity run passes | R-WEEKLY-2, -3, -4, -7, -8 |
| W3 | Publish and display | `bin/omarchy-kids-time`, `share/time/timesup.qml`, `bin/omarchy-kids-data`, `share/bar/KidsModule.qml`, the matching tests, `trust-boundary-test.sh` | Every figure is effective; ask button absent when ungrantable | R-WEEKLY-5 |
| W4 | Parent editing, docs, live gate | `lib/panel-kid.sh`, `lib/wizard-advanced.sh`, `docs/time.md`, `docs/conf.md`, `docs/panel.md`, `test/live/41-weekly-cap.sh`, `test/live/40-time-lights-out.sh` | Panel and wizard parity (including the two missing weekend rows); stale "once a minute" claims corrected; VM screenshots | R-WEEKLY-5, -6 |

- Each ticket goes through a draft, then an independent review, then the live gate at W4.
- W1 to W3 are shell-test-complete on their own.

---

# Part 2. Per-app daily limits ("PlayTime")

## Goal

Let a parent cap one launcher tile, for example "SuperTuxKart: 60 minutes a day". Root counts the time and root closes the app. The panel states exactly how strong that is for this kid.

## Today

**What is recorded about apps**

- The only per-app record is a launch event.
- `share/launcher/shell.qml:238-239` runs `omarchy-kids-launcher-ctl log <id>`. That command appends to a kid-writable file under `/run/user/<uid>` (`bin/omarchy-kids-launcher-ctl:9, 45-57`).
- Root later folds the file into `launches.log` with `O_NOFOLLOW` and an owner check (`lib/data.sh:86-101`).
- A launch line is kid-authored and has no duration. It cannot be the basis of a limit.

**Where tiles come from**

- Tiles are root-built. `launcher_map_render` resolves each allowlisted id to a fixed absolute argv. It also refuses executables a kid could modify (`lib/launcher-map.sh:37-43, 63-153`).
- The manifest carries `{id, label, icon, installed, argv}` (`lib/session-manifest.sh:199`).

**How the launcher starts an app**

- The launcher runs as the kid. It starts the app detached, straight from that argv (`share/launcher/shell.qml:229-245`).
- No root process is in the launch path.
- Apps do not get their own cgroup or scope. They live in the kid's session scope.
- Root can therefore not ask systemd how long "the SuperTuxKart unit" ran, because no such unit exists.

**Who knows which window has focus**

- Only the kid's compositor knows.
- Its socket lives under `/run/user/<uid>`, which the kid can write.
- Under AGENTS rule 9 root may not trust it for an enforcement decision.

**What root can trust**

- The kernel's own record: for each process, its real uid and `/proc/<pid>/exe`, read as root.

## What can and cannot be enforced — decided before the interface

| Situation | Strength | Why | What the panel says |
| --- | --- | --- | --- |
| Native app, kid has no terminal (Levels 1–2 in bands 3-5 and 6-8) | Enforced | The kid can start processes only from the root-owned map. Home, `/tmp`, and `/dev/shm` are `noexec` (R-FND-2, -2a). `exe` cannot be forged. | "Closes after 60 minutes a day." |
| Native app, kid has a terminal or Level 3 (9-12 playground, 13+ sandboxed, any Level 3) | **Fence** | A shell can run the binary through `ld-linux`, or from a copy in `/run/user/<uid>`, which `SPEC.md:54` already calls a stated fence. Either way `exe` no longer matches. | "A fence: <K> has a terminal and could start this app in a way Kids Mode can't see." |
| App that runs inside a shared runtime (Python, Electron, Java, a shell wrapper) | Not offered in this proposal | `exe` is the runtime, not the app. Telling apps apart means reading `cmdline`, which the process itself can rewrite. | The tile's row reads "Can't be limited on its own (it runs inside <runtime>)", with no control. |
| Web tile | Enforced or fence as above, for the browser **as a whole** | Every site and every kid web app (R-WEB-5) is the same Chromium `exe`. | "Web time includes every site and web app." |
| One site, or one web app | Not possible | Same `exe`. | Not offered. |
| "Only while it's in front" | Not possible | Focus is known only to the kid-owned compositor. | The row says: "Counts whenever the app is open, even behind another window." |
| Reopening after the limit | Closed again within one tick (≤ 30 s) | The tick is the enforcer. Nothing sits in the launch path. | "If <K> reopens it, it closes again within half a minute." |
| `More apps`, `What grown-ups see` | Not offered | These are Kids Mode's own surfaces. | — |

If the owner finds the third row too restrictive, the alternative is a labelled `cmdline` fence. See Open question 5. This proposal does not include it.

## Interface

### Setting

One new key goes in `share/config/schema.toml`, group `Apps`.

| Key | Type / validator | `default_source` | `editor` | `reset` | Label |
| --- | --- | --- | --- | --- | --- |
| `apps.limits` | csv / new `app-limits` | global (empty) | new `app-limits` | clear | "Daily app limits" |

**Format and validation**

- Value format: `id:minutes[,id:minutes…]`, for example `supertuxkart:60,chromium:45`.
- The validator accepts ids matching `^[a-z0-9_-]+$`. That is the same alphabet `session_manifest_allowlist_json` enforces (`lib/session-manifest.sh:112`). Minutes are 1..1440. Duplicate ids are rejected.
- That alphabet holds no comma, colon, quote, or backslash. Quoting and escaping do not arise (AGENTS "before you call a ticket done" item 5). The validator is what guarantees that, not the writer.

**Ids that are not live**

- An id that is not currently in the kid's allowlist is kept but has no effect. The panel shows it greyed: "not on <K>'s desktop".
- An id whose tile is not limitable is rejected at `set`, with the reason from the table above.

### Match data (root-built, never kid-supplied)

**Two new fields per tile**

- `launcher_map_render` adds `limitable` (`"exe"` or `"no"`) and `match_exe` (absolute paths) to each tile in `/etc/omarchy-kids/launchers/<kid>.json`.
- The source is a new optional pack field, `match_exe = ["/usr/bin/supertuxkart"]` in `share/packs/<band>.toml`. It is filled in by an audit (ticket A0) and checked on the VM.
- The built-in Web tile gets a fixed entry in `lib/launcher-map.sh`.
- A listed path is accepted only if `launcher_map_executable_ok` passes (`lib/launcher-map.sh:37-43`) and the file is ELF. Anything else renders as `limitable: "no"`.
- `apps.extra` ids that have no pack row are `limitable: "no"` until audited.

**The manifest does not change**

- It projects only five tile fields (`lib/session-manifest.sh:199`), so it stays byte-identical at schema version 1.

**The map does change**

- `launcher_map_ok` compares the file against a fresh render (`lib/launcher-map.sh:172-184`). After an upgrade every map is stale until `omarchy-kids-assert` runs `launcher_lock_fix` (`lib/assert-locks.sh:118-120`).
- The pacman hook does that in the same transaction (R-TRUST-5).
- Ticket A1 must prove the ordering, because a login in between fails closed.

### Accounting — a new root helper the tick calls

**`lib/apptime.py scan`**

- `bin/omarchy-kids-time-ledger` calls `lib/apptime.py scan <kid-uid> <map>`. It resolves the helper from its own location.
- The helper walks `/proc`.
  - It keeps processes whose real uid is the kid's.
  - It reads `exe` as root.
  - It prints the ids whose `match_exe` contains that path.
- A build-time constant, `PROC_ROOT`, relocates `/proc` for tests. It follows the same pattern as `SYSROOT`. No environment variable is involved.

**Attribution**

- The tick computes one elapsed figure for the kid. That code is unchanged (`bin/omarchy-kids-time-ledger:281-289`).
- The same figure is added to every limited app seen running at this tick. It counts only while the session is active, unlocked, and not paused.
- The error is at most one tick per start or stop. The docs state that.
- App time is also ordinary screen time. The daily and weekly limits still apply on top.

**Ledger**

- Path: `/var/lib/omarchy-kids/<kid>/app-usage/<day>/<id>`. Each file is a bare integer of minutes, written with the existing `time_write_int` and `time_ledger_add` (`lib/time.sh:155-171`).
- Grants go in `<id>.grant`, next to the usage file.
- Ownership: root-owned, `0755` directories and `0644` files, under the kid's existing root-owned data directory.
- A separate directory, rather than new files in `usage/`, means nothing that walks `usage/` has to learn a new shape. Examples are retention and assert's mode pass (`lib/assert-locks.sh:273-301`). I have not audited every reader of `usage/`.
- Sub-minute remainders live only in the runtime document, exactly as today.

**Runtime state**

- An additive `apps` object in `/run/omarchy-kids/time/<kid>.json`:
  `"<id>": { "limit_minutes", "used_minutes", "granted_minutes", "remainder_seconds", "remaining_seconds", "state": "allowed|warning|blocked", "running": bool, "warnings_fired": [..], "enforcement": { "action": "none|term|kill", "result", "at" } }`.
- `time_state_read` validates the object when it is present.

### Enforcement

**The sequence at `remaining_seconds = 0`**

1. The tick sets `state: blocked`.
2. It calls `lib/apptime.py close <kid-uid> <map> <id>`. That sends SIGTERM to every matching process.
3. On the next tick (30 seconds later), survivors get SIGKILL.
4. A blocked app found running again gets SIGTERM straight away.

**The check and the kill cannot be separated**

- The helper opens a pidfd first, re-checks uid and `exe` through it, and signals through the same pidfd.
- A re-read of `/proc/<pid>` followed by `kill <pid>` would be the pid-reuse window that AGENTS "before you call a ticket done" item 4 forbids.
- A failed signal is recorded as `failed` and retried. It never turns `blocked` back into `allowed` (compare R-TIMEAUTH-4).

**Session lock**

- The session is not locked for an app limit. Only the app closes.

**Warnings**

- Warnings at 5 and 1 minutes are published per app in the state document.
- The display adapter shows "5 minutes left in SuperTuxKart".
- The warnings matter because a closed game loses unsaved progress. The panel says so.

### Grants and asking

- `omarchy-kids-time grant <kid> <n> --app <id>` is root-only. It writes only the app's `.grant` file for today.
- The kid side uses a new ask kind, `apptime`, with `what = <id>` and `--minutes N`. The existing `time` kind carries its minutes in `what` (`bin/omarchy-kids-ask:176`), so it cannot be reused.
- This adds one value to Appendix D's `kind` enum. R-ASK-3 calls that format stable, so the owner decides it (Open question 6).
- The panel's approve performs the grant.
- An app grant adds no general screen time.

### Launcher (courtesy only)

**What it shows**

- `share/launcher/shell.qml` reads the fixed root state path with a `FileView`. `timesup.qml` already does the same.
- For a tile that has an `apps.<id>` entry, the launcher shows:
  - "N min left today", or
  - when blocked, the tile inert with "Done for today" and an **Ask a grown-up** action.
- The launcher already treats not-installed tiles as navigable but inert (`shell.qml:233-235, 366, 440`). Blocked tiles take the same shape.

**When the state is missing or malformed**

- The tile shows no badge and launches normally.
- Failing closed here would let a display bug block every app. The fence is the tick, not the launcher.

**What stays out of the launcher**

- It never computes time.
- It never writes anything the tick reads.

### Parent surfaces

**Panel: a new "App limits" screen under the kid**

- One row per tile: `SuperTuxKart — 60 min a day (23 used today)`.
- Each row carries the strength line from the table above. The line is chosen by root-side data (band terminal, level, `limitable`), never typed by hand.
- Enter edits the minutes. `0` or Esc-clear removes the limit.
- Tiles that cannot be limited are listed with the reason and no editor.
- The screen is keyboard-complete (I-5).
- It is a named screen under `docs/specs/06` if that work has landed. Otherwise it is one more positional screen. This work does not depend on `06`.

**Wizard**

- The Advanced table gains an "App limits" cell, using the same editor.
- Simple mode is unchanged.

**`omarchy-kids-time status`**

- Adds one line per limited app.

**`omarchy-kids-data summary`**

- Gains "minutes per app".

### Recorded data

- Minutes per app per day is new recorded data. Without changes, R-DATA-1 and R-DATA-3 would be untrue.
- This work adds it to:
  - `SPEC.md` R-DATA-1. Ninety days is proposed, matching launches.
  - `PRIVACY.md`.
  - The K5 "What my grown-ups can see" screen (`omarchy-kids-data mine`).
  - `omarchy-kids-data retention` (`bin/omarchy-kids-data:318-335`).
- Nothing leaves the machine (I-2).

## Requirements

- **R-APPTIME-1**
  - App limits are one root-only schema key.
  - Its validator fixes the id alphabet and minute range, and rejects tiles that are not limitable.
  - No kid-writable value selects, extends, or disables a limit.
- **R-APPTIME-2**
  - Which processes belong to a tile is decided by root-built match data in the launcher map, compared with `/proc/<pid>/exe` and the real uid as read by root.
  - Launch logs, window titles, `cmdline`, and the compositor are never inputs.
- **R-APPTIME-3**
  - Root accounts app time in the same tick from the same elapsed interval as screen time, only while the session counts.
  - Usage goes into integer-minute per-day files, and remainders only in the runtime document.
- **R-APPTIME-4**
  - At the limit, root terminates the matching processes. It terminates them again within one tick whenever they reappear that day.
  - A failed signal is retried and never yields `allowed`.
  - The pidfd check and the signal are one operation.
- **R-APPTIME-5**
  - A limit is offered only for tiles root can identify by executable.
  - Every offered limit carries a root-derived strength label. The label is "fence" for any kid with a terminal or Level 3.
  - Tiles that cannot be limited say why.
  - Counting-while-open, whole-browser web time, and close-on-reopen are stated in the panel copy.
- **R-APPTIME-6**
  - The launcher and the display adapter only render root state.
  - A missing or malformed state file never blocks a launch.
  - Neither contains limit arithmetic or a signal.
- **R-APPTIME-7**
  - A root app grant raises only that app's allowance for today.
  - The ask path reaches it through the queue with a documented kind.
- **R-APPTIME-8**
  - The limits can be seen and edited in the panel and the Advanced table.
  - The strength label is visible at the point of editing (R-WIZ-8, I-6).
- **R-APPTIME-9**
  - Assert re-asserts the new directory's ownership and modes and the launcher map, without changing usage or grants.
  - Per-app minutes appear in R-DATA-1, `PRIVACY.md`, the kid's transparency screen, and retention.
- **R-APPTIME-10**
  - A kid with no `apps.limits` has an identical tick and identical documents, apart from the absent `apps` object.
  - No `/proc` scan runs for that kid.

## Tests

### `test/shell.d`

**`time-test.sh` — accounting against a fixture `PROC_ROOT` tree (directories with `status` files and `exe` symlinks)**

- A match by `exe` only.
- A process of another uid with the same `exe` is ignored.
- A forged `cmdline` with a non-matching `exe` is ignored.
- Two processes of one app count once.
- No counting while locked, paused, or inactive.
- The remainder carry, and the day roll.
- The warning thresholds.
- `blocked` persists across ticks.
- A grant recomputes the state.
- A kid without limits triggers no scan. The test owns the helper as a stub and asserts it was not called (AGENTS "before you call a ticket done" item 1).

**`time-test.sh` — enforcement**

- The helper's `--plan` mode prints the pids it would signal. That proves selection on every platform.
- A Linux-only case starts real `sleep` processes, points `match_exe` at the real `sleep` path, and proves TERM followed by KILL.
  - It is skipped where `/proc` or pidfd is absent, the same way root tests skip without `unshare`.
  - This has to be said, because the development machine is macOS.
- A test proves pid-reuse safety. The fixture swaps the process between the scan and the close, and nothing is signalled.

**Other shell test files**

- `apps-test.sh` and `session-manifest-test.sh`:
  - The `match_exe` rules: mutable or non-ELF becomes `limitable: no`.
  - The manifest is byte-identical before and after.
  - The map is stale and then fixed by assert.
- `conf-test.sh`: the `app-limits` validator, including quote, backslash, comma, and colon inside an id. Every one is rejected.
- `launcher-grid-test.sh` and `launcher-desktop-test.sh`: the blocked tile is inert, and malformed state still launches.
- `qml-theme-static-test.sh`: no hard-coded colour in the badge.
- `panel-test.sh` and `wizard-test.sh`:
  - A strength label for each band and level combination.
  - A non-limitable row has no editor.
  - Edits go through `omarchy-kids-conf set`.
- `ask-test.sh`: the `apptime` kind, validated at read time from the kid's outbox.
- `data-test.sh`: the summary, `mine`, and retention.
- `assert-test.sh`: modes on `app-usage/`.
- `trust-boundary-test.sh`:
  - `PROC_ROOT` is only a build-time constant.
  - No signal or limit logic exists in QML or kid-side shell.
  - No new override.

### `test/live`, on the VM only

**`test/live/42-app-limit.sh`**

- Gives `kid-ada` a 2-minute limit on a native pack app.
- Opens the app and captures the badge.
- Waits for the warning and then the close.
- Reopens it and proves the app is closed again within one tick.
- Grants through the panel and shows that it runs again.
- Captures:
  - `42-app-badge.png`
  - `42-app-warning.png`
  - `42-app-blocked.png`
  - `42-app-granted.png`
  - `42-panel-app-limits.png`

**What only the VM can show**

- The real `exe` of every pack app, which is ticket A0's audit.
- That Chromium's process tree matches one path.
- That SIGTERM actually closes a full-screen game under Hyprland without wedging the Level 1 session.
- pidfd on the target kernel and Python.
- Timing with the real 30-second timer.

## Migration

- No limits exist today, so no profile needs rewriting.
- The ledger is compatible. Existing `usage/` files are neither read differently nor written differently. `app-usage/` is new and sits beside them.
- The runtime document stays additive.
- Launcher maps re-render once on upgrade, through assert. See Match data above.
- Sessions already logged in at upgrade keep the old launcher until logout. Root enforcement applies from the first tick anyway.
- `Remove Kids Mode` and remove-a-kid already move or delete `/var/lib/omarchy-kids/<kid>/` as a whole. Ticket A4 confirms that `app-usage/` goes with it.

## Out of scope

- A pooled "play" allowance across a category. Packs already carry `category`, so this is a natural follow-up.
- Per-app schedules or windows.
- Weekly per-app caps.
- Focus-based counting.
- Per-site or per-web-app limits.
- A root launch broker that would give each app its own scope. That is the route to a real wall for terminal-holding kids, and it should be specified separately.
- Matching by `cmdline`.
- Anything at Level 3 beyond the labelled fence.

## Tickets

| # | Ticket | Files | Acceptance | Satisfies |
| --- | --- | --- | --- | --- |
| A0 | Audit: what each pack app's process really is (gate runner, VM, no product code) | `docs/apps.md` (results table), `share/packs/*.toml` (`match_exe` only where verified) | Every pack app classed `exe` or `no`, with evidence; Web tile path recorded | R-APPTIME-5 (input) |
| A1 | Key, validator, match data in the map | `share/config/schema.toml`, `lib/conf.py`, `bin/omarchy-kids-conf`, `lib/launcher-map.sh`, `lib/assert-locks.sh`, `conf-test.sh`, `apps-test.sh`, `session-manifest-test.sh`, `assert-test.sh` | Non-limitable ids rejected at `set`; manifest unchanged; upgrade re-render proven | R-APPTIME-1, -2, -9 |
| A2 | Root accounting | `lib/apptime.py`, `lib/time.sh`, `bin/omarchy-kids-time-ledger`, `time-test.sh`, `trust-boundary-test.sh` | Fixture-`/proc` accounting; no scan without limits; ledgers integer-minute | R-APPTIME-2, -3, -10 |
| A3 | Root enforcement and grants | `lib/apptime.py`, `bin/omarchy-kids-time-ledger`, `bin/omarchy-kids-time`, `bin/omarchy-kids-ask`, `lib/ask.py`, `time-test.sh`, `ask-test.sh` | TERM then KILL through pidfd; re-close on reappearance; `--app` grant; `apptime` kind | R-APPTIME-4, -7 |
| A4 | Parent surfaces and recorded-data honesty | `lib/panel-kid.sh`, `lib/wizard-advanced.sh`, `bin/omarchy-kids-data`, `PRIVACY.md`, `docs/panel.md`, `docs/data.md`, `docs/time.md`, the matching tests | Strength labels derived by root; non-limitable rows inert; transparency and retention updated | R-APPTIME-5, -8, -9 |
| A5 | Launcher courtesy and live gate | `share/launcher/shell.qml`, `bin/omarchy-kids-time`, `share/time/toast.qml`, the launcher tests, `test/live/42-app-limit.sh` | Badge and inert tile; malformed state still launches; VM screenshots | R-APPTIME-6 |

- A0 comes first. If it finds that most of a band's pack cannot be limited, the owner should see that before A1 is drafted.
- Part 1 and Part 2 are independent. Part 1 is smaller and needs no new trust argument.
- Both parts edit `tick_kid`, so they should not be drafted at the same time.

---

## Open questions for the owner

1. **Band defaults.**
   - Option one: ship `weekly_min = 0` and `day_start = 04:00` for every band. That is recommended, because it changes nothing for existing kids.
   - Option two: ship real per-band defaults.
2. **The after-midnight lights-out hole (`lib/time.sh:193-199`).**
   - Fix it inside W2.
   - Or fix it now, as its own small ticket, whatever happens to this proposal.
3. **Monday as the fixed start of the week.**
   - Is that acceptable?
   - Or do you want a machine-level setting?
4. **Should a kid see the weekly figure during the week?**
   - For example, a line on the launcher clock.
   - Or only when the cap binds?
   - This proposal shows it only in warnings and on the card.
5. **Apps inside shared runtimes.**
   - Option one: leave them unlimitable. That is the choice this proposal makes.
   - Option two: add a `cmdline` match labelled as a fence for every kid.
6. **Appendix D.**
   - May the `kind` enum gain `apptime`?
   - Or should per-app asks wait?
7. **Retention for per-app minutes.**
   - Ninety days, as proposed?
   - Or one year, like usage?

## Decisions (2026-09-19, owner's standing order: "choose sensical defaults")

The open questions above are answered; these are the defaults to build against if the owner
opens ticket 0:

1. **Band defaults:** `weekly_min = 0` and `day_start = 04:00` for every band — changes nothing
   for existing kids.
2. **After-midnight lights-out hole:** fixed inside W2.
3. **Week start:** Monday, fixed.
4. **Kid visibility:** the weekly figure shows only in warnings and on the card, not on the
   launcher clock.
5. **Shared runtimes:** apps launched inside shared runtimes stay unlimitable; no `cmdline` match.
6. **Appendix D:** the `kind` enum may gain `apptime` when this is built.
7. **Retention:** per-app minutes keep 90 days, matching the other per-app data.
