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

# T18: hand the machine to a kid. There is no way to start a kid's live session
# from the parent's (Omarchy 4.0.2 has no such switch), so "enter Kids Mode"
# here means an honest sign-out: the parent's session ends and the login screen
# shows every account for a kid to sign in from. The same mechanism
# bin/omarchy-kids-exit --finish uses (ask the compositor to exit, then
# loginctl as a last resort). No tile is preselected; the label says so.
show_hand_over() {
  # shellcheck disable=SC2034 # read by tui_screen_confirm via nameref-by-name
  local -a facts=(
    "This signs you out of the desktop."
    ""
    "The login screen then shows every account, so a kid can sign in."
    "Nothing is changed, and no password is asked here."
  )
  tui_screen_confirm "Hand over to a kid?" 1 1 0 "" facts "Sign out" "Not now"
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  [dry-run] hyprctl dispatch exit (sign out)\n'
    return 0
  fi
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || hyprctl dispatch exit >/dev/null 2>&1 || true
  fi
  if [[ -n "${XDG_SESSION_ID:-}" ]]; then
    # Last resort, same as bin/omarchy-kids-exit --finish.
    exec loginctl terminate-session "$XDG_SESSION_ID"
  fi
  echo "omarchy-kids-panel: no graphical session to sign out of here." >&2
  return 1
}

screen_home() {
  while true; do
    local rows_out total_open total_reviews
    rows_out="$("$PROVISION_BIN" list 2>/dev/null)"
    total_reviews="$(count_open_reviews)"

    # One ask.py call for every kid's open-request count (T25), not one per kid.
    local req_rows
    req_rows="$(open_requests_by_kid)"
    total_open="$(open_request_total_from "$req_rows")"

    local -a choices=()
    if [[ "$rows_out" == *$'\t'* ]]; then
      local account name band status_out nreq home_line
      while IFS=$'\t' read -r account name band; do
        [[ -z "$account" ]] && continue
        status_out="$("$TIME_BIN" status "$account" 2>/dev/null)"
        nreq="$(open_request_count_from "$req_rows" "$account")"
        home_line="$(kid_home_line "$name" "$band" "$status_out" "$nreq")"
        choices+=("kid:$account|$home_line|")
      done <<<"$rows_out"
      choices+=("remove_kid|Remove a kid|Pick a kid to remove (their files are kept)")
      choices+=("hand_over|Hand over to a kid|Sign out so a kid can log in at the login screen")
    fi
    choices+=(
      "add|Add a kid|"
      "requests|Requests ($total_open)|"
      "notifications|Notifications|Turn notifications on or off, and pair a device"
      "reviews|Reviews ($total_reviews)|An approved app whose surface changed"
      "machine|Machine safety|The read-only safety report"
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
      add)
        # T17: run the wizard and come back to the panel, instead of exec'ing
        # it and ending the app (a parent who adds one kid wants the panel again).
        # --dry-run passes through, the same as Remove Kids Mode below.
        if [[ "$DRY_RUN" == "1" ]]; then "$WIZARD_BIN" --from-panel --dry-run; else "$WIZARD_BIN" --from-panel; fi
        rc=$?
        ((rc == 130)) && return 130
        ;;
      remove_kid)
        # T16: a top-level remove, alongside the per-kid Remove this kid row.
        local -a kid_choices=()
        while IFS=$'\t' read -r account name band; do
          [[ -z "$account" ]] && continue
          kid_choices+=("$account|$name|")
        done <<<"$rows_out"
        tui_screen_choose "Remove which kid?" 1 1 0 "" kid_choices
        rc=$?
        ((rc == 130)) && return 130
        ((rc == 0)) || continue
        local remove_account="$TUI_REPLY" remove_name=""
        while IFS=$'\t' read -r account name band; do
          [[ "$account" == "$remove_account" ]] && remove_name="$name"
        done <<<"$rows_out"
        screen_kid_remove "$remove_account" "${remove_name:-$remove_account}"
        rc=$?
        # Surface the remove screen's own notice (e.g. a mistyped name) on Home
        # rather than leaving it for whichever kid screen opens next.
        if [[ -n "$KID_NOTICE" ]]; then
          # shellcheck disable=SC2034 # read by panel_notice_lines (bin/omarchy-kids-panel)
          PANEL_NOTICE="$KID_NOTICE"
          KID_NOTICE=""
        fi
        ((rc == 130)) && return 130
        ;;
      requests)
        screen_requests
        rc=$?
        ((rc == 130)) && return 130
        ;;
      machine)
        screen_machine
        rc=$?
        ((rc == 130)) && return 130
        ;;
      notifications)
        screen_notify
        rc=$?
        ((rc == 130)) && return 130
        ;;
      reviews)
        screen_reviews
        rc=$?
        ((rc == 130)) && return 130
        ;;
      remove_kids_mode)
        show_remove_kids_mode
        rc=$?
        ((rc == 130)) && return 130
        ;;
      hand_over) show_hand_over || true ;;
      quit) return 1 ;;
      kid:*)
        screen_kid "${TUI_REPLY#kid:}"
        rc=$?
        ((rc == 130)) && return 130
        ;;
    esac
  done
}
