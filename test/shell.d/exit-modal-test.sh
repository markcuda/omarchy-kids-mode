#!/bin/bash
# Tests the exit modal's one-action contract (SPEC.md R-EXIT-1..3, I-5, I-6).
# This static check covers the QML seam that cannot run without Quickshell.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODAL="$ROOT/share/exit-modal/shell.qml"
fail=0

pass() { echo "ok   $*"; }
fail_check() {
  echo "FAIL $*"
  fail=1
}

check_absent() {
  local needle="$1" description="$2"
  if grep -qF "$needle" "$MODAL"; then
    fail_check "$description"
  else
    pass "$description"
  fi
}

check_count() {
  local needle="$1" want="$2" description="$3" got
  got="$(grep -cF "$needle" "$MODAL" || true)"
  if [[ "$got" == "$want" ]]; then
    pass "$description"
  else
    fail_check "$description (want $want, got $got)"
  fi
}

check_count 'id: finishButton' 1 "modal has exactly one Finish action"
check_count 'MouseArea {' 1 "modal has exactly one action target"
check_count '"Your password"' 1 "the empty field says whose password is wanted (live review)"
check_absent 'id: pauseButton' "modal has no Pause action"
check_absent 'Pause' "modal has no Pause copy"
check_absent 'pauseAvailable' "modal has no Pause availability state"
check_absent 'Coming soon' "modal has no unavailable-action copy"
check_absent 'toggleSelection' "modal has no selection toggle"
check_absent 'Keys.onTabPressed' "modal has no Tab handler"
check_absent 'Keys.onBacktabPressed' "modal has no Shift+Tab handler"
check_absent 'property int selectedAction' "modal has no multi-action selection state"
check_absent 'pendingAction' "modal has no deferred action selection"

if grep -qF 'KidsTheme { id: theme }' "$MODAL"; then
  pass "modal reads its colors through KidsTheme"
else
  fail_check "modal must read its colors through KidsTheme"
fi

if grep -qF 'Keys.onEscapePressed' "$MODAL" &&
  grep -qF 'Keys.onReturnPressed' "$MODAL" &&
  grep -qF 'Keys.onEnterPressed' "$MODAL"; then
  pass "modal keeps Escape and Enter keyboard flow"
else
  fail_check "modal must keep Escape and both Enter handlers"
fi

if grep -qF 'Quickshell.execDetached(["/usr/bin/omarchy-kids-exit", "--finish"])' "$MODAL"; then
  pass "modal submits the implemented Finish action"
else
  fail_check "modal must submit the implemented Finish action"
fi

echo "exit-modal-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit "$fail"
