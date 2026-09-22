# shellcheck shell=bash
# lib/time.sh -- shared helpers for the screen-time engine (SPEC.md
# R-TIME-1..5, Appendix F). Trust boundary: every write under $TIME_ROOT
# is only ever called by the root ledger helper or `omarchy-kids-time
# grant` (I-3, R-TIME-1) -- the kid-run command only ever reads. Not
# meant to be executed directly; source it. Every path/env var: docs/time.md.

# Root-side callers may replace this explicit scratch-tree seam after sourcing.
TIME_SYSROOT=""
TIME_VARLIB="$TIME_SYSROOT/var/lib/omarchy-kids"
TIME_NOW_FILE=""
TIME_CLOCK_FILE=""

# time_now — prints "YYYY-MM-DD HH:MM:SS", local wall clock.
time_now() {
  if [[ -n "$TIME_NOW_FILE" && -r "$TIME_NOW_FILE" ]]; then
    tr -d '\n' <"$TIME_NOW_FILE"
    printf '\n'
  else
    printf '%s\n' "${OMARCHY_KIDS_NOW:-$(date '+%Y-%m-%d %H:%M:%S')}"
  fi
}

# time_root_now — the authority never accepts an inherited clock value.
time_root_now() {
  if [[ -n "$TIME_NOW_FILE" && -r "$TIME_NOW_FILE" ]]; then
    tr -d '\n' <"$TIME_NOW_FILE"
    printf '\n'
  else
    date '+%Y-%m-%d %H:%M:%S'
  fi
}

# time_monotonic — integer monotonic seconds. Tests replace the build-time
# clock file; production reads Linux's monotonic uptime source.
time_monotonic() {
  local clock_file="${TIME_CLOCK_FILE:-/proc/uptime}"
  if [[ -r "$clock_file" ]]; then
    awk '{ print int($1) }' "$clock_file"
  else
    "$KIDS_PY" -c 'import time; print(int(time.monotonic()))'
  fi
}

# time_split_elapsed PREVIOUS_WALL CURRENT_WALL ELAPSED — split a short
# active interval at the 04:00 logical-day boundary.
time_split_elapsed() {
  "$KIDS_PY" - "$1" "$2" "$3" <<'PY'
import datetime
import sys

previous = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%d %H:%M:%S")
current = datetime.datetime.strptime(sys.argv[2], "%Y-%m-%d %H:%M:%S")
elapsed = max(0, int(sys.argv[3]))
wall_seconds = (current - previous).total_seconds()
boundary = datetime.datetime.combine(current.date(), datetime.time(4, 0))
if (wall_seconds <= 0 or wall_seconds > 86400 or
        not previous < boundary <= current):
    print("0")
    print(elapsed)
    raise SystemExit
before = max(0, min(elapsed, int((boundary - previous).total_seconds())))
print(before)
print(elapsed - before)
PY
}

# time_hm NOW — prints NOW's "HH:MM" (the last field, minus seconds).
time_hm() {
  local now="$1"
  printf '%s\n' "${now#* }" | cut -c1-5
}

# time_minutes_since_midnight HH:MM — an integer 0..1439.
time_minutes_since_midnight() {
  local hm="$1" h m
  h="${hm%%:*}"
  m="${hm##*:}"
  # Force base-10: bash treats a leading zero ("09") as octal otherwise,
  # and 08/09 are exactly the hours/minutes that trip that up.
  printf '%d\n' $((10#$h * 60 + 10#$m))
}

# time_logical_day NOW — "DAY\tWEEKEND" via lib/time.py (rolls at 04:00 local).
time_logical_day() {
  local now="$1" py out
  py="$(dirname "${BASH_SOURCE[0]}")/time.py"
  [[ -f "$py" ]] || py=/usr/lib/omarchy-kids/time.py
  out="$("$KIDS_PY" "$py" logical-day "$now")" || return 1
  printf '%s\t%s\n' "$(sed -n '1p' <<<"$out")" "$(sed -n '2p' <<<"$out")"
}

# time_conf KID KEY — omarchy-kids-conf get KID KEY, resolved as our own sibling.
time_conf() {
  local kid="$1" key="$2" bin
  bin="$(dirname "${BASH_SOURCE[0]}")/../bin/omarchy-kids-conf"
  [[ -x "$bin" ]] || bin=/usr/bin/omarchy-kids-conf
  "$bin" get "$kid" "$key"
}

# time_budget_minutes KID WEEKEND(yes/no) — budget_min(_weekend), via the band (R-TIME-2).
time_budget_minutes() {
  local kid="$1" weekend="$2" key=budget_min
  [[ "$weekend" == yes ]] && key=budget_min_weekend
  time_conf "$kid" "$key"
}

# time_lights_out KID WEEKEND(yes/no) — lights_out(_weekend) as HH:MM (R-TIME-2).
time_lights_out() {
  local kid="$1" weekend="$2" key=lights_out
  [[ "$weekend" == yes ]] && key=lights_out_weekend
  time_conf "$kid" "$key"
}

# time_kid_dir KID — /var/lib/omarchy-kids/<kid>, this kid's data area.
time_kid_dir() { printf '%s/%s\n' "$TIME_VARLIB" "$1"; }

# time_usage_dir KID — where per-day ledger/grant files live (R-TIME-1).
time_usage_dir() { printf '%s/usage\n' "$(time_kid_dir "$1")"; }

# time_usage_file KID DAY — one logical day's ledger: a bare integer,
# minutes used; missing means 0, never an error.
time_usage_file() { printf '%s/%s\n' "$(time_usage_dir "$1")" "$2"; }

# time_grant_file KID DAY — a one-off extension on DAY's budget (R-TIME-4).
time_grant_file() { printf '%s/%s.grant\n' "$(time_usage_dir "$1")" "$2"; }

# time_paused_file KID — its mere existence means "don't count" (R-TIME-2);
# nothing writes it yet, --pause isn't implemented (docs/exit.md).
time_paused_file() { printf '%s/paused\n' "$(time_kid_dir "$1")"; }

# time_is_paused KID — 0 (true) if the paused flag file exists.
time_is_paused() { [[ -e "$(time_paused_file "$1")" ]]; }

# time_read_int FILE — the integer FILE holds, or 0 if missing/corrupt.
time_read_int() {
  local file="$1" v
  [[ -r "$file" ]] || {
    printf '0\n'
    return 0
  }
  v="$(cat "$file" 2>/dev/null)"
  [[ "$v" =~ ^[0-9]+$ ]] || v=0
  printf '%s\n' "$v"
}

# time_used_minutes KID DAY
time_used_minutes() { time_read_int "$(time_usage_file "$1" "$2")"; }

# time_granted_minutes KID DAY
time_granted_minutes() { time_read_int "$(time_grant_file "$1" "$2")"; }

# time_write_int FILE VALUE — root-only. Creates the parent dir if
# needed, writes VALUE mode 0644 (world-readable, like lib/conf.sh's).
time_write_int() {
  local file="$1" value="$2" dir tmp
  dir="$(dirname "$file")"
  [[ -d "$dir" ]] || install -d -m 0755 "$dir"
  tmp="$(mktemp "${file}.XXXXXX")"
  printf '%s\n' "$value" >"$tmp"
  chmod 0644 "$tmp"
  mv "$tmp" "$file"
}

# time_ledger_add KID DAY MINUTES — adds MINUTES (usually 1) to DAY's used-minutes file. Root-only.
time_ledger_add() {
  local kid="$1" day="$2" add="$3" file cur
  file="$(time_usage_file "$kid" "$day")"
  cur="$(time_read_int "$file")"
  time_write_int "$file" "$((cur + add))"
}

# time_grant_add KID DAY MINUTES — adds MINUTES to DAY's one-off grant. Root-only.
time_grant_add() {
  local kid="$1" day="$2" add="$3" file cur
  file="$(time_grant_file "$kid" "$day")"
  cur="$(time_read_int "$file")"
  time_write_int "$file" "$((cur + add))"
}

# time_grant_newer_than KID DAY STATE_FILE — true when today's grant file is
# newer than the last published root tick. That document's remaining seconds
# were computed before the grant, so a just-made grant is invisible in it
# until the root ledger tick's next pass (30 s); status then keeps the parent-facing
# numbers by falling back to the read-only ledger math (docs/time.md). The
# published document is never rewritten here: enforcement still recomputes
# from the ledger.
time_grant_newer_than() {
  local grant state
  grant="$(time_grant_file "$1" "$2")"
  state="$3"
  [[ -f "$grant" && "$grant" -nt "$state" ]]
}

# time_remaining_minutes KID DAY WEEKEND — budget + grant - used, floored at 0.
time_remaining_minutes() {
  local kid="$1" day="$2" weekend="$3" budget used granted remaining
  budget="$(time_budget_minutes "$kid" "$weekend")"
  used="$(time_used_minutes "$kid" "$day")"
  granted="$(time_granted_minutes "$kid" "$day")"
  remaining=$((budget + granted - used))
  ((remaining < 0)) && remaining=0
  printf '%s\n' "$remaining"
}

# time_is_lights_out KID DAY WEEKEND NOW_HM — yes/no: reached lights-out.
time_is_lights_out() {
  local kid="$1" weekend="$2" now_hm="$3" lights_out now_min lo_min
  lights_out="$(time_lights_out "$kid" "$weekend")"
  now_min="$(time_minutes_since_midnight "$now_hm")"
  lo_min="$(time_minutes_since_midnight "$lights_out")"
  if ((now_min >= lo_min)); then printf 'yes\n'; else printf 'no\n'; fi
}

# time_next_boundary KID DAY WEEKEND NOW_HM — "KIND HH:MM": whichever of
# budget-runs-out or lights-out comes first.
time_next_boundary() {
  local kid="$1" day="$2" weekend="$3" now_hm="$4"
  local remaining lights_out now_min lo_min budget_out_min h m
  remaining="$(time_remaining_minutes "$kid" "$day" "$weekend")"
  lights_out="$(time_lights_out "$kid" "$weekend")"
  now_min="$(time_minutes_since_midnight "$now_hm")"
  lo_min="$(time_minutes_since_midnight "$lights_out")"
  budget_out_min=$((now_min + remaining))
  if ((remaining <= 0)) || ((budget_out_min >= lo_min)); then
    printf 'lights-out %s\n' "$lights_out"
  else
    h=$((budget_out_min / 60))
    m=$((budget_out_min % 60))
    printf 'budget %02d:%02d\n' "$h" "$m"
  fi
}

# time_state_dir/state_file — root-owned runtime status readable by the kid.
time_state_dir() { printf '%s/run/omarchy-kids/time\n' "$TIME_SYSROOT"; }
time_state_file() { printf '%s/%s.json\n' "$(time_state_dir)" "$1"; }

# time_state_boundary FILE — format the root-published next deadline for a parent display.
time_state_boundary() {
  local file="$1" reason last_wall remaining
  reason="$(jq -r '.reason' "$file")"
  last_wall="$(jq -r '.last_wall' "$file")"
  remaining="$(jq -r '.remaining_seconds' "$file")"
  if [[ "$reason" == lights-out ]]; then
    printf 'lights-out %s\n' "$(time_hm "$last_wall")"
    return 0
  fi
  "$KIDS_PY" - "$last_wall" "$remaining" <<'PY'
import datetime
import sys

wall = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%d %H:%M:%S")
deadline = wall + datetime.timedelta(seconds=int(sys.argv[2]))
print(f"budget {deadline:%H:%M}")
PY
}

# time_warning_thresholds PREV_SECONDS CURRENT_SECONDS FIRED — prints the
# thresholds fired now, then the retained threshold list for the next tick.
time_warning_thresholds() {
  local prev="$1" current="$2" fired="$3" threshold next_fired="" warning_now=""
  local -a warning_thresholds=(10 5 1)
  for threshold in "${warning_thresholds[@]}"; do
    if ((current <= threshold * 60)) && [[ " $fired " == *" $threshold "* ]]; then
      next_fired+="${next_fired:+ }$threshold"
    fi
  done
  fired="$next_fired"
  for threshold in "${warning_thresholds[@]}"; do
    if [[ " $fired " != *" $threshold "* ]] && ((current <= threshold * 60)) &&
      { [[ -z "$prev" ]] || ((prev > threshold * 60)); }; then
      warning_now+="${warning_now:+ }$threshold"
      fired+="${fired:+ }$threshold"
    fi
  done
  printf '%s\n' "$warning_now"
  printf '%s\n' "$fired"
}

# time_state_read FILE — validates the fixed schema before root consumes it.
time_state_read() {
  local file="$1"
  [[ -f "$file" && ! -L "$file" && -r "$file" ]] || return 1
  [[ "$(file_stat a "$file")" == 640 ]] || return 1
  jq -e '
    (.state | IN("allowed", "warning", "grace", "finishing")) and
    (.reason | type == "string") and
    (.remaining_seconds | type == "number" and . >= 0 and floor == .) and
    (.grace_deadline | type == "number" and . >= 0 and floor == .) and
    (.last_tick | type == "number" and . >= 0 and floor == .) and
    (.active_seconds_remainder | type == "number" and . >= 0 and . < 60 and floor == .) and
    (.warnings_fired | type == "array" and all(.[]; . == 1 or . == 5 or . == 10)) and
    (.logical_day | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) and
    (.last_wall | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$")) and
    ((.enforcement // {}) | (.action // "none") |
      IN("none", "lock", "finish")) and
    ((.enforcement // {}) | (.reason // "none") | type == "string") and
    ((.enforcement // {}) | (.result // "none") |
      IN("none", "success", "failed", "not-needed")) and
    ((.enforcement // {}) | (.at // "") |
      (type == "string" and (length == 0 or
        test("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"))))
  ' "$file" >/dev/null 2>&1
}

# time_state_write KID DAY STATE REASON REMAINING GRACE LAST REMAINDER FIRED LAST_WALL ACTION ACTION_REASON ACTION_RESULT ACTION_AT.
# Atomic replacement keeps a reader from seeing half a decision.
time_state_write() {
  local kid="$1" day="$2" state="$3" reason="$4" remaining="$5"
  local grace="$6" last="$7" remainder="$8" fired="$9" last_wall="${10}"
  local action="${11:-none}" action_reason="${12:-none}" action_result="${13:-none}"
  local action_at="${14:-}" dir tmp fired_json='[]'
  dir="$(time_state_dir)"
  install -d -m 0750 "$dir"
  chmod 0750 "$dir"
  chown root:omarchy-kids "$dir" 2>/dev/null || true
  if [[ -n "$fired" ]]; then
    fired_json="[$(tr ' ' ',' <<<"$fired")]"
  fi
  tmp="$(mktemp "$dir/.$kid.XXXXXX")"
  jq -n --arg kid "$kid" --arg day "$day" --arg state "$state" \
    --arg reason "$reason" --argjson remaining "$remaining" \
    --argjson grace "$grace" --argjson last "$last" \
    --argjson remainder "$remainder" --argjson fired "$fired_json" \
    --arg last_wall "$last_wall" --arg action "$action" \
    --arg action_reason "$action_reason" --arg action_result "$action_result" \
    --arg action_at "$action_at" \
    '{kid: $kid, logical_day: $day, last_wall: $last_wall, state: $state, reason: $reason,
      remaining_seconds: $remaining, grace_deadline: $grace, last_tick: $last,
      active_seconds_remainder: $remainder, warnings_fired: $fired,
      enforcement: {action: $action, reason: $action_reason, result: $action_result, at: $action_at}}' >"$tmp"
  chmod 0640 "$tmp"
  chown root:omarchy-kids "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$(time_state_file "$kid")"
}
