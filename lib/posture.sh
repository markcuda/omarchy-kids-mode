# shellcheck shell=bash
# lib/posture.sh — writers for the machine-level "posture" a kid account
# needs: polkit rules (R-FND-3/4), pam_namespace/PAM stack edits
# (R-FND-2a), the fstab bind-mount line (R-FND-2), the AccountsService
# pin (R-LOGIN-3), and the portal rewrite (R-LOGIN). The luks-slots
# rewrite (R-SEC-4) lives in lib/kids.sh instead -- see the note where
# it used to be, below. Every real path is prefixed by OMARCHY_KIDS_ROOT
# (default empty) for tests.
# Not meant to be executed directly; source it after lib/conf.sh. Full
# design and every env var: docs/portal.md, docs/boot.md.
# shellcheck source=./theme.sh
source "$(dirname "${BASH_SOURCE[0]}")/theme.sh"

posture_root() { printf '%s' "${OMARCHY_KIDS_ROOT:-}"; }

# posture_rebuild_boot_images — rebuild every installed kernel's UKI (docs/boot.md).
# Omarchy boots Limine UKIs built by limine-mkinitcpio and ships no
# /etc/mkinitcpio.d presets, so a bare `mkinitcpio -P` there rebuilds nothing:
# it dies with "No presets found", and Omarchy's /usr/local/bin/mkinitcpio
# wrapper then exits 0 regardless. limine-mkinitcpio itself exits 0 when one
# kernel fails, so its output is checked for that too. stdin is closed so
# neither tool can stop on a prompt inside a pacman hook.
posture_rebuild_boot_images() {
  local out rc
  if ! command -v limine-mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P </dev/null
    return
  fi
  out="$(limine-mkinitcpio </dev/null 2>&1)" && rc=0 || rc=$?
  printf '%s\n' "$out" >&2
  [[ "$rc" -eq 0 ]] && ! grep -q 'mkinitcpio failed for kernel' <<<"$out"
}
posture_polkit_dir() { printf '%s/etc/polkit-1/rules.d' "$(posture_root)"; }
posture_namespace_conf() { printf '%s/etc/security/namespace.conf' "$(posture_root)"; }
posture_pam_dir() { printf '%s/etc/pam.d' "$(posture_root)"; }
posture_fstab() { printf '%s/etc/fstab' "$(posture_root)"; }
posture_accountsservice_dir() { printf '%s/var/lib/AccountsService/users' "$(posture_root)"; }
posture_sddm_conf_dir() { printf '%s/etc/sddm.conf.d' "$(posture_root)"; }
posture_sddm_theme_dir() { printf '%s/usr/share/sddm/themes/omarchy-kids' "$(posture_root)"; }

# posture_install_if_changed FILE CONTENT [MODE] — writes CONTENT (plus a
# trailing newline) to FILE via a same-directory temp file and rename, but
# only if FILE doesn't already hold exactly that. Idempotent: a second call
# with the same CONTENT never touches the file's mtime or leaves a stage
# file behind if the process is killed mid-write.
posture_install_if_changed() {
  local file="$1" content="$2" mode="${3:-0644}" dir stage
  dir="$(dirname "$file")"
  install -d -m 0755 "$dir"
  if [[ -f "$file" ]] && [[ "$(cat "$file")" == "$content" ]]; then
    return 0
  fi
  stage="$(mktemp "$dir/.$(basename "$file").XXXXXX")"
  printf '%s\n' "$content" >"$stage"
  chmod "$mode" "$stage"
  mv -f "$stage" "$file"
}

# --- polkit (R-FND-3, R-FND-4) ---------------------------------------------

# posture_valid_account NAME — account names this file will interpolate
# into a polkit rule or SDDM config. Anchored, bounded, refuses anything
# that could close a JS string or config field (review S9, docs/portal.md).
posture_valid_account() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

posture_polkit_admin_rule_text() {
  local parent="$1"
  posture_valid_account "$parent" || {
    echo "lib/posture.sh: refusing to write a polkit admin rule for an unusable parent name '$parent'" >&2
    return 1
  }
  cat <<RULES
// Omarchy Kids Mode: members of omarchy-kids get the parent account as
// their polkit admin identity (SPEC.md R-FND-3), so the native dialog
// asks for the parent password and checks it against the parent's own
// account -- never root. Written once by "omarchy-kids-provision add";
// left in place by "remove" (machine-level, R-FND-6) until Remove Kids
// Mode takes the whole package out.
polkit.addAdminRule(function(action, subject) {
    if (subject.isInGroup("omarchy-kids")) {
        return ["unix-user:$parent"];
    }
});
RULES
}

# Built into a local first: a $(...) in an argument list swallows its own
# non-zero exit even under set -e (review §2.2, docs/assert.md).
posture_write_polkit_admin_rule() {
  local parent="$1" file text
  file="$(posture_polkit_dir)/40-omarchy-kids.rules"
  text="$(posture_polkit_admin_rule_text "$parent")" || return 1
  posture_install_if_changed "$file" "$text" 0644
}

posture_polkit_deny_rule_text() {
  cat <<'RULES'
// Omarchy Kids Mode: outright denies for kid accounts, no prompt at all
// (SPEC.md R-FND-4). Written once by "omarchy-kids-provision add"; left
// in place by "remove" until Remove Kids Mode.
polkit.addRule(function(action, subject) {
    if (!subject.isInGroup("omarchy-kids")) return null;
    var id = action.id;
    if (id.indexOf("org.freedesktop.NetworkManager.settings.modify") === 0 ||
        id.indexOf("org.freedesktop.udisks2.filesystem-mount") === 0 ||
        id.indexOf("org.freedesktop.udisks2.encrypted-unlock") === 0 ||
        id === "org.freedesktop.udisks2.loop-setup" ||
        id === "org.freedesktop.systemd1.manage-units" ||
        id.indexOf("org.freedesktop.packagekit.") === 0 ||
        id.indexOf("org.freedesktop.Flatpak.") === 0 ||
        id.indexOf("org.omarchy.") === 0) {
        return polkit.Result.NO;
    }
});
RULES
}

posture_write_polkit_deny_rule() {
  local file
  file="$(posture_polkit_dir)/41-omarchy-kids-deny.rules"
  posture_install_if_changed "$file" "$(posture_polkit_deny_rule_text)" 0644
}

# --- pam_namespace (R-FND-2a) -----------------------------------------------

# posture_namespace_line_tmp/shm ACCOUNT — namespace.conf lines for this
# account. In pam_namespace's fourth field, a bare list exempts users from
# polyinstantiation; the leading "~" instead selects only the named kid.
posture_namespace_line_tmp() { printf '/tmp /tmp/kids-inst/ tmpfs:mntopts=nosuid,nodev,noexec ~%s' "$1"; }
posture_namespace_line_shm() { printf '/dev/shm /dev/shm/kids-inst/ tmpfs:mntopts=nosuid,nodev,noexec ~%s' "$1"; }
posture_namespace_legacy_line_tmp() { printf '/tmp /tmp/kids-inst/ tmpfs:mntopts=nosuid,nodev,noexec %s' "$1"; }
posture_namespace_legacy_line_shm() { printf '/dev/shm /dev/shm/kids-inst/ tmpfs:mntopts=nosuid,nodev,noexec %s' "$1"; }

posture_add_namespace_lines() {
  local account="$1" file
  file="$(posture_namespace_conf)"
  install -d -m 0755 "$(dirname "$file")"
  posture_namespace_rewrite "$account" add
}

posture_remove_namespace_lines() {
  posture_namespace_rewrite "$1" remove
}

posture_namespace_rewrite() {
  local account="$1" action="$2" file tmp l1 l2 old_l1 old_l2 line
  file="$(posture_namespace_conf)"
  [[ "$action" == add || -f "$file" ]] || return 0
  l1="$(posture_namespace_line_tmp "$account")"
  l2="$(posture_namespace_line_shm "$account")"
  old_l1="$(posture_namespace_legacy_line_tmp "$account")"
  old_l2="$(posture_namespace_legacy_line_shm "$account")"
  tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")"
  if [[ -f "$file" ]]; then
    cp -p "$file" "$tmp" || {
      rm -f "$tmp"
      return 1
    }
  else
    chmod 0644 "$tmp" || {
      rm -f "$tmp"
      return 1
    }
  fi
  : >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  if [[ -f "$file" ]]; then
    if ! while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" == "$l1" || "$line" == "$l2" || "$line" == "$old_l1" || "$line" == "$old_l2" ]] && continue
      printf '%s\n' "$line" >>"$tmp" || {
        rm -f "$tmp"
        return 1
      }
    done <"$file"; then
      rm -f "$tmp"
      return 1
    fi
  fi
  if [[ "$action" == add ]]; then
    printf '%s\n%s\n' "$l1" "$l2" >>"$tmp" || {
      rm -f "$tmp"
      return 1
    }
  fi
  mv -f "$tmp" "$file"
}

# posture_ensure_pam_namespace PAM_FILE_BASENAME — idempotently appends a
# marker + "session required pam_namespace.so" to /etc/pam.d/<basename>.
posture_pam_namespace_marker() { printf '# omarchy-kids: pam_namespace for kid sessions (R-FND-2a)'; }

posture_ensure_pam_namespace() {
  local base="$1" file marker line
  file="$(posture_pam_dir)/$base"
  marker="$(posture_pam_namespace_marker)"
  line="session required pam_namespace.so"
  install -d -m 0755 "$(dirname "$file")"
  # Arch ships some stacks only under /usr/lib/pam.d (systemd-user). An /etc copy overrides the
  # vendor file wholesale, so seed it from the vendor file before appending, never edit /usr/lib.
  if [[ ! -f "$file" && -f "$(posture_root)/usr/lib/pam.d/$base" ]]; then
    cp "$(posture_root)/usr/lib/pam.d/$base" "$file"
  fi
  touch "$file"
  grep -qxF "$marker" "$file" && return 0
  {
    printf '%s\n' "$marker"
    printf '%s\n' "$line"
  } >>"$file"
}

# --- parent-unlock PAM line (R-SEC-2, R-SEC-3; SPEC.md I-6) ----------------
# One pam_exec line, inserted into sddm and omarchy-lock-password. Never
# touches system-login/system-auth (I-7). Full placement forensics on both
# real stacks this was confirmed against: docs/authd.md.

# posture_parent_unlock_marker — idempotence marker above the pam_exec line.
posture_parent_unlock_marker() { printf '# omarchy-kids: parent-unlock verifier (R-SEC-2, R-SEC-3)'; }

# posture_parent_unlock_line — the exact pam_exec line (docs/authd.md).
posture_parent_unlock_line() {
  printf 'auth       [success=done default=ignore]  pam_exec.so quiet expose_authtok /usr/bin/omarchy-kids-parent-auth'
}

# posture_parent_unlock_lock_stack — the second PAM stack (besides sddm):
# always "omarchy-lock-password" (docs/authd.md's forensics). A function,
# not a literal at every call site, so it changes in one place.
posture_parent_unlock_lock_stack() { printf 'omarchy-lock-password\n'; }

# posture_ensure_parent_unlock_line STACK — inserts the parent-unlock line
# once, idempotently. Fails (writes nothing) if the file has no "auth"
# line to anchor on -- callers decide whether that's fatal.
posture_ensure_parent_unlock_line() {
  local stack="$1" file marker
  file="$(posture_pam_dir)/$stack"
  marker="$(posture_parent_unlock_marker)"
  if [[ ! -f "$file" ]]; then
    echo "posture_ensure_parent_unlock_line: no such PAM stack '$file'" >&2
    return 1
  fi
  grep -qxF "$marker" "$file" && return 0

  # Find the first non-comment "auth" line (a literal "auth" token,
  # not "-auth"), and note whether it is itself a leading
  # "pam_faillock.so ... preauth" line.
  local line anchor_line="" anchor_is_preauth=0 found=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      '' | '#'*) continue ;;
    esac
    if [[ "$line" =~ ^auth[[:space:]] ]]; then
      anchor_line="$line"
      found=1
      if [[ "$line" == *pam_faillock.so* && "$line" == *preauth* ]]; then
        anchor_is_preauth=1
      fi
      break
    fi
  done <"$file"
  if [[ "$found" == 0 ]]; then
    echo "posture_ensure_parent_unlock_line: no non-comment 'auth ...' line in $file to anchor on" >&2
    return 1
  fi

  local tmp inserted=0
  tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$anchor_is_preauth" == 0 && "$inserted" == 0 && "$line" == "$anchor_line" ]]; then
      printf '%s\n' "$marker" >>"$tmp"
      printf '%s\n' "$(posture_parent_unlock_line)" >>"$tmp"
      inserted=1
    fi
    printf '%s\n' "$line" >>"$tmp"
    if [[ "$anchor_is_preauth" == 1 && "$inserted" == 0 && "$line" == "$anchor_line" ]]; then
      printf '%s\n' "$marker" >>"$tmp"
      printf '%s\n' "$(posture_parent_unlock_line)" >>"$tmp"
      inserted=1
    fi
  done <"$file"
  mv -f "$tmp" "$file"
}

# posture_remove_parent_unlock_line STACK — reverses the ensure above.
# No-op if the marker isn't there.
posture_remove_parent_unlock_line() {
  local stack="$1" file marker
  file="$(posture_pam_dir)/$stack"
  marker="$(posture_parent_unlock_marker)"
  [[ -f "$file" ]] || return 0
  grep -qxF "$marker" "$file" || return 0

  local tmp line skip_next=0
  tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$marker" ]]; then
      skip_next=1
      continue
    fi
    if [[ "$skip_next" == 1 ]]; then
      skip_next=0
      continue
    fi
    printf '%s\n' "$line" >>"$tmp"
  done <"$file"
  mv -f "$tmp" "$file"
}

# --- fstab (R-FND-2) --------------------------------------------------------

# posture_fstab_line ACCOUNT — always the real /home path, even under a
# scratch OMARCHY_KIDS_ROOT: read by a real machine's mount at boot.
posture_fstab_line() { printf '/home/%s /home/%s none bind,nosuid,nodev,noexec 0 0' "$1" "$1"; }

posture_add_fstab_line() {
  local account="$1" file line
  file="$(posture_fstab)"
  line="$(posture_fstab_line "$account")"
  install -d -m 0755 "$(dirname "$file")"
  touch "$file"
  grep -qxF "$line" "$file" || printf '%s\n' "$line" >>"$file"
}

posture_remove_fstab_line() {
  local account="$1" file line tmp l
  file="$(posture_fstab)"
  [[ -f "$file" ]] || return 0
  line="$(posture_fstab_line "$account")"
  tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")"
  while IFS= read -r l || [[ -n "$l" ]]; do
    [[ "$l" == "$line" ]] && continue
    printf '%s\n' "$l" >>"$tmp"
  done <"$file"
  mv -f "$tmp" "$file"
}

# --- AccountsService (R-LOGIN-3) -------------------------------------------

# posture_accountsservice_text AVATAR — pins the session, no picker. The
# icon path is always the real installed location, read by the real greeter.
posture_accountsservice_text() {
  local avatar="$1"
  cat <<EOF
[User]
Session=omarchy-kids
XSession=omarchy-kids
Icon=/usr/share/omarchy-kids/avatars/$avatar.svg
EOF
}

posture_write_accountsservice() {
  local account="$1" avatar="$2" file
  file="$(posture_accountsservice_dir)/$account"
  posture_install_if_changed "$file" "$(posture_accountsservice_text "$avatar")" 0644
}

posture_remove_accountsservice() {
  local account="$1"
  rm -f "$(posture_accountsservice_dir)/$account"
}

# --- SDDM face icons (issue #39, live VM finding) --------------------------
# AccountsService's Icon= is NOT what SDDM's UserModel actually reads --
# see docs/portal.md's "Avatars" for the real lookup order and citation.
posture_sddm_faces_dir() { printf '%s/usr/share/sddm/faces' "$(posture_root)"; }

# posture_write_face_icon SRC ACCOUNT — copied byte-for-byte (cmp -s,
# temp-file-then-rename), not routed through posture_install_if_changed's
# text-normalizing helper -- this must be an exact copy of the SVG file.
posture_write_face_icon() {
  local src="$1" account="$2" file dir stage
  if [[ ! -r "$src" ]]; then
    echo "posture_write_face_icon: no such avatar file '$src'" >&2
    return 1
  fi
  file="$(posture_sddm_faces_dir)/$account.face.icon"
  dir="$(dirname "$file")"
  install -d -m 0755 "$dir"
  cmp -s "$src" "$file" 2>/dev/null && return 0
  stage="$(mktemp "$dir/.$(basename "$file").XXXXXX")"
  install -m 0644 "$src" "$stage"
  mv -f "$stage" "$file"
}

# posture_remove_face_icon ACCOUNT — reverses posture_write_face_icon.
posture_remove_face_icon() {
  rm -f "$(posture_sddm_faces_dir)/$1.face.icon"
}

# --- SDDM theme selection (R-LOGIN, issue #14) -----------------------------

# posture_sddm_theme_dropin_text — its own conf.d drop-in, never a
# hand-edit of Omarchy's own (I-7); sorts after it by filename.
posture_sddm_theme_dropin_text() {
  cat <<'EOF'
[Theme]
Current=omarchy-kids
EOF
}

posture_write_sddm_theme_dropin() {
  local file
  file="$(posture_sddm_conf_dir)/zz-omarchy-kids-theme.conf"
  posture_install_if_changed "$file" "$(posture_sddm_theme_dropin_text)" 0644
}

# posture_remove_sddm_theme_dropin — not wired into "remove": machine-level
# (R-FND-6), left in place until Remove Kids Mode (docs/provision.md).
posture_remove_sddm_theme_dropin() {
  rm -f "$(posture_sddm_conf_dir)/zz-omarchy-kids-theme.conf"
}

# --- theme.conf.user: parent detection + avatars for the greeter (issue #39) -
# SDDM's own ThemeConfig::setTo() override, read automatically, no
# restart needed. Root-owned 0644, rewritten in full on every add/remove.
# Full design, the design this replaced, and the live-VM finding: docs/portal.md.

# posture_qsettings_value VALUE [always] — matches QSettings' INI string
# encoder. Lists pass "always" to keep scalar type.
posture_qsettings_value() {
  local value="$1" quote="${2:-auto}" encoded="" ch escaped
  local i code escape_next=0 needs_quotes=0
  for ((i = 0; i < ${#value}; i++)); do
    ch="${value:i:1}"
    [[ "$ch" == ';' || "$ch" == ',' || "$ch" == '=' ]] && needs_quotes=1
    if ((escape_next)) && [[ "$ch" =~ ^[0-9A-Fa-f]$ ]]; then
      printf -v code '%d' "'$ch"
      printf -v escaped '\\x%x' "$code"
      encoded+="$escaped"
      continue
    fi
    escape_next=0
    case "$ch" in
      $'\a') encoded+='\a' ;;
      $'\b') encoded+='\b' ;;
      $'\f') encoded+='\f' ;;
      $'\n') encoded+='\n' ;;
      $'\r') encoded+='\r' ;;
      $'\t') encoded+='\t' ;;
      $'\v') encoded+='\v' ;;
      '"' | $'\\') encoded+="\\$ch" ;;
      *)
        printf -v code '%d' "'$ch"
        if ((code <= 0x1f)); then
          printf -v escaped '\\x%x' "$code"
          encoded+="$escaped"
          escape_next=1
        else
          encoded+="$ch"
        fi
        ;;
    esac
  done
  if [[ "$quote" == always || "$needs_quotes" == 1 || "$encoded" == ' '* || "$encoded" == *' ' ]]; then
    printf '"%s"' "$encoded"
  else
    printf '%s' "$encoded"
  fi
}

posture_qsettings_line() {
  printf '%s=%s\n' "$1" "$(posture_qsettings_value "$2" "${3:-auto}")"
}

# posture_portal_field_encode VALUE — protects the three delimiters in one
# kids= field before QSettings encodes the completed scalar value.
posture_portal_field_encode() {
  local value="$1"
  value="${value//%/%25}"
  value="${value//,/%2C}"
  value="${value//:/%3A}"
  printf '%s' "$value"
}

# posture_parent_home PARENT — thin name for lib/theme.sh's
# account_home (AGENTS.md: no duplicated helpers).
posture_parent_home() { account_home "$1"; }

# posture_theme_conf_lines PARENT — the [General] color/font/geometry keys,
# resolved from PARENT's own theme. Subshell so THEME_KIDS_HOME doesn't
# leak. Full key list: share/sddm-theme/theme.conf's own header.
posture_theme_conf_lines() {
  local parent="$1"
  (
    THEME_KIDS_HOME="$(posture_parent_home "$parent")"
    export THEME_KIDS_HOME
    posture_qsettings_line backgroundColor "$(theme_color background)"
    posture_qsettings_line tileColor "$(theme_color surface)"
    posture_qsettings_line tileHighlightColor "$(theme_color highlight)"
    posture_qsettings_line parentTileColor "$(theme_color surface_muted)"
    posture_qsettings_line accentColor "$(theme_color accent)"
    posture_qsettings_line textColor "$(theme_color foreground)"
    posture_qsettings_line mutedTextColor "$(theme_color muted)"
    posture_qsettings_line errorColor "$(theme_color error)"
    posture_qsettings_line fontFamily "$(theme_font)"
    theme_geometry "$parent" "$(posture_sddm_theme_dir)/theme.conf.user"
  )
}

# posture_portal_parent_accounts PARENT — the recorded parent plus members
# of the two parent groups. Invalid NSS names are ignored before interpolation.
posture_portal_parent_accounts() {
  local parent="$1"
  local group line members_csv member parents=",$parent,"
  local -a members=()
  for group in omarchy-parents wheel; do
    command -v getent >/dev/null 2>&1 || break
    line="$(getent group "$group" 2>/dev/null || true)"
    members_csv="$(awk -F: 'NR == 1 { print $4 }' <<<"$line")"
    [[ -n "$members_csv" ]] || continue
    IFS=',' read -ra members <<<"$members_csv"
    for member in "${members[@]}"; do
      posture_valid_account "$member" || continue
      case "$parents" in
        *",$member,"*) ;;
        *) parents+="$member," ;;
      esac
    done
  done
  printf '%s\n' "${parents#,}" | sed 's/,$//'
}

# posture_portal_conf_text PARENT [ENTRY...] — ENTRY is
# "account<TAB>name<TAB>avatar" (tab, since ':'/',' are separators in the
# "kids=" value below). Followed by the parent allowlist and the
# theme keys, same [General] section (docs/portal.md, docs/theming.md).
posture_portal_conf_text() {
  local parent="$1" kids_field="" sep="" entry account name avatar parents_field
  local encoded_account encoded_name encoded_avatar
  shift
  posture_valid_account "$parent" || {
    echo "lib/posture.sh: refusing to write theme.conf.user for an unusable parent name '$parent'" >&2
    return 1
  }
  for entry in "$@"; do
    IFS=$'\t' read -r account name avatar <<<"$entry"
    encoded_account="$(posture_portal_field_encode "$account")"
    encoded_name="$(posture_portal_field_encode "$name")"
    encoded_avatar="$(posture_portal_field_encode "$avatar")"
    kids_field="${kids_field}${sep}${encoded_account}:${encoded_name}:${encoded_avatar}"
    sep=","
  done
  parents_field="$(posture_portal_parent_accounts "$parent")"
  printf '[General]\n'
  posture_qsettings_line parent "$parent"
  posture_qsettings_line parents "$parents_field" always
  posture_qsettings_line kids "$kids_field" always
  posture_theme_conf_lines "$parent"
}

# posture_write_portal_conf PARENT [ENTRY...] — text built first, same
# shape as posture_write_polkit_admin_rule (review §2.2).
posture_write_portal_conf() {
  local parent="$1"
  shift
  local file text
  file="$(posture_sddm_theme_dir)/theme.conf.user"
  text="$(posture_portal_conf_text "$parent" "$@")" || return 1
  posture_install_if_changed "$file" "$text" 0644
}

# luks-slots parsing/writing (R-SEC-4) moved to lib/kids.sh (parsing was
# duplicated across bin/omarchy-kids-provision and bin/omarchy-kids-remove;
# the writer, posture_write_luks_slots, went with it so bin/omarchy-kids-conf
# doesn't need a second source line just to record the parent's slot --
# docs/provision.md, docs/conf.md).
