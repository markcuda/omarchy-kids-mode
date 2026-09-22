#!/bin/bash
# Tests share/hyprland/L{1,2,3}.lua, share/hyprland/band-*.lua, and
# bin/omarchy-kids-session-start (SPEC.md R-DESK-1, R-DESK-3, R-DESK-5,
# Appendix E). Self-contained: writes only under a scratch $TMP.
#
# What this does NOT and cannot check without a real Hyprland/Quickshell
# (see docs/levels.md's verification-in-the-VM section and the header
# comments in the files themselves):
#   - that the Lua actually parses/runs under Hyprland's embedded Lua
#     (luac -p is used if available, but this dev environment and most
#     CI runners don't have a standalone Lua/luac, so that check is
#     usually SKIPped, not run)
#   - that `fullscreen = true` is really the right shape for a boolean
#     windowrule, that hl.unbind takes a key-combo string, or that
#     SUPER + RETURN is really Omarchy's terminal bind
#   - anything in share/launcher/shell.qml (no Quickshell here at all)
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HYPR="$DIR/share/hyprland"

fail=0
pass() { echo "ok   $*"; }
check() { # got want label
  if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want '$2', got '$1')"
    fail=1
  fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want to find '$2' in '$1')"
    fail=1
  fi
}
# bind_combos FILE -> each o.bind(...)'s first (key-combo) argument, one
# per line, in file order.
bind_combos() {
  grep -oE '^o\.bind\("[^"]+"' "$1" | sed -E 's/^o\.bind\("(.*)"$/\1/'
}

sorted() { printf '%s\n' "$@" | sort; }

# sorted_combos FILE -> bind_combos's output, sorted, newline-joined.
# A plain while-read loop into an array, not `$(bind_combos ...)`
# unquoted (which word-splits "SUPER + Home" into three separate words)
# and not `mapfile` (bash 4+ only; keep this bash-3.2-safe).
sorted_combos() {
  local file="$1" line combos=()
  while IFS= read -r line; do
    combos+=("$line")
  done < <(bind_combos "$file")
  sorted "${combos[@]}"
}

# --- lua syntax, if luac is available (this repo ships no Lua of its
# own, so skipping is the common case, not a failure) --------------------

if command -v luac >/dev/null 2>&1; then
  for f in "$HYPR"/L1.lua "$HYPR"/L2.lua "$HYPR"/L3.lua "$HYPR"/band-3-5.lua "$HYPR"/band-6-8.lua; do
    if luac -p "$f" 2>/tmp/levels-test-luac.$$; then
      echo "ok   luac -p $(basename "$f")"
    else
      echo "FAIL luac -p $(basename "$f"): $(cat /tmp/levels-test-luac.$$)"
      fail=1
    fi
    rm -f /tmp/levels-test-luac.$$
  done
else
  echo "SKIP luac syntax check: luac not found"
fi

# --- L1: exactly the Appendix E set, nothing else -----------------------

L1_WANT=$(sorted \
  'SUPER + Home' \
  'SUPER + RETURN' \
  'SUPER + Q' \
  'SUPER + SHIFT + K' \
  'SUPER + SHIFT + W' \
  'SUPER + SUPER_L' \
  'XF86AudioRaiseVolume' \
  'XF86AudioLowerVolume' \
  'XF86AudioMute' \
  'XF86MonBrightnessUp' \
  'XF86MonBrightnessDown')
L1_GOT=$(sorted_combos "$HYPR/L1.lua")
check "$L1_GOT" "$L1_WANT" "L1.lua binds exactly the Appendix E Level 1 set"

# Band overlays run after the level config and may set presentation gaps.
# Level 1 must restore its zero-gap kiosk geometry after that overlay so a
# launcher that leaves fullscreen cannot expose a band-sized black frame.
l1_band_end="$(grep -n '^end$' "$HYPR/L1.lua" | tail -1 | cut -d: -f1)"
l1_after_band="$(tail -n +$((l1_band_end + 1)) "$HYPR/L1.lua")"
check_contains "$l1_after_band" 'general = { gaps_in = 0, gaps_out = 0, border_size = 0 }' \
  "L1.lua restores zero-gap kiosk geometry after the band overlay"
check_contains "$(cat "$HYPR/L1.lua")" 'cursor = { inactive_timeout = 1 }' \
  "L1.lua hides the idle pointer (cursor:inactive_timeout, verified on the compositor)"
check_contains "$(cat "$HYPR/L2.lua")" 'cursor = { inactive_timeout = 1 }' \
  "L2.lua hides the idle pointer too"
# A stale merge once left L2.lua setting the same rule twice (and this test
# asserting it twice); one call is the whole rule, so pin the count. Count
# code lines only -- a comment quoting the rule must satisfy neither the
# presence check nor the count (same idiom as the L3 scan below).
check "$(grep -vE '^[[:space:]]*--' "$HYPR/L1.lua" | grep -c 'cursor = { inactive_timeout = 1 }')" "1" \
  "L1.lua sets the idle-pointer rule exactly once"
check "$(grep -vE '^[[:space:]]*--' "$HYPR/L2.lua" | grep -c 'cursor = { inactive_timeout = 1 }')" "1" \
  "L2.lua sets the idle-pointer rule exactly once"

# --- L2: the L1 set plus Appendix E's Level 2 additions ------------------

L2_WANT=$(sorted \
  'SUPER + Home' \
  'SUPER + RETURN' \
  'SUPER + Q' \
  'SUPER + SHIFT + K' \
  'SUPER + SHIFT + W' \
  'SUPER + SUPER_L' \
  'XF86AudioRaiseVolume' \
  'XF86AudioLowerVolume' \
  'XF86AudioMute' \
  'XF86MonBrightnessUp' \
  'XF86MonBrightnessDown' \
  'SUPER + LEFT' \
  'SUPER + RIGHT' \
  'SUPER + UP' \
  'SUPER + DOWN' \
  'SUPER + SHIFT + LEFT' \
  'SUPER + SHIFT + RIGHT' \
  'SUPER + SHIFT + UP' \
  'SUPER + SHIFT + DOWN' \
  'SUPER + K' \
  'SUPER + SPACE')
L2_GOT=$(sorted_combos "$HYPR/L2.lua")
check "$L2_GOT" "$L2_WANT" "L2.lua binds the Level 1 set plus Appendix E's Level 2 additions"

# --- L1/L2 never pull in Omarchy's own binding modules -------------------
#
# Matched against actual require(...) calls, not comment prose: both
# files' header comments explain, in English, why default.hypr.bindings.*
# is *not* required, which would otherwise false-positive a plain
# substring search.

for lvl in L1 L2; do
  requires="$(grep -E '^\s*require\("default\.hypr\.bindings' "$HYPR/$lvl.lua" || true)"
  check "$requires" "" "$lvl.lua never requires default.hypr.bindings.*"
done

# --- L3 requires the real Omarchy defaults and unbinds the terminal -----

l3_content="$(cat "$HYPR/L3.lua")"
check_contains "$l3_content" 'require("default.hypr.looknfeel")' \
  "L3.lua requires the stock modules it wants directly, not the umbrella"
check_contains "$l3_content" 'require("default.hypr.bindings.tiling")' \
  "L3.lua keeps the stock bindings"
check "$(grep -vE '^[[:space:]]*--' "$HYPR/L3.lua" | grep -cE 'default\.hypr\.(omarchy|autostart)|omarchy-provision-first-run' || true)" "0" \
  "L3.lua never pulls in Omarchy's autostart or first-run provisioning (live finding)"
check_contains "$l3_content" 'hl.unbind("SUPER + RETURN")' "L3.lua unbinds the terminal bind"
check_contains "$l3_content" 'o.bind("SUPER + SHIFT + K"' "L3.lua adds the Appendix E exit-modal bind"
check_contains "$l3_content" 'o.bind("SUPER + SHIFT + W", "Kids Mode: Wi-Fi", "omarchy-kids-wifi picker")' \
  "L3.lua adds the Wi-Fi picker bind"
check_contains "$l3_content" 'o.bind("SUPER + SUPER_L", "Kids Mode: exit (tap Super three times)", "omarchy-kids-super-tap", { release = true })' \
  "L3.lua adds the triple-tap release bind"

# --- session-start consumes the expected session manifest ----------------

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP session-start manifest checks: jq not found"
elif ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP session-start manifest checks: python3 not found"
else
  TMP="$(mktemp -d)"
  # shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
  cleanup() { rm -rf "$TMP"; }
  trap cleanup EXIT

  SHARE="$TMP/share"
  ETC="$TMP/etc"
  RUN="$TMP/run"
  STUBS="$TMP/stubs"
  mkdir -p "$SHARE/bands" "$SHARE/packs" "$SHARE/avatars" "$ETC/kids" "$TMP/apps" "$STUBS" \
    "$TMP/root/usr/share/applications"
  cp "$DIR/share/bands/bands.toml" "$SHARE/bands/"
  cp "$DIR"/share/packs/*.toml "$SHARE/packs/"
  cp "$DIR"/share/avatars/*.svg "$SHARE/avatars/"

  cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada
avatar=fox
band=6-8
theme=tokyo-night
EOF

  # The manifests below provide distinct level/band cases without env-selected paths.
  cat >"$ETC/kids/kid-two.conf" <<'EOF'
name=Two
avatar=fox
band=6-8
level=2
theme=tokyo-night
EOF

  cat >"$ETC/kids/kid-tot.conf" <<'EOF'
name=Tot
avatar=fox
band=3-5
level=1
theme=tokyo-night
EOF

  cat >"$TMP/apps/tuxpaint.desktop" <<'EOF'
[Desktop Entry]
Name=Tux Paint
Icon=tuxpaint
Exec=tuxpaint %F
EOF
  cp "$TMP/apps/tuxpaint.desktop" "$TMP/root/usr/share/applications/"

  # issue #42: session-start now marks a tile installed:true|false (a
  # matched .desktop file, above, or the resolved exec's first word on
  # PATH -- never pacman) and, by default, omits a missing app's tile
  # entirely rather than shipping one Enter silently does nothing on
  # (I-6). gcompris has no .desktop fixture, so a PATH stub is what
  # makes *it* count as installed here; the other six 6-8 pack apps are
  # deliberately left with neither, the live VM state issue #42
  # describes -- their omission (and its log line) is covered in detail
  # by test/shell.d/session-start-test.sh, not re-tested here.
  cat >"$STUBS/gcompris" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$STUBS/gcompris"
  cp "$STUBS/gcompris" "$STUBS/tuxpaint"

  # `id -un`, not $OMARCHY_KIDS_ACCOUNT: which kid a command thinks it is
  # is no longer settable from the environment (review §3.7).
  source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
  kids_id_stub "$STUBS" kid-ada "$(id -u)"
  kids_tree "$TMP/tree" "$DIR"
  SESSION_START="$TMP/tree/bin/omarchy-kids-session-start"
  kids_set_const "$SESSION_START" SHARE "$SHARE"
  kids_set_const "$SESSION_START" RUN "$RUN"

  # Stubs plus a base toolset only: a real Omarchy box has half this pack
  # actually installed, and `command -v <app>` would call those tiles
  # installed (AGENTS.md, testing rules).
  BASE_PATH="$(kids_base_path "$TMP/base")"

  export PATH="$STUBS:$BASE_PATH"
  export OMARCHY_KIDS_ETC="$ETC"
  export OMARCHY_KIDS_SHARE="$SHARE"
  export OMARCHY_KIDS_ROOT="$TMP/root"
  LIB="$DIR/lib"
  KIDS_DIR="$ETC/kids"
  CONF_BIN="$DIR/bin/omarchy-kids-conf"
  KIDS_PY=python3
  source "$DIR/lib/conf.sh"
  source "$DIR/lib/kids.sh"
  source "$DIR/lib/launcher-map.sh"
  # shellcheck source=lib/session-manifest.sh
  source "$DIR/lib/session-manifest.sh"
  launcher_map_fix kid-ada
  launcher_map_fix kid-two
  launcher_map_fix kid-tot
  session_manifest build kid-ada >/dev/null
  session_manifest build kid-two >/dev/null
  session_manifest build kid-tot >/dev/null

  SESSION_ROOT="$TMP/installed"
  mkdir -p "$SESSION_ROOT/bin"
  cp -R "$DIR/lib" "$SESSION_ROOT/"
  cp "$DIR/bin/omarchy-kids-session-start" "$SESSION_ROOT/bin/"
  cat >"$SESSION_ROOT/bin/omarchy-kids-session" <<EOF
#!/bin/bash
set -euo pipefail
account="\$(id -un)"
cat "$ETC/sessions/\$account.json"
EOF
  chmod +x "$SESSION_ROOT/bin/omarchy-kids-session"
  cp "$DIR/bin/omarchy-kids-conf" "$SESSION_ROOT/bin/"
  cp "$DIR/bin/omarchy-kids-apps" "$SESSION_ROOT/bin/"
  cp "$DIR/bin/omarchy-kids-time" "$SESSION_ROOT/bin/"
  SESSION_COPY="$SESSION_ROOT/bin/omarchy-kids-session-start"
  kids_set_const "$SESSION_COPY" SHARE "$SHARE"
  kids_set_const "$SESSION_COPY" SYSROOT "$TMP/root"
  kids_set_const "$SESSION_COPY" RUN "$RUN"

  out="$(
    PATH="$STUBS:$BASE_PATH" \
      OMARCHY_KIDS_SESSION_START_NO_EXEC=1 \
      bash "$SESSION_COPY"
  )"
  check "$out" "/usr/bin/quickshell -p $SHARE/launcher/shell.qml" "session-start prints the Level 1 exec line"

  manifest_path="$ETC/sessions/kid-ada.json"
  check "$(jq -r '.account' "$manifest_path")" "kid-ada" "manifest account"
  check "$(jq -r '.band' "$manifest_path")" "6-8" "manifest band"
  check "$(jq -r '.level' "$manifest_path")" "2" "manifest level (band 6-8's desktop default)"
  check "$(jq -r '.tiles[0].id' "$manifest_path")" "gcompris" "manifest keeps pack order"
  check "$(jq -r '.tiles | map(select(.id == "more-apps")) | length' "$manifest_path")" "1" \
    "issue #28: band 6-8 manifest gets a 'More apps' tile"
  check "$(jq -r '.tiles[] | select(.id == "tuxpaint") | .argv[0]' "$manifest_path")" "$STUBS/tuxpaint" \
    "manifest carries tuxpaint's absolute executable"
  [[ ! -e "$RUN/launcher-$(id -u).json" ]] && pass "session-start creates no runtime launcher JSON" ||
    fail_ "session-start creates no runtime launcher JSON"
  [[ ! -e "$RUN/allowlist.json" ]] && pass "session-start creates no runtime allowlist JSON" ||
    fail_ "session-start creates no runtime allowlist JSON"

  # Level 2 starts the same owned manifest-backed shell as Level 1.
  out2="$(
    PATH="$STUBS:$BASE_PATH" \
      KIDS_TEST_ACCOUNT=kid-two \
      OMARCHY_KIDS_SESSION_START_NO_EXEC=1 \
      bash "$SESSION_COPY"
  )"
  check "$out2" "/usr/bin/quickshell -p $SHARE/launcher/shell.qml" "session-start uses the owned Level 2 desktop/picker"

  # issue #28: band 3-5 gets no "More apps" tile at all -- not a shelf
  # that would always show empty (I-6).
  out3="$(
    PATH="$STUBS:$BASE_PATH" \
      KIDS_TEST_ACCOUNT=kid-tot \
      OMARCHY_KIDS_SESSION_START_NO_EXEC=1 \
      bash "$SESSION_COPY"
  )"
  check "$out3" "/usr/bin/quickshell -p $SHARE/launcher/shell.qml" "session-start (band 3-5) still prints the Level 1 exec line"
  check "$(jq -r '.tiles | map(select(.id == "more-apps")) | length' "$ETC/sessions/kid-tot.json")" "0" \
    "issue #28: band 3-5's manifest has no 'more-apps' tile"
fi

exit $fail
