# shellcheck shell=bash
# lib/assert-locks.sh — omarchy-kids-assert's per-kid and machine-level
# lock *_ok/*_fix pairs (everything but the Limine locks). Sourced by
# the dispatcher; not meant to be executed directly. See docs/assert.md's
# "Lock list" and "Judgment calls" for the full table and every rationale
# below -- each comment here is a one-line pointer, not the full case.

profile_field() { conf_get "$KIDS_DIR/$1.conf" "$2" 2>/dev/null || true; }

# fstab: R-FND-2's bind-mount line, via lib/posture.sh's idempotent writer.
fstab_ok() { grep -qxF "$(posture_fstab_line "$1")" "$(posture_fstab)" 2>/dev/null; }
fstab_fix() { posture_add_fstab_line "$1"; }

# mount: actually mounted noexec,nosuid,nodev right now, not just fstab.
mount_opts_ok() { [[ "$1" == *noexec* && "$1" == *nosuid* && "$1" == *nodev* ]]; }
mount_ok() {
  local opts
  opts="$(findmnt -no OPTIONS "$(home_dir_for "$1")" 2>/dev/null || true)"
  [[ -n "$opts" ]] && mount_opts_ok "$opts"
}
mount_fix() {
  local account="$1" home opts
  home="$(home_dir_for "$account")"
  opts="$(findmnt -no OPTIONS "$home" 2>/dev/null || true)"
  if [[ -z "$opts" ]]; then
    mount --bind "$home" "$home" || return 1
  fi
  mount -o remount,bind,nosuid,nodev,noexec "$home"
}

# namespace: R-FND-2a's two pam_namespace.conf lines for this account.
namespace_ok() {
  local file account="$1" old_l1 old_l2
  file="$(posture_namespace_conf)"
  [[ -f "$file" ]] || return 1
  old_l1="$(posture_namespace_legacy_line_tmp "$account")"
  old_l2="$(posture_namespace_legacy_line_shm "$account")"
  ! grep -qxF "$old_l1" "$file" && ! grep -qxF "$old_l2" "$file" &&
    grep -qxF "$(posture_namespace_line_tmp "$account")" "$file" &&
    grep -qxF "$(posture_namespace_line_shm "$account")" "$file"
}
namespace_fix() { posture_add_namespace_lines "$1"; }

# accountsservice: R-LOGIN-3's session pin, exact content match (same
# idempotence check posture_write_accountsservice itself uses).
accountsservice_ok() {
  local account="$1" avatar="$2" file
  file="$(posture_accountsservice_dir)/$account"
  [[ -f "$file" ]] && [[ "$(cat "$file")" == "$(posture_accountsservice_text "$avatar")" ]]
}
accountsservice_fix() { posture_write_accountsservice "$1" "$2"; }

# gecos (issue #39): passwd's representable display-name fallback.
gecos_ok() {
  local account="$1" name="$2" current expected
  command -v getent >/dev/null 2>&1 || return 2 # no way to read the field back
  current="$(getent passwd "$account" 2>/dev/null | cut -d: -f5)"
  expected="$(gecos_name_for_display "$name")"
  [[ "$current" == "$expected" ]]
}
gecos_fix() {
  local name
  name="$(gecos_name_for_display "$2")"
  usermod -c "$name" "$1"
}

# face (issue #39): the file SDDM's UserModel actually reads for the
# avatar, not AccountsService's Icon= (docs/portal.md's "Avatars").
face_ok() {
  local account="$1" avatar="$2" src file
  src="$SHARE/avatars/$avatar.svg"
  file="$(posture_sddm_faces_dir)/$account.face.icon"
  [[ -f "$file" ]] && cmp -s "$src" "$file"
}
face_fix() { posture_write_face_icon "$SHARE/avatars/$2.svg" "$1"; }

# groups: member of omarchy-kids and the band group. No lib/posture.sh
# writer to reuse here (docs/assert.md's "Judgment calls").
current_groups() { id -nG "$1" 2>/dev/null || true; }
has_group() { [[ " $1 " == *" $2 "* ]]; }
supplementary_groups() {
  local account="$1" primary
  primary="$(id -gn "$account" 2>/dev/null || true)"
  current_groups "$account" | tr ' ' '\n' | sed '/^$/d' | grep -Fxv "$primary" || true
}
groups_ok() {
  local account="$1" band="$2" group current expected
  group="$(group_for_band "$band")" || return 1
  current="$(supplementary_groups "$account" | sort -u)"
  expected="$(printf '%s\n' omarchy-kids "$group" | sort -u)"
  [[ "$current" == "$expected" ]]
}
groups_fix() {
  local account="$1" band="$2" group current expected
  group="$(group_for_band "$band")" || return 1
  current="$(supplementary_groups "$account" | sort -u)"
  expected="$(printf '%s\n' omarchy-kids "$group" | sort -u)"
  [[ "$current" == "$expected" ]] && return 0
  usermod -G "omarchy-kids,$group" "$account"
}

# theme (issue #53): the kid's current Omarchy theme still matches the
# profile's `theme` override -- docs/theming.md.
theme_ok() {
  local account="$1" expected current
  expected="$(profile_field "$account" theme)"
  [[ -n "$expected" ]] || return 0
  current="$(THEME_KIDS_HOME="$(home_dir_for "$account")" theme_current_name)"
  [[ "$current" == "$expected" ]]
}
theme_fix() {
  local account="$1" expected
  expected="$(profile_field "$account" theme)"
  [[ -n "$expected" ]] || return 0
  theme_apply_for "$account" "$expected"
}

# launcher-map: the root-owned id-to-argv execution authority (finding 2).
launcher_lock_ok() { launcher_map_ok "$1"; }
launcher_lock_fix() { launcher_map_fix "$1"; }

# session manifest: one validated root-owned input for every kid session (R-MANIFEST-7).
session_manifest_lock_ok() { session_manifest_check "$1"; }
session_manifest_lock_fix() { session_manifest_build "$1"; }

# --- machine-level locks ---

# expected in a local first: inline, an unusable parent name would make an
# empty rule file compare equal to it -- green forever with no rule (review §2.2).
polkit_admin_ok() {
  local parent file expected
  parent="$(conf_get "$MACHINE_CONF" parent 2>/dev/null || true)"
  [[ -n "$parent" ]] || return 1
  expected="$(posture_polkit_admin_rule_text "$parent")" || return 1
  file="$(posture_polkit_dir)/40-omarchy-kids.rules"
  [[ -f "$file" ]] && [[ "$(cat "$file")" == "$expected" ]]
}
polkit_admin_fix() {
  local parent
  parent="$(conf_get "$MACHINE_CONF" parent 2>/dev/null || true)"
  [[ -n "$parent" ]] || return 1
  posture_write_polkit_admin_rule "$parent"
}

polkit_deny_ok() {
  local file
  file="$(posture_polkit_dir)/41-omarchy-kids-deny.rules"
  [[ -f "$file" ]] && [[ "$(cat "$file")" == "$(posture_polkit_deny_rule_text)" ]]
}
polkit_deny_fix() { posture_write_polkit_deny_rule; }

# sddm-theme (R-LOGIN, issue #14): the portal's conf.d drop-in, exact match.
sddm_theme_ok() {
  local file
  file="$(posture_sddm_conf_dir)/zz-omarchy-kids-theme.conf"
  [[ -f "$file" ]] && [[ "$(cat "$file")" == "$(posture_sddm_theme_dropin_text)" ]]
}
sddm_theme_fix() { posture_write_sddm_theme_dropin; }

# portal-conf (issue #39): theme.conf.user, rebuilt whole every time from
# the current kid profiles + machine.conf's parent= -- docs/assert.md.
portal_conf_expected() {
  local parent entries=() line
  parent="$(conf_get "$MACHINE_CONF" parent 2>/dev/null || true)"
  [[ -n "$parent" ]] || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] && entries+=("$line")
  done < <(portal_conf_entries "$KIDS_DIR")
  posture_portal_conf_text "$parent" "${entries[@]+"${entries[@]}"}"
}
portal_conf_ok() {
  local expected file
  expected="$(portal_conf_expected)" || return 1
  file="$(posture_sddm_theme_dir)/theme.conf.user"
  [[ -f "$file" ]] && [[ "$(cat "$file")" == "$expected" ]]
}
portal_conf_fix() {
  local parent entries=() line
  parent="$(conf_get "$MACHINE_CONF" parent 2>/dev/null || true)"
  [[ -n "$parent" ]] || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] && entries+=("$line")
  done < <(portal_conf_entries "$KIDS_DIR")
  posture_write_portal_conf "$parent" "${entries[@]+"${entries[@]}"}"
}

pam_ok() {
  local file
  file="$(posture_pam_dir)/$1"
  [[ -f "$file" ]] && grep -qxF "$(posture_pam_namespace_marker)" "$file"
}
pam_fix() { posture_ensure_pam_namespace "$1"; }

# parent-unlock (R-SEC-2, R-SEC-3): the pam_exec line docs/authd.md
# describes, on sddm and whichever lock-screen stack this box has.
parent_unlock_ok() {
  local file
  file="$(posture_pam_dir)/$1"
  [[ -f "$file" ]] || return 2 # no such PAM stack here: nothing to look at
  grep -qxF "$(posture_parent_unlock_marker)" "$file"
}
parent_unlock_fix() { posture_ensure_parent_unlock_line "$1"; }

# getty@tty2..6 masked (R-FND-5): a symlink to /dev/null, checked
# directly rather than via systemctl -- docs/assert.md's "Judgment calls".
getty_unit_path() { printf '%s/etc/systemd/system/getty@tty%s.service' "$(posture_root)" "$1"; }
getty_ok() {
  local link
  link="$(getty_unit_path "$1")"
  [[ -L "$link" ]] && [[ "$(readlink "$link")" == "/dev/null" ]]
}
getty_fix() {
  local root_args=()
  [[ -n "$(posture_root)" ]] && root_args=(--root="$(posture_root)")
  systemctl "${root_args[@]}" mask "getty@tty$1.service"
}

# time_metadata_* — re-assert modes and root ownership without rewriting
# usage, grants, or the runtime decision document (R-TIMEAUTH-7).
time_metadata_owner_ok() {
  local path="$1" group="${2:-}"
  is_root || return 0
  [[ "$(file_stat u "$path")" == 0 ]] || return 1
  [[ -z "$group" || "$(file_stat G "$path")" == "$group" ]]
}

time_metadata_owner_fix() {
  local path="$1" group="${2:-}"
  if is_root; then
    if [[ -n "$group" ]]; then
      chown "root:$group" "$path"
    else
      chown root "$path"
    fi
  else
    if [[ -n "$group" ]]; then
      chown "root:$group" "$path" >/dev/null 2>&1 || true
    else
      chown root "$path" >/dev/null 2>&1 || true
    fi
  fi
}

time_metadata_dir_ok() {
  local path="$1" mode="$2" group="${3:-}"
  [[ -d "$path" && ! -L "$path" ]] || return 1
  [[ "$(file_stat a "$path")" == "$mode" ]] || return 1
  time_metadata_owner_ok "$path" "$group"
}

time_metadata_dir_fix() {
  local path="$1" mode="$2" group="${3:-}"
  if [[ -L "$path" || (-e "$path" && ! -d "$path") ]]; then return 1; fi
  install -d -m "$mode" "$path" || return 1
  chmod "$mode" "$path" || return 1
  time_metadata_owner_fix "$path" "$group"
}

time_metadata_file_ok() {
  local path="$1" mode="$2" group="${3:-}"
  [[ -f "$path" && ! -L "$path" ]] || return 1
  [[ "$(file_stat a "$path")" == "$mode" ]] || return 1
  time_metadata_owner_ok "$path" "$group"
}

time_metadata_file_fix() {
  local path="$1" mode="$2" group="${3:-}"
  [[ -f "$path" && ! -L "$path" ]] || return 1
  chmod "$mode" "$path" || return 1
  time_metadata_owner_fix "$path" "$group"
}

time_metadata_kid_ok() {
  local account="$1" state_dir ledger_dir file base
  state_dir="$(posture_root)/run/omarchy-kids/time"
  ledger_dir="$(posture_root)/var/lib/omarchy-kids/$account/usage"
  [[ ! -e "$state_dir" && ! -L "$state_dir" ]] || time_metadata_dir_ok "$state_dir" 750 omarchy-kids || return 1
  [[ ! -e "$ledger_dir" && ! -L "$ledger_dir" ]] || time_metadata_dir_ok "$ledger_dir" 755 || return 1
  file="$state_dir/$account.json"
  [[ ! -e "$file" && ! -L "$file" ]] || time_metadata_file_ok "$file" 640 omarchy-kids || return 1
  for file in "$ledger_dir"/*; do
    [[ -e "$file" || -L "$file" ]] || continue
    base="$(basename "$file")"
    [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(\.grant)?$ ]] || continue
    time_metadata_file_ok "$file" 644 || return 1
  done
}

time_metadata_kid_fix() {
  local account="$1" state_dir ledger_dir file base
  state_dir="$(posture_root)/run/omarchy-kids/time"
  ledger_dir="$(posture_root)/var/lib/omarchy-kids/$account/usage"
  time_metadata_dir_fix "$state_dir" 750 omarchy-kids || return 1
  time_metadata_dir_fix "$ledger_dir" 755 || return 1
  file="$state_dir/$account.json"
  [[ ! -e "$file" && ! -L "$file" ]] || time_metadata_file_fix "$file" 640 omarchy-kids || return 1
  for file in "$ledger_dir"/*; do
    [[ -e "$file" || -L "$file" ]] || continue
    base="$(basename "$file")"
    [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(\.grant)?$ ]] || continue
    time_metadata_file_fix "$file" 644 || return 1
  done
}

time_metadata_ok() {
  local account
  while IFS= read -r account; do
    [[ -n "$account" ]] || continue
    time_metadata_kid_ok "$account" || return 1
  done < <(kids_list "$KIDS_DIR")
}

time_metadata_fix() {
  local account
  while IFS= read -r account; do
    [[ -n "$account" ]] || continue
    time_metadata_kid_fix "$account" || return 1
  done < <(kids_list "$KIDS_DIR")
}

# devices (R-NOTIFY-3): the paired-device registry is root-owned, 0750 with
# 0600 records. Absent is fine (no device paired yet); present must be right.
devices_ok() {
  local dir file
  dir="$(posture_root)/etc/omarchy-kids/devices"
  [[ ! -e "$dir" && ! -L "$dir" ]] || time_metadata_dir_ok "$dir" 750 || return 1
  for file in "$dir"/*.conf; do
    [[ -e "$file" || -L "$file" ]] || continue
    time_metadata_file_ok "$file" 600 || return 1
  done
}
devices_fix() {
  local dir file
  dir="$(posture_root)/etc/omarchy-kids/devices"
  [[ -e "$dir" || -L "$dir" ]] || return 0 # nothing paired: nothing to fix
  time_metadata_dir_fix "$dir" 750 || return 1
  for file in "$dir"/*.conf; do
    [[ -e "$file" || -L "$file" ]] || continue
    time_metadata_file_fix "$file" 600 || return 1
  done
}

# relay-away (R-NOTIFY-11.1): the one drop-in that may widen the relay's fence.
# The fence itself is the package's unit and no lock ever writes it (I-7); this
# lock owns only the drop-in the parent's "away from home" consent wrote, and
# never creates it or deletes it (presence is the consent, N-10). A second
# *.conf in the directory is where a widened or replaced fence would live, and
# assert cannot tell an admin's file from an attacker's, so it fails rather than
# deleting one.
relay_unit_file() { printf '%s/usr/lib/systemd/system/%s' "$(posture_root)" "$RELAY_UNIT_NAME"; }
relay_away_dir() { printf '%s/etc/systemd/system/%s.d' "$(posture_root)" "$RELAY_UNIT_NAME"; }
relay_away_file() { printf '%s/away.conf' "$(relay_away_dir)"; }

relay_away_ok() {
  local dir file
  dir="$(relay_away_dir)"
  if [[ ! -e "$dir" && ! -L "$dir" ]]; then return 0; fi
  [[ -d "$dir" && ! -L "$dir" ]] || return 1
  [[ -r "$dir" && -x "$dir" ]] || return 2
  for file in "$dir"/*.conf; do
    [[ -e "$file" || -L "$file" ]] || continue
    [[ "$file" == "$(relay_away_file)" ]] || return 1 # a foreign drop-in
  done
  time_metadata_dir_ok "$dir" 755 || return 1
  file="$(relay_away_file)"
  [[ ! -e "$file" && ! -L "$file" ]] && return 0 # no away: the base fence applies
  time_metadata_file_ok "$file" 644 || return 1
  [[ "$(cat "$file" 2>/dev/null)" == "$(relay_away_conf_text)" ]]
}

relay_away_fix() {
  local dir file foreign tmp
  dir="$(relay_away_dir)"
  [[ -e "$dir" || -L "$dir" ]] || return 0 # nothing to re-assert
  [[ -d "$dir" && ! -L "$dir" ]] || return 1
  time_metadata_dir_fix "$dir" 755 || return 1
  file="$(relay_away_file)"
  if [[ -e "$file" || -L "$file" ]]; then
    [[ -f "$file" && ! -L "$file" ]] || return 1
    tmp="$file.$$"
    relay_away_conf_text >"$tmp" || return 1
    chmod 0644 "$tmp" || {
      rm -f "$tmp"
      return 1
    }
    time_metadata_owner_fix "$tmp"
    mv -f "$tmp" "$file" || {
      rm -f "$tmp"
      return 1
    }
    # The running fence must be the file's, not the stale one (N-10).
    relay_reload
  fi
  # A foreign drop-in is not this lock's to repair, but the file it owns has been
  # rewritten first: a widened away.conf must not stay widened while a second file
  # sits beside it. The lock still FAILs (assert never deletes an admin's file).
  for foreign in "$dir"/*.conf; do
    [[ -e "$foreign" || -L "$foreign" ]] || continue
    [[ "$foreign" == "$file" ]] || return 1
  done
  return 0
}

# relay_reload — the running fence must be the file's, not a stale one. Only on a
# live system (a scratch tree has no systemd); best effort, like the notify side.
relay_reload() {
  [[ -z "$(posture_root)" ]] || return 0
  command -v systemctl >/dev/null 2>&1 || return 0
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl try-restart "$RELAY_UNIT_NAME" >/dev/null 2>&1 || true
}

# relay-tls and courier-conf (R-NOTIFY-11.4): the two files that hold secrets.
# relay dir/key.pem is the private half of every paired device's pin; courier.conf
# carries the parent's Gotify token (or ntfy reply topic). The locks own modes and
# ownership only: they never open either file, never create one, never remove one,
# and never read a byte.
relay_dir() { printf '%s/etc/omarchy-kids/relay' "$(posture_root)"; }
courier_conf_file() { printf '%s/etc/omarchy-kids/courier.conf' "$(posture_root)"; }

# _relay_tls_entry ENTRY FIX -- one entry: cert.pem/key.pem at their modes, or a
# foreign name (never repaired; a loose copy of the key is what this catches).
relay_tls_entry() {
  local entry="$1" fix="$2"
  case "$(basename "$entry")" in
    cert.pem) "$fix" "$entry" 644 omarchy-parents ;;
    key.pem) "$fix" "$entry" 640 omarchy-parents ;;
    *) return 1 ;;
  esac
}

relay_tls_ok() {
  local dir entry
  dir="$(relay_dir)"
  if [[ ! -e "$dir" && ! -L "$dir" ]]; then return 0; fi
  [[ -d "$dir" && ! -L "$dir" ]] || return 1
  [[ -r "$dir" && -x "$dir" ]] || return 2
  time_metadata_dir_ok "$dir" 750 omarchy-parents || return 1
  for entry in "$dir"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    relay_tls_entry "$entry" time_metadata_file_ok || return 1
  done
}

relay_tls_fix() {
  local dir entry foreign=0
  dir="$(relay_dir)"
  [[ -e "$dir" || -L "$dir" ]] || return 0
  [[ -d "$dir" && ! -L "$dir" ]] || return 1
  time_metadata_dir_fix "$dir" 750 omarchy-parents || return 1
  for entry in "$dir"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    relay_tls_entry "$entry" time_metadata_file_fix || foreign=1
  done
  [[ "$foreign" -eq 0 ]] || return 1 # a foreign copy is left for a human
  return 0
}

courier_conf_ok() {
  local file
  file="$(courier_conf_file)"
  [[ ! -e "$file" && ! -L "$file" ]] && return 0
  time_metadata_file_ok "$file" 600 || return 1
}

courier_conf_fix() {
  local file
  file="$(courier_conf_file)"
  [[ -e "$file" || -L "$file" ]] || return 0
  time_metadata_file_fix "$file" 600 || return 1
}

# units (R-BOOT-3, R-SEC-2): enabled or the autologin drop-in never
# gets written. KIDS_UNITS/SOCKETS/TIMERS come from lib/kids.sh, shared
# with bin/omarchy-kids-wizard's Apply-time enable --now (issue #46).
unit_link() { printf '%s/etc/systemd/system/%s.wants/%s' "$(posture_root)" "$1" "$2"; }
units_ok() {
  local u
  for u in "${KIDS_UNITS[@]}"; do [[ -L "$(unit_link multi-user.target "$u")" ]] || return 1; done
  for u in "${KIDS_SOCKETS[@]}"; do [[ -L "$(unit_link sockets.target "$u")" ]] || return 1; done
  for u in "${KIDS_TIMERS[@]}"; do [[ -L "$(unit_link timers.target "$u")" ]] || return 1; done
  # Enabled is not running: on a live system the sockets and timers must be active too.
  if [[ -z "$(posture_root)" ]]; then
    for u in "${KIDS_SOCKETS[@]}" "${KIDS_TIMERS[@]}"; do systemctl is-active --quiet "$u" || return 1; done
  fi
  time_metadata_ok
}
units_fix() {
  local root_args=()
  [[ -n "$(posture_root)" ]] && root_args=(--root="$(posture_root)")
  time_metadata_fix || return 1
  systemctl "${root_args[@]}" enable "${KIDS_UNITS[@]}" "${KIDS_SOCKETS[@]}" "${KIDS_TIMERS[@]}" || return 1
  # On a live system the sockets and timers must also be running now, not at the next boot
  # (seen live: enabled-but-inactive timers, no ledger tick). --root has no running systemd.
  [[ -n "$(posture_root)" ]] || systemctl start "${KIDS_SOCKETS[@]}" "${KIDS_TIMERS[@]}"
}

# parent-group (R-BAR-3, issue #37): the parent must be in omarchy-parents
# to read status.json (0640 root:omarchy-parents), or the bar renders nothing.
parent_group_ok() {
  local parent
  parent="$(conf_get "$MACHINE_CONF" parent 2>/dev/null || true)"
  [[ -n "$parent" ]] || return 2 # machine.conf names no parent yet
  has_group "$(current_groups "$parent")" omarchy-parents
}
parent_group_fix() {
  local parent
  parent="$(conf_get "$MACHINE_CONF" parent 2>/dev/null || true)"
  [[ -n "$parent" ]] || return 0
  groupadd -f omarchy-parents 2>/dev/null || true
  usermod -aG omarchy-parents "$parent"
}

# hyprland configs: every *.lua in $SHARE/hyprland copied verbatim to
# $ETC/hyprland (R-DESK-1), via omarchy-kids-session --install-configs
# when on PATH, else copied directly here (a scratch tree may lack it).
HYPR_SHARE="$SHARE/hyprland"
HYPR_ETC="$ETC/hyprland"
hyprland_ok() {
  [[ -d "$HYPR_SHARE" ]] || return 2 # the package's own configs are missing
  local f base
  for f in "$HYPR_SHARE"/*.lua; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    [[ -f "$HYPR_ETC/$base" ]] || return 1
    cmp -s "$f" "$HYPR_ETC/$base" || return 1
  done
  return 0
}
hyprland_fix() {
  [[ -d "$HYPR_SHARE" ]] || return 0
  if command -v omarchy-kids-session >/dev/null 2>&1 &&
    OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" omarchy-kids-session --install-configs >/dev/null 2>&1; then
    return 0
  fi
  install -d -m 0755 "$HYPR_ETC" || return 1
  local f base
  for f in "$HYPR_SHARE"/*.lua; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    # atomic replace: Hyprland reloads on change, a half-written file shows a red banner
    install -m 0644 "$f" "$HYPR_ETC/.$base.tmp" && mv -f "$HYPR_ETC/.$base.tmp" "$HYPR_ETC/$base" || return 1
  done
}

# Chromium policy files (R-WEB-1): mode/owner only, for files that
# already exist -- no writer for them exists yet (docs/assert.md).
chromium_dir() { printf '%s/etc/chromium/policies/managed' "$(posture_root)"; }
# The group is part of the lock, not best-effort: chowning best-effort and
# returning 0 regardless used to report `fixed` on a wrong-group file
# forever (review S11). Skipped when the band group doesn't exist here.
chromium_ok() {
  local file="$1" band="${2:-}" group
  [[ "$(file_stat a "$file")" == "640" ]] || return 1
  group="$(group_for_band "$band" 2>/dev/null || true)"
  [[ -n "$group" ]] || return 0
  command -v getent >/dev/null 2>&1 && getent group "$group" >/dev/null 2>&1 || return 0
  [[ "$(file_stat G "$file")" == "$group" ]]
}
chromium_fix() {
  local file="$1" band="${2:-}" group
  chmod 0640 "$file" || return 1
  group="$(group_for_band "$band" 2>/dev/null || true)"
  [[ -n "$group" ]] || return 0
  command -v getent >/dev/null 2>&1 && getent group "$group" >/dev/null 2>&1 || return 0
  chown "root:$group" "$file"
}

# Boot hook (R-BOOT-5): disk-only; the dispatcher gates before any UKI access.
# shellcheck disable=SC2034 # read by the sourcing command (bin/omarchy-kids-assert) and lib/check-locks.sh
HOOK_FILE="$(posture_root)/usr/lib/initcpio/hooks/omarchy-kids-unlock"
find_uki() {
  if [[ -n "${OMARCHY_KIDS_UKI:-}" ]]; then
    printf '%s\n' "$OMARCHY_KIDS_UKI"
    return 0
  fi
  local f
  for f in "$(posture_root)"/boot/EFI/Linux/*.efi; do
    [[ -e "$f" ]] || continue
    printf '%s\n' "$f"
    return 0
  done
  return 1
}
boot_hook_ok() {
  local uki tmp rc
  uki="$(find_uki)" || return 2 # no image found to check
  tmp="$(mktemp "${TMPDIR:-/tmp}/omarchy-kids-assert-initrd.XXXXXX")"
  if objcopy -O binary --only-section=.initrd "$uki" "$tmp" 2>/dev/null &&
    lsinitcpio "$tmp" 2>/dev/null | grep -q omarchy-kids-unlock; then
    rc=0
  else
    rc=1
  fi
  rm -f "$tmp"
  return "$rc"
}
boot_hook_fix() { mkinitcpio -P; }
