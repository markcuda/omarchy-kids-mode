# shellcheck shell=bash
# lib/sock.sh -- one Unix-socket request/response client for every daemon
# this repo speaks to (bin/omarchy-kids-authd, bin/omarchy-kids-wifid),
# replacing three copies that had drifted. socat where it exists, python3
# otherwise, and a hard failure when neither does -- never a silent
# success, since every caller reads "no reply" as "refused".

# The two transport programs are pinned the way every other program seam in
# this repo is (rule 9): socat at its absolute path, and the interpreter through
# KIDS_PY when kids.sh was sourced (the packaged value is /usr/bin/python3; a
# command that sources only this file, like parent-auth, falls back to python3 on
# a root/PAM PATH, never a kid's). A dev checkout has neither /usr/bin/socat nor a
# rewritten KIDS_PY, so it uses PATH python3 -- the same seam tests already stub.
SOCAT_BIN=/usr/bin/socat
SOCK_PY="${KIDS_PY:-python3}"

# kids_sock_request SOCKET PAYLOAD [TIMEOUT] -- writes PAYLOAD, shuts the
# write side down, prints whatever comes back. Returns non-zero when
# there is no way to speak the protocol at all.
kids_sock_request() {
  local sock="$1" payload="$2" timeout="${3:-5}"
  if [[ -x "$SOCAT_BIN" ]]; then
    printf '%s' "$payload" | "$SOCAT_BIN" -T"$timeout" - "UNIX-CONNECT:$sock" 2>/dev/null
  elif command -v "$SOCK_PY" >/dev/null 2>&1; then
    printf '%s' "$payload" | "$SOCK_PY" -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(float(sys.argv[2]))
try:
    s.connect(sys.argv[1])
    s.sendall(sys.stdin.buffer.read())
    s.shutdown(socket.SHUT_WR)
    data = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        data += chunk
    sys.stdout.buffer.write(data)
except OSError:
    pass
' "$sock" "$timeout" 2>/dev/null
  else
    return 1
  fi
}
