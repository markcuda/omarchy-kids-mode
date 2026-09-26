#!/bin/bash
# Shared helpers for the VM acceptance harness (SPEC.md R-BUILD-3, the V1-V7 checks, the §8
# acceptance list). Sourced by every test/live/NN-*.sh scenario and by test/live/all — never run
# directly, and never on its own does anything but define functions and load config.
#
# This runs on the developer's own machine (a Mac; bash 3.2 here, same as the box
# test/shell.d/session-test.sh's header comment calls out — no associative arrays, no
# `${var,,}`/`${var^^}`) and drives the test laptop's VM entirely over SSH and QMP, the same
# recipe docs/vm.md and scripts/v1-two-sessions.sh / v6-limine.sh already use. Nothing here
# writes to this machine's own /etc (AGENTS.md rule 8) — every real write happens on the VM, over
# ssh, as root only through vmroot's explicit sudo, and the VM itself is only ever stopped via
# `vm-run.sh stop` (never a hard `quit` — docs/vm.md: a quit right after a write can leave
# zero-length files).

set -uo pipefail

LIVE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_REPO_ROOT="$(cd "$LIVE_LIB_DIR/../.." && pwd)"
if [[ "${OMARCHY_KIDS_VM_DRIVER_LOCKED:-0}" != 1 ]]; then
  exec "$LIVE_REPO_ROOT/scripts/vm-driver-lock" "$0" "$@"
fi

# --- config: env vars, optionally loaded from a sibling config.env (gitignored;
# config.env.example is the checked-in template) — a CI job can just export every LIVE_* var
# instead and skip the file entirely. -------------------------------------------------------
if [[ -f "$LIVE_LIB_DIR/config.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$LIVE_LIB_DIR/config.env"
  set +a
fi

LIVE_SSH_CFG="${LIVE_SSH_CFG:-$HOME/.ssh/omarchy-kids-vm-config}"
LIVE_REMOTE_REPO="${LIVE_REMOTE_REPO:-omarchy-kids-sandbox}"
LIVE_OWNER_PASSWORD="${LIVE_OWNER_PASSWORD:-omarchy}"
LIVE_OWNER_ACCOUNT="${LIVE_OWNER_ACCOUNT:-kid-vm}"
LIVE_KID1_ACCOUNT="${LIVE_KID1_ACCOUNT:-kid-cy}"
LIVE_KID1_NAME="${LIVE_KID1_NAME:-Cy}"
LIVE_KID1_PASSWORD="${LIVE_KID1_PASSWORD:-kidpass-cy}"
LIVE_KID1_LIGHTS_OUT_RESET="${LIVE_KID1_LIGHTS_OUT_RESET:-21:00}"
LIVE_WIZARD_KID_NAME="${LIVE_WIZARD_KID_NAME:-Ada}"
LIVE_WIZARD_KID_AVATAR="${LIVE_WIZARD_KID_AVATAR:-owl}"
LIVE_WIZARD_KID_PASSWORD="${LIVE_WIZARD_KID_PASSWORD:-kidpass-wiz}"
LIVE_OUT_DIR="${LIVE_OUT_DIR:-$LIVE_REPO_ROOT/test/live/out}"
LIVE_DESTRUCTIVE="${LIVE_DESTRUCTIVE:-0}"
LIVE_BOOT_DEADLINE="${LIVE_BOOT_DEADLINE:-180}"

mkdir -p "$LIVE_OUT_DIR"

# --- ssh / qmp ---------------------------------------------------------------------------

# air CMD... — runs CMD on the test laptop.
# shellcheck disable=SC2033 # false positive: "air" here is the ssh(1) Host alias, not a call
# to the shell function of the same name being defined on this line — same pattern already in
# scripts/v1-two-sessions.sh and scripts/v6-limine.sh.
air() { ssh -T -F "$LIVE_SSH_CFG" air "$@"; }

# vm CMD... — runs CMD in the VM as its unprivileged owner account. Short connect timeout: a VM
# that isn't up yet should fail fast, not hang whatever polling loop called this.
vm() { ssh -T -F "$LIVE_SSH_CFG" -o ConnectTimeout=5 vm "$@"; }

# vm_tty CMD — like vm, but forces a pty (`ssh -tt`). sudo's authentication ticket is scoped per
# tty (docs/vm.md), so a sequence that warms sudo with `sudo -S -v` and then relies on that ticket
# for later `sudo` calls (the wizard's Apply step, docs/wizard.md) has to run as one `-tt` command,
# not as separate `vm` calls that would each get sudo's own, cold ticket.
vm_tty() { ssh -tt -F "$LIVE_SSH_CFG" -o ConnectTimeout=5 vm "$@"; }

# vmroot CMD — runs CMD in the VM as root. The password is fed only to sudo's stdin; the target
# command gets /dev/null, so a cached sudo ticket cannot leak the unused password into it.
vmroot() {
  local command="$1" quoted
  quoted="$(printf '%q' "$command")"
  printf '%s\n' "$LIVE_OWNER_PASSWORD" |
    ssh -T -F "$LIVE_SSH_CFG" -o ConnectTimeout=5 vm \
      "sudo -S -p '' -v 2>/dev/null && sudo -n -p '' bash -c $quoted </dev/null"
}

# vm_write_file PATH — atomically writes stdin to a restrictive remote file. The data never
# appears in an SSH command string; callers use a here-document or redirected descriptor.
vm_write_file() {
  local path="$1" dir base qpath qtemplate
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  qpath="$(printf '%q' "$path")"
  qtemplate="$(printf '%q' "$dir/.$base.XXXXXX")"
  ssh -T -F "$LIVE_SSH_CFG" -o ConnectTimeout=5 vm \
    "set -u; path=$qpath; [ ! -L \"\$path\" ] || exit 1; tmp=\$(mktemp $qtemplate) || exit 1; cleanup() { rm -f \"\$tmp\"; }; abort() { cleanup; exit 143; }; trap cleanup EXIT; trap abort HUP TERM; trap 'cleanup; exit 130' INT; umask 077; cat >\"\$tmp\" || exit \$?; chmod 600 \"\$tmp\" || exit \$?; mv -fT -- \"\$tmp\" \"\$path\" || exit \$?; trap - EXIT HUP INT TERM"
}

# qmp ARGS... — talks to the VM's QEMU monitor via scripts/vm-qmp.sh on air: shot/type/enter/
# key/status/quit (scripts/vm-qmp.sh's own usage line).
qmp() {
  local action="${1:-}"
  if [[ "$action" == type ]]; then
    if (($# >= 2)); then
      printf '%s' "$2"
    else
      cat
    fi | air "cd ~/$LIVE_REMOTE_REPO && bash scripts/vm-qmp.sh type"
  else
    air "cd ~/$LIVE_REMOTE_REPO && bash scripts/vm-qmp.sh $*"
  fi
}

# shot NAME — screenshots the VM console to $LIVE_OUT_DIR/NAME.png. Prints "NAME.png" (just the
# basename) on success so test/live/all can collect that line straight into the report's
# screenshot column, and callers can do `shot foo || fail "..."` for the same reason every other
# helper here returns non-zero rather than dying on its own.
shot() {
  local name="$1"
  qmp shot "/home/omarky-air/vm/$name.png" >/dev/null || return 1
  scp -q -F "$LIVE_SSH_CFG" "air:/home/omarky-air/vm/$name.png" "$LIVE_OUT_DIR/$name.png" || return 1
  echo "$name.png"
}

# state — a one-screen debug snapshot of what's live in the VM right now: sessions other than the
# ssh/console owner's own, any greeter process, the last few SDDM journal lines. Not an assertion
# — scenarios call this around a failing step so the log shows what was actually going on.
state() {
  vmroot "loginctl list-sessions --no-legend | grep -v ' $LIVE_OWNER_ACCOUNT ' 2>/dev/null; pgrep -af 'sddm-greeter-qt[6]' | cut -c1-80; journalctl -b --no-pager -o cat -u sddm 2>/dev/null | tail -3 | cut -c1-150"
}

# --- boot / portal -----------------------------------------------------------------------

# boot_with PASSWORD [LABEL] — stop the VM, boot it fresh, wait the ~35s docs/vm.md says the disk
# prompt needs (this part isn't itself pollable: there's no ssh yet and no QMP query that reports
# "the disk prompt is up" short of screenshotting and reading it), type PASSWORD there, then poll
# ssh with a deadline rather than a fixed sleep for however long the actual boot after unlock
# takes. Returns 1 if ssh never answers within LIVE_BOOT_DEADLINE seconds.
boot_with() {
  local password="$1" label="${2:-boot}" waited=0
  air "cd ~/$LIVE_REMOTE_REPO && bash scripts/vm-run.sh stop; sleep 2; bash scripts/vm-run.sh boot" >/dev/null 2>&1
  sleep 35
  qmp type "$password" >/dev/null
  qmp enter >/dev/null
  while ((waited < LIVE_BOOT_DEADLINE)); do
    vm true 2>/dev/null && {
      echo "vm ssh reachable after $((waited + 35))s ($label)"
      return 0
    }
    sleep 5
    waited=$((waited + 5))
    # Under load the disk prompt can appear after the first try, and sshd comes up long before
    # any greeter would, so an unreachable VM at 30 s intervals is still at the prompt: retype.
    if ((waited % 30 == 0)); then
      qmp type "$password" >/dev/null
      qmp enter >/dev/null
    fi
  done
  echo "vm never came up booting with $label's password" >&2
  return 1
}

# portal_conf_unquote VALUE — decodes the QSettings escapes that are present
# in a quoted raw theme.conf.user value.
portal_conf_unquote() {
  local value="$1" decoded="" ch hex out="" i=0
  case "$value" in
    \"*\")
      value="${value#\"}"
      value="${value%\"}"
      ;;
    *)
      printf '%s\n' "$value"
      return
      ;;
  esac
  while ((i < ${#value})); do
    ch="${value:i:1}"
    i=$((i + 1))
    if [[ "$ch" != $'\\' ]]; then
      out+="$ch"
      continue
    fi
    ((i < ${#value})) || break
    ch="${value:i:1}"
    i=$((i + 1))
    case "$ch" in
      0) ;;
      a) out+=$'\a' ;;
      b) out+=$'\b' ;;
      f) out+=$'\f' ;;
      n) out+=$'\n' ;;
      r) out+=$'\r' ;;
      t) out+=$'\t' ;;
      v) out+=$'\v' ;;
      '"' | $'\\') out+="$ch" ;;
      x)
        hex=""
        while ((i < ${#value})) && [[ "${value:i:1}" =~ ^[0-9A-Fa-f]$ ]]; do
          hex+="${value:i:1}"
          i=$((i + 1))
        done
        [[ -n "$hex" ]] || continue
        printf -v decoded '%b' "\\x$hex"
        out+="$decoded"
        ;;
    esac
  done
  printf '%s\n' "$out"
}

# portal_conf_decode_field VALUE — reverses posture_portal_field_encode
# after record and field splitting have already happened.
portal_conf_decode_field() {
  local value="$1"
  value="${value//%3A/:}"
  value="${value//%2C/,}"
  value="${value//%25/%}"
  printf '%s\n' "$value"
}

# portal_conf_field CONF KEY — reads one [General] value as QSettings does.
portal_conf_field() {
  local conf="$1" key="$2" value
  value="$(awk -F= -v key="$key" '$1 == key { print substr($0, length($1) + 2); exit }' <<<"$conf")"
  portal_conf_unquote "$value"
}

# portal_kid_index KIDS_CSV ACCOUNT — pure, no ssh: KIDS_CSV is theme.conf.user's "kids=" value
# (share/sddm-theme's own posture_portal_conf_text), "account:name:avatar,account:name:avatar,...".
# Prints ACCOUNT's 0-based position among the kid tiles, or fails (exit 1) if it isn't listed.
portal_kid_index() {
  local csv acct="$2" i=0 entry a old_ifs=$IFS
  csv="$(portal_conf_unquote "$1")"
  IFS=','
  # shellcheck disable=SC2086 # word-splitting on the comma is the point
  set -- $csv
  IFS=$old_ifs
  for entry in "$@"; do
    a="${entry%%:*}"
    a="$(portal_conf_decode_field "$a")"
    if [[ "$a" == "$acct" ]]; then
      echo "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# portal_kid_name KIDS_CSV ACCOUNT — prints one decoded display name.
portal_kid_name() {
  local csv acct="$2" entry account rest name old_ifs=$IFS
  csv="$(portal_conf_unquote "$1")"
  IFS=','
  # shellcheck disable=SC2086 # word-splitting on the record comma is the point
  set -- $csv
  IFS=$old_ifs
  for entry in "$@"; do
    account="$(portal_conf_decode_field "${entry%%:*}")"
    rest="${entry#*:}"
    name="${rest%%:*}"
    if [[ "$account" == "$acct" ]]; then
      portal_conf_decode_field "$name"
      return 0
    fi
  done
  return 1
}

# portal_kid_count KIDS_CSV — pure, no ssh: how many comma-separated entries
# a portal config field lists.
portal_kid_count() {
  local csv old_ifs=$IFS
  csv="$(portal_conf_unquote "$1")"
  IFS=','
  # shellcheck disable=SC2086
  set -- $csv
  IFS=$old_ifs
  echo "$#"
}

# portal_conf_accounts KIDS_CSV PARENTS_CSV — the portal's configured order:
# profiled kids first, then the explicit parent allowlist.
portal_conf_accounts() {
  local csv old_ifs=$IFS entry
  local -a entries
  {
    for csv in "$@"; do
      csv="$(portal_conf_unquote "$csv")"
      IFS=',' read -ra entries <<<"$csv"
      IFS=$old_ifs
      for entry in "${entries[@]}"; do
        [[ -n "$entry" ]] && portal_conf_decode_field "${entry%%:*}"
      done
    done
  } | awk '!seen[$0]++'
}

# portal_conf_tile_count KIDS_CSV PARENTS_CSV — count the tiles the producer
# asks the consumer to render.
portal_conf_tile_count() {
  local count=0 account
  while IFS= read -r account; do
    [[ -n "$account" ]] && count=$((count + 1))
  done < <(portal_conf_accounts "$1" "$2")
  echo "$count"
}

# portal_parse_tile_report REPORT — extracts the finalized QML count and its
# kid/parent breakdown from a journal line. Pure; unit-tested in
# test/shell.d/live-lib-test.sh.
portal_parse_tile_report() {
  local report="$1"
  local pattern='portal: ([0-9]+) tiles \(kids=([0-9]+) parents=([0-9]+)\)'
  if [[ "$report" =~ $pattern ]]; then
    printf '%s %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi
  return 1
}

# portal_live_tile_counts — reads the finalized QML count from the current
# boot's greeter journal. It does not reconstruct the rendered tile list.
# The greeter's own stdout carries the syslog identifier `sddm-greeter-qt6`, not the `sddm` unit
# the daemon logs under, so this reads by identifier: `-u sddm` never matched the line and the
# check silently passed nothing to parse (found live 2026-09-04, issue #104).
portal_live_tile_counts() {
  local line parsed
  line="$(vmroot "journalctl -b --no-pager -o cat -t sddm-greeter-qt6 2>/dev/null | grep -E 'portal: [0-9]+ tiles \\(kids=[0-9]+ parents=[0-9]+\\)' | tail -1")" || return 1
  [[ -n "$line" ]] || return 1
  parsed="$(portal_parse_tile_report "$line")" || return 1
  printf '%s\n' "$parsed"
}

# portal_live_config_tile_count — expected count from the producer-owned
# config only. The observed value comes separately from portal_live_tile_counts.
portal_live_config_tile_count() {
  local conf kids parents
  conf="$(vmroot "cat /usr/share/sddm/themes/omarchy-kids/theme.conf.user")" || return 1
  kids="$(portal_conf_field "$conf" kids)"
  parents="$(portal_conf_field "$conf" parents)"
  portal_conf_tile_count "$kids" "$parents"
}

# portal_login KID PASSWORD [DEADLINE] — at the portal (the greeter showing the kid tiles),
# navigate to KID's tile, log in, and poll for the session to appear.
#
# Navigation is index math, not a remembered cursor position. share/sddm-theme/Main.qml builds
# its tile list as `kids.concat(parents)` (finishLoadingUsers()), kid tiles in theme.conf.user's
# own "kids=" order (which is $KIDS_DIR/*.conf glob order — alphabetical by account, see
# bin/omarchy-kids-provision's portal_conf_entries()), parent tile always last; its Left/Right
# handlers (Keys.onLeftPressed/onRightPressed, same file) clamp at the ends instead of wrapping.
# So sending Left more times than there are tiles is always safe — it just stops at tile 0 — which
# makes "Esc (out of password mode, if one was left open from a previous run), then Left enough
# times to guarantee tile 0, then Right exactly to the target index" land on the right tile no
# matter where SDDM's own `userModel.lastUser` preselection left the highlight. Read from the QML
# source, not yet confirmed live against more than two kid tiles — see docs/live-tests.md.
portal_login() {
  local kid="$1" password="$2" deadline="${3:-90}"
  local tiles index total waited=0 i conf kids parents
  # Main.qml filters SDDM's regular-account model through these producer-owned
  # fields, preserving kids first and parents last.
  conf="$(vmroot "cat /usr/share/sddm/themes/omarchy-kids/theme.conf.user")" || return 1
  kids="$(portal_conf_field "$conf" kids)"
  parents="$(portal_conf_field "$conf" parents)"
  tiles="$(portal_conf_accounts "$kids" "$parents")"
  index="$(portal_tile_index "$tiles" "$kid")" || {
    echo "portal_login: $kid is not among the greeter's accounts ($(echo "$tiles" | tr '\n' ' '))" >&2
    return 1
  }
  total="$(portal_conf_tile_count "$kids" "$parents")"

  qmp key esc >/dev/null # close a password field left open by an earlier attempt
  sleep 0.5
  for ((i = 0; i < total; i++)); do qmp key left >/dev/null; done # Left clamps at the first tile
  for ((i = 0; i < index; i++)); do qmp key right >/dev/null; done
  qmp enter >/dev/null
  sleep 1
  qmp type "$password" >/dev/null
  qmp enter >/dev/null

  while ((waited < deadline)); do
    assert_session "$kid" 0 && return 0
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}

# portal_tile_index LIST ACCOUNT — 0-based position of ACCOUNT in LIST (one account per line, in
# the greeter's sorted order). Pure; unit-tested in test/shell.d/live-lib-test.sh.
portal_tile_index() {
  local list="$1" acct="$2" i=0 a
  while IFS= read -r a; do
    [[ -z "$a" ]] && continue
    if [[ "$a" == "$acct" ]]; then
      echo "$i"
      return 0
    fi
    i=$((i + 1))
  done <<<"$list"
  return 1
}

# portal_reset [DEADLINE] — gets a fresh greeter on screen the only way SDDM 0.21 on Omarchy 4.0.2
# allows (docs/exit.md, docs/phase1/V1.md): a clean compositor exit of whatever seat0 session is
# active. SwitchToGreeter over D-Bus fails with HELPER_TTY_ERROR and, on the laptop, revoked the
# input devices; a hard terminate leaves SDDM with no greeter at all. If nothing is on seat0 (a
# black screen), restart SDDM (the owner's stock autologin fires) and exit that session cleanly.
portal_reset() {
  local deadline="${1:-45}" who sessions waited=0
  command -v jq >/dev/null 2>&1 || {
    echo "portal_reset: jq is required on the harness host to inspect Hyprland instances" >&2
    return 1
  }
  # Right after a boot the seat may still be empty while the owner's autologin (a recorded
  # parent slot, docs/boot.md) is starting: give it a moment before treating it as black.
  while :; do
    sessions="$(vmroot "loginctl list-sessions --no-legend" 2>/dev/null)" || return 1
    who="$(awk '$4=="seat0"{print $3; exit}' <<<"$sessions" | tr -d '[:space:]')"
    [[ -n "$who" || $waited -ge 45 ]] && break
    sleep 5
    waited=$((waited + 5))
  done
  case "$who" in
    sddm) : ;; # the greeter is already up
    "")
      vmroot "systemctl restart sddm" || return 1
      vmroot "sleep 16" || return 1
      who="$LIVE_OWNER_ACCOUNT"
      portal_clean_exit "$who" || return 1
      ;;
    *) portal_clean_exit "$who" || return 1 ;;
  esac
  assert_greeter "$deadline"
}

# portal_clean_exit ACCOUNT [DEADLINE] — waits for one live Hyprland instance on wayland-1, then
# asks that account's compositor to exit through its Lua dispatcher (docs/exit.md).
portal_clean_exit() {
  local acct="$1" deadline="${2:-45}" acct_q uid inventory count sig sig_q waited=0
  command -v jq >/dev/null 2>&1 || {
    echo "portal_clean_exit: jq is required on the harness host to inspect Hyprland instances" >&2
    return 1
  }
  acct_q="$(printf '%q' "$acct")"
  uid="$(vmroot "env -i PATH=/usr/bin:/bin /usr/bin/id -u $acct_q")" || return 1
  [[ "$uid" =~ ^[0-9]+$ ]] || return 1
  while :; do
    inventory="$(vmroot "runuser -u $acct_q -- env XDG_RUNTIME_DIR=/run/user/$uid WAYLAND_DISPLAY=wayland-1 LANG=C.UTF-8 /usr/bin/hyprctl instances -j" 2>/dev/null)" || inventory=
    count="$(jq -r --arg display wayland-1 '[.[] | select(.wl_socket == $display)] | length' <<<"$inventory" 2>/dev/null)" || count=
    if [[ "$count" == 1 ]]; then
      sig="$(jq -r --arg display wayland-1 '.[] | select(.wl_socket == $display) | .instance' <<<"$inventory" 2>/dev/null)" || return 1
      [[ -n "$sig" && "$sig" != null ]] || return 1
      sig_q="$(printf '%q' "$sig")"
      vmroot "runuser -u $acct_q -- env XDG_RUNTIME_DIR=/run/user/$uid HYPRLAND_INSTANCE_SIGNATURE=$sig_q WAYLAND_DISPLAY=wayland-1 /usr/bin/hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1" || return 1
      # A dispatch hyprctl accepted is not a compositor that has gone: it reports
      # success while the instance outlives it, and the old helper returned 0 on
      # that alone (sandbox #134 -- a gate then read "clean exit" from a session
      # that was still there). Wait for the instance to leave wayland-1, and say
      # so if it does not, rather than reporting an exit that did not happen.
      local gone_waited=0 after_inventory after_count
      while ((gone_waited < deadline)); do
        after_inventory="$(vmroot "runuser -u $acct_q -- env XDG_RUNTIME_DIR=/run/user/$uid WAYLAND_DISPLAY=wayland-1 LANG=C.UTF-8 /usr/bin/hyprctl instances -j" 2>/dev/null)" || after_inventory=
        after_count="$(jq -r --arg display wayland-1 '[.[] | select(.wl_socket == $display)] | length' <<<"$after_inventory" 2>/dev/null)" || after_count=
        [[ "$after_count" == 0 ]] && return 0
        sleep 5
        gone_waited=$((gone_waited + 5))
      done
      echo "portal_clean_exit: the dispatch was accepted but $acct's compositor is still on wayland-1 after ${deadline}s" >&2
      return 1
    fi
    ((count > 1)) && return 1
    ((waited >= deadline)) && return 1
    sleep 5
    waited=$((waited + 5))
  done
}

# --- build / install ---------------------------------------------------------------------

# vm_ready DEADLINE — waits until the VM answers ssh, retyping the disk password every 30 s in
# case it is still at the LUKS prompt. A scenario that starts while the VM is mid-boot (the
# previous gate just rebooted it) used to fail its build step on "banner exchange" and then
# report every later check as broken; waiting here keeps a failure meaning what it says.
vm_ready() {
  local deadline="${1:-180}" waited=0
  while ((waited < deadline)); do
    vm true 2>/dev/null && return 0
    sleep 5
    waited=$((waited + 5))
    ((waited % 30 == 0)) && {
      qmp type "$LIVE_OWNER_PASSWORD" >/dev/null 2>&1
      qmp enter >/dev/null 2>&1
    }
  done
  echo "vm_ready: the vm never answered ssh within ${deadline}s" >&2
  return 1
}

# build_install — pulls the latest commit on air, rebuilds the package with makepkg, copies the
# built package down to this machine's scratch out dir and back up to the VM, installs it with
# `pacman -U`, `sync`s the VM's disks (docs/vm.md: a `vm-run.sh stop` right after a write that
# hasn't hit disk yet has, once, left zero-length files), then gates on `pacman -Qkk omarchy-kids`'s
# own exit code — pacman -Qk exits non-zero if any installed file fails its content/mtime/
# permission check, a cheaper and more reliable "did this land intact" signal than parsing text.
build_install() {
  vm_ready 180 || return 1
  air "cd ~/$LIVE_REMOTE_REPO && git pull -q && rm -rf pkg src omarchy-kids-*.pkg.tar.zst && makepkg -sf --noconfirm >/dev/null 2>&1" ||
    {
      echo "build_install: makepkg failed on air" >&2
      return 1
    }
  scp -q -F "$LIVE_SSH_CFG" "air:~/$LIVE_REMOTE_REPO/omarchy-kids-*.pkg.tar.zst" "$LIVE_OUT_DIR/" ||
    {
      echo "build_install: could not fetch the built package" >&2
      return 1
    }
  scp -q -F "$LIVE_SSH_CFG" "$LIVE_OUT_DIR"/omarchy-kids-*.pkg.tar.zst vm:/tmp/ ||
    {
      echo "build_install: could not copy the package to the vm" >&2
      return 1
    }
  vmroot 'pacman -U --noconfirm /tmp/omarchy-kids-*.pkg.tar.zst && sync' >"$LIVE_OUT_DIR/live-pacman-U.log" 2>&1 ||
    {
      echo "build_install: pacman -U failed" >&2
      return 1
    }
  vmroot 'pacman -Qkk omarchy-kids' >"$LIVE_OUT_DIR/live-pacman-Qkk.log" 2>&1
}

# --- assertions --------------------------------------------------------------------------
# Every one of these is a polling loop with a deadline, not a fixed sleep: DEADLINE=0 means "check
# once, right now" (the loop body always runs at least once before the deadline test).

# assert_session KID [DEADLINE=60] — KID has a live loginctl session within DEADLINE seconds.
# A seat session of class "user" only: the harness's own ssh logins are sessions too (seat "-"),
# and scenario 20 once passed on one of those while the screen showed the portal.
seat_session_filter() { printf "awk -v u='%s' '\$3 == u && \$4 == \"seat0\" && \$6 == \"user\"' | grep -q ." "$1"; }

assert_session() {
  local kid="$1" deadline="${2:-60}" waited=0
  while :; do
    vmroot "loginctl list-sessions --no-legend | $(seat_session_filter "$kid")" 2>/dev/null && return 0
    ((waited >= deadline)) && return 1
    sleep 5
    waited=$((waited + 5))
  done
}

# wait_kid_ready KID [DEADLINE=60] — the session exists before its binds do: wait for the Level 1
# launcher to be running (exec-once has run, so the Super-tap bind is live), then settle.
wait_kid_ready() {
  local kid="$1" deadline="${2:-60}" waited=0
  while :; do
    vmroot "pgrep -u '$kid' -f 'omarchy-kids/launcher/shell.qml' >/dev/null" 2>/dev/null && {
      sleep 3
      return 0
    }
    ((waited >= deadline)) && return 1
    sleep 5
    waited=$((waited + 5))
  done
}

# kid_budget_headroom KID — earlier scenarios may have spent today's budget, and root now ends a
# session whose budget is gone; give KID room for this run. kid_budget_restore puts it back.
kid_budget_headroom() {
  KID_BUDGET_BEFORE="$(vmroot "omarchy-kids-conf get '$1' budget_min" 2>/dev/null | tr -d '[:space:]')"
  vmroot "omarchy-kids-conf set '$1' budget_min 600 >/dev/null"
}
kid_budget_restore() {
  [[ -n "${KID_BUDGET_BEFORE:-}" ]] && vmroot "omarchy-kids-conf set '$1' budget_min $KID_BUDGET_BEFORE >/dev/null"
}

# notify_pair_client KEY_PATH — the shared setup for the notification scenarios (70, 72, 73):
# enable notifications on the VM, start the relay (the tick would, but these want it up before a
# kid is live), open a pairing window, pair the scripted client
# (test/live/clients/notify-client.py) through /v1/pair with its key at KEY_PATH, and confirm the
# device is in the registry. Sets NOTIFY_DEVICE_ID on success; on any step it calls fail() and
# returns non-zero, and the caller skips whatever needed the pairing.
notify_pair_client() {
  local key_path="$1" pair_out uri token id reply
  vmroot "omarchy-kids-notify enable --apply" >/dev/null 2>&1 &&
    ok "notifications enabled (the relay certificate is minted)" ||
    {
      fail "omarchy-kids-notify enable failed"
      return 1
    }
  vmroot "systemctl start omarchy-kids-relayd.service" >/dev/null 2>&1 &&
    ok "relay started" || {
    fail "could not start the relay"
    return 1
  }
  pair_out="$(vmroot "omarchy-kids-notify pair --apply" 2>&1)"
  uri="$(printf '%s\n' "$pair_out" | grep -o 'omarchy-kids://pair[^ ]*' | head -1)"
  token="$(printf '%s' "$uri" | sed -n 's/.*[?&]token=\([^&]*\).*/\1/p')"
  # The pairing record's own id (d-xxxxxxxx) is the one authd looks up; the scenario pairs under
  # that, not one of its own.
  id="$(printf '%s' "$uri" | sed -n 's/.*[?&]id=\([^&]*\).*/\1/p')"
  if [[ -n "$token" && -n "$id" ]]; then
    ok "pairing window opened for $id"
  else
    fail "pair-start printed no id/token: $pair_out"
    return 1
  fi
  # The client is copied in, never run from the runner: it must reach the relay on the VM's own
  # localhost, which the unit's fence allows. vm_write_file runs as the owner, so /tmp, not /root.
  if vm_write_file /tmp/notify-client.py <"$LIVE_LIB_DIR/clients/notify-client.py"; then
    ok "client copied to the vm"
  else
    fail "could not copy the client to the vm"
    return 1
  fi
  reply="$(vmroot "python3 /tmp/notify-client.py pair --key $key_path --id $id --token $token" 2>&1)"
  if [[ "$reply" == *"pair 200"* ]]; then
    ok "the client paired through /v1/pair ($reply)"
  else
    fail "pairing failed: $reply"
    return 1
  fi
  vmroot "omarchy-kids-devices list" 2>/dev/null | grep -q "$id" &&
    ok "the device is in the registry" || {
    fail "the paired device is not in the registry"
    return 1
  }
  # shellcheck disable=SC2034 # read by the sourcing scenario after this returns
  NOTIFY_DEVICE_ID="$id"
  return 0
}

# notify_stop — the shared teardown: disable notifications (which revokes every device and removes
# the certificate) so no listener is left and no paired key survives the scenario.
notify_stop() {
  vmroot "omarchy-kids-notify disable --apply" >/dev/null 2>&1 &&
    ok "notifications disabled and the device revoked" || fail "disable failed"
}

# assert_no_session KID [DEADLINE=30] — KID has no live loginctl session within DEADLINE seconds.
assert_no_session() {
  local kid="$1" deadline="${2:-30}" waited=0
  while :; do
    vmroot "loginctl list-sessions --no-legend | $(seat_session_filter "$kid")" 2>/dev/null || return 0
    ((waited >= deadline)) && return 1
    sleep 5
    waited=$((waited + 5))
  done
}

# assert_greeter [DEADLINE=60] — an sddm-greeter process is running within DEADLINE seconds.
assert_greeter() {
  local deadline="${1:-60}" waited=0
  while :; do
    vmroot "pgrep -f 'sddm-greeter-qt[6]' >/dev/null 2>&1" && return 0
    ((waited >= deadline)) && return 1
    sleep 5
    waited=$((waited + 5))
  done
}

# --- reporting: PASS/FAIL lines and the Markdown table ------------------------------------
# Same idiom test/shell.d's own check() functions use (e.g. test/shell.d/conf-test.sh): "ok   "/
# "FAIL " lines for each assertion inside a scenario, and one final "PASS <name>"/"FAIL <name>"
# line test/live/all greps out to build its report and to decide whether to stop on -k.

LIVE_FAIL=0

ok() { echo "ok   $1"; }
fail() {
  echo "FAIL $1"
  LIVE_FAIL=1
}

# check GOT WANT LABEL
check() {
  if [[ "$1" == "$2" ]]; then ok "$3"; else fail "$3 (want '$2', got '$1')"; fi
}

# scenario_result NAME — call this last, exactly once, in every test/live/NN-*.sh. Prints the
# scenario's final PASS/FAIL line and exits with the matching status.
scenario_result() {
  local name="$1"
  if [[ "$LIVE_FAIL" -eq 0 ]]; then
    echo "PASS $name"
    exit 0
  else
    echo "FAIL $name"
    exit 1
  fi
}

# report_header — the fixed Markdown table header test/live/all's report starts with.
report_header() {
  printf '| Scenario | Result | Screenshots |\n| --- | --- | --- |'
}

# report_row NAME RESULT SHOTS_CSV — one Markdown table row. SHOTS_CSV is a comma-joined list of
# screenshot filenames, or empty (rendered as an em dash — no screenshots for this scenario).
report_row() {
  local name="$1" result="$2" shots="${3:-}"
  printf '| %s | %s | %s |' "$name" "$result" "${shots:-—}"
}
