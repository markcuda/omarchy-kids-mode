# shellcheck shell=bash
# lib/panel-machine.sh — omarchy-kids-panel's P4 (Machine): the read-only
# safety report from omarchy-kids-check (SPEC.md R-TRUST-2, Appendix A P4;
# docs/check.md). Sourced by the dispatcher; not meant to be executed
# directly.

# _machine_shorten DETAIL — the report's details are written for a
# terminal report; a card body reads better with a bounded line.
_machine_shorten() {
  local text="$1"
  if ((${#text} > 140)); then
    printf '%s…' "${text:0:139}"
  else
    printf '%s' "$text"
  fi
}

# screen_machine — P4. Runs `omarchy-kids-check --json` on every draw and
# shows the verdict plus every FAIL and WARN line. Read-only: it never
# fixes anything, and a FAIL detail already names assert or the step a
# grown-up must take (docs/check.md).
screen_machine() {
  while true; do
    local json rc=0 verdict fails warns passes skips generated
    json="$("$CHECK_BIN" --json 2>/dev/null)" || rc=$?
    if [[ -z "$json" ]] || ! printf '%s' "$json" | jq -e . >/dev/null 2>&1; then
      PANEL_NOTICE="Could not read the safety report from omarchy-kids-check."
      return 0
    fi

    verdict="$(jq -r '.verdict' <<<"$json" 2>/dev/null)"
    fails="$(jq -r '[.sections[].checks[] | select(.status=="fail")] | length' <<<"$json")"
    warns="$(jq -r '[.sections[].checks[] | select(.status=="warn")] | length' <<<"$json")"
    passes="$(jq -r '[.sections[].checks[] | select(.status=="pass")] | length' <<<"$json")"
    skips="$(jq -r '[.sections[].checks[] | select(.status=="skip")] | length' <<<"$json")"
    generated="$(jq -r '.generated_at // "just now"' <<<"$json" 2>/dev/null)"

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    case "$verdict" in
      pass) facts+=("Safety: every check passed.") ;;
      warn) facts+=("Safety: passing, with $warns warning(s) to review.") ;;
      fail) facts+=("Safety: NOT READY — $fails check(s) failing.") ;;
      *) facts+=("Safety: the report did not name a verdict.") ;;
    esac
    local id status detail short
    while IFS=$'\t' read -r id status detail; do
      [[ -n "$id" ]] || continue
      short="$(_machine_shorten "$detail")"
      case "$status" in
        fail) facts+=("" "FAIL  $id — $short") ;;
        warn) facts+=("WARN  $id — $short") ;;
      esac
    done < <(jq -r '.sections[].checks[] | select(.status=="fail" or .status=="warn") | [.id, .status, .detail] | @tsv' <<<"$json" 2>/dev/null)
    facts+=("" "$passes passed, $skips skipped, run $generated.")
    panel_notice_lines facts

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local choices=("refresh|Check again|" "back|Back|")
    tui_screen_choose "Machine safety" 1 1 0 "" choices "refresh" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    [[ "$TUI_REPLY" == back ]] && return 0
  done
}
