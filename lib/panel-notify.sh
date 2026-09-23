# shellcheck shell=bash
# lib/panel-notify.sh — omarchy-kids-panel's P6 (Notifications): the parent's
# switch for device notifications and the paired-device list (SPEC.md
# R-NOTIFY-1/3/5; docs/notify.md). Sourced by the dispatcher; not meant to be
# executed directly.
#
# The panel runs unprivileged, so every call here goes through the panel's own
# sudo wrappers: the warmed prompt is the parent's authentication (R-NOTIFY-5),
# which is why pair adds no password prompt of its own.

# NOTIFY_NOTICE — the pairing code and fingerprint (or the last failure) for
# the next draw. The card clears anything echoed above it, so a pairing window
# started now would otherwise scroll away before the parent could read it.
NOTIFY_NOTICE=""

notify_status_out() { read_priv "$NOTIFY_BIN" status 2>/dev/null; }

notify_devices_rows() { # ID NAME PLATFORM SCOPES, one per line
  read_priv "$NOTIFY_BIN" devices --json 2>/dev/null |
    jq -r '.[]? | [.id, .name, .platform, (.scopes | tostring)] | @tsv' 2>/dev/null
}

# notify_pair_show — start a single-use pairing window and leave its code and
# the relay's SPKI fingerprint on the next card (R-NOTIFY-5). The parent reads
# the code into the app, or scans the QR when the command is run in a terminal.
notify_pair_show() {
  warm_sudo || return 1
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  [dry-run] sudo %q pair --apply\n' "$NOTIFY_BIN"
    NOTIFY_NOTICE="Preview only — nothing was changed."
    return 0
  fi
  local out rc=0 uri fp
  out="$(sudo "$NOTIFY_BIN" pair --apply 2>&1)" || rc=$?
  if ((rc != 0)); then
    NOTIFY_NOTICE="Couldn't start pairing${out:+: ${out##*$'\n'}}"
    return "$rc"
  fi
  uri="$(printf '%s\n' "$out" | awk '/omarchy-kids:\/\/pair/{print $NF}')"
  fp="$(printf '%s\n' "$out" | awk '/fingerprint:/{print $2}')"
  NOTIFY_NOTICE="Pairing window open. In your phone app, open this code: $uri"
  [[ -n "$fp" ]] && NOTIFY_NOTICE+="  ·  fingerprint: $fp"
  return 0
}

screen_notify_devices() {
  while true; do
    local rows
    rows="$(notify_devices_rows)"
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    panel_notice_lines facts
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a choices=()
    if [[ -z "$rows" ]]; then
      facts+=("No devices are paired yet.")
    else
      local id name platform scopes
      while IFS=$'\t' read -r id name platform scopes; do
        [[ -n "$id" ]] || continue
        choices+=("$id|$name · $platform|Scopes: $scopes")
      done <<<"$rows"
    fi
    choices+=("back|Back|")
    tui_screen_choose "Paired devices" 1 1 0 "" choices "" "Enter select · Esc back" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    [[ "$TUI_REPLY" == back ]] && return 0

    local device_id="$TUI_REPLY"
    # shellcheck disable=SC2034 # read by tui_screen_confirm via nameref-by-name
    local -a cfacts=(
      "This device can no longer approve or decline anything. You can pair it"
      "again later."
    )
    tui_screen_confirm "Revoke this device?" 1 1 0 "" cfacts "Revoke" "Keep"
    rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || continue
    run_priv "$NOTIFY_BIN" revoke "$device_id" --apply
  done
}

screen_notify() {
  while true; do
    local status_out on=0
    status_out="$(notify_status_out)"
    [[ "$status_out" == *"notifications: on"* ]] && on=1

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    if ((on)); then
      facts+=("Notifications are on. A paired device can approve or decline, over your home network only.")
    else
      facts+=("Notifications are off. Nothing leaves this machine.")
    fi
    if [[ -n "$NOTIFY_NOTICE" ]]; then
      facts+=("" "$NOTIFY_NOTICE")
      NOTIFY_NOTICE=""
    fi
    panel_notice_lines facts

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a choices=()
    if ((on)); then
      choices+=("pair|Pair a device|Shows a code and fingerprint to check on your phone")
      choices+=("disable|Turn off notifications|Revokes every paired device")
    else
      choices+=("enable|Turn on notifications|Mints the relay's certificate")
    fi
    choices+=("devices|Paired devices|" "back|Back|")

    tui_screen_choose "Notifications" 1 1 0 "" choices "" "Enter select · Esc back" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    case "$TUI_REPLY" in
      enable) run_priv "$NOTIFY_BIN" enable --apply ;;
      disable)
        # shellcheck disable=SC2034 # read by tui_screen_confirm via nameref-by-name
        local -a cfacts=(
          "Every paired device loses access and the relay's certificate is"
          "removed. Nothing is left listening on the network."
        )
        tui_screen_confirm "Turn off notifications?" 1 1 0 "" cfacts "Turn off" "Keep"
        rc=$?
        ((rc == 130)) && return 130
        ((rc == 0)) || continue
        run_priv "$NOTIFY_BIN" disable --apply
        ;;
      pair) notify_pair_show ;;
      devices) screen_notify_devices ;;
      back) return 0 ;;
    esac
  done
}
