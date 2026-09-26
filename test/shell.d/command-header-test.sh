#!/bin/bash
# The header every bin/omarchy-kids-* command must carry (AGENTS.md, "Put
# # omarchy:summary=<one line> ... directly under the shebang of every
# bin/omarchy-kids-* command, before any prose", and "Every command in bin/ uses
# set -euo pipefail -- no exceptions without a one-line note in that file's own
# header saying why").
#
# trust-boundary-test.sh already owns the shebang half (rule 9: it is how a
# python command gets into the PKGBUILD's rewrite loop and nothing else does).
# The other two were stated but unchecked: a command could ship with no summary,
# or a bash command could drop `set -euo pipefail`, and the suite stayed green.
# The header is not decoration -- the app entry and `--help` are built from it --
# so a missing summary is a real (if small) break of the convention.
#
# Needs no external tools, so unlike the tool-gated checks this one runs on every
# box, the VM included.
set -uo pipefail
pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

shopt -s nullglob
commands=(bin/omarchy-kids-*)
if ((${#commands[@]} == 0)); then
  fail "no bin/omarchy-kids-* commands found"
  echo "command-header-test RESULT: FAIL"
  exit 1
fi

ok_count=0
for f in "${commands[@]}"; do
  [[ -f "$f" ]] || continue

  # The shebang is trust-boundary-test.sh's to enforce; if it is wrong here this
  # check says so too rather than guessing how to read the file.
  case "$(head -1 "$f")" in
    '#!/bin/bash') is_bash=1 ;;
    '#!/usr/bin/env python3') is_bash=0 ;;
    *)
      fail "$f: unexpected shebang '$(head -1 "$f")'"
      continue
      ;;
  esac

  summary="$(sed -n '2p' "$f")"
  case "$summary" in
    '# omarchy:summary='*)
      if [[ -z "${summary#\# omarchy:summary=}" ]]; then
        fail "$f: omarchy:summary is blank"
        continue
      fi
      ;;
    *)
      fail "$f: line 2 is not an omarchy:summary line (got: $summary)"
      continue
      ;;
  esac

  if ((is_bash)) && ! grep -q '^set -euo pipefail' "$f"; then
    fail "$f: a bash command without 'set -euo pipefail' and no note in its header"
    continue
  fi

  ok_count=$((ok_count + 1))
done

((${rc:-0} == 0)) && pass "all $ok_count bin/omarchy-kids-* command(s) carry a summary and a strict-mode line"
echo "command-header-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
