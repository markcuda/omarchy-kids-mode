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

out="$(
  python3 - "$DIR" <<'PY'
import pathlib, re, sys

# Scans every Text/TextInput/TextEdit opener and checks its *direct*
# properties (depth 1) for a family. Nested blocks are scanned by their own
# iteration. Braces inside strings or comments are not tracked; no such
# block exists under share/ today (update this scanner if one appears).
root = pathlib.Path(sys.argv[1])
open_re = re.compile(r"^(\s*)(Text|TextInput|TextEdit)\s*\{\s*(//.*)?$")
ok_re = re.compile(r"font\.family\s*:|^\s*font\s*:\s*[\w.]+\.font\s*$")
missing = []
for path in sorted(root.glob("share/**/*.qml")):
    lines = path.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if not open_re.match(line):
            continue
        depth = line.count("{") - line.count("}")
        j = i + 1
        resolved = False
        while j < len(lines) and depth > 0:
            stripped = lines[j].strip()
            if depth == 1 and not stripped.startswith("//") and ok_re.search(lines[j]):
                resolved = True
            depth += lines[j].count("{") - lines[j].count("}")
            j += 1
        if not resolved:
            missing.append(f"{path.relative_to(root)}:{i + 1}")

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
