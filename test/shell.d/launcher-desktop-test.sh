#!/bin/bash
# Tests the Level 2 picker and launcher control (R-DESK-3, R-BAND-2, I-3, I-5).
# Runs actual QML functions with owned process/window stubs; compositor rendering is a live gate.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if ! command -v node >/dev/null 2>&1; then
  echo "SKIP launcher-desktop-test: node is required"
  exit 0
fi
node - "$DIR" "$(command -v bash)" <<'JS'
const fs = require('fs'), os = require('os'), path = require('path'), vm = require('vm');
const assert = require('assert/strict'), child = require('child_process');
const dir = process.argv[2], bash = process.argv[3];
const source = fs.readFileSync(path.join(dir, 'share/launcher/shell.qml'), 'utf8');
const desktopSource = fs.readFileSync(path.join(dir, 'share/launcher/Desktop.qml'), 'utf8');
assert.match(desktopSource, /Super \+ Shift \+ K: Grown-up exit/,
  'the Level 2 footer must name the grown-up exit, not the Ask modal');
assert.doesNotMatch(desktopSource, /Ask a grown-up/,
  'the Level 2 footer must not reuse the Ask modal name for the exit bind');
const nav = require(path.join(dir, 'share/launcher/gridnav.js'));
const entries = [
  { id: 'paint', label: 'Tux Paint', installed: true, argv: ['/approved/paint'] },
  { id: 'math', label: 'GCompris', installed: true, argv: ['/approved/math', '--safe'] },
  { id: 'missing', label: 'Not installed', installed: false, argv: [] }
];
const launches = [];
const root = { manifest: { account: 'kid-ada', level: 2, tiles: entries }, desktopMode: true,
  currentIndex: 0, pickerOpen: false, requestActivate() {} };
Object.defineProperty(root, "visible", {get() { return this.pickerOpen; }});
const searchInput = { text: 'old query', forceActiveFocus() {} };
const launcherProcess = { command: [], startDetached() { launches.push(this.command.slice()); } };
const context = { root, launcherProcess, logProcess: {}, searchInput,
  keyScope: { forceActiveFocus() {} }, focusTimer: { restart() {} } };
function bind(name) {
  const start = source.indexOf('        function ' + name + '(');
  assert(start >= 0, 'missing QML function ' + name);
  const end = source.indexOf('\n        }', start);
  assert(end > start, 'unterminated QML function ' + name);
  root[name] = vm.runInNewContext('(' + source.slice(start, end + 10).trim() + ')', context);
}
for (const name of ['launchEntry', 'launchInstalled', 'launchArgv', 'dismissPicker', 'showPicker', 'launchCurrent']) bind(name);
root.showPicker();
assert.equal(root.visible, true);
assert.equal(searchInput.text, '');
root.tiles = nav.filterTiles(entries, 'gcom');
root.launchCurrent();
assert.deepEqual(launches[0], entries[1].argv, 'filtered first row must launch its stable ID, not unfiltered index zero');
assert.equal(root.visible, false, 'successful choice hides picker');
root.showPicker();
root.tiles = nav.filterTiles(entries, 'paint');
root.launchCurrent();
assert.equal(launches.length, 2, 'second app gets its own detached launch');
assert.deepEqual(launches[1], entries[0].argv);
root.showPicker();
root.tiles = nav.filterTiles(entries, 'not installed');
root.launchCurrent();
assert.equal(launches.length, 2, 'missing app never executes');
assert.equal(root.visible, true, 'missing app remains in the picker');
root.tiles = [];
root.launchCurrent();
assert.equal(launches.length, 2, 'empty search never executes');
root.dismissPicker();
assert.equal(root.visible, false);
root.showPicker();
assert.equal(root.visible, true, 'Escape then reopen works repeatedly');
root.desktopMode = false;
root.dismissPicker();
assert.equal(root.visible, true, 'youngest grid cannot be dismissed with Escape');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kids-desktop-control-'));
try {
  const ctl = path.join(temp, 'ctl'), control = path.join(temp, 'control'), log = path.join(temp, 'hyprctl.log');
  let script = fs.readFileSync(path.join(dir, 'bin/omarchy-kids-launcher-ctl'), 'utf8');
  script = script.replace(/^CONTROL=.*$/m, 'CONTROL=' + JSON.stringify(control));
  fs.writeFileSync(ctl, script);
  fs.writeFileSync(path.join(temp, 'hyprctl'), '#!/bin/bash\nprintf "%s\\n" "$@" >>' + JSON.stringify(log) + '\nexit 0\n', {mode: 0o755});
  const env = {...process.env, PATH: temp + ':' + process.env.PATH};
  function show() {
    const result = child.spawnSync(bash, [ctl, 'show'], {env, encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    return fs.readFileSync(control, 'utf8');
  }
  const first = show(), second = show();
  assert.match(first, /^show /);
  assert.notEqual(first, second, 'two show commands need distinct control text');
  const focusArgs = ['dispatch', 'hl.dsp.focus({window="title:^Omarchy Kids Launcher$"})'];
  assert.equal(fs.readFileSync(log, 'utf8'), focusArgs.join('\n') + '\n' + focusArgs.join('\n') + '\n',
    'show passes a dispatcher object to dispatch without calling it');
  const focusProcess = source.match(/id: focusProcess\s+command: (\[[^\n]+\])/);
  assert(focusProcess, 'QML focus fallback command exists');
  const focusCommand = Array.from(vm.runInNewContext(focusProcess[1]));
  assert.deepEqual(focusCommand, ['/usr/bin/hyprctl', ...focusArgs],
    'QML retry uses the same supported dispatcher argv as show');
} finally { fs.rmSync(temp, {recursive: true, force: true}); }
console.log('PASS launcher desktop: filtered identity, missing/empty choices, two launches, Escape/reopen, owned show control');
JS
