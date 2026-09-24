#!/bin/bash
# 73-notify-act: the scripted client grants more time and ends a session through the ACT frame
# (R-NOTIFY-13; docs/notify.md, docs/relayd.md). The grant is proved in the day's grant ledger; the
# end is proved by the frame being accepted (there is no kid session live here, and the command's
# own outcome for that is exit 0 -- the end's real effect is scenario 30's). The client is
# test/live/clients/notify-client.py.
#
# Unverified from a draft: this scenario has not been run from this checkout. AGENTS.md rule 11 --
# only the gate runner drives the VM.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/live/lib.sh
source "$DIR/lib.sh"

KEY=/root/live-device.key

build_install && ok "package installed and pacman -Qkk clean" ||
  fail "package build/install/Qkk gate failed"

boot_with "$LIVE_OWNER_PASSWORD" "$LIVE_OWNER_ACCOUNT" &&
  ok "vm booted" || fail "vm never came up"

portal_reset 30 && ok "greeter is up" || fail "greeter never appeared"

# The day's grant ledger, before. The logical day rolls at 04:00, so ask the box for it rather than
# computing it here.
day="$(vmroot "date +%Y-%m-%d" | tr -d '[:space:]')"
grant_file="/var/lib/omarchy-kids/$LIVE_KID1_ACCOUNT/usage/$day.grant"
before="$(vmroot "cat $grant_file 2>/dev/null || echo 0" | tr -d '[:space:]')"

notify_pair_client "$KEY" ||
  fail "the act scenario cannot run without a paired client"

if [[ -n "${NOTIFY_DEVICE_ID:-}" ]]; then
  grant_reply="$(vmroot "python3 /tmp/notify-client.py act --key $KEY --id $NOTIFY_DEVICE_ID --account $LIVE_KID1_ACCOUNT --action grant --minutes 15" 2>&1)"
  if [[ "$grant_reply" == *"act 200"* ]]; then
    ok "the client's signed grant was accepted ($grant_reply)"
  else
    fail "grant failed: $grant_reply"
  fi
  after="$(vmroot "cat $grant_file 2>/dev/null || echo 0" | tr -d '[:space:]')"
  if [[ "$after" == "$((before + 15))" ]]; then
    ok "the grant ledger shows +15 ($before -> $after)"
  else
    fail "the grant ledger does not show +15 (before='$before' after='$after')"
  fi
  # End: no session is live, so the command's own outcome is exit 0 (nothing to end) and the frame
  # is accepted. The session-ending effect itself is scenario 30's.
  end_reply="$(vmroot "python3 /tmp/notify-client.py act --key $KEY --id $NOTIFY_DEVICE_ID --account $LIVE_KID1_ACCOUNT --action end" 2>&1)"
  if [[ "$end_reply" == *"act 200"* ]]; then
    ok "the client's signed end was accepted ($end_reply)"
  else
    fail "end failed: $end_reply"
  fi
fi

shot 73-notify-act || fail "screenshot failed"

# Leave the box as it was: the grant back to what it held, notifications off (which revokes).
vmroot "printf '%s\n' '$before' > $grant_file" >/dev/null 2>&1
notify_stop

scenario_result 73-notify-act
