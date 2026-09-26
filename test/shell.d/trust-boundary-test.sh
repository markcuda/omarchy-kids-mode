#!/bin/bash
# The one rule this package cannot get wrong (SPEC.md I-3, R-SEC-2,
# R-FND-4; AGENTS.md "The trust boundary"): no environment variable, and
# nothing a kid can write, selects which code runs or whether a root
# check happens.
#
# A static test, deliberately: the 2026-09-03 round-two review's finding
# was not that one variable was wrong, it was that the *class* kept
# coming back -- `OMARCHY_KIDS_LIB` re-opened the hole that the
# `--socket` fix had just closed. So this walks every shipped file and
# fails on a new one, rather than testing one command's behaviour.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR" || exit 1

fail=0
ok() { echo "ok   $*"; }
bad() {
  echo "FAIL $*"
  fail=1
}

BASH_FILES=()
while IFS= read -r f; do BASH_FILES+=("$f"); done < <(
  grep -l '^#!/bin/bash' bin/omarchy-kids* 2>/dev/null
  printf '%s\n' lib/*.sh
)

# =====================================================================
# 1. The allowlist: every OMARCHY_KIDS_* variable bin/ or lib/ reads,
#    with one line saying why reading it cannot move a decision.
#    Anything not named here fails, including a brand new variable --
#    that is the point.
# =====================================================================
#
# Nothing below names a program, a library, a socket, or gates a root
# check. They are (a) scratch-tree prefixes for the data this package
# owns, which relocate *where it looks*, never *what it runs*, and which
# only ever hold root-written files; (b) an already-validated value the
# caller passes to a child it just started; (c) inputs a test drives.
ALLOWED=(
  # (a) scratch-tree prefixes -- data paths, never code paths.
  OMARCHY_KIDS_ROOT              # "/" prefix for the data tree a test owns
  OMARCHY_KIDS_ETC               # /etc/omarchy-kids: root-owned profiles
  OMARCHY_KIDS_SHARE             # /usr/share/omarchy-kids: package data
  OMARCHY_KIDS_RUN               # this session's own runtime dir
  OMARCHY_KIDS_RUN_DIR           # same, for omarchy-kids-session
  OMARCHY_KIDS_RUNTIME_DIR       # same, for omarchy-kids-super-tap
  OMARCHY_KIDS_RUN_USER_ROOT     # /run/user prefix (kid-owned; see §3.3 checks)
  OMARCHY_KIDS_RUN_USER_BASE     # same, for lib/data.sh
  OMARCHY_KIDS_HOME_ROOT         # home-dir prefix for a scratch tree
  OMARCHY_KIDS_HOMES_BASE        # /home prefix for lib/data.sh
  OMARCHY_KIDS_HOME              # the parent's own $HOME (omarchy-kids-bar)
  OMARCHY_KIDS_PROC_ROOT         # /proc prefix, read-only
  OMARCHY_KIDS_SDDM_DIR          # /etc/sddm.conf.d prefix
  OMARCHY_KIDS_HYPRLAND_DIR      # /etc/omarchy-kids/hyprland prefix
  OMARCHY_KIDS_SLOTS_FILE        # luks-slots path (root-only command)
  OMARCHY_KIDS_SETUP_LOG         # where the wizard writes its own log
  OMARCHY_KIDS_LAUNCHES_LOG      # the kid's own log, in their own runtime dir
  OMARCHY_KIDS_LAUNCHER_CONTROL  # the kid's own control file, same dir
  OMARCHY_KIDS_LAUNCHER_JSON     # the kid's own tile list, same dir
  OMARCHY_KIDS_PLUGIN_INDEX      # marketplace index path (root-only command)
  OMARCHY_KIDS_APPLICATIONS_DIRS # the .desktop search path for a kid's app surfaces (omarchy-kids-apps)
  OMARCHY_KIDS_LUKS_DEVICE       # which block device (root-only command)
  OMARCHY_KIDS_UKI               # which boot image to inspect (read-only check)
  OMARCHY_KIDS_UID_MAP           # test fixture for uid->account, root-only path
  # (b) values a command hands to the surface it is starting.
  OMARCHY_KIDS_ACCOUNT    # exported to a QML surface; never read back
  OMARCHY_KIDS_NAME       # display name, exported to a QML surface
  OMARCHY_KIDS_AVATAR     # avatar path, exported to a QML surface
  OMARCHY_KIDS_BAND       # display filter for the plugins shelf
  OMARCHY_KIDS_LEVEL      # exported for a QML surface's own label
  OMARCHY_KIDS_TOAST_TEXT # the text of a toast, exported to its QML
  OMARCHY_KIDS_TOAST_ICON # the glyph that fits a toast's own words, exported to its QML
  OMARCHY_KIDS_ASK_KIND   # the ask modal's own request fields, exported
  OMARCHY_KIDS_ASK_WHAT
  OMARCHY_KIDS_ASK_DESC
  OMARCHY_KIDS_ASK_MINUTES
  OMARCHY_KIDS_ASK_BIN # exported to the ask modal (never read by bin/)
  OMARCHY_KIDS_PARENT  # root-only argument to omarchy-kids-authd
  # (c) documented settings and test inputs that change no decision.
  OMARCHY_KIDS_NOW                   # a fixed clock, so tests need not wait
  OMARCHY_KIDS_TUI_ANSWERS           # scripted keystrokes for lib/tui.sh
  OMARCHY_KIDS_TUI_PLAIN             # no-colour rendering
  OMARCHY_KIDS_LAUNCHED_BY           # the .desktop entry; only ever turns preview OFF
  OMARCHY_KIDS_EXIT_WAIT             # seconds to wait for Hyprland
  OMARCHY_KIDS_WIFID_TIMEOUT         # socket timeout, seconds
  OMARCHY_KIDS_TIME_POLL_INTERVAL    # daemon poll interval, seconds
  OMARCHY_KIDS_TIME_DAEMON_ONESHOT   # run one poll instead of looping
  OMARCHY_KIDS_BLOCKED_SLEEP         # how long its placeholder pauses
  OMARCHY_KIDS_SUPER_TAP_WINDOW_MS   # the triple-tap window
  OMARCHY_KIDS_SUPER_TAP_NOW_MS      # a fixed clock for that window
  OMARCHY_KIDS_SESSION_START_NO_EXEC # print the exec line instead of exec'ing
  OMARCHY_KIDS_WEB_NO_EXEC           # print the argv instead of exec'ing Chromium
  OMARCHY_KIDS_TEST_ENV_DUMP         # dump the exported env for a test to read
  OMARCHY_KIDS_TEST_GETTY_STATE
  OMARCHY_KIDS_TEST_HYPRLAND_LOG
  OMARCHY_KIDS_TEST_HOME
  OMARCHY_KIDS_TEST_HOME_OPTS
  OMARCHY_KIDS_TEST_TMP_OPTS
)

is_allowed() {
  local name="$1" a
  for a in "${ALLOWED[@]}"; do [[ "$a" == "$name" ]] && return 0; done
  return 1
}

read_names=()
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  read_names+=("$name")
done < <(
  {
    # ${OMARCHY_KIDS_X...} in shell, os.environ.get("OMARCHY_KIDS_X") in python
    grep -rhoE '\$\{OMARCHY_KIDS_[A-Z0-9_]+' bin lib | sed 's/\${//'
    grep -rhoE 'environ[^)]*"OMARCHY_KIDS_[A-Z0-9_]+"' bin lib | grep -oE 'OMARCHY_KIDS_[A-Z0-9_]+'
    grep -rhoE 'getenv\("OMARCHY_KIDS_[A-Z0-9_]+"' bin lib | grep -oE 'OMARCHY_KIDS_[A-Z0-9_]+'
  } | sort -u
)

unlisted=0
for name in "${read_names[@]}"; do
  if ! is_allowed "$name"; then
    bad "trust boundary: bin/ or lib/ reads \$$name, which is not in this test's allowlist.
     If it genuinely cannot select code, a path a check reads, or a root
     check, add it above with a one-line why. Otherwise: delete it."
    unlisted=1
  fi
done
((unlisted == 0)) && ok "trust boundary: every OMARCHY_KIDS_* read in bin/ and lib/ is allowlisted (${#read_names[@]} names)"

# The OMARCHY_KIDS_* scan above also matches python (os.environ.get / getenv).
# A non-namespaced environment read is the same hazard under a plain name, and
# the only ones this package may make are systemd's socket-activation contract,
# read once and then popped (bin/omarchy-kids-authd and bin/omarchy-kids-wifid).
# A new one fails here.
PY_ALLOWED=(
  LISTEN_PID # sd_listen_fds: these are the systemd-activated daemons
  LISTEN_FDS # how many sockets systemd passed
  PATH       # lib/conf.py's desktop-argv; its only caller applies the executable fence
)
# Every python source the package ships, derived from its shebang (a hand-written
# list had the courier in and wifid out), plus lib/*.py.
PY_FILES=(lib/*.py)
while IFS= read -r f; do PY_FILES+=("$f"); done < <(
  grep -lE '^#!.*python' bin/omarchy-kids* 2>/dev/null
)
py_env_reads=()
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  py_env_reads+=("$name")
done < <(
  grep -rhoE 'os\.environ\[?"[A-Za-z_][A-Za-z0-9_]*"|os\.environ\.get\("[A-Za-z_][A-Za-z0-9_]*"|getenv\("[A-Za-z_][A-Za-z0-9_]*"' "${PY_FILES[@]}" 2>/dev/null |
    grep -oE '"[A-Za-z_][A-Za-z0-9_]*"' | tr -d '"' | sort -u
)
py_unlisted=0
for name in "${py_env_reads[@]}"; do
  [[ "$name" == OMARCHY_KIDS_* ]] && continue # covered and allowed above
  listed=0
  for a in "${PY_ALLOWED[@]}"; do [[ "$a" == "$name" ]] && listed=1; done
  if ((listed == 0)); then
    bad "trust boundary: the python side reads \$$name from the environment, which is not in PY_ALLOWED.
     If it cannot select code, a path a check reads, or a root check, add it
     above with a one-line why. Otherwise: delete it."
    py_unlisted=1
  fi
done
((py_unlisted == 0)) && ok "trust boundary: the python side's only environment reads are allowlisted (${#py_env_reads[@]} names)"

# Kid-facing commands have a stricter boundary: scratch path variables are
# root/test seams only, never safe inputs to a command a kid can run.
KID_COMMANDS=(
  bin/omarchy-kids-session bin/omarchy-kids-session-start bin/omarchy-kids-web
  bin/omarchy-kids-time bin/omarchy-kids-ask bin/omarchy-kids-wifi
  bin/omarchy-kids-launcher-ctl bin/omarchy-kids-blocked bin/omarchy-kids-super-tap
  bin/omarchy-kids-exit bin/omarchy-kids-theme
)
KID_PATH_VARS=(
  OMARCHY_KIDS_ROOT OMARCHY_KIDS_ETC OMARCHY_KIDS_SHARE OMARCHY_KIDS_RUN_DIR
  OMARCHY_KIDS_RUN OMARCHY_KIDS_RUNTIME_DIR OMARCHY_KIDS_RUN_USER_ROOT
  OMARCHY_KIDS_RUN_USER_BASE OMARCHY_KIDS_APPLICATIONS_DIRS
  OMARCHY_KIDS_LAUNCHES_LOG OMARCHY_KIDS_LAUNCHER_CONTROL
)
kid_path_reads=()
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  for path_name in "${KID_PATH_VARS[@]}"; do
    [[ "$name" == "$path_name" ]] && kid_path_reads+=("$name")
  done
done < <(
  grep -rhoE '\$\{OMARCHY_KIDS_[A-Z0-9_]+' "${KID_COMMANDS[@]}" lib/kids.sh lib/sock.sh lib/time.sh 2>/dev/null |
    sed 's/\${//' | sort -u
)
if ((${#kid_path_reads[@]})); then
  bad "trust boundary: a kid-facing command reads a runtime path variable: ${kid_path_reads[*]}"
else
  ok "trust boundary: kid-facing commands do not read runtime path variables"
fi

# An inherited scratch path must not redirect a real command's fixed paths.
hostile="$DIR/.trust-boundary-hostile"
if hostile_out="$(OMARCHY_KIDS_ETC="$hostile" OMARCHY_KIDS_SHARE="$hostile" \
  OMARCHY_KIDS_ROOT="$hostile" OMARCHY_KIDS_RUN="$hostile" \
  "$DIR/bin/omarchy-kids-session" --help 2>&1)" &&
  [[ "$hostile_out" == *"/etc/omarchy-kids"* ]] &&
  [[ "$hostile_out" == *"/usr/share/omarchy-kids"* ]] &&
  [[ "$hostile_out" != *"$hostile"* ]]; then
  ok "trust boundary: session ignores hostile inherited path variables"
else
  bad "trust boundary: session accepted a hostile inherited path variable"
fi

# A kid-writable manifest under the inherited ETC path must not be the file
# that --manifest reads; the command's compiled ETC path remains authoritative.
manifest_hostile_dir="$(mktemp -d)"
trap 'rm -rf "$manifest_hostile_dir"' EXIT
mkdir -p "$manifest_hostile_dir/sessions"
printf '%s\n' 'KID_WRITABLE_MANIFEST_MARKER' >"$manifest_hostile_dir/sessions/$(id -un).json"
if manifest_out="$(OMARCHY_KIDS_ETC="$manifest_hostile_dir" \
  "$DIR/bin/omarchy-kids-session" --manifest 2>"$manifest_hostile_dir/error")"; then
  bad "trust boundary: --manifest accepted OMARCHY_KIDS_ETC"
elif [[ -n "$manifest_out" || "$(cat "$manifest_hostile_dir/error")" == *KID_WRITABLE_MANIFEST_MARKER* ||
"$(cat "$manifest_hostile_dir/error")" == *"$manifest_hostile_dir"* ]]; then
  bad "trust boundary: --manifest read or disclosed the kid-writable hostile manifest"
else
  ok "trust boundary: --manifest ignores OMARCHY_KIDS_ETC and kid-writable manifests"
fi

# =====================================================================
# 2. Shapes that are never allowed, whatever the allowlist says: a
#    variable that could name a program, a library, a socket, or gate a
#    root check.
# =====================================================================
banned_shapes='\$\{OMARCHY_KIDS_[A-Z0-9_]*(_BIN|_PY|_LIB|_SOCK|_SOCKET|_CMD|REQUIRE_ROOT)[:}]'
if hits="$(grep -rnE "$banned_shapes" bin lib 2>/dev/null)"; then
  bad "trust boundary: an environment variable that names a program, a library, a socket, or gates a root check:"
  printf '     %s\n' "$hits"
else
  ok "trust boundary: no *_BIN / *_PY / *_LIB / *_SOCK / *REQUIRE_ROOT environment read in bin/ or lib/"
fi

# The specific one that caused this: every command resolves lib/ from its
# own resolved path, never from the environment (review §2.1).
missing_resolver=()
for f in "${BASH_FILES[@]}"; do
  [[ "$f" == lib/* ]] && continue
  grep -q '^LIB=' "$f" || continue
  grep -q '^LIB="\$DIR/lib"' "$f" || missing_resolver+=("$f")
  grep -q 'readlink -f "\${BASH_SOURCE\[0\]}"' "$f" ||
    missing_resolver+=("$f (DIR is not readlink -f \"\$0\")")
done
if ((${#missing_resolver[@]})); then
  bad "trust boundary: these resolve lib/ from something other than their own resolved path:"
  printf '     %s\n' "${missing_resolver[@]}"
else
  ok "trust boundary: every command resolves lib/ from readlink -f \"\$0\", else the installed prefix"
fi

if grep -qx 'BOOT_MODE_MACHINE_CONF=/etc/omarchy-kids/machine.conf' lib/boot-mode.sh &&
  grep -qx 'BOOT_MODE_LOCK=/run/omarchy-kids/boot-mode.lock' lib/boot-mode.sh &&
  ! grep -q '^BOOT_MODE_ETC=' lib/boot-mode.sh &&
  ! grep -q 'OMARCHY_KIDS_' lib/boot-mode.sh; then
  ok "trust boundary: boot-mode reads machine.conf and locks transitions at fixed build-time paths"
else
  bad "trust boundary: boot-mode has an environment-selected authority or lock path"
fi

# =====================================================================
# 3. One root check, and it reads nothing but the kernel's answer.
# =====================================================================
if hits="$(grep -rn 'id -u' bin lib --include='omarchy-kids*' --include='*.sh' |
  grep -vE 'id -u "|id -u \$|command id -u|is_root|data_kid_uid|# ' |
  grep -E '(!=|==) *"?0')"; then
  bad "trust boundary: a hand-rolled root check outside lib/kids.sh's is_root:"
  printf '     %s\n' "$hits"
else
  ok "trust boundary: every root check goes through lib/kids.sh's is_root"
fi

# =====================================================================
# 4. The compositor config a kid's session runs under decides nothing
#    from that session's own environment (review §3.5).
# =====================================================================
if hits="$(grep -nE '(package\.path|dofile|require)[^\n]*os\.getenv' share/hyprland/*.lua 2>/dev/null)"; then
  bad "trust boundary: a level config loads code from a path the session's environment sets:"
  printf '     %s\n' "$hits"
else
  ok "trust boundary: share/hyprland/L*.lua load Lua from fixed paths only"
fi

# =====================================================================
# 5. Root never follows a kid-controlled path (review §3.3).
# =====================================================================
if grep -q 'O_NOFOLLOW' lib/data.py && grep -q 'st_uid' lib/data.py; then
  ok "trust boundary: lib/data.py's fold opens the kid's log O_NOFOLLOW and checks its owner"
else
  bad "trust boundary: lib/data.py's fold-launches lost its O_NOFOLLOW/owner check"
fi
if grep -qE 'tail -c .*\$src' lib/data.sh; then
  bad "trust boundary: lib/data.sh reads the kid's runtime log through the shell again (follows symlinks)"
else
  ok "trust boundary: no shell read of the kid's runtime log"
fi

# Root enforcement is named once here (AGENTS.md: one table, never a second list
# that can drift): the lock, the ledger, the assert, the two parent paths that
# write the ledger or finish a session, and the ways to end one without naming
# those (systemctl, pkill/killall, and logind over D-Bus rather than loginctl).
# The finish pair is added for every surface except the exit modal, which runs it
# after the parent authenticates. The dispatcher spelling (`hyprctl dispatch ...`)
# is checked separately below, because it is the one shape that can wrap a line.
overlay_root_re='loginctl|omarchy-kids-time-ledger|omarchy-kids-assert|omarchy-kids-time grant|omarchy-kids-bar end|systemctl|pkill|killall|busctl|gdbus|qdbus|dbus-send|login1'
overlay_finish_re='omarchy-kids-exit|--finish'

# The dispatcher spelling can span lines (a wrapped QML array) and carries the
# `hl.dsp.` prefix the exit command actually uses, so it is matched against the
# file with newlines removed and a prefix-tolerant pattern: `hl.dsp.exit` trips
# it, the launcher's `hl.dsp.focus` does not.
overlay_dispatch_re='dispatch[^[:alpha:]]*([[:alpha:]_]+\.)*exit'

# The kid time display path -- the daemon and every overlay helper it runs --
# may show root's decision, but it must not make one. cmd_status and cmd_grant
# are deliberately outside this range: one is the kid-side read, the other the
# parent path, and both legitimately touch the ledger.
#
# One entry is a state-file field, not a function: `remaining_seconds` is a
# legitimate display read *if* the daemon ever shows "N minutes left" from it,
# so revisit this list rather than dropping the entry. Today the daemon shows
# only what `state`/`warnings_fired` say.
if hits="$(sed -n '/^show_toast()/,/^}/p;/^show_timesup()/,/^}/p;/^dismiss_timesup()/,/^}/p;/^warning_label()/,/^}/p;/^cmd_daemon()/,/^}/p' bin/omarchy-kids-time |
  grep -nE "time_remaining_minutes|time_next_boundary|time_warning_thresholds|time_is_lights_out|time_budget_minutes|time_lights_out|time_used_minutes|time_granted_minutes|remaining_seconds|$overlay_root_re|$overlay_finish_re" || true)" &&
  [[ -n "$hits" ]]; then
  bad "trust boundary: kid time display still contains policy or finish capability:"
  printf '     %s\n' "$hits"
else
  ok "trust boundary: kid time display has no policy transition or finish capability"
fi
if grep -q 'time_state_read' bin/omarchy-kids-time &&
  grep -q 'grace_deadline' share/time/timesup.qml &&
  grep -q 'omarchy-kids-ask' share/time/timesup.qml; then
  ok "trust boundary: kid time display reads root state and keeps the ask action"
else
  bad "trust boundary: kid time display lost root state or ask wiring"
fi
# No overlay a kid's session can show may reach root enforcement. Every QML or JS
# file under share/ is checked except the surfaces this repository does not own
# for a kid session: the parent's bar widget and the SDDM portal. The file list
# is enumerated, not hand-written, so a *new* overlay is checked from the day it
# lands. Nothing in the suite executes QML, so this textual check is the only
# guard on what these files run.
overlay_hits=""
while IFS= read -r q; do
  [[ "$q" =~ ^share/(bar|sddm-theme)/ ]] && continue
  if [[ ! -f "$q" ]]; then
    overlay_hits+="$q: missing"$'\n'
    continue
  fi
  re="$overlay_root_re"
  [[ "$q" == share/exit-modal/* ]] || re="$re|$overlay_finish_re"
  hits="$(grep -nE "$re" "$q" || true)"
  [[ -n "$hits" ]] && overlay_hits+="$q: $hits"$'\n'
  if grep -qE "$overlay_dispatch_re" <(tr -d '\n' <"$q"); then
    overlay_hits+="$q: dispatch ... exit"$'\n'
  fi
done < <(find share -name '*.qml' -o -name '*.js' | sort)
if [[ -n "$overlay_hits" ]]; then
  bad "trust boundary: a kid overlay names a root enforcement command:"
  printf '%s\n' "$overlay_hits" | sed 's/^/     /'
else
  ok "trust boundary: no kid overlay names the named enforcement commands (the exit modal may finish)"
fi

# The two display-only time overlays are stricter still: their only legitimate
# process use is the one ask call in timesup.qml, so any Process block or extra
# execDetached in either file is a change worth failing on -- a count, not a
# name, which is what the table above cannot express. Nothing in the suite
# executes QML, so the structure is asserted textually. time-test.sh carries a
# narrower duplicate for the finish command alone.
overlay_hits=""
for q in share/time/toast.qml share/time/timesup.qml; do
  if [[ ! -f "$q" ]]; then
    overlay_hits+="$q: missing"$'\n'
    continue
  fi
  hits="$(grep -nE "$overlay_root_re|$overlay_finish_re|Process[[:space:]]*\{" "$q" || true)"
  [[ -n "$hits" ]] && overlay_hits+="$q: $hits"$'\n'
done
toast_detach="$(grep -c 'execDetached' share/time/toast.qml || true)"
timesup_detach="$(grep -c 'execDetached' share/time/timesup.qml || true)"
if [[ "$toast_detach" != 0 ]]; then
  overlay_hits+="share/time/toast.qml: $toast_detach execDetached call(s)"$'\n'
fi
if [[ "$timesup_detach" != 1 ]] || ! grep -q 'omarchy-kids-ask' share/time/timesup.qml; then
  overlay_hits+="share/time/timesup.qml: expected exactly one execDetached, of omarchy-kids-ask"$'\n'
fi
if [[ -n "$overlay_hits" ]]; then
  bad "trust boundary: a kid time overlay enforces, launches, or is missing:"
  printf '     %s' "$overlay_hits"
else
  ok "trust boundary: the kid time overlays never enforce and keep only the ask call"
fi

# The pidfile helpers the kid overlays use (lib/kids.sh's modal_* functions) get
# the same names check. They are extracted per function, not by a line range: the
# units array just below them names the assert *service*, which is not kid-side
# enforcement and would false-fail. A function that has gone missing is a failure,
# not a silent pass.
modal_bodies="$(awk '
  /^modal_[a-z0-9_]*\(\)/ {
    if ($0 ~ /\}[[:space:]]*$/) { print FNR": "$0; next }
    inm = 1
  }
  inm { print FNR": "$0 }
  inm && /^}/ { inm = 0 }
' lib/kids.sh)"
missing_modal=""
for fn in modal_already_open modal_write_pid modal_close; do
  grep -q ": $fn(" <<<"$modal_bodies" || missing_modal+=" $fn"
done
if [[ -n "$missing_modal" ]]; then
  bad "trust boundary: lib/kids.sh's modal_* helpers moved (missing:$missing_modal); this guard cannot find them"
else
  hits="$(grep -E "$overlay_root_re|$overlay_finish_re" <<<"$modal_bodies" || true)"
  if [[ -n "$hits" ]]; then
    bad "trust boundary: a kid overlay pidfile helper names an enforcement command (lib/kids.sh line):"
    printf '%s\n' "$hits" | sed 's/^/     /'
  else
    ok "trust boundary: the kid overlay pidfile helpers name no enforcement command"
  fi
fi

# =====================================================================
# 6. Every command's shipped interpreter is absolute. A repo copy of a
#    python command says `#!/usr/bin/env python3` so a dev checkout
#    runs; the PKGBUILD must rewrite exactly those to /usr/bin/python3,
#    the same build-time seam KIDS_PY uses -- a direct exec of the
#    packaged copy must not resolve its interpreter through $PATH.
#    This is also the table's own check: a new python command that the
#    PKGBUILD does not name fails here.
# =====================================================================

py_bins=()
shebang_ok=1
for f in bin/omarchy-kids*; do
  case "$(head -1 "$f")" in
    '#!/bin/bash') ;;
    '#!/usr/bin/env python3') py_bins+=("$f") ;;
    *)
      bad "unexpected shebang in $f: $(head -1 "$f")"
      shebang_ok=0
      ;;
  esac
done
((shebang_ok)) && ok "trust boundary: every bin/omarchy-kids-* shebang is bash or the python dev form"
if ((${#py_bins[@]})); then
  # Only the loop line itself: a wider range would sweep in other commands named
  # nearby and quietly accept a python command the loop does not rewrite.
  py_in_pkgbuild=()
  while IFS= read -r name; do
    [[ -n "$name" ]] && py_in_pkgbuild+=("$(basename "$name")")
    # `[[:blank:]]*`, not `^\t`: in an ERE `\t` is a literal `t` to GNU grep (it
    # warns "stray \ before t" and matches nothing), so this check failed on every
    # real Arch box while passing on BSD grep. Caught by running the suite on the
    # target platform, 2026-09-25.
  done < <(grep -E '^[[:blank:]]*for py in .*; do$' "$DIR/PKGBUILD" | grep -oE 'omarchy-kids-[a-z-]+')
  same=1
  for f in "${py_bins[@]}"; do
    base="$(basename "$f")"
    named=0
    for n in ${py_in_pkgbuild[@]+"${py_in_pkgbuild[@]}"}; do
      [[ "$n" == "$base" ]] && named=1
    done
    ((named)) || {
      bad "PKGBUILD does not rewrite the shebang of $base"
      same=0
    }
  done
  # ... and the other direction: nothing else may be in that list, or "exactly"
  # below would be false.
  for n in ${py_in_pkgbuild[@]+"${py_in_pkgbuild[@]}"}; do
    is_py=0
    for f in "${py_bins[@]}"; do
      [[ "$(basename "$f")" == "$n" ]] && is_py=1
    done
    ((is_py)) || {
      bad "the PKGBUILD rewrites $n's shebang, but it is not a python command"
      same=0
    }
  done
  ((same)) && ok "trust boundary: the PKGBUILD rewrites exactly the $((${#py_bins[@]})) python command(s) the repo ships"
  if grep -Fq "s|^#!/usr/bin/env python3\$|#!/usr/bin/python3|" "$DIR/PKGBUILD" &&
    grep -Fq "grep -q '^#!/usr/bin/python3\$' \"\$py\"" "$DIR/PKGBUILD"; then
    ok "trust boundary: the python shebang rewrite and its guard are in the PKGBUILD"
  else
    bad "the PKGBUILD does not rewrite the python shebang to an absolute path"
  fi
else
  bad "no python command carries the dev shebang -- the PKGBUILD rewrite has nothing to rewrite"
fi

echo "trust-boundary-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit $fail
