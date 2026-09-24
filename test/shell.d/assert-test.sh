#!/bin/bash
# Tests bin/omarchy-kids-assert (SPEC.md I-4, R-TRUST-5, R-BOOT-5, R-WEB-1,
# R-BOOTMODE-6, R-BOOTMODE-11, R-BOOTMODE-12, R-TIMEAUTH-5,
# R-TIMEAUTH-7, R-FND-2..6, §5.1): every lock it re-asserts,
# one at a time, plus the no-profiles no-op and the "second run is all ok"
# idempotence claim.
#
# Fully self-contained, per AGENTS.md rule 8 (never write outside a
# scratch tree; never run as root): every system command that would touch
# the real machine (findmnt, mount, id, usermod, systemctl, mkinitcpio,
# objcopy, lsinitcpio) is a fake on a stub PATH that only logs its argv
# and fakes just enough state for the script under test to react to --
# same shape as test/shell.d/provision-test.sh's stub() helper, reused
# here almost verbatim. One provisioned kid throughout: kid-ada, band
# 6-8, per AGENTS.md rule 9's fixture convention.
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
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
wait_for_file() { # FILE PID: wait up to 30 seconds while PID is alive
  local file="$1" pid="$2"
  for _ in {1..3000}; do
    [[ -f "$file" ]] && return 0
    kill -0 "$pid" 2>/dev/null || return 1
    sleep 0.01
  done
  return 1
}
# line_status OUTPUT LOCK — the status word ("ok"/"fixed"/"FAIL"/"" if
# absent) that OUTPUT's line for LOCK starts with.
line_status() {
  local out="$1" lock="$2" line
  line="$(grep -E "^[A-Za-z-]+ +${lock}\$" <<<"$out" || true)"
  [[ -n "$line" ]] && awk '{print $1}' <<<"$line"
}
check_status() { # OUTPUT LOCK WANT LABEL
  local got
  got="$(line_status "$1" "$2")"
  check_eq "$got" "$3" "$4"
}
# only_this_lock_changed OUTPUT LOCK LABEL — every line in OUTPUT is "ok"
# except LOCK, which must be "fixed". Confirms one broken lock doesn't
# make assert touch (or misreport) any other lock.
only_this_lock_changed() {
  local out="$1" lock="$2" label="$3" bad
  check_status "$out" "$lock" "fixed" "$label: $lock reports fixed"
  bad="$(grep -Ev "^ok " <<<"$out" | grep -v "^fixed *${lock}\$" || true)"
  [[ -z "$bad" ]] && pass "$label: no other lock line changed" ||
    fail "$label: unexpected non-ok line(s):"$'\n'"$bad"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- scratch tree ------------------------------------------------------

ETC="$TMP/etc/omarchy-kids"
BOOT_MODE_LOCK="$ETC/boot-mode.lock"
SHARE="$TMP/share/omarchy-kids"
SCRATCH_ROOT="$TMP/root" # OMARCHY_KIDS_ROOT
HOMEROOT="$TMP/homeroot" # OMARCHY_KIDS_HOME_ROOT
STUBS="$TMP/stubs"
LOG="$TMP/log"
ARGV_LOG="$LOG/argv.log"

mkdir -p "$ETC/kids" "$SHARE/hyprland" "$SHARE/avatars" "$SCRATCH_ROOT/usr/lib/pam.d" "$HOMEROOT" "$STUBS" "$LOG/groups" "$LOG/gecos"
printf 'account include system-login\nsession include system-login\n' >"$SCRATCH_ROOT/usr/lib/pam.d/systemd-user"
touch "$ARGV_LOG"

cat >"$ETC/machine.conf" <<'EOF'
parent=mark
boot=disk
EOF
chmod 0644 "$ETC/machine.conf"

# The mode reader is a build-time constant. Test the command from a copied
# package tree with that constant pointed at this root-owned fixture.
TREE="$TMP/tree"
kids_tree "$TREE" "$ROOT_DIR"
rm -f "$TREE/lib"
cp -a "$ROOT_DIR/lib" "$TREE/lib"
kids_set_const "$TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$ETC/machine.conf"
kids_set_const "$TREE/lib/boot-mode.sh" BOOT_MODE_LOCK "$BOOT_MODE_LOCK"
BIN="$TREE/bin/omarchy-kids-assert"
CONF="$TREE/bin/omarchy-kids-conf"

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada Lovelace
avatar=fox
band=6-8
theme=tokyo-night
password=set
onboarded=no
EOF

# issue #53: a scratch system themes dir for theme_apply_for's own copy.
OMARCHY_PATH="$TMP/omarchy"
mkdir -p "$OMARCHY_PATH/themes/tokyo-night"
echo 'background = "#1a1b26"' >"$OMARCHY_PATH/themes/tokyo-night/colors.toml"

cp "$ROOT_DIR"/share/hyprland/*.lua "$SHARE/hyprland/"
cp "$ROOT_DIR"/share/avatars/*.svg "$SHARE/avatars/"
mkdir -p "$SHARE/bands" "$SHARE/packs"
cp "$ROOT_DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$ROOT_DIR"/share/packs/*.toml "$SHARE/packs/"

# --- stub PATH -----------------------------------------------------------

# stub NAME EXTRA — see provision-test.sh for the full rationale; same
# helper, copied rather than shared (test/shell.d files are each
# self-contained, matching every other file in this directory).
stub() {
  local name="$1" extra="${2:-}" f="$STUBS/$1"
  cat >"$f" <<'EOF'
#!/bin/bash
{ printf '%s' "__NAME__"; printf ' %s' "$@"; printf '\n'; } >> "__ARGVLOG__"
EOF
  [[ -n "$extra" ]] && printf '%s\n' "$extra" >>"$f"
  echo 'exit 0' >>"$f"
  sed -i.bak -e "s#__NAME__#$name#g" -e "s#__ARGVLOG__#$ARGV_LOG#g" -e "s#__LOG__#$LOG#g" \
    -e "s#__HOMEROOT__#$HOMEROOT#g" "$f"
  rm -f "$f.bak"
  chmod +x "$f"
}

# machine.conf is owned by this test user on disk; present the root ownership
# the installed reader requires while leaving every other stat call real.
REAL_STAT="$(command -v stat)"
# shellcheck disable=SC2016
stub stat '
if [[ "${1:-}" == "--version" ]]; then exec __REAL_STAT__ "$@"; fi
format="${2:-}"; target="${3:-}"
if [[ "$target" == "__ETC__" || "$target" == "__ETC__/machine.conf" || "$target" == "__ETC__/boot-mode.lock" ]]; then
    case "$format" in
        %u) echo 0; exit 0 ;;
        %G | %Sg) echo root; exit 0 ;;
    esac
fi
exec __REAL_STAT__ "$@"
'
sed -i.bak -e "s#__REAL_STAT__#$REAL_STAT#g" -e "s#__ETC__#$ETC#g" "$STUBS/stat"
rm -f "$STUBS/stat.bak"

# findmnt: reports noexec,nosuid,nodev when "$LOG/mounted-<acct>" exists
# (the marker `mount`'s remount branch below writes), else "not found".
# shellcheck disable=SC2016
stub findmnt '
target="${@: -1}"; acct="$(basename "$target")"
if [[ -f "__LOG__/mounted-$acct" ]]; then
    echo "rw,nosuid,nodev,noexec,relatime"
    exit 0
fi
exit 1
'
# mount: a bare bind is a no-op (logged only); a remount sets the marker
# findmnt reads, mirroring what a real remount,noexec would leave in place.
# shellcheck disable=SC2016
stub mount '
last="${@: -1}"; acct="$(basename "$last")"
case "$*" in
    *remount*) touch "__LOG__/mounted-$acct" ;;
esac
'
# id -nG <acct>: prints the space-separated group list usermod (below)
# maintains in "$LOG/groups/<acct>"; empty (not "found") if never seeded.
# shellcheck disable=SC2016
stub id '
if [[ "${1:-}" == "-u" && $# -eq 1 && "${BOOT_TEST_ROOT:-0}" == 1 ]]; then echo 0; exit 0; fi
acct="${@: -1}"
if [[ "${1:-}" == "-gn" ]]; then
    awk "{print \$1}" "__LOG__/groups/$acct" 2>/dev/null || true
else
    cat "__LOG__/groups/$acct" 2>/dev/null || true
fi
'
# flock: use the host implementation where available, so the Omarchy gate
# exercises the real fd lock. The Mac fallback has the same held/unlock shape.
REAL_FLOCK="$(command -v flock || true)"
LOCK_HELD="$TMP/boot-mode-held"
LOCK_OWNER="$TMP/boot-mode-owner"
FORCE_LOCK_TIMEOUT="$TMP/boot-mode-force-timeout"
cat >"$STUBS/flock" <<EOF
#!/bin/bash
printf 'flock %s\n' "\$*" >> "$ARGV_LOG"
[[ ! -e "$FORCE_LOCK_TIMEOUT" ]] || exit 1
if [[ -n "$REAL_FLOCK" ]]; then
  exec "$REAL_FLOCK" "\$@"
fi
if [[ "\${1:-}" == -u ]]; then
  if [[ "\$(cat "$LOCK_OWNER" 2>/dev/null || true)" == "\$PPID" ]]; then
    rm -rf "$LOCK_HELD" "$LOCK_OWNER"
  fi
  exit 0
fi
wait_count=500
if [[ "\${1:-}" == -w ]]; then
  shift 2
fi
for ((i = 0; i < wait_count; i++)); do
  if mkdir "$LOCK_HELD" 2>/dev/null; then
    printf '%s\n' "\$PPID" > "$LOCK_OWNER"
    exit 0
  fi
  owner="\$(cat "$LOCK_OWNER" 2>/dev/null || true)"
  if [[ -n "\$owner" ]] && ! kill -0 "\$owner" 2>/dev/null; then
    rm -rf "$LOCK_HELD" "$LOCK_OWNER"
    continue
  fi
  sleep 0.01
done
exit 1
EOF
chmod +x "$STUBS/flock"
# usermod -G g1,g2 <acct>: replaces supplementary groups, preserving primary.
# usermod -c NAME <acct> (issue #39): writes NAME to
# "$LOG/gecos/<acct>", read back by the "getent" stub below -- the same
# per-account-log-file idiom the groups fixture above already uses.
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
# getent passwd <acct>: a minimal passwd(5) line whose GECOS field (5th
# colon-separated field) is whatever the usermod stub above last wrote
# to "$LOG/gecos/<acct>" -- empty if never seeded, matching a real
# account with no GECOS set at all. This box has no real "kid-ada" user
# account to ask (AGENTS.md rule 8: nothing here is ever a real
# system), so this is the entire NSS lookup for the gecos lock's check
# side. The home field (6th) is __HOMEROOT__-prefixed, matching this
# suite's own OMARCHY_KIDS_HOME_ROOT scratch layout -- lib/theme.sh's
# theme_account_home (issue #53) prefers this real-shaped lookup over
# its own OMARCHY_KIDS_HOME_ROOT fallback, the same as a real getent
# would on an actual machine.
# shellcheck disable=SC2016
stub getent '
if [[ "$1" == "passwd" ]]; then
    acct="$2"
    gecos="$(cat "__LOG__/gecos/$acct" 2>/dev/null || true)"
    printf "%s:x:1000:1000:%s:__HOMEROOT__/home/%s:/bin/bash\n" "$acct" "$gecos" "$acct"
    exit 0
fi
exit 1
'
# systemctl --root=R mask UNIT / --root=R enable UNIT...: the two
# subcommands this suite exercises; each is a pure filesystem operation
# under a --root, no live systemd needed, so the check side (getty_ok,
# units_ok, in the script under test) reads real symlink state, not
# anything this stub invents. mask: UNIT -> /dev/null under
# R/etc/systemd/system. enable: UNIT -> /usr/lib/systemd/system/UNIT
# under the .wants directory matching its own suffix (.service ->
# multi-user.target.wants, .socket -> sockets.target.wants, .timer ->
# timers.target.wants) -- exactly the three .wants dirs units_ok reads
# via unit_link (issue #46: the no-kids units case exercises this fix
# path for the first time in this suite).
# shellcheck disable=SC2016
stub systemctl '
root=""
for a in "$@"; do case "$a" in --root=*) root="${a#--root=}" ;; esac; done
if [[ "$1" == "--root="* ]]; then shift; fi
case "$1" in
    mask)
        unit="$2"
        mkdir -p "$root/etc/systemd/system"
        ln -sf /dev/null "$root/etc/systemd/system/$unit"
        ;;
    enable)
        shift
        for unit in "$@"; do
            case "$unit" in
                *.service) target=multi-user.target.wants ;;
                *.socket) target=sockets.target.wants ;;
                *.timer) target=timers.target.wants ;;
                *) continue ;;
            esac
            mkdir -p "$root/etc/systemd/system/$target"
            ln -sf "/usr/lib/systemd/system/$unit" "$root/etc/systemd/system/$target/$unit"
        done
        ;;
esac
'
# lsinitcpio: ignores its argument entirely and just cats a log-controlled
# fixture the test flips between "has the hook" and "does not" -- objcopy
# needs no real ELF/PE input for this since lsinitcpio never reads it.
# shellcheck disable=SC2016
stub objcopy 'exit 0'
# shellcheck disable=SC2016
stub lsinitcpio '
cat "__LOG__/lsinitcpio-output" 2>/dev/null
'
# mkinitcpio -P: "rebuilds" the image by making the next lsinitcpio call
# report the hook present, exactly what a real rebuild would cause.
# shellcheck disable=SC2016
stub mkinitcpio '
[[ "$1" == "-P" ]] && echo "usr/lib/initcpio/hooks/omarchy-kids-unlock" > "__LOG__/lsinitcpio-output"
'
# limine-snapper-sync: present on PATH throughout, purely to prove the
# limine-snapshots lock never calls it in this suite -- OMARCHY_KIDS_ROOT
# is always set here, so posture_root is never empty (see below).
stub limine-snapper-sync ''

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

# --- seed every lock as "already provisioned", using lib/posture.sh's
#     own writers directly (never omarchy-kids-provision: this test is
#     about assert re-asserting, not about provisioning) --------------

# shellcheck source=lib/conf.sh
source "$ROOT_DIR/lib/conf.sh"
# shellcheck source=lib/posture.sh
source "$ROOT_DIR/lib/posture.sh"

posture_add_fstab_line kid-ada
posture_add_namespace_lines kid-ada

# Real PAM stacks ship with an auth chain already in them (issue #15,
# R-SEC-2): posture_ensure_parent_unlock_line anchors on the first
# non-comment "auth" line, not a pam_unix.so line (real Omarchy stacks
# don't reliably have one of their own -- see lib/posture.sh's own
# comment). These two fixtures are verbatim /etc/pam.d/sddm and
# /etc/pam.d/omarchy-lock-password from a real Omarchy 4.0.2 box
# (there is no /etc/pam.d/hyprlock on that box -- an earlier version of
# this suite guessed one; confirmed wrong and replaced). Seeded before
# posture_ensure_pam_namespace so the pam_namespace session line lands
# after it, at the bottom, matching how a real stack is laid out (auth
# block, then account/session).
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

cat >"$SCRATCH_ROOT/etc/pam.d/sddm-autologin" <<'EOF'
#%PAM-1.0
auth        required    pam_env.so
auth        required    pam_faillock.so preauth
-auth       [success=2 default=ignore] pam_systemd_home.so
auth        required    pam_permit.so
auth        required    pam_faillock.so authsucc
-auth       optional    pam_kwallet5.so
account     include     system-login
password    include     system-login
session     optional    pam_keyinit.so          force revoke
session     include     system-login
-session    optional    pam_gnome_keyring.so    auto_start
-session    optional    pam_kwallet5.so         auto_start
EOF
posture_ensure_pam_namespace sddm
posture_ensure_pam_namespace systemd-user
posture_ensure_pam_namespace sddm-autologin
posture_write_polkit_admin_rule mark
posture_write_polkit_deny_rule
posture_write_sddm_theme_dropin
posture_write_accountsservice kid-ada fox
posture_write_face_icon "$SHARE/avatars/fox.svg" kid-ada
posture_write_portal_conf mark "$(printf 'kid-ada\tAda Lovelace\tfox')"
printf '%s' 'Ada Lovelace' >"$LOG/gecos/kid-ada"
posture_ensure_parent_unlock_line sddm
posture_ensure_parent_unlock_line omarchy-lock-password

# mount: already mounted noexec (the findmnt stub's marker file)
mkdir -p "$HOMEROOT/home/kid-ada"
touch "$LOG/mounted-kid-ada"

# theme (issue #53): kid-ada's own current theme already matches the
# profile's theme=tokyo-night, via the same theme_apply_for the lock
# itself uses to fix drift, so the first "all ok" run below is really ok.
theme_apply_for kid-ada tokyo-night

# groups: already a member of both
echo "kid-ada omarchy-kids omarchy-kids-6-8" >"$LOG/groups/kid-ada"

# getty@tty2..6 already masked
for n in 2 3 4 5 6; do
  mkdir -p "$SCRATCH_ROOT/etc/systemd/system"
  ln -sf /dev/null "$SCRATCH_ROOT/etc/systemd/system/getty@tty$n.service"
done

# package units already enabled
for u in omarchy-kids-boot-login.service omarchy-kids-boot-login-cleanup.service omarchy-kids-assert.service; do
  mkdir -p "$SCRATCH_ROOT/etc/systemd/system/multi-user.target.wants"
  ln -sf "/usr/lib/systemd/system/$u" "$SCRATCH_ROOT/etc/systemd/system/multi-user.target.wants/$u"
done
mkdir -p "$SCRATCH_ROOT/etc/systemd/system/sockets.target.wants"
ln -sf /usr/lib/systemd/system/omarchy-kids-authd.socket "$SCRATCH_ROOT/etc/systemd/system/sockets.target.wants/omarchy-kids-authd.socket"
ln -sf /usr/lib/systemd/system/omarchy-kids-wifid.socket "$SCRATCH_ROOT/etc/systemd/system/sockets.target.wants/omarchy-kids-wifid.socket"
# omarchy-kids-ask-collect.timer already enabled too (issue #25)
mkdir -p "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants"
ln -sf /usr/lib/systemd/system/omarchy-kids-ask-collect.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-ask-collect.timer"
ln -sf /usr/lib/systemd/system/omarchy-kids-time.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-time.timer"
ln -sf /usr/lib/systemd/system/omarchy-kids-review.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-review.timer"
ln -sf /usr/lib/systemd/system/omarchy-kids-relay-courier.timer "$SCRATCH_ROOT/etc/systemd/system/timers.target.wants/omarchy-kids-relay-courier.timer"

# hyprland configs already installed (copied from the real share/hyprland
# fixture above, so a byte-for-byte cmp against $SHARE/hyprland passes)
mkdir -p "$ETC/hyprland"
cp "$SHARE"/hyprland/*.lua "$ETC/hyprland/"

# Launcher maps are rebuilt from root-owned desktop entries and absolute
# executables, then re-asserted like every other lock.
mkdir -p "$SCRATCH_ROOT/usr/share/applications"
stub gcompris
stub tuxpaint
cat >"$SCRATCH_ROOT/usr/share/applications/tuxpaint.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Tux Paint
Exec=tuxpaint %F
Icon=tuxpaint
EOF
DIR="$ROOT_DIR"
LIB="$ROOT_DIR/lib"
KIDS_DIR="$ETC/kids"
CONF_BIN="$ROOT_DIR/bin/omarchy-kids-conf"
KIDS_PY=python3
source "$ROOT_DIR/lib/launcher-map.sh"
# shellcheck source=lib/session-manifest.sh
source "$ROOT_DIR/lib/session-manifest.sh"

# chromium policy: one band's file, already 0640
mkdir -p "$SCRATCH_ROOT/etc/chromium/policies/managed"
CHROMIUM_FILE="$SCRATCH_ROOT/etc/chromium/policies/managed/omarchy-kids-6-8.json"
echo '{}' >"$CHROMIUM_FILE"
chmod 0640 "$CHROMIUM_FILE"
launcher_map_fix kid-ada

# The ownership fence (AGENTS.md rule 9): an executable that is group/other-
# writable is refused, so a PATH a kid can set can make a tile absent, never point
# it at the kid's own binary.
tuxpaint_bin="$(command -v tuxpaint)"
chmod 0777 "$tuxpaint_bin"
launcher_map_fix kid-ada 2>/dev/null
check_eq "$?" "1" "launcher-map: a world-writable executable is refused"
chmod 0755 "$tuxpaint_bin"
launcher_map_fix kid-ada ||
  fail "launcher-map: the map builds again once the executable is closed"

# The baseline is fully provisioned, including the session input assert owns.
session_manifest_build kid-ada
MANIFEST_FILE="$ETC/sessions/kid-ada.json"

# A failed allowlist (here: an account with no profile) must leave no map behind, never an empty one.
launcher_map_fix kid-nosuch 2>/dev/null
check_eq "$?" "1" "launcher_map_fix: fails when the allowlist cannot be built"
if [[ ! -e "$(launcher_map_path kid-nosuch)" ]]; then
  pass "launcher_map_fix: writes no map when it fails"
else
  fail "launcher_map_fix: writes no map when it fails"
fi

# boot hook: the package's hook file present, a fake UKI to "check", and
# lsinitcpio's fixture already reporting the hook is in it
mkdir -p "$SCRATCH_ROOT/usr/lib/initcpio/hooks" "$SCRATCH_ROOT/boot/EFI/Linux"
touch "$SCRATCH_ROOT/usr/lib/initcpio/hooks/omarchy-kids-unlock"
# The bootloader locks are machine-level and report `warn` where the file
# they assert does not exist (review S11), so the baseline tree has both.
mkdir -p "$SCRATCH_ROOT/boot" "$SCRATCH_ROOT/etc/default"
printf 'editor_enabled: no\ndefault_entry: 2\n' >"$SCRATCH_ROOT/boot/limine.conf"
printf 'MAX_SNAPSHOT_ENTRIES=0\n' >"$SCRATCH_ROOT/etc/default/limine"
UKI_FIXTURE="$SCRATCH_ROOT/boot/EFI/Linux/arch-linux.efi"
touch "$UKI_FIXTURE"
export OMARCHY_KIDS_UKI="$UKI_FIXTURE"
echo "usr/lib/initcpio/hooks/omarchy-kids-unlock" >"$LOG/lsinitcpio-output"

# --- --help / bad args ------------------------------------------------

help="$("$BIN" --help)"
check_eq "$?" 0 "--help exits 0"
check_contains "$help" "With no kids, only units runs" "--help names portal output with zero kids"
"$BIN" --nonsense >/dev/null 2>&1
check_eq "$?" 2 "an unknown flag exits 2"

# --- everything already correct: first full run is all ok -------------

out="$("$BIN")"
st=$?
check_eq "$st" 0 "a fully-provisioned, untouched tree exits 0"
for lock in "fstab:kid-ada" "mount:kid-ada" "namespace:kid-ada" \
  "accountsservice:kid-ada" "gecos:kid-ada" "face:kid-ada" "groups:kid-ada" "theme:kid-ada" "polkit-admin" "polkit-deny" \
  "sddm-theme" "portal-conf" \
  "pam:sddm" "pam:systemd-user" "pam:sddm-autologin" "parent-unlock:sddm" "parent-unlock:omarchy-lock-password" \
  "getty:tty2" "getty:tty3" "getty:tty4" \
  "getty:tty5" "getty:tty6" "units" "hyprland-configs" "chromium-policy:6-8" "boot-hook" \
  "launcher-map:kid-ada" "session-manifest:kid-ada" "limine-editor" "limine-snapshots"; do
  check_status "$out" "$lock" "ok" "first run: $lock is ok"
done

# --- root screen-time infrastructure -------------------------------------

TIME_UNIT="$ROOT_DIR/systemd/omarchy-kids-time.timer"
grep -qxF 'OnBootSec=30s' "$TIME_UNIT" && pass "time timer: starts after 30 seconds" ||
  fail "time timer: missing OnBootSec=30s"
grep -qxF 'OnUnitActiveSec=30s' "$TIME_UNIT" && pass "time timer: repeats every 30 seconds" ||
  fail "time timer: missing OnUnitActiveSec=30s"

TIME_STATE_DIR="$SCRATCH_ROOT/run/omarchy-kids/time"
TIME_STATE="$TIME_STATE_DIR/kid-ada.json"
TIME_LEDGER_DIR="$SCRATCH_ROOT/var/lib/omarchy-kids/kid-ada/usage"
mkdir -p "$TIME_STATE_DIR" "$TIME_LEDGER_DIR"
cat >"$TIME_STATE" <<'EOF'
{"kid":"kid-ada","state":"grace","reason":"lights-out","remaining_seconds":0,"grace_deadline":1234,"last_tick":1200,"active_seconds_remainder":12,"warnings_fired":[10],"logical_day":"2026-09-04","last_wall":"2026-09-04 21:00:00","enforcement":{"action":"lock","reason":"lights-out","result":"success","at":"2026-09-04 21:00:00"}}
EOF
printf '17\n' >"$TIME_LEDGER_DIR/2026-09-04"
printf '15\n' >"$TIME_LEDGER_DIR/2026-09-04.grant"
chmod 0770 "$TIME_STATE_DIR"
chmod 0660 "$TIME_STATE"
chmod 0700 "$TIME_LEDGER_DIR"
chmod 0600 "$TIME_LEDGER_DIR/2026-09-04" "$TIME_LEDGER_DIR/2026-09-04.grant"
state_before="$(cat "$TIME_STATE")"
state_inode="$(kids_file_mtime "$TIME_STATE")"
usage_before="$(cat "$TIME_LEDGER_DIR/2026-09-04")"
grant_before="$(cat "$TIME_LEDGER_DIR/2026-09-04.grant")"
out="$($BIN)"
check_status "$out" "units" "fixed" "time infrastructure: broken modes report fixed through units"
check_eq "$(kids_file_mode "$TIME_STATE_DIR")" "750" "time infrastructure: runtime directory is mode 0750"
check_eq "$(kids_file_mode "$TIME_STATE")" "640" "time infrastructure: runtime state is mode 0640"
check_eq "$(kids_file_mode "$TIME_LEDGER_DIR")" "755" "time infrastructure: usage directory is mode 0755"
check_eq "$(kids_file_mode "$TIME_LEDGER_DIR/2026-09-04")" "644" "time infrastructure: usage ledger is mode 0644"
check_eq "$(kids_file_mode "$TIME_LEDGER_DIR/2026-09-04.grant")" "644" "time infrastructure: grant ledger is mode 0644"
check_eq "$(cat "$TIME_STATE")" "$state_before" "time infrastructure: runtime state bytes are unchanged"
check_eq "$(kids_file_mtime "$TIME_STATE")" "$state_inode" "time infrastructure: runtime state was not replaced"
check_eq "$(cat "$TIME_LEDGER_DIR/2026-09-04")" "$usage_before" "time infrastructure: usage ledger is unchanged"
check_eq "$(cat "$TIME_LEDGER_DIR/2026-09-04.grant")" "$grant_before" "time infrastructure: grant ledger is unchanged"

# --- paired-device registry (R-NOTIFY-3) -----------------------------------

DEV_DIR="$SCRATCH_ROOT/etc/omarchy-kids/devices"
mkdir -p "$DEV_DIR"
printf 'id=d1\nname=Phone\n' >"$DEV_DIR/d1.conf"
chmod 0777 "$DEV_DIR"
chmod 0666 "$DEV_DIR/d1.conf"
out="$($BIN)"
check_status "$out" "devices" "fixed" "devices: broken modes report fixed (R-NOTIFY-3)"
check_eq "$(kids_file_mode "$DEV_DIR")" "750" "devices: directory is mode 0750 (R-NOTIFY-3)"
check_eq "$(kids_file_mode "$DEV_DIR/d1.conf")" "600" "devices: record is mode 0600 (R-NOTIFY-3)"

# --- the away drop-in: the relay's fence (R-NOTIFY-11.1) -------------------

AWAY_DIR="$SCRATCH_ROOT/etc/systemd/system/omarchy-kids-relayd.service.d"
AWAY_FILE="$AWAY_DIR/away.conf"
UNIT_DIR="$SCRATCH_ROOT/usr/lib/systemd/system"
UNIT_FILE="$UNIT_DIR/omarchy-kids-relayd.service"
mkdir -p "$UNIT_DIR"
printf '[Service]\nIPAddressAllow=localhost\nIPAddressDeny=any\n' >"$UNIT_FILE"
unit_before="$(cksum <"$UNIT_FILE")"

# Absent: ok, and assert must not create it (presence is the parent's consent).
out="$($BIN)"
check_status "$out" "relay-away" "ok" "relay-away: no drop-in is ok (the base fence applies)"
[[ -e "$AWAY_FILE" ]] && fail "relay-away: assert created a consent file" ||
  pass "relay-away: assert never creates the drop-in"

# Wrong bytes at the right mode: the content compare is what drives the fix.
mkdir -p "$AWAY_DIR"
printf 'IPAddressAllow=0.0.0.0/0\n' >"$AWAY_FILE"
chmod 0644 "$AWAY_FILE"
out="$($BIN)"
check_status "$out" "relay-away" "fixed" "relay-away: wrong bytes at 0644 report fixed"
grep -q '^IPAddressAllow=localhost link-local multicast 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fe80::/10 100.64.0.0/10$' "$AWAY_FILE" &&
  pass "relay-away: the drop-in carries the LAN list plus the CGNAT range" ||
  fail "relay-away: the drop-in content is wrong"
check_eq "$(cksum <"$UNIT_FILE")" "$unit_before" "relay-away: the packaged unit was not touched (I-7)"

# The exact bytes at 0644: ok, nothing to fix.
out="$($BIN)"
check_status "$out" "relay-away" "ok" "relay-away: the exact bytes at 0644 are ok"

# A right file with the wrong mode is fixed, not rewritten as content drift.
chmod 0600 "$AWAY_FILE"
out="$($BIN)"
check_status "$out" "relay-away" "fixed" "relay-away: a wrong mode reports fixed"
check_eq "$(kids_file_mode "$AWAY_FILE")" "644" "relay-away: the mode is restored to 0644"

# A foreign drop-in AND a widened away.conf: the lock FAILs, leaves the admin's
# file exactly as it was, and still repairs the file it owns first (round 1: the
# foreign check used to return before the rewrite, leaving the fence widened).
printf 'IPAddressAllow=0.0.0.0/0\n' >"$AWAY_FILE"
printf '[Service]\nIPAddressAllow=0.0.0.0/0\n' >"$AWAY_DIR/local-admin.conf"
foreign_before="$(cksum <"$AWAY_DIR/local-admin.conf")"
out="$($BIN)"
check_status "$out" "relay-away" "FAIL" "relay-away: a foreign drop-in fails the lock"
check_eq "$(cksum <"$AWAY_DIR/local-admin.conf")" "$foreign_before" \
  "relay-away: assert never rewrites (or deletes) an admin's file"
grep -q '^IPAddressAllow=localhost link-local multicast .* 100.64.0.0/10$' "$AWAY_FILE" &&
  pass "relay-away: the owned drop-in is repaired even beside a foreign one" ||
  fail "relay-away: a foreign drop-in left the owned file widened"
rm -f "$AWAY_DIR/local-admin.conf"

# away off (the consent file removed) is ok again.
rm -f "$AWAY_FILE"
out="$($BIN)"
check_status "$out" "relay-away" "ok" "relay-away: removing the consent file is ok"
[[ "$(cksum <"$UNIT_FILE")" == "$unit_before" ]] && pass "relay-away: the unit is still untouched" ||
  fail "relay-away: a packaged file changed"

# --- the secret-holding files: relay-tls and courier-conf (R-NOTIFY-11.4) ---

RELAY_DIR="$SCRATCH_ROOT/etc/omarchy-kids/relay"
COURIER_CONF="$SCRATCH_ROOT/etc/omarchy-kids/courier.conf"

out="$($BIN)"
check_status "$out" "relay-tls" "ok" "relay-tls: no relay directory is ok"
check_status "$out" "courier-conf" "ok" "courier-conf: no mailbox file is ok"
[[ -e "$RELAY_DIR" ]] && fail "relay-tls: assert created a relay directory" ||
  pass "relay-tls: assert never creates the directory"
[[ -e "$COURIER_CONF" ]] && fail "courier-conf: assert created the mailbox file" ||
  pass "courier-conf: assert never creates the file"

mkdir -p "$RELAY_DIR"
printf 'cert' >"$RELAY_DIR/cert.pem"
printf 'key' >"$RELAY_DIR/key.pem"
printf 'transport=ntfy\nurl=https://x\ntopic=y\n' >"$COURIER_CONF"
chmod 0777 "$RELAY_DIR"
chmod 0666 "$RELAY_DIR/cert.pem" "$RELAY_DIR/key.pem" "$COURIER_CONF"
out="$($BIN)"
check_status "$out" "relay-tls" "fixed" "relay-tls: wrong modes report fixed"
check_eq "$(kids_file_mode "$RELAY_DIR")" "750" "relay-tls: the directory is 0750"
check_eq "$(kids_file_mode "$RELAY_DIR/cert.pem")" "644" "relay-tls: cert.pem is 0644"
check_eq "$(kids_file_mode "$RELAY_DIR/key.pem")" "640" "relay-tls: key.pem is 0640"
check_status "$out" "courier-conf" "fixed" "courier-conf: a wrong mode reports fixed"
check_eq "$(kids_file_mode "$COURIER_CONF")" "600" "courier-conf: the mailbox file is 0600"

# A loose copy of the key beside the real one -- hidden, the shape a glob would
# miss: FAIL, left exactly as it was, and the file the lock owns is still repaired.
printf 'key' >"$RELAY_DIR/.key.pem.bak"
chmod 0600 "$RELAY_DIR/.key.pem.bak"
foreign_before="$(cksum <"$RELAY_DIR/.key.pem.bak")"
chmod 0666 "$RELAY_DIR/key.pem"
out="$($BIN)"
check_status "$out" "relay-tls" "FAIL" "relay-tls: a foreign copy fails the lock"
check_eq "$(kids_file_mode "$RELAY_DIR/key.pem")" "640" "relay-tls: the owned key is still repaired"
check_eq "$(cksum <"$RELAY_DIR/.key.pem.bak")" "$foreign_before" \
  "relay-tls: the hidden foreign copy is left untouched"
rm -f "$RELAY_DIR/.key.pem.bak"
out="$($BIN)"
check_status "$out" "relay-tls" "ok" "relay-tls: ok again once the foreign copy is gone"

# --- the request queue (R-NOTIFY-7) ----------------------------------------

QUEUE_DIR="$SCRATCH_ROOT/var/lib/omarchy-kids/queue"
out="$($BIN)"
check_status "$out" "queue" "ok" "queue: absent is ok (no request has been collected)"
[[ -e "$QUEUE_DIR" ]] && fail "queue: assert created the queue" ||
  pass "queue: assert never creates it"

mkdir -p "$QUEUE_DIR"
printf '{}' >"$QUEUE_DIR/1-kid-ada-time.json"
chmod 0755 "$QUEUE_DIR"
chmod 0644 "$QUEUE_DIR/1-kid-ada-time.json"
out="$($BIN)"
check_status "$out" "queue" "fixed" "queue: wrong modes report fixed"
check_eq "$(kids_file_mode "$QUEUE_DIR")" "750" "queue: the directory is 0750"
check_eq "$(kids_file_mode "$QUEUE_DIR/1-kid-ada-time.json")" "640" "queue: the record is 0640"

# A symlinked record is refused and never followed.
ln -sf /etc/passwd "$QUEUE_DIR/evil.json"
out="$($BIN)"
check_status "$out" "queue" "FAIL" "queue: a symlinked record fails the lock"
[[ -L "$QUEUE_DIR/evil.json" ]] && pass "queue: the symlink is left alone" ||
  fail "queue: the symlink was removed or replaced"
rm -f "$QUEUE_DIR/evil.json" "$QUEUE_DIR/1-kid-ada-time.json"

# A symlinked queue directory is refused, never followed.
rm -rf "$QUEUE_DIR"
ln -s /etc "$QUEUE_DIR"
out="$($BIN)"
check_status "$out" "queue" "FAIL" "queue: a symlinked directory fails the lock"
[[ -L "$QUEUE_DIR" ]] && pass "queue: the directory symlink is left alone" ||
  fail "queue: the directory symlink was removed or replaced"
rm -f "$QUEUE_DIR"

# A queue this caller cannot read is a warn ("I could not look"), not a FAIL.
mkdir -p "$QUEUE_DIR"
chmod 0000 "$QUEUE_DIR"
out="$($BIN)"
chmod 0750 "$QUEUE_DIR"
check_status "$out" "queue" "warn" "queue: an unreadable directory is a warn"
rmdir "$QUEUE_DIR"

# --- --quiet on an all-ok tree prints nothing ---------------------------

out="$("$BIN" --quiet)"
st=$?
check_eq "$st" 0 "--quiet on an all-ok tree exits 0"
check_eq "$out" "" "--quiet on an all-ok tree prints nothing"

# --- break each lock in turn; confirm exactly that lock reports fixed,
#     the state is restored, and nothing else moves -----------------

# fstab
sed -i.bak '/kid-ada/d' "$SCRATCH_ROOT/etc/fstab"
rm -f "$SCRATCH_ROOT/etc/fstab.bak"
out="$("$BIN")"
only_this_lock_changed "$out" "fstab:kid-ada" "fstab"
check_eq "$(grep -c "^/home/kid-ada /home/kid-ada none bind,nosuid,nodev,noexec 0 0\$" "$SCRATCH_ROOT/etc/fstab")" "1" \
  "fstab: the line is back"

# mount
rm -f "$LOG/mounted-kid-ada"
out="$("$BIN")"
only_this_lock_changed "$out" "mount:kid-ada" "mount"
check_contains "$(cat "$ARGV_LOG")" "mount -o remount,bind,nosuid,nodev,noexec $HOMEROOT/home/kid-ada" \
  "mount: the remount happened with the right options"
[[ -f "$LOG/mounted-kid-ada" ]] && pass "mount: state is back (mounted noexec again)" ||
  fail "mount: state was not restored"
: >"$ARGV_LOG"

# namespace
NSCONF="$SCRATCH_ROOT/etc/security/namespace.conf"
sed -i.bak '/kid-ada/d' "$NSCONF"
rm -f "$NSCONF.bak"
out="$("$BIN")"
only_this_lock_changed "$out" "namespace:kid-ada" "namespace"
check_eq "$(grep -c "~kid-ada\$" "$NSCONF")" "2" "namespace.conf: both lines use pam_namespace exclusions"

# A legacy bare account line must not make the lock look healthy. Reasserting
# it must remove both legacy lines and leave exactly the two exclusion lines.
printf '%s\n%s\n' \
  "$(posture_namespace_legacy_line_tmp kid-ada)" \
  "$(posture_namespace_legacy_line_shm kid-ada)" >>"$NSCONF"
chmod 0640 "$NSCONF"
if (OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" source "$ROOT_DIR/bin/omarchy-kids-assert" 2>/dev/null && namespace_ok kid-ada); then
  fail "namespace.conf: mixed legacy and exclusion lines are rejected"
else
  pass "namespace.conf: mixed legacy and exclusion lines are rejected"
fi
out="$("$BIN")"
check_eq "$(grep -c "noexec kid-ada\$" "$NSCONF")" "0" "namespace.conf: legacy bare lines are removed"
check_eq "$(grep -c "~kid-ada\$" "$NSCONF")" "2" "namespace.conf: reassert restores exactly two exclusions"
check_eq "$(kids_file_mode "$NSCONF")" "640" "namespace.conf: migration preserves file mode"

# A failed stage copy must fail the rewrite and leave the trusted file intact.
NSCONF_BEFORE="$TMP/namespace.conf.before-copy-failure"
cp "$NSCONF" "$NSCONF_BEFORE"
NSFAIL_STUBS="$TMP/namespace-failure-stubs"
mkdir -p "$NSFAIL_STUBS"
cat >"$NSFAIL_STUBS/cp" <<'EOF'
#!/bin/bash
exit 73
EOF
chmod +x "$NSFAIL_STUBS/cp"
if PATH="$NSFAIL_STUBS:$PATH" posture_add_namespace_lines kid-ada; then
  fail "namespace.conf: failed stage copy is reported"
else
  pass "namespace.conf: failed stage copy is reported"
fi
cmp -s "$NSCONF_BEFORE" "$NSCONF" && pass "namespace.conf: failed stage copy preserves the original" ||
  fail "namespace.conf: failed stage copy preserves the original"

# accountsservice
ASFILE="$SCRATCH_ROOT/var/lib/AccountsService/users/kid-ada"
rm -f "$ASFILE"
out="$("$BIN")"
only_this_lock_changed "$out" "accountsservice:kid-ada" "accountsservice"
check_contains "$(cat "$ASFILE" 2>/dev/null)" "Session=omarchy-kids" "accountsservice: the file is back"

# gecos (issue #39): a stray edit clears kid-ada's GECOS field entirely.
rm -f "$LOG/gecos/kid-ada"
out="$("$BIN")"
only_this_lock_changed "$out" "gecos:kid-ada" "gecos"
check_eq "$(cat "$LOG/gecos/kid-ada" 2>/dev/null)" "Ada Lovelace" "gecos: the display name is back"
check_contains "$(cat "$ARGV_LOG")" "usermod -c Ada Lovelace kid-ada" "gecos: usermod -c was called with the profile's name"
: >"$ARGV_LOG"

# face (issue #39, live VM finding): the SDDM face icon file is deleted.
FACE_ICON="$SCRATCH_ROOT/usr/share/sddm/faces/kid-ada.face.icon"
rm -f "$FACE_ICON"
out="$("$BIN")"
only_this_lock_changed "$out" "face:kid-ada" "face"
if [[ -f "$FACE_ICON" ]] && cmp -s "$SHARE/avatars/fox.svg" "$FACE_ICON"; then
  pass "face: the icon file is back, matching the fox avatar"
else
  fail "face: the icon file was not restored"
fi

# groups
echo "kid-ada omarchy-kids wheel" >"$LOG/groups/kid-ada" # band group missing, wheel is extra
out="$("$BIN")"
only_this_lock_changed "$out" "groups:kid-ada" "groups"
check_contains "$(cat "$ARGV_LOG")" "usermod -G omarchy-kids,omarchy-kids-6-8 kid-ada" \
  "groups: usermod replaces the supplementary group allowlist"
check_contains "$(cat "$LOG/groups/kid-ada")" "omarchy-kids-6-8" "groups: kid-ada is back in the band group"
if grep -qw wheel "$LOG/groups/kid-ada"; then
  fail "groups: repair leaves an extra wheel group"
else
  pass "groups: repair removes an extra wheel group"
fi
: >"$ARGV_LOG"

# theme (issue #53): kid-ada's own theme drifts to a different one (as if
# they deleted/replaced .../current/theme themselves -- they own the
# containing directory, lib/theme.sh's theme_apply_for header has why).
KID_THEME_NAME_FILE="$HOMEROOT/home/kid-ada/.local/state/omarchy/current/theme.name"
echo "some-other-theme" >"$KID_THEME_NAME_FILE"
out="$("$BIN")"
only_this_lock_changed "$out" "theme:kid-ada" "theme"
check_eq "$(cat "$KID_THEME_NAME_FILE" 2>/dev/null)" "tokyo-night" "theme: kid-ada's theme.name is back to the profile's theme"
check_eq "$(cat "$HOMEROOT/home/kid-ada/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null)" \
  "$(cat "$OMARCHY_PATH/themes/tokyo-night/colors.toml")" \
  "theme: kid-ada's colors.toml is back to tokyo-night's own"

# launcher map: a damaged root map is rebuilt from the pack and contains
# absolute argv with desktop-entry field codes already removed.
MAP_FILE="$ETC/launchers/kid-ada.json"
printf '%s\n' '{}' >"$MAP_FILE"
out="$("$BIN")"
only_this_lock_changed "$out" "launcher-map:kid-ada" "launcher-map"
check_eq "$(jq -r '.tiles[] | select(.id == "tuxpaint") | .argv[0]' "$MAP_FILE")" "$STUBS/tuxpaint" \
  "launcher-map: desktop Exec resolves to an absolute executable"
check_eq "$(jq -r '.tiles[] | select(.id == "tuxpaint") | .argv | length' "$MAP_FILE")" "1" \
  "launcher-map: desktop field code is stripped from argv"
check_eq "$(jq -r '.tiles[] | select(.id == "tuxpaint") | has("exec")' "$MAP_FILE")" "false" \
  "launcher-map: map has argv, never an exec string"

# theme: no override at all is "ok" (nothing to fix) -- a profile written
# before issue #53, or a parent with no theme to copy at provision time.
sed -i.bak '/^theme=/d' "$ETC/kids/kid-ada.conf"
rm -f "$ETC/kids/kid-ada.conf.bak"
out="$("$BIN")"
check_status "$out" "theme:kid-ada" "ok" "theme: no override at all reports ok, not FAIL or a fix"
# restore for the rest of this file's own idempotence checks below
printf 'theme=tokyo-night\n' >>"$ETC/kids/kid-ada.conf"
theme_apply_for kid-ada tokyo-night
"$BIN" >/dev/null # the theme is back in the profile, so the manifest must follow before it is the reference

# session manifest: missing files are rebuilt without changing the profile.
profile_before="$(cat "$ETC/kids/kid-ada.conf")"
manifest_before="$(cat "$MANIFEST_FILE")"
rm -f "$MANIFEST_FILE"
out="$($BIN)"
check_status "$out" "session-manifest:kid-ada" "fixed" "session-manifest: missing manifest is rebuilt"
check_eq "$(cat "$ETC/kids/kid-ada.conf")" "$profile_before" \
  "session-manifest: rebuilding does not change profile intent"
check_eq "$(cat "$MANIFEST_FILE")" "$manifest_before" \
  "session-manifest: rebuild restores the same valid bytes"
manifest_inode="$(file_stat i "$MANIFEST_FILE")"

# An unbuildable source must fail the lock and keep the previous valid document.
printf 'budget_min=0\n' >>"$ETC/kids/kid-ada.conf"
out="$($BIN)"
check_status "$out" "session-manifest:kid-ada" "FAIL" "session-manifest: unbuildable profile reports FAIL"
check_eq "$(cat "$MANIFEST_FILE")" "$manifest_before" \
  "session-manifest: failed rebuild keeps the last valid manifest"
check_eq "$(file_stat i "$MANIFEST_FILE")" "$manifest_inode" \
  "session-manifest: failed rebuild keeps the manifest inode"
sed -i.bak '/^budget_min=0$/d' "$ETC/kids/kid-ada.conf"
rm -f "$ETC/kids/kid-ada.conf.bak"

# polkit admin
ADMIN_RULE="$SCRATCH_ROOT/etc/polkit-1/rules.d/40-omarchy-kids.rules"
rm -f "$ADMIN_RULE"
out="$("$BIN")"
only_this_lock_changed "$out" "polkit-admin" "polkit-admin"
check_contains "$(cat "$ADMIN_RULE" 2>/dev/null)" '["unix-user:mark"]' "polkit-admin: the rule is back, naming the parent"

# polkit deny
DENY_RULE="$SCRATCH_ROOT/etc/polkit-1/rules.d/41-omarchy-kids-deny.rules"
rm -f "$DENY_RULE"
out="$("$BIN")"
only_this_lock_changed "$out" "polkit-deny" "polkit-deny"
check_contains "$(cat "$DENY_RULE" 2>/dev/null)" "polkit.Result.NO" "polkit-deny: the rule is back"

# sddm-theme
THEME_DROPIN="$SCRATCH_ROOT/etc/sddm.conf.d/zz-omarchy-kids-theme.conf"
rm -f "$THEME_DROPIN"
out="$("$BIN")"
only_this_lock_changed "$out" "sddm-theme" "sddm-theme"
check_contains "$(cat "$THEME_DROPIN" 2>/dev/null)" "Current=omarchy-kids" "sddm-theme: the drop-in is back"

# portal-conf (issues #39/#100): replaces the earlier portal.json + sddm.service
# XHR drop-in design -- see lib/posture.sh's and Main.qml's own header
# comments for why.
PORTAL_CONF="$SCRATCH_ROOT/usr/share/sddm/themes/omarchy-kids/theme.conf.user"
rm -f "$PORTAL_CONF"
out="$("$BIN")"
only_this_lock_changed "$out" "portal-conf" "portal-conf"
check_contains "$(cat "$PORTAL_CONF" 2>/dev/null)" "parent=mark" "portal-conf: the file is back, with the parent"
check_contains "$(cat "$PORTAL_CONF" 2>/dev/null)" 'parents="mark"' "portal-conf: the quoted parent allowlist is back"
check_contains "$(cat "$PORTAL_CONF" 2>/dev/null)" 'kids="kid-ada:Ada Lovelace:fox"' "portal-conf: kid-ada's quoted entry is back"

# pam:sddm
#
# Wiping the whole file also takes the leading "auth include system-login"
# line parent-unlock anchors on with it, so this run reports two non-ok
# lines, not one: "fixed pam:sddm" (pam_fix rebuilds the namespace
# marker from nothing, same as always) and "FAIL parent-unlock:sddm"
# (parent_unlock_fix has no anchor left to insert before -- see below for
# the anchor's restoration and parent-unlock:sddm's own self-heal).
PAMFILE_SDDM="$SCRATCH_ROOT/etc/pam.d/sddm"
rm -f "$PAMFILE_SDDM"
out="$("$BIN")"
check_status "$out" "pam:sddm" "fixed" "pam:sddm: reports fixed"
check_status "$out" "parent-unlock:sddm" "FAIL" "pam:sddm: wiping the file also fails parent-unlock:sddm (no anchor left)"
bad="$(grep -Ev '^ok |^fixed *pam:sddm$|^FAIL *parent-unlock:sddm$' <<<"$out" || true)"
[[ -z "$bad" ]] && pass "pam:sddm: no other lock line changed" ||
  fail "pam:sddm: unexpected non-ok line(s):"$'\n'"$bad"
check_eq "$(grep -c '^session required pam_namespace.so$' "$PAMFILE_SDDM" 2>/dev/null)" "1" "pam:sddm: the line is back"

# Wiping the whole file (above) also took the "auth include system-login"
# line parent-unlock anchors on with it -- pam_fix/posture_ensure_pam_namespace
# only ever cares about the pam_namespace session line, not the rest of a
# real vendor stack, so it doesn't restore one. That's a lock
# omarchy-kids-assert cannot repair on its own in this scenario (there's
# nothing to anchor on); simulate the vendor stack being restored the
# way a real package reinstall would, and confirm parent-unlock:sddm
# self-heals as soon as its anchor exists again.
cat >>"$PAMFILE_SDDM" <<'EOF'
auth        include     system-login
EOF
out="$("$BIN")"
only_this_lock_changed "$out" "parent-unlock:sddm" "parent-unlock:sddm (after its anchor line is restored)"
check_eq "$(grep -c '# omarchy-kids: parent-unlock verifier (R-SEC-2, R-SEC-3)' "$PAMFILE_SDDM")" "1" \
  "parent-unlock:sddm: the marker is back"

# parent-unlock:omarchy-lock-password (exact resulting text, and idempotence)
PAMFILE_LOCKPW="$SCRATCH_ROOT/etc/pam.d/omarchy-lock-password"
posture_remove_parent_unlock_line omarchy-lock-password # break it using the writer's own inverse, not hand-rolled sed
out="$("$BIN")"
only_this_lock_changed "$out" "parent-unlock:omarchy-lock-password" "parent-unlock:omarchy-lock-password"
expected_lockpw=$'#%PAM-1.0\nauth       required                    pam_faillock.so preauth silent deny=10 unlock_time=120\n# omarchy-kids: parent-unlock verifier (R-SEC-2, R-SEC-3)\nauth       [success=done default=ignore]  pam_exec.so quiet expose_authtok /usr/bin/omarchy-kids-parent-auth\n-auth      [success=2 default=ignore]  pam_systemd_home.so\nauth       [success=1 default=bad]     pam_unix.so try_first_pass nullok\nauth       [default=die]               pam_faillock.so authfail deny=10 unlock_time=120\nauth       optional                    pam_permit.so\nauth       required                    pam_env.so\nauth       required                    pam_faillock.so authsucc\naccount    include                     system-local-login'
check_eq "$(cat "$PAMFILE_LOCKPW")" "$expected_lockpw" \
  "parent-unlock:omarchy-lock-password: exact resulting file content (inserted after the leading preauth line)"
out="$("$BIN")"
check_status "$out" "parent-unlock:omarchy-lock-password" "ok" "parent-unlock:omarchy-lock-password: idempotent (a second run reports ok, not fixed)"
check_eq "$(cat "$PAMFILE_LOCKPW")" "$expected_lockpw" "parent-unlock:omarchy-lock-password: unchanged by the idempotent run"

# pam:systemd-user
PAMFILE_SU="$SCRATCH_ROOT/etc/pam.d/systemd-user"
rm -f "$PAMFILE_SU"
out="$("$BIN")"
only_this_lock_changed "$out" "pam:systemd-user" "pam:systemd-user"
check_eq "$(grep -c '^session required pam_namespace.so$' "$PAMFILE_SU" 2>/dev/null)" "1" "pam:systemd-user: the line is back"
check_eq "$(grep -c 'include system-login' "$PAMFILE_SU")" "2" "pam:systemd-user: re-seeded from the vendor file"

# getty@tty4 (one of five, to prove the others are untouched)
rm -f "$SCRATCH_ROOT/etc/systemd/system/getty@tty4.service"
out="$("$BIN")"
only_this_lock_changed "$out" "getty:tty4" "getty:tty4"
[[ -L "$SCRATCH_ROOT/etc/systemd/system/getty@tty4.service" ]] && pass "getty:tty4: the mask symlink is back" ||
  fail "getty:tty4: the mask symlink was not restored"

# hyprland configs (delete one of several)
rm -f "$ETC/hyprland/L2.lua"
out="$("$BIN")"
only_this_lock_changed "$out" "hyprland-configs" "hyprland-configs"
cmp -s "$SHARE/hyprland/L2.lua" "$ETC/hyprland/L2.lua" && pass "hyprland-configs: L2.lua is back, byte-for-byte" ||
  fail "hyprland-configs: L2.lua was not restored correctly"

# chromium policy (wrong mode)
chmod 0644 "$CHROMIUM_FILE"
out="$("$BIN")"
only_this_lock_changed "$out" "chromium-policy:6-8" "chromium-policy:6-8"
mode="$(kids_file_mode "$CHROMIUM_FILE")"
check_eq "$mode" "640" "chromium-policy:6-8: mode is back to 0640"

# boot hook: lsinitcpio stops reporting the hook -> mkinitcpio -P is run
echo "usr/lib/initcpio/hooks/some-other-hook" >"$LOG/lsinitcpio-output"
out="$("$BIN")"
only_this_lock_changed "$out" "boot-hook" "boot-hook"
check_contains "$(cat "$ARGV_LOG")" "mkinitcpio -P" "boot-hook: mkinitcpio -P was run"
check_contains "$(cat "$LOG/lsinitcpio-output")" "omarchy-kids-unlock" "boot-hook: the rebuilt image now reports the hook"
: >"$ARGV_LOG"

# --- second run after every fix above: everything is ok again ----------

out="$("$BIN")"
st=$?
check_eq "$st" 0 "second run (everything fixed) exits 0"
still_bad="$(grep -Ev '^ok ' <<<"$out" || true)"
[[ -z "$still_bad" ]] && pass "second run: every lock reports ok" ||
  fail "second run: still non-ok line(s):"$'\n'"$still_bad"

# --- --dry-run reports without writing ----------------------------------

sed -i.bak '/kid-ada/d' "$SCRATCH_ROOT/etc/fstab"
rm -f "$SCRATCH_ROOT/etc/fstab.bak"
out="$("$BIN" --dry-run)"
st=$?
check_eq "$st" 0 "--dry-run still exits 0"
check_status "$out" "fstab:kid-ada" "would-fix" "--dry-run: fstab:kid-ada reports would-fix"
check_eq "$(grep -c "kid-ada" "$SCRATCH_ROOT/etc/fstab" 2>/dev/null)" "0" "--dry-run: fstab was not actually written"
"$BIN" >/dev/null # restore for the no-profiles section below, which reuses this tree's stubs but not its ETC

# --- no profiles: silent no-op with --quiet -----------------------------

EMPTY_ETC="$TMP/etc-empty/omarchy-kids"
mkdir -p "$EMPTY_ETC/kids"
out="$(OMARCHY_KIDS_ETC="$EMPTY_ETC" "$BIN" --quiet)"
st=$?
check_eq "$st" 0 "no profiles: exits 0"
check_eq "$out" "" "no profiles: --quiet prints nothing"
out2="$(OMARCHY_KIDS_ETC="$EMPTY_ETC" "$BIN")"
st2=$?
check_eq "$st2" 0 "no profiles, not quiet: still exits 0"
check_contains "$out2" "nothing else to assert" "no profiles, not quiet: names why"

# --- no profiles, but the "units" lock is still asserted -- and fixed if
#     broken -- since it's machine-level, not per-kid (issue #46: a fresh
#     install before the first kid, or right after omarchy-kids-remove
#     disables them again, still needs the package's own units back) ----

check_status "$out2" "units" "ok" "no profiles: units is still checked (not skipped) with zero kids"
check_status "$out2" "relay-tls" "ok" "no profiles: relay-tls is still checked with zero kids"
check_status "$out2" "queue" "ok" "no profiles: queue is still checked with zero kids"
check_status "$out2" "courier-conf" "ok" "no profiles: courier-conf is still checked with zero kids"

# The secret-holding locks are fixed on the zero-kids path too (a leaked key
# still impersonates the relay to a device paired before the first kid).
mkdir -p "$SCRATCH_ROOT/etc/omarchy-kids/relay"
printf 'key' >"$SCRATCH_ROOT/etc/omarchy-kids/relay/key.pem"
printf 'transport=ntfy\nurl=https://x\ntopic=y\n' >"$SCRATCH_ROOT/etc/omarchy-kids/courier.conf"
chmod 0777 "$SCRATCH_ROOT/etc/omarchy-kids/relay"
chmod 0666 "$SCRATCH_ROOT/etc/omarchy-kids/relay/key.pem" "$SCRATCH_ROOT/etc/omarchy-kids/courier.conf"
out4="$(OMARCHY_KIDS_ETC="$EMPTY_ETC" "$BIN")"
check_status "$out4" "relay-tls" "fixed" "no profiles: relay-tls is fixed with zero kids"
check_status "$out4" "courier-conf" "fixed" "no profiles: courier-conf is fixed with zero kids"
check_eq "$(kids_file_mode "$SCRATCH_ROOT/etc/omarchy-kids/relay/key.pem")" "640" \
  "no profiles: the key is 0640 after the fix"
check_eq "$(kids_file_mode "$SCRATCH_ROOT/etc/omarchy-kids/courier.conf")" "600" \
  "no profiles: the mailbox file is 0600 after the fix"
rm -rf "$SCRATCH_ROOT/etc/omarchy-kids/relay" "$SCRATCH_ROOT/etc/omarchy-kids/courier.conf"

BOOT_LOGIN_LINK="$SCRATCH_ROOT/etc/systemd/system/multi-user.target.wants/omarchy-kids-boot-login.service"
rm -f "$BOOT_LOGIN_LINK"
out3="$(OMARCHY_KIDS_ETC="$EMPTY_ETC" "$BIN")"
st3=$?
check_eq "$st3" 0 "no profiles, units broken: still exits 0 once fixed"
check_status "$out3" "units" "fixed" "no profiles: units is fixed even though no kid is provisioned"
check_contains "$out3" "nothing else to assert" "no profiles, units broken: the no-kids line still explains why nothing else ran"
[[ -L "$BOOT_LOGIN_LINK" ]] && pass "no profiles: the boot-login unit's enable symlink is restored" ||
  fail "no profiles: the boot-login unit's enable symlink was not restored"

# idempotent: a second no-kids run with units already fixed is all ok again.
out4="$(OMARCHY_KIDS_ETC="$EMPTY_ETC" "$BIN")"
check_status "$out4" "units" "ok" "no profiles: units is idempotent after being fixed with zero kids"

conf_set "$ETC/machine.conf" boot portal
out5="$(OMARCHY_KIDS_ETC="$EMPTY_ETC" "$BIN")"
check_contains "$out5" "nothing else to assert" "no profiles, portal: names why boot locks did not run"
if grep -qF 'boot-locks:portal' <<<"$out5"; then
  fail "no profiles, portal: reported a boot-lock status that never ran"
else
  pass "no profiles, portal: prints no boot-lock status"
fi
conf_set "$ETC/machine.conf" boot disk

# --- Limine editor lock (V6) -------------------------------------------------
mkdir -p "$SCRATCH_ROOT/boot" "$ETC/kids"
printf 'name=Ada\navatar=fox\nband=6-8\npassword=set\nonboarded=no\n' >"$ETC/kids/kid-ada.conf"       # a provisioned kid again, so machine locks run
printf 'default_entry: 2\ninterface_branding: Omarchy Bootloader\n' >"$SCRATCH_ROOT/boot/limine.conf" # no editor_enabled line
out="$("$BIN" 2>&1)"
if grep -q "fixed *limine-editor" <<<"$out" && head -1 "$SCRATCH_ROOT/boot/limine.conf" | grep -qx 'editor_enabled: no'; then echo "PASS  limine-editor: editor_enabled: no inserted at the top"; else
  echo "FAIL  limine-editor fix ($out)"
  exit 1
fi
out="$("$BIN" 2>&1)"
if grep -q "ok *limine-editor" <<<"$out" && [[ "$(grep -c '^editor_enabled:' "$SCRATCH_ROOT/boot/limine.conf")" == "1" ]]; then echo "PASS  limine-editor: idempotent"; else
  echo "FAIL  limine-editor idempotence ($out)"
  exit 1
fi

# --- Limine snapshot entries lock (V6, issue #38) -----------------------

LIMINE_DEFAULT="$SCRATCH_ROOT/etc/default/limine"
mkdir -p "$SCRATCH_ROOT/etc/default"
: >"$ARGV_LOG"

# hide (the default: no boot.snapshot_entries override yet) fixes a
# pre-existing, non-zero MAX_SNAPSHOT_ENTRIES, remembering it in a comment.
printf 'KERNEL_CMDLINE[default]="quiet"\nMAX_SNAPSHOT_ENTRIES=10\n' >"$LIMINE_DEFAULT"
out="$("$BIN")"
check_status "$out" "limine-snapshots" "fixed" "limine-snapshots (hide, default): reports fixed"
check_eq "$(grep -c '^MAX_SNAPSHOT_ENTRIES=0$' "$LIMINE_DEFAULT")" "1" "limine-snapshots: MAX_SNAPSHOT_ENTRIES=0 is set"
check_eq "$(grep -c '^# omarchy-kids: was MAX_SNAPSHOT_ENTRIES=10$' "$LIMINE_DEFAULT")" "1" \
  "limine-snapshots: the old value (10) is remembered"
check_contains "$(cat "$LIMINE_DEFAULT")" 'KERNEL_CMDLINE[default]="quiet"' "limine-snapshots: unrelated lines are kept"
check_eq "$(grep -c "limine-snapper-sync" "$ARGV_LOG")" "0" \
  "limine-snapshots: limine-snapper-sync is not run against a test root"

# idempotent: a second run is ok, and nothing doubles up.
out="$("$BIN")"
check_status "$out" "limine-snapshots" "ok" "limine-snapshots (hide): idempotent"
check_eq "$(grep -c '^MAX_SNAPSHOT_ENTRIES=' "$LIMINE_DEFAULT")" "1" "limine-snapshots: still exactly one MAX_SNAPSHOT_ENTRIES line"

# show: restores the remembered value and drops our lines.
conf_set "$ETC/machine.conf" boot.snapshot_entries show
out="$("$BIN")"
check_status "$out" "limine-snapshots" "fixed" "limine-snapshots (show): reports fixed"
check_eq "$(grep -c '^MAX_SNAPSHOT_ENTRIES=10$' "$LIMINE_DEFAULT")" "1" "limine-snapshots: the old value (10) is restored"
check_eq "$(grep -c 'omarchy-kids: was MAX_SNAPSHOT_ENTRIES' "$LIMINE_DEFAULT")" "0" "limine-snapshots: the marker comment is gone"

# idempotent under show, too.
out="$("$BIN")"
check_status "$out" "limine-snapshots" "ok" "limine-snapshots (show): idempotent"

# back to hide: re-hides whatever value is there now (10), re-recording it.
conf_set "$ETC/machine.conf" boot.snapshot_entries hide
out="$("$BIN")"
check_status "$out" "limine-snapshots" "fixed" "limine-snapshots (back to hide): reports fixed"
check_eq "$(grep -c '^MAX_SNAPSHOT_ENTRIES=0$' "$LIMINE_DEFAULT")" "1" "limine-snapshots: hidden again"
check_eq "$(grep -c '^# omarchy-kids: was MAX_SNAPSHOT_ENTRIES=10$' "$LIMINE_DEFAULT")" "1" "limine-snapshots: value re-recorded"

# restore path with no remembered value at all: show just drops the line.
printf 'MAX_SNAPSHOT_ENTRIES=0\n' >"$LIMINE_DEFAULT" # our line present, but no "was" comment (e.g. after an upgrade)
conf_set "$ETC/machine.conf" boot.snapshot_entries show
out="$("$BIN")"
check_status "$out" "limine-snapshots" "fixed" "limine-snapshots (show, no remembered value): reports fixed"
check_eq "$(grep -c 'MAX_SNAPSHOT_ENTRIES' "$LIMINE_DEFAULT")" "0" \
  "limine-snapshots: with nothing remembered, the line is simply removed"

# no /etc/default/limine at all (no Limine, or a fresh test tree): nothing to assert.
rm -f "$LIMINE_DEFAULT"
conf_del "$ETC/machine.conf" boot.snapshot_entries
out="$("$BIN")"
check_status "$out" "limine-snapshots" "warn" \
  "limine-snapshots: no /etc/default/limine reports warn, never a silent ok (review S11)"

# --- review S5: limine-editor is machine-level, NOT nested under the hook ---
#
# It used to sit inside `if [[ -f "$HOOK_FILE" ]]`, mis-indented so it read
# as though it were outside. A box with no unlock hook -- never ran
# mkinitcpio -P, hook removed, not Limine-plus-hook -- is exactly the box
# where an unlocked Limine editor hands a kid init=/bin/bash.

printf 'MAX_SNAPSHOT_ENTRIES=0\n' >"$LIMINE_DEFAULT"
printf 'default_entry: 2\n' >"$SCRATCH_ROOT/boot/limine.conf" # editor NOT disabled
mv "$SCRATCH_ROOT/usr/lib/initcpio/hooks/omarchy-kids-unlock" "$SCRATCH_ROOT/hook.bak"

out="$("$BIN" 2>&1)"
if grep -qE '^(ok|fixed|warn|FAIL|would-fix) +boot-hook' <<<"$out"; then
  fail "no hook file: boot-hook should not be reported at all"
else
  pass "no hook file: boot-hook is correctly skipped"
fi
check_status "$out" "limine-editor" "fixed" \
  "no hook file: limine-editor is STILL asserted and fixed (review S5)"
check_eq "$(head -1 "$SCRATCH_ROOT/boot/limine.conf")" "editor_enabled: no" \
  "no hook file: editor_enabled: no was actually written"

out="$("$BIN" 2>&1)"
check_status "$out" "limine-editor" "ok" "no hook file: limine-editor stays ok on the next run"

# ...and with no limine.conf and no `limine` on PATH, this is not a Limine
# box: there is no menu editor to disable, so the lock is ok rather than a
# permanent warn that made omarchy-kids-check exit 1 on every GRUB or
# systemd-boot machine (review S11, issue #58). A box that *does* have
# limine installed but no readable config still warns.
rm -f "$SCRATCH_ROOT/boot/limine.conf"
out="$("$BIN" 2>&1)"
check_status "$out" "limine-editor" "ok" \
  "no limine.conf and no limine installed: nothing to lock, so ok (review S11)"

LIMINE_STUB="$(mktemp -d)"
printf '#!/bin/bash\nexit 0\n' >"$LIMINE_STUB/limine"
chmod +x "$LIMINE_STUB/limine"
out="$(PATH="$LIMINE_STUB:$PATH" "$BIN" 2>&1)"
check_status "$out" "limine-editor" "warn" \
  "limine installed but no readable limine.conf: warn, never a silent ok (review S11)"
rm -rf "$LIMINE_STUB"

mv "$SCRATCH_ROOT/hook.bak" "$SCRATCH_ROOT/usr/lib/initcpio/hooks/omarchy-kids-unlock"
printf 'editor_enabled: no\ndefault_entry: 2\n' >"$SCRATCH_ROOT/boot/limine.conf"

# --- boot-mode gate and the exact pacman argv ---------------------------

# A mode writer that arrives after assert reads disk but before the boot check
# must wait. The old re-read guard allowed portal to land in this window.
RACE_STUBS="$TMP/race-stubs"
mkdir -p "$RACE_STUBS"
cat >"$RACE_STUBS/chown" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$RACE_STUBS/chown"
CHECK_REACHED="$TMP/check-reached"
CHECK_RELEASE="$TMP/check-release"
cat >"$RACE_STUBS/objcopy" <<'EOF'
#!/bin/bash
if [[ -f "__CHECK_ARMED__" ]]; then
  touch "__CHECK_REACHED__"
  for _ in {1..500}; do
    [[ -f "__CHECK_RELEASE__" ]] && break
    sleep 0.01
  done
  [[ -f "__CHECK_RELEASE__" ]] || exit 98
fi
exit 0
EOF
sed -i.bak -e "s#__CHECK_ARMED__#$TMP/check-armed#g" -e "s#__CHECK_REACHED__#$CHECK_REACHED#g" \
  -e "s#__CHECK_RELEASE__#$CHECK_RELEASE#g" "$RACE_STUBS/objcopy"
rm -f "$RACE_STUBS/objcopy.bak"
chmod +x "$RACE_STUBS/objcopy"

conf_set "$ETC/machine.conf" boot disk
printf 'usr/lib/initcpio/hooks/omarchy-kids-unlock\n' >"$LOG/lsinitcpio-output"
touch "$TMP/check-armed"
: >"$ARGV_LOG"
PATH="$RACE_STUBS:$PATH" "$BIN" >"$TMP/check-race.out" 2>&1 &
assert_pid=$!
wait_for_file "$CHECK_REACHED" "$assert_pid" || true
check_eq "$(test -f "$CHECK_REACHED" && echo reached)" "reached" "mode race before check: assert reaches the protected boot action"
PATH="$RACE_STUBS:$PATH" BOOT_TEST_ROOT=1 "$CONF" machine set boot portal >"$TMP/check-writer.out" 2>&1 &
writer_pid=$!
sleep 0.05
check_eq "$(conf_get "$ETC/machine.conf" boot)" "disk" "mode race before check: writer cannot land after the guard"
if kill -0 "$writer_pid" 2>/dev/null; then
  pass "mode race before check: writer waits for assert's boot section"
else
  fail "mode race before check: writer escaped the shared lock"
fi
touch "$CHECK_RELEASE"
wait "$assert_pid"
check_eq "$?" 0 "mode race before check: assert completes under disk authority"
wait "$writer_pid"
check_eq "$?" 0 "mode race before check: waiting writer completes after assert"
check_eq "$(conf_get "$ETC/machine.conf" boot)" "portal" "mode race before check: portal lands only after boot work ends"

# A writer arriving after the failed check but before mkinitcpio mutation must
# also wait. The old second re-read sat immediately before this open window.
REPAIR_REACHED="$TMP/repair-reached"
REPAIR_RELEASE="$TMP/repair-release"
cat >"$RACE_STUBS/mkinitcpio" <<'EOF'
#!/bin/bash
touch "__REPAIR_REACHED__"
for _ in {1..500}; do
  [[ -f "__REPAIR_RELEASE__" ]] && break
  sleep 0.01
done
[[ -f "__REPAIR_RELEASE__" ]] || exit 98
printf 'usr/lib/initcpio/hooks/omarchy-kids-unlock\n' > "__LSINIT_OUTPUT__"
EOF
sed -i.bak -e "s#__REPAIR_REACHED__#$REPAIR_REACHED#g" -e "s#__REPAIR_RELEASE__#$REPAIR_RELEASE#g" \
  -e "s#__LSINIT_OUTPUT__#$LOG/lsinitcpio-output#g" "$RACE_STUBS/mkinitcpio"
rm -f "$RACE_STUBS/mkinitcpio.bak"
chmod +x "$RACE_STUBS/mkinitcpio"
rm -f "$TMP/check-armed" "$CHECK_REACHED" "$CHECK_RELEASE"
conf_set "$ETC/machine.conf" boot disk
printf 'usr/lib/initcpio/hooks/some-other-hook\n' >"$LOG/lsinitcpio-output"
PATH="$RACE_STUBS:$PATH" "$BIN" >"$TMP/repair-race.out" 2>&1 &
assert_pid=$!
wait_for_file "$REPAIR_REACHED" "$assert_pid" || true
check_eq "$(test -f "$REPAIR_REACHED" && echo reached)" "reached" "mode race before repair: assert reaches mkinitcpio after the failed check"
PATH="$RACE_STUBS:$PATH" BOOT_TEST_ROOT=1 "$CONF" machine set boot portal >"$TMP/repair-writer.out" 2>&1 &
writer_pid=$!
sleep 0.05
check_eq "$(conf_get "$ETC/machine.conf" boot)" "disk" "mode race before repair: writer cannot land before mutation"
if kill -0 "$writer_pid" 2>/dev/null; then
  pass "mode race before repair: writer waits for the repair"
else
  fail "mode race before repair: writer escaped the shared lock"
fi
touch "$REPAIR_RELEASE"
wait "$assert_pid"
check_eq "$?" 0 "mode race before repair: assert completes its disk repair"
wait "$writer_pid"
check_eq "$?" 0 "mode race before repair: waiting writer completes after repair"
check_eq "$(conf_get "$ETC/machine.conf" boot)" "portal" "mode race before repair: portal lands only after mutation ends"

# Assert never waits forever behind a transition. It keeps non-boot repair,
# reports the skipped boot section, and makes no boot probe after timeout.
conf_set "$ETC/machine.conf" boot disk
printf 'usr/lib/initcpio/hooks/some-other-hook\n' >"$LOG/lsinitcpio-output"
rm -f "$DENY_RULE"
touch "$FORCE_LOCK_TIMEOUT"
: >"$ARGV_LOG"
out="$("$BIN" 2>&1)"
st=$?
rm -f "$FORCE_LOCK_TIMEOUT"
check_eq "$st" 0 "mode lock timeout: assert exits 0 after skipping boot work"
check_status "$out" "polkit-deny" "fixed" "mode lock timeout: non-boot locks are still repaired"
check_status "$out" "boot-locks:unavailable" "skip" "mode lock timeout: report names the skipped boot section"
check_contains "$(grep '^flock ' "$ARGV_LOG" || true)" "-w 5" "mode lock timeout: assert uses a bounded five-second acquisition"
if grep -qE 'objcopy|lsinitcpio|mkinitcpio|limine' "$ARGV_LOG"; then
  fail "mode lock timeout: assert touched UKI or Limine after lock failure"
else
  pass "mode lock timeout: assert makes zero UKI or Limine calls"
fi
touch "$FORCE_LOCK_TIMEOUT"
out="$("$BIN" --quiet 2>&1)"
st=$?
rm -f "$FORCE_LOCK_TIMEOUT"
check_eq "$st" 0 "mode lock timeout: quiet assert still exits 0"
check_status "$out" "boot-locks:unavailable" "skip" "mode lock timeout: quiet report still names the skipped boot section"

TRACE_STUBS="$TMP/trace-stubs"
BOOT_PROBE_LOG="$LOG/boot-probes.log"
mkdir -p "$TRACE_STUBS"
trace_limine_paths() {
  local tool="$1" real
  real="$(type -P "$tool")"
  cat >"$TRACE_STUBS/$tool" <<EOF
#!/bin/bash
for arg in "\$@"; do
  case "\$arg" in
    "$SCRATCH_ROOT/boot/limine.conf" | "$LIMINE_DEFAULT")
      printf '%s %s\n' "$tool" "\$arg" >>"$ARGV_LOG"
      ;;
  esac
done
exec "$real" "\$@"
EOF
  chmod +x "$TRACE_STUBS/$tool"
}
for tool in cat chmod grep head mktemp mv; do trace_limine_paths "$tool"; done

run_assert_clean() {
  env -i PATH="$TRACE_STUBS:$PATH" OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_ROOT="$SCRATCH_ROOT" OMARCHY_KIDS_HOME_ROOT="$HOMEROOT" \
    OMARCHY_PATH="$OMARCHY_PATH" "$BIN" "$@"
}

run_assert_with_boot_probe_traps() {
  env -i PATH="$TRACE_STUBS:$PATH" OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_ROOT="$SCRATCH_ROOT" OMARCHY_KIDS_HOME_ROOT="$HOMEROOT" \
    OMARCHY_PATH="$OMARCHY_PATH" bash -c '
      bin="$1" probe_log="$2"
      shift 2
      source "$bin" "$@"
      boot_probe() { printf "%s\n" "$1" >>"$probe_log"; return 1; }
      find_uki() { boot_probe find_uki; }
      limine_editor_ok() { boot_probe limine_editor_ok; }
      limine_editor_fix() { boot_probe limine_editor_fix; }
      limine_snapshots_ok() { boot_probe limine_snapshots_ok; }
      limine_snapshots_fix() { boot_probe limine_snapshots_fix; }
      main
    ' bash "$BIN" "$BOOT_PROBE_LOG" "$@"
}

conf_set "$ETC/machine.conf" boot portal
printf 'usr/lib/initcpio/hooks/some-other-hook\n' >"$LOG/lsinitcpio-output"
printf 'hostile portal UKI fixture\n' >"$SCRATCH_ROOT/boot/EFI/Linux/portal-probe.efi"
printf 'editor_enabled: yes\ndefault_entry: 2\n' >"$SCRATCH_ROOT/boot/limine.conf"
printf 'MAX_SNAPSHOT_ENTRIES=10\n' >"$LIMINE_DEFAULT"
stub limine ''
rm -f "$DENY_RULE"
: >"$ARGV_LOG"
: >"$BOOT_PROBE_LOG"
limine_conf_before="$(cat "$SCRATCH_ROOT/boot/limine.conf")"
limine_default_before="$(cat "$LIMINE_DEFAULT")"

out="$(run_assert_with_boot_probe_traps)"
st=$?
check_eq "$st" 0 "portal mode: assert exits 0 after repairing a non-boot lock with env -i and no HOME"
check_status "$out" "polkit-deny" "fixed" "portal mode: non-boot locks are still repaired"
check_status "$out" "boot-locks:portal" "skip" "portal mode: boot locks are honestly reported as skipped"
if grep -qE '^(ok|fixed|warn|FAIL|would-fix) +(boot-hook|limine-editor|limine-snapshots)$' <<<"$out"; then
  fail "portal mode: a UKI or Limine lock was reported"
else
  pass "portal mode: no UKI or Limine lock is reported green"
fi
check_eq "$(cat "$SCRATCH_ROOT/boot/limine.conf")" "$limine_conf_before" \
  "portal mode: limine.conf is unchanged"
check_eq "$(cat "$LIMINE_DEFAULT")" "$limine_default_before" \
  "portal mode: /etc/default/limine is unchanged"
if grep -qE "(objcopy|lsinitcpio|mkinitcpio|limine|$SCRATCH_ROOT/boot/limine.conf|$LIMINE_DEFAULT)" "$ARGV_LOG"; then
  fail "portal mode: assert invoked a UKI/Limine tool or passed a Limine path"
else
  pass "portal mode: assert records zero UKI/Limine calls and zero Limine paths"
fi
if [[ -s "$BOOT_PROBE_LOG" ]]; then
  fail "portal mode: entered boot evidence code: $(tr '\n' ' ' <"$BOOT_PROBE_LOG")"
else
  pass "portal mode: never calls find_uki or a Limine lock function"
fi

hook_exec="$(sed -n 's/^Exec = //p' "$ROOT_DIR/pacman/omarchy-kids.hook")"
check_eq "$hook_exec" "/usr/bin/omarchy-kids-assert --quiet" "pacman hook: exact assert invocation is unchanged"
read -r hook_bin hook_arg hook_extra <<<"$hook_exec"
check_eq "$hook_bin" "/usr/bin/omarchy-kids-assert" "pacman hook: invokes the installed assert command"
check_eq "$hook_arg" "--quiet" "pacman hook: passes only --quiet"
check_eq "$hook_extra" "" "pacman hook: has no hidden extra argv"
rm -f "$DENY_RULE"
: >"$ARGV_LOG"
: >"$BOOT_PROBE_LOG"
out="$(run_assert_with_boot_probe_traps "$hook_arg")"
st=$?
check_eq "$st" 0 "pacman hook path: portal-mode repair exits 0"
check_status "$out" "polkit-deny" "fixed" "pacman hook path: repairs the same non-boot lock"
if grep -qE "(objcopy|lsinitcpio|mkinitcpio|limine|$SCRATCH_ROOT/boot/limine.conf|$LIMINE_DEFAULT)" "$ARGV_LOG"; then
  fail "pacman hook path: portal mode touched UKI or Limine"
else
  pass "pacman hook path: portal mode records zero UKI/Limine access"
fi
if [[ -s "$BOOT_PROBE_LOG" ]]; then
  fail "pacman hook path: entered boot evidence code: $(tr '\n' ' ' <"$BOOT_PROBE_LOG")"
else
  pass "pacman hook path: never calls find_uki or a Limine lock function"
fi

conf_set "$ETC/machine.conf" boot invalid
rm -f "$DENY_RULE"
: >"$ARGV_LOG"
out="$(run_assert_clean 2>&1)"
st=$?
check_eq "$st" 1 "invalid mode: assert exits 1"
check_contains "$out" "trusted boot mode" "invalid mode: assert names the configuration failure"
if [[ ! -e "$DENY_RULE" ]]; then
  pass "invalid mode: assert mutates no non-boot lock"
else
  fail "invalid mode: assert changed state before rejecting the mode"
fi
if grep -qE "(objcopy|lsinitcpio|mkinitcpio|limine|$SCRATCH_ROOT/boot/limine.conf|$LIMINE_DEFAULT)" "$ARGV_LOG"; then
  fail "invalid mode: assert touched UKI or Limine"
else
  pass "invalid mode: assert stops before UKI or Limine access"
fi

echo "assert-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
