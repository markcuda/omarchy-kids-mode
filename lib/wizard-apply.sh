# shellcheck shell=bash
# lib/wizard-apply.sh -- omarchy-kids-wizard's Apply screen (A13b) and its
# five steps: getok, account, web, pkgs, safety, then Done (A14). Sourced
# by the dispatcher; not meant to be executed directly. See docs/wizard.md
# "Apply's five steps" for the exit-code/logging contract each step follows.

# Step 1: write machine.conf's parent= first. Step 2 already holds the
# sudo ticket used by every command in this run.
apply_step_getok() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  [dry-run] sudo -v\n'
    printf '  [dry-run] sudo %q machine set parent %q\n' "$CONF_BIN" "$INVOKING_USER"
    printf '  [dry-run] sudo systemctl enable --now'
    printf ' %q' "${KIDS_UNITS[@]}" "${KIDS_SOCKETS[@]}" "${KIDS_TIMERS[@]}"
    printf '\n'
    printf '  [dry-run] sudo install -d -m 0755 %q\n' "$(dirname "$SETUP_LOG")"
    return 0
  fi
  sudo -n "$CONF_BIN" machine set parent "$INVOKING_USER" || return 1
  sudo -n systemctl enable --now "${KIDS_UNITS[@]}" "${KIDS_SOCKETS[@]}" "${KIDS_TIMERS[@]}" || return 1
  sudo -n install -d -m 0755 "$(dirname "$SETUP_LOG")"
}

# prepare_apply_log — establish the existing ticket and open the log
# before any step output enters a pipeline.
prepare_apply_log() {
  [[ "$DRY_RUN" == "1" ]] && return 0
  sudo -n -v >/dev/null 2>&1 || return 1
  sudo -n install -d -m 0755 "$(dirname "$SETUP_LOG")" || return 1
  sudo -n touch "$SETUP_LOG"
}

# Step 2: the account, plus every Appendix B override (R-BAND-2). A
# failed override doesn't stop the rest, so a parent sees every problem
# at once rather than one at a time across re-runs.
apply_step_account() {
  local rc=0
  if ((NO_PASSWORD)); then
    run_priv_stdin "$PROVISION_BIN" add "$DISPLAY_NAME" --band "$BAND" --avatar "$AVATAR" --no-password --apply </dev/null
  elif [[ "$DRY_RUN" == "1" ]]; then
    printf '%s\n%s\n' "$KID_PASSWORD" "$PARENT_PASSWORD" |
      run_priv_stdin "$PROVISION_BIN" add "$DISPLAY_NAME" --band "$BAND" --avatar "$AVATAR" --password-stdin --parent-password-stdin --apply
  else
    local boot_mode
    if ! boot_mode="$(sudo -n "$CONF_BIN" machine get boot 2>/dev/null)"; then
      echo "Could not read the active boot mode; account setup stopped." >&2
      return 1
    fi
    case "$boot_mode" in
      portal)
        printf '%s\n' "$KID_PASSWORD" |
          run_priv_stdin "$PROVISION_BIN" add "$DISPLAY_NAME" --band "$BAND" --avatar "$AVATAR" --password-stdin --apply
        ;;
      disk)
        printf '%s\n%s\n' "$KID_PASSWORD" "$PARENT_PASSWORD" |
          run_priv_stdin "$PROVISION_BIN" add "$DISPLAY_NAME" --band "$BAND" --avatar "$AVATAR" --password-stdin --parent-password-stdin --apply
        ;;
      *)
        echo "Unsupported active boot mode '$boot_mode'; account setup stopped." >&2
        return 1
        ;;
    esac
  fi
  rc=$?
  ((rc == 0)) || return "$rc"

  maybe_override level "$LEVEL" "$(band_field "$BAND" level)" || rc=$?
  maybe_override web "$WEB_MODE" "$(band_field "$BAND" web)" || rc=$?
  maybe_override wifi "$WIFI_MODE" "$(band_field "$BAND" wifi)" || rc=$?
  maybe_override budget_min "$BUDGET_MIN" "$(band_field "$BAND" budget_min)" || rc=$?
  maybe_override lights_out "$LIGHTS_OUT" "$(band_field "$BAND" lights_out)" || rc=$?
  maybe_override allowlist "$ALLOWLIST_IDS" "$(pack_field "$BAND" id | paste -sd, -)" || rc=$?
  maybe_override dns "$DNS_MODE" "$(band_field "$BAND" dns)" || rc=$?
  maybe_override sites "$SITES" "$(pack_sites "$BAND")" || rc=$?
  maybe_override history_visible "$HISTORY_VISIBLE" "$(band_field "$BAND" history_visible)" || rc=$?
  maybe_override budget_min_weekend "$BUDGET_MIN_WEEKEND" "$(band_field "$BAND" budget_min_weekend)" || rc=$?
  maybe_override lights_out_weekend "$LIGHTS_OUT_WEEKEND" "$(band_field "$BAND" lights_out_weekend)" || rc=$?
  # theme's default is the parent's own current theme, not a band value
  # (docs/theming.md) -- $PROVISION_BIN's theme step already copied it.
  maybe_override theme "$THEME" "$(theme_current_name)" || rc=$?
  return "$rc"
}

# Step 3: web policy.
apply_step_web() {
  run_priv "$WEB_BIN" install "$BAND" --apply
}

# Step 4: starter pack via omarchy-kids-apps --now, synchronous so the
# checkmark means the packages are really in. Always the whole band pack;
# the allowlist apply_step_account writes is what restricts the launcher.
apply_step_pkgs() {
  run_priv "$APPS_BIN" install "$BAND" --now --apply
}

# Step 5: the safety check (A13c) -- see docs/wizard.md "The safety check".
apply_step_safety() {
  local rc=0
  run_priv "$ASSERT_BIN"
  rc=$?
  if [[ "$DRY_RUN" == "1" ]] || id "$ACCOUNT" >/dev/null 2>&1; then
    run_priv_as "$ACCOUNT" "$SESSION_BIN" --check-setup
    local session_rc=$?
    ((session_rc == 0)) || rc=$session_rc
  else
    echo "  (skipping the session check — account $ACCOUNT does not exist)"
    rc=1
  fi
  return "$rc"
}

# run_apply_step LABEL FUNC — runs FUNC, tees its output live and (a real
# run only) to $SETUP_LOG (R-WIZ-5). FUNC's own exit code, via
# PIPESTATUS, decides ✓/✗ -- docs/wizard.md "Apply's five steps".
run_apply_step() {
  local func="$2" tmp rc line
  tmp="$(mktemp)"
  if [[ "$DRY_RUN" == "1" ]]; then
    "$func" 2>&1 | tee "$tmp"
    rc="${PIPESTATUS[0]}"
  else
    "$func" 2>&1 | tee "$tmp"
    rc="${PIPESTATUS[0]}"
    if ! sudo -n tee -a "$SETUP_LOG" <"$tmp" >/dev/null; then
      rc=1
      APPLY_LOG_FAILED=1
    fi
    if ! sudo -n -v >/dev/null 2>&1; then
      APPLY_AUTH_EXPIRED=1
    fi
  fi
  if ((rc != 0)); then
    echo
    echo "\"$1\" failed. Last lines:"
    tail -n 10 "$tmp"
    APPLY_FAILURE_TAIL=()
    while IFS= read -r line; do APPLY_FAILURE_TAIL+=("$line"); done < <(tail -n 6 "$tmp")
  fi
  rm -f "$tmp"
  return "$rc"
}

# A13b/A13c: Apply, then the safety check. Stops at the first failing
# step (real run only) rather than reporting success for a step that
# changed nothing -- docs/wizard.md "Apply's five steps".
screen_apply() {
  tui_header "Apply" 14 "$TOTAL_STEPS" 0 ""
  echo

  # shellcheck disable=SC2034 # read by tui_progress via nameref-by-name
  local steps=(
    "Getting your OK"
    "Setting up $DISPLAY_NAME's account"
    "Turning on the safe browser rules"
    "Installing $BAND starter apps"
    "Checking setup safeguards"
  )
  local -a funcs=(apply_step_getok apply_step_account apply_step_web apply_step_pkgs apply_step_safety)
  local total=${#steps[@]} i rc k

  tui_progress steps 0 "You can watch this happen — nothing here needs another click."

  APPLY_FAILURE_TAIL=()
  APPLY_LOG_FAILED=0
  APPLY_OK=1
  if ! prepare_apply_log; then
    APPLY_OK=0
    APPLY_AUTH_EXPIRED=1
    FAILED_STEP="${steps[0]}"
    echo
    echo "Authorization expired or the setup log is unavailable. Return to Step 2 to verify again."
    return 1
  fi
  # Only a real run has changed anything, so only then is leaving a
  # "your changes stay" situation (I-6).
  if [[ "$DRY_RUN" != "1" ]]; then
    APPLY_STARTED=1
    TUI_LEAVE_MESSAGE="Leave setup? Apply has already made its changes; they stay."
  fi
  for ((i = 0; i < total; i++)); do
    run_apply_step "${steps[i]}" "${funcs[i]}"
    rc=$?
    if ((APPLY_AUTH_EXPIRED)); then
      echo
      echo "Authorization expired. Return to Step 2 to verify again."
      return 1
    fi
    if [[ "$DRY_RUN" != "1" ]] && ((rc != 0)); then
      APPLY_OK=0
      for ((k = 0; k < total; k++)); do
        if ((k < i)); then
          echo "  ✓ ${steps[k]}"
        elif ((k == i)); then
          echo "  ✗ ${steps[k]}"
        else
          echo "  · ${steps[k]}"
        fi
      done
      FAILED_STEP="${steps[i]}"
      return 0
    fi
    if ((i == total - 1)); then
      tui_progress steps $((i + 1)) "The technical log is at $SETUP_LOG."
    else
      tui_progress steps $((i + 1))
    fi
  done
  return 0
}

# A14: Done. One action: an "open the desktop" preview does not exist on
# Omarchy 4.0.2, so offering the button would be a control that cannot work
# (SPEC.md R-WIZ-6's amendment, docs/wizard.md).
screen_done() {
  local headline omy footer
  if ((APPLY_OK)); then
    headline="$DISPLAY_NAME's setup is complete. Final safety checks run when they sign in."
    omy="$headline Next time the computer starts, $DISPLAY_NAME signs in from the login screen."
    omy+=" Want a peek at $DISPLAY_NAME from your own bar? Run 'omarchy-kids-bar enable' any time — it only changes what you ask it to."
  else
    headline="Setup stopped at \"$FAILED_STEP\"."
    if ((APPLY_LOG_FAILED)); then
      omy="$headline The failed step's own lines are below."
    else
      omy="$headline Details are in the setup log: $SETUP_LOG"
    fi
  fi
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=(
    "parent|Return to my desktop|"
  )
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local body=()
  if ((!APPLY_OK)) && ((${#APPLY_FAILURE_TAIL[@]})); then
    body+=("Last lines from the failed step:")
    body+=("${APPLY_FAILURE_TAIL[@]}")
  fi
  footer="Enter finish"
  if ((APPLY_STARTED)); then
    footer="Enter finish · Ctrl+C leave (changes stay)"
  fi
  tui_screen_choose "Done" 15 "$TOTAL_STEPS" 1 "$omy" choices "parent" "$footer" body
  local rc=$?
  return $((rc == 130 ? 130 : 0))
}
