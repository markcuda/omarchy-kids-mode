#!/bin/bash
# Tests bin/omarchy-kids-session and bin/omarchy-kids-blocked
# (SPEC.md R-DESK-1, R-DESK-2, R-WEB-4, R-FND-2a, I-3, I-4, I-9).
#
# Fully self-contained: findmnt, systemctl, and Hyprland are all fakes on
# a stub PATH under this test's own scratch tree (never the real ones),
# and every path omarchy-kids-session touches is redirected by substituting
# build-time constants in a copied command -- nothing here reads or writes
# the real /etc, /run, or /home (AGENTS.md rule 8). The test-only
# OMARCHY_KIDS_TEST_* env vars below aren't part of omarchy-kids-session's
# own contract -- they're how this file's findmnt/systemctl/Hyprland
# stubs (single-quoted heredocs, so nothing in them is expanded until the
# stub itself runs) learn what to report for the current scenario.
# shellcheck disable=SC2015 # "A && B || C" below is always used with B, C that can't fail
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
BIN="" # a copy in the scratch tree below; the compositor it execs is a
# build-time constant, so the stub is substituted in, not exported

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in: $1)"; fi
}
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ACCOUNT="kid-ada"
BAND="6-8"
LEVEL="1"

# --- scratch tree ----------------------------------------------------------

ETC="$TMP/etc/omarchy-kids"
SHARE="$TMP/share/omarchy-kids"
SYSROOT="$TMP/sysroot"
RUN="$TMP/run"
STUBS="$TMP/stubs"
KIDHOME="$TMP/home/$ACCOUNT"

mkdir -p "$ETC/kids" "$ETC/hyprland" "$SHARE/hyprland" \
  "$SYSROOT/etc/chromium/policies/managed" "$SYSROOT/etc/polkit-1/rules.d" \
  "$RUN" "$STUBS" "$KIDHOME"

POLICY="$SYSROOT/etc/chromium/policies/managed/omarchy-kids-$BAND.json"
POLKIT_ADMIN="$SYSROOT/etc/polkit-1/rules.d/40-omarchy-kids.rules"
POLKIT_DENY="$SYSROOT/etc/polkit-1/rules.d/41-omarchy-kids-deny.rules"
LEVEL_CONF="$ETC/hyprland/L$LEVEL.lua"
PROFILE="$ETC/kids/$ACCOUNT.conf"
LOG_FILE="$RUN/session-$(id -u).log"
HYPRLAND_LOG="$TMP/hyprland-argv.log"
HOME_OPTS_FILE="$TMP/home-opts"
TMP_OPTS_FILE="$TMP/tmp-opts"
SHM_OPTS_FILE="$TMP/shm-opts"
GETTY_STATE_DIR="$TMP/getty-state.d"

write_profile() { # write_profile WEB
  cat >"$PROFILE" <<EOF
name=Ada
avatar=fox
band=$BAND
level=$LEVEL
web=${1:-garden}
EOF
}

# --- stub: pkcheck answers what the polkit deny rule would make it answer ---
cat >"$STUBS/pkcheck" <<'PK'
#!/bin/bash
ans="$(cat "${PKCHECK_ANSWER_FILE:-/dev/null}" 2>/dev/null)"
case "$ans" in
  # polkit's answer when it authorizes outright (root, or an admin inside its
  # window): no output at all, exit 0.
  authorized) exit 0 ;;
  "") ans="Not authorized." ;;
esac
printf '%s\n' "$ans" >&2
[[ "$ans" == *authorized* ]] && exit 1 || exit 0
PK
chmod +x "$STUBS/pkcheck"
export PKCHECK_ANSWER_FILE="$TMP/pkcheck.answer"
export VERIFY_FAIL_FILE="$TMP/verify.fail"
# --- stub PATH: findmnt, systemctl, Hyprland --------------------------

cat >"$STUBS/findmnt" <<'EOF'
#!/bin/bash
# Real usage this stub needs to answer: `findmnt -no OPTIONS <target>`.
target="${*: -1}"
printf '%s\n' "$target" >>"$OMARCHY_KIDS_TEST_FINDMNT_LOG"
if [[ "$target" == "$OMARCHY_KIDS_TEST_HOME" ]]; then
  cat "$OMARCHY_KIDS_TEST_HOME_OPTS"
elif [[ "$target" == "/tmp" ]]; then
  cat "$OMARCHY_KIDS_TEST_TMP_OPTS"
elif [[ "$target" == "/dev/shm" ]]; then
  cat "$OMARCHY_KIDS_TEST_SHM_OPTS"
else
  exit 1
fi
EOF

cat >"$STUBS/systemctl" <<'EOF'
#!/bin/bash
# Real usage this stub needs to answer:
# `systemctl [--root=...] is-enabled getty@ttyN.service`.
unit="${*: -1}"
cat "$OMARCHY_KIDS_TEST_GETTY_STATE_DIR/$unit"
EOF

cat >"$STUBS/getent" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == passwd ]]; then
  account="${2:-}"
  printf '%s:x:%s:%s::%s:/bin/bash\n' "$account" "$(id -u)" "$(id -u)" "$OMARCHY_KIDS_TEST_HOME"
  exit 0
fi
exit 1
EOF

cat >"$STUBS/Hyprland" <<'EOF'
#!/bin/bash
# --verify-config: answer from a control file (missing = config verifies).
if [[ " $* " == *" --verify-config "* ]]; then
  if [[ -f "${VERIFY_FAIL_FILE:-/nonexistent}" ]]; then echo "config error: boom" >&2; exit 1; fi
  exit 0
fi
{ printf 'HYPRLAND'; printf ' %s' "$@"; printf '\n'; } >> "$OMARCHY_KIDS_TEST_HYPRLAND_LOG"
{
  printf 'ACCOUNT=%s\n' "$OMARCHY_KIDS_ACCOUNT"
  printf 'LEVEL=%s\n' "$OMARCHY_KIDS_LEVEL"
  printf 'BAND=%s\n' "$OMARCHY_KIDS_BAND"
  printf 'HYPRLAND_DIR=%s\n' "$OMARCHY_KIDS_HYPRLAND_DIR"
} >> "$OMARCHY_KIDS_TEST_HYPRLAND_LOG"
EOF

cp "$STUBS/Hyprland" "$STUBS/start-hyprland" # the launcher takes the same argv
chmod +x "$STUBS/findmnt" "$STUBS/systemctl" "$STUBS/getent" "$STUBS/Hyprland" "$STUBS/start-hyprland"

# The command under test runs from a scratch tree: /usr/bin/Hyprland is
# a constant now (a kid's own environment.d could otherwise point PATH's
# "Hyprland" at anything and get a session with no level config), so the
# stub is substituted into a copy the way PKGBUILD substitutes KIDS_PY.
kids_tree "$TMP/tree" "$ROOT_DIR"
BIN="$TMP/tree/bin/omarchy-kids-session"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$BIN" SHARE "$SHARE"
kids_set_const "$BIN" SYSROOT "$SYSROOT"
kids_set_const "$BIN" RUNTIME_DIR "$RUN"
kids_set_const "$BIN" RUN_DIR "$RUN"
kids_set_const "$BIN" HYPRLAND_BIN "$STUBS/Hyprland"
kids_set_const "$BIN" HYPRLAND_START "$STUBS/start-hyprland"

# `id -un` is how a command answers "which account am I?" now -- never
# $OMARCHY_KIDS_ACCOUNT (review §3.7) -- so this test stubs `id` the way
# it already stubs the rest of its world. The real uid is kept so every
# per-uid path (launcher-<uid>.json) still resolves to one place.
kids_id_stub "$STUBS" "$ACCOUNT" "$(id -u)"
export PATH="$STUBS:$PATH"
export OMARCHY_KIDS_BLOCKED_SLEEP=0
export HOME="$KIDHOME"
export OMARCHY_KIDS_TEST_HOME="$KIDHOME"
export OMARCHY_KIDS_TEST_HOME_OPTS="$HOME_OPTS_FILE"
export OMARCHY_KIDS_TEST_TMP_OPTS="$TMP_OPTS_FILE"
export OMARCHY_KIDS_TEST_SHM_OPTS="$SHM_OPTS_FILE"
export OMARCHY_KIDS_TEST_GETTY_STATE_DIR="$GETTY_STATE_DIR"
export OMARCHY_KIDS_TEST_HYPRLAND_LOG="$HYPRLAND_LOG"
export OMARCHY_KIDS_TEST_FINDMNT_LOG="$TMP/findmnt.log"

reset_pass() {                                     # everything set up so every check passes
  rm -f "$PKCHECK_ANSWER_FILE" "$VERIFY_FAIL_FILE" # stubs answer "all good" again
  write_profile garden
  rm -f "$POLICY"
  : >"$POLICY"
  chmod 644 "$POLICY"
  : >"$POLKIT_ADMIN"
  : >"$POLKIT_DENY"
  : >"$LEVEL_CONF"
  echo "rw,nosuid,nodev,noexec,relatime" >"$HOME_OPTS_FILE"
  echo "tmpfs rw,nosuid,nodev,noexec,relatime private" >"$TMP_OPTS_FILE"
  echo "tmpfs rw,nosuid,nodev,noexec,relatime private" >"$SHM_OPTS_FILE"
  mkdir -p "$GETTY_STATE_DIR"
  for n in 2 3 4 5 6; do echo "masked" >"$GETTY_STATE_DIR/getty@tty$n.service"; done
  rm -f "$LOG_FILE" "$HYPRLAND_LOG" "$OMARCHY_KIDS_TEST_FINDMNT_LOG"
}

# =====================================================================
# 1. Non-kid (no profile) refuses.
# =====================================================================

reset_pass
rm -f "$PROFILE"
out="$("$BIN" 2>&1)"
st=$?
check_eq "$st" 1 "no profile: exits 1"
check_contains "$out" "profile present" "no profile: names the failed check"
check_contains "$out" "Ask a grown-up" "no profile: shows the ask-grownup message"
[[ -e "$HYPRLAND_LOG" ]] && fail "no profile: must not start Hyprland" || pass "no profile: did not start Hyprland"
check_contains "$(cat "$LOG_FILE" 2>/dev/null)" "check=profile" "no profile: log records the profile check"
check_contains "$(cat "$LOG_FILE" 2>/dev/null)" "result=FAIL" "no profile: log records FAIL"

# =====================================================================
# 2. Every other fail-closed check, one at a time: stops the start,
#    names the right check, never starts Hyprland.
# =====================================================================

run_fail_case() { # run_fail_case LABEL BREAK_FN CHECK_ID HUMAN_NAME
  local label="$1" break_fn="$2" check_id="$3" human="$4"
  reset_pass
  "$break_fn"
  out="$("$BIN" 2>&1)"
  st=$?
  check_eq "$st" 1 "$label: exits 1"
  check_contains "$out" "$human" "$label: names '$human' in the ask-grownup output"
  [[ -e "$HYPRLAND_LOG" ]] && fail "$label: must not start Hyprland" || pass "$label: did not start Hyprland"
  check_contains "$(cat "$LOG_FILE" 2>/dev/null)" "check=$check_id" "$label: log records check=$check_id"
  check_contains "$(cat "$LOG_FILE" 2>/dev/null)" "result=FAIL" "$label: log records FAIL"
}

# shellcheck disable=SC2329 # invoked indirectly, via run_fail_case's "$break_fn"
break_policy() { rm -f "$POLICY"; }
run_fail_case "policy missing (web=garden)" break_policy policy "browser policy readable"

# shellcheck disable=SC2329 # invoked indirectly, via run_fail_case's "$break_fn"
break_policy_unreadable() { chmod 000 "$POLICY"; }
run_fail_case "policy unreadable (web=garden)" break_policy_unreadable policy "browser policy readable"

# shellcheck disable=SC2329 # invoked indirectly, via run_fail_case's "$break_fn"
break_polkit() { printf "Authorization requires authentication\n" >"$PKCHECK_ANSWER_FILE"; }
run_fail_case "polkit deny rule missing" break_polkit polkit "polkit rules present"
break_verify() { touch "$VERIFY_FAIL_FILE"; }
run_fail_case "level config fails verification" break_verify level_config "level config present"

# shellcheck disable=SC2329 # invoked indirectly, via run_fail_case's "$break_fn"
break_home() { echo "rw,nosuid,nodev,relatime" >"$HOME_OPTS_FILE"; }
run_fail_case "home not noexec" break_home home_noexec "home noexec"

# shellcheck disable=SC2329 # invoked indirectly, via run_fail_case's "$break_fn"
break_getty() { echo "enabled" >"$GETTY_STATE_DIR/getty@tty3.service"; }
run_fail_case "getty@tty3 not masked" break_getty consoles_masked "consoles masked"

# shellcheck disable=SC2329 # invoked indirectly, via run_fail_case's "$break_fn"
break_level_conf() { rm -f "$LEVEL_CONF"; }
run_fail_case "level config missing" break_level_conf level_config "level config present"

# =====================================================================
# 3. Both namespace mounts are required to be private tmpfs mounts with
#    nosuid,nodev,noexec (R-FND-2a).
# =====================================================================

reset_pass
break_tmp() { echo "tmpfs rw,nosuid,nodev,relatime private" >"$TMP_OPTS_FILE"; }
run_fail_case "/tmp is executable" break_tmp tmp_noexec "private /tmp noexec"

break_shm() { echo "tmpfs rw,nosuid,nodev,noexec,relatime shared" >"$SHM_OPTS_FILE"; }
run_fail_case "/dev/shm is shared" break_shm shm_noexec "private /dev/shm noexec"

# =====================================================================
# 4. web=none skips the browser policy check entirely, even with no
#    policy file on disk (R-WEB-4).
# =====================================================================

reset_pass
write_profile none
rm -f "$POLICY"
out="$("$BIN" 2>&1)"
st=$?
check_eq "$st" 0 "web=none: starts even with no policy file"
[[ -e "$HYPRLAND_LOG" ]] && pass "web=none: Hyprland started" || fail "web=none: Hyprland did not start"
check_contains "$(cat "$LOG_FILE" 2>/dev/null)" "check=policy" "web=none: policy check still logged"
check_contains "$(cat "$LOG_FILE" 2>/dev/null)" "result=PASS" "web=none: policy check logs PASS, not FAIL"

# =====================================================================
# 5. Everything passing: execs the Hyprland stub with the right
#    --config and the three documented env vars.
# =====================================================================

reset_pass
out="$("$BIN" 2>&1)"
st=$?
check_eq "$st" 0 "all pass: exits 0 (exec of the Hyprland stub succeeded)"
argv="$(cat "$HYPRLAND_LOG" 2>/dev/null)"
check_contains "$argv" "HYPRLAND -- --config $LEVEL_CONF" "all pass: start-hyprland stub got -- --config $LEVEL_CONF"
check_contains "$argv" "ACCOUNT=$ACCOUNT" "all pass: OMARCHY_KIDS_ACCOUNT exported"
check_contains "$argv" "LEVEL=$LEVEL" "all pass: OMARCHY_KIDS_LEVEL exported"
check_contains "$argv" "BAND=$BAND" "all pass: OMARCHY_KIDS_BAND exported"
check_contains "$argv" "HYPRLAND_DIR=$ETC/hyprland" "all pass: OMARCHY_KIDS_HYPRLAND_DIR exported"

# =====================================================================
# 6. --check: prints a table and does not start anything, whether every
#    check passes or one fails.
# =====================================================================

reset_pass
out="$("$BIN" --check 2>&1)"
st=$?
check_eq "$st" 0 "--check (all pass): exits 0"
check_contains "$out" "profile present" "--check (all pass): table names the profile check"
check_contains "$out" "PASS" "--check (all pass): table shows PASS"
[[ -e "$HYPRLAND_LOG" ]] && fail "--check must never start Hyprland" || pass "--check (all pass): did not start Hyprland"

reset_pass
break_polkit
out="$("$BIN" --check 2>&1)"
st=$?
check_eq "$st" 1 "--check (polkit missing): exits 1"
check_contains "$out" "polkit rules present" "--check (polkit missing): table names the polkit check"
check_contains "$out" "FAIL" "--check (polkit missing): table shows FAIL"
check_contains "$out" "level config present" "--check (polkit missing): still runs later checks (full table)"
[[ -e "$HYPRLAND_LOG" ]] && fail "--check (polkit missing): must never start Hyprland" || pass "--check (polkit missing): did not start Hyprland"

# Setup has no child PAM namespace. Only those two checks are deferred;
# the ordinary report and real login still reject the same broken mounts.
reset_pass
break_tmp
break_shm
rmdir "$RUN"
out="$("$BIN" --check-setup 2>&1)"
st=$?
check_eq "$st" 0 "--check-setup: executable/shared caller mounts do not fail setup"
check_contains "$(printf '%s' "$out" | tr -s ' ')" "private /tmp noexec SKIP" "--check-setup: /tmp is explicitly skipped"
check_contains "$(printf '%s' "$out" | tr -s ' ')" "private /dev/shm noexec SKIP" "--check-setup: /dev/shm is explicitly skipped"
check_contains "$out" "checked at child login" "--check-setup: states when skipped checks run"
check_eq "$(cat "$OMARCHY_KIDS_TEST_FINDMNT_LOG" 2>/dev/null)" "$KIDHOME" \
  "--check-setup: owned findmnt stub observes only the global home mount"
[[ -d "$RUN" ]] && fail "--check-setup must not create a session runtime directory" || pass "--check-setup did not create a session runtime directory"
[[ -e "$LOG_FILE" ]] && fail "--check-setup must not write a session log" || pass "--check-setup did not write a session log"
[[ -e "$HYPRLAND_LOG" ]] && fail "--check-setup must never start Hyprland" || pass "--check-setup did not start Hyprland"
out="$("$BIN" --check 2>&1)"
check_eq "$?" 1 "--check still rejects the caller's unsafe namespace"
out="$("$BIN" 2>&1)"
check_eq "$?" 1 "normal start still rejects the caller's unsafe namespace"
[[ -e "$HYPRLAND_LOG" ]] && fail "unsafe namespace must not start Hyprland" || pass "unsafe namespace did not start Hyprland"

# =====================================================================
# 3b. Root: polkit authorizes root outright, so pkcheck answers nothing
#     *because root is exempt*, not because the deny rule is off. The
#     probe cannot tell those apart, so it must SKIP with the reason
#     rather than blame the rule (found by running --check-setup as
#     root, 2026-09-22).
# =====================================================================

# polkit's real answer for root is an empty line and exit 0; the stub can now
# produce it, so the negative assertion below bites.
reset_pass
printf 'authorized\n' >"$PKCHECK_ANSWER_FILE"
out="$(KIDS_TEST_UID=0 KIDS_TEST_ACCOUNT=root KIDS_TEST_GROUPS='' "$BIN" --check-setup 2>&1)"
st=$?
check_eq "$st" 1 "as root: exits 1 (root has no Kids Mode profile)"
check_contains "$out" "not a Kids Mode kid" "as root: says root is not a kid"
check_contains "$(printf '%s' "$out" | tr -s ' ')" "polkit rules present SKIP" \
  "as root: the polkit probe is SKIP, not a verdict about the rule"
check_contains "$out" "which polkit authorizes outright" "as root: the SKIP says why"
if grep -qE "polkit rules present +FAIL|FAIL +polkit rules present" <<<"$out"; then
  fail "as root: gives the polkit row a FAIL verdict about this account"
else
  pass "as root: the polkit row is not a verdict about this account"
fi

# A profiled kid still runs the probe even if their groups have drifted: that
# drift is exactly what this check catches, so it must FAIL, not SKIP.
reset_pass
break_polkit
out="$(KIDS_TEST_GROUPS=wheel "$BIN" 2>&1)"
st=$?
check_eq "$st" 1 "profiled kid without the group: the preflight still fails"
check_contains "$out" "FAIL polkit rules present" \
  "profiled kid without the group: the probe still gives a verdict"
check_contains "$out" "the deny rule does not bind this account" \
  "profiled kid without the group: the verdict names what it checked"
[[ -e "$HYPRLAND_LOG" ]] && fail "profiled kid without the group: must not start Hyprland" ||
  pass "profiled kid without the group: did not start Hyprland"

# Another account the rule does not bind (the parent's own) gets the default
# policy's "requires authentication", which says just as little about a kid.
reset_pass
break_polkit
out="$(KIDS_TEST_ACCOUNT=parent KIDS_TEST_GROUPS=wheel "$BIN" --check-setup 2>&1)"
st=$?
check_eq "$st" 1 "as another account: exits 1 (it has no Kids Mode profile)"
check_contains "$(printf '%s' "$out" | tr -s ' ')" "polkit rules present SKIP" \
  "as another account: the polkit probe is SKIP too"
check_contains "$out" "'parent' has no Kids Mode profile" "as another account: the SKIP says why"
if grep -qE "polkit rules present +FAIL|FAIL +polkit rules present" <<<"$out"; then
  fail "as another account: gives the polkit row a FAIL verdict about it"
else
  pass "as another account: the polkit row is not a verdict about it"
fi

for break_fn in break_policy break_polkit break_home break_getty break_level_conf; do
  reset_pass
  "$break_fn"
  out="$("$BIN" --check-setup 2>&1)"
  check_eq "$?" 1 "--check-setup still fails $break_fn"
done
reset_pass
rm -f "$PROFILE"
out="$("$BIN" --check-setup 2>&1)"
check_eq "$?" 1 "--check-setup still fails a missing profile"

# Combining the report flag with other modes must never select startup.
reset_pass
for other in --check --manifest --install-configs --help --start; do
  "$BIN" --check-setup "$other" >/dev/null 2>&1 || true
  "$BIN" "$other" --check-setup >/dev/null 2>&1 || true
done
[[ -e "$HYPRLAND_LOG" ]] && fail "mixed setup-report flags must never start Hyprland" || pass "mixed setup-report flags did not start Hyprland"

# =====================================================================
# 7. --install-configs copies *.lua from share/hyprland to
#    etc/hyprland, mode 0644.
# =====================================================================

INSTALL_SHARE="$TMP/install-share"
INSTALL_ETC="$TMP/install-etc"
mkdir -p "$INSTALL_SHARE/hyprland"
printf -- '-- L1\n' >"$INSTALL_SHARE/hyprland/L1.lua"
printf -- '-- L2\n' >"$INSTALL_SHARE/hyprland/L2.lua"
printf -- '-- L3\n' >"$INSTALL_SHARE/hyprland/L3.lua"
printf 'not a lua file\n' >"$INSTALL_SHARE/hyprland/README"

kids_set_const "$BIN" ETC "$INSTALL_ETC"
kids_set_const "$BIN" SHARE "$INSTALL_SHARE"
out="$("$BIN" --install-configs 2>&1)"
st=$?
check_eq "$st" 0 "--install-configs: exits 0"
for n in L1 L2 L3; do
  f="$INSTALL_ETC/hyprland/$n.lua"
  if [[ -f "$f" ]]; then
    check_eq "$(cat "$f")" "-- $n" "--install-configs: $n.lua copied with matching content"
    mode="$(kids_file_mode "$f")"
    check_eq "$mode" "644" "--install-configs: $n.lua is mode 0644"
  else
    fail "--install-configs: $n.lua was not installed"
  fi
done
[[ -e "$INSTALL_ETC/hyprland/README" ]] && fail "--install-configs: must only copy *.lua files" ||
  pass "--install-configs: non-.lua files left alone"

# =====================================================================
# 8. --manifest exposes only the caller's current, root-owned manifest
#    (R-MANIFEST-4), with no kid/path argument.
# =====================================================================

MANIFEST_ETC="$TMP/manifest-etc"
MANIFEST_SHARE="$TMP/manifest-share"
MANIFEST_SYSROOT="$TMP/manifest-sysroot"
MANIFEST_DIR="$MANIFEST_ETC/sessions"
MANIFEST="$MANIFEST_DIR/$ACCOUNT.json"
MANIFEST_PROFILE="$MANIFEST_ETC/kids/$ACCOUNT.conf"
mkdir -p "$MANIFEST_DIR" "$MANIFEST_ETC/kids" "$MANIFEST_SHARE/avatars" \
  "$MANIFEST_SYSROOT"
cp "$ROOT_DIR/share/avatars/fox.svg" "$MANIFEST_SHARE/avatars/fox.svg"

cat >"$MANIFEST_PROFILE" <<'EOF'
name=Display Name
avatar=fox
band=6-8
level=1
web=none
theme=tokyo-night
EOF

kids_stub "$TMP/tree" omarchy-kids-conf <<'EOF'
#!/bin/bash
[[ "${1:-}" == get && "${2:-}" == kid-ada ]] || exit 1
case "${3:-}" in
  name) echo "Display Name" ;;
  avatar) echo fox ;;
  band) echo 6-8 ;;
  level) echo 1 ;;
  web) echo none ;;
  theme) echo tokyo-night ;;
  budget_min | budget_min_weekend) echo 60 ;;
  lights_out) echo 19:30 ;;
  lights_out_weekend) echo 20:00 ;;
  *) exit 1 ;;
esac
EOF
kids_stub "$TMP/tree" omarchy-kids-apps <<'EOF'
#!/bin/bash
[[ "${1:-}" == allowlist && "${2:-}" == kid-ada ]] && exit 0
exit 1
EOF

kids_set_const "$BIN" ETC "$MANIFEST_ETC"
kids_set_const "$BIN" SHARE "$MANIFEST_SHARE"
kids_set_const "$BIN" SYSROOT "$MANIFEST_SYSROOT"
kids_set_const "$BIN" RUNTIME_DIR "$RUN"
kids_set_const "$BIN" RUN_DIR "$RUN"

# The Mac user is not root, so this test stub supplies root metadata only for
# the manifest path; all other stat calls use the host's real stat.
REAL_STAT="$(type -P stat)"
cat >"$STUBS/stat" <<'EOF'
#!/bin/bash
# GNU stat is `-c %a/%u/%G`, BSD stat is `-f %Lp/%u/%Sg`; lib/kids.sh's file_stat tries GNU first.
if [[ "${KIDS_TEST_MANIFEST_STAT:-}" == 1 && "${3:-}" == */sessions/* ]]; then
  case "${2:-}" in
    %Lp | %a) echo "${KIDS_TEST_MANIFEST_MODE:-644}"; exit 0 ;;
    %u) [[ "${KIDS_TEST_MANIFEST_OWNER:-root}" == root ]] && echo 0 || echo 501; exit 0 ;;
    %Sg | %G) echo root; exit 0 ;;
  esac
fi
exec "$KIDS_TEST_REAL_STAT" "$@"
EOF
chmod +x "$STUBS/stat"
export KIDS_TEST_REAL_STAT="$REAL_STAT"

jq -n --arg account "$ACCOUNT" --arg band "$BAND" '{
  schema_version: 1,
  account: $account,
  name: "Display Name",
  avatar: "fox",
  band: $band,
  level: 1,
  theme: "tokyo-night",
  allowlist: [],
  web: "none",
  policy_id: "omarchy-kids-6-8",
  budget_min: 60,
  budget_min_weekend: 60,
  lights_out: "19:30",
  lights_out_weekend: "20:00",
  tiles: [{
    id: "more-apps",
    label: "More apps",
    icon: "",
    installed: true,
    argv: ["/usr/bin/env", ("OMARCHY_KIDS_BAND=" + $band), "/usr/bin/quickshell", "-p", "/usr/share/omarchy-kids/plugins/shell.qml"]
  }]
}' >"$MANIFEST"
cp "$MANIFEST" "$TMP/valid-manifest.json"

manifest_run() {
  out="$(KIDS_TEST_MANIFEST_STAT=1 "$BIN" --manifest 2>"$TMP/manifest.err")"
  st=$?
}
manifest_refused() {
  local label="$1"
  manifest_run
  check_eq "$st" 1 "$label: exits 1"
  check_eq "$out" "" "$label: prints no stdout"
  check_eq "$(wc -l <"$TMP/manifest.err" | tr -d ' ')" "1" "$label: prints one stderr line"
  check_contains "$(cat "$TMP/manifest.err")" "validated manifest unavailable" "$label: says manifest is unavailable"
}
manifest_restore() {
  rm -rf "$MANIFEST"
  cp "$TMP/valid-manifest.json" "$MANIFEST"
}

manifest_restore
manifest_run
check_eq "$st" 0 "--manifest: valid manifest exits 0"
check_eq "$out" "$(cat "$MANIFEST")" "--manifest: prints the validated JSON"

rm -f "$MANIFEST"
manifest_refused "--manifest: missing manifest"
manifest_restore

rm -f "$MANIFEST"
ln -s "$TMP/valid-manifest.json" "$MANIFEST"
manifest_refused "--manifest: symlink manifest"
manifest_restore

rm -f "$MANIFEST"
mkdir "$MANIFEST"
manifest_refused "--manifest: non-regular manifest"
rm -rf "$MANIFEST"
manifest_restore

KIDS_TEST_MANIFEST_MODE=600 manifest_refused "--manifest: wrong mode"
unset KIDS_TEST_MANIFEST_MODE

KIDS_TEST_MANIFEST_OWNER=other manifest_refused "--manifest: wrong owner"
unset KIDS_TEST_MANIFEST_OWNER

printf '{' >"$MANIFEST"
manifest_refused "--manifest: malformed JSON"
manifest_restore

jq '.schema_version = 2' "$MANIFEST" >"$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
manifest_refused "--manifest: wrong schema"
manifest_restore

jq '.name = "Stale Display"' "$MANIFEST" >"$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
manifest_refused "--manifest: stale document"
manifest_restore

jq '.account = "kid-other"' "$MANIFEST" >"$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
manifest_refused "--manifest: account mismatch"
manifest_restore

out="$("$BIN" --manifest "$ACCOUNT" 2>"$TMP/manifest.err")"
st=$?
check_eq "$st" 2 "--manifest: rejects a kid argument"
check_eq "$out" "" "--manifest: kid argument prints no stdout"
check_eq "$(wc -l <"$TMP/manifest.err" | tr -d ' ')" "1" "--manifest: kid argument prints one stderr line"

# --- --help / -h -------------------------------------------------------

out="$("$BIN" --help 2>&1)"
st=$?
check_eq "$st" 0 "--help exits 0"
check_contains "$out" "Usage: omarchy-kids-session" "--help prints usage"

echo "session-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
