#!/bin/bash
# Regression for issue #172: R-WIZ-3, I-5, I-6.
# The Advanced app row keeps the selectable item compact while the existing
# checklist card body shows the complete value without changing the CSV.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BAND=6-8
ALLOWLIST_IDS='gcompris,tuxpaint,ktuberling,blinken,supertux,supertuxkart,klettres,kanagram'
MARKER="$TMP/marker"

# shellcheck disable=SC2016 # the command-substitution text is intentionally literal
app_label_for() {
  case "$2" in
    gcompris) printf 'GCompris' ;;
    tuxpaint) printf 'Tux Paint' ;;
    ktuberling) printf 'KTuberling' ;;
    blinken) printf 'Blinken' ;;
    supertux) printf 'SuperTux' ;;
    supertuxkart) printf 'SuperTuxKart' ;;
    klettres) printf 'KLettres' ;;
    kanagram) printf 'Kanagram' ;;
    quote) printf 'Kid "Q" \\ \$(touch %s)' "$MARKER" ;;
  esac
}
friendly_web_mode() { printf '%s' "$1"; }
friendly_wifi_mode() { printf '%s' "$1"; }

# shellcheck disable=SC1091
source "$ROOT/lib/wizard-advanced.sh"

# Issue #20/I-6: the App menu row was offered but no level reads the key, so
# it must not be in the checklist. The history row is about the parent's view
# (SPEC.md R-DATA-4), not the kid's.
[[ " ${ADV_KEYS[*]} " != *" menu "* ]] || {
  echo 'FAIL Advanced checklist still offers the unenforced App menu row'
  exit 1
}
[[ "$(adv_label_of history_visible)" == "History you can see" ]] || {
  echo 'FAIL history row still reads as if it controls the kid view'
  exit 1
}
grep -q "Can you see .*'s browsing history?" "$ROOT/lib/wizard-advanced.sh" || {
  echo 'FAIL history prompt does not ask about the parent view'
  exit 1
}
# Avoid the pack reader here; the production row and formatter remain real.
adv_default() {
  if [[ "$1" == allowlist ]]; then
    printf '%s' "$ALLOWLIST_IDS"
  else
    adv_get "$1"
  fi
}

setup_advanced_globals() {
  DISPLAY_NAME=kid-ada
  # shellcheck disable=SC2034 # read indirectly through adv_get
  WEB_MODE=garden DNS_MODE=cloudflare-family SITES='' BUDGET_MIN=60
  # shellcheck disable=SC2034 # read indirectly through adv_get
  BUDGET_MIN_WEEKEND=60 LIGHTS_OUT=19:30 LIGHTS_OUT_WEEKEND=20:00
  # shellcheck disable=SC2034 # read indirectly through adv_get
  ALLOWLIST_IDS="$1" WIFI_MODE=parent LEVEL=1 MENU_MODE=trimmed
  # shellcheck disable=SC2034 # read indirectly through adv_get
  THEME=catppuccin-latte HISTORY_VISIBLE=yes
}

row="$(adv_row_line allowlist)"
[[ "$row" == *'8 apps selected'* ]] || {
  echo 'FAIL app row lost selected count'
  exit 1
}
[[ "$row" != *$'\n'* ]] || {
  echo 'FAIL selectable app row contains display newlines'
  exit 1
}
[[ "${#row}" -lt 80 ]] || {
  echo 'FAIL selectable app row remains too wide'
  exit 1
}

body=()
adv_allowlist_body body "$ALLOWLIST_IDS"
[[ "${#body[@]}" == 9 ]] || {
  echo 'FAIL app detail body did not expose one line per selected app'
  exit 1
}
body_text="$(printf '%s\n' "${body[@]}")"
for label in GCompris 'Tux Paint' KTuberling Blinken SuperTux SuperTuxKart KLettres Kanagram; do
  [[ "$body_text" == *"$label"* ]] || {
    echo "FAIL app detail body lost $label"
    exit 1
  }
done
[[ "$(adv_get allowlist)" == "$ALLOWLIST_IDS" ]] || {
  echo 'FAIL display formatting changed the underlying allowlist'
  exit 1
}
quoted_body=()
adv_allowlist_body quoted_body 'quote'
expected="  $(app_label_for "$BAND" quote)"
[[ "${quoted_body[1]}" == "$expected" ]] || {
  echo 'FAIL quoted app label was not preserved as data'
  exit 1
}
[[ ! -e "$MARKER" ]] || {
  echo 'FAIL app label triggered command substitution'
  exit 1
}

setup_advanced_globals 'quote'
captured_body=()
captured_choices=()
tui_screen_choose() {
  local choices_name="$6" body_name="${9:-}"
  eval "captured_choices=(\"\${${choices_name}[@]}\")"
  eval "captured_body=(\"\${${body_name}[@]}\")"
  TUI_REPLY='done'
  return 0
}
screen_advanced_checklist 13 15
[[ "${captured_choices[*]}" == *'allowlist|'* ]] || {
  echo 'FAIL Advanced checklist did not expose the app row'
  exit 1
}
# shellcheck disable=SC2016 # the command-substitution text is intentionally literal
[[ "${captured_body[*]}" == *'Kid "Q"'* && "${captured_body[*]}" == *'$('* ]] || {
  echo 'FAIL Advanced checklist did not pass complete app detail body'
  exit 1
}
printf '%s\n' 'PASS Advanced app detail is readable and preserves CSV selection'
