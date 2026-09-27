#!/bin/bash
# Static checks on the omarchy-kids-unlock runtime hook (R-BOOT-1). It runs
# in the initramfs under /usr/bin/ash, which macOS dev machines don't have,
# so the syntax check SKIPs (not FAILs) when neither ash nor busybox is
# available. The safety-return greps always run — they don't need ash.
set -uo pipefail
pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
skip() { echo "SKIP  $*"; }
rc=0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$ROOT/initcpio/hooks/omarchy-kids-unlock"
OPEN="$ROOT/initcpio/omarchy-kids-open"

[[ -f "$HOOK" ]] || {
  fail "hook not found at $HOOK"
  echo "unlock-hook-test RESULT: FAIL"
  exit 1
}
[[ -f "$OPEN" ]] || {
  fail "helper not found at $OPEN"
  echo "unlock-hook-test RESULT: FAIL"
  exit 1
}

# --- syntax: ash -n (real ash/dash; else busybox ash; else busybox in a container; else skip) ---
# The install script (initcpio/install/omarchy-kids-unlock) is deliberately not in this list: it is
# #!/bin/bash and runs at mkinitcpio time, not in the initramfs. The hook and the helper both run
# before the stock `encrypt` hook, where a syntax error is a boot that dies before the LUKS prompt.
ASH=""
if command -v ash >/dev/null 2>&1; then
  ASH="ash"
elif command -v busybox >/dev/null 2>&1 && busybox ash -c 'exit 0' >/dev/null 2>&1; then
  ASH="busybox ash"
elif command -v docker >/dev/null 2>&1 &&
  docker run --rm -v "$ROOT":/w -w /w busybox:latest ash -c 'exit 0' >/dev/null 2>&1; then
  # Docker is the only route on a box with neither ash nor busybox -- a macOS dev machine with
  # Docker Desktop. The probe above fails fast when the image cannot be pulled or there is no
  # network, so this still SKIPs rather than hanging where a container is not usable.
  ASH="container"
fi

if [[ "$ASH" == "container" ]]; then
  if docker run --rm -v "$ROOT":/w -w /w busybox:latest ash -n "${HOOK#"$ROOT"/}" &&
    docker run --rm -v "$ROOT":/w -w /w busybox:latest ash -n "${OPEN#"$ROOT"/}"; then
    pass "ash -n parses both the hook and the helper (busybox in a container)"
  else
    fail "ash -n reported a syntax error"
  fi
elif [[ -n "$ASH" ]]; then
  if $ASH -n "$HOOK" && $ASH -n "$OPEN"; then
    pass "ash -n parses both the hook and the helper"
  else
    fail "ash -n reported a syntax error"
  fi
else
  skip "no ash/busybox and no usable busybox container — syntax not checked"
fi

# --- no bashisms: neither file declares itself bash, nor uses [[ ]] ---
if grep -q '^#!/usr/bin/ash' "$HOOK" && grep -q '^#!/usr/bin/ash' "$OPEN"; then
  pass "both files shebang #!/usr/bin/ash"
else
  fail "shebang is not #!/usr/bin/ash in one of the files"
fi
if grep -qE '\[\[|^\s*local -[an]|declare ' "$HOOK" "$OPEN"; then
  fail "found a bash-only construct ([[ ]], local -a/-n, or declare)"
else
  pass "no obvious bashisms ([[ ]], local -a/-n, declare)"
fi

# --- the four fail-safe / do-nothing returns from R-BOOT-1 ---
if grep -q 'cryptkey' "$HOOK"; then
  pass "checks cryptkey (keyfile boot) before doing anything"
else
  fail "no cryptkey check found"
fi
if grep -q 'cryptdevice' "$HOOK"; then
  pass "returns safely when cryptdevice is unset"
else
  fail "no 'no cryptdevice' safety return found"
fi
if grep -qE '/dev/mapper/\$\{cryptname\}.*&&.*return 0|-b "/dev/mapper' "$HOOK"; then
  pass "returns safely when /dev/mapper/<name> already exists"
else
  fail "no 'already exists' safety return found"
fi
if grep -q 'isLuks' "$HOOK"; then
  pass "checks cryptsetup isLuks before prompting"
else
  fail "no LUKS check found"
fi
if grep -qE -e '-lt 3|-eq 3|number-of-tries=3' "$HOOK"; then
  pass "bounds password attempts to three"
else
  fail "no three-attempt bound found"
fi

echo "unlock-hook-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
