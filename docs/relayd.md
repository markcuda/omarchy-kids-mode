# `bin/omarchy-kids-relayd`: the LAN relay (SPEC.md R-NOTIFY-1/2, `docs/phase1/SPEC-AMENDMENT-notifications.md`)

The relay is the **only network listener** Kids Mode ships. It is a root-owned system unit
(`systemd/omarchy-kids-relayd.service`) that runs as `omarchy-kids-relay:omarchy-parents`, fenced to
loopback and the private LAN ranges, and it **never decides anything** (R-NOTIFY-2): it serves the
root-written state to the parent's paired devices and forwards a signed decision, review decision or
action to `omarchy-kids-authd`, which verifies and applies it.

## Lifecycle: it runs only while it is needed (N-7)

There is no always-on listener. `omarchy-kids-time-ledger tick` (root, every 30 seconds) asks the
unit to start when Kids Mode is in use — a kid live, a request open, or a pairing window open — and
does nothing while notifications are off. The relay stops itself once none of those has held for the
grace (`--needless-seconds`, default 60), even if a device is holding a stream open; `main_async`
cancels the client tasks and closes the server. So the port is closed soon after the last kid leaves
and the last request is decided, and the tick starts it again within 30 seconds of the next login,
request or pairing. `lib/relay.py`'s `is_needed` and `needs_stopping` are that rule; the field root
publishes for it is `pairing_open_until` in `status.json` (never the token, `docs/time.md`).

## TLS and what a device pins

The relay speaks TLS only, with the self-signed certificate `omarchy-kids-notify enable` mints
(`lib/cert.py`). There is no CA and no name: a device pins the certificate's **SPKI** SHA-256
fingerprint, which the parent compares at pairing (`docs/notify.md`). A plaintext client gets no
HTTP response.

## The API (Appendix H)

Every request except the TLS handshake and `/v1/pair` must be signed by a paired, unrevoked device:
the headers `X-Kids-Device: <id>` and `X-Kids-Sig: <ts>.<nonce>.<base64 Ed25519 signature>` cover the
method, path, timestamp, nonce and body. The relay refuses an unsigned request, a bad signature, an
unknown device, a stale timestamp (over five minutes) and a replayed nonce (a nonce seen in the last
ten minutes is in `--nonce-ledger`). `/v1/pair` is pre-auth: there is no device yet, and the frame
carries a proof (`HMAC-SHA256(token, sign_pub|box_pub|name)` — the pairing token itself never
travels), verified by root; a refusal is returned generically, so an unauthenticated caller learns
nothing from it (`docs/notify.md`).

| Method and path | What it does |
| --- | --- |
| `POST /v1/pair` | Carries a pairing frame (`id`, `name`, `platform`, `sign_pub`, `box_pub`, `proof`) to `authd`'s PAIR frame, which verifies the single-use proof and registers the device (R-NOTIFY-5). The relay never reads the root-only pairing record (R-NOTIFY-2). |
| `GET /v1/state` | The state document (`lib/relay.py`'s `build_state`: kids, open requests, recent decisions, open add-on reviews) from the root-written `status.json`, the queue and the reviews directory (R-NOTIFY-12). `recent` is the queue's decided records within 24h, each the request row plus `state`, `decided_at` and, when the parent typed one, `reply`; never `by` or `device`, which stay on the box for `omarchy-kids-ask list` (R-NOTIFY-15). |
| `GET /v1/events` | The same document as a Server-Sent Events stream: a `state` event per change and a heartbeat when nothing changes. A stream is authenticated once at connect, so a device revoked while it holds one keeps receiving state until the relay stops; its next request is refused. |
| `GET /v1/avatars/<name>` | One kid avatar from `--share`; a traversal is a 404. |
| `POST /v1/requests/<id>/decision` | Forwards the signed decision frame to `authd`'s DECIDE socket and returns its one-line reply. The relay does not apply it (R-NOTIFY-2). |
| `POST /v1/kids/<account>/grant` and `POST /v1/kids/<account>/end` | A paired device's grant or end (R-NOTIFY-13). The relay checks only the route's own shape (the account is a kid account, the signed record names that account and the route's action, and a grant's minutes are 1..1440) and carries the body verbatim as an `ACT` frame to authd, which verifies the signature with the `act` scope, checks the target is a provisioned kid, and runs the command as root. The relay does not check the account exists and never acts (R-NOTIFY-2). |
| `POST /v1/reviews/<review-id>/decision` | The same, for an add-on review (R-NOTIFY-12): it checks only the route's own shape and carries a `REVIEW` frame to authd, which re-reads the review file, refuses a fingerprint the app did not sign, and runs `omarchy-kids-review approve\|deny`. The relay does not open the review file and never decides. |

A decision is applied only after root verifies a signature from a paired, unrevoked device and the
`decide` scope (R-NOTIFY-9), through the same path the panel uses (R-NOTIFY-4); `docs/devices.md` and
`docs/authd.md` have the details. An action (R-NOTIFY-13) is applied the same way with the `act`
scope: the relay checks only the route's own shape and carries the body to authd as an `ACT` frame.

## The fence

`systemd/omarchy-kids-relayd.service` allows only `localhost link-local multicast` and the private
v4/v6 ranges, with `IPAddressDeny=any` after them, and sets `ProtectSystem=strict`, `ProtectHome=yes`,
`NoNewPrivileges=yes`, `PrivateTmp=yes`, `ReadOnlyPaths=/var/lib/omarchy-kids` and the other
hardening `systemd/omarchy-kids-wifid.service` uses. The parent may opt in to "away from home"
(N-10, `docs/notify.md`): a drop-in adds the CGNAT range `100.64.0.0/10` to the allow list, which is
the parent's tailnet but also any CGNAT network the box sits behind directly — the relay's own auth
(the pinned certificate and signed decisions) is the lock, not the fence alone). The drop-in adds
that one range and nothing else. Because the relay can never approve anything, its whole attack surface is
"notifications stop" (`docs/phase1/SPEC-AMENDMENT-notifications.md`).

## Files and flags

| Path | Mode / owner |
| --- | --- |
| `/etc/omarchy-kids/relay/{cert,key}.pem` | `0644` and `0640 root:omarchy-parents` (`docs/notify.md`) |
| `/run/omarchy-kids/devices.json` | the public device copy the relay reads, `0644` (`docs/devices.md`) |
| `/run/omarchy-kids/status.json` | `0640 root:omarchy-parents` |
| `/var/lib/omarchy-kids/queue/` | the ask queue, `0750 root:omarchy-parents`, records `0640` (R-NOTIFY-7, `docs/ask.md`) |
| `/var/lib/omarchy-kids/reviews/open/` | the open add-on reviews, `0750 root:omarchy-parents`, records `0640` (R-NOTIFY-12, `docs/review.md`) |
| `<nonce ledger>` | `--nonce-ledger`, default `/run/omarchy-kids/relay/nonces.json` |

The unit passes `--cert` and `--key`; every other flag is an argparse default that matches the paths
in the table above (`--devices-json`, `--status`, `--queue`, `--reviews`, `--auth-sock`,
`--nonce-ledger`, `--share`, `--lib`, `--needless-seconds`). `--bind`/`--port` default to `0.0.0.0` and `8447`. Nothing
here is settable by a kid (`AGENTS.md`, "The trust boundary").

## Tests

`test/shell.d/relay-test.sh` covers `lib/relay.py` (state, decision forwarding, `is_needed`,
`needs_stopping`) with no listener; `test/shell.d/relayd-test.sh` starts the relay on a scratch tree
with a test certificate and drives it from a Python client over TLS (signed and unsigned reads, a
replay, a stale timestamp, an unknown device, a decision POST to a stub authd, a pair POST and a
malformed one, an SSE stream, a plaintext client, and the not-in-use stop with a stream held open). It also proves the state carries the open reviews, and the refusals each route makes on its own shape (an unsigned POST, a review id that is not one, a record naming another review, a grant naming another account, minutes out of range, an end carrying minutes).
