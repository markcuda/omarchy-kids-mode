#!/bin/bash
# Regression for issue #180: R-WIZ-3, R-WIZ-9, I-5, I-6.
# App-list iteration must leave the interactive input channel available to
# Gum and must propagate real confirm errors through both callers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
mkdir -p "$STUBS"
cat >"$STUBS/gum" <<'GUM'
#!/bin/bash
case "${1:-}" in
  style) exit 0 ;;
  confirm)
    count=0
    [[ -r "${GUM_COUNT_FILE:-}" ]] && count=$(cat "$GUM_COUNT_FILE")
    count=$((count + 1))
    [[ -n "${GUM_COUNT_FILE:-}" ]] && printf '%s\n' "$count" >"$GUM_COUNT_FILE"
    if [[ -n "${GUM_FAIL_AFTER:-}" && "$count" -gt "$GUM_FAIL_AFTER" ]]; then
      exit "${GUM_FAIL_RC:-2}"
    fi
    [[ "${GUM_RC:-0}" == 0 ]] || exit "$GUM_RC"
    [[ -t 0 ]] || exit 1
    exit 0
    ;;
  *) exit 0 ;;
esac
GUM
cat >"$STUBS/clear" <<'CLEAR'
#!/bin/bash
:
CLEAR
cat >"$STUBS/tput" <<'TPUT'
#!/bin/bash
[[ "${1:-}" == cols ]] && printf '%s\n' 80
TPUT
chmod +x "$STUBS"/*
export PATH="$STUBS:$PATH"
GUM_RC=0
export GUM_RC

if [[ "${1:-}" == "" ]]; then
  pty_out="$(
    python3 - "$0" <<'PY'
import os
import pty
import select
import signal
import sys
import time

script = sys.argv[1]
pid, fd = pty.fork()
if pid == 0:
    os.execv('/bin/bash', ['/bin/bash', script, '--pty'])
chunks = []
# Generous on purpose: test/all runs several files at once and expiry here SIGKILLs the inner run,
# so a tight deadline turns a loaded box into a red suite (seen on the try-omarchy VM, 2026-09-26:
# this file failed in parallel and passed alone). The inner run takes ~0.9s idle.
deadline = time.monotonic() + 120
status = None
try:
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.1)
        if ready:
            try:
                data = os.read(fd, 4096)
            except OSError:
                data = b''
            if data:
                chunks.append(data)
        if status is None:
            done, child_status = os.waitpid(pid, os.WNOHANG)
            if done:
                status = child_status
        if status is not None and not ready:
            break
        if status is not None and ready and not data:
            break
finally:
    if status is None:
        # The PTY child owns this session and process group.
        os.killpg(pid, signal.SIGKILL)
        _, status = os.waitpid(pid, 0)
    os.close(fd)
sys.stdout.buffer.write(b''.join(chunks))
sys.exit(os.waitstatus_to_exitcode(status))
PY
  )" || {
    printf '%s\n' "$pty_out"
    exit 1
  }
  grep -q 'PASS interactive app picker retains Gum stdin' <<<"$pty_out"
  grep -q 'PASS confirm error propagates through both callers' <<<"$pty_out"
  bash "$0" --file
  printf '%s\n' 'PASS PTY reproduction completed'
  exit 0
fi

extract_apps_pick_walk() {
  awk '
    /^apps_pick_walk\(\) \{/ { inside=1 }
    inside {
      opens=gsub(/\{/, "{")
      closes=gsub(/\}/, "}")
      depth += opens - closes
      print
      if (depth == 0) exit
    }
  ' "$ROOT/bin/omarchy-kids-wizard"
}
eval "$(extract_apps_pick_walk)"
BAND=6-8 DISPLAY_NAME=kid-ben
TOTAL_STEPS=10
# shellcheck disable=SC2329 # invoked by the extracted production function
pack_field() { printf '%s\n' gcompris tuxpaint; }
app_label_for() { printf '%s' "$2"; }

# The actual renderer owns the confirm call; the Gum fixture refuses a pipe,
# reproducing the process-substitution collision on the old implementation.
# shellcheck disable=SC1091
source "$ROOT/lib/tui.sh"
TUI_C_ACCENT=accent TUI_C_FG=foreground TUI_C_MUTED=muted TUI_C_ERROR=error
TUI_FOOTER_DEFAULT='Enter continue · Esc back · Ctrl+C leave (nothing changes)'
export OMARCHY_KIDS_TUI_PLAIN=1

if [[ "${1:-}" == "--file" ]]; then
  TUI_MODE="file"
  TUI_HAVE_GUM="0"
  TUI_ANSWERS=(yes no)
  TUI_ANSWERS_I=0
  TUI_REPLY=''
  if ! apps_pick_walk 1 1; then
    echo 'FAIL file app picker returned an unexpected error'
    exit 1
  fi
  [[ "$TUI_REPLY" == gcompris ]] || {
    echo 'FAIL file answers did not follow app rows'
    exit 1
  }
  printf '%s\n' 'PASS file answers remain available to app picker'
  exit 0
fi

TUI_MODE=interactive TUI_HAVE_GUM=1
TUI_REPLY=''
apps_pick_walk 1 1
[[ "$TUI_REPLY" == gcompris,tuxpaint ]] || {
  echo 'FAIL interactive app picker lost selections'
  exit 1
}
printf '%s\n' 'PASS interactive app picker retains Gum stdin'

GUM_RC=0
GUM_COUNT_FILE="$TMP/gum-count"
GUM_FAIL_AFTER=1
GUM_FAIL_RC=2
export GUM_COUNT_FILE GUM_FAIL_AFTER GUM_FAIL_RC
set +e
apps_pick_walk 1 1
rc=$?
set -e
[[ "$rc" == 2 ]] || {
  echo "FAIL Gum error rc=$rc, want 2"
  exit 1
}
[[ "$(cat "$GUM_COUNT_FILE")" == 2 ]] || {
  echo 'FAIL picker did not retain partial prompt progress'
  exit 1
}

GUM_FAIL_RC=130
: >"$GUM_COUNT_FILE"
GUM_FAIL_AFTER=0
set +e
apps_pick_walk 1 1
rc=$?
set -e
[[ "$rc" == 130 ]] || {
  echo "FAIL Gum cancellation rc=$rc, want 130"
  exit 1
}

# A package-list read failure must also leave the previous reply untouched.
pack_field() { return 1; }
TUI_REPLY=existing
set +e
apps_pick_walk 1 1
rc=$?
set -e
[[ "$rc" == 2 ]] || {
  echo "FAIL package-list error rc=$rc, want 2"
  exit 1
}
[[ "$TUI_REPLY" == existing ]] || {
  echo 'FAIL package-list error cleared reply'
  exit 1
}

# Both production callers must preserve their existing selection on a real
# picker error instead of assigning an empty TUI_REPLY.
# shellcheck disable=SC1091
source "$ROOT/lib/wizard-advanced.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/wizard-screens.sh"
apps_pick_walk() { return 2; }
tui_screen_choose() {
  TUI_REPLY=pick
  return 0
}
ALLOWLIST_IDS=gcompris
if screen_apps; then
  echo 'FAIL Simple caller swallowed picker error'
  exit 1
fi
[[ "$ALLOWLIST_IDS" == gcompris ]] || {
  echo 'FAIL Simple caller cleared selection'
  exit 1
}
if adv_edit_allowlist 1 1; then
  echo 'FAIL Advanced caller swallowed picker error'
  exit 1
fi
[[ "$ALLOWLIST_IDS" == gcompris ]] || {
  echo 'FAIL Advanced caller cleared selection'
  exit 1
}
apps_pick_walk() { return 130; }
ALLOWLIST_IDS=gcompris
set +e
screen_apps
rc=$?
set -e
[[ "$rc" == 130 ]] || {
  echo "FAIL Simple caller cancellation rc=$rc, want 130"
  exit 1
}
[[ "$ALLOWLIST_IDS" == gcompris ]] || {
  echo 'FAIL Simple caller cleared on cancellation'
  exit 1
}
ALLOWLIST_IDS=gcompris
set +e
adv_edit_allowlist 1 1
rc=$?
set -e
[[ "$rc" == 130 ]] || {
  echo "FAIL Advanced caller cancellation rc=$rc, want 130"
  exit 1
}
[[ "$ALLOWLIST_IDS" == gcompris ]] || {
  echo 'FAIL Advanced caller cleared on cancellation'
  exit 1
}
printf '%s\n' 'PASS confirm error propagates through both callers'
