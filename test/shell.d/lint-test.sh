#!/bin/bash
# The shipped shell and the suite follow AGENTS.md's "shellcheck clean,
# shfmt -i 2 -ci clean" (R-BUILD-4). Nothing enforced that repo-wide: a test
# that shellcheck happens to run covers its own file, and the rest could drift.
# The 2026-09-25 repo-wide pass found one product file (initcpio/install/
# omarchy-kids-unlock) at the wrong indent and eight test-file warnings, none of
# which any check had ever looked at.
#
# Scope is the shipped shell (bin/, lib/, initcpio/, share/) plus the suite that
# runs it (test/shell.d/, test/all). Out of scope, with reasons:
#   test/live/   the gate runner's scenarios (rule 11); a draft does not own them
#   scripts/     operator tooling (vm-*.sh and the one-shot phase scripts), not shipped
#   test/phase1/ historical phase-1 collectors, not shipped
# Those are still run by hand where they matter; this check is about the code
# that reaches a box and the tests that guard it.
#
# Both tools are dev-machine-only and absent on a fresh Arch box, so the check
# SKIPs loudly rather than failing -- the same shape as the other tool-gated
# checks in this suite. (A comment beginning "# shellcheck ..." is itself read as
# a directive, so a line describing them must not start that way.)
set -uo pipefail
pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
skip() { echo "SKIP  $*"; }
rc=0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# A suite file's own assertion helpers must be the ones its assertions reach. Sourcing a
# library that defines check/pass/fail (test/live/lib.sh does, for the scenarios) silently
# shadows them, and a file whose check() can no longer set its own fail flag prints FAIL while
# exiting 0 -- a gate that lies, which is what test/shell.d/live-lib-test.sh did until
# 2026-09-26. So a file that sources a shadowing library must (re)define each helper it uses
# after that source line. Pure text, no tools: runs on the VM, before the shellcheck gate.
for f in "$ROOT"/test/shell.d/*-test.sh; do
  [[ -f "$f" ]] || continue
  src_line="$(grep -nE '^[[:space:]]*(source|\.)[[:space:]].*test/live/lib\.sh' "$f" | tail -1 | cut -d: -f1)"
  [[ -n "$src_line" ]] || continue
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    last_def="$(grep -nE "^[[:space:]]*${name}\(\)" "$f" | tail -1 | cut -d: -f1)"
    [[ -n "$last_def" ]] || continue
    if ((last_def < src_line)); then
      fail "${f#"$ROOT"/}: $name() is defined only before sourcing test/live/lib.sh (line $src_line)"
      fail "  the sourced library shadows it, so this file's assertions cannot fail"
    fi
  done < <(grep -oE '^[[:space:]]*(check|check_status|pass|fail|fail_|ok)\(\)' "$f" | tr -d ' ()' | sort -u)
done

missing=()
for tool in shellcheck shfmt; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if ((${#missing[@]})); then
  skip "lint-test.sh: not installed: ${missing[*]}"
  # Still carry the tool-free checks above (the shadowing guard): skipping shellcheck on a box
  # that lacks it is not the same as passing everything else this file knows how to check.
  echo "lint-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
  exit "$rc"
fi

# git ls-files where there is a checkout; a plain find where the suite runs
# from an extracted tarball (the VM copy has no .git), so this is not a test
# that only works on a developer's clone.
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  list="$(cd "$ROOT" && git ls-files 'bin/*' 'lib/*' 'initcpio/*' 'share/*' 'test/all' 'test/shell.d/*')"
else
  list="$(cd "$ROOT" && find bin lib initcpio share test -maxdepth 2 -path 'test/live' -prune -o -type f -print 2>/dev/null |
    sed "s|^\./||" | grep -E '^(bin/|lib/|initcpio/|share/|test/all$|test/shell\.d/)')"
fi

# Only files whose first line is a shell shebang: grepping anywhere would sweep
# in docs that quote a command (the 2026-09-25 pass did exactly that).
files=()
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  case "$(head -1 "$ROOT/$f" 2>/dev/null)" in
    '#!/bin/bash' | '#!/bin/sh' | '#!/usr/bin/env bash' | '#!/usr/bin/env sh') files+=("$f") ;;
  esac
done <<<"$list"
if ((${#files[@]} == 0)); then
  fail "no shell files found under the lint scope"
  echo "lint-test RESULT: FAIL"
  exit 1
fi

cd "$ROOT" || exit 1

if out="$(shellcheck -S warning -x "${files[@]}" 2>&1)"; then
  pass "shellcheck -S warning: ${#files[@]} file(s) clean"
else
  fail "shellcheck -S warning reported findings:"
  printf '%s\n' "$out" | head -40
fi

if out="$(shfmt -i 2 -ci -d "${files[@]}" 2>&1)"; then
  pass "shfmt -i 2 -ci -d: ${#files[@]} file(s) clean"
else
  fail "shfmt -i 2 -ci found files needing formatting:"
  printf '%s\n' "$out" | grep '^diff ' | head -20
fi

echo "lint-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
