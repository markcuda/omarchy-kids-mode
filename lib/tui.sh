# shellcheck shell=bash
# lib/tui.sh -- one screen renderer over gum for the parent wizard
# (SPEC.md R-WIZ-9, Appendix A; issue #18: "screens as data, one renderer").
# Not meant to be executed directly; source it from a command. See
# docs/tui.md for the prompt/answers-file contracts, the plain-vs-card
# render modes (issue #50), and a worked example.

# shellcheck source=./theme.sh
source "$(dirname "${BASH_SOURCE[0]}")/theme.sh"

TUI_ANS_ESC="@esc"
TUI_ANS_CTRLC="@ctrlc"

TUI_FOOTER_DEFAULT="Enter continue · Esc back · Ctrl+C leave (nothing changes)"
# shellcheck disable=SC2034 # for callers' first screen (no Esc target yet), not used here
TUI_FOOTER_FIRST="Enter continue · Ctrl+C leave (nothing changes)"
# Overridable so a caller that has already written something (the wizard
# after Apply) does not claim nothing changed. See _tui_confirm_leave.
TUI_LEAVE_MESSAGE="Leave setup? Nothing has been changed yet."

TUI_MODE="" # "interactive" or "file", set by tui_init
TUI_HAVE_GUM=0
TUI_REPLY=""        # the answer from the last tui_screen_* call
TUI_PRESET_ERROR="" # a caller's own verdict on the last answer, shown once on the next tui_screen_input
TUI_NEXT_ANSWER=""  # scratch: set by _tui_next_answer, read right after
declare -a TUI_ANSWERS=()
TUI_ANSWERS_I=0

# Card's max width (min(TUI_CARD_WIDTH, terminal width - 4)); _tui_measure
# resolves TUI_CARD_W/TUI_CARD_LEFT from it per render. Card mode only.
TUI_CARD_WIDTH=72
TUI_CARD_W=""
TUI_CARD_LEFT=0

# Resolved by tui_init via lib/theme.sh's theme_color -- docs/tui.md "Colors".
TUI_C_ACCENT=""
TUI_C_FG=""
TUI_C_MUTED=""
TUI_C_ERROR=""

# tui_init -- call once before any tui_screen_* call. Resolves colors and
# picks how prompts get answered. Returns 2 (never exits) when neither an
# answers file nor a terminal is available.
tui_init() {
  if command -v gum >/dev/null 2>&1; then TUI_HAVE_GUM=1; else TUI_HAVE_GUM=0; fi

  TUI_C_ACCENT="$(theme_color accent)"
  TUI_C_FG="$(theme_color foreground)"
  TUI_C_MUTED="$(theme_color muted)"
  TUI_C_ERROR="$(theme_color error)"
  local bg
  bg="$(theme_color background)"

  # Theme -> gum environment (issue #50): only fills a var Omarchy's own
  # themed session hasn't already exported -- docs/tui.md "Colors".
  _tui_gum_env_default FOREGROUND "$TUI_C_FG"
  _tui_gum_env_default BACKGROUND "$bg"
  _tui_gum_env_default BORDER_FOREGROUND "$TUI_C_ACCENT"
  _tui_gum_env_default BORDER_BACKGROUND "$bg"
  _tui_gum_env_default GUM_CHOOSE_CURSOR_FOREGROUND "$TUI_C_ACCENT"
  _tui_gum_env_default GUM_CHOOSE_ITEM_FOREGROUND "$TUI_C_FG"
  _tui_gum_env_default GUM_CHOOSE_SELECTED_FOREGROUND "$TUI_C_ACCENT"
  _tui_gum_env_default GUM_INPUT_PROMPT_FOREGROUND "$TUI_C_ACCENT"
  _tui_gum_env_default GUM_INPUT_PLACEHOLDER_FOREGROUND "$TUI_C_MUTED"
  _tui_gum_env_default GUM_CONFIRM_PROMPT_FOREGROUND "$TUI_C_ACCENT"
  _tui_gum_env_default GUM_CONFIRM_SELECTED_FOREGROUND "$TUI_C_ACCENT"

  if [[ -n "${OMARCHY_KIDS_TUI_ANSWERS:-}" ]]; then
    if [[ ! -r "$OMARCHY_KIDS_TUI_ANSWERS" ]]; then
      echo "tui: OMARCHY_KIDS_TUI_ANSWERS is set but not readable: $OMARCHY_KIDS_TUI_ANSWERS" >&2
      return 2
    fi
    TUI_ANSWERS=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
      TUI_ANSWERS+=("$line")
    done <"$OMARCHY_KIDS_TUI_ANSWERS"
    TUI_ANSWERS_I=0
    TUI_MODE="file"
  elif [[ -t 0 ]]; then
    TUI_MODE="interactive"
  else
    echo "tui: no terminal to ask, and OMARCHY_KIDS_TUI_ANSWERS is not set — nothing to answer prompts with" >&2
    return 2
  fi
  return 0
}

# _tui_next_answer -- sets TUI_NEXT_ANSWER to the next answers-file line,
# or returns 2 if it ran out. Call plain, never as `x="$(_tui_next_answer)"`
# -- a subshell would lose the TUI_ANSWERS_I bump and replay the same line.
_tui_next_answer() {
  if ((TUI_ANSWERS_I >= ${#TUI_ANSWERS[@]})); then
    echo "tui: ${OMARCHY_KIDS_TUI_ANSWERS:-<answers file>} ran out of lines, but a screen still needs one" >&2
    return 2
  fi
  TUI_NEXT_ANSWER="${TUI_ANSWERS[TUI_ANSWERS_I]}"
  TUI_ANSWERS_I=$((TUI_ANSWERS_I + 1))
}

# _tui_array_copy DEST SRC_ARRAYNAME -- copies the array named
# SRC_ARRAYNAME into DEST. eval, not a `local -n` nameref (bash 4.3+),
# since test/all also runs under macOS's bash 3.2 -- docs/tui.md.
_tui_array_copy() {
  local __tui_dest="$1" __tui_src="$2"
  # shellcheck disable=SC1087 # $__tui_src[@] is the array-name being
  # built for eval, not an expansion shellcheck can see through
  eval "$__tui_dest=(\"\${$__tui_src[@]+\"\${$__tui_src[@]}\"}\")"
}

# Escape one value for Gum v2/Kong's comma-separated --selected slice. The
# parser consumes backslash escapes, so protect backslashes before commas.
_tui_gum_slice_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//,/\\,}"
  printf '%s' "$value"
}

# _tui_gum_env_default NAME VALUE -- exports NAME=VALUE only when unset.
# eval, not `${!name}`, for the same bash-3.2 reason as _tui_array_copy.
_tui_gum_env_default() {
  local __tui_name="$1" __tui_val="$2" __tui_current
  __tui_current="$(eval "printf '%s' \"\${$__tui_name:-}\"")"
  if [[ -z "$__tui_current" ]]; then
    export "$__tui_name=$__tui_val"
  fi
}

# _tui_card_mode -- true for the cleared/bordered card render (issue #50);
# false (plain) whenever file mode or OMARCHY_KIDS_TUI_PLAIN=1 -- docs/tui.md.
_tui_card_mode() {
  [[ "$TUI_MODE" == interactive && "${OMARCHY_KIDS_TUI_PLAIN:-0}" != 1 ]]
}

# _tui_clear -- plain `clear`, same as omarchy-provision-owner's clear_logo,
# so tests can fake it on PATH. No-op, not a failure, if not installed.
_tui_clear() {
  command -v clear >/dev/null 2>&1 && clear
  return 0
}

# _tui_measure -- sets TUI_CARD_W/TUI_CARD_LEFT (card width/centering) and
# the GUM_*_PADDING/SHOW_HELP env so the chooser/input lines up under the
# card with no duplicate help line. `stty size` first (immune to a stale
# $COLUMNS), then `tput cols`, then $COLUMNS, then 80. Card mode only --
# never affects plain mode's byte-for-byte output. docs/tui.md.
_tui_measure() {
  local cols="" sz
  sz="$(stty size 2>/dev/null || true)"
  if [[ "$sz" =~ ^[0-9]+\ ([0-9]+)$ ]]; then
    cols="${BASH_REMATCH[1]}"
  fi
  if [[ -z "$cols" ]] && command -v tput >/dev/null 2>&1; then
    cols="$(tput cols 2>/dev/null || true)"
  fi
  [[ "$cols" =~ ^[0-9]+$ ]] || cols="${COLUMNS:-80}"

  TUI_CARD_W=$((cols - 4))
  ((TUI_CARD_W > TUI_CARD_WIDTH)) && TUI_CARD_W=$TUI_CARD_WIDTH
  ((TUI_CARD_W < 24)) && TUI_CARD_W=24

  TUI_CARD_LEFT=$(((cols - TUI_CARD_W) / 2))
  ((TUI_CARD_LEFT < 0)) && TUI_CARD_LEFT=0

  local pad="0 0 0 $((TUI_CARD_LEFT + 2))"
  export GUM_CHOOSE_PADDING="$pad" GUM_INPUT_PADDING="$pad" GUM_CONFIRM_PADDING="$pad"
  export GUM_CHOOSE_SHOW_HELP=false GUM_INPUT_SHOW_HELP=false GUM_CONFIRM_SHOW_HELP=false
}

# _tui_style FLAGS... -- TEXT... -- the one place gum style is called.
# Drops to plain text when gum isn't installed (a dev machine; PKGBUILD
# depends on it for a real install).
_tui_style() {
  local -a flags=() text=()
  local sep=0 a
  for a in "$@"; do
    if ((! sep)) && [[ "$a" == "--" ]]; then
      sep=1
      continue
    fi
    if ((sep)); then text+=("$a"); else flags+=("$a"); fi
  done
  if ((TUI_HAVE_GUM)); then
    # Text goes to gum on stdin, never as an argument: a card body can carry a
    # secret (the pairing code in P6), and any argument is readable from
    # /proc/<pid>/cmdline by another local session while gum runs. An all-blank
    # body would make gum print its own "provide text" error, so that one case
    # is printed here instead.
    local joined=""
    if ((${#text[@]})); then joined="$(printf '%s' "${text[@]}")"; fi
    if [[ -n "$joined" ]]; then
      printf '%s\n' "${text[@]}" | gum style "${flags[@]+"${flags[@]}"}"
    elif ((${#text[@]})); then
      printf '%s\n' "${text[@]}"
    else
      gum style "${flags[@]+"${flags[@]}"}" </dev/null
    fi
  else
    printf '%s\n' "${text[@]+"${text[@]}"}"
  fi
}

_tui_footer() {
  if _tui_card_mode; then
    _tui_style --foreground "$TUI_C_FG" --margin "0 0 0 $TUI_CARD_LEFT" -- "$1"
  else
    _tui_style --foreground "$TUI_C_FG" -- "$1"
  fi
}

# tui_header TITLE STEP TOTAL SHOW_OMY [OMY_LINE] [BODY_ARRAYNAME] [ERROR]
# Omy only renders when SHOW_OMY is 1 (spec v1.1: Welcome/Done only).
# Plain mode prints the unchanged bordered box; card mode clears, measures,
# and draws one closed `gum style` card over every line (ERROR=1 turns it
# the theme's error color) -- see docs/tui.md for why it's one gum call.
tui_header() {
  local title="$1" step="$2" total="$3" show_omy="$4" omy_line="${5:-}"
  local body_argname="${6:-}" errflag="${7:-0}"

  if _tui_card_mode; then
    _tui_clear
    _tui_measure

    local card_color="$TUI_C_FG" border_color="$TUI_C_ACCENT"
    if [[ "$errflag" == 1 ]]; then
      card_color="$TUI_C_ERROR"
      border_color="$TUI_C_ERROR"
    fi

    local -a lines=("$title")
    if [[ "$title" == "Kids Mode" ]]; then
      ((total > 1)) && lines[0]="Kids Mode · Step ${step} of ${total}"
    else
      ((total > 1)) && lines+=("Kids Mode · Step ${step} of ${total}")
    fi
    if [[ "$show_omy" == 1 ]]; then
      lines+=("")
      lines+=("🦉 Omy")
      [[ -n "$omy_line" ]] && lines+=("$omy_line")
    fi

    local -a _tui_hdr_body=()
    [[ -n "$body_argname" ]] && _tui_array_copy _tui_hdr_body "$body_argname"
    if ((${#_tui_hdr_body[@]})); then
      lines+=("")
      local b
      for b in "${_tui_hdr_body[@]}"; do lines+=("$b"); done
    fi

    _tui_style --border rounded --padding "1 2" --margin "1 0 1 $TUI_CARD_LEFT" \
      --width "$TUI_CARD_W" --foreground "$card_color" --border-foreground "$border_color" -- \
      "${lines[@]}"
  else
    if [[ "$show_omy" == 1 ]]; then
      _tui_style --foreground "$TUI_C_ACCENT" --bold -- "🦉 Omy"
      if [[ -n "$omy_line" ]]; then
        local -a f=(--italic)
        [[ -n "$TUI_C_FG" ]] && f+=(--foreground "$TUI_C_FG")
        _tui_style "${f[@]}" -- "$omy_line"
      fi
    fi

    local -a plain=("$title")
    if [[ "$title" == "Kids Mode" ]]; then
      ((total > 1)) && plain[0]="Kids Mode · step ${step} of ${total}"
    else
      ((total > 1)) && plain+=("step ${step} of ${total}")
    fi
    _tui_style --border rounded --padding "0 1" \
      --foreground "$TUI_C_ACCENT" --border-foreground "$TUI_C_ACCENT" -- "${plain[@]}"
  fi
}

# _tui_confirm_leave -- "$TUI_LEAVE_MESSAGE" (default: "Leave setup?
# Nothing has been changed yet."). Returns 0 (leave) or 1 (redraw the
# interrupted screen). A second Ctrl+C here also means leave.
_tui_confirm_leave() {
  local msg="$TUI_LEAVE_MESSAGE"
  if [[ "$TUI_MODE" == file ]]; then
    local ans
    _tui_next_answer || {
      echo "tui: answers file ran out during the leave confirmation" >&2
      exit 2
    }
    ans="$TUI_NEXT_ANSWER"
    case "$ans" in
      yes | y | Yes | Y) return 0 ;;
      *) return 1 ;;
    esac
  elif ((TUI_HAVE_GUM)); then
    gum confirm -- "$msg"
    local rc=$?
    [[ $rc == 0 || $rc == 130 ]] && return 0 || return 1
  else
    local a
    read -r -p "$msg [y/N] " a
    [[ "$a" =~ ^[Yy] ]] && return 0 || return 1
  fi
}

# tui_screen_choose TITLE STEP TOTAL SHOW_OMY OMY_LINE CHOICES_ARRAYNAME \
#                    [DEFAULT_VALUE] [FOOTER] [BODY_ARRAYNAME]
# CHOICES_ARRAYNAME holds "value|label|reason" strings — one choice per
# screen's worth of options, each with its one-line reason (R-WIZ-3). An
# answer may be the value, the label, the whole rendered line, or a plain
# 1-based number (the "number keys" the footer advertises).
# BODY_ARRAYNAME holds the screen's own facts, rendered inside the card
# under the title exactly as tui_screen_confirm's body is: card mode
# clears, so facts a caller echoes first are gone before anyone reads
# them (review §3.1).
tui_screen_choose() {
  local title="$1" step="$2" total="$3" show_omy="$4" omy_line="$5"
  local -a _tui_choices
  _tui_array_copy _tui_choices "$6"
  local default_value="${7:-}"
  local footer="${8:-$TUI_FOOTER_DEFAULT}"
  local -a _tui_choose_body=()
  [[ -n "${9:-}" ]] && _tui_array_copy _tui_choose_body "$9"

  local -a values=() labels=() display=()
  local c rest label reason i=0
  for c in "${_tui_choices[@]+"${_tui_choices[@]}"}"; do
    local value="${c%%|*}"
    rest="${c#*|}"
    label="${rest%%|*}"
    if [[ "$rest" == "$label" ]]; then reason=""; else reason="${rest#*|}"; fi
    i=$((i + 1))
    values+=("$value")
    labels+=("$label")
    if [[ -n "$reason" ]]; then
      display+=("$(printf '%d) %s — %s' "$i" "$label" "$reason")")
    else
      display+=("$(printf '%d) %s' "$i" "$label")")
    fi
  done

  local default_display=""
  for i in "${!values[@]}"; do
    [[ "${values[i]}" == "$default_value" ]] && default_display="${display[i]}"
  done

  while true; do
    if _tui_card_mode; then
      tui_header "$title" "$step" "$total" "$show_omy" "$omy_line" _tui_choose_body
    else
      tui_header "$title" "$step" "$total" "$show_omy" "$omy_line"
      local bl
      for bl in "${_tui_choose_body[@]+"${_tui_choose_body[@]}"}"; do _tui_style -- "$bl"; done
    fi

    # Print the list ourselves only when gum's own widget won't (file
    # mode, or the no-gum fallback below) -- avoids the duplicate list
    # issue #50's screenshots showed.
    if ! { [[ "$TUI_MODE" == interactive ]] && ((TUI_HAVE_GUM)); }; then
      local -a dm=()
      _tui_card_mode && dm=(--margin "0 0 0 $TUI_CARD_LEFT")
      local d
      for d in "${display[@]+"${display[@]}"}"; do _tui_style "${dm[@]+"${dm[@]}"}" -- "$d"; done
    fi
    # The footer must be visible before gum blocks while waiting; its own
    # help line is off in card mode.
    _tui_footer "$footer"

    local chosen
    if [[ "$TUI_MODE" == file ]]; then
      _tui_next_answer || return 2
      chosen="$TUI_NEXT_ANSWER"
    elif ((TUI_HAVE_GUM)); then
      local -a gflags=()
      if _tui_card_mode; then
        # No --header: the title's already the card's own line.
        gflags+=(--header "")
      else
        gflags+=(--header "$title")
      fi
      local h=${#display[@]}
      ((h > 16)) && h=16 # the avatar list is 13 rows; a paged list shows gum's dots
      ((h < 1)) && h=1
      gflags+=(--height "$h")
      if [[ -n "$default_display" ]]; then
        gflags+=(--selected "$(_tui_gum_slice_escape "$default_display")")
      fi
      chosen="$(gum choose "${gflags[@]}" -- "${display[@]+"${display[@]}"}")"
      case $? in
        1) return 1 ;;
        130)
          if _tui_confirm_leave; then return 130; else continue; fi
          ;;
      esac
    else
      read -r -p "> " chosen
    fi

    if [[ "$chosen" == "$TUI_ANS_ESC" ]]; then return 1; fi
    if [[ "$chosen" == "$TUI_ANS_CTRLC" ]]; then
      if _tui_confirm_leave; then return 130; else continue; fi
    fi

    local match="" j
    for j in "${!values[@]}"; do
      if [[ "$chosen" == "${values[j]}" || "$chosen" == "${labels[j]}" || "$chosen" == "${display[j]}" ]]; then
        match="${values[j]}"
        break
      fi
    done
    if [[ -z "$match" && "$chosen" =~ ^[0-9]+$ ]]; then
      local idx=$((chosen - 1))
      if ((idx >= 0 && idx < ${#values[@]})); then match="${values[idx]}"; fi
    fi

    if [[ -z "$match" ]]; then
      echo "tui: '$chosen' does not match any choice on '$title'" >&2
      return 2
    fi

    TUI_REPLY="$match"
    return 0
  done
}

# tui_screen_input TITLE STEP TOTAL SHOW_OMY OMY_LINE KIND PLACEHOLDER \
#                   [VALIDATOR] [FOOTER]
# KIND is "text" or "password". VALIDATOR, if given, is a function name
# called as `VALIDATOR "$candidate"`: it should print nothing and return 0
# for a valid answer, or print a one-line reason and return non-zero to
# have the screen redraw and ask again (spec's per-field validation, e.g.
# the name and password screens).
tui_screen_input() {
  local title="$1" step="$2" total="$3" show_omy="$4" omy_line="$5"
  local kind="$6" placeholder="${7:-}" validator="${8:-}"
  local footer="${9:-$TUI_FOOTER_DEFAULT}"
  local last_err="$TUI_PRESET_ERROR"
  TUI_PRESET_ERROR=""

  while true; do
    # A failed validator's message (or the caller's TUI_PRESET_ERROR)
    # rides along as an extra card line on the redraw -- card mode
    # clears the screen, so a line echoed off to the side is never read.
    local -a _tui_input_body=()
    [[ -n "$placeholder" ]] && _tui_input_body+=("$placeholder")
    [[ -n "$last_err" ]] && _tui_input_body+=("" "$last_err")

    if _tui_card_mode; then
      local errflag=0
      [[ -n "$last_err" ]] && errflag=1
      tui_header "$title" "$step" "$total" "$show_omy" "$omy_line" _tui_input_body "$errflag"
    else
      tui_header "$title" "$step" "$total" "$show_omy" "$omy_line"
      [[ -n "$placeholder" ]] && _tui_style --foreground "$TUI_C_MUTED" -- "$placeholder"
      [[ -n "$last_err" ]] && _tui_style --foreground "$TUI_C_ERROR" -- "$last_err"
    fi
    _tui_footer "$footer"

    local ans
    if [[ "$TUI_MODE" == file ]]; then
      _tui_next_answer || return 2
      ans="$TUI_NEXT_ANSWER"
    elif ((TUI_HAVE_GUM)); then
      # The hint is on the card (or printed above) already; repeating it inside the box read twice.
      local -a gflags=(--placeholder "" --prompt.foreground "$TUI_C_ACCENT")
      [[ "$kind" == password ]] && gflags+=(--password)
      ans="$(gum input "${gflags[@]}")"
      case $? in
        1) return 1 ;;
        130)
          if _tui_confirm_leave; then return 130; else continue; fi
          ;;
      esac
    else
      if [[ "$kind" == password ]]; then
        read -r -s -p "> " ans
        echo
      else
        read -r -p "> " ans
      fi
    fi

    if [[ "$ans" == "$TUI_ANS_ESC" ]]; then return 1; fi
    if [[ "$ans" == "$TUI_ANS_CTRLC" ]]; then
      if _tui_confirm_leave; then return 130; else continue; fi
    fi

    if [[ -n "$validator" ]]; then
      local err
      if ! err="$("$validator" "$ans")"; then
        last_err="${err:-That is not valid. Try again.}"
        continue
      fi
    fi

    TUI_REPLY="$ans"
    return 0
  done
}

# tui_screen_confirm TITLE STEP TOTAL SHOW_OMY OMY_LINE BODY_ARRAYNAME \
#                     [AFFIRM] [DECLINE] [FOOTER]
# A plain yes/no screen (the summary's "Apply this?" and similar). $TUI_REPLY
# is "yes" or "no" on success (0); a decline is also reported as exit 1
# (Esc and "No" are the same outcome for a confirm screen: don't proceed).
tui_screen_confirm() {
  local title="$1" step="$2" total="$3" show_omy="$4" omy_line="$5"
  local -a _tui_body
  _tui_array_copy _tui_body "$6"
  local affirm="${7:-Yes}" decline="${8:-No}"
  local footer="${9:-$TUI_FOOTER_DEFAULT}"

  if _tui_card_mode; then
    tui_header "$title" "$step" "$total" "$show_omy" "$omy_line" _tui_body
    _tui_footer "$footer"
  else
    tui_header "$title" "$step" "$total" "$show_omy" "$omy_line"
    local b
    for b in "${_tui_body[@]+"${_tui_body[@]}"}"; do _tui_style -- "$b"; done
    _tui_footer "$footer"
  fi

  local ans
  if [[ "$TUI_MODE" == file ]]; then
    _tui_next_answer || return 2
    ans="$TUI_NEXT_ANSWER"
    case "$ans" in
      "$TUI_ANS_CTRLC")
        TUI_REPLY=""
        return 130
        ;;
      "$TUI_ANS_ESC" | no | n | No | N)
        TUI_REPLY="no"
        return 1
        ;;
      yes | y | Yes | Y)
        TUI_REPLY="yes"
        return 0
        ;;
      *)
        echo "tui: '$ans' is not yes/no for '$title'" >&2
        return 2
        ;;
    esac
  elif ((TUI_HAVE_GUM)); then
    # No prompt text in card mode: the title/body is already the
    # card's own content (same reasoning as --header "" above).
    if _tui_card_mode; then
      gum confirm --affirmative "$affirm" --negative "$decline"
    else
      gum confirm --affirmative "$affirm" --negative "$decline" -- "$title"
    fi
    local rc=$?
    if [[ $rc == 0 ]]; then
      TUI_REPLY="yes"
    else
      TUI_REPLY="no"
    fi
    return $rc
  else
    read -r -p "$title [$affirm/$decline] " ans
    if [[ "$ans" =~ ^[Yy] ]]; then
      TUI_REPLY="yes"
      return 0
    else
      # shellcheck disable=SC2034 # TUI_REPLY is read by the caller, not here
      TUI_REPLY="no"
      return 1
    fi
  fi
}

# _tui_build_summary_lines ROWS_ARRAYNAME -- formats summary rows once so the
# summary card and its blocking chooser show the same readable values.
_tui_build_summary_lines() {
  local -a _tui_rows
  _tui_array_copy _tui_rows "$1"
  TUI_SUMMARY_LINES=()

  local row label width=0 value
  for row in "${_tui_rows[@]+"${_tui_rows[@]}"}"; do
    label="${row%%|*}"
    ((${#label} > width)) && width=${#label}
  done
  for row in "${_tui_rows[@]+"${_tui_rows[@]}"}"; do
    label="${row%%|*}"
    value="${row#*|}"
    TUI_SUMMARY_LINES+=("$(printf '%-*s  %s' "$width" "$label" "$value")")
  done
}

# tui_screen_summary TITLE STEP TOTAL SHOW_OMY OMY_LINE ROWS_ARRAYNAME [FOOTER]
# A pure display screen (spec A13): ROWS_ARRAYNAME holds "label|value"
# strings, rendered as an aligned two-column table. Pair it with
# tui_screen_choose for the Apply / Change something buttons — this
# function has no prompt of its own.
tui_screen_summary() {
  local title="$1" step="$2" total="$3" show_omy="$4" omy_line="$5"
  local footer="${7:-$TUI_FOOTER_DEFAULT}"
  _tui_build_summary_lines "$6"

  if _tui_card_mode; then
    tui_header "$title" "$step" "$total" "$show_omy" "$omy_line" TUI_SUMMARY_LINES
  else
    tui_header "$title" "$step" "$total" "$show_omy" "$omy_line"
    local l
    for l in "${TUI_SUMMARY_LINES[@]+"${TUI_SUMMARY_LINES[@]}"}"; do _tui_style -- "$l"; done
  fi

  _tui_footer "$footer"
}

# tui_progress STEPS_ARRAYNAME CURRENT_INDEX [TIP]
# Display-only (spec R-WIZ-5): one line per step (✓ done, ▸ current,
# · pending), a bar, and an optional tip. CURRENT_INDEX is 0-based;
# pass an index equal to the array length to mark every step done.
tui_progress() {
  local -a _tui_steps
  _tui_array_copy _tui_steps "$1"
  local current="$2" tip="${3:-}"
  local total=${#_tui_steps[@]}

  local i mark line
  for ((i = 0; i < total; i++)); do
    if ((i < current)); then
      mark="✓"
    elif ((i == current)); then
      mark="▸"
    else
      mark="·"
    fi
    line="  $mark ${_tui_steps[i]}"
    if ((i == current)); then
      _tui_style --foreground "$TUI_C_ACCENT" --bold -- "$line"
    elif ((i < current)); then
      _tui_style --foreground "$TUI_C_MUTED" -- "$line"
    else
      _tui_style -- "$line"
    fi
  done

  _tui_progress_bar "$current" "$total"
  [[ -n "$tip" ]] && _tui_style --foreground "$TUI_C_MUTED" --italic -- "Tip: $tip"
}

_tui_progress_bar() {
  local current="$1" total="$2" width=24 filled empty bar rest
  ((total > 0)) || total=1
  filled=$((current * width / total))
  ((filled > width)) && filled=$width
  empty=$((width - filled))
  printf -v bar '%*s' "$filled" ''
  bar="${bar// /█}"
  printf -v rest '%*s' "$empty" ''
  rest="${rest// /░}"
  _tui_style --foreground "$TUI_C_ACCENT" -- "${bar}${rest}"
}

# Parent-facing names for the existing persisted desktop level.
tui_desktop_label() {
  case "$1" in
    1) echo "App grid" ;;
    2) echo "Simplified desktop (retired)" ;;
    3) echo "Desktop" ;;
  esac
}
