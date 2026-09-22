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

### 2026-09-18, third round — review fixes

All three batch-reviewed branches closed their findings:

- `fix/kid-surface-words` gained `87db426`: the media driver and its test now wait for "Closing in"
  (the capture would have timed out), SPEC R-EXIT-1 quotes the shipped Finish subline, the
  exit-test static block moved out of the flag-parsing group, and the reason assertion matches the
  actual `root.reason === "lights-out"` branch.
- `fix/launcher-empty-hints` gained `e50ffee`: the comment and CHANGELOG no longer claim a failed
  manifest shows the empty state (a failed manifest hides the window first), `z: 1` keeps a tall
  grid from painting over the footer, the test matches the Level 1 string, and both visibility
  bindings are asserted.
- `docs/command-metadata` gained `278d1f5`: the time summary names `daemon` too, and the panel
  usage paragraph is reflowed.

Review findings left as recorded open items: `blocked`/`session` are candidates for
`omarchy:hidden`; the ledger's grace keeps its first `reason` for the whole countdown; and
`docs/time.md`'s dated live record still quotes the old "Finishing in" wording.

Full suite run at the end of the round (pinned Python and Node on PATH): **47 of 48 files pass**.
The only failure is `packaging-test.sh`, and only on this Mac — it needs `shellcheck` (not
installed) and its legacy disk-upgrade fixture needs Linux. All five new tests
(`theme-palette-test.sh`, `blocked-test.sh`, plus the additions to `panel-test.sh`,
`launcher-desktop-test.sh`, `launcher-grid-test.sh`, `time-test.sh`, `exit-test.sh`,
`media-driver-test.sh`) are in that green set.

### 2026-09-18, fourth round — fonts, triage, hygiene

- `fix/qml-fonts` (`f306ca0`, `f81fc00`, off main): every Text/TextInput block under
  `share/**/*.qml` now resolves a font family — the exit modal, Ask, plugins, Time's Up, the
  toast, the remaining Wi-Fi rows, and the bar's two badges (`bar.fontFamily`, falling back to
  `qs.Commons`' `Style`). Review caught a committed `share/.DS_Store`, nested-block gaps and a
  too-loose `font:` escape in the new scanner; all fixed. `qml-fonts-test.sh` fails on the
  pre-change tree; the scan covers every QML surface.
- `docs/branch-triage-2026-09-18` (`f8e3917`, off main): the 79 unmerged remote branches sorted
  for the gate runner — 45 already content-merged (deletion candidates), 19 clean merges, 15 need
  a rebase. The loop's own branches are listed separately.
- Hygiene: `docs/.DS_Store` and `share/.DS_Store` were untracked from every branch tip
  (`a138f67`, `888eb9f`, `fa6bd88`, `f81fc00`); all local branches verified clean.

### 2026-09-19, fifth round — settings, time-left, and the loop tooling

- `feat/panel-all-settings` (`43decbd`, stacked on the panel branches): R-WIZ-8's remaining panel
  settings — weekday and weekend budgets/lights-out, a Wi-Fi mode row, and a confirmed Reset to
  band defaults; `friendly_wifi_mode` now lives in `lib/kids.sh`. Panel suite green; the fable
  review was re-run after interruptions.
- `feat/remaining-time` (`db65f28`, stacked on the launcher hints branch): the launcher reads root's
  `/run/omarchy-kids/time/<kid>.json` display-only and shows "N minutes left" (Level 1 under the
  clock, Level 2 top-right, hidden in grace); `GridNav.remainingLabel` owns the words, node-tested,
  with `docs/time.md` recording what only the VM can prove.
- R-ASK-2's "one keystroke" approve is **parked on the owner**: Enter-on-list approving directly
  changes approve semantics; today it is list → detail with Approve preselected. Recorded rather
  than guessed.
- Tooling: `opencode-loop` installed (`~/.config/opencode/plugins`, `commands/`); the unattended
  protocol is `.opencode/loop-prompt.md` with the backlog and stop conditions, plus
  `docs/research/2026-09-18-kids-mode-landscape.md` (timekpr-nExt, Cozy Kids Launcher, others).
- Next: apply the P2 review findings, then research-derived favorites/recents or config
  export/import; per-app limits and weekly caps wait on a SPEC amendment.

### 2026-09-18, fifth round — panel P2 coverage and the kid's clock

- `feat/panel-all-settings` (`43decbd`; stacked on the panel branch chain): R-WIZ-8's "every
  setting" is now covered — weekday **and weekend** budgets and lights-out rows, a Wi-Fi mode
  screen (Ask me first / On their own, safely), and a confirmed Reset to band defaults that keeps
  the account, name, face and password. `friendly_wifi_mode` moved into `lib/kids.sh` so the panel
  and wizard cannot drift. Panel suite green; fable review pending (re-run; the first was killed
  by an interrupted tool call).
- `feat/remaining-time` (`db65f28`; stacked on the Level 1 hints branch): the launcher reads root's
  published time state (read-only `FileView`) and shows "N minutes left" at Level 1 and on the
  Level 2 desktop, hidden in grace. `GridNav.remainingLabel` owns the words and is node-tested;
  docs/time.md records that the live file watch still needs the VM.
- R-ASK-2's "approve/decline on one keystroke" is left open on purpose: the current list → detail
  (Approve preselected) is two screens, but making Enter on the list approve directly changes
  approve semantics and is the owner's call.

The loop's `.opencode/loop-prompt.md` protocol (committed on `chore/loop-and-research`) carries
this backlog for `opencode-loopd` when the session is not driving.

### 2026-09-19, fifth round — settings coverage, time-left, loop tooling

- `feat/panel-all-settings` (`43decbd`): P2 gets weekday **and weekend** budgets/lights-out, a
  Wi-Fi mode row, and a confirmed Reset to band defaults; `friendly_wifi_mode` moved into
  `lib/kids.sh`. Panel suite green; fable review re-run after interruptions.
- `feat/remaining-time` (`db65f28`): the launcher reads root's `/run/omarchy-kids/time/<kid>.json`
  display-only and shows "N minutes left" (Level 1 under the clock, Level 2 top-right, hidden in
  grace); `GridNav.remainingLabel` owns the words, node- and static-tested. docs/time.md records
  what only the VM can prove.
- R-ASK-2's "one keystroke" approve is parked for the owner: Enter-on-list would change approve
  semantics, so the current list → detail (Approve preselected) stays until that call is made.
- Tooling: `opencode-loop` + `opencode-loopd` installed; the unattended protocol is
  `.opencode/loop-prompt.md` (`5f2ec0d`) with the backlog and stop conditions, plus
  `docs/research/2026-09-18-kids-mode-landscape.md`.
- Next in the backlog: apply the P2 review findings, then favorites/recents from the launch log or
  config export/import; per-app limits and weekly caps wait on a SPEC amendment.

P2 review round closed in `484cd4b`: Back on the Wi-Fi screen no longer runs a write, the reset
card lists what actually stays (account, name, face, band, password, theme, hand-added sites), the
Wi-Fi labels/detail match `docs/wifi.md`'s real behavior, `friendly_wifi_mode` lives once in
`lib/kids.sh`, the weekday rows say "weekday", and the Wi-Fi tests use an exact answer script with
a real reset case. Panel and wizard suites green.

Backlog item 4 landed as `fix/remove-confirm` (`b9af8da`): `omarchy-kids-remove` confirms through
the shared card when a terminal is attached (type `yes` in full; Esc/Ctrl+C cancel) and keeps the
original one-line prompt for pipes and scripts, with `--yes` unchanged. `remove-test` passes on the
piped path and pins the tty branch statically; `trust-boundary-test` passes with the new
`lib/tui.sh` source.

### 2026-09-19, sixth round — remove's confirmation

`fix/remove-confirm` (`b9af8da`, off main) closes backlog item 4: `omarchy-kids-remove` uses
`lib/tui.sh`'s input card when a human is at a terminal (type `yes` in full; Esc/Ctrl+C cancel),
while a pipe or script keeps the original one-line prompt and `--yes` still skips it. remove-test
keeps the piped decline case and pins the tty branch; trust-boundary and remove suites green.

Backlog now: R-ASK-2 (owner decision), research-derived favorites/recents or config export/import
(`docs/research/2026-09-18-kids-mode-landscape.md`), then the I-6 deep-review pass.

### 2026-09-19, seventh round — portal help and failure wording

`fix/portal-help` (`aa0c036`, off main): the SDDM greeter now names its keys at the bottom
(arrows/Enter/power-off, switching to Enter/Esc while typing) and words a wrong password ("That
password didn't work. Try again.") instead of only shaking the tile. `portal-test` pins both
strings; `docs/portal.md` records the live check as still VM-only. The empty
`docs/spec-proposal-per-app-limits` branch was deleted.

### 2026-09-19, seventh round — portal help and worded failure

`fix/portal-help` (`aa0c036`, off main) closes a deep-review finding: the SDDM greeter now names
its keys at the bottom ("← → Choose · Enter Sign in · Ctrl+Shift+P Power off", switching to
"Enter Sign in · Esc Back" while typing) and answers a wrong password with "That password didn't
work. Try again." instead of a shake alone. portal-test pins both strings; docs/portal.md records
them and still marks the live check as outstanding (VM only).

### 2026-09-19, eighth round — config export

`feat/conf-export` (`bba578f`, off main): `omarchy-kids-conf export <kid>` prints every effective
setting as `key=value`, resolved override > band > default, omitting password/onboarded; enough to
save or diff a profile, and the safe half of the research-derived export/import item. conf-test
covers the header, effective values, an override winning, and the omission. Import (validated,
all-or-nothing) remains in the backlog, as does the per-app-limits/weekly-caps proposal and
R-ASK-2's owner decision.

### 2026-09-19, ninth round — validated config import

`feat/conf-import` (`9a6e20e`, stacked on `feat/conf-export`): `omarchy-kids-conf import <kid>
<file>` pairs with export — every line is parsed and validated through the schema before the first
write, so a bad file changes nothing, and password/onboarded are refused as system-managed.
conf-test covers a valid apply, an out-of-range value, an unknown key, and a system key. A fable
review of the export/import pair was launched; its findings, if any, are the next step.

The export/import review's findings were all closed in `ac85c3f` (still on `feat/conf-import`):
export now lists only real overrides as live lines with inherited values commented, so a round
trip cannot pin a band default; import validates first, refuses duplicates/system keys/CRLF
hazards, and replaces the profile in one atomic move before the theme side effect and manifest
rebuild run once. The review itself is kept at `docs/reviews/2026-09-19-conf-export-import.md` on
that branch. conf-test green.

### 2026-09-21, integration and UI-bug round

Because every earlier fix lived on its own branch, the fable UI review found `main` still had all
the old defects. The loop merged all 23 topic branches onto **`integration/dogfood-2026-09-19`**
(conflicts resolved once: `.gitignore` unions, CHANGELOG unions, both launcher assertion blocks,
both `docs/time.md` bullets, the panel usage and P4 rows). Then it squashed the review's top bugs:
the Level 1 grid caps its height and clips, the time-left line sits below the clock and the grid
accounts for it, long names elide in the exit/Time's Up cards, Wi-Fi's open-network failure no
longer blames a password, the portal words a missing session or zero accounts, both password
modals treat a verifier outage (exit 2) as "can't check right now" instead of a wrong password,
the Ask done sentence is capitalised and stays 3 s, and the panel says "Changes already made stay"
instead of "nothing changes". Mac suite (with shellcheck installed) is 48/48 before this round;
re-run after.

### 2026-09-21, loop iteration: two-kid-modes SPEC amendment (doc only)

Owner direction: two kid modes, band defaults 3-8 grid / 9+ desktop, parent override, Level 3 as a
parent-only hidden stock desktop. Drafted `docs/phase1/SPEC-AMENDMENT-two-kid-modes.md` with
before/after text for R-DESK-3/4/5, A11, Appendix B.2 and E, and the R-BAND table; storage keeps
the numeric `level` values so no profile migration is needed. A self-review against
`share/bands/bands.toml`, `share/config/schema.toml`, `test/shell.d/levels-test.sh` and
`docs/conf.md` caught one honesty gap in the draft: `menu` is stored but read by no mode today
(`docs/conf.md`:74), so the amendment now says the rename must ship the code that honors the key.
The headless fable review produced no output (0-byte report; re-run later) and left nothing open
that the self-review did not cover. No code changed. Five open questions wait on the owner; the
Level 2 VM pass (owner-supervised) is the next truthfulness gate.

### 2026-09-21, loop iteration: Level 1 legibility and the 540px frame

`fix/launcher-540p-legibility` (`bd5a84a`): short screens (under 640px tall -- the live 960x540
VM) spend 32px on the flat insets instead of 56px, so both tile rows and their focus rings fit;
the "not installed yet" label is 14px (grid) / 16px (picker) at 0.75 opacity over a tile dimmed
to 0.72 instead of 0.55, which the live review found unreadable. The unavailable tile is still
visible, labelled, and skipped by navigation. Launcher tests pass; the full suite was running
when the iteration closed.

### 2026-09-21, loop iteration: docs claim fixed (I-6)

`docs/levels.md` claimed the code "has never run against a real Hyprland or Quickshell"; the
2026-09-21 live pass disproved that for Levels 1 and 2. The page now records what was verified
(grid, navigation, launch, exit modal, portal; desktop layer and windowed picker), what is still
open (two apps side by side, Super+K, the wifi shell), and that the stock desktop stays
unverified. Docs only; found by the I-6 sweep.
### 2026-09-21, loop iteration: Discord kids-repo survey and add-on model (doc only)

Owner asked for a survey of the repos listed in the Omarchy community thread and a first design
for parent-controlled add-ons. `docs/research/2026-09-21-discord-plugin-survey.md` records the
18 harvested links (5 non-repo), per-repo verdicts with licenses, the fold-into-core ideas, the
add-on model (root-owned hash-pinned registry, open surfaces, parent approval at setup, updates
re-approved on surface/exec change), the collisions (school-mode and ok-extras both claim
`/etc/omarchy-kids/...`), and five owner questions. The thread's virtualized scroller would not
yield more links to scripted scrollTop, so coverage is the loaded set. No code changed.

### 2026-09-21, loop iteration: GCompris first-run/config proposal

`docs/gcompris-proposal` (`9d9d26f`): the live review's GCompris findings (first-run welcome
dialog; the app's own wrench and quit) become a proposal with the observed on-disk evidence
(`~/.config/gcompris/gcompris-qt.conf`: `fullscreen=true`, `kiosk=false`,
`exitConfirmation=false`, `[Internal] exeCount`/`lastGCVersionRan`). Recommends a provisioning
seed of that config (convenience in the kid's home, never a lock), gated on one VM run to confirm
`kiosk=true` hides the controls and which state suppresses the welcome dialog. No code.

### 2026-09-21, loop iteration: favorites/recents proposal

`docs/favorites-recents-proposal` (`1c9a1a3`): recents need no new plumbing, since
`data_fold_launches` already promotes the kid's runtime launch log into the root-owned
`/var/lib/omarchy-kids/<kid>/launches.log` with hardened reads. Proposes recents-first manifest
ordering (ordering only; argv and allowlist untouched; bounded, validated, deterministic ties),
defers a Recent row and parent-pinned favorites, and records three owner decisions. No code.

### 2026-09-21, loop iteration: Level 3 menu trim, real format

The live Level 3 pass showed the stock desktop works but the menu offers a kid
Update System and Pending Omarchy Migrations. Reading Omarchy's menu plugin on the VM
established the real mechanism: a user extension at `~/.config/omarchy/extensions/omarchy-menu.jsonc`,
merged by id field-wise (`MenuModel.mergeMenuSources`), hidden with `when: "false"`. The
`fix/level3-menu-trim` commit rewrites `share/menu/omarchy-kids-trimmed.jsonc` to that shape
(install/remove/update/setup) and adds `menu-trimmed-test.sh`; the header's "unverified schema"
warning is gone. Provisioning copies it into a trimmed kid's home next, then the live re-check.
### 2026-09-21, loop iteration: Level 3 no longer runs Omarchy's parent setup

`fix/level3-no-parent-autostart` (`50dcc4e` + the test follow-up): L3.lua required the
`default.hypr.omarchy` umbrella, whose autostart execs `omarchy-provision-first-run`,
power-profile init, udiskie and the post-boot hook on every start -- visible live as the kid's
first-run notifications (Update System, Learn Keybindings, pending migrations). L3 now requires
the stock bindings/envs/looknfeel/input/windows modules directly and runs its own start hook:
the two systemd/dbus imports, then `omarchy-kids-session-start` (which execs
`omarchy-launch-shell` at level 3). `levels-test.sh` keeps the stock-module assertions and adds a
guard that autostart/first-run provisioning can never come back (comments excluded).

### 2026-09-21, loop iteration: the menu trim reaches a kid at last

Stacked on `fix/level3-menu-trim`. `fix/level3-menu-seed`: provisioning gains
`install_kids_menu_trim` (writes the verified omarchy-menu extension into the kid's own
`~/.config/omarchy/extensions/omarchy-menu.jsonc` when the effective `menu` is `trimmed`) and calls
it after the chromium-flags override. A missing shipped file warns and skips instead of failing a
provision (I-6). `provision-test.sh` stages `share/menu/` and asserts the seeded file with its
`when: "false"` rows; provision-test green, menu-trimmed-test green, shellcheck clean. The
follow-up live Level 3 check (menu rows gone, no first-run chatter) is the remaining gate before
Level 3 is offered in the pickers.
### 2026-09-21, loop iteration: unavailable tiles no longer take focus (I-6)

The live passes (fable on Level 1, the Level 2 dogfood) both found the same shape: a tile whose
app is not installed showed its honest label but accepted the focus ring, and Enter on it silently
did nothing. Fixed in `fix/launcher-skip-unavailable` (`ef17b2d`): `gridnav.js` gained
availability-aware stepping plus `firstAvailable()`, `shell.qml` builds the availability array,
opens the picker on the first tile that can act, and passes it to every move. The tile stays
visible and labelled; it is simply skipped. `launcher-grid-test.sh` now asserts the skip cases and
`launcher-desktop-test.sh` supplies the `GridNav` and `tiles` globals its harness had been
getting away without. The Mac suite ran 51 files with no failures (5 environment skips, unchanged).
### 2026-09-21, loop iteration: Level 1 legibility and the 540px frame

`fix/launcher-540p-legibility` (`bd5a84a`): short screens (under 640px tall, the live 960x540 VM)
use 32px margins instead of 56px so both tile rows and their focus rings sit inside the frame
with the flat-inset shape unchanged; the "not installed yet" label is 14px (grid) / 16px (picker)
at 0.75 opacity over a tile dimmed to 0.72 instead of 0.55, which the live review found
unreadable. The unavailable tile is still skipped by navigation. Launcher tests pass; the full
suite was launched in the background at the end of the iteration.

### 2026-09-21, loop iteration: idle pointer hidden (live review)

`fix/hide-idle-cursor` (`87111e3` + the test commit): both L1.lua and L2.lua set
`cursor = { inactive_timeout = 1 }` so a pointer parked on a keyboard-only surface fades after a
second of stillness and returns on movement. The option name, units and "0 for never" default were
verified from the running compositor (`hyprctl -i 0 descriptions`), not guessed; `levels-test.sh`
asserts both files keep it. Docs only otherwise.

### 2026-09-21, loop iteration: the grid fits a short screen (live-verified)

`fix/launcher-height-fit`: the cell is now height-aware (`fitCell`, floored at 96px) instead of
width-only, the tile content (icon slot, fallback initial, labels, spacing) scales with the cell,
and the missing-app caption caps at two lines. Verified live at 875x492: both rows and the
key-hint footer sit inside the frame, nothing clips or overlaps. Known VM-only artifact: app icons
fall back to letter badges because this guest's icon theme lacks the names (happens on the old
build too). Live flow next: launching from the grid on this size.

### 2026-09-21, loop iteration: short-screen tile content fits (live)

`fix/launcher-height-fit` follow-ups: tile content scales with the cell, the missing-app caption
caps at one line, the name drops to one line on short cells, and the tile clips. Live 875x492:
ten tiles in two rows, every label inside its tile, footer clear (screenshot `l1-v5.png`).
Labels elide at this size (five columns of ~118px); the icon badges are the VM's icon-theme
artifact, not the launcher.

### 2026-09-21, loop iteration: Super+Q cannot blank the Level 1 desktop

Live: after the launched app closed, a second Super+Q closed the *launcher* window itself
(`onClosing` refused only in desktop mode), leaving a blank screen with no clients until
Super+Home. Fixed on `fix/launcher-height-fit` (`7e4f133` plus a test assertion): the launcher
refuses a close request in both modes; desktop mode still folds the picker away. Reinstalled and
re-checked live: two Super+Q presses leave the grid up (screenshot `l1-q.png` on the Mac).

### 2026-09-21, loop iteration: Super+Q cannot blank the Level 1 grid

Live finding: with the launched app closed, the launcher is the focused window, so the same
Super+Q a kid uses on an app closed the launcher itself -- blank screen, no clients until
Super+Home. `onClosing` refused the close only in desktop mode; both modes refuse now (desktop
still folds the picker). Verified live: two Super+Q chords, the grid stays (`l1-q.png`).

### 2026-09-21, loop iteration: Level 2 picker at 875x492

Verified live at this size: the L2 desktop hint layer and the windowed searchable picker
("Find an app…", rows, "Not installed yet", the key footer) all fit and read well; the row layout
does not need the height-fit that Level 1's grid did. Screenshot `l2-check.png`. Known trade-off
at this size in Level 1: five columns leave ~98px tiles, so names elide ("GComp…"); the icons are
the primary affordance for the youngest band, and the alternative (four columns) needs three rows
that cannot fit the height.

### 2026-09-21, loop iteration: launch flows verified on the small screen

Level 1: Enter on the grid opened GCompris fullscreen (`l1-app.png`). Level 2: Enter in the
windowed picker did the same (`l2-app.png`). Together with the earlier pass this closes the
875x492 sweep: fit, navigation, launch, close-refusal, both modes; the only VM artifact left is
the icon theme falling back to letter badges (reproduces on the guest's own build).

### 2026-09-21, loop iteration: the parent password field says what it wants

Live review + fix: the exit modal and the Ask modal both showed an empty password field with no
hint whose password was wanted. Both now show a non-interactive "Your password" while empty
(`e944e7d`, `c602a37`); verified live in the VM over a running app (`exit-hint.png`) and in the
Ask modal (`ask-hint.png`, "Ask a grown-up · 15 more minutes of screen time"). While wiring the
Ask assertion, a real test bug surfaced: `ask-test.sh` echoed its RESULT and exited mid-file, so
its grant-time assertions never ran; the result/exit pair is at the end now and they pass
(`350f2c9`).

### 2026-09-21, loop iteration: the Ask request path, end to end

Dogfooded live without the GUI: `omarchy-kids-ask submit time 15` as kid-ada wrote the kid-owned
outbox entry; the ask-collect timer moved it into the root queue (a manual `collect` found 0 left,
`list` showed it); `approve <id> --apply` ran `omarchy-kids-time grant kid-ada 15` and marked the
request approved ("now 75 granted today"). Together with the modal render check this closes
R-ASK-1..3 on the live box: a kid can ask, the root side collects and decides, and the decision
applies through the ledger. `cmd_collect` scans every user's outbox with an owner check, not the
kid-written `kid` field (review S2/S3), which the run confirms.

### 2026-09-21, loop iteration: the time gate and the ledger, live

Dogfooded the time gate on this build: with `budget_min = 1` the kid's session showed Time's Up
and ended (the daemon draws the screen at expiry and enforcement closes the session, so the
overlay is transient by design -- `omarchy-kids-time` has no on-demand show mode). `status`
reported the arithmetic honestly: "199 min used, 0 min left today (budget 60 + 75 granted)" after a
day of dogfooding, and `omarchy-kids-time grant kid-ada 120` (the product path) restored usable
time. The launcher's time-left line is absent at zero remaining, which is by design (the Time's Up
screen replaces it).

### 2026-09-21, loop iteration: a grant shows in status after the daemon's next tick

Live: `omarchy-kids-time grant kid-ada 120` printed "now N granted today", but an immediate
`status` still reported the pre-grant published state ("0 min left today", "budget runs out at
19:29"); about a minute later the daemon's next tick corrected it to "235 min left today (budget
60 + 375 granted), budget runs out at 23:26". `cmd_status` prefers the root-published state file
when it is today's, and the daemon owns that file, so a just-made grant is invisible until the next
tick. Refinement candidate (not done): on grant, either have the daemon re-tick promptly or have
`status` compare the published `last_tick` against the grant file's mtime and fall back to the
ledger math when the grant is newer. Enforcement itself is unaffected -- the daemon recomputes from
the ledger.

### 2026-09-22, loop iteration: three broken doc references

Dogfooded (session healthy; the live check is the box's usual 46 PASS plus its four known FAILs)
and then tried an angle the loop had not: a mechanical link-check over the live docs (`docs/*.md`,
excluding `docs/archive/`) for `docs/*.md` references that do not resolve. It found three:

- `docs/style.md` still pointed at `docs/hyprland-levels.md`, a file that was never created; the
  per-level rationale it describes (including why `default.hypr.envs` is not required) lives in
  `docs/levels.md` today.
- `docs/data.md` glued two paths into one twice (`docs/panel.md/docs/ask.md`,
  `docs/time.md/docs/panel.md`), each reading as a path to a file that does not exist.
- the GCompris proposal offered `docs/packs.md` (never created) or `docs/apps.md`; the pack format
  lives in docs/apps.md.

Fixed on `docs/fix-doc-references`; the live docs now have no unresolved `docs/*.md` reference.
`test/all` green. The archive's own references are historical and were left alone.
