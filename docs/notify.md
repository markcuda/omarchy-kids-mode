# The parent's notifications: `bin/omarchy-kids-notify` (SPEC.md R-NOTIFY, `docs/phase1/SPEC-AMENDMENT-notifications.md`)

This is the parent's switch for device notifications: turning the system on or off, minting the
relay's certificate, and pairing a device. It is the only place the certification and the device
registry are touched from the parent's side, and it never decides anything itself (R-NOTIFY-2).

```
omarchy-kids-notify enable [--host NAME] [--rekey] [--apply]
omarchy-kids-notify disable [--apply]
omarchy-kids-notify status
omarchy-kids-notify pair [--scopes decide,act] [--apply]
omarchy-kids-notify devices [--json]
omarchy-kids-notify rename <id> <name> [--apply]
omarchy-kids-notify scopes <id> decide[,act] [--apply]
omarchy-kids-notify revoke <id> [--apply]
```

Root only. `DRY_RUN=1` is the default for every writing subcommand (AGENTS.md rule 8), so a run
without `--apply` prints the plan and changes nothing; `--help` works for anyone, before the root
check. There is no network access anywhere in this command.

## `enable`

Mints one EC P-256 self-signed certificate (`lib/cert.py`) at `/etc/omarchy-kids/relay/cert.pem`
(`0644`) with its key at `key.pem` (`0640 root:omarchy-parents`), inside a `0750
root:omarchy-parents` directory the relay reads through its group. It prints the certificate's
**SPKI** SHA-256 fingerprint — the value a device pins, and the value the pairing screen shows
again — and the relay port (`8447`).

There is no CA and no DNS name to trust: the security is entirely in the parent comparing that
fingerprint on the device at pairing time. The certificate body lives ten years; rotating it is
`enable --rekey`.

**Running `enable` again does not re-key.** It prints the existing fingerprint and returns, because
every paired device pinned the current key. `enable --rekey` is the explicit way to replace it, and
since the devices pinned the key it replaces, it first **unpairs every device** (their pins are
stale) and stops the relay so its next start reads the new certificate.

## `disable`

Revokes every paired device, removes the certificate and key, and stops
`omarchy-kids-relayd.service`. After it, no listener exists while notifications are off
(R-NOTIFY-1) and no device holds a key that could approve anything.

## `status`

Prints whether notifications are on (the certificate is present), the relay port, and the paired
devices. The bar widget and the panel read the same state.

## `pair`

Starts a single-use pairing window (`omarchy-kids-devices pair-start`, R-NOTIFY-5) and prints the
`omarchy-kids://pair` URI plus the relay's fingerprint. Where `qrencode` is installed the URI is
also drawn as a QR; otherwise the code is there to read into the app. The URI carries the single-use
token, so it is piped to `qrencode` on **stdin**, never passed as an argument a local session could
read out of `/proc`.

Running this as root — from a terminal, or through the panel's warmed sudo — **is** the parent's
authentication, so there is no second password prompt. The window is consumed by the first device
that presents the token and expires on its own; `pair` refuses while notifications are off.

## The device subcommands

`devices`, `rename`, `scopes`, `revoke` and `publish` delegate straight to `omarchy-kids-devices`
(`docs/devices.md`); this command adds nothing to them beyond the shared root check and the plan
printing.

## Lifecycle: the relay exists only while it is needed (N-7)

There is no always-on listener. `omarchy-kids-time-ledger tick` (every 30 seconds, root) asks
`omarchy-kids-relayd.service` to start when Kids Mode is in use — a kid live, a request open, or a
pairing window open — and does nothing while notifications are off. The relay stops itself on the
same condition (`lib/relay.py`'s `is_needed` and `needs_stopping`): after a 60-second grace with
Kids Mode not in use, it closes — dropping any device that was holding a stream open, because a
subscriber must not become the always-on listener R-NOTIFY-1 forbids. It reads the pairing records
through its `omarchy-parents` group, so a window keeps it up; a pairing directory it cannot read
reads as no window and never stops the exit loop. So the port is closed soon
after the last kid leaves and the last request is decided (the bound is the tick's 30-second status
refresh plus the grace plus the 5-second poll, about 95 seconds), and the tick brings it back within
30 seconds of the next login, request, or pairing. Starting it is best effort and never fails a
tick; a start that races the relay's own exit is harmless, since the next tick starts it again if it
is still needed.

## The fence, stated plainly (R-NOTIFY-10, I-6)

- The relay listens on the box's own address, home network only; `systemd/omarchy-kids-relayd.service`
  denies every address but the LAN ranges. Nothing here opens a connection outward.
- The relay never decides; a decision is authenticated and applied by root (R-NOTIFY-2/4).
- Turning notifications off stops the listener and revokes the devices; a kid cannot reach any of
  this (root-owned, outside every home, `bin/omarchy-kids-notify` resolves its siblings from its own
  location).

## The panel (P6)

`lib/panel-notify.sh` is the parent's screen for all of the above (`docs/panel.md`): the on/off
state, enable/disable, pair (showing the code and fingerprint), and the paired-device list with a
revoke per device. The panel runs unprivileged, so each call goes through its own `sudo` wrappers.

## Files

| Path | Mode / owner |
| --- | --- |
| `/etc/omarchy-kids/relay/cert.pem` | `0644 root:omarchy-parents` |
| `/etc/omarchy-kids/relay/key.pem` | `0640 root:omarchy-parents` |
| `/etc/omarchy-kids/devices/*.conf` | root-owned device records (`docs/devices.md`) |

## Tests

`test/shell.d/notify-test.sh` (root-only, status, enable preview/mint/modes/idempotence/re-key,
disable, the pairing window) stubs `systemctl` and `qrencode` and works against a scratch tree;
`test/shell.d/panel-test.sh` drives the P6 screen through `OMARCHY_KIDS_TUI_ANSWERS`.
