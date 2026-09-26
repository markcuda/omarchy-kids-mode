#!/bin/bash
# Runs the parent app's Flutter widget tests (clients/parent/app, N-8): the UI
# over a fake relay -- the request list, Approve/Decline, and a reply chip. Skips
# where no Flutter SDK is on PATH, like the Dart and python-cryptography tests.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$DIR/clients/parent/app"

if ! command -v flutter >/dev/null 2>&1; then
  echo "SKIP parent-ui-test.sh: no flutter on PATH — the app's widget tests did not run"
  exit 0
fi

cd "$APP" || {
  echo "FAIL parent-ui-test.sh: $APP is missing"
  exit 1
}

if ! flutter pub get >/dev/null 2>&1; then
  echo "SKIP parent-ui-test.sh: flutter pub get failed (offline?) — the widget tests did not run"
  exit 0
fi

# The analyzer, not just the widget tests: same reason as parent-app-test.sh.
if out="$(flutter analyze 2>&1)"; then
  echo "ok   flutter analyze: the parent app is clean"
else
  echo "FAIL parent-ui-test.sh: flutter analyze found issues:"
  printf '%s\n' "$out" | tail -15
  exit 1
fi

out="$(flutter test 2>&1)"
st=$?
printf '%s\n' "$out" | grep -E 'All tests passed|Some tests failed' | tail -1
if [[ $st -eq 0 ]]; then
  echo "parent-ui-test RESULT: PASS"
else
  printf '%s\n' "$out" | tail -30
  echo "parent-ui-test RESULT: FAIL"
fi
exit $st
