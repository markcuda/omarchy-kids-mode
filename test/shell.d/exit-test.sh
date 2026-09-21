#!/bin/bash
# Tests bin/omarchy-kids-exit and bin/omarchy-kids-super-tap (SPEC.md
# R-EXIT-1..6). This is the shell half of issue #16 -- share/exit-modal/
# shell.qml is UNTESTED (no Quickshell here at all; see that file's own
# header) and has no test in this suite.
#
# Fully self-contained: quickshell, hyprctl, loginctl, pgrep, runuser, id,
# and omarchy-kids-conf are fakes on a stub PATH that only log their argv
# (same shape as test/shell.d/provision-test.sh's stub() helper), never
# touching a real Hyprland/Quickshell/systemd session. --finish --kid's
# own root check is exercised against the real, unstubbed `id -u` (the
# test runner's own, non-root, same convention as time-test.sh's
# root checks) before `id` gets stubbed for
# everything after.
# shellcheck disable=SC2015 # "A && B || C" below is always used with B, C that can't fail
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
# Both commands run from a scratch tree: each resolves its siblings from
# its own `readlink -f "$0"` and nothing else, so a stub omarchy-kids-conf
# (and, for super-tap, a stub omarchy-kids-exit) is *placed* beside them
# rather than exported (AGENTS.md, "The trust boundary").
EXIT_BIN=""
TAP_BIN=""

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2', got '$1')"; fi
}
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STUBS="$TMP/stubs"
LOG="$TMP/argv.log"
SHARE="$TMP/share"
mkdir -p "$STUBS" "$SHARE/exit-modal" "$SHARE/avatars"
touch "$LOG"
touch "$SHARE/exit-modal/shell.qml"

# stub NAME EXTRA — see provision-test.sh for the full rationale; same
# helper, copied rather than shared (each test/shell.d file is
# self-contained).
stub() {
  local name="$1" extra="${2:-}" f="$STUBS/$1"
  cat >"$f" <<'EOF'
#!/bin/bash
{ printf '%s' "__NAME__"; printf ' %s' "$@"; printf '\n'; } >> "__ARGVLOG__"
EOF
  [[ -n "$extra" ]] && printf '%s\n' "$extra" >>"$f"
  echo 'exit 0' >>"$f"
  sed -i.bak -e "s#__NAME__#$name#g" -e "s#__ARGVLOG__#$LOG#g" "$f"
  rm -f "$f.bak"
  chmod +x "$f"
}

kids_tree "$TMP/tree" "$ROOT_DIR"
EXIT_BIN="$TMP/tree/bin/omarchy-kids-exit"
TAP_BIN="$TMP/tree/bin/omarchy-kids-super-tap"
kids_set_const "$EXIT_BIN" ETC "$TMP/etc/omarchy-kids"
kids_set_const "$EXIT_BIN" SHARE "$SHARE"
kids_set_const "$EXIT_BIN" RUN "$TMP/default-runtime"
kids_set_const "$EXIT_BIN" RUN_USER_ROOT "$TMP/default-run-user"
kids_set_const "$EXIT_BIN" QUICKSHELL_BIN "$STUBS/quickshell"
kids_set_const "$TAP_BIN" RUN "$TMP/default-tap-runtime"

stub quickshell
stub hyprctl
stub loginctl
# pgrep "not found" by default (exit 1: no modal already up); flipped to
# "found" (exit 0) for the one test that needs it.
stub pgrep 'exit 1'
kids_stub "$TMP/tree" omarchy-kids-conf <<EOF
#!/bin/bash
printf 'omarchy-kids-conf %s\n' "\$*" >> "$LOG"
case "\$3" in
  name) echo "Ada Lovelace" ;;
  avatar) echo "fox" ;;
esac
exit 0
EOF

# `id -un` decides which account this is now, never the environment.
kids_id_stub "$STUBS" kid-ada "$(id -u)"

export PATH="$STUBS:$PATH"

# --- --help / bad args ------------------------------------------------

"$EXIT_BIN" --help >/dev/null 2>&1
check_eq "$?" 0 "--help exits 0"
"$EXIT_BIN" --nonsense >/dev/null 2>&1
check_eq "$?" 2 "an unknown flag exits 2"

# Static QML wording (the modal itself is not run here; see this file's
# own header): the subline must say where Finish actually lands.
check_contains "$(cat "$ROOT_DIR/share/exit-modal/shell.qml")" "return to the login screen" \
  "exit modal: the subline says Finish returns to the login screen"
check_not_contains "$(cat "$ROOT_DIR/share/exit-modal/shell.qml")" "switch to your desktop" \
  "exit modal: no longer claims it switches to a desktop"

# --- --open: execs quickshell with the env from omarchy-kids-conf --------

: >"$LOG"
env -u OMARCHY_KIDS_NAME -u OMARCHY_KIDS_AVATAR "$EXIT_BIN" --open >/dev/null 2>&1
st=$?
argv="$(cat "$LOG")"
check_eq "$st" 0 "--open exits 0"
check_contains "$argv" "quickshell -p $SHARE/exit-modal/shell.qml" "--open execs quickshell with the exit-modal path"
check_contains "$argv" "omarchy-kids-conf get kid-ada name" "--open reads the kid's name from omarchy-kids-conf"
check_contains "$argv" "omarchy-kids-conf get kid-ada avatar" "--open reads the kid's avatar id from omarchy-kids-conf"

# A no-args invocation defaults to --open too (this is what Super+Shift+K
# and the triple-tap actually bind, per share/hyprland/L1.lua etc.)
: >"$LOG"
"$EXIT_BIN" >/dev/null 2>&1
st=$?
check_eq "$st" 0 "no arguments defaults to --open and exits 0"
check_contains "$(cat "$LOG")" "quickshell -p $SHARE/exit-modal/shell.qml" "no-args --open still execs quickshell"

# Confirm the exact env quickshell would see (a wrapper script that dumps
# env, dropped in as "quickshell" for one call): this is the only way to
# check exec'd env vars, since the stub's own argv log can't see them.
cat >"$STUBS/quickshell" <<'EOF'
#!/bin/bash
{
  echo "OMARCHY_KIDS_ACCOUNT=$OMARCHY_KIDS_ACCOUNT"
  echo "OMARCHY_KIDS_NAME=$OMARCHY_KIDS_NAME"
  echo "OMARCHY_KIDS_AVATAR=$OMARCHY_KIDS_AVATAR"
} > "$OMARCHY_KIDS_TEST_ENV_DUMP"
EOF
chmod +x "$STUBS/quickshell"
ENV_DUMP="$TMP/env-dump"
OMARCHY_KIDS_TEST_ENV_DUMP="$ENV_DUMP" "$EXIT_BIN" --open >/dev/null 2>&1
env_out="$(cat "$ENV_DUMP" 2>/dev/null || true)"
check_contains "$env_out" "OMARCHY_KIDS_ACCOUNT=kid-ada" "--open exports OMARCHY_KIDS_ACCOUNT"
check_contains "$env_out" "OMARCHY_KIDS_NAME=Ada Lovelace" "--open exports OMARCHY_KIDS_NAME from omarchy-kids-conf"
check_contains "$env_out" "OMARCHY_KIDS_AVATAR=$SHARE/avatars/fox.svg" "--open exports OMARCHY_KIDS_AVATAR as a path under \$SHARE/avatars"

stub quickshell # restore the plain argv-logging stub for the rest of the suite

# --- --open: a no-op if a modal already looks open (review §1.9) ---------
#
# It is a pidfile now, not `pgrep -f "quickshell -p <path>"`: that matched
# any process a kid could start with that string in its argv, which let a
# kid wedge the parent's exit modal shut forever.

MODAL_RUN="$TMP/exit-runtime"
kids_set_const "$EXIT_BIN" RUN "$MODAL_RUN"
mkdir -p "$MODAL_RUN"

# A live pid whose /proc comm is not quickshell (or which has no /proc at
# all, as on macOS) is exactly the kid's decoy: it must NOT block the modal.
sleep 30 &
decoy=$!
printf '%s\n' "$decoy" >"$MODAL_RUN/exit-modal.pid"
: >"$LOG"
"$EXIT_BIN" --open >/dev/null 2>&1
kill "$decoy" 2>/dev/null
wait "$decoy" 2>/dev/null
if grep -qE '^quickshell ' "$LOG"; then
  pass "a live decoy process cannot block the exit modal"
else
  # On Linux the decoy's comm is "sleep", so the modal opens. Where
  # /proc is absent the pidfile is trusted, which is the documented
  # residual: report it honestly rather than pretending it passed.
  if [[ -d /proc ]]; then
    fail "a decoy process blocked the exit modal (review §1.9)"
  else
    pass "no /proc here: pidfile owner check is Linux-only (documented residual)"
  fi
fi

# A stale pidfile (dead pid) never blocks the modal either.
rm -f "$MODAL_RUN/exit-modal.pid"
printf '%s\n' "999999" >"$MODAL_RUN/exit-modal.pid"
: >"$LOG"
"$EXIT_BIN" --open >/dev/null 2>&1
if grep -qE '^quickshell ' "$LOG"; then
  pass "a stale pidfile never blocks the exit modal"
else
  fail "a stale pidfile blocked the exit modal"
fi

# --open records its own pid, so a second --open can see it.
rm -f "$MODAL_RUN/exit-modal.pid"
: >"$LOG"
"$EXIT_BIN" --open >/dev/null 2>&1
if [[ -s "$MODAL_RUN/exit-modal.pid" ]]; then
  pass "--open writes the modal pidfile"
else
  fail "--open did not write the modal pidfile"
fi
rm -rf "$MODAL_RUN"
kids_set_const "$EXIT_BIN" RUN "$TMP/default-runtime"

# --- --finish: hyprctl dispatch exit, then loginctl terminate-session -----

: >"$LOG"
export XDG_SESSION_ID="c7"
OMARCHY_KIDS_EXIT_WAIT=0 "$EXIT_BIN" --finish >/dev/null 2>&1
st=$?
argv2="$(cat "$LOG")"
check_eq "$st" 0 "--finish exits 0"
check_contains "$argv2" "hyprctl dispatch hl.dsp.exit()" "--finish asks Hyprland to exit with the Lua dispatcher"
check_contains "$argv2" "loginctl terminate-session c7" "--finish calls loginctl terminate-session with \$XDG_SESSION_ID"
# hyprctl's line must come first: Hyprland has to actually be asked to
# exit before the session it belongs to is torn down.
hyprctl_line="$(grep -n hyprctl <<<"$argv2" | cut -d: -f1)"
loginctl_line="$(grep -n loginctl <<<"$argv2" | cut -d: -f1)"
[[ "$hyprctl_line" -lt "$loginctl_line" ]] && pass "--finish: hyprctl runs before loginctl" ||
  fail "--finish: hyprctl should run before loginctl (got hyprctl on line $hyprctl_line, loginctl on $loginctl_line)"

# --- --finish: the compositor left on its own -> no terminate-session ----

: >"$LOG"
OMARCHY_KIDS_EXIT_WAIT=2 "$EXIT_BIN" --finish >/dev/null 2>&1
st=$?
argv3="$(cat "$LOG")"
check_eq "$st" 0 "--finish exits 0 once Hyprland is gone"
grep -q "loginctl terminate-session" <<<"$argv3" &&
  fail "--finish must not terminate the session when Hyprland already exited" ||
  pass "--finish leaves loginctl alone when Hyprland already exited"

# --- --finish: hyprctl missing is best-effort, loginctl still runs --------

rm -f "$STUBS/hyprctl"
: >"$LOG"
OMARCHY_KIDS_EXIT_WAIT=0 "$EXIT_BIN" --finish >/dev/null 2>&1
st=$?
check_eq "$st" 0 "--finish without hyprctl on PATH still exits 0"
check_contains "$(cat "$LOG")" "loginctl terminate-session c7" "--finish without hyprctl still calls loginctl"
stub hyprctl # restore

# =====================================================================
# --finish --kid <account>: root-side end-session (bin/omarchy-kids-bar
# end, issue #37)
# =====================================================================

# --- refuses without root (the real, unstubbed, non-root test runner) ----

: >"$LOG"
"$EXIT_BIN" --finish --kid kid-ada >/dev/null 2>&1
check_eq "$?" 1 "--finish --kid: refuses to run without root"

# --- --kid only makes sense with --finish ---------------------------------

"$EXIT_BIN" --open --kid kid-ada >/dev/null 2>&1
check_eq "$?" 2 "--kid without --finish is refused"

"$EXIT_BIN" --finish --kid >/dev/null 2>&1
check_eq "$?" 2 "--kid with no account is refused"

# From here on `id` answers as root (there is no env hook for the root
# check any more -- review §3.6): kid-ada is uid 1001, everything else is
# "no such account".
kids_id_stub "$STUBS" kid-ada 1001
export KIDS_TEST_UID=0
stub runuser
RUN_ROOT="$TMP/run-user"
kids_set_const "$EXIT_BIN" RUN_USER_ROOT "$RUN_ROOT"

# --- a signature is found: runuser dispatches the Lua exit into kid-ada's
#     own Hyprland instance, and Hyprland leaving on its own means
#     loginctl is never needed ----------------------------------------

rm -rf "$RUN_ROOT"
mkdir -p "$RUN_ROOT/1001/hypr/sig-abc123"
stub pgrep 'exit 1' # "not found" -- kid-ada's Hyprland is already gone
: >"$LOG"
OMARCHY_KIDS_EXIT_WAIT=2 "$EXIT_BIN" --finish --kid kid-ada >/dev/null 2>&1
st=$?
argv4="$(cat "$LOG")"
check_eq "$st" 0 "--finish --kid exits 0 once kid-ada's Hyprland is gone"
check_contains "$argv4" "runuser -u kid-ada -- env XDG_RUNTIME_DIR=$RUN_ROOT/1001 HYPRLAND_INSTANCE_SIGNATURE=sig-abc123 hyprctl dispatch hl.dsp.exit()" \
  "--finish --kid runs hyprctl as kid-ada, in kid-ada's own runtime dir/signature"
grep -q "loginctl terminate-user" <<<"$argv4" &&
  fail "--finish --kid must not terminate-user when Hyprland already exited" ||
  pass "--finish --kid leaves loginctl alone when Hyprland already exited"

# --- Hyprland ignores the request: falls back to loginctl terminate-user,
#     not terminate-session (no session id is known here) ----------------

stub pgrep 'exit 0' # "found" -- still there
: >"$LOG"
OMARCHY_KIDS_EXIT_WAIT=0 "$EXIT_BIN" --finish --kid kid-ada >/dev/null 2>&1
st=$?
argv5="$(cat "$LOG")"
check_eq "$st" 0 "--finish --kid exits 0 even on the loginctl fallback"
check_contains "$argv5" "runuser -u kid-ada" "the runuser dispatch still ran before falling back"
check_contains "$argv5" "loginctl terminate-user kid-ada" "--finish --kid falls back to loginctl terminate-user <account>"
check_not_contains "$argv5" "terminate-session" "the fallback is terminate-user, never terminate-session (no session id here)"

# --- no Hyprland instance on disk at all: skip runuser, go straight to
#     the wait/fallback (still says why on stderr) ------------------------

rm -rf "$RUN_ROOT"
: >"$LOG"
err="$(OMARCHY_KIDS_EXIT_WAIT=0 "$EXIT_BIN" --finish --kid kid-ada 2>&1 >/dev/null)"
st=$?
argv6="$(cat "$LOG")"
check_eq "$st" 0 "--finish --kid with no Hyprland instance on disk still exits 0"
check_contains "$err" "no Hyprland instance found" "it says why on stderr"
grep -q "^runuser " <<<"$argv6" &&
  fail "--finish --kid must not call runuser with no signature directory to target" ||
  pass "--finish --kid skips runuser when there's no signature directory"
check_contains "$argv6" "loginctl terminate-user kid-ada" "it still falls back to loginctl terminate-user"

# --- an unknown account is refused, not silently loginctl'd ---------------

out4="$("$EXIT_BIN" --finish --kid no-such-kid 2>&1)"
st=$?
check_eq "$st" 2 "--finish --kid with an unknown account is refused"
check_contains "$out4" "no such account" "the refusal names why"

unset KIDS_TEST_UID
stub pgrep 'exit 1' # restore "not found" for whatever runs next

# --- --pause: not implemented, exits 2, names why -------------------------

out3="$("$EXIT_BIN" --pause 2>&1)"
st=$?
check_eq "$st" 2 "--pause exits 2"
check_contains "$out3" "not available" "--pause says it isn't available"
check_contains "$out3" "V1.md" "--pause points at docs/phase1/V1.md"

echo

# =====================================================================
# bin/omarchy-kids-super-tap
# =====================================================================

RUNTIME_DIR="$TMP/runtime"
kids_set_const "$TAP_BIN" RUN "$RUNTIME_DIR"
EXIT_LOG="$TMP/exit-calls.log"
touch "$EXIT_LOG"
# super-tap resolves omarchy-kids-exit beside itself (review S12: nothing
# a kid's session runs is PATH-resolved, and no env var may redirect it),
# so the stub goes into the same scratch tree.
kids_stub "$TMP/tree" omarchy-kids-exit <<EOF
#!/bin/bash
echo "called with: \$*" >> "$EXIT_LOG"
EOF

# --help
"$TAP_BIN" --help >/dev/null 2>&1
check_eq "$?" 0 "super-tap --help exits 0"

# --- three taps within 1.5s trigger omarchy-kids-exit exactly once -------

rm -rf "$RUNTIME_DIR"
: >"$EXIT_LOG"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1000 "$TAP_BIN"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1400 "$TAP_BIN"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1900 "$TAP_BIN"
check_eq "$(wc -l <"$EXIT_LOG" | tr -d ' ')" "1" "three taps within 1.5s call omarchy-kids-exit exactly once"

# A fourth tap right after should NOT immediately fire again (the count
# was reset on the trigger, so this is only tap #1 of a fresh window).
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1950 "$TAP_BIN"
check_eq "$(wc -l <"$EXIT_LOG" | tr -d ' ')" "1" "the tap right after a trigger doesn't fire again on its own"

# --- taps spaced further apart than the window never trigger --------------

rm -rf "$RUNTIME_DIR"
: >"$EXIT_LOG"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1000 "$TAP_BIN"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=3000 "$TAP_BIN" # +2000ms: outside the 1500ms window
OMARCHY_KIDS_SUPER_TAP_NOW_MS=5000 "$TAP_BIN" # +2000ms: outside again
check_eq "$(wc -l <"$EXIT_LOG" | tr -d ' ')" "0" "three taps spread more than 1.5s apart never trigger"

# --- exactly at the edge of the window still counts (<=, not <) -----------

rm -rf "$RUNTIME_DIR"
: >"$EXIT_LOG"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1000 "$TAP_BIN"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=2000 "$TAP_BIN"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=2500 "$TAP_BIN" # 1500ms after the first, inclusive
check_eq "$(wc -l <"$EXIT_LOG" | tr -d ' ')" "1" "a third tap exactly 1.5s after the first still counts"

# --- a custom window is honored -------------------------------------------

rm -rf "$RUNTIME_DIR"
: >"$EXIT_LOG"
export OMARCHY_KIDS_SUPER_TAP_WINDOW_MS=500
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1000 "$TAP_BIN"
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1400 "$TAP_BIN" # +400ms: within a 500ms window
OMARCHY_KIDS_SUPER_TAP_NOW_MS=1900 "$TAP_BIN" # +500ms from tap 2, but +900ms from tap 1: tap 1 has aged out
check_eq "$(wc -l <"$EXIT_LOG" | tr -d ' ')" "0" "a shorter custom window prunes taps that would pass the default"
unset OMARCHY_KIDS_SUPER_TAP_WINDOW_MS

echo "exit-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
