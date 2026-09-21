# shellcheck shell=bash
# lib/panel-requests.sh — omarchy-kids-panel's P3 (Requests): list, view
# one request's detail, approve/decline through omarchy-kids-ask. Sourced
# by the dispatcher; not meant to be executed directly.

# --- P3: Requests -----------------------------------------------------------

# One line the Requests list shows on its next draw, same reason as
# lib/panel-kid.sh's KID_NOTICE: the card clears anything echoed.
REQ_NOTICE=""

screen_request_detail() { # ID
  local id="$1"
  local path="$QUEUE_DIR/$id.json"
  if [[ ! -f "$path" ]]; then
    REQ_NOTICE="That request isn't there anymore."
    return 0
  fi
  local kid kind what minutes desc
  kid="$(ask_field "$path" kid)"
  kind="$(ask_field "$path" kind)"
  what="$(ask_field "$path" what)"
  minutes="$(ask_field "$path" minutes)"
  if [[ "$kind" == time ]]; then desc="$minutes more minute(s) of screen time"; else desc="$what"; fi
  local kid_name kid_line
  kid_name="$(kid_display_name "$kid")"
  kid_line="$kid_name"
  [[ "$kid_name" != "$kid" ]] && kid_line="$kid_name ($kid)"

  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local -a facts=("Kid: $kid_line" "Kind: $kind" "Asked for: $desc")
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=("approve|Approve|" "decline|Decline|" "back|Back|")
  tui_screen_choose "Request from $kid_name" 1 1 0 "" choices "approve" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  case "$TUI_REPLY" in
    approve) run_priv "$ASK_BIN" approve "$id" --apply ;;
    decline) run_priv "$ASK_BIN" decline "$id" --apply ;;
  esac
  return 0
}

screen_requests() {
  while true; do
    local rows
    rows="$("$KIDS_PY" "$ASK_PY" list-open "$QUEUE_DIR" 2>/dev/null)"
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    if [[ -n "$REQ_NOTICE" ]]; then
      facts+=("$REQ_NOTICE")
      REQ_NOTICE=""
    fi
    panel_notice_lines facts
    if [[ -z "$rows" ]]; then
      facts+=("No open requests right now.")
      # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
      local choices=("back|Back|")
      tui_screen_choose "Requests" 1 1 0 "" choices "back" "" facts
      local rc=$?
      ((rc == 130)) && return 130
      return 0
    fi

    local -a choices=()
    local id kid kind what minutes asked_at desc age kid_name
    while IFS=$'\t' read -r id kid kind what minutes asked_at; do
      [[ -z "$id" ]] && continue
      if [[ "$kind" == time ]]; then desc="$minutes more minute(s)"; else desc="$kind: $what"; fi
      [[ "$asked_at" =~ ^[0-9]+$ ]] || asked_at=0 # never arithmetic on an unchecked field, docs/panel.md
      age="$(human_age "$(($(date +%s) - asked_at))")"
      kid_name="$(kid_display_name "$kid")"
      choices+=("$id|$kid_name — $desc ($age)|")
    done <<<"$rows"
    choices+=("back|Back|")

    tui_screen_choose "Requests" 1 1 0 "" choices "" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    [[ "$TUI_REPLY" == back ]] && return 0

    screen_request_detail "$TUI_REPLY"
    rc=$?
    ((rc == 130)) && return 130
  done
}
