#!/bin/bash
# Tests bin/omarchy-kids-blocked (SPEC.md R-DESK-2, I-6): the fail-closed
# "Ask a grown-up" screen shown before a kid's desktop starts. An owned gum
# stub captures the exact styling argv, and a failing omarchy-theme-color
# stub pins the resolver to lib/theme.sh's fallback palette so the expected
# accent does not depend on the host's theme.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/tree.sh
source "$DIR/test/shell.d/tree.sh"

fail=0
pass() { echo "ok   $*"; }
fail_() {
  echo "FAIL $*"
  fail=1
}
check() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail_ "$3 (want '$2', got '$1')"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail_ "$3 (want to find '$2' in '$1')"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail_ "$3 (did not want to find '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
GUM_LOG="$TMP/gum.log"
mkdir -p "$STUBS"
: >"$GUM_LOG"

cat >"$STUBS/gum" <<EOF
#!/bin/bash
{ printf '%s' "\$1"; printf ' <%s>' "\${@:2}"; printf '\n'; } >>"$GUM_LOG"
exit 0
EOF
cat >"$STUBS/omarchy-theme-color" <<'EOF'
#!/bin/bash
echo "stub: no theme tool here" >&2
exit 1
EOF
chmod +x "$STUBS/gum" "$STUBS/omarchy-theme-color"

kids_tree "$TMP/tree" "$DIR"
BLOCKED="$TMP/tree/bin/omarchy-kids-blocked"
export PATH="$STUBS:$PATH" GUM_LOG

"$BLOCKED" --help >/dev/null 2>&1
check "$?" 0 "blocked: --help exits 0"

: >"$GUM_LOG"
OMARCHY_KIDS_BLOCKED_SLEEP=0 "$BLOCKED" "private /tmp" >/dev/null 2>&1
check "$?" 1 "blocked: exits 1 so the session cannot start"
log="$(cat "$GUM_LOG")"
check_contains "$log" "can't start safely" "blocked: says the desktop cannot start"
check_contains "$log" "private /tmp" "blocked: names the check that failed"
check_not_contains "$log" "omarchy-kids-check" "blocked: sends the child to a grown-up, not to a CLI command"
check_contains "$log" "<--border> <rounded>" "blocked: uses the shared rounded card border"
check_contains "$log" "<--foreground> <#8fb8ff>" "blocked: takes its colour from the theme resolver's fallback"
check_not_contains "$log" "212" "blocked: no hardcoded 256-colour left"

if grep -q '212' "$DIR/bin/omarchy-kids-blocked"; then
  fail_ "blocked: source still carries the hardcoded colour 212"
else
  pass "blocked: source carries no hardcoded colour literal"
fi

echo "blocked-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit $fail
