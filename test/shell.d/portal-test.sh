#!/bin/bash
# Static checks for the SDDM portal (SPEC.md R-LOGIN-1..5, R-BOOT-3,
# R-SEC-3, I-5, I-7; issue #14): share/sddm-theme/{metadata.desktop,
# theme.conf,Main.qml}, the twelve share/avatars/*.svg, PKGBUILD's
# install of the theme, and lib/posture.sh's/omarchy-kids-assert's
# theme-selection drop-in. Nothing here runs SDDM or Qt -- this machine
# has neither (Main.qml's header points at docs/portal.md for the
# unverified list) -- so every check is
# either a text/grep check, a bash -n/python3 xml.etree parse, or
# exercises lib/posture.sh's shell functions directly against a scratch
# tree (never the real /etc, per AGENTS.md rule 8). The one exception is
# Main.qml's syntax, which qmllint checks when a Qt6 toolchain is present
# (on Arch it lives in /usr/lib/qt6/bin) and which is skipped, loudly,
# when it is not.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THEME_DIR="$ROOT/share/sddm-theme"
AVATARS_DIR="$ROOT/share/avatars"
PKGBUILD="$ROOT/PKGBUILD"

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in '$1')"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want '$2')"; fi
}
rc=0

# --- metadata.desktop -----------------------------------------------------

METADATA="$THEME_DIR/metadata.desktop"
if [[ -f "$METADATA" ]]; then
  pass "share/sddm-theme/metadata.desktop exists"
  if grep -qE '^\[SddmGreeterTheme\]$' "$METADATA"; then
    pass "metadata.desktop has [SddmGreeterTheme]"
  else
    fail "metadata.desktop missing [SddmGreeterTheme]"
  fi
  if grep -qE '^MainScript=Main\.qml$' "$METADATA"; then
    pass "metadata.desktop has MainScript=Main.qml"
  else
    fail "metadata.desktop missing MainScript=Main.qml"
  fi
  for key in Name Type; do
    if grep -qE "^${key}=" "$METADATA"; then
      pass "metadata.desktop has $key="
    else
      fail "metadata.desktop missing $key="
    fi
  done
else
  fail "$METADATA not found"
fi

# --- theme.conf -------------------------------------------------------------

THEME_CONF="$THEME_DIR/theme.conf"
if [[ -f "$THEME_CONF" ]]; then
  pass "share/sddm-theme/theme.conf exists"
  if grep -qE '^\[General\]$' "$THEME_CONF"; then
    pass "theme.conf has [General]"
  else
    fail "theme.conf missing [General]"
  fi
else
  fail "$THEME_CONF not found"
fi

# --- Main.qml ----------------------------------------------------------------

MAIN_QML="$THEME_DIR/Main.qml"
PORTAL_JS="$THEME_DIR/PortalConfig.js"
if [[ -f "$MAIN_QML" ]]; then
  pass "share/sddm-theme/Main.qml exists"

  # Braces/parens balance: cheap, no qmllint needed, catches a stray
  # copy/paste error without a real QML engine.
  counts="$(python3 -c "
s = open('$MAIN_QML').read()
print(s.count('{'), s.count('}'), s.count('('), s.count(')'))
")"
  read -r ob cb op cp <<<"$counts"
  if [[ "$ob" == "$cb" && "$op" == "$cp" ]]; then
    pass "Main.qml braces/parens balance ($ob/$cb, $op/$cp)"
  else
    fail "Main.qml braces/parens do not balance ($ob/$cb, $op/$cp)"
  fi

  for needle in "userModel" "sessionModel" "sddm.login" "needsPassword" "sddm.powerOff"; do
    if grep -qF "$needle" "$MAIN_QML"; then
      pass "Main.qml references $needle"
    else
      fail "Main.qml missing a reference to $needle"
    fi
  done

  # I-5/I-6: the portal says why a password failed and which keys work.
  for needle in "That password didn't work. Try again." "Ctrl+Shift+P" "Enter Sign in"; do
    if grep -qF "$needle" "$MAIN_QML"; then
      pass "Main.qml shows the words: $needle"
    else
      fail "Main.qml is missing the words: $needle"
    fi
  done

  # Keyboard-complete (I-5, R-LOGIN-4): arrows, Enter, Escape all
  # handled, plus at least one generic Keys.onPressed (the power-off
  # chord).
  for needle in "Keys.onLeftPressed" "Keys.onRightPressed" "Keys.onReturnPressed" "Keys.onEscapePressed" "Keys.onPressed"; do
    if grep -qF "$needle" "$MAIN_QML"; then
      pass "Main.qml handles $needle"
    else
      fail "Main.qml missing $needle"
    fi
  done

  # I-5/I-6: the keys are discoverable and a failed password is worded,
  # not only shaken.
  for needle in "That password didn't work. Try again." "Ctrl+Shift+P Power off" "Enter Sign in"; do
    if grep -qF "$needle" "$MAIN_QML"; then
      pass "Main.qml words: $needle"
    else
      fail "Main.qml missing the wording: $needle"
    fi
  done

  # I-6: every hint names a key that acts on this box. Arrows need a second
  # tile to move to, Enter needs a tile at all, and SDDM may refuse power-off,
  # so each hint must sit behind its own guard inside keyHelpText() -- and
  # nowhere else in the file, which would make it unconditional again.
  keyhelp_fn="$(sed -n '/function keyHelpText/,/^    }/p' "$MAIN_QML")"
  arrow_gated=no
  enter_gated=no
  power_gated=no
  hint_gate_line() { # BODY GUARD_TEXT HINT_TEXT -- yes when HINT_TEXT sits on a line at or after GUARD_TEXT
    local guard hint
    guard="$(grep -nF "$2" <<<"$1" | cut -d: -f1)"
    hint="$(grep -nF "$3" <<<"$1" | cut -d: -f1)"
    [[ -n "$guard" && -n "$hint" && "$guard" -le "$hint" ]] && echo yes || echo no
  }
  arrow_gated="$(hint_gate_line "$keyhelp_fn" 'root.users.length > 1' '"← → Choose"')"
  enter_gated="$(hint_gate_line "$keyhelp_fn" 'root.users.length > 0' '"Enter Sign in"')"
  power_gated="$(hint_gate_line "$keyhelp_fn" 'sddm.canPowerOff' '"Ctrl+Shift+P Power off"')"
  if [[ "$arrow_gated" == yes && "$enter_gated" == yes && "$power_gated" == yes ]]; then
    pass "keyHelpText gates each hint behind the condition that makes the key act"
  else
    fail "keyHelpText offers a hint with no guard (arrows=$arrow_gated enter=$enter_gated power=$power_gated)"
  fi
  # The footer must come from keyHelpText() at all: counts are of the phrase,
  # not the quoted literal, so a restored hardcoded footer (with the function
  # left behind as dead code) is caught too.
  keyhelp_binding="$(grep -cF 'text: root.keyHelpText()' "$MAIN_QML")"
  arrows_file="$(grep -cF '← → Choose' "$MAIN_QML")"
  arrows_fn="$(grep -cF '← → Choose' <<<"$keyhelp_fn")"
  chord_file="$(grep -cF 'Ctrl+Shift+P Power off' "$MAIN_QML")"
  chord_fn="$(grep -cF 'Ctrl+Shift+P Power off' <<<"$keyhelp_fn")"
  enter_file="$(grep -cF 'Enter Sign in' "$MAIN_QML")"
  enter_fn="$(grep -cF 'Enter Sign in' <<<"$keyhelp_fn")"
  if [[ "$keyhelp_binding" == 1 && "$arrows_file" == "$arrows_fn" && "$arrows_fn" == 1 &&
    "$chord_file" == "$chord_fn" && "$chord_fn" == 1 &&
    "$enter_file" == "$enter_fn" && "$enter_fn" -ge 2 ]]; then
    pass "the footer is keyHelpText() and every hint phrase lives only inside it"
  else
    fail "a hint phrase also appears outside keyHelpText, or the footer does not use it (binding=$keyhelp_binding arrows=$arrows_fn/$arrows_file chord=$chord_fn/$chord_file enter=$enter_fn/$enter_file)"
  fi

  # The greeter is the one surface no screenshot on this project's dogfood VM
  # can reach (try-omarchy logs its owner in at the image level), so at least
  # its syntax is machine-checked wherever a qmllint exists; the pass line
  # prints the tool's own version so a wrong-major one is visible. On Arch the
  # Qt6 lint is /usr/lib/qt6/bin/qmllint, which is not on PATH.
  qmllint="$(command -v qmllint 2>/dev/null || true)"
  [[ -n "$qmllint" ]] || { [[ -x /usr/lib/qt6/bin/qmllint ]] && qmllint="/usr/lib/qt6/bin/qmllint"; }
  if [[ -n "$qmllint" ]]; then
    if out="$("$qmllint" "$MAIN_QML" 2>&1)"; then
      pass "Main.qml passes qmllint ($("$qmllint" --version 2>/dev/null | head -1))"
    else
      fail "Main.qml fails qmllint: $(tail -3 <<<"$out")"
    fi
  else
    echo "SKIP qmllint syntax check: no qmllint on PATH or at /usr/lib/qt6/bin"
  fi

  # R-LOGIN-1: parent identified as NOT kid-<slug>, and rendered
  # smaller than a kid tile.
  if grep -qF 'kid-' "$MAIN_QML"; then
    pass "Main.qml keys parent-vs-kid off the 'kid-' prefix"
  else
    fail "Main.qml does not reference the 'kid-' prefix anywhere"
  fi
  if grep -qF 'isParent' "$MAIN_QML"; then
    pass "Main.qml tracks isParent for smaller/last rendering"
  else
    fail "Main.qml has no isParent tracking"
  fi

  # R-LOGIN-3: the session lookup is by file (not a picker UI).
  if grep -qF 'omarchy-kids.desktop' "$MAIN_QML" && grep -qF 'omarchy.desktop' "$MAIN_QML"; then
    pass "Main.qml looks up sessionModel by the pinned .desktop file names"
  else
    fail "Main.qml does not look up both omarchy-kids.desktop and omarchy.desktop"
  fi

  # issue #39/#100: the portal consumes the root-written account allowlists,
  # never every regular account from SDDM's userModel.
  for needle in "config.parent" "config.kids" "config.parents" "parsePortalConfig" "isParentAccount" "portalParent" "portalKids" "portalParents" "isPortalUser" "avatarSourceFor"; do
    if grep -qF "$needle" "$MAIN_QML"; then
      pass "Main.qml references $needle"
    else
      fail "Main.qml missing a reference to $needle"
    fi
  done
  # "new XMLHttpRequest" is the actual instantiation; the header
  # comment's historical explanation of why that approach was dropped
  # still mentions the word "XMLHttpRequest" in prose, which is fine.
  if grep -qF "new XMLHttpRequest" "$MAIN_QML"; then
    fail "Main.qml still instantiates XMLHttpRequest (dropped: needs QML_XHR_ALLOW_FILE_READ, see lib/posture.sh)"
  else
    pass "Main.qml no longer uses XMLHttpRequest for parent/kids data"
  fi
  if grep -qF 'charAt(0).toUpperCase()' "$MAIN_QML"; then
    pass "Main.qml capitalizes the stripped-account-name display fallback"
  else
    fail "Main.qml does not capitalize the stripped-account-name display fallback"
  fi
  if grep -qF 'if (root.isPortalUser(name))' "$MAIN_QML"; then
    pass "Main.qml hides SDDM accounts outside the profile/parent allowlists"
  else
    fail "Main.qml does not hide SDDM accounts outside the profile/parent allowlists"
  fi
  if grep -qF 'Object.prototype.hasOwnProperty.call(root.portalKids, String(name))' "$MAIN_QML"; then
    pass "Main.qml uses an own-property check for profiled kids"
  else
    fail "Main.qml admits inherited portalKids properties"
  fi
  if [[ -f "$PORTAL_JS" ]] && grep -qF 'decodeURIComponent(String(value))' "$PORTAL_JS" &&
    grep -qF 'PortalConfig.parsePortalConfig' "$MAIN_QML"; then
    pass "Main.qml uses the shared delimiter-safe portal parser"
  else
    fail "Main.qml does not use the delimiter-safe PortalConfig parser"
  fi
  if command -v node >/dev/null 2>&1 && [[ -f "$PORTAL_JS" ]]; then
    if node - "$PORTAL_JS" <<'NODE'
const fs = require("fs")
const vm = require("vm")
const source = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*/, "")
const portal = {}
vm.runInNewContext(source, portal)
const cases = [
  ["Ada, Jr", "Ada%2C Jr"],
  ["Ada: Cy", "Ada%3A Cy"],
  ['Ada "Cy" \\kid', 'Ada "Cy" \\kid'],
  ["Ada\rCy", "Ada\rCy"],
  ['Ada%2C, Cy: "kid" \\ \r', 'Ada%252C%2C Cy%3A "kid" \\ \r']
]
for (const [name, encoded] of cases) {
  const result = portal.parsePortalConfig("mark", "mark", `kid-ada:${encoded}:fox,kid-cy:Cy:owl`)
  if (result.kids["kid-ada"].name !== name || result.kids["kid-cy"].name !== "Cy") process.exit(1)
}
NODE
    then
      pass "PortalConfig parser restores every adversarial name with two kids present"
    else
      fail "PortalConfig parser did not restore every adversarial name"
    fi
  fi
  if grep -qF '!root.hasPortalKid(name)' "$MAIN_QML"; then
    pass "Main.qml gives profiled-kid membership precedence over parent membership"
  else
    fail "Main.qml can classify an account in both allowlists as a parent"
  fi
  display_fn="$(sed -n '/function displayNameFor/,/^    }/p' "$MAIN_QML")"
  portal_name_line="$(grep -nF 'return portalEntry.name' <<<"$display_fn" | cut -d: -f1)"
  real_name_line="$(grep -nF 'return realName' <<<"$display_fn" | cut -d: -f1)"
  if [[ -n "$portal_name_line" && -n "$real_name_line" && "$portal_name_line" -lt "$real_name_line" ]]; then
    pass "Main.qml prefers the exact portal display name over the GECOS fallback"
  else
    fail "Main.qml lets the GECOS fallback override the exact portal display name"
  fi
  if command -v node >/dev/null 2>&1 && node -e '
    const kids = {}
    const hasKid = name => Object.prototype.hasOwnProperty.call(kids, String(name))
    if (hasKid("constructor")) process.exit(1)
  '; then
    pass "portal allowlist adversarial case: inherited constructor is not a kid"
  else
    fail "portal allowlist adversarial case: inherited constructor was admitted"
  fi
  if grep -qF 'console.error("portal: " + root.users.length + " tiles (kids="' "$MAIN_QML"; then
    pass "Main.qml logs the finalized portal tile count to stderr"
  else
    fail "Main.qml does not log the finalized portal tile count"
  fi
  if grep -qF 'function loginUser(user, password)' "$MAIN_QML" &&
    grep -qF 'if (sessionIndex < 0) {' "$MAIN_QML" &&
    [[ "$(grep -cF 'return -1' "$MAIN_QML")" -ge 1 ]] &&
    ! grep -qF 'return sessionModel.lastIndex' "$MAIN_QML"; then
    pass "Main.qml refuses login when a pinned session is missing"
  else
    fail "Main.qml can fall back to sessionModel.lastIndex for a missing pinned session"
  fi
  if grep -qF 'OpacityMask' "$MAIN_QML" && grep -qF 'radius: Math.max(0, root.cornerRadius - avatarImage.anchors.margins)' "$MAIN_QML"; then
    pass "Main.qml masks avatars to the inset parent-theme radius"
  else
    fail "Main.qml does not apply the parent-theme avatar mask"
  fi
else
  fail "$MAIN_QML not found"
fi

# --- avatars: twelve SVGs, each parses as XML -------------------------------

EXPECTED_AVATARS=(fox owl panda frog whale cat bear bee koala otter penguin tiger)
if [[ -d "$AVATARS_DIR" ]]; then
  pass "share/avatars/ exists"
  missing=()
  for a in "${EXPECTED_AVATARS[@]}"; do
    [[ -f "$AVATARS_DIR/$a.svg" ]] || missing+=("$a.svg")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    pass "all twelve avatar SVGs are present"
  else
    fail "missing avatar SVGs: ${missing[*]}"
  fi

  bad=()
  for a in "${EXPECTED_AVATARS[@]}"; do
    f="$AVATARS_DIR/$a.svg"
    [[ -f "$f" ]] || continue
    if ! python3 -c "import xml.etree.ElementTree as ET; ET.parse('$f')" >/dev/null 2>&1; then
      bad+=("$a.svg")
    fi
  done
  if [[ ${#bad[@]} -eq 0 ]]; then
    pass "every avatar SVG parses as well-formed XML"
  else
    fail "avatar SVGs that failed to parse: ${bad[*]}"
  fi

  if [[ -f "$AVATARS_DIR/LICENSE" ]] && grep -qi "CC0" "$AVATARS_DIR/LICENSE"; then
    pass "share/avatars/LICENSE declares CC0"
  else
    fail "share/avatars/LICENSE missing or does not mention CC0"
  fi
else
  fail "$AVATARS_DIR not found"
fi

# --- PKGBUILD installs the theme --------------------------------------------

if [[ -f "$PKGBUILD" ]]; then
  if bash -n "$PKGBUILD"; then
    pass "bash -n PKGBUILD"
  else
    fail "bash -n PKGBUILD"
  fi
  pkg_body="$(sed -n '/^package()/,/^}/p' "$PKGBUILD")"
  if grep -qE 'share/sddm-theme/\.' <<<"$pkg_body" && grep -qF '/usr/share/sddm/themes/omarchy-kids' <<<"$pkg_body"; then
    pass "package() installs share/sddm-theme/ to /usr/share/sddm/themes/omarchy-kids/"
  else
    fail "package() does not install share/sddm-theme/ to /usr/share/sddm/themes/omarchy-kids/"
  fi

  # issue #39: qt6-svg so the avatar SVGs actually rasterize.
  depends_line="$(grep -E '^depends=' "$PKGBUILD")"
  if grep -qF 'qt6-svg' <<<"$depends_line"; then
    pass "PKGBUILD depends= includes qt6-svg"
  else
    fail "PKGBUILD depends= is missing qt6-svg"
  fi
  if grep -qF 'qt6-5compat' <<<"$depends_line"; then
    pass "PKGBUILD depends= includes qt6-5compat for OpacityMask"
  else
    fail "PKGBUILD depends= is missing qt6-5compat for OpacityMask"
  fi
else
  fail "$PKGBUILD not found"
fi

# --- lib/posture.sh: the theme drop-in writer, exercised directly ----------
# (never the real /etc/sddm.conf.d -- AGENTS.md rule 8).

TMP="$(mktemp -d)"

# A base toolset only: an Omarchy box has the real omarchy-theme-color,
# and the "no theme to read, so every key falls back" cases below would
# get its derived colors instead (AGENTS.md, testing rules).
BASE_PATH="$(kids_base_path "$TMP/base")"
export PATH="$BASE_PATH"
trap 'rm -rf "$TMP"' EXIT
# shellcheck source=lib/conf.sh
source "$ROOT/lib/conf.sh"
# shellcheck source=lib/kids.sh
source "$ROOT/lib/kids.sh"
# shellcheck source=lib/posture.sh
source "$ROOT/lib/posture.sh"

OMARCHY_KIDS_ROOT="$TMP/root"
export OMARCHY_KIDS_ROOT
posture_write_sddm_theme_dropin
DROPIN="$OMARCHY_KIDS_ROOT/etc/sddm.conf.d/zz-omarchy-kids-theme.conf"
if [[ -f "$DROPIN" ]] && grep -qE '^\[Theme\]$' "$DROPIN" && grep -qE '^Current=omarchy-kids$' "$DROPIN"; then
  pass "posture_write_sddm_theme_dropin writes [Theme] Current=omarchy-kids"
else
  fail "posture_write_sddm_theme_dropin did not write the expected drop-in"
fi
posture_remove_sddm_theme_dropin
if [[ ! -e "$DROPIN" ]]; then
  pass "posture_remove_sddm_theme_dropin removes the drop-in"
else
  fail "posture_remove_sddm_theme_dropin left the drop-in in place"
fi
unset OMARCHY_KIDS_ROOT

# --- lib/posture.sh: theme.conf.user (issue #39) ---------------------------
# Replaces the earlier portal.json + sddm.service XHR drop-in design (see
# Main.qml's and lib/posture.sh's own header comments for why: the drop-in
# only took effect after `systemctl restart sddm`, which re-fires the
# owner's stock autologin on an already-booted machine).

OMARCHY_KIDS_ROOT="$TMP/root2"
export OMARCHY_KIDS_ROOT
posture_write_portal_conf mark \
  "$(printf 'kid-ada\tAda Lovelace\tfox')" \
  "$(printf 'kid-cy\tCy\towl')"
PORTAL_CONF="$OMARCHY_KIDS_ROOT/usr/share/sddm/themes/omarchy-kids/theme.conf.user"
if [[ -f "$PORTAL_CONF" ]]; then
  pass "posture_write_portal_conf writes theme.conf.user"
  check() { # got want label
    if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
  }
  check "$(grep -c '^\[General\]$' "$PORTAL_CONF")" "1" "theme.conf.user: [General] section"
  check "$(grep -c '^parent=mark$' "$PORTAL_CONF")" "1" "theme.conf.user: parent=mark"
  check "$(grep -c '^parents="mark"$' "$PORTAL_CONF")" "1" "theme.conf.user: parents allowlist includes the recorded parent"
  check "$(grep -c '^kids="kid-ada:Ada Lovelace:fox,kid-cy:Cy:owl"$' "$PORTAL_CONF")" "1" \
    "theme.conf.user: kids= line has both kids in order"
  mode="$(kids_file_mode "$PORTAL_CONF")"
  check "$mode" "644" "theme.conf.user: mode 0644"
  # idempotence: a second write with the same content is a no-op
  mtime1="$(kids_file_mtime "$PORTAL_CONF")"
  sleep 1
  posture_write_portal_conf mark \
    "$(printf 'kid-ada\tAda Lovelace\tfox')" \
    "$(printf 'kid-cy\tCy\towl')"
  mtime2="$(kids_file_mtime "$PORTAL_CONF")"
  check "$mtime2" "$mtime1" "posture_write_portal_conf is idempotent (no rewrite on unchanged content)"
else
  fail "posture_write_portal_conf did not write $PORTAL_CONF"
fi

check "$(posture_qsettings_value plain)" "plain" "QSettings: plain values stay unquoted"
check "$(posture_qsettings_value 'comma,value')" '"comma,value"' "QSettings: comma-bearing values are quoted"
check "$(posture_qsettings_value 'semicolon;value')" '"semicolon;value"' "QSettings: semicolon-bearing values are quoted"
check "$(posture_qsettings_value 'equals=value')" '"equals=value"' "QSettings: equals-bearing values are quoted"
check "$(posture_qsettings_value ' leading')" '" leading"' "QSettings: leading whitespace is quoted"
check "$(posture_qsettings_value 'trailing ')" '"trailing "' "QSettings: trailing whitespace is quoted"
check "$(posture_qsettings_value 'quote"slash\kid-ada')" 'quote\"slash\\kid-ada' \
  "QSettings: quotes and backslashes are escaped"
check "$(posture_qsettings_value $'carriage\rreturn')" 'carriage\rreturn' \
  "QSettings: carriage returns use Qt's named escape"
check "$(posture_qsettings_value $'\a\b\f\n\r\t\v')" '\a\b\f\n\r\t\v' \
  "QSettings: every named Qt control escape is exact"
check "$(posture_qsettings_value $'control\x01a')" 'control\x1\x61' \
  "QSettings: other controls and following hex digits use Qt's unambiguous escapes"
check "$(posture_qsettings_value plain always)" '"plain"' "QSettings: list values can be quoted unconditionally"
check "$(gecos_name_for_display 'Ada: Cy')" "" \
  "GECOS: colon-bearing display names use an empty fallback"
check "$(gecos_name_for_display 'Ada, Jr')" "Ada, Jr" \
  "GECOS: representable display names stay exact"

# A removed profile may leave its Unix account and home on disk by design; the
# producer must omit it so the consumer cannot render a stale tile.
posture_write_portal_conf mark "$(printf 'kid-cy\tCy\towl')"
check_not_contains "$(cat "$PORTAL_CONF")" "kid-ada" \
  "theme.conf.user: removed-but-present kid-ada is absent from the profile allowlist"

# Parent membership is explicit data too: the recorded parent plus members of
# omarchy-parents and wheel are the only non-kid accounts the portal may show.
GETENT_STUB="$TMP/getent"
cat >"$GETENT_STUB" <<'EOF'
#!/bin/bash
if [[ "$1" == group && "$2" == omarchy-parents ]]; then
  printf '%s\n' 'omarchy-parents:x:990:mark,parent-helper'
elif [[ "$1" == group && "$2" == wheel ]]; then
  printf '%s\n' 'wheel:x:10:parent-helper,wheel-helper'
fi
EOF
chmod +x "$GETENT_STUB"
PATH="$TMP:$BASE_PATH"
posture_write_portal_conf mark "$(printf 'kid-cy\tCy\towl')"
check "$(grep -c '^parents="mark,parent-helper,wheel-helper"$' "$PORTAL_CONF")" "1" \
  "theme.conf.user: parents allowlist includes valid members of both parent groups"
PATH="$BASE_PATH"
unset OMARCHY_KIDS_ROOT

# --- lib/posture.sh: theme.conf.user's color/font keys (docs/theming.md,
# issue #48) -- posture_theme_conf_lines' nine [General] keys, layered
# over theme.conf's own defaults by SDDM's ThemeConfig::setTo() the same
# way parent=/kids= already are (this file's own header comment). No real
# "mark" account exists on this dev/test machine, so posture_parent_home
# falls back to OMARCHY_KIDS_HOME_ROOT-prefixed "/home/mark" -- which has
# no colors.toml either, so every key below is lib/theme.sh's own
# fallback palette (the exact values theme.conf itself ships as hardcoded
# defaults).

OMARCHY_KIDS_ROOT="$TMP/root2b"
OMARCHY_KIDS_HOME_ROOT="$TMP/homeroot-empty"
FONT_STUBS="$TMP/font-stubs"
mkdir -p "$FONT_STUBS"
cat >"$FONT_STUBS/fc-match" <<'EOF'
#!/bin/bash
printf '%s' 'Mono, Serif'
EOF
chmod +x "$FONT_STUBS/fc-match"
PATH="$FONT_STUBS:$BASE_PATH"
export OMARCHY_KIDS_ROOT OMARCHY_KIDS_HOME_ROOT PATH
posture_write_portal_conf mark \
  "$(printf 'kid-ada\tAda Lovelace\tfox')"
PORTAL_CONF2="$OMARCHY_KIDS_ROOT/usr/share/sddm/themes/omarchy-kids/theme.conf.user"
if [[ -f "$PORTAL_CONF2" ]]; then
  check "$(grep -c '^\[General\]$' "$PORTAL_CONF2")" "1" \
    "theme.conf.user: still exactly one [General] section with color/font keys appended"
  check "$(grep -c '^backgroundColor=#1a1b26$' "$PORTAL_CONF2")" "1" "theme.conf.user: backgroundColor falls back"
  check "$(grep -c '^tileColor=#232838$' "$PORTAL_CONF2")" "1" "theme.conf.user: tileColor falls back"
  check "$(grep -c '^tileHighlightColor=#3a4266$' "$PORTAL_CONF2")" "1" "theme.conf.user: tileHighlightColor falls back"
  check "$(grep -c '^parentTileColor=#1f2335$' "$PORTAL_CONF2")" "1" "theme.conf.user: parentTileColor falls back"
  check "$(grep -c '^accentColor=#8fb8ff$' "$PORTAL_CONF2")" "1" "theme.conf.user: accentColor falls back"
  check "$(grep -c '^textColor=#ffffff$' "$PORTAL_CONF2")" "1" "theme.conf.user: textColor falls back"
  check "$(grep -c '^mutedTextColor=#9aa5ce$' "$PORTAL_CONF2")" "1" "theme.conf.user: mutedTextColor falls back"
  check "$(grep -c '^errorColor=#f7768e$' "$PORTAL_CONF2")" "1" "theme.conf.user: errorColor falls back"
  check "$(grep -c '^fontFamily="Mono, Serif"$' "$PORTAL_CONF2")" "1" \
    "theme.conf.user: comma-bearing fontFamily is quoted"
else
  fail "posture_write_portal_conf did not write $PORTAL_CONF2"
fi
unset OMARCHY_KIDS_ROOT OMARCHY_KIDS_HOME_ROOT
PATH="$BASE_PATH"
export PATH

# --- lib/posture.sh: theme.conf.user's colors actually follow the
# parent's real theme, not just the fallback (docs/theming.md) -- a
# fixture colors.toml under a scratch "parent" home, plus a stub
# omarchy-theme-color on PATH (the real tool's own `--file <path> <key>`
# shape, matching test/shell.d/theme-test.sh's own fixture stub), proves
# the whole chain: posture_write_portal_conf -> posture_theme_conf_lines
# -> posture_parent_home -> lib/theme.sh's theme_color -> the parent's
# own colors.toml.

STUBS2="$TMP/stubs2"
mkdir -p "$STUBS2"
cat >"$STUBS2/omarchy-theme-color" <<'EOF'
#!/bin/bash
file="" key=""
while (( $# > 0 )); do
    case "$1" in
        --file) file="$2"; shift 2 ;;
        --all) key="--all"; shift ;;
        *) key="$1"; shift ;;
    esac
done
[[ -f "$file" ]] || exit 1
[[ "$key" == "--all" ]] && exit 0
value="$(sed -nE "s/^${key}[[:space:]]*=[[:space:]]*[\"']?([^\"']*)[\"']?.*/\1/p" "$file" | head -1)"
[[ -n "$value" ]] || exit 1
printf '%s\n' "$value"
EOF
chmod +x "$STUBS2/omarchy-theme-color"

HOMEROOT="$TMP/homeroot"
PARENT_THEME_DIR="$HOMEROOT/home/mark/.local/state/omarchy/current/theme"
mkdir -p "$PARENT_THEME_DIR"
cat >"$PARENT_THEME_DIR/colors.toml" <<'EOF'
background = "#101010"
foreground = "#f0f0f0"
accent = "#00ffcc"
muted = "#606060"
red = "#ff2222"
orange = "#ffbb00"
lighter_background = "#202020"
dark_background = "#050505"
selection = "#303030"
EOF

OMARCHY_KIDS_ROOT="$TMP/root2c"
OMARCHY_KIDS_HOME_ROOT="$HOMEROOT"
PATH="$STUBS2:$BASE_PATH"
export OMARCHY_KIDS_ROOT OMARCHY_KIDS_HOME_ROOT PATH
# Force lib/theme.sh's own readiness probe to run again: it caches its
# answer per process (_theme_kids_tool_ready, "one log line, not one per
# color"), and an earlier scenario above already cached "unavailable"
# with no omarchy-theme-color on PATH at all.
_THEME_KIDS_TOOL_STATUS=""
posture_write_portal_conf mark \
  "$(printf 'kid-ada\tAda Lovelace\tfox')"
PORTAL_CONF3="$OMARCHY_KIDS_ROOT/usr/share/sddm/themes/omarchy-kids/theme.conf.user"
if [[ -f "$PORTAL_CONF3" ]]; then
  check "$(grep -c '^backgroundColor=#101010$' "$PORTAL_CONF3")" "1" \
    "theme.conf.user: backgroundColor reads the parent's real colors.toml"
  check "$(grep -c '^accentColor=#00ffcc$' "$PORTAL_CONF3")" "1" \
    "theme.conf.user: accentColor reads the parent's real colors.toml"
  check "$(grep -c '^errorColor=#ff2222$' "$PORTAL_CONF3")" "1" \
    "theme.conf.user: errorColor maps to the parent's 'red'"
  check "$(grep -c '^tileColor=#202020$' "$PORTAL_CONF3")" "1" \
    "theme.conf.user: tileColor maps to the parent's 'lighter_background'"
  check "$(grep -c '^tileHighlightColor=#303030$' "$PORTAL_CONF3")" "1" \
    "theme.conf.user: tileHighlightColor maps to the parent's 'selection'"
else
  fail "posture_write_portal_conf did not write $PORTAL_CONF3"
fi
unset OMARCHY_KIDS_ROOT OMARCHY_KIDS_HOME_ROOT
PATH="$BASE_PATH"
export PATH
_THEME_KIDS_TOOL_STATUS=""

# --- lib/posture.sh: SDDM face icons (issue #39, live VM finding) ----------
# SDDM's UserModel reads the avatar from <FacesDir>/<account>.face.icon,
# not from AccountsService's Icon= key -- see lib/posture.sh's own header
# comment on posture_write_face_icon for the UserModel.cpp citation.

OMARCHY_KIDS_ROOT="$TMP/root3"
export OMARCHY_KIDS_ROOT
FOX_SVG="$AVATARS_DIR/fox.svg"
posture_write_face_icon "$FOX_SVG" kid-ada
FACE_ICON="$OMARCHY_KIDS_ROOT/usr/share/sddm/faces/kid-ada.face.icon"
if [[ -f "$FACE_ICON" ]] && cmp -s "$FOX_SVG" "$FACE_ICON"; then
  pass "posture_write_face_icon copies the avatar SVG byte-for-byte"
else
  fail "posture_write_face_icon did not write an exact copy to $FACE_ICON"
fi
mode="$(kids_file_mode "$FACE_ICON")"
if [[ "$mode" == "644" ]]; then
  pass "posture_write_face_icon: mode 0644"
else
  fail "posture_write_face_icon: mode is $mode, want 644"
fi
posture_remove_face_icon kid-ada
if [[ ! -e "$FACE_ICON" ]]; then
  pass "posture_remove_face_icon removes the file"
else
  fail "posture_remove_face_icon left the file in place"
fi
if posture_write_face_icon "$TMP/no-such-avatar.svg" kid-ada 2>/dev/null; then
  fail "posture_write_face_icon should fail on a missing source file"
else
  pass "posture_write_face_icon fails on a missing source file"
fi
# =====================================================================
# review S9/S10: names that would corrupt the files root writes
# =====================================================================
#
# S9: `posture_polkit_admin_rule_text` interpolates the parent's name into
# JavaScript through an UNQUOTED heredoc. A `parent=` value carrying a
# quote or a ']' either breaks the admin rule outright -- polkit then asks
# for *root*'s password instead of the parent's -- or injects code.
# S10: a display name carrying ':' or ',' shifts every later tile in the
# greeter's `kids=` field onto the wrong account.

for bad_parent in 'mark"; polkit.addAdminRule(function(){return ["unix-user:root"]}); //' \
  'mark]' "mark'" 'Mark Smith' '../mark' ''; do
  if posture_polkit_admin_rule_text "$bad_parent" >/dev/null 2>&1; then
    fail "S9: a polkit admin rule was written for an unusable parent name: $bad_parent"
  else
    pass "S9: refused to write a polkit rule for '$bad_parent'"
  fi
  if posture_portal_conf_text "$bad_parent" >/dev/null 2>&1; then
    fail "S9: theme.conf.user was written for an unusable parent name: $bad_parent"
  else
    pass "S9: refused to write theme.conf.user for '$bad_parent'"
  fi
done

rule="$(posture_polkit_admin_rule_text mark)"
check_contains "$rule" 'return ["unix-user:mark"];' "S9: an ordinary parent name still writes the rule"

# S10: payload delimiters are encoded before the full value receives its
# separate QSettings encoding.
conf="$(posture_portal_conf_text mark \
  "$(printf 'kid-ada\tAda\tfox')" \
  "$(printf 'kid-dot\tDot:Cy,kid-ada\towl')" \
  "$(printf 'kid-cy\tCy\tbear')" 2>/dev/null)"
check_contains "$conf" 'kids="kid-ada:Ada:fox,kid-dot:Dot%3ACy%2Ckid-ada:owl,kid-cy:Cy:bear"' \
  "S10: colon and comma are payload-encoded without shifting the next tile"

unset OMARCHY_KIDS_ROOT

echo "portal-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
