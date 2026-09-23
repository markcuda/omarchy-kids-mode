#!/bin/bash
# Tests bin/omarchy-kids-check (SPEC.md R-TRUST-2, R-TRUST-3, R-DESK-2;
# issue #29): a clean, fully-provisioned tree exits 0; a broken lock
# exits 2; a missing face icon (cosmetic-only) is a WARN, not a FAIL,
# and exits 1; --json's shape; --help and an unknown flag; --live
# without root; the firmware-password gate; and that check never calls
# a *_fix (it only ever reads, per its own header comment).
#
# Fixture tree: reuses test/shell.d/assert-test.sh's own scratch-tree
# and stub-PATH setup almost verbatim (same fixture kid, kid-ada, band
# 6-8, per AGENTS.md rule 9) — bin/omarchy-kids-check sources
# bin/omarchy-kids-assert for its lock-check functions, so the same
# fixture that satisfies every assert lock also satisfies every
# lock_check line here. Extended with a few fixtures assert-test.sh
# doesn't need: a readable (empty) sudoers, a luks-slots file plus a
# stub cryptsetup, a Limine config/default pair, a usage ledger
# directory, and machine.conf's firmware.card_done — see "extra
# fixtures for check" below for exactly why each exists.
#
# Fully self-contained per AGENTS.md rule 8: every system command that
# would touch the real machine is a stub on its own PATH; nothing here
# is ever root (the --live section is exercised only as "not root",
# which is what every real run of this suite actually is).
# shellcheck disable=SC2015 # "A && B || C" below is always used with B, C that can't fail
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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
# strip_ansi TEXT — drops the color escapes render_human wraps each
# STATUS word in (e.g. "\033[33mWARN\033[0m"), so a "STATUS  id" string
# match isn't broken by a reset code sitting between the two.
strip_ansi() { printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*m//g'; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- scratch tree (same shape as test/shell.d/assert-test.sh) --------------

ETC="$TMP/etc/omarchy-kids"
SHARE="$TMP/share/omarchy-kids"
SCRATCH_ROOT="$TMP/root" # OMARCHY_KIDS_ROOT
HOMEROOT="$TMP/homeroot" # OMARCHY_KIDS_HOME_ROOT
STUBS="$TMP/stubs"
LOG="$TMP/log"
ARGV_LOG="$LOG/argv.log"
CHECK_TREE="$TMP/check-tree"

kids_tree "$CHECK_TREE" "$ROOT_DIR"
rm -f "$CHECK_TREE/lib"
cp -a "$ROOT_DIR/lib" "$CHECK_TREE/lib"
BIN="$CHECK_TREE/bin/omarchy-kids-check"
kids_set_const "$CHECK_TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$ETC/machine.conf"
kids_set_const "$CHECK_TREE/lib/check-boot.sh" CHECK_BOOT_SLOTS_FILE "$ETC/luks-slots"
kids_set_const "$CHECK_TREE/lib/check-boot.sh" CHECK_BOOT_MKINITCPIO_DROPIN "$SCRATCH_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"
kids_set_const "$CHECK_TREE/lib/check-boot.sh" CHECK_BOOT_SDDM_DROPIN "$SCRATCH_ROOT/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf"

mkdir -p "$ETC/kids" "$SHARE/hyprland" "$SHARE/avatars" "$SCRATCH_ROOT/usr/lib/pam.d" "$HOMEROOT" "$STUBS" "$LOG/groups" "$LOG/gecos"
printf 'account include system-login\nsession include system-login\n' >"$SCRATCH_ROOT/usr/lib/pam.d/systemd-user"
touch "$ARGV_LOG"

cat >"$ETC/machine.conf" <<'EOF'
parent=mark
boot=disk
firmware.card_done=yes
EOF
chmod 0644 "$ETC/machine.conf"

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada Lovelace
avatar=fox
band=6-8
password=set
onboarded=no
EOF

cp "$ROOT_DIR"/share/hyprland/*.lua "$SHARE/hyprland/"
cp "$ROOT_DIR"/share/avatars/*.svg "$SHARE/avatars/"

# stub NAME EXTRA — see test/shell.d/provision-test.sh for the full
# rationale; same helper assert-test.sh already copies verbatim.
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

# shellcheck disable=SC2016
stub findmnt '
target="${@: -1}"; acct="$(basename "$target")"
if [[ -f "__LOG__/mounted-$acct" ]]; then
    echo "rw,nosuid,nodev,noexec,relatime"
    exit 0
fi
exit 1
'
# shellcheck disable=SC2016
stub mount '
last="${@: -1}"; acct="$(basename "$last")"
case "$*" in
    *remount*) touch "__LOG__/mounted-$acct" ;;
esac
'
# shellcheck disable=SC2016
stub id '
acct="${@: -1}"
if [[ "${1:-}" == "-gn" ]]; then
    awk "{print \$1}" "__LOG__/groups/$acct" 2>/dev/null || true
else
    cat "__LOG__/groups/$acct" 2>/dev/null || true
fi
'
# shellcheck disable=SC2016
stub usermod '
case "$1" in
    -G)
        groups="$2"; acct="$3"
        f="__LOG__/groups/$acct"
        primary="$(awk "{print \$1}" "$f" 2>/dev/null || true)"
        IFS="," read -ra add <<< "$groups"
        printf "%s" "$primary" > "$f"
        for g in "${add[@]}"; do printf " %s" "$g" >> "$f"; done
        printf "\n" >> "$f"
        ;;
    -aG)
        groups="$2"; acct="$3"
        f="__LOG__/groups/$acct"
        existing="$(cat "$f" 2>/dev/null || true)"
        IFS="," read -ra add <<< "$groups"
        for g in "${add[@]}"; do
            case " $existing " in *" $g "*) ;; *) existing="$existing $g" ;; esac
        done
        printf "%s\n" "${existing# }" > "$f"
        ;;
    -c)
        name="$2"; acct="$3"
        printf "%s" "$name" > "__LOG__/gecos/$acct"
        ;;
esac
'
# shellcheck disable=SC2016
stub getent '
if [[ "$1" == "passwd" ]]; then
    acct="$2"
    gecos="$(cat "__LOG__/gecos/$acct" 2>/dev/null || true)"
    printf "%s:x:1000:1000:%s:/home/%s:/bin/bash\n" "$acct" "$gecos" "$acct"
    exit 0
fi
exit 1
'
# systemctl: mask is a real filesystem op (matches --root); is-active
# always answers "inactive" (rc 1) — never exercised here anyway, since
# OMARCHY_KIDS_ROOT is set throughout this suite (skip, not fail/pass).
# shellcheck disable=SC2016
stub systemctl '
root=""
for a in "$@"; do case "$a" in --root=*) root="${a#--root=}" ;; esac; done
if [[ "$1" == "--root="* ]]; then shift; fi
if [[ "$1" == "mask" ]]; then
    unit="$2"
    mkdir -p "$root/etc/systemd/system"
    ln -sf /dev/null "$root/etc/systemd/system/$unit"
fi
if [[ "$1" == "is-active" ]]; then exit 1; fi
'
stub objcopy 'exit 0'
# shellcheck disable=SC2016
stub lsinitcpio '
cat "__LOG__/lsinitcpio-output" 2>/dev/null
'
# shellcheck disable=SC2016
stub mkinitcpio '
[[ "$1" == "-P" ]] && echo "usr/lib/initcpio/hooks/omarchy-kids-unlock" > "__LOG__/lsinitcpio-output"
'
stub limine-snapper-sync ''
# cryptsetup luksDump: two enabled LUKS2 slots, matching the luks-slots
# fixture below (boot:luks-slots, issue #29's new check).
stub cryptsetup '
if [[ "$1" == "luksDump" ]]; then
cat <<"DUMP"
Keyslots:
  0: luks2
  1: luks2
Tokens:
DUMP
fi
'
# loginctl: a fixture session directory, one "__LOG__/loginctl-session-<acct>"
# file per live session, holding "<session-id> <leader-pid>". Tests toggle
# which of these files exist to move live_test_tmpfs_noexec (issue #41)
# between its three paths: a live session, no session but a log to fall
# back on, or neither.
# shellcheck disable=SC2016
stub loginctl '
if [[ "$1" == "--no-legend" && "$2" == "list-sessions" ]]; then
    for f in __LOG__/loginctl-session-*; do
        [[ -e "$f" ]] || continue
        acct="$(basename "$f")"; acct="${acct#loginctl-session-}"
        read -r sess pid < "$f"
        printf "%s 1000 %s seat0 tty1\n" "$sess" "$acct"
    done
    exit 0
fi
if [[ "$1" == "show-session" ]]; then
    sess="$2"
    for f in __LOG__/loginctl-session-*; do
        [[ -e "$f" ]] || continue
        read -r fsess fpid < "$f"
        if [[ "$fsess" == "$sess" ]]; then
            printf "%s\n" "$fpid"
            exit 0
        fi
    done
    exit 1
fi
exit 1
'

# boot-mode.sh must see root ownership even though this Mac fixture is
# created by the test user. Every other stat call reaches the real tool.
REAL_STAT="$(command -v stat)"
cat >"$STUBS/stat" <<EOF
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
case "\$target" in
  "$ETC" | "$ETC/machine.conf")
    case "\$format" in
      %u) echo 0; exit 0 ;;
      %G | %Sg) echo root; exit 0 ;;
    esac
    ;;
esac
exec "$REAL_STAT" "\$@"
EOF
chmod +x "$STUBS/stat"

# Only the stubs and a base toolset: an Omarchy box has the real
# omarchy-*/omarchy-kids-* commands on PATH, and a check that one is
# missing must not depend on this box (AGENTS.md, testing rules).
BASE_PATH="$(kids_base_path "$TMP/base" unshare)"
export PATH="$STUBS:$BASE_PATH"
export OMARCHY_KIDS_ETC="$ETC"
export OMARCHY_KIDS_SHARE="$SHARE"
export OMARCHY_KIDS_ROOT="$SCRATCH_ROOT"
export OMARCHY_KIDS_HOME_ROOT="$HOMEROOT"
export OMARCHY_KIDS_LUKS_DEVICE="/dev/fake0"

# --- seed every lock as "already provisioned", using lib/posture.sh's
#     own writers directly, same as assert-test.sh -------------------

# shellcheck source=lib/conf.sh
source "$ROOT_DIR/lib/conf.sh"
# shellcheck source=lib/posture.sh
source "$ROOT_DIR/lib/posture.sh"

posture_add_fstab_line kid-ada
posture_add_namespace_lines kid-ada

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
cat >"$SCRATCH_ROOT/etc/pam.d/omarchy-lock-password" <<'EOF'
#%PAM-1.0
auth       required                    pam_faillock.so preauth silent deny=10 unlock_time=120
-auth      [success=2 default=ignore]  pam_systemd_home.so
auth       [success=1 default=bad]     pam_unix.so try_first_pass nullok
auth       [default=die]               pam_faillock.so authfail deny=10 unlock_time=120
auth       optional                    pam_permit.so
auth       required                    pam_env.so
auth       required                    pam_faillock.so authsucc
account    include                     system-local-login
EOF

posture_ensure_pam_namespace sddm
posture_ensure_pam_namespace systemd-user
posture_write_polkit_admin_rule mark
posture_write_polkit_deny_rule
posture_write_sddm_theme_dropin
posture_write_accountsservice kid-ada fox
posture_write_face_icon "$SHARE/avatars/fox.svg" kid-ada
posture_write_portal_conf mark "$(printf 'kid-ada\tAda Lovelace\tfox')"
PORTAL_CONF="$SCRATCH_ROOT/usr/share/sddm/themes/omarchy-kids/theme.conf.user"
check_eq "$(grep '^parents=' "$PORTAL_CONF" 2>/dev/null)" 'parents="mark"' \
  "fixture: portal parent allowlist is quoted"
check_eq "$(grep '^kids=' "$PORTAL_CONF" 2>/dev/null)" 'kids="kid-ada:Ada Lovelace:fox"' \
  "fixture: portal kid list is quoted"
printf '%s' 'Ada Lovelace' >"$LOG/gecos/kid-ada"
posture_ensure_parent_unlock_line sddm
posture_ensure_parent_unlock_line omarchy-lock-password

mkdir -p "$HOMEROOT/home/kid-ada"
touch "$LOG/mounted-kid-ada"

echo "kid-ada omarchy-kids omarchy-kids-6-8" >"$LOG/groups/kid-ada"

for n in 2 3 4 5 6; do
  mkdir -p "$SCRATCH_ROOT/etc/systemd/system"
  ln -sf /dev/null "$SCRATCH_ROOT/etc/systemd/system/getty@tty$n.service"
done

for u in omarchy-kids-boot-login.service omarchy-kids-boot-login-cleanup.service omarchy-kids-assert.service; do
  mkdir -p "$SCRATCH_ROOT/etc/systemd/system/multi-user.target.wants"
  ln -sf "/usr/lib/systemd/system/$u" "$SCRATCH_ROOT/etc/systemd/system/multi-user.target.wants/$u"
done
mkdir -p "$SCRATCH_ROOT/etc/systemd/system/sockets.target.wants"
ln -sf /usr/lib/systemd/system/omarchy-kids-authd.socket "$SCRATCH_ROOT/etc/systemd/system/sockets.target.wants/omarchy-kids-authd.socket"
ln -sf /usr/lib/systemd/system/omarchy-kids-wifid.socket "$SCRATCH_ROOT/etc/systemd/system/sockets.target.wants/omarchy-kids-wifid.socket"
mkdir -p "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants"
ln -sf /usr/lib/systemd/system/omarchy-kids-ask-collect.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-ask-collect.timer"
ln -sf /usr/lib/systemd/system/omarchy-kids-time.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-time.timer"
ln -sf /usr/lib/systemd/system/omarchy-kids-review.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-review.timer"
ln -sf /usr/lib/systemd/system/omarchy-kids-relay-courier.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-relay-courier.timer"

mkdir -p "$ETC/hyprland"
cp "$SHARE"/hyprland/*.lua "$ETC/hyprland/"

mkdir -p "$SCRATCH_ROOT/etc/chromium/policies/managed"
CHROMIUM_FILE="$SCRATCH_ROOT/etc/chromium/policies/managed/omarchy-kids-6-8.json"
cat >"$CHROMIUM_FILE" <<'EOF'
{"DnsOverHttpsMode": "secure"}
EOF
chmod 0640 "$CHROMIUM_FILE"

mkdir -p "$SCRATCH_ROOT/usr/lib/initcpio/hooks" "$SCRATCH_ROOT/boot/EFI/Linux"
touch "$SCRATCH_ROOT/usr/lib/initcpio/hooks/omarchy-kids-unlock"
touch "$SCRATCH_ROOT/boot/EFI/Linux/arch-linux.efi"
echo "usr/lib/initcpio/hooks/omarchy-kids-unlock" >"$LOG/lsinitcpio-output"

# --- extra fixtures for check, beyond what assert-test.sh needs -------
#
# sudoers: a readable, empty pair (account:no-sudo would otherwise WARN
#          "cannot verify" — real, just not readable by this non-root
#          suite, same reason a real /etc/sudoers is 0440).
# luks-slots + cryptsetup stub above: boot:luks-slots (issue #29's slot-
#          count-consistency check) needs both to resolve past "cannot
#          verify".
# limine.conf / etc/default/limine: boot:limine-editor and
#          boot:snapshot-entries reuse omarchy-kids-assert's own
#          limine_editor_ok/limine_snapshots_ok, which (like every lock
#          here) report "ok" when the file is simply absent — these
#          fixtures make them a real, checked PASS instead.
# usage/: time:ledger:kid-ada would otherwise WARN "doesn't exist yet",
#          true and correct before a kid's first session, but not what
#          a "clean, everything-checked" tree should show.
mkdir -p "$SCRATCH_ROOT/etc"
: >"$SCRATCH_ROOT/etc/sudoers"
mkdir -p "$SCRATCH_ROOT/etc/sudoers.d"
printf '0=mark\n1=kid-ada\n' >"$ETC/luks-slots"
printf 'default_entry: 1\neditor_enabled: no\n' >"$SCRATCH_ROOT/boot/limine.conf"
mkdir -p "$SCRATCH_ROOT/etc/default"
printf 'MAX_SNAPSHOT_ENTRIES=0\n' >"$SCRATCH_ROOT/etc/default/limine"
mkdir -p "$SCRATCH_ROOT/var/lib/omarchy-kids/kid-ada/usage"
chmod 0755 "$SCRATCH_ROOT/var/lib/omarchy-kids/kid-ada/usage"

# --- --help / bad args ------------------------------------------------

out="$("$BIN" --help)"
st=$?
check_eq "$st" 0 "--help exits 0"
check_contains "$out" "Usage: omarchy-kids-check" "--help prints usage"

"$BIN" --nonsense >/dev/null 2>&1
check_eq "$?" 2 "an unknown flag exits 2"

# --- a clean, fully-provisioned tree: exit 0 ("safe to hand over") -----

out="$("$BIN")"
st=$?
check_eq "$st" 0 "a clean, fully-provisioned tree exits 0"
check_contains "$out" "All checks pass" "clean tree: the human verdict line says so"
check_not_contains "$out" "FAIL" "clean tree: no FAIL line anywhere"
check_not_contains "$out" "WARN" "clean tree: no WARN line anywhere either (every fixture answers definitively)"
for id in "account:kid-ada:exists" "account:kid-ada:no-wheel" "account:kid-ada:no-sudo" \
  "account:kid-ada:band-group" "account:kid-ada:home-noexec" "account:kid-ada:gecos" \
  "lock:fstab:kid-ada" "lock:groups:kid-ada" "lock:boot-hook" "lock:limine-editor" "lock:limine-snapshots" \
  "boot:mode" "boot:unlock-hook" "boot:luks-slots" "boot:limine-editor" "boot:snapshot-entries" \
  "login:theme-dropin" "login:theme-conf-user" "login:face:kid-ada" "login:autologin-dropin" \
  "pam:parent-unlock:sddm" "pam:faillock-order:sddm" "web:mode:6-8" "web:doh:6-8" \
  "time:ledger:kid-ada" "firmware:password"; do
  check_contains "$out" "$id" "clean tree: report includes '$id'"
done

# --- --json: shape, and the same verdict/exit_code as the exit code ----

json="$("$BIN" --json)"
jst=$?
check_eq "$jst" 0 "--json on a clean tree also exits 0"
check_contains "$json" '"verdict": "pass"' "--json: verdict is pass"
check_contains "$json" '"exit_code": 0' "--json: exit_code matches the process exit code"
check_contains "$json" '"sections": [' "--json: has a sections array"
check_contains "$json" '"name": "Accounts"' "--json: has an Accounts section"
check_contains "$json" '"name": "Locks"' "--json: has a Locks section"
check_contains "$json" '"name": "Firmware"' "--json: has a Firmware section"
check_contains "$json" '"id": "lock:fstab:kid-ada", "status": "pass"' "--json: a check object has id/status fields"
check_contains "$json" '"detail":' "--json: a check object has a detail field"
if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="pass"; assert d["exit_code"]==0; assert isinstance(d["sections"], list) and d["sections"]; [d for s in d["sections"] for c in s["checks"] if c["status"] in ("pass","warn","fail","skip")]' 2>/dev/null; then
    pass "--json: parses as valid JSON with the documented shape (python3 json.load)"
  else
    fail "--json: python3 could not parse it as the documented shape"
  fi
else
  pass "--json: skipped the python3 structural parse (no python3 on this box)"
fi

# --- Boot JSON is selected only by the trusted machine mode -----------

if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
boot = next(s for s in d["sections"] if s["name"] == "Boot")
assert [c["id"] for c in boot["checks"]] == [
    "boot:mode", "boot:unlock-hook", "boot:luks-slots",
    "boot:limine-editor", "boot:snapshot-entries"
]
' 2>/dev/null; then
    pass "disk JSON exposes only the disk-mode Boot checks"
  else
    fail "disk JSON exposed the wrong Boot checks"
  fi
fi

conf_set "$ETC/machine.conf" boot portal
rm -f "$ETC/luks-slots"
rm -f "$SCRATCH_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"
rm -f "$SCRATCH_ROOT/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf"
: >"$ARGV_LOG"
portal_json="$("$BIN" --json)"
portal_status=$?
check_eq "$portal_status" 0 "portal mode with no owned boot artifacts exits 0"
for id in "boot:mode" "boot:no-kid-luks-slots" "boot:no-mkinitcpio-dropin" "boot:stock-autologin"; do
  check_contains "$portal_json" "\"id\": \"$id\"" "portal JSON includes '$id'"
done
for id in "boot:unlock-hook" "boot:luks-slots" "boot:limine-editor" "boot:snapshot-entries" \
  "lock:boot-hook" "lock:limine-editor" "lock:limine-snapshots"; do
  check_not_contains "$portal_json" "\"id\": \"$id\"" "portal JSON omits disk-only '$id'"
done
portal_argv="$(cat "$ARGV_LOG")"
for tool in cryptsetup objcopy lsinitcpio limine-snapper-sync; do
  check_not_contains "$portal_argv" "$tool " "portal check never invokes $tool"
done

if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$portal_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
boot = next(s for s in d["sections"] if s["name"] == "Boot")
assert [c["id"] for c in boot["checks"]] == [
    "boot:mode", "boot:no-kid-luks-slots",
    "boot:no-mkinitcpio-dropin", "boot:stock-autologin"
]
' 2>/dev/null; then
    pass "portal JSON exposes only the portal-mode Boot checks"
  else
    fail "portal JSON exposed the wrong Boot checks"
  fi
fi

printf '1=kid-ada\n' >"$ETC/luks-slots"
mkdir -p "$SCRATCH_ROOT/etc/mkinitcpio.conf.d" "$SCRATCH_ROOT/etc/sddm.conf.d"
touch "$SCRATCH_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"
printf '[Autologin]\nUser=kid-ada\n' >"$SCRATCH_ROOT/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf"
portal_bad_json="$("$BIN" --json)"
check_eq "$?" 2 "portal mode fails when disk-owned boot artifacts remain"
for id in "boot:no-kid-luks-slots" "boot:no-mkinitcpio-dropin" "boot:stock-autologin"; do
  check_contains "$portal_bad_json" "\"id\": \"$id\", \"status\": \"fail\"" "portal residue fails '$id'"
done
rm -f "$ETC/luks-slots"
rm -f "$SCRATCH_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"
rm -f "$SCRATCH_ROOT/etc/sddm.conf.d/zz-omarchy-kids-autologin.conf"

printf 'parent=mark\nboot=broken\nfirmware.card_done=yes\n' >"$ETC/machine.conf"
chmod 0644 "$ETC/machine.conf"
invalid_json="$("$BIN" --json)"
invalid_status=$?
check_eq "$invalid_status" 2 "an invalid trusted mode makes the safety report fail"
check_contains "$invalid_json" '"id": "boot:mode", "status": "fail"' "invalid mode is reported without guessing"
for id in "boot:unlock-hook" "boot:luks-slots" "boot:limine-editor" "boot:snapshot-entries" \
  "boot:no-kid-luks-slots" "boot:no-mkinitcpio-dropin" "boot:stock-autologin"; do
  check_not_contains "$invalid_json" "\"id\": \"$id\"" "invalid mode omits '$id'"
done

printf '0=mark\n1=kid-ada\n' >"$ETC/luks-slots"
conf_set "$ETC/machine.conf" boot disk

# --- a missing face icon: WARN, not FAIL — exit 1, not 2 ----------------

FACE_ICON="$SCRATCH_ROOT/usr/share/sddm/faces/kid-ada.face.icon"
rm -f "$FACE_ICON"
out="$("$BIN")"
st=$?
plain="$(strip_ansi "$out")"
check_eq "$st" 1 "a missing face icon alone: exits 1 (warn), not 2 (fail)"
check_contains "$plain" "WARN  lock:face:kid-ada" "missing face icon: lock:face:kid-ada is a WARN"
check_contains "$plain" "WARN  login:face:kid-ada" "missing face icon: login:face:kid-ada is a WARN too"
check_not_contains "$plain" "FAIL" "missing face icon: nothing else reports FAIL"
check_contains "$out" "Passing, with warnings" "missing face icon: the human verdict says 'passing, with warnings'"
posture_write_face_icon "$SHARE/avatars/fox.svg" kid-ada # restore for what follows

# --- a broken lock: FAIL — exit 2 ---------------------------------------

DENY_RULE="$SCRATCH_ROOT/etc/polkit-1/rules.d/41-omarchy-kids-deny.rules"
rm -f "$DENY_RULE"
out="$("$BIN")"
st=$?
plain="$(strip_ansi "$out")"
check_eq "$st" 2 "a broken lock (polkit-deny missing) exits 2"
check_contains "$plain" "FAIL  lock:polkit-deny" "broken lock: lock:polkit-deny reports FAIL"
check_contains "$out" "run 'omarchy-kids-assert'" "broken lock: the detail names the fix, without running it"
check_contains "$out" "Not ready" "broken lock: the human verdict says 'not ready'"

json2="$("$BIN" --json)"
check_contains "$json2" '"verdict": "fail"' "--json also reflects a broken lock as verdict fail"
check_contains "$json2" '"exit_code": 2' "--json also reflects exit_code 2"
posture_write_polkit_deny_rule # restore, after both the human and json checks above

# --- check never calls a *_fix: the fstab/mount/systemctl argv log never
#     shows a fix-shaped call (mount --bind, mount -o remount, systemctl
#     mask/enable) across this whole run, only fix() functions'
#     signatures. lock_check calls only *_ok functions -- confirm no
#     fixing side effects happened by re-breaking a lock and checking
#     that a FAIL does NOT restore it. ---------------------------------

rm -f "$DENY_RULE"
"$BIN" >/dev/null 2>&1
[[ ! -f "$DENY_RULE" ]] && pass "check never fixes: a FAILed lock (polkit-deny) is still missing after a run" ||
  fail "check must never write a lock back -- polkit-deny exists after a plain run"
posture_write_polkit_deny_rule # restore for what follows

# --- firmware-password gate (R-TRUST-3): red (FAIL) until marked done,
#     a plain PASS (with the software caveat) once it is -------------

conf_del "$ETC/machine.conf" firmware.card_done
out="$("$BIN")"
plain="$(strip_ansi "$out")"
check_contains "$plain" "FAIL  firmware:password" "firmware not marked done: FAIL (red), per R-TRUST-3"
check_contains "$out" "isn't marked done" "firmware not marked done: names the manual step"

conf_set "$ETC/machine.conf" firmware.card_done yes
out="$("$BIN")"
plain="$(strip_ansi "$out")"
check_contains "$plain" "PASS  firmware:password" "firmware marked done: PASS, with a software caveat in its own detail text"
check_contains "$out" "can't be verified from software" "firmware marked done: still honest about what it can't prove (R-TRUST-2)"

# --- no kids provisioned: Accounts/Locks/Firmware/Time say so, nothing
#     pretends to have checked anything kid-specific ------------------

EMPTY_ETC="$TMP/etc-empty/omarchy-kids"
mkdir -p "$EMPTY_ETC/kids"
cat >"$EMPTY_ETC/machine.conf" <<'EOF'
parent=mark
EOF
chmod 0644 "$EMPTY_ETC/machine.conf"
out="$(OMARCHY_KIDS_ETC="$EMPTY_ETC" "$BIN")"
check_contains "$out" "SKIP  accounts:none" "no kids: Accounts says so"
check_contains "$out" "SKIP  locks:none" "no kids: Locks says so"
check_contains "$out" "SKIP  firmware:password" "no kids: Firmware is skipped, not red, before any kid exists"
check_not_contains "$out" "kid-ada" "no kids: nothing about kid-ada leaks in from the real \$OMARCHY_KIDS_ETC"

# --- --live: without root, warns and skips rather than faking a result -

out="$("$BIN" --live)"
st=$?
if [[ "$(id -u)" != "0" ]]; then
  check_contains "$out" "live:skipped" "--live as non-root: the Live tests section names why it skipped"
  check_contains "$out" "isn't root" "--live as non-root: says it needs root"
else
  pass "--live: this suite is somehow running as root; skipping the non-root assertion (AGENTS.md rule 8's own root/unshare convention)"
fi

out="$("$BIN")"
check_contains "$out" "not run — pass --live" "without --live: the Live tests section says how to run it"

# --- --live's session-aware /tmp and /dev/shm noexec check (issue #41) --
#
# The old probe ran `findmnt` through `runuser`, whose PAM stack never
# opens a pam_namespace session, so it always saw the machine's own
# global /tmp/dev-shm and FAILed even when the kid's real session has
# private noexec tmpfs mounts (docs/check.md's "Verified live" section).
# live_test_tmpfs_noexec replaces it: a live session's own mountinfo,
# else the kid's last "omarchy-kids-session --check" log, else a WARN
# naming the exact command to run. All three need run_live_section's own
# EUID-0 gate, which needs a real (or simulated) root -- unshare --user
# --map-root-user when this box supports unprivileged user namespaces,
# skipped otherwise (AGENTS.md rule 8's root/unshare convention; this
# dev box has no unshare at all, Darwin).
PROC_ROOT="$TMP/proc"
RUN_ROOT="$SCRATCH_ROOT/run/user/1000/omarchy-kids"
mkdir -p "$PROC_ROOT" "$RUN_ROOT"

if command -v unshare >/dev/null 2>&1 && unshare --user --map-root-user true 2>/dev/null; then
  as_root() { unshare --user --map-root-user -- "$@"; }

  # -- a live session whose leader's own mountinfo shows real, private
  #    noexec tmpfs mounts on both /tmp and /dev/shm: PASS both -------
  mkdir -p "$PROC_ROOT/4242"
  cat >"$PROC_ROOT/4242/mountinfo" <<'EOF'
22 28 0:20 / /tmp rw,nosuid,nodev shared:9 - tmpfs tmpfs rw,size=1000000k
23 28 0:21 / /dev/shm rw,nosuid,nodev shared:10 - tmpfs tmpfs rw
24 22 0:22 / /tmp rw,nosuid,nodev,noexec,relatime - tmpfs tmpfs:kids-inst rw,size=65536k,uid=1000,gid=1000
25 23 0:23 / /dev/shm rw,nosuid,nodev,noexec,relatime - tmpfs tmpfs:kids-inst rw,size=65536k,uid=1000,gid=1000
EOF
  printf 's1 4242\n' >"$LOG/loginctl-session-kid-ada"

  out="$(OMARCHY_KIDS_PROC_ROOT="$PROC_ROOT" as_root "$BIN" --live)"
  plain="$(strip_ansi "$out")"
  check_contains "$plain" "PASS  live:kid-ada:tmp-noexec" "live session, private noexec /tmp: PASS from the session leader's own mountinfo"
  check_contains "$plain" "PASS  live:kid-ada:shm-noexec" "live session, private noexec /dev/shm: PASS too"
  check_contains "$plain" "pid 4242" "live session PASS: the detail names the session leader pid it read"

  # -- same live session, but its mountinfo shows only the machine's
  #    global (non-noexec) /tmp and /dev/shm -- exactly what the old
  #    runuser-based probe always saw: FAIL both, correctly this time --
  mkdir -p "$PROC_ROOT/4243"
  cat >"$PROC_ROOT/4243/mountinfo" <<'EOF'
22 28 0:20 / /tmp rw,nosuid,nodev shared:9 - tmpfs tmpfs rw,size=1000000k
23 28 0:21 / /dev/shm rw,nosuid,nodev shared:10 - tmpfs tmpfs rw
EOF
  printf 's1 4243\n' >"$LOG/loginctl-session-kid-ada"

  out="$(OMARCHY_KIDS_PROC_ROOT="$PROC_ROOT" as_root "$BIN" --live)"
  plain="$(strip_ansi "$out")"
  check_contains "$plain" "FAIL  live:kid-ada:tmp-noexec" "live session, global (non-noexec) /tmp: FAIL, not a false pass"
  check_contains "$plain" "FAIL  live:kid-ada:shm-noexec" "live session, global (non-noexec) /dev/shm: FAIL too"
  check_contains "$plain" "NOT a private noexec tmpfs" "live session FAIL: the detail says why"

  # -- no live session, but the kid's last session-log has a
  #    check=tmp_noexec PASS line: fall back to it, and skip shm (the
  #    log never records /dev/shm) -------------------------------------
  rm -f "$LOG/loginctl-session-kid-ada"
  printf '%s check=tmp_noexec name="private /tmp noexec" result=PASS detail="/tmp mounted noexec"\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" >"$RUN_ROOT/session-1000.log"

  out="$(OMARCHY_KIDS_PROC_ROOT="$PROC_ROOT" as_root "$BIN" --live)"
  plain="$(strip_ansi "$out")"
  check_contains "$plain" "PASS  live:kid-ada:tmp-noexec" "no live session, log says PASS: falls back to the session log"
  check_contains "$plain" "last 'omarchy-kids-session --check' log" "log fallback: the detail says it's reading the log, not a live probe"
  check_contains "$plain" "SKIP  live:kid-ada:shm-noexec" "log fallback: /dev/shm is a SKIP (the log never records it), not a FAIL"

  # -- same, but the log's line is a WARN (R-FND-2a not rolled out on
  #    this stack yet) -- surfaced as WARN, not silently upgraded to
  #    PASS or downgraded to FAIL -------------------------------------
  printf '%s check=tmp_noexec name="private /tmp noexec" result=WARN detail="/tmp is not a private noexec mount yet"\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" >"$RUN_ROOT/session-1000.log"

  out="$(OMARCHY_KIDS_PROC_ROOT="$PROC_ROOT" as_root "$BIN" --live)"
  plain="$(strip_ansi "$out")"
  check_contains "$plain" "WARN  live:kid-ada:tmp-noexec" "no live session, log says WARN: surfaced as WARN"

  # -- no live session and no log at all: WARN naming the exact command
  #    a parent can run, never a silent skip or a false FAIL ----------
  rm -f "$RUN_ROOT/session-1000.log"

  out="$(OMARCHY_KIDS_PROC_ROOT="$PROC_ROOT" as_root "$BIN" --live)"
  plain="$(strip_ansi "$out")"
  check_contains "$plain" "WARN  live:kid-ada:tmp-noexec" "no live session, no log: WARN, not FAIL"
  check_contains "$plain" "no live session to inspect" "no live session, no log: says so"
  check_contains "$plain" "loginctl list-sessions" "no live session, no log: names the exact command to run"
  check_contains "$plain" "omarchy-kids-session --check" "no live session, no log: names the check to run once logged in"
  check_contains "$plain" "SKIP  live:kid-ada:shm-noexec" "no live session, no log: /dev/shm is a SKIP too, pointing back at tmp-noexec"
else
  pass "--live session-aware tmp/shm check: no unprivileged user namespaces on this box (Darwin, or disabled) -- skipping, per AGENTS.md rule 8"
fi
rm -f "$LOG/loginctl-session-kid-ada" "$RUN_ROOT/session-1000.log"

echo "check-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
