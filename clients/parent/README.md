# The parent app

A phone or desktop app that pairs with the box, shows a kid's requests with **Approve** and
**Decline**, and signs the decision back.

**The UI is not built.** This directory holds the half that can be pinned down before it: a pure-Dart
package — `lib/notify_crypto.dart` (the box's signing, pairing and envelope code, byte for byte) and
`lib/relay_client.dart` (the frames and headers the relay expects: the pairing body, the
`X-Kids-Device`/`X-Kids-Sig` headers, the decision body, the reply chips and the pairing URI) and
`lib/transport.dart` (the trust anchor and the client: the certificate's SPKI SHA-256 — the value
the parent reads off the pairing screen and the app pins — and a `KidsRelayClient` that speaks TLS
to the relay with the signed headers). The
crypto and the wire frames are proven against the shared vectors, byte for byte; the reply chips and
the pairing-URI parser and the SPKI pin are pinned by the package's own tests (the pin fixture,
`test/fixtures/relay-cert.pem`, is a throwaway public certificate minted by `lib/cert.py`;
`test/shell.d/parent-app-test.sh` also checks the Dart constant equals what `lib/cert.py` prints),
and the client is proven end to end against the box's own relay
(`test/relay_integration_test.dart` starts `bin/omarchy-kids-relayd`, pins it and makes a signed
read). There is no Flutter project and nothing to install
on a phone yet, so there is nothing to scan a pairing QR with — `AGENTS.md` rule 6 is why this file
says so plainly. The box side is complete (`docs/notify.md`, `docs/relayd.md`, `docs/devices.md`).

```
cd clients/parent && dart pub get && dart test      # the crypto tests, against the vectors
```

`test/shell.d/parent-app-test.sh` runs those in the suite where a Dart SDK is present, and skips
without one.

## What the app must implement

1. **Pair.** Ask the box for a window (the parent does that from the panel), read the
   `omarchy-kids://pair` QR, and `POST /v1/pair` with
   `{id, name, platform, sign_pub, box_pub, proof}` where
   `proof = HMAC-SHA256(token, sign_pub|box_pub|name)` and `token` is the URI's `&token=`. The token
   itself never goes on the wire. `id` becomes the device id. Pin the relay's certificate by its
   **SPKI** SHA-256, which the parent reads off the pairing screen.
2. **Read.** Sign every request and `GET /v1/state`, or hold `GET /v1/events` for the SSE stream. The
   `addr=` list on the pairing URI is the box's own addresses to try. The signature travels in the
   headers, not the body:    `X-Kids-Device: <id>` and `X-Kids-Sig: <ts>.<nonce>.<sig>` (a dot-separated
   triple, so the nonce must contain no `.`; it is otherwise a fresh **ASCII** string up to 128
   bytes — the relay reads headers as latin-1, so keep it ASCII). An unsigned or malformed-header
   request is refused.
3. **Decide.** Sign a decision record and `POST /v1/requests/<id>/decision` with a JSON body
   `{record, signature}` **and** the same signed headers; the reply line rides `record.reply` (at most
   80 printable characters — `lib/devices.py`'s `MAX_REPLY`).
4. **Act** (grant/end) is the ACT frame's and is not built on the box yet.

## The signing scheme

Ed25519, base64 (standard alphabet) of the 64-byte signature. The exact bytes are a **context
prefix**, a newline, then JSON as **the box serializes it**: `json.dumps(record, sort_keys=True,
separators=(",", ":"))` with Python's default `ensure_ascii=True`, i.e. compact, sorted keys, and
every non-ASCII character escaped as `\uXXXX`. A Dart `jsonEncode` emits raw UTF-8 and will not match
for a reply with non-ASCII, a quote or a backslash — the shared vectors carry exactly that case. UTF-8 encode the
resulting string.

- **Decision**: `"omarchy-kids-decision-v1\n"` + `{device_id, request_id, decision, reply?, ts, nonce}`
  (`decision` is `approve` or `decline`, `ts` in Unix seconds).
- **Request**: `"omarchy-kids-request-v1\n"` +
  `{device_id, ts, nonce, method, path, body_sha256}`, where `body_sha256` is the hex SHA-256 of the
  request body (`""` hashes the empty string).
- **Pairing proof** (not Ed25519): hex HMAC-SHA256 keyed by the raw token bytes, over the UTF-8
  string `sign_pub + "|" + box_pub + "|" + name`.

The box verifies all three against the root-owned public key and refuses on an unknown or revoked
device, a missing `decide` scope, clock skew over five minutes, and a nonce seen in the last ten
minutes (`docs/devices.md`).

## Away envelopes (N-11)

The box-side away delivery **is** built (`docs/courier.md`); the app that opens the envelope is not,
so the format is pinned for it: a state
document is sealed for one device with a fresh ephemeral X25519 key, ECDH against the device's
`box_pub`, HKDF-SHA256 (salt `omarchy-kids-envelope-v1`, info `x25519-chacha20poly1305`), then
ChaCha20-Poly1305 with a random 12-byte nonce and the device id as associated data. The envelope is
`{v, device_id, eph_pub, nonce, ct}`. The app opens it with its private box key; `lib/envelope.py`
is the box side, and the vectors carry a worked example (recipient key, ephemeral key, nonce,
envelope) the app must open and reproduce.

The envelope is **confidential, not authenticated**: any holder of a device's public key can seal one,
so the app must show what it opens as untrusted and never act on it. Decisions the app sends are
signed separately and verified by root.

## The vectors

`test-vectors/notify-vectors.json` is generated by `test-vectors/generate.py` from a fixed seed and
carries, for one device: the public key, the two context prefixes (base64), a signed decision record
and its signature, a signed request and its signature, and a pairing token with its proof. Each
signed case also carries the **exact message bytes** it signed (`decision_message_b64`,
`request_message_b64`), so the file is self-describing. `test/shell.d/notify-vectors-test.sh` proves
the file still matches `lib/devices.py`; the app's own tests should read the same file and prove the
app reproduces every signature. Run the generator after changing the scheme and commit the new file.

## What this does not decide

The UI, the keystore, the platform notification plumbing, and the store builds are the app's own
work (N-8/N-12); none of it can be built without a Flutter toolchain, so none of it is claimed.
