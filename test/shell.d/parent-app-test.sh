#!/bin/bash
# Runs the parent app's Dart tests (clients/parent, N-8): the signing, pairing
# and envelope code proven against the box's shared vectors. Skips where no Dart
# SDK is on PATH, like the python-cryptography tests skip without that library.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$DIR/clients/parent"

if ! command -v dart >/dev/null 2>&1; then
  echo "SKIP parent-app-test.sh: no dart on PATH — the app's crypto tests did not run"
  exit 0
fi

cd "$APP" || {
  echo "FAIL parent-app-test.sh: $APP is missing"
  exit 1
}

if ! dart pub get >/dev/null 2>&1; then
  echo "SKIP parent-app-test.sh: dart pub get failed (offline?) — the app's crypto tests did not run"
  exit 0
fi

out="$(dart test 2>&1)"
st=$?
printf '%s\n' "$out" | grep -E '^\s*[0-9]+:[0-9]+ \+[0-9]+' | tail -1
if [[ $st -eq 0 ]]; then
  echo "parent-app-test RESULT: PASS"
else
  printf '%s\n' "$out" | tail -20
  echo "parent-app-test RESULT: FAIL"
fi
exit $st
