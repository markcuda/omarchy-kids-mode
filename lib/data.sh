# shellcheck shell=bash
# lib/data.sh -- shared helpers for recorded data (SPEC.md R-DATA-1..5,
# issue #27). Trust boundary same shape as lib/time.sh's: a kid can only
# write their own runtime launches log, never the root-owned copy --
# data_fold_launches (root only) is the one thing that promotes it. Not
# meant to be executed directly; source it. Every path/env var: docs/data.md.

DATA_SYSROOT="${OMARCHY_KIDS_ROOT:-}"
DATA_VARLIB="$DATA_SYSROOT/var/lib/omarchy-kids"
DATA_RUN_USER_BASE="${OMARCHY_KIDS_RUN_USER_BASE:-/run/user}"
DATA_HOMES_BASE="${OMARCHY_KIDS_HOMES_BASE:-/home}"
# data_py ARGS... — runs lib/data.py, resolved the way lib/time.sh
# resolves lib/time.py. No environment override.
data_py() {
  local py
  py="$(dirname "${BASH_SOURCE[0]}")/data.py"
  [[ -f "$py" ]] || py=/usr/lib/omarchy-kids/data.py
  "${KIDS_PY:-python3}" "$py" "$@"
}

data_kid_dir() { printf '%s/%s\n' "$DATA_VARLIB" "$1"; }
data_usage_dir() { printf '%s/usage\n' "$(data_kid_dir "$1")"; }

# data_decisions_dir KID -- the kid's own copies of their decided requests,
# written by lib/ask.py (R-NOTIFY-6); pruned by retention with the queue.
data_decisions_dir() { printf '%s/decisions\n' "$(data_kid_dir "$1")"; }
data_launches_file() { printf '%s/launches.log\n' "$(data_kid_dir "$1")"; }
data_launches_offset_file() { printf '%s/launches.offset\n' "$(data_kid_dir "$1")"; }
data_home_dir() { printf '%s/%s\n' "$DATA_HOMES_BASE" "$1"; }
data_chromium_history() { printf '%s/.config/chromium/Default/History\n' "$(data_home_dir "$1")"; }

# data_kid_uid KID — `id -u KID`, empty if there's no such account.
data_kid_uid() { id -u "$1" 2>/dev/null; }

# data_runtime_launches_file KID — the kid-writable source
# `omarchy-kids-launcher-ctl log` appends to, as root sees it
# ($XDG_RUNTIME_DIR's own convention). Returns 1 if KID has no uid.
data_runtime_launches_file() {
  local kid="$1" uid
  uid="$(data_kid_uid "$kid")" || return 1
  [[ -n "$uid" ]] || return 1
  printf '%s%s/%s/omarchy-kids/launches.log\n' "$DATA_SYSROOT" "$DATA_RUN_USER_BASE" "$uid"
}

# data_read_int FILE — same contract as lib/time.sh's time_read_int.
data_read_int() {
  local file="$1" v
  [[ -r "$file" ]] || {
    printf '0\n'
    return 0
  }
  v="$(cat "$file" 2>/dev/null)"
  [[ "$v" =~ ^[0-9]+$ ]] || v=0
  printf '%s\n' "$v"
}

# data_write_int FILE VALUE — same shape as lib/time.sh's time_write_int.
data_write_int() {
  local file="$1" value="$2" dir tmp
  dir="$(dirname "$file")"
  [[ -d "$dir" ]] || install -d -m 0755 "$dir"
  tmp="$(mktemp "${file}.XXXXXX")"
  printf '%s\n' "$value" >"$tmp"
  chmod 0644 "$tmp"
  mv "$tmp" "$file"
}

# data_read_offset FILE — "<inode> <byte-offset>" last recorded for the
# runtime log FILE tracks; both read as 0 if missing/empty/malformed,
# same as an unrecognized inode (docs/data.md).
data_read_offset() {
  local file="$1" inode="" off=""
  [[ -r "$file" ]] && read -r inode off <"$file" 2>/dev/null # missing is "unknown", not an error
  [[ "$inode" =~ ^[0-9]+$ ]] || inode=0
  [[ "$off" =~ ^[0-9]+$ ]] || off=0
  printf '%s %s\n' "$inode" "$off"
}

# data_write_offset FILE INODE OFFSET — same atomic-write shape as data_write_int.
data_write_offset() {
  local file="$1" inode="$2" off="$3" dir tmp
  dir="$(dirname "$file")"
  [[ -d "$dir" ]] || install -d -m 0755 "$dir"
  tmp="$(mktemp "${file}.XXXXXX")"
  printf '%s %s\n' "$inode" "$off" >"$tmp"
  chmod 0644 "$tmp"
  mv "$tmp" "$file"
}

# data_fold_launches KID — root-only: folds new bytes from KID's own
# runtime launches log into their root-owned launches.log, tracked by
# inode+offset so a fresh login's new tmpfs inode restarts the fold at 0.
# The actual read happens in lib/data.py, O_NOFOLLOW plus an owner check
# on the open descriptor -- never a shell `tail -c`, which follows a
# symlink to /etc/shadow. See docs/data.md "Root reading a kid's own file".
data_fold_launches() {
  local kid="$1" src dest offfile uid out inode saved_inode=0 off=0
  uid="$(data_kid_uid "$kid")" || return 0
  [[ "$uid" =~ ^[0-9]+$ ]] || return 0
  src="$(data_runtime_launches_file "$kid")" || return 0
  dest="$(data_launches_file "$kid")"
  offfile="$(data_launches_offset_file "$kid")"
  read -r saved_inode off <<<"$(data_read_offset "$offfile")"

  out="$(data_py fold-launches "$src" "$dest" "$uid" "$saved_inode" "$off")" || return 0
  [[ "$out" == "skip" || -z "$out" ]] && return 0
  read -r inode off <<<"$out"
  [[ "$inode" =~ ^[0-9]+$ && "$off" =~ ^[0-9]+$ ]] || return 0
  chgrp omarchy-parents "$dest" 2>/dev/null || true
  data_write_offset "$offfile" "$inode" "$off"
}

# data_history_visible KID CONF_BIN — "yes"/"no" (Appendix B's
# history_visible key, default "yes"); shared so omarchy-kids-data and
# omarchy-kids-panel read the R-DATA-4 gate the same way.
data_history_visible() {
  local kid="$1" conf_bin="$2" v
  v="$("$conf_bin" get "$kid" history_visible 2>/dev/null)" || v=yes
  [[ "$v" == "no" ]] && {
    printf 'no\n'
    return 0
  }
  printf 'yes\n'
}
