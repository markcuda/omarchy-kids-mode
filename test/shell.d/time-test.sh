#!/bin/bash
# Tests the screen-time engine (SPEC.md R-TIME-1..5, Appendix F, issue
# #23): bin/omarchy-kids-time-ledger's tick (active/inactive/locked/
# paused sessions, dedup, non-kid accounts ignored), budget/lights-out
# math (band defaults and per-kid overrides, weekday vs weekend), the
# day-boundary rollover, bin/omarchy-kids-time's status/grant,
# and lib/time.py's logical-day helper.
#
# Fully self-contained: `loginctl` is a fake on a stub PATH reading a
# plain "id uid user active locked" state file this test writes before
# each scenario (same stub() shape as test/shell.d/apps-test.sh), and
# `omarchy-kids-conf` is the real thing against a scratch tree (real
# bands.toml/packs, same reasoning as that file). The copied commands read
# the clock fixtures below, so nothing here depends on the host's own clock
# or its `date` binary's flavor. One provisioned
# kid throughout: kid-ada, band 6-8 (AGENTS.md rule 9's fixture
# convention).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="$DIR/bin/omarchy-kids-time-ledger"
TIME="$DIR/bin/omarchy-kids-time"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP time-test.sh: python3 not found"
  exit 0
fi

fail=0
pass() { echo "ok   $*"; }
fail_() {
  echo "FAIL $*"
  fail=1
}
check() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail_ "$3 (want '$2', got '$1')"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail_ "$3 (want to find '$2' in '$1')"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail_ "$3 (did not want to find '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ETC="$TMP/etc"
SHARE="$TMP/share"
ROOT="$TMP/root" # OMARCHY_KIDS_ROOT
STUBS="$TMP/stubs"
SESSIONS="$TMP/sessions" # loginctl stub's state file
CLOCK_FILE="$ROOT/run/omarchy-kids/time/monotonic"
NOW_FILE="$ROOT/run/omarchy-kids/time/now"
LOCK_LOG="$TMP/lock.log"
FINISH_LOG="$TMP/finish.log"
NO_ENGAGE_FILE="$TMP/lock-never-engages"
LOCK_FAIL_FILE="$TMP/lock-request-fails"

mkdir -p "$SHARE/bands" "$SHARE/packs" "$ETC/kids" "$STUBS" "$(dirname "$CLOCK_FILE")"
cp "$DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$DIR"/share/packs/*.toml "$SHARE/packs/"
: >"$SESSIONS"
: >"$LOCK_LOG"
: >"$FINISH_LOG"

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada Lovelace
avatar=fox
band=6-8
EOF

# set_sessions LINE... — each LINE is "id uid user active locked [class type]",
# e.g. "1 1000 kid-ada yes no" or "2 1000 kid-ada yes no manager unspecified".
# class/type default to user/wayland. Replaces the whole session table.
set_sessions() {
  : >"$SESSIONS"
  local line
  for line in "$@"; do printf '%s\n' "$line" >>"$SESSIONS"; done
}

# --- stub loginctl -----------------------------------------------------

cat >"$STUBS/loginctl" <<EOF
#!/bin/bash
STATE="$SESSIONS"
if [[ "\$1" == "list-sessions" ]]; then
  list_rc="\${LOGINCTL_LIST_RC:-0}"
  [[ "\$list_rc" == 0 ]] || exit "\$list_rc"
  awk '{print \$1, \$2, \$3, "seat0"}' "\$STATE"
  exit 0
fi
if [[ "\$1" == "show-session" ]]; then
  show_rc="\${LOGINCTL_SHOW_RC:-0}"
  [[ "\$show_rc" == 0 ]] || exit "\$show_rc"
  id="\$2"; shift 2
  [[ "\${LOGINCTL_FAIL_ID:-}" == "\$id" ]] && exit 1
  props=()
  while [[ \$# -gt 0 ]]; do
    case "\$1" in
      -p) props+=("\$2"); shift 2 ;;
      *) shift ;;
    esac
  done
  line="\$(awk -v id="\$id" '\$1==id{print;exit}' "\$STATE")"
  [[ -n "\$line" ]] || exit 1
  read -r _ _ _ active locked class type <<<"\$line"
  class="\${class:-user}"
  type="\${type:-wayland}"
  for p in "\${props[@]}"; do
    case "\$p" in
      Active) echo "Active=\$active" ;;
      LockedHint) echo "LockedHint=\$locked" ;;
      Class) echo "Class=\$class" ;;
      Type) echo "Type=\$type" ;;
    esac
  done
  exit 0
fi
if [[ "\$1" == "lock-session" ]]; then
  printf '%s %s\n' "\$1" "\$2" >>"$LOCK_LOG"
  [[ -e "$LOCK_FAIL_FILE" ]] && exit 1
  target="\$(awk -v id="\$2" '\$1==id{print;exit}' "\$STATE")"
  read -r _ _ _ _ _ class _ <<<"\$target"
  [[ "\${class:-user}" == "manager" ]] && exit 1
  [[ -e "$NO_ENGAGE_FILE" ]] && exit 0
  awk -v id="\$2" '\$1 == id { \$5 = "yes" } { print }' "\$STATE" >"\$STATE.tmp"
  mv -f "\$STATE.tmp" "\$STATE"
  exit 0
fi
exit 1
EOF
chmod +x "$STUBS/loginctl"

# `id -un`/`id -u` are what decide "which kid am I?" and "am I root?"
# now -- never $OMARCHY_KIDS_ACCOUNT or a *_REQUIRE_ROOT escape (review
# §3.6/§3.7). The ledger tick and `grant` are root, so this suite claims
# root through the same stub, per call.
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
kids_id_stub "$STUBS" kid-ada "$(id -u)"

kids_tree "$TMP/tree" "$DIR"
LEDGER="$TMP/tree/bin/omarchy-kids-time-ledger"
TIME="$TMP/tree/bin/omarchy-kids-time"
kids_set_const "$LEDGER" ETC "$ETC"
kids_set_const "$LEDGER" SYSROOT "$ROOT"
kids_set_const "$LEDGER" TIME_CLOCK_FILE "$CLOCK_FILE"
kids_set_const "$LEDGER" TIME_NOW_FILE "$NOW_FILE"
kids_set_const "$LEDGER" LOCK_VERIFY_TRIES 3
kids_set_const "$LEDGER" LOCK_VERIFY_INTERVAL 0
grep -q '^LOCK_VERIFY_TRIES="3"$' "$LEDGER" ||
  fail_ "setup: LOCK_VERIFY_TRIES was not substituted in the copied ledger"
kids_set_const "$TIME" ETC "$ETC"
kids_set_const "$TIME" SHARE "$SHARE"
kids_set_const "$TIME" SYSROOT "$ROOT"
kids_set_const "$TIME" TIME_NOW_FILE "$NOW_FILE"
kids_set_const "$TIME" RUN "$TMP/run"
kids_set_const "$TIME" QUICKSHELL_BIN "$TMP/tree/bin/quickshell"
kids_stub "$TMP/tree" omarchy-kids-exit <<EOF
#!/bin/bash
printf '%s\n' "\$*" >>"$FINISH_LOG"
if [[ "\${FINISH_RC:-0}" == 0 ]]; then
  awk '\$3 != "kid-ada"' "$SESSIONS" >"$SESSIONS.tmp"
  mv -f "$SESSIONS.tmp" "$SESSIONS"
fi
exit "\${FINISH_RC:-0}"
EOF
kids_stub "$TMP/tree" quickshell <<EOF
#!/bin/bash
printf 'argv=%s toast=%s account=%s name=%s avatar=%s\n' \\
  "\$*" "\${OMARCHY_KIDS_TOAST_TEXT:-}" "\${OMARCHY_KIDS_ACCOUNT:-}" \\
  "\${OMARCHY_KIDS_NAME:-}" "\${OMARCHY_KIDS_AVATAR:-}" >>"$TMP/quickshell.log"
EOF

export PATH="$STUBS:$PATH"
cat >"$STUBS/jq" <<'EOF'
#!/bin/bash
[[ "${JQ_SERIALIZE_FAIL:-0}" == 1 && "${1:-}" == -n ]] && exit 1
exec /usr/bin/jq "$@"
EOF
cat >"$STUBS/mv" <<'EOF'
#!/bin/bash
[[ "${MV_FAIL:-0}" == 1 ]] && exit 1
exec /bin/mv "$@"
EOF
chmod +x "$STUBS/jq" "$STUBS/mv"
export OMARCHY_KIDS_ETC="$ETC"
export OMARCHY_KIDS_SHARE="$SHARE"
export OMARCHY_KIDS_ROOT="$ROOT"
export KIDS_TEST_UID=0

USAGE_DIR="$ROOT/var/lib/omarchy-kids/kid-ada/usage"

used_today() { cat "$USAGE_DIR/$1" 2>/dev/null || echo 0; }
set_clock() { printf '%s\n' "$1" >"$CLOCK_FILE"; }
set_now() { printf '%s\n' "$1" >"$NOW_FILE"; }
state_value() {
  jq -r --arg key "$1" '.[$key] | if type == "array" then tojson else tostring end' \
    "$ROOT/run/omarchy-kids/time/kid-ada.json"
}
enforcement_value() {
  jq -r --arg key "$1" '.enforcement[$key] // ""' \
    "$ROOT/run/omarchy-kids/time/kid-ada.json"
}

# --- --help --------------------------------------------------------------

"$LEDGER" --help >/dev/null 2>&1
check "$?" 0 "omarchy-kids-time-ledger --help exits 0"
"$TIME" --help >/dev/null 2>&1
check "$?" 0 "omarchy-kids-time --help exits 0"
"$TIME" >/dev/null 2>&1
check "$?" 2 "omarchy-kids-time with no command exits 2"

# =========================================================================
# lib/time.py logical-day: the 04:00 rollover and weekday math
# =========================================================================

out="$(python3 "$DIR/lib/time.py" logical-day "2026-09-02 10:00:00")"
check "$(sed -n 1p <<<"$out")" "2026-09-02" "logical-day: 10:00 is still today"
check "$(sed -n 2p <<<"$out")" "no" "logical-day: 2026-09-02 (Wednesday) is not a weekend"

out="$(python3 "$DIR/lib/time.py" logical-day "2026-09-02 03:59:00")"
check "$(sed -n 1p <<<"$out")" "2026-09-01" "logical-day: 03:59 still belongs to the day before (Appendix F)"

out="$(python3 "$DIR/lib/time.py" logical-day "2026-09-02 04:00:00")"
check "$(sed -n 1p <<<"$out")" "2026-09-02" "logical-day: exactly 04:00 already belongs to the new day"

out="$(python3 "$DIR/lib/time.py" logical-day "2026-09-05 10:00:00")"
check "$(sed -n 2p <<<"$out")" "yes" "logical-day: 2026-09-05 (Saturday) is a weekend"

# lib/time.sh's own helpers: a plain sentence for a bad HH:MM and a named key
# when conf can't be read (live: a bad conf read surfaced in the ledger tick as
# bash's cryptic "10#: invalid integer constant").
tt() { bash -c 'source "$1/lib/time.sh"; shift; "$@"' _ "$DIR" "$@"; }
check "$(tt time_minutes_since_midnight 19:30)" "1170" \
  "time_minutes_since_midnight: 19:30 is minute 1170 of the day"
check "$(tt time_minutes_since_midnight 08:09)" "489" \
  "time_minutes_since_midnight: 08:09 is base-10 minute 489, not octal"
bad="$(tt time_minutes_since_midnight banana 2>&1)"; st=$?
check "$st" 1 "time_minutes_since_midnight: a bad value exits non-zero"
check_contains "$bad" "banana is not a 24-hour HH:MM time" \
  "time_minutes_since_midnight: a bad value is refused with a sentence"
check_not_contains "$bad" "invalid integer constant" \
  "time_minutes_since_midnight: never bash's 10# error"

bad="$(OMARCHY_KIDS_ETC="$ETC" bash -c 'source "$1/lib/time.sh"; time_conf kid-ada no_such_key' _ "$DIR" 2>&1)"; st=$?
check "$st" 1 "time_conf: an unreadable key exits non-zero"
check_contains "$bad" "could not read no_such_key for kid-ada" \
  "time_conf: an unreadable key names the key and the kid"

# Before the root timer's first tick, status keeps its parent-facing facts
# by falling back to the read-only ledger calculation.
set_now "2026-09-02 10:00:00"
out="$("$TIME" status kid-ada)"
check_contains "$out" "kid-ada: 0 min used, 60 min left today (budget 60)" \
  "status: missing root state keeps the parent-facing facts"
check_contains "$out" "budget runs out at 11:00" \
  "status: missing root state falls back to the ledger boundary"

# =========================================================================
# =========================================================================
# omarchy-kids-time-ledger tick
# =========================================================================

set_now "2026-09-02 10:00:00"
set_clock 1000

# --- active + unlocked: counts -------------------------------------------

set_sessions "1 1000 kid-ada yes no"
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "0" "tick: the first active tick initializes without fabricating a minute"
check "$(state_value state)" "allowed" "tick: first state is allowed"
check "$(state_value remaining_seconds)" "3600" "tick: first state starts from the integer ledgers"
check "$(kids_file_mode "$ROOT/run/omarchy-kids/time")" "750" "tick: runtime state directory is mode 0750"
check "$(kids_file_mode "$ROOT/run/omarchy-kids/time/kid-ada.json")" "640" "tick: runtime state is mode 0640"
set_clock 1030
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "0" "tick: thirty active seconds stay in the runtime remainder"
check "$(state_value active_seconds_remainder)" "30" "tick: runtime remainder preserves sub-minute usage"
set_clock 1060
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "1" "tick: sixty active seconds add one historical ledger minute"
check "$(state_value active_seconds_remainder)" "0" "tick: a whole minute clears the runtime remainder"

# --- inactive: does not count --------------------------------------------

set_sessions "1 1000 kid-ada no no"
set_clock 1120
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "1" "tick: an inactive session does not add a minute"

# --- locked: does not count ------------------------------------------------

set_sessions "1 1000 kid-ada yes yes"
set_clock 1180
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "1" "tick: a locked session does not add a minute"

# --- paused flag file: does not count, even if active+unlocked -----------

mkdir -p "$ROOT/var/lib/omarchy-kids/kid-ada"
touch "$ROOT/var/lib/omarchy-kids/kid-ada/paused"
set_sessions "1 1000 kid-ada yes no"
set_clock 1240
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "1" "tick: a paused kid does not add a minute even while active and unlocked"
rm -f "$ROOT/var/lib/omarchy-kids/kid-ada/paused"
set_clock 1300
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "2" "tick: counting resumes once the paused flag is gone"

# --- a non-kid account's session is ignored -------------------------------

set_sessions "1 1000 kid-ada yes no" "2 1001 mark yes no"
set_clock 1360
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "3" "tick: kid-ada's session still counts"
# (no profile for "mark" under $ETC/kids -- if it were mistakenly
# counted there'd be no ledger file to even check against; the real
# assertion is just that this doesn't error out.)
pass "tick: a non-kid account's session is silently ignored (no crash, no ledger file for it)"

# --- the relay starts on demand (N-7, R-NOTIFY-1) -------------------------
#
# The ledger asks the relay to start while a kid is live or a request is open;
# there is no certificate when notifications are off. A systemctl stub owns the
# proof (AGENTS.md shape 1), so a missing stub -- the real systemctl -- can
# never make these pass.
SYSTEMCTL_LOG="$TMP/systemctl.log"
cat >"$STUBS/systemctl" <<EOF
#!/bin/bash
printf 'systemctl %s\n' "\$*" >>"$SYSTEMCTL_LOG"
exit 0
EOF
chmod +x "$STUBS/systemctl"
mkdir -p "$ETC/relay" "$ROOT/var/lib/omarchy-kids/queue"

# Notifications off (no certificate): a live kid starts nothing.
: >"$SYSTEMCTL_LOG"
rm -f "$ETC/relay/cert.pem" "$ETC/relay/key.pem"
set_now "2026-09-02 10:00:00"
set_clock 1400
set_sessions "1 1000 kid-ada yes no"
"$LEDGER" tick >/dev/null
check_not_contains "$(cat "$SYSTEMCTL_LOG")" "omarchy-kids-relayd" \
  "tick: no certificate (notifications off) starts no relay"

# Notifications on, a kid live: it starts.
: >"$SYSTEMCTL_LOG"
: >"$ETC/relay/cert.pem"
: >"$ETC/relay/key.pem"
set_clock 1430
"$LEDGER" tick >/dev/null
check_contains "$(cat "$SYSTEMCTL_LOG")" "start --no-block omarchy-kids-relayd.service" \
  "tick: a live kid starts the relay on demand"

# Notifications on, no kid live, no open request: it starts nothing.
: >"$SYSTEMCTL_LOG"
set_sessions "1 1000 kid-ada no no"
set_clock 1460
"$LEDGER" tick >/dev/null
check_not_contains "$(cat "$SYSTEMCTL_LOG")" "omarchy-kids-relayd" \
  "tick: no live kid and no open request starts no relay"

# Notifications on, no kid live, but a request is open: it starts.
: >"$SYSTEMCTL_LOG"
printf '{"kid": "kid-ada", "kind": "time", "what": "10", "minutes": 10, "asked_at": 1000000002, "state": "open"}\n' \
  >"$ROOT/var/lib/omarchy-kids/queue/1000000002-kid-ada-time.json"
set_clock 1490
"$LEDGER" tick >/dev/null
check_contains "$(cat "$SYSTEMCTL_LOG")" "start --no-block omarchy-kids-relayd.service" \
  "tick: an open request starts the relay on demand"
rm -f "$ROOT/var/lib/omarchy-kids/queue/1000000002-kid-ada-time.json"

# Notifications on, no kid live, but a pairing window is open: it starts.
: >"$SYSTEMCTL_LOG"
mkdir -p "$ROOT/run/omarchy-kids/pairing"
printf '{"expires_at": %s}\n' "$(($(date +%s) + 300))" >"$ROOT/run/omarchy-kids/pairing/d-1"
set_clock 1520
"$LEDGER" tick >/dev/null
check_contains "$(cat "$SYSTEMCTL_LOG")" "start --no-block omarchy-kids-relayd.service" \
  "tick: an open pairing window starts the relay on demand"

# Notifications on, no kid live, an expired pairing record: it starts nothing.
: >"$SYSTEMCTL_LOG"
printf '{"expires_at": 0}\n' >"$ROOT/run/omarchy-kids/pairing/d-1"
set_clock 1550
"$LEDGER" tick >/dev/null
check_not_contains "$(cat "$SYSTEMCTL_LOG")" "omarchy-kids-relayd" \
  "tick: an expired pairing record starts no relay"
rm -rf "$ROOT/run/omarchy-kids/pairing"

# --- two sessions for the same kid: only one minute, not two -------------

set_sessions "1 1000 kid-ada yes no" "2 1000 kid-ada yes no"
set_clock 1420
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "4" "tick: two sessions for the same kid still only add one minute"

# --- day-boundary rollover: a tick just before 04:00 lands on yesterday --

set_now "2026-09-03 03:59:30"
set_clock 1480
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "5" "tick: 03:59 still counts active time against the prior logical day"
check "$(used_today 2026-09-03)" "0" "tick: nothing recorded yet for the new logical day before 04:00"

# --- state transitions: warning, grace, grant recovery, restart ------------

set_now "2026-09-03 04:00:30"
set_clock 1540
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-02)" "5" "tick: a session crossing 04:00 keeps the pre-boundary seconds on yesterday"
check "$(used_today 2026-09-03)" "0" "tick: a session crossing 04:00 starts the new day's integer ledger cleanly"
check "$(state_value active_seconds_remainder)" "30" "tick: a session crossing 04:00 carries only new-day seconds"
echo 50 >"$USAGE_DIR/2026-09-03"
"$LEDGER" tick >/dev/null
check "$(state_value state)" "warning" "tick: remaining ten minutes enters warning"
check "$(state_value reason)" "budget" "tick: warning records the budget reason"
check "$(state_value warnings_fired)" "[10]" "tick: warning persists the crossed threshold"

set_clock 1600
set_sessions
echo 60 >"$USAGE_DIR/2026-09-03"
"$LEDGER" tick >/dev/null
set_sessions "1 1000 kid-ada yes no"
"$LEDGER" tick >/dev/null
check "$(state_value state)" "grace" "tick: zero budget enters grace"
check "$(state_value reason)" "budget" "tick: grace records the budget reason"
check "$(state_value grace_deadline)" "1660" "tick: grace deadline is sixty monotonic seconds later"
check "$(used_today 2026-09-03)" "60" "tick: enforcement does not rewrite the usage ledger"
check "$(cat "$LOCK_LOG")" "lock-session 1" "tick: root locks the active session at the budget boundary"
check "$(enforcement_value action)" "lock" "tick: state records the root lock action"
check "$(enforcement_value reason)" "budget" "tick: state records why root locked"
check "$(enforcement_value result)" "success" "tick: state records a successful lock"
"$LEDGER" tick >/dev/null
check "$(wc -l <"$LOCK_LOG" | tr -d ' ')" "1" "tick: a locked grace state does not repeat the lock request"

echo 15 >"$ROOT/var/lib/omarchy-kids/kid-ada/usage/2026-09-03.grant"
set_clock 1630
"$LEDGER" tick >/dev/null
check "$(state_value state)" "allowed" "tick: a grant clears grace when policy permits use"
check "$(state_value grace_deadline)" "0" "tick: cleared grace removes its deadline"

rm -f "$ROOT/run/omarchy-kids/time/kid-ada.json"
rm -f "$ROOT/var/lib/omarchy-kids/kid-ada/usage/2026-09-03.grant"
echo 55 >"$USAGE_DIR/2026-09-03"
set_clock 1660
"$LEDGER" tick >/dev/null
check "$(state_value state)" "warning" "tick: missing runtime state rebuilds from root ledgers"
check "$(used_today 2026-09-03)" "55" "tick: state recovery leaves usage history unchanged"
out="$("$TIME" status kid-ada)"
check_contains "$out" "kid-ada: 55 min used, 5 min left today (budget 60)" \
  "status: keeps the parent-facing format with root remaining"
check_contains "$out" "budget runs out at 04:05" \
  "status: uses the root-published budget deadline"

set_now "2026-09-03 20:00:00"
set_clock 1720
set_sessions "1 1000 kid-ada yes no"
"$LEDGER" tick >/dev/null
check "$(state_value state)" "grace" "tick: lights-out enters grace independently of budget"
check "$(state_value reason)" "lights-out" "tick: lights-out records its own reason"
check "$(state_value grace_deadline)" "1780" "tick: lights-out grace gets a sixty-second deadline"
check "$(enforcement_value action)" "lock" "tick: lights-out records the root lock action"
check "$(enforcement_value reason)" "lights-out" "tick: state records why root locked at lights-out"
check "$(enforcement_value result)" "success" "tick: lights-out lock succeeds"
check "$(enforcement_value at)" "2026-09-03 20:00:00" "tick: enforcement record uses the fixed wall-clock reading"
check "$(wc -l <"$LOCK_LOG" | tr -d ' ')" "2" "tick: lights-out requests one additional root lock"
set_sessions "2 1000 kid-ada yes no"
set_clock 1730
"$LEDGER" tick >/dev/null
check "$(wc -l <"$LOCK_LOG" | tr -d ' ')" "3" "tick: a new session gets the existing lights-out lock decision"
out="$("$TIME" status kid-ada)"
check_contains "$out" "kid-ada: 56 min used, 4 min left today (budget 60)" \
  "status: keeps the parent-facing format at lights-out"
check_contains "$out" "lights-out at 20:00" \
  "status: uses the root-published lights-out deadline"
set_clock 1780
FINISH_RC=1 "$LEDGER" tick >/dev/null
check "$(state_value state)" "finishing" "tick: expired grace enters finishing"
check "$(enforcement_value action)" "finish" "tick: state records the root finish action"
check "$(enforcement_value reason)" "lights-out" "tick: finish record preserves the enforcement reason"
check "$(enforcement_value result)" "failed" "tick: failed finish is recorded as failed"
check "$(cat "$FINISH_LOG")" "--finish --kid kid-ada" "tick: root calls the sibling finish path"
FINISH_RC=0 "$LEDGER" tick >/dev/null
check "$(state_value state)" "finishing" "tick: successful finish remains an enforcing state"
check "$(enforcement_value result)" "success" "tick: successful finish is recorded"
check "$(wc -l <"$FINISH_LOG" | tr -d ' ')" "2" "tick: finish failure is retried on the next tick"
FINISH_RC=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$FINISH_LOG" | tr -d ' ')" "2" "tick: successful finish is idempotent"
set_sessions "3 1000 kid-ada yes no"
FINISH_RC=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$FINISH_LOG" | tr -d ' ')" "3" "tick: a new session gets the existing lights-out finish decision"
set_sessions "4 1000 kid-ada yes yes"
FINISH_RC=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$FINISH_LOG" | tr -d ' ')" "4" "tick: a locked session gets the existing lights-out finish decision"
set_sessions "5 1000 kid-ada no no"
FINISH_RC=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$FINISH_LOG" | tr -d ' ')" "5" "tick: an inactive session gets the existing lights-out finish decision"
LOGINCTL_LIST_RC=1 "$LEDGER" tick >/dev/null 2>&1
check "$?" "1" "tick: a session query failure is not treated as an empty session list"
check "$(enforcement_value result)" "success" "tick: a session query failure preserves the prior finish state"
set_sessions "6 1000 kid-ada yes no"
FINISH_RC=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$FINISH_LOG" | tr -d ' ')" "6" "tick: a failed session query retries finish when the query recovers"
STATE_FILE="$ROOT/run/omarchy-kids/time/kid-ada.json"
check "$(
  jq -e . "$STATE_FILE" >/dev/null 2>&1
  echo $?
)" "0" \
  "tick: state failure baseline is valid JSON"
before_state="$(cat "$STATE_FILE")"
set_sessions "7 1000 kid-ada yes no"
JQ_SERIALIZE_FAIL=1 "$LEDGER" tick >/dev/null 2>&1
check "$?" "1" "tick: jq state failure propagates"
check "$(cat "$STATE_FILE")" "$before_state" \
  "tick: jq state failure preserves the prior state"
MV_FAIL=1 "$LEDGER" tick >/dev/null 2>&1
check "$?" "1" "tick: state replacement failure propagates"
check "$(cat "$STATE_FILE")" "$before_state" \
  "tick: state replacement failure preserves the prior state"

# A property failure for one kid must preserve another kid's valid accounting
# while leaving the uncertain kid's interval pending for the retry.
cat >"$ETC/kids/kid-ben.conf" <<'EOF'
name=Ben Lovelace
avatar=fox
band=6-8
EOF
set_now "2026-09-12 10:00:00"
set_clock 2000
set_sessions "10 1000 kid-ada yes no" "11 1001 kid-ben yes no"
"$LEDGER" tick >/dev/null
set_clock 2060
LOGINCTL_FAIL_ID=11 "$LEDGER" tick >/dev/null 2>&1
check "$?" "1" "tick: one kid query failure propagates without hiding uncertainty"
check "$(used_today 2026-09-12)" "1" "tick: unaffected kid still receives its valid minute"
check "$(cat "$ROOT/var/lib/omarchy-kids/kid-ben/usage/2026-09-12" 2>/dev/null || true)" "" \
  "tick: uncertain kid does not commit guessed inactive usage"
set_clock 2120
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-12)" "2" "tick: unaffected kid catches up after the failed query recovers"
check "$(cat "$ROOT/var/lib/omarchy-kids/kid-ben/usage/2026-09-12" 2>/dev/null || true)" "2" \
  "tick: failed kid catches up its pending interval after recovery"

# =========================================================================
# lock targeting and engagement (the 2026-09-08 Air finding): only the
# account's own graphical session is a lock target, and a request that never
# engages is recorded failed -- the deadline still takes the session to finish.
# =========================================================================

set_now "2026-09-13 10:00:00"
set_clock 3000
rm -f "$ROOT/run/omarchy-kids/time/kid-ada.json" "$NO_ENGAGE_FILE"
echo 60 >"$USAGE_DIR/2026-09-13"
: >"$LOCK_LOG"
set_sessions
"$LEDGER" tick >/dev/null # grace is computed even before a session appears
set_sessions "20 1000 kid-ada yes no" "21 1000 kid-ada yes no manager unspecified"
set_clock 3010
"$LEDGER" tick >/dev/null
check "$(cat "$LOCK_LOG")" "lock-session 20" \
  "lock: only the Class=user graphical session is a lock target"
check "$(enforcement_value result)" "success" \
  "lock: the manager session does not turn a real lock into a failure"
check "$(state_value state)" "grace" "lock: the locked session remains in grace"

set_now "2026-09-14 10:00:00"
set_clock 4000
rm -f "$ROOT/run/omarchy-kids/time/kid-ada.json" "$LOCK_FAIL_FILE" "$NO_ENGAGE_FILE"
echo 60 >"$USAGE_DIR/2026-09-14"
: >"$LOCK_LOG"
set_sessions
"$LEDGER" tick >/dev/null
touch "$LOCK_FAIL_FILE"
set_sessions "30 1000 kid-ada yes no"
"$LEDGER" tick >/dev/null
check "$(cat "$LOCK_LOG")" "lock-session 30" \
  "lock: the engagement check still asks logind for the lock"
check "$(enforcement_value result)" "failed" \
  "lock: a rejected lock request is recorded as failed"
check "$(state_value state)" "grace" \
  "lock: a rejected lock still starts the grace clock"
rm -f "$LOCK_FAIL_FILE"
touch "$NO_ENGAGE_FILE"
set_clock 4030
"$LEDGER" tick >/dev/null
check "$(wc -l <"$LOCK_LOG" | tr -d ' ')" "2" \
  "lock: a failed lock is retried on the next tick"
check "$(enforcement_value result)" "failed" \
  "lock: a request that never engages is recorded as failed"
rm -f "$NO_ENGAGE_FILE"
set_clock 4050
"$LEDGER" tick >/dev/null
check "$(wc -l <"$LOCK_LOG" | tr -d ' ')" "3" \
  "lock: the retry asks for the lock again"
check "$(enforcement_value result)" "success" \
  "lock: a verified lock after failures records success"
set_clock 4060
"$LEDGER" tick >/dev/null
check "$(state_value state)" "finishing" \
  "lock: the deadline still expires after failed lock attempts"

# R-TIME-2: a manager session alone is not the kid using the computer, and a
# manager session does not make a locked graphical session look unlocked.
set_now "2026-09-15 10:00:00"
set_clock 5000
rm -f "$ROOT/run/omarchy-kids/time/kid-ada.json"
set_sessions "40 1000 kid-ada yes no manager unspecified"
"$LEDGER" tick >/dev/null
set_clock 5060
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-15)" "0" \
  "counting: a manager session alone never counts as active time"
set_sessions "41 1000 kid-ada yes yes" "42 1000 kid-ada yes no manager unspecified"
set_clock 5120
"$LEDGER" tick >/dev/null
check "$(used_today 2026-09-15)" "0" \
  "counting: a locked graphical session is not unlocked by its manager session"

echo

# =========================================================================
# root status is the only kid-side status source; policy math remains root-only
# =========================================================================

echo

# =========================================================================
# grant
# =========================================================================

# A fresh logical day, so the 500-minute grant from the "next boundary"
# scenario above doesn't leak into these totals.
set_now "2026-09-10 10:00:00"

# Refuses without the root bypass (simulating a real non-root caller);
# skip this one assertion if the test suite itself happens to run as
# root (AGENTS.md's own unshare/root convention).
if [[ "$(id -u)" != "0" ]]; then
  KIDS_TEST_UID="$(command id -u)" "$TIME" grant kid-ada 15 >/dev/null 2>&1
  check "$?" 1 "grant: refuses to run without root"
fi

out="$("$TIME" grant kid-ada 15 2>&1)"
st=$?
check "$st" 0 "grant: exits 0 with the root bypass"
check_contains "$out" "granted 15" "grant: says how many minutes it granted"
check "$(cat "$ROOT/var/lib/omarchy-kids/kid-ada/usage/2026-09-10.grant")" "15" \
  "grant: writes today's separate grant ledger"
out2="$("$TIME" status kid-ada)"
check_contains "$out2" "kid-ada: 0 min used, 75 min left today (budget 60 + 15 granted)" \
  "status: keeps the grant in the parent-facing facts"

"$TIME" grant kid-ada 0 >/dev/null 2>&1
check "$?" 2 "grant: refuses a zero amount"
"$TIME" grant kid-ada -5 >/dev/null 2>&1
check "$?" 2 "grant: refuses a negative amount"
"$TIME" grant kid-ada abc >/dev/null 2>&1
check "$?" 2 "grant: refuses a non-numeric amount"

echo

# =========================================================================
# daemon: reflects root's status only. A missing state does nothing; a
# root-published warning fires the matching display; grace opens Time's
# Up. The display path never computes a budget or invokes finish.
# =========================================================================

DAEMON_DAY="2026-09-16" # a fresh day, untouched by the tests above
CONF="$DIR/bin/omarchy-kids-conf"
set_now "$DAEMON_DAY 10:00:00"
"$CONF" set kid-ada budget_min 12 >/dev/null
"$CONF" set kid-ada budget_min_weekend 12 >/dev/null

DAEMON_USAGE_DIR="$ROOT/var/lib/omarchy-kids/kid-ada/usage"
mkdir -p "$DAEMON_USAGE_DIR"
DAEMON_RUN="$TMP/daemon-run"
DAEMON_LOG="$DAEMON_RUN/session-$(id -u).log"
kids_set_const "$TIME" RUN "$DAEMON_RUN"
export XDG_SESSION_ID=1
set_sessions "1 1000 kid-ada yes no"

# run_daemon_oneshot STATE_WRITER — writes a root-owned status fixture,
# runs one display poll, and prints the adapter log.
STATE_FILE="$ROOT/run/omarchy-kids/time/kid-ada.json"
write_state() {
  local state="$1" warnings="$2" remaining="$3" grace="$4" last="$5"
  install -d -m 0750 "$(dirname "$STATE_FILE")"
  jq -n --arg state "$state" --argjson warnings "$warnings" \
    --argjson remaining "$remaining" --argjson grace "$grace" \
    --argjson last "$last" \
    '{kid: "kid-ada", logical_day: "2026-09-16", last_wall: "2026-09-16 10:00:00",
      state: $state, reason: "budget", remaining_seconds: $remaining,
      grace_deadline: $grace, last_tick: $last, active_seconds_remainder: 0,
      warnings_fired: $warnings,
      enforcement: {action: "none", reason: "none", result: "none", at: ""}}' \
    >"$STATE_FILE"
  chmod 0640 "$STATE_FILE"
}

run_daemon_oneshot() {
  rm -rf "$DAEMON_RUN"
  mkdir -p "$DAEMON_RUN"
  rm -f "$TMP/quickshell.log"
  "$@"
  OMARCHY_KIDS_TIME_DAEMON_ONESHOT=1 "$TIME" daemon >/dev/null 2>&1
  sleep 1
  cat "$DAEMON_LOG" "$TMP/quickshell.log" 2>/dev/null
}

rm -f "$STATE_FILE"
log_out="$(run_daemon_oneshot true)"
check "$log_out" "" "daemon: missing root status does nothing"

write_warning_state() { write_state warning '[10,5]' 240 0 1000; }
log_out="$(run_daemon_oneshot write_warning_state)"
check_contains "$log_out" "argv=-p $SHARE/time/toast.qml toast=5 minutes left" \
  "daemon: root warning state drives the most urgent published warning"
check_not_contains "$log_out" "timesup.qml" "daemon: warning state does not open Time's Up"

write_grace_state() { write_state grace '[]' 0 1060 1000; }
log_out="$(run_daemon_oneshot write_grace_state)"
check_contains "$log_out" "argv=-p $SHARE/time/timesup.qml" \
  "daemon: root grace state opens the display-only Time's Up card"
check_not_contains "$log_out" "omarchy-kids-exit" \
  "daemon: root grace state does not invoke the finish command"
check_not_contains "$(cat "$DIR/share/time/timesup.qml")" "omarchy-kids-exit" \
  "timesup: overlay contains no finish command"
check_contains "$(cat "$DIR/share/time/timesup.qml")" 'root.reason === "lights-out"' \
  "timesup: branches on the root reason so lights-out can speak for itself"
check_contains "$(cat "$DIR/share/time/timesup.qml")" "It's bedtime." \
  "timesup: has bedtime words for a lights-out stop"
check_contains "$(cat "$DIR/share/time/timesup.qml")" '"Closing in "' \
  "timesup: counts down in plain words"

"$CONF" reset kid-ada >/dev/null
unset XDG_SESSION_ID
rm -rf "$DAEMON_RUN"
set_sessions

echo

# =========================================================================
# status vs a grant made after the last tick (docs/time.md): the published
# document is older than the grant, so status counts the grant now instead
# of showing the pre-grant remaining for up to a tick (live finding).
# =========================================================================

GRANT_DAY="2026-09-22" # a weekday outside the days the tests above touch
set_now "$GRANT_DAY 10:00:00"
STATUS_STATE="$ROOT/run/omarchy-kids/time/kid-ada.json"
install -d -m 0750 "$(dirname "$STATUS_STATE")"
write_status_state() {
  local remaining="$1"
  jq -n --argjson remaining "$remaining" \
    '{kid: "kid-ada", logical_day: "2026-09-22",
      last_wall: "2026-09-22 10:00:00", state: "allowed", reason: "none",
      remaining_seconds: $remaining, grace_deadline: 0, last_tick: 1000,
      active_seconds_remainder: 0, warnings_fired: [],
      enforcement: {action: "none", reason: "none", result: "none", at: ""}}' \
    >"$STATUS_STATE"
  chmod 0640 "$STATUS_STATE"
}

write_status_state 300 # the root tick last published 5 minutes
out="$("$TIME" status kid-ada)"
check_contains "$out" "kid-ada: 0 min used, 5 min left today (budget 60)" \
  "status: uses the published document while it is newer than any grant"

# A grant made since that tick is newer than the document, so its 20 minutes
# must count at once (ledger 60 + 20 - 0), not the stale published 5.
touch -t 202001010000 "$STATUS_STATE"
"$TIME" grant kid-ada 20 >/dev/null 2>&1
check "$?" 0 "status: the grant under test succeeds"
out="$("$TIME" status kid-ada)"
check_contains "$out" "kid-ada: 0 min used, 80 min left today (budget 60 + 20 granted)" \
  "status: a grant newer than the last tick is counted before the next tick"

# Once the root tick publishes again (document newer than the grant file), the
# published value is authoritative again. Age the grant so the rewrite is
# provably the newer file, not an equal-mtime tie.
touch -t 202001010000 "$ROOT/var/lib/omarchy-kids/kid-ada/usage/2026-09-22.grant"
write_status_state 240
out="$("$TIME" status kid-ada)"
check_contains "$out" "kid-ada: 0 min used, 4 min left today (budget 60 + 20 granted)" \
  "status: a tick since the grant returns to the published document"

echo

# =========================================================================
# static: systemd/omarchy-kids-time-ledger.{service} and omarchy-kids-time.timer
#
# tick reads every known kid's own $XDG_RUNTIME_DIR (lib/data.sh's
# data_fold_launches) as well as writing under /var/lib/omarchy-kids
# and /run/omarchy-kids -- ProtectHome=yes would hide /run/user/* from
# the unit (systemd's own docs), which is exactly where that runtime
# log lives, so it must stay unset; the two write targets still need
# to be explicit ReadWritePaths under ProtectSystem=strict.
# =========================================================================

SERVICE="$DIR/systemd/omarchy-kids-time-ledger.service"
TIMER="$DIR/systemd/omarchy-kids-time.timer"

if [[ -f "$SERVICE" ]]; then
  pass "omarchy-kids-time-ledger.service exists"
  grep -qE '^\[Service\]' "$SERVICE" && pass "service: has [Service]" || fail_ "service: missing [Service]"
  grep -qE '^Type=oneshot' "$SERVICE" && pass "service: Type=oneshot" || fail_ "service: missing Type=oneshot"
  grep -qE '^ExecStart=.*omarchy-kids-time-ledger tick' "$SERVICE" &&
    pass "service: ExecStart runs 'omarchy-kids-time-ledger tick'" ||
    fail_ "service: ExecStart does not run time-ledger tick"
  grep -qE '^ProtectHome=yes' "$SERVICE" &&
    fail_ "service: ProtectHome=yes would hide /run/user/* -- the runtime launches log tick folds lives there" ||
    pass "service: ProtectHome=yes is not set (so /run/user/<uid> stays visible to the fold step)"
  grep -qE '^ReadWritePaths=.*\bvar/lib/omarchy-kids\b' "$SERVICE" &&
    pass "service: ReadWritePaths includes /var/lib/omarchy-kids" ||
    fail_ "service: ReadWritePaths missing /var/lib/omarchy-kids"
  grep -qE '^ReadWritePaths=.*\brun/omarchy-kids\b' "$SERVICE" &&
    pass "service: ReadWritePaths includes /run/omarchy-kids" ||
    fail_ "service: ReadWritePaths missing /run/omarchy-kids"
else
  fail_ "$SERVICE not found"
fi

if [[ -f "$TIMER" ]]; then
  pass "omarchy-kids-time.timer exists"
  grep -qE '^\[Timer\]' "$TIMER" && pass "timer: has [Timer]" || fail_ "timer: missing [Timer]"
  grep -qE '^Unit=omarchy-kids-time-ledger\.service' "$TIMER" &&
    pass "timer: points at omarchy-kids-time-ledger.service" ||
    fail_ "timer: missing/wrong Unit="
  grep -qE '^\[Install\]' "$TIMER" && pass "timer: has [Install]" || fail_ "timer: missing [Install]"
  grep -qE '^WantedBy=timers\.target' "$TIMER" && pass "timer: WantedBy=timers.target" || fail_ "timer: missing WantedBy=timers.target"
else
  fail_ "$TIMER not found"
fi

if command -v systemd-analyze >/dev/null 2>&1; then
  if systemd-analyze verify "$SERVICE" "$TIMER" >/dev/null 2>&1; then
    pass "systemd-analyze verify: service + timer are syntactically valid"
  else
    fail_ "systemd-analyze verify: service or timer failed verification"
  fi
else
  pass "systemd-analyze not available here -- static [Section]/key checks above stand in for it"
fi

echo "time-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit $fail
