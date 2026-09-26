#!/bin/bash
# Tests scripts/vm-qmp.sh's character map and its QMP error handling (issue #178).
#
# **No VM is involved.** `socat` is a stub on a scratch PATH that logs the JSON
# it is handed and prints a canned reply, and VM_DIR points at a scratch tree, so
# nothing here opens the test VM's socket or needs it to exist. That matters:
# rule 11 keeps scripts/vm-*.sh and test/live/ to the gate runner, and this is a
# unit test of the mapping, not a live run.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

STUBS="$TMP/stubs"
mkdir -p "$STUBS" "$TMP/vm"
SOCAT_LOG="$TMP/socat.log"
cat >"$STUBS/socat" <<'EOF'
#!/bin/bash
cat >>"${SOCAT_LOG:?}"
printf '\n' >>"${SOCAT_LOG:?}"
printf '%s\n' "${SOCAT_REPLY:-{\"return\": {}}}"
EOF
chmod +x "$STUBS/socat"
: >"$TMP/vm/qmp.sock"
export PATH="$STUBS:$PATH" SOCAT_LOG
export VM_DIR="$TMP/vm"

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want '$2' in: $1)"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want '$2' in: $1)"; fi
}
check_status() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want exit $2, got $1)"; fi
}
rc=0

# --- a colon is shift-semicolon, not the invalid qcode ":" (the 21:00 bug) --
: >"$SOCAT_LOG"
out="$(printf '21:00' | bash "$DIR/scripts/vm-qmp.sh" type 2>&1)"
st=$?
check_status "$st" 0 "type '21:00' exits 0"
check_contains "$(cat "$SOCAT_LOG")" '"data":"shift"' "a colon is typed with shift held"
check_contains "$(cat "$SOCAT_LOG")" '"data":"semicolon"' "…as semicolon, not as a bare ':'"
check_not_contains "$(cat "$SOCAT_LOG")" '"data":":"' "the invalid qcode ':' is never sent"
check_contains "$(cat "$SOCAT_LOG")" '"data":"2"' "and the digits still go through"

# --- the full punctuation set the sandbox list named ----------------------
# Each row is "char base-qcode held": the script types a shifted character as the
# `shift` modifier held plus the base key, so the base is what the JSON contains.
while read -r char want held; do
  [[ -n "$char" ]] || continue
  : >"$SOCAT_LOG"
  printf '%s' "$char" | bash "$DIR/scripts/vm-qmp.sh" type >/dev/null 2>&1
  check_contains "$(cat "$SOCAT_LOG")" "\"data\":\"$want\"" "type '$char' sends qcode '$want'"
  if [[ "$held" == held ]]; then
    check_contains "$(cat "$SOCAT_LOG")" '"data":"shift"' "type '$char' holds shift"
  else
    check_not_contains "$(cat "$SOCAT_LOG")" '"data":"shift"' "type '$char' needs no shift"
  fi
done <<'PAIRS'
: semicolon held
; semicolon
, comma
! 1 held
@ 2 held
$ 4 held
( 9 held
) 0 held
_ minus held
+ equal held
? slash held
PAIRS

# --- a character with no mapping is refused, not sent as a broken qcode ----
: >"$SOCAT_LOG"
out="$(printf '€' | bash "$DIR/scripts/vm-qmp.sh" type 2>&1)"
st=$?
check_status "$st" 1 "type '€' exits non-zero (no mapping)"
check_contains "$out" "no qcode mapping" "…and says why"
check_not_contains "$(cat "$SOCAT_LOG")" '"data"' "…and nothing was sent for it"

# --- a QMP error reply fails the run instead of passing silently ----------
SOCAT_REPLY='{"error": {"class": "GenericError", "desc": "nope"}}' \
  bash "$DIR/scripts/vm-qmp.sh" status >/dev/null 2>&1
check_status "$?" 1 "a QMP error reply exits non-zero (was swallowed)"
out="$(printf 'a' | SOCAT_REPLY='{"error": {"class": "GenericError"}}' bash "$DIR/scripts/vm-qmp.sh" type 2>&1)"
check_status "$?" 1 "…so a refused keystroke stops the run"

# --- and a normal reply still passes --------------------------------------
out="$(SOCAT_REPLY='{"return": {"running": true}}' bash "$DIR/scripts/vm-qmp.sh" status 2>&1)"
check_status "$?" 0 "a normal QMP reply exits 0"
check_contains "$out" '"running"' "status prints the reply"

echo "vm-qmp-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
