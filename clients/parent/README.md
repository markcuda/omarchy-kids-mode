# The parent app

A phone or desktop app that pairs with the box, shows a kid's requests with **Approve** and
**Decline**, and signs the decision back.

**The app is a first slice.** `clients/parent` is the logic — a pure-Dart package whose files are:

- `lib/notify_crypto.dart`: the box's signing, pairing and envelope code, byte for byte.
- `lib/relay_client.dart`: the frames and headers the relay expects (the pairing body, the
  `X-Kids-Device`/`X-Kids-Sig` headers, the decision body, the reply chips, the pairing URI).
- `lib/transport.dart`: the trust anchor and the client — the certificate's SPKI pin, and a
  `KidsRelayClient` that speaks TLS to the relay, streams `/v1/events` (a stream that goes three
  heartbeats quiet ends with an error, so a half-open connection cannot hang), and posts decisions
  and pairings.
- `lib/state_model.dart`: the relay's document as typed kids, requests and recent decisions, parsed
  defensively.
- `lib/session.dart`: the controller (the device key from the keystore, refresh/watch,
  approve/decline with a reply) over an injectable transport.
- `lib/pairing.dart`: the pairing flow (generate the device's sign and box keys once, send the proof
  and never the token, remember the paired box).
- `lib/app_link.dart`: what the pairing screen needs from the box's output — the URI inside a
  terminal paste, a fingerprint typed with spaces or colons, and bare addresses turned into
  host + port (the relay's port is fixed at 8447).

`clients/parent/app` is the Flutter UI over it: pairing (paste the code the computer printed, type
the fingerprint it showed, compare, pair), the request list, a request screen with Approve, Decline
and the reply chips, an add-on that changed since it was approved (with what changed — `was`/`now` —
and Approve or Deny), and the kids themselves, where a tap gives **more time today** (15/30/60
minutes) or ends the session. Those two act with the device's own key and the `act` scope the parent
gave it: no password is typed, the box refuses without the scope, and the screen says so. A request
or an add-on change that arrives while the app is open is raised as a local notification (tap it to
open the row); nothing arrives while the app is closed, and the screen says exactly that — there is
no push, no server and no wake in v1. The notification rules (and the no-buttons choice: a tap opens
the screen that decides) are in the amendment, R-NOTIFY-14. Windows has no notification adapter in
this build; the lists and decisions work there regardless. The review decision signs the fingerprint the screen
showed, so the box refuses it if the surface moved since (R-NOTIFY-12). The list follows the box's own feed (`/v1/events`), so a new request
appears without a refresh; when the feed drops it says so, keeps the last list on screen, and
retries with a growing delay. The overflow menu offers **Forget this computer**, which clears the
local pairing so the app can pair again (a box that re-keyed has a pin this app can no longer
match); it asks first, and says the box keeps its own record until the parent revokes the device
there. The pairing and the device's own keys are kept in the system keystore (`flutter_secure_storage`:
Keychain, Android Keystore, Credential Manager, Secret Service) through a small `SecretStore` seam,
so a later run opens on the requests without the code; where there is no usable keystore the app
falls back to memory and the pairing screen says the pairing lasts only for the run. On Apple
platforms the keychain policy is first-unlock, this-device-only, so the keys open for a background
notification while the phone is locked but never ride a backup onto a second phone. A stored key the
app can no longer read (restored from another device, say) is not a dead end: the pairing screen
offers a reset that clears the device's keys and pairing, and says the computer keeps the old device
until it is revoked there. All of it is
widget-tested against a fake relay, a fake connection and a fake store. The device list, the store builds remain — there is nothing to install on a phone yet. The
system-notification adapter (`app/lib/local_notifier.dart`) is the one file that talks to the OS
plugin; it has not run on any platform here (no `android/`, `ios/` or `macos/` scaffolding is
committed), so treat it as written-not-proven on every platform, not just the ones it names.

The crypto and the wire frames are proven against the shared vectors byte for byte; the reply chips,
the pairing-URI parser and the SPKI pin are pinned by the package's own tests (the pin fixture,
`test/fixtures/relay-cert.pem`, is a throwaway public certificate minted by `lib/cert.py`;
`test/shell.d/parent-app-test.sh` also checks the Dart constant equals what `lib/cert.py` prints);
and the client is proven end to end against the box's own relay (`test/relay_integration_test.dart`
starts `bin/omarchy-kids-relayd`, pins it, makes a signed read, streams a state event, and shows a
decision POST and a pairing POST reach the relay's authd-forwarding step; the SSE parser's edge
cases are unit-tested). The box side is complete (`docs/notify.md`, `docs/relayd.md`,
`docs/devices.md`).

```
cd clients/parent && dart pub get && dart test      # the crypto tests, against the vectors
```

`test/shell.d/parent-app-test.sh` runs those in the suite where a Dart SDK is present, and skips
without one; `test/shell.d/parent-ui-test.sh` runs the widget tests where Flutter is present:

```
cd clients/parent/app && flutter pub get && flutter test
```

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
4. **Away mailbox.** The app package opens the courier's sealed state
   (`lib/relay_client.dart`'s `openStateEnvelope`), but there is no mailbox view:
   the app reads the box over the relay, not the parent's own ntfy/Gotify server.

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

The device list, the platform notification plumbing, and the store builds are the app's own work
(N-8/N-12) and are not claimed. The system-keystore adapter (`lib/keystore.dart`'s
`FlutterSecureStore`) is written but has only been exercised through its seam and its memory
fallback here; a device build is where it is proven.
