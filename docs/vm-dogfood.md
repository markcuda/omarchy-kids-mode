# The dogfood VM on the Mac (`try-omarchy`)

A second opinion to `docs/laptop-runbook.md`'s §7, which is about the *laptop's* QEMU use of
Omarchy's own `bin/omarchy-vm` harness. This one is about the guest the earlier dogfooding loops
drove from the Mac: a plain Omarchy 4.x install in QEMU, used to check the things a bare dev Mac
cannot (systemd, `cryptsetup`, SO_PEERCRED, `luac`, `qmllint`, GNU grep, bash 5).

It is a **dogfooding** guest. The gate-runner scenarios stay with `test/live/` and AGENTS.md's
rule 11; nothing here changes that.

## Launching and reaching it

```sh
OMARCHY_QEMU_GPU_CPUS=4 OMARCHY_QEMU_GPU_MEMORY_MIB=4096 \
OMARCHY_QEMU_GPU_PORT_FORWARDS=tcp:2222:22 \
  nohup bash "$HOME/Applications/Try Omarchy.app/Contents/Resources/scripts/run-qemu-gpu.sh" \
    "$HOME/Applications/Try Omarchy.app/Contents/Resources/guest" >/tmp/vm-launch.log 2>&1 &
```

- The port-forward preset both maps `127.0.0.1:2222` to the guest's sshd and appends
  `tryomarchy.ssh_access=1` to the kernel command line, which enables `sshd.service`; without it
  there is nothing to connect to.
- The launcher needs `sysctl` on `PATH` (put `/usr/sbin` first) or it exits without a word.
- `ssh -p 2222 <guest-user>@127.0.0.1`, key-based. Use `-o ConnectTimeout=10` so a closed VM fails
  fast rather than hanging an agent turn.
- The guest's sudo password is the owner's to give; it is not written down here, and it has changed
  at least once mid-pass (a rejected password is not a broken VM — check before rebuilding one).

## Leaving it as you found it

Every one of these has bitten at least one pass:

- **One suite at a time.** Four `test/all` runs started by ssh commands that had hit a tool
  timeout put the 4-core guest at load ~9 and made a test look hung for seven minutes. It was not
  hung; it was starved.
- **`test/all` on the guest is slow, not stuck** — roughly 15–45 minutes, because several test
  files run the full `omarchy-kids-assert` dozens of times each and every live check costs more
  there than on the Mac. Watch the `done <file> (n/73)` progress lines before concluding anything.
- **Kill leftovers from a script file**, never with `pkill -f`/`pgrep -f` issued from the ssh
  command line: the pattern matches that command line and kills the caller's own shell. (Sweep the
  scratch tree as well — `tree/bin/omarchy-kids-*` — not only the test files.)
- **Transfer with `git archive`.** `tar .` of the working tree carries build artifacts and xattrs:
  one tree copy was 385 MB against `git archive`'s 24 MB, ten of them filled the 24 GB disk, and
  the next `scp` died with `write remote: Failure` after 255 KB. Delete the tree when the run ends.
- Nothing under `/etc` on the Mac; on the guest, real runs are fine (`DRY_RUN=0`), but drop any
  autologin/apk/theme drop-ins you planted and confirm `ls /etc/sddm.conf.d/` is back to
  `zz-omarchy-kids-theme.conf` alone.

## Driving it

- **QMP** (`/tmp/omarchy-qemu-gpu.*/qmp.sock`) takes `input-send-event`, with `vmkeys.py` and
  `vmclick.py` as the thin wrappers. It sends keys to the focused client and **cannot press an
  Omarchy keybind** (Super+… is intercepted above the input layer the events reach) — do not
  conclude a keybind is broken from QMP.
- **Screenshots**: `grim` inside a Wayland session; the SDDM greeter is X11, so capture it with
  `import` on `:0` as the `sddm` user with its own `xauth` (QMP `screendump` returns black for it).
- **Overlays (ask, exit, Time's Up) are layer surfaces**, so they never appear in `hyprctl
  clients`; and a foreground `omarchy-kids-ask`/`omarchy-kids-exit` blocks the shell that starts
  it — use `setsid … </dev/null &`.
- The guest's pacman mirror was stale (`404` on `nodejs`), so `node`, `shellcheck` and `qmllint`
  cannot be installed there. That is why the suite's skips on the guest are mostly expected; the
  checks that *do* run there are the tool-gated ones the Mac lacks.

## What that VM has actually settled

Recorded here because each one closed a doc's "unverified": the migration markers against the real
`omarchy-migrate` (`docs/provision.md`), the media-key wrappers and `fullscreen = true` against
Omarchy's own Hyprland config (`docs/levels.md`), `qs.Ui` resolving for a third-party plugin
against `plugin-registry` and `shell/Ui/qmldir` (`docs/bar.md`), and the seat behaviour behind a
clean exit versus a `loginctl terminate-session` (`docs/live-tests.md`).
