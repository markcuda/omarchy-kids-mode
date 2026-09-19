#!/bin/bash
# Mac-side release screenshot driver (docs/GOAL.md item 3; issue #103).
# One VM driver at a time. Never run this beside test/live/all or another VM scenario.
# Usage: scripts/media-driver.sh [--surface NAME] [THEME ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ "${OMARCHY_KIDS_VM_DRIVER_LOCKED:-0}" != 1 ]]; then
  exec "$SCRIPT_DIR/vm-driver-lock" "$0" "$@"
fi
MEDIA_DIR="$REPO_ROOT/docs/media"
SURFACES=(portal launcher exit-modal ask times-up wifi-picker plugins-shelf wizard panel bar-module)
THEMES=()
SURFACE_FILTER=""
RUN_FAILED=0
THEMES_SAVED=0
THEME_DIRTY=0
ORIGINAL_OWNER_THEME=""
ORIGINAL_KID_THEME=""
ORIGINAL_KID_THEME_SOURCE=""
ORIGINAL_LIGHTS_OUT=""
ORIGINAL_LIGHTS_OUT_SOURCE=""
ORIGINAL_LIGHTS_OUT_WEEKEND=""
ORIGINAL_LIGHTS_OUT_WEEKEND_SOURCE=""
ORIGINAL_WIFI=""
ORIGINAL_WIFI_SOURCE=""
LIGHTS_OUT_DIRTY=0
LIGHTS_OUT_WEEKEND_DIRTY=0
WIFI_DIRTY=0
BAR_SESSION_DIRTY=0
BAR_SESSION_UNIT="omarchy-kids-media-session.service"

usage() {
  cat <<'EOF'
Usage: scripts/media-driver.sh [--surface NAME] [THEME ...]

Capture each supported Kids Mode release surface under each named Omarchy theme.
With no themes, captures tokyo-night and catppuccin-latte. Images land in
docs/media/<surface>-<theme>.png.

  --surface NAME  Capture only one of: portal, launcher, exit-modal, ask,
                  times-up, wifi-picker, plugins-shelf, wizard, panel,
                  bar-module.
  -h, --help      Show this help.

The shared VM lock refuses a second driver and names the active run. This
driver changes the owner and test-kid themes, restarts SDDM, then restores
both themes. The bar widget must already be enabled; this script never changes
the parent's bar. Before parent captures it dismisses the installer's Update
System and Learn Keybindings popups through the shell; notification settings
and history are preserved.
EOF
}

die() {
  echo "media-driver: $1" >&2
  exit "${2:-1}"
}

is_surface() {
  local wanted="$1" surface
  for surface in "${SURFACES[@]}"; do
    [[ "$surface" == "$wanted" ]] && return 0
  done
  return 1
}

while (($#)); do
  case "$1" in
    --surface)
      (($# >= 2)) || die "--surface needs a name (see --help)" 2
      SURFACE_FILTER="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*) die "unknown option '$1' (see --help)" 2 ;;
    *)
      THEMES+=("$1")
      shift
      ;;
  esac
done

[[ -z "$SURFACE_FILTER" ]] || is_surface "$SURFACE_FILTER" ||
  die "unknown surface '$SURFACE_FILTER' (see --help)" 2
((${#THEMES[@]})) || THEMES=(tokyo-night catppuccin-latte)
for theme in "${THEMES[@]}"; do
  [[ "$theme" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
    die "unsafe theme name '$theme'" 2
done

mkdir -p "$MEDIA_DIR"
STAGE_DIR="$(mktemp -d "$MEDIA_DIR/.media-driver.XXXXXX")"
export LIVE_OUT_DIR="$STAGE_DIR"
# shellcheck source=test/live/lib.sh
source "$REPO_ROOT/test/live/lib.sh"
# config.env may name the acceptance-report directory; this driver always stages beside docs/media.
export LIVE_OUT_DIR="$STAGE_DIR"

shell_quote() { printf '%q' "$1"; }

apply_owner_theme() {
  local theme_q
  theme_q="$(shell_quote "$1")"
  vm "export OMARCHY_PATH=/usr/share/omarchy; /usr/bin/omarchy-theme-set $theme_q >/dev/null"
}

apply_kid_theme() {
  local kid_q theme_q
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  theme_q="$(shell_quote "$1")"
  vmroot "env -i PATH=/usr/bin:/bin OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-kids-conf set $kid_q theme $theme_q >/dev/null"
}

unset_kid_setting() {
  local kid_q key_q
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  key_q="$(shell_quote "$1")"
  vmroot "env -i PATH=/usr/bin:/bin OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-kids-conf unset $kid_q $key_q >/dev/null"
}

kid_setting_source() {
  local kid_q key_q source
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  key_q="$(shell_quote "$1")"
  source="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf source $kid_q $key_q")" || return 1
  case "$source" in override | band | default) printf '%s\n' "$source" ;; *) return 1 ;; esac
}

refresh_portal() {
  local failed=0
  vmroot "env -i PATH=/usr/bin:/bin OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-kids-assert >/dev/null" || failed=1
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl restart sddm" || failed=1
  portal_reset 60 || failed=1
  return "$failed"
}

restore_themes() {
  local failed=0
  ((THEMES_SAVED && THEME_DIRTY)) || return 0
  echo "Restoring themes"
  apply_owner_theme "$ORIGINAL_OWNER_THEME" || {
    echo "media-driver: could not restore owner theme '$ORIGINAL_OWNER_THEME'" >&2
    failed=1
  }
  if [[ "$ORIGINAL_KID_THEME_SOURCE" == override ]]; then
    apply_kid_theme "$ORIGINAL_KID_THEME" || {
      echo "media-driver: could not restore $LIVE_KID1_ACCOUNT theme '$ORIGINAL_KID_THEME'" >&2
      failed=1
    }
  else
    unset_kid_setting theme || {
      echo "media-driver: could not restore $LIVE_KID1_ACCOUNT's inherited theme" >&2
      failed=1
    }
  fi
  ((failed)) || THEME_DIRTY=0
  return "$failed"
}

settle_at_greeter() {
  local failed=0
  echo "Closing sessions and confirming the greeter"
  vmroot "env -i PATH=/usr/bin:/bin OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-kids-assert >/dev/null" || {
    echo "media-driver: omarchy-kids-assert failed during cleanup" >&2
    failed=1
  }
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl restart sddm" || {
    echo "media-driver: could not restart SDDM during cleanup" >&2
    failed=1
  }
  portal_reset 60 || {
    echo "media-driver: could not reset the portal during cleanup" >&2
    failed=1
  }
  assert_no_seat_session "$LIVE_KID1_ACCOUNT" 60 || {
    echo "media-driver: could not confirm that $LIVE_KID1_ACCOUNT has no seat session after cleanup" >&2
    failed=1
  }
  assert_no_seat_session "$LIVE_OWNER_ACCOUNT" 60 || {
    echo "media-driver: could not confirm that $LIVE_OWNER_ACCOUNT has no seat session after cleanup" >&2
    failed=1
  }
  assert_greeter 60 || {
    echo "media-driver: cleanup could not confirm the SDDM greeter" >&2
    failed=1
  }
  return "$failed"
}

restore_transient_state() {
  local failed=0 kid_q value_q retick=0 active_status
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  if ((BAR_SESSION_DIRTY)); then
    if vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl is-active --quiet $BAR_SESSION_UNIT"; then
      if ! vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl stop $BAR_SESSION_UNIT"; then
        failed=1
      elif vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl is-active --quiet $BAR_SESSION_UNIT"; then
        echo "media-driver: $BAR_SESSION_UNIT remained active after stop" >&2
        failed=1
      else
        if ! bar_session_collected; then
          echo "media-driver: could not confirm $BAR_SESSION_UNIT was collected" >&2
          failed=1
        fi
      fi
    else
      active_status=$?
      if ! bar_session_collected; then
        echo "media-driver: could not confirm $BAR_SESSION_UNIT was collected (is-active status $active_status)" >&2
        failed=1
      fi
    fi
    if ((!failed)); then
      vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-time-ledger tick >/dev/null" || failed=1
    fi
    ((failed)) || BAR_SESSION_DIRTY=0
  fi
  if ((LIGHTS_OUT_DIRTY)); then
    if [[ "$ORIGINAL_LIGHTS_OUT_SOURCE" == override ]]; then
      value_q="$(shell_quote "$ORIGINAL_LIGHTS_OUT")"
      vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf set $kid_q lights_out $value_q >/dev/null"
    else
      unset_kid_setting lights_out
    fi &&
      LIGHTS_OUT_DIRTY=0 || failed=1
    retick=1
  fi
  if ((LIGHTS_OUT_WEEKEND_DIRTY)); then
    if [[ "$ORIGINAL_LIGHTS_OUT_WEEKEND_SOURCE" == override ]]; then
      value_q="$(shell_quote "$ORIGINAL_LIGHTS_OUT_WEEKEND")"
      vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf set $kid_q lights_out_weekend $value_q >/dev/null"
    else
      unset_kid_setting lights_out_weekend
    fi &&
      LIGHTS_OUT_WEEKEND_DIRTY=0 || failed=1
    retick=1
  fi
  if ((retick)); then
    vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-time-ledger tick >/dev/null" || failed=1
  fi
  if ((WIFI_DIRTY)); then
    if [[ "$ORIGINAL_WIFI_SOURCE" == override ]]; then
      value_q="$(shell_quote "$ORIGINAL_WIFI")"
      vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf set $kid_q wifi $value_q >/dev/null"
    else
      unset_kid_setting wifi
    fi &&
      WIFI_DIRTY=0 || failed=1
  fi
  return "$failed"
}

bar_session_collected() {
  local state
  if ! state="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl show --property=LoadState --property=ActiveState --property=SubState $BAR_SESSION_UNIT")"; then
    return 1
  fi
  [[ "$state" == $'LoadState=not-found\nActiveState=inactive\nSubState=dead' ]]
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if ! restore_transient_state; then status=1; fi
  if ! restore_themes; then status=1; fi
  if ! settle_at_greeter; then status=1; fi
  rm -rf "$STAGE_DIR"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

rendered_surface_contains() {
  local surface="$1" image="$2"
  shift 2
  if [[ "$surface" == wifi-picker ]]; then
    # Settled list, empty scan, or scan failure: each must show its active keys.
    "$SCRIPT_DIR/image-contains-text" "$image" "Wi-Fi" "choose" "Enter join" "Esc close" ||
      "$SCRIPT_DIR/image-contains-text" "$image" "Wi-Fi" "No networks found" "Try again" "Enter try again" "Esc close" ||
      "$SCRIPT_DIR/image-contains-text" "$image" "Wi-Fi" "Couldn't list networks" "Ask a grown-up" "Try again" "Enter try again" "Esc close"
  else
    "$SCRIPT_DIR/image-contains-text" "$image" "$@"
  fi
}

capture() {
  local surface="$1" theme="$2" name
  shift 2
  (($#)) || return 1
  case "$surface" in
    wizard | panel | bar-module) dismiss_capture_notices || return 1 ;;
  esac
  name="$surface-$theme"
  rm -f "$STAGE_DIR/$name.png" || return 1
  shot "$name" || return 1
  [[ -s "$STAGE_DIR/$name.png" ]] || {
    echo "media-driver: shot returned without $name.png" >&2
    return 1
  }
  if ! rendered_surface_contains "$surface" "$STAGE_DIR/$name.png" "$@"; then
    echo "media-driver: $name.png does not show the required surface; refusing to release it" >&2
    rm -f "$STAGE_DIR/$name.png"
    return 1
  fi
  mv -f "$STAGE_DIR/$name.png" "$MEDIA_DIR/$name.png" || return 1
  echo "saved docs/media/$name.png"
}

wait_rendered_surface() {
  local surface="$1" theme="$2" deadline="$3" waited=0 probe
  shift 3
  probe="media-ready-$surface-$theme"
  while ((waited < deadline)); do
    rm -f "$STAGE_DIR/$probe.png"
    if shot "$probe" >/dev/null && [[ -s "$STAGE_DIR/$probe.png" ]] &&
      rendered_surface_contains "$surface" "$STAGE_DIR/$probe.png" "$@"; then
      rm -f "$STAGE_DIR/$probe.png"
      return 0
    fi
    rm -f "$STAGE_DIR/$probe.png"
    sleep 1
    waited=$((waited + 1))
  done
  echo "media-driver: $surface did not render its required text within ${deadline}s" >&2
  return 1
}

wait_and_capture() {
  local surface="$1" theme="$2" deadline="$3"
  shift 3
  wait_rendered_surface "$surface" "$theme" "$deadline" "$@" || return 1
  capture "$surface" "$theme" "$@"
}

wait_vm_process() {
  local account_q pattern_q waited=0 deadline="${3:-30}"
  account_q="$(shell_quote "$1")"
  pattern_q="$(shell_quote "$2")"
  while ((waited < deadline)); do
    vmroot "env -i PATH=/usr/bin:/bin /usr/bin/pgrep -u $account_q -f $pattern_q >/dev/null" 2>/dev/null && return 0
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

gui_session_env() {
  local account="$1" account_q payload payload_q
  account_q="$(shell_quote "$account")"
  payload="acct=$account_q; uid=\$(/usr/bin/id -u \"\$acct\") || exit 1; runtime=/run/user/\$uid; sessions=\$(/usr/bin/loginctl list-sessions --no-legend) || exit 1; session=\$(printf '%s\\n' \"\$sessions\" | awk -v a=\"\$acct\" '\$3 == a && \$4 == \"seat0\" { id=\$1; n++ } END { if (n == 1) print id; else exit 1 }') || exit 1; inventory=\$(runuser -u \"\$acct\" -- env XDG_RUNTIME_DIR=\"\$runtime\" WAYLAND_DISPLAY=wayland-1 LANG=C.UTF-8 /usr/bin/hyprctl instances -j) || exit 1; count=\$(printf '%s' \"\$inventory\" | /usr/bin/jq -r '[.[] | select(.wl_socket == \"wayland-1\" and (.pid | type) == \"number\")] | length') || exit 1; [ \"\$count\" = 1 ] || exit 1; pid=\$(printf '%s' \"\$inventory\" | /usr/bin/jq -r '.[] | select(.wl_socket == \"wayland-1\") | .pid') || exit 1; sig=\$(printf '%s' \"\$inventory\" | /usr/bin/jq -r '.[] | select(.wl_socket == \"wayland-1\") | .instance') || exit 1; wl=\$(printf '%s' \"\$inventory\" | /usr/bin/jq -r '.[] | select(.wl_socket == \"wayland-1\") | .wl_socket') || exit 1; [ -n \"\$sig\" ] && [ \"\$sig\" != null ] || exit 1; [ \"\$(/usr/bin/stat -c %u \"/proc/\$pid\")\" = \"\$uid\" ] || exit 1; [ \"\$(/usr/bin/cat \"/proc/\$pid/comm\")\" = Hyprland ] || exit 1; [ -S \"\$runtime/\$wl\" ] || exit 1; home=\$(/usr/bin/getent passwd \"\$acct\" | cut -d: -f6); [ -n \"\$home\" ] || exit 1; printf 'HOME=%s\\nUSER=%s\\nLOGNAME=%s\\nLANG=%s\\nOMARCHY_PATH=/usr/share/omarchy\\nXDG_RUNTIME_DIR=%s\\nWAYLAND_DISPLAY=%s\\nHYPRLAND_INSTANCE_SIGNATURE=%s\\nXDG_SESSION_ID=%s\\nDBUS_SESSION_BUS_ADDRESS=unix:path=%s/bus\\n' \"\$home\" \"\$acct\" \"\$acct\" C.UTF-8 \"\$runtime\" \"\$wl\" \"\$sig\" \"\$session\" \"\$runtime\""
  payload_q="$(shell_quote "$payload")"
  vmroot "env -i PATH=/usr/bin:/bin /bin/bash -c $payload_q"
}

run_gui_command() {
  local account="$1" command="$2" mode="${3:-sync}" env_lines env_args_q=() line command_q launch
  env_lines="$(gui_session_env "$account")" || return 1
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      env_args_q+=("$(shell_quote "$line")")
    fi
  done <<<"$env_lines"
  command_q="$(shell_quote "$command")"
  if [[ "$mode" == async ]]; then
    # Allocate/open the log after runuser, inside the session shell. A root-side
    # redirect in /tmp could follow a path planted by another account.
    launch="log=\$(mktemp \"\$XDG_RUNTIME_DIR/omarchy-kids-media.XXXXXX\") || exit 1; setsid /bin/bash -c $command_q >\"\$log\" 2>&1 </dev/null &"
    launch="/bin/bash -c $(shell_quote "$launch")"
  else
    launch="/bin/bash -c $command_q"
  fi
  vmroot "env -i PATH=/usr/bin:/bin runuser -u $(shell_quote "$account") -- env ${env_args_q[*]} $launch"
}

wait_gui_session() {
  local account="$1" deadline="${2:-60}" waited=0 env_lines
  while ((waited < deadline)); do
    if env_lines="$(gui_session_env "$account")"; then
      printf '%s\n' "$env_lines"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

assert_no_seat_session() {
  local account="$1" deadline="${2:-60}" waited=0 sessions
  while :; do
    sessions="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/loginctl list-sessions --no-legend")" || return 1
    if awk -v account="$account" '$3 == account && $4 == "seat0" { found=1 } END { exit found }' <<<"$sessions"; then
      return 0
    fi
    ((waited >= deadline)) && return 1
    sleep 5
    waited=$((waited + 5))
  done
}

start_in_session() {
  run_gui_command "$1" "$2" async
}

run_in_session() {
  run_gui_command "$1" "$2"
}

# These installer prompts are persistent, so waiting longer does not remove
# them. Dismiss their popups through the same supported IPC as the desktop;
# never invoke their actions, clear notification history, or change DND.
dismiss_capture_notices() {
  local summary reply
  for summary in 'Update System' 'Learn Keybindings'; do
    reply="$(run_in_session "$LIVE_OWNER_ACCOUNT" \
      "/usr/bin/omarchy-shell notifications dismiss $(shell_quote "$summary")")" || return 1
    case "$reply" in
      ok | none) ;;
      *)
        echo 'media-driver: notification dismissal was not acknowledged' >&2
        return 1
        ;;
    esac
  done
}

wait_times_up_ready() {
  local waited=0 deadline="${1:-45}" ready
  while ((waited < deadline)); do
    ready="$(run_in_session "$LIVE_KID1_ACCOUNT" \
      "/usr/bin/qs -p /usr/share/omarchy-kids/time/timesup.qml ipc call media timesUpReady" 2>/dev/null || true)"
    [[ "$ready" == true ]] && return 0
    sleep 1
    waited=$((waited + 1))
  done
  echo "media-driver: Time's Up card and countdown did not report ready within ${deadline}s" >&2
  return 1
}

prepare_kid() {
  portal_reset 45 || return 1
  portal_login "$LIVE_KID1_ACCOUNT" "$LIVE_KID1_PASSWORD" || return 1
  wait_kid_ready "$LIVE_KID1_ACCOUNT" 60
}

prepare_owner() {
  portal_reset 45 || return 1
  portal_login "$LIVE_OWNER_ACCOUNT" "$LIVE_OWNER_PASSWORD" || return 1
  wait_gui_session "$LIVE_OWNER_ACCOUNT" >/dev/null
}

prepare_owner_for_bar() {
  if wait_gui_session "$LIVE_OWNER_ACCOUNT" >/dev/null; then
    return 0
  fi
  assert_greeter 30 || return 1
  portal_login "$LIVE_OWNER_ACCOUNT" "$LIVE_OWNER_PASSWORD" || return 1
  wait_gui_session "$LIVE_OWNER_ACCOUNT" >/dev/null
}

start_bar_kid_session() {
  local kid_q
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  if vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl is-active --quiet $BAR_SESSION_UNIT"; then
    echo "media-driver: stale $BAR_SESSION_UNIT is still active; inspect the VM before retrying" >&2
    return 1
  fi
  BAR_SESSION_DIRTY=1
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemd-run --quiet --collect --unit=omarchy-kids-media-session --property=PAMName=login --uid=$kid_q /usr/bin/sleep infinity"
}

wait_bar_live_status() {
  local kid_q waited=0 deadline="${1:-30}"
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  while ((waited < deadline)); do
    vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-time-ledger tick >/dev/null" || return 1
    if vmroot "env -i PATH=/usr/bin:/bin /usr/bin/jq -e --arg kid $kid_q '.kids[]? | select(.kid == \$kid and .live == true and .paused == false)' /run/omarchy-kids/status.json >/dev/null"; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  echo "media-driver: concurrent kid session did not produce live bar state within ${deadline}s" >&2
  return 1
}

shoot_portal() {
  local theme="$1" kid_q kid_name
  assert_greeter 30 || return 1
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  kid_name="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf get $kid_q name")" || return 1
  [[ -n "$kid_name" ]] || return 1
  wait_and_capture portal "$theme" 30 "$kid_name"
}

shoot_launcher() {
  local theme="$1"
  prepare_kid || return 1
  wait_and_capture launcher "$theme" 30 "GCompris"
}

shoot_exit_modal() {
  local theme="$1" kid_q kid_name
  prepare_kid || return 1
  for _ in 1 2 3; do
    qmp key meta_l >/dev/null || return 1
    sleep 0.25
  done
  wait_vm_process "$LIVE_KID1_ACCOUNT" exit-modal/shell.qml 15 || return 1
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  kid_name="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf get $kid_q name")" || return 1
  [[ -n "$kid_name" ]] || return 1
  wait_and_capture exit-modal "$theme" 30 "Finish for $kid_name"
}

shoot_ask() {
  local theme="$1"
  prepare_kid || return 1
  start_in_session "$LIVE_KID1_ACCOUNT" "/usr/bin/omarchy-kids-ask time 15" || return 1
  wait_vm_process "$LIVE_KID1_ACCOUNT" ask/shell.qml 15 || return 1
  wait_and_capture ask "$theme" 30 "Ask a grown-up" "15 more minutes"
}

shoot_times_up() {
  local theme="$1" kid_q
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  if ((!LIGHTS_OUT_DIRTY)); then
    ORIGINAL_LIGHTS_OUT_SOURCE="$(kid_setting_source lights_out)" || return 1
    if [[ "$ORIGINAL_LIGHTS_OUT_SOURCE" == override ]]; then
      ORIGINAL_LIGHTS_OUT="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf get $kid_q lights_out")" || return 1
    fi
  fi
  if ((!LIGHTS_OUT_WEEKEND_DIRTY)); then
    ORIGINAL_LIGHTS_OUT_WEEKEND_SOURCE="$(kid_setting_source lights_out_weekend)" || return 1
    if [[ "$ORIGINAL_LIGHTS_OUT_WEEKEND_SOURCE" == override ]]; then
      ORIGINAL_LIGHTS_OUT_WEEKEND="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf get $kid_q lights_out_weekend")" || return 1
    fi
  fi
  prepare_kid || return 1
  LIGHTS_OUT_DIRTY=1
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf set $kid_q lights_out 00:01 >/dev/null" || return 1
  LIGHTS_OUT_WEEKEND_DIRTY=1
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf set $kid_q lights_out_weekend 00:01 >/dev/null" || return 1
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-time-ledger tick >/dev/null" || return 1
  wait_times_up_ready 45 || return 1
  wait_and_capture times-up "$theme" 30 "Time's up" "Closing in"
}

shoot_wifi_picker() {
  local theme="$1" kid_q
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  if ((!WIFI_DIRTY)); then
    ORIGINAL_WIFI_SOURCE="$(kid_setting_source wifi)" || return 1
    if [[ "$ORIGINAL_WIFI_SOURCE" == override ]]; then
      ORIGINAL_WIFI="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf get $kid_q wifi")" || return 1
    fi
  fi
  prepare_kid || return 1
  WIFI_DIRTY=1
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf set $kid_q wifi helper >/dev/null" || return 1
  start_in_session "$LIVE_KID1_ACCOUNT" "/usr/bin/omarchy-kids-wifi picker" || return 1
  wait_vm_process "$LIVE_KID1_ACCOUNT" wifi/shell.qml 15 || return 1
  wait_and_capture wifi-picker "$theme" 30 "Wi-Fi"
}

shoot_plugins_shelf() {
  local theme="$1" kid_q band band_q command
  kid_q="$(shell_quote "$LIVE_KID1_ACCOUNT")"
  band="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf get $kid_q band")" || return 1
  case "$band" in 3-5 | 6-8 | 9-12 | 13+) ;; *) return 1 ;; esac
  band_q="$(shell_quote "$band")"
  command="OMARCHY_KIDS_BAND=$band_q /usr/bin/quickshell -p /usr/share/omarchy-kids/plugins/shell.qml"
  prepare_kid || return 1
  start_in_session "$LIVE_KID1_ACCOUNT" "$command" || return 1
  wait_vm_process "$LIVE_KID1_ACCOUNT" plugins/shell.qml 15 || return 1
  wait_and_capture plugins-shelf "$theme" 30 "More apps" "Pick one"
}

shoot_wizard() {
  local theme="$1"
  prepare_owner || return 1
  start_in_session "$LIVE_OWNER_ACCOUNT" "/usr/bin/omarchy-launch-floating-terminal-with-presentation /usr/bin/omarchy-kids-wizard --dry-run" || return 1
  wait_vm_process "$LIVE_OWNER_ACCOUNT" omarchy-kids-wizard 15 || return 1
  wait_and_capture wizard "$theme" 30 "Welcome" "Begin"
}

shoot_panel() {
  local theme="$1"
  prepare_owner || return 1
  start_in_session "$LIVE_OWNER_ACCOUNT" "/usr/bin/omarchy-launch-floating-terminal-with-presentation /usr/bin/omarchy-kids-panel --dry-run" || return 1
  wait_vm_process "$LIVE_OWNER_ACCOUNT" omarchy-kids-panel 15 || return 1
  wait_and_capture panel "$theme" 30 "Kids Mode" "Add a kid"
}

shoot_bar_module() {
  local theme="$1"
  [[ "$(vm "/usr/bin/omarchy-kids-bar status" 2>/dev/null)" == enabled ]] || {
    echo "media-driver: bar module is not enabled; refusing to change the parent's bar" >&2
    return 1
  }
  vmroot "env -i PATH=/usr/bin:/bin /usr/bin/systemctl is-active --quiet omarchy-kids-time.timer" || {
    echo "media-driver: the live status timer is not active; refusing a frozen bar capture" >&2
    return 1
  }
  prepare_owner_for_bar || return 1
  start_bar_kid_session || return 1
  wait_bar_live_status 30 || return 1
  run_in_session "$LIVE_OWNER_ACCOUNT" "/usr/bin/test -r /run/omarchy-kids/status.json" || {
    echo "media-driver: the owner session cannot read live bar status" >&2
    return 1
  }
  run_in_session "$LIVE_OWNER_ACCOUNT" "/usr/bin/omarchy-shell omarchy-kids.bar toggle" || return 1
  wait_and_capture bar-module "$theme" 30 "live" "Open Kids Mode"
}

run_surface() {
  local surface="$1" theme="$2" function failed=0
  function="shoot_${surface//-/_}"
  echo "Capturing $surface under $theme"
  "$function" "$theme" || failed=1
  restore_transient_state || failed=1
  ((failed)) || return 0
  echo "media-driver: FAILED $surface under $theme" >&2
  return 1
}

boot_with "$LIVE_OWNER_PASSWORD" "$LIVE_OWNER_ACCOUNT" || die "owner boot failed"
ORIGINAL_OWNER_THEME="$(vm "export OMARCHY_PATH=/usr/share/omarchy; /usr/bin/omarchy-theme-current")" ||
  die "could not read the owner's current theme"
ORIGINAL_KID_THEME_SOURCE="$(kid_setting_source theme)" ||
  die "could not read $LIVE_KID1_ACCOUNT's theme source"
if [[ "$ORIGINAL_KID_THEME_SOURCE" == override ]]; then
  ORIGINAL_KID_THEME="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/omarchy-kids-conf get $(shell_quote "$LIVE_KID1_ACCOUNT") theme")" ||
    die "could not read $LIVE_KID1_ACCOUNT's current theme"
fi
[[ -n "$ORIGINAL_OWNER_THEME" ]] || die "the owner's current theme must be known before capture"
THEMES_SAVED=1

for theme in "${THEMES[@]}"; do
  THEME_DIRTY=1
  if ! apply_owner_theme "$theme" || ! apply_kid_theme "$theme" || ! refresh_portal; then
    echo "media-driver: FAILED to prepare theme '$theme'; skipping its surfaces" >&2
    RUN_FAILED=1
    continue
  fi
  for surface in "${SURFACES[@]}"; do
    [[ -z "$SURFACE_FILTER" || "$surface" == "$SURFACE_FILTER" ]] || continue
    run_surface "$surface" "$theme" || RUN_FAILED=1
  done
done

if ! restore_themes; then RUN_FAILED=1; fi
exit "$RUN_FAILED"
