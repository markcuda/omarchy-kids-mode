#!/bin/bash
# Tests bin/omarchy-kids-provision and lib/posture.sh (SPEC.md R-FND-2..6,
# R-SEC-3..5, R-LOGIN-3, R-DESK-1, R-BOOTMODE-3, R-BOOTMODE-4,
# R-BOOTMODE-11, Appendix B) and issue #10's three
# findings: (a) luks-slots is a full rewrite after every slot change, (b)
# omarchy-provision-user runs when present, else migration markers are
# written, (c) pam_namespace lands on both sddm and systemd-user.
#
# Fully self-contained: every system command that would write outside this
# test's own scratch dir (useradd, usermod, chpasswd, mount, umount,
# systemctl, userdel, cryptsetup, omarchy-provision-user) is a fake on a
# stub PATH that only logs its argv (and, for a couple, fakes just enough
# behavior -- creating a home dir, printing cryptsetup's "Key slot N
# unlocked." line -- for the script under test to react to). Never touches
# the real /etc, /var, or /home (AGENTS.md rule 8).
# shellcheck disable=SC2015 # "A && B || C" below is always used with B, C that can't fail
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP provision-test.sh: python3 not found (needed by omarchy-kids-conf)"
  exit 0
fi

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2')"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want to find '$2')"; fi
}
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
count_occurrences() { # haystack needle -> count
  local needle="$2" n=0 rest="$1"
  while [[ "$rest" == *"$needle"* ]]; do
    n=$((n + 1))
    rest="${rest#*"$needle"}"
  done
  printf '%s' "$n"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- scratch tree ------------------------------------------------------

ETC="$TMP/etc/omarchy-kids"
SHARE="$TMP/share/omarchy-kids"
SCRATCH_ROOT="$TMP/root" # OMARCHY_KIDS_ROOT
mkdir -p "$SCRATCH_ROOT/usr/lib/pam.d"
mkdir -p "$SCRATCH_ROOT/usr/lib/pam.d"
printf 'account include system-login\nsession include system-login\n' >"$SCRATCH_ROOT/usr/lib/pam.d/systemd-user"
HOMEROOT="$TMP/homeroot" # OMARCHY_KIDS_HOME_ROOT
STUBS="$TMP/stubs"
LOG="$TMP/log"
ARGV_LOG="$LOG/argv.log"
TREE="$TMP/tree"

mkdir -p "$ETC/kids" "$SHARE/bands" "$SHARE/packs" "$SHARE/avatars" "$SHARE/policy" "$SHARE/menu" "$SCRATCH_ROOT" "$HOMEROOT" "$STUBS" "$LOG"
cp "$ROOT_DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$ROOT_DIR"/share/packs/*.toml "$SHARE/packs/"
cp "$ROOT_DIR"/share/avatars/*.svg "$SHARE/avatars/"
# issue #44: install_kids_chromium_flags's source file.
cp "$ROOT_DIR/share/policy/chromium-flags.conf" "$SHARE/policy/"
# R-DESK-4: install_kids_menu_trim's source file.
cp "$ROOT_DIR/share/menu/omarchy-kids-trimmed.jsonc" "$SHARE/menu/"
touch "$ARGV_LOG"

kids_tree "$TREE" "$ROOT_DIR"
rm -f "$TREE/lib"
cp -a "$ROOT_DIR/lib" "$TREE/lib"
kids_set_const "$TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$ETC/machine.conf"
BIN="$TREE/bin/omarchy-kids-provision"
CONFBIN="$TREE/bin/omarchy-kids-conf"

# The machine's owner (SPEC.md's "parent"); machine setup writes this
# before any kid is ever provisioned, and slot 0 in luks-slots, both
# preconditions omarchy-kids-provision assumes are already in place.
cat >"$ETC/machine.conf" <<'EOF'
parent=mark
boot=disk
EOF
chmod 0644 "$ETC/machine.conf"
mkdir -p "$HOMEROOT/home/mark"
echo "0=mark:omarchy.desktop" >"$ETC/luks-slots"

# issue #53: the parent's own current theme (posture_parent_home falls
# back to OMARCHY_KIDS_HOME_ROOT-prefixed /home/mark here, same as every
# other "mark" lookup in this file) and a scratch system themes dir
# (OMARCHY_PATH/themes) for theme_apply_for's own file copy.
OMARCHY_PATH="$TMP/omarchy"
mkdir -p "$OMARCHY_PATH/themes/tokyo-night/backgrounds"
echo 'background = "#1a1b26"' >"$OMARCHY_PATH/themes/tokyo-night/colors.toml"
: >"$OMARCHY_PATH/themes/tokyo-night/backgrounds/bg1.png"
mkdir -p "$HOMEROOT/home/mark/.local/state/omarchy/current/theme"
echo 'background = "#1a1b26"' >"$HOMEROOT/home/mark/.local/state/omarchy/current/theme/colors.toml"
echo tokyo-night >"$HOMEROOT/home/mark/.local/state/omarchy/current/theme.name"

# Real SDDM stacks ship with a real auth chain already in them (issue
# #15, R-SEC-2): "add" inserts the parent-unlock pam_exec line right
# before the first non-comment "auth" line, since sddm's own first auth
# line isn't a leading pam_faillock preauth line (lib/posture.sh's
# posture_ensure_parent_unlock_line documents the placement rule in
# full). This is the verbatim /etc/pam.d/sddm from a real Omarchy 4.0.2
# box -- it has no pam_unix.so line of its own at all, which is exactly
# why the anchor is "the first auth line", not "the pam_unix.so line".
# No omarchy-lock-password file is seeded here on purpose: that stack
# legitimately might not exist yet at kid-provisioning time (the lock
# screen hasn't been configured), which "add" must tolerate (a warning,
# not a failure) -- see test/shell.d/parent-unlock-test.sh for that
# stack's own shape (the verbatim real /etc/pam.d/omarchy-lock-password)
# and test/shell.d/assert-test.sh for the break/fix cycle on it.
mkdir -p "$SCRATCH_ROOT/etc/pam.d"
cat >"$SCRATCH_ROOT/etc/pam.d/sddm" <<'EOF'
#%PAM-1.0
auth        include     system-login
-auth       optional    pam_kwallet5.so
account     include     system-login
password    include     system-login
session     optional    pam_keyinit.so          force revoke
session     include     system-login
-session    optional    pam_gnome_keyring.so    auto_start
-session    optional    pam_kwallet5.so         auto_start
EOF

# --- stub PATH -----------------------------------------------------------

# stub NAME EXTRA — writes an executable $STUBS/NAME that appends its own
# argv (space-joined, one line -- none of this suite's arguments carry a
# space, so plain %s stays diffable; %q would escape commas for brace-
# expansion safety and make every assertion below have to know that) to
# $ARGV_LOG, then runs EXTRA (literal shell text; write it single-quoted
# at the call site, using __LOG__ for $LOG, so nothing in it is expanded
# until the stub itself runs), then exits 0.
stub() {
  local name="$1" extra="${2:-}" f="$STUBS/$1"
  cat >"$f" <<'EOF'
#!/bin/bash
{ printf '%s' "__NAME__"; printf ' %s' "$@"; printf '\n'; } >> "__ARGVLOG__"
EOF
  [[ -n "$extra" ]] && printf '%s\n' "$extra" >>"$f"
  echo 'exit 0' >>"$f"
  sed -i.bak -e "s#__NAME__#$name#g" -e "s#__ARGVLOG__#$ARGV_LOG#g" -e "s#__LOG__#$LOG#g" "$f"
  rm -f "$f.bak"
  chmod +x "$f"
}

# shellcheck disable=SC2016 # single-quoted on purpose: expands later, inside the stub script
stub useradd 'acct="${@: -1}"; mkdir -p "$OMARCHY_KIDS_HOME_ROOT/home/$acct"'
stub usermod
stub userdel
stub mount
stub umount
stub systemctl
stub gpasswd
# shellcheck disable=SC2016
stub chpasswd 'cat >> "__LOG__/chpasswd.stdin"'
# shellcheck disable=SC2016
# cryptsetup: luksDump reports the occupied slots (add_luks_slot diffs
# before/after rather than parsing "Key slot N unlocked", review §1.10);
# `open --test-passphrase` fails unless __LOG__/luks-open-ok exists, which
# is the "this password already unlocks the disk" case.
stub cryptsetup '
case "$1" in
    luksDump)
        echo "Keyslots:"
        echo "  0: luks2"
        echo "  1: luks2"
        [[ -e "__LOG__/luks-added" ]] && echo "  3: luks2"
        ;;
    luksAddKey)
        [[ ! -e "__LOG__/luks-add-fail" ]] || exit 1
        : > "__LOG__/luks-added"
        ;;
    luksKillSlot)
        [[ ! -e "__LOG__/luks-kill-fail" ]] || exit 1
        slot="${@: -1}"
        [[ ! -e "__LOG__/require-luks-intent" ]] ||
            grep -q "^$slot=" "$OMARCHY_KIDS_ETC"/luks-slots.removing-* || {
                : > "__LOG__/luks-intent-missing-at-kill"
                exit 1
            }
        [[ -e "__LOG__/luks-added" ]] || exit 1
        rm -f "__LOG__/luks-added"
        ;;
    open) [[ -e "__LOG__/luks-open-ok" ]] || exit 1 ;;
esac
'
stub lsblk 'echo "fake0 crypto_LUKS"'
stub flock
stub omarchy-provision-user
stub groupadd
stub runuser

# The fixed-path boot reader requires root ownership. This fixture owns the
# scratch files, so only the ownership fields are substituted.
REAL_STAT="$(command -v stat)"
REAL_CHMOD="$(command -v chmod)"
cat >"$STUBS/stat" <<EOF
#!/bin/bash
if [[ "\${1:-}" == --version ]]; then exec "$REAL_STAT" "\$@"; fi
format="\${2:-}"
target="\${3:-}"
if [[ "\$target" == "$ETC" || "\$target" == "$ETC/machine.conf" ]]; then
  case "\$format" in
    %u) echo 0 ;;
    %G | %Sg) echo root ;;
    *) exec "$REAL_STAT" "\$@" ;;
  esac
  exit 0
fi
exec "$REAL_STAT" "\$@"
EOF
chmod +x "$STUBS/stat"
cat >"$STUBS/chmod" <<EOF
#!/bin/bash
target="\${@: -1}"
if [[ -e "$LOG/luks-map-write-fail" && "\$target" == */.luks-slots.* && "\$target" != */.luks-slots.removing-*.* ]]; then exit 1; fi
exec "$REAL_CHMOD" "\$@"
EOF
chmod +x "$STUBS/chmod"

# Only the stubs and a base toolset: an Omarchy box has the real
# omarchy-*/omarchy-kids-* commands on PATH, and a check that one is
# missing must not depend on this box (AGENTS.md, testing rules).
BASE_PATH="$(kids_base_path "$TMP/base")"
export PATH="$STUBS:$BASE_PATH"
export OMARCHY_KIDS_ETC="$ETC"
export OMARCHY_KIDS_SHARE="$SHARE"
export OMARCHY_KIDS_ROOT="$SCRATCH_ROOT"
export OMARCHY_KIDS_HOME_ROOT="$HOMEROOT"
export OMARCHY_PATH
export DRY_RUN=0

SLUG="$("$CONFBIN" slug "Ada Lovelace")"

# --- add: refuses --no-password outside 3-5 -------------------------------

out="$("$BIN" add "Nope" --band 6-8 --no-password 2>&1)"
st=$?
check_eq "$st" 2 "add --no-password outside 3-5 exits 2"
check_contains "$out" "only allowed for band 3-5" "add --no-password outside 3-5 names the reason"
[[ -e "$ETC/kids/kid-nope.conf" ]] && fail "add --no-password outside 3-5 must not create a profile" ||
  pass "add --no-password outside 3-5 created no profile"

# --- add: needs --password-stdin or --no-password -------------------------

out="$("$BIN" add "Nothing" --band 6-8 2>&1)"
st=$?
check_eq "$st" 2 "add with neither password option exits 2"

# --- add: default DRY_RUN=1 writes nothing --------------------------------

: >"$ARGV_LOG"
out="$(printf 'somepassword\nparentpass1\n' | DRY_RUN=1 "$BIN" add "Dry Kid" --band 6-8 --avatar fox \
  --password-stdin --parent-password-stdin --luks-device /dev/fake0 2>&1)"
check_contains "$out" "[dry-run]" "default DRY_RUN=1 prints dry-run lines"
[[ -e "$ETC/kids/kid-drykid.conf" ]] && fail "DRY_RUN=1 must not write a profile" || pass "DRY_RUN=1 wrote no profile"
[[ -s "$ARGV_LOG" ]] && fail "DRY_RUN=1 must not invoke useradd/chpasswd/etc" || pass "DRY_RUN=1 invoked no real commands"

# --- boot mode gates every add/remove before mutation ---------------------

printf 'parent=mark\nboot=portal\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"
: >"$ARGV_LOG"
out_empty_env="$(printf 'kidpass1\n' | env -i PATH="$PATH" DRY_RUN=1 \
  OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" OMARCHY_KIDS_ROOT="$SCRATCH_ROOT" \
  OMARCHY_KIDS_HOME_ROOT="$HOMEROOT" OMARCHY_PATH="$OMARCHY_PATH" \
  "$BIN" add "Cy" --band 6-8 --avatar fox --password-stdin 2>&1)"
st=$?
check_eq "$st" 0 "portal add works with an empty environment and no HOME"
check_contains "$out_empty_env" "[dry-run]" "empty-environment add remains a preview"
for option in "--luks-device /dev/fake0" "--parent-password-stdin"; do
  : >"$ARGV_LOG"
  # shellcheck disable=SC2086 # the two fixed option shapes are intentional
  out_portal_reject="$(printf 'kidpass1\nparentpass1\n' | "$BIN" add "Dot" --band 6-8 --password-stdin $option 2>&1)"
  st=$?
  check_eq "$st" 2 "portal add rejects disk-only option: $option"
  check_contains "$out_portal_reject" "not available in portal mode" "portal add names why $option is rejected"
  [[ -e "$ETC/kids/kid-dot.conf" ]] && fail "portal rejection must not create kid-dot" ||
    pass "portal rejection for $option mutates no profile"
  check_eq "$(cat "$ARGV_LOG")" "" "portal rejection for $option invokes no system command"
done

: >"$ARGV_LOG"
out_portal_reject="$(printf 'kidpass1\n' | "$BIN" add "Dot" --band 6-8 --password-stdin \
  --parent-password-fd 9 9<<<'parentpass1' 2>&1)"
st=$?
check_eq "$st" 2 "portal add rejects disk-only option: --parent-password-fd"
check_contains "$out_portal_reject" "not available in portal mode" "portal add names why --parent-password-fd is rejected"
[[ -e "$ETC/kids/kid-dot.conf" ]] && fail "portal fd rejection must not create kid-dot" ||
  pass "portal fd rejection mutates no profile"
check_eq "$(cat "$ARGV_LOG")" "" "portal fd rejection invokes no system command"

: >"$ARGV_LOG"
out_portal="$(printf 'kidpass1\n' | "$BIN" add "Cy" --band 6-8 --avatar fox --password-stdin 2>&1)"
st=$?
check_eq "$st" 0 "portal add succeeds without a disk secret"
check_contains "$out_portal" "Done: kid-cy" "portal add reports completion"
if [[ -f "$HOMEROOT/home/kid-cy/.config/omarchy/extensions/omarchy-menu.jsonc" ]] &&
  grep -q '"when": "false"' "$HOMEROOT/home/kid-cy/.config/omarchy/extensions/omarchy-menu.jsonc"; then
  pass "portal add seeds the trimmed omarchy-menu extension for kid-cy"
else
  fail "portal add must seed the trimmed omarchy-menu extension for kid-cy"
fi
check_not_contains "$(cat "$ARGV_LOG")" "cryptsetup" "portal add makes no LUKS call"
[[ -e "$ETC/kids/kid-cy.conf" ]] && pass "portal add creates the kid profile" || fail "portal add did not create kid-cy"

: >"$ARGV_LOG"
out_portal_remove_reject="$("$BIN" remove kid-cy --luks-device /dev/fake0 2>&1)"
st=$?
check_eq "$st" 2 "portal per-kid remove rejects --luks-device"
check_contains "$out_portal_remove_reject" "not available in portal mode" "portal per-kid remove names why --luks-device is rejected"
[[ -e "$ETC/kids/kid-cy.conf" ]] && pass "portal per-kid rejection leaves the profile" ||
  fail "portal per-kid rejection removed the profile"
check_eq "$(cat "$ARGV_LOG")" "" "portal per-kid rejection invokes no system command"

: >"$ARGV_LOG"
printf '0=mark:omarchy.desktop\n7=kid-cy\n' >"$ETC/luks-slots"
out_portal_mapped="$("$BIN" remove kid-cy 2>&1)"
st=$?
check_eq "$st" 1 "portal per-kid remove refuses a recorded LUKS slot"
check_contains "$out_portal_mapped" "cannot verify recorded LUKS slot 7" "portal per-kid remove names the active-slot risk"
[[ -e "$ETC/kids/kid-cy.conf" ]] && pass "portal mapped-slot refusal leaves the profile" ||
  fail "portal mapped-slot refusal removed the profile"
check_not_contains "$(cat "$ARGV_LOG")" "userdel" "portal mapped-slot refusal stops before account deletion"

: >"$ARGV_LOG"
printf '0=mark:omarchy.desktop\n' >"$ETC/luks-slots"
"$BIN" remove kid-cy >/dev/null 2>&1
st=$?
check_eq "$st" 0 "portal per-kid remove succeeds once no kid slot is recorded"
check_not_contains "$(cat "$ARGV_LOG")" "cryptsetup" "portal per-kid remove makes no LUKS call"

printf 'parent=mark\nboot=invalid\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"
: >"$ARGV_LOG"
out_invalid="$("$BIN" add "Dot" --band 3-5 --no-password 2>&1)"
st=$?
check_eq "$st" 1 "invalid mode blocks add"
check_contains "$out_invalid" "invalid or missing boot mode" "invalid-mode add names the trusted setting"
[[ -e "$ETC/kids/kid-dot.conf" ]] && fail "invalid mode must not create kid-dot" || pass "invalid mode add mutates no profile"
check_eq "$(cat "$ARGV_LOG")" "" "invalid mode add invokes no system command"

cat >"$ETC/kids/kid-test.conf" <<'EOF'
name=Test
band=6-8
password=set
EOF
: >"$ARGV_LOG"
out_invalid="$("$BIN" remove kid-test 2>&1)"
st=$?
check_eq "$st" 1 "invalid mode blocks per-kid remove"
check_contains "$out_invalid" "invalid or missing boot mode" "invalid-mode remove names the trusted setting"
[[ -e "$ETC/kids/kid-test.conf" ]] && pass "invalid mode remove leaves the profile" || fail "invalid mode removed kid-test"
check_eq "$(cat "$ARGV_LOG")" "" "invalid mode remove invokes no system command"
rm -f "$ETC/kids/kid-test.conf"

printf 'parent=mark\nboot=disk\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"

# --- add: a failed LUKS add mutates no account or profile -----------------

: >"$ARGV_LOG"
touch "$LOG/luks-add-fail"
out_add_fail="$(printf 'kidpass1\nwrongparent\n' | "$BIN" add "Dot" --band 6-8 --avatar fox \
  --password-stdin --parent-password-stdin --luks-device /dev/fake0 2>&1)"
st=$?
rm -f "$LOG/luks-add-fail"
check_eq "$st" 2 "failed luksAddKey fails provisioning"
check_contains "$out_add_fail" "luksAddKey failed" "failed LUKS add names the failing operation"
check_not_contains "$(cat "$ARGV_LOG")" "useradd" "failed LUKS add happens before account creation"
[[ -e "$ETC/kids/kid-dot.conf" ]] && fail "failed LUKS add must not create a profile" ||
  pass "failed LUKS add creates no profile"
check_eq "$(cat "$ETC/luks-slots")" "0=mark:omarchy.desktop" "failed LUKS add leaves the slot map unchanged"

# --- add: kid-ada, band 6-8, password + LUKS slot -------------------------

: >"$ARGV_LOG"
out="$(printf 'kidpass1\nparentpass1\n' | "$BIN" add "Ada Lovelace" --band 6-8 --avatar fox \
  --password-stdin --parent-password-stdin --luks-device /dev/fake0 2>&1)"
st=$?
argv="$(cat "$ARGV_LOG")"

check_eq "$st" 0 "add kid-ada exits 0"
check_contains "$out" "Adding kid 'Ada Lovelace' as $SLUG" "add kid-ada announces the account name"

check_contains "$argv" "useradd -m -s /bin/bash -G omarchy-kids,omarchy-kids-6-8 $SLUG" "add: useradd argv is exact"
check_contains "$argv" "chpasswd" "add: chpasswd was invoked"
check_contains "$(cat "$LOG/chpasswd.stdin")" "$SLUG:kidpass1" "add: chpasswd got 'account:password' on stdin, never argv"
check_not_contains "$argv" "kidpass1" "add: the kid password never appears in any command's argv"
check_not_contains "$argv" "parentpass1" "add: the parent password never appears in any command's argv"

check_eq "$(grep -c '^name=Ada Lovelace$' "$ETC/kids/$SLUG.conf")" "1" "profile: name=Ada Lovelace"
check_eq "$(grep -c '^avatar=fox$' "$ETC/kids/$SLUG.conf")" "1" "profile: avatar=fox"
check_eq "$(grep -c '^band=6-8$' "$ETC/kids/$SLUG.conf")" "1" "profile: band=6-8"
check_eq "$(grep -c '^password=set$' "$ETC/kids/$SLUG.conf")" "1" "profile: password=set"
check_eq "$(grep -c '^onboarded=no$' "$ETC/kids/$SLUG.conf")" "1" "profile: onboarded=no"

MANIFEST="$ETC/sessions/$SLUG.json"
[[ -f "$MANIFEST" ]] && pass "add: built the session manifest" || fail "add: did not build the session manifest"
check_eq "$(jq -r '.account' "$MANIFEST")" "$SLUG" "manifest: account matches the added kid"
check_eq "$(jq -r '.schema_version' "$MANIFEST")" "1" "manifest: schema version is 1 after add"

FSTAB="$SCRATCH_ROOT/etc/fstab"
check_eq "$(grep -c "^/home/$SLUG /home/$SLUG none bind,nosuid,nodev,noexec 0 0\$" "$FSTAB")" "1" \
  "fstab: exact bind-mount line for $SLUG"
check_contains "$argv" "mount -o remount,bind,nosuid,nodev,noexec $HOMEROOT/home/$SLUG" \
  "add: remount happened with the right options"

ADMIN_RULE="$SCRATCH_ROOT/etc/polkit-1/rules.d/40-omarchy-kids.rules"
DENY_RULE="$SCRATCH_ROOT/etc/polkit-1/rules.d/41-omarchy-kids-deny.rules"
check_contains "$(cat "$ADMIN_RULE" 2>/dev/null)" '["unix-user:mark"]' "polkit admin rule names the parent, not root"
check_contains "$(cat "$DENY_RULE" 2>/dev/null)" "polkit.Result.NO" "polkit deny rule denies"
check_contains "$(cat "$DENY_RULE" 2>/dev/null)" "org.freedesktop.systemd1.manage-units" "polkit deny rule covers systemd manage-units"
check_contains "$(cat "$DENY_RULE" 2>/dev/null)" "org.omarchy." "polkit deny rule covers org.omarchy.*"

for n in 2 3 4 5 6; do
  check_contains "$argv" "systemctl --root=$SCRATCH_ROOT mask getty@tty$n.service" "add masks getty@tty$n"
done

NSCONF="$SCRATCH_ROOT/etc/security/namespace.conf"
check_eq "$(grep -c "^/tmp /tmp/kids-inst/ tmpfs:mntopts=nosuid,nodev,noexec ~$SLUG\$" "$NSCONF")" "1" \
  "namespace.conf: exact /tmp line for $SLUG"
check_eq "$(grep -c "^/dev/shm /dev/shm/kids-inst/ tmpfs:mntopts=nosuid,nodev,noexec ~$SLUG\$" "$NSCONF")" "1" \
  "namespace.conf: exact /dev/shm line for $SLUG"

for stack in sddm systemd-user; do
  PAMFILE="$SCRATCH_ROOT/etc/pam.d/$stack"
  check_eq "$(grep -c '^session required pam_namespace.so$' "$PAMFILE" 2>/dev/null)" "1" \
    "pam.d/$stack has exactly one pam_namespace.so line"
  [[ $stack == systemd-user ]] && check_eq "$(grep -c 'include system-login' "$PAMFILE")" "2" "pam.d/systemd-user was seeded from the vendor file"
done

# --- add: R-SEC-2 parent-unlock line inserted into pam.d/sddm ------------
#
# sddm's real first "auth" line isn't a leading pam_faillock preauth
# line, so lib/posture.sh's placement rule inserts right BEFORE it --
# ahead of the whole "include system-login" chain -- rather than after
# it (see lib/posture.sh's own comment on why the rule is anchor-based,
# not pam_unix.so-based: this real fixture has no pam_unix.so line at
# all to jump around).
SDDM_PAMFILE="$SCRATCH_ROOT/etc/pam.d/sddm"
MARKER="# omarchy-kids: parent-unlock verifier (R-SEC-2, R-SEC-3)"
PAM_EXEC_LINE="pam_exec.so quiet expose_authtok /usr/bin/omarchy-kids-parent-auth"
check_eq "$(grep -c "^$MARKER\$" "$SDDM_PAMFILE")" "1" "pam.d/sddm: parent-unlock marker inserted exactly once"
check_eq "$(grep -c "^auth       \[success=done default=ignore\]  $PAM_EXEC_LINE\$" "$SDDM_PAMFILE")" "1" \
  "pam.d/sddm: parent-unlock line uses the fixed success=done control"
expected_sddm=$'#%PAM-1.0\n'"$MARKER"$'\nauth       [success=done default=ignore]  '"$PAM_EXEC_LINE"$'\nauth        include     system-login\n-auth       optional    pam_kwallet5.so\naccount     include     system-login\npassword    include     system-login\nsession     optional    pam_keyinit.so          force revoke\nsession     include     system-login\n-session    optional    pam_gnome_keyring.so    auto_start\n-session    optional    pam_kwallet5.so         auto_start\n# omarchy-kids: pam_namespace for kid sessions (R-FND-2a)\nsession required pam_namespace.so'
check_eq "$(cat "$SDDM_PAMFILE")" "$expected_sddm" "pam.d/sddm: exact resulting file content after add"
check_contains "$out" "warning: could not add the parent-unlock line to pam.d/omarchy-lock-password" \
  "add: warns (does not fail) when the lock-screen PAM stack doesn't exist yet"

check_contains "$argv" "cryptsetup luksAddKey --batch-mode --key-file=" "add: cryptsetup luksAddKey called"
check_contains "$argv" "/dev/fake0" "add: cryptsetup ran against the given --luks-device"
check_contains "$argv" "cryptsetup luksDump /dev/fake0" "add: the new slot is found by diffing luksDump, not by --test-passphrase"
check_contains "$argv" "cryptsetup open --test-passphrase" "add: the kid password is tested against the disk before it is added"
check_contains "$out" "LUKS slot 3 added for $SLUG" "add: the discovered slot (3) is reported"
luks_add_line="$(awk '/cryptsetup luksAddKey/{print NR; exit}' "$ARGV_LOG")"
useradd_line="$(awk '/useradd /{print NR; exit}' "$ARGV_LOG")"
if [[ -n "$luks_add_line" && -n "$useradd_line" ]] && ((luks_add_line < useradd_line)); then
  pass "add: LUKS succeeds before account creation"
else
  fail "add: LUKS must succeed before account creation"
fi

# Review S6: neither secret may appear anywhere in the command's own output,
# and the dry-run preview shows placeholders instead.
case "$out" in
  *kidpass1*) fail "add: the kid's password appeared in the output" ;;
  *) pass "add: the kid's password never appears in the output" ;;
esac
case "$out" in
  *parentpass1*) fail "add: the parent's LUKS passphrase appeared in the output" ;;
  *) pass "add: the parent's LUKS passphrase never appears in the output" ;;
esac
check_eq "$(grep -c "^3=$SLUG\$" "$ETC/luks-slots")" "1" "luks-slots: slot 3 mapped to $SLUG"
check_eq "$(grep -c '^0=mark:omarchy.desktop$' "$ETC/luks-slots")" "1" "luks-slots: the parent's slot 0 line survives the rewrite"

ASFILE="$SCRATCH_ROOT/var/lib/AccountsService/users/$SLUG"
check_contains "$(cat "$ASFILE" 2>/dev/null)" "Session=omarchy-kids" "AccountsService pins the kid session"
check_contains "$(cat "$ASFILE" 2>/dev/null)" "Icon=/usr/share/omarchy-kids/avatars/fox.svg" "AccountsService icon path"

THEME_DROPIN="$SCRATCH_ROOT/etc/sddm.conf.d/zz-omarchy-kids-theme.conf"
check_contains "$(cat "$THEME_DROPIN" 2>/dev/null)" "Current=omarchy-kids" "add: SDDM portal theme selected (R-LOGIN)"

# --- add: issue #39 -- GECOS display name, the face icon, theme.conf.user --

check_contains "$argv" "usermod -c Ada Lovelace $SLUG" "add: GECOS set via usermod -c with the display name"

FACE_ICON="$SCRATCH_ROOT/usr/share/sddm/faces/$SLUG.face.icon"
if [[ -f "$FACE_ICON" ]] && cmp -s "$SHARE/avatars/fox.svg" "$FACE_ICON"; then
  pass "add: the SDDM face icon is written, matching the fox avatar"
else
  fail "add: the SDDM face icon was not written at $FACE_ICON"
fi

PORTAL_CONF="$SCRATCH_ROOT/usr/share/sddm/themes/omarchy-kids/theme.conf.user"
check_contains "$(cat "$PORTAL_CONF" 2>/dev/null)" "parent=mark" "theme.conf.user: parent is the machine owner"
check_contains "$(cat "$PORTAL_CONF" 2>/dev/null)" "kids=\"$SLUG:Ada Lovelace:fox\"" "theme.conf.user: $SLUG's name and avatar"

check_contains "$argv" "mount --bind $OMARCHY_KIDS_HOME_ROOT/home/$SLUG $OMARCHY_KIDS_HOME_ROOT/home/$SLUG" "add: bind mount created before the noexec remount"
check_contains "$argv" "runuser -l $SLUG -c omarchy-provision-user --first-install" "add: omarchy-provision-user --first-install runs as the kid via runuser"
check_contains "$argv" "groupadd -f omarchy-kids" "add: groups are created defensively"

# --- issue #44: the kid's own chromium-flags.conf is overridden -----------
# Whatever ~/.config/chromium-flags.conf omarchy-provision-user (or its
# fallback) left, "add" writes over it with Kids Mode's own copy so a kid
# running `chromium` from a terminal never hits the "disabled by the
# administrator" modal Omarchy's --load-extension flag produces under
# the kids policy.

FLAGS_FILE="$HOMEROOT/home/$SLUG/.config/chromium-flags.conf"
if [[ -f "$FLAGS_FILE" ]]; then
  pass "add: wrote $SLUG's own chromium-flags.conf"
  flags_content="$(cat "$FLAGS_FILE")"
  check_contains "$flags_content" "--ozone-platform=wayland" "chromium-flags.conf: keeps Omarchy's Wayland flag"
  check_not_contains "$flags_content" "--load-extension" "chromium-flags.conf: strips --load-extension (issue #44)"
  mode="$(kids_file_mode "$FLAGS_FILE")"
  check_eq "$mode" "644" "chromium-flags.conf: mode is 0644"
else
  fail "add: no chromium-flags.conf written for $SLUG"
fi

# --- issue #53: the kid's own theme matches the parent's current one ------

check_eq "$(grep -c "^theme=tokyo-night\$" "$ETC/kids/$SLUG.conf")" "1" "profile: theme=tokyo-night, the parent's own current theme"

KID_THEME_DIR="$HOMEROOT/home/$SLUG/.local/state/omarchy/current/theme"
check_eq "$(cat "$KID_THEME_DIR/colors.toml" 2>/dev/null)" "$(cat "$OMARCHY_PATH/themes/tokyo-night/colors.toml")" \
  "add: theme_apply_for actually copied the parent's theme into $SLUG's own \$HOME"
[[ -f "$KID_THEME_DIR/backgrounds/bg1.png" ]] && pass "add: the whole theme tree was copied, not just colors.toml" ||
  fail "add: backgrounds/ was not copied into $SLUG's theme"
check_eq "$(cat "$HOMEROOT/home/$SLUG/.local/state/omarchy/current/theme.name" 2>/dev/null)" "tokyo-night" \
  "add: theme.name written beside $SLUG's own theme directory"

# --- add: slug collision gets -2 ------------------------------------------

printf 'parent=mark\nboot=portal\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"
: >"$ARGV_LOG"
out2="$(printf 'kidpass2\n' | "$BIN" add "Ada Lovelace" --band 6-8 --avatar bear --password-stdin 2>&1)"
check_contains "$out2" "as $SLUG-2" "second kid with the same name gets the -2 suffix"
[[ -e "$ETC/kids/$SLUG-2.conf" ]] && pass "profile written for $SLUG-2" || fail "no profile for $SLUG-2"

# --- idempotence: polkit/pam edits are not duplicated by a second add -----

check_eq "$(count_occurrences "$(cat "$ADMIN_RULE")" 'polkit.addAdminRule')" "1" \
  "polkit admin rule still has exactly one rule block after a second add"
check_eq "$(grep -c '^session required pam_namespace.so$' "$SCRATCH_ROOT/etc/pam.d/sddm")" "1" \
  "pam.d/sddm still has exactly one pam_namespace.so line after a second add"
check_eq "$(grep -c "^$MARKER\$" "$SCRATCH_ROOT/etc/pam.d/sddm")" "1" \
  "pam.d/sddm still has exactly one parent-unlock marker after a second add"
check_eq "$(grep -c "$SLUG-2\$" "$NSCONF")" "2" "namespace.conf gained exactly 2 lines (not more) for the second kid"
check_eq "$(grep -c "^0=mark:omarchy.desktop\$" "$ETC/luks-slots")" "1" \
  "luks-slots still has exactly one slot-0 line after a second add"

check_eq "$(grep '^kids=' "$PORTAL_CONF" 2>/dev/null)" \
  "kids=\"$SLUG:Ada Lovelace:fox,$SLUG-2:Ada Lovelace:bear\"" \
  "theme.conf.user: the quoted list holds both kids in order"

# --- add: --no-password only for band 3-5 --------------------------------

printf 'parent=mark\nboot=disk\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"
: >"$ARGV_LOG"
"$BIN" add "Sam" --band 3-5 --avatar bear --no-password --luks-device /dev/fake0 >/dev/null 2>&1
st=$?
SLUG_SAM="$("$CONFBIN" slug "Sam")"
check_eq "$st" 0 "add --no-password for band 3-5 succeeds"
check_contains "$(cat "$ARGV_LOG")" "usermod -L $SLUG_SAM" "add --no-password locks the account with usermod -L"
check_not_contains "$(cat "$ARGV_LOG")" "chpasswd" "add --no-password never calls chpasswd"
check_eq "$(grep -c '^password=none$' "$ETC/kids/$SLUG_SAM.conf")" "1" "profile: password=none for a locked account"
check_not_contains "$(cat "$ARGV_LOG")" "luksAddKey" "add --no-password never touches LUKS, even with a device given"

# --- add: password below the band minimum is refused -----------------------

out4="$(printf 'ab\n' | "$BIN" add "Shorty" --band 6-8 --password-stdin 2>&1)"
st=$?
check_eq "$st" 2 "add refuses a password shorter than the band minimum"
check_contains "$out4" "too short" "add: short-password message names the reason"

# --- omarchy-provision-user missing: migration markers are written --------

printf 'parent=mark\nboot=portal\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"
rm -f "$STUBS/omarchy-provision-user"
out5="$(printf 'kidpass3\n' | "$BIN" add "Ben" --band 6-8 --avatar fox --password-stdin 2>&1)"
SLUG_BEN="$("$CONFBIN" slug "Ben")"
MARKER="$HOMEROOT/home/$SLUG_BEN/.local/state/omarchy/migrations.log"
check_not_contains "$out5" "omarchy-provision-user" "add without omarchy-provision-user on PATH doesn't try to run it"
[[ -f "$MARKER" ]] && pass "migration marker file written when omarchy-provision-user is absent" ||
  fail "no migration marker at $MARKER"
stub omarchy-provision-user # restore for the rest of the test

# --- issue #53: parent has no current Omarchy theme yet -> a warning, no
#     override written, no theme directory copied for the new kid --------

mv "$HOMEROOT/home/mark/.local/state/omarchy/current/theme.name" "$TMP/theme.name.bak"
: >"$ARGV_LOG"
out_notheme="$(printf 'kidpass4\n' | "$BIN" add "Nia" --band 6-8 --avatar bear --password-stdin 2>&1)"
SLUG_NIA="$("$CONFBIN" slug "Nia")"
check_contains "$out_notheme" "parent 'mark' has no current Omarchy theme yet" \
  "add: warns (does not fail) when the parent has never picked an Omarchy theme"
check_eq "$(grep -c '^theme=' "$ETC/kids/$SLUG_NIA.conf")" "0" \
  "add: no theme override is written when the parent has no theme to copy"
[[ -e "$HOMEROOT/home/$SLUG_NIA/.local/state/omarchy/current/theme" ]] &&
  fail "add: no theme directory should be created for $SLUG_NIA" ||
  pass "add: $SLUG_NIA's own theme directory was never created"
mv "$TMP/theme.name.bak" "$HOMEROOT/home/mark/.local/state/omarchy/current/theme.name"

printf 'parent=mark\nboot=disk\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"

# --- list ------------------------------------------------------------------

list_out="$("$BIN" list)"
check_contains "$list_out" "$SLUG" "list shows $SLUG"
check_contains "$list_out" "$SLUG-2" "list shows $SLUG-2"

# --- --help / no args --------------------------------------------------

"$BIN" --help >/dev/null 2>&1
check_eq "$?" 0 "--help exits 0"
"$BIN" >/dev/null 2>&1
check_eq "$?" 2 "no arguments exits 2"

# --- remove: reverses kid-ada (has a LUKS slot, home moved) -----------------

: >"$ARGV_LOG"
: >"$LOG/luks-kill-fail"
slots_before="$(cat "$ETC/luks-slots")"
out_remove_fail="$(OMARCHY_KIDS_LUKS_DEVICE=/dev/hostile "$BIN" remove "$SLUG" 2>&1)"
st=$?
rm -f "$LOG/luks-kill-fail"
check_eq "$st" 1 "failed disk slot removal exits 1"
check_contains "$out_remove_fail" "Removing kid $SLUG" "failed disk removal identifies the account"
check_eq "$(cat "$ETC/luks-slots")" "$slots_before" "failed disk slot removal preserves the slot map"
check_contains "$(cat "$ARGV_LOG")" "/dev/fake0 3" "disk removal ignores environment-selected devices"
check_not_contains "$(cat "$ARGV_LOG")" "/dev/hostile" "hostile device environment never reaches cryptsetup"
[[ -e "$ETC/kids/$SLUG.conf" ]] && pass "failed disk slot removal preserves the profile" || fail "failed disk slot removal removed the profile"
check_not_contains "$(cat "$ARGV_LOG")" "userdel" "failed disk slot removal stops before account deletion"
check_not_contains "$(cat "$ARGV_LOG")" "umount" "failed disk slot removal stops before home mutation"

: >"$ARGV_LOG"
touch "$LOG/luks-map-write-fail"
touch "$LOG/require-luks-intent"
out_map_fail="$("$BIN" remove "$SLUG" --luks-device /dev/fake0 2>&1)"
st=$?
rm -f "$LOG/luks-map-write-fail"
check_eq "$st" 1 "slot-map write failure fails per-kid removal"
check_contains "$out_map_fail" "could not update" "slot-map write failure names the preserved map"
check_eq "$(cat "$ETC/luks-slots")" "$slots_before" "slot-map write failure preserves the trusted map"
check_eq "$(cat "$ETC/luks-slots.removing-$SLUG")" "3=$SLUG" "slot-map write failure leaves a durable removal intent"
[[ -e "$LOG/luks-intent-missing-at-kill" ]] && fail "per-kid remove killed the slot before recording intent" ||
  pass "per-kid remove records intent before killing the slot"
[[ -e "$ETC/kids/$SLUG.conf" ]] && pass "slot-map write failure preserves the profile" ||
  fail "slot-map write failure removed the profile"

: >"$ARGV_LOG"
"$BIN" remove "$SLUG" --luks-device /dev/fake0 >/dev/null 2>&1
st=$?
argv6="$(cat "$ARGV_LOG")"

check_eq "$st" 0 "remove retry after a map-write failure exits 0"
check_not_contains "$argv6" "luksKillSlot" "remove retry does not kill the already-empty slot again"
check_contains "$argv6" "cryptsetup luksDump /dev/fake0" "remove retry verifies the recorded slot is empty"
check_eq "$(grep -c "^3=$SLUG\$" "$ETC/luks-slots")" "0" "luks-slots: $SLUG's slot is gone"
[[ -e "$ETC/luks-slots.removing-$SLUG" ]] && fail "remove retry should clear the durable intent" ||
  pass "remove retry clears the durable intent"
check_eq "$(grep -c '^0=mark:omarchy.desktop$' "$ETC/luks-slots")" "1" "luks-slots: the parent's slot 0 survives remove's rewrite"
check_eq "$(grep -c "$SLUG-2\$" "$ETC/luks-slots")" "0" "luks-slots: never had an entry for $SLUG-2 (no LUKS device was given for it)"

check_eq "$(grep -c "$SLUG\$" "$NSCONF")" "0" "namespace.conf lines for $SLUG are gone (only $SLUG-2's remain)"
[[ -e "$ASFILE" ]] && fail "AccountsService file for $SLUG should be removed" || pass "AccountsService file for $SLUG removed"
check_eq "$(grep -c "^/home/$SLUG /home/$SLUG " "$FSTAB")" "0" "fstab line for $SLUG removed"
check_contains "$argv6" "umount $HOMEROOT/home/$SLUG" "remove: unmounted the home"
[[ -e "$ETC/kids/$SLUG.conf" ]] && fail "profile for $SLUG should be removed" || pass "profile for $SLUG removed"
[[ -e "$MANIFEST" ]] && fail "manifest for $SLUG should be removed" || pass "manifest for $SLUG removed"
check_contains "$argv6" "userdel $SLUG" "remove: userdel called"
[[ -d "$HOMEROOT/home/mark/Kids Mode/Ada Lovelace" ]] && pass "home moved to <parent home>/Kids Mode/<name>" ||
  fail "home was not moved to $HOMEROOT/home/mark/Kids Mode/Ada Lovelace"

check_not_contains "$(cat "$PORTAL_CONF" 2>/dev/null)" "$SLUG:Ada Lovelace" \
  "theme.conf.user: $SLUG's entry is gone after remove"
check_contains "$(cat "$PORTAL_CONF" 2>/dev/null)" "kids=\"$SLUG-2:Ada Lovelace:bear," \
  "theme.conf.user: $SLUG-2's quoted entry survives $SLUG's removal"
rm -f "$LOG/require-luks-intent"

[[ -e "$FACE_ICON" ]] && fail "SDDM face icon for $SLUG should be removed" ||
  pass "SDDM face icon for $SLUG removed"

# --- remove --keep-home: home stays put -------------------------------------

: >"$ARGV_LOG"
"$BIN" remove "$SLUG-2" --keep-home >/dev/null 2>&1
st=$?
check_eq "$st" 0 "remove --keep-home exits 0"
check_contains "$(cat "$ARGV_LOG")" "userdel $SLUG-2" "remove --keep-home still removes the account"
[[ -d "$HOMEROOT/home/$SLUG-2" ]] && pass "remove --keep-home left the home in place" ||
  fail "remove --keep-home should not have moved/removed the home"

# --- remove: unknown account is refused -------------------------------------

out8="$("$BIN" remove kid-nosuchkid 2>&1)"
st=$?
check_eq "$st" 2 "remove of an unknown account exits 2"
check_contains "$out8" "no such kid account" "remove: unknown-account message names the problem"

# --- review S6: the DEFAULT dry run must never print either secret --------
#
# This is the documented preview run from the review: DRY_RUN=1, both
# passwords on stdin. add_luks_slot is deliberately not called through
# `run`, whose `printf ' %q'` preview used to shell-quote both onto stdout.

: >"$ARGV_LOG"
dry="$(printf 'S3cretKidPw\nS3cretParentPw\n' | DRY_RUN=1 "$BIN" add "Dry Luks" --band 6-8 --avatar fox \
  --password-stdin --parent-password-stdin --luks-device /dev/fake0 2>&1)"
check_contains "$dry" "[dry-run]" "dry run: still previews the plan"
check_contains "$dry" "add_luks_slot" "dry run: still names add_luks_slot in the preview"
check_contains "$dry" "<secret>" "dry run: the LUKS passphrases show as <secret> placeholders"
case "$dry" in
  *S3cretKidPw*) fail "dry run leaked the kid's password (review S6)" ;;
  *) pass "dry run never prints the kid's password" ;;
esac
case "$dry" in
  *S3cretParentPw*) fail "dry run leaked the parent's LUKS passphrase (review S6)" ;;
  *) pass "dry run never prints the parent's LUKS passphrase" ;;
esac
# The same, on every dry-run line at once: no `printf ' %q'` preview
# anywhere in this run may contain either password.
if printf '%s\n' "$dry" | grep -F "[dry-run]" | grep -qE 'S3cretKidPw|S3cretParentPw'; then
  fail "a [dry-run] preview line contained one of the passwords"
else
  pass "no [dry-run] preview line contains either password"
fi

# --- review §1.10: a kid password that already unlocks the disk ------------

: >"$ARGV_LOG"
: >"$LOG/luks-open-ok" # cryptsetup open --test-passphrase now succeeds
out9="$(printf 'sameaspar3nt\nsameaspar3nt\n' | "$BIN" add "Same Pass" --band 6-8 --avatar fox \
  --password-stdin --parent-password-stdin --luks-device /dev/fake0 2>&1)"
st=$?
rm -f "$LOG/luks-open-ok"
check_eq "$st" 2 "add: a kid password that already unlocks the disk is refused"
check_contains "$out9" "already unlocks" "add: the refusal names the reason"
if grep -q "luksAddKey" "$ARGV_LOG"; then
  fail "add: luksAddKey must not run for a password that already unlocks the disk"
else
  pass "add: luksAddKey never ran for a password that already unlocks the disk"
fi

# --- review S10: encoded portal delimiters are valid display-name text ------

for accepted in 'Ada:Lovelace' 'Ada,Lovelace' $'Ada\rLovelace' \
  $'Ada%2C, Lovelace: "kid" \\ \r'; do
  outb="$(DRY_RUN=1 "$BIN" add "$accepted" --band 3-5 --avatar fox --no-password 2>&1)"
  st=$?
  check_eq "$st" 0 "add: delimiter/control-bearing display-name text is accepted"
  check_not_contains "$outb" "may not contain" "add: accepted display-name text reaches the preview"
  if [[ "$accepted" == *:* ]]; then
    check_contains "$outb" "usermod -c ''" \
      "add: colon-bearing names use an empty passwd GECOS fallback"
  fi
done

for bad in $'Ada\tLovelace' $'Ada\nLovelace'; do
  outb="$(printf 'somepassword\n' | "$BIN" add "$bad" --band 6-8 --avatar fox --password-stdin 2>&1)"
  st=$?
  check_eq "$st" 2 "add: a display name containing a record-line separator is refused"
  check_contains "$outb" "may not contain" "add: the refusal explains which characters are out"
done

echo "provision-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
