"""lib/courier.py -- the away courier's transport (N-11, R-NOTIFY-8).

The one process that may open a connection beyond the LAN. It seals the state
document for each paired device (`lib/envelope.py`) and posts it to the server the
parent named -- an ntfy or Gotify topic of their own. Off by default: with no
config it refuses, and with notifications off there is no state to send.

This is the outbound half; pulling the parent's signed decisions back is a later
step. Nothing here decides, and nothing is sent anywhere but the configured
server. Stdlib only (+ python-cryptography through envelope.py).
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
TRANSPORTS = ("ntfy", "gotify")


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


envelope = _load(os.path.join(HERE, "envelope.py"), "kids_envelope")
relay = _load(os.path.join(HERE, "relay.py"), "kids_relay")


def load_config(path):
    """The parent's server config, or None. A missing or empty file means off."""
    config = {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                config[key.strip()] = value.strip()
    except OSError:
        return None
    if not config.get("transport") or not config.get("url"):
        return None
    return config


def load_devices(path):
    """The paired devices' public records the relay reads (id + box_pub)."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return []
    if not isinstance(data, list):
        return []
    out = []
    for entry in data:
        if not isinstance(entry, dict):
            continue
        device_id, box_pub = entry.get("id"), entry.get("box_pub")
        if isinstance(device_id, str) and device_id and isinstance(box_pub, str) and box_pub:
            out.append({"id": device_id, "box_pub": box_pub})
    return out


def _post(url, body, timeout):
    request = urllib.request.Request(
        url, data=body, method="POST", headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 -- the configured server
        return response.status


def post_ntfy(base_url, topic, body, timeout=15):
    """ntfy: POST the body to <base>/<topic>."""
    target = base_url.rstrip("/") + "/" + urllib.parse.quote(topic, safe="")
    return _post(target, body, timeout)


def post_gotify(base_url, token, title, body, timeout=15):
    """Gotify: POST /message?token=... with a JSON title/message."""
    target = base_url.rstrip("/") + "/message?token=" + urllib.parse.quote(token, safe="")
    payload = json.dumps({"title": title, "message": body.decode("utf-8")}).encode("utf-8")
    return _post(target, payload, timeout)


def send(config, state, devices, timeout=15):
    """Seal `state` for each device and post it. Best effort per device.

    Returns [(device_id, status_or_error), ...]; the caller reports them.
    """
    transport = config.get("transport")
    if transport not in TRANSPORTS:
        raise ValueError(f"unknown transport {transport!r}")
    plaintext = json.dumps(state, separators=(",", ":"), sort_keys=True).encode("utf-8")
    results = []
    for device in devices:
        try:
            sealed = envelope.seal(device["id"], device["box_pub"], plaintext)
            body = json.dumps(sealed, separators=(",", ":")).encode("utf-8")
            if transport == "ntfy":
                status = post_ntfy(config["url"], config.get("topic", "omarchy-kids"), body, timeout)
            else:
                status = post_gotify(
                    config["url"], config.get("token", ""), "omarchy-kids", body, timeout
                )
            results.append((device["id"], status))
        except Exception as exc:  # noqa: BLE001 -- one device's failure is not the others'
            results.append((device["id"], f"error: {exc}"))
    return results


def main(argv):
    parser = argparse.ArgumentParser(prog="courier.py")
    parser.add_argument("--config", required=True)
    parser.add_argument("--devices", required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--queue", required=True)
    parser.add_argument("--timeout", type=int, default=15)
    parser.add_argument("--apply", action="store_true", help="really post (default: print the plan)")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    if config is None:
        print("courier: no parent server is configured (off)", file=sys.stderr)
        return 0
    devices = load_devices(args.devices)
    if not devices:
        print("courier: no device is paired; nothing to send")
        return 0
    state = relay.build_state(args.status, args.queue)
    if not args.apply:
        for device in devices:
            print(f"  [dry-run] would seal the state for {device['id']} and POST it to "
                  f"{config['transport']} {config['url']}")
        return 0
    for device_id, status in send(config, state, devices, args.timeout):
        print(f"courier: {device_id}: {status}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
