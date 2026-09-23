#!/bin/bash
# 71-notify-idle-exit: with no kid live and no request open, the relay stops itself and the port
# closes (N-7's live step, R-NOTIFY-1; docs/notify.md, docs/relayd.md). The not-needed grace is 60
# seconds and the tick polls every 30, so the bound here is 180 seconds -- the old ten-minute
# connection-idle window was replaced by the not-in-use rule.
#
# Unverified from a draft: this scenario has not been run from this checkout. AGENTS.md rule 11.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/live/lib.sh
source "$DIR/lib.sh"

build_install && ok "package installed and pacman -Qkk clean" ||
  fail "package build/install/Qkk gate failed"

boot_with "$LIVE_OWNER_PASSWORD" "$LIVE_OWNER_ACCOUNT" &&
  ok "vm booted" || fail "vm never came up"

portal_reset 30 && ok "greeter is up" || fail "greeter never appeared"

# Kids Mode must not be in use: no kid session, no open request. (If a kid is still logged in from
# an earlier scenario, this scenario cannot test the exit -- say so rather than pass.)
kids_live="$(state 2>/dev/null | grep -c " $LIVE_KID1_ACCOUNT " || true)"
open_requests="$(vmroot "ls /var/lib/omarchy-kids/queue 2>/dev/null | wc -l" | tr -d '[:space:]')"
[[ "$kids_live" == "0" ]] && ok "no kid session is live" ||
  fail "a kid session is live; log out before running 71"
[[ "${open_requests:-0}" == "0" ]] && ok "no request is open" ||
  fail "the queue is not empty ($open_requests files); decide or clear them before running 71"

vmroot "omarchy-kids-notify enable --apply" >/dev/null 2>&1 &&
  ok "notifications enabled (the certificate exists, so the tick may start the relay)" ||
  fail "omarchy-kids-notify enable failed"

vmroot "systemctl start omarchy-kids-relayd.service" >/dev/null 2>&1 &&
  ok "relay started by hand for the test" || fail "could not start the relay"

listen_now() { vmroot "ss -ltn 2>/dev/null | grep -c ':8447' || true" | tr -d '[:space:]'; }

listening=0
for _ in 1 2 3 4 5 6; do
  [[ "$(listen_now)" != "0" ]] && {
    listening=1
    break
  }
  sleep 2
done
((listening)) && ok "the relay is listening on 8447" || fail "the relay never listened on 8447"

waited=0
closed=0
while ((waited < 180)); do
  if [[ "$(listen_now)" == "0" ]]; then
    closed=1
    break
  fi
  sleep 5
  waited=$((waited + 5))
done
if ((closed)); then
  ok "the relay stopped itself with Kids Mode not in use (after ~${waited}s)"
else
  fail "the port was still open after ${waited}s with no kid live and no request open"
fi

vmroot "omarchy-kids-notify disable --apply" >/dev/null 2>&1 &&
  ok "notifications disabled" || fail "disable failed"

scenario_result 71-notify-idle-exit
