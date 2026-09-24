#!/bin/bash
# Tests bin/omarchy-kids-data, lib/data.sh, lib/data.py, and the two
# small additions this issue makes to existing commands (SPEC.md
# R-DATA-1..5, I-2, I-6; issue #27):
#
#   - bin/omarchy-kids-launcher-ctl's new `log` command (a kid's own
#     half of the launch log, per that file's own header).
#   - bin/omarchy-kids-time-ledger tick's new launch-log fold step
#     (lib/data.sh's data_fold_launches, called once per known kid).
#
# Fully self-contained: `id -u <kid>` and `loginctl` are fakes on a
# stub PATH (same stub() shape as test/shell.d/apps-test.sh and
# test/shell.d/time-test.sh); the Chromium History fixture is a real
# SQLite db built by python3 (this issue's own "Chromium facts", not a
# fake); everything else is a real scratch tree under OMARCHY_KIDS_ROOT/
# OMARCHY_KIDS_ETC/OMARCHY_KIDS_SHARE. One provisioned kid throughout:
# kid-ada, band 6-8, AGENTS.md rule 9's fixture convention.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA="$DIR/bin/omarchy-kids-data"
LAUNCHER_CTL="$DIR/bin/omarchy-kids-launcher-ctl"
LEDGER="$DIR/bin/omarchy-kids-time-ledger"
CONF="$DIR/bin/omarchy-kids-conf"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP data-test.sh: python3 not found"
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
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail_ "$3 (did not want to find '$2' in '$1')"; fi
}
check_status() { # got_status want_status label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail_ "$3 (want exit $2, got $1)"; fi
}
check_file() { # FILE LABEL — FILE must exist
  [[ -f "$1" ]] && pass "$2" || fail_ "$2 (missing: $1)"
}
check_no_file() { # FILE LABEL — FILE must not exist
  [[ -f "$1" ]] && fail_ "$2 (still there: $1)" || pass "$2"
}

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ETC="$TMP/etc"
SHARE="$TMP/share"
ROOT="$TMP/root"  # OMARCHY_KIDS_ROOT
HOMES="$TMP/home" # OMARCHY_KIDS_HOMES_BASE
STUBS="$TMP/stubs"
# The kid's uid is this test user's own: lib/data.py's fold step opens
# the runtime log O_NOFOLLOW and refuses it unless the open descriptor is
# a regular file owned by that kid (review §3.3), and the fixture files
# are owned by whoever runs the suite.
KID_UID="$(id -u)"

mkdir -p "$SHARE/bands" "$SHARE/packs" "$ETC/kids" "$HOMES/kid-ada/.config/chromium/Default" "$STUBS"
cp "$DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$DIR"/share/packs/*.toml "$SHARE/packs/"

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada Lovelace
avatar=fox
band=6-8
EOF

# --- stub `id` — data_kid_uid's only dependency, and the one thing that
# now answers "which account am I?" for require_root_or_self and the root
# gates (review §3.6/§3.7). Default: a caller who is neither root nor the
# kid; $KIDS_TEST_ACCOUNT / $KIDS_TEST_UID name the two other callers.
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
kids_id_stub "$STUBS" kid-ada "$KID_UID"
kids_tree "$TMP/tree" "$DIR"
LEDGER="$TMP/tree/bin/omarchy-kids-time-ledger"
kids_set_const "$LEDGER" ETC "$ETC"
kids_set_const "$LEDGER" SYSROOT "$ROOT"
LAUNCHER_CTL="$TMP/tree/bin/omarchy-kids-launcher-ctl"
kids_set_const "$LAUNCHER_CTL" CONTROL "$ROOT/run/user/$KID_UID/omarchy-kids/launcher-control"
kids_set_const "$LAUNCHER_CTL" LAUNCHES_LOG "$ROOT/run/user/$KID_UID/omarchy-kids/launches.log"
export KIDS_TEST_ACCOUNT="not-a-kid"

# --- stub `loginctl` — no live sessions; the ledger's own tick logic is
# test/shell.d/time-test.sh's job, this file only cares about the fold
# step tick also runs. -------------------------------------------------

cat >"$STUBS/loginctl" <<'EOF'
#!/bin/bash
[[ "$1" == "list-sessions" ]] && exit 0
exit 1
EOF
chmod +x "$STUBS/loginctl"

export PATH="$STUBS:$PATH"
export OMARCHY_KIDS_ETC="$ETC"
export OMARCHY_KIDS_SHARE="$SHARE"
export OMARCHY_KIDS_ROOT="$ROOT"
export OMARCHY_KIDS_HOMES_BASE="$HOMES"
# Root is claimed through the `id` stub for the root-only steps (tick,
# retention --apply); everything else runs as "not-a-kid" so the real
# gate is exercised.

RUNTIME_LOG="$ROOT/run/user/$KID_UID/omarchy-kids/launches.log"
ROOT_LOG="$ROOT/var/lib/omarchy-kids/kid-ada/launches.log"
USAGE_DIR="$ROOT/var/lib/omarchy-kids/kid-ada/usage"

# make_history PYFILE — builds a fixture Chromium History db at PYFILE
# (urls: url, title, visit_count, last_visit_time in WebKit epoch us
# since 1601-01-01, per this issue's own "Chromium facts"). Five rows,
# spread across "today", hours ago, and "long ago", so --since and
# retention-adjacent filtering both have something to bite on; one has an
# empty title and one an ESC control character (both real Chromium row
# states a page controls) to pin the row parse and the control stripping.
make_history() {
  local db="$1"
  python3 - "$db" <<'PY'
import sqlite3, sys, datetime
db = sys.argv[1]
conn = sqlite3.connect(db)
conn.execute(
    "CREATE TABLE urls (id INTEGER PRIMARY KEY, url TEXT, title TEXT, "
    "visit_count INTEGER, last_visit_time INTEGER)"
)
def webkit(dt):
    return int((dt - datetime.datetime(1601, 1, 1)).total_seconds() * 1_000_000)
now = datetime.datetime(2026, 9, 2, 9, 30, 0)
rows = [
    ("https://wikipedia.org/wiki/Cat", "Cat - Wikipedia", 3, webkit(now)),
    ("https://wikipedia.org/wiki/Dog", "Dog - Wikipedia", 1, webkit(now - datetime.timedelta(hours=1))),
    ("https://example.com/old", "An old page", 2, webkit(datetime.datetime(2025, 1, 1))),
    ("https://no-title.example/", "", 1, webkit(now - datetime.timedelta(hours=2))),
    ("https://escape.example/", "evil\x1b[2Ktitle", 1, webkit(now - datetime.timedelta(hours=3))),
]
conn.executemany(
    "INSERT INTO urls (url, title, visit_count, last_visit_time) VALUES (?, ?, ?, ?)", rows
)
conn.commit()
conn.close()
PY
}

# =========================================================================
# --help
# =========================================================================

out="$("$DATA" --help 2>&1)"
st=$?
check_status "$st" 0 "--help exits 0"
check_contains "$out" "Usage: omarchy-kids-data" "--help prints usage"
"$DATA" >/dev/null 2>&1
check_status "$?" 2 "no command exits 2"
"$DATA" launches >/dev/null 2>&1
check_status "$?" 2 "launches with no kid exits 2"

out="$("$LAUNCHER_CTL" --help 2>&1)"
st=$?
check_status "$st" 0 "launcher-ctl --help exits 0"
check_contains "$out" "log ID" "launcher-ctl --help documents log"

echo

# =========================================================================
# launcher-ctl log — the kid-writable half
# =========================================================================

export XDG_RUNTIME_DIR="$ROOT/run/user/$KID_UID"

OMARCHY_KIDS_NOW="2026-09-02 09:00:00" "$LAUNCHER_CTL" log tuxpaint
OMARCHY_KIDS_NOW="2026-09-02 09:05:00" "$LAUNCHER_CTL" log gcompris
check_status "$?" 0 "launcher-ctl log exits 0"
check "$(wc -l <"$RUNTIME_LOG" | tr -d '[:space:]')" "2" "log: two launches, two lines"
check_contains "$(cat "$RUNTIME_LOG")" "2026-09-02T09:00:00 tuxpaint" "log: naive local timestamp, no embedded space"
check_contains "$(cat "$RUNTIME_LOG")" "2026-09-02T09:05:00 gcompris" "log: second launch recorded too"

"$LAUNCHER_CTL" log >/dev/null 2>&1
check_status "$?" 2 "log: refuses with no app id"

echo

# =========================================================================
# time-ledger tick folds the runtime log into the root-owned one, deduped
# =========================================================================

check_no_file "$ROOT_LOG" "before any tick: no root-owned launches.log yet"

OMARCHY_KIDS_NOW="2026-09-02 09:06:00" KIDS_TEST_UID=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$ROOT_LOG" | tr -d '[:space:]')" "2" "tick: folds both existing launches"

OMARCHY_KIDS_NOW="2026-09-02 09:07:00" KIDS_TEST_UID=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$ROOT_LOG" | tr -d '[:space:]')" "2" "tick: a second tick with nothing new folds nothing again (deduped by offset)"

OMARCHY_KIDS_NOW="2026-09-02 09:08:00" "$LAUNCHER_CTL" log blinken
OMARCHY_KIDS_NOW="2026-09-02 09:09:00" KIDS_TEST_UID=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$ROOT_LOG" | tr -d '[:space:]')" "3" "tick: a third launch is folded on the next tick"
check_contains "$(cat "$ROOT_LOG")" "blinken" "tick: the new line's content made it into the root log"

# A fresh login gets a fresh (smaller) runtime tmpfs -- the fold must
# not treat that as corruption, just start over from byte 0.
: >"$RUNTIME_LOG"
OMARCHY_KIDS_NOW="2026-09-02 10:00:00" "$LAUNCHER_CTL" log kanagram
OMARCHY_KIDS_NOW="2026-09-02 10:01:00" KIDS_TEST_UID=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$ROOT_LOG" | tr -d '[:space:]')" "4" "tick: a fresh (shrunk) runtime file after a new login still folds"
check_contains "$(cat "$ROOT_LOG")" "kanagram" "tick: the post-relogin launch made it in"

# A re-login's fresh runtime file is not guaranteed to be *smaller* --
# a kid who launches several tiles fast enough could recreate one at
# least as big as the old offset before the next tick runs. Recreate
# the path outright (rm, not truncate: a real new login gets a new
# tmpfs file, a new inode at the same path) with content that starts
# past the old byte offset, so a size-only check would wrongly treat
# it as "nothing new before this point" and silently drop the start of
# the new session's own log.
rm -f "$RUNTIME_LOG"
OMARCHY_KIDS_NOW="2026-09-02 11:00:00" "$LAUNCHER_CTL" log supertuxkart
OMARCHY_KIDS_NOW="2026-09-02 11:01:00" "$LAUNCHER_CTL" log gcompris
OMARCHY_KIDS_NOW="2026-09-02 11:02:00" KIDS_TEST_UID=0 "$LEDGER" tick >/dev/null
check "$(wc -l <"$ROOT_LOG" | tr -d '[:space:]')" "6" "tick: a same-path re-login (new inode, not smaller) still folds from its own start"
check_contains "$(cat "$ROOT_LOG")" "11:00:00 supertuxkart" "tick: the new session's first line is whole, not sliced off by the old offset"
check_contains "$(cat "$ROOT_LOG")" "11:01:00 gcompris" "tick: the new session's second line made it in too"

echo

# =========================================================================
# launches — reads the root-owned log
# =========================================================================

# The launch log is a record about a kid, for their parent: 0640
# root:omarchy-parents, and `launches` is root-or-self, so a sibling
# can't read it any more (review §3.7).
"$DATA" launches kid-ada >/dev/null 2>&1
check_status "$?" 1 "launches: refuses for a non-root, non-self caller"

out="$(KIDS_TEST_UID=0 "$DATA" launches kid-ada)"
check_contains "$out" "app launches" "launches: header line"
check_contains "$out" "tuxpaint" "launches: shows tuxpaint"
check_contains "$out" "kanagram" "launches: shows the most recent one too"

out="$(KIDS_TEST_UID=0 OMARCHY_KIDS_NOW="2026-09-02 10:05:00" "$DATA" launches kid-ada --since 1)"
check_contains "$out" "kanagram" "launches --since 1: still shows today's launch"

out="$(KIDS_TEST_UID=0 OMARCHY_KIDS_NOW="2026-09-10 10:05:00" "$DATA" launches kid-ada --since 1)"
check_contains "$out" "No app launches recorded" "launches --since 1: nothing in the last day, a week later"

KIDS_TEST_UID=0 "$DATA" launches kid-ada --since abc >/dev/null 2>&1
check_status "$?" 2 "launches --since: rejects a non-numeric value"

out="$(KIDS_TEST_UID=0 "$DATA" launches kid-nobody)"
check_contains "$out" "No app launches recorded" "launches: an unknown kid just reads as empty, not an error"

echo

# =========================================================================
# sites — reads a copy of the kid's Chromium History
# =========================================================================

HISTORY="$HOMES/kid-ada/.config/chromium/Default/History"
make_history "$HISTORY"

out="$(KIDS_TEST_ACCOUNT=kid-ada "$DATA" sites kid-ada)"
check_contains "$out" "sites visited" "sites: header line (running as the kid needs no root)"
check_contains "$out" "wikipedia.org" "sites: shows wikipedia.org"
check_contains "$out" "3 visits" "sites: shows the visit count"
check_contains "$out" "example.com" "sites: shows the old page too, with no --since"
check_contains "$out" "(no title) (1 visit)" \
  "sites: an empty page title shows the fallback with its own visit count (no field shift)"
check_not_contains "$out" $'\x1b' \
  "sites: a control character in a page title never reaches the parent's terminal"

out="$(KIDS_TEST_ACCOUNT=kid-ada OMARCHY_KIDS_NOW="2026-09-02 10:00:00" "$DATA" sites kid-ada --since 30)"
check_contains "$out" "wikipedia.org" "sites --since 30: recent visits still show"
check_not_contains "$out" "example.com" "sites --since 30: the year-old visit is filtered out"

"$DATA" sites kid-ada >/dev/null 2>&1
check_status "$?" 1 "sites: refuses for a non-root, non-self caller"
out="$("$DATA" sites kid-ada 2>&1 >/dev/null)"
check_contains "$out" "needs root" "sites: explains why it refused"

out="$(KIDS_TEST_UID=0 "$DATA" sites kid-ada)"
check_contains "$out" "wikipedia.org" "sites: root reads it too"

echo

# =========================================================================
# history_visible=no (R-DATA-4): sites says so, needs no privilege at all
# =========================================================================

"$CONF" set kid-ada history_visible no >/dev/null

out="$("$DATA" sites kid-ada)"
check_status "$?" 0 "sites: history_visible=no exits 0, not an error"
check_contains "$out" "not visible" "sites: says history isn't visible"
check_not_contains "$out" "wikipedia.org" "sites: no site data leaks through when it's off"

"$CONF" set kid-ada history_visible yes >/dev/null

echo

# =========================================================================
# summary
# =========================================================================

mkdir -p "$USAGE_DIR"
echo 23 >"$USAGE_DIR/2026-09-01"
echo 5 >"$USAGE_DIR/2026-09-02"

out="$(KIDS_TEST_ACCOUNT=kid-ada OMARCHY_KIDS_NOW="2026-09-02 10:00:00" "$DATA" summary kid-ada)"
check_contains "$out" "today (2026-09-02)" "summary: today's date"
check_contains "$out" "minutes used: 5" "summary: today's minutes"
check_contains "$out" "top apps:" "summary: top apps section present"
check_contains "$out" "gcompris" "summary: gcompris shows among today's top apps"
check_contains "$out" "top sites:" "summary: top sites section present (running as the kid)"
check_contains "$out" "wikipedia.org" "summary: wikipedia.org among today's top sites"

out="$(KIDS_TEST_ACCOUNT=kid-ada OMARCHY_KIDS_NOW="2026-09-02 10:00:00" "$DATA" summary kid-ada --week)"
check_contains "$out" "minutes per day (last 7 days)" "summary --week: header"
check_contains "$out" "2026-09-01: 23 min" "summary --week: yesterday's minutes"
check_contains "$out" "2026-09-02: 5 min" "summary --week: today's minutes"
check_contains "$out" "total: 28 min" "summary --week: total across the week"

out="$(OMARCHY_KIDS_NOW="2026-09-02 10:00:00" "$DATA" summary kid-ada)"
check_contains "$out" "run as root, or as kid-ada" "summary: without root or self, top sites explains why it's missing"
check_not_contains "$out" "wikipedia.org" "summary: no site data leaks through without privilege"
check_contains "$out" "minutes used: 5" "summary: minutes still show with no privilege at all"

"$CONF" set kid-ada history_visible no >/dev/null
out="$(OMARCHY_KIDS_NOW="2026-09-02 10:00:00" "$DATA" summary kid-ada)"
check_contains "$out" "history_visible=no" "summary: history_visible=no explains itself, needs no root check at all"
"$CONF" set kid-ada history_visible yes >/dev/null

echo

# =========================================================================
# mine — K5, "What my grown-ups can see"
# =========================================================================

out="$(KIDS_TEST_ACCOUNT=kid-ada OMARCHY_KIDS_NOW="2026-09-02 10:00:00" "$DATA" mine)"
check_contains "$out" "What my grown-ups can see" "mine: title"
check_contains "$out" "What you asked for" "mine: names the Ask a parent record (R-DATA-1/3)"
check_contains "$out" "1 year" "mine: states the minutes retention"
check_contains "$out" "90 days" "mine: states the launches retention"
check_contains "$out" "websites you visit" "mine: mentions browsing history when it's visible"
check_contains "$out" "Since: 2026-09-01" "mine: since-date is the earliest day on file"
check_contains "$out" "Your last day's summary (2026-09-02)" "mine: last day's summary is the most recent day on file"
check_contains "$out" "minutes used: 5" "mine: last day's summary shows real minutes"
check_contains "$out" "Nothing you type" "mine: R-DATA-2's never-list, in plain words"

"$CONF" set kid-ada history_visible no >/dev/null
out="$(KIDS_TEST_ACCOUNT=kid-ada "$DATA" mine)"
check_contains "$out" "turned OFF website history" "mine: says plainly when history is off (R-DATA-4)"
check_not_contains "$out" "websites you visit. Kept" "mine: doesn't claim to show history when it's off"
"$CONF" set kid-ada history_visible yes >/dev/null

echo

# =========================================================================
# retention
# =========================================================================

# A day well past the 1-year usage cutoff and the 90-day launches/
# requests cutoff, plus one recent day of each, so a run can tell old
# from new. A stale .grant sibling too -- it shares the same date-named
# pruning rule as its plain usage file (lib/time.sh's own convention).
echo 10 >"$USAGE_DIR/2024-01-01"
echo 5 >"$USAGE_DIR/2024-01-01.grant"
printf '2024-01-01T09:00:00 oldapp\n' >>"$ROOT_LOG"

QUEUE_DIR="$ROOT/var/lib/omarchy-kids/queue"
mkdir -p "$QUEUE_DIR"
OLD_TS=1700000000 # 2023-11-14, well past 90 days before this suite's "now"
NEW_TS=1893000000 # near this suite's fixture "now" (2026-09-02-ish)
echo '{"kid":"kid-ada"}' >"$QUEUE_DIR/${OLD_TS}-kid-ada-time.json"
echo '{"kid":"kid-ada"}' >"$QUEUE_DIR/${NEW_TS}-kid-ada-time.json"

# The kid's own copies of decisions (R-NOTIFY-6) share the queue's timestamp and
# its 90 days: the stale one goes with the stale record, the recent one stays.
DEC_DIR="$ROOT/var/lib/omarchy-kids/kid-ada/decisions"
mkdir -p "$DEC_DIR"
echo '{"kid":"kid-ada"}' >"$DEC_DIR/${OLD_TS}-kid-ada-time.json"
echo '{"kid":"kid-ada"}' >"$DEC_DIR/${NEW_TS}-kid-ada-time.json"
echo '{"kid":"kid-ada"}' >"$DEC_DIR/not-a-timestamp.json"

"$DATA" retention >/dev/null 2>&1
check_status "$?" 1 "retention: refuses without root"

export KIDS_TEST_UID=0 # the rest of this section is the root-only retention path
NOW="2026-09-02 10:00:00"

out="$(OMARCHY_KIDS_NOW="$NOW" "$DATA" retention)"
check_contains "$out" "2024-01-01" "retention (dry-run): names the stale usage day"
check_contains "$out" "launches.log" "retention (dry-run): names the launches log it would rewrite"
check_file "$USAGE_DIR/2024-01-01" "retention (dry-run): nothing was actually removed"
check "$(wc -l <"$ROOT_LOG" | tr -d '[:space:]')" "7" "retention (dry-run): launches.log untouched"
nreq=0
for f in "$QUEUE_DIR"/*.json; do [[ -e "$f" ]] && nreq=$((nreq + 1)); done
check "$nreq" "2" "retention (dry-run): queue untouched"

OMARCHY_KIDS_NOW="$NOW" "$DATA" retention --apply >/dev/null

check_no_file "$USAGE_DIR/2024-01-01" "retention --apply: the year-old usage day is gone"
check_no_file "$USAGE_DIR/2024-01-01.grant" "retention --apply: its .grant sibling is gone too"
check_file "$USAGE_DIR/2026-09-01" "retention --apply: recent usage days are kept"
check_not_contains "$(cat "$ROOT_LOG")" "oldapp" "retention --apply: the 2024 launch line is pruned"
check_contains "$(cat "$ROOT_LOG")" "kanagram" "retention --apply: recent launch lines are kept"
check_no_file "$QUEUE_DIR/${OLD_TS}-kid-ada-time.json" "retention --apply: the stale request is pruned"
check_file "$QUEUE_DIR/${NEW_TS}-kid-ada-time.json" "retention --apply: the recent request is kept"
check_no_file "$DEC_DIR/${OLD_TS}-kid-ada-time.json" "retention --apply: the stale kid copy is pruned"
check_file "$DEC_DIR/${NEW_TS}-kid-ada-time.json" "retention --apply: the recent kid copy is kept"
check_file "$DEC_DIR/not-a-timestamp.json" "retention --apply: a copy with no timestamp in its name is kept"

# Chromium's own History db is never touched by retention (R-DATA-1:
# "the browser's own retention") -- it should be untouched, byte for
# byte, by anything above.
check_file "$HISTORY" "retention: never touches the Chromium History db"

echo "data-test RESULT: $([[ $fail == 0 ]] && echo PASS || echo FAIL)"
exit $fail
