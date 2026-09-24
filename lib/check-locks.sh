# shellcheck shell=bash
# lib/check-locks.sh — omarchy-kids-check's Locks section: every
# omarchy-kids-assert lock, reused via its *_ok function only (never
# *_fix — see docs/check.md). Sourced by the dispatcher; not meant to be
# executed directly.

# --- Locks (every omarchy-kids-assert lock, via its *_ok function only) ----

# relay-fence (R-NOTIFY-11.2) — CHECK-ONLY: there is no assert lock behind this
# row, because the fence lives in the package's own unit and assert never rewrites
# a packaged file (I-7). A fail here is a reinstall, not an assert; lock_check's
# standard fail text names assert, so the row uses lock_check_relay_fence.
relay_fence_ok() {
  local unit service allow deny want fragment
  unit="$(relay_unit_file)"
  [[ -f "$unit" && ! -L "$unit" ]] || return 2 # the package is not installed here
  time_metadata_owner_ok "$unit" || return 1
  # Only the [Service] section carries the fence; a line elsewhere does not apply.
  service="$(awk '/^\[Service\]/{f=1;next} /^\[/{f=0} f' "$unit")"
  [[ "$(printf '%s\n' "$service" | grep -c "^IPAddressAllow=$RELAY_LAN_ALLOW\$")" == 1 ]] || return 1
  [[ "$(printf '%s\n' "$service" | grep -c '^IPAddressDeny=any$')" == 1 ]] || return 1
  if [[ -z "$(posture_root)" ]] && command -v systemctl >/dev/null 2>&1; then
    fragment="$(systemctl show "$RELAY_UNIT_NAME" -p FragmentPath --value 2>/dev/null || true)"
    [[ -z "$fragment" ]] && return 2 # not loaded here
    # A full override in /etc/systemd/system shadows the packaged unit: the fence
    # the package installed is not the fence systemd runs.
    [[ "$fragment" == "$unit" ]] || return 1
    allow="$(systemctl show "$RELAY_UNIT_NAME" -p IPAddressAllow --value 2>/dev/null || true)"
    deny="$(systemctl show "$RELAY_UNIT_NAME" -p IPAddressDeny --value 2>/dev/null || true)"
    [[ "$deny" == "any" ]] || return 1
    want="$(systemd_addr_expand "$RELAY_LAN_ALLOW")"
    # The CGNAT range only if the parent's away drop-in is there (N-10).
    [[ -f "$(relay_away_file)" ]] && want="$want $RELAY_CGNAT"
    # Reduce both sides over the one prefix the packaged list and the link-local
    # zone both name: fe80::/10 covers fe80::/64, and systemd may report either or
    # both, so the compare must not depend on that.
    [[ "$(addr_reduce "$allow")" == "$(addr_reduce "$want")" ]] || return 1
  fi
  return 0
}

# systemd expands its three address zone tokens (man systemd.resource-control);
# the comparison is over the expanded set, so the packaged list and what systemd
# reports are compared as the same thing.
systemd_addr_expand() {
  local out="" token
  for token in $1; do
    case "$token" in
      localhost) out="$out 127.0.0.0/8 ::1/128" ;;
      link-local) out="$out 169.254.0.0/16 fe80::/64" ;;
      multicast) out="$out 224.0.0.0/4 ff00::/8" ;;
      *) out="$out $token" ;;
    esac
  done
  printf '%s\n' "$out"
}

# addr_reduce TOKENS — drop a prefix another prefix on the same side covers, for
# the one documented pair here (fe80::/10 covers fe80::/64). Applied to both sides
# of the compare, so it does not matter whether systemd reports the wider prefix,
# the narrower one, or both.
addr_reduce() {
  local set token out=""
  set="$(addr_set "$1")"
  for token in $set; do
    if [[ "$token" == "fe80::/64" && "$set" == *"fe80::/10"* ]]; then continue; fi
    out="$out $token"
  done
  addr_set "$out"
}

# addr_set TOKENS — the tokens as a sorted, space-separated set (order and
# duplicates do not matter to systemd, so they must not matter here).
addr_set() {
  # LC_ALL=C: the compare is between two sets this file builds, and it must not
  # depend on the caller's locale (a C-locale runner would otherwise order
  # differently and the two sides would never match).
  printf '%s' "${1-}" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'
}

run_locks_section() {
  local boot_mode="${1:-}" acct band avatar name n dir cf bt kids_count
  kids_count="$(kid_conf_count)"
  if [[ "$kids_count" == 0 ]]; then
    add_result Locks "locks:none" skip "no kids provisioned; nothing to check (same as 'omarchy-kids-assert' with none provisioned)"
    return
  fi

  while IFS= read -r acct; do
    [[ -n "$acct" ]] || continue
    band="$(profile_field "$acct" band)"
    avatar="$(profile_field "$acct" avatar)"
    name="$(profile_field "$acct" name)"
    lock_check "fstab:$acct" fstab_ok "$acct"
    lock_check "mount:$acct" mount_ok "$acct"
    lock_check "namespace:$acct" namespace_ok "$acct"
    lock_check "accountsservice:$acct" accountsservice_ok "$acct" "$avatar"
    lock_check "gecos:$acct" gecos_ok "$acct" "$name"
    lock_check_warn "face:$acct" face_ok "$acct" "$avatar"
    lock_check "groups:$acct" groups_ok "$acct" "$band"
  done < <(kids_list "$KIDS_DIR")

  lock_check polkit-admin polkit_admin_ok
  lock_check polkit-deny polkit_deny_ok
  lock_check sddm-theme sddm_theme_ok
  lock_check portal-conf portal_conf_ok
  lock_check pam:sddm pam_ok sddm
  lock_check pam:systemd-user pam_ok systemd-user

  local lock_stack
  lock_stack="$(posture_parent_unlock_lock_stack)"
  lock_check parent-unlock:sddm parent_unlock_ok sddm
  lock_check "parent-unlock:$lock_stack" parent_unlock_ok "$lock_stack"

  for n in 2 3 4 5 6; do
    lock_check "getty:tty$n" getty_ok "$n"
  done

  lock_check units units_ok
  # The relay's fence and the two notification stores (R-NOTIFY-11.2).
  lock_check_relay_fence relay-fence relay_fence_ok
  lock_check relay-away relay_away_ok
  lock_check devices devices_ok
  lock_check hyprland-configs hyprland_ok

  dir="$(chromium_dir)"
  if [[ -d "$dir" ]]; then
    for cf in "$dir"/omarchy-kids-*.json; do
      [[ -e "$cf" ]] || continue
      bt="$(basename "$cf")"
      bt="${bt#omarchy-kids-}"
      bt="${bt%.json}"
      lock_check "chromium-policy:$bt" chromium_ok "$cf" "$bt"
    done
  fi

  if [[ "$boot_mode" == disk && -f "$HOOK_FILE" ]]; then
    lock_check boot-hook boot_hook_ok
    lock_check limine-editor limine_editor_ok
  fi

  if [[ "$boot_mode" == disk ]]; then
    lock_check limine-snapshots limine_snapshots_ok
  fi
}
