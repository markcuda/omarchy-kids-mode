#!/bin/bash
# Tests bin/omarchy-kids-ask (SPEC.md R-ASK-1..3, Appendix D; issue #25):
# the kid-side modal launcher, submit writing into a kid's own outbox,
# root-side collect/list/approve/decline, and static syntax checks for
# systemd/omarchy-kids-ask-collect.{service,timer} (systemd-analyze may
# not be installed here, so those checks are text/parse-only, same as
# test/shell.d/pkgbuild-test.sh's approach to the pacman hook).
#
# share/ask/shell.qml itself is UNTESTED here, same as share/exit-modal/
# shell.qml in test/shell.d/exit-test.sh's own header -- no Quickshell in
# this environment. This file only checks the bash side: what env vars
# it's launched with, and what it's expected to call back into.
#
# Fully self-contained: quickshell and pgrep are fakes on a stub PATH;
# omarchy-kids-conf, -web and -time are fakes placed in the scratch tree
# beside the command under test. All of them only log their argv and fake
# just enough state to react to -- the same shape as
# test/shell.d/exit-test.sh's and apps-test.sh's stub() helper.
# One provisioned kid throughout: kid-ada, band 6-8 (AGENTS.md rule 9);
# a second, kid-bo, only where two-kids-at-once matters (collect).
set -uo pipefail

# shellcheck source=test/shell.d/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
BIN="" # a copy in a scratch tree: omarchy-kids-conf / -web are resolved
# beside it now, so their stubs are placed there, not exported.

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP ask-test.sh: python3 not found"
  exit 0
fi

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
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want to find '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STUBS="$TMP/stubs"
LOG="$TMP/argv.log"
SHARE="$TMP/share"
ETC="$TMP/etc"
VARLIB_ROOT="$TMP/sysroot"       # OMARCHY_KIDS_ROOT
RUN_USER_ROOT="$TMP/run-user"    # OMARCHY_KIDS_RUN_USER_ROOT
CONF_STORE="$TMP/conf-store.tsv" # fake omarchy-kids-conf's backing store
QUEUE_DIR="$VARLIB_ROOT/var/lib/omarchy-kids/queue"

mkdir -p "$STUBS" "$SHARE/ask" "$ETC/kids" "$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox" \
  "$RUN_USER_ROOT/1001/omarchy-kids/ask-outbox"
touch "$LOG" "$SHARE/ask/shell.qml" "$CONF_STORE"

# `collect` resolves who owned an outbox from the uid in its path, not from
# the record's own `kid` field (review S2). OMARCHY_KIDS_UID_MAP stands in
# for `getent passwd` here; it is read from root's environment, never a
# kid's. The kid registry is the second gate: an outbox whose owner has no
# profile is skipped entirely.
UID_MAP="$TMP/uid-map"
printf '1000:kid-ada\n1001:kid-bo\n1002:not-a-kid\n' >"$UID_MAP"
printf 'band=6-8\n' >"$ETC/kids/kid-ada.conf"
printf 'band=6-8\n' >"$ETC/kids/kid-bo.conf"

# stub NAME EXTRA -- see test/shell.d/exit-test.sh for the full rationale.
stub() {
  local name="$1" extra="${2:-}" f="$STUBS/$1"
  cat >"$f" <<'EOF'
#!/bin/bash
{ printf '%s' "__NAME__"; printf ' %s' "$@"; printf '\n'; } >> "__ARGVLOG__"
EOF
  [[ -n "$extra" ]] && printf '%s\n' "$extra" >>"$f"
  echo 'exit 0' >>"$f"
  sed -i.bak -e "s#__NAME__#$name#g" -e "s#__ARGVLOG__#$LOG#g" -e "s#__STORE__#$CONF_STORE#g" "$f"
  rm -f "$f.bak"
  chmod +x "$f"
}

stub quickshell
stub pgrep 'exit 1' # "not found" by default: no modal already up

# omarchy-kids-conf get/set, backed by a flat "kid\tkey\tvalue" append
# log (last line for a kid/key wins) -- just enough to fake apps.extra
# and band lookups without a real /etc/omarchy-kids tree.
# shellcheck disable=SC2016
stub omarchy-kids-conf '
case "$1" in
  get)
    val="$(awk -F"\t" -v k="$2" -v key="$3" "\$1==k && \$2==key {v=\$3} END{print v}" "__STORE__")"
    printf "%s\n" "$val"
    ;;
  set)
    printf "%s\t%s\t%s\n" "$2" "$3" "$4" >> "__STORE__"
    ;;
esac
'
stub omarchy-kids-web ''

kids_tree "$TMP/tree" "$ROOT_DIR"
BIN="$TMP/tree/bin/omarchy-kids-ask"
cp "$STUBS/omarchy-kids-conf" "$STUBS/omarchy-kids-web" "$TMP/tree/bin/"

# omarchy-kids-time is a sibling too, resolved beside the command under
# test, so its stub goes in the tree, not on PATH.
time_stub() {
  stub omarchy-kids-time ''
  cp "$STUBS/omarchy-kids-time" "$TMP/tree/bin/"
}
time_stub_gone() { rm -f "$STUBS/omarchy-kids-time" "$TMP/tree/bin/omarchy-kids-time"; }

# The verifier socket is a constant now: point this copy at one that will
# never exist, so the suite can never reach a real daemon.
kids_set_const "$BIN" AUTH_SOCK "$TMP/no.sock"

# `id -un`, not $OMARCHY_KIDS_ACCOUNT: which kid this is, is not settable
# from the environment any more (review §3.7).
kids_id_stub "$STUBS" kid-ada 1000

# Only the stubs and a base toolset: an Omarchy box has the real
# omarchy-*/omarchy-kids-* commands on PATH, and a check that one is
# missing must not depend on this box (AGENTS.md, testing rules).
BASE_PATH="$(kids_base_path "$TMP/base")"
export PATH="$STUBS:$BASE_PATH"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$BIN" SHARE "$SHARE"
kids_set_const "$BIN" SYSROOT "$VARLIB_ROOT"
kids_set_const "$BIN" RUN "$RUN_USER_ROOT/1000/omarchy-kids"
kids_set_const "$BIN" RUN_USER_ROOT "$RUN_USER_ROOT"
kids_set_const "$BIN" UID_MAP "$UID_MAP"
kids_set_const "$BIN" QUICKSHELL_BIN "$STUBS/quickshell"

argv_since() { tail -n "+$(($1 + 1))" "$LOG"; }
argv_lines() { wc -l <"$LOG" | tr -d ' '; }

# =====================================================================
# --help / bad command
# =====================================================================

"$BIN" --help >/dev/null 2>&1
check_eq "$?" 0 "--help exits 0"
"$BIN" nonsense >/dev/null 2>&1
check_eq "$?" 2 "an unknown command exits 2"

# =====================================================================
# Kid-side: time/app/plugin/site open the modal with kid-words env
# =====================================================================

"$BIN" time 15 >/dev/null 2>&1
argv="$(cat "$LOG")"
check_contains "$argv" "quickshell -p $SHARE/ask/shell.qml" "time: execs quickshell with the ask modal path"

cat >"$STUBS/quickshell" <<'EOF'
#!/bin/bash
{
  echo "OMARCHY_KIDS_ACCOUNT=$OMARCHY_KIDS_ACCOUNT"
  echo "OMARCHY_KIDS_ASK_KIND=$OMARCHY_KIDS_ASK_KIND"
  echo "OMARCHY_KIDS_ASK_WHAT=$OMARCHY_KIDS_ASK_WHAT"
  echo "OMARCHY_KIDS_ASK_DESC=$OMARCHY_KIDS_ASK_DESC"
  echo "OMARCHY_KIDS_ASK_MINUTES=$OMARCHY_KIDS_ASK_MINUTES"
} > "$OMARCHY_KIDS_TEST_ENV_DUMP"
EOF
chmod +x "$STUBS/quickshell"

ENV_DUMP="$TMP/env-dump"
OMARCHY_KIDS_TEST_ENV_DUMP="$ENV_DUMP" "$BIN" time 15 >/dev/null 2>&1
env_out="$(cat "$ENV_DUMP" 2>/dev/null || true)"
check_contains "$env_out" "OMARCHY_KIDS_ACCOUNT=kid-ada" "time: exports OMARCHY_KIDS_ACCOUNT"
check_contains "$env_out" "OMARCHY_KIDS_ASK_KIND=time" "time: exports kind=time"
check_contains "$env_out" "OMARCHY_KIDS_ASK_WHAT=15" "time: exports what=15"
check_contains "$env_out" "OMARCHY_KIDS_ASK_MINUTES=15" "time: exports minutes=15"
check_contains "$env_out" "15 more minute" "time: description is in kid words"

: >"$ENV_DUMP"
OMARCHY_KIDS_TEST_ENV_DUMP="$ENV_DUMP" "$BIN" app "minecraft" >/dev/null 2>&1
env_out="$(cat "$ENV_DUMP" 2>/dev/null || true)"
check_contains "$env_out" "OMARCHY_KIDS_ASK_KIND=app" "app: exports kind=app"
check_contains "$env_out" "OMARCHY_KIDS_ASK_WHAT=minecraft" "app: exports what=minecraft"

: >"$ENV_DUMP"
OMARCHY_KIDS_TEST_ENV_DUMP="$ENV_DUMP" "$BIN" site "roblox.com" >/dev/null 2>&1
env_out="$(cat "$ENV_DUMP" 2>/dev/null || true)"
check_contains "$env_out" "OMARCHY_KIDS_ASK_KIND=site" "site: exports kind=site"
check_contains "$env_out" "OMARCHY_KIDS_ASK_WHAT=roblox.com" "site: exports what=roblox.com"

: >"$ENV_DUMP"
OMARCHY_KIDS_TEST_ENV_DUMP="$ENV_DUMP" "$BIN" plugin "weather-widget" >/dev/null 2>&1
env_out="$(cat "$ENV_DUMP" 2>/dev/null || true)"
check_contains "$env_out" "OMARCHY_KIDS_ASK_KIND=plugin" "plugin: exports kind=plugin"

stub quickshell # restore the plain argv-logging stub

# --- time: needs a positive whole number -----------------------------

"$BIN" time 0 >/dev/null 2>&1
check_eq "$?" 2 "time 0: refused"
"$BIN" time -5 >/dev/null 2>&1
check_eq "$?" 2 "time -5: refused"
"$BIN" time banana >/dev/null 2>&1
check_eq "$?" 2 "time banana: refused"

# --- already open: never execs quickshell again -----------------------

# A modal is tracked by a pidfile now, not by `pgrep -f "quickshell -p
# <path>"` -- which matched any process a kid could start with that string
# in its argv (review §1.9). A stale pid never blocks it.
MODAL_RUN="$TMP/kid-runtime"
mkdir -p "$MODAL_RUN"
printf '999999\n' >"$MODAL_RUN/ask-modal.pid"
before="$(argv_lines)"
kids_set_const "$BIN" RUN "$MODAL_RUN"
"$BIN" time 5 >/dev/null 2>&1
if grep -qE '^quickshell ' < <(argv_since "$before"); then
  pass "time: a stale modal pidfile never blocks the modal"
else
  fail "time: a stale modal pidfile blocked the modal"
fi
rm -f "$MODAL_RUN/ask-modal.pid"

before="$(argv_lines)"
"$BIN" time 5 >/dev/null 2>&1
st=$?
check_eq "$st" 0 "time: opening the modal exits 0"
[[ -s "$MODAL_RUN/ask-modal.pid" ]] && pass "time: the modal records its own pid" ||
  fail "time: the modal pidfile was not written"
rm -rf "$MODAL_RUN"

# =====================================================================
# submit: writes one Appendix D record into the kid's OWN outbox
# =====================================================================

OUTBOX_ADA="$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox"

kids_set_const "$BIN" RUN "$RUN_USER_ROOT/1000/omarchy-kids"
"$BIN" submit time 20 --minutes 20 >/dev/null
files=("$OUTBOX_ADA"/*-kid-ada-time.json)
check_eq "${#files[@]}" 1 "submit (open): writes exactly one record"
rec="${files[0]}"
check_contains "$(cat "$rec")" '"kid": "kid-ada"' "submit (open): kid field"
check_contains "$(cat "$rec")" '"state": "open"' "submit (open): state=open"
check_contains "$(cat "$rec")" '"minutes": 20' "submit (open): minutes=20"
check_not_contains "$(cat "$rec")" '"by"' "submit (open): no 'by' yet -- undecided"
rm -f "$rec"

# --- review S1: `submit` has no way to write a decision at all -----------

"$BIN" submit app firefox >/dev/null
files=("$OUTBOX_ADA"/*-kid-ada-app.json)
check_eq "${#files[@]}" 1 "submit: writes exactly one record"
rec="${files[0]}"
check_contains "$(cat "$rec")" '"state": "open"' "submit: every record is open, never a decision"
check_not_contains "$(cat "$rec")" '"by"' "submit: no 'by' -- nobody in this session decided anything"
check_contains "$(cat "$rec")" '"what": "firefox"' "submit: what=firefox"
rm -f "$rec"

for bad in --state --by; do
  "$BIN" submit app firefox "$bad" approved >/dev/null 2>&1
  check_eq "$?" 2 "submit: $bad is not an argument this command has (review S1)"
done
# ...and lib/ask.py itself refuses to write one, whatever calls it.
python3 "$ROOT_DIR/lib/ask.py" write "$OUTBOX_ADA" --kid kid-ada --kind app --what evil --state approved >/dev/null 2>&1
check_eq "$?" 2 "ask.py write: --state is gone from the writer entirely"

"$BIN" submit bogus-kind something >/dev/null 2>&1
check_eq "$?" 2 "submit: an unknown kind is refused"

# =====================================================================
# collect: dry-run previews, never moves anything
# =====================================================================

cat >"$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000000-kid-ada-time.json" <<'EOF'
{"kid": "kid-ada", "kind": "time", "what": "10", "minutes": 10, "asked_at": 1000000000, "state": "open"}
EOF

out="$("$BIN" collect)"
check_contains "$out" "dry-run" "collect (default): previews only"
[[ -e "$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000000-kid-ada-time.json" ]] &&
  pass "collect (default): outbox file left in place" ||
  fail "collect (default): outbox file must not move without --apply"
[[ -d "$QUEUE_DIR" && -n "$(find "$QUEUE_DIR" -name '*.json' 2>/dev/null)" ]] &&
  fail "collect (default): must not create a queue record" ||
  pass "collect (default): queue stays empty"

# =====================================================================
# collect --apply: promotes outbox records to OPEN, and nothing else
# =====================================================================
#
# Review S1/S2/S3, all three at once. collect is a mover, not a decider:
# whatever a kid writes into their own outbox becomes an open, undecided
# request attributed to the account that actually owned the outbox.

rm -f "$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000000-kid-ada-time.json" # the dry-run fixture above

# kid-ada, band 6-8 (for the site case below)
printf 'kid-ada\tband\t6-8\n' >>"$CONF_STORE"
printf 'kid-bo\tband\t6-8\n' >>"$CONF_STORE"

# An honest open request.
cat >"$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000001-kid-ada-time.json" <<'EOF'
{"kid": "kid-ada", "kind": "time", "what": "10", "minutes": 10, "asked_at": 1000000001, "state": "open"}
EOF
# S1: the whole attack. A kid writes state=approved into their own outbox
# and waits <=60s for the collect timer. Root used to grant it on sight.
cat >"$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000002-kid-ada-app.json" <<'EOF'
{"kid": "kid-ada", "kind": "app", "what": "minecraft", "asked_at": 1000000002, "state": "approved", "decided_at": 1000000002, "by": "keyboard"}
EOF
# S2: kid-bo's outbox, claiming to be kid-ada, pre-approved.
cat >"$RUN_USER_ROOT/1001/omarchy-kids/ask-outbox/1000000003-kid-bo-site.json" <<'EOF'
{"kid": "kid-ada", "kind": "site", "what": "roblox.com", "asked_at": 1000000003, "state": "approved", "decided_at": 1000000003, "by": "keyboard"}
EOF
# S3: root path traversal through the same field.
cat >"$RUN_USER_ROOT/1001/omarchy-kids/ask-outbox/1000000006-evil-site.json" <<'EOF'
{"kid": "../../../../etc/sudoers.d", "kind": "site", "what": "kid-ada ALL=(ALL) NOPASSWD: ALL", "asked_at": 1000000006, "state": "approved", "by": "keyboard"}
EOF

time_stub # installed here: a time grant COULD apply
before="$(argv_lines)"
out="$("$BIN" collect --apply)"
after_argv="$(argv_since "$before")"

check_contains "$out" "3 request(s) collected" "collect --apply: collects the three well-formed records"
check_contains "$out" "1 dropped" "collect --apply: drops the one that fails the allowlist"
check_not_contains "$out" "applied" "collect --apply: never reports applying anything (review S1)"

[[ -e "$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000001-kid-ada-time.json" ]] &&
  fail "collect --apply: must empty kid-ada's outbox" ||
  pass "collect --apply: kid-ada's outbox is empty afterward"
[[ -e "$RUN_USER_ROOT/1001/omarchy-kids/ask-outbox/1000000003-kid-bo-site.json" ]] &&
  fail "collect --apply: must empty kid-bo's outbox" ||
  pass "collect --apply: kid-bo's outbox is empty afterward"

# S1: not one of the pre-approved records was acted on, and none is approved.
check_not_contains "$after_argv" "time grant" "S1: collect never grants time"
check_not_contains "$after_argv" "apps.extra" "S1: collect never writes apps.extra"
check_not_contains "$after_argv" "omarchy-kids-web install" "S1: collect never re-installs a web policy"
for f in "$QUEUE_DIR"/*.json; do
  [[ -e "$f" ]] || continue
  check_not_contains "$(cat "$f")" '"approved"' "S1: $(basename "$f") landed open, not approved"
done

check_contains "$(cat "$QUEUE_DIR/1000000001-kid-ada-time.json")" '"state": "open"' \
  "collect --apply: an open record stays open"

# S2: the record kid-bo wrote claiming to be kid-ada is now kid-bo's.
check_contains "$(cat "$QUEUE_DIR/1000000003-kid-bo-site.json")" '"kid": "kid-bo"' \
  "S2: the kid field is re-derived from the outbox owner, not read from the file"

# R-NOTIFY-7: the queue and its records are the parent's, not the world's.
check_eq "$(kids_file_mode "$QUEUE_DIR")" "750" "queue directory is 0750 (R-NOTIFY-7)"
for f in "$QUEUE_DIR"/*.json; do
  [[ -e "$f" ]] || continue
  check_eq "$(kids_file_mode "$f")" "640" "queue record $(basename "$f") is 0640 (R-NOTIFY-7)"
  check_eq "$(kids_file_gid "$f")" "$(kids_file_gid "$QUEUE_DIR")" \
    "queue record $(basename "$f") takes the queue directory's group (R-NOTIFY-7)"
done

# S3: the path-like kid never reached the queue, and root created nothing.
[[ -e "$QUEUE_DIR/1000000006-evil-site.json" ]] &&
  fail "S3: a record with a path-like kid must never be queued" ||
  pass "S3: a record with a path-like kid is dropped, not queued"
[[ -e "$TMP/etc/sudoers.d" ]] &&
  fail "S3: root created a directory outside the kid tree" ||
  pass "S3: no directory was created outside the kid tree"

[[ -f "$ETC/kids/kid-bo/allow.txt" ]] && fail "S1: collect wrote allow.txt without a parent deciding" ||
  pass "S1: collect wrote no allow.txt"

# An outbox owned by an account with no profile is skipped entirely.
mkdir -p "$RUN_USER_ROOT/1002/omarchy-kids/ask-outbox"
cat >"$RUN_USER_ROOT/1002/omarchy-kids/ask-outbox/1000000007-x-app.json" <<'EOF'
{"kid": "kid-ada", "kind": "app", "what": "minecraft", "asked_at": 1000000007, "state": "open"}
EOF
err="$("$BIN" collect --apply 2>&1 >/dev/null)"
check_contains "$err" "is not a provisioned kid" "collect: an outbox owned by a non-kid is skipped"
[[ -e "$QUEUE_DIR/1000000007-x-app.json" ]] &&
  fail "collect: a non-kid's outbox must not reach the queue" ||
  pass "collect: a non-kid's outbox never reaches the queue"
rm -rf "$RUN_USER_ROOT/1002"

# a second collect on an empty set of outboxes is a harmless no-op
out2="$("$BIN" collect --apply)"
check_contains "$out2" "0 request(s) collected" "collect --apply: idempotent once outboxes are empty"

# =====================================================================
# apply-grant: omarchy-kids-authd's root callback (review S1)
# =====================================================================

rm -f "$QUEUE_DIR"/*.json # a clean queue for the sections below
rm -rf "$ETC/kids/kid-bo"

# apply-grant is root-only, with no environment escape any more: a
# scratch root used to satisfy that check too (review §3.6). The `id`
# stub is how this suite claims root, the same way it claims to be a kid.
"$BIN" apply-grant --kid kid-ada --kind app --what minecraft --apply >/dev/null 2>&1
check_eq "$?" 2 "apply-grant: refuses a non-root caller even with a scratch root"
export KIDS_TEST_UID=0

before="$(argv_lines)"
"$BIN" apply-grant --kid kid-ada --kind app --what minecraft --apply >/dev/null
after_argv="$(argv_since "$before")"
check_contains "$after_argv" "omarchy-kids-conf set kid-ada apps.extra minecraft" \
  "apply-grant: performs the action through the same apply path collect used to"
granted="$(grep -l '"what": "minecraft"' "$QUEUE_DIR"/*.json | tail -1)"
check_contains "$(cat "$granted")" '"state": "approved"' "apply-grant: records the decision in the queue"
check_contains "$(cat "$granted")" '"by": "keyboard"' "apply-grant: by=keyboard (the on-the-spot path)"

before="$(argv_lines)"
"$BIN" apply-grant --kid kid-bo --kind site --what roblox.com --apply >/dev/null
after_argv="$(argv_since "$before")"
check_contains "$after_argv" "omarchy-kids-web install 6-8 --allow" "apply-grant: applies a site grant"
check_contains "$after_argv" "--apply" "apply-grant: re-installs the web policy for real"
check_contains "$(cat "$ETC/kids/kid-bo/allow.txt")" "roblox.com" "apply-grant: records the site in allow.txt"

# R-NOTIFY-6: root drops the result where the kid's own session reads it.
KID_DEC="$VARLIB_ROOT/var/lib/omarchy-kids/kid-ada/decisions"
dfile="$(ls "$KID_DEC"/*.json 2>/dev/null | head -1)"
[[ -n "$dfile" ]] && pass "apply-grant: writes a kid decision file (R-NOTIFY-6)" ||
  fail "apply-grant: no kid decision file was written"
if [[ -n "$dfile" ]]; then
  check_eq "$(kids_file_mode "$dfile")" "640" "kid decision file is 0640 (R-NOTIFY-6)"
  check_eq "$(kids_file_gid "$dfile")" "$(kids_file_gid "$KID_DEC")" \
    "kid decision file takes the decisions directory's group"
  check_contains "$(cat "$dfile")" '"state": "approved"' "kid decision file records the approval"
fi
check_eq "$(kids_file_mode "$KID_DEC")" "750" "kid decisions directory is 0750 (R-NOTIFY-6)"

# Everything the allowlist refuses, refused again at the root entry point.
for args in \
  "--kid ../../../../etc/sudoers.d --kind site --what evil.com" \
  "--kid kid-ada --kind site --what ../../etc/passwd" \
  "--kid kid-ada --kind app --what .hidden" \
  "--kid kid-ada --kind time --what 99999 --minutes 99999" \
  "--kid kid-nobody --kind app --what minecraft"; do
  # shellcheck disable=SC2086
  "$BIN" apply-grant $args --apply >/dev/null 2>&1
  check_eq "$?" 2 "apply-grant refuses: $args"
done

unset KIDS_TEST_UID

# =====================================================================
# grant: the kid-side client refuses a bad request before it is sent
# =====================================================================
#
# There is no verifier socket in this suite, so a well-formed grant fails
# at the connect. A malformed one must fail earlier, without ever putting
# the typed password on a socket.

out="$(printf 'hunter2\n' |
  "$BIN" grant site "../../etc/passwd" 2>&1)"
st=$?
check_eq "$st" 2 "grant: a path-like host is refused before anything is sent"
check_contains "$out" "rejected before it was sent" "grant: says the request never left the session"

out="$(printf 'hunter2\n' |
  "$BIN" grant app minecraft 2>&1)"
st=$?
check_eq "$st" 1 "grant: no verifier reachable means no grant"
check_not_contains "$out" "hunter2" "grant: the typed password is never echoed"

# =====================================================================
# the modal cannot approve anything on its own
# =====================================================================

ASK_QML="$ROOT_DIR/share/ask/shell.qml"
check_not_contains "$(cat "$ASK_QML")" '"--state"' \
  "share/ask/shell.qml never passes --state (review S1)"
check_not_contains "$(cat "$ASK_QML")" '"approved"' \
  "share/ask/shell.qml never writes the word approved"
check_contains "$(cat "$ASK_QML")" '"grant"' \
  "share/ask/shell.qml goes through the root grant path instead"

# An honest open request, for the `list`/approve sections below.
time_stub
cat >"$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000009-kid-ada-time.json" <<'EOF'
{"kid": "kid-ada", "kind": "time", "what": "10", "minutes": 10, "asked_at": 1000000009, "state": "open"}
EOF
"$BIN" collect --apply >/dev/null
time_stub_gone

# approve/decline are root-only entry points; `list` reads through the queue's
# own permissions (R-NOTIFY-7): it works for whoever can read the queue and
# refuses when they cannot. The test user owns the scratch queue, so it works;
# an unreadable queue (a kid's case) is refused.
for subcommand in approve decline; do
  "$BIN" "$subcommand" no-such-id >/dev/null 2>&1
  check_eq "$?" 1 "$subcommand: refuses a non-root caller at entry"
done
"$BIN" list >/dev/null 2>&1
check_eq "$?" 0 "list: works when the queue is readable (the test user owns it)"
if [[ "${EUID:-0}" -ne 0 ]]; then
  chmod 0000 "$QUEUE_DIR"
  "$BIN" list >/dev/null 2>&1
  check_eq "$?" 1 "list: refuses when the queue is not readable (a kid's case, R-NOTIFY-7)"
  chmod 0750 "$QUEUE_DIR"
else
  pass "list: running as root, so the unreadable-queue assertion is skipped (root reads any queue)"
fi
# A fresh box has no queue; that is an empty queue, not an error.
mv "$QUEUE_DIR" "$QUEUE_DIR.absent"
out="$("$BIN" list 2>&1)"
check_eq "$?" 0 "list: an absent queue exits 0 (fresh box)"
check_contains "$out" "no open requests" "list: an absent queue says so"
mv "$QUEUE_DIR.absent" "$QUEUE_DIR"
export KIDS_TEST_UID=0

# =====================================================================
# list: only open (undecided) requests, all kids or one
# =====================================================================

out="$("$BIN" list)"
check_contains "$out" "kid-ada" "list: shows kid-ada's open request"
check_contains "$out" "time" "list: shows the kind"
check_not_contains "$out" "minecraft" "list: never shows an already-decided (approved) record"

out_ada="$("$BIN" list kid-ada)"
check_contains "$out_ada" "kid-ada" "list kid-ada: shows kid-ada"

out_bo="$("$BIN" list kid-bo)"
check_contains "$out_bo" "no open requests" "list kid-bo: nothing open for kid-bo"

# =====================================================================
# approve / decline: one keystroke, act on an id from `list`
# =====================================================================

id="1000000009-kid-ada-time" # the still-open time request from above

before="$(argv_lines)"
"$BIN" approve "$id" >/dev/null
check_contains "$(cat "$QUEUE_DIR/$id.json")" '"state": "open"' \
  "approve (default, no --apply): does not decide yet"

time_stub # back in place for the approve/decline checks
"$BIN" approve "$id" --apply >/dev/null
after_argv="$(argv_since "$before")"
check_contains "$after_argv" "time grant kid-ada 10" "approve --apply: performs the action (time grant)"
rec="$(cat "$QUEUE_DIR/$id.json")"
check_contains "$rec" '"state": "approved"' "approve --apply: marks the record approved"
check_contains "$rec" '"by": "panel"' "approve --apply: by=panel (a human, from the panel, decided this one)"

"$BIN" approve "$id" --apply >/dev/null 2>&1
check_eq "$?" 2 "approve: an already-decided id is refused"

"$BIN" approve "no-such-id" --apply >/dev/null 2>&1
check_eq "$?" 2 "approve: an unknown id is refused"

# decline: marks declined, never performs the action
cat >"$QUEUE_DIR/1000000005-kid-ada-site.json" <<'EOF'
{"kid": "kid-ada", "kind": "site", "what": "example.com", "asked_at": 1000000005, "state": "open"}
EOF
before="$(argv_lines)"
"$BIN" decline "1000000005-kid-ada-site" --apply >/dev/null
after_argv="$(argv_since "$before")"
check_not_contains "$after_argv" "example.com" "decline --apply: never touches allow.txt or web"
check_contains "$(cat "$QUEUE_DIR/1000000005-kid-ada-site.json")" '"state": "declined"' \
  "decline --apply: marks the record declined"
check_contains "$(cat "$QUEUE_DIR/1000000005-kid-ada-site.json")" '"by": "panel"' \
  "decline --apply: by=panel"

# =====================================================================
# static: systemd/omarchy-kids-ask-collect.{service,timer}
# =====================================================================

SERVICE="$ROOT_DIR/systemd/omarchy-kids-ask-collect.service"
TIMER="$ROOT_DIR/systemd/omarchy-kids-ask-collect.timer"

if [[ -f "$SERVICE" ]]; then
  pass "omarchy-kids-ask-collect.service exists"
  grep -qE '^\[Service\]' "$SERVICE" && pass "service: has [Service]" || fail "service: missing [Service]"
  grep -qE '^Type=oneshot' "$SERVICE" && pass "service: Type=oneshot" || fail "service: missing Type=oneshot"
  grep -qE '^ExecStart=.*omarchy-kids-ask collect --apply' "$SERVICE" &&
    pass "service: ExecStart runs 'omarchy-kids-ask collect --apply'" ||
    fail "service: ExecStart does not run collect --apply"
else
  fail "$SERVICE not found"
fi

if [[ -f "$TIMER" ]]; then
  pass "omarchy-kids-ask-collect.timer exists"
  grep -qE '^\[Timer\]' "$TIMER" && pass "timer: has [Timer]" || fail "timer: missing [Timer]"
  grep -qE '^OnUnitActiveSec=1min' "$TIMER" && pass "timer: fires every minute" || fail "timer: missing OnUnitActiveSec=1min"
  grep -qE '^Unit=omarchy-kids-ask-collect\.service' "$TIMER" &&
    pass "timer: points at omarchy-kids-ask-collect.service" ||
    fail "timer: missing/wrong Unit="
  grep -qE '^\[Install\]' "$TIMER" && pass "timer: has [Install]" || fail "timer: missing [Install]"
  grep -qE '^WantedBy=timers\.target' "$TIMER" && pass "timer: WantedBy=timers.target" || fail "timer: missing WantedBy=timers.target"
else
  fail "$TIMER not found"
fi

if command -v systemd-analyze >/dev/null 2>&1; then
  if systemd-analyze verify "$SERVICE" "$TIMER" >/dev/null 2>&1; then
    pass "systemd-analyze verify: service + timer are syntactically valid"
  else
    fail "systemd-analyze verify: service or timer failed verification"
  fi
else
  pass "systemd-analyze not available here -- static [Section]/key checks above stand in for it"
fi

# --- PKGBUILD installs the timer, and share/ask ---------------------------

PKGBUILD="$ROOT_DIR/PKGBUILD"
if [[ -f "$PKGBUILD" ]]; then
  pkg_body="$(sed -n '/^package()/,/^}/p' "$PKGBUILD")"
  grep -qE 'systemd/\*\.timer' <<<"$pkg_body" &&
    pass "PKGBUILD: package() installs systemd/*.timer" ||
    fail "PKGBUILD: package() does not install *.timer"
  grep -qE 'cp -a share/\.' <<<"$pkg_body" &&
    pass "PKGBUILD: package() copies all of share/ (covers share/ask/)" ||
    fail "PKGBUILD: package() does not copy share/ wholesale"
else
  fail "$PKGBUILD not found"
fi

[[ -f "$ROOT_DIR/share/ask/shell.qml" ]] && pass "share/ask/shell.qml exists" || fail "share/ask/shell.qml missing"


# --- grant time <n>: the minutes travel in <what> (seen live: rejected before it was sent) ---
out="$(printf 'pw\n' | "$BIN" grant time 7 2>&1)"
st=$?
check_not_contains "$out" "rejected before it was sent" "grant time 7 carries minutes into the request"
[[ $st -ne 0 ]] && pass "grant time 7 fails only on the missing verifier" || fail "grant time 7 should not succeed without a verifier"

# share/ask/shell.qml: the empty password field says whose password is wanted
# (live review, 2026-09-21 -- same fix as the exit modal).
check_contains "$(cat "$ROOT_DIR/share/ask/shell.qml")" '"Your password"' \
  "the ask modal's empty field says whose password is wanted"

# --- reply validation (Appendix D): printable and bounded at read time -------

python3 "$ROOT_DIR/lib/ask.py" write "$QUEUE_DIR" --kid kid-ada --kind time --what 5 --minutes 5 >/dev/null
reply_rec="$(ls -t "$QUEUE_DIR"/*.json 2>/dev/null | head -1)"
python3 "$ROOT_DIR/lib/ask.py" decide "$reply_rec" --state declined --by panel \
  --reply "$(printf 'a%.0s' $(seq 1 81))" >/dev/null 2>&1
check_eq "$?" 2 "decide: an over-long reply is refused (Appendix D)"
python3 "$ROOT_DIR/lib/ask.py" decide "$reply_rec" --state declined --by panel \
  --reply "$(printf 'bad\treply')" >/dev/null 2>&1
check_eq "$?" 2 "decide: a control character in the reply is refused (Appendix D)"
python3 "$ROOT_DIR/lib/ask.py" decide "$reply_rec" --state declined --by panel \
  --reply "After dinner" >/dev/null 2>&1
check_eq "$?" 0 "decide: a valid reply is accepted"
check_contains "$(cat "$reply_rec")" '"reply": "After dinner"' "decide: the reply is stored"

# --- R-NOTIFY-7: a record takes the queue directory's group, not the writer's --
# The N-1 blocking fix. Observable: point the queue at a *secondary* group of
# the test user, collect, and check the record took that group -- a record that
# kept the writer's primary group (the bug) would show it. /usr/bin/id, not the
# stubbed PATH id.
if [[ "${EUID:-0}" -ne 0 ]]; then
  real_id=/usr/bin/id
  pgid="$("$real_id" -g 2>/dev/null || true)"
  sgid=""
  for g in $("$real_id" -G 2>/dev/null || true); do
    [[ "$g" == "$pgid" ]] || {
      sgid="$g"
      break
    }
  done
else
  sgid=""
fi
if [[ -n "$sgid" ]]; then
  rm -f "$QUEUE_DIR"/*.json 2>/dev/null || true
  chgrp "$sgid" "$QUEUE_DIR" 2>/dev/null || true
  cat >"$RUN_USER_ROOT/1000/omarchy-kids/ask-outbox/1000000099-kid-ada-time.json" <<'EOF'
{"kid": "kid-ada", "kind": "time", "what": "5", "minutes": 5, "asked_at": 1000000099, "state": "open"}
EOF
  "$BIN" collect --apply >/dev/null 2>&1
  f="$(ls "$QUEUE_DIR"/1000000099-*.json 2>/dev/null | head -1)"
  if [[ -n "$f" ]]; then
    # Assert against the directory's group as it stands (collect's own
    # queue_ensure_dir may chgrp to omarchy-parents where that group exists),
    # and only bite when it differs from the writer's primary group.
    dir_gid="$(kids_file_gid "$QUEUE_DIR")"
    if [[ "$dir_gid" != "$pgid" ]]; then
      check_eq "$(kids_file_gid "$f")" "$dir_gid" \
        "queue record takes the directory's (non-primary) group (R-NOTIFY-7)"
    else
      pass "queue group: the queue kept the primary group (no omarchy-parents here); nothing to observe"
    fi
  else
    fail "queue group test: collect wrote no record"
  fi
else
  pass "queue group: no secondary group (or run as root); skipping the observable-group assertion"
fi

echo "ask-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
