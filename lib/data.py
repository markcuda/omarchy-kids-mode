#!/usr/bin/env python3
"""lib/data.py -- the one place recorded data (SPEC.md R-DATA-1..5,
issue #27) needs real Python: SQLite (a kid's Chromium browsing
history) and date math (retention cutoffs, "--since N days"), same
reasoning as lib/time.py's header for why day-rollover math lives here
instead of bash's `date`.

Every timestamp bin/omarchy-kids-data itself writes or filters is a
naive local "YYYY-MM-DDTHH:MM:SS" or "YYYY-MM-DD HH:MM:SS" string --
this system has no notion of timezone anywhere (lib/time.sh's own
header says the same thing about budget/lights-out), so cutoffs here
are plain calendar/clock subtraction, compared as strings wherever
possible (an ISO-shaped string without a zone sorts the same as it
reads, exactly like usage/<day> filenames already do) rather than
converted through a real epoch. The one place that's unavoidable is
Chromium's own History db, which stores an absolute instant (WebKit
epoch, microseconds since 1601-01-01) -- that's converted to *local*
wall-clock time (via the host's own zone, whatever it is) once, on the
way out, so every comparison downstream of this file is back to plain
naive-string comparison.

Usage:
    data.py since-cutoff DAYS "YYYY-MM-DD HH:MM:SS"
        Prints "YYYY-MM-DDTHH:MM:SS": NOW minus DAYS days, naive local.
        Used for launches.log filtering ("--since N") and retention.

    data.py since-epoch DAYS "YYYY-MM-DD HH:MM:SS"
        Prints an integer: NOW minus DAYS days, as a real Unix epoch
        (the host's own zone). Only the ask-queue's own "asked_at"
        (lib/ask.py, real `time.time()`) is stamped in real epoch, so
        only its retention pruning needs this instead of since-cutoff.

    data.py fold-launches SRC DEST UID SAVED_INODE SAVED_OFFSET
        Appends whatever is new in the kid-owned runtime log SRC onto the
        root-owned DEST and prints "INODE SIZE". SRC is opened
        O_NOFOLLOW and must be a regular file owned by UID.

    data.py filter-log FILE CUTOFF
        Prints every line of FILE (one "TIMESTAMP REST..." line, same
        shape as launches.log) whose first field is a timestamp >=
        CUTOFF (plain string compare). A line whose first field isn't a
        parseable "YYYY-MM-DDTHH:MM:SS" timestamp is dropped, not kept
        forever by accident. Missing FILE prints nothing (exit 0, not
        an error -- "no data yet" is not a failure).

    data.py chromium-visits DB [--since CUTOFF] [--limit N]
        Reads DB's `urls` table (url, title, last_visit_time,
        visit_count) and prints one US-separated (ASCII 0x1f) line per
        row, most recent first: LOCAL_TIME, host, title, visit_count.
        Not tab-separated: a page title can be empty, and bash `read`
        with a tab IFS collapses the empty field, shifting visit_count
        into title. --since (a "YYYY-MM-DDTHH:MM:SS" cutoff, same shape
        as since-cutoff's output) drops rows visited before it. --limit
        caps the row count (default: no cap).

    data.py chromium-top-sites DB [--since CUTOFF] [--limit N]
        Same source, grouped by host: host, total_visits, LOCAL_TIME
        (that host's most recent visit), US-separated like the above and
        sorted by total_visits desc then recency desc. --limit defaults
        to 5 (a "top sites" list, not the full history).

Exit 0 on success. Exit 2 with a one-line reason on stderr for a bad
argument or an unreadable/malformed database -- never a Python
traceback (same contract as lib/time.py and lib/ask.py).
"""
import datetime
import os
import re
import sqlite3
import stat
import sys
from urllib.parse import urlsplit

# Chromium/WebKit timestamps are microseconds since 1601-01-01T00:00:00Z
# (the Windows FILETIME epoch, not Unix's). This is the fixed offset
# between the two epochs, in seconds -- a well-known constant, not
# something to recompute per row.
WEBKIT_EPOCH_OFFSET_SECONDS = 11644473600

NOW_FMT = "%Y-%m-%d %H:%M:%S"      # OMARCHY_KIDS_NOW's shape (lib/time.sh)
TS_FMT = "%Y-%m-%dT%H:%M:%S"       # launches.log / --since cutoff shape


def die(msg):
    print(f"data.py: {msg}", file=sys.stderr)
    sys.exit(2)


def parse_now(s):
    try:
        return datetime.datetime.strptime(s, NOW_FMT)
    except ValueError as e:
        die(f"bad timestamp '{s}': {e}")


def parse_ts(s):
    """A launches.log / --since token, or None if it doesn't parse."""
    try:
        return datetime.datetime.strptime(s, TS_FMT)
    except ValueError:
        return None


def cmd_since_cutoff(argv):
    if len(argv) != 2:
        die("since-cutoff: needs DAYS and a \"YYYY-MM-DD HH:MM:SS\" NOW")
    try:
        days = int(argv[0])
    except ValueError:
        die(f"since-cutoff: DAYS must be an integer, got '{argv[0]}'")
    now = parse_now(argv[1])
    cutoff = now - datetime.timedelta(days=days)
    print(cutoff.strftime(TS_FMT))


def cmd_since_epoch(argv):
    if len(argv) != 2:
        die("since-epoch: needs DAYS and a \"YYYY-MM-DD HH:MM:SS\" NOW")
    try:
        days = int(argv[0])
    except ValueError:
        die(f"since-epoch: DAYS must be an integer, got '{argv[0]}'")
    now = parse_now(argv[1])
    cutoff = now - datetime.timedelta(days=days)
    # Naive datetime -> epoch via the host's own local zone, same as the
    # real `time.time()` lib/ask.py stamps "asked_at" with -- both sides
    # of the comparison come from the same clock, so this is consistent
    # even though it's not portable across machines in different zones.
    print(int(cutoff.timestamp()))


def cmd_filter_log(argv):
    if len(argv) != 2:
        die("filter-log: needs FILE and CUTOFF")
    path, cutoff = argv
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except FileNotFoundError:
        return  # "no data yet" -- not an error, nothing to print
    except OSError as e:
        die(f"filter-log: could not read {path}: {e}")
    for line in lines:
        line = line.rstrip("\n")
        if not line:
            continue
        field = line.split(" ", 1)[0]
        if parse_ts(field) is None:
            continue  # malformed line -- dropped, not kept forever
        if field >= cutoff:
            print(line)


def _webkit_to_local_str(webkit_us):
    unix_s = (webkit_us / 1_000_000) - WEBKIT_EPOCH_OFFSET_SECONDS
    return datetime.datetime.fromtimestamp(unix_s).strftime(TS_FMT)


def _open_readonly(db_path):
    try:
        # A copy the caller already made (Chromium locks the live file
        # while running -- see bin/omarchy-kids-data's own header),
        # opened read-only so nothing here ever mutates it, and with
        # immutable=1 so sqlite3 doesn't try to take out a lock or
        # replay a WAL on a file that will never be written to again.
        conn = sqlite3.connect(f"file:{db_path}?mode=ro&immutable=1", uri=True)
        conn.execute("SELECT 1 FROM urls LIMIT 1")
        return conn
    except sqlite3.Error as e:
        die(f"could not read '{db_path}' as a Chromium History db: {e}")


def _fetch_rows(db_path, since_cutoff):
    conn = _open_readonly(db_path)
    try:
        rows = conn.execute(
            "SELECT url, title, last_visit_time, visit_count FROM urls "
            "WHERE last_visit_time > 0"
        ).fetchall()
    finally:
        conn.close()
    out = []
    for url, title, last_visit_time, visit_count in rows:
        local = _webkit_to_local_str(last_visit_time)
        if since_cutoff is not None and local < since_cutoff:
            continue
        host = urlsplit(url).netloc or url
        out.append((local, host, title or "", visit_count or 0))
    return out


def _parse_common_flags(argv, allow_limit=True):
    if not argv:
        die("needs a DB path")
    db = argv[0]
    since = None
    limit = None
    i = 1
    while i < len(argv):
        if argv[i] == "--since" and i + 1 < len(argv):
            since = argv[i + 1]
            i += 2
        elif allow_limit and argv[i] == "--limit" and i + 1 < len(argv):
            try:
                limit = int(argv[i + 1])
            except ValueError:
                die(f"--limit must be an integer, got '{argv[i + 1]}'")
            i += 2
        else:
            die(f"unrecognized argument '{argv[i]}'")
    return db, since, limit


ROW_SEP = "\u001f"  # US: not IFS whitespace, so bash `read` keeps empty fields
_C0 = re.compile(r"[\x00-\x1f\x7f]")


def _row(*fields):
    # A page title is free-form kid-browsing text: strip every C0 control
    # (0x1f would forge a field boundary; ESC and friends would inject a
    # terminal escape sequence into the parent's `omarchy-kids-data` output).
    return ROW_SEP.join(_C0.sub(" ", str(f)) for f in fields)


def cmd_chromium_visits(argv):
    db, since, limit = _parse_common_flags(argv)
    rows = _fetch_rows(db, since)
    rows.sort(key=lambda r: r[0], reverse=True)
    if limit is not None:
        rows = rows[:limit]
    for local, host, title, visit_count in rows:
        print(_row(local, host, title, visit_count))


def cmd_chromium_top_sites(argv):
    db, since, limit = _parse_common_flags(argv)
    if limit is None:
        limit = 5
    rows = _fetch_rows(db, since)
    by_host = {}
    for local, host, _title, visit_count in rows:
        entry = by_host.setdefault(host, {"visits": 0, "last": local})
        entry["visits"] += visit_count
        if local > entry["last"]:
            entry["last"] = local
    ordered = sorted(
        by_host.items(), key=lambda kv: (kv[1]["visits"], kv[1]["last"]), reverse=True
    )
    for host, entry in ordered[:limit]:
        print(_row(host, entry["visits"], entry["last"]))


def cmd_fold_launches(argv):
    """fold-launches SRC DEST UID SAVED_INODE SAVED_OFFSET

    The one step that promotes a kid's own runtime log into the
    root-owned one, and the only place in this package where root reads a
    path a kid controls. SRC is opened with O_NOFOLLOW and checked
    (regular file, owned by UID, single link) *on the open file
    descriptor*, so neither a symlink nor a swap between the check and
    the read can point root at /etc/shadow (review §3.3).

    Prints "INODE SIZE" -- what data_write_offset should record. Prints
    "skip" and exits 0 when there is nothing to fold (no session yet), or
    "refused REASON" on stderr and exits 3 when SRC is not the plain file
    it must be.
    """
    if len(argv) != 5:
        die("fold-launches: needs SRC DEST UID SAVED_INODE SAVED_OFFSET")
    src, dest = argv[0], argv[1]
    try:
        want_uid, saved_inode, saved_off = (int(argv[2]), int(argv[3]), int(argv[4]))
    except ValueError:
        die("fold-launches: UID, SAVED_INODE and SAVED_OFFSET must be integers")

    try:
        fd = os.open(src, os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0))
    except FileNotFoundError:
        print("skip")
        return
    except OSError as exc:  # ELOOP (a symlink), EACCES, ...
        print(f"data.py: fold-launches: refusing to read {src}: {exc}", file=sys.stderr)
        sys.exit(3)

    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            print(f"data.py: fold-launches: {src} is not a regular file", file=sys.stderr)
            sys.exit(3)
        if st.st_uid != want_uid:
            print(
                f"data.py: fold-launches: {src} is owned by uid {st.st_uid}, not {want_uid}",
                file=sys.stderr,
            )
            sys.exit(3)
        if st.st_nlink != 1:
            print(f"data.py: fold-launches: {src} has {st.st_nlink} links", file=sys.stderr)
            sys.exit(3)

        size = st.st_size
        off = saved_off
        if st.st_ino != saved_inode or off > size:
            off = 0  # a fresh login's new tmpfs file, or a truncated one
        if size > off:
            os.makedirs(os.path.dirname(dest) or ".", mode=0o755, exist_ok=True)
            # 0640 root:omarchy-parents, like status.json: this is a
            # record *about* a kid, for their parent, and it was
            # world-readable to every sibling (review §3.7). The group is
            # set by the caller, which knows whether it exists.
            dfd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o640)
            try:
                os.lseek(fd, off, os.SEEK_SET)
                while off < size:
                    chunk = os.read(fd, min(65536, size - off))
                    if not chunk:
                        break
                    os.write(dfd, chunk)
                    off += len(chunk)
            finally:
                os.close(dfd)
        print(f"{st.st_ino} {size}")
    finally:
        os.close(fd)


COMMANDS = {
    "since-cutoff": cmd_since_cutoff,
    "fold-launches": cmd_fold_launches,
    "since-epoch": cmd_since_epoch,
    "filter-log": cmd_filter_log,
    "chromium-visits": cmd_chromium_visits,
    "chromium-top-sites": cmd_chromium_top_sites,
}


def main(argv):
    if not argv or argv[0] not in COMMANDS:
        die(f"usage: data.py {{{'|'.join(COMMANDS)}}} ...")
    COMMANDS[argv[0]](argv[1:])


if __name__ == "__main__":
    main(sys.argv[1:])
