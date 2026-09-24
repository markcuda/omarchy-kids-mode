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
  local unit allow deny
  unit="$(relay_unit_file)"
  [[ -f "$unit" && ! -L "$unit" ]] || return 2 # the package is not installed here
  [[ "$(grep -c "^IPAddressAllow=$RELAY_LAN_ALLOW\$" "$unit" 2>/dev/null)" == 1 ]] || return 1
  [[ "$(grep -c '^IPAddressDeny=any$' "$unit" 2>/dev/null)" == 1 ]] || return 1
  if [[ -z "$(posture_root)" ]] && command -v systemctl >/dev/null 2>&1; then
    deny="$(systemctl show "$RELAY_UNIT_NAME" -p IPAddressDeny --value 2>/dev/null || true)"
    allow="$(systemctl show "$RELAY_UNIT_NAME" -p IPAddressAllow --value 2>/dev/null || true)"
    [[ -z "$allow" && -z "$deny" ]] && return 2 # not loaded here
    [[ "$deny" == "any" ]] || return 1
    # The CGNAT range only if the parent's away drop-in is there (N-10).
    if [[ -f "$(relay_away_file)" ]]; then
      [[ "$allow" == *"$RELAY_CGNAT"* ]] || return 1
    else
      [[ "$allow" != *"$RELAY_CGNAT"* ]] || return 1
    fi
  fi
  return 0
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
