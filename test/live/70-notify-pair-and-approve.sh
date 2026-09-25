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

KEY=/root/live-device.key
REQ_ID="live-$(date +%s)-$LIVE_KID1_ACCOUNT-time"

build_install && ok "package installed and pacman -Qkk clean" ||
  fail "package build/install/Qkk gate failed"

boot_with "$LIVE_OWNER_PASSWORD" "$LIVE_OWNER_ACCOUNT" &&
  ok "vm booted" || fail "vm never came up"

portal_reset 30 && ok "greeter is up" || fail "greeter never appeared"

kid_budget_headroom "$LIVE_KID1_ACCOUNT" &&
  ok "budget headroom set for the approval run" || fail "could not set budget headroom"

# Enable, start the relay, open a pairing window and pair the client: the shared setup in
# test/live/lib.sh, so the three notification scenarios cannot drift (notify_pair_client sets
# NOTIFY_DEVICE_ID).
notify_pair_client "$KEY" ||
  fail "the notification scenario cannot run without a paired client"

# A request for the kid, written root-side in the queue's own format (the kid's own ask path is
# scenario 50's); this scenario is about the decide path, not the ask modal.
now="$(vmroot "date +%s" | tr -d '[:space:]')"
record="{\"kid\": \"$LIVE_KID1_ACCOUNT\", \"kind\": \"time\", \"what\": \"15\", \"minutes\": 15, \"asked_at\": $now, \"state\": \"open\"}"
vmroot "install -d -m 0750 /var/lib/omarchy-kids/queue; chown root:omarchy-parents /var/lib/omarchy-kids/queue; printf '%s\\n' '$record' > /var/lib/omarchy-kids/queue/$REQ_ID.json; chmod 0640 /var/lib/omarchy-kids/queue/$REQ_ID.json; chown root:omarchy-parents /var/lib/omarchy-kids/queue/$REQ_ID.json" &&
  ok "queued request $REQ_ID" || fail "could not queue the request"

before="$(vmroot "omarchy-kids-time status $LIVE_KID1_ACCOUNT | head -1")"

# notify_pair_client returned non-zero if anything above failed, and fail() does not exit (it just
# marks the scenario FAIL), so every step that needs the device is guarded: an unguarded use of an
# unset NOTIFY_DEVICE_ID would abort under set -u before scenario_result and skip the cleanup.
if [[ -n "${NOTIFY_DEVICE_ID:-}" ]]; then
  # The display binding (amendment section 20): a decision whose signed what
  # does not match the record is refused, and the record stays open.
  mismatch="$(vmroot "python3 /tmp/notify-client.py decide --key $KEY --id $NOTIFY_DEVICE_ID --request $REQ_ID --kid $LIVE_KID1_ACCOUNT --kind time --what 99 --minutes 99 --decision approve" 2>&1)"
  if [[ "$mismatch" != *"decide 200"* ]]; then
    ok "a relabelled decision is refused ($mismatch)"
  else
    fail "a relabelled decision was accepted"
  fi
  state_after="$(vmroot "jq -r '.state' /var/lib/omarchy-kids/queue/$REQ_ID.json" | tr -d '[:space:]')"
  [[ "$state_after" == "open" ]] &&
    ok "the relabelled decision left the record open" ||
    fail "the record is '$state_after' after a relabelled decision"

  decide_reply="$(vmroot "python3 /tmp/notify-client.py decide --key $KEY --id $NOTIFY_DEVICE_ID --request $REQ_ID --kid $LIVE_KID1_ACCOUNT --kind time --what 15 --minutes 15 --decision approve" 2>&1)"
  if [[ "$decide_reply" == *"decide 200"* ]]; then
    ok "the client's signed decision was accepted ($decide_reply)"
  else
    fail "decide failed: $decide_reply"
  fi
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

# R-NOTIFY-7, after the rewrite: the decision was applied by authd as root through
# omarchy-kids-ask, whose write_atomic rewrote this record. Its mode and group now are the
# root branch's, not the scenario's -- the VM is where that chown can be proven (a user
# namespace cannot map omarchy-parents).
mode_dir="$(vmroot "stat -c '%a %U %G' /var/lib/omarchy-kids/queue" | tr -s '[:space:]' ' ' | sed 's/ $//')"
mode_rec="$(vmroot "stat -c '%a %U %G' /var/lib/omarchy-kids/queue/$REQ_ID.json" | tr -s '[:space:]' ' ' | sed 's/ $//')"
[[ "$mode_dir" == "750 root omarchy-parents" ]] &&
  ok "the queue directory is 750 root omarchy-parents" ||
  fail "queue directory modes are '$mode_dir'"
[[ "$mode_rec" == "640 root omarchy-parents" ]] &&
  ok "the record rewrite left it 640 root omarchy-parents" ||
  fail "record modes after the decision are '$mode_rec'"

# R-NOTIFY-6: the kid's own copy of the decision, and the kid reading it. The
# root branch of write_kid_copy's chown cannot be proven off-box.
dec_dir="/var/lib/omarchy-kids/$LIVE_KID1_ACCOUNT/decisions"
mode_dec="$(vmroot "stat -c '%a %U %G' $dec_dir" | tr -s '[:space:]' ' ' | sed 's/ $//')"
mode_copy="$(vmroot "stat -c '%a %U %G' $dec_dir/$REQ_ID.json" | tr -s '[:space:]' ' ' | sed 's/ $//')"
[[ "$mode_dec" == "750 root $LIVE_KID1_ACCOUNT" ]] &&
  ok "the kid's decisions directory is 750 root:$LIVE_KID1_ACCOUNT" ||
  fail "decisions directory modes are '$mode_dec'"
[[ "$mode_copy" == "640 root $LIVE_KID1_ACCOUNT" ]] &&
  ok "the kid's copy is 640 root:$LIVE_KID1_ACCOUNT" ||
  fail "the kid's copy modes are '$mode_copy'"
out_line="$(vmroot "runuser -l $LIVE_KID1_ACCOUNT -c 'omarchy-kids-ask outcome'" | tr -d '\r')"
[[ "$out_line" == *$'\tapproved'* ]] &&
  ok "the kid reads the outcome in their own session ($out_line)" ||
  fail "the kid's outcome did not read approved: '$out_line'"

shot 70-notify-approve || fail "screenshot failed"

# Leave the box as it was: drop the request record and its lock, then revoke the device and
# remove the certificate. What stays: /root/live-device.key, /tmp/notify-client.py, and
# <id>.conf.revoked (by design -- a revoked id stays revoked).
vmroot "rm -f /var/lib/omarchy-kids/queue/$REQ_ID.json /var/lib/omarchy-kids/queue/$REQ_ID.json.lock" >/dev/null 2>&1
notify_stop
kid_budget_restore "$LIVE_KID1_ACCOUNT" && ok "budget headroom restored" || fail "could not restore budget headroom"

scenario_result 70-notify-pair-and-approve
