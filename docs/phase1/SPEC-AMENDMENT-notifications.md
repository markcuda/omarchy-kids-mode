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
