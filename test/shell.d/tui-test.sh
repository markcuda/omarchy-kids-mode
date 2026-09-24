#!/bin/bash
# Tests lib/tui.sh and scripts/omarchy-kids-tui-demo (issue #18: SPEC.md
# R-WIZ-9, Appendix A).
#
# Every scenario runs in its own subshell (lib/tui.sh sourced fresh each
# time) so one test's TUI_MODE/TUI_ANSWERS_I/etc. never leak into the
# next. gum is a fake on a stub PATH that logs every invocation to
# $GUM_LOG and, for `style`, prints back the text after the literal `--`
# separator -- the same convention lib/tui.sh's real gum calls use -- so
# rendering can be checked without a real terminal.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUI_LIB="$ROOT/lib/tui.sh"
DEMO="$ROOT/scripts/omarchy-kids-tui-demo"

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in: $1)"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want '$2' in: $1)"; fi
}
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

STUBS="$TMP/stubs"
mkdir -p "$STUBS"
GUM_LOG="$TMP/gum.log"
cat >"$STUBS/gum" <<'EOF'
#!/bin/bash
# Fake gum: records every call (argv, space-joined) to $GUM_LOG, and for
# `style` echoes the text it is given. lib/tui.sh pipes a card body on stdin
# (so a secret such as P6's pairing code never reaches argv), so `style`
# reads stdin when it has no text after the literal "--" separator; both
# paths are recorded, so a check can look for the body either way.
LOG="${GUM_LOG:?GUM_LOG must be set}"
printf '%s\n' "$*" >>"$LOG"
case "${1:-}" in
    style)
        shift
        seen=0
        text=()
        for a in "$@"; do
            if [[ $seen == 1 ]]; then text+=("$a"); fi
            [[ "$a" == "--" ]] && seen=1
        done
        if ((${#text[@]} == 0)); then
            while IFS= read -r line; do text+=("$line"); done
        fi
        if ((${#text[@]})); then
            printf '%s\n' "${text[@]}"
            # Also record argv and the body on one line, so a check can prove
            # the body belongs to this very call (the card), not another.
            printf '%s %s\n' "$*" "${text[*]}" >>"$LOG"
        fi
        ;;
    *)
        if [[ -n "${GUM_BLOCK_UNTIL:-}" ]]; then
            printf 'blocked %s\n' "${1:-}" >>"$LOG"
            while [[ ! -e "$GUM_BLOCK_UNTIL" ]]; do sleep 0.01; done
        fi
        [[ -n "${GUM_OUTPUT:-}" ]] && printf '%s\n' "$GUM_OUTPUT"
        exit "${GUM_EXIT:-0}"
        ;;
esac
EOF
chmod +x "$STUBS/gum"

# Fakes for the interactive/"card" path (issue #50): `clear` just logs that
# it ran, `tput` logs its args and answers `cols` with a fixed width so
# _tui_measure's math is predictable across machines.
CLEAR_LOG="$TMP/clear.log"
cat >"$STUBS/clear" <<'EOF'
#!/bin/bash
printf 'cleared\n' >>"${CLEAR_LOG:?CLEAR_LOG must be set}"
EOF
chmod +x "$STUBS/clear"

TPUT_LOG="$TMP/tput.log"
cat >"$STUBS/tput" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${TPUT_LOG:?TPUT_LOG must be set}"
case "${1:-}" in
    cols) echo 80 ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$STUBS/tput"

export PATH="$STUBS:$PATH"
export GUM_LOG CLEAR_LOG TPUT_LOG

answers_file() { # writes $1's remaining args, one per line, returns its path
  local f="$TMP/answers.$RANDOM"
  printf '%s\n' "$@" >"$f"
  printf '%s' "$f"
}

# --- non-tty, no answers file: tui_init fails closed with exit 2 -----------

out="$(
  {
    unset OMARCHY_KIDS_TUI_ANSWERS
    # shellcheck source=/dev/null
    source "$TUI_LIB"
    tui_init
    echo "tui_init rc=$?"
  } 2>&1
)" </dev/null
check_contains "$out" "tui_init rc=2" "tui_init: no terminal and no answers file exits 2"
check_contains "$out" "nothing to answer prompts with" "tui_init: exit-2 message explains why"

# --- answers file drives tui_init into file mode ----------------------------

f="$(answers_file begin)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  echo "rc=$? mode=$TUI_MODE"
)" </dev/null
check_contains "$out" "rc=0 mode=file" "tui_init: an answers file selects file mode and returns 0"

# --- Omy header appears only when asked -------------------------------------

: >"$GUM_LOG"
out="$(
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null # no answers file here; the test overrides TUI_MODE below
  TUI_MODE="file"
  tui_header "Some Screen" 2 5 0 "should never print"
)" </dev/null
check_not_contains "$out" "Omy" "tui_header show_omy=0: no Omy glyph"
check_not_contains "$out" "should never print" "tui_header show_omy=0: no Omy line"
check_contains "$out" "step 2 of 5" "tui_header: step counter always renders"
check_contains "$out" "Some Screen" "tui_header: title always renders"

: >"$GUM_LOG"
out="$(
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null # no answers file here; the test overrides TUI_MODE below
  TUI_MODE="file"
  tui_header "Welcome" 1 3 1 "Hi, I'm Omy."
)" </dev/null
check_contains "$out" "Omy" "tui_header show_omy=1: Omy glyph renders"
check_contains "$out" "Hi, I'm Omy." "tui_header show_omy=1: Omy line renders"
check_contains "$(cat "$GUM_LOG")" "style" "tui_header: rendering goes through the real gum style call"

# --- tui_screen_choose renders title, body, choices, and the reasons -------

f="$(answers_file garden)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=(
    "garden|Only sites you choose|A short list you can grow."
    "filtered|Filtered open web|Adult content blocked."
  )
  tui_screen_choose "What can K see?" 2 3 0 "" web_choices "garden"
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_contains "$out" "What can K see?" "tui_screen_choose: title renders"
check_contains "$out" "Only sites you choose" "tui_screen_choose: choice label renders"
check_contains "$out" "A short list you can grow." "tui_screen_choose: choice reason renders"
check_contains "$out" "Filtered open web" "tui_screen_choose: second choice renders"
check_contains "$out" "rc=0 reply=garden" "tui_screen_choose: the matching answer resolves to its value"

# --- a choose screen's own facts render as body, under the title -----------
# (review §3.1: the panel's screens pass their facts here instead of
# echoing them above a screen that, in card mode, clears first.)

f="$(answers_file garden)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=("garden|Only sites you choose|A short list you can grow.")
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_facts=("17m used / 0m left today" "Open requests: 2")
  tui_screen_choose "Ada" 1 1 0 "" web_choices "garden" "" web_facts
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_contains "$out" "17m used / 0m left today" "tui_screen_choose: a body line renders in plain mode"
check_contains "$out" "Open requests: 2" "tui_screen_choose: every body line renders in plain mode"
check_contains "$out" "rc=0 reply=garden" "tui_screen_choose: a body changes nothing about the answer"
title_line="$(grep -n '^Ada$' <<<"$out" | head -1 | cut -d: -f1)"
body_line="$(grep -n '^17m used' <<<"$out" | head -1 | cut -d: -f1)"
if [[ -n "$title_line" && -n "$body_line" ]] && ((title_line < body_line)); then
  pass "tui_screen_choose: plain mode prints the body under the title, not above it"
else
  fail "tui_screen_choose: body/title are out of order (title=$title_line body=$body_line)"
fi

# a bare 1-based number also resolves
f="$(answers_file 2)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=("garden|Only sites you choose|reason one" "filtered|Filtered open web|reason two")
  tui_screen_choose "T" 1 1 0 "" web_choices
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_contains "$out" "rc=0 reply=filtered" "tui_screen_choose: a number-key answer resolves by position"

# --- Esc goes back one screen, exit 1, nothing consumed beyond that line ---

f="$(answers_file "@esc" garden)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=("garden|Only sites you choose|r" "filtered|Filtered open web|r")
  tui_screen_choose "T" 1 1 0 "" web_choices
  echo "rc=$?"
)" </dev/null
check_contains "$out" "rc=1" "tui_screen_choose: @esc returns 1 (Esc = back)"

# --- Ctrl+C asks to leave; declining redraws and re-reads the next answer --

f="$(answers_file "@ctrlc" no garden)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=("garden|Only sites you choose|r" "filtered|Filtered open web|r")
  tui_screen_choose "T" 1 1 0 "" web_choices
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_contains "$out" "rc=0 reply=garden" "tui_screen_choose: @ctrlc + no stays, next line answers the screen"

f="$(answers_file "@ctrlc" yes)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=("garden|Only sites you choose|r" "filtered|Filtered open web|r")
  tui_screen_choose "T" 1 1 0 "" web_choices
  echo "rc=$?"
)" </dev/null
check_contains "$out" "rc=130" "tui_screen_choose: @ctrlc + yes leaves, exit 130"

# The same Esc/Ctrl+C contract on tui_screen_input.
f="$(answers_file "@esc")"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  tui_screen_input "Name" 1 1 0 "" text "hint" ""
  echo "rc=$?"
)" </dev/null
check_contains "$out" "rc=1" "tui_screen_input: @esc returns 1"

f="$(answers_file "@ctrlc" yes)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  tui_screen_input "Name" 1 1 0 "" text "hint" ""
  echo "rc=$?"
)" </dev/null
check_contains "$out" "rc=130" "tui_screen_input: @ctrlc + yes leaves, exit 130"

# --- tui_screen_input validation retries instead of accepting a bad value --

cat >"$TMP/lower_only.sh" <<'EOF'
lower_only() {
    if [[ "$1" =~ ^[a-z]+$ ]]; then return 0; fi
    echo "letters only"
    return 1
}
EOF
f="$(answers_file "BAD1" "ok")"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  # shellcheck source=/dev/null
  source "$TMP/lower_only.sh"
  tui_init
  tui_screen_input "Name" 1 1 0 "" text "" lower_only
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_contains "$out" "letters only" "tui_screen_input: a failed validator's message is shown"
check_contains "$out" "rc=0 reply=ok" "tui_screen_input: retries until the validator accepts"

# --- tui_screen_confirm: yes/no, and the Esc/No-are-the-same-outcome rule --

f="$(answers_file yes)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  body=("Apply this?")
  tui_screen_confirm "Summary" 1 1 0 "" body "Apply" "Change something"
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_contains "$out" "Apply this?" "tui_screen_confirm: body renders"
check_contains "$out" "rc=0 reply=yes" "tui_screen_confirm: yes returns 0"

f="$(answers_file "@esc")"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  body=("Apply this?")
  tui_screen_confirm "Summary" 1 1 0 "" body
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_contains "$out" "rc=1 reply=no" "tui_screen_confirm: @esc is the same outcome as declining"

f="$(answers_file "@ctrlc")"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  body=("Apply this?")
  tui_screen_confirm "Summary" 1 1 0 "" body
  echo "rc=$?"
)" </dev/null
check_contains "$out" "rc=130" "tui_screen_confirm: @ctrlc leaves directly, exit 130"

# --- tui_screen_summary: a pure table render, no prompt ---------------------

out="$(
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null # no answers file here; the test overrides TUI_MODE below
  TUI_MODE="file"
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  rows=("Account|kid-ada" "Level|1 — one thing at a time")
  tui_screen_summary "Summary" 1 1 0 "" rows
)" </dev/null
check_contains "$out" "Account" "tui_screen_summary: row label renders"
check_contains "$out" "kid-ada" "tui_screen_summary: row value renders"
check_contains "$out" "Level" "tui_screen_summary: second row renders"

# --- tui_progress: done marks, current marker, and the tip -----------------

out="$(
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null # no answers file here; the test overrides TUI_MODE below
  TUI_MODE="file"
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  steps=("Create account" "Install packages" "Apply settings")
  tui_progress steps 1 "Grab a coffee."
)" </dev/null
check_contains "$out" "✓" "tui_progress: a done step gets a check mark"
check_contains "$out" "▸" "tui_progress: the current step gets its marker"
check_contains "$out" "Create account" "tui_progress: step labels render"
check_contains "$out" "Grab a coffee." "tui_progress: the tip renders"

# --- issue #50: the interactive/"card" path clears the screen, draws one ---
# --- bordered card, and never prints gum's own choice list a second time --
# TUI_MODE is forced to "interactive" the same way earlier tests force
# "file" — there's no real tty in a test run — with the fake gum from above
# standing in for a real terminal.

: >"$GUM_LOG"
: >"$CLEAR_LOG"
: >"$TPUT_LOG"
out="$(
  unset OMARCHY_KIDS_TUI_ANSWERS OMARCHY_KIDS_TUI_PLAIN
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null # no tty, no answers file here; force interactive below
  TUI_MODE="interactive"
  # shellcheck disable=SC2034 # read by tui_screen_choose in lib/tui.sh (gates gum vs the read fallback)
  TUI_HAVE_GUM=1
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=(
    "garden|Only sites you choose|A short list you can grow."
    "filtered|Filtered open web|Adult content blocked."
  )
  tui_screen_choose "What can K see?" 2 3 0 "" web_choices "garden" 2>/dev/null
  echo "rc=$?"
)" </dev/null
check_contains "$(cat "$CLEAR_LOG")" "cleared" "tui_header: card mode clears the screen"
check_contains "$(cat "$TPUT_LOG")" "cols" "tui_header: card mode measures the terminal with tput"
check_contains "$(cat "$GUM_LOG")" "--border rounded" "tui_header: card mode draws one closed rounded-border card"
check_contains "$(cat "$GUM_LOG")" "--padding 1 2" "tui_header: card mode's card uses the padding round three settled on"
check_contains "$out" "Kids Mode · Step 2 of 3" "tui_header: card mode puts the step line inside the card"
check_contains "$out" "What can K see?" "tui_header: card mode puts the title inside the card"
check_contains "$(cat "$GUM_LOG")" "choose" "tui_screen_choose: card mode still asks gum choose for the list"
check_not_contains "$(cat "$GUM_LOG")" "--header What can K see?" "tui_screen_choose: card mode never hands gum choose the title as its own header (already in the card)"
check_not_contains "$out" "Only sites you choose" "tui_screen_choose: card mode never prints gum's own list a second time"

# $GUM_LOG records every gum invocation in the order lib/tui.sh made them,
# so the card (one `style --border rounded` call) has to come before gum
# choose is ever asked for the list.
style_line="$(grep -n -- '--border rounded' "$GUM_LOG" | head -1 | cut -d: -f1)"
choose_line="$(grep -n '^choose ' "$GUM_LOG" | head -1 | cut -d: -f1)"
if [[ -n "$style_line" && -n "$choose_line" && "$style_line" -lt "$choose_line" ]]; then
  pass "tui_screen_choose: the card renders before gum choose runs, not after"
else
  fail "tui_screen_choose: card/choose are out of order (card=$style_line choose=$choose_line)"
fi

# Essential keyboard guidance must use the readable theme role, even when the
# muted role is available for secondary copy (issue #119).
footer_colors="$(
  unset OMARCHY_KIDS_TUI_ANSWERS OMARCHY_KIDS_TUI_PLAIN
  # shellcheck disable=SC1090 # test fixture resolves the same checkout path as the parent test
  source "$TUI_LIB"
  TUI_MODE="interactive" TUI_HAVE_GUM=1
  # shellcheck disable=SC2034 # _tui_footer reads these indirect theme fixtures
  TUI_C_FG="#readable"
  # shellcheck disable=SC2034 # _tui_footer reads these indirect theme fixtures
  TUI_C_MUTED="#muted"
  : >"$GUM_LOG"
  _tui_footer "Enter continue · Esc back"
  cat "$GUM_LOG"
)"
check_contains "$footer_colors" "--foreground #readable" \
  "_tui_footer: essential keyboard guidance uses the readable theme role"
check_not_contains "$footer_colors" "--foreground #muted" \
  "_tui_footer: essential keyboard guidance does not use the muted theme role"

# Issue #110: card help must be visible while each blocking gum widget waits.
# The fake gum owns the blocking command and release fixture, so this checks
# output before the widget consumes an answer rather than after it exits.
blocked_out="$TMP/blocked.out"
release="$TMP/release"
first_footer='Enter continue · Ctrl+C leave (nothing changes)'
default_footer='Enter continue · Esc back · Ctrl+C leave (nothing changes)'
: >"$GUM_LOG"
(
  unset OMARCHY_KIDS_TUI_ANSWERS OMARCHY_KIDS_TUI_PLAIN
  # shellcheck disable=SC2030,SC2031 # the background fixture owns these exports
  export GUM_BLOCK_UNTIL="$release" GUM_OUTPUT=garden
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null
  TUI_MODE="interactive" TUI_HAVE_GUM=1
  # shellcheck disable=SC2034 # passed by name to tui_screen_choose's indirect array copy
  blocked_choices=("garden|Only sites you choose|")
  tui_screen_choose "Welcome" 1 3 1 "Hi from Omy." blocked_choices "garden" "$TUI_FOOTER_FIRST"
  echo "rc=$? reply=$TUI_REPLY"
) >"$blocked_out" 2>&1 </dev/null &
blocked_pid=$!
for ((i = 0; i < 100; i++)); do
  grep -q '^blocked choose$' "$GUM_LOG" && break
  sleep 0.01
done
check_contains "$(cat "$blocked_out")" "$first_footer" "tui_screen_choose: first-screen guidance is visible before gum consumes the answer"
touch "$release"
wait "$blocked_pid"
check_contains "$(cat "$blocked_out")" "rc=0 reply=garden" "tui_screen_choose: blocked widget still returns its answer"

: >"$GUM_LOG"
rm -f "$release"
(
  unset OMARCHY_KIDS_TUI_ANSWERS OMARCHY_KIDS_TUI_PLAIN
  # shellcheck disable=SC2030,SC2031 # the background fixture owns these exports
  export GUM_BLOCK_UNTIL="$release" GUM_OUTPUT=Ada
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null
  TUI_MODE="interactive" TUI_HAVE_GUM=1
  tui_screen_input "What's your kid's name?" 3 3 0 "" text "First name or nickname. It's what they'll see."
  echo "rc=$? reply=$TUI_REPLY"
) >"$blocked_out" 2>&1 </dev/null &
blocked_pid=$!
for ((i = 0; i < 100; i++)); do
  grep -q '^blocked input$' "$GUM_LOG" && break
  sleep 0.01
done
check_contains "$(cat "$blocked_out")" "$default_footer" "tui_screen_input: guidance is visible before gum consumes the answer"
touch "$release"
wait "$blocked_pid"
check_contains "$(cat "$blocked_out")" "rc=0 reply=Ada" "tui_screen_input: blocked widget still returns its answer"

: >"$GUM_LOG"
rm -f "$release"
(
  unset OMARCHY_KIDS_TUI_ANSWERS OMARCHY_KIDS_TUI_PLAIN
  # shellcheck disable=SC2030,SC2031 # the background fixture owns this export
  export GUM_BLOCK_UNTIL="$release"
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null
  TUI_MODE="interactive" TUI_HAVE_GUM=1
  # shellcheck disable=SC2034 # passed by name to tui_screen_confirm's indirect array copy
  confirm_body=("Review these choices.")
  tui_screen_confirm "Ready?" 13 13 0 "" confirm_body "Apply" "Change something"
  echo "rc=$? reply=$TUI_REPLY"
) >"$blocked_out" 2>&1 </dev/null &
blocked_pid=$!
for ((i = 0; i < 100; i++)); do
  grep -q '^blocked confirm$' "$GUM_LOG" && break
  sleep 0.01
done
check_contains "$(cat "$blocked_out")" "$default_footer" "tui_screen_confirm: guidance is visible before gum consumes the answer"
touch "$release"
wait "$blocked_pid"
check_contains "$(cat "$blocked_out")" "rc=0 reply=yes" "tui_screen_confirm: blocked widget still returns its answer"

# ...and a choose screen's body is drawn *inside* that one card (review
# §3.1), not printed beside it where the next clear would take it.
: >"$GUM_LOG"
: >"$CLEAR_LOG"
out="$(
  unset OMARCHY_KIDS_TUI_ANSWERS OMARCHY_KIDS_TUI_PLAIN
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null
  TUI_MODE="interactive"
  # shellcheck disable=SC2034 # read by tui_screen_choose in lib/tui.sh (gates gum vs the read fallback)
  TUI_HAVE_GUM=1
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  kid_choices=("time|Screen time|")
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  kid_facts=("Ada — band 6-8" "17m used / 0m left today")
  tui_screen_choose "Ada" 1 1 0 "" kid_choices "time" "" kid_facts 2>/dev/null
)" </dev/null
card_call="$(grep -- '--border rounded' "$GUM_LOG" | head -2)"
check_contains "$card_call" "Ada — band 6-8" "tui_screen_choose: card mode puts the body inside the card"
check_contains "$card_call" "17m used / 0m left today" "tui_screen_choose: every body line is in that same card"

# _tui_measure pads the chooser to line up under the card's own text
# (one column of border, one of padding), not flush with the terminal
# edge, and turns off gum's own keybind help line -- lib/tui.sh's own
# footer is the only help text a card-mode screen shows now.
pad_out="$(
  unset OMARCHY_KIDS_TUI_ANSWERS OMARCHY_KIDS_TUI_PLAIN
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null
  TUI_MODE="interactive"
  _tui_measure
  echo "left=$TUI_CARD_LEFT pad=$GUM_CHOOSE_PADDING help=$GUM_CHOOSE_SHOW_HELP"
)" </dev/null
left_val="$(sed -n 's/^left=\([0-9]*\).*/\1/p' <<<"$pad_out")"
check_contains "$pad_out" "pad=0 0 0 $((left_val + 2))" "_tui_measure: GUM_CHOOSE_PADDING lines up with the card's text, not its left edge"
check_contains "$pad_out" "help=false" "_tui_measure: GUM_CHOOSE_SHOW_HELP is off, so lib/tui.sh's own footer is the only help line"

# Plain (file) mode never clears, even for the exact same screen.
: >"$CLEAR_LOG"
f="$(answers_file garden)"
out="$(
  OMARCHY_KIDS_TUI_ANSWERS="$f"
  export OMARCHY_KIDS_TUI_ANSWERS
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init
  # shellcheck disable=SC2034 # read by lib/tui.sh via _tui_array_copy (by name)
  web_choices=("garden|Only sites you choose|reason" "filtered|Filtered open web|reason")
  tui_screen_choose "What can K see?" 2 3 0 "" web_choices "garden"
  echo "rc=$? reply=$TUI_REPLY"
)" </dev/null
check_eq "$(cat "$CLEAR_LOG")" "" "tui_screen_choose: file mode never clears the screen"
check_contains "$out" "Only sites you choose" "tui_screen_choose: file mode still prints its own list (nothing else will)"
check_contains "$out" "rc=0 reply=garden" "tui_screen_choose: file mode still answers correctly under the new card logic"

# OMARCHY_KIDS_TUI_PLAIN=1 forces plain rendering even when TUI_MODE would
# otherwise be interactive.
: >"$CLEAR_LOG"
out="$(
  unset OMARCHY_KIDS_TUI_ANSWERS
  export OMARCHY_KIDS_TUI_PLAIN=1
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  tui_init 2>/dev/null
  TUI_MODE="interactive"
  _tui_card_mode && echo "card" || echo "plain"
)" </dev/null
check_contains "$out" "plain" "OMARCHY_KIDS_TUI_PLAIN=1: forces plain mode even in an interactive terminal"

# --- tui_init: an already-set GUM_* var (the theme's own gum_env.lua) is ---
# --- never overwritten; an unset one gets theme_color's own fallback ------

out="$(
  unset OMARCHY_KIDS_TUI_ANSWERS
  export GUM_CHOOSE_CURSOR_FOREGROUND="#custom"
  unset GUM_INPUT_PROMPT_FOREGROUND
  # shellcheck source=/dev/null
  source "$TUI_LIB"
  f="$(answers_file begin)"
  OMARCHY_KIDS_TUI_ANSWERS="$f" tui_init >/dev/null 2>&1
  echo "cursor=$GUM_CHOOSE_CURSOR_FOREGROUND"
  if [[ -n "$GUM_INPUT_PROMPT_FOREGROUND" ]]; then echo "prompt=set"; else echo "prompt=unset"; fi
)" </dev/null
check_contains "$out" "cursor=#custom" "tui_init: an already-set GUM_* var from the theme is never overwritten"
check_contains "$out" "prompt=set" "tui_init: an unset GUM_* var gets theme_color's own fallback"

# --- the demo binary runs end to end from an answers file -------------------

f="$(answers_file begin garden kid)"
out="$(OMARCHY_KIDS_TUI_ANSWERS="$f" "$DEMO" </dev/null)"
demo_rc=$?
check_eq "$demo_rc" "0" "omarchy-kids-tui-demo: a full run exits 0"
check_contains "$out" "web=garden done=kid" "omarchy-kids-tui-demo: answers flow through all three screens"

f="$(answers_file begin "@ctrlc" yes)"
OMARCHY_KIDS_TUI_ANSWERS="$f" "$DEMO" >/dev/null </dev/null
check_eq "$?" "130" "omarchy-kids-tui-demo: Ctrl+C + confirming leave exits 130"

"$DEMO" --help >/dev/null </dev/null
check_eq "$?" "0" "omarchy-kids-tui-demo: --help exits 0"

# --- non-tty with no answers file exits 2 (checked once more through the ---
# --- real command, not just the sourced library) ----------------------------

unset OMARCHY_KIDS_TUI_ANSWERS
"$DEMO" </dev/null >/dev/null 2>"$TMP/err"
check_eq "$?" "2" "omarchy-kids-tui-demo: no tty and no answers file exits 2"
check_contains "$(cat "$TMP/err")" "nothing to answer prompts with" "omarchy-kids-tui-demo: exit-2 message reaches stderr"

echo "tui-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
