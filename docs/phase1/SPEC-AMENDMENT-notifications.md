# SPEC amendment: parental notifications (R-NOTIFY)

Status: **approved by the owner, 2026-09-22** — "have fable 5.1 determine the most robust, full
featured, EXCITING implementation and go with that." The design is
`docs/research/2026-09-22-parental-notifications.md` (a headless `claude-fable-5-1` run grounded in
this repo). This document is the exact SPEC.md text to apply, plus the AGENTS.md and PRIVACY.md
edits that follow from it.

Amends SPEC.md: I-2; adds the **R-NOTIFY** section (R-NOTIFY-1..12); R-BAR-3 (the status document
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
- R-NOTIFY-2 The relay never decides. Every decision is authenticated and applied by root
  (`omarchy-kids-authd` / `omarchy-kids-ask`), through the same `apply_record` path the panel uses.
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
  (`/var/lib/omarchy-kids/<kid>/`). The kid session holds no credential to the relay and gains no
  new way to act.
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
- R-NOTIFY-11 `omarchy-kids-assert` re-asserts the devices directory and conf modes and the units
  list on every update. Re-asserting the relay's address fence, and a `omarchy-kids-check` row for
  the relay and the devices (only the `units` row exists), are not built on this branch.
- R-NOTIFY-12 Update re-approval rides the same system: when an approved add-on's surface set or
  exec changes, the parent is notified and may approve, deny, or **check** it (Check shows what
  changed and decides nothing; it is not an onboard agent that assesses the change, `docs/review.md`).

## 3. R-BAR-3 (exact)

Before:

> R-BAR-3 Reads `/run/omarchy-kids/status.json`, root-written, group `omarchy-parents` readable.

After:

> R-BAR-3 Reads `/run/omarchy-kids/status.json`, root-written, group `omarchy-parents` readable.
> The document carries each live kid's minutes-left and paused state (R-NOTIFY-7) and the open-request
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

Authenticated requests carry `X-Kids-Device: <id>` and `X-Kids-Sig: <ts>.<nonce>.<sig>`; state
changes carry an inner `signed` object that root re-verifies (R-NOTIFY-4).

`proof` on `/v1/pair` is `HMAC-SHA256(token, sign_pub|box_pub|name)`: the pairing token (the QR's
credential) never travels, only a proof that the device holds it. The `grant`/`end` routes above are
the ACT frame's and are not built on this branch; a device learns its scopes and the kids from
`GET /v1/state`.

Away envelopes (R-NOTIFY-8, N-11: the box-side courier that seals and carries them is built, `docs/courier.md`; the app that opens them is not) are `{v, device_id, eph_pub, nonce, ct}`: a fresh ephemeral X25519 key does ECDH with the device's `box_pub`, HKDF-SHA256 (salt `omarchy-kids-envelope-v1`, info `x25519-chacha20poly1305`) derives the key, and ChaCha20-Poly1305 seals the document with a 12-byte nonce and the device id as associated data. `lib/envelope.py` seals; the device opens with its private box key; `clients/parent/test-vectors/notify-vectors.json` carries the vectors the app must reproduce. The envelope is confidential, not authenticated: anyone holding the device's public key can seal one, so the app must treat a sealed state document as untrusted display data and never act on it -- the decisions it sends the other way are signed by the device and verified by root. A box identity key (or a timestamp) is a later version's job.

File formats: `/etc/omarchy-kids/devices/<id>.conf` (root 0600: name, platform, both public keys,
`paired_at`, `paired_by`, scopes, `label_for_kids`); `/run/omarchy-kids/pairing/<id>` (root 0600, the
single-use pairing record). `/var/lib/omarchy-kids/<kid>/decisions/<id>.json` (0640 root:kid, the
result the kid's session reads) is **not built on this branch** -- the kid's result is shown by the ask
overlay instead.

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

- R-NOTIFY-14.1 **Source and trigger.** The only source is the `state` document as delivered by the `/v1/events` feed. The app keeps, in memory and for the life of the process only, the set of request ids and review ids it has seen. The first document of a run seeds that set and raises nothing. On every later document the app raises exactly one notification for each id in `requests` or `reviews` that is not in the set, then adds it. Nothing else raises one: not an id already in the set (a repost, a reconnect that replays the document, a heartbeat), not the passage of time (no reminder, no repeat), not an id leaving `requests` or `reviews` (a decision taken on the box, on another device, or by expiry), not a change to `kids` or `recent` (a login, a session end, a grant, `minutes_left`), not the feed connecting or dropping, and not a document from any other path (a `/v1/state` read, an away envelope). A reconnect diffs against the set, not against a fresh baseline: a request that arrived while the connection was down and the process was alive is new and is raised once. The set is never persisted: a fresh run starts silent, because a persisted set would raise, on open, things that arrived while the app was not running, which is exactly what R-NOTIFY-14.2 says the app cannot do.

- R-NOTIFY-14.2 **When.** A notification can be raised only while the feed is connected: the app in the foreground, or alive in the background for as long as the platform keeps the process and its connection. The app asks nothing more of the platform: no push token, no background-refresh or scheduled-task registration, no "keep alive" service. When the app is not running, or the platform has suspended it, there is no notification in v1; the request waits on the box (and on its own desktop notifier) until the app is opened. The label, on the pairing screen and beside the permission toggle, is exact: **"Notifies while the app is open. Nothing arrives while it is closed; open it to see what is waiting."** The app requests the platform's notification permission once, after pairing; a refusal is shown as "Notifications are off for this app in <platform> settings" and changes nothing else (the lists and decisions work without it).

- R-NOTIFY-14.3 **Content, payload, actions.** The title is the same string the list row shows: `describeRequest` for a request (the kid's display name the app already shows for that account, or "Your kid", and the `kind`/`what`/`minutes` the document carries) and `describeReview` for a review. The body is one fixed line: "Open to approve or decline" for a request, "Open to approve, deny or check" for a review. Nothing else from the document is placed in a notification: no account name beyond that kid's display name, no `was`/`now`, no id in visible text, no kid status. The payload is `{"kind": "request"|"review", "id": <id>}` and nothing more. A tap opens the request screen or the ReviewScreen for that id if it is in the current document, else the list. **There are no action buttons.** The box's notifier offers Approve/Decline/Deny/Check because each button lands at the parent's own terminal and sudo prompt: the password is the authentication and the screen is the review. On the device the signature is the authentication, so a button would sign a decision with no screen between the notification and the record: no reply chip, and for a review no `was`/`now` shown, which R-NOTIFY-12.3 requires (the parent signs the surface they looked at). Platform actions can also fire from a locked lock screen, and a handler that runs while the app is suspended has no feed to reconcile against. So a tap opens the screen that decides, and the decision goes through the same signed path as one taken from the list. Check is what ReviewScreen shows (R-NOTIFY-12.5); it is never a notification button.

- R-NOTIFY-14.4 **Identity, grouping, dismissal.** One notification per request id or review id. Its platform id is derived, not allocated: the first four bytes of `sha256("request:" + id)` or `sha256("review:" + id)` masked to a non-negative 31-bit integer, with the id string as the platform tag/thread where the platform has one. Raising the same id again replaces; it never stacks. All of the app's notifications sit in one platform channel/group ("Kids Mode", default importance, platform default sound); there is no per-kid channel or group, because a channel's name is stored by the platform outside the app. On every document the app cancels each notification it raised whose id is no longer in `requests` or `reviews`: that is how a decision made elsewhere, an expiry, or a review reopened under a new hash reaches an already-shown notification. Absence from the document is the signal; `recent` is not consulted (a review never appears there). On process start, and on Forget, the app cancels every notification it owns: the platform keeps them after the process dies, and a fresh run cannot tell which are still open until its first document, which raises nothing.

- R-NOTIFY-14.5 **What it is not.** It is not delivery: nothing about a request or review leaves the box for the device except over the feed the device already holds (I-2 as amended); a notification is local to the device and carries nothing to anyone. It is not a wake: no push service (APNs/FCM or any other), no push token, no server, no background fetch, no scheduled task, no badge count, no reminder, are built or registered in v1; a platform push that carries an opaque, contentless wake is a later version's question and is not this. It does not notify for a kid action or a kid state: no login, logout, session end, grant, end, or minutes change ever raises one. It does not decide: no signed record is produced from a notification. And it never reads the away envelope: the app does not use the courier for this.

## 14. R-NOTIFY-10 (exact)

Replace "and the platform limit on background delivery" with:

> and the app's own delivery limit: it notifies only while it is open and its feed is connected, nothing arrives while it is not running, and a tap opens the screen that decides rather than deciding itself (R-NOTIFY-14).
