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
> notifications are on. The only outbound connections are to the one address the parent typed, and
> everything sent there is end-to-end encrypted for one paired device. Nothing about a child ever
> reaches this project, the package's authors, or any push vendor. A platform push service may carry
> at most an opaque wake with no content, and only after the parent has enabled it and read what it
> carries.

## 2. New requirement section (paste after R-ASK)

### R-NOTIFY Parental notifications

- R-NOTIFY-1 The only network listener is `omarchy-kids-relayd`, a root-owned system unit whose
  configuration fences it to loopback and the private LAN ranges. It runs only while Kids Mode is in
  use and notifications are enabled, and exits on its own when idle. No listener exists while
  notifications are off.
- R-NOTIFY-2 The relay never decides. Every decision is authenticated and applied by root
  (`omarchy-kids-authd` / `omarchy-kids-ask`), through the same `apply_record` path the panel uses.
  A compromised relay can, at worst, stop delivering notifications.
- R-NOTIFY-3 The device registry is root-owned under `/etc/omarchy-kids/devices/`. Each record holds
  a device's public keys, its scopes and its pairing provenance. Revocation is a root write and
  takes effect immediately.
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
- R-NOTIFY-11 `omarchy-kids-assert` re-asserts the relay unit, its fence and the devices directory
  ownership on every update; `omarchy-kids-check` reports them.
- R-NOTIFY-12 Update re-approval rides the same system: when an approved add-on's surface set or
  exec changes, the parent is notified and may approve, deny, or ask their onboard agent to check it
  (the add-on model's re-approval rule).

## 3. R-BAR-3 (exact)

Before:

> R-BAR-3 Reads `/run/omarchy-kids/status.json`, root-written, group `omarchy-parents` readable.

After:

> R-BAR-3 Reads `/run/omarchy-kids/status.json`, root-written, group `omarchy-parents` readable.
> The document carries each live kid's minutes-left and paused state, and the open-request count and
> list (R-NOTIFY-7); the bar widget's badge reads the count from it rather than running any command.
> It also carries the pairing window's expiry (`pairing_open_until`), never the token, so the relay
> can keep itself up while a phone pairs (R-NOTIFY-2/5).

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
POST /v1/pair                       {code, name, platform, sign_pub, box_pub, proof} -> {device_id, relay_sign_pub, scopes, kids}
GET  /v1/state                      -> {kids:[...], requests:[open...], recent:[decided<24h]}
GET  /v1/events                     SSE: state, request.opened, request.decided, kid.live, kid.paused, kid.timeup
POST /v1/requests/<id>/decision     {decision: approve|decline, reply?, signed:{...}}
POST /v1/kids/<account>/grant       {minutes, signed:{...}}      scope act
POST /v1/kids/<account>/end         {signed:{...}}               scope act
GET  /v1/avatars/<id>.svg
```

Authenticated requests carry `X-Kids-Device: <id>` and `X-Kids-Sig: <ts>.<nonce>.<sig>`; state
changes carry an inner `signed` object that root re-verifies (R-NOTIFY-4).

File formats: `/etc/omarchy-kids/devices/<id>.conf` (root 0600: name, platform, both public keys,
`paired_at`, `paired_by`, scopes, `label_for_kids`); `/run/omarchy-kids/pairing/<id>` (root 0600, the
single-use pairing record); `/var/lib/omarchy-kids/<kid>/decisions/<id>.json` (0640 root:kid, the
result the kid's session reads).

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
