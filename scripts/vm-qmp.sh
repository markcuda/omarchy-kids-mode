#!/bin/bash
# Talk to the running test VM over QMP. shot <file.png> | type | key <qcode>... | status | quit
set -euo pipefail
VM="${VM_DIR:-$HOME/vm}"
S="$VM/qmp.sock"

# qmp EXECUTE_JSON -- run one QMP command, print its reply, and refuse a QMP
# error. The helper used to pipe the reply to /dev/null and take no notice of
# it, so a command QEMU rejected looked exactly like success -- which is how a
# dropped keystroke went unnoticed (issue #178).
qmp() {
  local reply
  if ! reply="$(printf '{"execute":"qmp_capabilities"}\n{"execute":%s}\n' "$1" |
    socat -t 3 - "UNIX-CONNECT:$S" | tail -1)"; then
    echo "vm-qmp: no reply from $S" >&2
    return 1
  fi
  if [[ -z "$reply" ]]; then
    echo "vm-qmp: empty reply from $S" >&2
    return 1
  fi
  if [[ "$reply" == *'"error"'* ]]; then
    echo "vm-qmp: QMP refused $1: $reply" >&2
    return 1
  fi
  printf '%s\n' "$reply"
}

# qcode_for CHAR -- the QEMU qcode that types CHAR on a US layout, or nothing
# when there is no mapping. A bare `:` used to fall through as the qcode ":" and
# be silently refused, so 21:00 arrived as 2100 (issue #178).
qcode_for() {
  case "$1" in
    [a-z0-9]) printf '%s' "$1" ;;
    [A-Z]) printf 'shift-%s' "${1,,}" ;;
    ' ') printf 'spc' ;;
    '-') printf 'minus' ;;
    '=') printf 'equal' ;;
    '.') printf 'dot' ;;
    ',') printf 'comma' ;;
    '/') printf 'slash' ;;
    ';') printf 'semicolon' ;;
    "'") printf 'apostrophe' ;;
    '\') printf 'backslash' ;;
    '`') printf 'grave_accent' ;;
    '[') printf 'bracket_left' ;;
    ']') printf 'bracket_right' ;;
    '!') printf 'shift-1' ;;
    '@') printf 'shift-2' ;;
    '#') printf 'shift-3' ;;
    '$') printf 'shift-4' ;;
    '%') printf 'shift-5' ;;
    '^') printf 'shift-6' ;;
    '&') printf 'shift-7' ;;
    '*') printf 'shift-8' ;;
    '(') printf 'shift-9' ;;
    ')') printf 'shift-0' ;;
    '_') printf 'shift-minus' ;;
    '+') printf 'shift-equal' ;;
    ':') printf 'shift-semicolon' ;;
    '"') printf 'shift-apostrophe' ;;
    '<') printf 'shift-comma' ;;
    '>') printf 'shift-dot' ;;
    '?') printf 'shift-slash' ;;
    '{') printf 'shift-bracket_left' ;;
    '}') printf 'shift-bracket_right' ;;
    '|') printf 'shift-backslash' ;;
    '~') printf 'shift-grave_accent' ;;
    *) : ;;
  esac
}

case ${1:-} in
  shot)
    qmp "\"screendump\", \"arguments\": {\"filename\": \"$2\", \"format\": \"png\"}" >/dev/null
    echo "$2"
    ;;
  key)
    shift
    keys=$(printf '{"type":"qcode","data":"%s"},' "$@")
    qmp "\"send-key\", \"arguments\": {\"keys\": [${keys%,}]}" >/dev/null
    ;;
  type)
    (($# == 1)) || {
      echo "type reads text from stdin" >&2
      exit 2
    }
    text="$(cat)"
    for ((i = 0; i < ${#text}; i++)); do
      c=${text:i:1}
      k="$(qcode_for "$c")"
      # Refuse rather than send an invalid qcode: a character this cannot type
      # must stop the run, not vanish into a silently refused command (issue #178).
      if [[ -z "$k" ]]; then
        printf 'vm-qmp: cannot type %q -- no qcode mapping (issue #178)\n' "$c" >&2
        exit 1
      fi
      if [[ $k == shift-* ]]; then
        qmp "\"send-key\", \"arguments\": {\"keys\": [{\"type\":\"qcode\",\"data\":\"shift\"},{\"type\":\"qcode\",\"data\":\"${k#shift-}\"}]}" >/dev/null
      else qmp "\"send-key\", \"arguments\": {\"keys\": [{\"type\":\"qcode\",\"data\":\"$k\"}]}" >/dev/null; fi
      sleep 0.05
    done
    ;;
  enter) qmp "\"send-key\", \"arguments\": {\"keys\": [{\"type\":\"qcode\",\"data\":\"ret\"}]}" >/dev/null ;;
  status) qmp '"query-status"' ;;
  quit) qmp '"quit"' >/dev/null ;;
  *)
    echo "usage: vm-qmp.sh shot <png> | type (reads stdin) | enter | key <qcode>... | status | quit"
    exit 2
    ;;
esac
