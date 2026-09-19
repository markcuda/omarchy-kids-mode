# Matching Omarchy's style

What omacom/omarchy actually does, at tag `v4.0.2`, versus what this repo does today. Every
"Observed" line is a primary source: a real file path and line range, fetched directly from
`github.com/omacom/omarchy` at that tag (commit `346e69e1cec6c4e8924531874af6ba010a1bc99e`) unless
marked **UNVERIFIED** (referenced by an Omarchy file but not itself fetched and read). Every "Gap"
line names the file(s) in this repo that don't match yet. See `AGENTS.md`'s "Conventions" section
for the short, imperative version of this file.

## 1. Script header: the summary line

**Observed.** Every short `bin/omarchy-*` command carries a one-line, machine-readable metadata
header directly under the shebang — `# omarchy:summary=`, plus `# omarchy:args=`,
`# omarchy:examples=`, `# omarchy:aliases=` where relevant — and nothing else before the code
starts:

```bash
#!/bin/bash

# omarchy:summary=Log out after closing application windows
# omarchy:examples=omarchy logout | omarchy system logout
# omarchy:aliases=omarchy logout
```

(`bin/omarchy-system-logout`, omacom/omarchy@v4.0.2, lines 1–5.) The same shape appears in
`bin/omarchy-launch-browser` (lines 1–4: `omarchy:summary`, `omarchy:args`), `bin/omarchy-menu`
(lines 1–5), and `bin/omarchy-theme-set` (lines 1–5). This is a documented metadata contract —
upstream's own `AGENTS.md` (line 6) points command authors at
`agents/skills/command-metadata.md` for it, and `AGENTS.md` (lines 26–30) says a command's
`# omarchy:hidden=true` flag is what keeps it out of `bin/omarchy`'s `GROUP_DESCRIPTIONS` listing
— **UNVERIFIED**: the exact parser for `omarchy:summary` wasn't fetched, but the header format
itself is directly observed in four files and is clearly load-bearing, not decorative.

**Checked 2026-09-18.** All 27 commands in `bin/` (the parent command plus the 26
`omarchy-kids-*` commands) carry a `# omarchy:summary=...` line under the shebang, and `AGENTS.md`
now requires it. The ten internal commands (`authd`, `wifid`, `boot-login`, `session-start`,
`session`, `blocked`, `launcher-ctl`, `parent-auth`, `super-tap`, `time-ledger`) also carry
`# omarchy:hidden=true`. `# omarchy:examples=` is still unused.

## 2. Shebang and safety flags

**Observed.** Shebang is always `#!/bin/bash`, never `#!/usr/bin/env bash` — this is an explicit
rule, not just a pattern: "Shebangs must use `#!/bin/bash` consistently (never
`#!/usr/bin/env bash`)" (upstream `AGENTS.md`, line 21). `set -euo pipefail` is **not** universal:
`bin/omarchy-system-logout`, `bin/omarchy-launch-browser`, and `bin/omarchy-refresh-hyprland`
carry no `set` line at all (short scripts that either exec into something else or have no failure
mode worth trapping), while `bin/omarchy-menu` opens with `set -euo pipefail` (line 10, a
script with real branching and a `case` dispatch). Upstream's own `AGENTS.md` (line 22) carves out
an explicit exception: "Scripts under `install/` and `migrations/` may be sourced and
intentionally omit shebangs" entirely.

**Checked 2026-09-18.** All 25 bash commands in `bin/` (`omarchy-kids` plus the 24 bash
`omarchy-kids-*` commands) use `set -euo pipefail`; the only non-bash commands there are the two
Python daemons (`omarchy-kids-authd`, `omarchy-kids-wifid`). The 2026-09-03 audit that found 18
files missing `-e`, and the fix under issue #49, are recorded below.

**Resolved (issue #49): (a).** All 18 files now carry `set -euo pipefail`, and `omarchy-kids`/
`omarchy-kids-exit` need no exception after all — their `exec` calls are each already the last
statement on their path, so `-e` never gets a chance to fire after them. Three files needed a
narrower, in-line exception instead of a blanket one: `bin/omarchy-kids-wizard`'s step-dispatch
loop, all of `bin/omarchy-kids-panel`'s screen tree (from `tui_init` on), and all of
`scripts/omarchy-kids-tui-demo` after its own `tui_init` — each `set +e`/`set -e` around exactly the
region where a screen function's return code (1=Esc, 130=Ctrl+C) is data for the caller's own
`case`, not an error, per a one-line comment at each site. Two more genuine bugs `-e` surfaced in
the process, both now fixed regardless of `-e`: `bin/omarchy-kids-wizard`'s `stop_prefetch` used
`[[ -n "$PREFETCH_PID" ]] && kill ...` as its whole body, which returns non-zero (and, under `-e`,
kills the whole script) whenever there was nothing to kill; `bin/omarchy-kids-session`'s `do_start`
called `run_check "$id"` bare, so a real FAIL exited before the FAIL/ask-grownup handling below it
ever ran.

**Indentation.** Two spaces, `case` patterns indented, operators at line ends: what
`shfmt -i 2 -ci` produces, and what most of Omarchy's own `bin/` uses. `shfmt -i 2 -ci -d bin lib
test scripts` must print nothing.

## 3. Length and comment density

**Observed.** Short single-purpose commands stay short and almost bare: `bin/omarchy-system-logout`
is 13 lines total; `bin/omarchy-launch-browser` is 34; `bin/omarchy-refresh-hyprland` is 14.
Even a longer command like `bin/omarchy-theme-set` (346 lines) explains a non-obvious decision in
4 lines, not a paragraph — e.g. lines 20–29 justify `INSTALLED_THEME_DENIED` ("What a theme
installed from a git repo may not ship, because these run code...") and stop. Shared *libraries*
get more up-front rationale: `install/provisioning/setup-form.sh` opens with a 23-line header
(lines 1–23) explaining the shared 0/1/130 status contract once, for every caller — but each
individual function after that gets 0–2 lines of "why" (e.g. lines 142–143: "Both fields are
skippable with Return, so an empty value is a real answer..."), never a "how this works
mechanically" essay. The pattern: **library-level rationale is written once, up front; per-block
comments explain *why*, not *how*.**

**Gap in this repo.** `bin/omarchy-kids-exit` opens with a 45-line header before its first `set`
line, and keeps adding 3–12-line comment blocks before nearly every function
(`cmd_finish_kid`'s header alone is 12 lines, `wait_for_hyprland_gone`'s is 5) that explain
mechanics ("how", including live-test narration like "seen live 2026-09-02") rather than a single
decision rationale. `bin/omarchy-kids-bar` has a 102-line header — the longest in the repo — for
what upstream would treat as a short dispatcher. `bin/omarchy-kids-check` is 1058 lines total; no
Omarchy command fetched approaches that (the closest, `bin/omarchy` at 1090 lines, is the single
top-level CLI dispatcher for the whole project, not an ordinary feature command).

**Fix.** For `bin/omarchy-kids-exit`, `bin/omarchy-kids-bar`, and any other command whose header
exceeds ~15 lines: keep one short paragraph of "why this shape" at the top (setup-form.sh-length,
not longer), reduce each function's comment to one line of "why" where it isn't obvious, and move
mechanics, "CONFIRMED/UNVERIFIED" audit trails, and live-test narration into the paired
`docs/<command>.md` file this repo already writes for every command (e.g. `docs/exit.md`,
`docs/bar.md` both already exist) — leave a one-line pointer comment in the source instead.
Consider splitting `bin/omarchy-kids-check` (1058 lines) into smaller `lib/check-<area>.sh` pieces
sourced by one thin dispatcher, mirroring how `bin/omarchy` itself stays a dispatcher over many
separate `bin/omarchy-<verb>-*` scripts rather than one large file.

**Resolved (issue #56).** `bin/omarchy-kids-check` is now a 182-line thin dispatcher over ten
`lib/check-<area>.sh` files, exactly the split this section asked for. Comment density in
`bin/`+`lib/` combined fell from 18% (issue #56's starting point, itself down from round one's
26%) to 11.85% (`grep -cE '^[[:space:]]*#'` over `wc -l`, every `bin/omarchy-kids-*` and `lib/*.sh`
file). Every file-level header is at or under setup-form.sh-length now; almost every remaining
function comment is 0–2 lines. The prose that used to live in those headers moved into the paired `docs/<command>.md` file, with
a one-line pointer left in the source — nothing was deleted, including comments that explained a
security or trust-boundary decision. A few small, dense library files
(`lib/kids.sh`, `lib/data.sh`) stay above 12% on their own: each is short (12–219
lines) with almost every remaining comment being a single-line function signature or a
trust-boundary rationale AGENTS.md rule 9 asks to keep local, not narrative bloat left to trim.
`lib/units.sh` (formerly three small arrays in their own file) folded into `lib/kids.sh` under a
"systemd units" heading — 2.2's finding — rather than staying a file of its own.

## 4. Naming

**Observed.** Commands: always hyphenated, always prefixed `omarchy-`, with the prefix carrying
purpose — `cmd-`, `capture-`, `pkg-`, `hw-`, `refresh-`, `restart-`, `launch-`, `install-`,
`setup-`, `toggle-`, `theme-`, `update-` (upstream `AGENTS.md`, "Command Naming", lines 24–45).
Upstream is explicit that this taxonomy lives in exactly one place — `bin/omarchy`'s
`GROUP_DESCRIPTIONS` table (confirmed directly: `bin/omarchy` lines 27–57 declare
`GROUP_DESCRIPTIONS[agent]=...` through dozens of prefixes) — and its own `AGENTS.md` says "Do not
maintain a second exhaustive prefix list here" (line 47). Functions: `lower_snake_case`
(`omarchy_prompt_keyboard`, `install/provisioning/setup-form.sh` line 94; `omarchy_log_line`,
`install/helpers/logging.sh` line 5; `as_root`, `install/helpers/as-root.sh` line 1). Variables:
`UPPER_SNAKE_CASE` for script-level/path constants (`CURRENT_THEME_PATH`, `bin/omarchy-theme-set`
line 12), `lower_snake_case` for locals (`local shim_dir status ufw_docker_bin`,
`install/config/firewall.sh` line 19).

**Gap in this repo.** Mostly matches already, and worth saying so: every command in `bin/` is
`omarchy-kids-*`; functions across `lib/conf.sh` (`conf_get`, `conf_set`, `conf_del`) and
`bin/omarchy-kids-exit` (`cmd_open`, `cmd_finish`, `modal_already_open`,
`wait_for_hyprland_gone`) are `lower_snake_case`; constants like `DIR`, `SHARE`, `CONF_BIN`,
`MODAL_QML` are `UPPER_SNAKE_CASE`. The one real gap: upstream's rule that prefix taxonomy lives
in exactly one authoritative table has no counterpart here. This repo's 26 second-level command
names (`apps`, `ask`, `assert`, `authd`, `bar`, `boot-login`, `check`, `conf`, `data`, `exit`,
`launcher-ctl`, `panel`, `parent-auth`, `plugins`, `provision`, `remove`, `session`,
`session-start`, `super-tap`, `time`, `time-ledger`, `web`, `wifi`, `wifid`, `wizard`)
don't share any purpose-prefix grouping the way upstream's `refresh-`/`toggle-`/`launch-` do, so
there's nothing yet for a future `omarchy-kids <group>` help listing to group by.

**Fix.** Not urgent at 26 commands, but before the surface grows much further: pick a small set of
purpose prefixes (e.g. a shared `time-*` family already exists by accident — `time`,
`time-ledger`) and write them down in one place (a `GROUP_DESCRIPTIONS`-style table in
`bin/omarchy-kids` itself, or a table in `AGENTS.md`), rather than let names accrete ad hoc.

## 5. User-facing output: voice, wording, gum styling

**Observed.** Prompts are terse, concrete, second-person-implied, occasionally personal:
`"Alphanumeric without spaces (like dhh)"`, `"Used for user + root, and disk encryption when
enabled"`, `"Must match the password you just typed"` (`install/provisioning/setup-form.sh`, lines
107, 127, 129). Styling is one consistent accent color across every prompt in that file —
`--prompt.foreground="#845DF9"` — not a different color per screen. Validation errors route
through one shared `notice <message> <seconds>` callback rather than each prompt inventing its own
error-display pattern (setup-form.sh line 20, used at lines 112, 119, 135, 137, 164).

**Gap in this repo.** This is a place this repo already matches upstream well, and does one thing
*better*: `lib/tui.sh` doesn't hardcode `#845DF9` — it resolves `TUI_C_ACCENT`/`TUI_C_FG`/
`TUI_C_MUTED` from `omarchy-theme-color` at `tui_init` (lines 65–70), falling back to
`#845DF9`-equivalent `212` only when no theme is readable yet (lines 49–56, which cite
setup-form.sh's own hex directly as the fallback's justification). No fix needed here; this file
is a model of the convention, not a gap.

## 6. Sudo and root handling

**Observed.** One shared helper, `install/helpers/as-root.sh` (7 lines total):

```sh
as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}
```

Every script needing conditional root sources this instead of reimplementing the `EUID` check.

**Gap in this repo.** No `lib/*.sh` equivalent exists. `bin/omarchy-kids-panel` implements its own
inline `warm_sudo`/wrapper (around lines 151–192, `sudo -v` then `sudo "$@"`), while
`bin/omarchy-kids-check` (lines 687, 957) and `bin/omarchy-kids-time-ledger` (documented at line
43 via `OMARCHY_KIDS_TIME_LEDGER_REQUIRE_ROOT`) each do their own raw `[[ "$EUID" != 0 ]]` check
with slightly different messaging. Three different reimplementations of the same idea.

**Fix.** Add a shared `require_root` / `as_root` to a new `lib/root.sh` (or fold into
`lib/conf.sh`), following `install/helpers/as-root.sh`'s shape, and source it from
`omarchy-kids-check`, `omarchy-kids-time-ledger`, and `omarchy-kids-panel` instead of each
reimplementing the `EUID` check. Note: this repo's `sudo -v`-then-warm-reuse pattern in
`omarchy-kids-panel` is a real, spec-driven addition (one password prompt for a whole run) that
upstream's plain `as_root` doesn't need — keep that behavior, just stop reimplementing the base
`EUID`-or-`sudo` check three times.

**Resolved (issue #58).** `lib/kids.sh`'s `is_root` is that one check, and every root gate in
`bin/` goes through it — `omarchy-kids-time grant`, `omarchy-kids-time-ledger tick`,
`omarchy-kids-exit --finish --kid`, `omarchy-kids-data retention`/`launches`/`sites`, and
`omarchy-kids-ask apply-grant`. The four `*_REQUIRE_ROOT` environment escapes are gone with them:
nothing a kid's session can set decides whether a root check happens (`AGENTS.md` rule 9), and
`test/shell.d/trust-boundary-test.sh` fails on a new hand-rolled one. It lives in `lib/kids.sh`
rather than a new `lib/root.sh` because every command that needs it already sources that file.

## 7. Config file locations: `~/.config/omarchy` and `/etc`

**Observed.** Upstream's user-writable state lives entirely under `~/.config/omarchy/` —
`~/.config/omarchy/shell.json` (full shell layout + settings) and
`~/.config/omarchy/plugins/<id>/` (third-party plugin checkouts) — populated from package
defaults in `config/` and `default/` (upstream `AGENTS.md`, "Config Structure", lines 88–92).
Once `shell.json` is customized it becomes authoritative and is never deep-merged with defaults
again (`shell/README.md`, lines 224–226).

**Gap in this repo — deliberate, not a bug.** This repo inverts that on purpose: locks are
root-owned and live at `/etc/omarchy-kids/kids/<account>.conf`, never under any home directory,
because spec rule I-3 ("locks are root-owned and live outside every home") forbids anything
user-writable from being responsible for enforcement — the opposite of upstream's parent-writable
`~/.config/omarchy/shell.json`. `share/` plays the role upstream's `config/`/`default/` play
(package-shipped defaults), provisioned into `/etc/omarchy-kids/` the way upstream's `config/`
populates `~/.config/`. This repo's own `AGENTS.md` Layout table already documents this mapping.
**No fix** — flagging this explicitly so a future agent doesn't try to "fix" it by moving locks
into a home directory to look more like upstream; that would violate I-3. Where this repo *does*
match well: `lib/conf.sh`'s own header (lines 1–11) documents its merge/preserve semantics
("comments and line order are preserved... `conf_set` only ever touches the one line it is asked
to touch") with the same clarity `shell/README.md` gives its own storage rules — keep that pattern
when new config formats are added.

## 8. Theme colour plumbing

**Observed.** Colors reach Quickshell through `themes/*/colors.toml` → `default/themed/*.tpl`
templates (upstream `AGENTS.md`, lines 90–92) and, at the QML layer, through the `qs.Commons`
`Style`/`Color` singletons or an injected `bar.foreground` — never a literal hex value.
`shell/Ui/BarWidget.qml` (45 lines total) contains zero hex literals; every color reference is
`bar.foreground`-shaped. `shell/plugins/panels/clock/BarWidget.qml` (180 lines) is the same:
`Style.space(10)`, `Style.bar.iconSlot`, `button.foreground` — no hex anywhere. The one deliberate
exception found anywhere in this material is `install/provisioning/setup-form.sh`'s
`--prompt.foreground="#845DF9"` (section 5 above), justified because that prompt runs before login,
before any theme file is readable.

**Resolved (checked 2026-09-18).** `share/bar/KidsModule.qml` now resolves its dots, badges and
selected row through `qs.Commons`' `Color`/`Style` (`Color.muted`, `Color.accent`, `Color.urgent`,
`Style.selectedFillFor`, `bar.foreground`, `bar.fontFamily`) and contains no raw hex or `Qt.rgba`
literals; `test/shell.d/qml-theme-static-test.sh` enforces the hex ban.

## 9. Lua helper style

**Observed.** `default/hypr/helpers.lua` opens with a single-line file header
("Shared helpers for Hyprland Lua configuration.", line 1) and nothing else before code. Private
helpers are `local function`, promoted onto the shared `o.` table one line later
(`o.shell_quote = shell_quote`, line 9). Two-space indent throughout. A "why" comment appears only
where the reasoning genuinely isn't obvious from the code, and stays to 1–2 lines: lines 21–22,
*"Hyprland reaps its own children, so `os.execute()` can't retrieve an exit status from inside the
compositor. Read a marker off stdout instead."*; line 25, *"Subshell, so the redirection covers
every command rather than binding to the last one..."*

**Gap in this repo.** `share/hyprland/L1.lua` opens with an 18-line rationale block (lines 1–18)
before any code, then a second ~30-line "what we require and why" audit (lines 20–47) walking
through each upstream Hyprland Lua module and why it was or wasn't `require`d — good "why"
content in spirit, but 4–7 lines per decision where upstream's helpers.lua uses 1–2. Two-space
indent already matches.

**Fix.** Trim `L1.lua`/`L2.lua`/`L3.lua`'s header and per-`require` rationale to one line each
("why this module, or why not"), and move the multi-paragraph module-by-module audit trail into
`docs/session.md` or a new `docs/hyprland-levels.md`, leaving a pointer comment
("see docs/hyprland-levels.md for why `default.hypr.envs` is not required here") in the source.

## 10. QML style

**Observed.** Two-space indent (`shell/Ui/BarWidget.qml`, `shell/plugins/panels/clock/BarWidget.qml`).
Colors and fonts are never literal — always a `Style.*` singleton or an injected property like
`bar.foreground` / `button.fontFamily` (see section 8; confirmed zero hex literals in either file
read). File headers are a short purpose comment plus a few data-shaped bullet lines, not prose —
`BarWidget.qml` lines 4–11 document the three injected properties (`bar`, `moduleName`,
`settings`) in three one-line bullets, then stop. Component ids and functions are `lowerCamelCase`
(`root`, `button`, `panelLoader`, `broadcast`, `cycleFormat`, `injectPanel`).

**Gap in this repo.** `share/bar/KidsModule.qml` already matches indent (2-space) and casing
(`kidSlug`, `kidInitial`, `activateRow`, `reloadStatus` all `lowerCamelCase`). Two real gaps: (a)
the five hardcoded hex colors from section 8; (b) the file's header comment runs 50 lines
(1–50), including a full "CONFIRMED / UNVERIFIED" sourcing audit — far longer than any upstream
QML header read, including the worked example it's explicitly modeled on
(`shell/plugins/panels/clock/BarWidget.qml`, which carries no such audit trail in-file at all).

**Fix.** Same split as section 3 and 9: move the sourcing/audit trail (which upstream files were
read, what's confirmed vs. not) into `docs/bar.md` (already exists), leaving one pointer line in
the QML header; fix the five hex colors per section 8's fix.

**Resolved (issue #56).** Every `share/**/*.qml` file's header is three lines or fewer now — what
the file is, the SPEC.md rule, and a pointer to its `docs/*.md` (`KidsModule.qml`'s included,
alongside `share/ask/shell.qml`, `share/exit-modal/shell.qml`, `share/launcher/shell.qml`,
`share/plugins/shell.qml`, `share/qml/KidsTheme.qml`, `share/sddm-theme/Main.qml` (the longest,
down from 144 lines), and `share/time/timesup.qml`/`toast.qml`/`share/wifi/shell.qml`). Every
sourcing/CONFIRMED-UNVERIFIED audit trail moved into the matching doc, several of which (e.g.
`docs/levels.md`, `docs/portal.md`, `docs/wifi.md`) had only a "see the file's own header" pointer
before and now carry the actual content. `share/exit-modal/shell.qml`'s header no longer
contradicts the file body the way round two's review found (an `UNTESTED` banner next to code
already verified live 2026-09-02) — the new header states the verified status directly.

## 11. Testing

**Observed.** Three entry points — `./test/all` (aggregate), `./test/cli`, `./test/shell` — with
new shell tests expected under `test/shell.d/*-test.sh`, sharing `test/shell.d/base-test.sh` for
root-path discovery and assertions (upstream `AGENTS.md`, lines 94–102). The graphical acceptance
suite runs in a disposable VM, never in the active dev session (line 104–105,
**UNVERIFIED** in detail: `agents/skills/acceptance-tests.md` itself wasn't fetched). Visual
changes additionally require live-UI verification per `agents/skills/visual-verification.md`
(referenced, **UNVERIFIED** — not fetched).

**Gap in this repo — already matches, no fix needed.** This repo's own `AGENTS.md` Layout table
already documents `test/shell.d/*-test.sh` ("one test file per command, Omarchy's `test/shell.d`
style; `test/all` runs them") and a separate `test/acceptance.d/` for VM-only tests, matching
upstream's dev-session-vs-VM split exactly. Confirmed on disk: `test/shell.d/apps-test.sh`,
`ask-test.sh`, `assert-test.sh`, etc. all exist and open with a comment naming the SPEC.md
requirement ids they cover, the same discipline upstream expects of contributors. The one thing
upstream has that this repo doesn't yet: a shared `base-test.sh` — every `test/shell.d/*-test.sh`
file here re-derives its own root path and assertion helpers rather than sourcing one shared file.
Minor, not urgent: worth adding a `test/shell.d/base-test.sh` once enough duplication accumulates
across the existing test files to justify it.

## Sources

- omacom/omarchy, tag `v4.0.2`, commit `346e69e1cec6c4e8924531874af6ba010a1bc99e` (GitHub API,
  fetched directly): `README.md`, `AGENTS.md`, `bin/omarchy`, `bin/omarchy-system-logout`,
  `bin/omarchy-theme-set`, `bin/omarchy-launch-browser`, `bin/omarchy-menu`,
  `bin/omarchy-refresh-hyprland`, `install/provisioning/setup-form.sh`,
  `install/helpers/logging.sh`, `install/helpers/as-root.sh`, `install/config/all.sh`,
  `install/config/firewall.sh`, `default/hypr/helpers.lua`, `shell/README.md`,
  `shell/Commons/Style.qml`, `shell/Commons/Color.qml`, `shell/Ui/BarWidget.qml`,
  `shell/plugins/panels/clock/BarWidget.qml`, `manual/01-welcome-to-omarchy.md`,
  `manual/14-omarchy-cli.md`, `manual/32-shell-plugins.md`.
- `CLAUDE.md` at that tag was fetched and is a 1-line pointer file; not otherwise used here.
- DHH, "Beautiful motivations" (world.hey.com/dhh/beautiful-motivations-6fef7c73), quoted only via
  `manual/01-welcome-to-omarchy.md`'s own link to it — not fetched separately; treat the manual's
  paraphrase ("productivity has always been downstream from motivation") as the primary citation.
- This repo (markcuda/omarchy-kids-sandbox), branch `style-conventions`: `AGENTS.md`, `README.md`,
  `bin/omarchy-kids`, `bin/omarchy-kids-exit`, `bin/omarchy-kids-check`, `bin/omarchy-kids-bar`,
  `bin/omarchy-kids-panel`, `bin/omarchy-kids-time-ledger`, `lib/conf.sh`, `lib/tui.sh`,
  `share/hyprland/L1.lua`, `share/bar/KidsModule.qml`.
- Not reached / marked **UNVERIFIED** above: `agents/skills/command-metadata.md`,
  `agents/skills/acceptance-tests.md`, `agents/skills/visual-verification.md`,
  `default/agents/skills/omarchy/SKILL.md` (all referenced by upstream's own `AGENTS.md` but not
  themselves fetched); no `CONTRIBUTING.md` exists in the omacom/omarchy tree at this tag (checked
  directly — absent, not overlooked); no explicit "philosophy" page exists in `manual/` at this
  tag (closest is `manual/01-welcome-to-omarchy.md`, used above).
