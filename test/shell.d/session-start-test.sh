#!/bin/bash
# Tests bin/omarchy-kids-session-start (SPEC.md R-MANIFEST-2, 5, 6): one
# caller-bound manifest input, manifest-derived launch environment, and a
# fail-closed missing-manifest path with no runtime launcher JSON.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if ! command -v python3 >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "SKIP session-start-test.sh: python3 and jq are required"
  exit 0
fi

fail=0
pass() { echo "ok   $*"; }
fail_() {
  echo "FAIL $*"
  fail=1
}
check() {
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail_ "$3 (want '$2', got '$1')"; fi
}
check_not_contains() {
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail_ "$3 (did not want '$2')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ETC="$TMP/etc/omarchy-kids"
SHARE="$TMP/share/omarchy-kids"
ROOT="$TMP/root"
RUN="$TMP/run"
STUBS="$TMP/stubs"
POLICY="$ROOT/etc/chromium/policies/managed/omarchy-kids-6-8.json"
ACCOUNT=kid-ada

mkdir -p "$ETC/kids" "$SHARE/bands" "$SHARE/packs" "$SHARE/avatars" \
  "$(dirname "$POLICY")" "$STUBS"
cp "$DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$DIR"/share/packs/*.toml "$SHARE/packs/"
cp "$DIR"/share/avatars/*.svg "$SHARE/avatars/"
cat >"$ETC/kids/$ACCOUNT.conf" <<'EOF'
name=Display Name
avatar=fox
band=6-8
level=1
web=garden
theme=tokyo-night
EOF
printf '{}\n' >"$POLICY"
chmod 0640 "$POLICY"

BASE_PATH="$(kids_base_path "$TMP/base")"
kids_id_stub "$STUBS" "$ACCOUNT" "$(id -u)"
REAL_STAT="$(type -P stat)"
cat >"$STUBS/stat" <<'EOF'
#!/bin/bash
if [[ "${3:-}" == */sessions/* ]]; then
  case "${2:-}" in
    %Lp | %a) echo 644; exit 0 ;;
    %u) echo 0; exit 0 ;;
    %Sg | %G) echo root; exit 0 ;;
  esac
fi
exec "$SESSION_START_REAL_STAT" "$@"
EOF
chmod +x "$STUBS/stat"
export SESSION_START_REAL_STAT="$REAL_STAT"
export PATH="$STUBS:$BASE_PATH"
export OMARCHY_KIDS_ROOT="$ROOT" OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE"

LIB="$DIR/lib"
KIDS_DIR="$ETC/kids"
CONF_BIN="$DIR/bin/omarchy-kids-conf"
KIDS_PY=python3
# shellcheck source=lib/conf.sh
source "$DIR/lib/conf.sh"
# shellcheck source=lib/kids.sh
source "$DIR/lib/kids.sh"
# shellcheck source=lib/launcher-map.sh
source "$DIR/lib/launcher-map.sh"
# shellcheck source=lib/session-manifest.sh
source "$DIR/lib/session-manifest.sh"
launcher_map_fix "$ACCOUNT" >/dev/null
session_manifest build "$ACCOUNT" >/dev/null
MANIFEST="$ETC/sessions/$ACCOUNT.json"

kids_tree "$TMP/tree" "$DIR"
SESSION_START="$TMP/tree/bin/omarchy-kids-session-start"
SESSION_BIN="$TMP/tree/bin/omarchy-kids-session"
kids_set_const "$SESSION_START" SHARE "$SHARE"
kids_set_const "$SESSION_START" RUN "$RUN"
kids_set_const "$SESSION_START" JQ_BIN "$(command -v jq)"
kids_set_const "$SESSION_BIN" ETC "$ETC"
kids_set_const "$SESSION_BIN" SHARE "$SHARE"
kids_set_const "$SESSION_BIN" SYSROOT "$ROOT"
kids_set_const "$SESSION_BIN" RUNTIME_DIR "$RUN"
kids_set_const "$SESSION_BIN" RUN_DIR "$RUN"

ENV_FILE="$TMP/session-start.env"
ARGS_FILE="$TMP/session-start.args"
ASK_LOG="$TMP/session-start.ask"
: >"$ASK_LOG"
cat >"$TMP/tree/bin/omarchy-kids-time" <<'EOF'
#!/bin/bash
exit 0
EOF
# session-start now also starts `omarchy-kids-ask watch` detached; stub it, or
# every invocation leaks a real, never-exiting watcher (AGENTS.md shape 1).
cat >"$TMP/tree/bin/omarchy-kids-ask" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >>"$SESSION_START_ASK_LOG"
exit 0
EOF
cat >"$STUBS/quickshell" <<'EOF'
#!/bin/bash
env | grep '^OMARCHY_KIDS_' >"$SESSION_START_ENV_FILE"
printf '%s\n' "$@" >"$SESSION_START_ARGS_FILE"
EOF
chmod +x "$TMP/tree/bin/omarchy-kids-time" "$TMP/tree/bin/omarchy-kids-ask" "$STUBS/quickshell"
kids_set_const "$SESSION_START" QUICKSHELL_BIN "$STUBS/quickshell"
export SESSION_START_ENV_FILE="$ENV_FILE" SESSION_START_ARGS_FILE="$ARGS_FILE" SESSION_START_ASK_LOG="$ASK_LOG"

source_text="$(cat "$SESSION_START")"
check_not_contains "$source_text" "CONF_BIN" "session-start does not read profile settings"
check_not_contains "$source_text" "APPS_BIN" "session-start does not resolve an app allowlist"
check_not_contains "$source_text" "launcher_map_find_desktop" "session-start does not invoke the desktop-entry resolver"
check_not_contains "$source_text" "LAUNCHER_JSON" "session-start has no runtime launcher JSON"
check_not_contains "$source_text" "LAUNCHER_MAP" "session-start has no runtime launcher map"
check "$(grep -c 'JQ_BIN' "$SESSION_START")" "2" "session-start parses the manifest once as a whole"

"$SESSION_START" >/dev/null
check "$?" "0" "session-start starts successfully from the manifest"
check "$(grep -c '^watch$' "$ASK_LOG")" "1" "session-start starts omarchy-kids-ask watch (R-NOTIFY-6)"
check "$(cat "$ARGS_FILE")" "-p
$SHARE/launcher/shell.qml" "Level 1 launches the fixed QML argv"
check "$(grep '^OMARCHY_KIDS_ACCOUNT=' "$ENV_FILE")" "OMARCHY_KIDS_ACCOUNT=$ACCOUNT" \
  "account comes from the manifest"
check "$(grep '^OMARCHY_KIDS_LEVEL=' "$ENV_FILE")" "OMARCHY_KIDS_LEVEL=1" \
  "level comes from the manifest"
check "$(grep '^OMARCHY_KIDS_THEME=' "$ENV_FILE")" "OMARCHY_KIDS_THEME=tokyo-night" \
  "theme comes from the manifest"
check "$(grep '^OMARCHY_KIDS_WEB=' "$ENV_FILE")" "OMARCHY_KIDS_WEB=garden" \
  "web mode comes from the manifest"
check "$(grep '^OMARCHY_KIDS_BUDGET_MIN=' "$ENV_FILE")" "OMARCHY_KIDS_BUDGET_MIN=60" \
  "weekday budget comes from the manifest"
check "$(grep '^OMARCHY_KIDS_BUDGET_MIN_WEEKEND=' "$ENV_FILE")" \
  "OMARCHY_KIDS_BUDGET_MIN_WEEKEND=60" "weekend budget comes from the manifest"
[[ ! -e "$RUN/launcher-$(id -u).json" ]] && pass "session-start creates no runtime launcher JSON" ||
  fail_ "session-start creates no runtime launcher JSON"
[[ ! -e "$RUN/allowlist.json" ]] && pass "session-start creates no runtime allowlist JSON" ||
  fail_ "session-start creates no runtime allowlist JSON"

rm -f "$MANIFEST" "$ENV_FILE" "$ARGS_FILE"
out="$("$SESSION_START" 2>&1 >/dev/null)"
status=$?
check "$status" "1" "missing manifest exits 1"
check "$out" "omarchy-kids-session-start: validated manifest unavailable" \
  "missing manifest emits one plain stderr line"
[[ ! -e "$RUN/launcher-$(id -u).json" ]] && pass "missing manifest does not create launcher JSON" ||
  fail_ "missing manifest does not create launcher JSON"

exit "$fail"
