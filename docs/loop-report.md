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

### 2026-09-24, owner-gated merge: the parental-notification workstream

Merged `feat/n5-relayd` into `integration/dogfood-2026-09-19` with the owner's explicit
authorization (merges otherwise stay with the owner's gate). The branch carried the whole N
workstream, the last 197 commits: the notification design amendment (N-0) and N-1 through N-15 --
queue visibility and the `open_requests` badge, the kid's answer, the devices CLI and the authd
`DECIDE`/`REVIEW`/`ACT` frames, the relay and its fence, pairing and the QR, on-demand relay, the
desktop notifier and the bar actions, the away/tailnet path, the review command and timer, the
courier with the sealed envelopes and the mailbox, and the parent app (pairing, the request and
review screens, live feed, notifications, "Recently decided", the keystore seam). Each slice was
specified (fable 5.1 high), implemented, and reviewed (fable 5.1); the review rounds that found
blocking defects were fixed and re-confirmed.

The last slice merged on the branch was R-NOTIFY-6, the kid's own copy of a decision: a root-written
`/var/lib/omarchy-kids/<kid>/decisions/<id>.json` (`0640 root:<kid>` in a `0750 root:<kid>`
directory, the queue record's decision and nothing else -- never `by`, never `device`), written by
`ask.py decide` after the record and healed by `collect`, read by `omarchy-kids-ask outcome` for the
ask overlay's display-only sentence, under a per-kid `decisions` assert lock and the same 90-day
retention as the queue. Its review returned FIX FIRST on six findings; five were real (the overlay's
`trim()` ate the empty reply's tab so a replyless decision showed no sentence; the sentence was not
`Text.PlainText`, so a reply rendered as markup; the "never rewrites a present copy" assertion
compared identical bytes and could not fail; the amendment claimed a `kids_list` gate and
"no error" the code does not have; item 7 claimed tests that did not exist), all fixed, and the
re-review returned MERGE. Two amendment doc-drift follow-ups closed the rest.

Gated before push: `test/all -j 4`, 63 files green, on the merged tree. Integration is at
`41d63d3`, in sync with `origin`.

Still not built (its own worktree, to be specified separately): the app's mailbox view for the away
envelopes -- `clients/parent/lib/relay_client.dart` opens them, no view shows them.

Open owner backlog from the dogfooding notes (to be triaged with the owner): speed, bundled kid
themes, profile-picture choice and previews, the TUI/mascot, the advanced-setup readability, the
number-to-jump keys, themeable login, mouse user selection on the greeter, the simple desktop's
shape, a fast "enter kids mode" and a top-level "remove kids", per-band default docs, the
provisioning hang, kid-made themes, the "open <kid>'s desktop" no-op, blocked out-of-band app
updates, and folding in the community screen-time work (#12488, #11196).
### 2026-09-22, loop iteration: the schema the Level 3 decision was waiting on

Dogfooded first -- the parent-exit fence this time: `Super+Shift+K` opened the exit modal (Ada's
avatar, the masked password field, "Finish for Ada" with "Closes Ada's apps. You return to the
login screen.") and `Esc` put the desktop back untouched. No finding there, so the iteration went
to the SPEC amendment's outstanding verification: it says Level 3 must stay hidden "until its
menu-trim extension and binds are verified on a real box", and the owner's own question 3 asks for
exactly that check.

Two things had to be separated: what `docs/levels.md` still claims, and what the *amendment* rests
on. The first is already handled -- `fix/levels-live-status` (a branch at the gate) rewrites the
live-status paragraph, the file table's row and item 6, and several other branches correct the rest
of that page, so this iteration did not touch it a second time.

The amendment itself no branch updates, and its premise is stale in a way that matters: the
menu-trim format is not a guess. Read on the box's Omarchy 4.0.2: `parseMenuJsonc` strips the JSONC
comments and turns a map keyed by id into items, `mergeMenuSources` merges stock and user files by
id with the user winning, `evaluateGuards` hides an item whose `when:` is false, and the four ids
the extension trims (`setup`, `install`, `remove`, `update`) are top-level keys in the stock menu
at lines 23-26. The live Level 3 pass already recorded the menu showing only Apps/Learn/Trigger/
Style/About. The "sudo path" worry resolves the same way: `omarchy-sudo-passwordless` is not a
keybind at all, it is the menu row `setup.security.passwordless-sudo` under the `setup` id this
extension hides, and the command would fail for a kid anyway (the live check refuses `sudo -n true`
for kid-ada); the real risk behind the item -- the umbrella autostart's
`omarchy-provision-first-run` -- is gone, since `fix/level3-no-parent-autostart` requires the stock
modules individually and the kid's journal shows no such line.

So the amendment now carries a dated "Level 3's verification status (2026-09-22)" section, its
`Why` bullet and verification bullet say what is now true instead of what was true when drafted,
and question 5's "until the menu-extension check passes" is marked as passed -- leaving the owner a
preference question about the 13+ band rather than a verification gate. Two thin items stay open and
are named there: whether stock ever bound `SUPER + RETURN`, and `hl.unbind`'s exact signature.

While citing the box, one thing did not check out: the image's own version file reads
`4.0.0.alpha` and the menu plugin is owned by `try-omarchy-runtime 4.0.3-1`, where the repo's
evidence lines say "try-omarchy VM, Omarchy 4.0.2". The 4.0.2 is the upstream release the research
compares against, not this image's build string, so the two are being conflated in every
"confirmed against Omarchy 4.0.2" line. The note and the jsonc header now name both; a sweep of the
rest is left for the owner or a later iteration (it touches a dozen files and several branches
already edit the same lines).
### 2026-09-22, loop iteration: the Level 2 Super+K cheat sheet does nothing

Dogfooded a flow the loop had not: at Level 2 (kid-ada, session healthy), `Super+K` -- Appendix E's
"cheat sheet" bind -- does nothing. Live diagnosis in the kid's session:
`omarchy-menu-keybindings` prints `OMARCHY_PATH is not set` and exits, and its interactive mode is
`omarchy-shell shell summon`, which by its own usage needs the Omarchy shell "already running;
this command does not start it". A Level 2 session runs the kids launcher, not that shell (only
Level 3's start hook execs `omarchy-launch-shell`), so the bind is inert at Level 2;
`omarchy-menu-keybindings --print` does work and prints the live binds as text, but there is no kid
surface to show it. Fixed the claims, not the bind, on `docs/levels-l2-cheat-sheet-inert`:
`L2.lua`'s comment and `docs/levels.md` (live-status paragraph, Level 2 description, and the
manual-verification step) now say the cheat sheet is inert at Level 2, note Level 3's works, and
record a kid-side cheat sheet as the open decision. The fable review caught one blocking scope
error -- an earlier draft doubted the Level 3 dogfood result on a false premise (`omarchy-shell` is
also what `omarchy-launch-shell` runs) -- and it was corrected. `test/all` green, `shellcheck`
untouched (Lua/docs only). Appendix E still mandates the bind, so it stays and the gap is recorded
for the owner; this is the one I-6/spec tension the loop has hit, noted rather than resolved.

(The earlier "actionable backlog is exhausted" entry stands for everything else the loop can reach
without the owner.)

### 2026-09-22, loop iteration: two apps side by side, verified at last

Dogfooded the next behaviour `docs/levels.md` still listed as open: launched Blinken and KTuberling
from the Level 2 picker, and `hyprctl clients` shows them tiled 446x496 each at 960x540 (Appendix
E's 50/50 dwindle split with the stock gaps; neither self-fullscreens), with `Super+Shift+Left`
swapping them (KTuberling 22,22 -> 492,22, Blinken the other way). That closes the "two apps open
side by side" item the 2026-09-21 pass had to leave uncaptured. No code changed -- the behaviour
was already right -- so the fix is the record: `docs/levels.md` no longer lists it as open, and the
dated dogfood report gets the follow-up. `test/all` green. Branch
`docs/levels-two-apps-verified`, stacked on `docs/levels-l2-cheat-sheet-inert` (both edit
`docs/levels.md`). The kid's time was granted 30 min afterwards to keep the box usable.
### 2026-09-22, loop iteration: the Ask modal's app, plugin and site kinds render (live)

`docs/ask.md` item 1 asked for the non-`time` kinds to be opened from a kid session; only `time`
was recorded as opened live (2026-09-02). On the try-omarchy VM, `omarchy-kids-ask app gcompris`,
`omarchy-kids-ask plugin kstars` and `omarchy-kids-ask site pbskids.org` each opened the modal over
the Level 2 desktop with the right kid-words line -- `the app "gcompris"`, `the plugin "kstars"`,
`the website "pbskids.org"` -- the focused password field, both choices and the key footer, at the
same size as the `time` card. Evidence `ask-kind-app-2026-09-22.png`, `-plugin-`, `-site-` in
`.local/media/`. The descriptions are built in `bin/omarchy-kids-ask`'s own
`cmd_app`/`cmd_plugin`/`cmd_site`, so this closes the render question those had left.

One wording note, not a defect: an app's description is its raw id (`the app "gcompris"`), and the
plugins shelf asks with `item.id` (`share/plugins/shell.qml:85`), so a shelf id that is not already
a readable app name would reach the kid verbatim. Whether that happens needs a real synced
marketplace index; there is none to judge from here.
### 2026-09-22, loop iteration: dogfood, the I-6 sweep, and the Ask "Ask later" path live

Dogfood: kid-ada logged in at Level 2 (the day's budget topped up), the desktop hint layer and
"NNN minutes left" rendered, Super+Space opened the windowed picker, the list scrolled a clipped row
into view, and Enter launched Blinken fullscreen. No defect.

The I-6 sweep over `share/` and `lib/` found no new safe code change. The two real candidates it
surfaced -- the `dns` and `sites` wizard choices that are stored and never applied -- are already
carried by `fix/dns-control-honesty` and `fix/garden-sources-agree` and recorded as open owner
decisions (`docs/phase1/DECISIONS-NEEDED.md` item 7); the ask and exit modals' missing key hints are
`fix/modal-key-hints`; and the ask modal's "Asked." wording is R-ASK-1's exact text, not an
overclaim. Nothing else in the two trees showed a control without an enforcement behind it.

Closed `docs/ask.md`'s two remaining open items on the try-omarchy VM. The modal's own "Ask later"
button (Right/Tab to the second choice, Enter) shows "Asked. Your grown-up will see it." and writes
one outbox record, `{"kind":"time","minutes":15,"state":"open"}`; Escape closes the modal with the
outbox and the root queue unchanged -- nothing written. Evidence `ask-later-sent-2026-09-22.png` and
`ask-modal-2026-09-22.png` in `.local/media/`. The installed modal carried `fix/modal-key-hints`'
footer, so the footer and the Left/Right handlers were exercised too; the `submit` and `closeModal`
functions are identical in the union. (`docs/ask.md`'s own text is reconciled on the unmerged
`14f47a3`, which still lists these two as open; this entry is the record until that branch merges.)
Still open: the app/plugin/site kinds, the wrong-password lockout, and the password -> authd ->
`apply-grant` path end to end.
### 2026-09-22, loop iteration: the Ask modal's wrong-password hint and lockout (live)

`docs/ask.md` item 3 was the one live check left that did not need a kind to be installed. Typing a
wrong password into the modal three times as kid-ada on the try-omarchy VM showed "That wasn't it."
after the first two misses, then on the third turned the field red and showed "Too many tries. Try
again in 30 seconds." -- the modal's own `wrongCount` lockout, and `omarchy-kids-authd`'s
`RateLimiter` behind it (three misses -> 30 s, ten -> 5 min, per peer uid and decayed, so it locks
the kid's own uid and never the parent's account). Evidence `ask-wrong-hint-2026-09-22.png` and
`ask-wrong-lockout-2026-09-22.png` in `.local/media/`. The exit modal shares this code path
(`docs/exit.md`); the shake is an animation a still cannot show.

Still open in `docs/ask.md`: item 2's app/plugin/site grants end to end, which needs a real
installed app/plugin/site and is not a read-only check.
### 2026-09-22, loop iteration: the bar's request badge cannot read the queue (needs a decision)

Live, as the parent `omini-test` (uid 1000) on the try-omarchy VM: both `/usr/bin/omarchy-kids-ask
list` and `/usr/bin/omarchy-kids --requests` die with "omarchy-kids-ask: list: root only" (exit 1).
That is exactly what the parent's bar widget runs: `share/bar/KidsModule.qml:112` polls
`omarchy-kids-ask list` every 30 s and counts its stdout lines, so its open-request badge is always
0, and the "Open requests" menu row (`KidsModule.qml:185`) runs `omarchy-kids --requests`, whose
error output the widget discards. Both are shown controls that cannot do what they claim (I-6), on
a surface `docs/bar.md:218-245` already lists as never exercised live.

Cause: the 2026-09-03 security fix (`60496dc`, "Require root at every ask review entry point") added
`is_root || die "list: root only" 1` at `bin/omarchy-kids-ask:469`; the widget and `--requests`
were written against the earlier unprivileged read. But the queue is world-readable by design
today -- `lib/ask.py:135` chmods each record 0644, the directory is 0755, and the parent's panel
reads it unprivileged (`lib/panel-requests.sh:44`, and `bin/omarchy-kids-panel:243-245`'s
`count_open_requests` via `ask.py list-open`). So the guard blocks the bar while not blocking the
panel, or anyone who can `cat` the files.

This is a request-visibility decision, not a patch to make quietly, so no code changed. Options:
1. Publish the open-request count in the root-written `/run/omarchy-kids/status.json` (0640
   root:`omarchy-parents`, which the widget already reads) and let the badge use that; keep `list`
   root-only.
2. Have `omarchy-kids --requests` (and so the badge) read the queue the way the panel already does,
   leaving `list` root-only -- consistent with the panel, but any local user of the parent command
   sees requests, which they already can via the 0644 files.
3. Tighten the queue to 0640 root:`omarchy-parents` and route the panel and the bar through a
   parent-group read, which is the only option that makes the root guard a real boundary.
### 2026-09-22, loop iteration: the exit modal's wrong-password lockout and Esc (live)

`docs/exit.md`'s "Not yet exercised live" named the exit modal's wrong-password shake/lockout and
Esc to close. On the try-omarchy VM, `Super+Shift+K` opened the modal (the bind delivers, "Ada",
"Finish for Ada", the key footer); a wrong password showed "That wasn't it."; the third miss turned
the field red and showed "Too many tries. Try again in 30 seconds." with the key footer hidden
while locked (the shared code's `visible: !root.locked`); and Esc closed the modal with the kid's
Hyprland still running -- nothing written, no finish. Same limiter scoping as the Ask modal: the
modal's own `wrongCount` plus authd's per-uid `RateLimiter`, the kid's uid only. Evidence
`exit-wrong-hint-2026-09-22.png`, `exit-wrong-lockout-2026-09-22.png` in `.local/media/`.

Still open in `docs/exit.md`: the parent password on a kid's tile at the portal (#15's PAM line),
which starts a parent session and so is not a loop check.
### 2026-09-22, loop iteration: the loop has nothing left it can reach (state)

The three "next work" items the union's `PROGRESS.md` named are done: the I-6 sweep, the Ask modal's
submit keys and the Time's Up screen, and the portal after a kid exits. The sweep re-found only
defects already carried by in-flight branches, so the union is a stale base rather than a source of
new work -- e.g. the portal footer advertises `← → Choose` and `Ctrl+Shift+P Power off`
unconditionally, which `fix/portal-key-hints` gates (not in the union); the ask/exit modal key hints
are `fix/modal-key-hints`; `dns`/`sites` are `fix/dns-control-honesty`/`fix/garden-sources-agree`.
57 remote branches (154 commits) sit ahead of `integration/dogfood-2026-09-19`.

What this loop added and cannot finish itself: the bar's open-request badge and its "Open requests"
row run the root-only `list` from the parent's unprivileged session -- recorded on
`docs/loop-bar-requests-finding`, since the union here does not carry that entry. The fix is a
request-visibility decision, not a patch.

*(Correction, 2026-09-26: `docs/loop-bar-requests-finding` never landed in the union, so that
citation dangles. The finding is settled -- the count moved into `status.json` and
`omarchy-kids-ask list` now admits `omarchy-parents` members -- see
`docs/phase1/DECISIONS-NEEDED.md` row 8 and `docs/bar.md`.)* Everything else waits on the owner's decisions
(`docs/phase1/DECISIONS-NEEDED.md`, latest on `docs/decisions-loop-2026-09-22`), the merge gate, or
an owner-run live session. Until one of those moves, a further pass should not open more branches.
### 2026-09-22, loop iteration: the notification workstream begins (N-0 .. N-3a)

The owner reviewed every open decision and directed the parental-notification build. Source design:
`docs/research/2026-09-22-parental-notifications.md` (a headless `claude-fable-5-1` run). Repo
default workflow is now in `AGENTS.md`: fable 5.1 (high) writes specs and reviews, DS4.1 flash
implements. The Matt Pocock engineering skills are installed (`~/.agents/skills` for opencode,
`~/.claude/skills` for claude-code) and `/setup-matt-pocock-skills` was run for this repo
(`docs/agents/`). Landed so far, each implemented then reviewed by fable 5.1:

- **N-0** the R-NOTIFY spec amendment: `SPEC.md` I-2 amended (paired device / parent-named server,
  only when notifications are on), the R-NOTIFY-1..12 section, R-BAR-3's count, Appendix D's
  `device`/`reply`, a new Appendix H, and `docs/phase1/SPEC-AMENDMENT-notifications.md`.
- **N-1** the request queue is the parent's: `0750 root:omarchy-parents`, records `0640`,
  `omarchy-kids-ask list` reads by permission, the ledger publishes `open_requests`/`requests` into
  `status.json`, the bar badge reads it, and `assert` re-asserts the queue lock. The review caught a
  blocking regression (records written `root:root`, so the parent's panel read nothing).
- **N-2** the kid sees the answer: root writes `<kid>/decisions/<id>.json` (`0640 root:<kid>`),
  `omarchy-kids-ask watch` shows `share/ask/decided.qml` for an unseen decision, `lib/ask.py decide
  --reply` is validated, and retention prunes the store. The review caught a card that could wedge
  `watch` and a logout-replays-history bug.
- **N-3a** the root-owned device registry `bin/omarchy-kids-devices` (add/list/rename/scopes/revoke/
  publish, validated, atomic, root-only) with `devices-test.sh`.

Also landed: the merge-gate conflict map (`docs/branch-conflict-map-2026-09-22.md`) and the
`merge=union` gitattribute for `docs/loop-report.md`.

**Next: N-3b** — authd's `PAIR`/`DECIDE`/`ACT` frames, Ed25519 verification through
`python-cryptography`, the nonce ledger, `approve --by device:<id>`, and the assert/check rows.
Planning fact: `python-cryptography` is present on neither the Mac nor the dogfood VM, so its crypto
tests will skip locally the way authd's `libcrypt` checks already do; the dependency ships in N-4's
PKGBUILD and a real run follows on a box that has it.
### 2026-09-22, loop iteration: a removal "gap" that is a recorded decision (no change)

Reviewing `omarchy-kids-remove` against everything provisioning writes turned up one asymmetry: the
`pam_namespace` marker + `session required pam_namespace.so` line that `lib/provision-add.sh` adds
to `/etc/pam.d/sddm`, `systemd-user` and `sddm-autologin` (and `omarchy-kids-assert` re-asserts) has
no counterpart in the removal plan, so it survives Remove Kids Mode.

It is not an oversight. `docs/remove.md:160-167` records it as deliberate: the line is inert once no
account has a matching `namespace.conf` entry, the removal task's own checklist never named it, and
it waits on "R-FND-2a's owner" to confirm it should be reversed. A fix was written
(`posture_remove_pam_namespace`, three `pam-namespace:<stack>` plan steps) and its tests passed, then
discarded -- reversing a documented decision is the owner's call, not a loop's. The next sweep that
reaches this asymmetry should stop at `docs/remove.md`.
### 2026-09-22, loop iteration: the bar's "End session" path and the portal after a kid exits (live)

Two items the docs list as unverified are now proven live on the try-omarchy VM, with no defect.

- `omarchy-kids-exit --finish --kid kid-ada` -- the root path `omarchy-kids-bar end` runs under sudo
  (`docs/bar.md:237-243`, item 5, and `docs/exit.md`'s own open items). It exited 0, found the kid's
  Hyprland instance under `/run/user/1001/hypr/<signature>/`, dispatched `hl.dsp.exit()` through
  `runuser`, and the kid's Hyprland and quickshell were gone. The clean path worked, so the
  `loginctl terminate-user` fallback was not exercised.
- The portal after a kid exits (union `PROGRESS.md`'s "next work"). The kid autologin drop-in was
  removed first, so SDDM would not re-autologin the kid on the restart. After the finish, SDDM was
  alive and had started `sddm-greeter-qt6 --theme /usr/share/sddm/themes/omarchy-kids`; the journal
  is clean (no "Process crashed"), and the greeter shows both tiles -- the kid's fox "Ada" and the
  parent's "Omini-test" (`portal-after-exit-2026-09-22.png` in `.local/media/`). This is the
  "Process crashed" black screen `docs/exit.md`'s Verified-live section was written to prevent, not
  reproduced.

A capture note for the next pass: QEMU's QMP `screendump` comes back all black for the X11 greeter
(the greeter's plane is not in the virtual framebuffer that QEMU reads), so the portal shot was
taken inside the guest with `import -window root` on the greeter's own X display (as the `sddm`
user, with the greeter's `/tmp/xauth_*`). The kid's Wayland sessions capture fine with `grim`
(that is the recipe's method) and are unaffected.

### 2026-09-22, loop iteration: the Wi-Fi picker overlay has run live

Dogfooded the one surface `docs/wifi.md` still called unrun: with `wifi=helper` (the VM has no
wireless device), `Super+Shift+W` reached Hyprland and opened `share/wifi/shell.qml` under a real
Quickshell over the Level 2 tiled windows -- the overlay drew, the `omarchy-kids-wifi list` Process
ran and its stdout was read back (empty), the "No networks found" empty state rendered with "Try
again" focused and "Enter try again · Esc close" in the footer, Enter re-ran the list (still empty,
no error), and Esc closed the process; the profile was set back to `parent`. So the doc's "this has
never run against a real Quickshell" was stale. The fix moves those device-free paths under
"Verified live" and leaves only the network-dependent parts (the populated list, the password step,
the join outcomes) open, with the same update in `docs/levels.md`'s live-status. Docs only, no
code; `test/all` green. Branch `docs/wifi-picker-verified`, stacked on
`docs/levels-two-apps-verified` (both edit `docs/levels.md`).

Also this iteration: the Level 2 "More apps" shelf renders its empty state honestly over the tiled
windows, and a full read of `share/wifi/shell.qml` found its join/refusal messages and the
`nmcli -t` colon-parse limitation exactly as `docs/wifi.md` already records them.
### 2026-09-22, loop iteration: the GCompris check the owner's approval waited on

Dogfooded first (Level 2 healthy, 94 min left, clean journal, `omarchy-kids-check --live` at 49
PASS / 1 FAIL / 3 WARN -- only `firmware:password`, a physical step). The backlog's live-UI item
ends with the GCompris first-run finding, and the proposal for it had been approved on 2026-09-21
with exactly one thing outstanding: a live check of what `kiosk=true` hides and what suppresses the
welcome dialog. That check is this iteration.

Reset `kid-ada`'s config and re-seeded it between launches on the aarch64 VM (gcompris-qt 26.1-1),
launching each time through our own picker:

- No config: "Welcome to GCompris! ... for the first time" with a red X.
- Config without `[Internal] lastGCVersionRan`: a "GCompris has been updated!" changelog, then a
  "Some activities have new dataset available" prompt with Apply/Cancel.
- Seeded with `fullscreen=true`, `kiosk=true` and `lastGCVersionRan=260100`: no dialog at all.

So the marker is the version key (the app's own encoding, `major*10000+minor*100+patch`), not the
run counter; `kiosk=true` removes the power/quit button, the wrench and the menu, leaving home,
help, the favourites hint and search; `Super+Q` still closed the app with a modal up, so its chrome
cannot trap a kid; and the app merged our two keys with its own on first run (`exeCount` rose). The
check also corrected the finding's premise: those dialogs are **not** red-X-only -- Escape cleared
the welcome and the changelog, Tab then Enter cleared the dataset prompt, so they are nuisances a
kid can keyboard past, not mouse-only traps.

With the check done and the owner's approval in hand, the seeding shipped on this branch:
`install_kids_gcompris_config` + `gcompris_version_number` in `bin/omarchy-kids-provision`, called
by `lib/provision-add.sh` like the menu trim, writing the kid's config kid-owned 0644 and **never
rewriting one the app has already written**; when the packaged version cannot be read it seeds
without the marker and says so rather than guessing. `docs/apps.md` states it is configuration, not
a lock, and `docs/research/2026-09-21-gcompris-first-run-and-config-proposal.md` now carries the
results table and the status change.

Verified: `provision-test.sh` asserts the seeded file's content, mode and kid ownership (a `chown`
stub, so the ownership is checked rather than attempted) plus the leave-alone path, and each new
assertion was mutation-checked -- dropping the existing-file guard, `kiosk=true`, or the marker
fails its own check and names it. Two of those assertions passed vacuously on the first two tries
(a fourth add reshuffled the test's exact-content checks, and the account got slugged to
`kid-ben-2`); both are now real, and the skip-path block runs last with its own boot-mode fixture.
The suite is green, and the VM's GCompris config is back to exactly what it was before the check.

The independent review then blocked the first shape of the writer, and it was right twice. Root was
writing through a path a kid could have replaced -- `[[ -e ]]` passes over a *dangling* symlink, and
`remove --keep-home` plus re-adding the same account leaves a home a Level 3 kid has had a shell in,
which is rule 9's exact shape; the writer now refuses a symlink at either directory or the file and
stages-then-renames (rename(2) replaces a link instead of following it), and the test plants a link
to prove nothing is written through it. And the directory was being created root:root, which would
have stopped Qt's QSettings from ever writing its lock and temp file beside the config -- the app
would have kept showing its "has been updated" screen after every upgrade. The file *and* both
directories are now handed to the kid (`install_kids_chromium_flags` had the same root-owned
`.config` gap when it creates one, fixed alongside), and the test pins the three-path `chown`. Two
smaller review findings are closed too: the arithmetic now forces decimal (`10#`), so a version like
26.08 cannot abort a provision halfway, and the warning and `docs/apps.md` no longer claim the
version marker is what suppresses the *welcome* dialog -- the check's own table shows the config
existing is what does that, and the marker is what suppresses the post-upgrade changelog.

A second review round found that the one-line directory chown added to
`install_kids_chromium_flags` had reintroduced the same shape there (a chown dereferences a symlinked
`~/.config`), so the guard became one shared helper and then, better, one preflight in `cmd_add`:
`kid_home_writable_paths` is the single list of what `add` writes into a kid's home, and the add
refuses -- before creating anything, exit 2, naming the path -- when any of them is a symlink. That
covers the writers the test's own plant-a-link case exposed beyond the two this branch touched (the
menu trim and the migration marker had the same exposure, and it is pre-existing rather than
introduced here). The symlink is a deliberate bypass shape, so the reproduction lives in the
untracked private area (`.local/recovery/FINDING-2026-09-22-kid-home-link-PRIVATE.md`) rather than in
this report, per `SECURITY.md`; the mitigation is on this branch, and the owner may want a private
advisory for the window before it merges.
### 2026-09-22, loop iteration: the Safe-search DNS choice does nothing

Dogfooded the box's unit health this time, since a broken daemon is invisible in a session
screenshot: `systemctl --failed` is empty, `authd` and `wifid` are running, both sockets are
active, and both timers are waiting. That led to a cadence sweep of the units' own claims, which is
clean -- the time timer's 30s matches `docs/time.md`, `omarchy-kids-time-ledger`'s header and its
`--help`, and the ask timer's one minute matches its Description. (The *box's* installed ledger copy
said "once a minute" -- it is an older package build, the usual dogfood mix, and the union's copy is
right.)

Then the I-6 pass went after the config schema: all 21 keys in `share/config/schema.toml` are
documented in `docs/conf.md`, and the three "extra" keys my check flagged are file or machine-level
names rather than profile keys. Clean at the mention level -- but not at the *applied* level. The
`dns` key is stored and never read by anything that affects a kid: the wizard records it, and
`omarchy-kids-web render` reads only the band's `web` mode, so the rendered Chromium policy always
carries the template's Cloudflare family resolver. Two parent-facing choices therefore promise an
effect they cannot deliver -- "CleanBrowsing Family | A second safe-search DNS provider" and "Type
my own" -- which is exactly what I-6 forbids.

Fix on `fix/dns-control-honesty`: those two descriptions now say they are stored for now while the
policy still uses Cloudflare (the Cloudflare row's description was already true of the effective
state), and `docs/conf.md`'s `dns` row carries the same note, next to the pointer to
`share/policy/README.md`, which has said "not wired into `omarchy-kids-web` yet" all along. Wiring
it properly is not a loop-sized call: the policy file is per band while the key is per kid, so a
per-kid override cannot be expressed in it at all. That question -- wire it band-level and say so,
or drop the control -- goes on the owner's decision list as item 7.

One operator lesson, recorded because it cost a stray write: `omarchy-kids-conf set` has no
dry-run. `DRY_RUN=1 omarchy-kids-conf set kid-ada dns ...` *writes*. The value was restored to the
band default immediately and has no effect either way, but the loop's habit of prefixing writers
with `DRY_RUN=1` does not hold for this command.
### 2026-09-22, loop iteration: the packaging fix the handoff called merged was not

Dogfooded first (session healthy at Level 2, Blinken and KTuberling tiled 50/50, clean journal,
timer toasts the only session-log lines); the live pass found nothing new, so the iteration went to
the backlog's first actionable item, the packaging fixes. Checking whether they were really in the
union turned up the opposite of the handoff: `PROGRESS.md` calls `PKGBUILD arch=('any')` and the
fresh-install ordering "merged", but `integration/dogfood-2026-09-19` still pins `arch=('x86_64')`,
its two units have no optional-path allowance, and its assert exits 1 on a box with no boot mode and
no kid -- so the pacman hook would abort a clean install and the aarch64 dogfood VM cannot build the
package from the union at all. All of it lives only on `fix/install-packaging`, which is based 150
commits back and would delete newer work if merged as-is. Re-landed the four changes on the current
tip (`fix/fresh-install-ordering`): `arch=('any')`, `StateDirectory`/`ConfigurationDirectory` so the
socket-activated authd starts and can write on a box that has never had those directories,
`-` on the `ReadWritePaths` entries, the `docs/install.md` clone path, and `.SRCINFO`'s arch. Two
fable review rounds blocked it first: the first for the assert's early exit 0 (it made the `units`
row, the no-kids notice and two exit-code sentences false, and skipped the machine-level lock issue
#46 exists for -- fixed by falling through to the existing no-kids branch so `units` still runs and
decides the exit code), for a running authd that could not write `/var/lib` on a fresh box, and for
`.SRCINFO`; the second found the same EROFS trap surviving on the `/etc/omarchy-kids` bind (the
wizard's A2 password check starts authd before Apply). Every new assertion was mutation-checked:
reverting the assert fix fails five, and dropping `ConfigurationDirectory`, either `StateDirectory`
or either `-` fails the pkgbuild pins. Suite green (52 files, five environment skips).

Live-verified on the VM, since the fresh-box case itself cannot be reproduced there (its
directories already exist): a transient unit carrying the same `StateDirectory`/
`ConfigurationDirectory`/`ProtectSystem=strict` properties created both directories as
`drwxr-xr-x root root` and wrote inside them, which is the mechanism the fix depends on; both unit
files pass `systemd-analyze verify` on the box's systemd 261; and the reworked assert installed from
this branch still exits 0 (`--quiet` and plain) with `kid-ada` present, repairing the same locks it
did before. `PROGRESS.md` on this branch no longer claims the packaging work is merged.

Recorded for the owner: `fix/install-packaging` is superseded by this branch and should not be
merged as-is; the same "merged" correction was also made on `fix/stale-threshold-name`, where the
sentence and the branch count were wrong too.

### 2026-09-22, loop iteration: Level 1 re-verified, and the package actually built

Dogfooded first, and this time on Level 1, which the loop had not exercised since the short-screen
fixes: set `kid-ada` to level 1, restarted the session through the documented autologin drop-in, and
the grid came up at 960x540 (`L1.lua present and verifies`, five columns, both rows inside the
frame, focus ring on the first tile, footer reading only the keys Level 1 has). The live check is
now 49 PASS / 1 FAIL / 3 WARN -- the three install-history FAILs cleared when the re-landed assert
repaired the locks, leaving only `firmware:password`, a step no software can do.

Two things came out of that screen. First, a cursor was parked on it, which looked like the merged
"hide the idle pointer" fix failing; it was the guest's own stale config: `/etc/omarchy-kids/
hyprland/L1.lua` was the old package copy with no `cursor = { inactive_timeout = 1 }`, and after
installing the union's L1/L2 and reloading, `hyprctl getoption cursor:inactive_timeout` reports
`1.000000, set: true` and the pointer is gone -- the fix is real on the compositor, and the lesson
is that Level 1 evidence needs the config installed from the branch exactly as Level 2 and 3 do.
Second, a finding for the owner: at 960x540 the tile labels elide to one line with a 18px font, so
"SuperTux" and "SuperTuxKart" both render as "Super...", and `GCompris`, `KTuberling`, `KLettres`,
`Kanagram` truncate the same way. The tiles are still distinguishable by icon on a box with an icon
theme -- this guest has none, so every tile shows a letter initial -- but the label is the fallback
identifier and it is ambiguous in exactly the case a kid cannot read the icon. Making it fit means
a layout or typography trade-off (wider cells, a smaller label, or two lines for names that cannot
word-wrap), which is the owner's call, not the loop's; recorded here rather than changed.

Then the backlog's packaging item got the verification it had never had. The aarch64 dogfood VM
cannot install from the union (that is why the fix exists), but it can build: a clean checkout of
this branch, `makepkg -d -f` as the parent user, no install. It built, and the PKGBUILD's own
post-substitution greps passed -- arch `any` in `.PKGINFO`, `SCHEMA="/usr/share/omarchy-kids/
config/schema.toml"` inside `usr/bin/omarchy-kids-conf`, `KIDS_PY=/usr/bin/python3` inside
`usr/lib/omarchy-kids/kids.sh`, 27 commands, 38 lib files, 77 data files, 13 units, both initcpio
files, the 0644 pacman hook, the `.INSTALL` scriptlet, twelve avatars and a `KidsTheme.qml` beside
each of the six standalone surfaces. That build also falsified something this branch's own docs
said: the artifact is not `...pkg.tar.zst` as a property of our package, it is whatever the build
box's `PKGEXT` says -- this guest is `.pkg.tar.xz`. `docs/packaging.md` now names the stock-Arch
example and says the extension is the machine's.

Still open (recorded for the owner): installing a built package on the test VM (`pacman -U`), which
needs a real box and is the remaining half of that doc's own item.

### 2026-09-22, loop iteration: the lock that caught the loop's own install

Dogfooded first, and the app-launch flow this time: from the Level 2 picker, two arrow presses and
Enter put Blinken on screen (verified with `ps -u kid-ada`), then `omarchy-kids-check --live` came
back with **two** FAILs where the box has had one for days. The new one was
`lock:hyprland-configs`, and it was the loop's own doing, not a defect: for the cursor verification
two iterations ago I installed the union's `L1.lua`/`L2.lua` into `/etc/omarchy-kids/hyprland/`
(the copy the session reads) and left `/usr/share/omarchy-kids/hyprland/` — the package's copy and
the lock's source of truth — at the stale versions. The check reporting that drift is the lock
working exactly as `docs/assert.md` describes; the recovery it names (`omarchy-kids-assert`)
restores `/etc` *from* `/usr/share`, which would have put the stale configs back.

Fixed by making both copies the union's (all five files now compare equal, and the box is back to
49 PASS / 1 FAIL / 3 WARN), and the recipe now says so: install a config into both copies, not just
the one the session reads.

The iteration's other half came out of trying to do it the *proper* way — rebuild and reinstall the
package — which is the packaging branch's own remaining "install it on the test VM" item. It is
blocked on that box, and the reasons are worth having written down: the union cannot be built on
aarch64 at all while `arch=('x86_64')` is unmerged (`makepkg` refuses it, which is why the guest's
files were hand-copied in the first place), and `pacman -U` of a fresh build then stops on
`conflicting files: /usr/lib/omarchy-kids/panel-machine.sh exists in filesystem` because the
installed package predates files later hand-copied from branches. `docs/packaging.md`'s open item
now records all of it, including that the `hyprland-configs` alarm is the check doing its job.
### 2026-09-22, loop iteration: two sources for the garden, and the keys nothing reads

Dogfooded the parent's data view this time: `omarchy-kids-data launches/sites/summary kid-ada` and
the kid's own `mine`. The record matches the loop's actual activity to the minute (chromium at
10:49, blinken at 09:52, gcompris three times around 08:00), and `sites` was empty only because the
browser checks so far had used a scratch profile or hit the block page -- so the Web tile was driven
to an allowlisted site, pbskids.org, which loaded normally and then appeared as `pbskids.org -- PBS
KIDS` in `sites` and in `summary`'s top sites. The garden's positive path works, and the evidence
trail is honest. (Two observations, neither a defect: Chromium shows its own "Install" affordance on
such a page -- the installed app stays under the same policy and never reaches the kid's root-owned
manifest; and `sites` prints one line per visit row, so a host with a redirect shows twice, which is
what docs/data.md says it does.)

Then the I-6 pass took the schema question one level deeper: not just "is every settable key
documented" (it is, `docs/conf.md` and `share/config/schema.toml` agree on all 21) but "does
anything read it". Most do -- and the sweep found the ones that don't and the reason a text-based
test cannot be written for it: the two heavy consumers read keys through a *variable*
(`lib/time.sh`'s `key=budget_min`, `lib/session-manifest.sh`'s `get "$account" "$key"`), so no grep
can tell a read from a name in a string. The honest conclusion is stated in the branch: a test was
drafted, found unsound for that reason, and dropped rather than shipped as false confidence.

What the sweep did produce: the band's starter garden is written in two files with no generator
between them, and they had drifted -- `share/packs/6-8.toml`'s `[garden].sites` listed three hosts
while `share/policy/lists/6-8.txt`, which is what `omarchy-kids-web render` turns into the live
URLAllowlist, allowed six (9-12: five against seven). The pack's own comment said those hosts "become
the URLAllowlist", which was simply not true. Both packs are now aligned up to the live list (no
site lost), the comment says which file the policy actually renders, and every `sites`-adjacent
surface now says the key is stored and not applied: `docs/conf.md`'s row, and the wizard's editor
prompt. A new test, `test/shell.d/garden-lists-test.sh`, compares the two lists per band so they
cannot drift quietly again (it fails on a one-line difference; 3-5 stays empty and 13+ is excluded
because SPEC R-WEB-3 says a filtered band adds no URL list, which its file says itself).

`apps.show_missing` also surfaced: the union lost its only reader (the box runs
`fix/show-missing-regression`, which restores it), so a missing app's tile is no longer omitted by
default. That branch is at the gate; nothing here duplicates it.
### 2026-09-22, loop iteration: the L2 idle-pointer rule was set twice

Dogfooded the VM first: kid-ada at Level 2, session healthy; opened the picker, launched Blinken
with Enter, and closed it with Super+Q -- all correct, and the launcher's time-left line showed
the earlier grant ("18 minutes left"). Then the I-6 pass over `share/` (the shelf's "never run
against a real Quickshell" claim is already corrected on `fix/plugins-shelf-field-shift`, so
nothing to redo there) found `share/hyprland/L2.lua` setting `cursor = { inactive_timeout = 1 }`
twice under two overlapping comments -- a stale merge -- with `test/shell.d/levels-test.sh`
asserting the L1/L2 rule twice to match. It is behaviour-neutral (same key, same value) but reads
like a botched merge in a root-owned level config. Fixed on `fix/l2-duplicate-cursor-rule`: one
call, one comment, one pair of assertions, plus a count guard over comment-stripped files that
fails (`got 2`) if the duplicate returns. `levels-test.sh` green (guard verified against a
reintroduced duplicate), `test/all` green (52 files, five skips), `shellcheck -x` clean, fable
review nothing blocking.

Live on the VM: installed `/etc/omarchy-kids/hyprland/L2.lua` from the branch and restarted the
kid session through SDDM; `omarchy-kids-session` reported `L2.lua present and verifies` and the
Level 2 desktop came up with `omarchy-kids-check --live` green except the expected
`firmware:password`. The kid's time had run out during the restart, so enforcement entered
`finishing` and ended that session; `grant kid-ada 60` returned the state to `allowed` and the
kid logged back in (58 minutes left). Two operator notes: a `sudo tee` with a heredoc swallowed
the piped password and repeated attempts tripped the guest's `pam_faillock` (locked the parent
account ~10 minutes, cleared on its own -- `.local/VM-DOGFOOD.md` now says never to combine
`sudo -S` with a heredoc), and the per-boot autologin drop-in was removed by hand because the
cleanup unit did not fire on a manual `systemctl restart sddm`. The VM was left with the kid
session up, no drop-in, and only the VM-only `firmware:password` FAIL.
### 2026-09-22, loop iteration: the modals that never said which keys work

Dogfooded the Ask modal this time -- a core kid surface the loop had never seen rendered. Drove it
exactly as the launcher and the Time's Up card do (`omarchy-kids-ask time 15` as the kid) and it
renders well: "Ask a grown-up", the request line ("15 more minutes of screen time"), the masked
password field, and the two choices side by side with "A grown-up is here" preselected, as the
standing decision requires.

What it showed: that card, and the exit modal, were the only kid-facing surfaces **with no key
hint**. The portal ("Enter Sign in · Esc Back"), the picker ("↑ ↓ Choose Enter Open Esc Back"), the
Wi-Fi picker, the plugins shelf and the launcher all name their keys; a kid facing two choices had
no way to learn that Tab moved between them, and had to guess that Enter confirms and Escape leaves
without asking. I-5 says every screen works with no pointer *and* that the keys are discoverable,
not memorized.

Fixed on `fix/modal-key-hints`: both modals carry a footer in the same style as the others -- the
ask card's says "← → Choose · Enter Ask · Esc Never mind" and the exit card's "Enter Finish · Esc
Back" -- and the ask modal now also answers Left/Right, since its two choices sit side by side and
every other kid surface's arrows select. Each footer hides while the field is locked out (Enter is
inert then, and the error line above already explains the wait).

Verified live, both installed from the worktree: the ask card shows its footer and a Right press
moves the ring from "A grown-up is here" to "Ask later"; Escape leaves with `omarchy-kids-ask list`
reporting no open requests (the hint's "Never mind" is true); the exit card shows its footer under
"Finish for Ada". `ask-test.sh` gained the key-handler and hint assertions and a header that says
what it actually checks (it had called the file UNTESTED while checking three things about it),
`exit-modal-test.sh` the footer; dropping the arrows or either footer fails them. Suite green.

Operator note: the first install was botched -- both files are named `shell.qml`, so one `scp` to
`/tmp` left only the exit modal and installing that into both directories opened the ask as a
squashed exit card. The recipe now warns about it.
### 2026-09-22, loop iteration: a reset the panel promised would keep your sites

Dogfooded the VM first (kid-ada at Level 2, session healthy; `omarchy-kids-check --live` at its
usual 46 PASS plus the four known drift FAILs this box always shows). The I-6 pass then moved into
`lib/`, which earlier iterations had swept less: the parent panel's "Reset to band defaults" card
told the parent their "password, theme and any sites you added by hand stay" -- but `sites` is
`reset = "clear"` in `share/config/schema.toml` and `cmd_reset` deletes every clear key, so a reset
really does delete hand-added sites (along with `dns`, `history_visible`, `menu` and the apps
keys). Fixed on `fix/panel-reset-claims`: the facts block now says every other screen's settings go
back to the band's defaults and names hand-added sites among them, the function comment and
`CHANGELOG.md` are corrected, and `conf`'s `reset` usage line gains the missing `theme`.
`panel-test.sh`'s real reset fixture now carries `sites=` and `theme=` and proves the code deletes
one and keeps the other; `test/all` green (52 files, five skips), `shellcheck -x` clean, fable
review one major (the changelog claim, now fixed) and three minors closed. This supersedes the
Reset-card wording quoted in the earlier 2026-09 entry below.

Live on the VM: installed `bin/omarchy-kids-conf` and `lib/panel-kid.sh` from the branch and ran
the panel's own file-mode harness (`OMARCHY_KIDS_TUI_ANSWERS` + `--dry-run`) as the parent; on real
gum the reset card rendered "Every other screen for this kid goes back to the band's defaults ...
Any sites you added by hand go back too. The account, name, face, band, password and theme stay.",
and the false claim is gone. Substrate note: a bare `bin/omarchy-kids-conf` from a branch does not
work installed as-is -- the PKGBUILD rewrites its `SCHEMA` seam (and `lib/kids.sh`'s `KIDS_PY`), so
the same `sed` ran before `install` (an unrewritten copy looks for
`/usr/share/config/schema.toml` and breaks every conf read). The kid session stayed up and
`omarchy-kids-check --live` still shows only this box's four known FAILs.
### 2026-09-22, loop iteration: the picker sliced the desktop's hint line

Dogfooded the VM first (kid-ada at Level 2, session healthy; `omarchy-kids-check --live` at its
usual 46 PASS plus this box's four known FAILs). The I-6 pass over `lib/`, the wizard and the SDDM
portal found nothing to fix -- and several claims that check out -- so the iteration took a live
cosmetic defect instead: with the app picker open at 960x540 (and 875x492), the centred picker
window's bottom edge sliced the desktop layer's own "Super + Q: Close app · Super + Shift + K:
Grown-up exit" line into broken half-glyphs. Fixed on `fix/picker-slices-desktop-hint`: the desktop
takes `pickerOpen` and hides that line while the picker covers it (the picker shows its own footer,
and Super+Q folds the picker away rather than closing an app, so the hidden line was the less
honest one to keep). `launcher-grid-test.sh` pins the flag, the pass-through, and the binding's own
target -- a targeted grep that fails if the binding moves onto another `Text`; `test/all` green (52
files, five skips), `shellcheck -x` clean, fable review nothing blocking (its two test minors
closed).

Live: installed `shell.qml` and `Desktop.qml` from the branch and restarted the kid session through
SDDM; with the picker open the crop under its border is clean background where the sliced glyphs
were, and closing it brings the hint line back intact. The session came back Level 2 with the
autologin drop-in removed by hand (the cleanup unit does not fire on a manual restart).

Checked-and-clean this iteration, no change needed: `bin/omarchy-kids-data`'s usage matches its
dispatch; the wizard's `filtered` web label ("Adult content blocked, safe search on") matches the
13+ policy (family DoH + forced SafeSearch + YouTube strict, no URL blocklist, as `docs/web.md`
says); the SDDM portal's Ctrl+Shift+P power chord is really bound; the panel's reset, home,
requests and machine cards are honest.

### 2026-09-22, loop iteration: the actionable backlog is exhausted

Dogfooded the VM first: kid-ada at Level 2, session healthy, `omarchy-kids-check --live` green plus
this box's four known drift FAILs, and `omarchy-kids-session --manifest` correct (tiles = the
installed allowlist apps + Web + More apps, with the right labels and argv; the uninstalled
`tuxpaint` is absent because `apps.show_missing` is off).

Swept the last unread surfaces without finding a defect worth a branch: the wizard's Advanced
screen (its DNS, history, sites, level and Wi-Fi labels all match what the code enforces), the
panel Machine card, the check report's own ids and details (honest; its FAILs are this box's drift),
the desktop entries and the systemd unit descriptions. One nit not worth a change: the Machine card
says "checks needing root report as warnings", which also covers the live section the report
actually *skips*.

Every remaining backlog item now needs the owner or hardware: the SPEC amendment (drafted, five
questions), the GCompris first-run dialog and its wrench (a packaging proposal), packaging (on
`fix/install-packaging`), Level 2 owner-supervised verification, favorites/recents (an owner
decision), W2's fail-open decision, and the Level 3 menu-trim verification on a real Omarchy box.
The loop's own branches -- 27 ahead of integration -- carry every safe fix found; further passes
would re-sweep what has been swept or manufacture changes. Stopping on the stop condition ("a
change needs a human decision"): the next move is the owner's gate.
### 2026-09-22, loop iteration: the portal's footer named keys that do not act

Dogfooded first: the Level 2 session is healthy (133 min left, Blinken and KTuberling tiled), and a
real Super+Space / Esc round trip brought the picker up and dismissed it, with the tile list
scrolling to keep the selection visible and uninstalled tiles skipped in navigation -- so the live
pass found nothing new and the iteration went to the I-6 pass over the kid surfaces. That pass had
one real finding left: `share/sddm-theme/Main.qml`'s footer advertised three keys unconditionally,
while the arrow handlers only move between tiles (with one tile nothing happens), Enter only signs
in when a tile exists (with none the file shows a "no accounts" line), and SDDM may refuse
power-off, which the chord's own handler already checks. The footer now comes from a `keyHelpText()`
that offers each hint only behind the condition that makes it act; with nothing to name the line is
empty. No new key is advertised, and the password-mode pair (`Enter Sign in · Esc Back`) is
unchanged.

Verified: `test/shell.d/portal-test.sh` extracts the function and asserts each hint sits behind its
own guard, that the footer actually calls it, and that each hint phrase occurs nowhere outside it --
mutation-checked three ways, including the partial regression a review pointed out (restore the
hardcoded footer, leave the function as dead code), which the first version of the check missed; a
failing stub `qmllint` fails the test and a passing one passes; the VM's Qt6 `qmllint` (6.11.2)
parses the file with rc 0, one more "Unqualified access" warning than before (`sddm` is a context
property, the same class as the 92 it already had); the suite is green (52 files, six skipped
checks -- the new qmllint one is the sixth on a box without Qt). The portal itself still cannot be
rendered on the dogfood VM (try-omarchy logs its owner in at the image level), which is why the
syntax check exists.

Recorded for the owner: the greeter's live pass (`docs/portal.md`, 2026-09-02) kept the old fixed
footer string as its record; that paragraph now names 2026-09-22 and says which case it describes.
### 2026-09-21, loop iteration: apps.show_missing was dead; restored (live)

Live Level 2 picker: `Super+Space` still showed "Tux Paint / Not installed yet" while
`omarchy-kids-conf show kid-ada` reported `apps.show_missing no`, which docs/conf.md and
docs/levels.md say must omit the tile entirely. `git log -S show_missing` shows the read lived in
`bin/omarchy-kids-session-start` (#42, `c93e89a`) and the manifest refactor (`38f878e`) moved tile
building to `lib/launcher-map.sh` without it, so every missing tile shipped regardless. Fixed on
`fix/show-missing-regression` (`f96d4f0`): `launcher_map_render` reads the effective
`apps.show_missing` and omits a missing pack app's tile unless it is `yes` (one stderr line per
omission), keeping the `yes` case (`installed:false`, no argv); the unknown-extra-id error is
unchanged. `session-manifest-test.sh` asserts omission at the default and the kept tile under `yes`;
the full Mac suite is 52 files green (5 environment skips) and the fable review returned MERGE.
Live re-verified after installing the branch's `lib/launcher-map.sh` into the VM and rebuilding the
manifest: with `no` the picker shows GCompris then KTuberling (Tux Paint gone); the `yes` rebuild
keeps `tuxpaint installed=false`, the `no` rebuild returns zero tuxpaint tiles. Docs
(conf/levels/apps) now say what the code does, including that the queue-based `"installing..."`
caption the same refactor dropped is not implemented.

Process note: this iteration collided with a second loop driver -- the headless `opencode-loopd`
was still serving its own session in this checkout while the TUI `/loop` job ran here; the other
session restarted the kid's SDDM session mid-pass (it set the budget to trigger Time's Up). The
owner chose to stop loopd and keep this session. Do not run `/loop` and `opencode-loopd` against
this repo at once.
### 2026-09-22, loop iteration: the tiles a kid could not tell apart

Dogfooded Level 1 this time (the loop has sat at Level 2 for many rounds): switched the box to
`level 1`, restarted through the documented drop-in, and the grid came up at 960x540 with the clock,
the time-left line, no idle cursor and the right footer. It also showed the thing five rounds of
Level 2 dogfooding never could: the tile labels were truncated to the point of uselessness --
"GComp...", "KTube...", "KLett...", "Kanag...", "More ..." and, worst, **two tiles both reading
"Super..."** (SuperTux and SuperTuxKart). The label is the only identifier on a tile here: this
guest has no icon theme, so every tile is a letter initial, and a six-year-old looking for SuperTux
sees two identical tiles.

The cause was a fixed label box: `width: parent.parent.width - 16`, i.e. the tile minus a 16px
inset, so the text had less room than the tile did and ordinary names elided. The fix is the same
box derived from what it should be -- the name's own width, capped by what the cell can hold
(`Math.min(implicitWidth, grid.cellWidth - 28)`; the tile is `cellWidth - 20`, so -28 keeps the text
inside it) -- applied to both the name and the "not installed yet" caption.

Verified live on that frame by applying the same two lines to the installed copy (which carries a
topic branch's picker fix, so a whole-file install would have dropped it) and restarting the
session: **GCompris**, Blinken, **KLettres**, **Kanagram** and **SuperTux** now read in full, the
longest two keep a distinguishable elision ("KTuber...", "SuperT..."), and "More apps" reads
"More a..." instead of "More ...". `test/shell.d/launcher-grid-test.sh` pins the derivation, that
both labels use it, and that the fixed inset box is gone; reverting the QML fails all three
assertions. Suite green.
### 2026-09-22, loop iteration: a bad conf read, two opaque lines, and a fail-open edge

Dogfooded the VM first and hit a live case: an earlier install of a bare `bin/omarchy-kids-conf`
(before the PKGBUILD's `SCHEMA` sed) made the root ledger tick fail from 01:49 to 01:50 with
`conf.py: no such file: /usr/share/config/schema.toml` and
`/usr/lib/omarchy-kids/time.sh: line 81: 10#: invalid integer constant`. The second came from an
empty lights-out reaching `time_minutes_since_midnight`'s base-10 arithmetic; the kid's session
briefly showed Time's Up and then self-dismissed when the tick succeeded again after the conf was
fixed (the grant file's mtime never changed -- no grant happened, the log's "more time granted"
wording is the daemon's generic dismissal line). Fixed the diagnostics on
`fix/time-read-diagnostics`: `time_conf` names a failed read, and
`time_minutes_since_midnight` refuses a non-HH:MM value with a sentence (same pattern as
`validate_lights_out`), both leaving every valid input and every enforcement decision untouched.
`test/all` green (52 files, five skips), `shellcheck -x` clean; fable review nothing blocking, and
its one behaviour-changing suggestion (a `[[ -z ]]` branch in `time_conf`, which would have turned
an empty budget from fail-closed into a stale-state fail-open) was dropped.

The review also confirmed the deeper gap: a persistently broken conf aborts the tick before it
writes state, so the last published state stays in force and `time:timer` only proves the timer is
active. That fail-open window is already on record as ticket W2
(`docs/research/2026-09-19-per-app-limits-and-weekly-caps-proposal.md`) and is now written into
`docs/time.md` too; it needs the owner's W2 decision, not a unilateral enforcement change.
### 2026-09-22, loop iteration: a fresh grant shows in status at once

Dogfooded the VM first (kid-ada at Level 2, session healthy, `omarchy-kids-check --live` all PASS
except the expected `firmware:password` on a VM), then took the refinement the 2026-09-21 "a grant
shows in status after the daemon's next tick" entry had left open. `omarchy-kids-time status` now
keeps the published document only while it is also newer than today's grant file, so a grant a
parent just made counts at once instead of showing "0 min left" (or an old boundary) until the
root ledger tick's next pass. The document is not rewritten and enforcement is unchanged: the root
tick still recomputes from the ledger and acts. `time-test.sh` covers the three states (fresh
document, a grant newer than the tick, a tick since the grant) and fails without the guard;
`test/all` green (52 files, five environment skips), `shellcheck -x` clean, and the fable reviewer
found nothing blocking (six minors closed). Branch `fix/time-status-fresh-grant`.

Live on the VM after installing `/usr/bin/omarchy-kids-time` and `/usr/lib/omarchy-kids/time.sh`
from the branch (never the integration copies): status read the fresh published document ("7 min
left", boundary 01:00); a root `grant kid-ada 10` made the grant file newer than the document
(00:53:08 vs 00:53:02), and the very next status counted it at once ("18 min left", boundary
01:11) instead of holding the pre-grant 7 until the next pass. The kid session stayed up and
healthy.
### 2026-09-22, loop iteration: the Time's Up card names the key that asks

Live: the Time's Up card (login at 15:41 with the day's budget spent) had one action and a
pointer-clickable button, but no key hint -- unlike the portal, the app picker, the Wi-Fi picker,
the plugins shelf and the exit/Ask modals, every one of which names its key (I-5). The card is up
only for its countdown, so a kid who cannot find Enter loses the one thing the screen offers
(`c09637a`): a centred "Enter Ask a grown-up" line under the button. The `FocusScope` already
handled Return/Enter; `time-test.sh` now pins the hint and both handlers, which is what stops the
wording and the handlers drifting apart.

The prior iteration was cut off here, so the pass was re-run: installed the branch `timesup.qml`,
granted to about two minutes of remaining so the budget would expire on a fresh session, logged the
kid in, and waited for a real `grace` state to appear and the daemon's next 30 s poll to launch the
overlay (a grab at the ledger tick catches the desktop instead -- the daemon is a separate poller).
The branch card renders "Enter Ask a grown-up" centred under the Ask button and fits the console;
evidence `timesup-keyhint-2026-09-22.png` in `.local/media/`. The autologin drop-in was removed
after the pass and the owner's session is back on the console.
### 2026-09-22, loop iteration: the toast icon belonged to another message

Dogfooded the VM first: kid-ada at Level 2; pressed `Super+Shift+W` (the kid Wi-Fi bind) with the
Wi-Fi setting `parent`, and got the refusal toast -- but beside "Wi-Fi needs a grown-up" it wore
the time warning's alarm clock. `share/time/toast.qml`, shared with `omarchy-kids-wifi`, hardcoded
⏰. Fixed on `fix/toast-icon-match`: the overlay reads `OMARCHY_KIDS_TOAST_ICON` (default ⏰), the
time command exports ⏰, and the wifi command exports the Wi-Fi bars 📶. The value is display-only
(it reaches a QML `Text`, never code or a check), so it joins `OMARCHY_KIDS_TOAST_TEXT` on the
trust-boundary allowlist with that why. `wifi-test.sh` gained a Quickshell stub that pins the glyph
and the whole message, `time-test.sh`'s stub now logs the icon so the clock stays pinned,
`test/all` green (52 files, five skips), `shellcheck -x` clean, fable review nothing blocking
(three minors closed, including the overlay's own stale header). Live: installed the three files
from the branch and pressed `Super+Shift+W` again -- the refusal toast now shows the Wi-Fi bars
(rendered, not tofu) where the clock used to be. The ⏰ default is unchanged and pinned by the time
tests (and the clock toast was live-verified in earlier iterations).
### 2026-09-22, loop iteration: a component-set skew, found live on the panel

Dogfooded the parent panel's remaining Kid screens live (Home, the Kid row menu, Screen time,
Wi-Fi, Apps, Data). The **Wi-Fi screen rendered "Mode: " blank**, with
`/usr/lib/omarchy-kids/panel-kid.sh: line 92: friendly_wifi_mode: command not found` in its output.
Not a repo defect: the repo's panel sources `lib/kids.sh`, which defines `friendly_wifi_mode`
(line 523) -- but the VM had version skew, because an earlier iteration installed
`lib/panel-kid.sh` from a branch without the matching `lib/kids.sh` (whose installed copy predates
that function). Repaired the VM by backing up the old file and installing integration's
`lib/kids.sh` with the PKGBUILD's `KIDS_PY` sed; the Wi-Fi screen now shows "Mode: Ask me first"
and the Apps screen its Plugins shelf row. Added `test/shell.d/panel-test.sh`'s first assertion on
that label (it fails when `friendly_wifi_mode` is stubbed to echo the raw value) and sharpened the
untracked `.local/VM-DOGFOOD.md` with the `panel-*.sh` -> `kids.sh` pairing. `test/all` green.
Branch `test/panel-wifi-mode-label` (a test-only pin; no product change).

Found honest along the way: the Data screen's sudo prompt appears once and falls back cleanly when
it cannot (the desktop entry is `Terminal=true`, so the real path has a tty), and the Kid, Screen
time and Apps screens' facts and rows are accurate.

### 2026-09-22, loop iteration: dogfood round, nothing to fix

Dogfooded the parent panel's remaining screens live (Web, Desktop, and the theme picker it opens)
and re-ran `omarchy-kids-check --live`. All honest: the Web screen says "Editable list: no -- this
mode has no allow list" for a non-garden mode and lists the kid's own sites for garden; the Desktop
screen shows the level and theme; the theme picker offers exactly the six system themes and exits on
Esc, as its footer says. The live check is the box's usual 46 PASS plus its four known FAILs
(band-group, groups, the `lock:hyprland-configs` my L2.lua install invalidated, firmware:password).

Also read two libs not yet swept. `lib/theme.sh`'s `$OMARCHY_PATH` handling is the documented
issue-#48 design (`docs/theming.md`), and the same variable being unset in a kid session is what the
Level 2 cheat-sheet finding turned on. `lib/session-manifest.sh` renders the launcher's manifest to
a stage in the root-owned manifest dir, schema-validates it, chowns it root:root 0644, publishes it
atomically, and re-validates it when served, so the `mktemp` is never a kid-writable path into the
kid's tile argv -- the "root-validated manifest" is real, not a comment.

Nothing actionable this round. The loop's remaining work is the owner's gate: 32 branches ahead of
integration, the SPEC amendment, the GCompris proposal, packaging, Level 2 verification,
favorites/recents and W2.

Branch note: this record first landed on `test/panel-wifi-mode-label` by mistake (`git checkout -b`
aborted because `docs/loop-report.md` differed, so the commit stayed on the current branch); it was
moved to its own branch with `git branch` + `git update-ref` (no reset), which left it stacked on
that branch rather than on integration. It is a docs-only record, so the stack is harmless.

### 2026-09-22, loop iteration: the backlog is fully drafted; a gate picture

Dogfooded: the Level 2 focus bind works (`Super+Right` moved focus from Blinken to KTuberling; the
swap bind was checked earlier), and `omarchy-kids-check --live` is the box's usual 46 PASS plus its
four known FAILs. Read `bin/omarchy-kids-bar`: `grant`/`end` build the terminal command with
`printf '%q '`, so a kid name cannot inject a shell command, and both go through the stock
`omarchy-launch-floating-terminal-with-presentation` with the parent's own sudo prompt.

The backlog's remaining items are now all drafted rather than buildable without an owner decision,
so this round records the state for the gate (it supersedes the 20-branch picture in
`docs/loop-merge-readiness`):

- 33 branches ahead of `integration/dogfood-2026-09-19`, each test-green on its own.
- 420 of their pairs conflict on nothing but the append-only `PROGRESS.md`/`docs/loop-report.md` --
  a keep-both resolution every time.
- 12 pairs have a real-file conflict: `docs/levels.md` (7), `docs/time.md` (2), `docs/wifi.md` (1),
  `share/launcher/shell.qml` (2).
- Awaiting an owner decision: the two-kid-modes SPEC amendment (five questions), the GCompris
  pre-seed, the add-on survey (five questions), favorites/recents (three decisions), W2's fail-open,
  Level 3's `Super+Shift+F` under `menu=trimmed`. Live-only work: the real-box menu trim, the
  laptop's Wi-Fi join/captive portal, a band-3-5 kid, the portal's wrong-password path.

### 2026-09-22, loop iteration: third clean round

Dogfooded the Level 2 session (the picker opens and closes, the two windows still tile) and
finished the I-6 pass over the kid-facing commands: `bin/omarchy-kids-web`'s `launch` is sound -- it
refuses to start Chromium unless the band's managed policy file is readable (R-WEB-4, fail closed),
execs an argv array rather than a shell string, and takes its flags from the policy conf. Nothing
else actionable: three consecutive rounds have found only the component-skew repair (VM state) and
the gate picture, and every backlog item now needs an owner decision or hardware. Worth pausing the
loop or pointing it at the owner's decisions instead of more sweeps.

### 2026-09-22, loop iteration: backlog check and merge-readiness

Dogfood: re-ran `omarchy-kids-exit --finish --kid kid-ada` as root (no password needed) -- the kid's
session ended and the SDDM portal came up with its two tiles ("kids=1 parents=1"), re-confirming
the `--finish --kid` path `docs/exit.md` already marks verified (2026-09-03). Re-logged the kid in.

Backlog check: the remaining items need the owner. Item 1 (two-kid-modes SPEC amendment) is drafted
and awaiting review; item 2's safe live-UI defects are fixed, and the rest (the GCompris first-run
dialog and its wrench) are proposals needing a packaging decision; item 3 lives on
`fix/install-packaging`; item 4 (Level 2 verification) is owner-supervised; item 5
(favorites/recents) is an owner-decision proposal; item 6's I-6 sweep is now down to design choices
(the toast's short-screen placement) rather than defects. The live-unverified surfaces that remain
need a real parent password (the portal after an exit) or hardware (a wifi join; a band-3-5 kid).

Merge-readiness (for the owner's gate): the ~20 topic branches ahead of integration conflict
heavily on the two append-only state files -- `PROGRESS.md` and `docs/loop-report.md` -- because
each appends its own entry at the same tail; those are trivial "keep both" resolutions. Two
real-file conflicts also exist and want a look: `docs/levels.md` between the older
`docs/levels-live-status` and `fix/levels-live-status`, and `share/launcher/shell.qml` between the
older `fix/launcher-insets-simplify` and `fix/launcher-time-left-refresh`. Everything else
auto-merges (tested branch-by-branch with `git merge-tree`). No code changed this iteration.

### 2026-09-21, loop iteration: docs/apps.md described runtime files that no longer exist

Dogfooded the Web path on the VM: `omarchy-kids-web launch` opened Chromium and navigating to
`example.com` showed Chromium's "This page is blocked", so the garden policy (URLBlocklist `*` plus
the band's starter allowlist) is enforced live; the non-live safety report showed only the known
drift. An I-6 sweep then found a substantive stale section in `docs/apps.md`: it described a
runtime `launcher-<uid>.json` (display-only, ridden against the root map) and a
`$RUN/allowlist.json` that `bin/omarchy-kids-session-start` "writes unconditionally" at Levels 2/3.
The manifest refactor (`38f878e`) removed both -- `session-start-test.sh` and `levels-test.sh`
assert neither is created -- because the manifest carries the tiles' fixed argv and the effective
allowlist, and the launcher executes the manifest. Fixed on `fix/apps-docs-manifest` (`0088383`,
stacked on `fix/show-missing-regression` so the tile-list pointer lands on the already-fixed
`docs/levels.md`/`docs/conf.md`): both passages rewritten, the "session-start calls allowlist for
the runtime JSON" sentence corrected, the queue-caption claim corrected (no launcher surface reads
the apps queue; a missing tile reads only "not installed yet"), and `lib/launcher-map.sh`'s stale
"the kid's runtime JSON is display-only" header comment fixed. fable review MERGE after four rounds
trimming overclaims (chiefly the queue/`apps.show_missing` wording, resolved by stacking on the
enforcement branch). Docs plus one comment.
### 2026-09-21, loop iteration: the Ask doc said the modal had never run (docs)

Dogfooded Level 1 on the VM: the grid renders at 875x492, two arrow presses moved the ring, Enter
launched Blinken (the launch log recorded it), and Super+Q closed it leaving the grid up (no blank
screen). Re-confirmed the wifi picker's `parent`-mode refusal toast. No code defect. The iteration
took an I-6 docs finding: `docs/ask.md` said `share/ask/shell.qml` "has not itself been run against
a real Quickshell", which its own "Verified live (2026-09-02)" section contradicted, and that run
described the outbox-`approved` flow the 2026-09-03 security fix removed. Fixed on
`fix/ask-docs-live-status` (`14f47a3`): the modal has run -- 2026-09-02 render/input, 2026-09-03 the
current `grant`/authd/`apply-grant` path (both in the QEMU test VM), and 2026-09-21 the CLI `submit`
+ collect-timer path on try-omarchy -- and the open items are the app/plugin/site kinds, the
wrong-password lockout, the modal's own "Ask later" button and Esc. The fable review took three
rounds, each cutting a claim the base branch's record did not support (the earlier sessions' modal
and panel live runs are recorded only on branches not yet merged); MERGE. Docs only.

Recorded so it is not lost: across these loop sessions the Ask modal's own keyboard path ("Ask
later" via Tab+Enter, then collect and `decline --apply`), the modal's `app` kind (`the app
"noage"` from the plugins shelf), and the parent panel's Home/kid/Data/Web/Apps/Desktop/Screen time
screens were all exercised live on the try-omarchy VM, but those checks live in the loop entries on
`fix/plugins-shelf-field-shift` and the panel branches, not on integration. When those merge,
`docs/ask.md`'s and `docs/install.md`'s open lists can be narrowed.
### 2026-09-21, loop iteration: a non-time request lost its asked_at (live)

Live: `omarchy-kids-ask submit app tuxpaint` as kid-ada, `collect --apply`, then `list` showed the
app request with a **blank ASKED_AT** column. Cause: `lib/ask.py` `list-open` emits tab-separated
rows and leaves `minutes` empty for a non-time (app/plugin/site) request, and both readers
(`omarchy-kids-ask list`, `lib/panel-requests.sh`) parse with `while IFS=$'\t' read` -- tab is IFS
whitespace, so bash collapsed the empty field and shifted `asked_at` into `minutes`. The panel then
coerced the blank to 0 and rendered "20700d ago". Fixed on `fix/ask-list-empty-minutes-shift`
(`4ee6a53`): rows are US (0x1f) separated (a non-whitespace byte, so empty fields survive) with
0x1f/CR/LF stripped from values so a kid-authored field cannot forge one; both readers use
`IFS=$'\x1f'`. `ask-test.sh` lists a non-time request and asserts its timestamp, `panel-test.sh`
asserts a `site` request's row shows a real ("just now") age, docs/ask.md documents the row format
and docs/panel.md no longer calls it tab-separated. Full Mac suite 52 files green; fable review
MERGE after the docs and panel-test fixes. Live re-verified from the branch: the queued app request
listed `ASKED_AT 1790036919`; declined it afterwards.

Same class, found the same pass, not yet fixed (next iteration): `bin/omarchy-kids-session-start:69`
reads the manifest's 10 `@tsv` fields into 9 variables, so the 10th (`allowlist`) is absorbed into
`OMARCHY_KIDS_LIGHTS_OUT_WEEKEND`; and a kid with no theme override (`theme=""`, valid per the
manifest and docs/theming.md) shifts every field (THEME="garden", WEB="60", BUDGET_MIN_WEEKEND=19:30,
...). The non-empty guard still passes, so the session starts with corrupted values -- silent only
because nothing reads those six exported vars yet -- but it would fail closed if the last field were
ever empty. `session-start-test.sh` asserts the env values but covers neither the missing variable
nor an empty theme. `bin/omarchy-kids-data`'s browse rows (`read -r t host title visits`) can hit
the same empty-field shift when a page has no title.
### 2026-09-21, loop iteration: a portal box's parent-only slot map is not a kid slot (live)

Dogfooding the Level 2 picker, then `omarchy-kids-check --live` (the loop recipe's own flow), turned
up a real FAIL on a correctly-provisioned portal box: `boot:no-kid-luks-slots` failed although the
wizard's Apply had run `omarchy-kids-conf machine set parent`, which by design (docs/boot.md step 5,
docs/conf.md) writes the parent's own `0=<parent>` line to `/etc/omarchy-kids/luks-slots`. The check
failed on the file's mere existence. Its own test fixture already used a kid entry (`1=kid-ada`) as
the residue that must fail, so the intent was "no kid slot", not "no file". Fixed on
`fix/boot-no-kid-luks-slots` (`cbf2697`): `boot_check_no_kid_luks_slots` now fails only on a non-`0`
entry (`luks_slots_kid_entries`), and WARNs as cannot-verify on an existing but unreadable file (a
non-root run against the root 0600 map) rather than passing it -- the fail-open the fable review
caught in round one. `check-test.sh` pins the parent-only pass and the unreadable WARN; docs/check.md
updated. Full Mac suite 52 files green; live-verified by installing the branch's `lib/check-boot.sh`
into the VM from the branch and re-running `omarchy-kids-check --live`: `boot:no-kid-luks-slots` now
PASSes ("maps only the parent's own slot; no kid slot is recorded").

The other `--live` FAILs on the dogfood box are drift, not repo defects and left alone: the manual
`usermod -aG input,video kid-ada` (the provisioner sets exactly omarchy-kids plus the band group),
a stale `/etc/omarchy-kids/hyprland` predating the branch's configs, and the firmware-password gate
that a VM cannot satisfy. `omarchy-kids-assert` in the guest would reconcile the first two.
### 2026-09-22, loop iteration: unreadable files were reading as false FAILs

Dogfooded the parent panel live on the VM for the first time (its own answers-file harness). Its
Machine screen called `pam:parent-unlock:sddm`, `pam:faillock-order:sddm` and `web:doh:6-8` FAIL --
"the parent-unlock line is missing from /etc/pam.d/sddm", "does not set DnsOverHttpsMode: secure" --
all three false: the panel runs unprivileged, `/etc/pam.d/sddm` is 0600 root and the web policy is
0640 `root:omarchy-kids-6-8`, so the checks could not read the files at all. The Machine card's own
promise is "checks needing root report as warnings", and `account:no-sudo`/`boot:no-kid-luks-slots`
already WARN correctly, so this was a straight I-6 breach. Fixed on `fix/check-unreadable-warns`:
each now WARNs "cannot verify: <file> is not readable here", and `lock:polkit-admin`,
`lock:polkit-deny` and `lock:accountsservice:<kid>` got the same guard through `lock_check`'s own
exit-2 convention (their dirs are 0755 here so they still PASS, but a 0750/0700 box would have
shown the same false FAIL). `check-test.sh` chmod-000s the fixtures and asserts each id warns;
every new assertion fails with its guard reverted. `test/all` green, `shellcheck -x` clean; the
fable review found two majors (the root-skip guarded on `id -u`, which this suite's PATH stubs, and
the Locks-section conflation it pushed me to fix defensively) and a minor (mode restore), all
closed.

Live: installed the three libs from the branch and re-ran the panel as the parent -- the Machine
card went from "NOT READY -- 7 check(s) failing" to "4", the remaining four all genuine (the box's
band-group/groups drift, the `lock:hyprland-configs` my earlier L2.lua install invalidated, and
`firmware:password`), and the three now read "cannot verify: ... is not readable here".

Operator note: completing that install needed a second ~11-minute wait on the guest's
`pam_faillock` (the install loop's first attempt failed and each retry reset the window); the VM was
left with the branch libs installed, the kid session up, and the box's four known FAILs.
### 2026-09-21, loop iteration: a browse row with no title shifted its visit count (live)

Fixed the same class flagged last iteration in `bin/omarchy-kids-data`: `lib/data.py
chromium-visits` prints `LOCAL_TIME<TAB>host<TAB>title<TAB>visit_count` and a page can have no
title (`title or ""`), so `read -r t host title visits` with a tab IFS collapsed the empty field --
the title column showed the visit count and the count was empty. `chromium-visits` and
`chromium-top-sites` now emit US (0x1f) separated rows through a `_row` helper, both readers use
`IFS=$'\x1f'`, and `_row` strips every C0 control and DEL -- the fable review's catch: a free-form
page title carrying ESC could otherwise inject a terminal escape sequence into the parent's
`omarchy-kids-data` output (I-6). Fixed on `fix/data-browse-empty-title` (`17b0fb8`);
`data-test.sh`'s History fixture gains an empty-title row and an ESC-bearing row, the latter
asserting the raw ESC never reaches the output. Full Mac suite 52 files green; fable review MERGE
after the C0 hardening. Live-verified from the branch on the VM with a fixture History db: a
no-title row renders "(no title) (2 visits)" (not a shifted count) and an ESC title prints as
plain text (`evil [2Ktitle`); the fixture was removed afterwards.

Follow-up from that pass, fixed here: a title whose bytes are not valid UTF-8 makes `lib/data.py`'s
`fetchall()` raise outside any handler, a traceback instead of the exit-2 one-liner the docstring
promises (a loud error, not a silent or forged one).

### 2026-09-21, loop iteration: a malformed History is exit 2, not a traceback (live)

Fixed that follow-up on `fix/data-corrupt-history-traceback` (`e199945`, stacked on
`fix/data-browse-empty-title` -- same file and functions): `_fetch_rows` now catches the fetch
error and validates each row's column types before use (a TEXT `last_visit_time`, a TEXT
`visit_count` or a BLOB `url` were the same uncaught `TypeError`/`AttributeError`), dying with the
docstring's one-line exit 2; a non-str `title` is coerced to empty; and `cmd_sites`/`cmd_summary`
drop the temporary History copy before that exit. The fable review found the wrong-type
paths in round one; the test builds an invalid-UTF-8 fixture and a wrong-typed column fixture for
each of the three columns, asserting exit 2 with no traceback. Full Mac suite 52 files green; review
MERGE after the type guard. Live-verified from the branch on the VM with an invalid-UTF-8 History:
`sites` exits 2 with one line (`data.py: could not read '...' as a Chromium History db: Could not
decode to UTF-8 column 'title' ...`), no traceback, and the temp copy is removed; the fixture was
cleaned up afterwards.

### 2026-09-21, loop iteration: a grant silently truncated the kid's data screen (live)

Dogfooded the parent panel live on the VM (main menu, kid screen, Data screen all render with real
data), then read the Data screen's own output. Two bugs in `omarchy-kids-data`, both triggered by a
kid who has ever been granted time (a `<day>.grant` sibling next to the `<day>` usage file):

- `find_usage_days` returned its last loop iteration's status, and `.grant` sorts after its day, so
  it returned 1; the caller's `earliest="$(find_usage_days ... | sort | head -1)"` then aborted the
  command under `set -euo pipefail`. Live: `omarchy-kids-data mine` (the kid's own "what my
  grown-ups can see" screen) printed only its intro and stopped before "Since:" -- the kid saw no
  date and no last-day summary. Fixed on `fix/data-grants-in-summary` (`6b2ff21`, stacked on
  `fix/data-corrupt-history-traceback`): the function now returns 0.
- the summary budget line printed the base budget only, so with a grant it read "budget 60, 105
  left" (impossible-looking). It now names the top-up, matching `omarchy-kids-time status`.

`data-test.sh` writes a `.grant` fixture and asserts the budget wording; the existing `mine`
assertions (Since date, last-day summary, minutes) now also catch the abort. Full Mac suite 52
files green; fable review MERGE. Live-verified from the branch: `mine` now prints "Since:
2026-09-21 / Your last day's summary (2026-09-21): minutes used: 338", and the summary line reads
"budget 60 + 375 granted, 97 left". No other glob loop in `omarchy-kids-data`/`lib/data.sh` has the
same last-iteration-status shape (the review checked each).
### 2026-09-21, loop iteration: the Apps screen named a tile the kid never sees (live)

Dogfooded the parent panel live on the VM: main menu, kid screen, Web, and Apps all render with
real data. The Apps screen listed "Tux Paint (shown)" though the launcher omits Tux Paint (not
installed, and `apps.show_missing=no` is the default) -- the panel dropped the `state` field from
`omarchy-kids-apps list --json`, so "(shown)" only meant "not hidden from the allowlist" while a
parent reads it as a visible tile (I-6). Fixed on `fix/panel-apps-not-installed` (`3b66d3a`): a
missing app's row now reads "(shown, not installed)" / "(hidden, not installed)"; the toggle and
its write are unchanged, and docs/panel.md records the suffix. `panel-test.sh` stubs `pacman` (only
gcompris-qt installed) so the state is deterministic and asserts both labels; the fable review
MERGE'd with no findings. Full Mac suite 52 files green. Live-verified from the branch:
"Tux Paint (shown, not installed)" and the installed pack apps plain "(shown)".
### 2026-09-21, loop iteration: the panel's read screens, live (preview)

Across this day's loop sessions the parent panel was driven on the try-omarchy VM with
`OMARCHY_KIDS_TUI_ANSWERS` (preview mode, no `--apply`) and the panel file set installed from the
branch: Home (kid rows with minutes used/left), the kid screen, Screen time (its grant, weekday and
weekend budget and lights-out rows), Web, Apps (the band pack rows, shown/hidden), Data (today and
this week), Desktop (level and theme), and the Plugins shelf all rendered from live root data. The
shelf listed a two-entry fixture catalog (kidmath, noage) and, once the fixture was removed, the
honest empty state. Requests, Password and Remove were not opened, and no write ran for real (the
write paths are `panel-test.sh`'s). `docs/panel.md` now records this, drops its stale "the Screen
Time screen only edits the weekday pair" note (the screen edits both) and its "panel-test drives
every screen" claim (it does not drive Web/Data/shelf/Password). fable review MERGE (after several
rounds trimming overclaims about what the test covers). Docs only.
### 2026-09-21, loop iteration: the plugins shelf parsed its own rows wrong (live)

Live pass: the Ask modal's keyboard path (Tab picks "Ask later", Enter writes the request; the
collect timer moved it to the root queue and `decline --apply` cleared it) works. Then the
launcher's "More apps" shelf -- a file the docs admitted had never run against a real Quickshell --
was launched on the VM. With an empty catalog it renders an honest empty state; with a hand-written
two-entry fixture index it exposed a real bug: a no-age plugin's `age` came out "verified", its
`verified` false, and the table's VERIFIED column printed the repo URL. Cause: `bin/
omarchy-kids-plugins`' `index_rows` emitted tab-separated rows and `cmd_shelf` parsed them with
`while IFS=$'\t' read`, but tab is IFS whitespace, so bash collapsed the entry's empty `age` field
and every field after it shifted (I-6). Fixed on `fix/plugins-shelf-field-shift` (`06043b9`): rows
use ASCII 0x1f (non-whitespace, so empty fields survive; stripped from values so an index entry
cannot forge a field), and each field is coerced with `tostring` before stripping -- the fable
review caught that jq's `gsub` raises on a numeric `age`, which would have silently truncated the
whole shelf; a numeric-age fixture pins it. `plugins-test.sh`'s existing `noage` entry plus a new
`numage` entry cover both. Live re-verified from the branch: `shelf --json` now reports noage
`age:""` / `verified:true`, and the overlay rendered the non-empty shelf, moved the selection with
Up/Down, and opened the Ask modal for that plugin on Enter -- so the surface is now verified end to
end (`8aaa847` updates docs/plugins.md and the shelf header), leaving only the band-3-5 launcher and
the panel's shelf screen open. Full Mac suite 52 files green; fable review MERGE after the gsub fix.
The fixture index was removed from the VM afterwards.
### 2026-09-21, loop iteration: session-start read the manifest's fields with a shift (live)

Recorded from the previous pass and fixed here: `bin/omarchy-kids-session-start` parsed the
manifest's jq `@tsv` row with `IFS=$'\t' read`, and the row has ten fields into only nine
variables, so the trailing `allowlist` was absorbed into `OMARCHY_KIDS_LIGHTS_OUT_WEEKEND`; a kid
with no theme override (`theme=""`, valid per docs/theming.md and the manifest) shifted every later
field too (THEME="garden", WEB="60", ...), and the non-empty guard still passed on the shifted
values. Fixed on `fix/session-start-manifest-fields` (`1154692`): the row is US (0x1f) separated
with 0x1f/CR/LF stripped from values, the allowlist is read into `_ALLOWLIST` so it cannot be
absorbed, and the guard no longer requires a non-empty theme (the other eight fields still must be
present, so a genuinely absent field still fails closed). `session-start-test.sh` sets
`lights_out`/`lights_out_weekend` in its fixture profile and asserts they arrive unshifted, plus a
no-theme kid that starts and exports an empty theme. Full Mac suite 52 files green; fable review
MERGE. Live-verified from the branch on the VM with an env-dumping copy of the installed command:
`OMARCHY_KIDS_LIGHTS_OUT_WEEKEND=20:00` (no allowlist appended), and the installed session-start
starts as kid-ada (exit 0, correct Level 2 exec line).

Remaining same-class candidate: `bin/omarchy-kids-data`'s browse rows (`read -r t host title
visits`) when a page has no title, shifting `visits` into `title`.
### 2026-09-22, loop iteration: the trust-boundary denylist named a function that does not exist

Dogfooded (session healthy; the box's four known FAILs), then tried a new mechanical angle --
identifiers cited by docs and tests that do not exist in the tree. It found `time_toast_thresholds`,
named in `test/shell.d/trust-boundary-test.sh`'s kid-time denylist and twice in `docs/time.md`. The
10/5/1 decision function is `time_warning_thresholds` (`lib/time.sh:246`, called by the ledger at
`bin/omarchy-kids-time-ledger:345`), so the denylist -- the check that the kid-side display can only
*show* root's decision -- was blind to the one policy function the daemon must not call, and the
docs pointed at a name no reader can find. Fixed on `fix/stale-threshold-name`; the denylist now
also names the other policy entry points the review pointed out (`time_next_boundary`, the direct
readers `time_budget_minutes`/`time_lights_out`/`time_used_minutes`/`time_granted_minutes`) plus
`remaining_seconds`. Verified by injection: each added name fails the check when placed in
`cmd_daemon`; `test/all` green; the fable review found nothing blocking.

Review follow-ups recorded for the owner (pre-existing, outside that diff): the check's `sed` range
covers only `cmd_daemon`, so a policy call in `show_toast`/`show_timesup`/`dismiss_timesup` would be
invisible (the oneshot daemon tests in `time-test.sh` partly cover it), and `docs/time.md`'s
Issue-#40 paragraph still says the function is "table-tested in `test/shell.d/time-test.sh`" (that
file never calls it directly) and that every check logs a `toast-check:` line (no file under `bin/`
emits it) -- both belong to that paragraph's staleness, which `fix/toast-clock-overlap` also edits.

### 2026-09-22, loop iteration: the denylist now covers the daemon's own helpers

Dogfooded (session healthy; the box's four known FAILs). Took last review's follow-up: the trust
boundary's kid-time denylist inspected only `cmd_daemon`, so a policy or finish call added to one of
the daemon's overlay helpers (`show_toast`, `show_timesup`, `dismiss_timesup`, `warning_label`)
would have been invisible to it. The window now covers those four plus `cmd_daemon`, with
`cmd_status`/`cmd_grant` deliberately outside (the kid-side read and the parent path both touch the
ledger legitimately), and a note that `remaining_seconds` is a state-file field a legitimate display
read could need. Verified by injection into `show_toast` (invisible to the old window, now fails the
check); `test/all` green; `shellcheck -x` clean; fable review nothing blocking.

Still pre-existing and recorded for the owner: the check is intra-file, so a `Process` block added
to `share/time/timesup.qml` or a `loginctl` in a `lib/kids.sh` `modal_*` helper would be invisible
(the reviewer read both and the boundary holds today), and the dispatch block and globals sit
outside the window as before.

### 2026-09-22, loop iteration: two identifier-reference scans, clean

Dogfooded (session healthy; the box's four known FAILs). Continued last round's angle -- identifiers
that docs and tests reference but the tree does not define -- across the whole live docs and the
test greps. After fixing the scan's own bugs (it first skipped `bin/` and accepted any word found in
code), the result is clean:

- Every lowercase `name()` cited in a live doc exists in the tree once the QML/JS/Lua/library APIs
  are counted; the only genuine miss was `time_toast_thresholds`, fixed last round. The names in
  `docs/specs/04-one-kid-shell.md` (`ping()`, `showLauncher()`, `hideModal()`, ...) are design
  proposals for a feature that is not built yet (a typed Quickshell IPC handler), not claims about
  the code.
- Every alternation name in a test's `grep` exists somewhere: the ones that are not repo
  identifiers (`declare`, `warn`, `fixed`, `lsinitcpio`, `mkinitcpio`, `objcopy`, `limine`) are
  commands or status words the tests look for.

Nothing to fix this round.

### 2026-09-22, loop iteration: the docs' code-path references, checked

Dogfooded (session healthy; the box's four known FAILs) and ran the last angle in this family: every
`lib/...`, `bin/...` or `share/...` path a live doc cites. Nothing genuine is missing -- the flagged
paths are Omarchy's own tools the docs name as external commands (`bin/omarchy`, `bin/omarchy-menu`,
`bin/omarchy-theme-color`, `bin/omarchy-plugin-add`, ...), files that exist only in future specs
(`docs/specs/04-one-kid-shell.md`'s `share/shell/*.qml` and `lib/shell-ipc.sh`,
`docs/specs/07-boot-mode.md`'s `lib/boot-mode-transition.sh`, `docs/specs/05`'s `lib/locks.sh`, ...),
or a *past* consolidation the doc itself describes as past (`docs/style.md`'s "`lib/units.sh` ...
folded into `lib/kids.sh`"). The live docs cite the TUI demo at its real
`scripts/omarchy-kids-tui-demo`; only the dated review records still say `bin/`. Nothing to fix.

With this, the mechanical-reference family is exhausted: docs links, docs-cited functions, docs-cited
code paths, test-grep alternations, command/doc/test inventory, SPEC id traceability, conventions and
file modes have all been swept, and each found only what earlier rounds fixed.

### 2026-09-22, loop iteration: a textual guard on the kid time overlays

Dogfooded (session healthy; the box's four known FAILs). Closed the review's follow-up from the
denylist round: nothing textual guarded the QML overlays a kid's session runs, so a `Process` block
or an `execDetached` added to `share/time/timesup.qml` (or `toast.qml`) would be caught only if a
behavioural test happened to exercise it -- and nothing in the suite executes QML. The
trust-boundary test now checks both display-only overlays structurally: the file exists, no
`Process {` block, no root enforcement name (`loginctl`, `omarchy-kids-exit`,
`omarchy-kids-time-ledger`, `omarchy-kids-assert`, `--finish`), no `execDetached` in `toast.qml`,
and exactly the one `omarchy-kids-ask` call in `timesup.qml`. `time-test.sh`'s narrower
finish-command duplicate now points here. Verified by injection (a `Process` block in `toast.qml`
fails the check); the suite is green; the review's two majors (a vacuous pass on a missing file, and
a names-only set that missed the shapes it had named) and two minors are closed.

Still open (recorded for the owner): `lib/kids.sh`'s `modal_*` helpers and the other kid overlays
(`ask`, `exit-modal`, `plugins`, `wifi`) have no equivalent guard -- the exit modal legitimately runs
the parent-authenticated finish, so its check would need a different shape.

### 2026-09-22, loop iteration: the overlay guard enumerated, one table

Dogfooded (session healthy; the box's four known FAILs). Extended last round's two-time-overlay
guard to every kid surface and closed the review's two majors: the file list was hand-written (a
new overlay would have been unchecked -- the "assertion must own its fixture" shape), and the "one
table" comment was untrue because the daemon check repeated the names in its own grep. Now every
`.qml` and `.js` under `share/` is checked, enumerated rather than listed, with the two surfaces
this repository does not own for a kid session skipped (the parent's bar widget and the SDDM
portal); the name table is defined once and spliced into the `bin/omarchy-kids-time` check too; it
gains the two parent paths (`omarchy-kids-time grant`, `omarchy-kids-bar end`); and the ok label
says "the named enforcement commands" rather than implying completeness. Verified: a brand-new
`share/zz-new-overlay/shell.qml` containing `loginctl` fails, the bar module's comment is skipped,
the exit modal's finish pair stays allowed, and the suite is green (the review's two minors -- the
overclaiming label and the multi-line indent -- are closed too).

Still open (recorded for the owner): `hyprctl dispatch exit` cannot be blanket-denied because the
launcher legitimately uses `hyprctl` for focus, so it stays a hole outside the two time overlays,
and `lib/kids.sh`'s `modal_*` helpers have no equivalent guard.

### 2026-09-22, loop iteration: the dispatcher exit spelling, and two more routes

Dogfooded (session healthy; the box's four known FAILs). Extended the overlay table's remaining
holes, and the review blocked the first try for a good reason: `dispatch[^[:alpha:]]*exit` misses
the spelling this repository actually uses -- `hl.dsp.exit()`, which `bin/omarchy-kids-exit` asks
Hyprland's Lua dispatcher for -- while the launcher's legitimate focus call is `hl.dsp.focus(...)`,
so a bare `exit` was not the shape to forbid. The dispatcher shape now has its own check, matched
against the file with newlines removed (a wrapped QML array cannot evade it) and with a
prefix-tolerant pattern that trips `hl.dsp.exit` and leaves `hl.dsp.focus` alone. The line-based
table drops that entry and gains the D-Bus route to logind
(`busctl`/`gdbus`/`qdbus`/`dbus-send`/`login1`, unused today), and the time-overlay rationale now
says a count -- not a name -- is what justifies its stricter check. Verified: same-line and wrapped
`hl.dsp.exit` both fail the check, the launcher's focus line passes, and the suite is green.

Still open (recorded for the owner): `lib/kids.sh`'s `modal_*` helpers have no equivalent guard (a
file-wide one would false-fail on the `KIDS_UNITS` array, which names the assert *service*), and
bare `kill` cannot be forbidden -- it would hit `killactive`-style dispatchers, so a word-bounded
form would be needed if ever wanted.

### 2026-09-22, loop iteration: the modal pidfile helpers guarded too

Dogfooded (session healthy; the box's four known FAILs). Closed the recorded follow-up:
`lib/kids.sh`'s `modal_*` pidfile helpers (which every kid overlay uses to track and close its own
process) had no equivalent of the enforcement table. They are now extracted per function -- an
`awk` that handles one-line and multi-line bodies -- and checked against the same shared table; a
plain line range would have swept in the `KIDS_UNITS` array just below, whose
`omarchy-kids-assert.service` entry is a service name, not kid-side enforcement. A missing helper
fails loudly rather than passing vacuously. The review's minors were applied: the one-line test is
anchored to a trailing brace (a header with a brace expansion no longer truncates the body), all
three names are pinned, the failure output prints the real `lib/kids.sh` line numbers rather than
offsets into the extracted blob, and the header pattern admits digits. Verified: `loginctl` and
`pkill` injected into `modal_close` fail the check with their real line numbers, `KIDS_UNITS` is
tolerated, the suite is green; the review found nothing blocking.

Still open (accepted, recorded for the owner): bare `kill` cannot be forbidden (it would hit
`killactive`-style dispatchers), and a column-0 `}` inside a helper body would end extraction early
-- nothing today has one.

### 2026-09-22, loop iteration: what the dogfood VM is actually running

Dogfooded (session healthy at Level 2, 36 min left, no autologin drop-in; the box's four known
FAILs, 46 PASS). Rather than start another fix on that surface, closed a hole in how our own live
claims are read: the guest's checkout is old and its installed files were placed by hand iteration
by iteration, so "verified live on the VM" can describe code the base does not have. Reconstructed
the installed set empirically -- each installed file's md5 against every one of the 78 local heads'
blobs, with the PKGBUILD's two build-time substitutions applied, and reported only files that
differ from `integration/dogfood-2026-09-19` (`.local/VM-PROVENANCE-2026-09-22.md`, untracked;
`/tmp/vm-provenance.py`). The result is legible: 18 files match exactly one topic branch (the
deliberate installs, each named in the recipe), 2 share one change across several on-base heads
(`lib/data.py`'s US-separator reader; `L2.lua`'s "inert at Level 2" note), and 17 match only
heads *not* descended from the base -- the guest simply predates a base commit (e.g.
`omarchy-kids-authd` lacks base's `omarchy:hidden=true`), which is why a naive "does it match some
branch" test called them drift. The recipe's "all green on 2026-09-21" line was false and is
replaced by the box's real four FAILs and what each means. No product code changed.

Still open (recorded for the owner): the four VM FAILs are this box's history, not defects --
re-running `omarchy-kids-assert` and re-provisioning `kid-ada`'s band group would clear two of
them but disturbs the session the loop keeps up for dogfooding, so they stay.
### 2026-09-21, loop iteration: the kid toast didn't fit its own message (live)

Dogfooded the kid-facing Wi-Fi picker -- a surface docs/levels.md listed as entirely unverified. A
`wifi=parent` kid (the 6-8 default) correctly gets a toast ("Wi-Fi needs a grown-up. Ask them to
turn it on for you.") and no picker. But the toast rendered wrong: it overlapped the launcher's
top-right clock, its message interleaving with the `N minutes left` line. `hyprctl layers` showed
the toast window was **320x32**: `implicitHeight: card.implicitHeight + 32` where `card` is a
Rectangle with `anchors.fill` and no implicit height of its own, so the wrapped message overflowed
the window and drew over the clock. Fixed on `fix/toast-clock-overlap` (`a58bbd2`): the window
sizes from the content Row (`cardContent`), and the top margin goes 96 -> 144 to clear the
launcher's whole clock block (the time plus the `N minutes left` line) -- 96 had been chosen
against a wrong clock inset (24, vs the launcher's 32 short / 56 tall). Live-verified at 875x492:
the window is now 320x98 at y=144 and the clock is clear. The fable review needed two rounds (120
was 2px short for Level 1 at >=640px tall; the docs claimed the block was "measured" when only the
window geometry was observed), ending MERGE. docs/time.md updated. Open: on a short screen a 98px
top-right toast still overlaps the launcher's title/card corner transiently (inherent -- there is
no free top-right space at 875x492), and the 6 s auto-dismiss and `Qt.quit()` shutdown remain
unverified (the toast's own timer/quit path).

### 2026-09-21, loop iteration: the launcher's time-left line was frozen (live)

Dogfooded the Time's Up screen on the try-omarchy VM, launching `share/time/timesup.qml` (installed
from its branch) against a hand-written `grace` status: the card rendered with the fox avatar,
"Time's up, Ada!", the reason line, a "Closing in N s" countdown that decremented, and the
highlighted "Ask a grown-up" button, and Enter on it opened the Ask modal over the card. (An
earlier attempt showed no avatar and the old "Finishing in" wording because the VM's installed
`timesup.qml` was a stale package build; installing the branch's file fixed both.)

That pass then found a real bug in the launcher: its "N minutes left" line was frozen at the value
it read when the launcher started -- "41 minutes left" stayed put for half an hour across many
daemon ticks and a `+10` grant, while the status file's `remaining_seconds` moved (the
hide-on-grace branch never ran either). Cause: the `FileView` had `watchChanges` but no
`onFileChanged` reload (FileView does not re-read on a watch signal by itself --
`share/bar/KidsModule.qml` adds the handler for the same reason), and the daemon publishes the
status by rename (`lib/time.sh`'s `mktemp` + `mv`), which can drop the watch. Fixed on
`fix/launcher-time-left-refresh` (`1acc799`, stacked on `fix/toast-clock-overlap` for the shared
`docs/time.md`): the FileView reloads on `fileChanged`, and a repeating 2s timer is the backstop
(the ledger ticks every 30s). `launcher-grid-test.sh` pins the whole timer block and the
`onFileChanged` handler; `docs/time.md` records the finding and drops the stale "the card still
needs a fresh VM run" note. The fable review found the missing `fileChanged` hook and the unproven
"the watcher stops" claim, ending MERGE. Live-verified with the final file: the line followed a
`+10` grant from "73" to "82 minutes left" at the next tick (and "79" to "88" the run before).
### 2026-09-21, loop iteration: docs/levels.md still called the Level 3 pass unverified

Dogfooding the panel live (main, kid, Screen time, Web, Apps, Desktop screens -- and the box was
missing the matching `bin/omarchy-kids-panel`, so the panel errored `panel_notice_lines: command
not found` until the whole panel file set was installed from the branch: an install-hygiene
reminder, not a repo defect). The live pass found no code defect, so the iteration took the
recorded I-6 candidate: `docs/levels.md` still said Level 3 was unverified on a real box and that
`share/menu/omarchy-kids-trimmed.jsonc`'s shape was "a guess", both disproved by the 2026-09-21
Level 3 pass (and the file's own header). Fixed on `fix/levels-live-status` (`8784df2`): the
live-status paragraph and files-table row now record what ran (stock desktop, the extension's
`when: "false"` rows hiding Install/Remove/Update/Setup, no first-run provisioning, two apps
tiled); checklist item 6 is marked verified, item 2 answered for the provisioning worry, item 1
checked, item 8's column model confirmed at the tested sizes, and item 3 left open with the real
reason (the launcher and GCompris self-fullscreen, so the `fullscreen = true` windowrule was never
exercised). The fable review needed several rounds, each closing a real overclaim (item 3's
"answered", the `hyprctl binds` no-op conclusion -- it cannot separate "stock never binds it" from
"the unbind worked" -- and a wrong #200 attribution), ending MERGE. Only `docs/levels.md` changed;
`levels-test.sh` was unaffected. The panel-install mismatch is noted so future dogfood installs the
whole component set.
### 2026-09-22, loop iteration: the two commands that resolved their interpreter through $PATH

Dogfooded the Ask flow end to end this time, since it is core and had not been run in a while: as
the kid, `omarchy-kids-ask submit time 15` wrote the request into their outbox; as root,
`collect --apply` moved it into the real queue ("1 request(s) collected, 0 dropped") and `list`
showed it with its id; `decline <id> --apply` closed it, the queue went empty and the budget never
moved. One thing that invocation taught: the kid-facing `omarchy-kids-ask time 15` (the shape the
Time's Up card and the plugins shelf run) is not a submit at all -- it opens the ask *modal*, which
is why it failed from an SSH shell with a Qt platform-plugin error until `WAYLAND_DISPLAY` was set.
The CLI submit is `submit <kind> <what>`; both shapes are in the command's `--help`, so nothing was
changed for it.

Then the backlog's I-6 pass, on the command contract rather than the kid surfaces: every
`bin/omarchy-kids-*` command's `--help` was run (all 28 exit 0 and name themselves; `omarchy-kids-
conf --help` only needs a Python 3.11+ on PATH, which the suite pins), and all 28 carry the
`omarchy:summary` header the conventions require. Nothing pins either fact, though, which is worth
a test someday.

What the contract sweep did find was a trust-boundary inconsistency in the shipped artifact. The
two Python commands, `omarchy-kids-authd` and `omarchy-kids-wifid`, ship
`#!/usr/bin/env python3`, so a direct exec resolves the interpreter through `$PATH` -- the exact
thing the PKGBUILD's own comment, three lines above, says this package must not do for `KIDS_PY`
("baked in here rather than resolving python3 through $PATH"). Both are socket-activated root
services started by systemd, whose PATH is fixed and root-controlled, so the practical exposure was
small; the artifact was still inconsistent with rule 9, and nothing pinned it either.

Fixed on `fix/python-shebang-absolute`: the PKGBUILD rewrites exactly those two shebangs to
`/usr/bin/python3`, each with the same guard-grep style as the `KIDS_PY` substitution, and the two
files carry the one-line "why python" header note the conventions ask for instead of an exception.
`trust-boundary-test.sh` gained a section that keeps the list honest in both directions: every
command's shebang must be bash or the python dev form, the PKGBUILD must name exactly the commands
that carry the dev form, and the rewrite and its guard must be present. The review earned its keep
again: the first version of that check parsed the PKGBUILD with a sed *range* that swept in a
neighbouring command and compared only one direction, so a python command named elsewhere in the
window would have passed while shipping a PATH-resolved shebang -- and its "exactly" claim was
false. Both are closed, and the reverse direction now fails a name that is not a python command.

Verified live through the real build: the arch fix and this hunk were applied together in the
guest's scratch tree (the union cannot build on aarch64 until that branch merges), `makepkg -d -f`
built it, and the package's `usr/bin/omarchy-kids-authd` and `-wifid` now begin
`#!/usr/bin/python3` while a bash command is still `#!/bin/bash` and the repo copies keep the dev
form. `docs/packaging.md`'s four `PKGBUILD:37-109` file-list citations became `37-123` (the
function's new end).
### 2026-09-21, loop iteration: the wifi picker had run; the docs said never (live)

Dogfooded the Wi-Fi picker's `helper` mode: set the kid's `wifi=helper`, installed the repo's
`share/wifi/shell.qml` (the VM's packaged one was stale -- it lacked the open-network message and
some font bindings), and launched `omarchy-kids-wifi picker` in the kid session. It loaded and
rendered "Wi-Fi", "No networks found", the accent-bordered "Try again" button, and "Enter try
again · Esc close" over the desktop (the VM has no wireless device, so `omarchy-kids-wifi list`
returned an empty OK) -- proving the layer shape and the list Process ran. No code defect. Fixed the
docs on `fix/wifi-docs-live-status` (`30c5d3a`): `docs/wifi.md` no longer says the picker "has
never run against a real Quickshell", leaves the non-empty `SplitParser` path, the join/password
flows, Esc and the `Super+Shift+W` bind as still unverified, and drops the nearby "the picker
overlay needs the laptop's card" contradiction; the picker's dangling "UNTESTED header above"
comment now points at `docs/wifi.md`. fable review MERGE (one pre-existing note fixed). The same
install-hygiene trap as `timesup.qml` appeared again: the VM's packaged files are older than the
branches, so a live check must install the file under test first.
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

### 2026-09-22, loop iteration: two mechanical sweeps, both clean

Dogfooded (session healthy; the live check is 46 PASS plus the box's four known FAILs), then tried
two angles the loop had not:

- **Command <-> doc <-> test inventory.** Every `bin/omarchy-kids-*` either has its own
  `docs/<command>.md` or is documented inside its topic doc (`blocked`, `boot-login`, `parent-auth`,
  `session-start`, `super-tap`, `time-ledger` and `wifid` are each mentioned in 3-11 live docs), and
  the extra `test/shell.d/*` files are topic tests (trust-boundary, qml-*, theme-*, wizard-*, ...),
  not gaps. No tracked build artifacts (`bin/__pycache__` is gitignored).
- **SPEC requirement-id traceability.** `SPEC.md` has 90 ids. The 8 cited in neither a test nor a
  doc are all explained: R-EXIT-2 is a pointer line ("verified through R-SEC-2"), R-EXIT-4/5 are
  Pause, deliberately unshipped (DECISIONS-NEEDED §6 item 2), and the rest (R-BOOT-4, R-BUILD-1,
  R-LOGIN-2, R-SEC-5, R-SEC-6) have their substance documented or their id cited in code -- e.g.
  R-LOGIN-2 is implemented and cited at `share/sddm-theme/Main.qml:211`, and R-BOOT-4's
  "supersedes, sorts later" is `docs/boot.md:28,90,128`.

Also confirmed the band data is consistent: four bands, each with a pack, a policy JSON and a list
file, and `render_policy_json` merges the list only for garden bands (the 13+ list is a parked proxy
blocklist, never merged), so R-WEB-3 holds. Nothing actionable this round; the remaining work is the
owner's (DECISIONS-NEEDED §7).

### 2026-09-22, loop iteration: conventions and file-mode audit, clean

Dogfooded (session healthy; 46 PASS plus the box's four known FAILs) and audited the repo's own
conventions mechanically: every bash command in `bin/` has `#!/bin/bash`, `set -euo pipefail`, an
`omarchy:summary=` line and the executable bit; the two Python daemons (`omarchy-kids-authd`,
`omarchy-kids-wifid`) carry `omarchy:summary=` and `omarchy:hidden=true`, and R-BUILD-1 sanctions a
Python verifier ("a tiny Python or Perl helper") for both. Every tracked file's mode matches its
kind once the executable set is read correctly (`bin/`, the `initcpio/` hook scripts, `scripts/`,
`test/live/`, `test/phase1/`, `test/all`). Nothing to fix.

### 2026-09-22, loop iteration: two stale "never run live" claims, retracted

Dogfooded (session healthy; 46 PASS plus the box's four known FAILs) and swept the live docs for the
claim class that found real defects twice before -- assertions that something has never run against
a real Hyprland/Quickshell. Two were stale:

- `docs/data.md` called the `kids-data` tile's lack of verification "the same caveat every other
  `share/launcher/shell.qml` feature carries", but the launcher runs live now (its grid, picker and
  app tiles were exercised on the VM 2026-09-21/22). The tile is offered only to bands 9-12 and 13+,
  and the loop's kid is 6-8, so it is that tile's *turn* that is missing, not the file's
  verification.
- `docs/levels.md`'s open-questions intro said "no live Hyprland, no Quickshell", contradicting the
  same doc's live-status paragraph (Levels 1 and 2 verified live); it now reads as the historical
  position it was, and says the Level 3 items are what still needs the VM or a real box.

Fixed on `docs/stale-launcher-claims`, stacked on `docs/fix-doc-references` (the same two files);
`test/all` green. Left alone as uncertain: `docs/time.md` says the repo "has never run against a
real `systemd-logind`", yet the VM's ledger tick parses real `loginctl` output every 30s (one
property per call, not the four-property form the doc names) -- whether that closes the item, or the
lock transition is still the open part, needs a closer look before changing the text.

### 2026-09-22, loop iteration: a docs claim is only as good as the branch it was observed on

Dogfooded (session healthy; the box's four known FAILs) and took on `docs/time.md`'s "What's
unverified" section, written before the VM ever ran the time engine. My first draft moved most items
to "verified live" -- and the fable review blocked it: the evidence I leaned on was gathered against
**branch** files, not this branch's. This branch still has the 96px toast margin (the live check of
it found the window sitting over the clock; `fix/toast-clock-overlap` raises it to 144), the
`FileView` with no `onFileChanged` reload (the time-left line was recorded frozen across ticks and a
grant on `fix/launcher-time-left-refresh`, which fixes and live-verified it), and no recorded
`LockedHint=yes` lock engagement (`fix/time-lock-engagement`; only `finish` ran live). One new claim
("the card dismissed after a grant") also misread a log line that fires at the *next* session start.

The corrected change keeps this branch's unverified list, adds a method note (the VM runs installed
branch files, so read every live claim with the branch it was observed on -- `docs/loop-report.md`),
points each item at the branch holding the evidence, and keeps exactly one claim verified: the
tick's own `loginctl` calls (they run against the VM's real logind every 30 s, one property per
call, and the usage accounting depends on parsing them -- the docs used to say the repo had never
run against a real logind, and named a four-property form the code does not use). Also fixed the
"Issue #40's fix" paragraph's closing claim that none of its three items had run live.

Lesson worth keeping: the loop's live evidence is branch-specific. Any future doc-currency edit here
must say which branch a "verified" claim belongs to, or it becomes a false claim on integration --
the same "label claims" rule, one level up.

### 2026-09-22, loop iteration: a repo-side record for the daemon's survival

Closes the one major the fable review left open on the `docs/time.md` change: that doc's unverified
list asks whether a background `&`'d `omarchy-kids-time daemon` survives
`omarchy-kids-session-start`'s `exec`, and the only evidence was a VM session log a reader cannot
see. Recorded here so the doc can cite it: the VM's `/run/user/1001/omarchy-kids/session-1001.log`
shows (lines quoted) the daemon started and still logging toasts hours later:
`2026-09-22T02:19:18-0400 starting omarchy-kids-time daemon for 'kid-ada'`, then
`2026-09-22T02:39:49-0400 toast: 10 minutes left`, `...T03:09:51-0400 toast: 10 minutes left`,
`...T03:14:21-0400 toast: 5 minutes left`, `...T03:18:51-0400 toast: 1 minute left` (no daemon was
launched by hand in that session). So it does survive the `exec`; nothing in
`test/shell.d/session-start-test.sh` asserts it (its time stub exits 0), which is the part still
open.

### 2026-09-22, loop iteration: three time.md sentences re-scoped, and what is still entangled

A re-review of the `docs/time.md` change found three sentences the first pass had left or made
wrong, now corrected: the Ask-modal sentence at `docs/time.md:161` and its list bullet say the
over-Time's-Up case *was* watched, against a hand-written `grace` status (`share/time/timesup.qml`,
`share/ask/` and `session-start` are byte-identical to this branch's, so that observation applies
here); the "Issue #40" paragraph's closing sentence no longer claims the warnings never ran (that
code is this branch's and did fire 10/5/1 on 2026-09-22); and the `loginctl` item now says the call
form is read from this branch's source rather than observed on the VM (which ledger build its ticks
ran is not recorded). Left for the branches that own them: `docs/time.md:138-140` and
`share/time/toast.qml:25-26` still say the 96px margin clears a roughly 40px clock, which
`fix/toast-clock-overlap` changes and must correct with it, and `fix/launcher-time-left-refresh`
owns the frozen-watch record.

### 2026-09-22, loop iteration: the branch-owned doc corrections, checked

Dogfooded (session healthy; the box's four known FAILs). Followed up last round's "left for the
branch that owns them" note and confirmed `fix/toast-clock-overlap` does carry them: its
`share/time/toast.qml` comment explains the 144px margin (the arithmetic and the 2026-09-21 finding
that the 96px window sat over the clock), and its `docs/time.md` already has the corrected margin
paragraph and unverified bullet. No action there.

Spot-checked six code-fix branches for the same shape (a behaviour change without the doc that
describes it): `fix/launcher-time-left-refresh` (docs/time.md), `fix/show-missing-regression`
(docs/apps.md, docs/conf.md, docs/levels.md), `fix/panel-apps-not-installed` (docs/panel.md) and
`fix/ask-list-empty-minutes-shift` (docs/ask.md, docs/panel.md) all carry their doc updates;
`fix/session-start-manifest-fields` and `fix/data-browse-empty-title` are code/test-only, and their
changes are internal enough that no doc describes the old behaviour they change. Nothing actionable
this round: the docs' remaining stale claims are owned by the branches that fix the code they
describe, and merge with them.
### 2026-09-22, loop iteration: the polkit check blamed the rule for root's own exemption

Dogfooded the box's read-only parent checks this time: `omarchy-kids-assert --dry-run` reports every
lock ok (`skip boot-locks:portal`, plus the known unverifiable parent-unlock warning), and
`omarchy-kids-session --check-setup` run as **root** printed a wall of per-account FAILs about
root's own account. One of them was a lie: `polkit rules present  FAIL  polkit authorized a denied
action: the deny rule is not active`. Root is authorized *outright* by polkit, so `pkcheck` exits 0
with no output at all, and the check's empty-answer branch read that as the rule being missing. The
same branch also misblames the parent's own account, which the default policy sends to "requires
authentication" — the check said the rule was off for them too.

Fix on `fix/polkit-check-as-root`: the probe now SKIPs (like the two mounts) when the invoking
account has no Kids Mode profile, or is root, with a detail that says why — root is authorized
outright, or the account simply isn't a kid, so the probe says nothing about how a kid is treated.
The guard sits before the `pkcheck` presence test, so a SKIP never depends on a tool it does not
use. `docs/session.md` and `--help` say the same thing, and the check's own FAIL detail no longer
over-claims the cause ("the deny rule does not bind this account (no rule, or the account is not in
omarchy-kids)").

Three review rounds, each of which found something real. The first: my test's "does not blame the
rule" assertion could not fail, because the harness's pkcheck stub substitutes "Not authorized."
for an empty answer file, making root's real answer unreachable — the stub now has an `authorized`
control value (nothing, exit 0), which also gives that branch its first coverage. The second, and
the one that mattered: keying the SKIP on *group membership* would have skipped a profiled kid
whose groups have drifted — exactly the state `lib/assert-locks.sh` exists to repair — turning a
fail-closed check into a silent pass, so the predicate is the profile (plus root) and a profiled kid
always gets the probe. A new test pins that case (`KIDS_TEST_GROUPS=wheel`, profile present,
`break_polkit`): it must FAIL, name what it checked, and not start Hyprland. The third round caught
the labels: help and docs still described the group predicate. Both mutation directions bite
(removing the guard fails six assertions; the group predicate fails the four drifted-kid ones).

Live-verified by installing the worktree copy as `/usr/bin/omarchy-kids-session` on the box: as root
the row is now `SKIP` with the honest reason and no false blame; as `kid-ada` it is unchanged — the
probe runs and reports the deny rule active.

### 2026-09-24, owner-gated union merge: every remaining topic branch

The owner said "merge everything", so the rest of the 71 branches ahead of integration were merged
with the owner's gate. This was run the way `docs/branch-conflict-map-2026-09-22.md` prescribes:
`chore/gitattributes-loop-report-union` landed first so `docs/loop-report.md` has the union driver
(its conflicts fell from 60 branches to 10), then the branches merged in a batch, gated at the end.

- **Merged: ~65 branches** -- the loop-iteration records, the fix/ branches (ask, data, dns, garden,
  launcher, levels, panel, plugins, portal, session-start, time, toast, wifi), the docs/ branches
  (bar, exit, levels, notify-design, web, wifi, matt-pocock's ACP workflow sections), `style/shfmt`,
  `feat/gcompris-preseed`, `test/panel-wifi-mode-label`, and `fix/fresh-install-ordering`.
- **Resolved by union, not by a side.** A first pass took the incoming branch's copy of the
  conflicting files for speed, which dropped integration's newer text (AGENTS.md lost rule 2's
  notification amendment; docs/time.md lost the N-workstream lines). That was corrected in
  `af8dd8e`: AGENTS.md is integration's text plus the two new ACP/agent-workflow sections, and
  docs/levels.md, docs/time.md, docs/packaging.md and docs/wifi.md are unions of both sides.
  PROGRESS.md and CHANGELOG.md took integration's copy (they rewrite their own top section).
- **Skipped, with the reason:** `feat/n1-queue-visibility` and `feat/n2-kid-sees-answer` are
  superseded -- integration already carries N-1's `open_requests` badge and R-NOTIFY-6's kid copy
  and `outcome` sentence cover "the kid sees the answer", and both branches conflict heavily with
  the evolved N code; `fix/install-packaging` is a subset of the merged
  `fix/fresh-install-ordering`; `fix/launcher-insets-simplify` is stale (its change is in the union
  already); `hub-archive-2026-09-19` and `two-paths` share no history with integration (the
  hub/spokes design lineage) and would need `--allow-unrelated-histories`.
- **One real defect the merge exposed and fixed:** the older python-shebang branch brought a
  PKGBUILD loop naming only authd and wifid, while the merged trust-boundary test derives the list
  from bin/ shebangs; relayd was missing. `bin/omarchy-kids-relayd` is named now, on the one line
  the test parses.

Gated before push: `test/all -j 4`, 64 files green (the merge added a test file). Integration is at
`3bb1963`, in sync with `origin`.

### 2026-09-24, the dogfooding workstream (owner's notes, branch `fix/kid-session-polish`)

The owner's dogfooding notes were triaged by opus 5.5 at max effort (54 tickets, T1-T54) and the
work started on a branch of its own, based on the merged integration:

- **The kid's first session survives and explains itself.** L1/L2/L3 set `ecosystem.no_update_news`
  and `no_donation_nag`, so Hyprland's update announcement (and the link it opened in Chromium)
  never appears in a kid session (T4); L1/L2 import the environment into `systemd --user` and the
  D-Bus activation environment like L3, the live finding behind a D-Bus-activated app dying (T5).
- **Two kid modes.** Grid (level 1) and Desktop (trimmed level 3); the old Simplified desktop
  (level 2) is retired. Bands 3-5/6-8 are Grid, 9-12/13+ Desktop. bands.toml, SPEC R-DESK-3/4, the
  R-BAND table, Appendix E, A11, docs/conf.md, docs/levels.md, docs/wizard.md, docs/session.md,
  schema.toml, the wizard and panel pickers, and the levels test all follow (T13/T14).
- **Kid themes.** OldJobobo's 15-theme collection (omacom/omarchy#12488) ships as config
  only (no wallpapers: their licences are not ours to pass on), under a package-owned root
  `share/themes-kids/`, listed by a second theme root in lib/theme.sh so the pickers offer them;
  the licence/provenance state is in its README (T46/T47).
- **The management menu.** A top-level "Remove a kid", and "Add a kid" returns to the panel instead
  of ending it (T16/T17).
- **TUI.** The screen title is the heading with the step line under it; no spec ids in the
  parent's menu labels; Omy talks in one bubble line; the Advanced checklist's changed rows show
  the new value in the row; the number-key claim corrected (T27/T29/T30/T33, and T28's honesty
  half).
- **Web.** Every band's Chromium policy disables promo tabs, the default-browser prompt, metrics
  and search suggestions (T12, Chromium half).
- **Docs.** docs/parent-guide.md (T36): the two desktops, each band's defaults, a plain explainer
  per setting, pinned to the schema and bands by a test.
- **Tests.** 65 files green on the Mac.

**Deferred, with the reason:** T18 (hand over to a kid) needs the portal's sign-out and the kid
tile preselected, which needs a VM and the R-WIZ-6 amendment; T31 (an `Ask Omy` `?` key) and T32
(a clickable, animated Omy) need a pointer GUI, which gum cannot do; T34 (a floating wizard window)
needs a compositor rule and a VM; T44/T45 (kid-chosen themes) and T49-T53 (the #11196 ideas:
per-weekday minutes, Agreement mode, a PIN, earn-minutes, a kid day view) each need their own
amendment. None is shipped as a claim that is not enforced.

### 2026-09-25, kid themes as a preference, and the seam review

Continuing the dogfooding workstream on `fix/kid-session-polish`.

- **T44 — the theme is a preference.** `theme_apply_for` writes the kid's `.../current/theme` and
  `theme.name` kid-owned; the `theme:<account>` assert lock is verify-only (an in-set kid choice
  passes; an out-of-set name, or a planted FIFO/symlink, fails and the fix re-applies the profile's
  theme, or the parent's current theme when there is no override).
- **T45 (half) — the collection is visible to Omarchy's own switcher.** Provisioning symlinks each
  package kid theme into the kid's `~/.config/omarchy/themes/`, where Omarchy reads user themes, so
  the kid's own `Super+Ctrl+Shift+Space` lists them. The chord binding itself is the VM-checked half.
- **Two reviews (opus 5.5 max).** Round one on T44 found a blocking rule-9 hole (root read the
  kid-writable `theme.name` with a plain `cat`, so a planted FIFO could hang the assert and the
  pacman re-assert hook) and an I-6 no-op fix; round two found the missing `O_NONBLOCK`, that the
  FIFO tests were vacuous (no `mkfifo` on the test PATH), and that the amendment wanted the parent
  default, not a FAIL. All closed; the read is `O_NOFOLLOW` + `O_NONBLOCK` + a regular-file check,
  and the tests create real FIFOs.
- **Amendments written** to unblock the rest: `SPEC-AMENDMENT-kid-themes.md` (T44/T45) and
  `SPEC-AMENDMENT-screen-time-11196.md` (T49-T53; take logind-based counting, per-weekday schedules,
  Agreement mode, a kid day view, opt-in root-checked earn-minutes; refuse its core edits and the
  kid sudo grant).
- **shfmt.** The union merges had left seven test files drifted; `shfmt -i 2 -ci` is clean again.

Gated: `test/all -j 4`, 65 files green. Integration at `57f6476`, in sync with `origin`.

### 2026-09-25, the theme write that hung the suite (a FIFO), and bounded waits

- T45's other half landed: `bin/omarchy-kids-theme` (the kid picker, applied through Omarchy's own
  `omarchy-theme-set`) bound on `Super+Ctrl+Shift+Space` at every level, with L3 removing Omarchy's
  own stock bind for the chord first. Reviewed by opus 5.5 (max).
- The review found a **security defect in T44**: `theme_apply_for` ran as root writing under a path
  a kid controls, and `theme_reload_if_live` read the kid's `colors.toml` as root -- a symlinked file
  could have leaked another file to the kid. Root now removes a stale tree and runs the whole build
  as the kid via `runuser`; the reload reads and IPC as the kid.
- The security refactor then introduced a real hang: it wrote `theme.name` with a shell redirect,
  which **blocks forever opening a FIFO for write**, and the T44 test plants exactly that FIFO. Every
  assert run hung and left orphan processes. It writes a `mktemp` file and `mv -f`s it over the
  target now (the old shape). With that fix, `assert-test` and `remove-test` both pass, and
  `test/all -j 4` is **67 files green with no workaround** for the first time on this Mac.
- `assert-test` also bounds its two concurrency `wait`s so a deadlock fails the gate instead of
  hanging it.

Integration at `64e3a58`, in sync with `origin`.

### 2026-09-25, six adversarial reviews, and the decision that binds the display

Continuing the dogfooding workstream on `fix/kid-session-polish`, this pass ran independent
adversarial reviews (opus 5.5 at max effort; fable 5.1 was rate-limited) over every high-risk
surface, and closed what they found.

- **Network and socket surface** (authd, wifid, relayd, courier, the posture writers): no
  exploitable finding. One hardening: `lib/sock.sh` pins its transport programs
  (`/usr/bin/socat`, `KIDS_PY`).
- **Enforcement and boot/removal**: one **critical** — in disk mode, `boot-login` treated an absent
  `boot-slot` as a no-op, so Omarchy's stock autologin (the parent) won and a kid who opened the
  disk after the hook stepped aside landed on the parent's desktop (a regression of the V7 fix).
  Disk mode now writes an empty `User=` (the portal). Plus an honest Password-screen card (the
  `passwd` fallback does not rotate the disk slot; R-SEC-5's "both update the slot" is recorded as
  unmet) and two LOW LUKS gaps in `docs/remove.md`.
- **Kid-facing surfaces** (launcher, modals, picker, bar): a terminal-backed tile on the fullscreen
  Grid (now level-2 only), and a theme chord that gave `gum` no tty (now wrapped in Omarchy's
  floating-terminal helper).
- **Config and provisioning write paths**: no exploitable finding; two loose validators tightened
  (`dns custom:`, `machine set parent`).
- **Parent app**: several real defects — a reply dropped on Approve, a `/v1/state` read raising a
  notification (R-NOTIFY-14.1), no app-side review id binding, a truncated URL approved full, a 10 s
  timeout under a 30 s box window, a list cap that kept the oldest, and a pinned-certificate check
  that could inspect the wrong chain certificate.
- **The decision binds the display (amendment section 20), built.** A request decision now signs the
  kid, kind, what and minutes the app showed; the box requires it and refuses a record whose fields
  moved. Its own confirmation review found the live client still signed the old shape (fixed) and a
  `docs/relayd.md` overclaim (the relay can still lie on screen; it cannot apply a relabelled
  decision) — both corrected, with the wire-contract docs and tests updated.

Also this pass: T44 (the kid's theme is a preference), T45 (the collection is visible to Omarchy's
switcher, and the picker is bound on Omarchy's own chord), T25 (one panel read per Home screen), and
the FIFO-write hang that broke every assert run. `test/all -j 4` is 68 files green, plus 61 Dart and
58 Flutter tests.

## 2026-09-25 — dogfood pass on the try-omarchy VM, and four fixes

Mark asked the loop to launch try-omarchy on this Mac and dogfood the product by driving it, not to
keep testing the CLI from a shell. This is that pass, plus the four defects it turned up. Base was
`integration/dogfood-2026-09-19` at `9415e98`; everything below is merged there, tip `9e66847`.

### Driving the VM (the hard part, and what it cost)

The old temp-dir SSH key had been purged, and the app's own launch menu was not a reliable control
path. What works, and is written up in the untracked `.local/VM-DOGFOOD.md`:

- Launch the app's QEMU directly with `OMARCHY_QEMU_GPU_PORT_FORWARDS=tcp:2222:22`, which also
  appends `tryomarchy.ssh_access=1` and so enables `sshd.service`; owner set the box to **4 cores /
  4 GB** for this pass. `/usr/sbin` must be on `PATH` (`sysctl`) or the launcher exits.
- Input over QMP (`input-send-event`, explicit down/up with a hold); `/tmp/vmkeys.py` and
  `/tmp/vmclick.py`. **QMP cannot fire Hyprland keybinds** — see the retractions.
- Screenshots: in-guest `grim`; an X11 greeter needs `import` on the SDDM X display, not
  `screendump`; a closed-modal QEMU window does not exist in `hyprctl clients` if it is a layer
  surface. Killing by `pkill -f` can match your own SSH command line; kill by pidfile.

### Verified live (working)

Portal (4 tiles, correct avatars); Grid plus keyboard launch; the browser fence both ways;
the garden start page; Desktop mode and its trimmed menu; Time's Up by budget **and** by
lights-out; ask → panel approve → the kid's overlay shows the answer, live; the desktop notifier
and the bar's open-request badge; the exit modal; wizard steps 1–6; panel home / kid / requests /
notifications / reviews; `provision add` and `remove`; the `helper`-band Wi-Fi path against the
6-8 refusal; data, K5 and retention; notify `enable`/`pair`/`disable`; `remove --dry-run`;
fresh-install authd; `--live`.

### Fixed (each its own branch, tests, merged)

| Branch | What | Issue |
| --- | --- | --- |
| `fix/kid-session-polish` (tip `b615211`) | A docs-vs-code sweep, plus two defects it exposed: `omarchy-kids-data prune_launches` rewrote the launches log `0644`, widening a record about a kid; and `L1.lua` still bound the theme picker, whose `gum` needs a terminal the fullscreen Grid must not offer. | — |
| `fix/check-live-no-session` (`ab9da53`) | `omarchy-kids-check --live` printed **nothing** and exited 1: `pid="$(live_session_leader_pid …)"` returns 1 for "no session", and under `set -euo pipefail` that ended the report before it rendered; the session-log `grep` had the same shape. The old coverage sat behind an `unshare` gate that only opens on Linux, which is why it shipped. | #7 |
| `fix/garden-start-page` (`0b728f7`, `5db4dad`) | The Web tile opened Chromium's own Google new-tab. `render_policy_json` now derives `RestoreOnStartupURLs`/`NewTabPageLocation` from the band's first allowlisted host, so both a cold start and a new tab land in the garden. Also corrected a false `docs/web.md` claim that `launch` takes its band from `$OMARCHY_KIDS_BAND`. | #6 |
| `fix/wizard-verifier-diagnostics` (`590a7d0`) | The unavailable-verifier line said "start omarchy-kids-authd.socket", the wrong repair when the socket is listening and the *service* died. It now names both units. | #4 |
| `fix/timesup-reload` (`318cada`) | The Time's Up card never rendered: `timesup.qml`'s `FileView` never re-read the state file, so the card hid itself while the state still said `allowed` and never came back. Bound `onFileChanged: reload()` plus the launcher's 2 s timer. | #9 |

### Filed, then retracted

`#10` ("Super+Shift+K does not fire") and `#11` ("closing the exit modal strands it") were my
harness, not the product. Marker binds (`SUPER + F10`, `SUPER + SHIFT + F10`, `SHIFT + F9`, each
`touch /tmp/<marker>`) never fired even though `hyprctl binds` listed them as loaded, and the exit
modal is a layer surface that never appears in `hyprctl clients`, so "the window closed" proved
nothing. Both closed with the reasoning; the recipe now says so. `#5` (letter tiles) closed as an
image gap: the VM has no `Yaru-*` icon theme at all, and symlinking `Yaru-blue -> Adwaita` made
every real icon appear.

### Open

`#8` (`ready-for-human`): in Desktop mode the Omarchy menu's Apps submenu is the parent's whole
installed-app list — WhatsApp, X, YouTube, Discord, Neovim, Docker. The trim extension hides four
top-level ids by name and cannot scope a list generated from `.desktop` files, and the three ways
out (scope it to the band pack, hide the row, or accept it and correct the claim) are mutually
exclusive product intents, so it needs Mark, not a guess.

### State of the machines

VM left clean: portal up, no autologin drop-in (`boot:stock-autologin` and `login:autologin-dropin`
both PASS), three kids on band defaults, notifications off, relay inactive, nothing listening.
`test/all -j 4` exit 0 (68 files), dart 61, flutter 58, shellcheck and `shfmt -i 2 -ci` clean on the
merged tip.

What this pass could not do: a **real device pairing** (no full Xcode here, only Command Line Tools,
so the Flutter macOS target will not build) and the `test/live/` scenarios (rule 11 — gate runner
only). The host half of pairing is verified: `notify enable` mints the cert and fingerprint,
`pair` opens a single-use window and prints the URI, `disable` removes the cert.

### 2026-09-26 — coverage hardening (`test/all` 68 → 72 files)

The dogfood pass above ended with the suite green. It was green **on this Mac**, which is not the
target. Running it on the VM turned up nine failures and, once those were fixed, showed how much the
suite was silently not running. Seven branches, each with a check proven to fail before it was
trusted:

| Branch | What | Commit |
| --- | --- | --- |
| `fix/suite-passes-on-arch` | GNU grep reads `\t` in an ERE as a literal `t`, so `trust-boundary-test.sh`'s python-command list was empty and all three "PKGBUILD rewrites the shebang" checks failed on every Arch box while passing on BSD grep. Three more checks turned a *missing* tool (`shellcheck`, `node`) into `bad`/`fail` instead of skipping. | `46e1710`, merged `42a7fd8` |
| `test/qml-syntax` | `portal-test.sh` linted only the portal's `Main.qml`; every other QML file was exercised only by a live run. New test lints all of them, using qmllint's *exit status* (nonzero = parse error, 0 = the unresolved-import warnings our files have by construction). Both analyzers (`dart analyze`, `flutter analyze`) wired into the parent tests. | `72dd13a`, merged `a9be72d` |
| `chore/enforce-shell-lint` | AGENTS.md claimed shellcheck/shfmt clean; nothing checked it. A shipped file was four-space indented and eight test warnings had never been read — including `courier-test.sh` capturing its authd stub as `AUTH_PID` and never killing it (one leaked process per run). New `lint-test.sh` enforces the style over `bin/ lib/ initcpio/ share/ test/shell.d/ test/all`. | `39459a4`, merged `f351f77` |
| `test/command-header-conventions` | `# omarchy:summary=` on line 2 and `set -euo pipefail` for every bash command were required and unchecked. New test; needs no tools, so it runs on the VM. Its first catch was itself — a comment beginning `# shellcheck …` is parsed as a directive (SC1073). | `9f351d4`, merged `769152b` |
| `test/pkgbuild-file-coverage` | `bin/` coverage had a glob behind it; `desktop/*.desktop` and the top-level initcpio file are installed one path at a time, so a new entry would never ship and every test would still pass. | `e79af84`, merged `f099da9` |
| `test/shell.d/pkgbuild-test.sh` (the `.SRCINFO` and units sweep) | `.SRCINFO`'s `arch` was compared but not `pkgver`/`pkgrel`, and no check swept all units: a command renamed without its unit leaves a service pointing at a binary that is not there. | `f551630`, merged `756bab0` |
| `test/shell.d/docs-pointers-test.sh` | A renamed doc leaves sources pointing at a file that is not there. Checks every pointer resolves and every command names one — not 1:1, since docs are topic-grouped. | `d32002b`, merged `1d8f775` |

Lessons worth keeping:

- **The Mac suite is necessary, not sufficient.** The target is GNU grep, bash 5.3, and often no
  `node`/`shellcheck`; this Mac is the opposite. Both machines' `test/all` are now run every pass,
  and `systemd-analyze verify`, `luac`, `qmllint`, SO_PEERCRED, `unshare` and libcrypt only exist on
  the VM side, while `ash` (initramfs) needed a `busybox` container — neither machine had it. The
  guest's pacman mirror is stale (`404` on nodejs), so its missing tools cannot be installed; the
  coverage is the union of the two plus that container.
- **A "skipped" check is a check that did not run.** Four of these gaps hid behind skips or behind
  checks that only ever ran by hand.
- `systemd-analyze verify` over all 18 installed units: clean. Dart/Flutter analyzers: clean.
  Repo-wide shellcheck/shfmt across 103 files: clean.

`test/all` is 72 files, exit 0 on both platforms; the VM's own `test/all` additionally runs the
`luac`, qmllint, SO_PEERCRED and `unshare`-gated checks the Mac skips.

### 2026-09-26 (second pass) — dogfooding the shipped files: 12 fixes, and what is left

The tracker was empty at the start of this pass, so the work came from reading the code and the
docs against a real 4.0.2 install rather than from a queue. Each item below is merged into
`integration/dogfood-2026-09-19`; the merge is what is named.

| # | Finding | Fixed by |
| --- | --- | --- |
| 1 | `portal_clean_exit` could report a clean exit for a compositor still there (`hyprctl` prints "Couldn't connect" and exits 0) | waits for the instance to leave `wayland-1`; sandbox #134, merged `6bc5391` |
| 2 | `portal_reset` did one greeter wait after any branch, so a restart that fires an autologin hung it — the #103 driver's failure | bounded seat loop (greeter / restart / clean exit); #21, merged `22c98ee` |
| 3 | `lint-test` had nothing stopping a sourced library from shadowing a test's own `check`/`pass`/`fail` | static guard, verified by planting one; merged `2a228e9` |
| 4 | `mark_migrations_done` wrote a `migrations.log` **nothing in Omarchy reads**, so a fallback-provisioned kid would still see "Pending Omarchy Migrations" | Omarchy's real per-migration markers (`migrations/<script name>`); merged `0a3e9dc`, verified end to end and recorded in `f8d813b` |
| 5 | L1/L2 media keys used raw `wpctl`/`brightnessctl` because `default/hypr/bindings/media.lua` "was not in the reference material" — it exists | Omarchy's own `omarchy-audio-output-volume`/`omarchy-brightness-display`, with `locked`/`repeating`; merged `6c8125f` |
| 6 | `levels-test.sh` called `check_not_contains` without defining it; `panel-test.sh`/`wizard-test.sh` called `check`; `wizard-advanced-row-test.sh` had no `tui.sh`; `ask-test.sh`/`assert-test.sh` snapshotted with a `cksum` their PATH did not have | all four fixed, `cksum` added to the base toolset, and a tool-free guard for the class; merged `380a108` |
| 7 | `docs/bar.md` asked whether `import qs.Ui` resolves outside `$OMARCHY_PATH` (with a vendoring fallback) | confirmed it does, from Omarchy's own plugin files and `Ui/qmldir`; merged `1a3ce77` |
| 8 | The bar's "Open Kids Mode"/"Open requests" rows ran `omarchy-kids` with no tty: it printed `tui: no terminal to ask` and **exited 0**, so the rows did nothing | both go through `omarchy-launch-floating-terminal-with-presentation`; merged `a1036eb` |
| 9 | `omarchy-kids-review` accepted `--dry-run` that its header, usage and `docs/review.md` never mentioned | added to all three; merged `dc655ea` |
| 10 | `docs/bar.md` described the old polling badge and the new `status.json` one at once, and decision row 8's premise had gone stale | one bullet, and row 8 marked settled; in `a1036eb` |
| 11 | Decision rows 4 (Level 3 "hidden for v1") and the two-modes amendment ("no code until then") were answered by the tree | rows record the code that settled them; merged `2c8089c` |
| 12 | `PROGRESS.md`'s live section still said `test/all` was 65 files and still listed T45 as blocked | 73 files, and T45 moved to a "done since" line; merged `7846925` |

Verified on the try-omarchy VM, not just the stub: 104 markers for 104 migrations with
`omarchy-migrate --pending` empty (exit 1) as the kid; a clean `hl.dsp.exit()` returned the greeter
within 5s while a `loginctl terminate-session` left seat0 empty with no greeter at all;
`/usr/bin/omarchy-audio-output-volume` and `omarchy-brightness-display` are where `media.lua` binds
them and both edited level files parse under `luac`; `qs.Ui`'s `qmldir` and the third-party plugin
directory are as `docs/bar.md` now says. `omarchy-kids-ask list` answers
`omarchy-kids-ask: no open requests` for a parent (exit 0), and `omarchy-kids --requests` with it.

Lessons worth keeping:

- **A comment admitting a guess is a defect with a location.** Two of the eleven came straight out
  of `# ... guessed`, `TODO(#10)` and `UNVERIFIED:` lines, and both were settled by reading
  Omarchy's own shipped files on the VM rather than by reasoning.
- **A green test proves nothing until it can fail.** Four assertions never ran at all (an undefined
  helper prints `command not found` and sets nothing), and eight before/after comparisons compared
  empty to empty because `cksum` was missing from the base toolset. Both classes now have a guard,
  and the two are the shapes AGENTS.md's "owns its fixture" rule already warned about.
- **Docs can contradict themselves.** `docs/bar.md` carried both the old and the new badge design,
  and the decision list carried rows the code had answered. Reading the docs against the tree is
  as much a part of a pass as reading the code.
- **Do not leave something running on the shared VM.** Four `test/all` runs left behind by ssh
  commands that hit the agent tool's timeout put the 4-core guest at load ~9 and made one test look
  hung for seven minutes; and `pkill -f` issued from a command line that contains the pattern kills
  that command's own session (twice). `test/all` on the guest is a ~30–45 minute affair: it is
  slow, not stuck.

Left blocked, not worked: real device pairing (needs a second peer), `test/live/` scenarios (rule
11 keeps them to the gate runner), app store builds (no Xcode/Android SDK), and the owner's own
open decisions — `docs/phase1/DECISIONS-NEEDED.md` rows 1 (Pause), 3 (add-on model), 5 (per-app
limits), 6 (the Level 3 file-manager bind) and 7 (`dns`/`sites`, stored and not applied).
