#!/bin/bash
# Tests that every Text/TextInput block under share/**/*.qml resolves a font
# family: `font.family:` (theme or bar) or a whole `font:` binding inherited
# from a themed control. The 2026-09-18 UI/UX review found five surfaces
# falling back to Qt's platform font while the launcher used JetBrains Mono
# (docs/theming.md, I-6's consistency claim).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP qml-fonts-test.sh: python3 not found"
  exit 0
fi

out="$(python3 - "$DIR" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
open_re = re.compile(r"^(\s*)(Text|TextInput)\s*\{\s*$")
ok_re = re.compile(r"font\.family\s*:|^\s*font\s*:")
missing = []
for path in sorted(root.glob("share/**/*.qml")):
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        match = open_re.match(lines[i])
        if not match:
            i += 1
            continue
        depth = lines[i].count("{") - lines[i].count("}")
        j = i + 1
        body = []
        while j < len(lines) and depth > 0:
            depth += lines[j].count("{") - lines[j].count("}")
            body.append(lines[j])
            j += 1
        if not any(ok_re.search(line) for line in body):
            missing.append(f"{path.relative_to(root)}:{i + 1}")
        i = j

for item in missing:
    print(item)
sys.exit(1 if missing else 0)
PY
)"
rc=$?
if ((rc != 0)); then
  echo "FAIL these Text/TextInput blocks resolve no font family:"
  printf '%s\n' "$out"
else
  echo "ok   every Text/TextInput block under share/**/*.qml resolves a font family"
fi
echo "qml-fonts-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
