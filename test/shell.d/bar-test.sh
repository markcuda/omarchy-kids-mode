#!/bin/bash
# Tests bin/omarchy-kids-bar (SPEC.md R-BAR, I-1; issue #37): enable/
# disable's exact shell.json edits on a fixture copy, backup, idempotence,
# and disable restoring the original -- plus /run/omarchy-kids/status.json's
# permissions (R-BAR-3), which bin/omarchy-kids-time-ledger writes and
# nothing tested until now.
#
# The widget itself (share/bar/KidsModule.qml) is QML that parses
# status.json inline; there is no separate bash/python parsing helper to
# unit-test here (see docs/bar.md's "What this doesn't test").
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
BAR=""    # a copy in a scratch tree, so the stub omarchy-kids-time /
LEDGER="" # -exit sit beside it: no *_BIN env override exists any more.

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP bar-test.sh: jq not found"
  exit 0
fi

fail=0
pass() { echo "ok   $*"; }
fail_() {
  echo "FAIL $*"
  fail=1
}
check() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail_ "$3 (want '$2', got '$1')"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail_ "$3 (want to find '$2' in '$1')"; fi
}
check_status() { # got_status want_status label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail_ "$3 (want exit $2, got $1)"; fi
}

TMP="$(mktemp -d)"

# Stubs plus a base toolset only: an Omarchy box has the real floating-
# terminal helper and the omarchy-kids-* commands on PATH, and a check that
# one is missing must not depend on this box (AGENTS.md, testing rules).
BASE_PATH="$(kids_base_path "$TMP/base")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

SHARE="$TMP/share"
mkdir -p "$SHARE/bar"
cp "$DIR/share/bar/manifest.json" "$DIR/share/bar/KidsModule.qml" "$SHARE/bar/"

export OMARCHY_KIDS_SHARE="$SHARE"

kids_tree "$TMP/tree" "$DIR"
BAR="$TMP/tree/bin/omarchy-kids-bar"
LEDGER="$TMP/tree/bin/omarchy-kids-time-ledger"

plugin_id="omarchy-kids.bar"

# ===========================================================================
# 1. No pre-existing shell.json, no defaults file: refuses to invent one
#    (I-1 -- never silently discard whatever else would have been on the
#    parent's real bar).
# ===========================================================================
HOME1="$TMP/home1"
mkdir -p "$HOME1"
# The defaults file is $OMARCHY_PATH/config/omarchy/shell.json -- Omarchy's
# own variable, pointed at a scratch tree here. There is no
# OMARCHY_KIDS_* override for it any more (AGENTS.md, "The trust boundary").
out="$(OMARCHY_KIDS_HOME="$HOME1" OMARCHY_PATH="$TMP/no-such-omarchy" \
  "$BAR" enable --apply 2>&1)"
status=$?
check_status "$status" 1 "enable refuses when there is no shell.json and no defaults to seed from"
check_contains "$out" "refusing to invent" "the refusal explains why"
check "$([[ -f "$HOME1/.config/omarchy/shell.json" ]] && echo yes || echo no)" "no" \
  "no shell.json was created"

# ===========================================================================
# 2. No pre-existing shell.json, but a defaults file exists (a fresh
#    install that never customized the bar): enable seeds shell.json from
#    the defaults, adds the widget, and remembers it created the file.
# ===========================================================================
HOME2="$TMP/home2"
DEFAULTS2="$TMP/defaults2/config/omarchy/shell.json"
mkdir -p "$HOME2" "$(dirname "$DEFAULTS2")"
cat >"$DEFAULTS2" <<'EOF'
{
  "version": 1,
  "bar": {
    "id": "omarchy.bar",
    "layout": {
      "left": [{"id": "omarchy.menu"}, {"id": "omarchy.workspaces"}],
      "center": [{"id": "omarchy.clock"}],
      "right": [{"id": "omarchy.audio"}]
    }
  },
  "plugins": []
}
EOF

env2() { OMARCHY_KIDS_HOME="$HOME2" OMARCHY_PATH="$TMP/defaults2" "$@"; }

out="$(env2 "$BAR" status)"
check "$out" "disabled" "status: disabled before enable"

out="$(env2 "$BAR" enable)"
check "$([[ -f "$HOME2/.config/omarchy/shell.json" ]] && echo yes || echo no)" "no" \
  "enable (dry-run, the default) writes nothing"
check_contains "$out" "dry-run" "enable's dry-run output says so"

env2 "$BAR" enable --apply >/dev/null
SHELL_JSON2="$HOME2/.config/omarchy/shell.json"
check "$([[ -f "$SHELL_JSON2" ]] && echo yes || echo no)" "yes" \
  "enable --apply creates shell.json from the defaults"
check "$([[ -f "$HOME2/.config/omarchy/.omarchy-kids-bar-created-shell-json" ]] && echo yes || echo no)" "yes" \
  "a 'we created this' marker is left behind"
check "$([[ -f "$HOME2/.config/omarchy/plugins/$plugin_id/manifest.json" ]] && echo yes || echo no)" "yes" \
  "the plugin manifest is installed"
check "$([[ -f "$HOME2/.config/omarchy/plugins/$plugin_id/KidsModule.qml" ]] && echo yes || echo no)" "yes" \
  "KidsModule.qml is installed"
check "$(jq -r '.bar.layout.left | length' "$SHELL_JSON2")" "2" \
  "the defaults' left section survives untouched"
check "$(jq -r '[.bar.layout.right[] | select(.id == "omarchy.audio")] | length' "$SHELL_JSON2")" "1" \
  "the defaults' right section keeps its existing widget"
check "$(jq -r "[.bar.layout.right[] | select(.id == \"$plugin_id\")] | length" "$SHELL_JSON2")" "1" \
  "the kids widget was added to the right section"
check "$(env2 "$BAR" status)" "enabled" "status: enabled after enable --apply"

# --- idempotence: enabling again changes nothing further ------------------
before="$(cat "$SHELL_JSON2")"
out="$(env2 "$BAR" enable --apply)"
after="$(cat "$SHELL_JSON2")"
check "$out" "omarchy-kids-bar: already enabled" "a second enable --apply says already enabled"
check "$before" "$after" "a second enable --apply leaves shell.json byte-for-byte the same"
check "$(jq -r "[.bar.layout.right[] | select(.id == \"$plugin_id\")] | length" "$SHELL_JSON2")" "1" \
  "still exactly one widget entry after a second enable"

# --- disable: since enable created shell.json, disable removes it ---------
env2 "$BAR" disable --apply >/dev/null
check "$([[ -f "$SHELL_JSON2" ]] && echo yes || echo no)" "no" \
  "disable removes the shell.json it created (back to 'no file' = defaults)"
check "$([[ -f "$HOME2/.config/omarchy/.omarchy-kids-bar-created-shell-json" ]] && echo yes || echo no)" "no" \
  "the created-marker is cleared"
check "$(env2 "$BAR" status)" "disabled" "status: disabled after disable"
check "$([[ -d "$HOME2/.config/omarchy/plugins/$plugin_id" ]] && echo yes || echo no)" "yes" \
  "the installed plugin files are left in place (matches 'omarchy plugin disable')"

out="$(env2 "$BAR" disable --apply)"
check "$out" "omarchy-kids-bar: already disabled" "disabling again is a no-op"

# ===========================================================================
# 3. A pre-existing, already-customized shell.json: enable backs it up
#    once, adds the widget, leaves everything else alone; disable restores
#    the exact original bytes and removes the backup.
# ===========================================================================
HOME3="$TMP/home3"
mkdir -p "$HOME3/.config/omarchy"
SHELL_JSON3="$HOME3/.config/omarchy/shell.json"
BACKUP3="$SHELL_JSON3.omarchy-kids.bak"
cat >"$SHELL_JSON3" <<'EOF'
{
  "version": 1,
  "idle": {"screensaver": 150, "lock": 300},
  "bar": {
    "id": "omarchy.bar",
    "position": "top",
    "layout": {
      "left": [{"id": "omarchy.menu"}],
      "center": [{"id": "omarchy.clock", "format": "HH:mm"}],
      "right": [{"id": "omarchy.tailscale"}, {"id": "omarchy.audio"}]
    }
  },
  "plugins": [{"id": "acme.weather"}]
}
EOF
original3="$(cat "$SHELL_JSON3")"

env3() { OMARCHY_KIDS_HOME="$HOME3" OMARCHY_PATH="$TMP/unused-omarchy" "$@"; }

env3 "$BAR" enable --apply >/dev/null
check "$([[ -f "$BACKUP3" ]] && echo yes || echo no)" "yes" \
  "enable backs up an existing shell.json before touching it"
check "$(cat "$BACKUP3")" "$original3" "the backup is byte-for-byte the original"
check "$([[ -f "$HOME3/.config/omarchy/.omarchy-kids-bar-created-shell-json" ]] && echo yes || echo no)" "no" \
  "no 'we created this' marker for a shell.json that already existed"
check "$(jq -r '.plugins | length' "$SHELL_JSON3")" "1" \
  "unrelated plugins[] entries survive"
check "$(jq -r '.idle.lock' "$SHELL_JSON3")" "300" "unrelated top-level keys survive"
check "$(jq -r "[.bar.layout.right[] | select(.id == \"$plugin_id\")] | length" "$SHELL_JSON3")" "1" \
  "the widget was added"
check "$(jq -r '.bar.layout.right | length' "$SHELL_JSON3")" "3" \
  "the widget was added alongside, not instead of, the existing two"

# --- idempotence: a second enable does not re-back-up or duplicate --------
env3 "$BAR" enable --apply >/dev/null
check "$(cat "$BACKUP3")" "$original3" "the backup is still the original after a second enable"
check "$(jq -r "[.bar.layout.right[] | select(.id == \"$plugin_id\")] | length" "$SHELL_JSON3")" "1" \
  "still exactly one widget entry after a second enable"

# --- disable restores the original and removes the backup -----------------
env3 "$BAR" disable --apply >/dev/null
check "$(cat "$SHELL_JSON3")" "$original3" "disable restores shell.json to the exact original bytes"
check "$([[ -f "$BACKUP3" ]] && echo yes || echo no)" "no" "the backup is removed once restored"
check "$(env3 "$BAR" status)" "disabled" "status: disabled after restoring"

out="$(env3 "$BAR" disable --apply)"
check "$out" "omarchy-kids-bar: already disabled" "disabling an already-disabled bar is a no-op"

# ===========================================================================
# 4. grant: opens Omarchy's floating-terminal helper and wraps a plain
#    `sudo omarchy-kids-time grant` inside it.
# ===========================================================================
STUBS4="$TMP/stubs4"
mkdir -p "$STUBS4"
cat >"$STUBS4/sudo" <<'EOF'
#!/bin/bash
echo "SUDO $*" >>"$LOGFILE"
exec "$@"
EOF
chmod +x "$STUBS4/sudo"

# The two sibling commands are resolved beside omarchy-kids-bar itself,
# so their stubs go into the scratch tree, not onto PATH.
kids_stub "$TMP/tree" omarchy-kids-time <<'EOF'
#!/bin/bash
echo "TIME $*" >>"$LOGFILE"
exit 0
EOF
kids_stub "$TMP/tree" omarchy-kids-exit <<'EOF'
#!/bin/bash
echo "EXIT $*" >>"$LOGFILE"
exit 0
EOF

# The terminal is Omarchy's own helper, never named by an env var
# (review 1.4: there is no fallback left to pick).
cat >"$STUBS4/omarchy-launch-floating-terminal-with-presentation" <<'EOF'
#!/bin/bash
echo "TERM $*" >>"$LOGFILE"
exec "$@"
EOF
chmod +x "$STUBS4/omarchy-launch-floating-terminal-with-presentation"

LOGFILE="$TMP/grant.log"
: >"$LOGFILE"
out="$(PATH="$STUBS4:$BASE_PATH" LOGFILE="$LOGFILE" \
  "$BAR" grant kid-ada 15 </dev/null 2>&1)"
check_status "$?" 0 "grant exits 0 when the terminal/sudo/time chain succeeds"
log="$(cat "$LOGFILE")"
check_contains "$log" "TERM " "grant launches the configured terminal"
check_contains "$log" "SUDO " "the terminal ran the command through sudo"
check_contains "$log" "TIME grant kid-ada 15" "sudo ran omarchy-kids-time grant kid-ada 15"

out="$("$BAR" grant 2>&1)"
check_status "$?" 2 "grant with no kid/minutes is refused"

out="$("$BAR" grant kid-ada nope 2>&1)"
check_status "$?" 2 "grant with a non-numeric minutes is refused"
check_contains "$out" "positive integer" "the refusal explains why"

# --- end: R-BAR-2's "end session" action, same terminal/sudo shape, but
#     via omarchy-kids-exit --finish --kid, never loginctl directly --
#     see bin/omarchy-kids-bar's own header for why (a hard loginctl
#     terminate on a live session crashes sddm-helper, docs/exit.md) -----
LOGFILE3="$TMP/end.log"
: >"$LOGFILE3"
out="$(PATH="$STUBS4:$BASE_PATH" LOGFILE="$LOGFILE3" \
  "$BAR" end kid-ada </dev/null 2>&1)"
check_status "$?" 0 "end exits 0 when the terminal/sudo/omarchy-kids-exit chain succeeds"
log3="$(cat "$LOGFILE3")"
check_contains "$log3" "TERM " "end launches the configured terminal"
check_contains "$log3" "SUDO " "end ran the command through sudo"
check_contains "$log3" "EXIT --finish --kid kid-ada" "sudo ran omarchy-kids-exit --finish --kid <kid>"
check "$(grep -c loginctl "$LOGFILE3")" "0" "end never calls loginctl directly"

out="$("$BAR" end 2>&1)"
check_status "$?" 2 "end with no kid is refused"

# --- approve / decline: N-9's desktop-notification actions, the same
#     terminal/sudo shape, through omarchy-kids-ask (R-NOTIFY) ------------
kids_stub "$TMP/tree" omarchy-kids-ask <<'EOF'
#!/bin/bash
echo "ASK $*" >>"$LOGFILE"
exit 0
EOF

LOGFILE4="$TMP/approve.log"
: >"$LOGFILE4"
out="$(PATH="$STUBS4:$BASE_PATH" LOGFILE="$LOGFILE4" \
  "$BAR" approve 1000000001-kid-ada-time </dev/null 2>&1)"
check_status "$?" 0 "approve exits 0 when the terminal/sudo/ask chain succeeds"
check_contains "$(cat "$LOGFILE4")" "SUDO " "approve ran the command through sudo"
check_contains "$(cat "$LOGFILE4")" "ASK approve 1000000001-kid-ada-time --apply" \
  "sudo ran omarchy-kids-ask approve <id> --apply"

LOGFILE5="$TMP/decline.log"
: >"$LOGFILE5"
out="$(PATH="$STUBS4:$BASE_PATH" LOGFILE="$LOGFILE5" \
  "$BAR" decline 1000000002-kid-ada-app </dev/null 2>&1)"
check_status "$?" 0 "decline exits 0 when the terminal/sudo/ask chain succeeds"
check_contains "$(cat "$LOGFILE5")" "ASK decline 1000000002-kid-ada-app --apply" \
  "sudo ran omarchy-kids-ask decline <id> --apply"

out="$("$BAR" approve 2>&1)"
check_status "$?" 2 "approve with no id is refused"
out="$("$BAR" decline 2>&1)"
check_status "$?" 2 "decline with no id is refused"

# ===========================================================================
# 5. /run/omarchy-kids/status.json (R-BAR-3): mode 0640, group
#    omarchy-parents -- NOT world-readable 0644. SPEC.md R-BAR-3 says
#    "group omarchy-parents readable"; the issue that asked for this test
#    said to make it 0644 world-readable if it wasn't already, which
#    disagrees with the spec -- per AGENTS.md, the spec wins, and this is
#    the ticket's comment. bin/omarchy-kids-time-ledger already writes
#    exactly what the spec asks for (chmod 0640; chgrp omarchy-parents,
#    best-effort so a dev box with no such group still ticks).
# ===========================================================================
if command -v python3 >/dev/null 2>&1; then
  ROOT5="$TMP/root5"
  ETC5="$TMP/etc5"
  mkdir -p "$ETC5/kids" "$ROOT5"
  cat >"$ETC5/kids/kid-ada.conf" <<'EOF'
name=Ada
avatar=fox
band=6-8
EOF
  export OMARCHY_KIDS_SHARE="$SHARE" # harmless: conf.sh only reads bands/packs it needs
  mkdir -p "$SHARE/bands" "$SHARE/packs"
  cp "$DIR/share/bands/bands.toml" "$SHARE/bands/" 2>/dev/null || true
  cp "$DIR"/share/packs/*.toml "$SHARE/packs/" 2>/dev/null || true

  STUBS_LEDGER="$TMP/stubs-ledger"
  mkdir -p "$STUBS_LEDGER"
  kids_id_stub "$STUBS_LEDGER" kid-ada "$(id -u)"
  PATH="$STUBS_LEDGER:$BASE_PATH" KIDS_TEST_UID=0 \
    OMARCHY_KIDS_ETC="$ETC5" OMARCHY_KIDS_ROOT="$ROOT5" \
    OMARCHY_KIDS_NOW="2026-09-01 12:00:00" \
    "$LEDGER" tick >/dev/null 2>&1

  STATUS_JSON5="$ROOT5/run/omarchy-kids/status.json"
  if command -v jq >/dev/null 2>&1 && [[ -f "$STATUS_JSON5" ]]; then
    mode="$(kids_file_mode "$STATUS_JSON5")"
    check "$mode" "640" "status.json is written mode 0640 (group omarchy-parents readable, R-BAR-3)"
    check "$(jq -r '.kids[0].kid' "$STATUS_JSON5")" "kid-ada" "status.json lists the known kid"
    check "$(jq -r '.kids[0] | has("minutes_left")' "$STATUS_JSON5")" "true" "status.json rows have minutes_left"
    check "$(jq -r '.kids[0] | has("paused")' "$STATUS_JSON5")" "true" "status.json rows have paused"
    check "$(jq -r '.kids[0] | has("live")' "$STATUS_JSON5")" "true" "status.json rows have live"
  else
    echo "SKIP status.json checks: jq missing or the ledger didn't write it (see time-test.sh for the same tick, tested there)"
  fi
  grep -q 'chgrp omarchy-parents' "$LEDGER" && pass "the ledger's write_status_json chgrps omarchy-parents (best-effort)" ||
    fail_ "expected bin/omarchy-kids-time-ledger to chgrp omarchy-parents"
else
  echo "SKIP status.json checks: python3 not found (lib/time.sh needs it)"
fi

# --- KidsModule.qml renders nothing when the file is missing --------------
grep -q 'root.hasFile = false' "$SHARE/bar/KidsModule.qml" &&
  grep -q 'visible: root.hasFile' "$SHARE/bar/KidsModule.qml" &&
  pass "KidsModule.qml is visible only when status.json parsed (renders nothing when missing)" ||
  fail_ "expected KidsModule.qml's visible binding to gate on hasFile"

# --- shellcheck (the harness runs this too, but a direct check here keeps
#     the failure local to this test file) ----------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning "$BAR" >/dev/null; then
    pass "shellcheck -S warning is clean on bin/omarchy-kids-bar"
  else
    fail_ "shellcheck -S warning found something in bin/omarchy-kids-bar"
    shellcheck -S warning "$BAR" || true
  fi
fi

exit $fail
