# shellcheck shell=bash
# lib/panel-home.sh — omarchy-kids-panel's P1 (Home): the kid list,
# add/requests/remove-kids-mode row, and the dispatch to P2/P3.
# Sourced by the dispatcher; not meant to be executed directly.

# --- P1: Home ----------------------------------------------------------------

show_remove_kids_mode() {
  # What it does belongs on the card, not echoed above a screen that clears
  # (review §3.1). Then it hands off to bin/omarchy-kids-remove
  # (docs/remove.md), which prints its own plan and asks its own
  # confirmation; the panel's dry-run default is passed through.
  # shellcheck disable=SC2034 # read by tui_screen_confirm via nameref-by-name
  local -a facts=(
    "This reverses every lock and removes every kid account. Their files are kept"
    "under your home in \"Kids Mode/<Name>\", and you're offered a snapshot first."
    ""
    "It prints the whole plan and asks again before touching anything."
  )
  tui_screen_confirm "Remove Kids Mode?" 1 1 0 "" facts "Continue" "Not now"
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0

  if [[ "$DRY_RUN" == 1 ]]; then
    sudo "$REMOVE_BIN" --dry-run
  else
    sudo "$REMOVE_BIN"
  fi
}

screen_home() {
  while true; do
    local rows_out total_open
    rows_out="$("$PROVISION_BIN" list 2>/dev/null)"
    total_open="$(count_open_requests)"

    local -a choices=()
    if [[ "$rows_out" == *$'\t'* ]]; then
      local account name band status_out nreq home_line
      while IFS=$'\t' read -r account name band; do
        [[ -z "$account" ]] && continue
        status_out="$("$TIME_BIN" status "$account" 2>/dev/null)"
        nreq="$(count_open_requests "$account")"
        home_line="$(kid_home_line "$name" "$band" "$status_out" "$nreq")"
        choices+=("kid:$account|$home_line|")
      done <<<"$rows_out"
    fi
    choices+=(
      "add|Add a kid|"
      "requests|Requests ($total_open)|"
      "remove_kids_mode|Remove Kids Mode|"
      "quit|Quit|"
    )

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    panel_notice_lines facts

    tui_screen_choose "Kids Mode" 1 1 0 "" choices "" "Enter select · Esc quit" facts
    local rc=$?
    case "$rc" in
      1) return 1 ;;
      130) return 130 ;;
    esac
    ((rc == 0)) || return 1

    case "$TUI_REPLY" in
      add) exec "$WIZARD_BIN" ;;
      requests)
        screen_requests
        rc=$?
        ((rc == 130)) && return 130
        ;;
      remove_kids_mode)
        show_remove_kids_mode
        rc=$?
        ((rc == 130)) && return 130
        ;;
      quit) return 1 ;;
      kid:*)
        screen_kid "${TUI_REPLY#kid:}"
        rc=$?
        ((rc == 130)) && return 130
        ;;
    esac
  done
}
