#!/bin/bash
# Tests the package migration lifecycle (R-BOOTMODE-1, R-BOOTMODE-6,
# R-BOOTMODE-11, R-BOOTMODE-12). The copied fixtures call the scriptlet
# through pre_upgrade, simulated package replacement, and post_upgrade.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok() { echo "ok   $*"; }
bad() {
  echo "FAIL $*"
  fail=1
}
check() {
  if [[ "$1" == "$2" ]]; then ok "$3"; else bad "$3 (want '$2', got '$1')"; fi
}
check_status() {
  if [[ "$1" == "$2" ]]; then ok "$3"; else bad "$3 (want '$2', got '$1')"; fi
}

if [[ -f "$ROOT/share/boot/omarchy_kids.conf" ]]; then
  ok "boot template is shipped under share/boot"
else
  bad "boot template is missing from share/boot"
fi

if [[ ! -e "$ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" ]]; then
  ok "active mkinitcpio drop-in is not in the source package"
else
  bad "source package still contains the active mkinitcpio drop-in"
fi

if grep -qF 'etc/mkinitcpio.conf.d/omarchy_kids.conf' "$ROOT/PKGBUILD"; then
  bad "PKGBUILD still owns the active drop-in"
else
  ok "PKGBUILD no longer owns the active drop-in"
fi

if [[ -f "$ROOT/.SRCINFO" ]] && grep -qF 'backup = etc/mkinitcpio.conf.d/omarchy_kids.conf' "$ROOT/.SRCINFO"; then
  bad ".SRCINFO still owns the active drop-in"
else
  ok ".SRCINFO no longer owns the active drop-in"
fi

if grep -qF 'share/boot/omarchy_kids.conf' "$ROOT/PKGBUILD" ||
  grep -qF 'cp -a share/. ' "$ROOT/PKGBUILD"; then
  ok "package() ships the inactive boot template"
else
  bad "package() does not ship the inactive boot template"
fi

if sh -n "$ROOT/omarchy-kids.install"; then
  ok "sh -n omarchy-kids.install"
else
  bad "omarchy-kids.install is not valid POSIX shell"
fi
# A missing shellcheck is not a rejection. The old single guard turned it into
# a `bad`, so this file failed on every box without shellcheck installed (a
# fresh Arch box, the try-omarchy VM) while passing on the dev Mac -- the
# opposite of AGENTS.md's "must pass on a real Omarchy box" rule.
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "SKIP packaging-test.sh: shellcheck not installed"
elif shellcheck -s sh "$ROOT/omarchy-kids.install"; then
  ok "ShellCheck validates omarchy-kids.install as POSIX sh"
else
  bad "ShellCheck rejects omarchy-kids.install"
fi

if grep -qF '_omarchy_kids_conf_bin="/usr/bin/omarchy-kids-conf"' "$ROOT/omarchy-kids.install" &&
  grep -qF 'machine migrate boot' "$ROOT/omarchy-kids.install" &&
  ! grep -qF 'machine get boot' "$ROOT/omarchy-kids.install" &&
  ! grep -qF 'machine set boot' "$ROOT/omarchy-kids.install" &&
  ! grep -q 'OMARCHY_KIDS_' "$ROOT/omarchy-kids.install"; then
  ok "scriptlet delegates the complete migration to the trusted locked command"
else
  bad "scriptlet bypasses the trusted locked boot migration"
fi

if grep -qF '"$R/share/boot/omarchy_kids.conf"' "$ROOT/scripts/deploy-boot-hook.sh" &&
  ! grep -qF '"$R/etc/mkinitcpio.conf.d/omarchy_kids.conf"' "$ROOT/scripts/deploy-boot-hook.sh"; then
  ok "deployment reads the package-owned boot template"
else
  bad "deployment still reads the deleted boot template path"
fi

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via trap EXIT, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

CASE_ROOT="$TMP/case"
INSTALL="$TMP/omarchy-kids.install"
BOOT_TREE="$TMP/boot-tree"
STUBS="$TMP/stubs"
mkdir -p "$STUBS/bin"
cp "$ROOT/omarchy-kids.install" "$INSTALL"
kids_tree "$BOOT_TREE" "$ROOT"
rm -f "$BOOT_TREE/lib"
cp -a "$ROOT/lib" "$BOOT_TREE/lib"
BOOT_CONF="$BOOT_TREE/bin/omarchy-kids-conf"
kids_set_const "$INSTALL" _omarchy_kids_legacy_dropin "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"
kids_set_const "$INSTALL" _omarchy_kids_migration_copy "$CASE_ROOT/run/omarchy-kids/legacy-boot.conf"
kids_set_const "$INSTALL" _omarchy_kids_conf_bin "$BOOT_CONF"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_MACHINE_CONF "$CASE_ROOT/etc/omarchy-kids/machine.conf"
kids_set_const "$BOOT_TREE/lib/boot-mode.sh" BOOT_MODE_LOCK "$CASE_ROOT/run/omarchy-kids/boot-mode.lock"
kids_id_stub "$STUBS" mark 0
kids_stub "$STUBS" groupadd <<'EOF'
#!/bin/bash
exit 0
EOF
kids_stub "$STUBS" systemctl <<'EOF'
#!/bin/bash
exit 0
EOF
kids_stub "$STUBS" findmnt <<'EOF'
#!/bin/bash
echo /dev/mapper/root
EOF
kids_stub "$STUBS" cryptsetup <<'EOF'
#!/bin/bash
[[ "${1:-}" == status ]]
EOF
kids_stub "$STUBS" chown <<'EOF'
#!/bin/bash
exit 0
EOF
REAL_FLOCK="$(command -v flock || true)"
LOCK_HELD="$TMP/packaging-boot-mode-held"
LOCK_OWNER="$TMP/packaging-boot-mode-owner"
kids_stub "$STUBS" flock <<EOF
#!/bin/bash
if [[ -n "$REAL_FLOCK" ]]; then
  exec "$REAL_FLOCK" "\$@"
fi
if [[ "\${1:-}" == -u ]]; then
  if [[ "\$(cat "$LOCK_OWNER" 2>/dev/null || true)" == "\$PPID" ]]; then
    rm -rf "$LOCK_HELD" "$LOCK_OWNER"
  fi
  exit 0
fi
for ((i = 0; i < 500; i++)); do
  if mkdir "$LOCK_HELD" 2>/dev/null; then
    printf '%s\n' "\$PPID" >"$LOCK_OWNER"
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
  "$CASE_ROOT" | "$CASE_ROOT"/*)
    case "\$format" in
      %u) echo 0 ;;
      %G | %Sg) echo root ;;
      %a) exec "$REAL_STAT" -c '%a' "\$target" ;;
      %Lp) exec "$REAL_STAT" -f '%Lp' "\$target" ;;
      %i) if [[ "\${1:-}" == -c ]]; then exec "$REAL_STAT" -c '%i' "\$target"; else exec "$REAL_STAT" -f '%i' "\$target"; fi ;;
      *) exit 1 ;;
    esac
    ;;
  *) exec "$REAL_STAT" "\$@" ;;
esac
EOF
chmod +x "$STUBS/stat"
BASE_PATH="$(kids_base_path "$TMP/base")"
PATH_VALUE="$STUBS/bin:$STUBS:$BASE_PATH"

reset_case() {
  rm -rf "$CASE_ROOT"
  mkdir -p "$CASE_ROOT/etc/omarchy-kids/kids" "$CASE_ROOT/etc/mkinitcpio.conf.d"
  chmod 0755 "$CASE_ROOT/etc/omarchy-kids" "$CASE_ROOT/etc/omarchy-kids/kids" "$CASE_ROOT/etc/mkinitcpio.conf.d"
}

run_upgrade() {
  PATH="$PATH_VALUE" sh -c '. "$1"; pre_upgrade; rm -f "$2"; post_upgrade' sh "$INSTALL" "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"
}

legacy_dropin() { cp "$ROOT/share/boot/omarchy_kids.conf" "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"; }
mode() { PATH="$PATH_VALUE" "$BOOT_CONF" machine get boot 2>/dev/null || true; }

# A legacy disk install must retain its drop-in after pacman replaces files.
reset_case
printf 'parent=mark\n' >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
printf 'band=6-8\n' >"$CASE_ROOT/etc/omarchy-kids/kids/kid-ada.conf"
chmod 0644 "$CASE_ROOT/etc/omarchy-kids/machine.conf" "$CASE_ROOT/etc/omarchy-kids/kids/kid-ada.conf"
legacy_dropin
run_upgrade
check_status "$?" 0 "legacy disk upgrade succeeds"
check "$(mode)" "disk" "legacy disk upgrade sets and reads back disk"
check "$(test -f "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" && echo present)" "present" "legacy disk upgrade restores the transition-owned drop-in"

# A legacy install without disk evidence migrates to portal and leaves no copy.
reset_case
printf 'parent=mark\n' >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
chmod 0644 "$CASE_ROOT/etc/omarchy-kids/machine.conf"
run_upgrade
check_status "$?" 0 "legacy portal upgrade succeeds"
check "$(mode)" "portal" "legacy portal upgrade sets and reads back portal"
check "$(test ! -e "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" && echo absent)" "absent" "legacy portal upgrade has no active drop-in"

# A valid existing disk setting still restores the old package file captured before replacement.
reset_case
printf 'parent=mark\nboot=disk\n' >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
chmod 0644 "$CASE_ROOT/etc/omarchy-kids/machine.conf"
legacy_dropin
run_upgrade
check_status "$?" 0 "valid disk upgrade succeeds"
check "$(mode)" "disk" "valid disk state remains authoritative"
check "$(test -f "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" && echo present)" "present" "valid disk state restores the captured drop-in"

# A valid portal setting removes a stale captured drop-in.
reset_case
printf 'parent=mark\nboot=portal\n' >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
chmod 0644 "$CASE_ROOT/etc/omarchy-kids/machine.conf"
legacy_dropin
run_upgrade
check_status "$?" 0 "valid portal upgrade succeeds"
check "$(mode)" "portal" "valid portal state remains authoritative"
check "$(test ! -e "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" && echo absent)" "absent" "valid portal state removes the captured drop-in"

# Unsafe ownership/mode is rejected by the real fixed-path reader.
reset_case
printf 'parent=mark\n' >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
chmod 0664 "$CASE_ROOT/etc/omarchy-kids/machine.conf"
run_upgrade
check_status "$?" 1 "unsafe machine.conf blocks migration"
check "$(mode)" "" "unsafe machine.conf has no boot mode"

# A malformed line cannot pass a weaker boot-key grep.
reset_case
printf 'parent=mark\nboot=disk\nmalformed\n' >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
chmod 0644 "$CASE_ROOT/etc/omarchy-kids/machine.conf"
legacy_dropin
run_upgrade
check_status "$?" 1 "ambiguous machine.conf blocks migration"
check "$(mode)" "" "ambiguous machine.conf has no boot mode"

# A portal transition arriving while the scriptlet restores disk evidence must
# wait for that whole read-and-restore section, then remove the disk artifact.
RACE_STUBS="$TMP/race-stubs"
mkdir -p "$RACE_STUBS"
cp "$STUBS/stat" "$RACE_STUBS/"
RESTORE_REACHED="$TMP/restore-reached"
ALLOW_RESTORE="$TMP/allow-restore"
WRITER_STARTED="$TMP/writer-started"
WRITER_WAITING="$TMP/writer-waiting"
WRITER_COMPLETED="$TMP/writer-completed"
REAL_INSTALL="$(command -v install)"
cat >"$RACE_STUBS/install" <<EOF
#!/bin/bash
if [[ "\${*: -1}" == "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" ]]; then
  touch "$RESTORE_REACHED"
  while [[ ! -e "$ALLOW_RESTORE" ]]; do sleep 0.02; done
fi
exec "$REAL_INSTALL" "\$@"
EOF
chmod +x "$RACE_STUBS/install"
cat >"$RACE_STUBS/flock" <<EOF
#!/bin/bash
if [[ "\${1:-}" != -u && -e "$WRITER_STARTED" ]]; then
  touch "$WRITER_WAITING"
fi
exec "$STUBS/bin/flock" "\$@"
EOF
chmod +x "$RACE_STUBS/flock"
RACE_PATH="$RACE_STUBS:$STUBS/bin:$STUBS:$BASE_PATH"

run_scriptlet_race() {
  local machine_conf="$1" label="$2" upgrade_pid writer_pid upgrade_rc writer_rc writer_order
  reset_case
  rm -f "$RESTORE_REACHED" "$ALLOW_RESTORE" "$WRITER_STARTED" "$WRITER_WAITING" "$WRITER_COMPLETED"
  rm -rf "$LOCK_HELD" "$LOCK_OWNER"
  printf '%s' "$machine_conf" >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
  printf 'band=6-8\n' >"$CASE_ROOT/etc/omarchy-kids/kids/kid-ada.conf"
  chmod 0644 "$CASE_ROOT/etc/omarchy-kids/machine.conf" "$CASE_ROOT/etc/omarchy-kids/kids/kid-ada.conf"
  legacy_dropin
  mkdir -p "$CASE_ROOT/run/omarchy-kids"
  chmod 0755 "$CASE_ROOT/run/omarchy-kids"

  PATH="$RACE_PATH" sh -c '. "$1"; pre_upgrade; rm -f "$2"; post_upgrade' sh \
    "$INSTALL" "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" &
  upgrade_pid=$!
  for _ in {1..250}; do
    [[ -e "$RESTORE_REACHED" ]] && break
    sleep 0.02
  done
  check "$(test -e "$RESTORE_REACHED" && echo reached)" "reached" "$label: scriptlet reaches disk restoration"

  (
    set -e
    PATH="$RACE_PATH"
    export PATH
    touch "$WRITER_STARTED"
    "$BOOT_CONF" machine set boot portal >/dev/null
    touch "$WRITER_COMPLETED"
    rm -f "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf"
  ) &
  writer_pid=$!
  for _ in {1..250}; do
    [[ -e "$WRITER_STARTED" ]] && break
    sleep 0.02
  done
  for _ in {1..250}; do
    [[ -e "$WRITER_WAITING" || -e "$WRITER_COMPLETED" ]] && break
    sleep 0.02
  done
  writer_order=stalled
  [[ -e "$WRITER_WAITING" ]] && writer_order=blocked
  [[ -e "$WRITER_COMPLETED" ]] && writer_order=early
  touch "$ALLOW_RESTORE"
  wait "$upgrade_pid"
  upgrade_rc=$?
  wait "$writer_pid"
  writer_rc=$?
  check_status "$upgrade_rc" 0 "$label: scriptlet upgrade succeeds"
  check_status "$writer_rc" 0 "$label: portal writer succeeds"
  check "$writer_order" "blocked" "$label: scriptlet holds the lock through disk restoration"
  check "$(mode)" "portal" "$label: later portal mode remains authoritative"
  check "$(test ! -e "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" && echo absent)" "absent" "$label: portal mode leaves no disk drop-in"
}

run_scriptlet_race $'parent=mark\nboot=disk\n' "existing disk mode race"
run_scriptlet_race $'parent=mark\n' "first migration race"

# post_remove remains harmless and does not erase transition-owned state.
reset_case
printf 'parent=mark\nboot=disk\n' >"$CASE_ROOT/etc/omarchy-kids/machine.conf"
chmod 0644 "$CASE_ROOT/etc/omarchy-kids/machine.conf"
legacy_dropin
PATH="$PATH_VALUE" sh -c '. "$1"; post_remove' sh "$INSTALL" >/dev/null
check_status "$?" 0 "post_remove fixture succeeds"
check "$(test -f "$CASE_ROOT/etc/mkinitcpio.conf.d/omarchy_kids.conf" && echo present)" "present" "post_remove leaves transition-owned boot state"

echo "packaging-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit "$fail"
