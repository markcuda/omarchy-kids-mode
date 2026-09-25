# shellcheck shell=bash
# lib/wizard-screens.sh -- omarchy-kids-wizard's Easy-path screens (A1-A13),
# one function per screen, Appendix A order; each returns lib/tui.sh's
# 0/1/130 contract (continue/back/leave) for the driver loop to switch on.
# Sourced by the dispatcher; not meant to be executed directly. See
# docs/wizard.md "The screens, in Appendix A order" for the full walkthrough.

# A1: Welcome.
screen_welcome() {
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=("begin|Begin|")
  local omy=$'Hi! Each kid gets their own desktop.

You stay in charge with your own password, and everything can be undone.'
  tui_screen_choose "Welcome" 1 "$TOTAL_STEPS" 1 "$omy" choices "begin" "$TUI_FOOTER_FIRST"
}

# A2: Parent password (SPEC.md R-WIZ-1), kept in memory for Apply's
# noninteractive sudo ticket. Three tries then leaves, counted here rather than via lib/tui.sh's
# retry loop (its validator runs in a subshell) -- docs/wizard.md.
PARENT_PASSWORD_TRIES=3
screen_parent_password() {
  local attempt=0
  while true; do
    tui_screen_input "First, your password." 2 "$TOTAL_STEPS" 0 "" \
      password "Kids Mode uses it for every grown-up decision. It's the same one you log in with."
    local rc=$?
    ((rc == 0)) || return $rc

    if [[ "$DRY_RUN" == "1" ]] || verify_parent_password "$TUI_REPLY"; then
      # shellcheck disable=SC2034 # global read by bin/omarchy-kids-wizard's driver
      PARENT_PASSWORD="$TUI_REPLY"
      return 0
    fi

    if [[ "${PARENT_AUTH_ERROR:-wrong}" != wrong ]]; then
      echo
      case "$PARENT_AUTH_ERROR" in
        # Issue #4: the socket can be listening while the service is what
        # failed (the fresh-install case was a 226/NAMESPACE on activation),
        # so name both units -- "start the socket" alone repaired nothing.
        unavailable) printf '%s\n' \
          "The parent verifier is unavailable. Ask a grown-up to start omarchy-kids-authd.socket." \
          "Still down? The service is what failed: systemctl status omarchy-kids-authd.service" ;;
        privilege) echo "Could not establish noninteractive privilege. Nothing was changed." ;;
      esac
      return 130
    fi
    attempt=$((attempt + 1))
    if ((attempt >= PARENT_PASSWORD_TRIES)); then
      echo
      echo "That wasn't it."
      return 130
    fi
    # shellcheck disable=SC2034 # read by lib/tui.sh's tui_screen_input on the next redraw
    TUI_PRESET_ERROR="That wasn't it. Try again."
  done
}

# A3: Name.
screen_name() {
  tui_screen_input "What's your kid's name?" 3 "$TOTAL_STEPS" 0 "" \
    text "First name or nickname. It's what they'll see." validate_kid_name
  local rc=$?
  ((rc == 0)) || return $rc
  DISPLAY_NAME="$TUI_REPLY"
  ACCOUNT="$("$CONF_BIN" slug "$DISPLAY_NAME")" || die "could not slug '$DISPLAY_NAME'"
  return 0
}

# A4: Face — a keyboard list of share/avatars/*.svg (the twelve CC0
# animals, Q18); no separate grid widget in lib/tui.sh, a list works too.
screen_face() {
  local -a choices=()
  local f id label
  shopt -s nullglob
  for f in "$SHARE/avatars"/*.svg; do
    id="$(basename "$f" .svg)"
    label="$(tr '[:lower:]' '[:upper:]' <<<"${id:0:1}")${id:1}"
    choices+=("$id|$label|")
  done
  shopt -u nullglob
  if ((${#choices[@]} == 0)); then
    AVATAR="fox"
    return 0
  fi
  tui_screen_choose "Pick $DISPLAY_NAME's face." 4 "$TOTAL_STEPS" 0 "" choices "fox"
  local rc=$?
  ((rc == 0)) || return $rc
  AVATAR="$TUI_REPLY"
  return 0
}

# A5: Age.
screen_band() {
  local -a choices=()
  local b label blurb
  for b in "${VALID_BANDS[@]}"; do
    label="$(band_field "$b" label)"
    blurb="$(band_field "$b" blurb)"
    choices+=("$b|$label|$blurb")
  done
  tui_screen_choose "How old is $DISPLAY_NAME?" 5 "$TOTAL_STEPS" 0 "" choices "6-8"
  local rc=$?
  ((rc == 0)) || return $rc
  BAND="$TUI_REPLY"
  # shellcheck disable=SC2034 # global read by bin/omarchy-kids-wizard's validate_kid_password
  PASSWORD_MIN="$(band_field "$BAND" password_min)"
  adv_init               # seeds every Advanced-checklist row to this band's default
  start_prefetch "$BAND" # R-WIZ-4: backgrounded, never blocks
  return 0
}

# A6: Simple or Advanced. Advanced opens the grouped checklist in place
# of Simple's five one-choice screens (A7-A11) — see the driver loop's
# step-7 special case below.
screen_mode() {
  local choices=(
    "simple|Simple|A few clear choices with sensible defaults. About five minutes."
    "advanced|Advanced|Every setting on one screen."
  )
  tui_screen_choose "How do you want to set up $DISPLAY_NAME's computer?" \
    6 "$TOTAL_STEPS" 0 "" choices "simple"
  local rc=$?
  ((rc == 0)) || return $rc
  # shellcheck disable=SC2034 # global read by bin/omarchy-kids-wizard's driver
  MODE="$TUI_REPLY"
  return 0
}

# A7: Web (Simple). Two band-appropriate options from R-WEB-3's three
# real modes (none/garden/filtered).
screen_web() {
  local -a choices=()
  local default
  case "$BAND" in
    3-5)
      choices=(
        "none|No browser|Simplest and safest for the youngest kids."
        "garden|Only sites you choose|A short list you can grow, if you'd rather start early."
      )
      default="none"
      ;;
    13+)
      choices=(
        "filtered|Filtered open web|Adult content blocked, safe search on."
        "garden|Only sites you choose|A shorter, safer list if you'd rather start there."
      )
      default="filtered"
      ;;
    *)
      choices=(
        "garden|Only sites you choose|A short list you can grow. Best for younger kids."
        "filtered|Filtered open web|Adult content blocked, safe search on."
      )
      default="garden"
      ;;
  esac
  tui_screen_choose "What can $DISPLAY_NAME see on the web?" 7 "$TOTAL_STEPS" 0 "" choices "$default"
  local rc=$?
  ((rc == 0)) || return $rc
  WEB_MODE="$TUI_REPLY"
  return 0
}

# A8: Time (Simple). B leads to two custom fields, per Appendix A.
screen_time() {
  local band_budget band_budget_weekend band_lights band_lights_weekend
  band_budget="$(band_field "$BAND" budget_min)"
  band_budget_weekend="$(band_field "$BAND" budget_min_weekend)"
  band_lights="$(band_field "$BAND" lights_out)"
  band_lights_weekend="$(band_field "$BAND" lights_out_weekend)"
  local current_budget_weekend="${BUDGET_MIN_WEEKEND:-$band_budget_weekend}"
  local current_lights_weekend="${LIGHTS_OUT_WEEKEND:-$band_lights_weekend}"
  local choices=(
    "default|Weekdays: $band_budget min; weekends: $current_budget_weekend min|Lights out: $band_lights weekdays; $current_lights_weekend weekends."
    "custom|I'll set my own|Pick your own minutes and bedtime."
  )
  tui_screen_choose "How much screen time?" 8 "$TOTAL_STEPS" 0 "" choices "default"
  local rc=$?
  ((rc == 0)) || return $rc
  if [[ "$TUI_REPLY" == default ]]; then
    BUDGET_MIN="$band_budget"
    LIGHTS_OUT="$band_lights"
    return 0
  fi
  tui_screen_input "How many minutes a day?" 8 "$TOTAL_STEPS" 0 "" \
    text "A number, like 60." validate_budget_minutes
  rc=$?
  ((rc == 0)) || return $rc
  BUDGET_MIN="$TUI_REPLY"
  tui_screen_input "Lights out at?" 8 "$TOTAL_STEPS" 0 "" \
    text "24-hour time, like 19:30." validate_lights_out
  rc=$?
  ((rc == 0)) || return $rc
  LIGHTS_OUT="$TUI_REPLY"
  return 0
}

summary_weekday_weekend() {
  local weekday="$1" weekend="$2" weekday_default="$3" weekend_default="$4"
  local text="$weekday minutes a day weekdays; $weekend minutes a day weekends"
  if [[ "$weekday" != "$weekday_default" || "$weekend" != "$weekend_default" ]]; then
    text+=' (custom)'
  fi
  printf '%s' "$text"
}

summary_lights_weekday_weekend() {
  local weekday="$1" weekend="$2" weekday_default="$3" weekend_default="$4"
  local text="$weekday weekdays; $weekend weekends"
  if [[ "$weekday" != "$weekday_default" || "$weekend" != "$weekend_default" ]]; then
    text+=' (custom)'
  fi
  printf '%s' "$text"
}

# A9: Apps (Simple). B walks the pack one app at a time via apps_pick_walk
# (lib/tui.sh has no multi-select widget yet).
screen_apps() {
  local names aur_count
  names="$(pack_field "$BAND" label | paste -sd, - | sed 's/,/, /g')"
  # AUR apps in the pack install by hand after setup, not during Apply
  # (bin/omarchy-kids-apps skips them). Say so, so the list is not a promise
  # Apply cannot keep (I-6, R-APPS-1).
  aur_count="$(pack_field "$BAND" pkg | grep -c '^aur:' || true)"
  local -a apps_body=()
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  ((aur_count > 0)) && apps_body=("$aur_count of these install by hand after setup (AUR); the rest install now.")
  local choices=(
    "pack|The $BAND starter pack|$names"
    "pick|Let me pick|Turn any of them off, one at a time."
  )
  tui_screen_choose "Which apps to start with?" 9 "$TOTAL_STEPS" 0 "" choices "pack" "$TUI_FOOTER_DEFAULT" apps_body
  local rc=$?
  ((rc == 0)) || return $rc
  APPS_MODE="$TUI_REPLY"
  if [[ "$APPS_MODE" == pick ]]; then
    apps_pick_walk 9 "$TOTAL_STEPS"
    rc=$?
    ((rc != 0)) && return "$rc"
    ALLOWLIST_IDS="$TUI_REPLY"
  else
    ALLOWLIST_IDS="$(pack_field "$BAND" id | paste -sd, -)" # whole pack, band default
  fi
  return 0
}

# A10: Wi-Fi (Simple).
screen_wifi() {
  local default
  default="$(band_field "$BAND" wifi)"
  local choices=(
    "parent|Ask me first|Wi-Fi requests go through you."
    "helper|On their own, safely|They can join school or café Wi-Fi. The network can't change what's blocked."
  )
  tui_screen_choose "Can $DISPLAY_NAME join new Wi-Fi?" 10 "$TOTAL_STEPS" 0 "" choices "$default"
  local rc=$?
  ((rc == 0)) || return $rc
  WIFI_MODE="$TUI_REPLY"
  return 0
}

# A11: Level (Simple), band default marked.
screen_level() {
  local default
  default="$(band_field "$BAND" level)"
  local choices=(
    "1|App grid|Big app tiles. One app fills the screen."
    "3|Desktop|The grown-up Omarchy desktop with its install, update and setup rows hidden. Windows sit side by side."
  )
  # Two kid modes only (SPEC R-DESK-3): Grid (1) and Desktop (3). The old
  # Simplified desktop (2) is retired and never offered.
  tui_screen_choose "How should $DISPLAY_NAME's desktop work?" 11 "$TOTAL_STEPS" 0 "" choices "$default"
  local rc=$?
  ((rc == 0)) || return $rc
  LEVEL="$TUI_REPLY"
  return 0
}

# A12: Kid password. A band whose `password_optional` is true gets an extra
# "set one or not" choice first (R-BAND's password_optional).
screen_password() {
  NO_PASSWORD=0
  if [[ "$(band_field "$BAND" password_optional)" == "true" ]]; then
    local choices=(
      "yes|Set a password|$DISPLAY_NAME types it to get in."
      "no|No password|$DISPLAY_NAME gets in once you start their session, no typing needed."
    )
    tui_screen_choose "Give $DISPLAY_NAME a password?" 12 "$TOTAL_STEPS" 0 "" choices "yes"
    local rc=$?
    ((rc == 0)) || return $rc
    if [[ "$TUI_REPLY" == no ]]; then
      NO_PASSWORD=1
      KID_PASSWORD=""
      return 0
    fi
  fi

  while true; do
    tui_screen_input "Now a password for $DISPLAY_NAME." 12 "$TOTAL_STEPS" 0 "" \
      password "This unlocks $DISPLAY_NAME's screen (and this computer's disk, if it's encrypted) and logs them in." \
      validate_kid_password
    local rc=$?
    ((rc == 0)) || return $rc
    local first="$TUI_REPLY"

    tui_screen_input "Type it again to be sure." 12 "$TOTAL_STEPS" 0 "" \
      password "Same password, once more." validate_kid_password
    rc=$?
    ((rc == 0)) || return $rc

    if [[ "$first" == "$TUI_REPLY" ]]; then
      # shellcheck disable=SC2034 # global read by bin/omarchy-kids-wizard's driver
      KID_PASSWORD="$first"
      return 0
    fi
    # shellcheck disable=SC2034 # read by lib/tui.sh's tui_screen_input on the next redraw
    TUI_PRESET_ERROR="Those didn't match — let's try again."
  done
}

# A13: Summary. "Change something" opens Advanced's own grouped checklist,
# then redraws this summary with whatever changed — a loop, not one screen.
screen_summary() {
  while true; do
    local label blurb apps_desc password_line
    label="$(band_field "$BAND" label)"
    blurb="$(band_field "$BAND" blurb)"
    apps_desc="$(friendly_allowlist "$ALLOWLIST_IDS")"
    # Mark AUR apps in the summary too (I-6), the same as A9.
    local aur_count
    aur_count="$(pack_field "$BAND" pkg | grep -c '^aur:' || true)"
    ((aur_count > 0)) && apps_desc="$apps_desc ($aur_count install by hand after setup, AUR)"
    if ((NO_PASSWORD)); then
      password_line="No password — $DISPLAY_NAME gets in once you start their session."
    else
      password_line="$DISPLAY_NAME types their own password to get in."
    fi

    # shellcheck disable=SC2034 # read by _tui_build_summary_lines via nameref-by-name
    local rows=(
      "Account|$ACCOUNT"
      "Face|$AVATAR"
      "Age band|$label ($blurb)"
      "Desktop|$(mark_if_changed level "$(tui_desktop_label "$LEVEL")")"
      "Web|$(mark_if_changed web "$(friendly_web_mode "$WEB_MODE")")"
      "Screen time|$(summary_weekday_weekend "$BUDGET_MIN" "$BUDGET_MIN_WEEKEND" "$(band_field "$BAND" budget_min)" "$(band_field "$BAND" budget_min_weekend)")"
      "Bedtime|$(summary_lights_weekday_weekend "$LIGHTS_OUT" "$LIGHTS_OUT_WEEKEND" "$(band_field "$BAND" lights_out)" "$(band_field "$BAND" lights_out_weekend)")"
      "Wi-Fi|$(mark_if_changed wifi "$(friendly_wifi_mode "$WIFI_MODE")")"
      "Starter apps|$(mark_if_changed allowlist "$apps_desc")"
      "Password|$password_line"
    )
    adv_summary_extra_rows rows # Advanced-only cells, shown once actually changed
    # One card: build the rows, then let the chooser draw them once. A separate
    # tui_screen_summary here would be cleared by the chooser before it is read.
    _tui_build_summary_lines rows
    TUI_SUMMARY_LINES=("Here's what happens next for $DISPLAY_NAME." "" "${TUI_SUMMARY_LINES[@]}")
    # One line, not a row: a long label would widen every row's padding (N-6).
    TUI_SUMMARY_LINES+=("" "You can pair a parent app for $DISPLAY_NAME's requests later — the panel's Notifications screen does that (the app is still being built).")

    local choices=("apply|Apply|" "change|Change something|")
    tui_screen_choose "Ready?" 13 "$TOTAL_STEPS" 0 "" choices "apply" "$TUI_FOOTER_DEFAULT" TUI_SUMMARY_LINES
    local rc=$?
    ((rc == 0)) || return $rc # Esc/Ctrl+C: go back a screen / leave
    [[ "$TUI_REPLY" == apply ]] && return 0

    screen_advanced_checklist 13 "$TOTAL_STEPS"
    rc=$?
    ((rc == 130)) && return 130
    # rc 0 ("Done customizing") or 1 (Esc out of the checklist's own
    # row list): either way, back to a freshly recomputed summary.
  done
}
