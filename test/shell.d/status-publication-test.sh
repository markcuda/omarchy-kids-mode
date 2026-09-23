#!/bin/bash
# R-BAR-3: status publication prepares valid JSON and parent-readable metadata
# before replacing the last good status file, and preserves it on failure.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="$DIR/bin/omarchy-kids-time-ledger"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0
pass() { echo "ok   $*"; }
fail_() {
  echo "FAIL $*"
  fail=1
}
check() { [[ "$1" == "$2" ]] && pass "$3" || fail_ "$3 (want '$2', got '$1')"; }
file_hash() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

STUBS="$TMP/stubs"
ROOT="$TMP/root"
mkdir -p "$STUBS" "$ROOT/run/omarchy-kids" "$ROOT/etc/omarchy-kids/kids"
cat >"$ROOT/etc/omarchy-kids/kids/kid-ada.conf" <<'KID'
name=Ada
avatar=fox
band=6-8
KID

cat >"$STUBS/jq" <<'JQ'
#!/bin/bash
[[ ${STATUS_JQ_FAIL:-0} == 1 ]] && exit 17
[[ ${STATUS_JQ_FINAL_FAIL:-0} == 1 && "$1" == -s ]] && exit 18
exec /usr/bin/jq "$@"
JQ
cat >"$STUBS/getent" <<'GETENT'
#!/bin/bash
[[ ${STATUS_GETENT_FAIL:-0} == 1 ]] && exit 2
[[ "$1" == group && "$2" == omarchy-parents ]] && printf 'omarchy-parents:x:987:kid-vm\n' && exit 0
exit 2
GETENT
cat >"$STUBS/chown" <<'CHOWN'
#!/bin/bash
[[ ${STATUS_CHOWN_FAIL:-0} == 1 ]] && exit 19
[[ "$1" == root && "$2" == */status.json.* ]] || exit 26
path="${@: -1}"
printf '%s\n' root >"$STATUS_META_DIR/$(basename "$path").owner"
CHOWN
cat >"$STUBS/chgrp" <<'CHGRP'
#!/bin/bash
[[ ${STATUS_CHGRP_FAIL:-0} == 1 ]] && exit 20
[[ "$1" == omarchy-parents && "$2" == */status.json.* ]] || exit 27
path="${@: -1}"
printf '%s\n' omarchy-parents >"$STATUS_META_DIR/$(basename "$path").group"
CHGRP
cat >"$STUBS/chmod" <<'CHMOD'
#!/bin/bash
[[ ${STATUS_CHMOD_FAIL:-0} == 1 ]] && exit 21
mode="$1"
path="$2"
[[ "$mode" == 0640 && "$path" == */status.json.* ]] || exit 28
/bin/chmod "$mode" "$path"
printf '%s\n' "$mode" >"$STATUS_META_DIR/$(basename "$path").mode"
CHMOD
cat >"$STUBS/mv" <<'MV'
#!/bin/bash
src="${@: -2:1}"
dst="${@: -1}"
[[ ${STATUS_MV_FAIL:-0} == 1 ]] && exit 22
base="$(basename "$src")"
[[ -s "$STATUS_META_DIR/$base.owner" && $(cat "$STATUS_META_DIR/$base.owner") == root ]] || exit 23
[[ -s "$STATUS_META_DIR/$base.group" && $(cat "$STATUS_META_DIR/$base.group") == omarchy-parents ]] || exit 24
[[ -s "$STATUS_META_DIR/$base.mode" && $(cat "$STATUS_META_DIR/$base.mode") == 0640 ]] || exit 25
mode="$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' "$src")" || exit 29
[[ "$mode" == 640 ]] || exit 29
printf 'root:omarchy-parents:%s\n' "$mode" >"$STATUS_MV_BOUNDARY"
/bin/mv "$src" "$dst"
MV
chmod +x "$STUBS"/*

awk '/^write_status_json\(\)/ { capture=1 } /^cmd_tick\(\)/ { exit } capture { print }' \
  "$LEDGER" >"$TMP/write-status.sh"
# shellcheck source=/dev/null
source "$TMP/write-status.sh"

time_root_now() { printf '2026-09-06 12:00:00\n'; }
time_hm() { printf '12:00\n'; }
time_logical_day() { printf '2026-09-06\tfalse\n'; }
time_remaining_minutes() { printf '42\n'; }
time_is_paused() { return 1; }
active_kid_sessions() { printf 'kid-ada\n'; }
kids_list() { printf 'kid-ada\n'; }

PATH="$STUBS:/usr/bin:/bin"
# shellcheck disable=SC2034 # consumed by the extracted production function
KIDS_DIR="$ROOT/etc/omarchy-kids/kids"
RUN_DIR="$ROOT/run/omarchy-kids"
STATUS_JSON="$RUN_DIR/status.json"
PAIRING_DIR="$RUN_DIR/pairing"
REVIEW_DIR="$RUN_DIR/reviews/open"
QUEUE_DIR="$ROOT/var/lib/omarchy-kids/queue"
printf '%s\n' '{"generated_at":"old","kids":[]}' >"$STATUS_JSON"
OLD_HASH="$(file_hash "$STATUS_JSON")"

assert_unchanged() {
  [[ "$(file_hash "$STATUS_JSON")" == "$OLD_HASH" ]] || return 1
  [[ -z "$(find "$RUN_DIR" -maxdepth 1 -type f \( -name '.status-*' -o -name 'status.json.*' \) -print)" ]] || return 1
}

export STATUS_MV_BOUNDARY="$TMP/mv-boundary"
export STATUS_META_DIR="$TMP/meta"
mkdir -p "$STATUS_META_DIR"
write_status_json
check "$(jq -r '.kids[0].kid' "$STATUS_JSON")" kid-ada "publishes complete JSON"
check "$(cat "$STATUS_MV_BOUNDARY")" 'root:omarchy-parents:640' "metadata is complete at publication boundary"

# A pending pairing window is published as its expiry, never the token, so the
# relay can keep itself up while a phone pairs (R-NOTIFY-2/5).
mkdir -p "$PAIRING_DIR"
printf '{"expires_at": 4102444800}\n' >"$PAIRING_DIR/d-1"
write_status_json
check "$(jq -r '.pairing_open_until' "$STATUS_JSON")" "4102444800" "publishes the pairing window's expiry"
rm -rf "$PAIRING_DIR"
write_status_json
check "$(jq -r '.pairing_open_until' "$STATUS_JSON")" "0" "no pairing window publishes 0"

# An open add-on review (R-NOTIFY-12) is published as a count, so the bar and the
# notifier see the same number.
mkdir -p "$REVIEW_DIR"
printf '{"kid": "kid-ada", "id": "minecraft", "state": "open"}\n' >"$REVIEW_DIR/kid-ada.abc123.json"
write_status_json
check "$(jq -r '.reviews' "$STATUS_JSON")" "1" "publishes the open-review count"
rm -rf "$REVIEW_DIR"
write_status_json
check "$(jq -r '.reviews' "$STATUS_JSON")" "0" "no open review publishes 0"

# The open-request count (R-BAR-3 as amended) rides the same document.
mkdir -p "$QUEUE_DIR"
printf '{"kid": "kid-ada", "kind": "time", "what": "10", "minutes": 10, "asked_at": 1, "state": "open"}\n' \
  >"$QUEUE_DIR/1-kid-ada-time.json"
write_status_json
check "$(jq -r '.open_requests' "$STATUS_JSON")" "1" "publishes the open-request count"
rm -rf "$QUEUE_DIR"
write_status_json
check "$(jq -r '.open_requests' "$STATUS_JSON")" "0" "no open request publishes 0"

for failure in jq-row jq-final chown chgrp chmod mv getent; do
  rm -f "$RUN_DIR"/status.json.* "$STATUS_MV_BOUNDARY"
  printf '%s\n' '{"generated_at":"old","kids":[]}' >"$STATUS_JSON"
  OLD_HASH="$(file_hash "$STATUS_JSON")"
  STATUS_JQ_FAIL=0 STATUS_JQ_FINAL_FAIL=0 STATUS_CHOWN_FAIL=0 STATUS_CHGRP_FAIL=0 STATUS_CHMOD_FAIL=0 STATUS_MV_FAIL=0 STATUS_GETENT_FAIL=0
  case "$failure" in
    jq-row) STATUS_JQ_FAIL=1 ;;
    jq-final) STATUS_JQ_FINAL_FAIL=1 ;;
    chown) STATUS_CHOWN_FAIL=1 ;;
    chgrp) STATUS_CHGRP_FAIL=1 ;;
    chmod) STATUS_CHMOD_FAIL=1 ;;
    mv) STATUS_MV_FAIL=1 ;;
    getent) STATUS_GETENT_FAIL=1 ;;
  esac
  export STATUS_JQ_FAIL STATUS_JQ_FINAL_FAIL STATUS_CHOWN_FAIL STATUS_CHGRP_FAIL STATUS_CHMOD_FAIL STATUS_MV_FAIL STATUS_GETENT_FAIL
  write_status_json
  if assert_unchanged; then
    pass "$failure failure preserves status and removes scratch"
  else
    fail_ "$failure failure preserves status and removes scratch"
  fi
done

((fail == 0)) && exit 0
exit 1
