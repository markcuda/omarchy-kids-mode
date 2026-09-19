#!/bin/bash
# Tests that the four hand-kept fallback palettes agree: lib/theme.sh (the
# one the shell commands use), share/qml/KidsTheme.qml, share/sddm-theme/
# Main.qml's literal fallbacks, and share/sddm-theme/theme.conf. They are
# copies by design (each medium loads its own), and the 2026-09-18 UI/UX
# review found this is exactly where drift hides (docs/theming.md). Bash
# 3.2-safe: no associative arrays (the macOS test host).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/theme.sh
source "$DIR/lib/theme.sh"

fail=0
pass() { echo "ok   $*"; }
fail_() {
  echo "FAIL $*"
  fail=1
}
check() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail_ "$3 (want '$2', got '$1')"; fi
}

KIDS_THEME="$DIR/share/qml/KidsTheme.qml"
MAIN_QML="$DIR/share/sddm-theme/Main.qml"
THEME_CONF="$DIR/share/sddm-theme/theme.conf"

# value_of FILE PATTERN — the first capture of the pattern (one group).
value_of() { # FILE PATTERN
  grep -oE "$2" "$1" | head -1 | sed -E 's/.*"(#[0-9a-fA-F]{6})".*/\1/'
}

# want NAME — the shell resolver's own fallback for a semantic key.
want() {
  case "$1" in
    background | foreground | accent | muted | error | warning | surface | surface_muted | highlight)
      _theme_kids_fallback "$1"
      ;;
    *)
      echo "theme-palette-test: unknown key '$1'" >&2
      return 1
      ;;
  esac
}

# --- KidsTheme.qml: keys share the resolver's names ------------------------

for key in background foreground accent muted error warning; do
  got="$(value_of "$KIDS_THEME" "$key: \"(#[0-9a-fA-F]{6})\"")"
  check "$got" "$(want "$key")" "KidsTheme.qml: $key matches lib/theme.sh"
done

if grep -q "fontFamily: \"$THEME_KIDS_FALLBACK_FONT\"" "$KIDS_THEME"; then
  pass "KidsTheme.qml: font family matches lib/theme.sh"
else
  fail_ "KidsTheme.qml: fontFamily does not match THEME_KIDS_FALLBACK_FONT"
fi

# --- share/sddm-theme/Main.qml: SDDM's own key names -----------------------

# check_qml QML_KEY WANT_KEY
check_qml() {
  local got
  got="$(value_of "$MAIN_QML" "$1 \|\| \"(#[0-9a-fA-F]{6})\"")"
  check "$got" "$(want "$2")" "Main.qml: $1 matches lib/theme.sh $2"
}
check_qml backgroundColor background
check_qml textColor foreground
check_qml accentColor accent
check_qml mutedTextColor muted
check_qml errorColor error
check_qml tileColor surface
check_qml tileHighlightColor highlight
check_qml parentTileColor surface_muted

# --- share/sddm-theme/theme.conf: the same names ---------------------------

# check_conf CONF_KEY WANT_KEY
check_conf() {
  local got
  got="$(grep -oE "^$1=#[0-9a-fA-F]{6}" "$THEME_CONF" | head -1 | cut -d= -f2)"
  check "$got" "$(want "$2")" "theme.conf: $1 matches lib/theme.sh $2"
}
check_conf backgroundColor background
check_conf textColor foreground
check_conf accentColor accent
check_conf mutedTextColor muted
check_conf errorColor error
check_conf tileColor surface
check_conf tileHighlightColor highlight
check_conf parentTileColor surface_muted

conf_font="$(grep -oE '^fontFamily=.*' "$THEME_CONF" | head -1 | cut -d= -f2)"
check "$conf_font" "$THEME_KIDS_FALLBACK_FONT" "theme.conf: font family matches lib/theme.sh"

echo "theme-palette-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit $fail
