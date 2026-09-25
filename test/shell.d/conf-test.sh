#!/bin/bash
# Tests bin/omarchy-kids-conf, lib/conf.sh, and lib/conf.py (SPEC.md
# R-BAND-1, R-BAND-2, R-BUILD-5, R-CONFIG-1/2/6, R-BOOTMODE-1, R-BOOTMODE-12,
# Appendix B, Appendix C).
# Self-contained: runs entirely against scratch OMARCHY_KIDS_ETC and
# OMARCHY_KIDS_SHARE trees, so it never touches the real /etc or
# /usr/share. share/ is copied from the repo rather than faked, so this
# also exercises the real bands.toml and packs/ this issue ships.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF="$DIR/bin/omarchy-kids-conf"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP conf-test.sh: python3 not found"
  exit 0
fi

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ETC="$TMP/etc"
SHARE="$TMP/share"
mkdir -p "$SHARE/bands" "$SHARE/config" "$SHARE/packs"
cp "$DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$DIR/share/config/schema.toml" "$SHARE/config/"
cp "$DIR"/share/packs/*.toml "$SHARE/packs/"
mkdir -p "$SHARE/avatars"
cp "$DIR/share/avatars/fox.svg" "$SHARE/avatars/"

# issue #53: a scratch system themes dir ($OMARCHY_PATH/themes) for
# `theme`'s validation and `theme_apply_for`'s own file copy, plus a
# scratch home root so that copy never touches this box's real /home.
OMARCHY_PATH="$TMP/omarchy"
mkdir -p "$OMARCHY_PATH/themes/tokyo-night" "$OMARCHY_PATH/themes/catppuccin-latte"
echo 'background = "#1a1b26"' >"$OMARCHY_PATH/themes/tokyo-night/colors.toml"
echo 'background = "#eff1f5"' >"$OMARCHY_PATH/themes/catppuccin-latte/colors.toml"
OMARCHY_KIDS_HOME_ROOT="$TMP/homeroot"
mkdir -p "$OMARCHY_KIDS_HOME_ROOT/home/kid-ada"

# A base toolset only: a real Omarchy box already has a kid-ada account,
# and `getent passwd kid-ada` would send theme_apply_for at the real
# /home/kid-ada instead of the scratch root (AGENTS.md, testing rules).
BASE_PATH="$(kids_base_path "$TMP/base")"
export PATH="$BASE_PATH"

export OMARCHY_KIDS_ETC="$ETC"
export OMARCHY_KIDS_SHARE="$SHARE"
export OMARCHY_PATH
export OMARCHY_KIDS_HOME_ROOT

fail=0
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
check_status() { # got_status want_status label
  if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want exit $2, got $1)"
    fail=1
  fi
}

# --- schema parity --------------------------------------------------------

expected_keys=(
  name avatar band level web dns budget_min budget_min_weekend
  lights_out lights_out_weekend wifi history_visible menu theme allowlist sites
  password onboarded apps.extra apps.hidden apps.show_missing
)
schema_keys="$(
  python3 - "$SHARE/config/schema.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as schema_file:
    schema = tomllib.load(schema_file)
for entry in schema.get("key", []):
    print(entry["key"])
PY
)"
expected_key_text="$(printf '%s\n' "${expected_keys[@]}")"
check "$schema_keys" "$expected_key_text" "schema: declares every profile and extension key once in CLI order"

schema_metadata="$(
  python3 - "$SHARE/config/schema.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as schema_file:
    schema = tomllib.load(schema_file)
for entry in schema["key"]:
    required = "yes" if entry["required"] else "no"
    print("\t".join((
        entry["key"], entry["type"], required, entry["default_source"],
        entry["group"], entry["label"], entry["editor"], entry["validator"],
    )))
PY
)"
check_contains "$schema_metadata" $'name\tstring\tyes\tnone\tIdentity\tName\ttext\tnonempty-single-line' \
  "schema: name declares its type, required state, source, label, group, editor, and validator"
check_contains "$schema_metadata" $'level\tenum\tno\tband\tDesktop\tDesktop\tenum\tlevel' \
  "schema: level declares band precedence and its editor metadata"
check_contains "$schema_metadata" $'dns\tstring\tno\tband\tWeb\tSafe-search DNS\tdns\tdns' \
  "schema: dns retains band precedence"
check_contains "$schema_metadata" $'history_visible\tenum\tno\tband\tData\tBrowsing history\ttoggle\tyes-no' \
  "schema: history visibility retains band precedence"
check_contains "$schema_metadata" $'theme\tstring\tyes\tparent-theme\tDesktop\tTheme\ttheme\ttheme-id' \
  "schema: theme names the required parent-theme source"
check_contains "$schema_metadata" $'allowlist\tcsv\tno\tpack\tApps\tStarter apps\tlauncher-list\tlauncher-ids' \
  "schema: allowlist declares pack precedence and its editor metadata"

for key in "${expected_keys[@]}"; do
  count="$(printf '%s\n' "$schema_keys" | grep -cxF "$key")"
  check "$count" "1" "schema: $key occurs exactly once"
done

schema_rejections=(
  "schema-version-bool|schema_version = 1"
  "unknown-top-level|unknown top-level fields"
  "enum-non-list|invalid enum"
  "min-non-integer|non-integer min"
  "max-non-integer|non-integer max"
  "pattern-non-string|invalid pattern"
  "bounds-on-string|bounds for a non-integer type"
  "duplicate-enum|duplicate enum value"
)
for rejection in "${schema_rejections[@]}"; do
  kind="${rejection%%|*}"
  expected="${rejection#*|}"
  rejected="$TMP/$kind.toml"
  cp "$DIR/share/config/schema.toml" "$rejected"
  python3 - "$rejected" "$kind" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
kind = sys.argv[2]
text = path.read_text()
if kind == "schema-version-bool":
    text = text.replace("schema_version = 1", "schema_version = true", 1)
elif kind == "unknown-top-level":
    text = 'unexpected = "nope"\n' + text
elif kind == "enum-non-list":
    text = text.replace('enum = ["3-5", "6-8", "9-12", "13+"]', 'enum = "3-5"', 1)
elif kind == "min-non-integer":
    text = text.replace("min = 1", 'min = "one"', 1)
elif kind == "max-non-integer":
    text = text.replace("max = 1440", 'max = "many"', 1)
elif kind == "pattern-non-string":
    text = text.replace('pattern = "^([01][0-9]|2[0-3]):[0-5][0-9]$"', "pattern = 24", 1)
elif kind == "bounds-on-string":
    text = text.replace('type = "string"\n', 'type = "string"\nmin = 1\nmax = 2\n', 1)
elif kind == "duplicate-enum":
    text = text.replace('enum = ["3-5", "6-8", "9-12", "13+"]', 'enum = ["3-5", "3-5"]', 1)
path.write_text(text)
PY
  err="$(python3 "$DIR/lib/conf.py" schema-dump "$rejected" 2>&1 >/dev/null)"
  check_status "$?" 2 "schema-dump rejects $kind"
  check_contains "$err" "$expected" "schema-dump explains $kind"
done

out="$(SCHEMA="$TMP/not-the-package-schema.toml" "$CONF" bands)"
check_contains "$out" "3-5" "schema path ignores a runtime environment override"

# --- bands / band ---------------------------------------------------------

out="$("$CONF" bands)"
check_contains "$out" "3-5" "bands lists 3-5"
check_contains "$out" "6-8" "bands lists 6-8"
check_contains "$out" "9-12" "bands lists 9-12"
check_contains "$out" "13+" "bands lists 13+"
check_contains "$out" "Pre-reader" "bands shows the 3-5 blurb"

out="$("$CONF" band 6-8)"
check_contains "$out" "level=1" "band 6-8 defaults to the app grid (SPEC R-DESK-3)"
check_contains "$out" "web=garden" "band 6-8 has web=garden"
check_contains "$out" "budget_min=60" "band 6-8 has budget_min=60"
check_contains "$out" "lights_out=19:30" "band 6-8 has lights_out=19:30"
check_contains "$out" "lights_out_weekend=20:00" "band 6-8 weekend lights-out is 30 min later"
check_contains "$out" "terminal=none" "band 6-8 has no terminal"

out="$("$CONF" band 9-12)"
check_contains "$out" "level=3" "band 9-12 defaults to the desktop (SPEC R-DESK-3)"
check_contains "$out" "wifi=helper" "band 9-12 has the safe wifi helper"
check_contains "$out" "terminal=playground" "band 9-12 has a playground terminal"

"$CONF" band nope-such-band >/dev/null 2>&1
check_status "$?" 2 "band with a bad name exits 2"

# #200 changes only the desktop default; each band's other permissions stay distinct.
for pair in "3-5:1" "6-8:1" "9-12:3" "13+:3"; do
  band="${pair%%:*}"
  expected="${pair##*:}"
  check_contains "$("$CONF" band "$band")" "level=$expected" "$band has its intended desktop default"
done
check_contains "$("$CONF" band 13+)" "web=filtered" "older desktop keeps filtered-web permission"
check_contains "$("$CONF" band 13+)" "terminal=sandboxed" "older desktop keeps terminal policy data"
check_contains "$("$CONF" band 13+)" "menu=trimmed" "every band defaults to the trimmed menu now (SPEC R-DESK-3)"

# --- slug (Appendix B.1) --------------------------------------------------

check "$("$CONF" slug Ada)" "kid-ada" "slug: Ada -> kid-ada"
check "$("$CONF" slug "Zoë  O'Brien")" "kid-zoeobrien" "slug: transliterates and drops non-alphanumerics"
LONG40="$(printf 'a%.0s' {1..40})"
slug_long="$("$CONF" slug "$LONG40")"
check "${#slug_long}" "28" "slug: a 40-char name is truncated to a 24-char slug (kid- + 24)"
check "$slug_long" "kid-$(printf 'a%.0s' {1..24})" "slug: truncated slug is the first 24 chars"

# --- set: fixture profile (kid-ada, band 6-8 per AGENTS.md) ---------------

"$CONF" set kid-ada name Ada >/dev/null
"$CONF" set kid-ada avatar fox >/dev/null
"$CONF" set kid-ada band 6-8 >/dev/null
"$CONF" set kid-ada theme tokyo-night >/dev/null
check_status "$?" 0 "set writes the identity keys"

# Band and pack sources remain authoritative; the schema supplies only their source.
band_keys=(level web dns budget_min budget_min_weekend lights_out lights_out_weekend wifi history_visible menu)
for band in 3-5 6-8 9-12 13+; do
  "$CONF" set kid-ada band "$band" >/dev/null
  for key in "${band_keys[@]}"; do
    expected="$("$CONF" band "$band" | awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2) }')"
    check "$("$CONF" get kid-ada "$key")" "$expected" "schema precedence: $band $key comes from bands.toml"
  done
  expected="$(python3 "$DIR/lib/conf.py" pack-ids "$SHARE/packs/$band.toml")"
  check "$("$CONF" get kid-ada allowlist)" "$expected" "schema precedence: $band allowlist comes from its pack"
  expected="$(python3 "$DIR/lib/conf.py" pack-sites "$SHARE/packs/$band.toml")"
  check "$("$CONF" get kid-ada sites)" "$expected" "schema precedence: $band sites come from its pack"
done
"$CONF" set kid-ada band 6-8 >/dev/null

# Distinct scratch values prove band-derived keys are not silently global.
python3 - "$SHARE/bands/bands.toml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
band = None
for index, line in enumerate(lines):
    if line.startswith("[band.\""):
        band = line.split('"')[1]
    elif band == "6-8" and line.startswith("dns = "):
        lines[index] = 'dns = "cleanbrowsing-family"'
    elif band == "6-8" and line.startswith("history_visible = "):
        lines[index] = 'history_visible = "no"'
path.write_text("\n".join(lines) + "\n")
PY
check "$("$CONF" get kid-ada dns)" "cleanbrowsing-family" "get: dns follows a distinct band value"
check "$("$CONF" get kid-ada history_visible)" "no" "get: history visibility follows a distinct band value"
out="$("$CONF" show kid-ada)"
check "$(echo "$out" | awk '/^dns[ \t]/{print $NF}')" "band" "show: dns marks its band source"
check "$(echo "$out" | awk '/^history_visible[ \t]/{print $NF}')" "band" "show: history visibility marks its band source"

# --- export: the kid's overrides live, inherited values as comments -------

imp="$TMP/import.conf"
out="$("$CONF" export kid-ada)"
check "$(echo "$out" | head -1)" "# omarchy-kids-conf export for kid-ada" \
  "export: names the kid in a comment header"
check "$(echo "$out" | awk -F= '/^name=/{print $2}')" "Ada" "export: an override is a live line"
check_contains "$out" "# level=1 (inherited)" "export: an inherited value is commented, not pinned"
check_contains "$out" "# web=garden (inherited)" "export: inherited values are shown for reference"
check "$(grep -c '^level=' <<<"$out")" "0" "export: inherited values are not importable lines"
check "$(grep -c '^password=' <<<"$out")" "0" \
  "export: never prints a password (the hash lives in shadow)"

# A round trip re-applies only overrides, so inherited settings stay inherited.
"$CONF" set kid-ada level 1 >/dev/null
"$CONF" export kid-ada >"$imp"
"$CONF" unset kid-ada level >/dev/null
check "$("$CONF" get kid-ada level)" "1" "round trip: the override was cleared"
"$CONF" import kid-ada "$imp" >/dev/null
check "$("$CONF" get kid-ada level)" "1" "round trip: the override is restored"
check "$("$CONF" source kid-ada web)" "band" "round trip: inherited values stay inherited"
"$CONF" unset kid-ada level >/dev/null

# --- get: override -> band -> default fallback ----------------------------

check "$("$CONF" get kid-ada level)" "1" "get: level falls back to band 6-8's desktop default"
check "$("$CONF" get kid-ada web)" "garden" "get: web falls back to band default (garden)"
check "$("$CONF" get kid-ada onboarded)" "no" "get: onboarded falls back to the global default (no)"
check "$("$CONF" get kid-ada password)" "set" "get: password falls back to the global default (set)"
check "$("$CONF" get kid-ada allowlist)" \
  "gcompris,tuxpaint,ktuberling,blinken,supertux,supertuxkart,klettres,kanagram" \
  "get: allowlist falls back to the band's pack"

"$CONF" set kid-ada level 2 >/dev/null
check "$("$CONF" get kid-ada level)" "2" "get: an override wins over the band default"
check "$("$CONF" source kid-ada level)" "override" "source: reports an explicit override"
check "$("$CONF" source kid-ada wifi)" "band" "source: reports an inherited band value"
check "$("$CONF" source kid-ada onboarded)" "default" "source: reports an inherited global default"

"$CONF" set kid-ada level 1 >/dev/null
"$CONF" set kid-ada band 13+ >/dev/null
check "$("$CONF" get kid-ada level)" "1" "manual app grid survives switching to an older band"
"$CONF" set kid-ada band 6-8 >/dev/null
"$CONF" unset kid-ada level >/dev/null
check "$("$CONF" source kid-ada level)" "band" "unset: removes one override"
check "$("$CONF" get kid-ada level)" "1" "unset: exposes the band value again"
"$CONF" unset kid-ada name >/dev/null 2>&1
check_status "$?" 2 "unset: refuses a required key with no inherited value"
"$CONF" set kid-ada level 2 >/dev/null

# --- set: validation -------------------------------------------------------

"$CONF" set kid-ada level 9 >/dev/null 2>&1
check_status "$?" 2 "set: out-of-range level is refused"

"$CONF" set kid-ada web open-everything >/dev/null 2>&1
check_status "$?" 2 "set: a bad web value is refused"

"$CONF" set kid-ada lights_out "9pm" >/dev/null 2>&1
check_status "$?" 2 "set: a non-HH:MM lights_out is refused"

err="$("$CONF" set kid-ada frobnicate yes 2>&1 >/dev/null)"
status=$?
check_status "$status" 2 "set: an unknown key is refused"
check_contains "$err" "frobnicate" "set: the refusal names the bad key"

err="$("$CONF" get kid-ada frobnicate 2>&1 >/dev/null)"
status=$?
check_status "$status" 2 "get: an unknown key is also refused"

"$CONF" set kid-ada budget_min 75 >/dev/null
check "$("$CONF" get kid-ada budget_min)" "75" "set: a valid budget_min is written and read back"

# Every schema validator accepts the current shape and rejects its old bad shape.
valid_values=(
  "name|Ada" "avatar|fox" "band|6-8" "level|1" "web|garden"
  "dns|cloudflare-family" "dns|custom:https://example.test/dns" "budget_min|60" "budget_min_weekend|60"
  "lights_out|19:30" "lights_out_weekend|20:00" "wifi|parent"
  "history_visible|yes" "menu|trimmed" "theme|tokyo-night"
  "allowlist|gcompris" "allowlist|" "sites|example.com" "sites|" "password|set" "onboarded|no"
  "apps.extra|gcompris" "apps.extra|" "apps.hidden|gcompris" "apps.hidden|" "apps.show_missing|no"
)
for pair in "${valid_values[@]}"; do
  key="${pair%%|*}"
  value="${pair#*|}"
  "$CONF" set kid-ada "$key" "$value" >/dev/null 2>&1
  check "$?" "0" "schema validation: accepts $key's current valid shape"
done

invalid_values=(
  "name|" "avatar|Bad Id" "avatar|not-an-avatar"
  "band|7-9" "level|0" "web|open-everything" "dns|custom:" "dns|custom"
  "budget_min|0" "budget_min_weekend|1441" "lights_out|9pm"
  "lights_out_weekend|24:00" "wifi|child" "history_visible|maybe"
  "menu|all" "theme|Not A Real Theme" "theme|no-such-theme"
  "allowlist|not an id" "sites|not a host" "password|ask"
  "onboarded|maybe" "apps.extra|not an id" "apps.hidden|not an id"
  "apps.show_missing|maybe"
)
for pair in "${invalid_values[@]}"; do
  key="${pair%%|*}"
  value="${pair#*|}"
  "$CONF" set kid-ada "$key" "$value" >/dev/null 2>&1
  check "$?" "2" "schema validation: rejects $key's old invalid shape"
done

# Restore the source mix used by the existing show assertions.
source "$DIR/lib/conf.sh"
conf_del "$ETC/kids/kid-ada.conf" onboarded
conf_del "$ETC/kids/kid-ada.conf" wifi
"$CONF" set kid-ada level 2 >/dev/null

# --- theme (issue #53): validation, get, and the real apply side effect ----

check "$("$CONF" get kid-ada theme)" "tokyo-night" "get: theme reads back the fixture's override"

"$CONF" set kid-ada theme "Not A Real Theme" >/dev/null 2>&1
check_status "$?" 2 "set: a theme name with spaces/caps is refused before it ever checks the themes dir"

err="$("$CONF" set kid-ada theme no-such-theme 2>&1 >/dev/null)"
status=$?
check_status "$status" 2 "set: a lowercase-shaped but non-existent theme is refused"
check_contains "$err" "no-such-theme" "set: the refusal names the bad theme"
check_contains "$err" "$OMARCHY_PATH/themes" "set: the refusal names where it looked"

"$CONF" set kid-ada theme catppuccin-latte >/dev/null
check "$("$CONF" get kid-ada theme)" "catppuccin-latte" "set: a real installed theme is accepted and read back"


KID_THEME_DIR="$OMARCHY_KIDS_HOME_ROOT/home/kid-ada/.local/state/omarchy/current/theme"
check "$(cat "$KID_THEME_DIR/colors.toml" 2>/dev/null)" "$(cat "$OMARCHY_PATH/themes/catppuccin-latte/colors.toml")" \
  "set theme: theme_apply_for actually copied the new theme's colors.toml to disk"
check "$(cat "$OMARCHY_KIDS_HOME_ROOT/home/kid-ada/.local/state/omarchy/current/theme.name" 2>/dev/null)" "catppuccin-latte" \
  "set theme: theme.name on disk matches what was just set"

# put kid-ada back on tokyo-night for the rest of this file's fixtures
"$CONF" set kid-ada theme tokyo-night >/dev/null

# The package's own kid theme root: conf must accept a theme that ships only in
# the kid collection (KIDS_THEMES_DIR), not only Omarchy's. The constant is
# rewritten in a copy of lib/theme.sh, the one substitution seam (tree.sh).
THEME_TREE="$TMP/theme-tree"
kids_tree "$THEME_TREE" "$DIR"
rm -f "$THEME_TREE/lib"
cp -a "$DIR/lib" "$THEME_TREE/lib"
KID_THEMES="$TMP/kid-themes"
mkdir -p "$KID_THEMES/cozy-night"
echo 'background = "#000000"' >"$KID_THEMES/cozy-night/colors.toml"
kids_set_const "$THEME_TREE/lib/theme.sh" KIDS_THEMES_DIR "$KID_THEMES"
THEME_CONF="$THEME_TREE/bin/omarchy-kids-conf"
"$THEME_CONF" set kid-ada theme cozy-night >/dev/null 2>&1
check_status "$?" 0 "set: a theme from the kid collection is accepted (KIDS_THEMES_DIR)"
err="$("$THEME_CONF" set kid-ada theme no-such-kid 2>&1 >/dev/null)"
check_status "$?" 2 "set: a theme in neither root is refused"
check_contains "$err" "no-such-kid" "set: the refusal names the bad theme"

# A missing theme override still reports the parent-theme source even though
# `get` retains the required-profile failure used by provisioning.
"$CONF" set kid-ben name Ben >/dev/null
"$CONF" set kid-ben avatar fox >/dev/null
"$CONF" set kid-ben band 6-8 >/dev/null
check "$("$CONF" source kid-ben theme)" "default" \
  "source: a missing theme override reports the parent-theme default"
"$CONF" get kid-ben theme >/dev/null 2>&1
check_status "$?" 2 "get: theme with no override at all exits 2, same as name/avatar/band"

mkdir -p "$OMARCHY_KIDS_HOME_ROOT/home/kid-test/.local/state/omarchy/current"
printf 'tokyo-night\n' >"$OMARCHY_KIDS_HOME_ROOT/home/kid-test/.local/state/omarchy/current/theme.name"
printf 'parent=kid-test\n' >"$ETC/machine.conf"
"$CONF" unset kid-ada theme >/dev/null
check "$(grep -c '^theme=' "$ETC/kids/kid-ada.conf")" "0" \
  "unset theme: removes the explicit override"
check "$(cat "$OMARCHY_KIDS_HOME_ROOT/home/kid-ada/.local/state/omarchy/current/theme.name")" "tokyo-night" \
  "unset theme: applies the parent's inherited theme to the kid's home"
"$CONF" set kid-ada theme tokyo-night >/dev/null
rm -f "$ETC/machine.conf"

# --- show: source column ----------------------------------------------------
# Match on the key at the start of the line and the source at the end,
# rather than the exact column widths, so this doesn't break if the
# formatting ever changes.

out="$("$CONF" show kid-ada)"
check "$(echo "$out" | awk '/^level[ \t]/{print $NF}')" "override" "show: an overridden key is marked override"
check "$(echo "$out" | awk '/^wifi[ \t]/{print $NF}')" "band" "show: a band-derived key is marked band"
check "$(echo "$out" | awk '/^onboarded[ \t]/{print $NF}')" "default" "show: a global-default key is marked default"

# --- reset: keeps identity keys, clears the rest ----------------------------

"$CONF" set kid-ada onboarded yes >/dev/null
"$CONF" set kid-ada password set >/dev/null
"$CONF" set kid-ada menu full >/dev/null
"$CONF" reset kid-ada >/dev/null

profile="$ETC/kids/kid-ada.conf"
check "$(grep -c '^name=' "$profile")" "1" "reset: name survives"
check "$(grep -c '^avatar=' "$profile")" "1" "reset: avatar survives"
check "$(grep -c '^band=' "$profile")" "1" "reset: band survives"
check "$(grep -c '^theme=' "$profile")" "1" "reset: theme survives (issue #53)"
check "$(grep -c '^password=' "$profile")" "1" "reset: password survives"
check "$(grep -c '^onboarded=' "$profile")" "1" "reset: onboarded survives"
check "$(grep -c '^level=' "$profile")" "0" "reset: level override is cleared"
check "$(grep -c '^menu=' "$profile")" "0" "reset: menu override is cleared"
check "$("$CONF" get kid-ada level)" "1" "reset: level reads back as the band default again"
check "$("$CONF" get kid-ada onboarded)" "yes" "reset: onboarded keeps its value across reset"

# --- profile file permissions (spec 5.1: root 0644) -------------------------

mode="$(kids_file_mode "$profile")"
check "$mode" "644" "profile file is mode 0644"

# --- machine set parent: recording the parent's LUKS slot (docs/boot.md
#     step 5, lib/kids.sh's luks_slots_record_parent) -- without a "0="
#     line, a boot unlocked with the parent's own disk password lands on
#     the portal instead of their desktop -------------------------------

SLOTS_FILE="$ETC/luks-slots"

# Fresh file: no luks-slots at all yet.
rm -f "$SLOTS_FILE"
"$CONF" machine set parent mark >/dev/null
check "$(cat "$SLOTS_FILE" 2>/dev/null)" "0=mark" \
  "machine set parent: a fresh luks-slots gets a 0=<parent> line"
slots_mode="$(kids_file_mode "$SLOTS_FILE")"
check "$slots_mode" "600" "machine set parent: luks-slots stays mode 0600"

# Existing kid entries are kept, not clobbered, by the same write.
rm -f "$SLOTS_FILE"
printf '3=kid-ada\n5=kid-ben\n' >"$SLOTS_FILE"
"$CONF" machine set parent mark >/dev/null
check "$(grep -c '^3=kid-ada$' "$SLOTS_FILE")" "1" \
  "machine set parent: an existing kid entry survives the parent-slot write"
check "$(grep -c '^5=kid-ben$' "$SLOTS_FILE")" "1" \
  "machine set parent: a second existing kid entry survives too"
check "$(grep -c '^0=mark$' "$SLOTS_FILE")" "1" \
  "machine set parent: 0=<parent> is added alongside the kid entries"

# An existing 0= line is left alone, even one naming someone else.
rm -f "$SLOTS_FILE"
printf '0=someone-else\n3=kid-ada\n' >"$SLOTS_FILE"
err="$("$CONF" machine set parent mark 2>&1 >/dev/null)"
check_status "$?" 0 "machine set parent: an existing 0= line naming someone else doesn't fail the command"
check "$(cat "$SLOTS_FILE")" "$(printf '0=someone-else\n3=kid-ada')" \
  "machine set parent: the existing 0= line (and the rest of the file) is left untouched"
check_contains "$err" "left it alone" \
  "machine set parent: leaving an existing 0= line alone is noted on stderr"

# Slot 0 already claimed by a provisioned kid (kid-ada, set up above):
# refuses outright rather than clash with that kid's own LUKS slot.
rm -f "$SLOTS_FILE"
printf '0=kid-ada\n' >"$SLOTS_FILE"
err="$("$CONF" machine set parent mark 2>&1 >/dev/null)"
check_status "$?" 2 "machine set parent: a kid already on slot 0 makes the command fail"
check_contains "$err" "kid-ada" "machine set parent: the refusal names the kid holding slot 0"
check "$(cat "$SLOTS_FILE")" "0=kid-ada" \
  "machine set parent: refusing to clash leaves the kid's slot-0 line untouched"

rm -f "$SLOTS_FILE"

# --- machine set parent (issue #46: the wizard's Apply step writes this
#     before anything else, so omarchy-kids-authd and omarchy-kids-provision
#     both have a parent to check against) -----------------------------

MACHINE_CONF="$ETC/machine.conf"
out="$("$CONF" machine set parent mark)"
st=$?
check "$st" "0" "machine set parent exits 0"
check "$out" "machine: parent=mark" "machine set parent echoes what it wrote"
check "$(cat "$MACHINE_CONF" 2>/dev/null)" "parent=mark" "machine set parent creates machine.conf with the right line"
machine_mode="$(kids_file_mode "$MACHINE_CONF")"
check "$machine_mode" "644" "machine.conf is mode 0644, same as a kid's profile"

# idempotent, and in-place: a second write replaces the value, not appends.
"$CONF" machine set parent dana >/dev/null
check "$(cat "$MACHINE_CONF" 2>/dev/null)" "parent=dana" "machine set parent replaces the value in place, doesn't append a second line"
check "$(grep -c '^parent=' "$MACHINE_CONF")" "1" "machine set parent: still exactly one parent= line"

"$CONF" machine set parent "" >/dev/null 2>&1
check "$?" "2" "machine set parent rejects an empty value"

"$CONF" machine bogus parent mark >/dev/null 2>&1
check "$?" "2" "an unknown machine subcommand exits 2"

"$CONF" machine set bogus mark >/dev/null 2>&1
check "$?" "2" "an unknown machine key exits 2"

# sudo strips OMARCHY_PATH; the theme validation must not die on it (seen live 2026-09-03).
err="$(env -u OMARCHY_PATH "$CONF" set kid-ada theme tokyo-night 2>&1 >/dev/null)"
check "$?" "0" "set theme with OMARCHY_PATH unset exits 0"
[[ "$err" != *"unbound variable"* ]] && clean=0 || clean=1
check "$clean" "0" "set theme with OMARCHY_PATH unset prints no unbound-variable error"

# A profile change rebuilds the kid's session manifest on a provisioned box (the sessions dir
# exists), so the next login does not fail closed on a stale manifest (seen live 2026-09-04).
# shellcheck source=lib/kids.sh
source "$DIR/lib/kids.sh"
# shellcheck source=lib/conf.sh
source "$DIR/lib/conf.sh"
# shellcheck source=lib/launcher-map.sh
source "$DIR/lib/launcher-map.sh"
# shellcheck source=lib/session-manifest.sh
source "$DIR/lib/session-manifest.sh"
CONF_BIN="$CONF" LIB="$DIR/lib" KIDS_PY=python3 KIDS_DIR="$ETC/kids" SYSROOT="$TMP/sysroot"
export OMARCHY_KIDS_ROOT="$SYSROOT" # the map builder scans <root>/usr/share/applications, never this box's
mkdir -p "$ETC/sessions" "$ETC/launchers" "$SYSROOT" "$SHARE/avatars"
[[ -e "$SHARE/avatars/fox.svg" ]] || cp "$DIR/share/avatars/fox.svg" "$SHARE/avatars/fox.svg"
if session_manifest_build kid-ada 2>"$TMP/mf.err"; then
  "$CONF" set kid-ada budget_min 45 >/dev/null
  check "$(jq -r '.budget_min' "$ETC/sessions/kid-ada.json")" "45" "set: the session manifest follows the profile change"
else
  check "built" "not built: $(tr "\n" " " <"$TMP/mf.err" | cut -c1-400)" "set: a manifest could be built for the fixture kid"
fi
rm -rf "$ETC/sessions"
"$CONF" set kid-ada budget_min 60 >/dev/null
check "$?" "0" "set: no sessions dir (not provisioned) is not an error"

# --- trusted machine boot mode (R-BOOTMODE-1, R-BOOTMODE-12) -----------
# The boot reader has a fixed machine-conf path. Use a copied command tree
# and build-time substitutions, never an environment path override.
BOOT_TREE="$TMP/boot-tree"
BOOT_ETC="$TMP/boot-etc"
BOOT_LOCK="$BOOT_ETC/boot-mode.lock"
BOOT_STUBS="$TMP/boot-stubs"
mkdir -p "$BOOT_ETC" "$BOOT_STUBS"
kids_tree "$BOOT_TREE" "$DIR"
rm -f "$BOOT_TREE/lib"
cp -a "$DIR/lib" "$BOOT_TREE/lib"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$BOOT_ETC/machine.conf"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_LOCK "$BOOT_LOCK"
BOOT_CONF="$BOOT_TREE/bin/omarchy-kids-conf"
kids_id_stub "$BOOT_STUBS" mark 0
REAL_STAT="$(command -v stat)"
cat >"$BOOT_STUBS/stat" <<EOF
#!/bin/bash
if [[ "\${1:-}" == --version ]]; then exec "$REAL_STAT" "\$@"; fi
format=""
target=""
case "\${1:-}" in
  -c | -f)
    format="\${2:-}"
    target="\${3:-}"
    ;;
esac
if [[ "\$target" == "$BOOT_ETC" || "\$target" == "$BOOT_ETC/machine.conf" || "\$target" == "$BOOT_LOCK" ]]; then
  case "\$format" in
    %u)
      if [[ "\$target" == "$BOOT_ETC" ]]; then
        [[ -e "$TMP/unsafe-dir-owner" ]] && echo 501 || echo 0
      else
        [[ -e "$TMP/unsafe-file-owner" ]] && echo 501 || echo 0
      fi
      ;;
    %G | %Sg)
      if [[ "\$target" == "$BOOT_ETC" ]]; then
        [[ -e "$TMP/unsafe-dir-owner" ]] && echo staff || echo root
      else
        [[ -e "$TMP/unsafe-file-owner" ]] && echo staff || echo root
      fi
      ;;
    %a) exec "$REAL_STAT" -c '%a' "\$target" ;;
    %Lp) exec "$REAL_STAT" -f '%Lp' "\$target" ;;
    %i) if [[ "\${1:-}" == -c ]]; then exec "$REAL_STAT" -c '%i' "\$target"; else exec "$REAL_STAT" -f '%i' "\$target"; fi ;;
    *) exit 1 ;;
  esac
  exit 0
fi
exec "$REAL_STAT" "\$@"
EOF
cat >"$BOOT_STUBS/chown" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$BOOT_STUBS/flock" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$TMP/conf-flock.log"
exit 0
EOF
chmod +x "$BOOT_STUBS/stat" "$BOOT_STUBS/chown" "$BOOT_STUBS/flock"
BOOT_BASE="$(kids_base_path "$TMP/boot-base")"
BOOT_PATH="$BOOT_STUBS:$BOOT_BASE"

out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: missing mode exits 1"
check "$out" "" "machine get boot: missing mode has no stdout"

PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot portal >/dev/null
check "$?" 0 "machine set boot portal: root write exits 0"
check "$(test -f "$BOOT_LOCK" && echo present)" "present" "machine set boot: creates the shared lock file"
check "$(kids_file_mode "$BOOT_LOCK")" "600" "machine set boot: lock file is root-only"
check "$(head -1 "$TMP/conf-flock.log" | grep -E '^[0-9]+$' >/dev/null && echo locked)" "locked" "machine set boot: holds the shared lock while writing"
check "$(cat "$BOOT_ETC/machine.conf")" "boot=portal" "machine set boot portal: writes the exact enum"
check "$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot)" "portal" "machine get boot: prints exactly portal"
check "$(kids_file_mode "$BOOT_ETC/machine.conf")" "644" "boot machine.conf is mode 0644"

printf 'parent=mark\nboot=portal\n' >"$BOOT_ETC/machine.conf"
chmod 0644 "$BOOT_ETC/machine.conf"
PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot disk >/dev/null
check "$?" 0 "machine set boot disk: preserves existing machine keys"
check "$(cat "$BOOT_ETC/machine.conf")" $'parent=mark\nboot=disk' "machine set boot disk: replaces one boot key"

BOOT_ARTIFACT="$TMP/etc/mkinitcpio.conf.d/omarchy_kids.conf"
mkdir -p "$(dirname "$BOOT_ARTIFACT")"
printf 'untouched\n' >"$BOOT_ARTIFACT"
artifact_before="$(cat "$BOOT_ARTIFACT")"
PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot portal >/dev/null
check "$(cat "$BOOT_ARTIFACT")" "$artifact_before" "machine set boot: changes no boot artifact"

PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot nope >/dev/null 2>&1
check_status "$?" 2 "machine set boot: values outside disk|portal exit 2"
check "$(cat "$BOOT_ETC/machine.conf")" $'parent=mark\nboot=portal' "machine set boot: bad value does not mutate state"

PATH="$BOOT_PATH" "$BOOT_CONF" machine get >/dev/null 2>&1
check_status "$?" 2 "machine get: missing key exits 2"
PATH="$BOOT_PATH" "$BOOT_CONF" machine set >/dev/null 2>&1
check_status "$?" 2 "machine set: missing key exits 2"
PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot >/dev/null 2>&1
check_status "$?" 2 "machine set boot: missing value exits 2"

printf 'parent=mark\nboot=disk\n' >"$BOOT_ETC/machine.conf"
chmod 0664 "$BOOT_ETC/machine.conf"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: group/world-writable state exits 1"
check "$out" "" "machine get boot: unsafe mode has no stdout"
chmod 0644 "$BOOT_ETC/machine.conf"
touch "$TMP/unsafe-file-owner"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: wrong owner exits 1"
check "$out" "" "machine get boot: wrong file owner has no stdout"
rm -f "$TMP/unsafe-file-owner"

chmod 0775 "$BOOT_ETC"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: user-writable parent exits 1"
check "$out" "" "machine get boot: user-writable parent has no stdout"
chmod 0755 "$BOOT_ETC"

touch "$TMP/unsafe-dir-owner"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: wrong directory owner exits 1"
check "$out" "" "machine get boot: wrong directory owner has no stdout"
rm -f "$TMP/unsafe-dir-owner"

SYMLINK_ETC="$TMP/boot-etc-link"
mkdir -p "$TMP/real-boot-etc"
cp "$BOOT_ETC/machine.conf" "$TMP/real-boot-etc/machine.conf"
ln -s "$TMP/real-boot-etc" "$SYMLINK_ETC"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$SYMLINK_ETC/machine.conf"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: symlinked parent exits 1"
check "$out" "" "machine get boot: symlinked parent has no stdout"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$BOOT_ETC/machine.conf"

ln -sf "$BOOT_ETC/machine.conf" "$TMP/machine-link"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$TMP/machine-link"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: symlink state exits 1"
check "$out" "" "machine get boot: symlink state has no stdout"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$BOOT_ETC/machine.conf"

printf 'parent=mark\nboot=disk\nboot=portal\n' >"$BOOT_ETC/machine.conf"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: duplicate keys exit 1"
printf 'parent=mark\nboot=unknown\n' >"$BOOT_ETC/machine.conf"
out="$(PATH="$BOOT_PATH" "$BOOT_CONF" machine get boot 2>/dev/null)"
check_status "$?" 1 "machine get boot: invalid value exits 1"

printf 'parent=mark\nboot=portal\n' >"$BOOT_ETC/machine.conf"
before="$(cat "$BOOT_ETC/machine.conf")"
export KIDS_TEST_UID=501
PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot disk >/dev/null 2>&1
check_status "$?" 1 "machine set boot: non-root write exits 1"
check "$(cat "$BOOT_ETC/machine.conf")" "$before" "machine set boot: non-root write does not mutate state"
unset KIDS_TEST_UID

cat >"$BOOT_STUBS/mv" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$BOOT_STUBS/mv"
before="$(cat "$BOOT_ETC/machine.conf")"
PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot disk >/dev/null 2>&1
check_status "$?" 1 "machine set boot: failed atomic replace exits 1"
check "$(cat "$BOOT_ETC/machine.conf")" "$before" "machine set boot: failed replace preserves old state"
rm -f "$BOOT_STUBS/mv"

printf 'parent=mark\n' >"$BOOT_ETC/machine.conf"
PATH="$BOOT_PATH" "$BOOT_CONF" machine set boot disk >/dev/null
check "$?" 0 "machine set boot: explicit repair adds a missing boot key"
check "$(cat "$BOOT_ETC/machine.conf")" $'parent=mark\nboot=disk' "machine set boot: repaired state has one boot key"

# --- import: validated up front, applied in one atomic replace ------------

imp="$TMP/import.conf"
cat >"$imp" <<'EOF'
# settings for one kid
level=1
web=filtered
EOF
"$CONF" import kid-ada "$imp" >/dev/null
check "$("$CONF" get kid-ada level)" "1" "import: a valid file applies its overrides"
check "$("$CONF" get kid-ada web)" "filtered" "import: every valid line applies"
"$CONF" unset kid-ada level >/dev/null
"$CONF" unset kid-ada web >/dev/null

cat >"$imp" <<'EOF'
level=1
budget_min=99999
EOF
err="$("$CONF" import kid-ada "$imp" 2>&1)"
st=$?
check "$st" "2" "import: an out-of-range value exits 2"
check_contains "$err" "line 2" "import: the refusal names the line"
check_contains "$err" "budget_min" "import: the refusal names the key"
check "$("$CONF" get kid-ada level)" "1" "import: a rejected file changes nothing"

printf 'nonsense=1\n' >"$imp"
err="$("$CONF" import kid-ada "$imp" 2>&1)"
check_contains "$err" "unknown key 'nonsense'" "import: an unknown key is named"

printf 'password=set\n' >"$imp"
err="$("$CONF" import kid-ada "$imp" 2>&1)"
check_contains "$err" "system-managed" "import: a system-managed key is refused"

printf 'level=1\nlevel=1\n' >"$imp"
err="$("$CONF" import kid-ada "$imp" 2>&1)"
check_contains "$err" "duplicate key 'level'" "import: a duplicate key is refused"

printf 'level=1\r\n' >"$imp"
"$CONF" import kid-ada "$imp" >/dev/null
check "$("$CONF" get kid-ada level)" "1" "import: a CRLF line is accepted"
"$CONF" unset kid-ada level >/dev/null

# --- desktop-argv: the launcher's fixed Exec resolution (R-DESK-2) ----------
#
# A root-side validator (lib/launcher-map.sh calls it while a kid's launcher map
# is built), and the only thing that turns a .desktop Exec into the fixed argv
# the map carries. It resolves programs on the session PATH; the caller then
# refuses anything not root-owned or group/other-writable, which is what keeps a
# PATH a kid can set from choosing a binary in their map (AGENTS.md rule 9,
# docs/apps.md).

DESKTOP="$TMP/exec.desktop"

mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/stockprog"
chmod 0755 "$TMP/bin/stockprog"
cat >"$DESKTOP" <<'EOF'
[Desktop Entry]
Name=Thing
Exec=stockprog %u --flag
EOF
out="$(PATH="$TMP/bin:$PATH" python3 "$DIR/lib/conf.py" desktop-argv "$DESKTOP" 2>&1)"
check "$?" "0" "desktop-argv: a program on the session PATH resolves"
check "$(printf '%s' "$out" | python3 -c 'import json,sys; a=json.load(sys.stdin); print(a[0].rsplit("/",1)[-1], a[1:])')" \
  "stockprog ['--flag']" "desktop-argv: the field code is stripped and the program is absolute"
check_contains "$out" "$TMP/bin/stockprog" "desktop-argv: the resolved path is absolute"

# The resolved program is refused when it is not on the PATH at all.
cat >"$DESKTOP" <<'EOF'
[Desktop Entry]
Exec=stockprog %u
EOF
out="$(python3 "$DIR/lib/conf.py" desktop-argv "$DESKTOP" 2>&1)"
check "$?" "2" "desktop-argv: a program not on the PATH at all is refused"
check_contains "$out" "executable not found" "desktop-argv: the refusal names the missing executable"

# env with assignments is allowed; a shell -c is not.
cat >"$DESKTOP" <<'EOF'
[Desktop Entry]
Exec=env FOO=bar true %u
EOF
PATH="$(dirname "$(command -v python3)"):/usr/bin:/bin:$PATH" python3 "$DIR/lib/conf.py" desktop-argv "$DESKTOP" >/dev/null 2>&1
check "$?" "0" "desktop-argv: env with an assignment resolves the real program"

cat >"$DESKTOP" <<'EOF'
[Desktop Entry]
Exec=bash -c "echo hi"
EOF
out="$(python3 "$DIR/lib/conf.py" desktop-argv "$DESKTOP" 2>&1)"
check "$?" "2" "desktop-argv: a shell -c is refused"
check_contains "$out" "shell evaluation" "desktop-argv: the refusal names shell evaluation"

# no Exec, and an unsupported field code.
printf '[Desktop Entry]\nName=X\n' >"$DESKTOP"
out="$(python3 "$DIR/lib/conf.py" desktop-argv "$DESKTOP" 2>&1)"
check "$?" "2" "desktop-argv: a file with no Exec= is refused"
check_contains "$out" "no Exec=" "desktop-argv: the refusal says there is no Exec="

printf '[Desktop Entry]\nExec=true %%x\n' >"$DESKTOP"
out="$(python3 "$DIR/lib/conf.py" desktop-argv "$DESKTOP" 2>&1)"
check "$?" "2" "desktop-argv: an unsupported field code is refused"
check_contains "$out" "unsupported field code" "desktop-argv: the refusal names the field code"

exit $fail
