#!/bin/bash
# The network boundary (SPEC.md I-2 as amended 2026-09-22; AGENTS.md rule 2): the only things that
# may open a network connection are the package manager, the DoH template inside the kids browser
# policy, `omarchy-kids-relayd` on the LAN, and `omarchy-kids-relay-courier` to the parent's own
# server -- and only when notifications are on.
#
# A static test, like the trust boundary's, because the failure this guards against is a *new*
# surface quietly fetching something: no unit test of an existing command would notice, and the
# first sign would be a child's data leaving the machine. Both sweeps are plain grep so they run on
# a fresh Omarchy box as well as here.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR" || exit 1

fail=0
pass() { echo "ok   $*"; }
fail_() {
  echo "FAIL $*"
  fail=1
}

# 1. The HTTP client lives in the courier and nowhere else. `__pycache__` is filtered because it is
#    gitignored debris that any run of the Python commands leaves behind, and it contains the same
#    strings as its source -- this test has to pass on a box where those caches exist, not only on a
#    fresh clone.
http_files="$(grep -rlE 'urllib\.request|http\.client|urlopen|requests\.(get|post|put)' bin lib 2>/dev/null |
  grep -v '__pycache__' | sort || true)"
if [[ "$http_files" == "lib/courier.py" ]]; then
  pass "the only shipped HTTP client is lib/courier.py (the courier, rule 2)"
else
  fail_ "a shipped file other than lib/courier.py can make an HTTP request:"
  printf '     %s\n' "${http_files:-(none at all -- is the courier still there?)}"
fi

# 2. The shipped UI never fetches: no QML or JavaScript under share/ uses a web API. The kid's
#    surfaces read local files (status.json, the manifest, the control file); a fetch there is the
#    exact thing I-2 forbids, and it would look like any other QML change.
ui_fetch="$(grep -rlE 'XMLHttpRequest|WebSocket|fetch[[:space:]]*\(' share --include='*.qml' --include='*.js' 2>/dev/null || true)"
if [[ -z "$ui_fetch" ]]; then
  pass "no shipped QML or JavaScript fetches anything (I-2: nothing about a child leaves the machine)"
else
  fail_ "a shipped UI file uses a web API:"
  printf '     %s\n' "$ui_fetch"
fi

echo "network-boundary-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit $fail
