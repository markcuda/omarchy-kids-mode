# Parental notifications: the owner-directed design (2026-09-22)

Owner directive: "fable 5.1 to determine the most robust, full-featured, exciting implementation and
go with that." This document is that determination, produced by a headless `claude-fable-5-1` run
grounded in this repo (AGENTS.md, SPEC.md, the ask queue, the bar widget, authd). It is the spec
source for the notification workstream; its 14 tickets (N-0..N-13) are implementation-ready and the
loop builds them in order. It resolves `docs/phase1/DECISIONS-NEEDED.md` item 8 with option 3 (the
queue-tightening one). Security review still applies before any trust-boundary code merges.

---

**Ranking, up front.** I recommend option A, the full build: a local broker on the Omarchy box, one Flutter parent app for iOS, Android, macOS and Windows, a native on-box path for Omarchy, LAN-first with zero third parties, and two opt-in "away from home" transports that the parent owns. Option B, LAN-only with desktop clients and a phone experience that works only while the app is open, is the same design with tickets N-10 and N-11 dropped. Option C, a bring-your-own ntfy or Gotify webhook with no app of our own, is cheap and unnative, and survives in A as one courier adapter. The cost of A is real: a new network daemon, a device registry with real cryptography, a four-platform app with store distribution the owner must sign, and a spec amendment. The trust boundary is what makes it affordable: the broker can never approve anything, so its whole attack surface is "notifications stop".

## Architecture and trust boundary

**1.1 What runs where**

| Piece | Runs as | Where | Job |
| --- | --- | --- | --- |
| `omarchy-kids-relayd` (new) | system user `omarchy-kids-relay`, group `omarchy-parents` | the Omarchy box, `/usr/lib/systemd/system/omarchy-kids-relayd.service` | HTTPS on the LAN: pairing handshake, state, a Server-Sent Events stream, decision forwarding. Reads status.json and the queue. Writes nothing root owns. |
| `omarchy-kids-relay-courier` (new, ticket N-11) | same user, separate unit | the box | The only process allowed to talk beyond the LAN. Delivers end-to-end encrypted envelopes to the one server the parent typed and pulls signed decisions back. |
| `omarchy-kids-authd` (extended) | root | existing socket | Three new frames: `PAIR`, `DECIDE`, `ACT`. Verifies device signatures itself against root-owned keys. Peer uid must be the relay account. |
| `omarchy-kids-devices` (new) | root | `bin/` | The device registry: `/etc/omarchy-kids/devices/<id>.conf`, publishes `/run/omarchy-kids/devices.json`. authd's callback, like `apply-grant` today. |
| `omarchy-kids-notify` (new) | the parent | `bin/` | Enable, pair, list, revoke, away mode, test. Every write goes through `sudo` the way the panel's `run_priv` does today. |
| `omarchy-kids-ask` (extended) | root | existing | `approve --by device:<id>`, an optional parent reply line, and the per-kid result file. |
| `omarchy-kids-ask watch` (new verb) | the kid | kid session autostart | Shows the decision card when root writes the result. Reads only a root-written file owned by the kid's group. |
| Parent app, `clients/parent/` (new) | the parent's device | iOS, Android, macOS, Windows, Linux | Pairs, subscribes, shows rich notifications with Approve and Decline actions, signs decisions. |
| Omarchy on-box notifier, `systemd --user` unit (new) | the parent | the parent's session | Desktop notifications with actions from the queue the parent can now read. The bar widget badge reads status.json. |

**1.2 The trust boundary, stated once.** Nothing changes about who decides. Today root decides in two places: `omarchy-kids-authd`'s `GRANT` handler after a password and an SO_PEERCRED check, and `omarchy-kids-ask approve` run under sudo. The broker adds a third caller of the same root path, and it authenticates with a signature root verifies, not with anything the broker says. Concretely:

- A decision arrives at the broker as a JSON object signed with Ed25519 by a paired device. The broker forwards it verbatim to authd as `DECIDE <json>\n`. authd checks that the socket peer's uid is the relay account, that the device file exists under `/etc/omarchy-kids/devices/` and is not revoked, that the timestamp is within five minutes, that the nonce is unseen, and that the signature verifies against the root-owned public key. Only then does it run `omarchy-kids-ask approve <id> --apply --by device:<id>`. A compromised broker can replay nothing: a queue record is decided once, which `lib/ask.py`'s `decide` already enforces at `lib/ask.py:219`.
- Pairing is gated by the parent password through the existing verifier, in the parent's session, and the pairing token never reaches the broker in clear. The device proves possession of it with an HMAC over its public key. So the broker cannot substitute its own key at pairing time.
- The broker reads only what the parent's own session may already read: status.json, mode 0640 root:omarchy-parents, and the queue, which ticket N-1 tightens to the same mode. That resolves item 8 in `docs/phase1/DECISIONS-NEEDED.md` with the loop report's option 3, the one the finding itself called the only option that makes the root guard a real boundary.
- The kid's session gets no new path. It raises requests exactly as today, through its own outbox and the `GRANT` frame. It learns the result from a file root writes into `/var/lib/omarchy-kids/<kid>/`, already 0750 root:kid per SPEC §5.1. A kid process can connect to the relay's TCP port on the box's own address; without a paired key it can reach the pairing endpoint only, which needs a five-minute single-use 40-bit code plus the HMAC proof, and is rate-limited. The worst a flooding kid does is delay notifications. The relay is never a lock, so this joins Appendix G as a stated non-wall.
- AGENTS.md rule 9 holds: no environment variable selects code. The relay's TLS paths, socket path and port are build-time constants; tests substitute them in a copied tree like `KIDS_PY`.

**1.3 Transport tiers, ranked.** The parent sees these as one switch and one optional "away from home" row.

1. **Home, on by default when notifications are on.** Direct HTTPS from the device to the box on the LAN, port 8447, self-signed certificate generated at enable time and pinned by its SPKI hash from the pairing QR. Discovery is a UDP beacon on the same port answering a fixed probe with host, port and SPKI hash, plus mDNS `_omarchy-kids._tcp` through `avahi-publish` when avahi is present. Realtime through SSE. No third party anywhere. The unit carries `IPAddressDeny=any` and an allow list of loopback, link-local, multicast and the RFC 1918 and ULA ranges, so "home network only" is a root-owned kernel-enforced fact, not a label.
2. **Away, tailnet.** The parent already runs Tailscale or WireGuard, as the test laptop does. The pairing record carries every address the box has, the app tries them in order, and a root-written unit drop-in adds the CGNAT range and the Tailscale ULA to the allow list. Still no third party of ours. Cost: small.
3. **Away, mailbox.** The parent types the URL and token of a server they own: ntfy, Gotify, or any UnifiedPush endpoint. The courier posts envelopes encrypted for one device with X25519 and ChaCha20-Poly1305 and pulls signed decisions back from a reply topic. The server sees ciphertext and timing. No inbound reachability is needed. Cost: the courier, the envelope format, two adapters. This is the only tier that gives Android true background delivery without any vendor, through UnifiedPush.
4. **Not built: a project-run push service.** iOS delivers background notifications only through Apple's push service, and only a server holding the app's push key can send them. That server would be ours, a third party in I-2's sense, even if it carried a random token and no content. I recommend not building it in v1 and flag it as open question 1. Until then the honest iOS story is: instant while the app is open or recently open, everything waiting when the parent opens it, and if the parent runs a mailbox, the ntfy iOS app gets a contentless wake through ntfy's own upstream, which the panel discloses and leaves off.

**Is a cloud relay ever allowed?** Under the amendment below: a server the parent named, yes. A server we or a vendor run, no, with the single exception of an opaque wake that carries no content and only after the parent enables it. That line is drawn in I-2 itself, not in a setting.

**1.4 Per-platform client story.**

- **Omarchy, the same box.** The bar widget's badge reads an `open_requests` count from status.json, which the ledger writes root-side. A `systemd --user` unit in the parent's session, installed only on the same consent as the bar widget, watches the queue and posts libnotify notifications with Approve and Decline actions; an action opens `omarchy-kids-bar approve <id>`, the floating terminal and sudo path `bin/omarchy-kids-bar:181` already uses for grants. No pairing needed: this is the parent's own session with the parent's own password.
- **Another Omarchy or Linux machine.** The Flutter Linux build of the parent app, pairing like a phone. It posts notifications through the portal's notification interface.
- **macOS.** The Flutter macOS build as a menu-bar app: kid dots mirroring the Omarchy bar, notifications through `UNUserNotificationCenter` with action buttons, keys in the Keychain, the SSE connection alive because menu-bar agents are not suspended.
- **Windows.** The Flutter Windows build as a tray app with toast notifications and action buttons, keys in the Credential Manager.
- **Android.** The Flutter app with a foreground service at home for realtime SSE, or UnifiedPush when a mailbox is set. Keys in the Android Keystore. Notifications with Approve, Decline and "15 minutes only" actions, answerable from the lock screen.
- **iOS.** The same app. Keys in the Secure Enclave-backed Keychain, local network permission requested at pairing with a plain sentence. Realtime while open. See tier 4.

One codebase for the four remote platforms is the point: the pairing, signing and SSE code is written and tested once. The on-box Omarchy path stays shell and QML, matching the rest of the repo.

**1.5 Wire API, all under `/v1`, JSON, TLS only.**

```text
POST /v1/pair              {code, name, platform, sign_pub, box_pub, proof}
                           -> {device_id, relay_sign_pub, scopes, kids:[...]}
GET  /v1/state             -> {kids:[{account,name,avatar,band,live,paused,minutes_left}],
                               requests:[open...], recent:[decided in the last 24 h]}
GET  /v1/events            SSE: state, request.opened, request.decided,
                           kid.live, kid.paused, kid.timeup, heartbeat every 25 s
POST /v1/requests/<id>/decision   {decision: approve|decline, reply?, signed:{...}}
POST /v1/kids/<account>/grant     {minutes, signed:{...}}        scope act
POST /v1/kids/<account>/end       {signed:{...}}                 scope act
GET  /v1/avatars/<id>.svg
```

Every authenticated request carries `X-Kids-Device: <id>` and `X-Kids-Sig: <ts>.<nonce>.<sig>`, where the signature covers the timestamp, nonce, method, path and body hash. The relay checks that itself for reads using the public keys in `/run/omarchy-kids/devices.json`. For anything that changes state, the `signed` object inside the body is what authd verifies again as root. Two signatures, on purpose: the outer one keeps the relay from serving a stranger, the inner one is the one that matters.

**1.6 Active when Kids Mode is in use.** The relay is not socket-activated and the port is closed most of the day. The screen-time tick, `bin/omarchy-kids-time-ledger`'s `cmd_tick`, starts the unit when any kid is live or any request is open. The panel's pairing screen starts it too. The relay exits on its own after ten minutes with no live kid, no open request and no connected device, and the courier follows. The app shows "Kids Mode isn't running right now" with the last known state, which is true.

**2. Pairing and auth**

Pairing, from the panel or `omarchy-kids-notify pair`:

1. Parent password through the verifier. Root generates a pairing id, a 20-byte token and an 8-character code from a 32-symbol alphabet, writes `/run/omarchy-kids/pairing/<id>` root 0600 with a five-minute expiry, and starts the relay.
2. The panel renders a QR with `qrencode -t UTF8` plus the code and the SPKI hash as six words, for the desktop apps where scanning is awkward. The QR encodes `omarchy-kids://pair?v=1&host=…&port=8447&spki=…&id=…&token=…`.
3. The app generates an Ed25519 signing key and an X25519 box key, stores both in the platform keystore, connects with the pinned SPKI, and posts `sign_pub`, `box_pub`, its name, its platform, and `proof = HMAC-SHA256(token, sign_pub || box_pub || name)`.
4. The relay forwards `PAIR <json>` to authd. authd checks the peer uid, loads the pairing file, verifies the HMAC, deletes the pairing file, and calls `omarchy-kids-devices add`, which writes `/etc/omarchy-kids/devices/<device-id>.conf` root 0600: name, platform, both public keys, `paired_at`, `paired_by`, scopes `decide,act`, and a `label_for_kids` defaulting to "a grown-up". It republishes `/run/omarchy-kids/devices.json`.
5. The reply carries the device id and the relay's own signing key, so the app can verify state pushes were not tampered with by a LAN peer that somehow got past TLS.

Authenticating an approval back to root: the device signs `{request_id, decision, reply, device_id, ts, nonce}` with its Ed25519 key. authd verifies with `python-cryptography`, a new hard dependency, and refuses on any of: unknown or revoked device, scope missing, clock skew over five minutes, nonce seen in the last ten minutes, record already decided. On success the decision is written with `by: device` and `device: <id>` and the action runs through the same `apply_record` at `bin/omarchy-kids-ask:233`. `ACT` is the same shape for a grant or an end-session with no request, scope `act`, calling `omarchy-kids-time grant` and `omarchy-kids-exit --finish --kid`.

Revocation: panel Devices row or `omarchy-kids-notify revoke <id>`, parent password, root renames the file to `<id>.revoked`, republishes `devices.json`, and the relay drops the connection within a second. Lost phone: same. Revoke all: `omarchy-kids-notify disable`, which also removes the TLS key, so old QR codes are dead. `omarchy-kids-assert` re-asserts modes and owners of the devices directory and the relay key on every update, and `omarchy-kids-check` reports it.

Multiple parents: every device is named, every decision records which one. There is still one Unix parent account and one parent password, as I-8 requires. Two devices deciding the same request race on the write-once record; the loser sees "Already approved by Sam's phone, 8 seconds ago" and nothing runs twice.

## Flows, failures, and the amendment

**3. UX flows**

Kid raises a request, no parent present. The modal at `share/ask/shell.qml` says "Asked. Your grown-up will see it." as today. New: it stays as a small "Waiting for a grown-up" chip at the top of the Level 1 grid or the Level 2 picker, fed by a root-written `/var/lib/omarchy-kids/<kid>/requests.json` holding only that kid's own records. The minute timer collects the outbox, the queue record appears, the ledger's next tick writes the count into status.json, and the relay pushes `request.opened` to every connected device and hands the courier an envelope for the rest.

Parent device. A notification: the kid's avatar, "Ada wants 15 more minutes", asked 40 seconds ago, "47 min left today", buttons Approve, Decline, and for time requests "15 min only". Approve from the lock screen signs and posts the decision; the app shows "Done. Ada has 62 minutes left." Decline opens an optional reply line, eight quick chips like "After dinner" and "Not today", limited to 80 printable characters, which root validates on read. The macOS and Windows apps do the same from the menu bar or tray; the Omarchy on-box notifier opens the floating terminal for the sudo prompt, because that session has the parent's own password and needs no device key.

Result shown to the kid. `omarchy-kids-ask decide` now also writes `/var/lib/omarchy-kids/<kid>/decisions/<id>.json`, 0640 root:kid, with the decision, the device's `label_for_kids`, the reply and the time. `omarchy-kids-ask watch`, autostarted in every level config beside `omarchy-kids-time daemon`, shows `share/ask/decided.qml`: a big card with the avatar, "Yes! 15 more minutes." or "Not this time. After dinner." and one Enter to dismiss. Keyboard complete, theme colors from `share/qml/KidsTheme.qml`, and for a time grant the toast from `share/time/toast.qml` updates the minutes.

Parent's panel, new screen P6 Notifications, keyboard-complete like every other screen and shipped as `share/tui/screens/*.toml` once spec 06 lands: an on/off row that names the port and the "home network only" fence in plain words, a Devices list with name, platform, last seen and a Revoke action, "Pair a phone or computer", "Away from home" with Off, My own VPN, and My own push server, and "Send a test". The wizard summary gains one line, "Your phone can get Ada's requests: pair it from the panel." Nothing about notifications is asked in the wizard proper.

Terminal mirror, one command:

```text
omarchy-kids-notify enable [--apply]
omarchy-kids-notify disable [--apply]        revokes every device, removes the relay key
omarchy-kids-notify status
omarchy-kids-notify pair [--name NAME]       parent password on the tty, prints the QR and code
omarchy-kids-notify devices
omarchy-kids-notify revoke <device-id> [--apply]
omarchy-kids-notify rename <device-id> <name> [--apply]
omarchy-kids-notify scopes <device-id> decide[,act] [--apply]
omarchy-kids-notify away off|tailnet|mailbox <url> [--token-stdin] [--apply]
omarchy-kids-notify test
```

`DRY_RUN=1` prints the plan everywhere it writes, per AGENTS.md rule 8; `pair` and `test` run for real on a tty like the other interactive commands.

**4. Failure modes and what the kid sees**

| Situation | System behavior | Parent device | Kid sees |
| --- | --- | --- | --- |
| Box offline from the LAN | Queue and panel unaffected. Relay keeps running, nothing connects. | "Can't reach the computer, last seen 12:04." Actions disabled, no fake state. | Nothing changes: "Waiting for a grown-up". Any parent at the box approves as today. |
| Relay unit down or crashed | `Restart=on-failure`. The ledger tick restarts it. `omarchy-kids-check` shows a red row. | Reconnects with backoff, shows the gap. | Same as above. |
| Notifications enabled, no device paired | Relay idle-exits. Panel says "No devices yet" with the pair action. | n/a | Same as today. |
| Parent away, no away mode | Requests wait. | Nothing until home. | "Waiting for a grown-up". |
| Mailbox server unreachable | Courier retries with backoff, envelopes expire after 24 h, panel shows the last delivery error. | Stale, marked as such. | Same. |
| Two parents decide at once | First signature wins on the write-once record; second gets a typed refusal. | "Already approved by Sam's phone." | One result card. |
| Replayed decision | Nonce ledger and write-once record refuse it. Logged to the journal, never to the parent as noise. | n/a | Nothing. |
| Forged decision, stolen `devices.json` | Public keys only; no private key leaves a device. Signature fails. | n/a | Nothing. |
| Stolen phone | Revoke from the panel with the parent password. Until then that phone can approve, which is the same as a stolen phone that knows the parent's Wi-Fi today. | Revoked device gets a 401 and clears its keys. | Nothing. |
| Kid floods the port | Per-IP connection cap and the `MAX_INFLIGHT` pattern from authd. Enforcement never depends on the relay. | Delays. | Nothing, and nothing granted. |
| Clock skew on a device | Five-minute window; refusal names the skew. | "Your phone's clock is off." | Nothing. |
| Package update | The pacman hook's `omarchy-kids-assert` re-asserts modes, owners, the units and the IP fence. | n/a | n/a |

**5. I-2 amendment, exact text**

Before, `SPEC.md` line 39:

> **I-2 Nothing about a child leaves the machine.** No telemetry, accounts, cloud, or network listener.

After:

> **I-2 Nothing about a child leaves the machine, except to a device the parent paired or a server the parent named, and only after the parent turned notifications on.** No telemetry. No accounts. No cloud that is not the parent's own. The only network listener is `omarchy-kids-relayd`, fenced to the home network by its root-owned unit, running only while Kids Mode is in use and notifications are on. The only outbound connections are to the one address the parent typed, and everything sent there is end-to-end encrypted for one paired device. Nothing about a child ever reaches this project, the package's authors, or any push vendor. A platform push service may carry at most an opaque wake with no content, and only after the parent has enabled it and read what it carries.

AGENTS.md rule 2 becomes: "Nothing about a child leaves the machine except to the parent's own paired devices or a parent-named server, and only when notifications are on (I-2 as amended). The only processes that may open a network connection are the package manager, the DoH template inside the kids browser policy, `omarchy-kids-relayd` on the LAN, and `omarchy-kids-relay-courier` to the parent's own server."

What stays forbidden, in the spec's "decided against" list: any listener other than the relay; any listener while notifications are off; any outbound connection from any other command; any server run by the project or a vendor as a content path; plaintext child data to any server, including the parent's own; usage data, history, app launches or anything from R-DATA-1 beyond the request and status fields Appendix H names; kid sessions reaching the relay with any credential; and pairing without the parent password.

## Tickets and open questions

**6. Ticket breakdown, in order.** Each is one PR, drafted from this document with no further design decision. Live scenarios run only from the gate runner per AGENTS.md rule 11.

1. **N-0 Spec amendment: notifications.** Adds I-2 as above, `R-NOTIFY-1` to `R-NOTIFY-12` (listener fence, relay never decides, device registry root-owned, signature verified by root, pairing gated by the verifier, idle exit, kid result file, queue mode, courier the only egress, per-device scopes, honest labels, assert coverage), Appendix D `by` gains `device` plus `device` and `reply` fields, Appendix H wire and file formats, Appendix G rows for the relay. Resolves DECISIONS item 8 as option 3. Touches `SPEC.md`, `AGENTS.md`, `PRIVACY.md`, `docs/phase1/DECISIONS-NEEDED.md`. Tests: none. Done: the owner has read the amendment text, and every later ticket cites an `R-NOTIFY` id.
2. **N-1 Queue visibility and the bar badge.** Queue directory 0750 root:omarchy-parents and records 0640 (`lib/ask.py:135`, `lib/assert-locks.sh`); `omarchy-kids-ask list` accepts root or a member of `omarchy-parents`; `omarchy-kids --requests` works as the parent; the ledger adds `open_requests` and a `requests` array to status.json; `share/bar/KidsModule.qml` reads the badge from status.json and drops the 30 s `list` poll. Tests: `ask-test.sh` (modes, group read, kid read refused via `unshare`), `status-publication-test.sh`, `bar-menu-rows-test.sh`, `assert-test.sh`. Live: extend `50-ask-grant.sh` to assert the badge count after a queued request. Done: the loop report finding of 2026-09-22 no longer reproduces on the VM.
3. **N-2 The kid sees the answer.** `decide` writes the per-kid result and requests files; `omarchy-kids-ask watch`; `share/ask/decided.qml`; the waiting chip in the Level 1 launcher and Level 2 picker; `reply` validated at read time. Autostart line in `share/hyprland/L{1,2,3}.lua` and the session manifest. Tests: `ask-test.sh` (result file mode and owner, reply validation rejects control characters and length), `launcher-grid-test.sh`, `qml-theme-static-test.sh`. Live: new `51-ask-decided-card.sh`, queue as the kid, approve as root, screenshot the card. Done: approve from the panel produces the card in the kid session within a minute, verified by screenshot.
4. **N-3 Device registry and root verification.** `bin/omarchy-kids-devices`, the devices directory and `devices.json`, authd frames `PAIR`, `DECIDE`, `ACT` with the relay-uid check, Ed25519 through `python-cryptography`, nonce ledger under `/var/lib/omarchy-kids/devices/`, `omarchy-kids-ask approve --by device:<id>`, `omarchy-kids-time grant` and `omarchy-kids-exit --finish` from `ACT`. `omarchy-kids-assert` and `-check` rows. Tests: `devices-test.sh`, `authd-test.sh` extended with key fixtures generated in the test, wrong peer uid refused, replay refused, revoked refused, skew refused; `trust-boundary-test.sh` learns the new constants. Done: a signed decision from a test key is applied by root and a second copy is refused, on Linux, not skipped.
5. **N-4 Package plumbing and the fence.** `sysusers.d` for `omarchy-kids-relay`, PKGBUILD `depends` gains `python-cryptography` and `qrencode`, `optdepends` gains `avahi`, the two units with hardening matching `systemd/omarchy-kids-wifid.service` plus `IPAddressDeny=any` and the LAN allow list, key generation in `omarchy-kids-notify enable`, `KIDS_UNITS` in `lib/assert-locks.sh`. Tests: `pkgbuild-test.sh`, `packaging-test.sh`, `assert-test.sh` (unit file contains the deny line, key mode 0640 root:omarchy-kids-relay). Done: `makepkg` on the laptop installs, `omarchy-kids-check` is green with notifications off.
6. **N-5 `omarchy-kids-relayd`.** asyncio, stdlib `ssl`, a minimal HTTP/1.1 and SSE server, the API in 1.5, outer signature checks, per-IP caps, one-second polling of status.json and the queue, idle exit, UDP beacon, `avahi-publish` best effort. Tests: `relayd-test.sh` starts it on a scratch tree with a test certificate and drives it from a Python client, covering pair, state, events, decision forwarding to a stub authd socket, loopback refusal, idle exit. Done: the shell suite passes on the VM through scenario 05.
7. **N-6 `omarchy-kids-notify` and panel P6.** The command in 3, the panel screen, the wizard summary line, `docs/notify.md`. Tests: `notify-test.sh` (dry-run plans, revoke and disable flows against a scratch tree), `panel-test.sh`. Live: `70-notify-pair-and-approve.sh` pairs a scripted Python client from the runner over the VM's forwarded port, queues a request as the kid, approves from the client, asserts the grant and the kid's card. Done: the scenario is green.
8. **N-7 Lifecycle.** Ledger tick starts the relay, relay idle exit tuned, `ask collect` nudges it, `omarchy-kids-check` rows, journal lines. Tests: `time-test.sh` with a `systemctl` stub proving the start is called only when a kid is live or a request is open, and, per AGENTS.md's stub rule, that it is not called otherwise. Live: `71-notify-idle-exit.sh`. Done: port closed ten minutes after the last kid logs out, checked with `ss` on the VM.
9. **N-8 Parent app foundation.** `clients/parent/` Flutter: pairing by QR and by code, SPKI pinning, keystore, state screen, SSE, notifications with actions, decision signing, reply chips. Android and macOS first, since the owner can run both unsigned. Tests: Flutter unit tests for signing and envelope code with vectors shared with `authd-test.sh`; an integration test against `relayd` in a scratch tree. Done: pair, approve and decline from a real Android phone and a Mac on the laptop's LAN, screenshots in `docs/media/`.
10. **N-9 Omarchy on-box notifier.** The `systemd --user` unit and `omarchy-kids-bar approve|decline`, installed on the bar-widget consent, libnotify actions, `docs/bar.md`. Tests: `bar-test.sh`. Live: extend 70 to approve from a desktop notification action. Done: a queued request shows a notification on the parent's desktop within a minute and Approve works with one sudo prompt.
11. **N-10 Away, tailnet.** Address enumeration into the pairing record, the drop-in with the CGNAT range, app address fallback. Tests: `notify-test.sh` for the drop-in content, `relayd-test.sh` for multi-address state. Live: from the runner over the laptop's tailnet to the VM's forwarded port. Done: approve from off-LAN over the tailnet.
12. **N-11 Away, mailbox.** The courier unit, the envelope format, ntfy and Gotify and UnifiedPush adapters, decisions back through the reply topic, app-side decrypt and UnifiedPush registration on Android. Tests: `courier-test.sh` with a stub HTTP server, envelope vectors shared with the app. Live: a local ntfy on the laptop, phone on mobile data. Done: an Android phone off Wi-Fi receives and approves.
13. **N-12 iOS and Windows builds.** Store-ready projects, local network permission copy, tray and toast on Windows, TestFlight and MSIX artifacts, unsigned. Done: both build in CI and pair on real devices; signing and publishing are the owner's outward-facing step.
14. **N-13 Docs and cards.** `docs/relayd.md`, `docs/devices.md`, `docs/notify.md` "label claims" pass, `PRIVACY.md`, README, the parent card line about pairing and revoking. Done: every `--help` and doc claim checked against the code per AGENTS.md's sixth shape.

**7. Open questions, only where a human must decide**

1. A project-run zero-content push poke for iOS background delivery. I recommend no in v1; it is the only path to a first-class iOS experience, and it is the only thing in this design that is a third party by construction.
2. Store distribution and signing: an Apple developer account, notarization, Play or sideload. Outward-facing, yours, and it gates N-12's last step only.
3. Default scopes for a new device. I recommend `decide` and `act` both on, labeled at pairing, since the person who typed the parent password is holding the phone.

Two things I could not do. One shell command was denied by the sandbox, so I verified the group creation and the kid-side toast path with the search tool instead; nothing in the design rests on the denied command. And the kid-side overlay mechanism for the decision card mirrors `omarchy-kids-time daemon`'s file-watching shape rather than a verified live run, so N-2's live scenario is the proof.
