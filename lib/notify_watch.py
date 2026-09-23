"""lib/notify_watch.py -- the parent's desktop notifier (N-9, R-NOTIFY).

The user-side half of the on-box path: it polls the ask queue -- which the
parent's `omarchy-parents` group can read -- and posts one libnotify
notification per open request it has not already shown, with Approve and
Decline actions. Choosing an action runs `omarchy-kids-bar approve|decline
<id>`, which opens the parent's own floating terminal and sudo prompt (N-9 part
1); this watcher never decides anything itself and holds no privilege.

`gdbus` (org.freedesktop.Notifications) carries the action buttons; where that
is unavailable the fallback is a plain `notify-send` with no buttons, and the
body says to use the panel. It is not an enforcement path: stopped or
notifications off, a kid is affected in no way.

Stdlib only. CLI and `--once` (used by the tests) live at the bottom.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

APP_NAME = "omarchy-kids"
RE_ID = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._+@-]{0,127}\Z")
KINDS = ("time", "app", "plugin", "site")
# A notification the parent never answers must not stall the poll loop.
ACTION_WINDOW = 30


def _clean(value, limit=120):
    """A queue value is kid-written; strip control characters and cap length."""
    text = str(value if value is not None else "")
    text = "".join(ch for ch in text if ch.isprintable())
    return text[:limit]


def read_open(queue_dir):
    """Every open request, oldest first: {id, kid, kind, what, minutes, asked_at}."""
    rows = []
    try:
        names = sorted(os.listdir(queue_dir))
    except OSError:
        return rows
    for name in names:
        if name.startswith(".") or not name.endswith(".json"):
            continue
        record_id = name[: -len(".json")]
        if not RE_ID.match(record_id):
            continue
        try:
            with open(os.path.join(queue_dir, name), "r", encoding="utf-8") as f:
                record = json.load(f)
        except (OSError, ValueError):
            continue
        if not isinstance(record, dict) or record.get("state") != "open":
            continue
        kid, kind, what = record.get("kid"), record.get("kind"), record.get("what")
        if not isinstance(kid, str) or not isinstance(kind, str) or kind not in KINDS:
            continue
        minutes = record.get("minutes")
        rows.append(
            {
                "id": record_id,
                "kid": _clean(kid, 32),
                "kind": kind,
                "what": _clean(what),
                "minutes": minutes if isinstance(minutes, int) and not isinstance(minutes, bool) else None,
                "asked_at": record.get("asked_at"),
            }
        )
    rows.sort(key=lambda r: r["asked_at"] if isinstance(r["asked_at"], int) else 0)
    return rows


def summary_body(row):
    """The notification's title and body, in plain words a parent reads."""
    kid = row["kid"] or "Your kid"
    if row["kind"] == "time" and row["minutes"]:
        return f"{kid} wants more time", f"{kid} asked for {row['minutes']} more minutes."
    what = row["what"] or row["kind"]
    return f"{kid} asked to use {what}", f"{kid} asked for {what}. Approve or decline."


# --- state: which ids have already been shown, so a poll does not spam -------


def load_state(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return set()
    if isinstance(data, list):
        return {i for i in data if isinstance(i, str)}
    return set()


def save_state(path, ids):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, mode=0o700, exist_ok=True)
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(sorted(ids), f)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


# --- the two notifiers ------------------------------------------------------


def _actions_variant(actions):
    return "[" + ", ".join("'%s', '%s'" % (a, l) for a, l in actions) + "]"


def gdbus_notify(title, body, actions):
    """Send through org.freedesktop.Notifications; return the notification id or None."""
    if shutil.which("gdbus") is None:
        return None
    cmd = [
        "gdbus", "call", "--session",
        "--dest", "org.freedesktop.Notifications",
        "--object-path", "/org/freedesktop/Notifications",
        "--method", "org.freedesktop.Notifications.Notify",
        APP_NAME, "0", "", title, body, _actions_variant(actions), "{}", "-1",
    ]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    match = re.search(r"uint32 (\d+)", out.stdout)
    return int(match.group(1)) if match else None


def gdbus_wait_action(notification_id, seconds=ACTION_WINDOW):
    """The action the parent chose, or None. Bounded by `seconds`."""
    try:
        out = subprocess.run(
            ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.Notifications"],
            capture_output=True, text=True, timeout=seconds,
        )
        text = out.stdout
    except subprocess.TimeoutExpired as exc:
        text = exc.stdout or ""
        if isinstance(text, bytes):
            text = text.decode("utf-8", "replace")
    except (OSError, subprocess.SubprocessError):
        return None
    match = re.search(r"ActionInvoked \(uint32 (\d+), '([^']*)'\)", text)
    if match and int(match.group(1)) == notification_id:
        return match.group(2)
    return None


def notify_send(title, body):
    """The fallback: no buttons. Returns no id (never blocks for an action)."""
    if shutil.which("notify-send") is None:
        return None
    try:
        subprocess.run(["notify-send", APP_NAME, body, title], capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def notify(row, bar_bin, use_gdbus=True):
    """Show one request and, where supported, wait for and run the chosen action."""
    title, body = summary_body(row)
    if use_gdbus:
        notification_id = gdbus_notify(title, body, [("approve", "Approve"), ("decline", "Decline")])
        if notification_id is not None:
            action = gdbus_wait_action(notification_id)
            if action in ("approve", "decline"):
                run_action(bar_bin, action, row["id"])
            return action
    notify_send(title, body)
    return None


def run_action(bar_bin, action, request_id):
    """Hand the decision to the bar command, which opens the parent's terminal."""
    try:
        subprocess.run([bar_bin, action, request_id], check=False)
    except OSError:
        pass


# --- the loop ---------------------------------------------------------------


def watch(queue_dir, state_path, bar_bin, interval, once, use_gdbus=True):
    notified = load_state(state_path)
    while True:
        rows = read_open(queue_dir)
        current = {row["id"] for row in rows}
        notified &= current  # forget what has been decided or withdrawn
        for row in rows:
            if row["id"] in notified:
                continue
            notify(row, bar_bin, use_gdbus)
            notified.add(row["id"])
        save_state(state_path, notified)
        if once:
            return 0
        time.sleep(interval)


def main(argv):
    parser = argparse.ArgumentParser(prog="notify_watch.py")
    parser.add_argument("--queue", required=True)
    parser.add_argument("--state", required=True)
    parser.add_argument("--bar", required=True)
    parser.add_argument("--interval", type=int, default=15)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--no-actions", action="store_true", help="force the notify-send fallback")
    args = parser.parse_args(argv)
    return watch(args.queue, args.state, args.bar, args.interval, args.once, not args.no_actions)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
