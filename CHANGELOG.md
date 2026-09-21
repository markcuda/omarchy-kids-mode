# Changelog

Seeded from `git log`'s merge commits, one entry per merged issue branch, in build order.
There has been no tagged release yet, so everything below sits under `[Unreleased]` — see
`docs/packaging.md`'s "AUR readiness" section for the `pkgver` scheme this will start following
once there is one. Regenerate or extend this by hand; it is not produced by a script.

## [Unreleased]

### Security

- Root screen-time enforcement now targets only the account's own graphical session and records a
  lock as successful only when the session reports `LockedHint=yes`: logind's `Class=manager`
  session and an unengaged lock request are no longer recorded as success.
- Launcher activation now uses fixed argv arrays embedded in the validated root-owned session
  manifest; no kid-writable runtime launcher JSON or separate launcher map is read by the launcher.
- Closed kid-session path and binary redirect surfaces: kid-facing commands use build-time paths,
  absolute Quickshell, the account's NSS home, private fenced `/tmp` and `/dev/shm`, and all
  six console gettys; exact supplementary groups and root-only ask review commands are enforced.
- Session manifests snapshot the validated profile and launcher tiles as root-owned JSON, with
  atomic rebuilds that preserve the last valid document on failure.
- Provisioning now builds each session manifest immediately after its launcher map, and assert
  re-asserts every provisioned kid's manifest while preserving a valid document on failure.
- `omarchy-kids-session --manifest` now exposes only the caller's validated, current,
  root-owned 0644 session manifest; missing, linked, mutable, malformed, stale, and mismatched
  documents are refused without stdout.

### Added

- Panel P2 now covers the rest of R-WIZ-8's "every setting": weekday **and weekend** daily
  budgets and lights-out times, a **Wi-Fi** mode row (Ask me first / On their own, safely), and a
  confirmed **Reset to band defaults** that keeps the account, name, face, band, password, theme
  and any sites added by hand.
- Panel P4 Machine (R-TRUST-2): Home gains a **Machine safety** row that runs
  `omarchy-kids-check --json` and shows the verdict, every FAIL and WARN with its own detail, and
  the passed/skipped counts; read-only, with **Check again** to refresh.

### Changed

- Repository identity: the project now lives at `markcuda/omarchy-kids-mode`; the old sandbox
  repository is archived, and the hub's planning history (CORE.md, SPOKES.md, PATH-*.md,
  research/) is kept on the `hub-archive-2026-09-19` branch.
- Wizard honesty pass (I-6): the Advanced checklist no longer offers the unenforced `menu` row,
  the history row asks about the parent's view (R-DATA-4), Done carries the failed step's own
  tail instead of pointing at a screen it just cleared, Done no longer offers a preview button
  that only apologised, the summary draws one card instead of two, the password question follows
  the band's `password_optional` data, and leaving after Apply no longer claims nothing changed.
- Command metadata: the ten internal commands (`authd`, `wifid`, `boot-login`, `session-start`,
  `session`, `blocked`, `launcher-ctl`, `parent-auth`, `super-tap`, `time-ledger`) are marked
  `omarchy:hidden=true`, the wizard header lists `--apply`, the time summary names `grant` and
  `daemon`, and the panel's `--help` no longer cites spec ids at a parent.
- Level 3 is hidden from the wizard's and panel's desktop-level pickers for v1 (existing
  level = 3 profiles still start); R-ASK-2's spec wording now matches the safe list → request
  card with **Approve** preselected. Both decisions are recorded in
  `docs/phase1/DECISIONS-NEEDED.md` §6.
- Kid-facing wording: the Time's Up card reads root's `reason` and says "It's bedtime" when
  lights-out triggered it (budget keeps the old line), counts down as "Closing in Ns", the Level 2
  footer names **Super+Shift+K** as the grown-up exit instead of reusing the Ask modal's name, and
  the exit card says Finish returns to the login screen.
- One font across every surface: the exit modal, Ask, More apps, Time's Up, the toast, the Wi-Fi
  picker's remaining rows and the bar's badges now resolve `font.family` from the theme (the bar
  from `bar.fontFamily`, falling back to `qs.Commons`' `Style`), so no kid surface renders in Qt's
  platform font while the launcher renders JetBrains Mono. `test/shell.d/qml-fonts-test.sh` scans
  every `share/**/*.qml` Text block and fails on the next one that resolves no family.
- Level 1's launcher gains a key-hint footer ("↑ ↓ ← → Choose    Enter Open") that hides when there
  is nothing to open, and an empty manifest now shows "Nothing is set up here yet."
  instead of a blank window.
- Panel Requests now name the kid by their profile name (with the account beside it on the request
  card) instead of the Unix account name.
- Panel writes now carry their result into the next card (`PANEL_NOTICE`): a preview says
  "Preview only — nothing was changed", a success says "Change applied", and a failure shows the
  command's own last line; a rejected password says so instead of returning a blank card, and a
  site-list write that fails is distinguished from a policy apply that fails.
- `omarchy-kids-remove` confirms through the shared card when a human is at a terminal (type
  `yes` in full, Esc/Ctrl+C cancel); a pipe or script keeps the original one-line prompt, and
  `--yes` still skips the question entirely.
- The login portal names the keys at the bottom ("← → Choose · Enter Sign in · Ctrl+Shift+P
  Power off", and "Enter Sign in · Esc Back" while typing) and words a failed password
  ("That password didn't work. Try again.") instead of only shaking the tile (I-5, I-6).
- The login portal names the keys at the bottom ("← → Choose · Enter Sign in · Ctrl+Shift+P Power
  off", and "Enter Sign in · Esc Back" while typing) and words a failed password ("That password
  didn't work. Try again.") instead of only shaking the tile (I-5, I-6).
- The fail-closed "Ask a grown-up" screen now uses the theme resolver's accent and the shared
  rounded border instead of a hardcoded 256-colour and a one-off double border, and its words
  send the child to a grown-up rather than naming a CLI command (I-6).
- Kid session startup now reads one caller-bound validated manifest for level, theme, web, tiles,
  budget, and lights-out values, and executes the selected surface directly without desktop scans
  or runtime launcher JSON.


- The Level 1/2 launcher shows root's remaining time ("N minutes left", `GridNav.remainingLabel`),
  read from `/run/omarchy-kids/time/<kid>.json` and hidden in grace — display only, the launcher
  never computes or enforces the deadline.
- `omarchy-kids-conf export <kid>` prints every effective setting as `key=value` (read-only) for
  saving or diffing a profile; `password`/`onboarded` are omitted as system-managed markers.
- `omarchy-kids-conf export <kid>` prints the kid's own overrides as `key=value`, with inherited
  values shown as `# key=value (inherited)` comments so a round trip never pins them;
  `password`/`onboarded` are omitted. `import <kid> <file>` validates every line first (refusing
  unknown, duplicate, system-managed, and invalid values), then replaces the profile in one atomic
  move, so a bad file changes nothing; the theme side effect and manifest rebuild run once after.
- Configuration schema ticket 1 (#72): one package-owned declaration now covers every profile and
  `apps.*` key while preserving the existing `omarchy-kids-conf` commands and behavior.
- Root screen-time state machine (#68, ticket 1): monotonic active seconds now feed root-owned
  per-kid `allowed`/`warning`/`grace`/`finishing` state without rewriting integer usage history.
- Root screen-time enforcement (#69, ticket 2): the root tick locks at the budget or lights-out
  boundary, finishes through the root-side exit path after 60 seconds, and records action results
  for safe retries.
- Package skeleton: `PKGBUILD`, `omarchy-kids.install`, the pacman hook, desktop entries, command
  stubs (#8)
- `omarchy-kids-conf`, `bands.toml`, and the starter packs (#9)
- `omarchy-kids-provision add/remove/list` with the posture writers (#10)
- `omarchy-kids-session`: the launcher with fail-closed checks, ask-grownup placeholder (#11)
- `omarchy-kids-assert`: re-asserts every lock; the boot-time unit (#12)
- Level 1/2/3 Hyprland configs, band overlays, the Level 1 launcher, `session-start` (#13)
- The login portal: SDDM greeter theme with face tiles (#14)
- `lib/tui.sh`: the screens-as-data `gum` renderer shared by the wizard and panel (#18)
- The parent wizard's Easy path, then reworked screen by screen against SPEC.md Appendix A (#19)
- The wizard's Advanced path: a grouped checklist over every Appendix B cell (#20)
- The parent panel: Home, Kid, and Requests screens; the Remove row hands off to
  `omarchy-kids-remove` (#21)
- Web: per-band Chromium policy, starter allow lists, fail-closed web tile (#22)
- The screen-time engine: root ledger, kid-side daemon, budget/lights-out warnings (#23)
- Apps: starter-pack installs, launcher allowlist, hide-from-mine (#24)
- "Ask a parent": the modal, the queue, `-ask-grownup` collect, panel verbs (#25)
- Wi-Fi for kids: `omarchy-kids-wifi` + `omarchy-kids-wifid` (#26)
- Remove Kids Mode: `omarchy-kids-remove` (#30)
- Early-boot LUKS-unlock hook and per-boot autologin, tested on Arch (#36)
- The parent-password verifier, `omarchy-kids-authd`/`-parent-auth`, tested on Arch (#35)
- The exit modal, parent-unlock PAM lines, the triple-Super-tap gesture (#16)
- Portal polish: display names, parent detection via `theme.conf.user`, avatars via
  `.face.icon` (#39)
- `assert`'s `limine-snapshots` lock, hiding pre-Kids-Mode Snapper boot entries (#38)

### Fixed

- `--apply` never crosses `sudo`; every command's own exit code drives the wizard/panel dashboard
  instead of assuming success
- The exit modal's parent-unlock check reads one line instead of waiting for EOF, which had left
  the verifier hanging
- `omarchy-kids-time`'s timer unit now names its ledger service, and the `units` assert lock
  starts sockets/timers on a live system rather than only enabling them
- `omarchy-provision-user` failing inside `omarchy-kids-provision add` is a warning with a
  migrations fallback, not a failed add (no offline Node tarball in the VM)


- Kid screen-time display now follows the root-published runtime state; the kid path no longer
  calculates budget or lights-out policy, and the Time's Up card no longer has a finish action
  (#70, ticket 3).
- Maintainer-eye review (`docs/reviews/2026-09-03-maintainer-eye.md`): the wizard shows a wrong
  parent password on the redrawn card, one `is_in` in `lib/kids.sh`, `.SRCINFO` and the units'
  `Documentation=` match what ships, the app entry has an icon, four `--help` texts and README's
  "What is here now" say what exists
- Time's Up's "Ask a grown-up" button opens the real R-ASK-1 modal (`omarchy-kids-ask time 15`);
  `omarchy-kids-time ask-grownup`, a placeholder that showed the "this desktop can't start safely"
  screen instead, is gone (2026-09-03 maintainer-eye review)
- `omarchy-kids-ask-grownup` is now `omarchy-kids-blocked`: the "ask a grown-up" screen a kid
  sees when a check refuses to start their session. `omarchy-kids-time ask-grownup` keeps its
  name; it is a different action (#56)
- `omarchy-kids-tui-demo` moved to `scripts/` and is no longer packaged (#56)
- Comments in `bin/` and `lib/` trimmed to one-line whys (18% -> 12% of lines); the mechanics
  and audit trails moved into the matching `docs/<command>.md` (#56)

- One `account_home` resolver in `lib/kids.sh` (was two); the PKGBUILD's depends rationale
  lives in `docs/packaging.md`; Omy's welcome is two sentences; Time's Up shows the owl when a
  kid has no avatar; wizard, README, AGENTS and style.md say only what ships (maintainer-eye
  review, the rest of the applied findings)
- Every bash file is `shfmt -i 2 -ci` (Omarchy's two-space indent); the check is in AGENTS.md
- Panel: no step counter on single screens, facts without the account prefix, an honest footer
  (Esc quits; `q` never did); `omarchy-kids-time status` says "lights-out at 19:30" instead of
  "next boundary: lights-out at 19:30"; the Ask modal's scrim is stronger so the Time's Up card
  fades behind it
- The structural refactor (#49): shared helpers in `lib/kids.sh`, one header shape and one
  dispatcher shape per command, `set -e` everywhere it is safe
- Kids inherit the parent's Omarchy theme at provision and can be given their own with
  `omarchy-kids-conf set <kid> theme <name>`; every kid-side surface reads the kid's theme (#53)
- Light themes: readable contrast in every standalone Quickshell surface (#57)

### Fixed (later)

- `omarchy-kids-conf set`/`reset` rebuild the kid's session manifest: a settings change had
  made the next login fail closed on a stale manifest (seen live)
- `omarchy-kids-conf set <kid> theme` died under `sudo` on an unset `OMARCHY_PATH` after the
  theme library stopped exporting it at source time; the validation defaults it itself now
- The kid session starts Hyprland through `start-hyprland -- --config`, its own watchdog
  launcher; starting `/usr/bin/Hyprland` directly earned a red banner at every kid login
- Portal: Left and Right went dead after a password field had been opened and closed once; the
  key scope takes focus back, so a parent can arrow from a kid's tile to their own
- Live harness: a session assert means a seat session, not the harness's own ssh login
  (scenario 20 had passed while the screen showed the portal)
- Four things that only misbehaved on Linux, found by running the unit suite on the VM:
  `omarchy-kids-check --live` aborted on `pkcheck`'s non-zero "not authorized" (the answer it
  wanted); `omarchy-kids-wifi` died silently when `socat` found no socket instead of saying
  "no reply"; an account with no `colors.toml` got the fallback palette plus one black parent
  tile on the portal; `kids_bin`'s `/usr/bin` fallback made "not installed yet" untestable on
  an installed box (branch `vmtests`)
- The unit suite itself runs green on an Omarchy box with the package installed: one portable
  `stat` and a sealed `PATH` in `test/shell.d/lib.sh`; live scenario 05 is the gate
- Launch folding: the ledger unit's `ProtectHome=` hid `/run/user`, so the kid's runtime launch
  log was never folded into the root ledger (#55)

### Fixed (the first `test/all` on a box with the package installed)

- `omarchy-kids-check --live` aborted mid-report: `pkcheck` exits non-zero for "not authorized",
  the answer it is looking for, and that status reached the command's own `set -e`
- `omarchy-kids-wifi` never printed its "no reply from omarchy-kids-wifid" line on any box with
  `socat` installed — the command just died with exit 1
- An account with no `colors.toml` got the fallback palette plus one derived black tile:
  `omarchy-theme-color --all` succeeds with no theme at all, so `lib/theme.sh` checks the file
- `kids_bin`'s `/usr/bin` fallback was redundant (an installed command's own prefix *is* `/usr`)
  and hid "not installed yet" wherever the package was installed
- `omarchy-kids-bar`'s terminal is Omarchy's `omarchy-launch-floating-terminal-with-presentation`,
  and so is the `kids-data` tile's: the `alacritty -e` fallback and the
  `kitty`/`alacritty`/`foot`/`wezterm`/`xterm` walk both guessed where a convention exists, and a
  stock 4.0.2 box has no `alacritty` (2026-09-03 maintainer-eye review, 1.4)
- `omarchy-kids-ask` resolves `omarchy-kids-time` as a sibling like every other command, not off
  `PATH`; the "isn't installed yet" branch from before that command existed is gone (same review)
- Tests: `test/shell.d/lib.sh`'s `kids_file_mode` (GNU `stat` first) and `kids_base_path` (stubs
  plus a base toolset, nothing else), so a check that needs a command absent means it
  (docs/live-tests.md, run 6)

### Security (round-one review, #51)

- A kid-side process could write `approved` and root applied it; now root verifies every
  approval itself (the parent's password over the authd socket), the verifier is called by
  absolute path, the socket path cannot be overridden, the Limine-editor lock is asserted whether
  or not the boot hook exists, dry-run output no longer prints secrets, and the desktop entry
  runs the real wizard (`docs/reviews/2026-09-03-antagonistic.md`)

### Security (round-two review, #58)

- **One trust boundary, enforced by a test.** No environment variable, and nothing a kid can
  write, selects which code runs or whether a root check happens. `$OMARCHY_KIDS_LIB` (read by all
  21 commands, including the `pam_exec` verifier — a kid could source their own `sock.sh` and
  unlock the screen with any password), every `*_BIN`/`*_PY` override, both socket paths, and the
  four `*_REQUIRE_ROOT` escapes are gone. `test/shell.d/trust-boundary-test.sh` walks `bin/` and
  `lib/` and fails on a new one; `AGENTS.md` rule 9 states the rule.
- A kid-written `asked_at` no longer reaches bash arithmetic in the parent's panel: `lib/ask.py`
  validates it on both sides of the queue, and `lib/panel-requests.sh` refuses a non-integer.
- Root no longer follows a kid-controlled path: `lib/data.py`'s `fold-launches` opens the kid's
  runtime log `O_NOFOLLOW` and checks the open descriptor (regular file, owned by that kid), and
  the root-owned `launches.log` is 0640 root:`omarchy-parents`, not world-readable.
- `lib/posture.sh`'s name guard aborts the write and reports FAIL instead of silently installing
  an empty polkit admin rule (which made every admin action ask for *root*'s password).
- `omarchy-kids-time` tracks its overlays by pidfile, not `pgrep -f`, so a kid cannot wedge
  lights-out shut with a decoy process.
- `omarchy-kids-wifid` applies R-WIFI-2's DNS lockdown *before* activating a connection, validates
  the SSID and password, puts `--` before every client value, and deletes the profile on any
  failure. `omarchy-kids-wifi portal` is removed: a kid could never have run it.
- `omarchy-kids-authd` caps concurrent client threads, so a kid cannot loop connections until the
  verifier dies.
- `README.md`'s "What works today" now says which of those controls are advisory (lights-out for
  bands with a terminal; the exit modal's password), and `test/live/05-unit-tests-on-vm.sh` runs
  `test/all` on the VM so the password-verifier and SO_PEERCRED tests actually execute.

### Fixed (2026-09-03, the parent's LUKS slot)

- A parent's own boot landed on the portal after "Remove Kids Mode" or on a fresh install: the
  parent's LUKS slot is now recorded when the parent is. `omarchy-kids-conf machine set parent`
  writes `luks-slots`' `0=<parent>` line (`lib/kids.sh`'s new `luks_slots_record_parent`) right
  after `machine.conf`'s `parent=`, the moment there's a parent to record — nothing else in this
  repo ever wrote that line, so `docs/boot.md` step 5's "the parent's slot maps to the parent"
  had no `0=` line to read on either of those two paths. `luks_slots_parent_line`,
  `luks_slots_kid_entries`, and `luks_slot_for_account` also move out of duplicated copies in
  `bin/omarchy-kids-provision` and `bin/omarchy-kids-remove` into `lib/kids.sh`, alongside the
  `posture_write_luks_slots` writer (moved from `lib/posture.sh`), so there's one place this file
  is parsed and rewritten instead of three.

### Known gaps

See `docs/phase1/DECISIONS-NEEDED.md` and `docs/phase1/BLOCKED.md` for what still needs a human
decision (Pause/fast-user-switch, the Limine snapshot default) or is blocked on real hardware
(Wi-Fi, captive portals, firmware password). Each command's own doc has a "Verified live" section
naming exactly what has and hasn't run against real Hyprland/Quickshell/SDDM yet.
