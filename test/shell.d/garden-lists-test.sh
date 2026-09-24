#!/bin/bash
# Tests that a band's starter garden is written down the same way in both
# places it lives (SPEC.md R-WEB-3, I-6):
#
#   share/packs/<band>.toml   [garden].sites -- the default a parent sees for
#                             the kid's `sites` key (docs/conf.md)
#   share/policy/lists/<band>.txt        -- what `omarchy-kids-web render`
#                             turns into the managed Chromium policy's
#                             URLAllowlist
#
# They are separate files with no generator between them, and they had already
# drifted: 6-8's pack listed three hosts while the live policy allowed six, so
# a parent reading the kid's `sites` value was shown a smaller garden than the
# one actually in force. This compares them so it cannot happen quietly again.
#
# 3-5 has no browser (`web=none`) and no garden: both are empty. 13+ is
# `filtered`, which SPEC.md R-WEB-3 says adds neither URL list, so its file is
# parked reference data for a future option, says so in its own header, and is
# excluded here.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
rc=0
pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}

pack_garden() { # BAND -> the [garden].sites hosts, one per line
  python3 - "$ROOT/share/packs/$1.toml" <<'PY'
import re, sys
m = re.search(r'\[garden\](.*?)(\n\[|\Z)', open(sys.argv[1]).read(), re.S)
print("\n".join(re.findall(r'"([a-z0-9.-]+)"', m.group(1))) if m else "")
PY
}

list_garden() { # BAND -> the policy list's hosts, comments and blanks stripped
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$ROOT/share/policy/lists/$1.txt" | tr -d ' '
}

for band in 3-5 6-8 9-12; do
  pack="$(pack_garden "$band")"
  list="$(list_garden "$band")"
  if [[ "$pack" == "$list" ]]; then
    pass "$band: the pack garden and the policy list hold the same hosts"
  else
    fail "$band: the pack garden and the policy list disagree"
    diff <(printf '%s\n' "$pack") <(printf '%s\n' "$list") | sed 's/^/        /'
  fi
done

# 3-5 has no browser at all, so its garden must stay empty rather than grow a
# list nothing renders.
if [[ -z "$(pack_garden 3-5)$(list_garden 3-5)" ]]; then
  pass "3-5 has no garden in either file (web=none)"
else
  fail "3-5 is web=none but a garden list exists"
fi

echo "garden-lists-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
