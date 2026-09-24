#!/bin/bash
# 72-notify-review-decide: an approved add-on whose desktop surface changed is approved from the
# scripted client's signed REVIEW frame, and the review clears (R-NOTIFY-12; docs/review.md,
# docs/relayd.md). The app the review is about is a desktop file root writes and the scenario
# removes again, so nothing installed is touched. The client is
# test/live/clients/notify-client.py.
#
# Unverified from a draft: this scenario has not been run from this checkout. AGENTS.md rule 11 --
# only the gate runner drives the VM.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/live/lib.sh
source "$DIR/lib.sh"

KEY=/root/live-device.key
APP_ID="kids-live-review"
DESKTOP="/usr/share/applications/$APP_ID.desktop"
REVIEWS=/var/lib/omarchy-kids/reviews/open

build_install && ok "package installed and pacman -Qkk clean" ||
  fail "package build/install/Qkk gate failed"

boot_with "$LIVE_OWNER_PASSWORD" "$LIVE_OWNER_ACCOUNT" &&
  ok "vm booted" || fail "vm never came up"

portal_reset 30 && ok "greeter is up" || fail "greeter never appeared"

# The add-on, added the way the parent's panel would: a desktop file the launcher resolves, and the
# id in the kid's apps.extra. First scan stamps it (that is the approval), the changed Exec opens a
# review, and the client approves the new surface.
vmroot "printf '%s\n' '[Desktop Entry]' 'Name=Live Review' 'Exec=/usr/bin/true %u' > $DESKTOP; chmod 0644 $DESKTOP" &&
  ok "wrote $APP_ID.desktop" || fail "could not write the desktop file"
# Save what apps.extra held, so the teardown restores it (a kid with no override must not come back
# with an explicit empty list).
apps_before="$(vmroot "omarchy-kids-conf get $LIVE_KID1_ACCOUNT apps.extra 2>/dev/null" | tr -d '[:space:]')"
apps_new="$APP_ID"
[[ -n "$apps_before" ]] && apps_new="$apps_before,$APP_ID"
vmroot "omarchy-kids-conf set $LIVE_KID1_ACCOUNT apps.extra $apps_new" >/dev/null 2>&1 &&
  ok "added $APP_ID to $LIVE_KID1_ACCOUNT's apps" || fail "could not set apps.extra"

# Scoped to the kid throughout: an unscoped scan would also sweep or close other kids' reviews.
vmroot "omarchy-kids-review scan --apply --kid $LIVE_KID1_ACCOUNT" >/dev/null 2>&1 &&
  ok "the first scan stamped the approval" || fail "scan failed"
vmroot "sed -i 's|^Exec=.*|Exec=/usr/bin/false %u|' $DESKTOP" &&
  ok "changed the app's Exec" || fail "could not change the Exec"
vmroot "omarchy-kids-review scan --apply --kid $LIVE_KID1_ACCOUNT" >/dev/null 2>&1 ||
  fail "the second scan failed"

# The review id is deterministic (kid, a dot, sha256(app id)[:16]); compute it rather than take
# whatever file is first, which could be another app's review.
digest="$(vmroot "python3 -c 'import hashlib,sys;print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:16])' $APP_ID" | tr -d '[:space:]')"
rid="$LIVE_KID1_ACCOUNT.$digest"
vmroot "test -f $REVIEWS/$rid.json" >/dev/null 2>&1 &&
  ok "the expected review opened ($rid)" || fail "no review at $rid"

notify_pair_client "$KEY" ||
  fail "the review scenario cannot run without a paired client"

if [[ -n "${NOTIFY_DEVICE_ID:-}" && -n "$rid" ]]; then
  seen="$(vmroot "jq -r '.now' $REVIEWS/$rid.json" | tr -d '[:space:]')"
  review_reply="$(vmroot "python3 /tmp/notify-client.py review --key $KEY --id $NOTIFY_DEVICE_ID --review-id $rid --decision approve --seen $seen" 2>&1)"
  if [[ "$review_reply" == *"review 200"* ]]; then
    ok "the client's signed review decision was accepted ($review_reply)"
  else
    fail "review failed: $review_reply"
  fi
  vmroot "test -e $REVIEWS/$rid.json" >/dev/null 2>&1 &&
    fail "the review was not cleared" || ok "the review cleared"
  vmroot "omarchy-kids-review list --kid $LIVE_KID1_ACCOUNT" 2>/dev/null | grep -q "$APP_ID" &&
    fail "the review list still shows $APP_ID" || ok "the review list is empty of it"
fi

shot 72-notify-review || fail "screenshot failed"

# Leave the box as it was: apps.extra back to what it held (unset if it held nothing), this app's
# own stamp out of the kid's baseline (not the whole file -- it holds the kid's other apps), the
# review files and the desktop file gone, notifications off (which revokes the device).
if [[ -n "${apps_before:-}" ]]; then
  vmroot "omarchy-kids-conf set $LIVE_KID1_ACCOUNT apps.extra $apps_before" >/dev/null 2>&1
else
  vmroot "omarchy-kids-conf unset $LIVE_KID1_ACCOUNT apps.extra" >/dev/null 2>&1
fi
vmroot "omarchy-kids-review scan --apply --kid $LIVE_KID1_ACCOUNT" >/dev/null 2>&1
if [[ -n "${rid:-}" ]]; then
  vmroot "rm -f $REVIEWS/$rid.json $REVIEWS/$rid.json.lock" >/dev/null 2>&1
fi
vmroot "f=/var/lib/omarchy-kids/reviews/baseline/$LIVE_KID1_ACCOUNT.json; if [ -f \"\$f\" ]; then t=\$f.tmp; jq 'del(.\"$APP_ID\")' \"\$f\" >\"\$t\" && mv -f \"\$t\" \"\$f\" && chmod 0640 \"\$f\"; fi" >/dev/null 2>&1
vmroot "rm -f $DESKTOP" >/dev/null 2>&1
notify_stop

scenario_result 72-notify-review-decide
