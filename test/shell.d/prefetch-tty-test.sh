#!/bin/bash
# Issue #185: a background pacman prefetch must not inherit the wizard PTY.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WIZARD="$DIR/bin/omarchy-kids-wizard"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
LOG="$TMP/log"
mkdir -p "$STUBS" "$LOG"

cat >"$STUBS/sudo" <<'EOF'
#!/bin/bash
if [[ "$2" == "true" ]]; then exit 0; fi
if [[ "$2" == "pacman" ]]; then
  if [[ -t 0 ]]; then
    printf 'tty\n' >"__LOG__/stdin"
    exit 1
  fi
  printf 'not-tty\n' >"__LOG__/stdin"
  if IFS= read -r -t 1 value; then
    printf 'data:%s\n' "$value" >>"__LOG__/stdin"
  else
    status=$?
    if [[ "$status" == 1 ]]; then
      printf 'eof\n' >>"__LOG__/stdin"
    else
      printf 'read-status:%s\n' "$status" >>"__LOG__/stdin"
    fi
  fi
  exit 0
fi
exit 1
EOF
sed -i.bak -e "s#__LOG__#$LOG#g" "$STUBS/sudo"
rm -f "$STUBS/sudo.bak"
chmod +x "$STUBS/sudo"

python3 - "$WIZARD" "$STUBS" "$LOG" "${BASH:-$(command -v bash)}" <<'PY'
import os
import pty
import select
import signal
import subprocess
import sys
import time

wizard, stubs, log, bash = sys.argv[1:]
fragment = subprocess.check_output(
    ["sed", "-n", "/^start_prefetch()/,/^}/p", wizard], text=True)
harness = """\
set -euo pipefail
repo_and_aur_pkgs() { REPO_PKGS=(demo-package); }
REPO_PKGS=()
DRY_RUN=0
%s
start_prefetch 6-8
wait "$PREFETCH_PID"
""" % fragment
pid, master = pty.fork()
if pid == 0:
    env = {"PATH": stubs + ":/usr/bin:/bin", "TERM": "xterm-256color"}
    os.execve(bash, [bash, "--noprofile", "--norc", "-i", "-m", "-c", harness], env)

# Generous on purpose: test/all runs several files at once and this deadline kills the child, so a
# tight one turns a loaded box into a red suite (seen on the try-omarchy VM, 2026-09-26, where a
# file failed in parallel and passed alone). The run itself takes ~0.2s idle.
deadline = time.monotonic() + 60
status = None
while time.monotonic() < deadline:
    waited, raw = os.waitpid(pid, os.WNOHANG)
    if waited == pid:
        status = os.waitstatus_to_exitcode(raw)
        break
    ready, _, _ = select.select([master], [], [], 0.1)
    if ready:
        try:
            os.read(master, 4096)
        except OSError:
            pass
if status is None:
    os.killpg(pid, signal.SIGTERM)
    time.sleep(0.1)
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    _, raw = os.waitpid(pid, 0)
    raise SystemExit("harness timeout: prefetch did not finish")
os.close(master)
if status != 0:
    raise SystemExit(f"harness failed: {status}")
PY

if [[ "$(cat "$LOG/stdin")" != $'not-tty\neof' ]]; then
  echo "FAIL prefetch stdin was not an EOF-only non-tty stream"
  cat "$LOG/stdin"
  exit 1
fi
echo "ok   prefetch pacman receives EOF on stdin under owned PTY"
