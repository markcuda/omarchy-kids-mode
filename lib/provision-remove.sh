# shellcheck shell=bash
# lib/provision-remove.sh — omarchy-kids-provision's "remove" subcommand.
# Sourced by the dispatcher; not meant to be executed directly. docs/provision.md.

cmd_remove() {
  local account="" keep_home=0 luks_device=""

  while (($#)); do
    case "$1" in
      --keep-home)
        keep_home=1
        shift
        ;;
      --luks-device)
        luks_device="${2:?--luks-device needs a value}"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --) shift ;;
      -*) die "remove: unknown option '$1'" ;;
      *)
        if [[ -z "$account" ]]; then account="$1"; else die "remove: unexpected argument '$1'"; fi
        shift
        ;;
    esac
  done

  [[ -n "$account" ]] || die "remove: needs an account"
  local boot_mode
  boot_mode="$(read_boot_mode)"
  if [[ "$boot_mode" == portal && -n "$luks_device" ]]; then
    die "remove: --luks-device is not available in portal mode"
  fi
  local profile="$KIDS_DIR/$account.conf"
  [[ -e "$profile" ]] || die "remove: no such kid account '$account' (no profile at $profile)"

  local display_name
  display_name="$(conf_get "$profile" name 2>/dev/null || true)"
  [[ -n "$display_name" ]] || display_name="$account"

  echo "Removing kid $account"

  # R-SEC-4: portal mode cannot prove a recorded key is gone. Disk mode
  # journals the slot before killing it, then completes or resumes the map.
  local slot="" device="" intent="" intent_file
  slot="$(luks_slot_for_account "$SLOTS_FILE" "$account" || true)"
  intent_file="$(luks_removal_intent_file "$SLOTS_FILE" "$account")"
  if [[ -e "$intent_file" ]]; then
    intent="$(luks_read_removal_intent "$SLOTS_FILE" "$account")" ||
      die "remove: invalid LUKS removal intent at $intent_file; repair it before retrying" 1
    slot="${intent%% *}"
  fi
  if [[ "$boot_mode" == portal && -n "$slot" ]]; then
    die "remove: portal mode cannot verify recorded LUKS slot $slot for $account; remove the slot in disk mode first" 1
  fi
  if [[ "$boot_mode" == disk && -n "$slot" ]]; then
    device="$(detect_luks_device "$luks_device")" ||
      die "remove: disk mode cannot find the LUKS root for slot $slot" 1
    if [[ "$DRY_RUN" == "0" ]]; then
      luks_remove_account_slot "$SLOTS_FILE" "$account" "$device" ||
        die "remove: LUKS slot removal did not finish for $account" 1
    else
      run luks_remove_account_slot "$SLOTS_FILE" "$account" "$device"
    fi
  fi

  # R-FND-2a
  run posture_remove_namespace_lines "$account"

  # R-LOGIN-3
  run posture_remove_accountsservice "$account"

  # R-LOGIN, issue #39
  run posture_remove_face_icon "$account"

  # R-LOGIN, issue #39: theme.conf.user rebuilt without this account.
  local parent portal_entries=() line
  parent="$(read_parent)"
  while IFS= read -r line; do
    [[ -n "$line" ]] && portal_entries+=("$line")
  done < <(portal_conf_entries "$KIDS_DIR" "$account")
  run posture_write_portal_conf "$parent" "${portal_entries[@]+"${portal_entries[@]}"}"

  # R-FND-2: unmount and drop the fstab line.
  run umount "$(home_dir_for "$account")"
  run posture_remove_fstab_line "$account"

  # Appendix B
  run launcher_map_remove "$account"
  run session_manifest_remove "$account"

  # R-FND-6: the account, then its home.
  run userdel "$account"
  if ((! keep_home)); then
    local dest parent_home
    parent_home="$(parent_home_dir "$MACHINE_CONF")"
    dest="$parent_home/Kids Mode/$display_name"
    run install -d -m 0755 "$parent_home/Kids Mode"
    run mv "$(home_dir_for "$account")" "$dest"
  fi
  # Keep the profile as the retry record until the account and home are done.
  run rm -f "$profile"

  echo "Done: $account removed"
  echo "(groups, console masks, and the polkit rules stay until Remove Kids Mode -- SPEC.md R-FND-6)"
}
