#!/bin/bash
# Tests share/launcher/gridnav.js and shell.qml -- the Level 1/2 launcher
# reads its tiles and fixed argv from the caller-bound session manifest,
# while its key navigation and GridView layout share (issue #43:
# key nav used a hardcoded `columns: 4` while the GridView actually drew
# five tiles per row, so Down from row1/col4 landed on row2/col3 instead
# of row2/col4, and Right from row2/col3 didn't move at all). See
# docs/levels.md.
#
# What this does NOT and cannot check without a real Quickshell/QtQuick
# environment (see share/launcher/shell.qml's own header):
#   - that `import "gridnav.js" as GridNav` really resolves at runtime
#   - that GridView really lays columns out as floor(width/cellWidth)
#   - that grid.width/grid.cellWidth hold the values this assumes at the
#     VM's real 1280x800 resolution
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JS="$DIR/share/launcher/gridnav.js"
QML="$DIR/share/launcher/shell.qml"

fail=0
check() { # got want label
  if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want '$2', got '$1')"
    fail=1
  fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want to find '$2' in '$1')"
    fail=1
  fi
}

if [[ -f "$JS" ]]; then
  echo "ok   share/launcher/gridnav.js exists"
else
  echo "FAIL share/launcher/gridnav.js missing"
  fail=1
fi

qml_content="$(cat "$QML" 2>/dev/null || true)"

check_contains "$qml_content" 'import "gridnav.js" as GridNav' \
  "shell.qml imports gridnav.js"
check_contains "$qml_content" 'GridNav.columnsFor(grid.width, grid.cellWidth)' \
  "shell.qml derives its column count from the GridView's own width/cellWidth, not a hardcoded number"
check_contains "$qml_content" 'GridNav.moveLeft(root.currentIndex, root.tiles.length, root.tileAvailability)' \
  "Left key uses the shared move function and skips unavailable tiles"
check_contains "$qml_content" 'GridNav.moveRight(root.currentIndex, root.tiles.length, root.tileAvailability)' \
  "Right key uses the shared move function and skips unavailable tiles"
check_contains "$qml_content" 'GridNav.moveUp(root.currentIndex, root.columns, root.tiles.length, root.tileAvailability)' \
  "Up key uses the shared move function and skips unavailable tiles"
check_contains "$qml_content" 'GridNav.moveDown(root.currentIndex, root.columns, root.tiles.length, root.tileAvailability)' \
  "Down key uses the shared move function and skips unavailable tiles"
check_contains "$qml_content" 'GridNav.firstAvailable(root.tiles.length, root.tileAvailability)' \
  "a picker that opens on an unavailable tile starts on one that can act"
check_contains "$qml_content" 'readonly property var tileAvailability' \
  "shell.qml builds the availability array the move functions skip on"
check_contains "$qml_content" 'Keys.onReturnPressed' "Return launches the highlighted tile"
check_contains "$qml_content" 'root.launchCurrent()' "Enter/Return calls launchCurrent()"
check_contains "$qml_content" 'command: ["/usr/bin/omarchy-kids-session", "--manifest"]' \
  "launcher reads the caller-bound session manifest"
check_contains "$qml_content" 'root.manifest.tiles || []' \
  "launcher gets tiles from the manifest"
check_contains "$qml_content" 'root.launchInstalled(tile.id || "") !== true' \
  "activation requires the manifest to mark the tile installed"
check_contains "$qml_content" 'launcherProcess.command = argv' \
  "activation passes manifest argv directly to Quickshell Process"
check "$(grep -c 'OMARCHY_KIDS_LAUNCHER_JSON\|OMARCHY_KIDS_LAUNCHER_MAP\|launcherMap' "$QML" || true)" "0" \
  "launcher has no runtime launcher JSON or separate launcher map"
check "$(grep -c 'tile\.exec\|\["sh", "-c"\]' "$QML" || true)" "0" \
  "shell.qml never evaluates a tile-provided shell command"
check "$(grep -c 'tile\.installed' "$QML" || true)" "0" \
  "activation does not trust an unvalidated tile state"
# The line froze live because watchChanges never re-read the file and the
# daemon's rename-replace can drop the watch; the timer is the backstop, and
# it must repeat -- a one-shot would freeze again after 2s.
check_contains "$qml_content" '        Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: timeStatus.reload()
        }' "shell.qml re-reads the time-left status on a repeating 2s timer"
check_contains "$qml_content" 'onFileChanged: reload()' \
  "shell.qml reloads the time-left status on a fileChanged signal"

# issue #43's bug was exactly this: a hardcoded columns count baked into
# the nav's own `%`/`<` comparisons instead of read from the layout.
check "$(grep -c 'property int columns: 4' "$QML" || true)" "0" \
  "shell.qml no longer hardcodes columns: 4"

# --- issue #54: centred grid, derived tile size, icon lookup + fallback ---

check_contains "$qml_content" 'anchors.horizontalCenter: parent.horizontalCenter' \
  "grid is horizontally centred, not left-anchored"
check_contains "$qml_content" 'anchors.top: parent.top' \
  "grid is top-anchored (not anchors.fill, so it sits in the upper part of the screen)"
check_contains "$qml_content" 'readonly property int minTileWidth: 160' \
  "tile width has a 160px floor"
check_contains "$qml_content" 'readonly property int targetColumns: 5' \
  "tile size is derived to fit five per row at the reference width"
check_contains "$qml_content" 'Math.max(minTileWidth, Math.floor(availableWidth / targetColumns))' \
  "cell size is derived from the available screen width, not hardcoded"

# --- the tile label gets the whole tile (live 960x540, 2026-09-22) ---------
# A fixed box -- the tile minus a 16px inset -- truncated ordinary names on the
# live frame: "SuperTux" and "SuperTuxKart" both rendered as "Super...", two
# tiles a six-year-old cannot tell apart by label. The width is now what the
# name needs, capped by what the cell can hold (the tile is cellWidth-20, so
# -28 keeps the text inside it).
check_contains "$qml_content" 'width: Math.min(implicitWidth, grid.cellWidth - 28)' \
  "a tile label takes as much of the cell as its name needs"
check "$(grep -cF 'width: Math.min(implicitWidth, grid.cellWidth - 28)' "$QML")" "2" \
  "both the name and the missing caption use the derived width"
check "$(grep -cF 'width: parent.parent.width - 16' "$QML")" "0" \
  "no tile label is back to the fixed inset box that truncated names"

# Icon lookup: resolved through Quickshell's own icon-theme API (the same
# one omacom/omarchy's shell/services/AppLibrary.qml iconSource() uses),
# with a rounded-initial fallback when nothing resolves -- never a bare
# icon *name* handed to Image.source as a literal path (the old, broken
# behavior this issue replaces).
check_contains "$qml_content" 'Quickshell.iconPath(value, true)' \
  "icon lookup goes through Quickshell.iconPath(), not a literal icon name"
check_contains "$qml_content" 'visible: status === Image.Ready' \
  "the icon Image is hidden whenever nothing actually resolved"
check_contains "$qml_content" 'visible: !iconImg.visible' \
  "the rounded-initial fallback shows exactly when the icon Image did not"
check_contains "$qml_content" 'radius: width / 2' \
  "the icon fallback is a rounded (circular) initial badge"
check_contains "$qml_content" 'color: theme.accent' \
  "the icon fallback badge uses the theme accent colour"
check_contains "$qml_content" 'font.pixelSize: Math.round(iconSize / 2)' \
  "the icon fallback initial scales with the icon slot"
check_contains "$qml_content" 'readonly property int iconSize: Math.max(28, Math.min(64, Math.round(grid.cellHeight * 0.40)))' \
  "the tile content scales with a shrunken cell"

# --- Live review fix: the clock must never overlap the grid -----------
# A live 1280x800/nine-tile screenshot showed the clock (top-right, same
# flat root.margin top inset as the grid) overlapping the fifth tile of
# row one -- a centred five-wide grid reaches close enough to the right
# edge to pass under a top-right clock. Fixed by giving the clock its
# own band above the grid: grid top = clock bottom + margin, i.e. the
# grid's own topMargin must read off clockText's real height, not just
# a flat root.margin shared with the clock (the old, overlapping shape).
check_contains "$qml_content" 'id: clockText' \
  "the clock has an id the grid's own layout can bind to"
check_contains "$qml_content" 'readonly property real topInset: root.margin + clockText.height + root.margin' \
  "grid top = clock bottom (clockText's own root.margin inset + its height) + one more root.margin gap"
check_contains "$qml_content" 'anchors.topMargin: topInset' \
  "the grid anchors below the clock via the shared top inset"
check_contains "$qml_content" 'clip: true' \
  "the grid clips instead of growing past the window"
check_contains "$qml_content" 'readonly property real fitCell: Math.max(root.minFitCell,' \
  "the cell size is height-aware (fitCell), not width-only"
check_contains "$qml_content" 'readonly property int minFitCell: 96' \
  "the shrink has a 96px tap-target floor"
check_contains "$qml_content" 'rowsNeeded: Math.max(1, Math.ceil(root.tiles.length / Math.max(1, root.neededColumns)))' \
  "the row count comes from the same column count the layout uses"
check_contains "$qml_content" 'event.accepted = false' \
  "the launcher refuses a close request (Super+Q cannot blank the Level 1 desktop)"
check "$(grep -c '^[[:space:]]*anchors.topMargin: root.margin$' "$QML" || true)" "2" \
  "clock and desktop-only search box use flat insets; the grid and time-left line do not overlap them"

# Labels in the theme font (docs/theming.md) -- every Text element in the
# every Text/TextInput in shell.qml must set font.family, not rely on Qt's
# platform default.
check "$(grep -c 'font.family: theme.fontFamily' "$QML" || true)" "13" \
  "grid, searchable picker and time-left labels set the theme font"

# No literal colour hex crept into this file (qml-theme-static-test.sh
# checks every share/**/*.qml file; this re-checks just this one inline
# so a regression here fails the test file most directly relevant to it).
check "$(grep -coE '#[0-9A-Fa-f]{6,8}' "$QML" || true)" "0" \
  "shell.qml still has no literal hex colours"

if command -v node >/dev/null 2>&1; then
  out="$(node -e "
    var module = { exports: {} };
    eval(require('fs').readFileSync(process.argv[1], 'utf8'));
    var G = module.exports;
    var results = [];

    // Ten tiles, 800px-wide grid, 160px cells -- five per row, the exact
    // live scenario in the issue.
    var cols = G.columnsFor(800, 160);
    results.push('columns=' + cols);

    // Down from index 3 (row1, 4th tile, 0-indexed col 3) must land on
    // index 8 (row2, 4th tile), not index 7 (row2, 3rd tile) -- the bug.
    results.push('down3=' + G.moveDown(3, cols, 10));

    // Right from index 7 (row2, 3rd tile) must move to index 8, not
    // hold still -- the other half of the bug.
    results.push('right7=' + G.moveRight(7, 10));

    // Right at the very last tile clamps (does not wrap to index 0).
    results.push('right9=' + G.moveRight(9, 10));

    // Left at the very first tile clamps.
    results.push('left0=' + G.moveLeft(0));

    // Left at the first column of row2 (index 5) wraps to the last
    // tile of row1 (index 4), since tiles are laid out row-major.
    results.push('left5=' + G.moveLeft(5));

    // Up at the top row clamps.
    results.push('up2=' + G.moveUp(2, cols));

    // Down at the bottom-right tile (no tile below) clamps.
    results.push('down9=' + G.moveDown(9, cols, 10));

    // A tile whose app is not installed is shown with its honest label but
    // skipped by navigation (I-6): Enter on it could neither launch nor
    // explain. `false` in the availability array marks such a tile.
    var avail = [true, false, true, true, true, true, true, true, false, true];
    results.push('skipRight=' + G.moveRight(0, 10, avail));
    results.push('skipLeft=' + G.moveLeft(2, 10, avail));
    results.push('skipDown=' + G.moveDown(3, cols, 10, avail));
    results.push('downAvail=' + G.moveDown(0, cols, 10, avail));
    var availHead = [false, true, true];
    results.push('firstHead=' + G.firstAvailable(3, availHead));
    var availNone = [false, false, false];
    results.push('firstNone=' + G.firstAvailable(3, availNone));
    results.push('holdNone=' + G.moveRight(0, 3, availNone));
    results.push('legacyRight=' + G.moveRight(0, 3));

    // columnsFor() never returns 0 or a negative number, even for
    // degenerate (not-yet-laid-out) width/cellWidth values -- avoids a
    // divide-by-zero-shaped bug the moment shell.qml starts up before
    // GridView has a real width.
    results.push('cols0=' + G.columnsFor(0, 160));
    results.push('colsNeg=' + G.columnsFor(800, 0));

    var choices = [{id: 'paint', label: 'Tux Paint', argv: ['/safe/paint']},
                   {id: 'math', label: 'GCompris', argv: ['/safe/math']},
                   {id: 'missing', label: 'Missing App', installed: false}];
    var found = G.filterTiles(choices, ' gCoM ');
    if (found.length !== 1 || found[0] !== choices[1]) throw Error('filter lost stable entry identity');
    if (G.filterTiles(choices, 'unknown').length !== 0) throw Error('filter invented a match');
    if (G.filterTiles(choices, '').length !== 3) throw Error('reopening should restore choices');
    if (G.filterTiles(choices, 'missing')[0].installed !== false) throw Error('missing state lost');

    // remainingLabel: the kid-visible time left, display only.
    if (G.remainingLabel(1800) !== '30 minutes left') throw Error('remainingLabel(1800)');
    if (G.remainingLabel(61) !== '2 minutes left') throw Error('remainingLabel rounds up');
    if (G.remainingLabel(60) !== '1 minute left') throw Error('remainingLabel singular');
    if (G.remainingLabel(0) !== '') throw Error('remainingLabel(0)');
    if (G.remainingLabel(-1) !== '') throw Error('remainingLabel(-1)');
    if (G.remainingLabel(NaN) !== '') throw Error('remainingLabel(NaN)');
    if (G.remainingLabel('60') !== '') throw Error('remainingLabel rejects strings');
    console.log(results.join(' '));
  " "$JS" 2>&1)"
  check "$out" "columns=5 down3=8 right7=8 right9=9 left0=0 left5=4 up2=2 down9=9 skipRight=2 skipLeft=0 skipDown=3 downAvail=5 firstHead=1 firstNone=0 holdNone=0 legacyRight=1 cols0=1 colsNeg=1" \
    "gridnav.js index math matches issue #43's live scenario (node)"
  check_contains "$qml_content" "readonly property string timeStatusPath" \
    "shell.qml reads root's time state path (docs/time.md)"
  check_contains "$qml_content" "GridNav.remainingLabel(root.remainingSeconds)" \
    "shell.qml renders GridNav.remainingLabel"
  check_contains "$qml_content" 'timeLeft: GridNav.remainingLabel(root.remainingSeconds)' \
    "shell.qml passes the label into the Level 2 desktop"
else
  echo "SKIP gridnav.js index-math check: node not found"
fi

# Live 2026-09-22 (960x540): the centred picker window reached within a few
# pixels of the desktop's own bottom hint line and sliced its top half into
# broken glyphs; the desktop hides that line while the picker is open. These
# three greps need no node, so they run even where the JS check above skips.
desktop_content="$(cat "$DIR/share/launcher/Desktop.qml" 2>/dev/null || true)"
check_contains "$desktop_content" 'property bool pickerOpen' \
  "Desktop.qml takes a pickerOpen flag"
check_contains "$qml_content" 'pickerOpen: root.pickerOpen' \
  "shell.qml tells the Level 2 desktop when its picker is open"
# Pin the binding to the hint line itself: moving it onto another Text must
# not satisfy this (the sliced line would come back).
if grep -A2 -F 'visible: !desktop.pickerOpen' "$DIR/share/launcher/Desktop.qml" 2>/dev/null |
  grep -qF 'Super + Q: Close app'; then
  echo "ok   Desktop.qml hides the bottom hint line itself while the picker covers it"
else
  echo "FAIL Desktop.qml: the pickerOpen binding is not on the bottom hint line"
  fail=1
fi

exit $fail
