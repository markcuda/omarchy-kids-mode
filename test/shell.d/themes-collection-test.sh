#!/bin/bash
# Tests the shipped kid theme collection (share/themes-kids/, T46/T47;
# docs/phase1/SPEC-AMENDMENT-kid-themes.md). Each theme is config only and
# carries its credits; the collection README says no wallpapers ship. This pins
# the shape so the collection cannot drift or quietly gain a file we can't
# redistribute.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLL="$ROOT/share/themes-kids"

rc=0
pass() { echo "ok   $*"; }
fail() {
  echo "FAIL $*"
  rc=1
}
check() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
check_contains() {
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in '$1')"; fi
}

[[ -d "$COLL" ]] || {
  echo "FAIL theme collection missing at $COLL"
  exit 1
}

# The collection README exists and states that no wallpapers ship.
if [[ -f "$COLL/README.md" ]]; then
  pass "the collection has a README"
  check_contains "$(cat "$COLL/README.md")" "No wallpapers ship" \
    "the collection README states that no wallpapers ship"
else
  fail "the collection README is missing"
fi

themes=0
for d in "$COLL"/*/; do
  [[ -d "$d" ]] || continue
  name="$(basename "$d")"
  themes=$((themes + 1))
  if [[ -f "$d/colors.toml" ]]; then pass "$name: has colors.toml"; else fail "$name: missing colors.toml"; fi
  if [[ -f "$d/README.md" ]]; then pass "$name: has a README"; else fail "$name: missing README.md"; fi
  if [[ -f "$d/ATTRIBUTION.md" || -f "$d/CREDITS.md" ]]; then
    pass "$name: carries its credits"
  else
    fail "$name: no ATTRIBUTION.md or CREDITS.md"
  fi
  check_contains "$(head -1 "$d/README.md")" "ships this theme's config only" \
    "$name: its README says the config is all that ships"
  if [[ -d "$d/backgrounds" ]]; then
    fail "$name: ships a backgrounds/ directory (no wallpaper licence was cleared)"
  else
    pass "$name: ships no wallpapers"
  fi
done
check "$themes" "15" "the collection holds the 15 upstream kid themes"

echo "themes-collection-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
