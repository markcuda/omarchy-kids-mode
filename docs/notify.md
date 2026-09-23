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
omarchy-kids-notify away <off|tailnet> [--apply]
omarchy-kids-notify away-status
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
`omarchy-kids://pair` URI plus the relay's fingerprint. Where `qrencode` is installed the URI is also
drawn as a QR; otherwise the URI is there as the code. The app puts a proof in `POST /v1/pair` — the
HMAC of the token over its own keys and name, so the token itself never travels — and the relay
carries that frame to `authd`; root verifies it and registers the device. The app that would do that
is not built on this branch, so the window is ready for it with nothing on the device side to scan
yet. The
URI carries the single-use token, so it is piped to `qrencode` on **stdin**, never passed as an
argument a local session could read out of `/proc`.

Running this as root — from a terminal, or through the panel's warmed sudo — **is** the parent's
authentication, so there is no second password prompt. The window is consumed by the first device
that presents the token and expires on its own; `pair` refuses while notifications are off.

The URI's `addr=` list carries the box's own routable addresses (every global IPv4 except the
CGNAT range unless away is on, plus the tailnet address when `away tailnet` is on), so the app can
try another when one fails (N-10). The addresses also ride the single-use record; each is validated
before it reaches the URI.

## Away from home (N-10)

Off by default: the relay is fenced to the LAN (`docs/relayd.md`). `away tailnet` writes a systemd
drop-in adding the CGNAT range Tailscale uses (`100.64.0.0/10`) to the relay's allow list, so a
device on the parent's own tailnet can reach it; `away off` removes the drop-in. That range is the
parent's tailnet, but it is also where some ISPs put the box's WAN address, so the relay's own
authentication — the pinned certificate and signed decisions — is the lock, not the fence alone. It
changes nothing else about the fence, and it is the parent's own VPN, not a third party.

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
subscriber must not become the always-on listener R-NOTIFY-1 forbids. Root publishes only the
pairing window's expiry in `status.json` (`pairing_open_until`), which the relay reads through
`omarchy-parents`; the pairing record itself stays root-only, so the relay never sees the token
(R-NOTIFY-2). So the port is closed soon
after the last kid leaves and the last request is decided (the bound is the tick's 30-second status
refresh plus the grace plus the 5-second poll, about 95 seconds), and the tick brings it back within
30 seconds of the next login, request, or pairing. Starting it is best effort and never fails a
tick; a start that races the relay's own exit is harmless, since the next tick starts it again if it
is still needed.

## The desktop notifier (N-9)

On the Omarchy box the parent is told through their own desktop, not a device: `bin/omarchy-kids-notify-watch`
is a user-side process that polls the request queue (world-readable today; R-NOTIFY-7 tightens it to
`0750 root:omarchy-parents`, which the parent's group also reads) and the open add-on reviews
(`docs/review.md`), and posts one libnotify notification per item. A request offers **Approve** and
**Decline**; a changed add-on offers **Approve**, **Deny** and **Check**. An action runs
`omarchy-kids-bar approve|decline <id>` or `omarchy-kids-bar review-approve|review-deny|review-check
<kid> <id>` (`docs/bar.md`), which ends at the parent's own floating terminal and sudo prompt. Check
only shows the change and the notification is posted again, so the item stays answerable. Nothing
here is privileged and nothing here decides: with the watcher stopped, a kid is affected in no way
and the panel still works.

The action buttons come from `org.freedesktop.Notifications` over the session bus (`gdbus`); where
that is unavailable the fallback is a plain `notify-send` with no buttons and a body that points at
the panel. The watcher remembers which ids it has shown, in a user-owned state file, so a poll does
not re-notify; a request that is decided or withdrawn is forgotten. `lib/notify_watch.py` holds the
logic and `test/shell.d/notify-watch-test.sh` drives it with stubs.

## The fence, stated plainly (R-NOTIFY-10, I-6)

- The relay listens on the box's own address, home network only — plus the CGNAT range when the
  parent turns on away-from-home (N-10); `systemd/omarchy-kids-relayd.service` denies every address
  but those. Nothing here opens a connection outward.
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
