# The parent-password verifier (R-SEC-1, R-SEC-2)

`omarchy-kids-authd` is the one place in Kids Mode that knows how to check the parent's password.
Every screen that asks "is a parent here?" — the exit modal, the ask modal, the lock-screen line,
the portal line, panel confirmations, the bar-widget actions — goes through it instead of
re-implementing password checking itself. I-8: Kids Mode never asks for anything but the parent's
own login password, and never stores it.

## Pieces

- `bin/omarchy-kids-authd` — a root, socket-activated Python daemon. Reads the parent's shadow
  hash fresh on every request (never cached) and answers with a short `ok` or `no` reply.
- `bin/omarchy-kids-parent-auth` — a small bash client for `pam_exec`. Reads a candidate password
  from stdin, asks the daemon, and turns the answer into an exit code.
- `systemd/omarchy-kids-authd.socket` / `.service` — the socket unit owns
  `/run/omarchy-kids/auth.sock` (mode `0666`, directory `0755`) and starts the daemon on first
  connection.

## Wire protocol

A client connects to the Unix socket and sends one framed request. The candidate line is always
newline-terminated and at most 512 bytes:

```text
client -> "VERIFY\nhunter2\n"
server -> "ok\n"       # or "no\n"
server closes the connection
```

The wizard bootstrap uses a caller-bound frame:

```text
client -> "BOOTSTRAP\nhunter2\n"
server -> "ok\n"       # or "no\n"
server closes the connection
```

The `GRANT` form sends a JSON request line followed by the password and may include a reason in a
negative reply:

```text
client -> "GRANT {…}\nhunter2\n"
server -> "ok\n"       # or "no <reason>\n"
server closes the connection
```text

Anything that doesn't fit one of those shapes, including an unframed password, gets `no`. A client
that goes quiet for more than 5 seconds also gets `no`. The daemon never writes the candidate
anywhere, not to a log, not to disk, and not into an exception message.

## Where the parent's identity and hash come from

- The parent's login name comes from `/etc/omarchy-kids/machine.conf` (a `key=value` file, key
  `parent`), or from the root-only `--parent NAME` option used by tests and socket activation.
- The hash comes from `/etc/shadow` (path overridable with `--shadow PATH`, which is how the
  tests run without touching the real file), read again on every single request. A locked account
  (a hash starting with `!` or `*`) never matches.
- Comparison is `crypt(3)` via libxcrypt, loaded through `ctypes.CDLL("libcrypt.so.1")` rather
  than Python's `crypt` module, which is gone as of Python 3.13. This also means the daemon
  understands whatever `crypt(3)` on the box understands — yescrypt included — for free. The
  daemon's own result is compared against the stored hash with `hmac.compare_digest`, so a
  mismatch doesn't leak timing information about where the strings diverge.

## Rate limiting

The limiter is in memory, process-wide, and resets on restart:

- 3 wrong answers in a row → refuse (`no`) for 30 seconds, no matter what's sent.
- 10 wrong answers in a row → refuse for 300 seconds.
- A correct answer resets the counter to zero.

While locked out, the daemon does not even look at the candidate — it can't leak a correct
password's worth of timing or oracle behavior during the lockout window, and a truly correct
guess made during a lockout still comes back `no`.

## Threat notes

- **Any local user can talk to the oracle.** The socket is `0666` by design (kid sessions, the
  portal, and the parent's own session all need to reach it, and none of them run as the parent).
  That makes this daemon a password oracle available to anyone on the box, including the kid
  account it exists to keep locked down. The rate limit above is the whole defense against
  brute-forcing it, not a nice-to-have: at worst an attacker gets 3 fast guesses before a 30s
  wait, and 10 before a 5-minute one.
- **The modal is a second line of defense, not the first.** Whatever UI calls into this daemon
  (the exit modal, the portal, etc.) should apply its own pacing/backoff on top of this, per
  I-6 ("honest UI") — don't let a kid brute-force the *daemon's* limit once per boot from every
  surface that calls it.
- **This is not `faillock`.** R-SEC-1 is explicit: the verifier never touches the system's
  faillock state for the parent's login. A string of wrong guesses through Kids Mode cannot lock
  the parent out of their own console login, and console lockouts don't affect this daemon.
- **The daemon fails closed.** No parent configured, no matching shadow entry, an unreadable
  shadow file, a locked/disabled account, libxcrypt missing — every one of those answers `no`
  rather than crashing or falling through to "allowed."

## How PAM uses it

`pam_exec.so` with `expose_authtok` puts the just-typed password on the client's stdin; the
client asks the daemon and turns the reply into an exit code the PAM stack understands:

```text
auth [success=1 default=ignore] pam_exec.so quiet expose_authtok /usr/bin/omarchy-kids-parent-auth
```text

`success=1` skips the next line (normally a `pam_deny` or similar) when the verifier says yes;
`default=ignore` means every other outcome falls through to whatever comes after, unchanged. This
line is written once and used everywhere R-SEC-2 lists — the exit modal, the ask modal, the
lock-screen line, the portal line, panel confirmations, the bar-widget actions — because
verification always happens in the daemon, never in the caller, whether that caller is running as
root or as the kid.

The client also refuses immediately, without contacting the daemon, if `PAM_TYPE` is set and
isn't `auth` — `pam_exec` invokes the same line for `account`/`session`/`password` stack entries
too, and this isn't valid outside of `auth`.

The client reads exactly one line from stdin, not "until EOF": `pam_exec` closes its pipe after
writing the password, but a caller that keeps stdin open instead (the exit modal's Quickshell
`Process` did this, found live) would hang `cat -`/`read` forever waiting for a second line.
`read -r` returns non-zero on a final line with no trailing newline; the candidate password is
still filled in when that happens, so the client keeps it rather than treating a non-zero `read`
as "nothing was typed."

**Confirmed (issue #15 review): there is no `PAM_USER` check, on purpose.** The client reads
`PAM_TYPE` and stdin only; it never looks at which account is being authenticated at all. That's
deliberate, not a gap: `omarchy-kids-provision`'s `posture_ensure_parent_unlock_line` inserts this
line into `/etc/pam.d/sddm` and `/etc/pam.d/omarchy-lock-password` ahead of each stack's own auth
chain, so it runs for *whoever* is logging in — a kid's tile, the parent's own tile, or anything
else that stack authenticates. That is exactly right: R-LOGIN-5 says the parent's password opens
any kid's tile, and there's no reason it shouldn't also succeed (redundantly, but harmlessly) when
the parent is unlocking their own. Gating on `PAM_USER` would only add a way to accidentally
exclude an account this was supposed to work for; the daemon's own hash comparison is what
actually decides yes/no, not which account asked.

## Testing

`test/shell.d/authd-test.sh` starts the daemon on a temp socket with a fixed, known sha512-crypt
hash (`$6$saltsalt$...`, for the password `secret123`) and a `--shadow`/`--parent` pointed at
test fixtures — no real `/etc/shadow` or `/etc/omarchy-kids/machine.conf` involved. It needs a
loadable `libcrypt.so.1` to actually run the daemon, which macOS doesn't have; on a host without
it, the test prints `SKIP` and exits 0 rather than failing. Run it directly with:

```text
bash test/shell.d/authd-test.sh
```text

or as part of the full suite with `test/all`.
## The GRANT request type (2026-09-03)

The daemon answers four request shapes, one per connection. Ordinary verification uses the
explicit `VERIFY` frame. The wizard's `BOOTSTRAP` frame adds the caller-identity check. The third
is `GRANT <json-request-line>\n<password>\n`, and it exists because an "Ask a grown-up" approval
cannot be an exit code from a process the kid owns (review S1). Root does all of it here: it
parses the request, runs it through `lib/ask.py`'s `validate_grant` (loaded by path from
`--lib`), reads the connecting peer's real uid from `SO_PEERCRED` and refuses unless it matches
the request's `kid`, confirms that kid has a profile under `--etc`, and only then spends a
`crypt(3)` on the password. Everything that can be refused without the password is refused
first. On success it runs `<--ask-bin> apply-grant --kid ... --apply` with a fixed argv list, so
the "do the thing" code has exactly one home. The fourth is `DECIDE <json-frame>\n`, a paired
device's signed decision (R-NOTIFY-4): only the relay account (`--relay-user`) may send it,
`lib/devices.py` verifies the Ed25519 signature, skew, nonce and the fixed `decide` scope as root,
and on success root runs `<--ask-bin> approve|decline <id> --by device:<id> --apply`, which refuses
an already-decided record. A missing module, ledger or relay account makes every DECIDE fail
closed. Two other changes came from the same review: the
rate limiter is keyed per peer uid and decays after a quiet window, so a kid looping wrong
guesses at the world-connectable socket can no longer lock the parent out of their own exit
modal (S7); and each connection is handled on its own thread, so a peer holding a connection
open no longer serializes everyone else's verification behind it. The limiter is the only shared
state and takes its own lock.

`bin/omarchy-kids-parent-auth`, the pam_exec client, reads **nothing** from its environment
(issue #58). It runs inside the kid's session -- hyprlock's PAM stack, the exit modal -- so not
the socket path and not `lib/`: it sources `lib/sock.sh` from its own `readlink -f "$0"`, else
`/usr/lib/omarchy-kids`. `$OMARCHY_KIDS_LIB` used to decide that, which meant a kid could write
`~/evil/sock.sh` with `kids_sock_request() { printf 'ok\n'; }`, export the variable from their
own `~/.profile`, and have any password unlock the screen (review §2.1 -- the worst thing in the
round-two review). `--socket` is still honoured for root only, with one build-time exception
(`TEST_SOCKET_ROOT`, empty in every shipped copy and asserted so by
`test/shell.d/pkgbuild-test.sh`) so the tests can point it at a scratch socket. The PAM line in
`lib/posture.sh` names the helper as `/usr/bin/omarchy-kids-parent-auth`: pam_exec execs that path
directly and never consults `PATH`, so neither the binary, nor its libraries, nor the socket can
be redirected by anything the kid sets. `test/shell.d/authd-test.sh` asserts the source mentions
no `OMARCHY_KIDS_*` variable at all.

The daemon caps concurrent client threads at `MAX_INFLIGHT` (16) with a semaphore released in
`handle_client`'s `finally`, answering `no busy` over the cap. The socket is `0666`, so without a
cap a kid looping `socat - UNIX-CONNECT:/run/omarchy-kids/auth.sock` without sending a line spawned
one 5-second root thread per connection until Python could not start another and the unit bounced
-- taking the exit modal and every GRANT with it (review §2.5).

## PAM stack placement forensics (moved from `lib/posture.sh`, issue #49)

```text
--- parent-unlock PAM line (R-SEC-2, R-SEC-3; SPEC.md I-6; docs/authd.md) --

The lock screen and SDDM both need "did a parent type their own password
here?" answered the same way (docs/authd.md): pam_exec.so calling
omarchy-kids-parent-auth, which asks the omarchy-kids-authd daemon rather
than re-implementing password checking. This line is written once, into
each real stack this ships on, at a fixed position relative to that
stack's own first "auth" line -- not by finding a pam_unix.so line to
jump around, which real Omarchy 4.0.2 stacks don't reliably even have
(confirmed against a real box; see below).

Placement, confirmed against the real /etc/pam.d/sddm and
/etc/pam.d/omarchy-lock-password on Omarchy 4.0.2 (there is no
/etc/pam.d/hyprlock on that box -- omarchy-apply-lock always writes
omarchy-lock-password):

  /etc/pam.d/sddm is `auth include system-login` first -- no pam_unix.so
  line of its own at all, and no leading pam_faillock preauth line
  either. Our line has to go *before* that first "auth" line, so it runs
  (and can potentially succeed outright) before system-login's own chain
  -- which is what actually checks whichever account is really logging
  in -- ever runs.

  /etc/pam.d/omarchy-lock-password (bin/omarchy-apply-lock,
  scratchpad/pr9750.diff) leads with
  "auth required pam_faillock.so preauth ...". Our line goes right
  *after* that one line (never before it -- preauth has to run first so
  a lockout is tracked correctly), still ahead of pam_unix.so.

So the one rule that covers both real shapes: insert right after a
leading "auth ... pam_faillock.so ... preauth" line if the very first
"auth" line in the file is one, otherwise insert right before that first
"auth" line. ("auth", not "-auth" -- a dash-prefixed line is a
module-load-failure-is-silent variant of the same facility, never the
anchor point.) Never touches system-login or system-auth themselves
(I-7): those are included by reference, never opened by this function.

The control is fixed, not computed: "[success=done default=ignore]".
"done" ends the whole stack successfully the instant a parent's password
verifies, so pam_unix (and whatever system-login/system-auth's own chain
does) is never even consulted with the parent's password. "default=ignore"
on anything else (wrong password, daemon unreachable, rate-limited) falls
through to the stack's normal chain, which -- because our line sits
ahead of it with `expose_authtok` already having read the typed password
-- reuses that exact same token via pam_unix's own `try_first_pass`
(already on both real stacks' pam_unix lines), so nobody is ever
prompted twice.
```
