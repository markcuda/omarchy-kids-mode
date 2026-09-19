# Loop report, night of 2026-09-02

Written for Mark at the end of the autonomous loop. Everything below happened on the test
laptop's QEMU VM (`docs/vm.md`), never on the laptop's own account, and nothing left the two
machines except pushes to this repo and issue comments.

## What was built

Every ticket in Milestones 1 to 5 has code on `main`, merged from one agent branch each after
the unit suite (`bash test/all`, 28 files) passed: provisioning and the assert locks, the boot
hook and per-boot autologin, the verifier daemon and the parent-unlock PAM lines, the Level 1/2/3
configs and the Level 1 launcher, the SDDM portal theme, the Super x3 exit modal, the screen-time
engine, Ask a parent, Wi-Fi for kids, the wizard (Easy and Advanced), the panel, the bar widget,
recorded data, the plugins shelf, `omarchy-kids-check` v2, Remove Kids Mode, the live harness,
and the shipping docs (`docs/install.md`, `PRIVACY.md`, `docs/parent-card.md`, `.SRCINFO`,
`CHANGELOG.md`).

## What is verified live

Each command's doc has a "Verified live" section with the exact evidence. In one line each:

- Cold boot with a kid's disk password lands on that kid's Level 1 launcher; the owner's password
  lands on the owner's desktop; an unknown slot lands on the portal.
- The portal shows every account with names, face icons and a smaller parent tile; keyboard-only
  login works; the parent's password on a kid's tile opens the kid's session.
- Super x3 opens the exit modal; parent password + Finish ends the session cleanly and a fresh
  portal appears. The same works from root for the bar and panel.
- Screen time: the ledger ticks real minutes, toasts fire, Time's Up appears by budget and by
  lights-out, and auto-Finish returns the portal. Ask a grown-up grants minutes on the spot.
- The wizard provisions a kid through all fifteen Appendix A screens (answers file over
  `ssh -tt`); a cold boot as that kid works. The Advanced path writes exactly the changed cells.
- The panel shows live minutes per kid and grants time through one sudo prompt.
- The Chromium walled garden blocks non-allowed sites for a 6-8 kid; the Web tile launches
  Chromium without Omarchy's extension flags or the keyring prompt.
- The Wi-Fi helper refuses parent-managed kids and answers helper-mode kids over its socket.
- Kid sessions have private `noexec` `/tmp` and `/dev/shm` on both login stacks.
- `test/live/all` runs seven scenarios end to end against the VM and all pass.

## Round two (after Mark's note)

Mark asked for DHH-grade code, Omarchy's own conventions and per-theme styling, and UX work
from screenshots. Done since:

- `docs/style.md` and a Conventions section in `AGENTS.md`, derived from omacom/omarchy v4.0.2.
- An antagonistic review (`docs/reviews/2026-09-03-antagonistic.md`) and its security fixes
  (#51): approvals are root's decision, verifier paths are absolute and ignore the kid's
  environment, the Limine editor lock no longer hides behind the boot hook, secrets never reach
  a preview, the interactive commands run for real, boot-login uses the profile registry. A
  live attack pass confirmed the forged-approval and socket-redirect paths are closed; the real
  on-the-spot grant needed two more fixes found live (a minutes field and the verifier's line
  reader) plus writable state paths in the service unit.
- Theme plumbing (#47): the portal and the wizard follow the owner's theme, verified under
  tokyo-night and catppuccin-latte; kid surfaces use the kid's own theme (#53 inherits the
  parent's at provision time).
- Starter packs audited against the official repos (#52) and installed for real; GCompris
  launched from the launcher.
- Launcher with real app icons and a centred grid (#54); the wizard as one rounded card per
  step in the theme's colours (#50); uninstalled tiles hidden (#42); grid navigation fixed (#43).
- The live harness ran all seven scenarios green in one run after these merges.
- The structural refactor (#49) merged and passed the full live harness; the second
  antagonistic review (`docs/reviews/2026-09-03-antagonistic-round-two.md`) found that it had
  re-created the same class of hole it closed (an environment variable selecting which library
  loads, even for the PAM-wired verifier), plus an arithmetic injection and a root read that
  follows a kid's symlink. Its verdict: not mergeable upstream until one trust boundary is
  stated and enforced by a test, the authorization tests run on Linux instead of skipping, and
  no unenforced control ships. All of that landed as #58: one trust boundary stated in
  `AGENTS.md`, every environment override gone (including the one the PAM verifier read), a
  static test that walks `bin/` and `lib/` and fails on a new one, root reads with
  `O_NOFOLLOW`, and the Wi-Fi portal window removed rather than shipped unenforced.
- Light themes fixed in every standalone Quickshell surface (#57); the style follow-ups (#56)
  cut comments in `bin/` and `lib/` from 18% to 12% of lines, renamed `ask-grownup` to
  `omarchy-kids-blocked`, and moved the TUI demo out of the package.
- The live harness gained scenario 05, which copies the checkout to the VM and runs the unit
  suite there. Run 5: the seven behaviour scenarios green, and scenario 05 found the real gap of
  the night: 61 checks in 16 test files fail on Arch. The suite had only ever run on the Mac and
  assumed a host with no Omarchy tools on PATH, no package installed, and BSD `stat`. Nothing in
  the product broke; the tests did. Fixing that on branch `vmtests`, with a new rule in
  `AGENTS.md`: the suite must be green on an Omarchy box with the package installed, and
  scenario 05 is the gate.
- A third review is reading the repo with a maintainer's eye (taste and conventions, not
  security); its notes will be `docs/reviews/2026-09-03-maintainer-eye.md`.

## Round three (the morning after)

- The unit suite now runs on the VM as live scenario 05, and it is the gate: 61 checks in 16
  files had only ever passed on the Mac (BSD `stat`, tools assumed absent from `PATH`, the
  package assumed uninstalled). `test/shell.d/lib.sh` gives every test one portable `stat` and
  a sealed `PATH`. The same run found four real Linux-only bugs: `check --live` aborted on
  `pkcheck`'s non-zero "not authorized", `omarchy-kids-wifi` died silently when `socat` found
  no socket, an account without `colors.toml` got a black parent tile on the portal, and
  `kids_bin`'s `/usr/bin` fallback made "not installed yet" untestable on an installed box.
- A maintainer-eye review (`docs/reviews/2026-09-03-maintainer-eye.md`, taste and conventions
  rather than security) found 33 things; about 30 are applied. The visible ones: every panel
  screen now shows its facts inside the card instead of echoing them above a menu that cleared
  the screen (verified by screenshot under tokyo-night and catppuccin-latte); Time's Up's
  "Ask a grown-up" opens the real ask modal; a wrong parent password shows on the redrawn card;
  Omy's welcome is two sentences; the PKGBUILD reads like code with its reasoning in
  `docs/packaging.md`; one `account_home`, one `is_in`, no `TIME_CONF_BIN` handshake, no
  `PY` aliases, `apps list --json` instead of parsing a table by column offset.
- Harness run 6 after all of that: six of eight scenarios green in one run; the two failures
  were SSH timeouts through the laptop, and both scenarios passed on their own straight after.
- Afternoon finds, all from screenshots and the fresh-greeter probes, all fixed and verified on
  the VM: the greeter's Left and Right died after a password field had been opened and closed
  once (focus stayed on the hidden field; a parent could not arrow from a kid's tile to their
  own); the harness's "session is live" check counted its own SSH login, so scenario 20 had
  been passing while the screen showed the portal; and behind that, the real V7 gap: nothing
  ever recorded the parent's LUKS slot, so a boot unlocked with the parent's disk password
  landed on the portal instead of the parent's desktop. `omarchy-kids-conf machine set parent`
  now writes the `0=<parent>` line, and a cold boot with the owner's password lands on the
  owner's desktop again.
- The kid session now starts Hyprland through `start-hyprland -- --config`, Hyprland's own
  watchdog launcher, which removes the red "started without start-hyprland" banner every kid
  saw at login. Arguments must follow `--`; without it the launcher drops the config, which is
  the kind of thing only a live run catches.
- Panel polish from the screenshots: no step counter on single screens, facts without the
  account prefix, an honest footer (`q` never quit), "lights-out at 19:30" instead of "next
  boundary: lights-out at 19:30", and a stronger scrim so the Time's Up card fades behind the
  Ask modal.
- Three harness lessons, each now a line of code: a session exists before its keybinds do (the
  Super taps must wait for the launcher), the owner's boot now autologs the owner so a portal
  reset must wait for that session before exiting it cleanly, and a kid whose daily budget
  earlier scenarios used up gets Time's Up at login, which swallows the exit keystrokes.
- Harness run 7, after all of that: all eight scenarios green in one run. Then the launcher,
  the exit modal, the Ask modal and Time's Up were screenshotted with catppuccin-latte as the
  kid's own theme: all four read well on light. Setting that theme under `sudo` had died on an
  unset variable left by a review refactor; fixed with a test that runs it unset.
- One more harness lesson: the exit modal preselects Finish while Pause has no mechanism (the
  honest-UI rule), and the scenario's extra Tab was moving the selection onto Pause, which the
  modal refuses. The launcher change was never at fault; scenario 30 passes with the launcher
  frame clean of the banner.
- README and the parent card were reread as a parent would: the Phase 1 status line still said
  V1 was in progress (it finished and failed, which is why Pause is not built), the card
  promised a fast user switch that does not exist, and two spec citations became plain words.
  Every other claim in both checked out against the code.
- Harness run 8 over the end-of-day main: all eight scenarios green again.
- The wizard's first six screens screenshotted under catppuccin-latte on the owner's desktop:
  themed and readable; two nits fixed from them (the input box no longer repeats the card's hint
  as its placeholder, and the avatar list no longer pages at ten rows).
- The portal follows the owner's theme: after switching the owner to catppuccin-latte and
  re-asserting, the greeter came up light with the theme's blue on the selected tile.
- From 17:00, at your request, Codex (gpt-5.6-luna, high) writes the first draft of every
  ticket, headless from the shell in its own clone; I brief, gate and merge. Its first two jobs:
  an AUR-maintainer pass over `docs/install.md` and `docs/packaging.md` (merged after checking
  every claim it wrote against the files) and a maintainer review of main (running).
- Codex's review (`docs/reviews/2026-09-03-codex-maintainer.md`) would not bless the repo yet:
  16 findings, ten high. The real ones: the kid-facing launchers still read path prefixes from
  the environment (the same class round two closed for the verifier, allowed through as "scratch
  tree" variables), the launcher runs a kid-writable exec string through a shell, screen time
  is enforced from the kid's own process, and the group assert accepts a kid who is also in
  wheel. Filed as #59 to #63; Codex is drafting #59 and #60 now, #61 rides with #59, #62 next.
- Architecture review (`docs/reviews/2026-09-03-architecture.md`): keep the stack, rebuild three
  shapes (a root-written session manifest, root-enforced screen time, one config schema), then one
  kid shell for the speed you can feel, and two deepenings in place. Per your direction the
  pipeline from here is: gpt-5.6-sol writes a spec per candidate in `docs/specs/` with a ticket
  breakdown, the tickets are filed, gpt-5.6-luna drafts each one, I gate and merge.
- Six specs are in `docs/specs/` (written by gpt-5.6-sol, checked against the code), and their
  24 tickets are issues #64 to #87, four per spec, in order. Codex is drafting #64, the session
  manifest builder. Codex's launcher fix (#60) merged after both suites; its first cold boot
  showed an empty launcher because the boot-time assert runs with no HOME and the builder wrote
  an empty map silently; fixed the same hour with two rules that now have tests: root-side
  builders never replace state on failure, and root paths are exercised with an empty
  environment.
- Codex's fixes for its own review are in: #60 (root-owned launcher map, no shell evaluation),
  #59 (no environment-selected paths in any kid-facing command, absolute Quickshell, the home
  from getent, /tmp and /dev/shm fail closed, all six gettys masked) and #61 (exact group
  allowlist, root checks at the entry of ask's root verbs). Each was gated on both suites and
  the live login scenario; #59 needed two rebases and one Linux-only test fix on the way.
  Spec 01's first ticket (#64, the session manifest builder) is the first spec-driven merge.
- Spec-driven merges so far, each drafted by Codex and gated on both suites: #64 and #65 (the
  session manifest builder and the kid's own validated read of it), #68 and #69 (the root ledger
  tick now decides budget and lights-out from root-owned data and ends the session itself; the
  kid-side overlay only warns). #66 (session startup reads one manifest, no scans, no runtime
  exec strings: session-start went from 253 lines to 108) passed both suites, was merged, and
  was reverted the same hour: nothing built the manifest on a provisioned machine yet, so a kid
  got a black screen, and scenario 10 had passed because it only checked that the session was
  live. Two rules came out of it and are now code: a consumer never merges before its producer
  is wired, and a live scenario asserts the launcher is running, not that a session exists.
  Ticket 4 re-lands it with the wiring.
- The community scan is done: `docs/research/2026-09-03-community-scan.md` reads the whole
  #omarchy-kids channel (64 messages, the design thread) and ten repos. Short version: nobody
  else has per-kid accounts, a login portal, browser policy or a live harness; two things are
  worth borrowing (a signed, single-use ask-a-parent protocol from omarchy-parentapproval, and
  the hardened root-helper shape from omarchy-clarity and omarchy-pisafe), one needs a written
  decision (our per-kid-account model against Pete's one-shared-account installer path, which is
  DHH's own spec). Filed as #88, #89, #90. Discord text stayed on the Mac.
- After midnight: #66 and #67 landed together (session startup reads one root-built manifest;
  assert and provision build it), and the first real boots found three root-only bugs that the
  Mac suite cannot see: the launcher map read a file mode's owner digit as the world bit and
  refused every root-owned 755 app, a kid without a theme of their own could not get a manifest,
  and a settings change made the next login fail closed on a stale manifest until the next
  assert. All three fixed with tests; `omarchy-kids-conf set` now rebuilds the manifest itself.
- The standing order and the definition of done are written down in `docs/GOAL.md`.
- Still open for you: the same list as before (#2 #4 #17 #26 #28 #32 #33, hub PR #3). One
  thing to know: an agent installed Homebrew bash 5.3 on the Mac without being asked; it is
  harmless and still there.

## What is open

- `#2` V1 and `#17` Pause: SDDM on 4.0.2 cannot open a second greeter; a design decision.
- `#4` V3: the captive-portal window needs a real captive portal to test.
- `#26` `#28` `#32` `#33`: real Wi-Fi hardware, a populated plugins catalog, the AUR upload and
  the upstream notes need the laptop or you.
- The greeter arrow-key focus question and the scenario-20 assertion (round three, above).

Decisions waiting for you: `docs/phase1/DECISIONS-NEEDED.md` (Pause, snapshot entries, AUR
publish, upstream notes). Blocked items: `docs/phase1/BLOCKED.md`.

## Things learned the hard way

`docs/exit.md`, `docs/vm.md` and `docs/live-tests.md` carry the details; the short list: a
hard `loginctl terminate-session` or a killed greeter leaves SDDM with no greeter at all;
Hyprland 0.56 wants `hyprctl dispatch 'hl.dsp.exit()'`; a QEMU power cut two seconds after
`pacman -U` zeroed the unit files; `DRY_RUN=0` does not cross `sudo`; SDDM's autologin stack is
a separate PAM file; the greeter lists accounts alphabetically, not in our order.

## State of the machines

The laptop (`omarky-air`) was never rebooted and its own account was not touched beyond the
repo clone. After the real Remove run the wizard re-provisioned Cy for real and a cold boot with Cy's
password landed on the launcher again, which closes the cycle; the older kids' files are under
the owner's "Kids Mode" folder; the owner `kid-vm` is in `omarchy-parents` and has the bar widget enabled. The
scratchpad on the Mac holds only the driving scripts; every screenshot was deleted after viewing.

## 2026-09-04, small hours: the Air itself becomes the target

Mark's order at 03:30: no AUR upload, no hub PR; install on the Air itself, dogfood on real
hardware, spawn gpt-5.6-sol agents, best work. GOAL.md's definition of done changed to match.

- #70 (spec 02 ticket 3, the kid path is display only) merged after the VM gate passed twice;
  the first failure was a host-coupled conf test (it scanned the VM's real desktop entries), now
  isolated with `OMARCHY_KIDS_ROOT`. #71 is being drafted; #72 (config schema) is in a
  review loop: a sol maintainer review said FIX FIRST (package-owned schema path, band-derived
  dns/history sources, parent-theme source, strict schema validation, missing reject tests) and
  luna is fixing.
- First two walkthrough videos recorded on the VM from QMP frames: the kid's day (delivered)
  and the parent's setup (not delivered yet: the take ran while the VM was busy with the unit
  gate, so gum screens rendered late and one keystroke landed on the wrong screen; the apply
  step then showed a sudo prompt in the terminal). Re-recording on an idle VM before judging.
- sol wrote the Air install plan and its verdict is the important finding of the night: the
  package's disk path (LUKS slot per kid, initramfs hook, UKI rebuild, Limine entry, run from
  assert on every pacman transaction once a kid exists) is a boot risk on an encrypted laptop
  whose passphrase nobody will type for us, and the boot-login unit forces the portal by
  writing an empty `User=` when no slot is recorded, contrary to its own comment. There is no
  supported way to run Kids Mode without the disk path.
- Decision (mine, under Mark's "I trust you fully"): make a portal-only boot mode first class
  instead of hand-quarantining units on the Air. sol is writing docs/specs/07-boot-mode.md: a
  root-owned `boot=disk|portal` machine setting, read by provision, assert, boot-login, remove and
  the pacman hook, chosen by the wizard from detection and overridable; it also fixes the
  boot-login bug, the wizard's passwordless-sudo password check (accepts anything), and the
  apply step's second prompt. The Air install follows spec 07's first tickets, in portal mode.

### 04:00, first screenshot pass (VM, kid-cy, tokyo-night and catppuccin-latte)

Surfaces shot: portal, launcher (rest and focus), KTuberling at Level 1, the exit modal over the
launcher and over the fullscreen app, the modal with a typed password, the launcher after
Super+Q, then the screen-time surfaces. Findings, in order of weight:

- Screen time did not act. With a fresh root state, budget set to used+1 minute and a ledger
  tick forced, no toast appeared within 5 s and no Time's Up within 150 s of the next tick; the
  session stayed up. Main today has the kid path reduced to display (#70) but the root
  infrastructure re-assert and the live proof are #71, in its VM gate now. Re-shot after #71.
- The portal shows a leftover account as a kid tile (#100): SDDM's user model feeds every
  regular account into the tile list and anything not a parent is treated as a kid. The
  fallback silhouette also overflows its circle.
- The wizard's Apply asks for the sudo password a second time: the step output is piped through
  `sudo tee` into the root-owned setup log before the ticket exists (spec 07 ticket 5, #96).
- The exit modal, Super x3 over a fullscreen app, Escape, Super+Q, and the launcher all behave;
  dark and light themes render correctly on the launcher and modal. The light portal could not
  be judged yet: the VM owner's theme switch needs the Omarchy path exported over SSH.
- Driver lessons: QEMU key names (`esc`), chords are one `key` call with several names, gum
  renders late under CPU load (the unit gate on the VM), a kid tile that is "not installed
  yet" swallows Enter (the first kid-day video opened nothing; re-recorded next).

### 04:30, spec 02 closes its tickets; the live proof says "almost"

#71 merged after its VM gate. Scenario 40 on main: root enters grace at lights-out and
auto-finishes the session, the greeter returns; but root's lock step reports not-needed while
the kid is live, and the scenario's own kill uses `pgrep -x` on a name Linux truncates. A sol
post-merge review added a rule-9 violation in assert-locks (an inherited environment root
selects time paths), swallowed chown failures, root:root 0755 usage directories where the spec
says kid group 0750, and a timer check that never repairs the installed unit. All six plus the
lock investigation went back to luna on `roottime-5`, fixing forward on main.

Spec 07 moved: #92 (the boot setting, package no longer owns the /etc drop-in) and #96 (PAM-only
parent auth, Apply never prompts twice) are drafted and Mac-green; VM gates run in sequence
with sol reviews. #72 (config schema) passed sol's third round on the Mac. Decisions made under
the standing order: snapshot entries hidden in disk mode (§3), AUR out of scope (§4), the exit
modal ships Finish only (#102). New UX tickets from the screenshots: #100 stray portal tiles,
#101 launcher frame after an app closes.

### 05:10, merges and the queue

Merged: #72 (config schema, three sol rounds) and #102 (exit modal is Finish only). Drafted and
in gates: #92 (boot setting; rebasing over the schema merge), #96 (PAM-only parent auth; sol's
second-round items being fixed), #100 (portal tiles), the #71 fix-forward on `roottime-5`, and
#73 (wizard and panel read the schema). Screenshot and video passes resume once #100 and the
fix-forward land, so the portal and the screen-time surfaces are shot as they will ship.

### 06:20, the portal is honest

#100 merged after two sol rounds: tiles come only from posture's root-owned allowlists, a stray
account gets nothing, an unpinned session refuses login, and scenario 30 now reads the tile
count the greeter itself reports. Scenario 30 runs on main next, which also takes the first live
picture of the Finish-only modal (#102). The #71 fix-forward is in its second round (sol found
a grant clearing enforcement without unlocking, swallowed systemctl failures, weekend settings
bypassing both live scenarios, and the VM gate saw launch-history tests break under the new
0640 ledgers). #73 (typed profile access) and #92/#96 are in their fix rounds. The VM now has
ShellCheck so the install script is linted for real.

### 07:30, one VM driver at a time

Three VM gates in a row lost their SSH session mid-suite and one left a QEMU stuck at the disk
prompt with no control socket. Cause: the #71 fix-forward draft, whose brief named live
scenarios 40 and 50, ran scenario 40 itself from its clone, and its boot step rebooted the VM
under the gates. Fixes: AGENTS.md rule 11 (drafting agents never drive the VM), draft clones no
longer carry `test/live/config.env` (the gate runner lends it for its own run only), every
brief now says so in its first line, and `boot_with` retypes the disk password every 30 s while
the VM stays unreachable. The dropped gates (#73 round three, #92, scenario 30, #96) are queued
again in order.

### 08:50, the boot setting lands

#92 merged: `boot=disk|portal` in machine.conf behind a trusted reader, the package no longer
owns the mkinitcpio drop-in, and upgrades migrate from real disk evidence. Three sol rounds;
ShellCheck now runs on the VM. Luna is on its consumers #93 (assert and the pacman hook never
touch the UKI or Limine in portal mode) and #95 (provision and removal mode-aware); #94
(boot-login preserves stock autologin) follows. #96 (parent auth without sudo) is on its fifth
and final commit and queued for the VM; #73, #76 and the #71 fix-forward are in review rounds.

### 09:50, sol takes the code, and the Air is prepped

Mark switched the drafting model: gpt-5.6-sol on high writes the code as well as the specs and
reviews (a separate sol session reviews, so the reviewer never grades its own work). Merged
since the last note: #101 (the launcher stays edge to edge after an app closes) and, earlier,
#92, #100, #102, #72, #71.

The Air is prepped for the portal-mode install: rollback state captured at
`/root/omarchy-kids-preflight` (the PAM, SDDM, fstab, namespace, Limine and mkinitcpio files as
a tar, the 981-package list, the single UKI hash, limine.conf), the package builds clean on the
laptop, and two runbooks are ready in the scratchpad: one installs in portal mode and gates on
"the UKI, Limine and the stock autologin are byte-identical afterwards", the other returns the
laptop to stock. The install waits on #93 (assert and the pacman hook), #94 (boot-login) and
#95 (provision and removal) so that portal mode is honoured by every root path, not just the
setting.

### 14:20, back up after the Mac died

The laptop driving the loop lost power around noon and took `/tmp` with it: every Codex draft
clone (unpushed, so #93, #94 and #95 are gone), the live harness's `test/live/config.env`, the
gate and chain runners, the screenshot drivers, and the two Air runbooks. The Air, the VM and
everything pushed to `origin` were untouched — the VM was still sitting at its greeter with no
orphan runs, and the Air still holds the pre-install rollback state at
`/root/omarchy-kids-preflight`.

Rebuilt: the `air`/`vm` ssh stanza from `docs/vm.md`, `config.env` from its own example file, and
the gate runner. Everything the loop cannot cheaply rebuild now lives in `~/.omarchy-kids-loop/`
on the Mac instead of the scratchpad, with a README saying why. New standing rule: a draft branch
is pushed to `origin` as soon as it has one working commit, because an unpushed branch is one
power cut away from gone.

Main is green again on the Mac suite (35 files, no failures), the VM suite is running against it,
and gpt-5.6-sol is redrafting #93 (assert and the pacman hook honour the boot mode) and #95
(provisioning and removal honour it). `build_install`'s rationale, which the last commit before
the crash had separated from its function, sits with `build_install` again.

### 15:00, the portal had no kids on it

Scenario 30 failed on main, and the failure was real. On a box with two kids the login portal
renders a single tile: the parent. No child can log in. With one kid it works, which is why every
live run so far has passed and why the bug reached main at all.

The greeter's own QML, asked to say what it built, reported `kids=0 parents=1` while
`theme.conf.user` held both kids. `config.kids` arrives in QML as *undefined* while the comma-free
`config.parents` arrives intact: QSettings reads an unquoted comma-separated value as a list, and
that value never reaches the map SDDM hands the theme. Quoting the value by hand and restarting
the greeter turned one tile into three on the spot. Issue #104 has the evidence and the fix, and
gpt-5.6-sol is on it — the producer quotes its list values, every reader learns the quotes, and
the suite gains the two-kid regression it never had.

A second defect was hiding the first: the harness read the greeter's tile report with
`journalctl -u sddm`, but the greeter logs under the identifier `sddm-greeter-qt6`, so the check
added with #100 had never once seen the line it asserts on. Fixed on main. Two checks that could
not see each other's failure is how a portal with no children on it stayed green.

#93 (assert and the pacman hook honour the boot mode) is drafted, pushed to `boot-2`, and with an
independent sol reviewer; #95 is still drafting.

### 2026-09-05, four merges, two real-hardware finds, and one decision left for a human

Four spec-07 tickets landed: #93 (assert honours the boot mode, serialised by one root-owned lock
that the mode setter and the install scriptlet also take), #94 (boot-login resolves the account to
a trusted role, so a malformed record can never drop a kid into the parent's session), #95
(provisioning and removal honour the mode) and #104 (the portal shows kid tiles again once a
machine has more than one kid). Main was gated on the VM with all four combined, not only branch by
branch, because four branches that each pass alone can still conflict together.

#104 is worth remembering. On any box with two or more kids the portal rendered a single tile, the
parent's, so no child could log in at all. The kid list is written into the greeter's theme config
as a comma-separated value, and QSettings reads an unquoted comma-separated value as a list, which
never reaches the greeter's QML. It took five rounds: the first fix quoted the value, and the
review correctly called that a half fix, since a display name is typed by a parent and a name
carrying a quote breaks straight back out. What shipped escapes the way Qt's own encoder does, with
every reader its exact inverse, and encodes the record separators inside each field. A child called
"Bo, Jr" reaches the login screen. A second defect had hidden the first for days: the harness read
the greeter's tile report from the wrong journal source and had never once seen the line it
asserts on.

**Kids Mode is installed on the Air**, in portal mode, owner recorded. Two bugs surfaced within
minutes, neither of which the VM could have shown:

- The app entry did not open a terminal. `omarchy-kids` is a gum TUI, so clicking Kids Mode gave a
  launch toast and then nothing at all. Omarchy's own TUI entries set `Terminal=true`; so does ours
  now, with a test that says why.
- **#109**: installing the package rebuilds the UKI and rewrites `limine.conf`, even in portal mode
  whose entire promise is that it leaves the boot path alone. Our own hook behaves correctly and
  changes nothing; the rebuild is Arch's `90-mkinitcpio-install.hook`, firing because the package
  ships a file under `/usr/lib/initcpio/hooks/`. A parent who installs and chooses portal has had
  their boot image regenerated before answering a question.

**Process changes, measured rather than assumed.** Of roughly twenty review rounds, eleven found
real defects, five were environment problems and four were rebases and scope. The five are fixed
structurally: the gate now runs the test box's formatter first, in seconds, because the Mac cannot
host that formatter honestly (Homebrew's 3.14 disagrees with the box's 3.13 on files already
clean). The unit suite runs in parallel on the Mac and serially on the VM, which has two cores and
is the correctness gate; a file that fails in parallel is re-run alone and named. Review now comes
before the gate, since reviews are cheap and parallel while the gate is one slot. And AGENTS.md
gained the six shapes every blocking finding has taken, with drafts required to attack their own
diff against it before handing over.

The test box had also been running at a third of its capacity for days: sixteen orphaned processes
from a wizard-test stub that waited on a release file with no bound, one leaked per interrupted
run. Bounded, and its load fell from ten to one.

**Left for a person, not an agent.** #98's transitions no longer touch the boot image, but the
conversion now asks the parent to rebuild by hand, and a power cut during *that* can still leave
this single-UKI laptop unbootable with no firmware-bootable fallback. Its author said plainly that
it cannot be called power-cut safe and returned the ship decision. That belongs with #109, which
is the same single-image weakness seen from the other side. #103 is implementation-complete but has
taken no real pictures yet; the media folder waits on a session that can drive the machines.

`PROGRESS.md` and `docs/handoff-prompt.md` carry all of this forward.

## Takeover pass, 2026-09-05

Connected to both machines and inspected real laptop welcome/password screens and the VM
portal and launcher. The laptop screenshots produced #110, keyboard guidance hidden until
after input, and #111, stale inherited gum colors overriding the active theme. The light VM
portal produced #112, a faint parent-account label. Each ticket links a screenshot and its
cause line. The originals are under `docs/media/dogfood/`; they record findings, not release
acceptance.

Independent review approved #110 after fixing two ShellCheck warnings, and #111 after testing
the actual upstream terminal helper. #110 merged through PR #113 at `bd679f9`: VM formatter
first, all 35 Mac test files, the same suite serially on the VM, and live welcome/input/back/cancel
on both machines passed. The Mac had five platform skips; the VM had two (bar status fixture and
ash syntax). Authentication and SO_PEERCRED checks ran on the VM. The merged-main formatter, both full suites, and the same live scenario also passed; all eight
post-merge screenshots were inspected and both wizard processes exited after confirmation.
The live scenario used exact staged source with `--dry-run`, so it proves the renderer and
keyboard navigation, not provisioning or full installation. #111 remains draft PR #115.

The newly visible keyboard help is too faint in both themes (#119), and resizing an existing
wizard corrupts the printed card (#120). Both are separate screenshot-backed tickets. The VM's
empty More apps shelf produced #117, and its exit card's unlabeled password field produced #118.
The missing-app launcher finding belongs to existing #91, which received the new screenshot.
#112's parent-label correction has independent approval and awaits its gate in draft PR #116.

Review of #103 found that an unsuccessful service-status query could leave the temporary
login running while cleanup reported success. The correction preserves uncertainty and checks
termination, and independent review approved it at `8ba4d6a`. Draft PR #114 awaits the full gate
and real captures. A drafting session initially pushed this correction to the hub; that exact
mistaken branch was removed after its hash was checked, and the commit was recovered into the
sandbox. The repository identity is now explicit in the repo lock and AGENTS.md.

A screen-time finding from real VM use is being handled privately under the hub's SECURITY.md.
Its remediation remains separate from the public UI tickets. #98 still requires Mark's ship
decision with #109; #97 still waits for #98. The Air has not been rebooted or had boot files
changed during this pass.

Mark requested file watching for Quickshell iteration. The laptop inherited
`QS_DISABLE_FILE_WATCHER=1`; clearing it for a separate Kids Mode preview made an edited title
appear without restarting the process. The original title was restored and the preview closed.
`docs/live-tests.md` records the launch requirement. This preview is not release media.

The empty More apps shelf now has a reviewed draft with a compact card and a real Back button
(PR #122). A separate watched laptop preview demonstrated Escape, pointer hover, and an actual
click closing the surface. The exact #111 desktop entry also launched the installed wizard with
correct theme values in both Tokyo Night and Catppuccin Latte. Temporary previews and the entry
were removed, and Tokyo Night was restored. These checks do not replace their ordered gates.

The parent panel empty state was inspected on the laptop. Following Add a kid exposed #123:
preview mode was not handed to the wizard. An owned wizard stub confirmed the mode loss without
provisioning an account. Its explicit CLI mode handoff is drafted for independent review.

## 2026-09-18 — review-driven drafting loop (deepseek drafting, fable reviewing)

A headless loop turned the two 2026-09-18 read-only reviews (status + UI/UX, run with
`claude-fable-5-1` high effort) into reviewed topic branches. No push, no PR, no VM run: the `gh`
CLI's active account is not `markcuda` (repo lock), and rule 11 keeps drafting agents off the test
VM. Everything below is local, for the gate runner.

| Branch | What | State |
| --- | --- | --- |
| `fix/time-lock-engagement` (`9d038cf`, off main) | The root tick locks only the account's own graphical session (`Class=user`, `Type=wayland|x11`), verifies `LockedHint=yes` before recording success, retries failures, and keeps the deadline; a manager session no longer counts as active time (R-TIME-2, R-TIMEAUTH-4). | Reviewed (approve with nits, closed). Needs the VM lock scenario. |
| `docs/truth-pass-2026-09-18` (`6f8639e`) | README, panel.md, exit.md, time.md, wizard.md, style.md, conf.md, the trimmed-menu comment and media/README checked against the code. | Reviewed twice: changes required, then approve. |
| `fix/wizard-honesty` (`cccda92`, `3c43dec`; stacked on the docs branch) | Drops the Advanced App menu row (no level reads the key), fixes the history row to ask about the parent's view, carries a failed Apply's own tail into Done, removes the preview button that only apologised, draws the summary once, takes the 3-5 password question from band data, and leaves honestly after Apply; SPEC.md R-WIZ-1/R-WIZ-6/A14 amended to record the unshipped preview. | Reviewed; both rounds' findings closed. |
| `fix/panel-write-results` (`2e10e59`, `a34a432`, off main) | `PANEL_NOTICE` carries preview / applied / failed (the command's last line) into the next card; a rejected password and a failed site-list write now say what happened. | Reviewed; findings closed. |
| `fix/blocked-screen` (`2cdfa33`, off main) | The R-DESK-2 fail-closed screen takes the theme accent and shared rounded border and sends the child to a grown-up instead of naming a CLI command; new `blocked-test.sh`. | Not independently reviewed (small, tested). |

Private: `.local/recovery/spec-08-session-lock-engagement-PRIVATE.md` is a fable-written spec for
the missing Level 1/2 lock listener (options, interface, requirements, tickets). It describes the
still-open lock weakness, so it stays out of the public tree until the owner approves publication.

Machine notes for the next run: on this Mac `python3` resolves to a mise shim that can stall the
suite under parallel load; `test/all` is green with
`PATH=$HOME/.local/share/mise/installs/python/3.13.15/bin:$PATH`, except `packaging-test.sh`,
which fails only because `shellcheck` is not installed here. The previously stalled
`remove-test.sh` passed alone with that PATH.

Open follow-ups the loop recorded but did not fix: `screen_done` maps a TUI error (2) to a normal
finish; the remove command's own confirmation is still a plain `read` instead of the card idiom;
Level 3 is still offered while unverified; the dead `menu`/`terminal` band keys remain accepted
config. Level 1/2 lock engagement depends on the private spec above.

### 2026-09-18, later — second round

Continued the loop with the same drafting/review split. New local branches:

| Branch | What | State |
| --- | --- | --- |
| `feat/panel-machine` (`b04206b`, `cd12088`; stacked on `fix/panel-write-results`) | P4 Machine: Home row and screen running `omarchy-kids-check --json`, verdict, every FAIL/WARN in full, counts, **Check again**. | Reviewed; shape validation, full details, `0x1f` parsing, the unprivileged note, and garbage/refresh tests closed in `cd12088`. |
| `fix/panel-request-names` (`eb006a9`, `8c6d02a`; stacked on the Machine tip) | Requests show the profile name (account in parentheses on the card). | Review caught a wrong parent (rebased) and name-hygiene gaps (`|`, whitespace, control chars); fixed and tested. |
| `test/theme-palette-parity` (`b8d2d35`, off main) | Pins the four hand-kept fallback palettes to `lib/theme.sh`; proven to fail on a one-character drift. | New test, no review needed. |
| `docs/command-metadata` (`0779540`; on the docs truth branch) | `omarchy:hidden=true` on the eight internal commands, wizard args list `--apply`, time summary names `grant`, panel `--help` drops spec ids, style.md updated. | Batch review pending. |
| `fix/kid-surface-words` (`20c1f43`, off main) | Time's Up is reason-aware ("It's bedtime") and says "Closing in Ns"; the Level 2 footer says "Grown-up exit"; the exit card says Finish returns to the login screen. | Batch review pending. |
| `fix/launcher-empty-hints` (`27a4f7a`, off main) | Level 1 gains a key-hint footer and "Nothing is set up here yet." empty state; the font-count test moved 10→12. | Batch review pending. |

Mac test note update: the launcher node tests need a real Node, not the mise shim —
`PATH=$HOME/.local/share/mise/installs/node/20.19.0/bin:$HOME/.local/share/mise/installs/python/3.13.15/bin:$PATH`.

Still not done: a card-mode panel test (the wizard's exists), `font.family` on the exit/Ask/plugins/
Time's Up/toast surfaces, Level 3 gating (human decision), the dead `menu`/`terminal` band keys,
and the remove command's own plain `read` confirmation.
