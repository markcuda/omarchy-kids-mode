# shellcheck shell=bash
# lib/kids.sh -- shared helpers formerly duplicated across bin/omarchy-kids-*
# commands: dry-run preview, band/home-dir lookups, LUKS/stat wrappers, the
# sibling-binary resolver, the kid roster, portal entries, and the exit/ask
# modal's pidfile guard. Not meant to be executed directly; source it.

# is_root -- the one uid check in this package. No environment override:
# nothing a kid's session can set may decide whether a root check happens
# (AGENTS.md, "The trust boundary").
is_root() { [[ "$(id -u)" == "0" ]]; }

# KIDS_PY -- build-time constant, never an environment read (AGENTS.md).
# shellcheck disable=SC2034 # read by every sourcing command as "$KIDS_PY", not here
KIDS_PY=python3

# run CMD [ARG...] — DRY_RUN=1 (default) prints the shell-quoted command
# instead of running it; DRY_RUN=0 (or --apply) runs it for real.
run() {
  if [[ "$DRY_RUN" == "0" ]]; then
    "$@"
  else
    printf '  [dry-run]'
    printf ' %q' "$@"
    printf '\n'
  fi
}

# passwd(5) reserves colon as a field delimiter. The portal profile keeps
# the exact display name; GECOS is only a fallback for representable names.
gecos_name_for_display() {
  local name="$1"
  [[ "$name" == *:* ]] && return 0
  printf '%s' "$name"
}

# VALID_BANDS -- Appendix B's four age bands, in order, declared once
# (previously six duplicated copies, where `13+` vs `13plus` had drifted).
# shellcheck disable=SC2034 # read by the sourcing command, not here
VALID_BANDS=("3-5" "6-8" "9-12" "13+")

# is_in NEEDLE [HAYSTACK...] -- is NEEDLE one of the rest.
is_in() {
  local needle="$1" x
  shift
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

# is_valid_band BAND — is BAND one of them.
is_valid_band() { is_in "$1" "${VALID_BANDS[@]}"; }

# group_for_band BAND -- the Unix group for a provisioned band (Appendix
# C). Accepts both "13+" and "13plus" (a Chromium policy filename can't
# hold a '+').
group_for_band() {
  case "$1" in
    3-5) echo omarchy-kids-3-5 ;;
    6-8) echo omarchy-kids-6-8 ;;
    9-12) echo omarchy-kids-9-12 ;;
    13+ | 13plus) echo omarchy-kids-13plus ;;
    *) return 1 ;;
  esac
}

# home_dir_for ACCOUNT -- ACCOUNT's home under $HOME_ROOT (a scratch
# prefix in tests, empty by default).
home_dir_for() { printf '%s/home/%s\n' "${OMARCHY_KIDS_HOME_ROOT:-}" "$1"; }

# account_home ACCOUNT -- the real home via getent, else home_dir_for's guess.
account_home() {
  local home
  if command -v getent >/dev/null 2>&1; then
    home="$(getent passwd "$1" 2>/dev/null | cut -d: -f6)"
    [[ -n "$home" ]] && {
      printf '%s\n' "$home"
      return 0
    }
  fi
  home_dir_for "$1"
}

# parent_home_dir MACHINE_CONF -- the parent's home, or 1 when no parent is recorded.
parent_home_dir() {
  local parent
  parent="$(conf_get "$1" parent 2>/dev/null || true)"
  [[ -n "$parent" ]] || return 1
  account_home "$parent"
}

# detect_luks_device [EXPLICIT] -- EXPLICIT wins, then
# $OMARCHY_KIDS_LUKS_DEVICE, then a best-effort lsblk scan.
detect_luks_device() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  if [[ -n "${OMARCHY_KIDS_LUKS_DEVICE:-}" ]]; then
    printf '%s\n' "$OMARCHY_KIDS_LUKS_DEVICE"
    return 0
  fi
  if command -v lsblk >/dev/null 2>&1; then
    local dev
    dev="$(lsblk -rno NAME,FSTYPE 2>/dev/null | awk '$2=="crypto_LUKS"{print "/dev/"$1; exit}')"
    [[ -n "$dev" ]] && {
      printf '%s\n' "$dev"
      return 0
    }
  fi
  return 1
}

# --- luks-slots (R-SEC-4, and the "LUKS2 reuses slot numbers" finding) -----
# The one place this file's "slot=account[:session]" lines (docs/boot.md's
# format) are parsed and rewritten -- previously two identical copies of
# the three parsers below, one in bin/omarchy-kids-provision and one in
# bin/omarchy-kids-remove ("Remove Kids Mode"); the writer moved here too
# (from lib/posture.sh) so nothing needs a second source line for it.

luks_fsync_path() {
  "$KIDS_PY" -c 'import os, sys
p = sys.argv[1]
for target in (p, os.path.dirname(p)):
    fd = os.open(target, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)' "$1"
}

luks_lock_acquire() {
  local slots_file="$1"
  install -d -m 0755 "$(dirname "$slots_file")" || return 1
  exec 8>"$slots_file.lock" || return 1
  chmod 0600 "$slots_file.lock" || {
    exec 8>&-
    return 1
  }
  flock -x 8 || {
    exec 8>&-
    return 1
  }
}

luks_lock_release() {
  flock -u 8 || true
  exec 8>&-
}

# luks_slots_parent_line FILE -- the "0=account[:session]" line, if any.
luks_slots_parent_line() {
  local file="$1" line
  [[ -r "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      '' | '#'*) continue ;;
      0=*)
        printf '%s\n' "$line"
        return 0
        ;;
    esac
  done <"$file"
}

# luks_slots_kid_entries FILE — every "slot=account[:session]" line whose
# slot isn't 0, one per line.
luks_slots_kid_entries() {
  local file="$1" line key
  [[ -r "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in '' | '#'*) continue ;; esac
    key="${line%%=*}"
    [[ "$key" == "0" ]] && continue
    printf '%s\n' "$line"
  done <"$file"
}

# luks_slot_for_account FILE ACCOUNT -- the slot number mapped to ACCOUNT, if any.
luks_slot_for_account() {
  local file="$1" account="$2" line key val acct
  [[ -r "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in '' | '#'*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    acct="${val%%:*}"
    if [[ "$acct" == "$account" ]]; then
      printf '%s\n' "$key"
      return 0
    fi
  done <"$file"
}

# luks_occupied_slots DEVICE -- occupied slot numbers from a trusted dump.
luks_occupied_slots() {
  local dump slots
  dump="$(cryptsetup luksDump "$1" 2>/dev/null)" || return 1
  slots="$(printf '%s\n' "$dump" | sed -n \
    -e 's/^[[:space:]]*\([0-9][0-9]*\):[[:space:]]*luks2[[:space:]]*$/\1/p' \
    -e 's/^Key Slot \([0-9][0-9]*\): ENABLED[[:space:]]*$/\1/p' |
    sort -n -u)" || return 1
  [[ -n "$slots" ]] || return 1
  printf '%s\n' "$slots"
}

# luks_slot_occupied DEVICE SLOT -- 0 occupied, 1 empty, 2 unreadable.
luks_slot_occupied() {
  local slots
  slots="$(luks_occupied_slots "$1")" || return 2
  grep -qxF -- "$2" <<<"$slots"
}

# posture_write_luks_slots FILE PARENT_LINE [ENTRY...] — always a full
# rewrite, never append/edit-in-place: LUKS2 reuses freed slot numbers,
# so a stale line could point a reused slot at the wrong account
# (docs/provision.md). Kept its "posture_" name (it moved from
# lib/posture.sh, which still owns every other machine-posture writer;
# only the file changed).
posture_write_luks_slots() {
  local file="$1" parent_line="$2" tmp lines=()
  shift 2
  install -d -m 0755 "$(dirname "$file")" || return 1
  tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")" || return 1
  [[ -z "$parent_line" ]] || lines+=("$parent_line")
  lines+=("$@")
  if ((${#lines[@]})); then
    printf '%s\n' "${lines[@]}" >"$tmp" || {
      rm -f "$tmp" || true
      return 1
    }
  elif ! : >"$tmp"; then
    rm -f "$tmp" || true
    return 1
  fi
  chmod 0600 "$tmp" || {
    rm -f "$tmp" || true
    return 1
  }
  mv -f "$tmp" "$file" || {
    rm -f "$tmp" || true
    return 1
  }
  return 0
}

# One intent file per kid is the durable boundary around a slot deletion. A
# failed child never blocks another child's independently safe removal.
luks_removal_intent_file() { printf '%s.removing-%s\n' "$1" "$2"; }

luks_write_removal_intent() {
  local slots_file="$1" slot="$2" account="$3" file tmp
  [[ "$slot" =~ ^[1-9][0-9]*$ && "$account" =~ ^kid-[a-z0-9-]+$ ]] || return 1
  file="$(luks_removal_intent_file "$slots_file" "$account")"
  install -d -m 0755 "$(dirname "$file")" || return 1
  tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")" || return 1
  if ! printf '%s=%s\n' "$slot" "$account" >"$tmp"; then
    rm -f "$tmp" || true
    return 1
  fi
  if ! chmod 0600 "$tmp"; then
    rm -f "$tmp" || true
    return 1
  fi
  if ! mv -f "$tmp" "$file"; then
    rm -f "$tmp" || true
    return 1
  fi
  luks_fsync_path "$file" || return 1
  return 0
}

# luks_read_removal_intent FILE ACCOUNT — print "slot account"; 1 absent, 2 invalid.
luks_read_removal_intent() {
  local file line account="$2"
  file="$(luks_removal_intent_file "$1" "$account")"
  [[ -e "$file" ]] || return 1
  line="$(cat "$file")" || return 2
  [[ "$line" =~ ^([1-9][0-9]*)=(kid-[a-z0-9-]+)$ ]] || return 2
  [[ "${BASH_REMATCH[2]}" == "$account" ]] || return 2
  printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
}

luks_removal_intent_for_account() {
  local intent slot account
  intent="$(luks_read_removal_intent "$1" "$2")" || return $?
  read -r slot account <<<"$intent"
  printf '%s\n' "$slot"
}

luks_removal_intents() {
  local slots_file="$1" file account intent
  for file in "$slots_file".removing-*; do
    [[ -e "$file" ]] || continue
    account="${file#"$slots_file.removing-"}"
    intent="$(luks_read_removal_intent "$slots_file" "$account")" || return 1
    printf '%s\n' "$intent"
  done
}

luks_remove_account_slot_locked() {
  local slots_file="$1" account="$2" device="$3" key_fd="${4:-}"
  local intent="" intent_slot="" mapped_slot slot_state
  local parent_line entries=() line acct

  mapped_slot="$(luks_slot_for_account "$slots_file" "$account" || true)"
  if [[ -e "$(luks_removal_intent_file "$slots_file" "$account")" ]]; then
    intent="$(luks_read_removal_intent "$slots_file" "$account")" || {
      echo "invalid LUKS removal intent beside $slots_file; repair it before retrying" >&2
      return 1
    }
    intent_slot="${intent%% *}"
    if [[ -n "$mapped_slot" && "$mapped_slot" != "$intent_slot" ]]; then
      echo "LUKS removal intent for $account disagrees with $slots_file" >&2
      return 1
    fi
  else
    [[ -n "$mapped_slot" ]] || return 0
    intent_slot="$mapped_slot"
    if ! luks_write_removal_intent "$slots_file" "$intent_slot" "$account"; then
      echo "could not record removal intent for LUKS slot $intent_slot for $account" >&2
      return 1
    fi
  fi

  if luks_slot_occupied "$device" "$intent_slot"; then
    if [[ -n "$key_fd" ]]; then
      cryptsetup luksKillSlot --batch-mode --key-file="/dev/fd/$key_fd" "$device" "$intent_slot" || {
        echo "cryptsetup could not remove slot $intent_slot for $account" >&2
        return 1
      }
    else
      cryptsetup luksKillSlot --batch-mode "$device" "$intent_slot" || {
        echo "cryptsetup could not remove slot $intent_slot for $account" >&2
        return 1
      }
    fi
  else
    slot_state=$?
    if ((slot_state != 1)); then
      echo "could not inspect LUKS slots on $device" >&2
      return 1
    fi
  fi

  parent_line="$(luks_slots_parent_line "$slots_file")"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    acct="${line#*=}"
    acct="${acct%%:*}"
    [[ "$acct" == "$account" ]] && continue
    entries+=("$line")
  done < <(luks_slots_kid_entries "$slots_file")
  if ! posture_write_luks_slots "$slots_file" "$parent_line" "${entries[@]+"${entries[@]}"}"; then
    echo "slot $intent_slot is gone, but could not update $slots_file; retry removal" >&2
    return 1
  fi
  if ! luks_fsync_path "$slots_file"; then
    echo "slot $intent_slot is gone and its map was rewritten, but that rewrite is not durable; retry removal" >&2
    return 1
  fi
  if ! rm -f "$(luks_removal_intent_file "$slots_file" "$account")"; then
    echo "slot $intent_slot and its map entry are gone, but the removal intent remains; retry removal" >&2
    return 1
  fi
  return 0
}

luks_remove_account_slot() {
  local rc=0
  if ! luks_lock_acquire "$1"; then
    echo "could not lock $1 for LUKS slot removal" >&2
    return 1
  fi
  luks_remove_account_slot_locked "$@" || rc=$?
  luks_lock_release
  return "$rc"
}

# luks_slots_record_parent FILE KIDS_DIR PARENT -- makes sure slot 0 maps
# to PARENT (docs/boot.md step 5): a fresh install, and a machine freshly
# through "Remove Kids Mode" and provisioned again, both start with no
# luks-slots file at all, and until now nothing ever wrote a "0=" line --
# a boot unlocked with the parent's own disk password mapped to nothing
# and landed on the portal instead of their desktop. Every existing kid
# entry carries over untouched. An existing "0=" line is always left
# alone, even one naming someone else -- overwriting it risks pointing a
# real, already-unlocked LUKS slot at the wrong account -- noted on
# stderr either way, success or not. The one case that refuses outright:
# the existing "0=" line names a currently-provisioned kid, meaning slot
# 0 is already how that kid's own account unlocks -- writing PARENT
# there too would be a real slot clash, not just an ownership question,
# so this exits non-zero instead of silently leaving a kid mapped to the
# slot the parent now thinks is theirs.
luks_slots_record_parent() {
  local file="$1" kids_dir="$2" parent="$3"
  local parent_line existing
  parent_line="$(luks_slots_parent_line "$file")"
  if [[ -n "$parent_line" ]]; then
    existing="${parent_line#0=}"
    existing="${existing%%:*}"
    if [[ "$existing" != "$parent" ]] && is_known_kid "$kids_dir" "$existing"; then
      echo "lib/kids.sh: $file already maps slot 0 to kid account '$existing', not parent '$parent' -- refusing to clash; resolve the LUKS slot mapping by hand" >&2
      return 1
    fi
    echo "lib/kids.sh: $file already has a slot 0 mapping ('$parent_line'); left it alone" >&2
    return 0
  fi
  local entries=() line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    entries+=("$line")
  done < <(luks_slots_kid_entries "$file")
  posture_write_luks_slots "$file" "0=$parent" "${entries[@]+"${entries[@]}"}"
}

# file_stat FMT FILE -- GNU/BSD stat(1) wrapper, GNU tried first (issue #49, docs/assert.md).
file_stat() {
  local fmt="$1" file="$2"
  if stat --version >/dev/null 2>&1; then
    stat -c "%${fmt}" "$file" 2>/dev/null || true
    return 0
  fi
  case "$fmt" in
    a) stat -f '%Lp' "$file" 2>/dev/null || true ;;
    G) stat -f '%Sg' "$file" 2>/dev/null || true ;;
    i) stat -f '%i' "$file" 2>/dev/null || true ;;
    u) stat -f '%u' "$file" 2>/dev/null || true ;;
    *) return 1 ;;
  esac
}

# kids_bin NAME DIR -- sibling command NAME, always DIR/bin/omarchy-kids-
# NAME. DIR is the caller's own resolved prefix, so on an installed box
# this *is* /usr/bin; a /usr/bin fallback would only hide "not installed
# yet" behind whatever the package happens to have put there. No
# environment override (AGENTS.md, "The trust boundary").
kids_bin() {
  printf '%s/bin/omarchy-kids-%s\n' "$2" "$1"
}

# first_field KEY TEXT -- value of the first "KEY=<value>" line. One awk
# pass, never `sed ... | head -1`: under `set -o pipefail` that returns
# 141 as soon as sed hasn't finished writing, aborting a caller's `set -e`.
first_field() {
  awk -F= -v k="$1" '$1 == k { print substr($0, length(k) + 2); exit }' <<<"$2"
}

# kids_band_field CONF_BIN BAND KEY -- one value out of `CONF_BIN band
# BAND` (Appendix C's per-band defaults).
kids_band_field() {
  local out
  out="$("$1" band "$2")" || return 1
  first_field "$3" "$out"
}

# kids_list DIR -- one provisioned account per line, every "*.conf"
# basename. Glob, not `ls`, so an empty directory yields nothing.
kids_list() {
  local dir="$1" f
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/*.conf; do
    [[ -e "$f" ]] || continue
    basename "$f" .conf
  done
}

# portal_conf_entries DIR [EXCLUDE] -- one "account<TAB>name<TAB>avatar"
# line per kid, for theme.conf.user. EXCLUDE drops the account being
# removed while it's still on disk.
portal_conf_entries() {
  local dir="$1" exclude="${2:-}" f account name avatar
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/*.conf; do
    [[ -e "$f" ]] || continue
    account="$(basename "$f" .conf)"
    [[ -n "$exclude" && "$account" == "$exclude" ]] && continue
    name="$(conf_get "$f" name 2>/dev/null || true)"
    avatar="$(conf_get "$f" avatar 2>/dev/null || true)"
    printf '%s\t%s\t%s\n' "$account" "$name" "$avatar"
  done
}

# launched_by_a_human -- a person driving this, not a script: the app
# entry sets OMARCHY_KIDS_LAUNCHED_BY, or a tty on stdin+stdout. Only
# turns the DRY_RUN=1 default OFF for the two interactive commands
# (AGENTS.md rule 8) -- the screen the parent confirms is the confirmation.
launched_by_a_human() {
  [[ -n "${OMARCHY_KIDS_LAUNCHED_BY:-}" ]] && return 0 # the .desktop entry
  [[ -t 0 && -t 1 ]]                                   # a terminal
}

# is_known_kid DIR ACCOUNT -- is ACCOUNT a provisioned kid under DIR.
is_known_kid() { [[ -f "$1/$2.conf" ]]; }

# --- shared TUI validators/labels: each prints the one-line reason
# lib/tui.sh shows under the field, and returns 1.

# validate_budget_minutes VALUE -- Appendix B's budget_min range.
validate_budget_minutes() {
  [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 1440)) && return 0
  echo "A number of minutes, 1 to 1440."
  return 1
}

# validate_lights_out VALUE -- Appendix B's lights_out, 24-hour HH:MM.
validate_lights_out() {
  [[ "$1" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] && return 0
  echo "24-hour time, like 19:30."
  return 1
}

# friendly_web_mode MODE -- R-WEB-3's three modes, in a parent's words.
friendly_web_mode() {
  case "$1" in
    none) echo "No browser" ;;
    garden) echo "Only sites you choose" ;;
    filtered) echo "Filtered open web" ;;
    *) echo "$1" ;;
  esac
}

# friendly_wifi_mode MODE -- Appendix B's two Wi-Fi modes, parent words.
friendly_wifi_mode() {
  case "$1" in
    parent) echo "Ask me first" ;;
    helper) echo "On their own, safely" ;;
    *) echo "$1" ;;
  esac
}

# modal_already_open PIDFILE -- true if PIDFILE names a still-live process
# whose /proc comm is quickshell. Not a `pgrep -f` substring match on argv:
# a kid could start any process containing that string and wedge it shut.
modal_already_open() {
  local pidfile="$1" pid comm=""
  [[ -r "$pidfile" ]] || return 1
  IFS= read -r pid <"$pidfile" || return 1
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ -r "/proc/$pid/comm" ]] && IFS= read -r comm <"/proc/$pid/comm"
  [[ -z "$comm" || "$comm" == quickshell* ]]
}

# modal_write_pid PIDFILE [PID] -- records PID ($$, or $! for a
# backgrounded caller) as the one holding the modal open.
modal_write_pid() { printf '%s\n' "${2:-$$}" >"$1"; }

# modal_close PIDFILE -- ends the modal, if PIDFILE's owner is still the
# process that wrote it. Never `pkill -f` on an argv substring.
modal_close() {
  local pidfile="$1" pid
  modal_already_open "$pidfile" || {
    rm -f "$pidfile"
    return 0
  }
  IFS= read -r pid <"$pidfile" || return 0
  [[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null
  rm -f "$pidfile"
  return 0
}

# --- systemd units -----------------------------------------------------
# The package's own units (R-BOOT-3, R-SEC-2), one list shared by
# omarchy-kids-assert's "units" lock and the wizard's Apply.

# shellcheck disable=SC2034 # read by sourcing callers, not here
KIDS_UNITS=(omarchy-kids-boot-login.service omarchy-kids-boot-login-cleanup.service omarchy-kids-assert.service)
# wifid.socket: without it, a helper-mode kid's wifi command fails closed
# with "no reply" (docs/wifi.md) rather than silently doing nothing.
# shellcheck disable=SC2034 # read by sourcing callers, not here
KIDS_SOCKETS=(omarchy-kids-authd.socket omarchy-kids-wifid.socket)
# ask-collect.timer: the every-minute backstop that applies an "ask a
# parent" request submitted while no one was running the panel.
# shellcheck disable=SC2034 # read by sourcing callers, not here
KIDS_TIMERS=(omarchy-kids-time.timer omarchy-kids-ask-collect.timer omarchy-kids-review.timer omarchy-kids-relay-courier.timer)

# The relay's network fence, in one place: the notify writer and the assert lock
# both use these (R-NOTIFY-11.1). A drift between two copies would make every
# boot and every update rewrite the drop-in and restart the relay, dropping every
# held device stream, so there is exactly one copy (the tests cross-check too).
# shellcheck disable=SC2034 # read by sourcing callers
RELAY_UNIT_NAME="omarchy-kids-relayd.service"
# shellcheck disable=SC2034 # read by sourcing callers
RELAY_LAN_ALLOW="localhost link-local multicast 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fe80::/10"
# shellcheck disable=SC2034 # read by sourcing callers
RELAY_CGNAT="100.64.0.0/10"

# The exact bytes "omarchy-kids-notify away tailnet" writes; also what the
# relay-away lock expects, byte for byte.
relay_away_conf_text() {
  cat <<EOF
# Kids Mode: "Away from home: my own VPN" (N-10), written by
# omarchy-kids-notify away tailnet. Extends the relay's fence to the CGNAT range
# Tailscale uses, so a device on the parent's own tailnet can reach it. "away off"
# removes this file. The LAN list is repeated so this file is correct whether
# systemd merges IPAddressAllow or replaces the unit's.
[Service]
IPAddressAllow=$RELAY_LAN_ALLOW $RELAY_CGNAT
EOF
}
