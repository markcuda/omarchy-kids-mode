#!/bin/bash
# Tests R-WIZ-3's default selection across Gum v2/Kong slice parsing.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
mkdir -p "$STUBS"
GUM_LOG="$TMP/gum.log"
export GUM_LOG
cat >"$STUBS/gum" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${GUM_LOG:?}"
case "$1" in
  style) : ;;
  choose)
    selected=""
    options=()
    after_options=0
    while (($#)); do
      if [[ "$1" == --selected ]]; then selected="$2"; shift 2; continue; fi
      if [[ "$1" == -- ]]; then after_options=1; shift; continue; fi
      if ((after_options)); then options+=("$1"); fi
      shift
    done
    # Kong's slice boundary: comma splits unless escaped; backslash escapes
    # the following byte and is removed before Gum matches the option.
    parts=()
    decoded=""
    escaped=0
    for ((i = 0; i < ${#selected}; i++)); do
      ch="${selected:i:1}"
      if ((escaped)); then decoded+="$ch"; escaped=0
      elif [[ "$ch" == \\ ]]; then escaped=1
      elif [[ "$ch" == , ]]; then parts+=("$decoded"); decoded=""
      else decoded+="$ch"; fi
    done
    ((escaped == 0)) || exit 22
    parts+=("$decoded")
    chosen="${options[0]}"
    for part in "${parts[@]}"; do
      for option in "${options[@]}"; do
        [[ "$option" == "$part" ]] && chosen="$option"
      done
    done
    printf '%s\n' "$chosen"
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$STUBS/gum"

export PATH="$STUBS:$PATH"
ANSWERS="$TMP/answers"
printf '%s\n' unused >"$ANSWERS"
export OMARCHY_KIDS_TUI_ANSWERS="$ANSWERS"
export OMARCHY_KIDS_TUI_PLAIN=1 TUI_C_ACCENT=blue
source "$ROOT/lib/tui.sh"
if ! tui_init; then
  echo 'wizard default: tui_init failed with owned answers file' >&2
  exit 1
fi
[[ "$TUI_MODE" == file && "$TUI_HAVE_GUM" == 1 ]] || exit 1
# tui_init deliberately proves the no-TTY initialization path above; the
# owned Gum stub then exercises the same chooser in its interactive branch.
TUI_MODE=interactive
# shellcheck disable=SC2034 # read by tui_screen_choose via nameref-by-name
choices=("plain|Plain option|No comma" "six|Ages 6–8, \\ safe|The intended default")
tui_screen_choose "Age" 1 1 0 "" choices six
[[ "$TUI_REPLY" == six ]] || exit 1
grep -Fq -- '--selected 2) Ages 6–8\, \\ safe — The intended default' "$GUM_LOG" || exit 1

: >"$GUM_LOG"
tui_screen_choose "Plain" 1 1 0 "" choices plain
[[ "$TUI_REPLY" == plain ]] || exit 1

printf '%s\n' 'wizard default: comma/backslash selected value survives Kong parsing'
