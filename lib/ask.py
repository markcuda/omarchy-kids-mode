#!/usr/bin/env python3
"""lib/ask.py -- the one place omarchy-kids-ask needs JSON (SPEC.md
R-ASK-1..3, Appendix D).

Reads and writes one queue record per request:

    { "kid": account, "kind": "time|app|plugin|site", "what": string,
      "minutes": int?, "asked_at": ts, "state": "open|approved|declined",
      "decided_at": ts?, "by": "keyboard|panel|widget" }

"Approvers append, never rewrite history" (Appendix D) is read here as:
a record's state moves from "open" to "approved"/"declined" exactly
once. `decide` refuses (exit 3) if the record is already decided --
nothing here ever flips a decision back, and nothing here ever edits
`kid`/`kind`/`what`/`minutes`/`asked_at` after they're first written.

Nothing a kid writes is ever trusted: `write` only ever produces an
`open` record, and every field a kid can influence goes through
`validate_grant` below -- a strict allowlist (no slashes, no leading
dot, bounded lengths) that is the ONE home for these rules. Both root
callers use it: bin/omarchy-kids-authd's GRANT handler (imported) and
bin/omarchy-kids-ask's `collect`/`apply-grant` (via `ask.py validate`).

Usage:
    ask.py write DIR --kid K --kind KIND --what WHAT [--minutes N]
    ask.py decide PATH --state approved|declined --by panel|keyboard|widget
    ask.py show PATH [--field FIELD]
    ask.py list-open DIR [--kid KID]
    ask.py reopen PATH --kid KID
    ask.py validate --kid K --kind KIND --what WHAT [--minutes N]

Exit 0 on success. Exit 2 for a bad argument or unreadable file, exit 3
for "already decided" (decide only) -- never a Python traceback.
"""
import glob
import json
import os
import re
import sys
import time

KINDS = ("time", "app", "plugin", "site")
STATES = ("open", "approved", "declined")
BY = ("keyboard", "panel", "widget")

# --- the strict allowlist (the one home; see the module docstring) ---------
#
# Every one of these is anchored, bounded, and rejects a leading dot and
# any slash outright, so no value reaching root can ever be a path
# fragment ("../../../../etc/sudoers.d") or a hidden file.
MAX_MINUTES = 1440  # one day; a grant is "more screen time", not a new policy

RE_ACCOUNT = re.compile(r"\A[a-z_][a-z0-9_-]{0,31}\Z")
RE_ID = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._+@-]{0,127}\Z")
RE_HOST = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9.-]{0,253}\Z")


def valid_epoch(value):
    """VALUE as an int Unix timestamp, or None. Every field a kid's own
    outbox can set is validated here at read time, not just the four
    validate_grant already covered: `asked_at` reaches bash arithmetic in
    the parent's panel, where an unvalidated string is an *expression*
    (review §2.4). Bounded as well as typed -- a 20-digit number is not a
    timestamp, and "0001-01-01" is not either."""
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        return None
    try:
        n = int(value)
    except (TypeError, ValueError):
        return None
    # 2001-09-09 .. 2286-11-20: any real request stamp, nothing wilder.
    if n < 1000000000 or n > 9999999999:
        return None
    return n


def valid_account(name) -> bool:
    """A Unix account name we are willing to hand to root as a path
    component. Deliberately narrower than useradd's own rules."""
    return isinstance(name, str) and bool(RE_ACCOUNT.match(name))


def validate_grant(kid, kind, what, minutes=None):
    """None if this request is safe to apply as root, else a one-line
    reason. Shared by authd's GRANT handler and omarchy-kids-ask."""
    if not valid_account(kid):
        return f"bad kid name {kid!r}"
    if kind not in KINDS:
        return f"bad kind {kind!r}"
    if not isinstance(what, str) or not what:
        return "missing what"
    if ".." in what or "/" in what or what.startswith("."):
        return f"bad what {what!r}"
    if kind == "time":
        if minutes is None:
            return "time request without minutes"
        try:
            n = int(minutes)
        except (TypeError, ValueError):
            return f"minutes {minutes!r} is not a number"
        if n < 1 or n > MAX_MINUTES:
            return f"minutes {n} out of range (1..{MAX_MINUTES})"
        if what != str(n):
            return "time request whose 'what' does not match 'minutes'"
        return None
    if kind in ("app", "plugin"):
        return None if RE_ID.match(what) else f"bad {kind} id {what!r}"
    if kind == "site":
        return None if RE_HOST.match(what) else f"bad host {what!r}"
    return f"bad kind {kind!r}"


def die(msg, code=2):
    print(f"ask.py: {msg}", file=sys.stderr)
    sys.exit(code)


def load_record(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        die(f"no such record: {path}")
    except (OSError, json.JSONDecodeError) as e:
        die(f"could not read {path}: {e}")


def write_atomic(path, record):
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, mode=0o750, exist_ok=True)
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(record, f, sort_keys=True)
        f.write("\n")
    # 0640, not 0644: the queue is the parent's (R-NOTIFY-7); the kid's own
    # outbox directory is 0700 and the kid never reads records back.
    os.chmod(tmp, 0o640)
    os.replace(tmp, path)


def parse_kv_args(argv, flags):
    """Pulls --flag value pairs out of argv (any order); returns (dict,
    leftover positional args). `flags` is the set of recognized --names
    (without the leading --)."""
    out = {}
    rest = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a.startswith("--"):
            name = a[2:]
            if name not in flags:
                die(f"unknown option --{name}")
            if i + 1 >= len(argv):
                die(f"--{name} needs a value")
            out[name] = argv[i + 1]
            i += 2
        else:
            rest.append(a)
            i += 1
    return out, rest


def cmd_write(argv):
    # No --state and no --by: a kid-side write is a *claim*, never a
    # decision (review S1). Only root decides, through cmd_decide.
    opts, rest = parse_kv_args(argv, {"kid", "kind", "what", "minutes"})
    if len(rest) != 1:
        die("write: needs DIR")
    directory = rest[0]

    kid = opts.get("kid") or die("write: --kid is required")
    kind = opts.get("kind") or die("write: --kind is required")
    what = opts.get("what")
    if what is None:
        die("write: --what is required")

    if kind not in KINDS:
        die(f"write: unknown kind '{kind}' (must be one of {', '.join(KINDS)})")

    now = int(time.time())
    record = {
        "kid": kid,
        "kind": kind,
        "what": what,
        "asked_at": now,
        "state": "open",
    }
    if "minutes" in opts:
        try:
            record["minutes"] = int(opts["minutes"])
        except ValueError:
            die("write: --minutes must be an integer")

    os.makedirs(directory, mode=0o755, exist_ok=True)
    # <unix-ts>-<account>-<kind>.json (Appendix D); a counter suffix
    # keeps two requests in the same second from colliding.
    base = f"{now}-{kid}-{kind}"
    path = os.path.join(directory, f"{base}.json")
    n = 1
    while os.path.exists(path):
        n += 1
        path = os.path.join(directory, f"{base}-{n}.json")
    write_atomic(path, record)
    print(os.path.basename(path))


def cmd_decide(argv):
    opts, rest = parse_kv_args(argv, {"state", "by"})
    if len(rest) != 1:
        die("decide: needs PATH")
    path = rest[0]
    state = opts.get("state")
    by = opts.get("by")
    if state not in ("approved", "declined"):
        die("decide: --state must be 'approved' or 'declined'")
    if by not in BY:
        die(f"decide: --by must be one of {', '.join(BY)}")

    record = load_record(path)
    if record.get("state") != "open":
        die(f"already decided ({record.get('state')}) -- {path}", code=3)

    record["state"] = state
    record["decided_at"] = int(time.time())
    record["by"] = by
    write_atomic(path, record)


def cmd_show(argv):
    opts, rest = parse_kv_args(argv, {"field"})
    if len(rest) != 1:
        die("show: needs PATH")
    record = load_record(rest[0])
    field = opts.get("field")
    if field is None:
        json.dump(record, sys.stdout, sort_keys=True)
        print()
        return
    value = record.get(field, "")
    print("" if value is None else value)


def cmd_list_open(argv):
    opts, rest = parse_kv_args(argv, {"kid"})
    if len(rest) != 1:
        die("list-open: needs DIR")
    directory = rest[0]
    want_kid = opts.get("kid")

    rows = []
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        try:
            with open(path, "r", encoding="utf-8") as f:
                record = json.load(f)
        except (OSError, json.JSONDecodeError):
            continue  # a malformed record is skipped, not a crash
        if record.get("state") != "open":
            continue
        if want_kid and record.get("kid") != want_kid:
            continue
        # The queue is root-owned, but every value in it started as a
        # line a kid wrote, and this row is rendered by the parent's
        # panel -- so it is re-validated on the way out, not just on the
        # way in (review §2.4).
        kid = record.get("kid")
        kind = record.get("kind")
        what = record.get("what")
        minutes = record.get("minutes")
        if validate_grant(kid, kind, what, minutes) is not None:
            continue
        asked_at = valid_epoch(record.get("asked_at"))
        if asked_at is None:
            continue
        record_id = os.path.basename(path)[: -len(".json")]
        if not RE_ID.match(record_id):
            continue
        rows.append(
            (
                record_id,
                kid,
                kind,
                what,
                int(minutes) if kind == "time" else "",
                asked_at,
            )
        )
    for row in rows:
        print("\t".join(str(v) for v in row))


def cmd_reopen(argv):
    """Force a collected record back to a plain open request owned by KID.

    This is what makes `omarchy-kids-ask collect` unable to be tricked:
    whatever a kid wrote into their own outbox, the record that lands in
    the root-owned queue is `open`, undecided, and attributed to the
    account that actually owned the outbox (review S1/S2)."""
    opts, rest = parse_kv_args(argv, {"kid"})
    if len(rest) != 1:
        die("reopen: needs PATH")
    path = rest[0]
    kid = opts.get("kid")
    if not valid_account(kid):
        die(f"reopen: bad --kid {kid!r}")

    record = load_record(path)
    kind = record.get("kind")
    if kind not in KINDS:
        die(f"reopen: record has an unusable kind {kind!r}")
    what = record.get("what")
    minutes = record.get("minutes")
    reason = validate_grant(kid, kind, what, minutes)
    if reason is not None:
        die(f"reopen: {reason}")

    clean = {
        "kid": kid,
        "kind": kind,
        "what": what,
        # Never the kid's own string: a validated int, or this instant.
        "asked_at": valid_epoch(record.get("asked_at")) or int(time.time()),
        "state": "open",
    }
    if kind == "time":
        clean["minutes"] = int(minutes)
    write_atomic(path, clean)


def cmd_request_json(argv):
    """One validated request as a single JSON line, for the GRANT wire
    form. Validating here too means a malformed request never even
    leaves the kid's session."""
    opts, rest = parse_kv_args(argv, {"kid", "kind", "what", "minutes"})
    if rest:
        die(f"request-json: unexpected argument '{rest[0]}'")
    kid, kind = opts.get("kid"), opts.get("kind")
    what, minutes = opts.get("what"), opts.get("minutes")
    reason = validate_grant(kid, kind, what, minutes)
    if reason is not None:
        die(f"request-json: {reason}")
    request = {"kid": kid, "kind": kind, "what": what}
    if kind == "time":
        request["minutes"] = int(minutes)
    print(json.dumps(request, sort_keys=True, separators=(",", ":")))


def cmd_validate(argv):
    """Exit 0 if the request is safe for root to apply, else 2 with the
    reason on stderr. The shell side of the one allowlist."""
    opts, rest = parse_kv_args(argv, {"kid", "kind", "what", "minutes"})
    if rest:
        die(f"validate: unexpected argument '{rest[0]}'")
    reason = validate_grant(
        opts.get("kid"), opts.get("kind"), opts.get("what"), opts.get("minutes")
    )
    if reason is not None:
        die(f"validate: {reason}")


COMMANDS = {
    "write": cmd_write,
    "reopen": cmd_reopen,
    "request-json": cmd_request_json,
    "validate": cmd_validate,
    "decide": cmd_decide,
    "show": cmd_show,
    "list-open": cmd_list_open,
}


def main(argv):
    if not argv or argv[0] not in COMMANDS:
        die(f"usage: ask.py {{{'|'.join(COMMANDS)}}} ...")
    COMMANDS[argv[0]](argv[1:])


if __name__ == "__main__":
    main(sys.argv[1:])
