**Verdict: request changes.** Six blocking findings (four Standards, two Spec), several of them
regressions or overclaims this pass introduced. Reviewed by the headless fable reviewer
(`claude-opus-5-5`, max effort) reading `git diff 5dbb933..HEAD` and the tree only — it was denied
shfmt, shellcheck, the test suite and `gh`, so nothing below is backed by a run, and the pass's
own claims about tests are what it checked against the code.

I reviewed `5dbb933..HEAD`: 48 commits (24 topic commits plus their merges), 32 files. I read the whole diff and checked each claim against the tree. This session denied running shfmt, shellcheck, the test suite, `gh issue view` (#21, #23, #10) and a few `git ls-files`/`file` calls, so everything below comes from reading and tracing code, not from a run.

These changes look right as far as I can trace them: the per-migration marker format, the bar rows going through the terminal, `portal_clean_exit` waiting for the compositor to leave, `cksum` in the base toolset, and the longer PTY deadlines.

## Standards

### Blocking

**1. `bacd496`: the migration-marker writer lets a kid-planted link steer where root writes (rule 9)** — `bin/omarchy-kids-provision:166-173`, `:201-214`
- **What's wrong:** each marker `~/.local/state/omarchy/migrations/<name>.sh` is written by stage-then-`mv -f`. None of those paths are in `kid_home_writable_paths`, the refusal list its own comment calls "the one table for this rule". `mv` without `-T` moves *into* a destination that is a symlink to a directory.
- **Why it matters:** `lib/provision-add.sh:82-87` names this exact threat: a home left behind by `remove --keep-home` after the kid had a shell.
  - If that home holds `migrations/1787815267.sh -> /etc/<dir>`, re-adding the kid passes the refusal check.
  - Root then creates a root-owned 0600 file named `.1787815267.sh.XXXXXX` inside `/etc/<dir>`.
  - The direct impact is small (an empty file with a random name). But it's a regression: the old single file, `migrations.log`, was in the refusal list.
  - The comment (`:169-170`), `docs/provision.md:224-227` and the commit all say a planted link "is replaced rather than written through". That's false for a link to a directory.
  - The planted-link test only plants at the directory (`provision-test.sh:933-944`).
- **Smallest fix:**
  - In the loop, refuse or `rm -f` any existing symlink or directory at `$state_dir/$base` before the rename. (`mv -fT` works on Arch, but the Mac suite's BSD `mv` has no `-T`.)
  - Add a test case with a link-to-directory at a marker name.
  - If this gets filed, file it privately per `SECURITY.md`.

**2. `633ee79` breaks `check-test.sh` wherever `unshare` works** — `lib/check-live.sh:165`, `lib/check-web.sh:30`
- **What's wrong:**
  - `is_root` (`lib/kids.sh:10`) runs whichever `id` comes first on `PATH`.
  - `check-test.sh` puts its `id` stub first (`:132-139`, `:275-276`), and that stub prints nothing for a bare `id -u`.
  - The same file explains this at `:586-587`: "`$EUID`, not `id -u` … `id -u` here is empty".
  - So under `as_root` (`:850-919`), the live section now reports "isn't root".
- **Why it matters:**
  - Every live-row assertion in that block fails on the VM and on a real Omarchy box. AGENTS says the suite must pass there.
  - The commit's "check-test … all pass" only holds on Darwin, which skips the block.
  - `PROGRESS.md:32` ("73 files green on the Mac and the VM") was written before this commit.
  - The commit also says rule 9 means reading `/usr/bin/id` by absolute path, which `is_root` doesn't do.
- **Smallest fix:** make the `id` stub pass a bare `-u` through to the real `id`, then run `check-test.sh` on the VM.

**3. A test that prints FAIL but still exits 0 survives in the very file the new lint guard was built for** — `test/shell.d/live-lib-test.sh:66`
- **What's wrong:** at top level, `… && fail "…"` calls `test/live/lib.sh:674`'s `fail`. That one sets `LIVE_FAIL`, not this file's `fail` flag (set at `:39`, used in the exit at `:412`). So this assertion can never fail the file.
- **Why the guards miss it:**
  - Guard 1 (`lint-test.sh:32-51`) only checks helpers the file itself defines as functions.
  - Guard 2 (`:53-77`) counts `test/live/lib.sh`'s `ok`/`fail`/`check` as "defined" for any file that sources it (`:64-69`). That is exactly the shadowing guard 1 exists to catch.
  - Guard 2 also only matches calls at the start of a line (`:76`). About 300 `&& pass` / `|| fail` / `then fail` call sites across 42 files are invisible to it.
- **Claims that go too far:**
  - `CHANGELOG.md:310` says the suite "can no longer carry an assertion that never runs", and `c3e93cb`'s title says the same.
  - The CHANGELOG credits the lint with catching `wizard-advanced-row-test.sh`, but that bug was an undefined `tui_desktop_label`, which the guard doesn't look for.
  - `loop-report.md:2801` says "Both classes now have a guard", but nothing guards against a tool missing from `KIDS_BASE_TOOLS`.
- **Smallest fix:**
  - Define a top-level `fail_` in `live-lib-test.sh` and use it at `:66`.
  - Stop counting the live library's helpers as the file's own; mark the deliberate calls at `:165-180` explicitly.
  - Also match calls after `&&`, `||`, `then`, `else` and `;`.
  - Rewrite the CHANGELOG line to say what the guard actually checks.

**4. `docs/vm-dogfood.md` tells agents to do what their standing orders forbid**
- **What's wrong:** it commits the dogfood-VM recipe: how to launch QEMU (`:13-26`) and how to drive the VM with `scripts/vm-qmp.sh` (`:49-56`).
  - `.opencode/loop-prompt.md:13-16` says that recipe "lives in `.local/VM-DOGFOOD.md` -- untracked, never commit it", and "Never run anything under `test/live/` or `scripts/vm-*.sh`, never launch QEMU".
  - AGENTS rule 11 also says "no `scripts/vm-*.sh` runs from a draft".
- **Why it matters:** the doc's own line "nothing here changes that" (`:9`) is false, and it is written for the next pass. This is the public repo, so if the branch was pushed, the recipe is now public.
- **Smallest fix:** move the launch and QMP sections back to `.local/`. Keep only the "leave it as you found it" lessons, or have the owner amend rule 11 first.

### Should fix

- **The trust-boundary test still can't see `$EUID` checks.** `trust-boundary-test.sh:274-281` only looks for `id -u`, which is how the two `$EUID` checks passed "every root check goes through … is_root". `633ee79` fixed those two, not the guard. Add `\bE?UID\b`, exempting the documented copy in `omarchy-kids-parent-auth`.
- **"shfmt and shellcheck are clean" is unverified.** `PROGRESS.md:32-33` restates it, but by the repo's own notes neither machine ran the tools:
  - The Mac has no shellcheck (`loop-prompt.md:33`).
  - The VM can't install it (`vm-dogfood.md:62-64`).
  - `lint-test.sh` skips the whole gate if either tool is missing.
  - So none of the new shell code in this range has been linted. Run the tools somewhere once, or drop the claim.
- **`portal_reset` can pick the wrong session.** `test/live/lib.sh:418` takes the first seat0 row, whatever its class or state.
  - After a clean exit, a session whose processes linger stays listed as `closing`. The disowned `omarchy-kids-time daemon`, which loops forever, is one such process (`session-start:116-117`, `time:198`).
  - The next round then waits 45 seconds on a user with no compositor and reports a successful reset as a failure.
  - The test stub (`live-lib-test.sh:239-247`) makes that session vanish instantly; the hand probe never showed that happens.
  - Separately, the result of the third attempt is never checked (`:439`).
  - **Fix:** prefer the greeter-class row (or ask `loginctl show-seat seat0 -p ActiveSession`), skip `closing` rows, and check the seat once more after the last attempt.
- **`test/all` keeps the wrong lines as evidence.** At `:87` it keeps `tail -3`, which is usually the last few checks plus `RESULT: FAIL`. A FAIL in the middle of a file is still lost, so `CHANGELOG.md:317` ("the summary quotes the evidence") overclaims. The summary at `:106` still says every retried file shares state, although `97e890c` blamed load. Use `grep -m3 '^ *FAIL'` with `tail` as the fallback, and reword the summary.
- **Process.** AGENTS says "Nothing commits unreviewed", and `loop-prompt.md:43-47` says not to commit root, security or trust-boundary changes before review. No commit here records a review, including `bacd496`, `633ee79` and `b31a2b3`; findings 1 and 2 are exactly what that review is for. The loop also merged its own 24 branches, while `loop-prompt.md:10` says merges stay with the owner's gate. Worth confirming that was intended.

### Nitpicks

- **`mark_migrations_done` details:**
  - It marks every file in the migrations directory (`:166-167`), though its docs say Omarchy only walks `*.sh`.
  - The comment at `:176-177` says the markers must be the kid's, but they stay root-owned 0600.
  - The `chown` it now depends on is silenced with `|| true`.
  - It reads `OMARCHY_MIGRATIONS_DIR` from the environment while rejecting `OMARCHY_MIGRATION_STATE` on rule-9 grounds, and `provision-test.sh:652` exports a variable the allowlist doesn't police.
- **Comment density.** AGENTS allows 0-2 lines per function. These carry dated narrative instead: `provision:145-157`, `KidsModule.qml:21-25`, `L1.lua:100-105` and `:149-154`, `levels-test.sh:26-28` and `:44-46`, `panel-test.sh:56-58`, `wizard-test.sh:509-510`.
- **Stale comments.** `check-test.sh:797` and `:842` still describe an "EUID gate".
- **Zero deadline.** With a deadline of 0, `portal_clean_exit` never checks after sending the exit (`test/live/lib.sh:468`).
- **Bundled commits.** `82972c8` and `030a8ed` each mix several topics; AGENTS asks for one topic per commit.
- **The requests row may flash and close.** `omarchy-kids-bar:239-259` adds its own "press Enter" prompt because it assumes the terminal helper closes the window on exit. The new requests row has no prompt, so if that assumption is right, the list closes before the parent can read it.

## Spec

### Blocking

**5. The media-key "on-screen feedback" can't happen at Levels 1 and 2, and the new binds were never tried there** — `L1.lua:149-154`, `L2.lua:97-99`, `CHANGELOG.md:290-295`, `docs/levels.md:353-360`
- **What's wrong:**
  - In Omarchy 4 the on-screen display is part of `omarchy-shell` (`research/01-omarchy-platform.md:8,37`).
  - Levels 1 and 2 never start `omarchy-shell` (`omarchy-kids-session-start:95-98`).
  - `L2.lua:118-123` itself says no Omarchy shell runs there and `$OMARCHY_PATH` is unset.
- **Why it matters:** the stated benefit can't happen. Whether the wrappers still change volume without the shell was never exercised; `levels.md` admits "not exercised live". The old `wpctl` binds already capped volume at 100% (`-l 1`), so the "volume ceiling" benefit isn't new either.
- **Smallest fix:** press the five keys in a live Level 1 session. If the wrappers need the shell, revert Levels 1 and 2 to `wpctl`/`brightnessctl`. Strike the on-screen-feedback claim either way.

**6. `omarchy-kids-review --dry-run` doesn't do what its new help says** — `bin/omarchy-kids-review:51-52`, `docs/review.md:40-41`
- **What's wrong:** the help says `--dry-run` "forces the preview whatever DRY_RUN says". But `:29` hard-codes `DRY_RUN=1` (the environment is never read), and the flag loop at `:364-383` lets the last flag win. So `approve kid id --dry-run --apply` really runs.
- **Why it matters:** AGENTS rule 8 says `--dry-run` always forces the preview, and making the help accurate was the whole point of `1e3e1da`.
- **Smallest fix:** make `--dry-run` win regardless of order (set a flag during parsing and apply it after the loop), and drop the wording about the environment.

### Should fix

- **The decision record misstates the owner's decisions.**
  - `DECISIONS-NEEDED.md:71` says the two-modes amendment's owner section answers "all five" questions, including the labels "App grid"/"Desktop".
    - That section (`SPEC-AMENDMENT-two-kid-modes.md:188-195`) has three items and says "1=grid, 2=desktop, 3=stock".
    - The owner's later label choice was "Simple Computer"/"Full Desktop" (`:95-97`).
    - SPEC A11 (2026-09-24) wins, but the row should say so rather than hide the conflict.
  - Row 8 (`:78`) says "Settled, option 1". The owner chose option 3 on 2026-09-22 (`:119-125`; `loop-prompt.md:76-78`).
  - `loop-report.md:2812-2816` lists five open owner decisions (rows 1, 3, 5, 6 and 7), but at least four are already decided:
    - Pause is decided (§6 row 2), and per-app limits are decided (§6 row 5).
    - §9 already answered rows 6 and 7.
    - Two of those are approved work the tree hasn't done yet: wiring dns/sites, and keeping the Level 3 terminal (`L3.lua:61` still unbinds it).
- **T45 is marked done (`PROGRESS.md:39-41`), but the Grid half isn't built and the Level 3 half is unverified.**
  - `SPEC.md:367` (Appendix E) binds the theme chord in the Grid, and the kid-themes amendment says "Built … at Grid".
  - `L1.lua` deliberately doesn't bind it (`levels.md:93`).
  - The revived `levels-test.sh:105-106` now pins the opposite of Appendix E, directly under a line labelled "exactly the Appendix E Level 1 set" (`:104`).
  - `hl.unbind` still "remains unshown" (`levels.md:310-316`).
  - Keep T45 blocked, and raise a spec amendment for the conflict between Appendix E and R-DESK-3.
- **`docs/GOAL.md:22-28` contradicts the repo about how the release pictures were taken.**
  - It says `grim` produced `docs/media/` and QMP "was not the route any committed picture came from".
  - But `docs/media/README.md:3` names `scripts/media-driver.sh`, whose screenshots are QMP `screendump` (`test/live/lib.sh:109-114`).
  - The recorded QMP failure is only the X11 greeter (`loop-report.md:1200-1204`).
  - Say that instead.
- **The R-SEC-6 guard is narrower than its label** (`trust-boundary-test.sh:504-520`, merged as "R-SEC-6 is enforced").
  - It misses `passwd -l root` and `usermod -p … root`.
  - It misses `printf 'root:%s\n' … | chpasswd`, which is the tree's own idiom with a literal root.
  - It misses `Defaults rootpw`, the design SPEC §9 explicitly rejects.
  - It skips `share/`, `PKGBUILD` and `omarchy-kids.install`.
  - Widen the pattern and the scan, and make the pass message say what's actually checked.

### Nitpicks

- **Stale pointers.** `lib/provision-add.sh:212-213` and `docs/provision.md:129` still point at the old "Known gap" section, and `:199` still says "guessed markers".
- **`docs/bar.md` now contradicts itself.** `:58-67` and `:261-265` say loading and drawing the plugin is unverified, while `:306-313` records it loading and drawing on 2026-09-02, with `import qs.Ui` in place since `2df593a`.
- **Counts and details that are off:**
  - "Two of the eleven" at `loop-report.md:2796` sits under a heading of 12 fixes.
  - The "eight" cksum comparisons are really four; ask-test's `before` at `:750` is never compared.
  - `L2.lua` has no `fullscreen = true` rule, though the CHANGELOG says both files use it.
  - Mute isn't `repeating` (`levels.md:353`).
  - The "tui: no terminal" message only applied to the Open Kids Mode row, not both.
  - The guest runtime is given as both 15–45 and 30–45 minutes.
- **`live-tests.md` overstates the evidence.** It says "Verified live" next to the new `portal_reset`, but the new loop itself never ran live. `f0bb773`'s account of how the old helper failed doesn't match the old code, which already clean-exited `$LIVE_OWNER_ACCOUNT` after a restart.

**Summary:**
- **Standards:** 4 blocking, 5 should-fix, 6 nitpicks. The worst is the rule-9 gap in `mark_migrations_done` (1).
- **Spec:** 2 blocking, 4 should-fix, 4 nitpicks. The worst is the media-key change (5): it claims on-screen feedback Levels 1 and 2 can't show, and it was never tried in a kid session.
