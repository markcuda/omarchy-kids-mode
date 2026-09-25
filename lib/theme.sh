# shellcheck shell=bash
# lib/theme.sh -- resolves Omarchy's per-theme colors/font the way
# Omarchy's own tools do, so every Kids Mode surface matches the parent's
# theme. THEME_KIDS_HOME points resolution at another account's $HOME, for
# a root-owned caller (lib/posture.sh). Not meant to be executed directly.
# See docs/theming.md for the ground-truth citations against v4.0.2.

# shellcheck source=./kids.sh
source "$(dirname "${BASH_SOURCE[0]}")/kids.sh" # account_home

# The package's own kid theme root: a second, package-owned themes directory
# beside Omarchy's, so the kid theme collection ships without writing into
# /usr/share/omarchy (I-7). A plain build-time constant, never an environment
# read (AGENTS.md rule 9): nothing a kid can set chooses it. Listed after
# Omarchy's, so an upstream theme of the same name wins (theme_list_installed,
# theme_apply_for). A test overrides it after sourcing.
KIDS_THEMES_DIR=/usr/share/omarchy-kids/themes-kids

# _theme_kids_env_defaults -- defaults $OMARCHY_PATH/$LANG (issue #48) --
# unset in a session with no Omarchy env (SSH, CI). Called from every
# function below that reads $OMARCHY_PATH or is about to run an Omarchy
# tool, never at source time, so sourcing this library never changes the
# caller's environment (review 2.7). A tool that still fails never aborts
# the caller, see _theme_kids_tool_ready. Idempotent; cheap to call again.
_theme_kids_env_defaults() {
  : "${OMARCHY_PATH:=/usr/share/omarchy}"
  export OMARCHY_PATH
  if [[ -z "${LANG:-}" || "${LANG:-}" == "C" ]]; then
    export LANG=C.UTF-8
  fi
}

# theme_dir -- the directory whose colors.toml theme_color/theme_font
# read. THEME_KIDS_HOME overrides $HOME; unset falls back to plain $HOME.
theme_dir() {
  _theme_kids_env_defaults
  printf '%s/.local/state/omarchy/current/theme' "${THEME_KIDS_HOME:-$HOME}"
}

# _theme_kids_fallback NAME -- matches share/sddm-theme/theme.conf's own
# hardcoded defaults.
_theme_kids_fallback() {
  case "$1" in
    background) printf '#1a1b26\n' ;;
    foreground) printf '#ffffff\n' ;;
    accent) printf '#8fb8ff\n' ;;
    muted) printf '#9aa5ce\n' ;;
    error) printf '#f7768e\n' ;;
    warning) printf '#ffd27a\n' ;;
    surface) printf '#232838\n' ;;
    surface_muted) printf '#1f2335\n' ;;
    highlight) printf '#3a4266\n' ;;
  esac
}
THEME_KIDS_FALLBACK_FONT="JetBrainsMono Nerd Font"

# _theme_kids_tool_ready -- cached (_THEME_KIDS_TOOL_STATUS) probe of
# whether omarchy-theme-color can actually answer for this account. --all
# never fails for a key a theme lacks -- nor for a colors.toml that is not
# there at all, where the tool still derives a few keys from nothing; hence
# the explicit readability check, so a themeless account gets the whole
# fallback palette rather than one derived black tile.
_THEME_KIDS_TOOL_STATUS=""
_theme_kids_tool_ready() {
  _theme_kids_env_defaults
  if [[ -z "$_THEME_KIDS_TOOL_STATUS" ]]; then
    if command -v omarchy-theme-color >/dev/null 2>&1 &&
      [[ -r "$(theme_dir)/colors.toml" ]] &&
      omarchy-theme-color --file "$(theme_dir)/colors.toml" --all >/dev/null 2>&1; then
      _THEME_KIDS_TOOL_STATUS="ok"
    else
      _THEME_KIDS_TOOL_STATUS="unavailable"
      echo "theme_color: omarchy-theme-color is missing or failed here — using the fallback palette (docs/theming.md)" >&2
    fi
  fi
  [[ "$_THEME_KIDS_TOOL_STATUS" == "ok" ]]
}

# theme_color NAME -- resolves one semantic color via omarchy-theme-color,
# falling back to _theme_kids_fallback. docs/theming.md for the key map.
theme_color() {
  local name="$1" key value
  case "$name" in
    background | foreground | accent | muted) key="$name" ;;
    error) key="red" ;;
    warning) key="orange" ;;
    surface) key="lighter_background" ;;
    surface_muted) key="dark_background" ;;
    highlight) key="selection" ;;
    *)
      echo "theme_color: unknown color '$name'" >&2
      return 1
      ;;
  esac

  if _theme_kids_tool_ready; then
    value="$(omarchy-theme-color --file "$(theme_dir)/colors.toml" "$key" 2>/dev/null || true)"
  fi
  if [[ -z "${value:-}" ]]; then
    value="$(_theme_kids_fallback "$name")"
  fi
  printf '%s\n' "$value"
}

# theme_font -- resolves "monospace" via fc-match, same as Omarchy's
# shell. THEME_KIDS_HOME has no effect: fontconfig resolves per-process.
theme_font() {
  local family
  if command -v fc-match >/dev/null 2>&1; then
    family="$(fc-match -f '%{family[0]}' monospace 2>/dev/null || true)"
  fi
  [[ -n "${family:-}" ]] || family="$THEME_KIDS_FALLBACK_FONT"
  printf '%s\n' "$family"
}

# Geometry follows the parent's live compositor or its last matching snapshot.
# The helper reads theme files as data only; see docs/theming.md.
theme_geometry() {
  local parent="$1" cache="$2" helper
  helper="$(dirname "${BASH_SOURCE[0]}")/theme-geometry.py"
  "$KIDS_PY" "$helper" "$parent" "${THEME_KIDS_HOME:-$HOME}" "$cache"
}

# theme_current_name -- theme_dir's own theme.name, plain one-line file.
# Empty, not an error, if that account has never received a theme.
# The read is a root process opening a file inside a kid's home (rule 9), so it
# goes through O_NOFOLLOW + a regular-file check: a FIFO or a symlink a kid
# plants must never hang the assert or follow to another file. Empty on any
# error. `theme_geometry` is the same shape for the portal (lib/theme-geometry.py).
theme_current_name() {
  local f
  f="$(dirname "$(theme_dir)")/theme.name"
  "$KIDS_PY" -c 'import os, stat, sys
p = sys.argv[1]
try:
    fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0))
except OSError:
    sys.exit(0)
try:
    if not stat.S_ISREG(os.fstat(fd).st_mode):
        sys.exit(0)
    data = os.read(fd, 4096)
finally:
    os.close(fd)
sys.stdout.write(data.decode("utf-8", "replace").strip() + "\n")
' "$f" 2>/dev/null || true
}

# theme_list_installed -- every name under $OMARCHY_PATH/themes and the
# package's own $KIDS_THEMES_DIR, sorted and de-duplicated. The wizard/panel
# Desktop screens offer only these, never a user-installed
# ~/.config/omarchy/themes/<name> -- docs/theming.md issue #53.
theme_list_installed() {
  _theme_kids_env_defaults
  local dir d
  for dir in "$OMARCHY_PATH/themes" "$KIDS_THEMES_DIR"; do
    [[ -d "$dir" ]] || continue
    for d in "$dir"/*/; do
      [[ -d "$d" ]] || continue
      basename "$d"
    done
  done | sort -u
}

# theme_apply_for ACCOUNT NAME -- writes ACCOUNT's current theme, mirroring
# omarchy-theme-set's own build-then-swap shape but narrower (no user-theme
# overlay, no background, no live-session restart -- theme_reload_if_live
# is that half). Kid-owned inside the kid's own home (T44): the theme is a
# presentation preference, so the kid may change it on Omarchy's own chord; the
# "theme:<account>" assert lock is verify-only (it refuses a name outside the
# offered set, never re-applies over the kid's choice). See docs/theming.md
# issue #53 and docs/phase1/SPEC-AMENDMENT-kid-themes.md.
theme_apply_for() {
  _theme_kids_env_defaults
  local account="$1" name="$2" home src current next tmp
  home="$(account_home "$account")"
  src="$OMARCHY_PATH/themes/$name"
  [[ -d "$src" ]] || src="$KIDS_THEMES_DIR/$name"
  if [[ ! -d "$src" ]]; then
    echo "theme_apply_for: no such theme '$name' under $OMARCHY_PATH/themes or $KIDS_THEMES_DIR" >&2
    return 1
  fi

  current="$home/.local/state/omarchy/current/theme"
  next="$home/.local/state/omarchy/current/.next-theme.$$"
  install -d -m 0755 "$(dirname "$current")" || return 1
  rm -rf "$next"
  install -d -m 0755 "$next" || return 1
  cp -r "$src/." "$next/" 2>/dev/null

  if [[ ! -f "$next/colors.toml" && -f "$next/alacritty.toml" ]] &&
    command -v omarchy-theme-colors-from-alacritty >/dev/null 2>&1; then
    omarchy-theme-colors-from-alacritty "$next" >/dev/null 2>&1 || true
  fi

  if ! chown -R "$account:$account" "$next" >/dev/null 2>&1; then
    echo "theme_apply_for: could not chown $next to $account (fine outside a real root run)" >&2
  fi
  find "$next" -type d -exec chmod 0755 {} + 2>/dev/null
  find "$next" -type f -exec chmod 0644 {} + 2>/dev/null

  rm -rf "$current"
  mv "$next" "$current" || return 1

  tmp="$(mktemp "$(dirname "$current")/.theme.name.XXXXXX")" || return 1
  printf '%s\n' "$name" >"$tmp"
  chown "$account:$account" "$tmp" >/dev/null 2>&1 || true
  chmod 0644 "$tmp"
  mv -f "$tmp" "$(dirname "$current")/theme.name"
}

# theme_reload_if_live ACCOUNT -- best-effort IPC reload (same call
# omarchy-theme-set's shell_ipc makes), run as ACCOUNT via runuser so it
# reaches their own socket, not root's. No-op with one log line when
# ACCOUNT has no live Hyprland session -- the theme is on disk either way.
theme_reload_if_live() {
  local account="$1" current colors_b64="" shell_b64=""
  if ! pgrep -u "$account" -x Hyprland >/dev/null 2>&1; then
    echo "theme_reload_if_live: no live session for '$account' -- the new theme applies at next login" >&2
    return 0
  fi
  current="$(account_home "$account")/.local/state/omarchy/current/theme"
  [[ -f "$current/colors.toml" ]] && colors_b64="$(base64 -w 0 "$current/colors.toml" 2>/dev/null || true)"
  [[ -f "$current/shell.toml" ]] && shell_b64="$(base64 -w 0 "$current/shell.toml" 2>/dev/null || true)"
  if command -v runuser >/dev/null 2>&1; then
    runuser -l "$account" -c "timeout 2 omarchy-shell shell applyTheme '$colors_b64' '$shell_b64'" >/dev/null 2>&1 ||
      echo "theme_reload_if_live: live reload failed for '$account' -- the theme is applied on disk, they will see it at next login" >&2
  fi
}
