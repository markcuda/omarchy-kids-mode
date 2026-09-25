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
    ask.py decide PATH --state approved|declined --by panel|keyboard|widget|device [--device ID]
                 [--expect-kid K --expect-kind KIND --expect-what W [--expect-minutes N]]
    ask.py show PATH [--field FIELD]
    ask.py list-open DIR [--kid KID]
    ask.py reopen PATH --kid KID
    ask.py validate --kid K --kind KIND --what WHAT [--minutes N]
    ask.py sync-decisions QUEUE_DIR
    ask.py outcome <kid>/decisions            (the kid's own copy; display only)

Exit 0 on success. Exit 2 for a bad argument or unreadable file, exit 3
for "already decided" (decide only) -- never a Python traceback.
"""
import glob
import fcntl
import grp
import pwd
import json
import os
import re
import stat
import sys
import time

KINDS = ("time", "app", "plugin", "site")
STATES = ("open", "approved", "declined")
BY = ("keyboard", "panel", "widget", "device")
RE_DEVICE_ID = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._-]{0,62}\Z")

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
    # Root reads a record that may have just been moved out of a kid's outbox, so
    # the open is O_NOFOLLOW and the file must be regular: a planted symlink is
    # never followed to another file (the shape lib/devices.py already uses).
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0))
    except FileNotFoundError:
        die(f"no such record: {path}")
    except OSError as e:
        die(f"could not read {path}: {e}")
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            die(f"could not read {path}: not a regular file")
        with os.fdopen(fd, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        die(f"could not read {path}: {e}")


def _parent_gid():
    """The omarchy-parents gid, or None where the group is not set up (the
    caller's own tooling reports that; a mode still lands)."""
    try:
        return grp.getgrnam("omarchy-parents").gr_gid
    except KeyError:
        return None


def write_atomic(path, record):
    """Write RECORD to PATH atomically, with the mode the writer's store wants
    (R-NOTIFY-7): root writes the request queue (0640 root:omarchy-parents, so
    the parent group and the relay's unit read it); anyone else writes their own
    outbox draft (0600, closed by the writer's 0700 directory too). Who writes
    decides, never a path pattern or an argument (AGENTS.md rule 9)."""
    directory = os.path.dirname(path) or "."
    root = os.geteuid() == 0
    os.makedirs(directory, mode=0o750 if root else 0o700, exist_ok=True)
    if root:
        # The queue directory is group-readable on every write, not only at
        # creation: an earlier 0755 is corrected here.
        os.chmod(directory, 0o750)
        gid = _parent_gid()
        if gid is not None:
            try:
                os.chown(directory, 0, gid)
            except OSError:
                pass
    tmp = f"{path}.{os.getpid()}.tmp"
    # O_EXCL|0600: the temp file is closed from the moment it exists, not only after the
    # chmod below (the directory is closed first, but nothing should depend on that).
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(record, f, sort_keys=True)
        f.write("\n")
    os.chmod(tmp, 0o640 if root else 0o600)
    if root:
        gid = _parent_gid()
        if gid is not None:
            try:
                os.chown(tmp, 0, gid)
            except OSError:
                pass
    os.replace(tmp, path)


def _kid_group_gid(kid):
    """The kid account's primary gid, or None (R-NOTIFY-6: their own copies are
    readable by the kid's own group and by no other account). Only root resolves
    and applies ownership, as every ownership check in this package does: a
    non-root test build writes the copy owned by whoever ran it."""
    if os.geteuid() != 0:
        return None
    try:
        return pwd.getpwnam(kid).pw_gid
    except KeyError:
        return None


def _data_root(queue_path):
    """<varlib>/queue/<id>.json -> <varlib>: the kid copies live beside queue/."""
    return os.path.dirname(os.path.dirname(os.path.abspath(queue_path)))


def kid_decision_path(queue_path, kid):
    name = os.path.basename(queue_path)
    if name.endswith(".json"):
        name = name[: -len(".json")]
    return os.path.join(_data_root(queue_path), kid, "decisions", name + ".json")


def _kid_copy(record, name):
    """(copy, reason): the kid's own copy of a decision (R-NOTIFY-6), the queue
    record's own values and nothing else. `by` and `device` stay off it: they
    name where a decision was signed, not who signed it."""
    kid = record.get("kid")
    state = record.get("state")
    if not valid_account(kid) or state not in ("approved", "declined"):
        return None, "not a decision for an account"
    asked = valid_epoch(record.get("asked_at"))
    decided = valid_epoch(record.get("decided_at"))
    if asked is None or decided is None:
        return None, "malformed timestamps"
    copy = {
        "id": name,
        "kid": kid,
        "kind": record.get("kind"),
        "what": record.get("what"),
        "asked_at": asked,
        "state": state,
        "decided_at": decided,
    }
    minutes = record.get("minutes")
    if isinstance(minutes, int) and not isinstance(minutes, bool):
        copy["minutes"] = minutes
    reply = record.get("reply")
    if isinstance(reply, str) and reply:
        copy["reply"] = reply
    return copy, "ok"


def write_kid_copy(queue_path, record):
    """Write the kid's own copy of a decision, (ok, reason). A failure is said
    out loud by the caller and never fails the decision: the queue record is the
    decision of record, and `sync-decisions` heals a missing copy."""
    name = os.path.basename(queue_path)
    if name.endswith(".json"):
        name = name[: -len(".json")]
    copy, reason = _kid_copy(record, name)
    if copy is None:
        return False, reason
    path = kid_decision_path(queue_path, copy["kid"])
    directory = os.path.dirname(path)
    try:
        if os.geteuid() == 0:
            gid = _kid_group_gid(copy["kid"])
            if gid is None:
                return False, f"no account '{copy['kid']}'"
        else:
            gid = None
        os.makedirs(directory, mode=0o750, exist_ok=True)
        os.chmod(directory, 0o750)
        if gid is not None:
            os.chown(directory, 0, gid)
        tmp = f"{path}.{os.getpid()}.tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(copy, f, sort_keys=True)
            f.write("\n")
        os.chmod(tmp, 0o640)
        if gid is not None:
            os.chown(tmp, 0, gid)
        os.replace(tmp, path)
    except OSError as e:
        return False, e.strerror or str(e)
    return True, "ok"


def _read_valid_decision(path, account, name):
    """The copy at PATH if every field is valid for ACCOUNT, else None. Every
    field a kid can read is validated here, at read time (nothing a kid could
    write is trusted)."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            record = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(record, dict):
        return None
    if record.get("kid") != account:
        return None
    if record.get("id") != name or not RE_ID.match(str(record.get("id", ""))):
        return None
    kind = record.get("kind")
    if kind not in KINDS:
        return None
    minutes = record.get("minutes")
    if kind == "time":
        if validate_grant(account, kind, record.get("what", ""), minutes) is not None:
            return None
    elif validate_grant(account, kind, record.get("what", "")) is not None:
        return None
    if record.get("state") not in ("approved", "declined"):
        return None
    if valid_epoch(record.get("asked_at")) is None or valid_epoch(record.get("decided_at")) is None:
        return None
    reply = record.get("reply")
    if reply is not None and (
        not isinstance(reply, str) or len(reply) > MAX_REPLY or any(not c.isprintable() for c in reply)
    ):
        return None
    return record


def cmd_sync_decisions(argv):
    """Write the kid copy of every decided queue record that lacks one
    (R-NOTIFY-6): the heal for a `decide` whose copy failed, run by `collect`.
    A present copy is never rewritten; an open record and an account that no
    longer resolves are skipped."""
    if len(argv) != 1:
        die("sync-decisions: needs QUEUE_DIR")
    queue_dir = argv[0]
    for path in sorted(glob.glob(os.path.join(queue_dir, "*.json"))):
        try:
            with open(path, "r", encoding="utf-8") as f:
                record = json.load(f)
        except (OSError, ValueError):
            continue
        if not isinstance(record, dict) or record.get("state") not in ("approved", "declined"):
            continue
        kid = record.get("kid")
        if not valid_account(kid):
            continue
        if os.path.exists(kid_decision_path(path, kid)):
            continue
        ok, reason = write_kid_copy(path, record)
        if not ok:
            print(
                f"ask.py: could not write the kid's copy of {os.path.basename(path)}: {reason}",
                file=sys.stderr,
            )


def cmd_outcome(argv):
    """The newest decided request in the kid's own directory, one tab-separated
    line, or nothing (R-NOTIFY-6). Display only: it prints what the file says
    and nothing else, and an unreadable or malformed file is skipped."""
    if len(argv) != 1:
        die("outcome: needs DIR")
    directory = argv[0]
    if not os.path.exists(directory):
        return
    account = os.path.basename(os.path.dirname(os.path.abspath(directory)))
    try:
        names = sorted(n for n in os.listdir(directory) if n.endswith(".json"))
    except OSError:
        die("outcome: cannot read your decisions directory", 1)
    for name in reversed(names):
        record = _read_valid_decision(os.path.join(directory, name), account, name[: -len(".json")])
        if record is None:
            continue
        minutes = ""
        if record.get("kind") == "time":
            minutes = str(record["minutes"])
        print(
            "\t".join(
                [
                    str(record.get("kind", "")),
                    str(record.get("what", "")),
                    minutes,
                    str(record.get("state", "")),
                    str(record.get("reply", "")),
                ]
            )
        )
        return


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

    os.makedirs(directory, mode=0o700, exist_ok=True)
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


MAX_REPLY = 80


def cmd_decide(argv):
    opts, rest = parse_kv_args(
        argv, {"state", "by", "device", "reply", "expect_kid", "expect_kind", "expect_what", "expect_minutes"}
    )
    if len(rest) != 1:
        die("decide: needs PATH")
    path = rest[0]
    state = opts.get("state")
    by = opts.get("by")
    device = opts.get("device")
    if state not in ("approved", "declined"):
        die("decide: --state must be 'approved' or 'declined'")
    reply = opts.get("reply")
    if reply is not None and (
        not isinstance(reply, str) or len(reply) > MAX_REPLY or any(not c.isprintable() for c in reply)
    ):
        die("decide: --reply must be up to 80 printable characters")
    if by not in BY:
        die(f"decide: --by must be one of {', '.join(BY)}")
    if by == "device":
        if not isinstance(device, str) or not RE_DEVICE_ID.match(device):
            die("decide: --by device needs --device <id>")
        # A device decision must carry the display binding (amendment section 20):
        # authd always sends it, and requiring it here closes the path that would
        # otherwise let a device decision skip the record check.
        for field in ("kid", "kind", "what"):
            if opts.get("expect_" + field) is None:
                die(f"decide: a device decision needs --expect-{field}")
    else:
        device = None

    # The check-and-set is atomic: an fcntl lock on a sibling file makes a
    # second decision (a double-tap, a re-signed retry) wait, then see the
    # record already decided and refuse -- so the action is never performed
    # twice (R-NOTIFY-4, checklist item 4).
    with open(path + ".lock", "w", encoding="utf-8") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            record = load_record(path)
            if record.get("state") != "open":
                die(f"already decided ({record.get('state')}) -- {path}", code=3)

            # The display binding (amendment section 20): a device decision signs
            # the kid/type/what/minutes it showed; refuse when the record no
            # longer carries them, so a compromised relay cannot apply one
            # request's fields under another's id. A panel/keyboard decision
            # (no --expect-*) is unaffected.
            for field in ("kid", "kind", "what", "minutes"):
                want = opts.get("expect_" + field)
                if want is None:
                    continue
                have = record.get(field)
                got = "" if have is None else str(have)
                if got != str(want):
                    die("decide: the record changed since it was shown", code=2)

            record["state"] = state
            record["decided_at"] = int(time.time())
            record["by"] = by
            if device is not None:
                record["device"] = device
            if reply is not None:
                record["reply"] = reply
            write_atomic(path, record)
            # R-NOTIFY-6: the kid's own copy, after the record that *is* the
            # decision. Best effort: a failure is said out loud and the decision
            # stands; `omarchy-kids-ask collect`'s sync-decisions heals it.
            ok, reason = write_kid_copy(path, record)
            if not ok:
                print(
                    "ask.py: decided; could not write the kid's copy of "
                    f"{os.path.basename(path)}: {reason}",
                    file=sys.stderr,
                )
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)


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
    # US-separated, not tab: `minutes` is an empty field for a non-time
    # request, and bash `read` with a tab IFS collapses the run, shifting
    # `asked_at` into it (every consumer reads this as fields). 0x1f is
    # not IFS whitespace, so an empty field survives; strip it (and CR/LF)
    # from values so a kid-authored `what` cannot forge one.
    for row in rows:
        print("\u001f".join(
            str(v).replace("\u001f", " ").replace("\n", " ").replace("\r", " ")
            for v in row))


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
    "sync-decisions": cmd_sync_decisions,
    "outcome": cmd_outcome,
}


def main(argv):
    if not argv or argv[0] not in COMMANDS:
        die(f"usage: ask.py {{{'|'.join(COMMANDS)}}} ...")
    COMMANDS[argv[0]](argv[1:])


if __name__ == "__main__":
    main(sys.argv[1:])
