#!/bin/bash
# Issue #187: portal provisioning must not receive disk-only LUKS flags.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY="$DIR/lib/wizard-apply.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
mkdir -p "$STUBS"

cat >"$STUBS/sudo" <<'EOF'
#!/bin/bash
set -euo pipefail
[[ "$1" == -n ]] || exit 2
shift
exec "$@"
EOF
cat >"$STUBS/conf" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "$1" == machine && "$2" == get && "$3" == boot ]]; then
  [[ "$(cat "__MODE__")" == read-failure ]] && exit 7
  cat "__MODE__"
else
  exit 2
fi
EOF
cat >"$STUBS/provision" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >"__ARGS__"
cat >"__INPUT__"
EOF
sed -i.bak \
  -e "s#__MODE__#$TMP/mode#g" \
  -e "s#__ARGS__#$TMP/args#g" \
  -e "s#__INPUT__#$TMP/input#g" \
  "$STUBS/conf" "$STUBS/provision"
rm -f "$STUBS/conf.bak" "$STUBS/provision.bak"
chmod +x "$STUBS/sudo" "$STUBS/conf" "$STUBS/provision"

fragment="$TMP/apply-step.sh"
sed -n '/^apply_step_account()/,/^}/p' "$APPLY" >"$fragment"

run_case() { # mode expected_args expected_input expected_status
  local mode="$1" expected_args="$2" expected_input="$3" expected_status="$4" status
  printf '%s\n' "$mode" >"$TMP/mode"
  printf '%s' "$expected_input" >"$TMP/expected"
  : >"$TMP/args"
  : >"$TMP/input"
  set +e
  PATH="$STUBS:/usr/bin:/bin" \
    MODE="$mode" CONF_BIN="$STUBS/conf" PROVISION_BIN="$STUBS/provision" \
    bash -c '
      set -u
      DRY_RUN=0 NO_PASSWORD=0 DISPLAY_NAME="Ben" BAND=6-8 AVATAR=fox
      KID_PASSWORD=kid-secret PARENT_PASSWORD=parent-secret
      LEVEL=standard WEB_MODE=ask WIFI_MODE=ask BUDGET_MIN=60 LIGHTS_OUT=21:00
      ALLOWLIST_IDS=one DNS_MODE=secure SITES=none HISTORY_VISIBLE=yes
      BUDGET_MIN_WEEKEND=75 LIGHTS_OUT_WEEKEND=21:00 THEME=Latte
      run_priv_stdin() { sudo -n "$@"; }
      maybe_override() { :; }
      band_field() { printf default; }
      pack_field() { printf app; }
      pack_sites() { printf site; }
      theme_current_name() { printf Latte; }
      source "$1"
      apply_step_account
    ' _ "$fragment"
  status=$?
  set -e
  if [[ "$status" != "$expected_status" ]]; then
    echo "FAIL $mode status (want $expected_status, got $status)"
    return 1
  fi
  if [[ "$expected_status" == 0 ]]; then
    [[ "$(cat "$TMP/args")" == "$expected_args" ]] || {
      echo "FAIL $mode argv: $(cat "$TMP/args")"
      return 1
    }
    cmp -s "$TMP/input" "$TMP/expected" || {
      echo "FAIL $mode stdin"
      return 1
    }
  else
    [[ ! -s "$TMP/args" ]] || {
      echo "FAIL $mode invoked provision"
      return 1
    }
  fi
}

run_case portal 'add Ben --band 6-8 --avatar fox --password-stdin --apply' $'kid-secret\n' 0
run_case disk 'add Ben --band 6-8 --avatar fox --password-stdin --parent-password-stdin --apply' $'kid-secret\nparent-secret\n' 0
run_case invalid 'unused' 'unused' 1
run_case read-failure 'unused' 'unused' 1

echo "ok   portal and disk account streams are mode-specific; invalid mode fails closed"
