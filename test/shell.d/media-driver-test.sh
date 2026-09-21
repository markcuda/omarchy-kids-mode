#!/bin/bash
# Tests scripts/media-driver.sh (docs/GOAL.md item 3, SPEC.md R-BUILD-3): defaults,
# one-surface runs, failure continuation, command order, and state restoration.
set -uo pipefail
# The gate may invoke this unit while its outer driver already holds the
# shared lock. Each fixture owns its own substituted lock, so inherit no
# global lock state from that caller.
unset OMARCHY_KIDS_VM_DRIVER_LOCKED
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TMP="$(mktemp -d)"
GUI_TOOLS=""
cleanup() {
  rm -rf "$TMP"
  [[ -z "$GUI_TOOLS" ]] || rm -rf "$GUI_TOOLS"
}
trap cleanup EXIT

fail=0
pass() { echo "ok   $1"; }
fail_() {
  echo "FAIL $1"
  fail=1
}
check() {
  if [[ "$1" == "$2" ]]; then pass "$3"; else
    fail_ "$3 (want '$2', got '$1')"
  fi
}
check_contains() {
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else
    fail_ "$3 (missing '$2')"
  fi
}
check_file_contains() {
  if grep -Fq "$2" "$1"; then pass "$3"; else
    fail_ "$3 (missing '$2')"
  fi
}

make_fixture() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/test/live" "$root/docs/media"
  cp "$DIR/scripts/media-driver.sh" "$root/scripts/media-driver.sh"
  cp "$DIR/scripts/vm-driver-lock" "$root/scripts/vm-driver-lock"
  sed -i.bak "s#/tmp/omarchy-kids-vm-driver.lock#$root/vm-driver.lock#" "$root/scripts/vm-driver-lock"
  rm -f "$root/scripts/vm-driver-lock.bak"
  cat >"$root/scripts/image-contains-text" <<'EOF'
#!/bin/bash
: "${MEDIA_TEST_LOG:?}"
printf 'image-contains-text %s\n' "$*" >>"$MEDIA_TEST_LOG"
image_name="$(basename "$1")"
if [[ "$image_name" == *wifi-picker* && -n "${MEDIA_TEST_WIFI_TEXT:-}" ]]; then
  contents="$(cat "$1")"
  for required in "${@:2}"; do
    [[ "$contents" == *"$required"* ]] || exit 1
  done
fi
[[ -z "${MEDIA_TEST_NEVER_RENDER:-}" || "$*" != *"$MEDIA_TEST_NEVER_RENDER"* ]] || exit 1
[[ "${MEDIA_TEST_BAD_IMAGE:-}" != "$image_name" ]] || exit 1
[[ "${MEDIA_TEST_TIMES_UP_IMAGE:-1}" == 1 ]]
EOF
  chmod +x "$root/scripts/media-driver.sh" "$root/scripts/vm-driver-lock" \
    "$root/scripts/image-contains-text"
  cat >"$root/test/live/lib.sh" <<'EOF'
LIVE_OWNER_PASSWORD=owner-password
LIVE_OWNER_ACCOUNT=kid-test
LIVE_KID1_ACCOUNT=kid-cy
LIVE_KID1_PASSWORD=kid-password
: "${MEDIA_TEST_LOG:?}"
if [[ -n "${MEDIA_TEST_WRONG_OUT:-}" ]]; then
  LIVE_OUT_DIR="$MEDIA_TEST_WRONG_OUT"
  mkdir -p "$LIVE_OUT_DIR"
fi
log() { printf '%s\n' "$*" >>"$MEDIA_TEST_LOG"; }
sleep() { :; }
boot_with() {
  log "boot_with $*"
  if [[ -n "${MEDIA_TEST_HOLD:-}" ]]; then
    : >"$MEDIA_TEST_HOLD.ready"
    while [[ ! -e "$MEDIA_TEST_HOLD.release" ]]; do /bin/sleep 0.01; done
  fi
}
portal_login() {
  log "portal_login $*"
  [[ "$1" != "$LIVE_OWNER_ACCOUNT" ]] || : >"$MEDIA_TEST_LOG.owner-session"
}
wait_kid_ready() { log "wait_kid_ready $*"; }
portal_reset() {
  log "portal_reset $*"
  if [[ "${MEDIA_TEST_FAIL_PORTAL_RESET:-0}" == 1 ||
    ( "${MEDIA_TEST_FAIL_PORTAL_RESET_CLEANUP:-0}" == 1 && -e "$MEDIA_TEST_LOG.capture-started" ) ]]; then
    return 1
  fi
  if [[ "${MEDIA_TEST_RESIDUAL_OWNER:-0}" != 1 ]]; then
    rm -f "$MEDIA_TEST_LOG.owner-session"
  fi
  MEDIA_TEST_PORTAL_RESET_DONE=1
  assert_greeter "$1"
}
portal_clean_exit() { log "portal_clean_exit $*"; }
assert_greeter() {
  log "assert_greeter $*"
  [[ "${MEDIA_TEST_STALE_GREETER:-0}" != 1 || "${MEDIA_TEST_GREETER_RELOADED:-0}" == 1 ]] || return 1
  [[ "${MEDIA_TEST_OWNER_AUTLOGIN:-0}" != 1 || "${MEDIA_TEST_PORTAL_RESET_DONE:-0}" == 1 ]]
}
assert_no_session() { log "assert_no_session $*"; }
qmp() { log "qmp $*"; }
shot() {
  local name="$1"
  log "shot $name"
  : >"$MEDIA_TEST_LOG.capture-started"
  [[ "${MEDIA_TEST_FAIL_SHOT:-}" != "$name" ]] || return 1
  if [[ "$name" == *wifi-picker* && -n "${MEDIA_TEST_WIFI_TEXT:-}" ]]; then
    if [[ "$name" == wifi-picker-* && -n "${MEDIA_TEST_WIFI_FINAL_TEXT:-}" ]]; then
      printf '%s\n' "$MEDIA_TEST_WIFI_FINAL_TEXT" >"$LIVE_OUT_DIR/$name.png"
    else
      printf '%s\n' "$MEDIA_TEST_WIFI_TEXT" >"$LIVE_OUT_DIR/$name.png"
    fi
  else
    printf 'png\n' >"$LIVE_OUT_DIR/$name.png"
  fi
  echo "$name.png"
}
vm() {
  log "vm $*"
  if [[ -n "${MEDIA_TEST_FAIL_VM:-}" && "$*" == *"$MEDIA_TEST_FAIL_VM"* ]]; then
    return 1
  fi
  case "$*" in
    *omarchy-theme-current*) echo original-owner ;;
    *omarchy-kids-bar\ status*)
      if [[ "${MEDIA_TEST_BAR_ENABLED:-1}" == 1 ]]; then echo enabled; else echo disabled; fi
      ;;
  esac
}
vmroot() {
  log "vmroot $*"
  if [[ -n "${MEDIA_TEST_FAIL_VMROOT_ONCE:-}" && "$*" == *"$MEDIA_TEST_FAIL_VMROOT_ONCE"* &&
    ! -e "$MEDIA_TEST_STATE_DIR/fail-once" ]]; then
    : >"$MEDIA_TEST_STATE_DIR/fail-once"
    return 1
  fi
  if [[ -n "${MEDIA_TEST_FAIL_VMROOT_AFTER_START:-}" &&
    "$*" == *"$MEDIA_TEST_FAIL_VMROOT_AFTER_START"* && -e "$MEDIA_TEST_LOG.bar-session" ]]; then
    return 255
  fi
  if [[ -n "${MEDIA_TEST_FAIL_VMROOT:-}" && "$*" == *"$MEDIA_TEST_FAIL_VMROOT"* ]]; then
    return 255
  fi
  if [[ "$*" == *hyprctl*instances*-j* ]]; then
    if [[ "${MEDIA_TEST_OWNER_SESSION:-1}" == 0 && ! -e "$MEDIA_TEST_LOG.owner-session" ]]; then
      return 1
    fi
    case "${MEDIA_TEST_GUI_STATE:-valid}" in
      valid)
        if [[ "$*" == *"acct='kid-cy'"* ]]; then
          printf 'HOME=/home/kid-cy\nUSER=kid-cy\nLOGNAME=kid-cy\nOMARCHY_PATH=/usr/share/omarchy\nXDG_RUNTIME_DIR=/run/user/1001\nWAYLAND_DISPLAY=wayland-1\nHYPRLAND_INSTANCE_SIGNATURE=instance-valid\nXDG_SESSION_ID=13\nDBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus\n'
        else
          printf 'HOME=/home/kid-test\nUSER=kid-test\nLOGNAME=kid-test\nOMARCHY_PATH=/usr/share/omarchy\nXDG_RUNTIME_DIR=/run/user/1000\nWAYLAND_DISPLAY=wayland-1\nHYPRLAND_INSTANCE_SIGNATURE=instance-valid\nXDG_SESSION_ID=12\nDBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus\n'
        fi
        ;;
      missing | ambiguous | owner-mismatch) return 1 ;;
    esac
    return 0
  fi
  case "$*" in
    *omarchy-shell*notifications*dismiss*)
      printf '%s\n' "${MEDIA_TEST_NOTICE_REPLY:-ok}"
      return "${MEDIA_TEST_NOTICE_STATUS:-0}"
      ;;
    *"systemctl show --property=LoadState --property=ActiveState --property=SubState"*)
      if [[ "${MEDIA_TEST_FAIL_COLLECTED_QUERY:-0}" == 1 ]]; then
        return 1
      fi
      if [[ -e "$MEDIA_TEST_LOG.bar-session" ]]; then
        printf 'LoadState=loaded\nActiveState=active\nSubState=running\n'
      elif [[ "${MEDIA_TEST_COLLECTED_STATE:-collected}" == loaded-inactive ]]; then
        printf 'LoadState=loaded\nActiveState=inactive\nSubState=dead\n'
      else
        printf 'LoadState=not-found\nActiveState=inactive\nSubState=dead\n'
      fi
      ;;
    *"loginctl list-sessions --no-legend"*)
      if [[ "${MEDIA_TEST_FAIL_SESSION_QUERY:-0}" == 1 ]]; then
        return 1
      fi
      if [[ -e "$MEDIA_TEST_LOG.owner-session" ]]; then
        printf '1 1000 kid-test seat0 - online\n'
      fi
      if [[ "${MEDIA_TEST_RESIDUAL_OWNER:-0}" == 1 ]]; then
        printf '2 1000 kid-test seat0 - background\n'
      fi
      if [[ "${MEDIA_TEST_RESIDUAL_KID:-0}" == 1 ]]; then
        printf '3 1001 kid-cy seat0 - online\n'
      fi
      ;;
    *"systemctl restart sddm"*)
      if [[ "${MEDIA_TEST_OWNER_AUTLOGIN:-0}" == 1 ]]; then
        : >"$MEDIA_TEST_LOG.owner-session"
      fi
      MEDIA_TEST_GREETER_RELOADED=1
      ;;
    *"pgrep -u kid-test -f Hyprland"*)
      [[ "${MEDIA_TEST_OWNER_SESSION:-1}" == 1 || -e "$MEDIA_TEST_LOG.owner-session" ]]
      ;;
    *"systemctl is-active --quiet omarchy-kids-time.timer"*)
      [[ "${MEDIA_TEST_TIMER_ACTIVE:-1}" == 1 ]]
      ;;
    *"systemctl is-active --quiet omarchy-kids-media-session.service"*)
      if [[ -e "$MEDIA_TEST_LOG.bar-session" ]]; then
        return 0
      else
        return "${MEDIA_TEST_IS_ACTIVE_ABSENT_STATUS:-3}"
      fi
      ;;
    *"systemd-run --quiet --collect --unit=omarchy-kids-media-session"*)
      [[ "${MEDIA_TEST_PRECOLLECTED:-0}" == 1 ]] || : >"$MEDIA_TEST_LOG.bar-session"
      ;;
    *"systemctl stop omarchy-kids-media-session.service"*)
      rm -f "$MEDIA_TEST_LOG.bar-session"
      ;;
    *timesUpReady*)
      [[ "${MEDIA_TEST_TIMES_UP_READY:-1}" == 1 ]] && echo true || echo false
      ;;
    *"omarchy-kids-conf source kid-cy theme"*)
      if [[ "${MEDIA_TEST_INHERITED:-0}" == 1 ]]; then echo default; else echo override; fi
      ;;
    *"omarchy-kids-conf source kid-cy lights_out_weekend"*)
      if [[ "${MEDIA_TEST_INHERITED:-0}" == 1 ]]; then echo band; else echo override; fi
      ;;
    *"omarchy-kids-conf source kid-cy lights_out"*)
      if [[ "${MEDIA_TEST_INHERITED:-0}" == 1 ]]; then echo band; else echo override; fi
      ;;
    *"omarchy-kids-conf source kid-cy wifi"*)
      if [[ "${MEDIA_TEST_INHERITED:-0}" == 1 ]]; then echo band; else echo override; fi
      ;;
    *"omarchy-kids-conf set kid-cy lights_out_weekend 00:01"*)
      [[ -z "${MEDIA_TEST_STATE_DIR:-}" ]] || printf '00:01\n' >"$MEDIA_TEST_STATE_DIR/lights_out_weekend"
      ;;
    *"omarchy-kids-conf set kid-cy lights_out_weekend 22:00"*)
      [[ -z "${MEDIA_TEST_STATE_DIR:-}" ]] || printf '22:00\n' >"$MEDIA_TEST_STATE_DIR/lights_out_weekend"
      ;;
    *"omarchy-kids-conf set kid-cy lights_out 00:01"*)
      [[ -z "${MEDIA_TEST_STATE_DIR:-}" ]] || printf '00:01\n' >"$MEDIA_TEST_STATE_DIR/lights_out"
      ;;
    *"omarchy-kids-conf set kid-cy lights_out 21:00"*)
      [[ -z "${MEDIA_TEST_STATE_DIR:-}" ]] || printf '21:00\n' >"$MEDIA_TEST_STATE_DIR/lights_out"
      ;;
    *"omarchy-kids-conf get kid-cy lights_out_weekend"*)
      if [[ -n "${MEDIA_TEST_STATE_DIR:-}" ]]; then cat "$MEDIA_TEST_STATE_DIR/lights_out_weekend"; else echo 22:00; fi
      ;;
    *"omarchy-kids-conf get kid-cy theme"*) echo original-kid ;;
    *"omarchy-kids-conf get kid-cy lights_out"*)
      if [[ -n "${MEDIA_TEST_STATE_DIR:-}" ]]; then cat "$MEDIA_TEST_STATE_DIR/lights_out"; else echo 21:00; fi
      ;;
    *"omarchy-kids-conf get kid-cy wifi"*) echo parent ;;
    *"omarchy-kids-conf get kid-cy band"*) echo 6-8 ;;
    *"omarchy-kids-conf get kid-cy name"*) echo Cy ;;
  esac
}
EOF
}

ROOT1="$TMP/default"
make_fixture "$ROOT1"
LOG1="$TMP/default.log"
WRONG_OUT="$TMP/configured-live-out"
MEDIA_TEST_LOG="$LOG1" MEDIA_TEST_WRONG_OUT="$WRONG_OUT" \
  "$ROOT1/scripts/media-driver.sh" >"$TMP/default.out" 2>&1
status=$?
check "$status" "0" "default run exits 0"
check "$(find "$ROOT1/docs/media" -name '*.png' | wc -l | tr -d ' ')" "20" \
  "default run writes ten honest surfaces under two themes"
check "$(find "$WRONG_OUT" -name '*.png' | wc -l | tr -d ' ')" "0" \
  "config.env's acceptance output cannot divert release pictures"
for theme in tokyo-night catppuccin-latte; do
  for surface in portal launcher exit-modal ask times-up wifi-picker plugins-shelf wizard panel bar-module; do
    [[ -s "$ROOT1/docs/media/$surface-$theme.png" ]] &&
      pass "$surface is captured under $theme" || fail_ "$surface is missing under $theme"
  done
done
log1="$(cat "$LOG1")"
while IFS='|' read -r surface required; do
  for theme in tokyo-night catppuccin-latte; do
    check_file_contains "$LOG1" "/media-ready-$surface-$theme.png $required" \
      "$surface waits for rendered text under $theme"
    check_file_contains "$LOG1" "/$surface-$theme.png $required" \
      "$surface verifies required text in the release PNG under $theme"
  done
done <<'EOF'
portal|Cy
launcher|GCompris
exit-modal|Finish for Cy
ask|Ask a grown-up 15 more minutes
times-up|Time's up Closing in
wifi-picker|Wi-Fi choose Enter join Esc close
plugins-shelf|More apps Pick one
wizard|Welcome Begin
panel|Kids Mode Add a kid
bar-module|live Open Kids Mode
EOF
check_contains "$log1" "boot_with owner-password kid-test" "driver starts from a known owner boot"
check_contains "$log1" "export OMARCHY_PATH=/usr/share/omarchy; /usr/bin/omarchy-theme-set tokyo-night" \
  "parent theme uses omarchy-theme-set with OMARCHY_PATH"
check_contains "$log1" "omarchy-kids-conf set kid-cy theme tokyo-night" \
  "kid theme follows the requested theme"
check_contains "$log1" "omarchy-kids-assert" "portal producer is refreshed"
check_contains "$log1" "systemctl restart sddm" "SDDM restarts before portal capture"
assert_line="$(grep -n 'omarchy-kids-assert' "$LOG1" | head -1 | cut -d: -f1)"
restart_line="$(grep -n 'systemctl restart sddm' "$LOG1" | head -1 | cut -d: -f1)"
portal_line="$(grep -n 'shot portal-tokyo-night' "$LOG1" | head -1 | cut -d: -f1)"
if [[ -n "$assert_line" && -n "$restart_line" && -n "$portal_line" ]] &&
  ((assert_line < restart_line && restart_line < portal_line)); then
  pass "portal config is produced, SDDM restarted, then the portal is captured"
else
  fail_ "portal producer/restart/capture order"
fi
check_contains "$log1" "omarchy-theme-set original-owner" "parent theme is restored"
check_contains "$log1" "omarchy-kids-conf set kid-cy theme original-kid" "kid theme is restored"
bad_root_calls="$(grep '^vmroot ' "$LOG1" | grep -v '^vmroot env -i PATH=/usr/bin:/bin' || true)"
check "$bad_root_calls" "" "driver-owned root commands work without inherited environment or HOME"
if [[ "$log1" != *"omarchy-kids-bar enable"* ]]; then
  pass "driver never enables or rewrites the parent's bar"
else
  fail_ "driver changed the parent's bar"
fi
if [[ "$log1" != *"systemctl stop omarchy-kids-time.timer"* ]]; then
  pass "driver never freezes the live-status producer for a screenshot"
else
  fail_ "driver froze the live-status producer"
fi

ROOT2="$TMP/single"
make_fixture "$ROOT2"
LOG2="$TMP/single.log"
MEDIA_TEST_LOG="$LOG2" "$ROOT2/scripts/media-driver.sh" --surface ask nord >"$TMP/single.out" 2>&1
status=$?
check "$status" "0" "single-surface run exits 0"
check "$(find "$ROOT2/docs/media" -name '*.png' | wc -l | tr -d ' ')" "1" \
  "--surface captures only one requested picture"
[[ -s "$ROOT2/docs/media/ask-nord.png" ]] && pass "positional theme argument is used" ||
  fail_ "positional theme argument was not used"

ROOT3="$TMP/failure"
make_fixture "$ROOT3"
LOG3="$TMP/failure.log"
MEDIA_TEST_LOG="$LOG3" MEDIA_TEST_FAIL_SHOT=ask-tokyo-night \
  "$ROOT3/scripts/media-driver.sh" tokyo-night >"$TMP/failure.out" 2>&1
status=$?
check "$status" "1" "a failed surface makes the run fail"
[[ ! -e "$ROOT3/docs/media/ask-tokyo-night.png" ]] &&
  pass "a failed copy does not land a partial image" || fail_ "failed copy landed an image"
[[ -s "$ROOT3/docs/media/times-up-tokyo-night.png" ]] &&
  pass "the run continues after one surface fails" || fail_ "run stopped after one surface failed"
log3="$(cat "$LOG3")"
check_contains "$log3" "omarchy-theme-set original-owner" "failure path restores the parent theme"
check_contains "$log3" "omarchy-kids-conf set kid-cy theme original-kid" \
  "failure path restores the kid theme"

ROOT4="$TMP/partial"
make_fixture "$ROOT4"
LOG4="$TMP/partial.log"
MEDIA_TEST_LOG="$LOG4" MEDIA_TEST_FAIL_VMROOT="lights_out_weekend 00:01" \
  "$ROOT4/scripts/media-driver.sh" --surface times-up tokyo-night >"$TMP/partial.out" 2>&1
status=$?
check "$status" "1" "a partial Time's Up setup makes the run fail"
log4="$(cat "$LOG4")"
check_contains "$log4" "omarchy-kids-conf set kid-cy lights_out 21:00" \
  "a partial Time's Up setup restores the weekday setting"
check_contains "$log4" "omarchy-kids-conf set kid-cy lights_out_weekend 22:00" \
  "a partial Time's Up setup restores the weekend setting"

ROOT5="$TMP/bar-live"
make_fixture "$ROOT5"
LOG5="$TMP/bar-live.log"
MEDIA_TEST_LOG="$LOG5" \
  "$ROOT5/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-live.out" 2>&1
status=$?
check "$status" "0" "the bar is captured from a live owner session"
[[ -s "$ROOT5/docs/media/bar-module-tokyo-night.png" ]] &&
  pass "the verified bar image is released" || fail_ "the verified bar image is missing"
log5="$(cat "$LOG5")"
check_contains "$log5" "systemd-run --quiet --collect --unit=omarchy-kids-media-session --property=PAMName=login --uid=kid-cy /usr/bin/sleep infinity" \
  "the bar uses a real concurrent kid login session"
check_contains "$log5" "systemctl is-active --quiet omarchy-kids-time.timer" \
  "the bar requires the real status timer to remain active"
check_contains "$log5" "/usr/bin/test" \
  "the owner session itself can read the live status file"
check_contains "$log5" "omarchy-kids-time-ledger tick" \
  "the live status producer reads the concurrent kid session"
check_contains "$log5" ".live == true and .paused == false" \
  "the bar waits for fresh live, unpaused status"
check_contains "$log5" "omarchy-kids.bar" \
  "the owner opens the real enabled bar widget"
check_contains "$log5" "systemctl stop omarchy-kids-media-session.service" \
  "the temporary kid login is closed after capture"
if [[ "$log5" != *"systemctl stop omarchy-kids-time.timer"* &&
  "$log5" != *"hl.dsp.exit"* ]]; then
  pass "the bar capture neither freezes updates nor removes a compositor"
else
  fail_ "the bar capture froze updates or removed a compositor"
fi

ROOT5D="$TMP/owner-autologin"
make_fixture "$ROOT5D"
LOG5D="$TMP/owner-autologin.log"
MEDIA_TEST_LOG="$LOG5D" MEDIA_TEST_OWNER_AUTLOGIN=1 \
  "$ROOT5D/scripts/media-driver.sh" --surface portal tokyo-night >"$TMP/owner-autologin.out" 2>&1
status=$?
check "$status" "0" "portal capture resets an owner autologin before asserting the greeter"
log5d="$(cat "$LOG5D")"
check_contains "$log5d" "portal_reset 60" \
  "owner-autologin fixture uses the shared portal reset"
check_contains "$log5d" "vmroot env -i PATH=/usr/bin:/bin /usr/bin/loginctl list-sessions --no-legend" \
  "owner-autologin cleanup queries seat sessions explicitly"
if [[ "$log5d" == *"portal_reset 60"* && "$log5d" == *"assert_greeter 60"* ]]; then
  pass "owner-autologin fixture reaches the greeter after portal reset"
else
  fail_ "owner-autologin fixture did not reach the greeter after portal reset"
fi

# Execute the production selector itself. Only its external paths are relocated.
GUI_TOOLS="$(mktemp -d /tmp/kids-gui.XXXXXX)"
mkdir -p "$GUI_TOOLS/proc/4242" "$GUI_TOOLS/runtime/1000" "$GUI_TOOLS/bin"
for tool in cat jq; do
  ln -s "$(command -v "$tool")" "$GUI_TOOLS/bin/$tool"
done
printf 'Hyprland\n' >"$GUI_TOOLS/proc/4242/comm"
cat >"$GUI_TOOLS/bin/id" <<'EOF'
#!/bin/bash
printf '1000\n'
EOF
cat >"$GUI_TOOLS/bin/loginctl" <<'EOF'
#!/bin/bash
state=$(cat "$(dirname "$0")/../state")
[[ "$state" != missing-seat ]] || exit 0
printf '12 1000 kid-test seat0 - user\n'
[[ "$state" != seat-query-failure ]] || exit 1
[[ "$state" != ambiguous-seat ]] || printf '13 1000 kid-test seat0 - user\n'
EOF
cat >"$GUI_TOOLS/bin/runuser" <<'EOF'
#!/bin/bash
while (($#)) && [[ "$1" != -- ]]; do shift; done
(($#)) || exit 1
shift
exec "$@"
EOF
cat >"$GUI_TOOLS/bin/hyprctl" <<'EOF'
#!/bin/bash
state=$(cat "$(dirname "$0")/../state")
case "$state" in
  query-failure) exit 1 ;;
  missing) printf '[]\n' ;;
  ambiguous) printf '[{"pid":4242,"instance":"first","wl_socket":"wayland-1"},{"pid":4243,"instance":"second","wl_socket":"wayland-1"}]\n' ;;
  *) printf '[{"pid":4242,"instance":"instance-valid","wl_socket":"wayland-1"}]\n' ;;
esac
EOF
cat >"$GUI_TOOLS/bin/stat" <<'EOF'
#!/bin/bash
state=$(cat "$(dirname "$0")/../state")
if [[ "$state" == owner-mismatch ]]; then echo 1001; else echo 1000; fi
EOF
cat >"$GUI_TOOLS/bin/getent" <<'EOF'
#!/bin/bash
printf 'kid-test:x:1000:1000::/home/kid-test:/bin/bash\n'
EOF
chmod +x "$GUI_TOOLS/bin/"{id,loginctl,runuser,hyprctl,stat,getent}
# A bound, closed Unix socket leaves the owned filesystem node; no helper process persists.
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' \
  "$GUI_TOOLS/runtime/1000/wayland-1"
{
  # shellcheck disable=SC2016 # These are literal definitions for the copied selector.
  printf '%s\n' '#!/bin/bash' 'set -uo pipefail' \
    'shell_quote() { printf "%q" "$1"; }' 'vmroot() { /bin/bash -c "$1"; }'
  sed -n '/^gui_session_env() {/,/^run_gui_command() {/p' "$DIR/scripts/media-driver.sh" | sed '$d' |
    sed -e "s#/usr/bin/#$GUI_TOOLS/bin/#g" \
      -e "s#runuser #$GUI_TOOLS/bin/runuser #g" \
      -e "s#/proc/#$GUI_TOOLS/proc/#g" \
      -e "s#/run/user/#$GUI_TOOLS/runtime/#g"
  printf '%s\n' 'gui_session_env kid-test'
} >"$GUI_TOOLS/selector.sh"
printf 'valid\n' >"$GUI_TOOLS/state"
gui_actual=$(bash "$GUI_TOOLS/selector.sh")
gui_status=$?
gui_expected=$(printf 'HOME=/home/kid-test\nUSER=kid-test\nLOGNAME=kid-test\nLANG=C.UTF-8\nOMARCHY_PATH=/usr/share/omarchy\nXDG_RUNTIME_DIR=%s/runtime/1000\nWAYLAND_DISPLAY=wayland-1\nHYPRLAND_INSTANCE_SIGNATURE=instance-valid\nXDG_SESSION_ID=12\nDBUS_SESSION_BUS_ADDRESS=unix:path=%s/runtime/1000/bus' "$GUI_TOOLS" "$GUI_TOOLS")
check "$gui_status" 0 "the real selector accepts the owned compositor and socket"
check "$gui_actual" "$gui_expected" "the real selector emits every GUI field in its correct position"
for gui_state in missing ambiguous owner-mismatch query-failure missing-seat seat-query-failure ambiguous-seat wrong-process socket-absent; do
  printf '%s\n' "$gui_state" >"$GUI_TOOLS/state"
  if [[ "$gui_state" == wrong-process ]]; then printf 'bash\n' >"$GUI_TOOLS/proc/4242/comm"; fi
  if [[ "$gui_state" == socket-absent ]]; then rm "$GUI_TOOLS/runtime/1000/wayland-1"; fi
  gui_actual=$(bash "$GUI_TOOLS/selector.sh" 2>/dev/null)
  gui_status=$?
  check "$gui_status" 1 "the real selector rejects $gui_state"
  check "$gui_actual" "" "the real selector emits no guessed environment for $gui_state"
  printf 'Hyprland\n' >"$GUI_TOOLS/proc/4242/comm"
done
rm -rf "$GUI_TOOLS"
GUI_TOOLS=""

{
  sed -n '/^run_gui_command() {/,/^assert_no_seat_session() {/p' "$DIR/scripts/media-driver.sh" | sed '$d'
  cat <<'EOF'
PROBE_LOG=$1
gui_session_env() { echo probe >>"$PROBE_LOG"; return 1; }
vmroot() { echo transport >>"$PROBE_LOG"; return 1; }
sleep() { echo sleep >>"$PROBE_LOG"; }
run_gui_command kid-test true
EOF
} >"$TMP/gui-command.sh"
bash "$TMP/gui-command.sh" "$TMP/gui-command.log"
check "$?" 1 "one GUI command fails when its environment cannot be read"
check "$(cat "$TMP/gui-command.log")" probe "one GUI command probes once without nested polling or transport"

ROOT5E="$TMP/session-query-failure"
make_fixture "$ROOT5E"
LOG5E="$TMP/session-query-failure.log"
MEDIA_TEST_LOG="$LOG5E" MEDIA_TEST_FAIL_SESSION_QUERY=1 \
  "$ROOT5E/scripts/media-driver.sh" --surface portal tokyo-night >"$TMP/session-query-failure.out" 2>&1
status=$?
check "$status" "1" "cleanup fails when the seat-session query fails"
check_contains "$(cat "$TMP/session-query-failure.out")" \
  "could not confirm that kid-cy has no seat session after cleanup" \
  "session-query failure is not reported as an empty seat"

ROOT5F="$TMP/stale-greeter"
make_fixture "$ROOT5F"
LOG5F="$TMP/stale-greeter.log"
MEDIA_TEST_LOG="$LOG5F" MEDIA_TEST_STALE_GREETER=1 \
  "$ROOT5F/scripts/media-driver.sh" --surface portal tokyo-night >"$TMP/stale-greeter.out" 2>&1
status=$?
check "$status" "0" "portal capture reloads a stale greeter before reset"
check_contains "$(cat "$LOG5F")" "vmroot env -i PATH=/usr/bin:/bin /usr/bin/systemctl restart sddm" \
  "stale-greeter fixture observes the real SDDM restart"

ROOT5G="$TMP/setup-reset-failure"
make_fixture "$ROOT5G"
LOG5G="$TMP/setup-reset-failure.log"
MEDIA_TEST_LOG="$LOG5G" MEDIA_TEST_FAIL_PORTAL_RESET=1 \
  "$ROOT5G/scripts/media-driver.sh" --surface portal tokyo-night >"$TMP/setup-reset-failure.out" 2>&1
status=$?
check "$status" "1" "a setup reset failure makes the run fail"
[[ ! -e "$ROOT5G/docs/media/portal-tokyo-night.png" ]] &&
  pass "a setup reset failure prevents capture" || fail_ "setup reset failure still captured a portal"

ROOT5H="$TMP/cleanup-reset-failure"
make_fixture "$ROOT5H"
LOG5H="$TMP/cleanup-reset-failure.log"
MEDIA_TEST_LOG="$LOG5H" MEDIA_TEST_FAIL_PORTAL_RESET_CLEANUP=1 \
  "$ROOT5H/scripts/media-driver.sh" --surface portal tokyo-night >"$TMP/cleanup-reset-failure.out" 2>&1
status=$?
check "$status" "1" "a cleanup reset failure makes the run fail"
check_contains "$(cat "$TMP/cleanup-reset-failure.out")" \
  "could not reset the portal during cleanup" \
  "cleanup reset failure remains visible"

for residual in owner kid; do
  root5_residual="$TMP/residual-$residual"
  log5_residual="$TMP/residual-$residual.log"
  make_fixture "$root5_residual"
  if [[ "$residual" == owner ]]; then
    residual_env=MEDIA_TEST_RESIDUAL_OWNER=1
    residual_account=kid-test
  else
    residual_env=MEDIA_TEST_RESIDUAL_KID=1
    residual_account=kid-cy
  fi
  env MEDIA_TEST_LOG="$log5_residual" "$residual_env" \
    "$root5_residual/scripts/media-driver.sh" --surface portal tokyo-night \
    >"$TMP/residual-$residual.out" 2>&1
  status=$?
  check "$status" "1" "a residual $residual seat session makes cleanup fail"
  check_contains "$(cat "$TMP/residual-$residual.out")" \
    "could not confirm that $residual_account has no seat session after cleanup" \
    "cleanup reports the residual $residual seat session"
done

ROOT5B="$TMP/bar-disabled"
make_fixture "$ROOT5B"
LOG5B="$TMP/bar-disabled.log"
MEDIA_TEST_LOG="$LOG5B" MEDIA_TEST_BAR_ENABLED=0 \
  "$ROOT5B/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-disabled.out" 2>&1
status=$?
check "$status" "1" "a disabled parent bar is refused without changing it"
if [[ "$(cat "$LOG5B")" != *"systemd-run"* ]]; then
  pass "a disabled bar starts no temporary kid session"
else
  fail_ "a disabled bar started a temporary kid session"
fi

ROOT5C="$TMP/bar-status-failure"
make_fixture "$ROOT5C"
LOG5C="$TMP/bar-status-failure.log"
MEDIA_TEST_LOG="$LOG5C" MEDIA_TEST_FAIL_VMROOT=".live == true" \
  "$ROOT5C/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-status-failure.out" 2>&1
status=$?
check "$status" "1" "a missing fresh live status makes the bar capture fail"
check_contains "$(cat "$LOG5C")" "systemctl stop omarchy-kids-media-session.service" \
  "bar failure still closes the temporary kid login"

ROOT5D="$TMP/bar-timer-stopped"
make_fixture "$ROOT5D"
LOG5D="$TMP/bar-timer-stopped.log"
MEDIA_TEST_LOG="$LOG5D" MEDIA_TEST_TIMER_ACTIVE=0 \
  "$ROOT5D/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-timer-stopped.out" 2>&1
status=$?
check "$status" "1" "a stopped status timer makes the bar capture fail"
if [[ "$(cat "$LOG5D")" != *"systemd-run"* ]]; then
  pass "a stopped timer starts no temporary kid session"
else
  fail_ "a stopped timer started a temporary kid session"
fi

ROOT5F="$TMP/bar-status-query-failure"
make_fixture "$ROOT5F"
LOG5F="$TMP/bar-status-query-failure.log"
STATE5F="$TMP/bar-status-query-failure-state"
mkdir -p "$STATE5F"
MEDIA_TEST_LOG="$LOG5F" MEDIA_TEST_STATE_DIR="$STATE5F" \
  MEDIA_TEST_FAIL_VMROOT_AFTER_START="systemctl is-active --quiet omarchy-kids-media-session.service" \
  "$ROOT5F/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-status-query-failure.out" 2>&1
status=$?
check "$status" "1" "an uncertain temporary-session status makes the run fail"
if [[ "$(cat "$LOG5F")" != *"systemctl stop omarchy-kids-media-session.service"* ]]; then
  pass "an uncertain status never claims the temporary session is stopped"
else
  fail_ "an uncertain status attempted a stop without a confirmed active state"
fi
check "$(grep -c 'omarchy-kids-time-ledger tick' "$LOG5F")" "1" \
  "an uncertain status does not clear the dirty session through a ledger tick"

ROOT5G="$TMP/bar-stop-failure"
make_fixture "$ROOT5G"
LOG5G="$TMP/bar-stop-failure.log"
MEDIA_TEST_LOG="$LOG5G" MEDIA_TEST_FAIL_VMROOT="systemctl stop omarchy-kids-media-session.service" \
  "$ROOT5G/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-stop-failure.out" 2>&1
status=$?
check "$status" "1" "a failed temporary-session stop makes the run fail"
check_contains "$(cat "$LOG5G")" "systemctl stop omarchy-kids-media-session.service" \
  "a failed stop is attempted during cleanup"
check "$(grep -c 'omarchy-kids-time-ledger tick' "$LOG5G")" "1" \
  "a failed stop does not clear the dirty session through a ledger tick"

ROOT5H="$TMP/bar-collected-state"
make_fixture "$ROOT5H"
LOG5H="$TMP/bar-collected-state.log"
MEDIA_TEST_LOG="$LOG5H" MEDIA_TEST_IS_ACTIVE_ABSENT_STATUS=4 \
  "$ROOT5H/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-collected-state.out" 2>&1
status=$?
check "$status" "0" "a collected temporary session restores cleanly"
check_contains "$(cat "$LOG5H")" \
  "systemctl show --property=LoadState --property=ActiveState --property=SubState" \
  "cleanup verifies the collected unit state"

ROOT5I="$TMP/bar-collected-query-failure"
make_fixture "$ROOT5I"
LOG5I="$TMP/bar-collected-query-failure.log"
MEDIA_TEST_LOG="$LOG5I" MEDIA_TEST_IS_ACTIVE_ABSENT_STATUS=4 MEDIA_TEST_FAIL_COLLECTED_QUERY=1 \
  "$ROOT5I/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-collected-query-failure.out" 2>&1
status=$?
check "$status" "1" "a failed collected-state query makes cleanup fail"
check_contains "$(cat "$TMP/bar-collected-query-failure.out")" \
  "could not confirm omarchy-kids-media-session.service was collected" \
  "failed collected-state query remains visible"

ROOT5J="$TMP/bar-collected-status-four"
make_fixture "$ROOT5J"
LOG5J="$TMP/bar-collected-status-four.log"
MEDIA_TEST_LOG="$LOG5J" MEDIA_TEST_IS_ACTIVE_ABSENT_STATUS=4 MEDIA_TEST_PRECOLLECTED=1 \
  "$ROOT5J/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-collected-status-four.out" 2>&1
status=$?
check "$status" "0" "an already-collected unit with status 4 is accepted"
check_contains "$(cat "$LOG5J")" \
  "systemctl show --property=LoadState --property=ActiveState --property=SubState" \
  "an already-collected unit is confirmed through a checked state query"
if [[ "$(cat "$LOG5J")" == *"systemctl stop omarchy-kids-media-session.service"* ]]; then
  fail_ "an already-collected unit does not need a stop"
else
  pass "an already-collected unit does not need a stop"
fi

ROOT5K="$TMP/bar-loaded-inactive"
make_fixture "$ROOT5K"
LOG5K="$TMP/bar-loaded-inactive.log"
MEDIA_TEST_LOG="$LOG5K" MEDIA_TEST_COLLECTED_STATE=loaded-inactive \
  "$ROOT5K/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-loaded-inactive.out" 2>&1
status=$?
check "$status" "1" "a loaded inactive unit is not treated as collected"
check_contains "$(cat "$TMP/bar-loaded-inactive.out")" \
  "could not confirm omarchy-kids-media-session.service was collected" \
  "loaded inactive state remains visible"

ROOT5E="$TMP/bar-owner-login"
make_fixture "$ROOT5E"
LOG5E="$TMP/bar-owner-login.log"
MEDIA_TEST_LOG="$LOG5E" MEDIA_TEST_OWNER_SESSION=0 \
  "$ROOT5E/scripts/media-driver.sh" --surface bar-module tokyo-night >"$TMP/bar-owner-login.out" 2>&1
status=$?
check "$status" "0" "the bar capture can start a genuine owner session"
check_contains "$(cat "$LOG5E")" "portal_login kid-test owner-password" \
  "a missing owner session is entered through the portal"
owner_login_line="$(grep -n 'portal_login kid-test owner-password' "$LOG5E" | head -1 | cut -d: -f1)"
portal_reset_line="$(grep -n '^portal_reset' "$LOG5E" | head -1 | cut -d: -f1)"
if [[ -n "$owner_login_line" && -n "$portal_reset_line" ]] && ((portal_reset_line < owner_login_line)); then
  pass "starting the owner session does not remove another compositor"
else
  fail_ "starting the owner session removed another compositor"
fi

ROOT6="$TMP/reject"
make_fixture "$ROOT6"
LOG6="$TMP/reject.log"
: >"$LOG6"
MEDIA_TEST_LOG="$LOG6" "$ROOT6/scripts/media-driver.sh" 'bad;theme' >"$TMP/reject.out" 2>&1
status=$?
check "$status" "2" "unsafe theme names are rejected before driving the VM"
check "$(wc -l <"$LOG6" | tr -d ' ')" "0" "rejected input calls no VM helper"

ROOT7="$TMP/locked"
make_fixture "$ROOT7"
LOG7="$TMP/locked.log"
HOLD7="$TMP/driver-lock"
MEDIA_TEST_LOG="$LOG7" MEDIA_TEST_HOLD="$HOLD7" \
  "$ROOT7/scripts/media-driver.sh" --surface ask nord >"$TMP/holder.out" 2>&1 &
holder_pid=$!
for _ in {1..100}; do
  [[ -e "$HOLD7.ready" ]] && break
  /bin/sleep 0.01
done
MEDIA_TEST_LOG="$LOG7" "$ROOT7/scripts/media-driver.sh" --surface ask nord >"$TMP/contender.out" 2>&1
status=$?
check "$status" "75" "a second VM driver is refused while the shared lock is held"
check_contains "$(cat "$TMP/contender.out")" "media-driver.sh" \
  "the lock refusal identifies the run holding the VM"
if [[ "$(cat "$TMP/contender.out")" != *"nord"* ]]; then
  pass "the lock refusal does not disclose driver arguments"
else
  fail_ "the lock refusal disclosed driver arguments"
fi
: >"$HOLD7.release"
wait "$holder_pid"
check "$(grep -c '^boot_with ' "$LOG7")" "1" "the refused driver never reaches boot_with"
for driver in v1-two-sessions.sh v6-limine.sh; do
  if grep -q 'exec .*vm-driver-lock' "$DIR/scripts/$driver"; then
    pass "$driver takes the shared VM lock"
  else
    fail_ "$driver can bypass the shared VM lock"
  fi
done

ROOT8="$TMP/theme-read-failure"
make_fixture "$ROOT8"
LOG8="$TMP/theme-read-failure.log"
MEDIA_TEST_LOG="$LOG8" MEDIA_TEST_FAIL_VM="omarchy-theme-current" \
  "$ROOT8/scripts/media-driver.sh" --surface ask nord >"$TMP/theme-read-failure.out" 2>&1
status=$?
check "$status" "1" "an owner-theme read failure makes the run fail"
log8="$(cat "$LOG8")"
check_contains "$log8" "systemctl restart sddm" \
  "a theme-read failure still restarts SDDM during cleanup"
check_contains "$log8" "vmroot env -i PATH=/usr/bin:/bin /usr/bin/loginctl list-sessions --no-legend" \
  "cleanup confirms the kid session is closed"
check_contains "$log8" "vmroot env -i PATH=/usr/bin:/bin /usr/bin/loginctl list-sessions --no-legend" \
  "cleanup confirms the owner session is closed"
check_contains "$log8" "assert_greeter 60" \
  "cleanup confirms the greeter after a theme-read failure"

ROOT9="$TMP/assert-failure"
make_fixture "$ROOT9"
LOG9="$TMP/assert-failure.log"
MEDIA_TEST_LOG="$LOG9" MEDIA_TEST_FAIL_VMROOT="omarchy-kids-assert" \
  "$ROOT9/scripts/media-driver.sh" --surface portal nord >"$TMP/assert-failure.out" 2>&1
status=$?
check "$status" "1" "an assert failure makes the run fail"
log9="$(cat "$LOG9")"
assert_line="$(grep -n 'omarchy-kids-assert' "$LOG9" | tail -1 | cut -d: -f1)"
restart_line="$(grep -n 'systemctl restart sddm' "$LOG9" | tail -1 | cut -d: -f1)"
if [[ -n "$assert_line" && -n "$restart_line" ]] && ((assert_line < restart_line)); then
  pass "cleanup restarts SDDM even when the preceding assert fails"
else
  fail_ "assert failure prevented the cleanup SDDM restart"
fi
check_contains "$log9" "vmroot env -i PATH=/usr/bin:/bin /usr/bin/loginctl list-sessions --no-legend" \
  "assert-failure cleanup confirms the kid session is closed"
check_contains "$log9" "vmroot env -i PATH=/usr/bin:/bin /usr/bin/loginctl list-sessions --no-legend" \
  "assert-failure cleanup confirms the owner session is closed"

ROOT10="$TMP/inherited"
make_fixture "$ROOT10"
LOG10="$TMP/inherited.log"
MEDIA_TEST_LOG="$LOG10" MEDIA_TEST_INHERITED=1 \
  "$ROOT10/scripts/media-driver.sh" tokyo-night >"$TMP/inherited.out" 2>&1
status=$?
check "$status" "0" "a run with inherited kid settings exits 0"
log10="$(cat "$LOG10")"
for key in theme lights_out lights_out_weekend wifi; do
  check_contains "$log10" "omarchy-kids-conf unset kid-cy $key" \
    "an inherited $key value is restored by clearing its temporary override"
done
if [[ "$log10" != *"omarchy-kids-conf set kid-cy theme original-kid"* &&
  "$log10" != *"omarchy-kids-conf set kid-cy lights_out 21:00"* &&
  "$log10" != *"omarchy-kids-conf set kid-cy lights_out_weekend 22:00"* &&
  "$log10" != *"omarchy-kids-conf set kid-cy wifi parent"* ]]; then
  pass "inherited values are never pinned as explicit overrides"
else
  fail_ "an inherited value was pinned as an explicit override"
fi

ROOT11="$TMP/restore-retry"
make_fixture "$ROOT11"
LOG11="$TMP/restore-retry.log"
STATE11="$TMP/restore-retry-state"
mkdir -p "$STATE11"
printf '21:00\n' >"$STATE11/lights_out"
printf '22:00\n' >"$STATE11/lights_out_weekend"
MEDIA_TEST_LOG="$LOG11" MEDIA_TEST_STATE_DIR="$STATE11" \
  MEDIA_TEST_FAIL_VMROOT_ONCE="lights_out 21:00" \
  "$ROOT11/scripts/media-driver.sh" --surface times-up tokyo-night nord >"$TMP/restore-retry.out" 2>&1
status=$?
check "$status" "1" "a transient restoration failure remains visible in the run status"
check "$(cat "$STATE11/lights_out")" "21:00" \
  "a later theme restores the true original weekday value"
check "$(cat "$STATE11/lights_out_weekend")" "22:00" \
  "a later theme keeps the true original weekend value"

ROOT12="$TMP/times-up-not-ready"
make_fixture "$ROOT12"
LOG12="$TMP/times-up-not-ready.log"
MEDIA_TEST_LOG="$LOG12" MEDIA_TEST_TIMES_UP_READY=0 \
  "$ROOT12/scripts/media-driver.sh" --surface times-up tokyo-night >"$TMP/times-up-not-ready.out" 2>&1
status=$?
check "$status" "1" "a Time's Up card that never renders makes the run fail"
log12="$(cat "$LOG12")"
if [[ "$log12" != *"shot times-up-tokyo-night"* ]]; then
  pass "an unready Time's Up card is never photographed"
else
  fail_ "the driver photographed Time's Up without a rendered-card signal"
fi
check_contains "$(cat "$DIR/share/time/timesup.qml")" "function timesUpReady(): bool" \
  "Time's Up exposes its rendered card and countdown readiness"

ROOT13="$TMP/times-up-wrong-frame"
make_fixture "$ROOT13"
LOG13="$TMP/times-up-wrong-frame.log"
MEDIA_TEST_LOG="$LOG13" MEDIA_TEST_TIMES_UP_IMAGE=0 \
  "$ROOT13/scripts/media-driver.sh" --surface times-up tokyo-night >"$TMP/times-up-wrong-frame.out" 2>&1
status=$?
check "$status" "1" "a Time's Up frame without the card makes the run fail"
[[ ! -e "$ROOT13/docs/media/times-up-tokyo-night.png" ]] &&
  pass "an unverified Time's Up frame is never released" ||
  fail_ "the driver released a Time's Up frame whose pixels were not verified"
check_contains "$(cat "$LOG13")" "image-contains-text" \
  "the captured Time's Up PNG is checked for the card and countdown text"

ROOT14="$TMP/ask-not-ready"
make_fixture "$ROOT14"
LOG14="$TMP/ask-not-ready.log"
MEDIA_TEST_LOG="$LOG14" MEDIA_TEST_NEVER_RENDER="Ask a grown-up" \
  "$ROOT14/scripts/media-driver.sh" --surface ask tokyo-night >"$TMP/ask-not-ready.out" 2>&1
status=$?
check "$status" "1" "an Ask card that never renders makes the run fail"
[[ ! -e "$ROOT14/docs/media/ask-tokyo-night.png" ]] &&
  pass "an unready Ask card is never released" || fail_ "the driver released an unready Ask card"

ROOT15="$TMP/ask-wrong-frame"
make_fixture "$ROOT15"
LOG15="$TMP/ask-wrong-frame.log"
MEDIA_TEST_LOG="$LOG15" MEDIA_TEST_BAD_IMAGE="ask-tokyo-night.png" \
  "$ROOT15/scripts/media-driver.sh" --surface ask tokyo-night >"$TMP/ask-wrong-frame.out" 2>&1
status=$?
check "$status" "1" "an Ask release frame without the card makes the run fail"
[[ ! -e "$ROOT15/docs/media/ask-tokyo-night.png" ]] &&
  pass "an unverified Ask frame is never released" || fail_ "the driver released an unverified Ask frame"

# Actual copied driver, owned shot text and literal OCR stub: this proves the
# state acceptance contract, not rendering or the macOS Vision recognizer.
while IFS='|' read -r label expected text final_text; do
  root="$TMP/wifi-state-$label"
  make_fixture "$root"
  MEDIA_TEST_LOG="$root/log" MEDIA_TEST_WIFI_TEXT="$text" \
    MEDIA_TEST_WIFI_FINAL_TEXT="$final_text" \
    "$root/scripts/media-driver.sh" --surface wifi-picker tokyo-night >"$root/out" 2>&1
  check "$?" "$expected" "Wi-Fi capture $label returns $expected"
  check_file_contains "$root/log" "/media-ready-wifi-picker-tokyo-night.png Wi-Fi" \
    "Wi-Fi $label reaches readiness OCR"
  if [[ -n "$final_text" ]]; then
    check_file_contains "$root/log" "/wifi-picker-tokyo-night.png Wi-Fi" \
      "Wi-Fi $label reaches final-frame OCR"
  fi
  if [[ "$expected" == 0 ]]; then
    [[ -s "$root/docs/media/wifi-picker-tokyo-night.png" ]] &&
      pass "Wi-Fi $label publishes settled frame" || fail_ "Wi-Fi $label missing frame"
  else
    [[ ! -e "$root/docs/media/wifi-picker-tokyo-night.png" ]] &&
      pass "Wi-Fi $label refuses release frame" || fail_ "Wi-Fi $label released invalid frame"
  fi
done <<'EOF'
list|0|Wi-Fi Cafe choose Enter join Esc close|
empty|0|Wi-Fi No networks found Try again Enter try again Esc close|
error|0|Wi-Fi Couldn't list networks. Ask a grown-up. Try again Enter try again Esc close|
loading|1|Wi-Fi Looking for networks Esc close|
title|1|Wi-Fi|
password|1|Wi-Fi Cafe Enter join Esc back|
retry-without-result|1|Wi-Fi Try again Enter try again Esc close|
changed-final|1|Wi-Fi No networks found Try again Enter try again Esc close|Wi-Fi Looking for networks Esc close
EOF

# The actual copied driver must dismiss only the two installer popups, after
# target readiness and before each parent release shot. No child capture does it.
check "$(grep -c 'notifications.*dismiss' "$LOG1")" 12 \
  "three parent surfaces dismiss two startup prompts in each theme"
if python3 - "$LOG1" <<'PY'; then pass "startup dismissal uses owner GUI and precedes each parent release"; else
import sys
pending = []
captures = 0
for line in open(sys.argv[1]):
    if 'notifications' in line and 'dismiss' in line:
        pending.append(line)
    if line.startswith(('shot wizard-', 'shot panel-', 'shot bar-module-')):
        assert len(pending) == 2, pending
        assert 'Update' in pending[0] and 'System' in pending[0]
        assert 'Learn' in pending[1] and 'Keybindings' in pending[1]
        assert all('runuser -u kid-test' in command for command in pending)
        pending = []
        captures += 1
assert captures == 6 and not pending
PY
  fail_ "startup dismissal ordering or owner context"
fi
for notice_case in none invalid failed-partial; do
  notice_root="$TMP/notice-$notice_case"
  make_fixture "$notice_root"
  notice_reply=none
  notice_status=0
  expected_status=0
  case "$notice_case" in
    invalid)
      notice_reply='Function not found.'
      expected_status=1
      ;;
    failed-partial)
      notice_reply=ok
      notice_status=255
      expected_status=1
      ;;
  esac
  MEDIA_TEST_LOG="$TMP/notice-$notice_case.log" MEDIA_TEST_NOTICE_REPLY="$notice_reply" \
    MEDIA_TEST_NOTICE_STATUS="$notice_status" "$notice_root/scripts/media-driver.sh" \
    --surface wizard tokyo-night >"$TMP/notice-$notice_case.out" 2>&1
  check "$?" "$expected_status" "notice $notice_case has a truthful run status"
  if ((expected_status)); then
    [[ ! -e "$notice_root/docs/media/wizard-tokyo-night.png" ]] &&
      pass "notice $notice_case refuses the release frame" || fail_ "notice failure released a frame"
    check_file_contains "$TMP/notice-$notice_case.log" 'omarchy-theme-set original-owner' \
      "notice $notice_case still restores the owner theme"
  fi
done

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning "$DIR/scripts/media-driver.sh" "$DIR/test/shell.d/media-driver-test.sh"; then
    pass "shellcheck -S warning is clean on the driver and its test"
  else
    fail_ "shellcheck -S warning found something in the driver or its test"
  fi
else
  echo "SKIP shellcheck: not installed"
fi

exit $fail
