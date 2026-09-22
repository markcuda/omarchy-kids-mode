#!/bin/bash
# Tests bin/omarchy-kids-plugins (SPEC.md R-APPS-7, I-3, I-6; issue #28):
# the shelf's category+verified filtering, the --band age-floor filter,
# --all's warning, --json, and install/remove's argv (runuser -l <kid>
# -c "omarchy-plugin-add/-remove ..." then an apps.extra edit).
#
# Fully self-contained, per AGENTS.md rule 8: `runuser` is a fake on a
# stub PATH that actually execs its -c command (so the omarchy-plugin-add/
# -remove stubs underneath it run too, same shape
# test/shell.d/apps-test.sh's stub() helper uses for pacman). The real
# `jq` and `omarchy-kids-conf` are used -- neither needs faking. One
# provisioned kid throughout: kid-ada, band 6-8, per AGENTS.md rule 9's
# fixture convention.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGINS="$DIR/bin/omarchy-kids-plugins"
CONF="$DIR/bin/omarchy-kids-conf"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP plugins-test.sh: jq not found"
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

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ETC="$TMP/etc"
IDX="$TMP/idx/index.json"
STUBS="$TMP/stubs"
LOG="$TMP/log"
ARGV_LOG="$LOG/argv.log"

mkdir -p "$ETC/kids" "$TMP/idx" "$STUBS" "$LOG"
touch "$ARGV_LOG"

cat >"$ETC/kids/kid-ada.conf" <<'EOF'
name=Ada Lovelace
avatar=fox
band=6-8
EOF

# --- fixture marketplace index (shaped like omarchy-plugin-marketplace's
# site/catalog.json -- see docs/plugins.md's "What 'the marketplace
# catalog' actually is" for the real fields this is drawn from) -----------
cat >"$IDX" <<'EOF'
{
  "generatedAt": "2026-09-02T00:00:00.000Z",
  "plugins": [
    {
      "id": "kidmath",
      "name": "Kid Math",
      "description": "Fun arithmetic drills for early readers.",
      "author": "example",
      "category": "Kids",
      "tags": ["education", "kids"],
      "verificationStatus": "verified",
      "installAvailable": true,
      "installCommand": "omarchy plugin add https://github.com/example/kidmath.git --enable",
      "repo": "https://github.com/example/kidmath",
      "age": "3-5"
    },
    {
      "id": "kidpaint",
      "name": "Kid Paint",
      "description": "A simple drawing pad.",
      "author": "example",
      "category": "Kids",
      "tags": ["kids"],
      "verificationStatus": "unverified",
      "installAvailable": true,
      "installCommand": "omarchy plugin add https://github.com/example/kidpaint.git --enable",
      "repo": "https://github.com/example/kidpaint",
      "age": "6-8"
    },
    {
      "id": "kidquiz",
      "name": "Kid Quiz",
      "description": "Trivia for older kids.",
      "author": "example",
      "category": "Kids",
      "tags": ["education"],
      "verificationStatus": "verified",
      "installAvailable": true,
      "installCommand": "omarchy plugin add https://github.com/example/kidquiz.git --enable",
      "repo": "https://github.com/example/kidquiz",
      "age": "9-12"
    },
    {
      "id": "noage",
      "name": "No Age Recorded",
      "description": "A verified Kids plugin with no age floor.",
      "author": "example",
      "category": "Kids",
      "tags": [],
      "verificationStatus": "verified",
      "installAvailable": true,
      "installCommand": "omarchy plugin add https://github.com/example/noage.git --enable",
      "repo": "https://github.com/example/noage"
    },
    {
      "id": "numage",
      "name": "Numeric Age",
      "description": "Age recorded as a bare number, not a band string.",
      "author": "example",
      "category": "Kids",
      "tags": [],
      "verificationStatus": "verified",
      "installAvailable": true,
      "installCommand": "omarchy plugin add https://github.com/example/numage.git --enable",
      "repo": "https://github.com/example/numage",
      "age": 5
    },
    {
      "id": "notkids",
      "name": "Not A Kids Plugin",
      "description": "Wrong category entirely.",
      "author": "example",
      "category": "Widgets",
      "tags": [],
      "verificationStatus": "verified",
      "installAvailable": true,
      "installCommand": "omarchy plugin add https://github.com/example/notkids.git --enable",
      "repo": "https://github.com/example/notkids"
    },
    {
      "id": "noinstall",
      "name": "Not Installable",
      "description": "Suite-shaped, no single install command.",
      "author": "example",
      "category": "Kids",
      "tags": [],
      "verificationStatus": "verified",
      "installAvailable": false,
      "installCommand": "",
      "repo": "https://github.com/example/noinstall"
    }
  ]
}
EOF

# --- stub PATH: runuser really execs its -c command (so the
# omarchy-plugin-add/-remove stubs underneath run too), those two just
# log their own argv --------------------------------------------------

stub() { # stub NAME EXTRA
  local name="$1" extra="${2:-}" f="$STUBS/$1"
  cat >"$f" <<'EOF'
#!/bin/bash
{ printf '%s' "__NAME__"; printf ' %s' "$@"; printf '\n'; } >> "__ARGVLOG__"
EOF
  [[ -n "$extra" ]] && printf '%s\n' "$extra" >>"$f"
  echo 'exit 0' >>"$f"
  sed -i.bak -e "s#__NAME__#$name#g" -e "s#__ARGVLOG__#$ARGV_LOG#g" "$f"
  rm -f "$f.bak"
  chmod +x "$f"
}

# shellcheck disable=SC2016
stub runuser '
if [[ "$1" == "-l" && "$3" == "-c" ]]; then
    bash -c "$4"
fi
'
stub omarchy-plugin-add ''
stub omarchy-plugin-remove ''

export PATH="$STUBS:$PATH"
export OMARCHY_KIDS_ETC="$ETC"
export OMARCHY_KIDS_PLUGIN_INDEX="$IDX"

argv_since() { tail -n "+$(($1 + 1))" "$ARGV_LOG"; } # LINE_COUNT -> lines appended since
argv_lines() { wc -l <"$ARGV_LOG" | tr -d ' '; }

# --- shelf: category Kids AND verified only, by default -------------------

out="$("$PLUGINS" shelf)"
check_contains "$out" "kidmath" "shelf: verified Kids plugin (kidmath) is listed"
check_contains "$out" "kidquiz" "shelf: another verified Kids plugin (kidquiz) is listed"
check_contains "$out" "noage" "shelf: a verified Kids plugin with no age floor is listed"
check_not_contains "$out" "kidpaint" "shelf: unverified Kids plugin (kidpaint) is NOT listed by default"
check_not_contains "$out" "notkids" "shelf: wrong-category plugin is never listed"
check_not_contains "$out" "noinstall" "shelf: installAvailable=false plugin is never listed"

# --- shelf --all: unverified Kids listings too, with a warning ------------

out_all="$("$PLUGINS" shelf --all)"
check_contains "$out_all" "--all:" "shelf --all: prints the warning line"
check_contains "$out_all" "kidmath" "shelf --all: still lists the verified one"
check_contains "$out_all" "kidpaint" "shelf --all: also lists the unverified one"
check_not_contains "$out_all" "notkids" "shelf --all: still never lists the wrong category"

out_default="$("$PLUGINS" shelf)"
check_not_contains "$out_default" "--all:" "shelf (no --all): no warning line"

# --- shelf --band: keeps entries at/below the band's age floor; an
# entry with no age floor is never filtered out -----------------------

out_35="$("$PLUGINS" shelf --band 3-5)"
check_contains "$out_35" "kidmath" "shelf --band 3-5: age-3-5 entry (kidmath) is kept"
check_contains "$out_35" "noage" "shelf --band 3-5: entry with no age floor is always kept"
check_not_contains "$out_35" "kidquiz" "shelf --band 3-5: age-9-12 entry (kidquiz) is filtered out"

out_1312="$("$PLUGINS" shelf --band 13+)"
check_contains "$out_1312" "kidmath" "shelf --band 13+: age-3-5 entry is kept (below the floor)"
check_contains "$out_1312" "kidquiz" "shelf --band 13+: age-9-12 entry is kept (at/below the floor)"

"$PLUGINS" shelf --band nope-such-band >/dev/null 2>&1
check_status "$?" 2 "shelf --band: an unknown band is refused"

# --- shelf --json: valid JSON, right fields, band filter still applies ----

json_out="$("$PLUGINS" shelf --json)"
check "$(jq -e 'type' <<<"$json_out" 2>/dev/null)" '"array"' "shelf --json: prints a JSON array"
check "$(jq -r '. | length' <<<"$json_out")" "4" "shelf --json: four verified Kids entries by default"
check "$(jq -r '.[] | select(.id=="kidmath") | .verified' <<<"$json_out")" "true" \
  "shelf --json: kidmath's verified field is true"
check "$(jq -r '.[] | select(.id=="kidmath") | .age' <<<"$json_out")" "3-5" \
  "shelf --json: kidmath carries its age hint"
check "$(jq -r '.[] | select(.id=="noage") | .age' <<<"$json_out")" "" \
  "shelf --json: a no-age entry's empty age does not shift the next field into it"
check "$(jq -r '.[] | select(.id=="noage") | .verified' <<<"$json_out")" "true" \
  "shelf --json: a no-age entry is still verified (fields did not shift)"
check "$(jq -r '.[] | select(.id=="numage") | .age' <<<"$json_out")" "5" \
  "shelf --json: a numeric age is kept, not dropped (gsub coerces to string)"
check "$(jq -r '.[] | select(.id=="numage") | .verified' <<<"$json_out")" "true" \
  "shelf --json: a numeric-age entry is still verified"
check_not_contains "$out" "https://github.com/example/noage" \
  "shelf table: the repo URL never leaks into the VERIFIED column"
check_not_contains "$json_out" "--all:" "shelf --json: never prints the --all warning line, even with --all"

json_35="$("$PLUGINS" shelf --json --band 3-5)"
check "$(jq -r '. | length' <<<"$json_35")" "3" "shelf --json --band 3-5: kidmath + noage + numage"

# --- shelf: a missing index is not an error --------------------------------

out_missing="$(OMARCHY_KIDS_PLUGIN_INDEX="$TMP/idx/does-not-exist.json" "$PLUGINS" shelf)"
check_status "$?" 0 "shelf: a missing index file exits 0"
check_contains "$out_missing" "nothing on the shelf" "shelf: a missing index file says so plainly"

# --- install: refuses an unverified plugin, never touches runuser or
# apps.extra ----------------------------------------------------------------

before="$(argv_lines)"
err="$("$PLUGINS" install kidpaint --kid kid-ada --apply 2>&1 >/dev/null)"
check_status "$?" 2 "install: an unverified plugin is refused"
check_contains "$err" "not verified" "install: refusal names why (unverified)"
after_argv="$(argv_since "$before")"
check "$after_argv" "" "install (refused): runuser is never called"
check "$("$CONF" get kid-ada apps.extra)" "" "install (refused): apps.extra is untouched"

# --- install: refuses a wrong-category / not-installable / unknown id -----

"$PLUGINS" install notkids --kid kid-ada --apply >/dev/null 2>&1
check_status "$?" 2 "install: a wrong-category id is refused"

"$PLUGINS" install noinstall --kid kid-ada --apply >/dev/null 2>&1
check_status "$?" 2 "install: installAvailable=false is refused"

"$PLUGINS" install not-on-the-index --kid kid-ada --apply >/dev/null 2>&1
check_status "$?" 2 "install: an id not on the index at all is refused"

# --- install: refuses a kid who isn't provisioned --------------------------

"$PLUGINS" install kidmath --kid not-a-real-kid --apply >/dev/null 2>&1
check_status "$?" 2 "install: an unprovisioned kid is refused"

# --- install: default only previews; never calls runuser or edits
# apps.extra -----------------------------------------------------------

before="$(argv_lines)"
out="$("$PLUGINS" install kidmath --kid kid-ada)"
check_status "$?" 0 "install (default, no --apply): exits 0"
check_contains "$out" "dry-run" "install (default, no --apply): reports dry-run"
after_argv="$(argv_since "$before")"
check "$after_argv" "" "install (default, no --apply): runuser is never called"
check "$("$CONF" get kid-ada apps.extra)" "" "install (default, no --apply): apps.extra is untouched"

# --- install --apply: installs into the kid's own account, then adds
# the id to apps.extra -------------------------------------------------

before="$(argv_lines)"
"$PLUGINS" install kidmath --kid kid-ada --apply >/dev/null
after_argv="$(argv_since "$before")"
check_contains "$after_argv" "runuser -l kid-ada -c" "install --apply: runs Omarchy's installer as the kid (runuser -l)"
check_contains "$after_argv" "omarchy-plugin-add https://github.com/example/kidmath.git --enable --yes" \
  "install --apply: omarchy-plugin-add gets the .git repo URL, --enable --yes"
check "$("$CONF" get kid-ada apps.extra)" "kidmath" "install --apply: apps.extra now has the plugin id"

# idempotent: installing the same plugin again doesn't duplicate apps.extra
"$PLUGINS" install kidmath --kid kid-ada --apply >/dev/null
check "$("$CONF" get kid-ada apps.extra)" "kidmath" "install --apply: installing twice doesn't duplicate apps.extra"

# --- remove --apply: the reverse, drops the id from apps.extra -------------

before="$(argv_lines)"
"$PLUGINS" remove kidmath --kid kid-ada --apply >/dev/null
after_argv="$(argv_since "$before")"
check_contains "$after_argv" "runuser -l kid-ada -c" "remove --apply: runs as the kid (runuser -l)"
check_contains "$after_argv" "omarchy-plugin-remove kidmath --yes" \
  "remove --apply: omarchy-plugin-remove gets the plain id, --yes"
check "$("$CONF" get kid-ada apps.extra)" "" "remove --apply: apps.extra no longer has the plugin id"

# a removed-but-never-installed plugin is a harmless no-op on apps.extra
"$PLUGINS" remove kidmath --kid kid-ada --apply >/dev/null
check_status "$?" 0 "remove --apply: removing an already-absent plugin id is a harmless no-op"

# --- R-APPS-7 / AGENTS.md rule 3: no plugin may enforce anything, and
# this command never makes one responsible for a lock. A plugin installs
# into the kid's own unprivileged $HOME (via `runuser -l`, checked
# above) and nothing here ever touches /etc/polkit-1, /etc/sudoers.d, or
# the R-APPS-6 "parents only" fence's own 0750 root:omarchy-parents
# pattern -- a static grep against this command's own source, so a
# future edit that starts writing one of those can't land silently. -----

check_not_contains "$(cat "$PLUGINS")" "polkit" \
  "bin/omarchy-kids-plugins never mentions polkit (no plugin becomes a lock)"
check_not_contains "$(cat "$PLUGINS")" "sudoers" \
  "bin/omarchy-kids-plugins never mentions sudoers (no plugin becomes a lock)"
check_not_contains "$(cat "$PLUGINS")" "omarchy-parents" \
  "bin/omarchy-kids-plugins never writes the parents-only fence"

# --- --help exits 0 and mentions every verb --------------------------------

help_out="$("$PLUGINS" --help)"
check_status "$?" 0 "--help exits 0"
check_contains "$help_out" "shelf" "--help mentions shelf"
check_contains "$help_out" "install" "--help mentions install"
check_contains "$help_out" "remove" "--help mentions remove"

exit $fail
