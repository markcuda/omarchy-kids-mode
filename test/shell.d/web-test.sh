#!/bin/bash
# Tests bin/omarchy-kids-web (SPEC.md R-WEB-1..4) and the manifest-backed web
# tile consumed by bin/omarchy-kids-session-start.
#
# Self-contained: a copied command has its build-time SHARE/ETC/SYSROOT
# constants substituted with scratch paths (same convention as the session test).
# The /etc prefix is not an env var any more: R-WEB-4's fail-closed check
# reads it, and a kid must not be able to point a fence check at a tree
# they own (review §3.8). It is a build-time constant, substituted into a
# copy of the command the way PKGBUILD substitutes one at package time.
# shellcheck disable=SC2015 # "A && B || C" below is always used with B, C that can't fail
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
BIN="" # a substituted copy in the scratch tree, set up below
SESSION_START="$DIR/bin/omarchy-kids-session-start"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP web-test.sh: jq not found"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP web-test.sh: python3 not found (needed by omarchy-kids-conf)"
  exit 0
fi

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

SHARE="$TMP/share"
ETC="$TMP/etc"
mkdir -p "$SHARE/bands" "$SHARE/packs" "$SHARE/policy/lists"
cp "$DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$DIR"/share/packs/*.toml "$SHARE/packs/"
cp "$DIR"/share/policy/*.json "$SHARE/policy/"
cp "$DIR"/share/policy/lists/*.txt "$SHARE/policy/lists/"
cp "$DIR/share/policy/chromium-flags.conf" "$SHARE/policy/"

STUBS="$TMP/stubs"
mkdir -p "$STUBS"
kids_tree "$TMP/tree" "$DIR"
BIN="$TMP/tree/bin/omarchy-kids-web"
kids_set_const "$BIN" SHARE "$SHARE"

# `launch` resolves the band from the caller's own profile (`id -un`),
# never $OMARCHY_KIDS_BAND: the band decides which managed policy must be
# live before Chromium starts (review §3.8).
ETC_LAUNCH="$TMP/etc-launch"
mkdir -p "$ETC_LAUNCH/kids"
printf 'name=Ada\navatar=fox\nband=6-8\n' >"$ETC_LAUNCH/kids/kid-ada.conf"
printf 'name=Bo\navatar=fox\nband=9-12\n' >"$ETC_LAUNCH/kids/kid-bo.conf"
kids_id_stub "$STUBS" kid-ada "$(id -u)"
export PATH="$STUBS:$PATH"

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
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then echo "ok   $3"; else
    echo "FAIL $3 (did not want to find '$2' in '$1')"
    fail=1
  fi
}
check_status() { # got_status want_status label
  if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want exit $2, got $1)"
    fail=1
  fi
}

# =====================================================================
# render: baseline keys, every band (R-WEB-2)
# =====================================================================

for band in 3-5 6-8 9-12 13+; do
  out="$("$BIN" render "$band")"
  st=$?
  check_status "$st" 0 "render $band: exits 0"
  check "$(jq -r '.DnsOverHttpsMode' <<<"$out")" "secure" "render $band: DnsOverHttpsMode=secure"
  check "$(jq -r '.DnsOverHttpsTemplates' <<<"$out")" "https://family.cloudflare-dns.com/dns-query" \
    "render $band: DoH template is Cloudflare Family"
  check "$(jq -r '.ForceGoogleSafeSearch' <<<"$out")" "true" "render $band: ForceGoogleSafeSearch"
  check "$(jq -r '.ForceYouTubeRestrict' <<<"$out")" "2" "render $band: ForceYouTubeRestrict=2"
  check "$(jq -r '.IncognitoModeAvailability' <<<"$out")" "1" "render $band: IncognitoModeAvailability=1"
  check "$(jq -r '.DeveloperToolsAvailability' <<<"$out")" "2" "render $band: DeveloperToolsAvailability=2"
  check "$(jq -c '.ExtensionInstallBlocklist' <<<"$out")" '["*"]' "render $band: ExtensionInstallBlocklist=[\"*\"]"
  check "$(jq -r '.BrowserSignin' <<<"$out")" "0" "render $band: BrowserSignin=0"
  # No first-run or promo popups, and nothing that leaves the machine on the
  # kid's behalf (the owner's "app updates/promos showing up" note; I-2).
  check "$(jq -r '.PromotionalTabsEnabled' <<<"$out")" "false" "render $band: no promotional tabs"
  check "$(jq -r '.DefaultBrowserSettingEnabled' <<<"$out")" "false" "render $band: no default-browser prompt"
  check "$(jq -r '.MetricsReportingEnabled' <<<"$out")" "false" "render $band: no metrics leave the machine"
  check "$(jq -r '.SearchSuggestEnabled' <<<"$out")" "false" "render $band: no search-suggestion requests"
  check "$(jq -r '.DownloadRestrictions' <<<"$out")" "1" "render $band: DownloadRestrictions=1"
  check "$(jq -r '.SavingBrowserHistoryDisabled' <<<"$out")" "false" "render $band: SavingBrowserHistoryDisabled=false"
  check "$(jq -r '.AllowDeletingBrowserHistory' <<<"$out")" "false" "render $band: AllowDeletingBrowserHistory=false"
done

# =====================================================================
# render: per-mode shape (R-WEB-3)
# =====================================================================

# --- 3-5 (none): blocked, no allowlist key, password manager off -------
out="$("$BIN" render 3-5)"
check "$(jq -c '.URLBlocklist' <<<"$out")" '["*"]' "render 3-5: URLBlocklist=[\"*\"]"
check "$(jq -r 'has("URLAllowlist")' <<<"$out")" "false" "render 3-5: no URLAllowlist key at all"
check "$(jq -r '.PasswordManagerEnabled' <<<"$out")" "false" "render 3-5: PasswordManagerEnabled=false"

out="$("$BIN" render 3-5 --allow /dev/null 2>&1)"
st=$?
check_status "$st" 2 "render 3-5 --allow: refuses (exit 2)"
check_contains "$out" "takes no allowlist" "render 3-5 --allow: names the reason"

# --- 6-8, 9-12 (garden): blocked plus a merged allowlist ---------------
for band in 6-8 9-12; do
  out="$("$BIN" render "$band")"
  check "$(jq -c '.URLBlocklist' <<<"$out")" '["*"]' "render $band: URLBlocklist=[\"*\"]"
  check_contains "$(jq -c '.URLAllowlist' <<<"$out")" "pbskids.org" "render $band: allowlist includes pbskids.org from the starter list"
  n="$(jq -r '.URLAllowlist | length' <<<"$out")"
  [[ "$n" -gt 0 ]] && echo "ok   render $band: allowlist is non-empty ($n hosts)" ||
    {
      echo "FAIL render $band: allowlist is empty"
      fail=1
    }
done
check "$(jq -r '.PasswordManagerEnabled' <<<"$("$BIN" render 6-8)")" "false" "render 6-8: PasswordManagerEnabled=false (young band)"
check "$(jq -r 'has("PasswordManagerEnabled")' <<<"$("$BIN" render 9-12)")" "false" "render 9-12: PasswordManagerEnabled left unset"

# --allow merges an extra host and dedupes one already on the starter list
ALLOW_FILE="$TMP/kid-sites.txt"
cat >"$ALLOW_FILE" <<'EOF'
# a kid's own approved sites
example-approved.org
pbskids.org
EOF
out="$("$BIN" render 6-8 --allow "$ALLOW_FILE")"
check_contains "$(jq -c '.URLAllowlist' <<<"$out")" "example-approved.org" "render 6-8 --allow: merges the extra host"
count="$(jq -r '[.URLAllowlist[] | select(. == "pbskids.org")] | length' <<<"$out")"
check "$count" "1" "render 6-8 --allow: pbskids.org is not duplicated"

# --- 13+ (filtered): neither key, --allow refused ----------------------
out="$("$BIN" render 13+)"
check "$(jq -r 'has("URLBlocklist")' <<<"$out")" "false" "render 13+: no URLBlocklist key (R-WEB-3: filtered adds neither)"
check "$(jq -r 'has("URLAllowlist")' <<<"$out")" "false" "render 13+: no URLAllowlist key"

out="$("$BIN" render 13+ --allow /dev/null 2>&1)"
st=$?
check_status "$st" 2 "render 13+ --allow: refuses (exit 2)"
check_contains "$out" "R-WEB-3" "render 13+ --allow: cites R-WEB-3"

# =====================================================================
# render: --out, unknown band
# =====================================================================

OUT_FILE="$TMP/out.json"
"$BIN" render 6-8 --out "$OUT_FILE" >/dev/null
if [[ -f "$OUT_FILE" ]] && jq -e '.' "$OUT_FILE" >/dev/null 2>&1; then
  echo "ok   render --out: wrote valid JSON to the named file"
else
  echo "FAIL render --out: no valid JSON at $OUT_FILE"
  fail=1
fi

out="$("$BIN" render nope 2>&1)"
st=$?
check_status "$st" 2 "render with an unknown band: exits 2"
check_contains "$out" "unknown band" "render with an unknown band: names the reason"

# =====================================================================
# install: dry-run by default, --apply writes at 0640 root:group
# =====================================================================

SYSROOT="$TMP/sysroot"
mkdir -p "$SYSROOT"
kids_set_const "$BIN" SYSROOT "$SYSROOT"
kids_set_const "$BIN" ETC "$ETC_LAUNCH"

POLICY_FILE="$SYSROOT/etc/chromium/policies/managed/omarchy-kids-6-8.json"

out="$(DRY_RUN=1 "$BIN" install 6-8 2>&1)"
st=$?
check_status "$st" 0 "install (dry-run): exits 0"
check_contains "$out" "[dry-run]" "install (dry-run): prints a dry-run line"
[[ -e "$POLICY_FILE" ]] && {
  echo "FAIL install (dry-run): must not write $POLICY_FILE"
  fail=1
} ||
  echo "ok   install (dry-run): wrote nothing"

out="$("$BIN" install 6-8 --apply 2>&1)"
st=$?
check_status "$st" 0 "install --apply: exits 0"
if [[ -f "$POLICY_FILE" ]]; then
  echo "ok   install --apply: wrote $POLICY_FILE"
  mode="$(kids_file_mode "$POLICY_FILE")"
  check "$mode" "640" "install --apply: mode is 0640 (R-WEB-1)"
  check "$(jq -r '.DnsOverHttpsMode' "$POLICY_FILE")" "secure" "install --apply: content is the rendered policy"
else
  echo "FAIL install --apply: did not write $POLICY_FILE"
  fail=1
fi

# 13+ installs cleanly too (no allowlist to merge).
out="$("$BIN" install 13+ --apply 2>&1)"
st=$?
check_status "$st" 0 "install 13+ --apply: exits 0"
[[ -f "$SYSROOT/etc/chromium/policies/managed/omarchy-kids-13+.json" ]] &&
  echo "ok   install 13+ --apply: wrote omarchy-kids-13+.json" ||
  {
    echo "FAIL install 13+ --apply: file missing"
    fail=1
  }

# =====================================================================
# launch: exact exec argv (issue #44) -- Omarchy's own Wayland/password-
# store/feature flags, never --load-extension, plus --no-first-run
# --no-default-browser-check --hide-crash-restore-bubble
# --disable-session-crashed-bubble, and the URL last when one is given.
# Reuses $SYSROOT/6-8's and 13+'s policy files installed just above; 9-12
# was never installed in this SYSROOT, so it doubles as the R-WEB-4
# fail-closed case below.
# =====================================================================

EXPECTED_LAUNCH_ARGV=(
  /usr/lib/chromium/chromium
  --ozone-platform=wayland
  --ozone-platform-hint=wayland
  --password-store=basic
  --enable-features=TouchpadOverscrollHistoryNavigation
  --no-first-run
  --no-default-browser-check
  --hide-crash-restore-bubble
  --disable-session-crashed-bubble
)
expected_joined="$(printf '%s\n' "${EXPECTED_LAUNCH_ARGV[@]}")"

argv_out="$(OMARCHY_KIDS_WEB_NO_EXEC=1 "$BIN" launch 2>&1)"
st=$?
check_status "$st" 0 "launch: exits 0"
check "$argv_out" "$expected_joined" "launch: exact exec argv, no URL"
check_not_contains "$argv_out" "--load-extension" "launch: never --load-extension (issue #44)"

argv_out_url="$(OMARCHY_KIDS_WEB_NO_EXEC=1 "$BIN" launch https://pbskids.org 2>&1)"
st=$?
check_status "$st" 0 "launch URL: exits 0"
check "$argv_out_url" "$expected_joined"$'\n'"https://pbskids.org" "launch URL: exact exec argv with the URL appended last"

out="$(KIDS_TEST_ACCOUNT=kid-bo OMARCHY_KIDS_WEB_NO_EXEC=1 "$BIN" launch 2>&1)"
st=$?
check_status "$st" 1 "launch: refuses when the band's policy isn't installed (exit 1)"
check_contains "$out" "R-WEB-4" "launch: refusal cites R-WEB-4"

# The browser this execs is a constant, not an override: a kid's session
# must not be able to name the program that opens with their policy.
grep -q '^ *local chromium_bin=/usr/lib/chromium/chromium$' "$DIR/bin/omarchy-kids-web" &&
  echo "ok   launch: the Chromium path is a hardcoded constant, not an env override" ||
  {
    echo "FAIL launch: the Chromium path is no longer a hardcoded constant"
    fail=1
  }

# =====================================================================
# --help
# =====================================================================

out="$("$BIN" --help 2>&1)"
st=$?
check_status "$st" 0 "--help exits 0"
check_contains "$out" "Usage: omarchy-kids-web" "--help prints usage"

# =====================================================================
# The manifest remains valid when the band's policy file is missing; its
# root-built tile list simply contains no chromium tile (R-WEB-4).
# =====================================================================

ETC="$TMP/etc-session"
RUN="$TMP/run-session"
mkdir -p "$ETC/kids" "$ETC/sessions"
cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada
avatar=fox
band=6-8
level=1
theme=tokyo-night
web=garden
budget_min=60
budget_min_weekend=60
lights_out=19:30
lights_out_weekend=20:00
EOF

cat >"$ETC/sessions/kid-ada.json" <<'EOF'
{"schema_version":1,"account":"kid-ada","name":"Ada","avatar":"fox","band":"6-8","level":1,"theme":"tokyo-night","allowlist":[],"web":"garden","policy_id":"omarchy-kids-6-8","budget_min":60,"budget_min_weekend":60,"lights_out":"19:30","lights_out_weekend":"20:00","tiles":[]}
EOF

kids_tree "$TMP/session-tree" "$DIR"
SESSION_START="$TMP/session-tree/bin/omarchy-kids-session-start"
kids_set_const "$SESSION_START" SHARE "$SHARE"
kids_set_const "$SESSION_START" RUN "$RUN"
cat >"$TMP/session-tree/bin/omarchy-kids-session" <<EOF
#!/bin/bash
set -euo pipefail
[[ "\${1:-}" == --manifest ]]
cat "$ETC/sessions/kid-ada.json"
EOF
chmod +x "$TMP/session-tree/bin/omarchy-kids-session"
out="$(OMARCHY_KIDS_SESSION_START_NO_EXEC=1 bash "$SESSION_START" 2>&1)"
st=$?
check_status "$st" 0 "session-start with a manifest lacking Chromium: exits 0"
check "$(jq -r '.tiles | map(select(.id == "chromium")) | length' "$ETC/sessions/kid-ada.json")" "0" \
  "session-start: manifest has no chromium tile when the policy file is missing"
[[ ! -e "$RUN/launcher-$(id -u).json" ]] && echo "ok   session-start: no runtime launcher JSON" ||
  {
    echo "FAIL session-start: runtime launcher JSON was written"
    fail=1
  }

echo "web-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit $fail
