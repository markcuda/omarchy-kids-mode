#!/bin/bash
# Tests bin/omarchy-kids-notify-watch and lib/notify_watch.py -- the parent's
# desktop notifier (SPEC.md R-NOTIFY; N-9). gdbus, notify-send and the bar
# command are stubs on a test-owned PATH, so the action path and the fallback
# are both exercised for real without a session bus.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$DIR/test/shell.d/tree.sh"

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0
check_status() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want exit $2, got $1)"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want '$2' in '$1')"; fi
}
check() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
ROOT="$TMP/root"
QUEUE_DIR="$ROOT/var/lib/omarchy-kids/queue"
mkdir -p "$STUBS" "$QUEUE_DIR"

kids_tree "$TMP/tree" "$DIR"
BIN="$TMP/tree/bin/omarchy-kids-notify-watch"
kids_set_const "$BIN" SYSROOT "$ROOT"
kids_set_const "$BIN" STATE_FILE "$TMP/watch.state"

BAR_LOG="$TMP/bar.log"
GDBUS_LOG="$TMP/gdbus.log"
NOTIFY_LOG="$TMP/notify.log"
export BAR_LOG GDBUS_LOG NOTIFY_LOG

kids_stub "$TMP/tree" omarchy-kids-bar <<'EOF'
#!/bin/bash
printf 'bar %s\n' "$*" >>"$BAR_LOG"
EOF

cat >"$STUBS/gdbus" <<'EOF'
#!/bin/bash
printf 'gdbus %s\n' "$*" >>"$GDBUS_LOG"
case "${1:-}" in
  call) printf '(uint32 7,)\n' ;;
  monitor) printf "ActionInvoked (uint32 7, '%s')\n" "${GDBUS_ACTION:-approve}" ;;
esac
exit 0
EOF
cat >"$STUBS/notify-send" <<'EOF'
#!/bin/bash
printf 'notify-send %s\n' "$*" >>"$NOTIFY_LOG"
EOF
chmod +x "$STUBS"/*
export PATH="$STUBS:$PATH"

ID="1000000001-kid-ada-time"
write_record() { # state
  printf '{"kid":"kid-ada","kind":"time","what":"10","minutes":10,"asked_at":1,"state":"%s"}\n' "$1" \
    >"$QUEUE_DIR/$ID.json"
}
reset() {
  rm -f "$TMP/watch.state"
  : >"$BAR_LOG"
  : >"$GDBUS_LOG"
  : >"$NOTIFY_LOG"
}

# --- the action path: gdbus carries Approve/Decline ------------------------
reset
write_record open
out="$("$BIN" --once 2>&1)"
check_status "$?" 0 "watch --once exits 0"
check_contains "$(cat "$GDBUS_LOG")" "org.freedesktop.Notifications.Notify" \
  "the request is shown through org.freedesktop.Notifications"
check_contains "$(cat "$GDBUS_LOG")" "Approve" "the notification carries an Approve action"
check_contains "$(cat "$GDBUS_LOG")" "Decline" "the notification carries a Decline action"
check_contains "$(cat "$BAR_LOG")" "bar approve $ID" "choosing Approve runs the bar action"
check_contains "$(cat "$TMP/watch.state")" "$ID" "the shown id is remembered"

# --- a shown request is not shown twice ------------------------------------
: >"$GDBUS_LOG"
: >"$BAR_LOG"
"$BIN" --once >/dev/null 2>&1
check "$(grep -c Notify "$GDBUS_LOG")" "0" "an already-shown request is not shown twice"

# --- Decline ----------------------------------------------------------------
reset
write_record open
GDBUS_ACTION=decline "$BIN" --once >/dev/null 2>&1
check_contains "$(cat "$BAR_LOG")" "bar decline $ID" "choosing Decline runs the bar action"

# --- the fallback: no session bus, notify-send, no buttons ------------------
reset
write_record open
"$BIN" --once --no-actions >/dev/null 2>&1
check_status "$?" 0 "the no-actions fallback exits 0"
check_contains "$(cat "$NOTIFY_LOG")" "kid-ada" "the fallback notifies through notify-send"
check "$(grep -c . "$BAR_LOG")" "0" "the no-actions fallback runs no bar action"

# --- a decided request is forgotten ----------------------------------------
reset
write_record open
"$BIN" --once >/dev/null 2>&1
write_record approved
"$BIN" --once >/dev/null 2>&1
check "$(cat "$TMP/watch.state")" "[]" "a decided request is dropped from the state"

# --- a malformed record is skipped, never a crash --------------------------
reset
printf 'not json\n' >"$QUEUE_DIR/$ID.json"
"$BIN" --once >/dev/null 2>&1
check_status "$?" 0 "a malformed record does not crash the watcher"
check "$(grep -c Notify "$GDBUS_LOG")" "0" "a malformed record is not notified"

echo "notify-watch-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
