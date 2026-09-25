#!/bin/bash
# Tests bin/omarchy-kids-theme: the kid-side theme picker (T45,
# docs/phase1/SPEC-AMENDMENT-kid-themes.md). It lists the offered set and
# applies a choice through Omarchy's own omarchy-theme-set; it never offers a
# name outside the set.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/bin/omarchy-kids-theme"

rc=0
pass() { echo "ok   $*"; }
fail() {
  echo "FAIL $*"
  rc=1
}
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
check_contains() {
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in '$1')"; fi
}
check_status() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want exit $2, got $1)"; fi
}

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# A scratch system themes dir, plus a stub omarchy-theme-set that logs its argv
# so the test proves the picker calls Omarchy's own command.
OMARCHY_PATH="$TMP/omarchy"
mkdir -p "$OMARCHY_PATH/themes/cozy-night" "$OMARCHY_PATH/themes/tokyo-night"
echo 'background = "#000000"' >"$OMARCHY_PATH/themes/cozy-night/colors.toml"
echo 'background = "#1a1b26"' >"$OMARCHY_PATH/themes/tokyo-night/colors.toml"
export OMARCHY_PATH

STUBS="$TMP/stubs"
mkdir -p "$STUBS"
cat >"$STUBS/omarchy-theme-set" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$THEME_SET_LOG"
EOF
chmod +x "$STUBS/omarchy-theme-set"
# A base toolset + the stub, never the machine's own PATH.
BASE_PATH="$(kids_base_path "$TMP/base")"
export PATH="$STUBS:$BASE_PATH"
export THEME_SET_LOG="$TMP/theme-set.log"
: >"$THEME_SET_LOG"

check_eq "$("$BIN" --list)" "$(printf 'cozy-night\ntokyo-night')" \
  "the picker lists the offered set, sorted"

out="$("$BIN" --set cozy-night --dry-run)"
check_contains "$out" "[dry-run] omarchy-theme-set cozy-night" \
  "--set --dry-run prints the command it would run"
check_eq "$(cat "$THEME_SET_LOG")" "" "a dry run changes nothing"

DRY_RUN=0 "$BIN" --set tokyo-night >/dev/null
check_eq "$(cat "$THEME_SET_LOG")" "tokyo-night" \
  "--set applies through Omarchy's own omarchy-theme-set"

"$BIN" --set not-a-theme >/dev/null 2>&1
check_status "$?" 2 "a name outside the offered set is refused"

check_contains "$("$BIN" --help)" "Pick your own desktop theme" "--help prints the summary line"

echo "theme-kids-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
