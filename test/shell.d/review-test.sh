#!/bin/bash
# Tests bin/omarchy-kids-review — the add-on re-approval (SPEC.md R-NOTIFY-12):
# a first sight stamps an approved app's desktop surface, a change opens a review,
# approve restamps and denies hides. A stub app-tree and a scratch applications
# dir own every fixture; no root, no machine state.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$DIR/test/shell.d/tree.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP review-test.sh: python3 not found"
  exit 0
fi

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0
check() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
check_status() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want exit $2, got $1)"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
ETC="$TMP/etc"
ROOT="$TMP/root"
APPDIR="$TMP/applications"
KIDS="$ETC/kids"
mkdir -p "$STUBS" "$KIDS" "$APPDIR"

kids_tree "$TMP/tree" "$DIR"
BIN="$TMP/tree/bin/omarchy-kids-review"
kids_id_stub "$STUBS" root 0
export PATH="$STUBS:$PATH"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$BIN" SYSROOT "$ROOT"
kids_set_const "$TMP/tree/bin/omarchy-kids-conf" ETC "$ETC"
export KIDS_TEST_UID=0
kids_set_const "$BIN" APPLICATIONS_DIRS "$APPDIR"

printf 'name=Ada\nband=6-8\napps.extra=minecraft\n' >"$KIDS/kid-ada.conf"
desktop() { printf '[Desktop Entry]\nName=Minecraft\nExec=%s %%u\n' "$1" >"$APPDIR/minecraft.desktop"; }
desktop "minecraft first"
BASELINE="$ROOT/var/lib/omarchy-kids/reviews/baseline/kid-ada.json"
REVIEW_HASH="$(python3 -c 'import hashlib; print(hashlib.sha256(b"minecraft").hexdigest()[:16])')"
OPEN_REVIEW="$ROOT/var/lib/omarchy-kids/reviews/open/kid-ada.$REVIEW_HASH.json"

# apps is stubbed: deny must ask it to hide, and nothing else may run.
kids_stub "$TMP/tree" omarchy-kids-apps <<EOF
#!/bin/bash
printf 'apps %s\n' "\$*" >>"$TMP/apps.log"
[[ -f "$TMP/apps-fail" ]] && exit 1
exit 0
EOF
APPS_LOG="$TMP/apps.log"

# --- root only -------------------------------------------------------------
KIDS_TEST_UID=1000 "$BIN" list >/dev/null 2>&1
check_status "$?" 2 "a non-root caller is refused (the stamps and the surface are root-owned)"
export KIDS_TEST_UID=0

# --- first sight stamps, no review ----------------------------------------
out="$("$BIN" scan 2>&1)"
check_contains "$out" "[dry-run] would stamp kid-ada/minecraft" "scan previews the first sighting"
[[ -e "$BASELINE" ]] && fail "scan (dry-run) must not write the stamp" || pass "scan (dry-run) writes nothing"

out="$("$BIN" scan --apply 2>&1)"
check_contains "$out" "nothing needs reviewing" "scan --apply stamps without opening a review"
check "$(jq -r 'has("minecraft")' "$BASELINE" 2>/dev/null)" "true" "the first sighting is stamped"

# --- a changed Exec opens a review ----------------------------------------
desktop "minecraft second"
out="$("$BIN" scan --apply 2>&1)"
check_contains "$out" "review opened for kid-ada/minecraft" "a changed surface opens a review"
[[ -f "$OPEN_REVIEW" ]] && pass "the review record exists" || fail "no review record"
check "$(jq -r '.state' "$OPEN_REVIEW")" "open" "the review is open"
check_contains "$("$BIN" list)" "kid-ada/minecraft" "list shows the open review"
check "$(jq -r '.[0].id' <("$BIN" list --json))" "minecraft" "list --json carries the app id"

# A scan with no further change keeps the review open (not reverted).
"$BIN" scan --apply >/dev/null 2>&1
[[ -f "$OPEN_REVIEW" ]] && pass "an unchanged scan keeps the review open" || fail "the review vanished"

# --- approve restamps and clears ------------------------------------------
out="$("$BIN" approve kid-ada minecraft --apply 2>&1)"
check_contains "$out" "approved the new surface" "approve reports it"
[[ -f "$OPEN_REVIEW" ]] && fail "approve left the review open" || pass "approve clears the review"
check_contains "$("$BIN" list)" "No add-on needs re-review" "list is empty after approve"

# A further scan of the same surface stays closed.
"$BIN" scan --apply >/dev/null 2>&1
[[ -f "$OPEN_REVIEW" ]] && fail "a reverted surface reopened the review" || pass "the restamped surface stays quiet"

# --- deny hides the app and clears ----------------------------------------
desktop "minecraft third"
"$BIN" scan --apply >/dev/null 2>&1
[[ -f "$OPEN_REVIEW" ]] && pass "the changed surface opens a review again" || fail "no review after a change"
: >"$APPS_LOG"
out="$("$BIN" deny kid-ada minecraft --apply 2>&1)"
check_contains "$out" "denied kid-ada/minecraft" "deny reports it"
check_contains "$(cat "$APPS_LOG")" "apps hide kid-ada minecraft --apply" "deny asks apps to hide the app"
[[ -f "$OPEN_REVIEW" ]] && fail "deny left the review open" || pass "deny clears the review"
check "$(jq -r 'has("minecraft")' "$BASELINE" 2>/dev/null)" "false" "deny drops the stamp"

# --- deny fails closed: the review survives a failed hide -----------------
desktop "minecraft redo base"
"$BIN" scan --apply >/dev/null 2>&1 # re-stamp: the previous deny dropped it
desktop "minecraft redo"
"$BIN" scan --apply >/dev/null 2>&1 # a change -> a review
[[ -f "$OPEN_REVIEW" ]] || fail "setup: expected a review before the deny-failure case"
: >"$TMP/apps-fail"
"$BIN" deny kid-ada minecraft --apply >/dev/null 2>&1
check_status "$?" 1 "deny exits non-zero when the hide fails"
[[ -f "$OPEN_REVIEW" ]] && pass "a failed hide leaves the review open to retry" ||
  fail "the review was cleared although the hide failed"
check "$(jq -r 'has("minecraft")' "$BASELINE" 2>/dev/null)" "true" "a failed hide keeps the stamp"
rm -f "$TMP/apps-fail"
"$BIN" deny kid-ada minecraft --apply >/dev/null 2>&1

# --- a removed package reads as missing -----------------------------------
desktop "minecraft fourth"
"$BIN" scan --apply >/dev/null 2>&1 # re-stamp: deny dropped the previous one
rm -f "$APPDIR/minecraft.desktop"
out="$("$BIN" scan --apply 2>&1)"
check_contains "$out" "review opened for kid-ada/minecraft" "a removed desktop opens a review"
check "$(jq -r '.now' "$OPEN_REVIEW")" "missing" "the review says the surface is missing"

# --- neither approve nor deny with a bad call -----------------------------
"$BIN" approve kid-ada >/dev/null 2>&1
check_status "$?" 2 "approve with no id is refused"
"$BIN" bogus >/dev/null 2>&1
check_status "$?" 2 "an unknown command is refused"

echo "review-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
