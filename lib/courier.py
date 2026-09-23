"""lib/courier.py -- the away courier's transport (N-11, R-NOTIFY-8).

The one process that may open a connection beyond the LAN. It seals the state
document for each paired device (`lib/envelope.py`) and posts it to the server the
parent named -- an ntfy or Gotify topic of their own. Off by default: with no
config it refuses, and with notifications off there is no state to send.

It talks only to the configured URL: https (or http to loopback, for tests), no
redirects followed, and the proxy environment ignored, so a redirected or proxied
request cannot reach a third host. The Gotify token rides an `X-Gotify-Key`
header, never the query string (proxy and access logs keep query strings).

Both directions: send the sealed state out, and carry the app's signed decisions
back to authd. The courier never decides. The courier never decides. Exit status is nonzero if any device's send
failed, so a timer can notice. Stdlib only (+ python-cryptography via envelope.py).
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
TRANSPORTS = ("ntfy", "gotify")
LOOPBACK_HOSTS = ("127.0.0.1", "::1", "localhost")


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


envelope = _load(os.path.join(HERE, "envelope.py"), "kids_envelope")
relay = _load(os.path.join(HERE, "relay.py"), "kids_relay")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """A redirect is not followed: returning None raises HTTPError instead."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _opener():
    # No proxy (root's https_proxy must not reroute this), no redirects.
    return urllib.request.build_opener(urllib.request.ProxyHandler({}), _NoRedirect())


def url_allowed(url):
    """https, or http to loopback only (the tests' local server)."""
    if url.startswith("https://"):
        return True
    if not url.startswith("http://"):
        return False
    try:
        host = urllib.parse.urlsplit(url).hostname or ""
    except ValueError:
        return False
    host = host.strip("[]")
    return host in LOOPBACK_HOSTS


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


def state_digest(state, config, devices):
    """A digest of what a send would carry: the state's meaning (everything but
    generated_at, which every 30-second tick rewrites), the server it would go to,
    and the devices. The courier skips an unchanged digest so an idle box does not
    post a message every five minutes, but a changed config or device still sends.
    """
    clone = dict(state)
    clone.pop("generated_at", None)
    material = {
        "state": clone,
        "transport": config.get("transport"),
        "url": config.get("url"),
        "topic": config.get("topic"),
        "devices": sorted(device["id"] for device in devices),
    }
    return hashlib.sha256(json.dumps(material, separators=(",", ":"), sort_keys=True).encode()).hexdigest()


def read_sent(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def write_sent(path, digest):
    try:
        directory = os.path.dirname(path)
        if directory:
            os.makedirs(directory, mode=0o755, exist_ok=True)
        tmp = f"{path}.{os.getpid()}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(digest + "\n")
        os.replace(tmp, path)
    except OSError as exc:
        # Not fatal, but it means the next run re-sends: say so.
        print(f"courier: could not record the last-sent state: {exc}", file=sys.stderr)


def _get(url, timeout):
    request = urllib.request.Request(url, method="GET")
    try:
        with _opener().open(request, timeout=timeout) as response:  # noqa: S310 -- one configured server
            return response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        print(f"courier: the server answered {exc.code}", file=sys.stderr)
        return ""


def _post(url, body, headers, timeout):
    request = urllib.request.Request(url, data=body, method="POST", headers=headers)
    try:
        with _opener().open(request, timeout=timeout) as response:  # noqa: S310 -- one configured server
            return response.status
    except urllib.error.HTTPError as exc:
        return exc.code


def post_ntfy(base_url, topic, body, timeout=15):
    """ntfy: POST the body to <base>/<topic>."""
    target = base_url.rstrip("/") + "/" + urllib.parse.quote(topic, safe="")
    return _post(target, body, {"Content-Type": "application/json"}, timeout)


def post_gotify(base_url, token, title, body, timeout=15):
    """Gotify: POST /message with the token in a header (not the query string)."""
    target = base_url.rstrip("/") + "/message"
    payload = json.dumps({"title": title, "message": body.decode("utf-8")}).encode("utf-8")
    return _post(target, payload, {"Content-Type": "application/json", "X-Gotify-Key": token}, timeout)


def fetch_ntfy_replies(base_url, topic, since, timeout=15):
    """New messages on an ntfy topic: [{id, message}]. `since` is the last id seen."""
    target = base_url.rstrip("/") + "/" + urllib.parse.quote(topic, safe="") + "/json?poll=1"
    if since:
        target += "&since=" + urllib.parse.quote(str(since), safe="")
    out = []
    for line in _get(target, timeout).splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if isinstance(message, dict) and isinstance(message.get("message"), str):
            out.append({"id": message.get("id"), "time": message.get("time"), "message": message["message"]})
    return out


def read_cursor(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip() or None
    except OSError:
        return None


def write_cursor(path, value):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, mode=0o755, exist_ok=True)
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(str(value) + "\n")
    os.replace(tmp, path)


def poll(config, auth_sock, cursor_path, apply, timeout=15):
    """Fetch new replies and carry each signed decision to authd (R-NOTIFY-4/8).

    Replies come from an ntfy topic (Gotify's GET needs a client token we do not
    hold, so it is not supported). The app posts a signed decision frame; the
    courier only carries it -- authd verifies and applies. A message that is not a
    decision frame is skipped. The cursor is the newest message time, advanced only
    when every carried frame got a definite answer from authd, so a decision that
    arrived while authd was down is retried rather than lost. Returns
    [(id, authd_reply_or_None), ...].
    """
    if config.get("transport") != "ntfy":
        raise ValueError("replies are only fetched from ntfy")
    url = config.get("url", "")
    if not url_allowed(url):
        raise ValueError("the configured server must be https (or loopback for tests)")
    since = read_cursor(cursor_path)
    replies = fetch_ntfy_replies(url, config.get("reply_topic", ""), since, timeout)
    frames = []
    for reply in replies:
        try:
            frame = json.loads(reply["message"])
        except ValueError:
            continue
        if isinstance(frame, dict) and "record" in frame:
            frames.append(reply)
    if not apply:
        for _ in frames:
            print("  [dry-run] would carry one signed decision to authd")
        return [(reply.get("id"), None) for reply in frames]
    forwarded = []
    definite = True
    for reply in frames:
        answer = relay.forward_decide(auth_sock, reply["message"])
        forwarded.append((reply.get("id"), answer))
        if answer is None:
            definite = False
    # Advance to the newest time only when nothing was left half-done; a retry of
    # a carried frame is refused by authd's nonce ledger, so this never loses one.
    if frames and definite:
        times = [reply["time"] for reply in frames if isinstance(reply.get("time"), int)]
        if times:
            write_cursor(cursor_path, max(times))
    elif not frames and replies:
        times = [reply["time"] for reply in replies if isinstance(reply.get("time"), int)]
        if times:
            write_cursor(cursor_path, max(times))
    return forwarded


def send(config, state, devices, timeout=15):
    """Seal `state` for each device and post it. Best effort per device.

    Returns [(device_id, status_or_error), ...]; the caller reports them and
    decides its exit status.
    """
    transport = config.get("transport")
    if transport not in TRANSPORTS:
        raise ValueError(f"unknown transport {transport!r}")
    url = config.get("url", "")
    if not url_allowed(url):
        raise ValueError("the configured server must be https (or loopback for tests)")
    plaintext = json.dumps(state, separators=(",", ":"), sort_keys=True).encode("utf-8")
    results = []
    for device in devices:
        try:
            sealed = envelope.seal(device["id"], device["box_pub"], plaintext)
            body = json.dumps(sealed, separators=(",", ":")).encode("utf-8")
            if transport == "ntfy":
                status = post_ntfy(url, config.get("topic", "omarchy-kids"), body, timeout)
            else:
                status = post_gotify(url, config.get("token", ""), "omarchy-kids", body, timeout)
            results.append((device["id"], status))
        except Exception as exc:  # noqa: BLE001 -- one device's failure is not the others'
            results.append((device["id"], f"error: {exc}"))
    return results


def _failed(result):
    return isinstance(result[1], str) or not (200 <= result[1] < 300)


def main(argv):
    parser = argparse.ArgumentParser(prog="courier.py")
    parser.add_argument("--config", required=True)
    parser.add_argument("--devices", default="")
    parser.add_argument("--status", default="")
    parser.add_argument("--queue", default="")
    parser.add_argument("--sent", default="")
    parser.add_argument("--poll", action="store_true", help="carry replies to authd instead of sending")
    parser.add_argument("--auth-sock", default="/run/omarchy-kids/auth.sock")
    parser.add_argument("--cursor", default="")
    parser.add_argument("--timeout", type=int, default=15)
    parser.add_argument("--apply", action="store_true", help="really post (default: print the plan)")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    if config is None:
        print("courier: no parent server is configured (off)")
        return 0
    if args.poll:
        if not url_allowed(config.get("url", "")):
            print("courier: the configured server must be https; refusing", file=sys.stderr)
            return 2
        if config.get("transport") == "ntfy" and not config.get("reply_topic"):
            print("courier: no reply topic is configured; nothing to poll")
            return 0
        if not args.apply:
            print("  [dry-run] would fetch replies and carry any signed decision to authd")
            return 0
        forwarded = poll(config, args.auth_sock, args.cursor, True, args.timeout)
        for reply_id, reply in forwarded:
            print(f"courier: reply {reply_id}: {reply}")
        return 0
    if not (args.devices and args.status and args.queue):
        print("courier: --devices, --status and --queue are required to send", file=sys.stderr)
        return 2
    devices = load_devices(args.devices)
    if not devices:
        print("courier: no device is paired; nothing to send")
        return 0
    if not url_allowed(config.get("url", "")):
        print("courier: the configured server must be https; refusing", file=sys.stderr)
        return 2
    state = relay.build_state(args.status, args.queue)
    if not args.apply:
        for device in devices:
            print(
                f"  [dry-run] would seal the state for {device['id']} and POST it to "
                f"{config['transport']} {config['url']}"
            )
        return 0
    digest = state_digest(state, config, devices)
    if args.sent and read_sent(args.sent) == digest:
        print("courier: the state has not changed; nothing sent")
        return 0
    results = send(config, state, devices, args.timeout)
    for device_id, status in results:
        print(f"courier: {device_id}: {status}")
    failed = any(_failed(result) for result in results)
    if not failed and args.sent:
        write_sent(args.sent, digest)
    return 1 if failed else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
