#!/bin/bash
# Regression for issue #167: R-WIZ-3, I-5, I-6.
# Owns the blocking Ready? chooser and checks its current card, not historical
# stdout, after the chooser clears the prior summary.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
mkdir -p "$STUBS"
DISPLAY_BUFFER="$TMP/current-card"
export DISPLAY_BUFFER
cat >"$STUBS/gum" <<'GUM'
#!/bin/bash
case "${1:-}" in
  style)
    shift
    seen=0
    text=()
    for arg in "$@"; do
      ((seen)) && text+=("$arg")
      [[ "$arg" == -- ]] && seen=1
    done
    if ((${#text[@]} == 0)); then
      while IFS= read -r line; do text+=("$line"); done
    fi
    : >>"${DISPLAY_BUFFER:?DISPLAY_BUFFER must be set}"
    for arg in "${text[@]+"${text[@]}"}"; do
      printf '%s\n' "$arg" >>"$DISPLAY_BUFFER"
      printf '%s\n' "$arg"
    done
    ;;
  choose) printf '%s\n' "${GUM_OUTPUT:-apply}" ;;
  *) exit 0 ;;
esac
GUM
cat >"$STUBS/clear" <<'CLEAR'
#!/bin/bash
: >"${DISPLAY_BUFFER:?DISPLAY_BUFFER must be set}"
CLEAR
cat >"$STUBS/tput" <<'TPUT'
#!/bin/bash
[[ ${1:-} == cols ]] && echo 80
TPUT
chmod +x "$STUBS"/*
export PATH="$STUBS:$PATH"

# shellcheck disable=SC2034 # globals are read indirectly by the sourced production screen/renderer
setup_globals() {
  TUI_MODE="$1"
  TUI_HAVE_GUM="$2"
  TUI_C_ACCENT=accent TUI_C_FG=foreground TUI_C_MUTED=muted TUI_C_ERROR=error
  TUI_FOOTER_DEFAULT='Enter continue · Esc back · Ctrl+C leave (nothing changes)'
  TUI_REPLY='' TUI_PRESET_ERROR=''
  DISPLAY_NAME=kid-test ACCOUNT=kid-test AVATAR=fox BAND=3-5 MODE=simple
  WEB_MODE=garden BUDGET_MIN=30 BUDGET_MIN_WEEKEND=45 LIGHTS_OUT=20:00
  LIGHTS_OUT_WEEKEND=20:30 WIFI_MODE=parent LEVEL=1 ALLOWLIST_IDS=browser
  NO_PASSWORD=1 KID_PASSWORD='' TOTAL_STEPS=15
  DNS_MODE='' SITES='' THEME='' HISTORY_VISIBLE=''
}

# Source the real renderer and production screen. Runtime dependencies used by
# screen_summary are owned here rather than replaced wholesale.
# shellcheck disable=SC1091
source "$ROOT/lib/tui.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/wizard-screens.sh"
band_field() {
  case "$2" in
    label) printf '6-8' ;;
    blurb) printf 'A short setup.' ;;
    budget_min) printf '60' ;;
    budget_min_weekend) printf '60' ;;
    lights_out) printf '19:30' ;;
    lights_out_weekend) printf '20:00' ;;
    *) printf 'A short setup.' ;;
  esac
}
friendly_allowlist() { printf 'Browser'; }
mark_if_changed() { printf '%s' "$2"; }
# shellcheck disable=SC1091
source "$ROOT/lib/wizard-advanced.sh"
# Keep unrelated Advanced values equal to their current value, while giving
# weekend keys real band defaults so reintroduced weekend-only appenders are
# observable in the current-card assertion.
adv_default() {
  case "$1" in
    budget_min_weekend) printf '60' ;;
    lights_out_weekend) printf '20:00' ;;
    *) adv_get "$1" ;;
  esac
}
# shellcheck disable=SC2329 # invoked indirectly by screen_summary
screen_advanced_checklist() { return 0; }

setup_globals interactive 1
GUM_OUTPUT=apply
export GUM_OUTPUT
: >"$DISPLAY_BUFFER"
out="$TMP/card.out"
screen_summary >"$out" 2>&1
status=$?
[[ $status == 0 ]] || {
  echo "FAIL card summary returned $status"
  exit 1
}
current_card="$(cat "$DISPLAY_BUFFER")"
grep -q 'Screen time.*30 minutes a day weekdays; 45 minutes a day weekends' <<<"$current_card" || {
  echo 'FAIL current Ready card lost weekday/weekend screen-time summary'
  exit 1
}
grep -q 'Bedtime.*20:00 weekdays; 20:30 weekends' <<<"$current_card" || {
  echo 'FAIL current Ready card lost weekday/weekend bedtime summary'
  exit 1
}
grep -q 'Notifications.*Your phone can get .*requests' <<<"$current_card" || {
  echo 'FAIL current Ready card lost the one-line notifications summary (N-6)'
  exit 1
}
if grep -q '|' <<<"$current_card"; then
  echo 'FAIL current Ready card contains raw row separators'
  exit 1
fi
[[ "$(grep -c '^Account' <<<"$current_card")" == 1 ]] || {
  echo 'FAIL the summary is drawn more than once (or not at all)'
  exit 1
}
[[ "$(grep -Ec 'Screen time \(weekends\)|Bedtime \(weekends\)' <<<"$current_card" || true)" == 0 ]] || {
  echo 'FAIL production Advanced helper duplicated weekend summary rows'
  exit 1
}
printf '%s\n' 'PASS Ready chooser current card retains formatted summary body'

setup_globals file 0
TUI_ANSWERS=(change @esc)
# shellcheck disable=SC2034 # consumed by the renderer globals
TUI_ANSWERS_I=0
# shellcheck disable=SC2329,SC2034 # invoked indirectly by screen_summary
screen_advanced_checklist() {
  BUDGET_MIN=45
  BUDGET_MIN_WEEKEND=50
  LIGHTS_OUT=20:15
  LIGHTS_OUT_WEEKEND=21:00
  return 0
}
# shellcheck disable=SC2329,SC2034 # invoked indirectly by screen_summary
adv_summary_extra_rows() {
  local name="$1"
  eval "$name+=(\"Custom setting|Changed\")"
}
out="$TMP/change.out"
screen_summary >"$out" 2>&1
status=$?
[[ $status == 1 ]] || {
  echo "FAIL Change then Esc returned $status"
  exit 1
}
grep -q 'Screen time.*45 minutes a day' "$out" || {
  echo 'FAIL customized summary was not redrawn'
  exit 1
}
grep -q 'Custom setting.*Changed' "$out" || {
  echo 'FAIL customized extra row was not redrawn'
  exit 1
}
grep -q 'Screen time.*45 minutes a day weekdays; 50 minutes a day weekends (custom)' "$out" || {
  echo 'FAIL customized weekday/weekend screen-time summary was not redrawn'
  exit 1
}
printf '%s\n' 'PASS Change loop redraws customized settings and does not apply'

setup_globals file 0
# shellcheck disable=SC2034 # consumed by the renderer globals
TUI_ANSWERS=(@ctrlc yes)
# shellcheck disable=SC2034 # consumed by the renderer globals
TUI_ANSWERS_I=0
out="$TMP/ctrlc.out"
screen_summary >"$out" 2>&1
status=$?
[[ $status == 130 ]] || {
  echo "FAIL Ctrl+C then Leave returned $status"
  exit 1
}
printf '%s\n' 'PASS Ctrl+C leave exits summary without applying'

setup_globals file 0
TUI_ANSWERS=(default)
TUI_ANSWERS_I=0
BUDGET_MIN_WEEKEND=50
LIGHTS_OUT_WEEKEND=21:00
# Capture the actual choice payload while selecting the default route.  This
# proves the label and the resulting state agree when weekend values already
# came from a customized caller state.
tui_screen_choose() {
  local choices_name="$6"
  eval "printf '%s\\n' \"\${${choices_name}[@]}\""
  TUI_REPLY=default
  return 0
}
screen_time >"$TMP/default-choice.out" 2>&1
[[ "$BUDGET_MIN_WEEKEND" == 50 && "$LIGHTS_OUT_WEEKEND" == 21:00 ]] || {
  echo 'FAIL default Simple time route reset customized weekend values'
  exit 1
}
grep -q 'Weekdays: 60 min; weekends: 50 min|Lights out: 19:30 weekdays; 21:00 weekends' "$TMP/default-choice.out" || {
  echo 'FAIL default Simple time route advertised stale weekend values'
  exit 1
}
printf '%s\n' 'PASS default Simple time route preserves customized weekend values'
