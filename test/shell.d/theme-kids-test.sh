#!/bin/bash
# Tests bin/omarchy-kids-theme: the kid-side theme picker (T45,
# docs/phase1/SPEC-AMENDMENT-kid-themes.md). It lists the offered set (Omarchy's
# themes plus the package's kid collection) and applies a choice through
# Omarchy's own omarchy-theme-set; it never offers a name outside the set.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

# A scratch system themes dir and a scratch kid collection, so the test owns
# both roots. A theme in the collection only (paper-harbor) proves that half.
OMARCHY_PATH="$TMP/omarchy"
KID_THEMES="$TMP/kid-themes"
mkdir -p "$OMARCHY_PATH/themes/cozy-night" "$OMARCHY_PATH/themes/tokyo-night" "$KID_THEMES/paper-harbor"
echo 'background = "#000000"' >"$OMARCHY_PATH/themes/cozy-night/colors.toml"
echo 'background = "#1a1b26"' >"$OMARCHY_PATH/themes/tokyo-night/colors.toml"
echo 'background = "#faf0e6"' >"$KID_THEMES/paper-harbor/colors.toml"

# A stub omarchy-theme-set that logs its argv, at the fixed path the command
# reads (THEME_SET_BIN, rule 9): the constants are rewritten in a copied tree.
STUBS="$TMP/stubs"
mkdir -p "$STUBS"
cat >"$STUBS/omarchy-theme-set" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$THEME_SET_LOG"
EOF
chmod +x "$STUBS/omarchy-theme-set"

TREE="$TMP/tree"
kids_tree "$TREE" "$ROOT"
rm -f "$TREE/lib"
cp -a "$ROOT/lib" "$TREE/lib"
kids_set_const "$TREE/bin/omarchy-kids-theme" THEME_SET_BIN "$STUBS/omarchy-theme-set"
kids_set_const "$TREE/lib/theme.sh" KIDS_THEMES_DIR "$KID_THEMES"
BIN="$TREE/bin/omarchy-kids-theme"

BASE_PATH="$(kids_base_path "$TMP/base")"
export PATH="$STUBS:$BASE_PATH"

export OMARCHY_PATH
export THEME_SET_LOG="$TMP/theme-set.log"
: >"$THEME_SET_LOG"

check_eq "$("$BIN" --list)" "$(printf 'cozy-night\npaper-harbor\ntokyo-night')" \
  "the picker lists both roots' offered set, sorted"

out="$("$BIN" --set cozy-night --dry-run)"
check_contains "$out" "[dry-run] omarchy-theme-set cozy-night" \
  "--set --dry-run prints the command it would run"
check_eq "$(cat "$THEME_SET_LOG")" "" "a dry run changes nothing"

# The kid-collection half of the set is real: a collection-only theme applies.
DRY_RUN=0 "$BIN" --set paper-harbor >/dev/null
check_eq "$(cat "$THEME_SET_LOG")" "paper-harbor" \
  "--set applies a kid-collection theme through Omarchy's own omarchy-theme-set"

# A refusal must not reach the apply path, even for real.
: >"$THEME_SET_LOG"
DRY_RUN=0 "$BIN" --set not-a-theme >/dev/null 2>&1
check_status "$?" 2 "a name outside the offered set is refused"
check_eq "$(cat "$THEME_SET_LOG")" "" "a refused name never calls omarchy-theme-set"

check_contains "$("$BIN" --help)" "Pick your own desktop theme" "--help prints the summary line"

echo "theme-kids-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
