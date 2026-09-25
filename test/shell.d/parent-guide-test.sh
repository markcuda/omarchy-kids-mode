#!/bin/bash
# Tests docs/parent-guide.md: the plain-language guide must cover every profile
# schema key (share/config/schema.toml) and every band (share/bands/bands.toml),
# so it cannot quietly fall behind the code (R-CONFIG-1, Appendix B; the
# owner's "explainers for every setting and every band" note).
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUIDE="$DIR/docs/parent-guide.md"
SCHEMA="$DIR/share/config/schema.toml"
BANDS="$DIR/share/bands/bands.toml"

rc=0
pass() { echo "ok   $*"; }
fail() {
  echo "FAIL $*"
  rc=1
}

check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want '$2')"; fi
}

[[ -f "$GUIDE" ]] || {
  echo "FAIL parent guide is missing at $GUIDE"
  exit 1
}

guide="$(cat "$GUIDE")"

# Every schema key must be named in the guide (as `key`).
missing_keys=()
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  [[ "$guide" == *"\`$key\`"* ]] || missing_keys+=("$key")
done < <(grep -oE '^key = "[^"]+"' "$SCHEMA" | sed -E 's/^key = "(.*)"$/\1/')
if ((${#missing_keys[@]} == 0)); then
  pass "parent guide names every schema key"
else
  fail "parent guide is missing schema key(s): ${missing_keys[*]}"
fi

# Every band must appear.
while IFS= read -r band; do
  [[ -z "$band" ]] && continue
  check_contains "$guide" "$band" "parent guide names band $band"
done < <(grep -oE '^\[band\."[^"]+"\]' "$BANDS" | sed -E 's/^\[band\."(.*)"\]$/\1/')

# Every band's desktop default (the key line of the band table here) must be
# one of the guide's own mode names, so the table can't drift from R-DESK-3.
for pair in "3-5:App grid" "6-8:App grid" "9-12:Desktop" "13+:Desktop"; do
  band="${pair%%:*}"
  mode="${pair##*:}"
  check_contains "$guide" "$mode" "parent guide gives band $band the $mode default"
done

echo "parent-guide-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
