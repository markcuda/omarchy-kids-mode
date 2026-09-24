# shellcheck shell=bash
# lib/launcher-map.sh — root-written launcher maps for the Level 1/2 tile grid.
# The map is the execution authority; the kid's runtime JSON is display-only.

launcher_map_path() { printf '%s/launchers/%s.json' "$ETC" "$1"; }

# launcher_map_find_desktop ID PKG — finds only package-owned desktop entries.
launcher_map_find_desktop() {
  local id="$1" pkg="$2" sysroot dir f base needle_id needle_pkg base_lc
  sysroot="${OMARCHY_KIDS_ROOT:-}"
  needle_id="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')"
  needle_pkg="${pkg#aur:}"
  needle_pkg="$(printf '%s' "$needle_pkg" | tr '[:upper:]' '[:lower:]')"
  for dir in "$sysroot/usr/share/applications" "$sysroot/usr/local/share/applications"; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*.desktop; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f" .desktop)"
      base_lc="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
      if [[ "$base_lc" == *"$needle_id"* || (-n "$needle_pkg" && "$base_lc" == *"$needle_pkg"*) ]]; then
        printf '%s\n' "$f"
        return 0
      fi
    done
  done
  return 1
}

# launcher_map_executable_ok FILE — the first argv item must not be mutable by a kid.
# launcher_map_mode_writable_by_others MODE -- group or other write bit set (755 no, 775/757 yes).
# The owner digit is not looked at: root-owned 755 is the normal case, not a threat.
launcher_map_mode_writable_by_others() {
  local mode="$1"
  [[ "${mode: -2:1}" == [2367] || "${mode: -1}" == [2367] ]]
}

launcher_map_executable_ok() {
  local file="$1"
  [[ "$file" == /* && -f "$file" && ! -L "$file" && -x "$file" ]] || return 1
  # The writable-mode refusal is not root's alone: a group/other-writable binary
  # must not be trusted by any builder, and it is what keeps a PATH a kid can set
  # from putting a binary they can rewrite into the map (AGENTS.md rule 9). The
  # owner check needs root to read the uid field.
  ! launcher_map_mode_writable_by_others "$(file_stat a "$file")" || return 1
  is_root || return 0
  [[ "$(file_stat u "$file")" == 0 ]]
}

# launcher_map_exec_json FILE — fixed absolute argv from a trusted desktop entry.
launcher_map_exec_json() {
  local argv executable
  argv="$("$KIDS_PY" "$LIB/conf.py" desktop-argv "$1")" || return 1
  executable="$(jq -r '.[0]' <<<"$argv")"
  launcher_map_executable_ok "$executable" || return 1
  printf '%s\n' "$argv"
}

# launcher_map_bare_json ID — resolves a pack fallback while root owns the map.
launcher_map_bare_json() {
  local executable
  # A pack fallback is looked up on the session's PATH (it names an installed
  # program), and the ownership check below is the fence: whatever it resolves is
  # refused unless it is root-owned and not group/other-writable, so a PATH a kid
  # can set can make a fallback absent, never point the map at a kid's binary.
  executable="$(command -v "$1" 2>/dev/null || true)"
  [[ "$executable" == /* && -x "$executable" ]] || return 1
  launcher_map_executable_ok "$executable" || return 2
  jq -n --arg executable "$executable" '[$executable]'
}

# launcher_map_render ACCOUNT OUTPUT — derives one map from the root profile.
launcher_map_render() {
  local account="$1" output="$2" band level web show_missing allowlist pack id meta label pkg desktop icon argv_json installed known bare_rc
  local entries
  local -a ids
  local sysroot="${OMARCHY_KIDS_ROOT:-}" apps_bin

  band="$(conf_get "$KIDS_DIR/$account.conf" band)"
  level="$("$CONF_BIN" get "$account" level)"
  web="$("$CONF_BIN" get "$account" web)"
  # apps.show_missing=no (the default, docs/conf.md) omits a missing app's tile.
  show_missing="$("$CONF_BIN" get "$account" apps.show_missing 2>/dev/null || echo no)"
  apps_bin="$(kids_bin apps "$DIR")"
  # A failed allowlist must not become an empty map: keep whatever map exists and say why.
  if ! allowlist="$(OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" "$apps_bin" allowlist "$account")"; then
    echo "launcher-map: omarchy-kids-apps allowlist failed for '$account'; map left as it was" >&2
    return 1
  fi
  pack="$SHARE/packs/$band.toml"
  entries="$(mktemp)"

  IFS=',' read -ra ids <<<"$allowlist"
  for id in "${ids[@]+"${ids[@]}"}"; do
    [[ -n "$id" ]] || continue
    desktop=""
    known=true
    if meta="$("$KIDS_PY" "$LIB/conf.py" pack-app "$pack" "$id" 2>/dev/null)"; then
      IFS=$'\t' read -r label pkg _web <<<"$meta"
    else
      # Extra ids have no pack row; desktop metadata still gives them a fixed tile.
      label="$id"
      pkg="$id"
      known=false
    fi
    icon=""
    argv_json='[]'
    if desktop="$(launcher_map_find_desktop "$id" "$pkg")"; then
      icon="$(grep -m1 '^Icon=' "$desktop" | cut -d= -f2- || true)"
      if ! argv_json="$(launcher_map_exec_json "$desktop" 2>/dev/null)"; then
        echo "launcher-map: desktop entry for '$id' has no trusted executable" >&2
        rm -f "$entries"
        return 1
      fi
    fi
    if [[ "$argv_json" == '[]' ]]; then
      if argv_json="$(launcher_map_bare_json "$id" 2>/dev/null)"; then
        :
      else
        bare_rc=$?
        [[ "$bare_rc" == 2 ]] || bare_rc=0
        if [[ "$bare_rc" == 2 ]]; then
          echo "launcher-map: executable for '$id' is mutable" >&2
          rm -f "$entries"
          return 1
        fi
        argv_json='[]'
      fi
    fi
    installed=false
    [[ "$argv_json" != '[]' ]] && installed=true
    if [[ "$installed" == false ]]; then
      # A missing pack app is omitted by default (apps.show_missing=no) and kept
      # greyed when yes (issue #42); an unknown extra id is a config error, not a tile.
      if [[ "$known" == false ]]; then
        echo "launcher-map: unknown launcher id '$id'" >&2
        rm -f "$entries"
        return 1
      fi
      if [[ "$show_missing" != yes ]]; then
        echo "launcher-map: omitting tile '$id' for '$account': app not installed (apps.show_missing=no)" >&2
        continue
      fi
    fi
    jq -n --arg id "$id" --arg label "$label" --arg icon "$icon" --arg pkg "$pkg" \
      --argjson argv "$argv_json" --argjson installed "$installed" \
      '{id: $id, label: $label, icon: $icon, pkg: $pkg, installed: $installed, argv: $argv}' >>"$entries"
  done

  # Web uses the packaged command, so no browser command comes from the kid's PATH.
  if [[ "$web" != "none" && -r "$sysroot/etc/chromium/policies/managed/omarchy-kids-$band.json" ]]; then
    jq -n '{id: "chromium", label: "Web", icon: "chromium", pkg: "", installed: true,
      argv: ["/usr/bin/omarchy-kids-web", "launch"]}' >>"$entries"
  fi

  if [[ "$level" != "3" && "$band" != "3-5" ]]; then
    jq -n --arg band "$band" \
      '{id: "more-apps", label: "More apps", icon: "", pkg: "", installed: true,
        argv: ["/usr/bin/env", ("OMARCHY_KIDS_BAND=" + $band), "/usr/bin/quickshell", "-p",
          "/usr/share/omarchy-kids/plugins/shell.qml"]}' >>"$entries"
  fi

  if [[ "$band" == "9-12" || "$band" == "13+" ]]; then
    jq -n '{id: "kids-data", label: "What grown-ups see", icon: "", pkg: "", installed: true,
      argv: ["/usr/bin/omarchy-launch-floating-terminal-with-presentation",
        "/usr/bin/omarchy-kids-data", "mine"]}' >>"$entries"
  fi

  jq -s --arg account "$account" --arg band "$band" --arg level "$level" \
    '{account: $account, band: $band, level: $level, tiles: .}' "$entries" >"$output"
  rm -f "$entries"
}

# launcher_map_fix ACCOUNT — atomically writes the root-owned execution map.
launcher_map_fix() {
  local account="$1" dir stage
  dir="$(dirname "$(launcher_map_path "$account")")"
  install -d -m 0755 "$dir"
  stage="$(mktemp "$dir/.$account.XXXXXX")"
  launcher_map_render "$account" "$stage" || {
    rm -f "$stage"
    return 1
  }
  chmod 0644 "$stage"
  chown root:root "$stage" 2>/dev/null || true
  mv -f "$stage" "$(launcher_map_path "$account")"
}

launcher_map_remove() { rm -f "$(launcher_map_path "$1")"; }

launcher_map_ok() {
  local account="$1" expected
  [[ "$(file_stat a "$(launcher_map_path "$account")" 2>/dev/null || true)" == 644 ]] || return 1
  expected="$(mktemp)"
  launcher_map_render "$account" "$expected" || {
    rm -f "$expected"
    return 1
  }
  cmp -s "$expected" "$(launcher_map_path "$account")"
  local rc=$?
  rm -f "$expected"
  return "$rc"
}
