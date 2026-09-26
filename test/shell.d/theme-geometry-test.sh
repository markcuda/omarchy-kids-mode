#!/bin/bash
# Tests R-LOGIN-1, I-1, I-5, issue #201: parent geometry, offline data and zero-width borders.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 - "$ROOT" <<'PY'
import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("geometry", root / "lib/theme-geometry.py")
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
with tempfile.TemporaryDirectory() as temp:
    home = Path(temp) / "parent"
    theme = home / ".local/state/omarchy/current/theme"
    theme.mkdir(parents=True)
    shell = theme / "shell.toml"
    lua = theme / "hyprland.lua"
    cache = Path(temp) / "theme.conf.user"
    shell.write_text('[controls]\nnormal-border-width=0\nfocus-border-width=0\nselected-border-width=0\nselected-fill-alpha=0.18\n')
    lua.write_text('hl.config({ decoration = {\n rounding = 0,\n} })\n')
    safe_stat = SimpleNamespace(st_mode=stat.S_IFREG | 0o644, st_uid=0)
    with patch.object(g, "live_radius", return_value=None):
        square = g.geometry("parent", home, cache)
        assert square["cornerRadius"] == 0
        assert all(square[s + "BorderWidth"] == 0 for s in ("normal", "focus", "selected"))
        assert square["selectedFillAlpha"] == 0.18
        lua.write_text('hl.config({ decoration = {\n rounding = 6,\n} })\n')
        rounded = g.geometry("parent", home, cache)
        assert rounded["cornerRadius"] == 6
    with patch.object(g, "live_radius", return_value=10):
        live = g.geometry("parent", home, cache)
        assert live["cornerRadius"] == 10
    cache.write_text('[General]\n' + '\n'.join(f'{k}={v}' for k, v in live.items()))
    for mode, uid in ((stat.S_IFREG | 0o666, 0), (stat.S_IFREG | 0o644, 1234), (stat.S_IFLNK | 0o777, 0)):
        with patch.object(Path, "lstat", return_value=SimpleNamespace(st_mode=mode, st_uid=uid)):
            assert g.cached_radius(cache, live["geometryIdentity"]) is None
    with patch.object(g, "live_radius", return_value=None), patch.object(Path, "lstat", return_value=safe_stat):
        assert g.geometry("parent", home, cache)["cornerRadius"] == 10
        assert g.geometry("other-parent", home, cache)["cornerRadius"] == 6
        lua.write_text('hl.config({ decoration = {\n rounding = 0,\n} })\n')
        assert g.geometry("parent", home, cache)["cornerRadius"] == 0
        lua.write_text('rounding = os.execute("do not execute")\n')
        assert g.geometry("parent", home, cache)["cornerRadius"] == 0
        shell.write_text('[controls]\nnormal-border-width=-1\nfocus-border-width=inf\nselected-border-width=true\nselected-fill-alpha=nan\nfocus-color="bad\\nvalue"\n')
        invalid = g.geometry("parent", home, cache)
        assert (invalid["normalBorderWidth"], invalid["focusBorderWidth"], invalid["selectedBorderWidth"]) == (1, 1, 0)
        assert invalid["selectedFillAlpha"] == 0.18 and invalid["focusColor"] == "foreground"
        shell.write_text('[controls]\nnormal-border-width=2\n[style]\nnormal-border-width=3\nhover-cursor-border-width=4\nhover-cursor-fill-alpha=0\n')
        legacy = g.geometry("parent", home, cache)
        assert legacy["normalBorderWidth"] == 3 and legacy["focusBorderWidth"] == 4
        assert legacy["focusFillAlpha"] == 0
        for focus in ("inherit", "hover", "hover-cursor", "invalid"):
            shell.write_text('[controls]\nnormal-color=" TRANSPARENT "\nselected-color="TEXT"\nhover-cursor-color="#12345678"\nfocus-color="' + focus + '"\n')
            colors = g.geometry("parent", home, cache)
            assert colors["normalColor"] == "transparent" and colors["selectedColor"] == "foreground"
            assert colors["focusColor"] == "#12345678"
        for token in ("#abc", "#aabbcc", "#aabbccdd", "text", "foreground", "background", "accent", "urgent", "transparent"):
            assert g.color_token(token.upper()) == ("foreground" if token == "text" else token)
        shell.write_text('[controls]\nnormal-border-width=broken\n')
        assert g.geometry("parent", home, cache)["normalBorderWidth"] == 1
    assert g.literal_radius('--[[\nrounding = 90,\n]]\nrounding = 6, -- theme\n') == 6
    assert g.literal_radius('--[=[\nrounding = 90,\n]=]\nrounding = 6,\n') == 6
    assert g.literal_radius('local text = [[\nrounding = 90,\n]]\nrounding = 6,\n') == 6
    assert g.literal_radius('if false then\nrounding = 6,\nend\n') is None
    assert g.literal_radius('rounding = 6,\nrounding = 7,\n') is None
    assert g.literal_radius('rounding = -1,\n') is None
    assert g.literal_radius('-- rounding = 6,\n') is None
    marker = Path(temp) / "never-execute"
    assert g.literal_radius(f'rounding = os.execute("touch {marker}"),\n') is None
    assert not marker.exists()
    oversized = Path(temp) / "oversized"
    oversized.write_text('x' * 262145)
    assert g.read_text(oversized) == ""
    proc_fixture = Path(temp) / "comm"
    proc_fixture.write_text("Hyprland\n")
    with patch.object(g.os, "fstat", return_value=SimpleNamespace(st_mode=stat.S_IFREG | 0o444, st_size=0)):
        assert g.read_text(proc_fixture) == "Hyprland\n"
    for invalid in (-1, 257, True, float("inf"), float("nan"), "bad"):
        assert g.number(invalid, 9) == 9
    assert g.number(0, 9) == 0
    calls = []
    def query(command, **kwargs):
        calls.append(command)
        assert kwargs["timeout"] == 2 and kwargs["check"]
        assert command[:6] == ["/usr/bin/runuser", "-u", "parent", "--", "/usr/bin/env", "-i"]
        assert "/bin/bash" not in command
        reply = [{"pid": 123, "instance": "owned_123"}] if command[-2:] == ["instances", "-j"] else {"int": 6}
        return SimpleNamespace(stdout=json.dumps(reply))
    owner = SimpleNamespace(pw_uid=1234, pw_dir=str(home))
    with patch.object(g.pwd, "getpwnam", return_value=owner), patch.object(g.os, "geteuid", return_value=0), \
            patch.object(g.subprocess, "run", side_effect=query), patch.object(Path, "stat", return_value=SimpleNamespace(st_uid=1234)), \
            patch.object(g, "read_text", return_value="Hyprland\n"):
        assert g.live_radius("parent", home) == 6 and len(calls) == 2
        assert "HYPRLAND_INSTANCE_SIGNATURE=owned_123" in calls[-1]
        with patch.object(g.subprocess, "run", side_effect=subprocess.TimeoutExpired("hyprctl", 2)):
            assert g.live_radius("parent", home) is None
        with patch.object(Path, "stat", return_value=SimpleNamespace(st_uid=999)):
            assert g.live_radius("parent", home) is None
print("PASS parent geometry: square, rounded, live, matching cache, malformed tokens and owned runtime query")
PY
rc=$?
# node is optional here; without it this check used to abort the whole file
# with "node: command not found" (a fail, not a skip) on any box that has no
# node -- every fresh Arch install, the try-omarchy VM. 2026-09-25.
if command -v node >/dev/null 2>&1; then
  node - "$ROOT/share/sddm-theme/PortalConfig.js" <<'JS' || rc=1
const fs = require('fs');
const vm = require('vm');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8').replace(/^\.pragma library\s*/, ''), context);
for (const value of [undefined, null, '', ' ', true, 'garbage', -1, Infinity, 257]) {
  if (context.geometryNumber(value, 8, 256) !== 8) throw Error('invalid geometry accepted');
}
if (context.geometryNumber('0', 8, 256) !== 0 || context.geometryNumber('6', 0, 256) !== 6) throw Error('valid geometry lost');
for (const [color, channels] of [['transparent', [0, 0, 0, 0]], ['#fff', [1, 1, 1, 1]], ['#ff000080', [1, 0, 0, 128/255]]]) {
  if (JSON.stringify(context.colorChannels(color)) !== JSON.stringify(channels)) throw Error('state color channels changed');
}
if (context.colorChannels('invalid') !== null) throw Error('invalid state color accepted');
const main = fs.readFileSync(process.argv[2].replace('PortalConfig.js', 'Main.qml'), 'utf8');
context.Qt = {rgba: (r, g, b, a) => [r, g, b, a]};
context.controlColor = () => ({r: 1, g: 0, b: 0, a: 0});
context.controlNumber = () => 0.4;
for (const name of ['controlFill', 'controlBorder']) {
  vm.runInContext(main.match(new RegExp('function ' + name + '\\([^]*?\\n    }'))[0], context);
  if (JSON.stringify(context[name]('normal', 1)) !== '[1,0,0,0.4]') throw Error('state alpha must replace source alpha without losing RGB');
}
console.log('PASS QML geometry parser preserves zero and rejects malformed tokens');
JS
else
  echo "SKIP theme-geometry-test.sh: node not found (QML geometry parser check)"
fi
exit "$rc"
