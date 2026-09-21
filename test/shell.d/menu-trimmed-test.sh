#!/bin/bash
# SPEC.md R-DESK-4 (Q23): share/menu/omarchy-kids-trimmed.jsonc is the
# omarchy-menu *user extension* shape, not the "hide list" this file used to
# guess at. Verified 2026-09-21 against Omarchy's menu plugin on the VM:
# Menu.qml reads $HOME/.config/omarchy/extensions/omarchy-menu.jsonc and
# MenuModel.mergeMenuSources() merges it with the stock entries field-by-field
# by id, so a hide is the same id with `when: "false"`. This test is the static
# shape check; the live effect (hidden rows, stock desktop) runs in the VM.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/share/menu/omarchy-kids-trimmed.jsonc"
rc=0
fail() { echo "FAIL menu-trimmed: $*"; rc=1; }
pass() { echo "ok   menu-trimmed: $*"; }

if [[ ! -f "$FILE" ]]; then
  fail "missing $FILE"
  echo "menu-trimmed-test RESULT: FAIL"
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  out="$(FILE="$FILE" node <<'NODE'
const fs = require('fs');
const raw = fs.readFileSync(process.env.FILE, 'utf8');
const stripped = raw.replace(/^\s*\/\/.*$/gm, '');
let obj;
try {
  obj = JSON.parse(stripped);
} catch (e) {
  console.error('parse: ' + e.message);
  process.exit(2);
}
const want = ['install', 'remove', 'update', 'setup'];
const missing = want.filter((id) => !obj[id] || obj[id].when !== 'false');
console.log(JSON.stringify({
  hide: Object.prototype.hasOwnProperty.call(obj, 'hide'),
  missing: missing
}));
NODE
)" || {
    fail "the file does not parse as JSONC"
    echo "menu-trimmed-test RESULT: FAIL"
    exit 1
  }

  if grep -q '"hide":true' <<<"$out"; then
    fail "the retired hide-list key is back; the real shape is when:false per id"
  elif grep -q '"missing":\[\]' <<<"$out"; then
    pass "id keys hidden with when:false (install/remove/update/setup)"
  else
    fail "ids are not hidden as expected: $out"
  fi
else
  echo "SKIP menu-trimmed-test: node not found"
fi

echo "menu-trimmed-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
