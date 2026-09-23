#!/bin/bash
# 70-notify-pair-and-approve: enable notifications on the box, pair a scripted client (standing in
# for the parent app) through the relay's /v1/pair, queue a request as the kid, and approve it from
# the client's signed decision; confirm the grant lands in the ledger (N-6's live step,
# R-NOTIFY-1/4/5; docs/notify.md, docs/relayd.md). The client is test/live/clients/notify-client.py,
# which implements exactly clients/parent/README.md's scheme.
#
# Unverified from a draft: this scenario has not been run from this checkout. AGENTS.md rule 11 --
# only the gate runner drives the VM.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/live/lib.sh
source "$DIR/lib.sh"

CLIENT="$DIR/clients/notify-client.py"
KEY=/root/live-device.key
REQ_ID="live-$(date +%s)-$LIVE_KID1_ACCOUNT-time"

build_install && ok "package installed and pacman -Qkk clean" ||
  fail "package build/install/Qkk gate failed"

boot_with "$LIVE_OWNER_PASSWORD" "$LIVE_OWNER_ACCOUNT" &&
  ok "vm booted" || fail "vm never came up"

portal_reset 30 && ok "greeter is up" || fail "greeter never appeared"

kid_budget_headroom "$LIVE_KID1_ACCOUNT" &&
  ok "budget headroom set for the approval run" || fail "could not set budget headroom"

vmroot "omarchy-kids-notify enable --apply" >/dev/null 2>&1 &&
  ok "notifications enabled (the relay certificate is minted)" ||
  fail "omarchy-kids-notify enable failed"

# Start the relay explicitly: the tick starts it on demand, and this scenario wants it up before
# any kid is live so the pair window can be reached.
vmroot "systemctl start omarchy-kids-relayd.service" >/dev/null 2>&1 &&
  ok "relay started" || fail "could not start the relay"

pair_out="$(vmroot "omarchy-kids-notify pair --apply" 2>&1)"
uri="$(printf '%s\n' "$pair_out" | grep -o 'omarchy-kids://pair[^ ]*' | head -1)"
token="$(printf '%s' "$uri" | sed -n 's/.*[?&]token=\([^&]*\).*/\1/p')"
# The pairing record's own id (d-xxxxxxxx) is the one authd looks up; the scenario must pair under
# that, not one of its own.
DEVICE_ID="$(printf '%s' "$uri" | sed -n 's/.*[?&]id=\([^&]*\).*/\1/p')"
[[ -n "$token" && -n "$DEVICE_ID" ]] && ok "pairing window opened for $DEVICE_ID" ||
  fail "pair-start printed no id/token: $pair_out"

# The client is copied in, never run from the runner: it must reach the relay on the VM's own
# localhost, which the unit's fence allows. vm_write_file runs as the owner, so /tmp, not /root.
if vm_write_file /tmp/notify-client.py <"$CLIENT"; then
  ok "client copied to the vm"
else
  fail "could not copy the client to the vm"
fi

pair_reply="$(vmroot "python3 /tmp/notify-client.py pair --key $KEY --id $DEVICE_ID --token $token" 2>&1)"
if [[ "$pair_reply" == *"pair 200"* ]]; then
  ok "the client paired through /v1/pair ($pair_reply)"
else
  fail "pairing failed: $pair_reply"
fi
vmroot "omarchy-kids-devices list" 2>/dev/null | grep -q "$DEVICE_ID" &&
  ok "the device is in the registry" || fail "the paired device is not in the registry"

# A request for the kid, written root-side in the queue's own format (the kid's own ask path is
# scenario 50's); this scenario is about the decide path, not the ask modal.
now="$(vmroot "date +%s" | tr -d '[:space:]')"
record="{\"kid\": \"$LIVE_KID1_ACCOUNT\", \"kind\": \"time\", \"what\": \"15\", \"minutes\": 15, \"asked_at\": $now, \"state\": \"open\"}"
vmroot "printf '%s\\n' '$record' > /var/lib/omarchy-kids/queue/$REQ_ID.json; chmod 0644 /var/lib/omarchy-kids/queue/$REQ_ID.json" &&
  ok "queued request $REQ_ID" || fail "could not queue the request"

before="$(vmroot "omarchy-kids-time status $LIVE_KID1_ACCOUNT | head -1")"

decide_reply="$(vmroot "python3 /tmp/notify-client.py decide --key $KEY --id $DEVICE_ID --request $REQ_ID --decision approve" 2>&1)"
if [[ "$decide_reply" == *"decide 200"* ]]; then
  ok "the client's signed decision was accepted ($decide_reply)"
else
  fail "decide failed: $decide_reply"
fi

waited=0
granted=0
status="$before"
while ((waited < 90)); do
  status="$(vmroot "omarchy-kids-time status $LIVE_KID1_ACCOUNT | head -1")"
  if [[ -n "$status" && "$status" != "$before" ]]; then
    granted=1
    break
  fi
  sleep 5
  waited=$((waited + 5))
done
if ((granted)); then
  ok "ledger shows the grant ('$before' -> '$status')"
else
  fail "ledger never reflected the approved +15 (still: '$before')"
fi

state="$(vmroot "jq -r '.state' /var/lib/omarchy-kids/queue/$REQ_ID.json 2>/dev/null" | tr -d '[:space:]')"
[[ "$state" == "approved" ]] && ok "the request record is approved" ||
  fail "the request record is not approved (state='$state')"

shot 70-notify-approve || fail "screenshot failed"

# Leave the box as it was: drop the request record and its lock, then revoke the device and
# remove the certificate. What stays: /root/live-device.key, /tmp/notify-client.py, and
# <id>.conf.revoked (by design -- a revoked id stays revoked).
vmroot "rm -f /var/lib/omarchy-kids/queue/$REQ_ID.json /var/lib/omarchy-kids/queue/$REQ_ID.json.lock" >/dev/null 2>&1
vmroot "omarchy-kids-notify disable --apply" >/dev/null 2>&1 &&
  ok "notifications disabled and the device revoked" || fail "disable failed"
kid_budget_restore "$LIVE_KID1_ACCOUNT" && ok "budget headroom restored" || fail "could not restore budget headroom"

scenario_result 70-notify-pair-and-approve
