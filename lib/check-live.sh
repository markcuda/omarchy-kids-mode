# shellcheck shell=bash
# lib/check-live.sh — omarchy-kids-check's --live section. Sourced by the
# dispatcher; not meant to be executed directly. docs/check.md.

# kid_uid ACCOUNT — resolved via getent, never assumed 1000.
kid_uid() {
  command -v getent >/dev/null 2>&1 || return 0
  getent passwd "$1" 2>/dev/null | cut -d: -f3
}

# live_session_leader_pid ACCOUNT — ACCOUNT's live session leader pid
# (loginctl's Leader=), or nothing + return 1. docs/check.md's "Live tests".
live_session_leader_pid() {
  local acct="$1" list sess uid user _rest leader
  command -v loginctl >/dev/null 2>&1 || return 1
  list="$(loginctl --no-legend list-sessions 2>/dev/null || true)"
  [[ -n "$list" ]] || return 1
  while read -r sess uid user _rest; do
    [[ -n "$sess" && "$user" == "$acct" ]] || continue
    leader="$(loginctl show-session "$sess" -p Leader --value 2>/dev/null || true)"
    if [[ -n "$leader" && "$leader" != 0 ]]; then
      printf '%s' "$leader"
      return 0
    fi
  done <<<"$list"
  return 1
}

# mountinfo_noexec FILE MOUNTPOINT — "noexec"/"exec" for the last mount at
# MOUNTPOINT in a mountinfo(5)-shaped FILE, checking both option fields.
mountinfo_noexec() {
  local file="$1" mountpoint="$2"
  [[ -r "$file" ]] || return 0
  awk -v mp="$mountpoint" '
        {
            sep = 0
            for (i = 1; i <= NF; i++) { if ($i == "-") { sep = i; break } }
            if (sep == 0 || $5 != mp) next
            fstype = $(sep + 1)
            opts = $6 "," $(sep + 3)
            if (fstype == "tmpfs" && opts ~ /(^|,)noexec(,|$)/) { result = "noexec" }
            else { result = "exec" }
        }
        END { if (result != "") print result }
    ' "$file"
}

# live_test_tmpfs_noexec ACCOUNT — reads the live session leader's own
# mountinfo, else falls back to the last session-check log, else WARN.
# Not proven through runuser: see docs/check.md's "Live tests" for why.
live_test_tmpfs_noexec() {
  local acct="$1" pid mountinfo tmp_r shm_r uid logf line detail

  # "No session" is an answer, not a failure: live_session_leader_pid returns 1
  # for it, and an assignment inherits that status, so without `|| true` the
  # caller's `set -e` ended the whole report before it rendered (issue #7).
  pid="$(live_session_leader_pid "$acct")" || true
  if [[ -n "$pid" ]]; then
    mountinfo="$PROC_ROOT/$pid/mountinfo"
    if [[ -r "$mountinfo" ]]; then
      tmp_r="$(mountinfo_noexec "$mountinfo" /tmp)"
      shm_r="$(mountinfo_noexec "$mountinfo" /dev/shm)"
      if [[ "$tmp_r" == "noexec" ]]; then
        add_result "Live tests" "live:$acct:tmp-noexec" pass "$acct: /tmp is a private noexec tmpfs in their live session (session leader pid $pid's own mountinfo, R-FND-2a)"
      else
        add_result "Live tests" "live:$acct:tmp-noexec" fail "$acct: /tmp is NOT a private noexec tmpfs in their live session (session leader pid $pid's mountinfo: ${tmp_r:-no tmpfs mounted there at all}) (R-FND-2a)"
      fi
      if [[ "$shm_r" == "noexec" ]]; then
        add_result "Live tests" "live:$acct:shm-noexec" pass "$acct: /dev/shm is a private noexec tmpfs in their live session (session leader pid $pid's own mountinfo, R-FND-2a)"
      else
        add_result "Live tests" "live:$acct:shm-noexec" fail "$acct: /dev/shm is NOT a private noexec tmpfs in their live session (session leader pid $pid's mountinfo: ${shm_r:-no tmpfs mounted there at all}) (R-FND-2a)"
      fi
      return
    fi
    # mountinfo unreadable right now -- fall through to the log.
  fi

  uid="$(kid_uid "$acct")"
  if [[ -n "$uid" ]]; then
    logf="$(posture_root)/run/user/$uid/omarchy-kids/session-$uid.log"
    if [[ -r "$logf" ]]; then
      # grep with no match returns 1; pipefail then makes the assignment carry
      # that status, which the caller's `set -e` would end the report on. A log
      # with no tmp_noexec line is the case this branch exists to report.
      line="$(grep 'check=tmp_noexec ' "$logf" 2>/dev/null | tail -n1)" || true
      if [[ -n "$line" ]]; then
        detail="${line#*detail=}"
        case "$line" in
          *result=PASS*)
            add_result "Live tests" "live:$acct:tmp-noexec" pass "$acct: no live session to inspect right now; their last 'omarchy-kids-session --check' log ($logf) recorded PASS for tmp_noexec: $detail"
            ;;
          *result=WARN*)
            add_result "Live tests" "live:$acct:tmp-noexec" warn "$acct: no live session to inspect right now; their last 'omarchy-kids-session --check' log ($logf) recorded WARN for tmp_noexec: $detail"
            ;;
          *)
            add_result "Live tests" "live:$acct:tmp-noexec" warn "$acct: no live session to inspect, and their last session log's tmp_noexec line ($logf) doesn't parse as PASS or WARN"
            ;;
        esac
        add_result "Live tests" "live:$acct:shm-noexec" skip "$acct: no live session to inspect; the session log only ever records tmp_noexec, not /dev/shm (see live:$acct:tmp-noexec)"
        return
      fi
    fi
  fi

  add_result "Live tests" "live:$acct:tmp-noexec" warn "$acct: no live session to inspect right now, and no 'omarchy-kids-session --check' log to fall back on -- have $acct log in, then from a grown-up's terminal run: loginctl list-sessions (find their session), then as $acct: omarchy-kids-session --check"
  add_result "Live tests" "live:$acct:shm-noexec" skip "$acct: no live session or session log to inspect (see live:$acct:tmp-noexec)"
}

# live_test_pkcheck ACCOUNT ACTION LABEL — same proof method
# bin/omarchy-kids-session's check_polkit uses at real login (docs/check.md).
live_test_pkcheck() {
  local acct="$1" action="$2" label="$3" out
  # pkcheck exits non-zero for "not authorized" -- the answer we want --
  # so never let the assignment's status reach omarchy-kids-check's set -e.
  out="$(runuser -u "$acct" -- bash -c 'pkcheck --action-id "$1" --process "$$" 2>&1' _ "$action")" || true
  case "$out" in
    *"Not authorized"* | *"not authorized"*)
      add_result "Live tests" "live:$acct:pkcheck-$label" pass "$acct: polkit refuses $action outright (R-FND-4)"
      ;;
    *"requires authentication"* | *"Authorization requires"*)
      add_result "Live tests" "live:$acct:pkcheck-$label" fail "$acct: polkit would PROMPT for $action instead of refusing it — the deny rule isn't active (R-FND-4)"
      ;;
    "")
      add_result "Live tests" "live:$acct:pkcheck-$label" fail "$acct: polkit AUTHORIZED $action — the deny rule isn't active (R-FND-4)"
      ;;
    *)
      add_result "Live tests" "live:$acct:pkcheck-$label" warn "$acct: unexpected pkcheck answer for $action: ${out%%$'\n'*}"
      ;;
  esac
}

live_test_kid() {
  local acct="$1" out rc

  if runuser -u "$acct" -- sudo -n true >/dev/null 2>&1; then
    add_result "Live tests" "live:$acct:sudo" fail "$acct: 'sudo -n true' SUCCEEDED — $acct has passwordless sudo (R-FND-3)"
  else
    add_result "Live tests" "live:$acct:sudo" pass "$acct: 'sudo -n true' is refused (R-FND-3)"
  fi

  live_test_pkcheck "$acct" org.freedesktop.NetworkManager.settings.modify.system networkmanager-settings
  live_test_pkcheck "$acct" org.freedesktop.systemd1.manage-units systemd-manage-units

  live_test_tmpfs_noexec "$acct"

  # A refused exec is the pass here, so capture rc without set -e seeing it.
  rc=0
  out="$(runuser -u "$acct" -- bash -c 'f="$HOME/.omarchy-kids-check-live-$$"; printf "#!/bin/sh\necho pwned\n" > "$f" && chmod +x "$f" && "$f"; rc=$?; rm -f "$f"; exit $rc' 2>&1)" || rc=$?
  if [[ "$rc" != 0 && ("$out" == *"Permission denied"* || "$rc" == 126) ]]; then
    add_result "Live tests" "live:$acct:home-noexec-run" pass "$acct: running a freshly-written executable in \$HOME fails (Permission denied) (R-FND-2)"
  elif [[ "$rc" == 0 ]]; then
    add_result "Live tests" "live:$acct:home-noexec-run" fail "$acct: a downloaded/self-written executable in \$HOME actually RAN (R-FND-2)"
  else
    add_result "Live tests" "live:$acct:home-noexec-run" warn "$acct: could not run the live exec test cleanly (rc=$rc, output: ${out:-none}) — inconclusive, not a pass"
  fi
}

run_live_section() {
  if [[ "$LIVE" != 1 ]]; then
    add_result "Live tests" "live:skipped" skip "not run — pass --live (as root) to spawn a short session as each kid and confirm sudo/polkit/tmp/exec are actually denied"
    return
  fi
  if [[ "$EUID" != 0 ]]; then
    add_result "Live tests" "live:skipped" warn "--live was passed but this isn't root — live tests need root to runuser as each kid"
    return
  fi
  local acct any=0
  while IFS= read -r acct; do
    [[ -n "$acct" ]] || continue
    any=1
    live_test_kid "$acct"
  done < <(kids_list "$KIDS_DIR")
  [[ "$any" == 1 ]] || add_result "Live tests" "live:none" skip "no kids provisioned; nothing to test"
}
