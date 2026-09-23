# The away courier: `bin/omarchy-kids-relay-courier` (SPEC.md R-NOTIFY-8, N-11)

The courier is the **only Kids Mode process that may open a connection beyond the LAN** (R-NOTIFY-8).
It seals the state for each paired device and posts it to the **one ntfy or Gotify topic the parent
named** — the parent's own server, not this project's and not a vendor's. It never decides anything,
holds no decision power, and is off by default.

## Turning it on

`omarchy-kids-notify mailbox <off|ntfy|gotify> --url <https://…> --topic <name>` writes
`/etc/omarchy-kids/courier.conf` (root `0600`); `mailbox off` removes it and `mailbox-status` prints
`off`, `ntfy` or `gotify`. The URL must be `https`, and for Gotify the token is typed on **stdin**
(never argv, like a password). With no config, or while notifications are off, the courier sends
nothing.

## What it sends

`omarchy-kids-relay-courier [--apply]` reads the root-written state (the same document the LAN relay
serves), seals it for each paired device with `lib/envelope.py` (`{v, device_id, eph_pub, nonce,
ct}` — X25519 ECDH, HKDF-SHA256, ChaCha20-Poly1305, the device id as associated data), and POSTs the
envelope: ntfy gets it as the topic body, Gotify as a POST to `/message` with the token in an `X-Gotify-Key`
header (not the query string, which proxy and access logs keep). Root only; `--apply` is required to
post (`DRY_RUN=1` prints the plan). A send is best effort per device, and the command exits nonzero
if any device's send failed, so a timer can notice.

The envelope is **confidential but not authenticated**: any holder of a device's public key can seal
one, so the app must treat a sealed document as untrusted display data and never act on it — the
decisions the app sends are signed separately and verified by root (Appendix H;
`clients/parent/README.md`). An app's decision coming back through the topic is a later step.

## Running it

`systemd/omarchy-kids-relay-courier.timer` runs the service every five minutes (and three minutes
after boot); with no config the run exits at once. The service is the one unit here allowed
`AF_INET`/`AF_INET6`, and it carries no capabilities and a strict filesystem view, because it is the
one process that talks to the outside.

## The one fence that matters

Nothing else in the package opens an outbound connection (`AGENTS.md` rule 2). The courier talks only
to the configured URL: https (loopback http is allowed for the tests), redirects are refused rather
than followed, and the proxy environment is ignored, so a redirected or proxied request cannot reach
a third host. It runs only while notifications are on, and a kid cannot reach it (root-owned config
and state, and the command is root-only).

## Tests

`test/shell.d/courier-test.sh` runs a local HTTP server, points a scratch config at it, and proves
that `--apply` posts a sealed envelope the device's private key opens (carrying the state), that a
dry run posts nothing, that the Gotify transport posts to `/message` with the token in a header and
the sealed state as its message, that a non-https server is refused, that a failed send exits
nonzero, and that notifications-off or no-config sends nothing.
`test/shell.d/envelope-test.sh` covers the seal itself.
