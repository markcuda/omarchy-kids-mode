# shellcheck shell=bash
# lib/panel-kid.sh — omarchy-kids-panel's P2 (one kid): time (weekday and
# weekend), web, Wi-Fi, apps, plugins, data, desktop (level, theme — issue
# #53), password, reset to band defaults, remove — screen_kid is the row
# menu that dispatches to each. Sourced by the dispatcher; not meant to be
# executed directly.

# --- P2: one kid -------------------------------------------------------------

# One line the Kid screen shows on its next draw, for a screen that has
# nothing left to show of its own (a failed read, a mistyped name): the
# card clears, so it has to be carried, not echoed (review §3.1).
KID_NOTICE=""

screen_kid_time() { # ACCOUNT NAME
  local account="$1" name="$2"
  while true; do
    local status_out budget lights budget_we lights_we line
    status_out="$("$TIME_BIN" status "$account" 2>&1)"
    budget="$(kid_conf_get "$account" budget_min)"
    lights="$(kid_conf_get "$account" lights_out)"
    budget_we="$(kid_conf_get "$account" budget_min_weekend)"
    lights_we="$(kid_conf_get "$account" lights_out_weekend)"
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    while IFS= read -r line; do facts+=("${line#"$account: "}"); done <<<"$status_out"
    panel_notice_lines facts

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local choices=(
      "grant|Give more minutes today|"
      "budget|Change weekday daily budget (now $budget min)|"
      "lights|Change weekday lights-out (now $lights)|"
      "budget_we|Change weekend daily budget (now $budget_we min)|"
      "lights_we|Change weekend lights-out (now $lights_we)|"
      "back|Back|"
    )
    tui_screen_choose "$name's screen time" 1 1 0 "" choices "grant" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0

    case "$TUI_REPLY" in
      grant)
        tui_screen_input "How many more minutes today?" 1 1 0 "" \
          text "A number, like 15." validate_positive_minutes
        rc=$?
        ((rc == 130)) && return 130
        ((rc == 0)) && run_priv "$TIME_BIN" grant "$account" "$TUI_REPLY"
        ;;
      budget)
        tui_screen_input "How many minutes a day?" 1 1 0 "" \
          text "A number, 1 to 1440." validate_budget_minutes
        rc=$?
        ((rc == 130)) && return 130
        ((rc == 0)) && run_priv "$CONF_BIN" set "$account" budget_min "$TUI_REPLY"
        ;;
      lights)
        tui_screen_input "Lights out at?" 1 1 0 "" \
          text "24-hour time, like 19:30." validate_lights_out
        rc=$?
        ((rc == 130)) && return 130
        ((rc == 0)) && run_priv "$CONF_BIN" set "$account" lights_out "$TUI_REPLY"
        ;;
      budget_we)
        tui_screen_input "How many minutes a day on weekends?" 1 1 0 "" \
          text "A number, 1 to 1440." validate_budget_minutes
        rc=$?
        ((rc == 130)) && return 130
        ((rc == 0)) && run_priv "$CONF_BIN" set "$account" budget_min_weekend "$TUI_REPLY"
        ;;
      lights_we)
        tui_screen_input "Weekend lights-out at?" 1 1 0 "" \
          text "24-hour time, like 20:00." validate_lights_out
        rc=$?
        ((rc == 130)) && return 130
        ((rc == 0)) && run_priv "$CONF_BIN" set "$account" lights_out_weekend "$TUI_REPLY"
        ;;
      back) return 0 ;;
    esac
  done
}

# screen_kid_wifi ACCOUNT NAME — the Wi-Fi mode that used to be wizard-only
# (R-WIZ-8's "every setting"): parent (Ask) or helper (the root helper).
# Labels come from lib/kids.sh's friendly_wifi_mode so the wizard and the
# panel cannot drift.
screen_kid_wifi() { # ACCOUNT NAME
  local account="$1" name="$2" current mode_label
  current="$(kid_conf_get "$account" wifi)"
  if [[ "$current" == parent || "$current" == helper ]]; then
    mode_label="$(friendly_wifi_mode "$current")"
  else
    current=""
    mode_label="not set (the band's default applies)"
  fi
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local facts=("Mode: $mode_label")
  panel_notice_lines facts
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=(
    "parent|Ask me first|They can't join new Wi-Fi themselves; you join it from your account."
    "helper|On their own, safely|The root helper joins what they ask for. The network can't change what's blocked."
    "back|Back|"
  )
  tui_screen_choose "$name's Wi-Fi" 1 1 0 "" choices "$current" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  [[ "$TUI_REPLY" == back ]] && return 0
  [[ "$TUI_REPLY" != "$current" ]] &&
    run_priv "$CONF_BIN" set "$account" wifi "$TUI_REPLY"
  return 0
}

# screen_kid_reset ACCOUNT NAME — clear per-kid overrides back to the
# band's defaults, keeping identity (account, name, avatar, band, password,
# onboarded) and theme (omarchy-kids-conf reset). Confirmed, because it
# discards every custom choice at once.
screen_kid_reset() { # ACCOUNT NAME
  local account="$1" name="$2"
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local facts=(
    "Every other screen for this kid goes back to the band's defaults:"
    "time, web (and safe-search DNS), Wi-Fi, apps, data, desktop level"
    "and menu. Any sites you added by hand go back too."
    "The account, name, face, band, password and theme stay."
    ""
    "It does not undo screen time already used today."
  )
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=("reset|Reset|" "back|Keep my settings|")
  tui_screen_choose "Reset $name to band defaults?" 1 1 0 "" choices "back" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  [[ "$TUI_REPLY" == reset ]] && run_priv "$CONF_BIN" reset "$account"
  return 0
}

screen_kid_web() { # ACCOUNT NAME
  local account="$1" name="$2" band mode allow_file
  band="$(kid_conf_get "$account" band)"
  mode="$(kid_conf_get "$account" web)"
  allow_file="$ETC/kids/$account/allow.txt"

  if [[ "$mode" != garden ]]; then
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=(
      "Mode: $(friendly_web_mode "$mode")"
      "Editable list: no — this mode has no allow list (SPEC.md R-WEB-3)"
    )
    panel_notice_lines facts
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local choices=("back|Back|")
    tui_screen_choose "$name's web" 1 1 0 "" choices "back" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    return 0
  fi

  while true; do
    local -a lines=()
    local l
    if [[ -r "$allow_file" ]]; then
      while IFS= read -r l; do [[ -n "$l" ]] && lines+=("$l"); done <"$allow_file"
    fi
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=("$name's allowed sites (mode: only sites you choose):")
    if ((${#lines[@]} == 0)); then
      facts+=("  (none of the kid's own yet — the band's starter list still applies)")
    else
      for l in "${lines[@]}"; do facts+=("  - $l"); done
    fi
    panel_notice_lines facts

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local choices=("add|Add a site|")
    # "Remove a site" only when there is one (I-6: no control that does nothing).
    ((${#lines[@]})) && choices+=("remove|Remove a site|")
    choices+=("back|Back|")
    tui_screen_choose "$name's web" 1 1 0 "" choices "add" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0

    case "$TUI_REPLY" in
      add)
        tui_screen_input "Add which site?" 1 1 0 "" \
          text "A hostname, like example.com." validate_hostname
        rc=$?
        ((rc == 130)) && return 130
        if ((rc == 0)); then
          lines+=("$TUI_REPLY")
          # warm_sudo first, in *this* shell: write_root_file is the
          # receiving end of a pipe below, so it runs in a subshell
          # that can't set our SUDO_WARMED flag back here — without
          # this, the "one warm-up prompt" would print twice.
          warm_sudo || continue
          if ! printf '%s\n' "${lines[@]}" | write_root_file "$allow_file"; then
            PANEL_NOTICE="That change failed: could not write the site list."
            continue
          fi
          if ! run_priv "$WEB_BIN" install "$band" --allow "$allow_file" --apply; then
            PANEL_NOTICE+=" (the site list was saved; the policy was not applied)"
          fi
        fi
        ;;
      remove)
        local -a rchoices=()
        local site
        for site in "${lines[@]}"; do rchoices+=("$site|$site|"); done
        rchoices+=("back|Never mind|")
        tui_screen_choose "Remove which site?" 1 1 0 "" rchoices "back"
        rc=$?
        ((rc == 130)) && return 130
        if ((rc == 0)) && [[ "$TUI_REPLY" != back ]]; then
          local -a kept=()
          for site in "${lines[@]}"; do [[ "$site" != "$TUI_REPLY" ]] && kept+=("$site"); done
          warm_sudo || continue
          if ((${#kept[@]} == 0)); then
            if ! write_root_file "$allow_file" </dev/null; then
              PANEL_NOTICE="That change failed: could not write the site list."
              continue
            fi
          else
            if ! printf '%s\n' "${kept[@]}" | write_root_file "$allow_file"; then
              PANEL_NOTICE="That change failed: could not write the site list."
              continue
            fi
          fi
          if ! run_priv "$WEB_BIN" install "$band" --allow "$allow_file" --apply; then
            PANEL_NOTICE+=" (the site list was saved; the policy was not applied)"
          fi
        fi
        ;;
      back) return 0 ;;
    esac
  done
}

screen_kid_apps() { # ACCOUNT NAME
  local account="$1" name="$2"
  while true; do
    local list_out allow
    list_out="$("$APPS_BIN" list "$account" --json 2>/dev/null)" || {
      KID_NOTICE="Could not read $name's app pack."
      return 0
    }
    allow="$("$APPS_BIN" allowlist "$account" 2>/dev/null)"

    local -a choices=()
    local id label state suffix
    while IFS=$'\t' read -r id label state; do
      [[ -n "$id" ]] || continue
      # Say when the app isn't installed: with apps.show_missing=no (the
      # default) the launcher omits it whatever this toggle says, so "(shown)"
      # alone would name a tile the kid never sees (I-6).
      suffix=""
      [[ "$state" == missing ]] && suffix=", not installed"
      if is_in_csv "$id" "$allow"; then
        choices+=("$id|$label (shown$suffix)|")
      else
        choices+=("$id|$label (hidden$suffix)|")
      fi
    done < <(jq -r '.[] | [.id, .label, .state] | @tsv' <<<"$list_out" 2>/dev/null)
    choices+=("plugins|Plugins shelf|Marketplace plugins, category Kids, verified only")
    choices+=("back|Back|")

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    panel_notice_lines facts
    tui_screen_choose "$name's apps — Enter toggles" 1 1 0 "" choices "back" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    case "$TUI_REPLY" in
      back) return 0 ;;
      plugins)
        screen_kid_plugins "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      *)
        if is_in_csv "$TUI_REPLY" "$allow"; then
          run_priv "$APPS_BIN" hide "$account" "$TUI_REPLY"
        else
          run_priv "$APPS_BIN" show "$account" "$TUI_REPLY"
        fi
        ;;
    esac
  done
}

# screen_kid_plugins ACCOUNT NAME — the "Plugins shelf" row under Apps
# (SPEC.md R-APPS-7, issue #28): marketplace listings, category Kids,
# verified only (never --all -- I-6, only what Enter can install shows).
# Enter installs for this kid, same sudo path as every other write.
# Reads shelf's --json (like screen_kid_apps reads `apps list --json`)
# instead of parsing the human table's columns.
screen_kid_plugins() { # ACCOUNT NAME
  local account="$1" name="$2" band
  band="$(kid_conf_get "$account" band)"
  while true; do
    local shelf_out
    shelf_out="$("$PLUGINS_BIN" shelf --band "$band" --json 2>/dev/null)" || true

    local -a choices=()
    local id label desc
    while IFS=$'\t' read -r id label desc; do
      [[ -n "$id" ]] || continue
      choices+=("$id|$label|$desc")
    done < <(jq -r '.[] | [.id, .name, .description] | @tsv' <<<"$shelf_out" 2>/dev/null)

    if ((${#choices[@]} == 0)); then
      # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
      local -a facts=("Nothing on the Kids shelf yet for $name's band ($band).")
      panel_notice_lines facts
      # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
      local -a empty_choices=("back|Back|")
      tui_screen_choose "$name's plugins shelf" 1 1 0 "" empty_choices "back" "" facts
      local rc=$?
      ((rc == 130)) && return 130
      return 0
    fi
    choices+=("back|Back|")

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    panel_notice_lines facts
    tui_screen_choose "$name's plugins shelf — Enter installs" 1 1 0 "" choices "back" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    [[ "$TUI_REPLY" == back ]] && return 0

    run_priv "$PLUGINS_BIN" install "$TUI_REPLY" --kid "$account" --apply
  done
}

# screen_kid_data ACCOUNT NAME — R-DATA-1..5's transparency screen:
# today's/this week's minutes/launches/sites, read-only (issue #27).
# Sites needs root (a kid's Chromium profile is in a home the parent
# can't reach) unless history_visible=no, which omarchy-kids-data
# already says in plain words without root (R-DATA-4).
screen_kid_data() { # ACCOUNT NAME
  local account="$1" name="$2" hv line
  hv="$(kid_conf_get "$account" history_visible)"

  # Sites need root; minutes and launches don't (R-DATA-4), so read_priv
  # only where it's really needed. Warm its one prompt here, in *this*
  # shell: the reads below run in subshells that can't set the warmed
  # flag back, and their output is the card's body, not the screen.
  local -a summary_cmd=("$DATA_BIN" summary "$account")
  if [[ "$hv" == yes ]]; then
    warm_sudo_read || {
      KID_NOTICE="Couldn't read $name's data without your password."
      return 0
    }
    summary_cmd=(read_priv "${summary_cmd[@]}")
  fi

  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local -a facts=("$name's data — today")
  while IFS= read -r line; do facts+=("${line#"$account: "}"); done < <("${summary_cmd[@]}")
  facts+=("" "$name's data — this week")
  while IFS= read -r line; do facts+=("${line#"$account: "}"); done < <("${summary_cmd[@]}" --week)

  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=("back|Back|")
  tui_screen_choose "$name's data" 1 1 0 "" choices "back" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  return 0
}

screen_kid_level() { # ACCOUNT NAME
  local account="$1" name="$2" current
  current="$(kid_conf_get "$account" level)"
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=(
    "1|App grid|Big app tiles. One app fills the screen."
    "3|Desktop|The grown-up Omarchy desktop with its install, update and setup rows hidden. Windows sit side by side."
  )
  # Two kid modes only (SPEC R-DESK-3): Grid (1) and Desktop (3); the old
  # Simplified desktop (2) is retired and never offered.
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local -a facts=()
  panel_notice_lines facts
  tui_screen_choose "$name's desktop" 1 1 0 "Changes apply next time they sign in." choices "$current" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  [[ "$TUI_REPLY" != "$current" ]] && run_priv "$CONF_BIN" set "$account" level "$TUI_REPLY"
  return 0
}

# screen_kid_theme ACCOUNT NAME — a picker over theme_list_installed's own
# names (lib/theme.sh, issue #53: the system themes dir only, never a
# kid- or parent-installed one — theme_apply_for's own header has why).
# Writing an override here (`omarchy-kids-conf set <kid> theme <name>`)
# is what actually applies the theme to disk as root and best-effort
# reloads a live session — see that command's own cmd_set.
screen_kid_theme() { # ACCOUNT NAME
  local account="$1" name="$2" current
  current="$(kid_conf_get "$account" theme)"
  local -a choices=()
  local t
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    choices+=("$t|$t|")
  done < <(theme_list_installed)
  if ((${#choices[@]} == 0)); then
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=("No installed themes found under \$OMARCHY_PATH/themes — nothing to pick from.")
    panel_notice_lines facts
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local back_choices=("back|Back|")
    tui_screen_choose "$name's theme" 1 1 0 "" back_choices "back" "" facts
    local rc=$?
    ((rc == 130)) && return 130
    return 0
  fi
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local -a facts=()
  panel_notice_lines facts
  tui_screen_choose "$name's theme" 1 1 0 "" choices "$current" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0
  [[ "$TUI_REPLY" != "$current" ]] && run_priv "$CONF_BIN" set "$account" theme "$TUI_REPLY"
  return 0
}

# screen_kid_desktop ACCOUNT NAME — the panel's Desktop screen (issue
# #53's own brief: "a row in the panel's Desktop screen"): Desktop level
# and Theme, each opening its own picker above.
screen_kid_desktop() { # ACCOUNT NAME
  local account="$1" name="$2"
  while true; do
    local level_cur theme_cur
    level_cur="$(kid_conf_get "$account" level)"
    theme_cur="$(kid_conf_get "$account" theme)"
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local choices=(
      "level|Desktop|$(tui_desktop_label "$level_cur")"
      "theme|Theme|${theme_cur:-(none set)}"
      "back|Back|"
    )
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=()
    panel_notice_lines facts
    tui_screen_choose "$name's desktop" 1 1 0 "" choices "level" "" facts
    local rc=$?
    case "$rc" in
      130) return 130 ;;
      1) return 0 ;;
    esac
    ((rc == 0)) || return 0
    case "$TUI_REPLY" in
      level)
        screen_kid_level "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      theme)
        screen_kid_theme "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      back) return 0 ;;
    esac
  done
}

# screen_kid_password ACCOUNT NAME — SPEC.md R-WIZ-8's "reset password"
# has no real implementation yet (`omarchy-kids-provision` has no
# `passwd` subcommand today, only `add`/`remove`/`list` — see
# docs/provision.md); this checks for one anyway (future-proofing, per
# the issue brief) and otherwise names the exact command a parent runs
# themselves (I-6: don't claim a control that isn't there).
screen_kid_password() { # ACCOUNT NAME
  local account="$1" name="$2"
  if "$PROVISION_BIN" --help 2>&1 | grep -qE '^ *passwd\b'; then
    tui_screen_input "New password for $name" 1 1 0 "" \
      password "Typed once here; never shown, never logged."
    local rc=$?
    ((rc == 130)) && return 130
    ((rc == 0)) || return 0
    printf '%s\n' "$TUI_REPLY" | {
      warm_sudo || return 1
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  [dry-run] sudo %s passwd %s --apply\n' "$PROVISION_BIN" "$account"
        cat >/dev/null
      else
        sudo "$PROVISION_BIN" passwd "$account" --apply
      fi
    }
    return 0
  fi

  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local -a facts=(
    "Account: $account"
    "Run this: sudo passwd $account"
    ""
    "There's no panel button for this yet — run the line above in a terminal;"
    "it asks for the new password twice and never shows it on screen."
  )
  # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
  local choices=("back|Back|")
  tui_screen_choose "Change $name's password" 1 1 0 "" choices "back" "" facts
  local rc=$?
  ((rc == 130)) && return 130
  return 0
}

KID_JUST_REMOVED=0
screen_kid_remove() { # ACCOUNT NAME
  local account="$1" name="$2"
  tui_screen_input "Type \"$name\" to remove this kid's account" 1 1 0 "" \
    text "Files move to ~parent/Kids Mode/$name/ (SPEC.md R-FND-6); this can't be undone from here."
  local rc=$?
  ((rc == 130)) && return 130
  ((rc == 0)) || return 0

  if [[ "$TUI_REPLY" == "$name" ]]; then
    if run_priv "$PROVISION_BIN" remove "$account" --apply; then
      [[ "$DRY_RUN" == "0" ]] && KID_JUST_REMOVED=1
    fi
  else
    KID_NOTICE="That didn't match \"$name\" — nothing was removed."
  fi
  return 0
}

screen_kid() { # ACCOUNT
  local account="$1" name band
  KID_JUST_REMOVED=0
  while true; do
    name="$(kid_conf_get "$account" name)"
    band="$(kid_conf_get "$account" band)"
    local status_out nreq line
    status_out="$("$TIME_BIN" status "$account" 2>&1)"
    nreq="$(count_open_requests "$account")"
    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local -a facts=("$name — band $band")
    while IFS= read -r line; do facts+=("${line#"$account: "}"); done <<<"$status_out"
    facts+=("Open requests: $nreq")
    if [[ -n "$KID_NOTICE" ]]; then
      facts+=("" "$KID_NOTICE")
      KID_NOTICE=""
    fi
    panel_notice_lines facts

    # shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
    local choices=(
      "time|Screen time|"
      "web|Web|"
      "wifi|Wi-Fi|"
      "apps|Apps|"
      "data|Data|"
      "desktop|Desktop|"
      "password|Password|"
      "reset|Reset to band defaults|"
      "remove|Remove this kid|"
      "back|Back|"
    )
    tui_screen_choose "$name" 1 1 0 "" choices "time" "" facts
    local rc=$?
    case "$rc" in
      130) return 130 ;;
      1) return 0 ;;
    esac
    ((rc == 0)) || return 0

    case "$TUI_REPLY" in
      time)
        screen_kid_time "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      web)
        screen_kid_web "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      wifi)
        screen_kid_wifi "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      apps)
        screen_kid_apps "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      data)
        screen_kid_data "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      desktop)
        screen_kid_desktop "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      password)
        screen_kid_password "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      reset)
        screen_kid_reset "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ;;
      remove)
        screen_kid_remove "$account" "$name"
        rc=$?
        ((rc == 130)) && return 130
        ((KID_JUST_REMOVED)) && return 0
        ;;
      back) return 0 ;;
    esac
  done
}
