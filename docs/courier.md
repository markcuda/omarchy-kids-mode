# The away courier: `bin/omarchy-kids-relay-courier` (SPEC.md R-NOTIFY-8, N-11)

The courier is the **only Kids Mode process that may open a connection beyond the LAN** (R-NOTIFY-8).
It seals the state for each paired device and posts it to the **one ntfy or Gotify topic the parent
named** — the parent's own server, not this project's and not a vendor's. It never decides anything,
holds no decision power, and is off by default.

## Turning it on

`omarchy-kids-notify mailbox <off|ntfy|gotify> --url <https://…> --topic <name> [--token <token>]`
writes `/etc/omarchy-kids/courier.conf` (root `0600`); `mailbox off` removes it and
`mailbox-status` prints `off`, `ntfy` or `gotify`. The URL must be `https`, and Gotify also needs a
token. With no config, or while notifications are off, the courier sends nothing.

## What it sends

`omarchy-kids-relay-courier [--apply]` reads the root-written state (the same document the LAN relay
serves), seals it for each paired device with `lib/envelope.py` (`{v, device_id, eph_pub, nonce,
ct}` — X25519 ECDH, HKDF-SHA256, ChaCha20-Poly1305, the device id as associated data), and POSTs the
envelope: ntfy gets it as the topic body, Gotify as `/message?token=…`. Root only; `--apply` is
required to post (`DRY_RUN=1` prints the plan).

The envelope is **confidential but not authenticated**: any holder of a device's public key can seal
one, so the app must treat a sealed document as untrusted display data and never act on it — the
decisions the app sends are signed separately and verified by root (Appendix H;
`clients/parent/README.md`). An app's decision coming back through the topic is a later step, as is
the systemd unit that runs the courier on a timer.

## The one fence that matters

Nothing else in the package opens an outbound connection (`AGENTS.md` rule 2). The courier talks only
to the configured URL, and only while notifications are on; a kid cannot reach it (root-owned config
and state, and the command is root-only).

## Tests

`test/shell.d/courier-test.sh` runs a local HTTP server, points a scratch config at it, and proves
that `--apply` posts a sealed envelope the device's private key opens (carrying the state), that a
dry run posts nothing, and that notifications-off or no-config sends nothing.
`test/shell.d/envelope-test.sh` covers the seal itself.
