# shellcheck shell=bash
# lib/check-pam.sh — omarchy-kids-check's PAM section. Sourced by the
# dispatcher; not meant to be executed directly. docs/check.md.

# pam_faillock_order_check STACK — a genuinely new check, not a restatement
# of omarchy-kids-assert's parent_unlock_ok (docs/check.md's "PAM" section).
pam_faillock_order_check() {
  local stack="$1" file marker line idx=0 marker_idx=-1 preauth_idx=-1 pam_unix_idx=-1
  file="$(posture_pam_dir)/$stack"
  if [[ ! -f "$file" ]]; then
    add_result PAM "pam:faillock-order:$stack" warn "cannot verify: no $file on this box"
    return
  fi
  # A real /etc/pam.d/sddm is 0600 root, so the unprivileged panel (the way a
  # parent normally runs this) cannot read it. That is "cannot verify", not
  # "the marker is missing" (I-6: the panel promises root-needing checks WARN).
  if [[ ! -r "$file" ]]; then
    add_result PAM "pam:faillock-order:$stack" warn "cannot verify: $file is not readable here — run with sudo to check this"
    return
  fi
  marker="$(posture_parent_unlock_marker)"
  if ! grep -qxF "$marker" "$file"; then
    add_result PAM "pam:faillock-order:$stack" fail "the parent-unlock marker isn't in $file at all — run 'omarchy-kids-assert'"
    return
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    idx=$((idx + 1))
    [[ "$line" == "$marker" ]] && marker_idx=$idx
    if [[ "$preauth_idx" == -1 && "$line" == auth*pam_faillock.so*preauth* ]]; then
      preauth_idx=$idx
    fi
    if [[ "$pam_unix_idx" == -1 && "$line" == auth*pam_unix.so* && "$line" != *pam_exec.so* ]]; then
      pam_unix_idx=$idx
    fi
  done <"$file"

  local ok=1 why=""
  if [[ "$preauth_idx" != -1 && "$marker_idx" -lt "$preauth_idx" ]]; then
    ok=0
    why="the parent-unlock line is before the pam_faillock preauth line — a lockout would never be tracked for it"
  fi
  if [[ "$pam_unix_idx" != -1 && "$marker_idx" -gt "$pam_unix_idx" ]]; then
    ok=0
    why="the parent-unlock line is after pam_unix.so — it would never get a chance to short-circuit first"
  fi

  if [[ "$ok" == 1 ]]; then
    add_result PAM "pam:faillock-order:$stack" pass "$stack: the parent-unlock line sits in the right place relative to preauth/pam_unix (docs/authd.md)"
  else
    add_result PAM "pam:faillock-order:$stack" fail "$stack: $why — run 'omarchy-kids-assert', or look for a hand-edit of $file"
  fi
}

# pam_parent_unlock_check STACK REQS — WARN, not the misleading PASS
# parent_unlock_ok alone would give, when the stack file doesn't exist.
pam_parent_unlock_check() {
  local stack="$1" reqs="$2" file
  file="$(posture_pam_dir)/$stack"
  if [[ ! -f "$file" ]]; then
    add_result PAM "pam:parent-unlock:$stack" warn "cannot verify: no $file on this box"
    return
  fi
  # Unreadable is not missing: a 0600 /etc/pam.d/sddm makes `parent_unlock_ok`'s
  # grep fail, which used to read as "the parent-unlock line is missing" under
  # the unprivileged panel (I-6).
  if [[ ! -r "$file" ]]; then
    add_result PAM "pam:parent-unlock:$stack" warn "cannot verify: $file is not readable here — run with sudo to check this ($reqs)"
    return
  fi
  if parent_unlock_ok "$stack"; then
    add_result PAM "pam:parent-unlock:$stack" pass "the parent-unlock line is present in $file ($reqs)"
  else
    add_result PAM "pam:parent-unlock:$stack" fail "the parent-unlock line is missing from $file — run 'omarchy-kids-assert' ($reqs)"
  fi
}

run_pam_section() {
  local lock_stack
  lock_stack="$(posture_parent_unlock_lock_stack)"

  pam_parent_unlock_check sddm "R-SEC-2"
  pam_parent_unlock_check "$lock_stack" "R-SEC-2, R-SEC-3"

  pam_faillock_order_check sddm
  pam_faillock_order_check "$lock_stack"
}
