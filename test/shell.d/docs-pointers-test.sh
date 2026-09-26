#!/bin/bash
# Every docs/<something>.md a shipped file points at must exist, and every
# bin/omarchy-kids-* command must point at one (AGENTS.md: the mechanics live in
# the command's doc, and the source keeps "one pointer comment" instead).
#
# A doc renamed or deleted leaves the pointer dangling: the reader is sent to a
# file that is not there, and the command's own header now claims a doc it does
# not have. Nothing checked it; both halves hold today (35 unique targets, all
# present) and this keeps them holding. Needs no external tools, so it runs on
# every box.
#
# Deliberately not a 1:1 map: docs are grouped by topic (docs/exit.md covers
# exit and super-tap, docs/wifi.md covers wifi and wifid), so the check is "at
# least one existing doc", never "docs/<command>.md" -- a rule like that would
# fail correct files.
set -uo pipefail
pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

# The shipped trees, from git where there is a checkout and find where the suite
# runs from an extracted tarball.
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  shipped="$(git ls-files 'bin/*' 'lib/*' 'share/*' 'systemd/*' 'initcpio/*' 'pacman/*' 'desktop/*')"
else
  shipped="$(find bin lib share systemd initcpio pacman desktop -type f 2>/dev/null)"
fi

dangling=0
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    if [[ ! -f "$ROOT/$d" ]]; then
      fail "$f points at $d, which does not exist"
      dangling=1
    fi
  done < <(grep -ohE 'docs/[A-Za-z0-9._/-]+\.md' "$f" 2>/dev/null | sort -u)
done <<<"$shipped"
((dangling)) || pass "every docs/*.md pointer in the shipped tree resolves"

undocumented=0
for f in bin/omarchy-kids*; do
  [[ -f "$f" ]] || continue
  if ! grep -qE 'docs/[A-Za-z0-9._/-]+\.md' "$f"; then
    fail "$f names no docs/*.md at all"
    undocumented=1
  fi
done
((undocumented)) || pass "every bin/omarchy-kids-* command names a doc"

# Relative markdown links between docs (and README/AGENTS) must resolve: a doc
# renamed by one of these sweeps leaves a clickable link to nothing in every file
# that referenced it. 29 links, all resolving today.
broken_links=0
while IFS= read -r f; do
  dir="$(dirname "$f")"
  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    case "$target" in /* | http*) continue ;; esac
    if [[ ! -f "$dir/$target" ]]; then
      fail "$f links to $target, which does not exist"
      broken_links=1
    fi
  done < <(grep -ohE '\]\([A-Za-z0-9._/-]+\.md\)' "$f" 2>/dev/null | sed 's|](||; s|)$||' | sort -u)
done < <(
  find docs -name '*.md'
  printf '%s\n' README.md AGENTS.md CONTRIBUTING.md
)
((broken_links)) || pass "every relative .md link in docs/README/AGENTS resolves"

echo "docs-pointers-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
