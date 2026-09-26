#!/bin/bash
# Every QML file in the tree parses under qmllint (R-DESK-3, R-LOGIN, R-WIZ-9).
#
# portal-test.sh lints share/sddm-theme/Main.qml, and nothing linted the other
# QML the product ships -- the launcher, the ask/exit/time overlays, the plugins
# and bar modules, the wizard's screens. They are only ever checked by the live
# dogfood runs on the VM, so a stray brace in one of them reaches a kid before
# anyone notices.
#
# qmllint's exit status is the signal, not its output: it prints `Warning:
# ... [syntax]` and exits nonzero for a parse error, but exits 0 for the
# unresolved-import warnings every one of our files has by construction (they
# import Quickshell and qs.* modules, and KidsTheme from a sibling). So no
# output grepping: nonzero means broken. Verified by deliberately breaking a
# file, 2026-09-25.
#
# The Qt6 lint is /usr/lib/qt6/bin/qmllint on Arch, not on PATH. A machine
# without it SKIPs loudly (same shape as portal-test.sh's Main.qml check).
set -uo pipefail
pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
skip() { echo "SKIP  $*"; }
rc=0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

qmllint="$(command -v qmllint 2>/dev/null || true)"
[[ -n "$qmllint" ]] || { [[ -x /usr/lib/qt6/bin/qmllint ]] && qmllint="/usr/lib/qt6/bin/qmllint"; }
if [[ -z "$qmllint" ]]; then
  skip "qml-syntax-test.sh: no qmllint on PATH or at /usr/lib/qt6/bin"
  echo "qml-syntax-test RESULT: PASS"
  exit 0
fi

# while-read, not mapfile: test/all also runs under macOS's bash 3.2.
files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$ROOT" -name '*.qml' -not -path '*/.git/*' | sort)
if ((${#files[@]} == 0)); then
  fail "no .qml files found under $ROOT"
  echo "qml-syntax-test RESULT: FAIL"
  exit 1
fi

checked=0
for f in "${files[@]}"; do
  checked=$((checked + 1))
  if out="$("$qmllint" "$f" 2>&1)"; then
    :
  else
    fail "${f#"$ROOT"/} does not parse: $(head -3 <<<"$out" | tr '\n' ' ')"
  fi
done

((${rc:-0} == 0)) && pass "all $checked .qml file(s) parse under $("$qmllint" --version 2>/dev/null | head -1)"
echo "qml-syntax-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
