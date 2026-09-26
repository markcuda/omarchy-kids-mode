#!/bin/bash
# Tests lib/theme.sh: theme_dir, theme_color, and theme_font (docs/theming.md).
#
# Every scenario runs in its own subshell (lib/theme.sh sourced fresh each
# time) so one test's PATH/env changes never leak into the next. Two fake
# tools go on a stub PATH: `omarchy-theme-color`, which mimics the real
# tool's `--file <colors.toml> <key>` interface (exit 1 / no output for a
# key it doesn't have, same as the real one) so these tests never depend
# on Omarchy actually being installed on the machine running test/all, and
# `fc-match`, mimicking `-f '%{family[0]}' monospace`.
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THEME_LIB="$ROOT/lib/theme.sh"

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

STUBS="$TMP/stubs"
mkdir -p "$STUBS"

# Every case below runs against this base toolset, never the machine's own
# PATH: a real Omarchy box has omarchy-theme-color, fc-match and getent,
# and the "no tool"/"unknown account" cases would never run there
# (AGENTS.md, testing rules).
BASE_PATH="$(kids_base_path "$TMP/base")"
export PATH="$BASE_PATH"

# Fake omarchy-theme-color: reads "--file <path> <key>", greps a plain
# "key=value" line out of that file (colors.toml's own real shape, quotes
# and all), same as the real parser's "one value per line" contract.
# Missing file or missing key: prints nothing and exits 1, exactly how the
# real tool reports "this theme doesn't define that key" (its own
# `[[ -n $value ]] || exit 1`). "--all" (theme_color's own readiness
# probe, lib/theme.sh's _theme_kids_tool_ready) succeeds whenever the file
# exists, regardless of which keys it defines — same as the real tool,
# which never fails just because a theme is missing a particular key.
cat >"$STUBS/omarchy-theme-color" <<'EOF'
#!/bin/bash
file="" key=""
while (( $# > 0 )); do
    case "$1" in
        --file) file="$2"; shift 2 ;;
        --all) key="--all"; shift ;;
        *) key="$1"; shift ;;
    esac
done
[[ -f "$file" ]] || exit 1
[[ "$key" == "--all" ]] && exit 0
value="$(sed -nE "s/^${key}[[:space:]]*=[[:space:]]*[\"']?([^\"']*)[\"']?.*/\1/p" "$file" | head -1)"
[[ -n "$value" ]] || exit 1
printf '%s\n' "$value"
EOF
chmod +x "$STUBS/omarchy-theme-color"

# Fake omarchy-theme-color that always fails, the way the real tool does
# when $OMARCHY_PATH isn't set outside a full Omarchy session (issue #48's
# live finding) — used below to prove that failure never aborts a caller,
# only falls back with one log line.
mkdir -p "$STUBS/broken-theme-color"
cat >"$STUBS/broken-theme-color/omarchy-theme-color" <<'EOF'
#!/bin/bash
echo "omarchy-theme-color: OMARCHY_PATH is not set" >&2
exit 1
EOF
chmod +x "$STUBS/broken-theme-color/omarchy-theme-color"

cat >"$STUBS/fc-match" <<'EOF'
#!/bin/bash
echo "Comic Sans MS"
EOF
chmod +x "$STUBS/fc-match"

FIXTURE_HOME="$TMP/home"
FIXTURE_THEME_DIR="$FIXTURE_HOME/.local/state/omarchy/current/theme"
mkdir -p "$FIXTURE_THEME_DIR"
cat >"$FIXTURE_THEME_DIR/colors.toml" <<'EOF'
background = "#111111"
foreground = "#eeeeee"
accent = "#22aaff"
muted = "#888888"
red = "#ff3333"
orange = "#ffaa00"
lighter_background = "#222222"
dark_background = "#050505"
selection = "#334455"
EOF

# --- theme_dir --------------------------------------------------------------

out="$(
  HOME="$FIXTURE_HOME"
  unset THEME_KIDS_HOME
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_dir
)"
check_eq "$out" "$FIXTURE_THEME_DIR" "theme_dir: defaults to \$HOME/.local/state/omarchy/current/theme"

out="$(
  HOME="/somewhere/else"
  THEME_KIDS_HOME="$FIXTURE_HOME"
  export THEME_KIDS_HOME
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_dir
)"
check_eq "$out" "$FIXTURE_THEME_DIR" "theme_dir: THEME_KIDS_HOME overrides \$HOME"

# --- theme_color: fixture theme dir, real-shaped omarchy-theme-color stub --

run_with_fixture() { # NAME
  (
    PATH="$STUBS:$BASE_PATH"
    THEME_KIDS_HOME="$FIXTURE_HOME"
    export PATH THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_color "$1"
  )
}

check_eq "$(run_with_fixture background)" "#111111" "theme_color background: reads colors.toml's own key"
check_eq "$(run_with_fixture foreground)" "#eeeeee" "theme_color foreground"
check_eq "$(run_with_fixture accent)" "#22aaff" "theme_color accent"
check_eq "$(run_with_fixture muted)" "#888888" "theme_color muted"
check_eq "$(run_with_fixture error)" "#ff3333" "theme_color error: mapped to colors.toml's 'red'"
check_eq "$(run_with_fixture warning)" "#ffaa00" "theme_color warning: mapped to colors.toml's 'orange'"
check_eq "$(run_with_fixture surface)" "#222222" "theme_color surface: mapped to 'lighter_background'"
check_eq "$(run_with_fixture surface_muted)" "#050505" "theme_color surface_muted: mapped to 'dark_background'"
check_eq "$(run_with_fixture highlight)" "#334455" "theme_color highlight: mapped to 'selection'"

# --- theme_color: fallback palette (no omarchy-theme-color on PATH) --------

run_no_tool() { # NAME
  (
    PATH="$BASE_PATH" # deliberately no omarchy-theme-color
    THEME_KIDS_HOME="$FIXTURE_HOME"
    export PATH THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_color "$1"
  )
}

check_eq "$(run_no_tool background)" "#1a1b26" "theme_color background: falls back with no omarchy-theme-color on PATH"
check_eq "$(run_no_tool accent)" "#8fb8ff" "theme_color accent: fallback"
check_eq "$(run_no_tool error)" "#f7768e" "theme_color error: fallback"
check_eq "$(run_no_tool warning)" "#ffd27a" "theme_color warning: fallback"
check_eq "$(run_no_tool surface)" "#232838" "theme_color surface: fallback"

# --- theme_color: tool present but this key isn't in the theme -------------

out="$(
  (
    PATH="$STUBS:$BASE_PATH"
    THEME_KIDS_HOME="$TMP/no-such-home"
    export PATH THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_color muted
  )
)"
check_eq "$out" "#9aa5ce" "theme_color: falls back when the theme has no colors.toml at all"

# --- theme_color: unknown name --------------------------------------------

(
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_color nonsense >/dev/null 2>"$TMP/err"
)
theme_color_status=$?
check_eq "$theme_color_status" "1" "theme_color: unknown name exits 1"
check_eq "$(cat "$TMP/err")" "theme_color: unknown color 'nonsense'" "theme_color: unknown name prints a message"

# --- theme_font -------------------------------------------------------------

out="$(
  PATH="$STUBS:$BASE_PATH"
  export PATH
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_font
)"
check_eq "$out" "Comic Sans MS" "theme_font: reads fc-match's resolved family"

out="$(
  PATH="$BASE_PATH" # deliberately no fc-match
  export PATH
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_font
)"
check_eq "$out" "JetBrainsMono Nerd Font" "theme_font: falls back with no fc-match on PATH"

# --- issue #48 live finding: OMARCHY_PATH/LANG defaults, a broken tool
# never aborts the caller ---------------------------------------------------
#
# Review 2.7: the defaults are no longer set at source time -- sourcing a
# library must never change the caller's environment. They apply lazily,
# the first time a theme_* function that needs them runs (theme_dir here,
# since it needs no stubbed tool).

out="$(
  unset OMARCHY_PATH
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  printf '%s\n' "${OMARCHY_PATH:-<still unset>}"
)"
check_eq "$out" "<still unset>" "sourcing lib/theme.sh: OMARCHY_PATH is untouched at source time (review 2.7)"

out="$(
  unset OMARCHY_PATH
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_dir >/dev/null
  printf '%s\n' "$OMARCHY_PATH"
)"
check_eq "$out" "/usr/share/omarchy" "calling a theme_* function: OMARCHY_PATH defaults when unset"

out="$(
  OMARCHY_PATH=/some/other/path
  export OMARCHY_PATH
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_dir >/dev/null
  printf '%s\n' "$OMARCHY_PATH"
)"
check_eq "$out" "/some/other/path" "calling a theme_* function: an already-set OMARCHY_PATH is left alone"

out="$(
  unset LANG
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  printf '%s\n' "${LANG:-<still unset>}"
)"
check_eq "$out" "<still unset>" "sourcing lib/theme.sh: LANG is untouched at source time (review 2.7)"

out="$(
  unset LANG
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_dir >/dev/null
  printf '%s\n' "$LANG"
)"
check_eq "$out" "C.UTF-8" "calling a theme_* function: LANG defaults to C.UTF-8 when unset"

out="$(
  LANG=C
  export LANG
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_dir >/dev/null
  printf '%s\n' "$LANG"
)"
check_eq "$out" "C.UTF-8" "calling a theme_* function: LANG=C is also upgraded to C.UTF-8"

out="$(
  LANG=en_US.UTF-8
  export LANG
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_dir >/dev/null
  printf '%s\n' "$LANG"
)"
check_eq "$out" "en_US.UTF-8" "calling a theme_* function: a real LANG is left alone"

# A tool on PATH that always dies the way the live report described
# ("OMARCHY_PATH is not set") must never abort a caller — not even one
# running under set -euo pipefail, the mode every bin/omarchy-kids-*
# command uses — and falls back to the palette with exactly one warning
# line, not one per color resolved.
# A `{ ...; } 2>file` group, not a trailing redirect on the assignment
# itself (`out="$(...)" 2>file`) — the plain bash 3.2 this also has to run
# under (AGENTS.md, lib/tui.sh's own _tui_array_copy comment) does not
# reliably apply a redirect trailing a bare assignment to the command
# substitution's own stderr; wrapping the assignment in a group does.
{
  out="$(
    set -euo pipefail
    PATH="$STUBS/broken-theme-color:$BASE_PATH"
    THEME_KIDS_HOME="$FIXTURE_HOME"
    export PATH THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    for name in background foreground accent muted error warning; do
      theme_color "$name"
    done
    echo "survived rc=$?"
  )"
  rc_survived=$?
} 2>"$TMP/broken.err"
check_eq "$rc_survived" "0" "theme_color: a broken omarchy-theme-color under set -e never aborts the caller"
check_eq "$out" "$(printf '#1a1b26\n#ffffff\n#8fb8ff\n#9aa5ce\n#f7768e\n#ffd27a\nsurvived rc=0')" \
  "theme_color: falls back to the palette for every name when the tool is broken"
check_eq "$(wc -l <"$TMP/broken.err" | tr -d ' ')" "1" \
  "theme_color: a broken tool logs exactly one line, not once per color"
check_eq "$(cat "$TMP/broken.err")" \
  "theme_color: omarchy-theme-color is missing or failed here — using the fallback palette (docs/theming.md)" \
  "theme_color: the one log line explains what happened and where to read more"

# --- issue #53: account_home, theme_current_name --------------------

check_eq "$(
  (
    unset OMARCHY_KIDS_HOME_ROOT
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    account_home nosuchaccountxyz
  )
)" "/home/nosuchaccountxyz" \
  "account_home: falls back to /home/<account> for an unknown account"

check_eq "$(
  (
    OMARCHY_KIDS_HOME_ROOT="$TMP/scratchroot"
    export OMARCHY_KIDS_HOME_ROOT
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    account_home kid-ada
  )
)" "$TMP/scratchroot/home/kid-ada" \
  "account_home: OMARCHY_KIDS_HOME_ROOT prefixes the fallback path"

echo tokyo-night >"$FIXTURE_HOME/.local/state/omarchy/current/theme.name"
check_eq "$(
  (
    THEME_KIDS_HOME="$FIXTURE_HOME"
    export THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_current_name
  )
)" "tokyo-night" "theme_current_name: reads .../current/theme.name beside theme_dir"

check_eq "$(
  (
    THEME_KIDS_HOME="$TMP/no-such-home"
    export THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_current_name
  )
)" "" "theme_current_name: empty (not an error) with no theme.name at all"

# rule 9: root opens a kid-writable theme.name with O_NOFOLLOW + a regular-file
# check, so a FIFO cannot hang the assert and a symlink is not followed.
FIFO_HOME="$TMP/fifo-home"
mkdir -p "$FIFO_HOME/.local/state/omarchy/current"
/usr/bin/mkfifo "$FIFO_HOME/.local/state/omarchy/current/theme.name"
check_eq "$(
  (
    THEME_KIDS_HOME="$FIFO_HOME"
    export THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_current_name
  )
)" "" "theme_current_name: a FIFO theme.name reads empty, never hangs (rule 9)"
rm -f "$FIFO_HOME/.local/state/omarchy/current/theme.name"
ln -s /etc/passwd "$FIFO_HOME/.local/state/omarchy/current/theme.name"
check_eq "$(
  (
    THEME_KIDS_HOME="$FIFO_HOME"
    export THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_current_name
  )
)" "" "theme_current_name: a symlinked theme.name is not followed (rule 9)"

# theme_name_state tells "nothing set" from "planted something", so the lock can
# FAIL on a FIFO/symlink instead of reading it as "no theme" (review finding).
check_eq "$(
  (
    THEME_KIDS_HOME="$TMP/no-such-home"
    export THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_name_state
  )
)" "none" "theme_name_state: absent theme.name is 'none'"
check_eq "$(
  (
    THEME_KIDS_HOME="$FIFO_HOME"
    export THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_name_state
  )
)" "unsafe" "theme_name_state: a symlinked theme.name is 'unsafe'"
rm -f "$FIFO_HOME/.local/state/omarchy/current/theme.name"
/usr/bin/mkfifo "$FIFO_HOME/.local/state/omarchy/current/theme.name"
check_eq "$(
  (
    THEME_KIDS_HOME="$FIFO_HOME"
    export THEME_KIDS_HOME
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_name_state
  )
)" "unsafe" "theme_name_state: a FIFO theme.name is 'unsafe' (O_NONBLOCK, no hang)"

# --- issue #53: theme_list_installed, theme_apply_for, theme_reload_if_live -

OMARCHY_SHARE="$TMP/omarchy-share"
mkdir -p "$OMARCHY_SHARE/themes/tokyo-night" "$OMARCHY_SHARE/themes/catppuccin-latte"
cat >"$OMARCHY_SHARE/themes/tokyo-night/colors.toml" <<'EOF'
background = "#1a1b26"
foreground = "#c0caf5"
EOF
mkdir -p "$OMARCHY_SHARE/themes/tokyo-night/backgrounds"
: >"$OMARCHY_SHARE/themes/tokyo-night/backgrounds/bg1.png"
cat >"$OMARCHY_SHARE/themes/catppuccin-latte/colors.toml" <<'EOF'
background = "#eff1f5"
foreground = "#4c4f69"
EOF

check_eq "$(
  (
    OMARCHY_PATH="$OMARCHY_SHARE"
    export OMARCHY_PATH
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    KIDS_THEMES_DIR="$TMP/no-kids-themes"
    theme_list_installed
  )
)" "$(printf 'catppuccin-latte\ntokyo-night')" \
  "theme_list_installed: every theme under \$OMARCHY_PATH/themes, sorted"

check_eq "$(
  (
    OMARCHY_PATH="$TMP/no-such-omarchy-path"
    export OMARCHY_PATH
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    KIDS_THEMES_DIR="$TMP/no-kids-themes"
    theme_list_installed
  )
)" "" "theme_list_installed: empty, not an error, with no themes dir at all"

# The package's own kid theme root is listed too, and a name in both roots
# appears once (docs/theming.md, the kid theme collection).
KIDS_SHARE="$TMP/kids-share"
mkdir -p "$KIDS_SHARE/themes-kids/cozy-night" "$KIDS_SHARE/themes-kids/tokyo-night"
: >"$KIDS_SHARE/themes-kids/cozy-night/colors.toml"
: >"$KIDS_SHARE/themes-kids/tokyo-night/colors.toml"
check_eq "$(
  (
    OMARCHY_PATH="$OMARCHY_SHARE"
    export OMARCHY_PATH
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    # shellcheck disable=SC2034 # read by the sourced theme_list_installed
    KIDS_THEMES_DIR="$KIDS_SHARE/themes-kids"
    theme_list_installed
  )
)" "$(printf 'catppuccin-latte\ncozy-night\ntokyo-night')" \
  "theme_list_installed: the kid theme root is listed too, de-duplicated by name"

APPLY_HOME_ROOT="$TMP/apply-homeroot"
mkdir -p "$APPLY_HOME_ROOT/home/kid-ada"
(
  OMARCHY_PATH="$OMARCHY_SHARE"
  OMARCHY_KIDS_HOME_ROOT="$APPLY_HOME_ROOT"
  export OMARCHY_PATH OMARCHY_KIDS_HOME_ROOT
  # shellcheck source=/dev/null
  source "$THEME_LIB"
  theme_apply_for kid-ada tokyo-night
)
apply_rc=$?
check_eq "$apply_rc" "0" "theme_apply_for: exits 0 for a real theme"

KID_THEME_DIR="$APPLY_HOME_ROOT/home/kid-ada/.local/state/omarchy/current/theme"
check_eq "$(cat "$KID_THEME_DIR/colors.toml" 2>/dev/null)" "$(cat "$OMARCHY_SHARE/themes/tokyo-night/colors.toml")" \
  "theme_apply_for: colors.toml copied verbatim from the system theme"
[[ -f "$KID_THEME_DIR/backgrounds/bg1.png" ]] && pass "theme_apply_for: copies the whole theme tree, not just colors.toml" ||
  fail "theme_apply_for: backgrounds/ was not copied"
check_eq "$(cat "$APPLY_HOME_ROOT/home/kid-ada/.local/state/omarchy/current/theme.name" 2>/dev/null)" "tokyo-night" \
  "theme_apply_for: writes theme.name beside the theme directory"

mode="$(kids_file_mode "$KID_THEME_DIR/colors.toml")"
check_eq "$mode" "644" "theme_apply_for: theme files are mode 0644"

out="$(
  (
    OMARCHY_PATH="$OMARCHY_SHARE"
    OMARCHY_KIDS_HOME_ROOT="$APPLY_HOME_ROOT"
    export OMARCHY_PATH OMARCHY_KIDS_HOME_ROOT
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_apply_for kid-ada no-such-theme
  ) 2>&1
)"
apply_bad_rc=$?
check_eq "$apply_bad_rc" "1" "theme_apply_for: exits 1 for an unknown theme name"
check_contains "$out" "no such theme 'no-such-theme'" "theme_apply_for: names the missing theme in its error"

# theme_reload_if_live: no live session for this account (no real Hyprland
# process owned by it in this test environment) is a no-op with one line,
# never a failure.
out="$(
  (
    OMARCHY_KIDS_HOME_ROOT="$APPLY_HOME_ROOT"
    export OMARCHY_KIDS_HOME_ROOT
    # shellcheck source=/dev/null
    source "$THEME_LIB"
    theme_reload_if_live kid-ada
  ) 2>&1
)"
reload_rc=$?
check_eq "$reload_rc" "0" "theme_reload_if_live: exits 0 with no live session"
check_contains "$out" "no live session for 'kid-ada'" "theme_reload_if_live: explains why it did nothing"

echo "theme-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
