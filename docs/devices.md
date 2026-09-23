# The paired-device registry: `bin/omarchy-kids-devices` (SPEC.md R-NOTIFY-3/4/5/9)

The parent's notification devices are the phones and computers that may see a kid's requests and
answer them. Each is a record the parent created by pairing; each decision a device sends is
verified by root before it is applied, and the relay itself never decides (`docs/relayd.md`).

## The records

| Path | Mode / owner |
| --- | --- |
| `/etc/omarchy-kids/devices/<id>.conf` | `0600 root` |
| `/etc/omarchy-kids/devices/` | `0750 root` |
| `/run/omarchy-kids/devices.json` | `0644`, the public copy the relay reads |

A record is `key=value` lines: `id`, `name`, `platform`, `sign_pub` and `box_pub` (base64 public
keys), `scopes`, plus who added it and when. `publish` writes the public copy (`id`, name, platform,
scopes and the two **public** keys — never a private key) for the relay. Root only; `DRY_RUN=1` is
the default and prints the plan (`AGENTS.md` rule 8).

## Commands

```
omarchy-kids-devices list [--json]
omarchy-kids-devices add --id ID --name NAME --platform P --sign-pub B64 --box-pub B64 [--scopes decide,act] [--by WHO] [--apply]
omarchy-kids-devices rename <id> <name> [--apply]
omarchy-kids-devices scopes <id> decide[,act] [--apply]
omarchy-kids-devices revoke <id> [--apply]
omarchy-kids-devices publish [--apply]
omarchy-kids-devices pair-start [--id ID] [--scopes decide,act] [--apply]
```

- `add` is normally the PAIR frame's job (below); a parent rarely runs it by hand.
- `revoke` renames the record to `<id>.conf.revoked`, so the relay's public copy stops offering it
  and a revoked device's signature is refused. A revoked id stays revoked: `pair-start` refuses it
  and `load_device` returns nothing while the `.revoked` file exists, so revoking is final for that
  id -- pair the device again under a new id.
- `publish` must be re-run after a change for the relay to see it; `add`/`rename`/`scopes`/`revoke`
  do it for you.
- `pair-start` writes one single-use pairing record (R-NOTIFY-5) and prints the `omarchy-kids://pair`
  URI that carries the token. The token is the only credential; the record expires and is consumed
  by the PAIR frame. `omarchy-kids-notify pair` is the parent-facing wrapper (`docs/notify.md`).

## Scopes (R-NOTIFY-9)

A device carries `decide` (approve or decline a request) and/or `act` (grant time or end a session
with no open request). **`decide` is enforced today**: `authd`'s DECIDE frame refuses a decision
from a device whose scopes lack it. `act` is defined by the spec but its ACT frame is not built on
this branch, so a device may carry the `act` scope and still cannot act with it yet -- the scope is
stored and re-checked, not yet a control.

## How a decision is verified (R-NOTIFY-4)

A device signs a canonical record with its Ed25519 key; `omarchy-kids-authd` verifies it with
`python-cryptography` against the root-owned public key and refuses on any of: unknown or revoked
device, missing `decide` scope, clock skew over five minutes, a nonce seen in the last ten minutes,
or an already-decided record. On success the decision is applied through the same path the panel
uses, recorded with `by: device` and the device id. The relay only forwards the frame
(`docs/relayd.md`);
`docs/authd.md` has the frames (VERIFY, BOOTSTRAP, PAIR, DECIDE). Everything fails closed: a missing
library, an unreadable record or a bad signature refuses, never applies.

## Files root opens for a kid

Nothing here is kid-writable. Where root does read a value a kid could have written (their outbox, a
pairing record), it is validated at read time and opened with `O_NOFOLLOW` and a regular-file and
owner check, never through the shell (`AGENTS.md`, "The trust boundary").

## Tests

`test/shell.d/devices-test.sh` (modes, the id and key validation, revoke, publish, the pairing
record), `test/shell.d/device-verify-test.sh` (`lib/devices.py`'s signature and request checks) and
`test/shell.d/authd-test.sh` (the frames, including the refusals).
