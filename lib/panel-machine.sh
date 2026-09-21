# shellcheck shell=bash
# lib/panel-machine.sh — omarchy-kids-panel's P4 (Machine): the read-only
# safety report from omarchy-kids-check (SPEC.md R-TRUST-2, Appendix A P4;
# docs/check.md). Sourced by the dispatcher; not meant to be executed
# directly.

# screen_machine — P4. Runs `omarchy-kids-check --json` on every draw and
# shows the verdict plus every FAIL and WARN line in full. Read-only: it
# never fixes anything, and a FAIL detail names the assert command or the
# step a grown-up must take (docs/check.md). The panel runs unprivileged,
# so checks that need root report as warnings; the card says so.
screen_machine() {
  while true; do
    local json check_rc=0 verdict fails warns passes skips total generated
    json="$("$CHECK_BIN" --json 2>/dev/null)" || check_rc=$?
    : "$check_rc" # 1=warn, 2=fail: the check's verdict, never a screen failure
    if [[ -z "$json" ]] ||
      ! printf '%s' "$json" | jq -e '(.verdict|type=="string") and (.sections|type=="array")' >/dev/null 2>&1; then
      PANEL_NOTICE="Could not read the safety report from omarchy-kids-check."
      return 0
    fi

    verdict="$(jq -r '.verdict' <<<"$json")"
    total="$(jq -r '[.sections[].checks[]?] | length' <<<"$json")"
    fails="$(jq -r '[.sections[].checks[]? | select(.status=="fail")] | length' <<<"$json")"
    warns="$(jq -r '[.sections[].checks[]? | select(.status=="warn")] | length' <<<"$json")"
    passes="$(jq -r '[.sections[].checks[]? | select(.status=="pass")] | length' <<<"$json")"
    skips="$(jq -r '[.sections[].checks[]? | select(.status=="skip")] | length' <<<"$json")"
    generated="$(jq -r '.generated_at // "just now"' <<<"$json")"

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    if ((total == 0)); then
      facts+=("Safety: the report ran no checks.")
    else
      case "$verdict" in
        pass) facts+=("Safety: every check passed.") ;;
        warn) facts+=("Safety: passing, with $warns warning(s) to review.") ;;
        fail) facts+=("Safety: NOT READY — $fails check(s) failing.") ;;
        *) facts+=("Safety: the report did not name a verdict.") ;;
      esac
    fi
    local id status detail
    while IFS=$'\037' read -r id status detail; do
      [[ -n "$id" ]] || continue
      case "$status" in
        fail) facts+=("" "FAIL  $id — $detail") ;;
        warn) facts+=("WARN  $id — $detail") ;;
      esac
    done < <(jq -r '.sections[].checks[]? | select(.status=="fail" or .status=="warn") | [.id, .status, .detail] | join("\u001f")' <<<"$json")
    facts+=("" "$passes passed, $skips skipped, run $generated.")
    facts+=("Loaded without root; checks needing root report as warnings.")
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
