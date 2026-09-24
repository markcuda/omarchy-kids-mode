"""lib/notify_watch.py -- the parent's desktop notifier (N-9, N-12, R-NOTIFY).

The user-side half of the on-box path: it polls the ask queue and the open
add-on reviews, and posts one libnotify notification per item it has not already
shown, with Approve and Decline (or Deny) actions. Choosing an action runs
`omarchy-kids-bar ...`, which opens the parent's own floating terminal and sudo
prompt (N-9 part 1); this watcher never decides anything itself and holds no
privilege.

A request is approved or declined; an add-on review (R-NOTIFY-12, when an
approved app's surface or exec changed) is approved or denied. Action buttons
come from `org.freedesktop.Notifications` over the session bus (`gdbus`): a
single background monitor watches for `ActionInvoked`, and the notification id
we sent tells us which item the parent answered -- never a blocking wait, and
never another app's notification. Where the session bus is unavailable the
fallback is a plain `notify-send` with no buttons and a body that points at the
panel.

Not an enforcement path: stopped, or notifications off, a kid is affected in no
way. Stdlib only. CLI and `--once` (used by the tests) live at the bottom.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time

APP_NAME = "omarchy-kids"
RE_ID = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._+@-]{0,127}\Z")
KINDS = ("time", "app", "plugin", "site")
ACTION_INVOKED = re.compile(r"ActionInvoked \(uint32 (\d+), '([^']*)'\)")
NOTIFICATION_CLOSED = re.compile(r"NotificationClosed \(uint32 (\d+), uint32 \d+\)")
# --once is a test/debug mode: give the action signal a moment to arrive.
ONCE_GRACE = 1.0
REQUEST_ACTIONS = [("approve", "Approve"), ("decline", "Decline")]
REVIEW_ACTIONS = [("approve", "Approve"), ("deny", "Deny"), ("check", "Check")]


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
    """A request's title and body, in plain words a parent reads."""
    kid = row["kid"] or "Your kid"
    if row["kind"] == "time" and row["minutes"]:
        return f"{kid} wants more time", f"{kid} asked for {row['minutes']} more minutes."
    what = row["what"] or row["kind"]
    return f"{kid} asked to use {what}", f"{kid} asked for {what}."


def read_reviews(reviews_dir):
    """Every open add-on review: {kid, id, now} (R-NOTIFY-12)."""
    rows = []
    try:
        names = sorted(os.listdir(reviews_dir))
    except OSError:
        return rows
    for name in names:
        if name.startswith(".") or not name.endswith(".json"):
            continue
        try:
            with open(os.path.join(reviews_dir, name), "r", encoding="utf-8") as f:
                record = json.load(f)
        except (OSError, ValueError):
            continue
        if not isinstance(record, dict) or record.get("state") != "open":
            continue
        kid, app_id = record.get("kid"), record.get("id")
        if not isinstance(kid, str) or not isinstance(app_id, str):
            continue
        rows.append({"kid": _clean(kid, 32), "id": _clean(app_id, 64), "now": _clean(record.get("now"), 64)})
    return rows


def request_item(row):
    title, body = summary_body(row)
    return {
        "key": "req:" + row["id"],
        "title": title,
        "body": body,
        "actions": REQUEST_ACTIONS,
        "callbacks": {
            "approve": ["approve", row["id"]],
            "decline": ["decline", row["id"]],
        },
    }


def review_item(row):
    gone = row["now"] == "missing"
    state = "was removed" if gone else "changed since you approved it"
    return {
        "key": f"rev:{row['kid']}:{row['id']}",
        "title": f"{row['kid']}'s {row['id']} {state}",
        "body": f"The app {state}. Approve to keep it, deny to hide it.",
        "actions": REVIEW_ACTIONS,
        "callbacks": {
            "approve": ["review-approve", row["kid"], row["id"]],
            "deny": ["review-deny", row["kid"], row["id"]],
            "check": ["review-check", row["kid"], row["id"]],
        },
    }


# --- state: which keys have already been shown, so a poll does not spam ------


def load_state(path):
    """The keys already shown; any read failure is treated as an empty state."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return set()
    if isinstance(data, list):
        return {i for i in data if isinstance(i, str)}
    return set()


def save_state(path, ids):
    """Best-effort: a failed write must never kill the watcher."""
    directory = os.path.dirname(path)
    try:
        if directory:
            os.makedirs(directory, mode=0o700, exist_ok=True)
        tmp = f"{path}.{os.getpid()}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(sorted(ids), f)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except (OSError, UnboundLocalError):
            pass


# --- gdbus: notify with actions, and one background monitor for the answers --


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


def notify_send(title, body):
    """The fallback: no buttons. libnotify's notify-send takes SUMMARY [BODY]."""
    if shutil.which("notify-send") is None:
        return False
    text = f"{body} Open the Kids Mode panel to answer."
    try:
        out = subprocess.run(["notify-send", title, text], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return False
    return out.returncode == 0


def run_callback(bar_bin, argv):
    """Hand the decision to the bar command, which opens the parent's terminal."""
    try:
        subprocess.run([bar_bin] + list(argv), check=False)
    except OSError:
        pass


class GdbusNotifier:
    """Sends notifications with buttons and answers them from one monitor.

    The monitor runs for the watcher's lifetime in a background thread, so a
    notification never blocks the poll loop and a click is honoured as soon as
    the daemon reports it. Only ids this watcher sent are acted on.
    """

    def __init__(self, bar_bin):
        self.bar_bin = bar_bin
        self.pending = {}  # notification id -> the item shown
        self.lock = threading.Lock()

    def start(self):
        threading.Thread(target=self._monitor_loop, daemon=True).start()

    def _monitor_loop(self):
        while True:
            try:
                proc = subprocess.Popen(
                    ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.Notifications"],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
                )
            except OSError:
                return
            if proc.stdout is not None:
                for line in proc.stdout:
                    closed = NOTIFICATION_CLOSED.search(line)
                    if closed:
                        # Dismissed without an answer: forget its id.
                        with self.lock:
                            self.pending.pop(int(closed.group(1)), None)
                        continue
                    match = ACTION_INVOKED.search(line)
                    if not match:
                        continue
                    notification_id = int(match.group(1))
                    action = match.group(2)
                    with self.lock:
                        item = self.pending.pop(notification_id, None)
                    argv = item["callbacks"].get(action) if item else None
                    if argv:
                        run_callback(self.bar_bin, argv)
                    # A Check decides nothing, so post it again: the parent can
                    # still approve or deny after looking, whatever the daemon
                    # did with the notification.
                    if item and action == "check":
                        self.send(item)
            proc.wait()
            time.sleep(1)  # a monitor that exits at once must not spin us

    def send(self, item):
        """Show one item; True when the session bus took it.

        The lock is held across the notify call and the id record, so the
        monitor can never see the action before we know which item it is.
        """
        with self.lock:
            notification_id = gdbus_notify(item["title"], item["body"], item["actions"])
            if notification_id is None:
                return False
            self.pending[notification_id] = item
        return True


# --- the loop ---------------------------------------------------------------


def items(queue_dir, reviews_dir):
    """Every item to show: open requests first, then open reviews."""
    result = [request_item(row) for row in read_open(queue_dir)]
    if reviews_dir:
        result += [review_item(row) for row in read_reviews(reviews_dir)]
    return result


def watch(queue_dir, reviews_dir, state_path, bar_bin, interval, once, use_gdbus=True):
    notified = load_state(state_path)
    notifier = None
    if use_gdbus and shutil.which("gdbus") is not None:
        notifier = GdbusNotifier(bar_bin)
        notifier.start()
    while True:
        current = items(queue_dir, reviews_dir)
        keys = {item["key"] for item in current}
        notified &= keys  # forget what has been decided, withdrawn or denied
        for item in current:
            if item["key"] in notified:
                continue
            shown = notifier is not None and notifier.send(item)
            if not shown:
                shown = notify_send(item["title"], item["body"])
            # Remember it only once something showed it: at login the daemon may
            # not be up yet, and marking a failed send would lose the item.
            if shown:
                notified.add(item["key"])
        save_state(state_path, notified)
        if once:
            time.sleep(ONCE_GRACE)  # let a stubbed or real action signal arrive
            return 0
        time.sleep(interval)


def main(argv):
    parser = argparse.ArgumentParser(prog="notify_watch.py")
    parser.add_argument("--queue", required=True)
    parser.add_argument("--reviews", default="")
    parser.add_argument("--state", required=True)
    parser.add_argument("--bar", required=True)
    parser.add_argument("--interval", type=int, default=15)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--no-actions", action="store_true", help="force the notify-send fallback")
    args = parser.parse_args(argv)
    return watch(
        args.queue, args.reviews, args.state, args.bar, args.interval, args.once, not args.no_actions
    )


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
