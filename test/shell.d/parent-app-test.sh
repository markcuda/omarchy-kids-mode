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

# Tie the Dart pin fixture to the box: lib/cert.py's own SPKI of the committed
# certificate must equal the constant the Dart pinning test uses, so a change to
# either side fails here. Skips where python-cryptography is absent.
if python3 -c "import cryptography" >/dev/null 2>&1; then
  want="$(python3 -c "import sys; sys.path.insert(0, '$DIR/lib'); import cert; print(cert.spki_fingerprint('$APP/test/fixtures/relay-cert.pem'))" 2>/dev/null)"
  got="$(sed -n "s/^const String fixtureSpki = '\(.*\)';$/\1/p" "$APP/test/pinning_test.dart")"
  if [[ -n "$want" && "$want" == "$got" ]]; then
    echo "ok   the pin fixture matches lib/cert.py's SPKI ($want)"
  else
    echo "FAIL parent-app-test.sh: the pin fixture ($got) does not match lib/cert.py ($want)"
    exit 1
  fi
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
