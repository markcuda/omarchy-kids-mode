# shellcheck shell=bash
# lib/panel-reviews.sh — omarchy-kids-panel's P7 (Add-on reviews): an approved
# app whose surface or exec changed since the parent approved it (SPEC.md
# R-NOTIFY-12; docs/review.md). Approve, Deny or Check. The records are root-owned
# and group-readable, so this screen reads them with no privilege and only the
# actions go through run_priv.

# REV_NOTICE — the last action's result, for the next draw (the card clears).
REV_NOTICE=""

# reviews_rows — "kid<TAB>id<TAB>now<TAB>path", one per open review.
reviews_rows() {
  local f kid id now
  for f in "$REVIEW_DIR"/*.json; do
    [[ -e "$f" ]] || continue
    kid="$(jq -r '.kid // empty' "$f" 2>/dev/null)"
    id="$(jq -r '.id // empty' "$f" 2>/dev/null)"
    [[ -n "$kid" && -n "$id" ]] || continue
    now="$(jq -r '.now // empty' "$f" 2>/dev/null)"
    printf '%s\t%s\t%s\t%s\n' "$kid" "$id" "$now" "$f"
  done
}

# count_open_reviews — the Home row's number.
count_open_reviews() {
  local n=0 f
  for f in "$REVIEW_DIR"/*.json; do
    [[ -e "$f" ]] && n=$((n + 1))
  done
  printf '%s' "$n"
}

# review_desc NOW — one plain phrase for the list.
review_desc() {
  if [[ "$1" == "missing" ]]; then
    printf 'was removed'
  else
    printf 'changed since you approved it'
  fi
}

# screen_review_check KID ID — show what changed (a look, decides nothing).
screen_review_check() {
  local kid="$1" id="$2" out
  if warm_sudo_read; then
    out="$(sudo "$REVIEW_BIN" show "$kid" "$id" 2>&1)"
  else
    out="Could not read the review."
  fi
  local -a facts=()
  while IFS= read -r line; do
    facts+=("$line")
  done <<<"$out"
  local -a choices=("approve|Approve this change|" "deny|Deny (hide the app)|" "back|Back|")
  tui_screen_choose "Check: $id" 1 1 0 "" choices "back" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  case "$TUI_REPLY" in
    approve) run_priv "$REVIEW_BIN" approve "$kid" "$id" --apply ;;
    deny) run_priv "$REVIEW_BIN" deny "$kid" "$id" --apply ;;
  esac
  return 0
}

screen_review_detail() { # KID ID PATH
  local kid="$1" id="$2" path="$3"
  local kid_name was now
  kid_name="$(kid_display_name "$kid")"
  was="$(jq -r '.was // empty' "$path" 2>/dev/null)"
  now="$(jq -r '.now // empty' "$path" 2>/dev/null)"
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local -a facts=("$kid_name — $id" "" "Approved: ${was:0:16}…" "Now:      ${now:0:16}…")
  panel_notice_lines facts
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=("approve|Approve this change|" "deny|Deny (hide the app)|" "check|Check what changed|" "back|Back|")
  tui_screen_choose "Review: $id" 1 1 0 "" choices "approve" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  local crc
  case "$TUI_REPLY" in
    approve) run_priv "$REVIEW_BIN" approve "$kid" "$id" --apply ;;
    deny) run_priv "$REVIEW_BIN" deny "$kid" "$id" --apply ;;
    check)
      # Return Ctrl+C from the Check card up, or the panel would stay.
      screen_review_check "$kid" "$id"
      crc=$?
      ((crc == 130)) && return 130
      ;;
  esac
  return 0
}

screen_reviews() {
  while true; do
    local rows
    rows="$(reviews_rows)"
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    if [[ -n "$REV_NOTICE" ]]; then
      facts+=("$REV_NOTICE")
      REV_NOTICE=""
    fi
    panel_notice_lines facts
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a choices=()
    if [[ -z "$rows" ]]; then
      facts+=("No add-on needs re-review.")
      choices=("back|Back|")
      tui_screen_choose "Add-on reviews" 1 1 0 "" choices "back" "" facts
      local rc=$?
      ((rc == 130)) && return 130
      return 0
    fi
    local kid id now path kid_name
    while IFS=$'\t' read -r kid id now path; do
      [[ -n "$kid" ]] || continue
      kid_name="$(kid_display_name "$kid")"
      choices+=("$kid:$id|$kid_name — $id ($(review_desc "$now"))|")
    done <<<"$rows"
    choices+=("back|Back|")
    tui_screen_choose "Add-on reviews" 1 1 0 "" choices "" "Enter select · Esc back" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    [[ "$TUI_REPLY" == back ]] && return 0
    local sel_kid="${TUI_REPLY%%:*}" sel_id="${TUI_REPLY#*:}"
    local sel_path
    sel_path="$(printf '%s\n' "$rows" | awk -F'\t' -v k="$sel_kid" -v a="$sel_id" '$1==k && $2==a{print $4; exit}')"
    [[ -n "$sel_path" ]] || continue
    screen_review_detail "$sel_kid" "$sel_id" "$sel_path"
    rc=$?
    ((rc == 130)) && return 130
  done
}
