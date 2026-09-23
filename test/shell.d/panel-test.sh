#!/bin/bash
# Tests bin/omarchy-kids-panel (SPEC.md R-WIZ-7, R-WIZ-8, R-ASK-2,
# R-TIME-4/5, R-FND-6; issue #21). Drives every screen through
# OMARCHY_KIDS_TUI_ANSWERS, same convention as test/shell.d/wizard-test.sh.
#
# Two kinds of check here:
#
#   - dry-run (the default): asserts the exact "[dry-run] sudo ..." line
#     the panel itself prints for a write, same style as
#     wizard-test.sh's own checks -- no stub PATH needed for these, since
#     DRY_RUN=1 never reaches a real command.
#   - real mode (--apply): a pass-through `sudo` fake (same shape as
#     wizard-test.sh's RM_STUBS/sudo) plus a "spy" wrapper around each of
#     omarchy-kids-conf/-time/-ask/-apps/-web/-provision that logs its own
#     argv to $ARGV_LOG and then runs the *real* command against this
#     file's own scratch OMARCHY_KIDS_ETC/SHARE/ROOT trees -- so these
#     checks prove both the exact command AND that it actually did the
#     right thing (a budget that's really changed, an app that's really
#     hidden, a request that's really approved). omarchy-kids-provision's
#     spy is the one exception: `remove` is faked (logged, not really
#     run) rather than dragging in provision-test.sh's whole
#     useradd/cryptsetup/mount stub environment for a check that's really
#     about the panel's own wiring, not provision's own correctness
#     (that's provision-test.sh's job).
#
# One provisioned kid throughout: kid-ada, band 6-8 (AGENTS.md rule 9).
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
BIN="" # a copy in a scratch tree: the panel resolves every sibling
# command beside itself now, so the fakes are placed there.

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP panel-test.sh: python3 not found (needed by omarchy-kids-conf/-ask)"
  exit 0
fi

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in '$1')"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want to find '$2' in '$1')"; fi
}
check_status() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want exit $2, got $1)"; fi
}

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ETC="$TMP/etc"
SHARE="$TMP/share"
ROOT="$TMP/root" # OMARCHY_KIDS_ROOT
STUBS="$TMP/stubs"
ROOT_ID_STUBS="$TMP/root-stubs"
ARGV_LOG="$TMP/argv.log"
QUEUE_DIR="$ROOT/var/lib/omarchy-kids/queue"

mkdir -p "$ETC/kids" "$SHARE/bands" "$SHARE/packs" "$SHARE/avatars" "$STUBS" "$ROOT_ID_STUBS" "$QUEUE_DIR"
cp "$ROOT_DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$ROOT_DIR"/share/packs/*.toml "$SHARE/packs/"
: >"$ARGV_LOG"

# The panel under test lives in a scratch tree so the spies below can sit
# beside it; the first section runs against a plain copy, with no fakes.
kids_tree "$TMP/tree" "$ROOT_DIR"
BIN="$TMP/tree/bin/omarchy-kids-panel"
# The commands the panel prints are resolved from its own `readlink -f`,
# so the expected paths are the resolved ones (on macOS /var is a symlink).
TREE_BIN="$(cd "$TMP/tree/bin" && pwd -P)"

# The kid-facing helpers have fixed paths; give the panel's real spies their
# own copied tree so this test never relies on a runtime path override.
kids_tree "$TMP/real-tree" "$ROOT_DIR"
for helper_tree in "$TMP/tree" "$TMP/real-tree"; do
  for helper in ask time; do
    kids_set_const "$helper_tree/bin/omarchy-kids-$helper" ETC "$ETC"
    kids_set_const "$helper_tree/bin/omarchy-kids-$helper" SHARE "$SHARE"
    kids_set_const "$helper_tree/bin/omarchy-kids-$helper" SYSROOT "$ROOT"
    kids_set_const "$helper_tree/bin/omarchy-kids-$helper" RUN "$ROOT/run/user/$(id -u)/omarchy-kids"
  done
done

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada
avatar=fox
band=6-8
EOF

answers_file() { # writes $@ (one per line) to a fresh file, prints its path
  local f="$TMP/answers.$RANDOM"
  printf '%s\n' "$@" >"$f"
  printf '%s' "$f"
}

# run_panel ANSWERS_FILE [FLAGS...] -> stdout+stderr in $out, exit in
# $PANEL_STATUS. The answers-file harness has no terminal, so the panel's
# own default here is a preview; every call below says which it wants.
run_panel() {
  local answers="$1"
  shift
  out="$(OMARCHY_KIDS_TUI_ANSWERS="$answers" "$BIN" "$@" 2>&1)"
  PANEL_STATUS=$?
}

# --- dry-run: exact "[dry-run] sudo ..." lines, nothing on PATH stubbed
# beyond the real helper binaries beside this script (no writes ever
# actually run in this mode) ------------------------------------------

# issue #53: a scratch system themes dir for the Desktop screen's theme
# picker (screen_kid_theme's own theme_list_installed).
OMARCHY_PATH="$TMP/omarchy"
mkdir -p "$OMARCHY_PATH/themes/tokyo-night" "$OMARCHY_PATH/themes/catppuccin-latte"

export OMARCHY_KIDS_ETC="$ETC" OMARCHY_KIDS_SHARE="$SHARE" OMARCHY_KIDS_ROOT="$ROOT" OMARCHY_PATH

answers="$(answers_file "kid:kid-ada" time grant 15 back back quit)"
run_panel "$answers" --dry-run
check_status "$PANEL_STATUS" 0 "dry-run grant exits 0"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-time grant kid-ada 15" \
  "dry-run: 'give more minutes' prints the exact grant command"

answers="$(answers_file "kid:kid-ada" time budget 45 back back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-conf set kid-ada budget_min 45" \
  "dry-run: changing the budget prints the exact conf-set command"
check_contains "$out" "Preview only — nothing was changed" \
  "dry-run: the next card carries the write's preview notice"

answers="$(answers_file "kid:kid-ada" apps gcompris back back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-apps hide kid-ada gcompris" \
  "dry-run: hiding an app prints the exact hide command"

# issue #53: the Desktop screen's two rows, level and theme.
answers="$(answers_file "kid:kid-ada" desktop level 1 back back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-conf set kid-ada level 1" \
  "dry-run: Desktop -> Desktop level prints the exact conf-set command"

answers="$(answers_file "kid:kid-ada" desktop theme catppuccin-latte back back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-conf set kid-ada theme catppuccin-latte" \
  "dry-run: Desktop -> Theme prints the exact conf-set command"

# R-WIZ-8's "every setting": weekend limits, Wi-Fi mode, reset to defaults.
answers="$(answers_file "kid:kid-ada" time budget_we 90 back back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-conf set kid-ada budget_min_weekend 90" \
  "dry-run: weekend budget prints the exact conf-set command"

answers="$(answers_file "kid:kid-ada" time lights_we 20:00 back back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-conf set kid-ada lights_out_weekend 20:00" \
  "dry-run: weekend lights-out prints the exact conf-set command"

answers="$(answers_file "kid:kid-ada" wifi helper back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-conf set kid-ada wifi helper" \
  "dry-run: Wi-Fi mode prints the exact conf-set command"
check_not_contains "$out" "does not match" \
  "dry-run: the Wi-Fi answer script is consumed exactly"

answers="$(answers_file "kid:kid-ada" reset reset back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-conf reset kid-ada" \
  "dry-run: reset to defaults prints the exact conf-reset command"

answers="$(answers_file "kid:kid-ada" remove NotAda back quit)"
run_panel "$answers"
check_not_contains "$out" "omarchy-kids-provision remove" \
  "dry-run: a wrong confirmation name never even prints a remove command"
check_contains "$out" "didn't match" "dry-run: a wrong confirmation name says so"

answers="$(answers_file "kid:kid-ada" remove Ada back quit)"
run_panel "$answers"
check_contains "$out" "sudo $TREE_BIN/omarchy-kids-provision remove kid-ada --apply" \
  "dry-run: the right confirmation name prints the exact remove command"

answers="$(answers_file quit)"
run_panel "$answers"
check_status "$PANEL_STATUS" 0 "Home alone: 'quit' exits 0"
check_contains "$out" "Ada · 6-8" "Home lists the one provisioned kid"
check_contains "$out" "Add a kid" "Home offers Add a kid"
check_contains "$out" "Machine safety" "Home offers the Machine safety row"
check_contains "$out" "Notifications" "Home offers the Notifications row"
check_contains "$out" "Requests (0)" "Home shows the open-request count"
check_contains "$out" "Remove Kids Mode" "Home offers the Remove Kids Mode row"

# review §3.1: a screen's facts are its own card body now, so they belong
# between that screen's header and its own first row. Echoed above the
# screen instead -- fine here, since file mode never clears -- they left a
# header line sitting between the facts and the rows, and on a real
# terminal the clear took them. facts_in_screen FACTS NTH ROW LABEL looks
# for that header line, matching loosely on purpose: where gum is really
# installed (the vm, not the mac) the header is drawn inside a border.
facts_in_screen() {
  local facts="$1" nth="$2" row="$3" label="$4" verdict
  verdict="$(awk -v facts="$facts" -v nth="$nth" -v row="$row" '
        index($0, facts) && !seen { if (++n == nth) { seen = 1; next } }
        seen && !done && index($0, "Kids Mode") { verdict = "a header sits between the facts and the rows"; done = 1 }
        seen && !done && index($0, row) { verdict = "ok"; done = 1 }
        END {
            if (!seen) verdict = "the facts line never rendered"
            else if (!done) verdict = "no row rendered after the facts"
            print verdict
        }' <<<"$out")"
  if [[ "$verdict" == ok ]]; then pass "$label"; else fail "$label ($verdict)"; fi
}

answers="$(answers_file "kid:kid-ada" back quit)"
run_panel "$answers"
check_contains "$out" "Ada — band 6-8" "the Kid screen shows the kid's name and band"
check_contains "$out" "Open requests: 0" "the Kid screen shows the open-request count"
facts_in_screen "Ada — band 6-8" 1 "1) Screen time" \
  "the Kid screen's facts are its own screen body, above its rows"

# The screen-time screen's status lines are its body too. Its own copy of
# `omarchy-kids-time status` is the second: the Kid screen shows one first.
answers="$(answers_file "kid:kid-ada" time back back quit)"
run_panel "$answers"
facts_in_screen "min used" 2 "1) Give more minutes today" \
  "Screen time's status lines are its own screen body, above its rows"

answers="$(answers_file "@esc")"
run_panel "$answers"
check_status "$PANEL_STATUS" 0 "Home: Esc also leaves (I-5, keyboard-complete)"

answers="$(answers_file "@ctrlc" yes)"
run_panel "$answers"
check_status "$PANEL_STATUS" 130 "Home: Ctrl+C leaves with 130"

# --- real mode (--apply): a pass-through sudo, and a spy wrapper per
# helper binary that logs argv then runs the real thing --------------

# sudo: strips the flags this panel passes (-v with nothing else, or a
# command after them) and execs whatever's left -- same fake as
# wizard-test.sh's RM_STUBS/sudo.
cat >"$STUBS/sudo" <<'EOF'
#!/bin/bash
args=()
while (($#)); do
    case "$1" in
        -n | -v | -S) shift ;;
        -p) shift 2 ;;
        -u) shift 2 ;;
        *) args+=("$1"); shift ;;
    esac
done
if ((${#args[@]} == 0)); then
    cat >/dev/null
    exit 0
fi
exec "${args[@]}"
EOF
chmod +x "$STUBS/sudo"

# spy NAME REAL -- logs "NAME argv..." to $ARGV_LOG, then execs REAL with
# the same argv (so the real behavior -- and the real command's own exit
# status -- still happen, against this file's scratch trees).
spy() {
  local name="$1" real="$2" f="$STUBS/$1"
  cat >"$f" <<EOF
#!/bin/bash
{ printf '%s' "$name"; printf ' %s' "\$@"; printf '\n'; } >> "$ARGV_LOG"
if [[ "$name" == omarchy-kids-ask ]]; then
  PATH="$ROOT_ID_STUBS:\$PATH" exec "$real" "\$@"
fi
exec "$real" "\$@"
EOF
  chmod +x "$f"
}

cat >"$ROOT_ID_STUBS/id" <<'EOF'
#!/bin/bash
case "${1:-}" in
  -u) echo 0 ;;
  -un) echo root ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$ROOT_ID_STUBS/id"
spy omarchy-kids-conf "$ROOT_DIR/bin/omarchy-kids-conf"
spy omarchy-kids-time "$TMP/real-tree/bin/omarchy-kids-time"
spy omarchy-kids-ask "$TMP/real-tree/bin/omarchy-kids-ask"
spy omarchy-kids-apps "$ROOT_DIR/bin/omarchy-kids-apps"
spy omarchy-kids-web "$ROOT_DIR/bin/omarchy-kids-web"

# omarchy-kids-provision's spy fakes `remove` instead of really running
# it (see this file's header) but still forwards `list`/`--help` to the
# real thing, since the panel's Home screen and the password fallback
# both depend on those.
cat >"$STUBS/omarchy-kids-provision" <<EOF
#!/bin/bash
{ printf '%s' "omarchy-kids-provision"; printf ' %s' "\$@"; printf '\n'; } >> "$ARGV_LOG"
if [[ "\${1:-}" == "remove" ]]; then
    echo "kid-ada: removed (fake, panel-test.sh)"
    exit 0
fi
exec "$ROOT_DIR/bin/omarchy-kids-provision" "\$@"
EOF
chmod +x "$STUBS/omarchy-kids-provision"

export PATH="$STUBS:$PATH"

for fake in omarchy-kids-conf omarchy-kids-time omarchy-kids-ask \
  omarchy-kids-apps omarchy-kids-web omarchy-kids-provision; do
  [[ -f "$STUBS/$fake" ]] && cp "$STUBS/$fake" "$TMP/tree/bin/$fake"
done

# --- real: grant minutes ------------------------------------------------

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada
avatar=fox
band=6-8
EOF
: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" time grant 15 back back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real grant exits 0"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-time grant kid-ada 15" \
  "real: 'give more minutes' actually calls the grant command"

# --- real: change the daily budget, and it's really written ------------

: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" time budget 45 back back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real budget change exits 0"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-conf set kid-ada budget_min 45" \
  "real: changing the budget actually calls conf set"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "budget_min=45" \
  "real: the budget override is really on disk afterward"
check_contains "$out" "Change applied" \
  "real: the next card carries the write's success notice"

# --- real: hide an app, and it's really written -------------------------

: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" apps gcompris back back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real hide exits 0"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-apps hide kid-ada gcompris" \
  "real: hiding an app actually calls apps hide"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "apps.hidden=gcompris" \
  "real: the hidden app is really on disk afterward"

# --- real: the Wi-Fi mode really lands on disk --------------------------

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada
avatar=fox
band=6-8
EOF
check_not_contains "$(cat "$ETC/kids/kid-ada.conf")" "wifi=helper" \
  "real: the Wi-Fi fixture starts with no override"
: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" wifi helper back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real Wi-Fi mode change exits 0"
check_not_contains "$out" "does not match" \
  "real: the Wi-Fi answer script is consumed exactly"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-conf set kid-ada wifi helper" \
  "real: changing Wi-Fi mode actually calls conf set"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "wifi=helper" \
  "real: the Wi-Fi mode is really on disk afterward"

# --- real: reset clears overrides but keeps the account ----------------

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada
avatar=fox
band=6-8
budget_min=45
wifi=helper
EOF
answers="$(answers_file "kid:kid-ada" reset reset back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real reset exits 0"
check_not_contains "$(cat "$ETC/kids/kid-ada.conf")" "budget_min=" \
  "real: reset clears a budget override"
check_not_contains "$(cat "$ETC/kids/kid-ada.conf")" "wifi=helper" \
  "real: reset clears a Wi-Fi override"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "name=Ada" \
  "real: reset keeps the kid's name"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "band=6-8" \
  "real: reset keeps the kid's band"

# --- real: approve a request, and it's really marked approved ----------

: >"$ARGV_LOG"
req_id="$(python3 "$ROOT_DIR/lib/ask.py" write "$QUEUE_DIR" --kid kid-ada --kind time \
  --what 15 --minutes 15)"
req_id="${req_id%.json}"
answers="$(answers_file requests "$req_id" approve back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real approve exits 0"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-ask approve $req_id --apply" \
  "real: approving a request actually calls ask approve"
check_contains "$(cat "$QUEUE_DIR/$req_id.json")" '"state": "approved"' \
  "real: the request is really marked approved afterward"
check_contains "$out" "Ada — 15 more minute(s)" \
  "real: the Requests list shows the kid's display name"
check_not_contains "$out" "kid-ada — 15 more minute(s)" \
  "real: the Requests list no longer labels the row with the account name"
check_contains "$out" "Request from Ada" "real: the request card names the kid by display name"
check_contains "$out" "Kid: Ada (kid-ada)" "real: the request card keeps the account name alongside it"

# A kid with no profile name falls back to the account, with no empty
# parentheses on the card.
req_id2="$(python3 "$ROOT_DIR/lib/ask.py" write "$QUEUE_DIR" --kid kid-cy --kind time \
  --what 10 --minutes 10)"
req_id2="${req_id2%.json}"
answers="$(answers_file requests "$req_id2" back back quit)"
run_panel "$answers"
check_status "$PANEL_STATUS" 0 "a request from a kid with no profile still renders"
check_contains "$out" "kid-cy — 10 more minute(s)" \
  "real: a missing profile name falls back to the account in the list"
check_contains "$out" "Kid: kid-cy" "real: the card falls back to the account"
check_not_contains "$out" "Kid: kid-cy (kid-cy)" \
  "real: the card does not repeat the account as if it were a name"

# --- real: remove a kid, wrong confirmation -> nothing runs -------------

: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" remove "NotAda" back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real wrong-confirmation exits 0"
check_not_contains "$(cat "$ARGV_LOG")" "omarchy-kids-provision remove" \
  "real: a wrong confirmation name never calls provision remove"
[[ -e "$ETC/kids/kid-ada.conf" ]] && pass "real: kid-ada's profile is untouched after a wrong confirmation" ||
  fail "real: kid-ada's profile is untouched after a wrong confirmation"

# --- real: remove a kid, right confirmation -> the exact command runs --

: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" remove "Ada" quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "real right-confirmation exits 0"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-provision remove kid-ada --apply" \
  "real: the right confirmation name actually calls provision remove"

# --- real: a failing write is carried, not swallowed by the next card ---

cat >"$TMP/tree/bin/omarchy-kids-conf" <<EOF
#!/bin/bash
if [[ "\${1:-}" == "set" ]]; then
  echo "conf: refusing on purpose" >&2
  exit 1
fi
exec "$ROOT_DIR/bin/omarchy-kids-conf" "\$@"
EOF
chmod +x "$TMP/tree/bin/omarchy-kids-conf"
answers="$(answers_file "kid:kid-ada" time budget 50 back back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "a failing write does not abort the panel"
check_contains "$out" "conf: refusing on purpose" "the failing write's own message is shown"
check_contains "$out" "That change failed" "the next card carries the failure notice"
cp "$STUBS/omarchy-kids-conf" "$TMP/tree/bin/omarchy-kids-conf"

# --- real: a rejected sudo password is carried, not a blank card ---------

mv "$STUBS/sudo" "$STUBS/sudo.real"
cat >"$STUBS/sudo" <<EOF
#!/bin/bash
if [[ "\${1:-}" == "-v" ]]; then
  echo "sudo: no password supplied" >&2
  exit 1
fi
exec "$STUBS/sudo.real" "\$@"
EOF
chmod +x "$STUBS/sudo"
answers="$(answers_file "kid:kid-ada" time grant 15 back back quit)"
run_panel "$answers" --apply
check_status "$PANEL_STATUS" 0 "a rejected password does not abort the panel"
check_contains "$out" "password wasn't accepted" \
  "the next card says nothing changed after a rejected password"
mv "$STUBS/sudo.real" "$STUBS/sudo"

# --- real: Machine safety, rendered from the check's own JSON ------------

cat >"$TMP/tree/bin/omarchy-kids-check" <<'EOF'
#!/bin/bash
cat <<'JSON'
{"generated_at":"2026-09-18T10:00:00Z","verdict":"fail","exit_code":2,"sections":[
 {"name":"Accounts","checks":[{"id":"kid-ada:no-wheel","status":"pass","detail":"not in wheel"}]},
 {"name":"Firmware","checks":[{"id":"firmware:password","status":"fail","detail":"the firmware-password step isn't marked done"}]},
 {"name":"Web","checks":[{"id":"web:policy","status":"warn","detail":"could not be verified on this machine"}]}]}
JSON
exit 2
EOF
chmod +x "$TMP/tree/bin/omarchy-kids-check"
answers="$(answers_file machine back quit)"
run_panel "$answers"
check_status "$PANEL_STATUS" 0 "Machine screen exits 0 on a failing report"
check_contains "$out" "Safety: NOT READY — 1 check(s) failing." \
  "Machine shows the verdict and the failing count"
check_contains "$out" "firmware:password" "Machine names the failing check"
check_contains "$out" "isn't marked done" "Machine shows the failing check's own detail"
check_contains "$out" "WARN  web:policy" "Machine shows warnings too"
check_contains "$out" "Loaded without root" "Machine says the report ran unprivileged"

# A garbage report is a notice, not a fake pass.
cat >"$TMP/tree/bin/omarchy-kids-check" <<'EOF'
#!/bin/bash
echo "not a report at all"
exit 2
EOF
chmod +x "$TMP/tree/bin/omarchy-kids-check"
answers="$(answers_file machine back quit)"
run_panel "$answers"
check_status "$PANEL_STATUS" 0 "a garbage report does not abort the panel"
check_contains "$out" "Could not read the safety report" \
  "a garbage report is reported as unreadable"

# Refresh redraws from a fresh run.
cat >"$TMP/tree/bin/omarchy-kids-check" <<'EOF'
#!/bin/bash
cat <<'JSON'
{"generated_at":"2026-09-18T10:00:00Z","verdict":"pass","exit_code":0,"sections":[
 {"name":"Accounts","checks":[{"id":"kid-ada:no-wheel","status":"pass","detail":"not in wheel"}]}]}
JSON
exit 0
EOF
chmod +x "$TMP/tree/bin/omarchy-kids-check"
answers="$(answers_file machine refresh back quit)"
run_panel "$answers"
check_status "$PANEL_STATUS" 0 "the refresh loop exits 0"
check "$(grep -c 'Safety: every check passed.' <<<"$out")" 2 \
  "Check again runs the report a second time"

# --- Notifications (P6, R-NOTIFY-1/3/5) ---------------------------------
#
# The notify command is stubbed here (AGENTS.md shape 1): the panel's job is
# its own wiring -- the exact command it asks sudo to run, and the state it
# draws. A file switches the stub's status between off and on.
cat >"$TMP/tree/bin/omarchy-kids-notify" <<EOF
#!/bin/bash
{ printf '%s' "omarchy-kids-notify"; printf ' %s' "\$@"; printf '\n'; } >> "$ARGV_LOG"
case "\${1:-}" in
  status)
    [[ -f "$TMP/notify.fail" ]] && exit 1
    if [[ -f "$TMP/notify.on" ]]; then echo "notifications: on"; else echo "notifications: off"; fi
    echo "no devices paired"
    ;;
  devices)
    if [[ -f "$TMP/notify.device" ]]; then
      echo '[{"id":"d-1","name":"Phone","platform":"android","scopes":["decide","act"]}]'
    else
      echo "[]"
    fi
    ;;
  enable) echo "omarchy-kids-notify: notifications on (relay port 8447)" ;;
  disable) echo "omarchy-kids-notify: notifications off; certificate removed" ;;
  pair)
    echo "omarchy-kids-devices: pairing started for d-1"
    echo "  pair:  omarchy-kids://pair?v=1&id=d-1&token=abc"
    echo "  fingerprint: deadbeef"
    ;;
  revoke) echo "omarchy-kids-devices: revoked \$2" ;;
esac
exit 0
EOF
chmod +x "$TMP/tree/bin/omarchy-kids-notify"

rm -f "$TMP/notify.on" "$TMP/notify.fail" "$TMP/notify.device"
: >"$ARGV_LOG"
answers="$(answers_file notifications enable back quit)"
run_panel "$answers" --dry-run
check_contains "$out" "Notifications are off" "notifications off: the screen says so"
check_contains "$out" "Turn on notifications" "notifications off: the screen offers to turn them on"
check_contains "$out" "[dry-run] sudo $TREE_BIN/omarchy-kids-notify enable --apply" \
  "dry-run: enable prints the exact command"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-notify status" \
  "the screen reads the status through sudo (root owns the certificate)"

# A failed read is a notice, never a fake "off" (I-6): the relay may be listening.
touch "$TMP/notify.fail"
answers="$(answers_file notifications back quit)"
run_panel "$answers" --dry-run
check_contains "$out" "Couldn't read the notification status" \
  "a failed status read says so instead of claiming notifications are off"

# --apply: pair captures the code and fingerprint onto the next card (R-NOTIFY-5).
rm -f "$TMP/notify.fail"
touch "$TMP/notify.on"
: >"$ARGV_LOG"
answers="$(answers_file notifications pair back quit)"
run_panel "$answers" --apply
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-notify pair --apply" \
  "apply: pair really runs the command"
check_contains "$out" "Pairing window open" "apply: the pairing window is announced"
check_contains "$out" "omarchy-kids://pair" "apply: the pairing code survives onto the card"
check_contains "$out" "fingerprint: deadbeef" "apply: the fingerprint survives onto the card"

# --apply: a paired device is listed and revoked through sudo.
touch "$TMP/notify.device"
: >"$ARGV_LOG"
answers="$(answers_file notifications devices d-1 yes back back quit)"
run_panel "$answers" --apply
check_contains "$out" "Phone · android" "devices: the paired device is listed"
check_contains "$(cat "$ARGV_LOG")" "omarchy-kids-notify revoke d-1 --apply" \
  "devices: revoke really runs for the chosen device"
rm -f "$TMP/notify.device"

touch "$TMP/notify.on"
answers="$(answers_file notifications pair back quit)"
run_panel "$answers" --dry-run
check_contains "$out" "Notifications are on" "notifications on: the screen says so"
check_contains "$out" "Turn off notifications" "notifications on: the screen offers to turn them off"
check_contains "$out" "[dry-run] sudo $TREE_BIN/omarchy-kids-notify pair --apply" \
  "dry-run: pair prints the exact command"

: >"$ARGV_LOG"
answers="$(answers_file notifications disable no back quit)"
run_panel "$answers" --dry-run
check_not_contains "$out" "omarchy-kids-notify disable" \
  "declining the disable confirm prints no disable command"

answers="$(answers_file notifications disable yes back quit)"
run_panel "$answers" --dry-run
check_contains "$out" "[dry-run] sudo $TREE_BIN/omarchy-kids-notify disable --apply" \
  "confirming prints the exact disable command"

answers="$(answers_file notifications devices back back quit)"
run_panel "$answers" --dry-run
check_contains "$out" "No devices are paired" "devices: an empty list says so"

# --- --help works with no terminal and no answers file needed ----------
help_out="$("$BIN" --help 2>&1)"
help_status=$?
check_status "$help_status" 0 "--help exits 0"
check_contains "$help_out" "Usage: omarchy-kids-panel" "--help prints usage"

# =====================================================================
# review §1.5: opened by a human, the panel is real
# =====================================================================
#
# The shipped app entry runs `env OMARCHY_KIDS_LAUNCHED_BY=desktop
# omarchy-kids`, which reaches the panel with no terminal at all. Before
# this fix a parent opened Kids Mode from the drawer, changed something,
# watched "[dry-run] sudo ..." scroll past and had no change. There is no
# flag the drawer can pass to fix that, so the default has to be right.

: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" time budget 55 back back quit)"
out="$(OMARCHY_KIDS_TUI_ANSWERS="$answers" OMARCHY_KIDS_LAUNCHED_BY=desktop "$BIN" 2>&1)"
check_status $? 0 "launched from the app entry: exits 0"
check_not_contains "$out" "[dry-run]" "launched from the app entry: no preview, this is a real run"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "budget_min=55" \
  "launched from the app entry: the change is really on disk (review §1.5)"

# ...and --dry-run still wins, even from the app entry.
: >"$ARGV_LOG"
answers="$(answers_file "kid:kid-ada" time budget 60 back back quit)"
out="$(OMARCHY_KIDS_TUI_ANSWERS="$answers" OMARCHY_KIDS_LAUNCHED_BY=desktop "$BIN" --dry-run 2>&1)"
check_contains "$out" "[dry-run]" "--dry-run wins over the app entry"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "budget_min=55" "--dry-run wrote nothing"

# ...and with no terminal and no app entry (a script, a test, CI) the
# safe default still holds -- AGENTS.md rule 8.
answers="$(answers_file "kid:kid-ada" time budget 70 back back quit)"
out="$(OMARCHY_KIDS_TUI_ANSWERS="$answers" "$BIN" 2>&1)"
check_contains "$out" "[dry-run]" "no tty and no app entry: still previews by default"
check_contains "$(cat "$ETC/kids/kid-ada.conf")" "budget_min=55" "no tty: wrote nothing"

# The desktop entry really does set the marker the panel keys on.
DESKTOP="$ROOT_DIR/desktop/omarchy-kids.desktop"
check_contains "$(cat "$DESKTOP")" "OMARCHY_KIDS_LAUNCHED_BY=desktop" \
  "desktop/omarchy-kids.desktop marks itself as a human launch"

echo "panel-test.sh: done"
exit $rc
