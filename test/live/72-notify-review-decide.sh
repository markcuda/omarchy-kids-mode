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
vmroot "omarchy-kids-conf set $LIVE_KID1_ACCOUNT apps.extra $APP_ID" >/dev/null 2>&1 &&
  ok "added $APP_ID to $LIVE_KID1_ACCOUNT's apps" || fail "could not set apps.extra"

vmroot "omarchy-kids-review scan --apply" >/dev/null 2>&1 &&
  ok "the first scan stamped the approval" || fail "scan failed"
vmroot "sed -i 's|^Exec=.*|Exec=/usr/bin/false %u|' $DESKTOP" &&
  ok "changed the app's Exec" || fail "could not change the Exec"
vmroot "omarchy-kids-review scan --apply" >/dev/null 2>&1 || fail "the second scan failed"

rid="$(vmroot "ls $REVIEWS 2>/dev/null | head -1 | sed 's/\.json\$//'" | tr -d '[:space:]')"
[[ -n "$rid" ]] && ok "a review opened ($rid)" || fail "no review opened"

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
  vmroot "omarchy-kids-review list" 2>/dev/null | grep -q "$APP_ID" &&
    fail "the review list still shows $APP_ID" || ok "the review list is empty of it"
fi

shot 72-notify-review || fail "screenshot failed"

# Leave the box as it was: the app id out of apps.extra, the review and its baseline entry gone,
# the desktop file removed, notifications off (which revokes the device).
vmroot "omarchy-kids-conf set $LIVE_KID1_ACCOUNT apps.extra ''" >/dev/null 2>&1
vmroot "omarchy-kids-review scan --apply" >/dev/null 2>&1
vmroot "rm -f $DESKTOP $REVIEWS/$rid.json $REVIEWS/$rid.json.lock /var/lib/omarchy-kids/reviews/baseline/$LIVE_KID1_ACCOUNT.json" >/dev/null 2>&1
notify_stop

scenario_result 72-notify-review-decide
