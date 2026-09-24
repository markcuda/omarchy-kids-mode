#!/bin/bash
# Tests lib/session-manifest.sh (SPEC.md R-MANIFEST-1..3, R-MANIFEST-6):
# schema, fixed launcher argv, missing applications, atomic replacement,
# modes, stale data, and failed-build preservation.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP session-manifest-test.sh: python3 not found"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP session-manifest-test.sh: jq not found"
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
check_file() {
  if [[ -e "$1" ]]; then pass "$2"; else fail_ "$2 (missing '$1')"; fi
}
check_contains() {
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail_ "$3 (want '$2')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ETC="$TMP/etc/omarchy-kids"
SHARE="$TMP/share/omarchy-kids"
SCRATCH_ROOT="$TMP/root"
STUBS="$TMP/stubs"
BASE="$TMP/base"
ACCOUNT=kid-ada
PROFILE="$ETC/kids/$ACCOUNT.conf"

mkdir -p "$ETC/kids" "$SHARE/bands" "$SHARE/packs" \
  "$SHARE/avatars" "$SCRATCH_ROOT/usr/share/applications" "$SCRATCH_ROOT/etc/chromium/policies/managed" \
  "$STUBS"
cp "$ROOT_DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$ROOT_DIR"/share/packs/*.toml "$SHARE/packs/"
cp "$ROOT_DIR"/share/avatars/*.svg "$SHARE/avatars/"

cat >"$PROFILE" <<'EOF'
name=Display Name
avatar=fox
band=6-8
level=1
web=garden
theme=tokyo-night
EOF
echo '{}' >"$SCRATCH_ROOT/etc/chromium/policies/managed/omarchy-kids-6-8.json"
chmod 0640 "$SCRATCH_ROOT/etc/chromium/policies/managed/omarchy-kids-6-8.json"

cat >"$STUBS/gcompris" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$STUBS/gcompris"
cat >"$STUBS/tuxpaint" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$STUBS/tuxpaint"
cat >"$SCRATCH_ROOT/usr/share/applications/tuxpaint.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Tux Paint
Exec=tuxpaint --file %F
Icon=tuxpaint-icon
EOF

BASE_PATH="$(kids_base_path "$BASE")"
export PATH="$STUBS:$BASE_PATH"
export OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" OMARCHY_KIDS_ROOT="$SCRATCH_ROOT"

DIR="$ROOT_DIR"
LIB="$ROOT_DIR/lib"
KIDS_DIR="$ETC/kids"
CONF_BIN="$ROOT_DIR/bin/omarchy-kids-conf"
KIDS_PY=python3

# shellcheck source=lib/conf.sh
source "$ROOT_DIR/lib/conf.sh"
# shellcheck source=lib/kids.sh
source "$ROOT_DIR/lib/kids.sh"
# shellcheck source=lib/launcher-map.sh
source "$ROOT_DIR/lib/launcher-map.sh"
# shellcheck source=lib/session-manifest.sh
source "$ROOT_DIR/lib/session-manifest.sh"

MAP="$(launcher_map_path "$ACCOUNT")"
MANIFEST="$(session_manifest_path "$ACCOUNT")"

launcher_map_fix "$ACCOUNT" >/dev/null
check_file "$MAP" "launcher map exists before manifest build"
session_manifest build "$ACCOUNT" >/dev/null
check_file "$MANIFEST" "manifest is installed"
check "$(kids_file_mode "$ETC/sessions")" "750" "sessions directory is mode 0750"
check "$(kids_file_mode "$MANIFEST")" "644" "manifest is mode 0644"
[[ ! -L "$MANIFEST" ]] && pass "manifest is not a symlink" || fail_ "manifest is not a symlink"

check "$(jq -r '.schema_version' "$MANIFEST")" "1" "manifest schema version is 1"
check "$(jq -r '.account' "$MANIFEST")" "$ACCOUNT" "manifest account is the requested kid"
check "$(jq -r '.name' "$MANIFEST")" "Display Name" "manifest carries the display name"
check "$(jq -r '.avatar' "$MANIFEST")" "fox" "manifest carries the avatar"
check "$(jq -r '.band' "$MANIFEST")" "6-8" "manifest carries the band"
check "$(jq -r '.level' "$MANIFEST")" "1" "manifest carries the level"
check "$(jq -r '.theme' "$MANIFEST")" "tokyo-night" "manifest carries the theme"
check "$(jq -r '.web' "$MANIFEST")" "garden" "manifest carries the web mode"
check "$(jq -r '.policy_id' "$MANIFEST")" "omarchy-kids-6-8" "manifest carries the policy id"
check "$(jq -r '.budget_min' "$MANIFEST")" "60" "manifest carries the weekday budget"
check "$(jq -r '.budget_min_weekend' "$MANIFEST")" "60" "manifest carries the weekend budget"
check "$(jq -r '.lights_out' "$MANIFEST")" "19:30" "manifest carries weekday lights-out"
check "$(jq -r '.lights_out_weekend' "$MANIFEST")" "20:00" "manifest carries weekend lights-out"
check "$(jq -r '.allowlist | type' "$MANIFEST")" "array" "manifest allowlist is an array"
check "$(jq -r '.tiles | type' "$MANIFEST")" "array" "manifest tiles are an array"
check "$(jq -r '[.. | objects | has("exec")] | any' "$MANIFEST")" "false" "manifest has no shell command field"
check "$(jq -r '[.tiles[] | has("pkg")] | any' "$MANIFEST")" "false" "manifest tiles omit map-only package metadata"

# The manifest tile projection must be exactly the fixed map tile data.
jq -S '[.tiles[] | {id, label, icon, installed, argv}]' "$MAP" >"$TMP/map-tiles.json"
jq -S '.tiles' "$MANIFEST" >"$TMP/manifest-tiles.json"
cmp -s "$TMP/map-tiles.json" "$TMP/manifest-tiles.json" &&
  pass "manifest tiles preserve launcher-map parity" ||
  fail_ "manifest tiles preserve launcher-map parity"
check "$(jq -r '.tiles[] | select(.id == "tuxpaint") | .argv[0]' "$MANIFEST")" "$STUBS/tuxpaint" \
  "installed tile has a fixed absolute argv"
check "$(jq -r '.tiles[] | select(.id == "tuxpaint") | .argv | length' "$MANIFEST")" "2" \
  "installed tile keeps fixed arguments"
check "$(jq -r '[.tiles[] | select(.id == "ktuberling")] | length' "$MANIFEST")" "0" \
  "missing pack app is omitted by default (apps.show_missing=no)"
conf_set "$PROFILE" apps.show_missing yes
session_manifest build "$ACCOUNT" >/dev/null
check "$(jq -r '.tiles[] | select(.id == "ktuberling") | .installed' "$MANIFEST")" "false" \
  "apps.show_missing=yes keeps the missing tile as unavailable"
check "$(jq -r '.tiles[] | select(.id == "ktuberling") | .argv | length' "$MANIFEST")" "0" \
  "kept missing tile has no executable argv"
conf_set "$PROFILE" apps.show_missing no
session_manifest build "$ACCOUNT" >/dev/null

session_manifest check "$ACCOUNT" >/dev/null
check "$?" "0" "check accepts a current manifest"

before_inode="$(file_stat i "$MANIFEST")"
session_manifest build "$ACCOUNT" >/dev/null
after_inode="$(file_stat i "$MANIFEST")"
[[ "$before_inode" != "$after_inode" ]] && pass "successful rebuild replaces the manifest atomically" ||
  fail_ "successful rebuild replaces the manifest atomically"

chmod 0600 "$MANIFEST"
if session_manifest check "$ACCOUNT" >/dev/null 2>"$TMP/mode.err"; then
  fail_ "check rejects a manifest with the wrong mode"
else
  pass "check rejects a manifest with the wrong mode"
fi
session_manifest build "$ACCOUNT" >/dev/null
check "$(kids_file_mode "$MANIFEST")" "644" "build restores the manifest mode"

stale_inode="$(file_stat i "$MANIFEST")"
conf_set "$PROFILE" web invalid-mode
if error="$(session_manifest build "$ACCOUNT" 2>&1 >/dev/null)"; then
  fail_ "invalid profile makes build fail"
else
  pass "invalid profile makes build fail"
fi
check_contains "$error" "web" "failed build explains the invalid profile field"
check "$(file_stat i "$MANIFEST")" "$stale_inode" "failed build preserves the last manifest inode"
cp "$MANIFEST" "$TMP/last-valid.json"
conf_set "$PROFILE" web garden
session_manifest build "$ACCOUNT" >/dev/null
cmp -s "$MANIFEST" "$TMP/last-valid.json" && pass "failed build preserves the last manifest bytes" ||
  fail_ "failed build preserves the last manifest bytes"

conf_set "$PROFILE" name "New Display"
if error="$(session_manifest check "$ACCOUNT" 2>&1 >/dev/null)"; then
  fail_ "check rejects stale profile data"
else
  pass "check rejects stale profile data"
fi
check_contains "$error" "stale" "stale check explains the reason"
session_manifest build "$ACCOUNT" >/dev/null
check "$(jq -r '.name' "$MANIFEST")" "New Display" "rebuild refreshes stale display data"

conf_set "$PROFILE" apps.extra unknown-launcher
if session_manifest build "$ACCOUNT" >/dev/null 2>"$TMP/unknown.err"; then
  fail_ "unknown launcher id makes build fail"
else
  pass "unknown launcher id makes build fail"
fi
check_contains "$(cat "$TMP/unknown.err")" "unknown launcher" "unknown launcher failure says why"

exit "$fail"

# --- a kid with no theme of their own (follows the parent's): the manifest says "" -------------
NOTHEME="$ETC/kids/kid-plain.conf"
printf 'name=Plain\navatar=owl\nband=6-8\n' >"$NOTHEME"
if session_manifest_build kid-plain 2>"$TMP/plain.err"; then
  check "$(jq -r '.theme' "$(session_manifest_path kid-plain)")" "" "manifest: a kid without a theme builds with theme \"\""
else
  check "built" "failed: $(cat "$TMP/plain.err")" "manifest: a kid without a theme still builds"
fi
rm -f "$NOTHEME"

# --- the executable mode rule looks at group and other, never the owner digit ------------------
launcher_map_mode_writable_by_others 755
check "$?" "1" "mode 755 is not writable by others (root's normal executable)"
launcher_map_mode_writable_by_others 775
check "$?" "0" "mode 775 is group-writable"
launcher_map_mode_writable_by_others 757
check "$?" "0" "mode 757 is world-writable"
launcher_map_mode_writable_by_others 4755
check "$?" "1" "mode 4755 (setuid, owner-only write) is not writable by others"

exit $fail
