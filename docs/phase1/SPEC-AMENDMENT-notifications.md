# SPEC amendment: parental notifications (R-NOTIFY)

Status: **approved by the owner, 2026-09-22** — "have fable 5.1 determine the most robust, full
featured, EXCITING implementation and go with that." The design is
`docs/research/2026-09-22-parental-notifications.md` (a headless `claude-fable-5-1` run grounded in
this repo). This document is the exact SPEC.md text to apply, plus the AGENTS.md and PRIVACY.md
edits that follow from it.

Amends SPEC.md: I-2; adds the **R-NOTIFY** section (R-NOTIFY-1..12, and the later
sections continue the numbering with R-NOTIFY-11.x, 12.x, 13, 14 and 15, which SPEC.md also
carries); R-BAR-3 (the status document
gains the open-request count); R-ASK-3 (the queue is now served); Appendix D (`by` gains `device`,
plus `device` and `reply`); Appendix G (relay rows); **Appendix H** (new — the wire and file
formats). Code follows the design's tickets N-1..N-13, in order; N-3/N-4/N-5/N-6 touch the trust
boundary and need independent review before commit.

## 1. I-2, before and after (exact)

Before (SPEC.md line 39):

> **I-2 Nothing about a child leaves the machine.** No telemetry, accounts, cloud, or network listener.

After:

> **I-2 Nothing about a child leaves the machine, except to a device the parent paired or a server
> the parent named, and only after the parent turned notifications on.** No telemetry. No accounts.
> No cloud that is not the parent's own. The only network listener is `omarchy-kids-relayd`, fenced
> to the home network by its root-owned unit, running only while Kids Mode is in use and
> notifications are on. The parent may extend that fence, off by default and only by their own
> action, to the CGNAT range their own VPN uses (N-10); it stays one range and the relay's
> authentication, not the fence alone, is the lock. The only outbound connections are to the one
> address the parent typed, and
> everything sent there is end-to-end encrypted for one paired device. Nothing about a child ever
> reaches this project, the package's authors, or any push vendor. A platform push service may carry
> at most an opaque wake with no content, and only after the parent has enabled it and read what it
> carries.

## 2. New requirement section (paste after R-ASK)

### R-NOTIFY Parental notifications

- R-NOTIFY-1 The only network listener is `omarchy-kids-relayd`, a root-owned system unit whose
  configuration fences it to loopback and the private LAN ranges. It runs only while Kids Mode is in
  use and notifications are enabled, and exits on its own when idle. No listener exists while
  notifications are off. The parent may opt in (N-10) to extend the fence to the CGNAT range their
  own VPN uses; off by default, one range only, and the relay's authentication remains the lock.
- R-NOTIFY-2 The relay never decides. A request decision is authenticated and applied by root
  (`omarchy-kids-authd` / `omarchy-kids-ask`) through the same `apply_record` path the panel uses; an
  add-on review decision and an action (grant/end) are authenticated the same way and then run the
  same command the parent's own surfaces run (the panel's review and screen-time rows and the bar's
  end row: `omarchy-kids-review approve|deny`, `omarchy-kids-time grant`, `omarchy-kids-exit
  --finish`).
  A compromised relay can, at worst, stop delivering notifications.
- R-NOTIFY-3 The device registry is root-owned under `/etc/omarchy-kids/devices/`. Each record holds
  a device's public keys, its scopes and its pairing provenance. Revocation is a root write and
  takes effect on the next request or decision (a held SSE stream is authenticated once at connect).
- R-NOTIFY-4 A decision is accepted only after root verifies a signature from a paired, unrevoked
  device over the exact decision, within a bounded clock skew and with a single-use nonce, against
  the write-once queue record. A seen nonce, a stale timestamp, an unknown device or an
  already-decided record is refused.
- R-NOTIFY-5 Pairing is gated by the parent password through the existing verifier. The pairing code
  is single-use and expires; no device key is established without it.
- R-NOTIFY-6 A kid learns the outcome through a root-written file under their own directory
  (`/var/lib/omarchy-kids/<kid>/decisions/<id>.json`, `0640 root:<kid>` in a `0750 root:<kid>`
  directory, a copy of the queue record's decision and nothing else; §19). The ask overlay shows the
  newest one when it opens. The kid session holds no credential to the relay and gains no new way to
  act: the file is read, never written, by anything a kid runs, and the queue record stays the
  decision of record (R-NOTIFY-4).
- R-NOTIFY-7 The queue is not world-readable: `/var/lib/omarchy-kids/queue/` is `0750
  root:omarchy-parents` and each record is `0640`. `omarchy-kids-ask list` reads for root or a
  member of `omarchy-parents`; `omarchy-kids --requests` works for the parent.
- R-NOTIFY-8 `omarchy-kids-relay-courier` is the only process that may reach beyond the LAN, and only
  to the one server the parent named. Everything it sends is end-to-end encrypted for one paired
  device. No content ever reaches this project, its authors, or a push vendor.
- R-NOTIFY-9 Each device carries per-device scopes (`decide`, `act`). A decision or action without
  its scope is refused.
- R-NOTIFY-10 Every parent-facing label states what is enforced and what is not: the fence ("home
  network only"), the relay's inability to decide, and the platform limit on background delivery.
- R-NOTIFY-11 `omarchy-kids-assert` re-asserts, on every update and every boot, the devices
  directory and conf modes, the units list, and the away drop-in that widens the relay's fence
  (R-NOTIFY-11.1). It never rewrites the packaged unit that carries the fence itself.
  `omarchy-kids-check` has a row for the fence, a row for the away drop-in and a row for the devices,
  each stating what it proves and what it cannot (R-NOTIFY-11.2, R-TRUST-2).
- R-NOTIFY-12 Update re-approval rides the same system: when an approved add-on's surface set or
  exec changes, the parent is notified and may approve, deny, or **check** it (Check shows what
  changed and decides nothing; it is not an onboard agent that assesses the change, `docs/review.md`).

## 3. R-BAR-3 (exact)

Before:

> R-BAR-3 Reads `/run/omarchy-kids/status.json`, root-written, group `omarchy-parents` readable.

After:

> R-BAR-3 Reads `/run/omarchy-kids/status.json`, root-written, group `omarchy-parents` readable.
> The document carries each live kid's minutes-left and paused state and the open-request
> count (`open_requests`); the bar widget's badge reads the count from the document rather than running
> any command.
> It also carries the pairing window's expiry (`pairing_open_until`), never the token, so the relay
> can keep itself up while a phone pairs (R-NOTIFY-2/5), and the open add-on review count
> (`reviews`, R-NOTIFY-12).

## 4. Appendix D (exact)

Before the closing sentence, the record gains two fields and one `by` value:

`... "by": "keyboard|panel|widget|device", "device": string?, "reply": string? }`

`device` names the registry id that decided; `reply` is the parent's optional line, validated at read
time (printable, bounded length).

## 5. Appendix G additions

| Actor | Path | Why it is not a way past a lock |
| --- | --- | --- |
| Kid → `relayd` TCP port | Kid connects to the box's own address | Reaches the pairing endpoint only, which needs the parent password; the relay holds no decision power (R-NOTIFY-2). Flooding delays notifications and nothing else. |
| Paired device → root decision | Signed decision via the relay | Root verifies the signature against a root-owned key; the relay and the device both fail closed (R-NOTIFY-4). |

## 6. Appendix H (new) — notification wire and file formats

```text
POST /v1/pair                       {id, name, platform, sign_pub, box_pub, proof} -> {reply}
GET  /v1/state                      -> {kids:[...], requests:[open...], recent:[decided<24h]}
GET  /v1/events                     SSE: one `state` event per change, plus a heartbeat
POST /v1/requests/<id>/decision     {record:{...}, signature}
POST /v1/kids/<account>/grant       {minutes, signed:{...}}      scope act
POST /v1/kids/<account>/end         {signed:{...}}               scope act
GET  /v1/avatars/<id>.svg
```

Authenticated requests carry `X-Kids-Device: <id>` and `X-Kids-Sig: <ts>.<nonce>.<sig>`; a decision,
review decision or action POST carries `{record, signature}` (a state *read* has no such body, and
the SSE stream is authenticated once at connect), and root re-verifies the signature before
applying it (R-NOTIFY-4).

`proof` on `/v1/pair` is `HMAC-SHA256(token, sign_pub|box_pub|name)`: the pairing token (the QR's
credential) never travels, only a proof that the device holds it. The `grant`/`end` routes above are
the ACT frame's (§12); a device learns its scopes and the kids from `GET /v1/state`.

Away envelopes (R-NOTIFY-8, N-11: the box-side courier that seals and carries them is built, `docs/courier.md`; the app package opens them (`clients/parent/lib/relay_client.dart`) but its mailbox view is not built) are `{v, device_id, eph_pub, nonce, ct}`: a fresh ephemeral X25519 key does ECDH with the device's `box_pub`, HKDF-SHA256 (salt `omarchy-kids-envelope-v1`, info `x25519-chacha20poly1305`) derives the key, and ChaCha20-Poly1305 seals the document with a 12-byte nonce and the device id as associated data. `lib/envelope.py` seals; the device opens with its private box key; `clients/parent/test-vectors/notify-vectors.json` carries the vectors the app must reproduce. The envelope is confidential, not authenticated: anyone holding the device's public key can seal one, so the app must treat a sealed state document as untrusted display data and never act on it -- the decisions it sends the other way are signed by the device and verified by root. A box identity key (or a timestamp) is a later version's job.

File formats: `/etc/omarchy-kids/devices/<id>.conf` (root 0600: name, platform, both public keys,
`paired_at`, `paired_by`, scopes, `label_for_kids`); `/run/omarchy-kids/pairing/<id>` (root 0600, the
single-use pairing record). `/var/lib/omarchy-kids/<kid>/decisions/<id>.json` (`0640 root:<kid>` in a
`0750 root:<kid>` directory, the result the kid's session reads through `omarchy-kids-ask outcome`,
which the ask overlay shows; §19).

## 7. AGENTS.md rule 2 and PRIVACY.md

AGENTS.md rule 2 becomes: "Nothing about a child leaves the machine except to the parent's own paired
devices or a parent-named server, and only when notifications are on (I-2 as amended). The only
processes that may open a network connection are the package manager, the DoH template inside the
kids browser policy, `omarchy-kids-relayd` on the LAN, and `omarchy-kids-relay-courier` to the
parent's own server."

PRIVACY.md gains a "Parental notifications" section stating: the relay is local and fenced; the
courier talks only to the parent's own server; everything sent is end-to-end encrypted for one
paired device; nothing reaches the project or any vendor; and the iOS caveat (no first-party
background push in v1).

## 8. Decided against (add to the spec's list)

- Any listener other than the relay; any listener while notifications are off.
- Any outbound connection from any command other than the courier.
- Any server run by the project or a vendor as a content path.
- Plaintext child data to any server, including the parent's own.
- Any data beyond the request and status fields this appendix names.
- A kid session reaching the relay with any credential.
- Pairing without the parent password.

## 9. R-NOTIFY-12 over the relay (exact)

R-NOTIFY-12 says an add-on change notifies the parent and they may approve, deny, or check it. The
box side is `omarchy-kids-review`; the panel and the desktop notifier read it locally. This makes the
same review reachable from a paired device, over the wire the requests already use.

- R-NOTIFY-12.1 **State.** The `/v1/state` document gains `reviews`, the open add-on reviews. One row
  per file in `/var/lib/omarchy-kids/reviews/open/` whose name is exactly `<kid>.<16 lowercase
  hex>.json`, read through the relay's `omarchy-parents` membership:

  `{"id": "<kid>.<hash>", "kid": "...", "app": "<app id>", "was": "<hex>", "now": "<hex>",
  "detected_at": <int>}`

  `id` is the review id (the file name without `.json`); `app` is the record's own `id`; `was` and
  `now` are the surface fingerprints as written. Rows are in file-name order. Best-effort, like
  `requests`: a missing directory is `[]`, and a file that does not parse to an object, whose
  `state` is not `"open"`, whose `kid` is not the name's kid part, or whose
  `sha256(app)[:16]` is not the name's hash part, is skipped. A row never carries a token, a
  decision, a path or a desktop-file body. A change to the directory is a state change (one `state`
  event). An open review does **not** hold the relay up: `is_needed` is unchanged, so a review can
  stay open for days while the relay still exits when idle (R-NOTIFY-1).

- R-NOTIFY-12.2 **Route.** `POST /v1/reviews/<review-id>/decision`, body `{record:{...},
  signature}`. The relay authenticates the caller exactly as a request decision does; a failure is
  `403 {"error": <reason>}`. It requires `<review-id>` to match `^[a-z_][a-z0-9_-]*\.[0-9a-f]{16}$`
  and the body to parse to an object whose `record` is an object with `record.review_id` equal to the
  path id and which has a `signature`; anything else is `400 {"error": "malformed"}`. It does not open
  the review file, compare fingerprints or read the device's scopes: it forwards the body verbatim as
  `REVIEW <json>\n` to authd. `502` on a transport failure; otherwise authd's reply passes through
  (`200 {"reply": "ok"}`, else `403 {"reply": "no <reason>"}`). The relay never decides (R-NOTIFY-2).

- R-NOTIFY-12.3 **Frame and record.** The prefix is `REVIEW `. Who may present it is who may present
  `DECIDE` (the relay account, or root). The signed record is exactly

  `{"device_id", "review_id", "decision", "seen", "ts", "nonce"}`

  and nothing else: no `request_id`, no `reply`. `decision` is `"approve"` or `"deny"` (the command's
  own verbs, not `DECIDE`'s `approve`/`decline`); `seen` is the `now` value the app displayed: a
  64-character lowercase hex sha256, or the literal `"missing"` for a desktop file that no longer
  resolves (the command's own sentinel, `bin/omarchy-kids-review`). The signed bytes are `canonical(record)` (the same
  `omarchy-kids-decision-v1\n` context). A `DECIDE` record can never verify as a `REVIEW` record or
  the reverse: each has a required key the other forbids (`request_id` / `review_id`). The scope is
  `decide`, taken from the root-owned registry, never the frame. Skew and the per-device nonce ledger
  are the same, so one nonce cannot be spent once as a decision and once as a review. The refusals are
  `verify_decision`'s, in the same order.

- R-NOTIFY-12.4 **Apply.** After verification, authd (root) re-reads
  `/var/lib/omarchy-kids/reviews/open/<review_id>.json` itself (`O_NOFOLLOW`, a root-owned regular
  file, `state == "open"`) and takes `kid` and `id` from the file. Missing, or any failure, or a kid
  or app id that does not match the review id's parts, is `no no-such-review` (the nonce stays
  burned). A file whose `now` is not the record's `seen` is `no changed-again`. It then runs, with a
  30-second timeout and no shell, `omarchy-kids-review approve <kid> <id> --seen <seen> --apply` or
  `omarchy-kids-review deny <kid> <id> --apply`. The signed fingerprint rides through to `approve`,
  which re-checks it against the live surface **under the same flock `scan` takes** and exits 3 when
  they differ; authd maps that to `no changed-again`. Comparing at authd alone would be a re-read and
  not a lock (rule 4): a `scan` could rewrite `now` between the two. So the parent decides the surface
  they looked at, and a surface that moved reopens on the next scan. The residual is the microseconds
  between the command's own `fingerprint` call and its `baseline_set`, which no lock can close. A
  non-zero exit, a timeout or a spawn failure is `no apply failed`, and a failed deny leaves the
  review open (the command's own rule).

- R-NOTIFY-12.5 **Check.** Check is local and read-only, as before: on the box
  `omarchy-kids-review show` and the panel; in the app, the row's `was` and `now` and nothing more.
  There is no review-diff route, no frame and no decision behind Check.

## 10. Appendix H, added

```text
GET  /v1/state                       -> {kids, requests, recent, reviews:[open add-on reviews]}
POST /v1/reviews/<review-id>/decision {record:{device_id,review_id,decision,seen,ts,nonce}, signature}  scope decide
```

`/var/lib/omarchy-kids/reviews/open/<kid>.<sha256(app)[:16]>.json` (0640 root:omarchy-parents, the
directory 0750 root:omarchy-parents): `{kid, id, was, now, detected_at, state:"open"}`, root-written
by `omarchy-kids-review scan`, deleted by a successful approve or deny. The relay reads it; only root
decides on it.

## 11. The ACT frame (exact)

Appendix H names two routes, `grant` and `end`, and marks them not built. R-BAR-2 says the bar's
"give more time" and "end session" go through a polkit-gated helper with the parent password. This
is the other way in: a paired device with the `act` scope, whose signature is the authentication,
reaching the same two root commands the bar reaches, with no terminal and no password.

- R-NOTIFY-13.1 **Routes.** `POST /v1/kids/<account>/grant`, body `{record:{...}, signature}`, and
  `POST /v1/kids/<account>/end`, body `{record:{...}, signature}`. (Appendix H's `{minutes,
  signed:{...}}` sketch is replaced by this: `minutes` lives inside the signed record and nowhere
  else, so an unsigned copy cannot disagree with the signed one.) The relay authenticates the caller
  exactly as a request decision does (`X-Kids-Device`, `X-Kids-Sig` over method, path and body); a
  failure is `403 {"error": <reason>}`. It then requires, before anything is forwarded:
  `<account>` matches `^[a-z_][a-z0-9_-]*$`; the body parses to an object whose `record` is an
  object and which has a `signature`; `record.account` is a string equal to the path account;
  `record.action` is `"grant"` on the grant route and `"end"` on the end route; on the grant route
  `record.minutes` is a JSON integer (not a bool, not a string, not a float) in `1..1440`; on the
  end route the `minutes` key is absent. Anything else is `400 {"error": "malformed"}`. The relay
  does not read the device's scopes, the kids directory, `status.json` or the time files, and it
  does not check that the account is a kid: it forwards the body verbatim as `ACT <json>\n` to
  authd. `502` on a transport failure; otherwise authd's reply passes through (`200 {"reply":
  "ok"}`, else `403 {"reply": "no <reason>"}`). The relay never acts (R-NOTIFY-2).

- R-NOTIFY-13.2 **Frame and record.** The prefix is `ACT `. Who may present it is who may present
  `DECIDE` (the relay account, or root); the courier does not carry it on this branch, so an ACT is
  LAN-only. The signed record is exactly

  `{"device_id", "account", "action", "minutes", "ts", "nonce"}` for a grant, and
  `{"device_id", "account", "action", "ts", "nonce"}` for an end,

  and nothing else: no `request_id`, no `review_id`, no `reply`. `action` is `"grant"` or `"end"`;
  `minutes` is required for `grant` and forbidden for `end`, an integer in `1..1440` (the same
  `MAX_MINUTES` the ask path uses: a grant is more screen time today, not a new policy);
  `account` matches `^[a-z_][a-z0-9_-]*$`. The signed bytes are `canonical(record)` (the same
  `omarchy-kids-decision-v1\n` context). An ACT record can never verify as a `DECIDE` or `REVIEW`
  record or the reverse: each has a required key the others forbid (`action` / `request_id` /
  `review_id`). The scope is `act`, taken from the root-owned registry, never the frame; a device
  paired with `decide` alone is refused `scope-missing` (R-NOTIFY-9). Skew (`SKEW_SECONDS`) and the
  per-device nonce ledger are the same, so one nonce cannot be spent once as a decision and once as
  an action. The refusals are `verify_decision`'s, in the same order, and nothing touches the ledger
  until the signature is good.

- R-NOTIFY-13.3 **Apply.** After verification, authd (root) validates the target itself, before any
  command runs: `account` must match the shape again, must not be `root`, must not be the account
  of any uid below 1000, and `/etc/omarchy-kids/kids/<account>.conf` must be a regular file (the
  same test the ask path uses for "a provisioned kid account"). The parent's own account is never a
  target: it has no profile there, and a signed ACT naming it is `no not-a-kid` (I-1). Any failure
  of these is `no not-a-kid`, one reason for all of them, and the nonce stays burned. For a grant
  `minutes` is an integer in `1..1440` enforced by the record shape before the signature is checked
  (`no malformed` otherwise), and it reaches the command as its decimal digits. It then runs, with
  a 30-second timeout and no shell, `omarchy-kids-time grant <account> <minutes>` for a grant, or
  `omarchy-kids-exit --finish --kid <account>` for an end. `omarchy-kids-time grant` validates the
  minutes but not the account, which is why authd validates the account before it; `omarchy-kids-exit`
  resolves the account with `id -u` and refuses an unknown one, and is never replaced by a direct
  `loginctl` call. A non-zero exit, a timeout or a spawn failure is `no apply failed`. A grant
  adds to today's one-off grant in `/var/lib/omarchy-kids/<account>/usage/<day>.grant` (the writer
  `lib/time.sh`'s `time_grant_add` uses, `docs/time.md`) and is picked up by the next tick, which
  re-publishes `/run/omarchy-kids/time/<account>.json`; the grant itself does not unlock a locked
  screen faster than that tick. An end asks
  each of the account's Hyprland instances to exit and, if none is found or none goes away, falls
  back to `loginctl terminate-user`, which ends every session the account has (the command's own
  rule, `docs/exit.md`); authd does not check `status.json` for whether the kid is live, because a
  re-read of that file would not be a lock (rule 4).

- R-NOTIFY-13.4 **What it is not.** An ACT is not a kid's request: it writes no queue record, has
  no `request_id`, appears in neither `requests` nor `recent`, and `omarchy-kids-ask list` never
  shows it. It is not the polkit/password path: no prompt is shown, no parent password is read, and
  the bar's own rows keep going through `sudo` as before. It cannot pause: there is no `"pause"`
  action (pause is not available, `omarchy-kids-exit --pause`), and an action value other than
  `grant` or `end` is `malformed`. It cannot push lights-out, change a budget, or grant tomorrow: a
  grant extends today's budget only (R-TIME-4). It cannot target the parent, root or any system
  account (R-NOTIFY-13.3). A device with the `decide` scope alone cannot present it. The app labels
  the two buttons by what they do: "more time today" and "end session", never "pause".

- R-NOTIFY-13.5 **Idle rule.** A grant or an end never holds the relay up: `is_needed` is
  unchanged. Both are one-shot; a live kid already holds the relay up on their own, and a grant for a
  kid who is not live, or an end after the session has gone, leaves nothing to wait for. The applied
  result is visible on the next `state` event (`minutes_left`, or the kid's `live` flag going
  false) and is never carried in a separate document.

## 12. Appendix H, amended

Replace the two `scope act` lines with:

```text
POST /v1/kids/<account>/grant       {record:{device_id,account,action:"grant",minutes,ts,nonce}, signature}  scope act
POST /v1/kids/<account>/end         {record:{device_id,account,action:"end",ts,nonce}, signature}            scope act
```

and strike "the `grant`/`end` routes above are the ACT frame's and are not built on this branch".
The relay forwards either body as `ACT <json>\n`; authd verifies the signature against the
root-owned registry with scope `act`, checks the account is a provisioned kid, and runs
`omarchy-kids-time grant` or `omarchy-kids-exit --finish --kid` as root. No file is written by the
frame itself; the grant lands in `/var/lib/omarchy-kids/<account>/usage/<day>.grant` through the
time command's own writer (`lib/time.sh`), and the tick re-publishes the runtime state.

## 13. The app's own notifications (exact)

R-NOTIFY says the parent is notified; on the box that is `omarchy-kids-notify-watch` (N-9, `docs/notify.md`). The app (N-12) shows the same requests and reviews in its lists, fed by `/v1/events`. This is what the app itself may raise as a platform notification on the paired device, and what it may not.

- R-NOTIFY-14.1 **Source and trigger.** The only source is the `state` document as delivered by the `/v1/events` feed. The app keeps, in memory and for the life of the process only, the set of request ids and review ids the **last document carried**. The first document of a run seeds that set and raises nothing. On every later document the app raises exactly one notification for each id in `requests` or `reviews` the previous document did not carry, then replaces the set with the new document's ids. An id the new document no longer carries is forgotten, so a review the parent decided on the box and a later scan reopened **under the same id** raises again, while a reconnect that replays the same document raises nothing (it carries the same ids). Nothing else raises one: not an id already in the set (a repost, a reconnect that replays the document, a heartbeat), not the passage of time (no reminder, no repeat), not an id leaving `requests` or `reviews` (a decision taken on the box, on another device, or by expiry), not a change to `kids` or `recent` (a login, a session end, a grant, `minutes_left`), not the feed connecting or dropping, and not a document from any other path (a `/v1/state` read, an away envelope). A reconnect diffs against the set, not against a fresh baseline: a request that arrived while the connection was down and the process was alive is new and is raised once. The set is never persisted: a fresh run starts silent, because a persisted set would raise, on open, things that arrived while the app was not running, which is exactly what R-NOTIFY-14.2 says the app cannot do.

- R-NOTIFY-14.2 **When.** A notification can be raised only while the feed is connected: the app in the foreground, or alive in the background for as long as the platform keeps the process and its connection. The app asks nothing more of the platform: no push token, no background-refresh or scheduled-task registration, no "keep alive" service. When the app is not running, or the platform has suspended it, there is no notification in v1; the request waits on the box (and on its own desktop notifier) until the app is opened. The label, on the pairing screen and under the list, is exact: **"Notifies while the app is open. Nothing arrives while it is closed; open it to see what is waiting."** The app requests the platform's notification permission once, after pairing; a refusal replaces that label with "Notifications are off for this app in your system settings. Open the app to see what is waiting." and changes nothing else (the lists and decisions work without it). Where this build has no adapter at all (Windows in v1), the note is instead **"This platform has no notifications in this build. Open the app to see what is waiting."** -- there is no setting to blame, so the label says what is true.

- R-NOTIFY-14.3 **Content, payload, actions.** The title is the same string the list row shows: `describeRequest` for a request (the kid's display name the app already shows for that account, or "Your kid", and the `kind`/`what`/`minutes` the document carries) and `describeReview` for a review. The body is one fixed line: "Open to approve or decline" for a request, "Open to approve, deny or check" for a review. Nothing else from the document is placed in a notification: no account name beyond that kid's display name, no `was`/`now`, no id in visible text, no kid status. The payload is `{"kind": "request"|"review", "id": <id>}` and nothing more. A tap opens the request screen or the ReviewScreen for that id if it is in the current document, else the list. **There are no action buttons.** The box's notifier offers Approve/Decline/Deny/Check because each button lands at the parent's own terminal and sudo prompt: the password is the authentication and the screen is the review. On the device the signature is the authentication, so a button would sign a decision with no screen between the notification and the record: no reply chip, and for a review no `was`/`now` shown, which R-NOTIFY-12.3 requires (the parent signs the surface they looked at). Platform actions can also fire from a locked lock screen, and a handler that runs while the app is suspended has no feed to reconcile against. So a tap opens the screen that decides, and the decision goes through the same signed path as one taken from the list. Check is what ReviewScreen shows (R-NOTIFY-12.5); it is never a notification button.

- R-NOTIFY-14.4 **Identity, grouping, dismissal.** One notification per request id or review id. Its platform id is derived, not allocated: the first four bytes of `sha256("request:" + id)` or `sha256("review:" + id)` masked to a non-negative 31-bit integer. Raising the same id again replaces; it never stacks. All of the app's notifications sit in one platform channel/group ("Kids Mode", default importance, platform default sound); there is no per-kid channel or group, because a channel's name is stored by the platform outside the app. On every document the app cancels each notification it raised whose id is no longer in `requests` or `reviews`: that is how a decision made elsewhere, or an expiry, clears an already-shown notification. Absence from the document is the signal (and a review decided and later reopened carries the same id, so R-NOTIFY-14.1 raises it again); `recent` is not consulted (a review never appears there). On process start, and on Forget, the app cancels every notification it owns: the platform keeps them after the process dies, and a fresh run cannot tell which are still open until its first document, which raises nothing.

- R-NOTIFY-14.5 **What it is not.** It is not delivery: nothing about a request or review leaves the box for the device except over the feed the device already holds (I-2 as amended); a notification is local to the device and carries nothing to anyone. It is not a wake: no push service (APNs/FCM or any other), no push token, no server, no background fetch, no scheduled task, no badge count, no reminder, are built or registered in v1; a platform push that carries an opaque, contentless wake is a later version's question and is not this. It does not notify for a kid action or a kid state: no login, logout, session end, grant, end, or minutes change ever raises one. It does not decide: no signed record is produced from a notification. And it never reads the away envelope: the app does not use the courier for this.

## 14. R-NOTIFY-10 (exact)

Replace "and the platform limit on background delivery" with:

> and the app's own delivery limit: it notifies only while it is open and its feed is connected, nothing arrives while it is not running, and a tap opens the screen that decides rather than deciding itself (R-NOTIFY-14).

## 15. R-NOTIFY-11 (exact)

R-NOTIFY-11 becomes:

> - R-NOTIFY-11 `omarchy-kids-assert` re-asserts, on every update and every boot, the devices directory and conf modes, the units list, and the away drop-in that widens the relay's fence (R-NOTIFY-11.1). It never rewrites the packaged unit that carries the fence itself. `omarchy-kids-check` has a row for the fence, a row for the away drop-in and a row for the devices, each stating what it proves and what it cannot (R-NOTIFY-11.2, R-TRUST-2).

and strike "Re-asserting the relay's address fence, and a `omarchy-kids-check` row for the relay and the devices (only the `units` row exists), are not built on this branch."

- R-NOTIFY-11.1 **The `relay-away` lock.** One new machine-level lock, id `relay-away`, asserted next to `units` and `devices` on both the no-kids path and the full path. It owns exactly `/etc/systemd/system/omarchy-kids-relayd.service.d/away.conf` and the directory that holds it, and nothing else. The fence itself is `[Service]` of `/usr/lib/systemd/system/omarchy-kids-relayd.service` (`IPAddressAllow=localhost link-local multicast 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fe80::/10`, `IPAddressDeny=any`, R-NOTIFY-1); that file is the package's, and no lock ever writes it. The drop-in's presence is the parent's consent (N-10): the lock never creates it and never deletes it, and the only thing it ever writes is the one text below, byte for byte:

  ```text
  # Kids Mode: "Away from home: my own VPN" (N-10), written by
  # omarchy-kids-notify away tailnet. Extends the relay's fence to the CGNAT range
  # Tailscale uses, so a device on the parent's own tailnet can reach it. "away off"
  # removes this file. The LAN list is repeated so this file is correct whether
  # systemd merges IPAddressAllow or replaces the unit's.
  [Service]
  IPAddressAllow=localhost link-local multicast 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fe80::/10 100.64.0.0/10
  ```

  `ok` is: the directory is absent, or it is a directory (not a symlink), root-owned, `0755`, and `away.conf` is absent; or `away.conf` is a regular file (not a symlink), root-owned, `0644`, and its content is exactly the text above. Any other `*.conf` in that directory is a `fail` of this lock (assert prints the lock id; list the directory to see which file), whether or not it names `IPAddress*`: a second drop-in is where a widened or replaced fence would live, and assert cannot tell an admin's file from an attacker's. It returns `2` only when the directory exists and cannot be read.

  `fix` is: if the directory exists, set it to root `0755`; if `away.conf` exists, rewrite it to the text above through a temporary file in the same directory and `mv -f`, then `chmod 0644`; then, on a live system only (no `--root`), `systemctl daemon-reload` and `try-restart omarchy-kids-relayd.service`, so the running fence is the file's and not a stale one. A foreign `*.conf` is not this lock's to repair: `fix` does not remove, rename or rewrite it and returns `1`, so the run ends non-zero and the pacman hook says so on every update until a human removes the file or accepts a failing assert. `fix` never creates `away.conf` (that would be consent the parent did not give) and never deletes it (that would revoke consent the parent did give; `omarchy-kids-notify away off` is the only remover).

- R-NOTIFY-11.2 **The check rows.** Three rows under Locks, each through assert's `*_ok` only (`lock_check`; no `*_fix` is ever called by check):

  - `lock:relay-fence`, verify-only. `relay_fence_ok` requires `/usr/lib/systemd/system/omarchy-kids-relayd.service` to be a root-owned regular file whose `[Service]` section carries exactly one `IPAddressAllow=` line equal to the packaged list and exactly one `IPAddressDeny=any` line. On a live system it also reads `systemctl show omarchy-kids-relayd.service` and requires `FragmentPath` to be the packaged unit (a full override in `/etc/systemd/system` shadows it and is a fail), the effective deny to be `any` (systemd expands it to the two catch-all prefixes `0.0.0.0/0 ::/0`, which is what `systemctl show` reports; either form is accepted), and the effective allow set — systemd expands `localhost`, `link-local` and `multicast` to their prefixes (`127.0.0.0/8 ::1/128`, `169.254.0.0/16 fe80::/64`, `224.0.0.0/4 ff00::/8`; the comparison is over that expansion, as a set, order and duplicates ignored, and each side is first reduced by dropping a prefix another on that side covers — the packaged list names `fe80::/10`, which covers the zone's `fe80::/64`, and both sides are reduced the same way, so it does not matter whether systemd names the wider prefix alongside the zone's narrower one; a report that dropped the packaged `fe80::/10` would fail, as it should) — to be exactly the packaged list when `away.conf` is absent, or the packaged list plus `100.64.0.0/10` when it is present. Absent file (the package is not installed here) is `2`, a warn. A fail is not `lock_check`'s standard text: it says "the relay's fence differs from what the package installed; reinstall `omarchy-kids` (a packaged file, which `omarchy-kids-assert` never rewrites) and remove any drop-in you did not write", because there is no assert lock behind this row. Proves: the packaged fence is intact and, live, that what systemd applies is that fence, plus the away range if and only if the parent's consent file is present. Cannot: that the relay is running, that the fence is a firewall (it binds one unit's sockets; it is not `nftables` and covers no other process), or that the unit was not replaced by someone with root who also replaced the package's copy.
  - `lock:relay-away`, through `relay_away_ok`, repairable, so the standard fail text names `omarchy-kids-assert`. Proves: the away drop-in is absent (the relay is fenced to the LAN) or is exactly the consent file, root `0644`, and no other drop-in sits beside it. Cannot: that the parent, rather than anyone with root, put it there; that the relay has been reloaded since it was written (the fence row's live check is what shows that); that any tailnet exists or that a device on it is one the parent paired.
  - `lock:devices`, through `devices_ok`, repairable, standard fail text. Proves: `/etc/omarchy-kids/devices` is absent or is a root-owned `0750` directory whose every `*.conf` is root-owned `0600`. Cannot: that a record parses, that its keys belong to the parent's device, that a device the parent revoked is gone, or that any record has ever been used.

  `docs/assert.md`'s lock table gains `relay-away`; `docs/check.md`'s Locks section gains the three rows with the proves/cannot text above, and its `relay-fence` entry says in so many words that a fail there is a reinstall, not an assert.

- R-NOTIFY-11.3 **What none of this proves.** The fence is the unit's, not the machine's: `IPAddressAllow`/`IPAddressDeny` bind the relay's sockets and nothing else, and no row claims a firewall. An intact fence says nothing about whether the relay is up: a stopped relay delivers nothing and passes every row (the `units` row covers enabled and active, not that a connection would succeed). A held SSE stream is authenticated once at connect (R-NOTIFY-3): a device revoked, or a drop-in removed, after the connect keeps the stream it already holds until the relay restarts or the stream drops, and no row can see that stream. Every one of these files is root-owned, so anyone with root can change any of them, and assert then restores only what it owns: `away.conf`'s content and modes, the devices modes; not the packaged unit, not a foreign drop-in, not the registry's contents. The rows say "matches what `omarchy-kids-assert` expects" and never "the relay is reachable only from home".

## 16. Recently decided (exact)

Appendix H's `/v1/state` has carried `recent` since section 6, and the app has parsed it into `RecentDecision` since R-NOTIFY-14 landed, but nothing reads it: the parent decides a request and the row vanishes from the app with no trace. The `recent` list is the trace. It is read-only display of what the box already recorded, nothing more.

- R-NOTIFY-15.1 **Row.** `build_state` keeps one row builder for both lists. A row in `requests` is exactly `{id, kid, kind, what, minutes, asked_at}` and gains nothing from this section. A row in `recent` is that row plus `state` (string, `"approved"` or `"declined"`, the record's own), `decided_at` (integer, unix seconds, the record's own; a record whose `decided_at` is not an integer within `RECENT_SECONDS` of now is not in `recent`, as today), and `reply` (string, present only when the record carries a non-empty string; an absent, empty or non-string `reply` puts no key on the row). The row carries nothing else from the record: not `by`, not `device`, not the path. Order on the wire stays file-name order (`<unix-ts>-<account>-<kind>`, so the order asked); the box does not sort for the app, and the document says nothing about how many rows there are beyond the window.

- R-NOTIFY-15.2 **What the app shows.** One section, header **"Recently decided"**, after the requests list and above the notification note, which stays the footer. It is absent when `recent` is empty: no placeholder, because an empty window is not information. Each row's title is `describeRequest(row, kidName)` with the same kid label the Requests section uses (the account the box published, "Your kid" when empty). Its subtitle is **"Approved"** or **"Declined"**, and when the row carries `reply`, `Approved: "<reply>"` or `Declined: "<reply>"` with the reply cleaned as every other string is (`_clean`, cap 80, the record's own bound). Its trailing text is `decided_at` rendered on the device's clock, time only when within the device's today, else weekday and time; no date arithmetic beyond that. The app sorts by `decided_at` descending, ties by `id`, and shows at most 20 rows of the up to 64 it parses (`_bounded`). A row whose `state` is not `"approved"` or `"declined"`, or whose `decided_at` is not an integer, is dropped by the parser: the app cannot label it honestly, so it does not show it. There is no chevron, no `onTap`, no long-press, no swipe, no menu: the tile is inert. Under the section, one line: **"What was decided on the computer in the last 24 hours, as it reports it. Nothing here can be changed."** It does not say who decided: the box records the record, not the actor (R-NOTIFY-15.4).

- R-NOTIFY-15.3 **What it is not.** It raises no notification: R-NOTIFY-14.1 already says a change to `recent` raises nothing, and R-NOTIFY-14.4 says `recent` is not consulted for dismissal; both stand. It does not decide: no route, no signed record, no Approve or Decline is reachable from a recent row, and a request that is decided is decided (`ask.py decide` refuses a non-open record, code 3). It does not edit a reply: `reply` is written once by the decision that carried it and there is no route that changes it. It is not history: the app keeps no decision past the document that carried it, writes nothing to disk, and a fresh document that lacks a row is a row gone. The window is the box's (`RECENT_SECONDS`, 24 hours); the app has no setting for it and never asks for more.

- R-NOTIFY-15.4 **Honest limits.** The box decides the window, on the box's clock; a decision older than it disappears from the app on the next document, and a device whose clock disagrees with the box's may see a row's time as slightly wrong, never a row missing. A decision made at the keyboard, from the panel, from this device, or from another paired device all look the same here: the row does not carry `by` or `device`, by decision. Over the relay the document is root-written and read through a pinned TLS connection, so `by` would be true, but the app would then be showing a provenance it cannot check the moment the same document arrives sealed in an away envelope (the envelope is confidential, not authenticated, section 6), and a row that says "decided from this phone" is a claim a replayed envelope could make. `by` also names where the decision was signed, not who signed it: `keyboard` and `panel` are anyone in the parent group at the box's own prompt. The record keeps `by` and `device` for `omarchy-kids-ask list` on the box, where root read them; the app says "decided" and no more. An id that leaves `requests` without arriving in `recent` (a record removed, or, should a later version add one, an expiry that sets no `decided_at`) is simply gone, and the app says nothing about it. Whether the kid saw the reply is not in the document and is not claimed.

- R-NOTIFY-15.5 **Tests.** `test/shell.d/relay-test.sh` proves: an open record's row has exactly the six keys of R-NOTIFY-15.1; a decided record's row carries `state` and `decided_at` and carries `reply` only when the record's is a non-empty string; a decided record older than the window, or with a non-integer `decided_at`, is in neither list. The app's model test (`test/state_model_test.dart`) proves a `recent` row with a bad `state` or `decided_at` is dropped and `reply` is cleaned and capped at 80; the widget test (`test/app_test.dart`) proves the section's order (after the requests, newest first, ties by id, capped at 20), the wording, the bare time for a decision from today, and that the row carries no `onTap`.

- R-NOTIFY-15.6 **Appendix H and docs.** Appendix H's `/v1/state` line becomes:

  ```text
  GET  /v1/state                      -> {kids, requests:[{id,kid,kind,what,minutes,asked_at}], recent:[requests row + {state, decided_at, reply?}, decided<24h], reviews:[open add-on reviews]}
  ```

  `docs/relayd.md`'s `GET /v1/state` row gains: "`recent` is the queue's decided records within 24h, each the request row plus `state`, `decided_at` and, when the parent typed one, `reply`; never `by` or `device`, which stay on the box for `omarchy-kids-ask list` (R-NOTIFY-15)."

## 17. R-NOTIFY-11, continued: the secret-holding files (exact)

### R-NOTIFY-11.4 The secret-holding files: `relay-tls` and `courier-conf`

R-NOTIFY-11's quoted text gains, after "the away drop-in that widens the relay's fence (R-NOTIFY-11.1)", the words ", the modes of the relay's TLS pair and of the courier's mailbox file (R-NOTIFY-11.4)", and its second sentence becomes "`omarchy-kids-check` has a row for the fence, a row for the away drop-in, a row for the devices, a row for the relay's TLS pair and a row for the mailbox file, each stating what it proves and what it cannot (R-NOTIFY-11.2, R-NOTIFY-11.4, R-TRUST-2)."

1. **Why two more locks.** `omarchy-kids-notify enable` mints `/etc/omarchy-kids/relay/key.pem`: the private half of the pin every paired device holds, so anyone who can read it can stand in for the relay to a paired device and see and answer every decision. `omarchy-kids-notify mailbox gotify|ntfy` writes `/etc/omarchy-kids/courier.conf`, which for Gotify carries the parent's `token=` and for ntfy names the `reply_topic=` the courier reads replies from: anyone who can read it can post to the parent's own topic and, for ntfy, read the parent's replies. Both are credentials, both are root-written, and neither has been under a lock; a `chmod` by anyone with root, or a mode lost to a restore, would stay lost until the parent noticed. These two locks re-assert the modes on every update and every boot. They own modes and ownership only.

2. **The `relay-tls` lock.** Machine-level, id `relay-tls`, asserted next to `units`, `devices` and `relay-away` on both the no-kids path and the full path (a key that leaks with zero kids provisioned still impersonates the relay to a device paired before the first kid). It owns exactly `/etc/omarchy-kids/relay/`, `cert.pem` and `key.pem` inside it, and nothing else.

   `ok` is: the directory is absent (notifications are off, or `disable` ran); or it is a directory (not a symlink), owner root, group `omarchy-parents`, `0750`, and `cert.pem`, when present, is a regular file (not a symlink), owner root, group `omarchy-parents`, `0644`, and `key.pem`, when present, is a regular file (not a symlink), owner root, group `omarchy-parents`, `0640`, and no other entry of any kind sits in that directory. A missing `cert.pem` or `key.pem` beside a present one is not a `fail` of this lock: the pair is minted and removed together by `omarchy-kids-notify`, and its `status` and the relay's own start are what report a half pair. Any other entry in the directory is a `fail` (assert prints the lock id; list the directory to see which file): a copy of the key under another name is exactly the leak this lock exists to catch, and assert cannot tell an admin's backup from an attacker's copy, so it fails rather than deleting it. It returns `2` only when the directory exists and cannot be read or searched by the caller (a check run outside `omarchy-parents`). Ownership and group are checked only when running as root, as every lock through `time_metadata_owner_ok` is.

   `fix` is: if the directory exists, `time_metadata_dir_fix` to root `omarchy-parents` `0750`; if `cert.pem` exists, `time_metadata_file_fix` to root `omarchy-parents` `0644`; if `key.pem` exists, `time_metadata_file_fix` to root `omarchy-parents` `0640`. That is the whole of it. `fix` never creates the directory or either file (that would be minting a relay identity no `enable` asked for), never removes either (that would revoke a pairing; `omarchy-kids-notify disable` is the only remover), never rewrites a byte of either, and never reads the key. A foreign entry is not this lock's to repair: `fix` does not remove, rename or rewrite it and returns `1`, so the run ends non-zero and the pacman hook says so on every update until a human removes the file or accepts a failing assert. A symlink or a non-regular file at either name is `1` from both `ok` and `fix`, never followed. If the `omarchy-parents` group does not exist, `chown` fails and so does `fix`: the package's own group is missing and that is a real defect, not one to paper over with a root-only key the relay's parent-group reader could not open.

3. **The `courier-conf` lock.** Machine-level, id `courier-conf`, asserted next to `relay-tls` on both the no-kids path and the full path (the token is the parent's whether or not a kid is provisioned). It owns exactly `/etc/omarchy-kids/courier.conf` and nothing else: not `courier.conf.<pid>` left by an interrupted `mailbox` (that is `omarchy-kids-notify`'s temp file; the writer `chmod 0600`s it before `mv -f`, and a leftover is for a human), not the courier's unit, not its timer.

   `ok` is: the file is absent (`mailbox off`, or never set); or it is a regular file (not a symlink), owner root, `0600`. No group is checked: at `0600` the group has no bearing, and `omarchy-kids-notify` writes it through a root temp file with no `chgrp`. It never returns `2`: a `0600` file's metadata is readable by anyone who can search `/etc/omarchy-kids`, and the contents are never opened.

   `fix` is: if the file exists, `time_metadata_file_fix` to root `0600`. `fix` never creates the file (a mailbox the parent did not name), never removes it (`omarchy-kids-notify mailbox off` is the only remover), never rewrites it, and never reads the `token=` line or any other line. A symlink or a non-regular file at that path is `1` from both `ok` and `fix`, never followed.

4. **The two check rows.** Under Locks, next to `lock:devices` and `lock:relay-away`, each through assert's `*_ok` only (`lock_check`; no `*_fix` is ever called by check), both repairable, so the standard fail text names `omarchy-kids-assert`:

   - `lock:relay-tls`, through `relay_tls_ok`. Proves: `/etc/omarchy-kids/relay` is absent, or is a root `omarchy-parents` `0750` directory in which `cert.pem`, if present, is root `omarchy-parents` `0644`, `key.pem`, if present, is root `omarchy-parents` `0640`, neither is a symlink, and nothing else is there. A warn is the directory being unreadable to this run. Cannot: that `key.pem` is the key `cert.pem` was minted with, or the one the relay is serving; that no paired device holds a pin for an earlier pair (`enable` after `disable` mints a new pair, and R-NOTIFY-3's re-pairing is the only cure); that the relay is running or listening; that the key was not read while its mode was wrong, or by anyone in `omarchy-parents`, who may read it by design.
   - `lock:courier-conf`, through `courier_conf_ok`. Proves: `/etc/omarchy-kids/courier.conf` is absent, or is a root-owned `0600` regular file, not a symlink. Cannot: that the file parses, that `transport=`, `url=`, `topic=` or `reply_topic=` name anything real, that the `token=` is valid or has not been revoked on the server, that the parent's server is reachable, that the courier's timer is enabled or has ever run, or that the token was not read while the mode was wrong.

5. **What these locks deliberately do not do.** Neither opens either file: no lock reads the key, the certificate, or a line of `courier.conf`, so no lock can, and none claims to, tell a valid token from a stale one or a matching pair from a mismatched one. Neither redacts anything: assert's and check's output name the lock id and the path, never a byte of content, and this section makes no claim that the token or key is absent from any other log or output (`omarchy-kids-notify`'s stdin-only token rule and the pairing record's root-only mode are where that is stated). Neither looks at the ntfy or Gotify side: no request is made, no topic is checked, no reply is read (I-2 as amended: assert and check open no network connection). Neither creates, removes, rotates or rewrites a secret: `omarchy-kids-notify enable`, `disable`, `mailbox` and `mailbox off` are the only writers and removers, and a lock that minted or deleted a credential would be deciding for the parent. A mode restored by `fix` says the file is closed from now; it says nothing about who read it before, and the row does not pretend otherwise.

### R-NOTIFY-11.5 Docs

1. `docs/assert.md`'s machine-level table gains two rows, and its heading's zero-kid list becomes "`units`, `devices`, `relay-away`, `relay-tls` and `courier-conf`":

   | Lock id | Checks | Fix |
   | --- | --- | --- |
   | `relay-tls` | The relay's TLS pair (R-NOTIFY-11.4): `/etc/omarchy-kids/relay` is absent or is root `omarchy-parents` `0750` with `cert.pem` root `omarchy-parents` `0644` and `key.pem` root `omarchy-parents` `0640` where present, no symlinks, nothing else in the directory. `key.pem` is the private half of every paired device's pin; a foreign entry is where a loose copy of it would sit, so the lock FAILs and leaves it for a human rather than deleting it. Presence is `omarchy-kids-notify enable`'s: the fix never mints, removes or reads a key. **Runs even with zero kids** | `chmod`/`chown` of the directory and the two files to the modes above; never creates, never deletes, never rewrites, never touches a foreign entry |
   | `courier-conf` | The courier's mailbox file (R-NOTIFY-11.4): `/etc/omarchy-kids/courier.conf` is absent or is a root-owned `0600` regular file, not a symlink. It carries the parent's Gotify `token=` or ntfy `reply_topic=`, which is a credential to the parent's own server. Presence is `omarchy-kids-notify mailbox`'s: the fix never creates, removes or reads it, and no group is checked at `0600`. **Runs even with zero kids** | `chmod 0600` and `chown root`; never creates, never deletes, never rewrites |

2. `docs/check.md`'s Locks section, after the paragraph on the three R-NOTIFY-11.2 rows, gains: "Two more rows, `lock:relay-tls` and `lock:courier-conf`, are the assert locks of the same names (R-NOTIFY-11.4), standard shape and standard fail text. They prove only that the relay's private key (`/etc/omarchy-kids/relay/key.pem`, root `omarchy-parents` `0640`, its certificate `0644`, the directory `0750` with nothing else in it) and the courier's mailbox file (`/etc/omarchy-kids/courier.conf`, root `0600`, which carries the Gotify token or the ntfy reply topic) are absent or closed to everyone but root and, for the key, the parent group. Neither row opens either file: not that the key matches the certificate or the one a device pinned, not that the token is valid or the server reachable, not that the relay or the courier is running, and not that nobody read the secret while its mode was wrong. A warn on `lock:relay-tls` is the directory being unreadable to this run, which is what a run outside `omarchy-parents` sees."

## 18. R-NOTIFY-7, built (exact)

R-NOTIFY-7's quoted text stands as written and gains one sentence at its end: "The queue is under the `queue` assert lock, which owns the directory's and each record's mode and ownership and nothing else (item 4 of this section); `omarchy-kids-check` has a row for it stating what it proves and what it cannot (R-TRUST-2)."

1. **Why this is a change and not a description.** Today `omarchy-kids-ask collect`, `apply-grant` and `list` each create the queue `install -d -m 0755`, and `lib/ask.py`'s `write_atomic` writes every record `0644` under a directory it `makedirs` at `0755`. Every local account can list and read every kid's requests: what they asked for, when, and how it was decided. The kid's own draft in the outbox is `0644` inside a `0700` directory, closed by the directory alone. Nothing a kid runs needs the queue (item 3), so closing it costs no kid path anything.

2. **Modes and ownership.**

   - `/var/lib/omarchy-kids/queue/` is a directory, not a symlink, `0750`, owner root, group `omarchy-parents`. It may be absent: absent means no request has ever been collected or granted on this box, and every reader treats absent as empty. Only root creates it, and only on a write: `omarchy-kids-ask collect` (the timer, `--apply`) and `omarchy-kids-ask apply-grant` (authd's callback), each with `install -d -m 0750` followed by `chown root:omarchy-parents` and `chmod 0750` on every run, so an existing `0755` directory is corrected by the next collect, not only at creation. `omarchy-kids-ask list` no longer creates it: a reader creates nothing. The `queue` lock's `fix` does not create it either (item 4).
   - Each record `<unix-ts>-<account>-<kind>[-<n>].json` is a regular file, not a symlink, `0640`, owner root, group `omarchy-parents`. `write_atomic` sets this on the temp file before `os.replace`, so no record is ever reachable under its final name at any other mode, and it sets it on *every* write: `write`, `decide` and `reopen` all pass through `write_atomic`, so a record left at `0644` by an earlier version is corrected by its next write (its decision) and, before that, by the lock. `write_atomic` sets the group with `os.chown(tmp, 0, gid)` where `gid` is `grp.getgrnam("omarchy-parents")`. If the group does not exist the `chown` is skipped (`|| true`, as the notify writer's `chgrp` already is) and the record lands root-only: that is a real defect the `queue` lock (item 4) and `parent-group` then report, not one a write papers over. `collect` checks `getent group omarchy-parents` once, before it moves anything, and exits `1` touching no outbox when `getent` is present and the group is missing; where `getent` is absent the check is skipped, the repo's own idiom for a box that cannot answer (the lock reports the resulting root-only mode, and `parent-group` the group's absence) `apply-grant` records before it applies (as today), so a failed record write means nothing was granted.
   - Between `collect`'s `mv -n` and its `reopen`, the file in the queue is the kid's own outbox file (kid-owned, `0600`, item 2's next bullet), inside the `0750` directory, for the length of one `reopen`. `reopen` either rewrites it as a root `omarchy-parents` `0640` open request or `collect` removes it; no third outcome.
   - `<record>.lock`, the zero-byte sibling `decide` takes its `flock` on, and `<record>.<pid>.tmp`, which never outlives `write_atomic`, are the writer's own and carry no content; they are created inside the `0750` directory and are neither checked nor fixed by the lock.
   - The outbox record `/run/user/<uid>/omarchy-kids/ask-outbox/<name>.json` is the kid's own draft: owner the kid, `0600`, no group claim. `write_atomic` chooses by writer, not by path: a writer with `os.geteuid() == 0` writes `0640 root:omarchy-parents`; any other writer writes `0600` and calls no `chown`. Root never writes an outbox and a kid never writes the queue (item 3), so who writes decides which store is being written, and no argument, path pattern or environment value is consulted (AGENTS.md rule 9). The directory stays `install -d -m 0700` as today.

3. **Readers, and who is not one.**

   - Root reads and writes as today: `omarchy-kids-ask collect`, `apply-grant`, `approve`, `decline` and `list`; `omarchy-kids-authd` (the socket's decisions); `omarchy-kids-time-ledger` (`list-open` for `status.json`'s `open_requests`); `omarchy-kids-relay-courier` (`build_state` for the away envelope); `omarchy-kids-data retention` (prunes by file name, never opens a record).
   - `omarchy-parents` reads: `omarchy-kids-relayd` (`User=omarchy-kids-relay`, `Group=omarchy-parents`, `ReadOnlyPaths=/var/lib/omarchy-kids`) for `/v1/state`; `omarchy-kids-notify-watch` in the parent's own session; `omarchy-kids-panel`'s Requests screen and Home counts, which run `list-open` directly as the parent (their approve and decline go through `run_priv`, as today); `omarchy-kids-ask list`. The parent is in `omarchy-parents` because the `parent-group` lock puts them there and keeps them there.
   - `omarchy-kids-ask list` today dies `list: root only`, exit `1`, for every non-root caller; `omarchy-kids --requests` therefore fails for the parent today, against R-NOTIFY-7's own words. Now: `list` runs for root or for a caller whose `id -Gn` contains `omarchy-parents` (one helper in `lib/kids.sh`, `in_parent_group`, reading `id -Gn` and nothing else); anyone else gets `list: root or a member of omarchy-parents only`, exit `1`. For a non-root caller: an absent directory is "no open requests"; a directory it cannot read or search is `list: cannot read the queue (are you in omarchy-parents in this session?)`, exit `1`, never "no open requests", because a group added since login is not in the session's credentials until the next login and an empty answer there would be a lie. A record `list-open` cannot open is skipped as a malformed one is today; the lock, not `list`, reports a record at the wrong mode. `approve` and `decline` stay root-only. `omarchy-kids --requests` runs `omarchy-kids-ask list` unchanged and now works for the parent, and only for the parent.
   - Nothing a kid runs opens the queue. `omarchy-kids-ask submit` writes the kid's own outbox; `grant` talks to `omarchy-kids-authd` over its socket; `time`, `app`, `plugin` and `site` open the modal, which calls those two; the kid's bar badge reads `/run/omarchy-kids/status.json`, root-written, never the queue. `omarchy-kids-ask-collect.service` is root. There is no kid path to keep working and none is kept.

4. **The `queue` lock.** Machine-level, id `queue`, asserted next to `devices` on both the no-kids path and the full path: records for a kid removed since outlive the kid until retention prunes them, and they are still that kid's. It owns exactly `/var/lib/omarchy-kids/queue/` and the `*.json` regular files directly inside it, and nothing else.

   `ok` is: the directory is absent (no request yet); or it is a directory (not a symlink), owner root, group `omarchy-parents`, `0750`, and every `*.json` in it is a regular file (not a symlink), owner root, group `omarchy-parents`, `0640`. It returns `2` only when the directory exists and cannot be read or searched by the caller (a check run outside `omarchy-parents`). Ownership and group are checked only when running as root, as every lock through `time_metadata_owner_ok` is. `.lock`, `.tmp` and any other entry are not looked at: nothing in this directory is a credential, the directory's own mode is what closes them, and this lock does not fail on a foreign entry the way `relay-tls` does.

   `fix` is: if the directory exists, `time_metadata_dir_fix` to root `omarchy-parents` `0750`; for each `*.json`, `time_metadata_file_fix` to root `omarchy-parents` `0640`. That is the whole of it. `fix` never creates the directory (a queue nobody asked into), never removes a record (retention and the parent's decisions are the only removers), never rewrites a byte of one, and never reads one. A symlink or a non-regular file at the directory or at a `*.json` name is `1` from both `ok` and `fix`, never followed. If the `omarchy-parents` group does not exist, `chown` fails and so does `fix`: the same defect item 2 refuses to paper over.

   The check row is `lock:queue`, under Locks next to `lock:devices`, through `queue_ok` and `lock_check` (no `*_fix` is ever called by check), repairable, so the standard fail text names `omarchy-kids-assert`. Proves: `/var/lib/omarchy-kids/queue` is absent, or is a root `omarchy-parents` `0750` directory whose `*.json` records are root `omarchy-parents` `0640` regular files, none a symlink. A warn is the directory being unreadable to this run, which is what a run outside `omarchy-parents` sees. Cannot: that any record is well-formed, open, or for a provisioned kid (`list-open` re-validates on the way out and that is where a bad record is dropped); that `collect` has run or the timer is enabled (`units`); that the relay or the notifier can reach the directory through their units' own sandboxes; that a record was not read while its mode was wrong; or anything about the outbox, which is the kid's runtime directory and is not this lock's.

5. **Honest limits.** A mode is not encryption: the records are plain JSON and stay so. Root reads them, by definition; every member of `omarchy-parents` reads them, by design, and that is the parent and the relay's service account; a kid is not in `omarchy-parents` (the `groups:<kid>` lock pins the kid's groups to the band's set) and this section is what keeps another kid, a guest account or any other local user from listing what a kid asked for. The content is what the kid typed into the modal and what the parent decided; this section does not change what is recorded, how long it is kept (`omarchy-kids-data retention`, 90 days) or what leaves the box (R-NOTIFY, I-2 as amended). A record was world-readable from the day it was written until the first `assert` or write after this version lands; this section restores the mode from then on and says nothing about who read it before. The `0600` outbox record is closed by its `0700` directory already; the tighter file mode is one more fence, not a new guarantee, and a kid can still read their own draft, which is theirs.

6. **Tests.** `test/shell.d/ask-test.sh` proves: `submit` leaves the outbox record `0600` (read through `kids_file_mode`); a record written by a non-root `write` is `0600`; `collect` refuses, exit `1`, moving nothing, when a stubbed `getent group omarchy-parents` finds no group; `list` as a non-root caller whose stubbed `id -Gn` lacks `omarchy-parents` exits `1` with the refusal text, and with it prints the rows from a scratch queue it can read, and reports "cannot read the queue", exit `1`, not "no open requests", for a scratch directory made `0000`; `list` creates no directory. The root `0640 root:omarchy-parents` branch of `write_atomic` runs `os.chown` to a real group, which a user namespace cannot map, so it is proven on the VM: `test/live/70-notify-pair-and-approve.sh` approves the queued request (authd runs `omarchy-kids-ask approve --apply` as root, whose `write_atomic` rewrites the record) and then asserts `stat -c '%a %U %G'` on the directory and the record -- after the rewrite, so the modes are the root branch's and not the scenario's own fixture. `test/shell.d/assert-test.sh` proves, against a scratch tree, that `queue_ok` accepts an absent directory and the exact shape, refuses a `0755` directory, a `0644` record, a symlink at a record and a symlinked directory (leaving each alone), reports `warn` for a directory the caller cannot read, and that `queue_fix` corrects the directory and a record and creates nothing. `test/shell.d/check-test.sh` proves `lock:queue` is a pass (absent), a fail (a `0644` record) and a warn (an unreadable directory).

7. **Docs.** `docs/assert.md`'s machine-level table gains one row, and its heading's zero-kid list becomes "`units`, `devices`, `queue`, `relay-away`, `relay-tls` and `courier-conf`":

   | Lock id | Checks | Fix |
   | --- | --- | --- |
   | `queue` | The request queue (R-NOTIFY-7): `/var/lib/omarchy-kids/queue` is absent or is root `omarchy-parents` `0750` with every `*.json` record root `omarchy-parents` `0640`, none a symlink. What a kid asked for and how it was decided is for root and the parent group, not for every local account. Presence is `omarchy-kids-ask collect`'s and `apply-grant`'s: the fix never creates, removes, rewrites or reads a record. **Runs even with zero kids** | `chmod`/`chown` of the directory and each record to the modes above; never creates, never deletes, never rewrites |

   `docs/check.md`'s Locks section gains: "`lock:queue` is the assert lock of the same name (R-NOTIFY-7), standard shape and standard fail text. It proves only that the request queue is absent or closed to everyone but root and `omarchy-parents`; not that any record is valid, that `collect` runs, or that nobody read a record while its mode was wrong. A warn is the directory being unreadable to this run, which is what a run outside `omarchy-parents` sees."

   `docs/ask.md` replaces "The command requires `is_root` before reading the queue" with "`list` runs for root or a member of `omarchy-parents`; `approve` and `decline` are root-only", and its outbox and queue paragraphs carry the modes of item 2. `docs/notify.md`'s desktop-notifier paragraph drops "(world-readable today; R-NOTIFY-7 tightens it to …)" for "(`0750 root:omarchy-parents`, which the parent's group reads; R-NOTIFY-7)". `omarchy-kids-ask --help`'s `list` line says "Root or a member of omarchy-parents", and `omarchy-kids --help`'s `--requests` line says "works for the parent (a member of omarchy-parents)".

## 19. R-NOTIFY-6, built (exact)

R-NOTIFY-6's quoted text loses "(**not built on this branch** — the ask overlay shows the result instead; Appendix H's file section says so)" and becomes: "A kid learns the outcome through a root-written file under their own directory (`/var/lib/omarchy-kids/<kid>/decisions/<id>.json`, `0640 root:<kid>`, a copy of the queue record's decision and nothing else; item 3 of this section). The ask overlay shows the newest one when it opens (item 4). The kid session holds no credential to the relay and gains no new way to act: the file is read, never written, by anything a kid runs, and the queue record stays the decision of record (R-NOTIFY-4). The directory is under the `decisions` assert lock and `omarchy-kids-check` has a row for it (item 5); `omarchy-kids-data retention` prunes it with the queue (item 5)."

1. **Why a file, and why now.** Today a kid who chose "Ask later" learns nothing: the parent decides from the panel, the bar, the desktop notifier, a paired device or the courier, the queue record turns `approved` or `declined` under `0750 root:omarchy-parents` (R-NOTIFY-7), and the kid's session, which may not read the queue, sees only that a grant took effect or did not. R-NOTIFY-6 named the file and the mode on the day the section was written; this section builds it, as a copy the kid can read and not as a channel the kid can write. Nothing decides through it and nothing acts on it.

2. **When it is written, and in what order.** Every decision on this box passes through `lib/ask.py`'s `cmd_decide`, reached by `omarchy-kids-ask approve|decline` (the panel, `omarchy-kids --requests`, the bar, the desktop notifier, `omarchy-kids-authd`'s `DECIDE` for a device and the courier's reply) and by `omarchy-kids-ask apply-grant` (the on-the-spot path, `--by keyboard`). `cmd_decide` gains one step and no new caller: after `write_atomic` has replaced the queue record, and still inside the `flock` on `<record>.lock`, it calls `write_kid_copy(path, record)`, which writes the file of item 3. The order is fixed: queue record first, kid copy second, both under the one lock, so no reader ever finds a copy whose record is still `open`, and a second `decide` racing on the same record is refused (code 3) before it can write a second copy. The on-the-spot path is not special: `apply-grant` applies, then decides, then the copy lands, so a kid who typed the parent's password at the keyboard gets the same file as a kid who waited.

   A failed copy does not undo a decision. `write_kid_copy` failing (the kid's account no longer resolves, the directory cannot be created, the disk is full) prints `ask.py: decided; could not write the kid's copy of <id>: <reason>` on stderr and `cmd_decide` exits `0`: the decision is the queue record's, it is written, and the parent's answer stands (checklist item 3: the record that lets a retry finish is written first). It is retried, by root, on the next `omarchy-kids-ask collect` run (the timer, every minute, and the panel's own `collect --apply`): after moving the outboxes, `collect` runs `ask.py sync-decisions QUEUE_DIR`, which resolves the data root as the queue directory's parent and, for every queue record whose `state` is not `open` and whose `kid` is a valid account name writes the copy if `VARLIB/<kid>/decisions/<id>.json` is absent, and never rewrites one that exists (a present copy is a finished write, `os.replace` being the only way one appears). A record whose account no longer resolves gets no copy and a stderr line, never a retry loop; there is no reader, and every queue record's `kid` was checked when it was written. `sync-decisions` reads the queue record's bytes, and `write_atomic`'s `os.replace` means it sees either the open record or the decided one, never a half-written one; an open record is skipped and healed on the next run. `cmd_decide` never blocks on the copy, never sleeps, never retries in place.

3. **Path, mode, ownership, content.**

   - The directory is `/var/lib/omarchy-kids/<kid>/decisions/`, a directory, not a symlink, `0750`, owner root, group the kid's primary group (`pwd.getpwnam(kid).pw_gid`, the account's own; the `groups:<kid>` lock keeps the kid out of every other group that matters, and no other account is in a kid's primary group). Ownership and the account are resolved only when running as root, as every ownership check in this package is: a non-root test build writes the copy owned by whoever ran it. It may be absent: absent means nothing has been decided for this kid on this box. Root creates it, on the first copy, with `os.makedirs(mode=0o750)` then `os.chmod(0o750)` and `os.chown(0, gid)` on every write, so an earlier mode is corrected by the next decision. Nothing a kid runs creates it: `omarchy-kids-ask outcome` (item 4) treats absent as "nothing decided yet". The parent directory `/var/lib/omarchy-kids/<kid>/` is what it is today (`usage/`'s parent, `0755` root) and this section does not change it.
   - The file is `/var/lib/omarchy-kids/<kid>/decisions/<id>.json`, where `<id>` is the queue record's basename without `.json`, `<unix-ts>-<account>-<kind>[-<n>]`, exactly, so a queue record and its copy share a name and retention prunes both by the same leading timestamp. It is a regular file, not a symlink, `0640`, owner root, group the kid's primary group. `write_kid_copy` writes it as `write_atomic` does: a `<path>.<pid>.tmp` opened `O_WRONLY|O_CREAT|O_EXCL` at `0600`, `chmod 0640`, `chown 0:gid`, `os.replace`; no name is ever reachable at another mode. It is written once. `sync-decisions` skips a present file, `decide` never reaches the same record twice, and no command rewrites, appends to or removes a copy except `omarchy-kids-data retention`.
   - The content is one JSON object, `sort_keys`, one trailing newline, with exactly these keys, each the queue record's own value: `id` (the basename above), `kid`, `kind`, `what`, `asked_at`, `state` (`"approved"` or `"declined"`), `decided_at`, and `minutes` when the record carries it, and `reply` when the record carries a non-empty string. Nothing else: not `by`, not `device`, not the queue path, not a token, not a device name or key, not the parent's account. `by` and `device` stay off it for the reasons R-NOTIFY-15.4 keeps them off the app's `recent` row: they name where a decision was signed, not who signed it, and a kid reading "decided from Mum's phone" would be reading a claim this file cannot back. If `decided_at` or `asked_at` is not an integer, or `state` is not one of the two, `write_kid_copy` writes nothing and reports as a failed copy: the queue record is malformed and `list-open` is where that is already dropped.
   - Who writes: root, through `cmd_decide` and `sync-decisions`, and nobody else. Who reads: root; the kid, by group, in their own session, and only their own directory (another kid's is `0750` under a group they are not in); the parent, only as root (`sudo omarchy-kids-ask list` shows the queue, which already has everything the copy has and more). No unit reads it: not `omarchy-kids-relayd` (`/v1/state`'s `recent` is built from the queue), not the courier, not the ledger, not `status.json`.

4. **The kid-side read.** `omarchy-kids-ask` gains one kid-side subcommand, `outcome`, display only. It takes no arguments, resolves the account as `id -un`, and the directory as `/var/lib/omarchy-kids/<that>/decisions` (a build-time constant beside `QUEUE_DIR`, never an argument, never an environment value: AGENTS.md rule 9). It runs `ask.py outcome DIR`, which sorts `*.json` by basename, takes the last, opens it, and validates every field before printing a byte: `kid` equals the directory's account, `kind` in `KINDS`, `what` and `minutes` through `validate_grant`, `state` in `approved`/`declined`, `asked_at` and `decided_at` through `valid_epoch`, `id` matching `RE_ID` and equal to the basename, `reply` absent or a printable string of at most 80 characters. A file that fails any check is skipped and the next-newest is tried, oldest last; an unreadable or malformed file is skipped, never a traceback. It prints one tab-separated line, `kind what minutes state reply` (`minutes` empty unless `kind` is `time`, `reply` empty when absent), or nothing, exit `0`, when the directory is absent, empty, or holds nothing valid. It never prints `decided_at`, `asked_at` or the id: the modal shows a sentence, not a record. Exit `1` only when the directory exists and cannot be read, with `outcome: cannot read your decisions directory` on stderr. Root running `outcome` gets root's own (absent) directory and prints nothing; it is not a way to read a kid's.

   `share/ask/shell.qml` runs `/usr/bin/omarchy-kids-ask outcome` in a `Process` when it opens, the way `grantProcess` runs `grant`: absolute path, no new environment variable, so the trust-boundary allowlist gains nothing. While the process runs, or when it prints nothing, the modal is exactly what it is today. When it prints a line, one sentence appears below the request's description, in the body text style, no button, no focus stop, no key bound to it:

   - `approved`: **"Last time your grown-up said yes to <thing>."**
   - `declined`: **"Last time your grown-up said not this time to <thing>."**
   - with a `reply`, either sentence gains **` They said: "<reply>"`**, the reply rendered as plain text (no rich text, no markup), so a quote or an angle bracket in it is a quote or an angle bracket.

   `<thing>` is `<minutes> more minutes` for `time`, and `what` for `app`, `plugin` and `site`, as `desc` is for the current request. The sentence carries no time and no date: the file carries `decided_at`, but a kid does not need "on Tuesday at 4" to know the answer, and a line that ages badly ("last time" being six weeks ago) is still true. The sentence disappears when `omarchy-kids-data retention` prunes the file (item 5), and never before: this section adds no window. Focus, Tab order, Esc and Ctrl+C are unchanged (I-5). The sentence is display only (I-6): there is no route from it to `grant`, `submit`, or anything else; it does not preselect an action; it is not a control and is not labelled as one. The two existing outcome texts stand as the code has them, and the docs say so (item 7): the on-the-spot path says **"Got it! <Desc> is ready now."** (`onGranted`; root applied before `grant` exited), and "Ask later" says **"Asked. Your grown-up will see it."** (`submitLater`). Neither path shows its own decision on the spot: the "Ask later" answer is what the next open shows, and this section does not add a watcher, a notification, or a bar badge for it.

5. **The `decisions` lock, the check row, retention.**

   - The lock is id `decisions`, asserted on the full path next to `queue`, walking `kids_list` (a provisioned kid's directory has a group to check; a removed kid's directory has none, is not walked, and is treated as `usage/` is today). It owns exactly `/var/lib/omarchy-kids/<kid>/decisions/` and the `*.json` regular files directly inside it, for each provisioned kid, and nothing else. `ok` is, per kid: the directory is absent; or `time_metadata_dir_ok "$dir" 750 "$(id -gn "$kid")"` and, for every `*.json`, `time_metadata_file_ok "$file" 640 "$(id -gn "$kid")"`; `.tmp` and any other entry are not looked at, and the lock does not fail on a foreign entry (nothing here is a credential; the directory's own mode closes it). It returns `2` only when a directory exists and cannot be read or searched by the caller. Ownership and group are checked only when running as root, as every lock through `time_metadata_owner_ok` is. `fix` is: if the directory exists, `time_metadata_dir_fix` to root `<kid group>` `0750`; for each `*.json`, `time_metadata_file_fix` to root `<kid group>` `0640`. `fix` never creates the directory (a decision nobody made), never removes a copy, never rewrites one, never reads one, never regenerates a missing copy (that is `collect`'s `sync-decisions`, item 2, not a lock's). A symlink or non-regular file at the directory or at a `*.json` name is `1` from both, never followed. If `id -gn "$kid"` fails the kid is not an account and `fix` returns `1`: `assert` reporting a provisioned kid with no account is the real defect.
   - The check row is `lock:decisions`, under Locks next to `lock:queue`, through `decisions_ok` and `lock_check` (no `*_fix` is ever called by check), repairable, standard fail text naming `omarchy-kids-assert`. Proves: for every provisioned kid, `/var/lib/omarchy-kids/<kid>/decisions` is absent, or is a root `0750` directory in the kid's own primary group whose `*.json` files are root `0640` in that group, none a symlink. A warn is a directory being unreadable to this run. Cannot: that any copy matches its queue record (nothing compares them; the queue is the record and the copy is display); that a decided record has a copy at all (a missing one is healed by the next `collect`, and this row does not count them); that the kid has seen it; or anything about the queue, which is `lock:queue`'s.
   - `omarchy-kids-data retention` gains `prune_decisions KID CUTOFF_EPOCH APPLY` in its per-kid loop, next to `prune_usage` and `prune_launches`, using `queue_cutoff` (90 days, R-DATA-1's "requests"): for each `*.json` in the kid's `decisions/` whose basename starts with an integer below the cutoff, `rm -f` under `--apply`, `[dry-run] rm <path>` otherwise; a name that does not start with an integer is skipped. The copy and the queue record share a timestamp, so they leave together; a copy can outlive its record by at most one run when the record was pruned by a run the kid's loop had not reached, and a record can never be pruned before its copy is eligible. `omarchy-kids-data mine`'s line "What you asked for ("Ask a parent") and what happened. Kept for 90 days." is now true of the kid's own directory, and its `--help` says "requests and their decisions 90 days".

6. **Honest limits.** The file is a copy the kid can read, not a channel: nothing on the box reads it to decide anything, act on anything, or show the parent anything. A kid cannot write it (`0640` root, in a `0750` root directory), and a kid who somehow did would change only the sentence their own modal shows them, since every reader of the decision (`apply_record`, the panel, `list`, `/v1/state`, the courier) reads the queue record, which is `0750 root:omarchy-parents` and write-once. The queue record remains the decision of record (R-NOTIFY-4); the copy is derived, later, and may be missing for up to a minute after a failed write, during which the kid's modal says nothing about that decision and the grant, if any, has already been applied. A decision older than retention disappears from the modal on the run that prunes it, and the modal then shows the newest that remains, or nothing. The copy does not say who decided or from where, by decision (item 3), and it does not say the kid saw it: nothing records that, and the app's "Recently decided" section (R-NOTIFY-15.4) still does not claim it. A mode is not encryption: the copy is plain JSON, readable by root and by the kid it is for; another kid, a guest account, and the relay's service account cannot open it. This section changes nothing about what leaves the box (R-NOTIFY, I-2 as amended): the copy is written to the kid's own directory on the kid's own machine and no process carries it anywhere.

7. **Tests.** `test/shell.d/ask-test.sh` proves: `decide` on a scratch queue writes `<varlib>/<kid>/decisions/<id>.json` after the record (the test's stubbed `os.replace` order, or a copy whose `state` matches the rewritten record's, never an `open` record beside a copy) with exactly the keys of item 3 and no `by` or `device`, and `reply` only when the decision carried one; a `decide` whose copy directory cannot be created (a file at `decisions`) leaves the record decided, prints the stderr note, and exits `0`; `sync-decisions` writes a missing copy for a decided record, leaves a present copy's bytes unchanged (a differing sentinel is not overwritten), and writes nothing for an `open` record; a `decide` whose copy directory cannot be created (a file at `decisions`) leaves the record decided, prints the stderr note and exits `0`; `outcome` prints nothing for an absent directory, prints the newest valid file by name past a newer malformed one, prints `reply` only when present, and skips a copy whose `kid` is not the directory's account. The root `0640 root:<kid group>` branch runs `os.chown` to a real account's group, which a user namespace cannot map, so it is proven on the VM: `test/live/70-notify-pair-and-approve.sh` asserts `stat -c '%a %U %G'` on `/var/lib/omarchy-kids/kid-ada/decisions/` and the approved request's copy after the approve, and that `runuser -l kid-ada -c 'omarchy-kids-ask outcome'` prints the approved line. `test/shell.d/assert-test.sh` proves, against a scratch tree with a stubbed `id -gn`, that `decisions_ok` accepts an absent directory and the exact shape, refuses a `0755` directory, a `0644` copy, a symlinked copy and a symlinked directory, leaving each alone, reports `2` for an unreadable directory, a symlinked directory, reports `2` for an unreadable directory, and that `decisions_fix` corrects the directory and a copy and creates nothing. `test/shell.d/check-test.sh` proves `lock:decisions` is a pass (absent), a fail (a `0644` copy) and a warn (an unreadable directory). `test/shell.d/data-test.sh` proves `retention --apply` removes a copy older than 90 days and keeps a newer one and a name with no timestamp. `test/shell.d/trust-boundary-test.sh`'s allowlist is unchanged (`outcome` takes the account from `id -un` and a build-time constant, like `submit`; the existing scan covers the file).

8. **Docs, help, spec.** Appendix H's files line replaces "(`0640 root:kid`; **not built on this branch** -- the kid's result is shown by the ask overlay, not this file)" with "(`0640 root:<kid>` in a `0750 root:<kid>` directory: `{id, kid, kind, what, minutes?, asked_at, state, decided_at, reply?}`, a copy of the queue record's decision written by `ask.py decide` after the record and healed by `collect`; never `by` or `device`; read by `omarchy-kids-ask outcome` for the ask overlay, which shows the newest; R-NOTIFY-6)". `docs/ask.md` gains an `outcome` section stating item 4 and a "The kid's copy" paragraph stating items 2, 3 and 6, and its sentence "Got it! ... will be ready very soon", never "Done"" becomes what the modal says: "Got it! <Desc> is ready now." (root applied before `grant` returned; label claims, AGENTS.md item 6). `docs/notify.md`'s decision paragraph gains: "Every decision, from the panel, a device or the courier, also lands as a root-written copy under the kid's own directory, which the ask overlay shows the next time it opens (R-NOTIFY-6). The kid cannot write it and nothing reads it to act." `docs/data.md`'s table gains a row for `/var/lib/omarchy-kids/<kid>/decisions/`, 90 days, "the kid's own copy of each decided request; what the kid sees in the ask overlay". `docs/assert.md`'s per-kid table gains:

   | Lock id | Checks | Fix |
   | --- | --- | --- |
   | `decisions` | The kid's copies of their decided requests (R-NOTIFY-6): `/var/lib/omarchy-kids/<kid>/decisions` is absent or is root `0750` in the kid's own primary group with every `*.json` root `0640` in that group, none a symlink, for each provisioned kid. The copy is what the ask overlay shows the kid; the queue record is the decision. Presence is `ask.py decide`'s and `collect`'s: the fix never creates, removes, rewrites, regenerates or reads a copy | `chmod`/`chown` of the directory and each copy to the modes above; never creates, never deletes, never rewrites |

   `docs/check.md`'s Locks section gains: "`lock:decisions` is the assert lock of the same name (R-NOTIFY-6), standard shape and standard fail text. It proves only that each provisioned kid's decisions directory is absent or closed to everyone but root and that kid; not that a copy matches its record, that every decided record has one, or that the kid saw it. A warn is a directory being unreadable to this run." `omarchy-kids-ask --help`'s usage block gains `omarchy-kids-ask outcome  # the newest decision in your own directory`, and `collect`'s line notes `# also heals a missing kid copy (R-NOTIFY-6)`. and `omarchy-kids-data --help`'s `retention` line reads "requests and their decisions 90 days".

## 20. Known gap: the request decision does not sign what the parent saw (security review, 2026-09-25)

A request decision the app sends signs the request id, the decision, a timestamp, a nonce and the
optional reply (`clients/parent/lib/relay_client.dart`, `lib/session.dart`); root applies whatever
the queue record with that id says (`bin/omarchy-kids-authd`). The app signs no kid, type, `what` or
minutes, so a compromised `omarchy-kids-relay` -- the only network listener -- could show request B's
id with request A's details and have the parent approve A's fields under B's id. The review id is
already bound (`kid.sha256(app)[:16]`, checked by `lib/relay.py`, `lib/devices.py`, and now the app),
so add-on reviews are safe; the request record is the remaining gap.

Closing it is a wire change, not a client-only one: the app signs the displayed `kid`, `kind`, `what`
and `minutes` (and `reply`) into the decision frame, and authd re-validates them against the queue
record the id names before applying -- the shape the review fingerprint already uses. It needs both
sides changed together and a VM check, so it is tracked here rather than shipped half-done. Until
then, `docs/relayd.md` states the limit plainly instead of claiming the relay's whole attack surface
is "notifications stop".
