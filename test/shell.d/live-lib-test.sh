#!/bin/bash
# Tests the local helpers in test/live/lib.sh — portal tile/index parsing, live compositor
# readiness, the finalized journal-report parser, and the report table generator. The live
# compositor checks below own vmroot and sleep, so they never contact the test laptop or VM; the
# scenarios themselves (test/live/NN-*.sh) are exercised by hand against the real VM per
# docs/live-tests.md, never here.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Copy every sourced library beside synthetic config before sourcing anything. The fixture uses
# only this scratch tree, so it cannot read checkout config or touch a real VM helper.
LIB_FIXTURE_ROOT="$TMP/library"
mkdir -p "$LIB_FIXTURE_ROOT/test/live" "$LIB_FIXTURE_ROOT/lib"
cp "$DIR/test/live/lib.sh" "$LIB_FIXTURE_ROOT/test/live/lib.sh"
cp "$DIR/lib/conf.sh" "$LIB_FIXTURE_ROOT/lib/conf.sh"
cp "$DIR/lib/posture.sh" "$LIB_FIXTURE_ROOT/lib/posture.sh"
cp "$DIR/lib/theme.sh" "$LIB_FIXTURE_ROOT/lib/theme.sh"
cp "$DIR/lib/theme-geometry.py" "$LIB_FIXTURE_ROOT/lib/theme-geometry.py"
cp "$DIR/lib/kids.sh" "$LIB_FIXTURE_ROOT/lib/kids.sh"
cat >"$LIB_FIXTURE_ROOT/test/live/config.env" <<EOF
LIVE_OWNER_ACCOUNT=kid-test
LIVE_OWNER_PASSWORD=fixture-owner
LIVE_OUT_DIR=$TMP/out
LIVE_SSH_CFG=$TMP/does-not-exist
EOF
export OMARCHY_KIDS_VM_DRIVER_LOCKED=1
# shellcheck source=/dev/null
source "$LIB_FIXTURE_ROOT/test/live/lib.sh"
# shellcheck source=/dev/null
source "$LIB_FIXTURE_ROOT/lib/conf.sh"
# shellcheck source=/dev/null
source "$LIB_FIXTURE_ROOT/lib/posture.sh"

fail=0
check() { # got want label
  if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want '$2', got '$1')"
    fail=1
  fi
}
check_status() { # got_status want_status label
  if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want exit $2, got $1)"
    fail=1
  fi
}

# --- portal_kid_index / portal_kid_count -----------------------------------------------------

CSV="kid-ada:Ada Lovelace:fox,kid-cy:Cy:panda"
QUOTED_CSV="\"$CSV\""

check "$(portal_kid_index "$CSV" kid-ada)" "0" "portal_kid_index: the first kid is index 0"
check "$(portal_kid_index "$CSV" kid-cy)" "1" "portal_kid_index: the second kid is index 1"
check "$(portal_kid_count "$CSV")" "2" "portal_kid_count: two entries"
check "$(portal_kid_index "$QUOTED_CSV" kid-cy)" "1" "portal_kid_index: quoted two-kid value keeps the second kid"
check "$(portal_kid_count "$QUOTED_CSV")" "2" "portal_kid_count: quoted two-kid value has two entries"
TILES=$'kid-ada\nkid-ben\nkid-cy\nkid-vm'
check "$(portal_tile_index "$TILES" kid-cy)" "2" "portal_tile_index: sorted greeter order, third account is index 2"
check "$(portal_tile_index "$TILES" kid-vm)" "3" "portal_tile_index: the parent sorts last here"
portal_tile_index "$TILES" kid-zed >/dev/null && fail "portal_tile_index: unknown account should fail" || echo "ok   portal_tile_index: unknown account fails"

portal_kid_index "$CSV" kid-nope >/dev/null 2>&1
check_status "$?" "1" "portal_kid_index: an account not in the list fails"

check "$(portal_kid_index "kid-ada:Ada:fox" kid-ada)" "0" "portal_kid_index: a single kid is index 0"
check "$(portal_kid_count "kid-ada:Ada:fox")" "1" "portal_kid_count: one entry"

check "$(portal_kid_count "")" "0" "portal_kid_count: no kids= value yet is zero kids"
portal_kid_index "" kid-ada >/dev/null 2>&1
check_status "$?" "1" "portal_kid_index: no kids= value yet always fails"

PARENTS="kid-vm,parent-helper"
QUOTED_PARENTS="\"$PARENTS\""
check "$(portal_conf_accounts "$CSV" "$PARENTS")" \
  $'kid-ada\nkid-cy\nkid-vm\nparent-helper' \
  "portal_conf_accounts: kids precede the explicit parent allowlist"
check "$(portal_conf_accounts "kid-ada:Ada Lovelace:fox" "kid-ada,parent-helper")" \
  $'kid-ada\nparent-helper' \
  "portal_conf_accounts: duplicate kid/parent membership produces one tile"
check "$(portal_conf_tile_count "$CSV" "$PARENTS")" "4" \
  "portal_conf_tile_count: counts profiled kids plus parents"
check "$(portal_conf_accounts "$QUOTED_CSV" "$QUOTED_PARENTS")" \
  $'kid-ada\nkid-cy\nkid-vm\nparent-helper' \
  "portal_conf_accounts: quoted lists preserve every account"
check "$(portal_conf_tile_count "$QUOTED_CSV" "$QUOTED_PARENTS")" "4" \
  "portal_conf_tile_count: quoted lists keep all four tiles"
check "$(portal_conf_unquote 'already\\decoded')" 'already\\decoded' \
  "portal_conf_unquote: an already-decoded value is not unescaped twice"

PORTAL_CONF="$TMP/theme.conf.user"
cat >"$PORTAL_CONF" <<'EOF'
[General]
parent=kid-vm
parents="kid-vm"
kids="kid-ada:Ada Lovelace:fox,kid-cy:Cy:panda"
EOF
conf="$(cat "$PORTAL_CONF")"
kids="$(portal_conf_field "$conf" kids)"
parents="$(portal_conf_field "$conf" parents)"
check "$kids" "$CSV" "theme.conf.user: reads back the complete two-kid list"
check "$(portal_conf_accounts "$kids" "$parents")" $'kid-ada\nkid-cy\nkid-vm' \
  "theme.conf.user: both written kids and the parent survive readback"

OMARCHY_KIDS_ROOT="$TMP/roundtrip-root"
OMARCHY_KIDS_HOME_ROOT="$TMP/roundtrip-home"
export OMARCHY_KIDS_ROOT OMARCHY_KIDS_HOME_ROOT
ROUNDTRIP_NAMES=(
  'Ada, Jr'
  'Ada: Cy'
  'Ada "Cy" \kid'
  $'Ada\rCy'
  $'Ada%2C, Cy: "kid" \\ \r'
)
for ROUNDTRIP_NAME in "${ROUNDTRIP_NAMES[@]}"; do
  posture_write_portal_conf kid-vm \
    "$(printf 'kid-ada\t%s\tfox' "$ROUNDTRIP_NAME")" \
    "$(printf 'kid-cy\tCy\towl')"
  ROUNDTRIP_CONF="$OMARCHY_KIDS_ROOT/usr/share/sddm/themes/omarchy-kids/theme.conf.user"
  conf="$(cat "$ROUNDTRIP_CONF")"
  kids="$(portal_conf_field "$conf" kids)"
  check "$(portal_kid_name "$kids" kid-ada)" "$ROUNDTRIP_NAME" \
    "theme.conf.user: adversarial display name survives writer-reader round trip"
  check "$(portal_kid_name "$kids" kid-cy)" "Cy" \
    "theme.conf.user: second kid survives adversarial-name readback"
  check "$(portal_kid_count "$kids")" "2" \
    "theme.conf.user: adversarial display name preserves both kids"
done
check "$(grep '^kids=' "$ROUNDTRIP_CONF")" \
  'kids="kid-ada:Ada%252C%2C Cy%3A \"kid\" \\ \r:fox,kid-cy:Cy:owl"' \
  "theme.conf.user: payload encoding precedes exact QSettings escaping"
unset OMARCHY_KIDS_ROOT OMARCHY_KIDS_HOME_ROOT
check "$(portal_parse_tile_report 'qrc:/Main.qml: portal: 3 tiles (kids=2 parents=1)')" "3 2 1" \
  "portal_parse_tile_report: extracts the greeter's observed finalized counts"
portal_parse_tile_report "portal: malformed" >/dev/null 2>&1
check_status "$?" "1" "portal_parse_tile_report: malformed journal output fails"

# --- report_header / report_row ---------------------------------------------------------------

expected_header="| Scenario | Result | Screenshots |
| --- | --- | --- |"
check "$(report_header)" "$expected_header" "report_header: the fixed Markdown table header"

check "$(report_row 10-cold-boot-kid PASS 10-cold-boot-kid.png)" \
  "| 10-cold-boot-kid | PASS | 10-cold-boot-kid.png |" \
  "report_row: name, result, one screenshot"

check "$(report_row 30-portal-login-and-finish PASS 30-launcher.png,30-after-finish.png)" \
  "| 30-portal-login-and-finish | PASS | 30-launcher.png,30-after-finish.png |" \
  "report_row: multiple screenshots stay comma-joined"

check "$(report_row 90-remove FAIL "")" \
  "| 90-remove | FAIL | — |" \
  "report_row: no screenshots falls back to an em dash"

# --- ok / fail / scenario_result's PASS/FAIL line contract -------------------------------------
# (scenario_result itself calls `exit`, so it's exercised as a subshell here rather than called
# directly — the same reason test/shell.d never calls a command's own `exit` inline either.)

out="$(
  export LIVE_FAIL=0
  ok "a check"
  scenario_result some-scenario
)"
status=$?
check "$out" "ok   a check
PASS some-scenario" "scenario_result: an all-ok run prints PASS"
check_status "$status" "0" "scenario_result: an all-ok run exits 0"

out="$(
  export LIVE_FAIL=0
  ok "a check"
  fail "a broken check"
  scenario_result some-scenario
)"
status=$?
check "$out" "ok   a check
FAIL a broken check
FAIL some-scenario" "scenario_result: any fail prints FAIL"
check_status "$status" "1" "scenario_result: any fail exits 1"

# --- portal_clean_exit live inventory ---------------------------------------------------------
# Source a copied helper beside synthetic config, then own every remote call in the behavior
# fixture. This keeps command-substitution state and config reads inside the scratch tree.
BEHAVIOR_ROOT="$LIB_FIXTURE_ROOT"

(
  export OMARCHY_KIDS_VM_DRIVER_LOCKED=1
  export LIVE_OUT_DIR="$TMP/behavior-out"
  export LIVE_SSH_CFG="$TMP/does-not-exist"
  # shellcheck source=/dev/null
  source "$BEHAVIOR_ROOT/test/live/lib.sh"
  export LIVE_OUT_DIR="$TMP/behavior-out"
  LIVE_TEST_VMROOT_MODE=delayed
  LIVE_TEST_STATE_DIR="$TMP/behavior-state"
  mkdir -p "$LIVE_TEST_STATE_DIR"
  pass() { echo "ok   $*"; }
  fail_() {
    echo "FAIL $*"
    fail=1
  }
  # The source above is test/live/lib.sh, which has its own check/pass/fail for scenarios and
  # therefore shadows this file's check/check_status inside this subshell: a FAIL would print
  # while the file still exited 0. Re-declare both after the source so every assertion below
  # counts, which is how the earlier inner failures were able to pass the suite.
  check() { # got want label
    if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
      echo "FAIL $3 (want '$2', got '$1')"
      fail=1
    fi
  }
  check_status() { # got_status want_status label
    if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
      echo "FAIL $3 (want exit $2, got $1)"
      fail=1
    fi
  }
  vmroot() {
    local command="$1" calls=0
    [[ -f "$LIVE_TEST_STATE_DIR/calls" ]] && calls="$(cat "$LIVE_TEST_STATE_DIR/calls")"
    calls=$((calls + 1))
    printf '%s\n' "$calls" >"$LIVE_TEST_STATE_DIR/calls"
    case "$command" in
      *"/usr/bin/id -u kid-test"*) printf '1000\n' ;;
      *"loginctl list-sessions --no-legend"*)
        [[ "$LIVE_TEST_VMROOT_MODE" != query-failure ]] || return 1
        if [[ "$LIVE_TEST_VMROOT_MODE" == restart-failure ]]; then
          return 0 # an empty seat, so portal_reset tries the SDDM restart
        fi
        # Seat0 holds a session until the clean exit has happened; after a clean exit the
        # greeter is back on its own (issue #21, live-verified on the try-omarchy VM).
        # `autologin` starts empty and hands the seat to a session at SDDM start;
        # `session-always` never stops returning a session.
        if [[ "$LIVE_TEST_VMROOT_MODE" == session-always ]]; then
          printf '1 1000 kid-test seat0 - user\n'
        elif [[ "$LIVE_TEST_VMROOT_MODE" == autologin && ! -f "$LIVE_TEST_STATE_DIR/restart-attempt" ]]; then
          return 0
        elif [[ -f "$LIVE_TEST_STATE_DIR/dispatches" ]]; then
          printf '2 965 sddm seat0 - greeter\n'
        else
          printf '1 1000 kid-test seat0 - user\n'
        fi
        return 0
        ;;
      *"systemctl restart sddm"*)
        : >"$LIVE_TEST_STATE_DIR/restart-attempt"
        [[ "$LIVE_TEST_VMROOT_MODE" != restart-failure ]]
        ;;
      *"sleep 16"*) : >"$LIVE_TEST_STATE_DIR/sleep-attempt" ;;
      *"instances -j"*)
        local inventory_calls=0 dispatches_seen=0
        [[ -f "$LIVE_TEST_STATE_DIR/inventory-calls" ]] && inventory_calls="$(cat "$LIVE_TEST_STATE_DIR/inventory-calls")"
        inventory_calls=$((inventory_calls + 1))
        printf '%s\n' "$inventory_calls" >"$LIVE_TEST_STATE_DIR/inventory-calls"
        # Once the dispatch has gone out, the compositor is gone too -- that is
        # what portal_clean_exit now waits for (sandbox #134). A `stubborn` run
        # is a compositor hyprctl says it exited but which is still there.
        [[ -f "$LIVE_TEST_STATE_DIR/dispatches" ]] && dispatches_seen="$(cat "$LIVE_TEST_STATE_DIR/dispatches")"
        # `session-always` keeps a compositor on every odd read: portal_clean_exit's find
        # sees one, its confirmation sees it gone, and the next attempt finds one again,
        # so the seat can keep handing back a session until portal_reset's bound is hit.
        if [[ "$LIVE_TEST_VMROOT_MODE" == session-always ]]; then
          if ((inventory_calls % 2 == 1)); then
            printf '[{"instance":"live","wl_socket":"wayland-1","pid":2}]\n'
          else
            printf '[]\n'
          fi
          return 0
        fi
        if ((dispatches_seen >= 1)) && [[ "$LIVE_TEST_VMROOT_MODE" != stubborn ]]; then
          printf '[]\n'
          return 0
        fi
        case "$LIVE_TEST_VMROOT_MODE:$inventory_calls" in
          delayed:1) printf '[{"instance":"old","wl_socket":"wayland-0","pid":1}]\n' ;;
          delayed:*) printf '[{"instance":"live","wl_socket":"wayland-1","pid":2}]\n' ;;
          malformed-delayed:1) printf ']\n' ;;
          malformed-delayed:*) printf '[{"instance":"live","wl_socket":"wayland-1","pid":2}]\n' ;;
          malformed:*) printf ']\n' ;;
          ambiguous:*) printf '[{"instance":"one","wl_socket":"wayland-1","pid":2},{"instance":"two","wl_socket":"wayland-1","pid":3}]\n' ;;
          *) printf '[{"instance":"live","wl_socket":"wayland-1","pid":2}]\n' ;;
        esac
        ;;
      *"dispatch 'hl.dsp.exit()'"*)
        local dispatches=0
        [[ -f "$LIVE_TEST_STATE_DIR/dispatches" ]] && dispatches="$(cat "$LIVE_TEST_STATE_DIR/dispatches")"
        dispatches=$((dispatches + 1))
        printf '%s\n' "$dispatches" >"$LIVE_TEST_STATE_DIR/dispatches"
        [[ "$LIVE_TEST_VMROOT_MODE" != dispatch-failure ]]
        ;;
      *) return 1 ;;
    esac
  }
  sleep() { :; }
  assert_greeter() { :; }

  portal_clean_exit kid-test 10
  check_status "$?" "0" "portal_clean_exit: delayed inventory waits for a live instance"
  # Two queries to find the live instance, and one more to confirm it really
  # left after the dispatch (sandbox #134).
  check "$(cat "$LIVE_TEST_STATE_DIR/inventory-calls")" "3" \
    "portal_clean_exit: delayed inventory queried twice, then once to confirm the exit"
  check "$(cat "$LIVE_TEST_STATE_DIR/dispatches")" "1" \
    "portal_clean_exit: dispatches exactly once after readiness"
  LIVE_TEST_VMROOT_MODE=malformed
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/inventory-calls"
  portal_clean_exit kid-test 0
  check_status "$?" "1" "portal_clean_exit: malformed inventory is not treated as ready"
  LIVE_TEST_VMROOT_MODE=ambiguous
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/inventory-calls"
  portal_clean_exit kid-test 0
  check_status "$?" "1" "portal_clean_exit: ambiguous inventory is rejected"
  # hyprctl accepts the exit and the compositor stays anyway (sandbox #134):
  # the helper must not report a clean exit for a session still on wayland-1.
  LIVE_TEST_VMROOT_MODE=stubborn
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/inventory-calls" "$LIVE_TEST_STATE_DIR/dispatches"
  portal_clean_exit kid-test 10
  check_status "$?" "1" "portal_clean_exit: a compositor that stays after the dispatch is not a clean exit"
  check "$(cat "$LIVE_TEST_STATE_DIR/dispatches")" "1" \
    "portal_clean_exit: the stubborn case still dispatched exactly once"
  LIVE_TEST_VMROOT_MODE=malformed-delayed
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/inventory-calls" "$LIVE_TEST_STATE_DIR/dispatches"
  portal_clean_exit kid-test 10
  check_status "$?" "0" "portal_clean_exit: invalid inventory waits for a later valid query"
  check "$(cat "$LIVE_TEST_STATE_DIR/inventory-calls")" "3" \
    "portal_clean_exit: invalid inventory queried twice, then once to confirm the exit"
  LIVE_TEST_VMROOT_MODE=dispatch-failure
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/inventory-calls"
  rm -f "$LIVE_TEST_STATE_DIR/dispatches"
  portal_clean_exit kid-test 0
  check_status "$?" "1" "portal_clean_exit: dispatch failure propagates"
  check "$(cat "$LIVE_TEST_STATE_DIR/dispatches")" "1" \
    "portal_clean_exit: dispatch failure reached the dispatcher"
  LIVE_TEST_VMROOT_MODE=dispatch-failure
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/inventory-calls" "$LIVE_TEST_STATE_DIR/dispatches"
  portal_reset 0
  check_status "$?" "1" "portal_reset: clean-exit failure propagates"
  check "$(cat "$LIVE_TEST_STATE_DIR/inventory-calls")" "1" \
    "portal_reset: dispatch case queried inventory once"
  check "$(cat "$LIVE_TEST_STATE_DIR/dispatches")" "1" \
    "portal_reset: dispatch case attempted exactly once"
  LIVE_TEST_VMROOT_MODE=query-failure
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/restart-attempt"
  portal_reset 0
  check_status "$?" "1" "portal_reset: session query failure propagates"
  [[ ! -e "$LIVE_TEST_STATE_DIR/restart-attempt" ]] &&
    pass "portal_reset: query failure does not restart SDDM" ||
    fail_ "portal_reset restarted SDDM after query failure"
  LIVE_TEST_VMROOT_MODE=restart-failure
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/restart-attempt" "$LIVE_TEST_STATE_DIR/sleep-attempt"
  portal_reset 0
  check_status "$?" "1" "portal_reset: SDDM restart failure propagates"
  [[ -e "$LIVE_TEST_STATE_DIR/restart-attempt" ]] &&
    pass "portal_reset: restart failure attempted SDDM restart" ||
    fail_ "portal_reset skipped SDDM restart"
  [[ ! -e "$LIVE_TEST_STATE_DIR/sleep-attempt" ]] &&
    pass "portal_reset: restart failure skips the wait" ||
    fail_ "portal_reset waited after restart failure"
  LIVE_TEST_VMROOT_MODE=
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/restart-attempt" "$LIVE_TEST_STATE_DIR/dispatches"
  portal_reset 0
  check_status "$?" "0" "portal_reset: a session's clean exit returns the greeter"
  check "$(cat "$LIVE_TEST_STATE_DIR/dispatches")" "1" \
    "portal_reset: exited the session exactly once"
  LIVE_TEST_VMROOT_MODE=autologin
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/restart-attempt" "$LIVE_TEST_STATE_DIR/dispatches"
  portal_reset 0
  check_status "$?" "0" "portal_reset: an empty seat restarts into a session and still ends at the greeter"
  [[ -e "$LIVE_TEST_STATE_DIR/restart-attempt" ]] &&
    pass "portal_reset: restarted SDDM when the seat was empty" ||
    fail_ "portal_reset skipped the SDDM restart on an empty seat"
  check "$(cat "$LIVE_TEST_STATE_DIR/dispatches")" "1" \
    "portal_reset: exited the autologin session exactly once"
  LIVE_TEST_VMROOT_MODE=session-always
  : >"$LIVE_TEST_STATE_DIR/calls"
  rm -f "$LIVE_TEST_STATE_DIR/dispatches"
  portal_reset 0
  check_status "$?" "1" "portal_reset: a seat that keeps coming back as a session fails"
  check "$(cat "$LIVE_TEST_STATE_DIR/dispatches")" "3" \
    "portal_reset: bounded at three attempts, not endless"
  # Last: this case hides jq for the rest of the subshell, so nothing may follow it that
  # needs jq (or cat/rm on the real PATH).
  mkdir -p "$TMP/no-jq"
  rm -f "$LIVE_TEST_STATE_DIR/restart-attempt"
  # shellcheck disable=SC2123 # intentionally hide jq while exercising the host prerequisite
  PATH="$TMP/no-jq"
  portal_reset 0
  check_status "$?" "1" "portal_reset: missing jq fails before VM mutation"
  [[ ! -e "$LIVE_TEST_STATE_DIR/restart-attempt" ]] &&
    pass "portal_reset: missing jq does not restart SDDM" ||
    fail_ "portal_reset mutated SDDM without jq"
  exit $fail
)
behavior_status=$?
((behavior_status == 0)) || fail=1

exit $fail
