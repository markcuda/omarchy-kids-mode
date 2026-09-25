#!/bin/bash
# Tests bin/omarchy-kids-wizard (SPEC.md R-WIZ-1..9; issue #19: the Easy
# path). Drives the whole flow through OMARCHY_KIDS_TUI_ANSWERS, with gum
# faked on a stub PATH (same convention as test/shell.d/tui-test.sh: it
# logs nothing interesting itself here, since --dry-run means the wizard's
# own `run_priv`/`run_priv_stdin` print every command instead of ever
# calling sudo, pacman, omarchy-kids-provision, -web, -assert, or -session
# -- so what this checks is the *text* those wrappers print, not a stub's
# argv log. Fakes for those six are still put on PATH as a safety net (a
# code path that ever ran one for real would hit a fake, not the real
# thing), but --dry-run never reaches them, which is exactly the point:
# nothing here ever touches the real /etc, /var, /home, or invokes a real
# pacman or sudo (AGENTS.md rule 8).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
BIN="" # a copy in a scratch tree per stub set: the wizard resolves
# every sibling command beside itself now (AGENTS.md, "The trust
# boundary"), so each fake is placed there rather than exported.

# wizard_for STUBDIR [AUTH_SOCK] — prints the path of a wizard copy whose
# siblings are STUBDIR's fakes and whose verifier socket is AUTH_SOCK (by
# default one that cannot exist, so no run here can ever reach a real
# omarchy-kids-authd -- on the VM there is one). Both are build-time
# constants in a copy, never environment overrides.
wizard_for() {
  local stubs="$1" tree="$1.tree" sock f
  sock="${2:-$stubs/no-such-auth.sock}"
  kids_tree "$tree" "$DIR"
  for f in "$stubs"/omarchy-kids-*; do
    [[ -e "$f" ]] && cp "$f" "$tree/bin/"
  done
  mv "$tree/bin/omarchy-kids-conf" "$tree/bin/omarchy-kids-conf.real"
  cat >"$tree/bin/omarchy-kids-conf" <<EOF
#!/bin/bash
set -euo pipefail
if [[ "\${1:-}" == machine && "\${2:-}" == get && "\${3:-}" == boot ]]; then
  printf '%s\n' "\${WIZARD_TEST_BOOT_MODE:?wizard fixture boot mode is unset}"
else
  exec "$tree/bin/omarchy-kids-conf.real" "\$@"
fi
EOF
  chmod +x "$tree/bin/omarchy-kids-conf"
  kids_set_const "$tree/bin/omarchy-kids-wizard" AUTH_SOCK "$sock"
  kids_set_const "$tree/bin/omarchy-kids-parent-auth" DEFAULT_SOCK "$sock"
  printf '%s\n' "$tree/bin/omarchy-kids-wizard"
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP wizard-test.sh: python3 not found (needed by omarchy-kids-conf)"
  exit 0
fi

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want to find '$2' in output)"; fi
}
check_not_contains() { # haystack needle label
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (did not want '$2' in output)"; fi
}
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
check_status() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want exit $2, got $1)"; fi
}

TMP="$(mktemp -d)"
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# --- scratch tree: real bands.toml/packs, scratch everything else ------

ETC="$TMP/etc/omarchy-kids"
SHARE="$TMP/share/omarchy-kids"
STUBS="$TMP/stubs"
ARGV_LOG="$TMP/argv.log"
mkdir -p "$ETC/kids" "$SHARE/bands" "$SHARE/packs" "$SHARE/avatars" "$STUBS"
cp "$DIR/share/bands/bands.toml" "$SHARE/bands/"
cp "$DIR"/share/packs/*.toml "$SHARE/packs/"
cp "$DIR"/share/avatars/*.svg "$SHARE/avatars/"
: >"$ARGV_LOG"

# issue #53: a scratch $HOME (so theme_current_name never reads whatever
# real Omarchy theme this dev/CI box happens to have, AGENTS.md rule 8)
# with a current theme set, plus a scratch system themes dir
# ($OMARCHY_PATH/themes) with two installed names for the Desktop group's
# theme row to pick from.
export HOME="$TMP/home"
mkdir -p "$HOME/.local/state/omarchy/current/theme"
echo tokyo-night >"$HOME/.local/state/omarchy/current/theme.name"
export OMARCHY_PATH="$TMP/omarchy"
mkdir -p "$OMARCHY_PATH/themes/tokyo-night" "$OMARCHY_PATH/themes/catppuccin-latte"

# Fake gum: same convention as test/shell.d/tui-test.sh's own fake --
# only needed here so lib/tui.sh's header rendering has something to
# call; every actual answer in this file comes from OMARCHY_KIDS_TUI_ANSWERS,
# never from gum.
cat >"$STUBS/gum" <<'EOF'
#!/bin/bash
case "${1:-}" in
    style)
        shift
        seen=0
        text=()
        for a in "$@"; do
            [[ $seen == 1 ]] && text+=("$a")
            [[ "$a" == "--" ]] && seen=1
        done
        if ((${#text[@]} == 0)); then
            while IFS= read -r line; do text+=("$line"); done
        fi
        ((${#text[@]})) && printf '%s\n' "${text[@]}"
        ;;
    *) exit 0 ;;
esac
EOF

cat >"$STUBS/omarchy-kids-parent-auth" <<'EOF'
#!/bin/bash
read -r candidate || candidate=""
[[ "$candidate" == "${CORRECT_PW:-parentpw123}" ]]
EOF

# Fakes for every command the Apply step (or prefetch) might shell out to:
# each just logs its own argv, one line, to $ARGV_LOG, so a dry run can be
# told apart from a run that actually reached one of these.
for name in omarchy-kids-provision omarchy-kids-web omarchy-kids-assert omarchy-kids-session omarchy-kids-apps pacman sudo; do
  cat >"$STUBS/$name" <<EOF
#!/bin/bash
echo "$name \$*" >>"$ARGV_LOG"
cat >/dev/null
exit 0
EOF
done
chmod +x "$STUBS"/*

export PATH="$STUBS:$PATH"
export WIZARD_TEST_BOOT_MODE=portal
export OMARCHY_KIDS_ETC="$ETC"
export OMARCHY_KIDS_SHARE="$SHARE"
BIN="$(wizard_for "$STUBS")"
# The EXIT cleanup must clear the in-memory parent candidate, not only stop
# background work. Keep this as a source-level contract because the process
# exits before a child test can inspect its shell variables.
cleanup_body="$(sed -n '/^cleanup() {/,/^}/p' "$DIR/bin/omarchy-kids-wizard")"
check_contains "$cleanup_body" 'PARENT_PASSWORD=""' \
  "wizard EXIT cleanup clears the parent password"
check_contains "$(grep '^trap ' "$DIR/bin/omarchy-kids-wizard")" 'cleanup' \
  "wizard EXIT trap runs secret cleanup"
# This hostile value must not affect Apply. The expected identity is the
# process's real account, read the same way the wizard reads it.
EXPECTED_INVOKING_USER="$(id -un)"
export OMARCHY_KIDS_INVOKING_USER="forged-parent"
export DRY_RUN=1

answers_file() { # writes $@ (one per line) to a fresh file, prints its path
  local f="$TMP/answers.$RANDOM"
  printf '%s\n' "$@" >"$f"
  printf '%s' "$f"
}

# run_wizard ANSWERS_FILE -> stdout+stderr in $out, exit status in
# $WIZ_STATUS. --dry-run is passed explicitly: walked by a human the
# wizard's own default is a real Apply now (review §1.5), and every
# preview assertion in this file wants the preview on purpose.
run_wizard() {
  local answers="$1"
  out="$(OMARCHY_KIDS_TUI_ANSWERS="$answers" "$BIN" --dry-run 2>&1)"
  WIZ_STATUS=$?
}

# --- the whole Easy path, band 6-8, non-default web/Wi-Fi/level so the
# overrides those choices need are exercised too (R-BAND-2) --------------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada owl 6-8 simple filtered default pack helper 2 secret1 secret1 apply parent)"
run_wizard "$answers"

check_status "$WIZ_STATUS" 0 "happy path exits 0"
check_contains "$out" "step 1 of 15" "Welcome is step 1"
check_contains "$out" "step 2 of 15" "Parent password is step 2, right after Welcome (A2)"
check_contains "$out" "Pick Ada's face." "the face screen (A4) is shown"
check_contains "$out" "kid-ada" "name screen previews the kid- account slug"
check_contains "$out" "step 15 of 15" "Done is the last step"
check_contains "$out" "Screen time" "summary shows the screen-time row"
check_contains "$out" "60 minutes a day" "summary shows band 6-8's budget"
check_contains "$out" "19:30" "summary shows band 6-8's bedtime"
check_contains "$out" "Face          owl" "summary shows the chosen face"

# --dry-run means Apply's run_priv/run_priv_stdin print the command
# instead of ever calling sudo/pacman/omarchy-kids-*, so this is checking
# the wizard's own "[dry-run] sudo ..." lines in $out, not a stub's argv.
# Apply's first step (issue #46) writes machine.conf's parent= (via the
# tiny "omarchy-kids-conf machine set parent", issue #46 follow-up) to
# $OMARCHY_KIDS_INVOKING_USER, then enables and starts the package's own
# units -- the same KIDS_UNITS/KIDS_SOCKETS/KIDS_TIMERS list lib/kids.sh
# shares with omarchy-kids-assert's "units" lock -- before provisioning,
# so a fresh install (or right after omarchy-kids-remove) has both a
# parent for omarchy-kids-authd to check against and the boot-time
# autologin back before the account step and the next wizard run need
# them.
check_contains "$out" "omarchy-kids-conf machine set parent $EXPECTED_INVOKING_USER" \
  "Apply's first step writes machine.conf's parent=, to id -un"
check_not_contains "$out" "omarchy-kids-conf machine set parent forged-parent" \
  "OMARCHY_KIDS_INVOKING_USER cannot change Apply's parent identity"
check_contains "$out" "sudo systemctl enable omarchy-kids-boot-login.service omarchy-kids-boot-login-cleanup.service omarchy-kids-assert.service omarchy-kids-authd.socket omarchy-kids-wifid.socket omarchy-kids-time.timer omarchy-kids-ask-collect.timer omarchy-kids-review.timer omarchy-kids-relay-courier.timer" \
  "Apply's first step enables the package's units, before provisioning"
check_contains "$out" "sudo systemctl start omarchy-kids-authd.socket omarchy-kids-wifid.socket omarchy-kids-time.timer omarchy-kids-ask-collect.timer omarchy-kids-review.timer omarchy-kids-relay-courier.timer" \
  "Apply starts only the sockets and timers (T20: no oneshot blocks it)"
check_not_contains "$out" "systemctl start omarchy-kids-boot-login" "Apply never starts a oneshot service (the cleanup unit sleeps 20s; T20)"
check_not_contains "$out" "enable --now" "Apply never blocks on the assert oneshot at step 1 (the 15-second hang)"
check_contains "$out" "omarchy-kids-provision add Ada --band 6-8 --avatar owl --password-stdin --parent-password-stdin --apply" \
  "apply runs provision add with the exact flags, including the chosen face"
machine_pos="${out%%machine set parent*}"
machine_pos="${#machine_pos}"
units_pos="${out%%sudo systemctl enable *}"
units_pos="${#units_pos}"
provision_pos="${out%%omarchy-kids-provision add*}"
provision_pos="${#provision_pos}"
if ((machine_pos < units_pos && units_pos < provision_pos)); then
  pass "machine.conf's parent is written first, then units are enabled, then the account is provisioned"
else
  fail "step ordering is wrong (machine at $machine_pos, units at $units_pos, provision at $provision_pos)"
fi
check_contains "$out" "omarchy-kids-conf set kid-ada web filtered" "a web choice that differs from the band default is written as an override"
check_contains "$out" "omarchy-kids-conf set kid-ada wifi helper" "a Wi-Fi choice that differs from the band default is written as an override"
check_contains "$out" "omarchy-kids-conf set kid-ada level 3" "a level choice that differs from the band default is written as an override"
check_contains "$out" "omarchy-kids-web install 6-8 --apply" "apply runs web install for the chosen band"
check_contains "$out" "Checking setup safeguards: " "apply prints a per-step duration (T19)"
check_contains "$out" "omarchy-kids-apps install 6-8 --now --apply" "apply installs the starter pack from cache via omarchy-kids-apps, with --apply so it isn't silently a no-op under sudo"
check_contains "$out" "omarchy-kids-assert" "apply runs the safety check (assert)"
check_contains "$out" "omarchy-kids-session --check-setup" "apply runs the session setup safety report"
check_contains "$out" "Final safety checks run when they sign in." "Done defers session safety to sign-in"
check_contains "$out" "sudo -u kid-ada" "the session check runs as the new kid's own account"

# Own both privileged calls: a successful setup report must not mask a
# failed root assertion, and a failed setup report must still stop Apply.
for safety_failure in assert session; do
  safety_out="$(
    source "$DIR/lib/wizard-apply.sh"
    DRY_RUN=0 ACCOUNT=kid-ada ASSERT_BIN=assert-fixture SESSION_BIN=session-fixture
    id() { [[ "$1" == kid-ada ]]; }
    run_priv() { [[ "$safety_failure" != assert ]]; }
    run_priv_as() {
      printf '%s\n' "$*"
      [[ "$safety_failure" != session ]]
    }
    apply_step_safety
  )"
  check_status "$?" 1 "safety still fails when $safety_failure fails"
  check_contains "$safety_out" "kid-ada session-fixture --check-setup" \
    "safety report uses the child account and setup-only mode"
done

# --- every Simple choice left at the band default writes no override at
# all (R-BAND-2: "the profile stores only overrides") --------------------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Bea fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "all-defaults path exits 0"
check_not_contains "$out" "omarchy-kids-conf set" "leaving every Simple choice at its band default writes no override"

# --- band 3-5: the no-password branch, and provision gets --no-password --

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Zoe fox 3-5 simple none default pack parent 1 no apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "band 3-5 no-password path exits 0"
check_contains "$out" "No password" "summary reflects the no-password choice"
check_contains "$out" "omarchy-kids-provision add Zoe --band 3-5 --avatar fox --no-password --apply" \
  "apply passes --no-password for a 3-5 kid who skipped a password"
check_not_contains "$out" "--password-stdin" "no-password path never passes --password-stdin"

# --- time (A8): "I'll set my own" asks two custom fields, validated ----

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 simple garden custom notanumber 45 badtime 20:15 pack parent 1 secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "custom screen time with bad input first still completes"
check_contains "$out" "A number of minutes, 1 to 1440." "a non-numeric budget is rejected with a reason"
check_contains "$out" "24-hour time, like 19:30." "a malformed lights-out time is rejected with a reason"
check_contains "$out" "45 minutes a day" "the summary shows the custom budget"
check_contains "$out" "20:15" "the summary shows the custom lights-out time"

# --- apps (A9): "Let me pick" walks the pack one app at a time ---------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 simple garden default pick yes no yes no yes no yes no parent 1 secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "picking apps one at a time still completes"
check_contains "$out" "Include GCompris in Ada's starter apps?" "the checklist asks about each pack app by name"
check_contains "$out" "GCompris, KTuberling, SuperTux, KLettres" "the summary lists only the apps answered yes"
# %q escapes the commas (printf's own quoting choice, not a bug); the
# value bash would actually pass through as argv[3] is still the plain
# comma-joined list.
check_contains "$out" 'omarchy-kids-conf set kid-ada allowlist gcompris\,ktuberling\,supertux\,klettres' \
  "the chosen subset is written as the allowlist override (what shows in the launcher)"
check_contains "$out" "omarchy-kids-apps install 6-8 --now --apply" \
  "apply still installs the whole band pack regardless of the pick (R-WIZ-4: changed selections need no undo); the allowlist above is what actually restricts the kid to the chosen subset"

# --- name validation: digits/punctuation rejected, then a good name works -

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 "123!!" Mo fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "a bad name doesn't abort the wizard"
check_contains "$out" "Letters, spaces, and hyphens only" "invalid name is rejected with a reason"
check_contains "$out" "kid-mo" "the wizard proceeds once a valid name is given"

# --- Advanced (A6 -> the grouped checklist, A13a, issue #20): changing
# three keys across two groups (Web's web/dns, Screen time's budget_min)
# shows them grouped and marked, and Apply writes exactly those three
# overrides -- nothing else, since every untouched row is still at its
# band default (R-BAND-2) --------------------------------------------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 advanced \
  web filtered dns cleanbrowsing-family budget_min 75 "done" \
  secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "the Advanced path completes"
check_contains "$out" "[Web] Web access" "the checklist groups the web row under Web"
check_contains "$out" "[Web] Safe-search DNS" "the checklist groups the dns row under Web too"
check_contains "$out" "[Screen time] Minutes a day (weekdays)" "the checklist groups budget_min under Screen time"
check_contains "$out" "Web access — Filtered open web (changed)" "a changed row shows the new value in the row and is marked"
check_contains "$out" "omarchy-kids-conf set kid-ada web filtered" "Apply writes the web override chosen in Advanced"
check_contains "$out" "omarchy-kids-conf set kid-ada dns cleanbrowsing-family" "Apply writes the dns override chosen in Advanced"
check_contains "$out" "omarchy-kids-conf set kid-ada budget_min 75" "Apply writes the budget_min override chosen in Advanced"
check_not_contains "$out" "omarchy-kids-conf set kid-ada wifi" "a row never opened in Advanced writes no override"
check_not_contains "$out" "[Desktop] App menu" "the unenforced App menu row is not offered"

# --- issue #53: the Desktop group's theme row -- default is the parent's
# own current theme (tokyo-night, from $HOME above), not a band value;
# leaving it untouched writes no override; picking a different installed
# theme does ---------------------------------------------------------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 advanced "done" secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "Advanced with no rows opened still completes"
check_not_contains "$out" "omarchy-kids-conf set kid-ada theme" \
  "theme's default already matches the parent's current theme, so leaving the row alone writes no override"

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 advanced \
  theme catppuccin-latte "done" secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "picking a different theme in Advanced still completes"
check_contains "$out" "[Desktop] Theme" "the checklist groups the theme row under Desktop with level"
check_contains "$out" "omarchy-kids-conf set kid-ada theme catppuccin-latte" \
  "Apply writes the theme override chosen in Advanced"

# --- Esc from an editor returns to the checklist, not out of it: the
# row's value is untouched and the wizard still finishes normally -------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 advanced \
  web @esc "done" secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "Esc from an editor still lets the wizard finish"
check_contains "$out" "Band default: Only sites you choose" "the web row still shows its band default after Esc"
check_not_contains "$out" "omarchy-kids-conf set kid-ada web" "Esc from the web editor writes no override"

# --- Nothing is written before Apply: making changes in Advanced, then
# leaving from the summary (before choosing Apply), never runs (or, in
# --dry-run, prints) omarchy-kids-conf set at all -- only Apply's own
# maybe_override calls (apply_step_account) ever do that -----------------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 advanced \
  web filtered "done" secret1 secret1 @ctrlc yes)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 130 "leaving from the summary after Advanced changes exits 130"
check_contains "$out" "Left setup. Nothing changed." "leaving from the summary shows the leave message"
check_not_contains "$out" "omarchy-kids-conf set" "nothing is written before Apply, even after changing a row in Advanced"
check_not_contains "$out" "omarchy-kids-provision" "Apply itself never starts before the summary's own Apply is chosen"

# --- The Easy summary's "Change something" opens that same grouped
# checklist (issue #20, point 2: "for both paths"), and the summary marks
# the result distinctly once Apply is finally chosen --------------------

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada fox 6-8 simple garden default pack parent 1 \
  secret1 secret1 change level 2 "done" apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "Change something from a Simple-built summary still completes"
check_contains "$out" "Desktop (custom)" "the summary marks a row changed via Change something"
check_contains "$out" "omarchy-kids-conf set kid-ada level 3" "Apply writes the override made through Change something"

# --- Esc from the face screen goes back to the name screen, keyboard-only

: >"$ARGV_LOG"
answers="$(answers_file begin parentpw123 Ada @esc Bea fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 0 "Esc-back then finishing still exits 0"
check_contains "$out" "kid-bea" "the re-entered name after Esc-back is the one used"
check_contains "$out" "Pick Bea's face." "the face screen re-renders for the name entered after Esc-back"

# --- Ctrl+C right after Welcome (before anything else) leaves with
# nothing changed, no commands run and no prefetch started ---------------

: >"$ARGV_LOG"
answers="$(answers_file begin @ctrlc yes)"
run_wizard "$answers"
check_status "$WIZ_STATUS" 130 "Ctrl+C exits 130"
check_contains "$out" "Left setup. Nothing changed." "Ctrl+C shows the leave message"
check_not_contains "$out" "[dry-run]" "Ctrl+C before Apply prints no command at all"

# --- real mode (DRY_RUN=0): a failing step stops the dashboard, shows its
# last output lines, and the technical log is actually written -----------
#
# This needs its own scratch PATH: the harness's shared `sudo` fake above
# only logs and exits 0, which would make every step trivially "succeed"
# in real mode. Here `sudo` actually execs what it's given (stripping the
# few flags this wizard passes it), so a fake omarchy-kids-provision that
# exits 1 is genuinely what apply_step_account sees.

RM_TMP="$(mktemp -d)"
RM_STUBS="$RM_TMP/stubs"
RM_ETC="$RM_TMP/etc/omarchy-kids"
RM_LOG="$RM_TMP/setup.log"
mkdir -p "$RM_STUBS" "$RM_ETC/kids"

cat >"$RM_STUBS/sudo" <<'EOF'
#!/bin/bash
# A real-enough fake sudo for tests: strips the flags this wizard passes
# (-n/-v/-S/-p ARG/-u USER) and execs whatever command is left, or just
# exits 0 for a bare "sudo -v" credential warm-up (no command at all).
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
cat >"$RM_STUBS/systemctl" <<'EOF'
#!/bin/bash
# Apply's own first step (issue #46) now enables the units and starts them (except the assert oneshot, T20)
# on the package's units before provisioning; a plain success stub is
# enough here, since these scenarios are about what happens *after* that
# step, not about systemd itself.
exit 0
EOF
cat >"$RM_STUBS/omarchy-kids-provision" <<'EOF'
#!/bin/bash
echo "FAKE-PROVISION: refusing on purpose (out of disk space)"
cat >/dev/null
exit 1
EOF
cat >"$RM_STUBS/omarchy-kids-web" <<'EOF'
#!/bin/bash
echo "FAKE-WEB: this must never print — Apply should have stopped already"
exit 0
EOF
cp "$STUBS/gum" "$RM_STUBS/gum"
cp "$STUBS/omarchy-kids-parent-auth" "$RM_STUBS/omarchy-kids-parent-auth"
chmod +x "$RM_STUBS"/*

rm_out="$(
  PATH="$RM_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM_LOG" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin parentpw123 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)" \
    DRY_RUN=0 "$(wizard_for "$RM_STUBS")" 2>&1
)"
rm_status=$?
check_status "$rm_status" 0 "a real run still exits 0 even when Apply fails (Done still shows what happened)"
check_contains "$rm_out" "✗ Setting up Ada's account" "the failing step is marked ✗, not ✓, on a real exit-code failure"
check_contains "$rm_out" "FAKE-PROVISION: refusing on purpose" "the failing command's own output is shown (the tail)"
check_not_contains "$rm_out" "FAKE-WEB" "Apply stops at the first failure and never reaches a later step"
check_contains "$rm_out" 'Setup stopped at "Setting up Ada'"'"'s account"' "Done explains which step stopped it"
check_contains "$rm_out" "Last lines from the failed step:" "Done carries the failed step's tail into its own card"
check "$(awk '
  /Last lines from the failed step:/ { header = NR }
  header && /FAKE-PROVISION: refusing on purpose/ { found = 1 }
  END { print(found ? "yes" : "no") }' <<<"$rm_out")" "yes" \
  "the tail content lands after Done's own header, not only above it"
check_not_contains "$rm_out" "see the lines above" "Done no longer points at a cleared screen"
check_contains "$(cat "$RM_LOG" 2>/dev/null)" "FAKE-PROVISION: refusing on purpose" \
  "a real run actually writes the technical log at OMARCHY_KIDS_SETUP_LOG"

# Leaving after a real Apply must not claim "nothing changed" (I-6), and
# Done must not offer a choice that no longer exists.
rm_leave_out="$(
  PATH="$RM_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM_LOG" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin parentpw123 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply @ctrlc yes)" \
    DRY_RUN=0 "$(wizard_for "$RM_STUBS")" 2>&1
)"
check_status "$?" 130 "leaving from Done after Apply still exits 130"
check_contains "$rm_leave_out" "Apply already made its changes" \
  "the leave message after Apply says the changes stay"
rm_kid_out="$(
  PATH="$RM_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM_LOG" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin parentpw123 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply kid)" \
    DRY_RUN=0 "$(wizard_for "$RM_STUBS")" 2>&1
)"
check_not_contains "$rm_kid_out" "Open Ada's desktop" \
  "Done offers no preview button any more"
check_contains "$rm_kid_out" "does not match any choice on 'Done'" \
  "an answer the old preview button used is refused, not silently accepted"

RM_STUBS_SUDO="$(mktemp)" # reused by the default-mode section below
cp "$RM_STUBS/sudo" "$RM_STUBS_SUDO"
rm -rf "$RM_TMP"

# --- real mode: authd decides whether a candidate is correct, even when
# sudo is passwordless. The fake parent-auth is the authd client seam; the
# fake sudo accepts every ticket so it cannot decide authentication.

RM3_TMP="$(mktemp -d)"
RM3_STUBS="$RM3_TMP/stubs"
RM3_ETC="$RM3_TMP/etc/omarchy-kids"
RM3_ARGV_LOG="$RM3_TMP/argv.log"
mkdir -p "$RM3_STUBS" "$RM3_ETC/kids"

cat >"$RM3_STUBS/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${SUDO_LOG:-/dev/null}"
args=()
noninteractive=0
reads_stdin=0
validates=0
while (($#)); do
    case "$1" in
        -n) noninteractive=1; shift ;;
        -v) validates=1; shift ;;
        -S) reads_stdin=1; shift ;;
        -p) shift 2 ;;
        -u) shift 2 ;;
        *) args+=("$1"); shift ;;
    esac
done
if ((noninteractive && validates)) && [[ -n "${SUDO_FAIL_V_AT:-}" ]]; then
    count_file="${SUDO_V_COUNT_FILE:?}"
    count=0
    [[ -f "$count_file" ]] && count="$(<"$count_file")"
    count=$((count + 1))
    printf '%s\n' "$count" >"$count_file"
    ((count < SUDO_FAIL_V_AT)) || exit 1
fi
if ((noninteractive && validates)) && [[ -n "${KEEPER_RELEASE_FILE:-}" ]] &&
    [[ -f "$KEEPER_RELEASE_FILE" ]]; then
    touch "$KEEPER_REFRESH_FILE"
fi
if ((${#args[@]} == 0)); then
    ((reads_stdin)) && cat >/dev/null
    exit 0
fi
if ((noninteractive == 0)); then
    echo "[sudo] password for testparent:" >&2
    exit 1
fi
exec "${args[@]}"
EOF
cat >"$RM3_STUBS/omarchy-kids-parent-auth" <<'EOF'
#!/bin/bash
read -r candidate || candidate=""
[[ "$candidate" == "${CORRECT_PW:-}" ]]
EOF
cat >"$RM3_STUBS/systemctl" <<'EOF'
#!/bin/bash
if [[ -n "${KEEPER_RELEASE_FILE:-}" ]]; then
    touch "$KEEPER_RELEASE_FILE"
    for _ in $(seq 1 200); do
        [[ -e "${KEEPER_REFRESH_FILE:-}" ]] && exit 0
        /bin/sleep 0.01
    done
    echo "keeper did not refresh authorization" >&2
    exit 1
fi
exit 0
EOF
for name in omarchy-kids-provision omarchy-kids-web omarchy-kids-apps omarchy-kids-assert omarchy-kids-session; do
  cat >"$RM3_STUBS/$name" <<EOF
#!/bin/bash
printf '%s %s\n' "$name" "\$*" >>"$RM3_ARGV_LOG"
echo "FAKE-$name: ok"
exit 0
EOF
done
cp "$STUBS/gum" "$RM3_STUBS/gum"
chmod +x "$RM3_STUBS"/*

# The right password (first try) gets all the way through.
rm3a_out="$(
  PATH="$RM3_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM3_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM3_TMP/setup.log" \
    CORRECT_PW="hunter2" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin hunter2 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)" \
    DRY_RUN=0 "$(wizard_for "$RM3_STUBS")" 2>&1
)"
rm3a_status=$?
check_status "$rm3a_status" 0 "authd accepts the correct password: the wizard completes"
check_not_contains "$rm3a_out" "failed unexpectedly" \
  "authd success never reports the screen as having failed unexpectedly"
# Apply's own step output only shows up live on failure (tail-on-error);
# the technical log always gets it, same as the existing failing-step
# test above -- that's where "A2 actually let Apply start" is checkable.
check_contains "$(cat "$RM3_TMP/setup.log" 2>/dev/null)" "FAKE-omarchy-kids-provision: ok" \
  "authd success: Apply actually runs (A2 accepted it)"

# Three wrong passwords in a row: "That wasn't it" each time, then leaves
# with nothing changed -- the same exit Ctrl+C uses -- never a crash and
# never "failed unexpectedly".
rm3b_out="$(
  PATH="$RM3_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM3_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    CORRECT_PW="hunter2" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin wrong1 wrong2 wrong3)" \
    DRY_RUN=0 "$(wizard_for "$RM3_STUBS")" 2>&1
)"
rm3b_status=$?
check_status "$rm3b_status" 130 "authd rejects wrong passwords: leaves (same exit as Ctrl+C)"
check_eq "$(grep -c "That wasn't it" <<<"$rm3b_out")" "3" \
  "each of the three wrong tries is told plainly \"That wasn't it\""
check_contains "$rm3b_out" "Left setup. Nothing changed." \
  "leaving after three wrong tries shows the same message Ctrl+C does"
check_not_contains "$rm3b_out" "failed unexpectedly" \
  "three wrong tries never reports the screen as having failed unexpectedly"
check_not_contains "$rm3b_out" "FAKE-omarchy-kids-provision" \
  "Apply never starts -- A2 never let a wrong password through"

# R-BOOTMODE-8: a real pseudo-terminal Apply has one stdin password
# validation and no later interactive sudo prompt.
# Make the new account visible to the safety check without changing the
# wizard's invoking identity lookup.
REAL_ID="$(command -v id)"
cat >"$RM3_STUBS/id" <<EOF
#!/bin/bash
if [[ "\${1:-}" == kid-ada ]]; then
  exit 0
fi
exec "$REAL_ID" "\$@"
EOF
chmod +x "$RM3_STUBS/id"

SUDO_LOG="$RM3_TMP/sudo.log"
pty_out="$(
  PATH="$RM3_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM3_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM3_TMP/pty-setup.log" \
    SUDO_LOG="$SUDO_LOG" \
    CORRECT_PW="hunter2" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin hunter2 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)" \
    DRY_RUN=0 python3 - "$(wizard_for "$RM3_STUBS")" <<'PYEOF'
import os, pty, select, signal, sys, time

pid, fd = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], [sys.argv[1]])

output = bytearray()
deadline = time.monotonic() + 30
while True:
    if time.monotonic() >= deadline:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        sys.exit(124)
    ready, _, _ = select.select([fd], [], [], 0.5)
    if ready:
        try:
            output.extend(os.read(fd, 4096))
        except OSError:
            break
    waited, status = os.waitpid(pid, os.WNOHANG)
    if waited:
        break
sys.stdout.buffer.write(output)
sys.exit(os.waitstatus_to_exitcode(status))
PYEOF
)"
check_not_contains "$pty_out" "[sudo] password" \
  "R-BOOTMODE-8: pseudo-terminal Apply has no later sudo prompt"
check_eq "$(grep -Ec '(^| )-S( |$)' "$SUDO_LOG")" "1" \
  "R-BOOTMODE-8: the candidate warms sudo exactly once"
sudo_calls="$(wc -l <"$SUDO_LOG" | tr -d ' ')"
check_eq "$(grep -Ec '(^| )-n( |$)' "$SUDO_LOG")" "$((sudo_calls - 1))" \
  "R-BOOTMODE-8: every later sudo call is noninteractive"

check_contains "$pty_out" "Ada's setup is complete." \
  "R-BOOTMODE-8: the PTY transcript reaches the success headline"
check_contains "$pty_out" "FAKE-omarchy-kids-session: ok" \
  "R-BOOTMODE-8: the PTY transcript includes the kid session check"
check_not_contains "$pty_out" "hunter2" \
  "R-BOOTMODE-8: the candidate never appears in the terminal transcript"
check_not_contains "$(cat "$RM3_TMP/pty-setup.log" 2>/dev/null)" "hunter2" \
  "R-BOOTMODE-8: the candidate never appears in the technical log"
check_not_contains "$(cat "$RM3_ARGV_LOG" 2>/dev/null)" "hunter2" \
  "R-BOOTMODE-8: the candidate never appears in child argv logs"
check_not_contains "$SUDO_LOG" "hunter2" \
  "R-BOOTMODE-8: the candidate never appears in sudo argv logs"

SLEEP_COUNT_FILE="$RM3_TMP/keeper-sleep-count"
KEEPER_SLEEP_ARGS_FILE="$RM3_TMP/keeper-sleep-args"
KEEPER_RELEASE_FILE="$RM3_TMP/keeper-release"
KEEPER_REFRESH_FILE="$RM3_TMP/keeper-refresh"
KEEPER_SUDO_LOG="$RM3_TMP/keeper-sudo.log"
cat >"$RM3_STUBS/sleep" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$KEEPER_SLEEP_ARGS_FILE"
count=0
[[ -f "$SLEEP_COUNT_FILE" ]] && count="$(<"$SLEEP_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" >"$SLEEP_COUNT_FILE"
if ((count == 1)); then
  # Bounded: if the run this stub belongs to dies before it releases, an unbounded wait outlives
  # its own scratch dir and spins forever. Sixteen of these were found on the test VM, the oldest
  # a day old, burning a third of its CPU and slowing every gate (2026-09-05).
  for _ in $(seq 1 3000); do
    [[ -e "$KEEPER_RELEASE_FILE" ]] && exit 0
    /bin/sleep 0.01
  done
  echo "sleep stub: keeper never released within 30s" >&2
  exit 1
fi
exit 1
EOF
chmod +x "$RM3_STUBS/sleep"

# The Apply step cannot pass its systemctl call until the background keeper
# has refreshed sudo, so this proves the refresh came from the 60-second loop.
keeper_out="$({
  PATH="$RM3_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM3_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM3_TMP/keeper-setup.log" \
    SUDO_LOG="$KEEPER_SUDO_LOG" \
    SLEEP_COUNT_FILE="$SLEEP_COUNT_FILE" \
    KEEPER_SLEEP_ARGS_FILE="$KEEPER_SLEEP_ARGS_FILE" \
    KEEPER_RELEASE_FILE="$KEEPER_RELEASE_FILE" \
    KEEPER_REFRESH_FILE="$KEEPER_REFRESH_FILE" \
    CORRECT_PW="hunter2" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin hunter2 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)" \
    DRY_RUN=0 "$(wizard_for "$RM3_STUBS")" 2>&1
})"
keeper_status=$?
check_status "$keeper_status" 0 "the wizard completes after the keeper refreshes authorization"
check_eq "$(head -n 1 "$KEEPER_SLEEP_ARGS_FILE")" "60" \
  "the authorization keeper waits on its 60-second interval"
if [[ -f "$KEEPER_REFRESH_FILE" ]]; then
  pass "the 60-second keeper performs a noninteractive authorization refresh"
else
  fail "the 60-second keeper performs a noninteractive authorization refresh"
fi
check_contains "$keeper_out" "Ada's setup is complete." \
  "keeper-backed Apply reaches the success headline"
check_contains "$(cat "$RM3_TMP/keeper-setup.log" 2>/dev/null)" "FAKE-omarchy-kids-session: ok" \
  "keeper-backed Apply runs the kid session check"

# If the cached authorization has expired before Apply, the wizard must
# return to Step 2 rather than claiming Done. The fake fails the second
# noninteractive validation, which is Apply's preflight after A2.
EXPIRY_COUNT="$RM3_TMP/expiry-count"
expiry_out="$(
  PATH="$RM3_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM3_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM3_TMP/expiry-setup.log" \
    SUDO_FAIL_V_AT=2 \
    SUDO_V_COUNT_FILE="$EXPIRY_COUNT" \
    CORRECT_PW="hunter2" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin hunter2 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent @ctrlc yes)" \
    DRY_RUN=0 "$(wizard_for "$RM3_STUBS")" 2>&1
)"
expiry_status=$?
check_status "$expiry_status" 130 "expired Apply authorization leaves after returning to Step 2"
expiry_prompts="$(grep -c "First, your password." <<<"$expiry_out")"
if ((expiry_prompts >= 2)); then
  pass "expired Apply authorization redraws the only password screen"
else
  fail "expired Apply authorization redraws the only password screen (got $expiry_prompts prompt renders)"
fi
check_not_contains "$expiry_out" "Ada's setup is complete." \
  "expired Apply authorization never advances to Done"

rm -rf "$RM3_TMP"

# --- real mode: an unavailable authd verifier fails closed at step 2
# and never falls back to sudo, even when a socket-shaped path exists.

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: unavailable-authd test needs python3 to create a stale Unix socket"
else
  RM4_TMP="$(mktemp -d)"
  RM4_STUBS="$RM4_TMP/stubs"
  RM4_ETC="$RM4_TMP/etc/omarchy-kids"
  mkdir -p "$RM4_STUBS" "$RM4_ETC/kids"

  RM4_SOCK="$RM4_TMP/auth.sock"
  python3 -c "
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(sys.argv[1])
" "$RM4_SOCK"

  cat >"$RM4_STUBS/sudo" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "-k" ]]; then
    exit 0
fi
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
    read -r candidate || candidate=""
    [[ "$candidate" == "${CORRECT_PW:-}" ]]
    exit $?
fi
exec "${args[@]}"
EOF
  cat >"$RM4_STUBS/systemctl" <<'EOF'
#!/bin/bash
exit 0
EOF
  for name in omarchy-kids-provision omarchy-kids-web omarchy-kids-apps omarchy-kids-assert omarchy-kids-session; do
    cat >"$RM4_STUBS/$name" <<EOF
#!/bin/bash
echo "FAKE-$name: ok"
cat >/dev/null
exit 0
EOF
  done
  cp "$STUBS/gum" "$RM4_STUBS/gum"
  chmod +x "$RM4_STUBS"/*

  rm4_out="$(
    PATH="$RM4_STUBS:$PATH" \
      OMARCHY_KIDS_ETC="$RM4_ETC" \
      OMARCHY_KIDS_SHARE="$SHARE" \
      OMARCHY_KIDS_SETUP_LOG="$RM4_TMP/setup.log" \
      CORRECT_PW="hunter2" \
      OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin hunter2 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)" \
      DRY_RUN=0 "$(wizard_for "$RM4_STUBS" "$RM4_SOCK")" 2>&1
  )"
  rm4_status=$?
  check_status "$rm4_status" 130 "unavailable authd: step 2 leaves without falling back to sudo"
  check_contains "$rm4_out" "parent verifier is unavailable" \
    "an unavailable verifier gives a repair instruction"
  check_not_contains "$rm4_out" "failed unexpectedly" \
    "an unavailable verifier never reports a failed unexpectedly"
  check_not_contains "$rm4_out" "FAKE-omarchy-kids-provision" \
    "an unavailable verifier never starts Apply"

  rm -rf "$RM4_TMP"
fi

# --- real mode: the safety check skips sudo -u <kid> ... --check when the
# account was never actually created, instead of handing sudo a user that
# doesn't exist -------------------------------------------------------

RM2_TMP="$(mktemp -d)"
RM2_STUBS="$RM2_TMP/stubs"
RM2_ETC="$RM2_TMP/etc/omarchy-kids"
mkdir -p "$RM2_STUBS" "$RM2_ETC/kids"

cat >"$RM2_STUBS/sudo" <<'EOF'
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
cat >"$RM2_STUBS/systemctl" <<'EOF'
#!/bin/bash
exit 0
EOF
for name in omarchy-kids-provision omarchy-kids-web omarchy-kids-apps omarchy-kids-assert; do
  cat >"$RM2_STUBS/$name" <<EOF
#!/bin/bash
echo "FAKE-$name: ok (no real account created — this is a stub)"
cat >/dev/null
exit 0
EOF
done
cp "$STUBS/gum" "$RM2_STUBS/gum"
cp "$STUBS/omarchy-kids-parent-auth" "$RM2_STUBS/omarchy-kids-parent-auth"
chmod +x "$RM2_STUBS"/*

rm2_out="$(
  PATH="$RM2_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$RM2_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$RM2_TMP/setup.log" \
    OMARCHY_KIDS_TUI_ANSWERS="$(answers_file begin parentpw123 Zzznobody fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)" \
    DRY_RUN=0 "$(wizard_for "$RM2_STUBS")" 2>&1
)"
rm2_status=$?
check_status "$rm2_status" 0 "real mode with every fake succeeding still exits 0"
check_contains "$rm2_out" "skipping the session check — account kid-zzznobody does not exist" \
  "the safety check explains why it skipped, rather than handing sudo -u a nonexistent user"
check_not_contains "$rm2_out" "sudo -u kid-zzznobody" \
  "omarchy-kids-session --check-setup is never actually invoked for an account that doesn't exist"

rm -rf "$RM2_TMP"

# --- --help works with no terminal and no answers file needed ----------

help_out="$("$BIN" --help 2>&1)"
help_status=$?
check_status "$help_status" 0 "--help exits 0"
check_contains "$help_out" "Usage: omarchy-kids-wizard" "--help prints usage"

# =====================================================================
# review §1.5: walked by a human, Apply is real
# =====================================================================

DEF_TMP="$(mktemp -d)"
DEF_STUBS="$DEF_TMP/stubs"
mkdir -p "$DEF_STUBS"
DEF_ETC="$DEF_TMP/etc"
mkdir -p "$DEF_ETC/kids"
printf 'parent=%s\n' "$(id -un)" >"$DEF_ETC/machine.conf"
DEF_MARK="$DEF_TMP/provision-ran"
cat >"$DEF_STUBS/omarchy-kids-provision" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$DEF_MARK"
EOF
cp "$RM_STUBS_SUDO" "$DEF_STUBS/sudo" # the real-mode sudo fake from above
cp "$STUBS/omarchy-kids-parent-auth" "$DEF_STUBS/omarchy-kids-parent-auth"
for n in omarchy-kids-web omarchy-kids-apps omarchy-kids-session omarchy-kids-assert \
  pacman systemctl runuser chpasswd usermod; do
  printf '#!/bin/bash\nexit 0\n' >"$DEF_STUBS/$n"
done
chmod +x "$DEF_STUBS"/*

wizard_launched_by_desktop() { # -> the run's output
  OMARCHY_KIDS_TUI_ANSWERS="$1" \
    PATH="$DEF_STUBS:$PATH" \
    OMARCHY_KIDS_ETC="$DEF_ETC" \
    OMARCHY_KIDS_SHARE="$SHARE" \
    OMARCHY_KIDS_SETUP_LOG="$DEF_TMP/setup.log" \
    OMARCHY_KIDS_LAUNCHED_BY=desktop \
    DRY_RUN='' \
    "$(wizard_for "$DEF_STUBS")" "${@:2}" 2>&1
}

ans="$(answers_file begin parentpw123 Ada fox 6-8 simple garden default pack parent 1 secret1 secret1 apply parent)"

: >"$DEF_MARK"
def_out="$(wizard_launched_by_desktop "$ans")"
check_not_contains "$def_out" "[dry-run]" "opened from the app entry: Apply is real, not a preview (review §1.5)"
if [[ -s "$DEF_MARK" ]]; then
  pass "opened from the app entry: omarchy-kids-provision actually ran"
else
  fail "opened from the app entry: nothing ran -- Apply was still a preview"
fi

: >"$DEF_MARK"
def_out="$(wizard_launched_by_desktop "$ans" --dry-run)"
check_contains "$def_out" "[dry-run]" "--dry-run still wins over the app entry"
if [[ -s "$DEF_MARK" ]]; then
  fail "--dry-run ran a real command"
else
  pass "--dry-run ran nothing"
fi

# No terminal and no app entry (a script, CI): the safe default holds.
: >"$DEF_MARK"
def_out="$(OMARCHY_KIDS_TUI_ANSWERS="$ans" OMARCHY_KIDS_ETC="$DEF_ETC" OMARCHY_KIDS_SHARE="$SHARE" \
  DRY_RUN='' "$(wizard_for "$DEF_STUBS")" 2>&1)"
check_contains "$def_out" "[dry-run]" "no tty and no app entry: still previews by default (AGENTS.md rule 8)"

rm -rf "$DEF_TMP" "$RM_STUBS_SUDO"

echo "wizard-test.sh: done"
exit $rc
