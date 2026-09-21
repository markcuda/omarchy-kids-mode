// shell.qml -- the Level 1 app grid and Level 2 desktop/picker. Reads the caller-bound
// session manifest (SPEC.md R-DESK-3, R-DESK-5, R-MANIFEST-5; I-3, I-5, I-6).
// See docs/levels.md "Open questions" #5 for the Quickshell API guesses still to confirm.

import QtQuick
import Quickshell
import Quickshell.Io
import "gridnav.js" as GridNav

ShellRoot {
    Window {
        id: root

        // Theme colors/font (docs/theming.md) — every literal hex below has
        // been replaced by a `theme.*` reference; see share/qml/KidsTheme.qml
        // for where these come from and why this file can't `import
        // qs.Commons` directly.
        KidsTheme { id: theme }

        // A stable, plain-QtQuick-`Window.title` is what
        // bin/omarchy-kids-launcher-ctl matches using `hyprctl dispatch` and
        // `hl.dsp.focus({window=...})` — keep this string in sync with that
        // script if it ever changes.
        title: "Omarchy Kids Launcher"
        property bool pickerOpen: false
        visibility: !root.pickerOpen ? Window.Hidden : (root.desktopMode ? Window.Windowed : Window.FullScreen)
        flags: Qt.Window | Qt.FramelessWindowHint
        width: root.desktopMode ? Math.min(720, root.screen ? root.screen.width - 64 : 720) : 640
        height: root.desktopMode ? Math.min(560, root.screen ? root.screen.height - 80 : 560) : 480
        color: theme.background

        // --- Tile data -----------------------------------------------------
        // The validated manifest is the only source for display and launch data.
        property var manifest: ({})
        readonly property bool desktopMode: root.manifest.level === 2
        readonly property var tiles: desktopMode ? GridNav.filterTiles(root.manifest.tiles || [], searchInput.text)
                                               : (root.manifest.tiles || [])
        // Parallel to `tiles`: true when the tile can act. A tile whose app is
        // not installed stays visible with its honest label, but navigation
        // must skip it -- a control that cannot act must not take the focus
        // ring and swallow Enter (I-6). `launchInstalled` returns null for an
        // unknown id; that is not `false`, so it stays navigable.
        readonly property var tileAvailability: {
            var list = root.tiles
            var out = []
            for (var i = 0; i < list.length; i++) {
                out.push(root.launchInstalled((list[i] && list[i].id) || "") !== false)
            }
            return out
        }
        onTilesChanged: {
            if (!GridNav.navigable(root.tileAvailability, root.currentIndex)) {
                root.currentIndex = GridNav.firstAvailable(root.tiles.length, root.tileAvailability)
            }
        }

        function showPicker() {
            if (!root.manifest.account) return
            searchInput.text = ""
            root.currentIndex = GridNav.firstAvailable(root.tiles.length, root.tileAvailability)
            root.pickerOpen = true
            root.requestActivate()
            root.focusTries = 0
            focusTimer.restart()
            if (root.desktopMode) searchInput.forceActiveFocus()
            else keyScope.forceActiveFocus()
        }

        property int focusTries: 0
        Process {
            id: focusProcess
            command: ["/usr/bin/hyprctl", "dispatch", 'hl.dsp.focus({window="title:^Omarchy Kids Launcher$"})']
        }
        Timer {
            id: focusTimer
            interval: 100
            repeat: true
            onTriggered: {
                if (!root.visible || root.active || ++root.focusTries > 10) { stop(); return }
                if (!focusProcess.running) focusProcess.running = true
            }
        }

        function dismissPicker() {
            if (root.desktopMode) root.pickerOpen = false
        }

        onClosing: (event) => {
            // The launcher is the whole desktop in Level 1: if the same
            // Super+Q that closes an app can also close it, a kid ends up on
            // a blank screen with no way back (live finding, 2026-09-21).
            // Refuse in both modes; desktop mode also folds the picker away.
            // The exit modal and the session's own end remain the ways out.
            event.accepted = false
            if (root.desktopMode) root.dismissPicker()
        }
        // issue #43: this used to be a hardcoded `4` that drifted out of
        // sync with what GridView actually renders (five columns, seen live
        // with ten tiles). Derived here from the exact same inputs --
        // grid.width and grid.cellWidth -- GridView itself uses to lay tiles
        // out, via the shared pure function in gridnav.js, so key navigation
        // and the rendered layout can never disagree on column count again.
        readonly property int columns: root.desktopMode ? 1 : GridNav.columnsFor(grid.width, grid.cellWidth)
        property int currentIndex: 0

        // --- Grid layout (issue #54) -----------------------------------------
        // Live at 1280x800: two tiles sat top-left with the rest of the
        // screen empty, and ten tiles filled only the top third -- GridView
        // was anchored top-left, full-width, with a hardcoded 160px cell.
        // margin is one number so the grid's left/right/top edges and the
        // clock's top-right position (below) share the exact same inset.
        // targetColumns/minTileWidth is the "five per row at 1280, tile
        // width derived, min 160px" rule from the issue: cellSize is
        // whatever width fits five tiles in the space left after margin on
        // each side, floored at minTileWidth, so a bigger screen gets bigger
        // tiles (not just more of them) and a narrower one falls back to
        // fewer than five per row -- grid.width below (columns actually
        // rendered * cellSize) drives GridNav.columnsFor() the same way it
        // always has, so this never disagrees with itself.
        // A 960x540 live frame (review, 2026-09-21) showed the second row of
        // tiles hugging the bottom edge with a large empty band under the
        // clock. Short screens keep the flat-inset shape but spend less of
        // their height on it, so both rows and their rings fit.
        readonly property int margin: root.desktopMode ? 24 : (root.height < 640 ? 32 : 56)
        readonly property int minTileWidth: 160
        // The floor the grid may shrink a cell to when the screen is short;
        // 96px is the tap-target minimum the launcher comments cite. Below it
        // the grid clips rather than shrinking further.
        readonly property int minFitCell: 96
        readonly property int targetColumns: 5
        readonly property real availableWidth: Math.max(minTileWidth, root.width - margin * 2)
        readonly property int cellSize: Math.max(minTileWidth, Math.floor(availableWidth / targetColumns))
        // How many columns the grid itself should be exactly as wide as --
        // never more than targetColumns, and never more than there are
        // tiles to show (so two tiles sit in a small, centred 2-wide grid
        // instead of a full-width one with empty space to their right, the
        // live "two tiles top-left, the rest empty" screenshot this issue
        // is fixing).
        readonly property int neededColumns: Math.max(1, Math.min(targetColumns, tiles.length))

        // iconSource ICON -> a themed icon file/URL for a freedesktop
        // Icon= value, or "" if nothing resolves. Same shape as the real
        // Omarchy shell's own launcher icon lookup --
        // shell/services/AppLibrary.qml's iconSource() (omacom/omarchy
        // @v4.0.2, commit 346e69e1cec6c4e8924531874af6ba010a1bc99e): an
        // already-literal file://, image://, or absolute-path source is
        // used as-is; otherwise Quickshell.iconPath(name, true) resolves the
        // name through the active icon theme, the same call that file makes.
        // Unlike that file, an unresolved name here returns "" rather than
        // falling back to a generic "application-x-executable" glyph -- the
        // delegate below draws a rounded initial instead (I-6: no icon
        // resolving isn't hidden behind a placeholder that looks like one).
        function iconSource(icon) {
            var value = String(icon || "")
            if (value.length === 0) return ""
            if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
            if (value.charAt(0) === "/") return "file://" + value
            return Quickshell.iconPath(value, true)
        }

        Process {
            id: manifestProcess
            command: ["/usr/bin/omarchy-kids-session", "--manifest"]
            running: true
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: root.reloadManifest(String(text || ""))
            }
        }

        function reloadManifest(raw) {
            try {
                var data = JSON.parse(raw)
                if (data && data.tiles) {
                    root.manifest = data
                } else {
                    root.manifest = ({})
                }
            } catch (e) {
                root.manifest = ({})
            }
            root.pickerOpen = root.manifest.level === 1
            if (!GridNav.navigable(root.tileAvailability, root.currentIndex)) {
                root.currentIndex = GridNav.firstAvailable(root.tiles.length, root.tileAvailability)
            }
        }

        function launchEntry(id) {
            var entries = root.manifest.tiles || []
            for (var i = 0; i < entries.length; i++) {
                if (entries[i] && entries[i].id === id) return entries[i]
            }
            return null
        }

        function launchInstalled(id) {
            var entry = root.launchEntry(id)
            return entry ? entry.installed === true : null
        }

        function launchArgv(id) {
            var entry = root.launchEntry(id)
            if (!entry || !Array.isArray(entry.argv) || entry.argv.length === 0) return []
            for (var i = 0; i < entry.argv.length; i++) {
                if (typeof entry.argv[i] !== "string" || entry.argv[i].length === 0) return []
            }
            if (entry.argv[0].charAt(0) !== "/") return []
            return entry.argv
        }

        // The existing control file accepts show as well as activate, so a
        // hidden desktop picker can reopen without a second launcher process.
        property string lastControlText: ""

        FileView {
            id: controlFile
            path: (Quickshell.env("OMARCHY_KIDS_LAUNCHER_CONTROL") || (Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-kids/launcher-control"))
        }

        // Root's published time state, read-only: the launcher shows the
        // minutes root says are left and never computes or enforces them
        // (docs/time.md). Hidden in grace, where Time's Up takes over.
        readonly property string timeStatusPath: "/run/omarchy-kids/time/" + (root.manifest.account || "") + ".json"
        property int remainingSeconds: -1

        FileView {
            id: timeStatus
            path: root.manifest.account ? root.timeStatusPath : ""
            watchChanges: true
            printErrors: false
            onLoaded: root.readTimeStatus()
            onTextChanged: root.readTimeStatus()
        }

        function readTimeStatus() {
            var status
            try {
                status = JSON.parse(timeStatus.text())
            } catch (error) {
                root.remainingSeconds = -1
                return
            }
            if (!status || (status.state !== "allowed" && status.state !== "warning")) {
                root.remainingSeconds = -1
                return
            }
            root.remainingSeconds = Number(status.remaining_seconds)
        }

        Timer {
            interval: 150
            running: true
            repeat: true
            onTriggered: {
                controlFile.reload()
                var text = (controlFile.text() || "").trim()
                if (text.length > 0 && text !== root.lastControlText) {
                    root.lastControlText = text
                    // First word is the command; omarchy-kids-launcher-ctl
                    // appends a nonce so the same command can fire twice in
                    // a row without this file having to truncate the
                    // control file back to empty itself.
                    var command = text.split(/\s+/)[0]
                    if (command === "show") root.showPicker()
                    else if (command === "activate" && root.visible) root.launchCurrent()
                }
            }
        }

        // --- Launching a tile -------------------------------------------------
        Process {
            id: launcherProcess
            onExited: running = false
        }

        // R-DATA-1 (issue #27): fire-and-forget record of "a tile was
        // opened", one line per launch, via the kid-writable half of the
        // launch log (bin/omarchy-kids-launcher-ctl's own header explains
        // why this can't just write the root-owned log directly -- I-3).
        // Never allowed to affect the real launch above/below: a failure
        // here is invisible to the kid either way, same as launcherProcess
        // itself never surfaces an error.
        Process {
            id: logProcess
            onExited: running = false
        }

        function launchCurrent() {
            if (root.currentIndex < 0 || root.currentIndex >= root.tiles.length) return
            var tile = root.tiles[root.currentIndex]
            if (!tile) return
            // Unavailable applications stay honest and inert; the manifest is
            // already the root-validated source of their installed state.
            if (root.launchInstalled(tile.id || "") !== true) return
            var argv = root.launchArgv(tile.id || "")
            if (argv.length === 0) return
            logProcess.command = ["/usr/bin/omarchy-kids-launcher-ctl", "log", tile.id || ""]
            logProcess.running = true
            launcherProcess.command = argv
            if (root.desktopMode) {
                launcherProcess.startDetached()
                root.dismissPicker()
            } else {
                launcherProcess.running = true
            }
        }

        // --- Keyboard navigation (I-5: keyboard-complete) --------------------
        // Plain arrows/Return/Escape, handled entirely inside this app while
        // it has focus -- no Hyprland bind needed for these (Appendix E does
        // not list plain arrow keys for Level 1; Super+arrows at Level 2 is a
        // separate, window-focus feature in share/hyprland/L2.lua).
        FocusScope {
            id: keyScope
            anchors.fill: parent
            focus: true

            // issue #43: index math lives in gridnav.js, not here, so it's
            // one shared implementation instead of four inline expressions
            // that can each drift from the layout (and from each other)
            // independently. Left/Right wrap to the previous/next row --
            // clamping only at the very first/last tile -- since tiles are
            // laid out row-major and index+/-1 already crosses a row
            // boundary correctly on its own; see gridnav.js's header for
            // why that's the design, not a shortcut. Up/Down clamp at the
            // top/bottom edge (including a ragged last row) rather than
            // jumping to some other tile.
            Keys.onLeftPressed: (event) => {
                root.currentIndex = GridNav.moveLeft(root.currentIndex, root.tiles.length, root.tileAvailability)
                event.accepted = true
            }
            Keys.onRightPressed: (event) => {
                root.currentIndex = GridNav.moveRight(root.currentIndex, root.tiles.length, root.tileAvailability)
                event.accepted = true
            }
            Keys.onUpPressed: (event) => {
                root.currentIndex = GridNav.moveUp(root.currentIndex, root.columns, root.tiles.length, root.tileAvailability)
                event.accepted = true
            }
            Keys.onDownPressed: (event) => {
                root.currentIndex = GridNav.moveDown(root.currentIndex, root.columns, root.tiles.length, root.tileAvailability)
                event.accepted = true
            }
            Keys.onReturnPressed: (event) => { root.launchCurrent(); event.accepted = true }
            Keys.onEnterPressed: (event) => { root.launchCurrent(); event.accepted = true }
            // Escape returns to the Level 2 desktop; the youngest grid stays open.
            Keys.onEscapePressed: (event) => { root.dismissPicker(); event.accepted = true }

            // issue #54: centred in the upper part of the screen, not
            // anchors.fill -- width is exactly as many cells as fit (never
            // the full window width, so it centres instead of hugging the
            // left edge with two tiles), and height is exactly as many rows
            // as the tile count needs (never the full window height, so
            // this sits in the upper third with the rest of the screen
            // empty below it, matching the issue's live screenshots).
            //
            // Live at 1280x800 with nine tiles: the clock (top-right, same
            // root.margin top inset as the grid) overlapped the fifth tile
            // of the first row -- both sat in the same horizontal band, and
            // a centred five-wide grid reaches close enough to the right
            // edge to pass under it. Fixed by giving the clock its own band
            // above the grid instead: grid top = clock bottom + margin
            // (clockText's own top inset, root.margin, plus its height,
            // plus one more root.margin gap before the grid starts) --
            // never just root.margin on its own, so there is no width past
            // which the two can touch, regardless of tile count.
            Rectangle {
                id: searchBox
                visible: root.desktopMode
                anchors.top: parent.top
                anchors.topMargin: root.margin
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(720, root.availableWidth)
                height: 60
                radius: 12
                color: theme.inputFill
                border.color: theme.accent
                border.width: 2

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 16
                    color: theme.foreground
                    font.family: theme.fontFamily
                    font.pixelSize: 22
                    clip: true
                    selectByMouse: true
                    onTextChanged: root.currentIndex = GridNav.firstAvailable(root.tiles.length, root.tileAvailability)
                    Keys.onUpPressed: (event) => { root.currentIndex = GridNav.moveUp(root.currentIndex, root.columns, root.tiles.length, root.tileAvailability); event.accepted = true }
                    Keys.onDownPressed: (event) => { root.currentIndex = GridNav.moveDown(root.currentIndex, root.columns, root.tiles.length, root.tileAvailability); event.accepted = true }
                    Keys.onReturnPressed: (event) => { root.launchCurrent(); event.accepted = true }
                    Keys.onEnterPressed: (event) => { root.launchCurrent(); event.accepted = true }
                    Keys.onEscapePressed: (event) => { root.dismissPicker(); event.accepted = true }
                    Text {
                        visible: searchInput.text.length === 0
                        text: "Find an app…"
                        color: theme.caption
                        font: searchInput.font
                    }
                }
            }

            Text {
                visible: root.desktopMode && root.tiles.length === 0
                anchors.top: searchBox.bottom
                anchors.topMargin: 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No matching apps. Try another name."
                color: theme.foreground
                font.family: theme.fontFamily
                font.pixelSize: 20
            }

            ListView {
                id: appList
                visible: root.desktopMode
                anchors { top: searchBox.bottom; left: parent.left; right: parent.right; bottom: pickerHelp.top; margins: root.margin }
                clip: true
                spacing: 8
                model: root.tiles
                currentIndex: root.currentIndex
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    readonly property bool missing: root.launchInstalled(modelData.id || "") === false
                    width: appList.width
                    height: 68
                    radius: 10
                    color: ListView.isCurrentItem ? theme.tileFill : theme.cardFill
                    border.width: ListView.isCurrentItem ? 2 : 0
                    border.color: theme.accent
                    opacity: missing ? 0.6 : 1
                    Image {
                        id: rowIcon
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                        width: 40
                        height: 40
                        source: root.iconSource(modelData.icon)
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.centerIn: rowIcon
                        visible: rowIcon.status !== Image.Ready
                        text: String(modelData.label || modelData.id || "?").charAt(0).toUpperCase()
                        color: theme.accent
                        font.family: theme.fontFamily
                        font.pixelSize: 26
                    }
                    Column {
                        anchors { left: rowIcon.right; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
                        Text {
                            width: parent.width
                            text: modelData.label || modelData.id || ""
                            color: theme.foreground
                            font.family: theme.fontFamily
                            font.pixelSize: 20
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: missing
                            text: "Not installed yet"
                            // Live review: 14px low-contrast grey was unreadable
                            // for a kid or a parent behind them; the label stays
                            // secondary but legible.
                            color: theme.foreground
                            opacity: 0.75
                            font.family: theme.fontFamily
                            font.pixelSize: 16
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.currentIndex = index; root.launchCurrent() }
                    }
                }
            }
            Text {
                id: pickerHelp
                visible: root.desktopMode
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 20 }
                text: "↑ ↓ Choose    Enter Open    Esc Back"
                color: theme.caption
                font.family: theme.fontFamily
                font.pixelSize: 16
            }

            // Level 1 has no search and no Escape; the footer says only what
            // the keys do (I-5) and hides when there is nothing to open.
            Text {
                id: gridHelp
                z: 1
                visible: !root.desktopMode && root.tiles.length > 0
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 20 }
                text: "↑ ↓ ← → Choose    Enter Open"
                color: theme.caption
                font.family: theme.fontFamily
                font.pixelSize: 16
            }

            // An empty manifest must say so, not show a blank window.
            Text {
                id: emptyGrid
                visible: !root.desktopMode && root.tiles.length === 0
                anchors.centerIn: parent
                text: "Nothing is set up here yet.\nAsk a grown-up for help."
                color: theme.caption
                font.family: theme.fontFamily
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
            }

            GridView {
                id: grid
                visible: !root.desktopMode
                // The grid never grows past the room below the clock/time-left
                // line and above the key-hint footer: a tall pack must scroll,
                // not hide a selected tile off-screen (review B4).
                // A short screen (the live 875x492 / 960x540 frames) cannot fit
                // two full-size rows: the cell shrinks to fit the rows into the
                // height left below the clock/time-left line and above the
                // footer, down to the tap-target floor, instead of clipping the
                // last row and letting the footer overlap it (live finding).
                readonly property real topInset: root.margin + clockText.height + root.margin +
                    (timeLeftText.visible ? timeLeftText.height + 8 : 0)
                readonly property real bottomInset: gridHelp.visible ? gridHelp.height + 40 : root.margin
                readonly property int rowsNeeded: Math.max(1, Math.ceil(root.tiles.length / Math.max(1, root.neededColumns)))
                readonly property real fitCell: Math.max(root.minFitCell,
                    Math.min(root.cellSize, Math.floor((parent.height - topInset - bottomInset) / rowsNeeded)))
                readonly property real rowsHeight: rowsNeeded * cellHeight
                anchors.top: parent.top
                anchors.topMargin: topInset
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(root.availableWidth, cellWidth * root.neededColumns)
                height: Math.min(rowsHeight,
                    Math.max(cellHeight, parent.height - topInset - bottomInset))
                clip: true
                cellWidth: fitCell
                cellHeight: fitCell
                model: root.tiles
                currentIndex: root.currentIndex
                interactive: false

                delegate: Rectangle {
                    // Missing applications stay visible and carry their honest
                    // "not installed yet" label, but navigation skips them
                    // (root.tileAvailability): a control that cannot launch must
                    // not take the focus ring and swallow Enter (I-6).
                    readonly property bool missing: root.launchInstalled(modelData.id || "") === false
                    // issue #54: the resolved icon source, or "" -- an
                    // empty Image source (Image.Null) never reaches
                    // Image.Ready, so the rounded-initial fallback below
                    // shows automatically with no extra branching here.
                    readonly property string resolvedIcon: root.iconSource(modelData.icon)
                    readonly property string initial: {
                        var s = String(modelData.label || modelData.id || "?").trim()
                        return s.length > 0 ? s.charAt(0).toUpperCase() : "?"
                    }
                    // A short screen shrinks the cell (grid.fitCell); the tile
                    // content scales with it so the icon+label column never
                    // spills past the tile and collides with the row below
                    // (live 875x492 finding).
                    readonly property int iconSize: Math.max(28, Math.min(64, Math.round(grid.cellHeight * 0.40)))
                    readonly property int labelSize: Math.max(11, Math.min(18, Math.round(grid.cellHeight * 0.15)))

                    // issue #54: derived from the shared cell size (min
                    // 160px per the issue), inset from the cell itself so
                    // adjacent tiles never touch -- still comfortably over
                    // the 96px tap-target floor even at the smallest cell.
                    width: grid.cellWidth - 20
                    height: grid.cellHeight - 20
                    // Nothing the shrunken layout cannot fit may paint outside
                    // the tile and collide with its neighbours (live 875x492).
                    clip: true
                    radius: 16
                    color: missing ? theme.background : (GridView.isCurrentItem ? theme.tileFill : theme.cardFill)
                    // Dimmed enough to read as unavailable, not so much that its
                    // honest label stops being legible (review, 2026-09-21).
                    opacity: missing ? 0.75 : 1.0
                    // Highlight ring in the theme accent (docs/theming.md) --
                    // only the current tile gets a border at all.
                    border.width: GridView.isCurrentItem ? 4 : 0
                    border.color: theme.accent

                    Column {
                        anchors.centerIn: parent
                        spacing: Math.max(4, Math.round(grid.cellHeight * 0.05))

                        Item {
                            id: iconSlot
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: iconSize
                            height: iconSize

                            Image {
                                id: iconImg
                                anchors.fill: parent
                                source: resolvedIcon
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            // issue #54: no icon resolved through
                            // Quickshell.iconPath() (a fresh install not yet
                            // in the icon theme cache, a bad Icon= name, or
                            // no Icon= at all) -- a rounded initial in the
                            // theme accent colour instead of a broken-image
                            // glyph or empty space, so every tile still
                            // looks intentional (I-6).
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: theme.accent
                                visible: !iconImg.visible

                                Text {
                                    anchors.centerIn: parent
                                    text: initial
                                    color: theme.background
                                    font.family: theme.fontFamily
                                    // Scaled with the icon slot (a short
                                    // screen's cell is smaller than 64px): the
                                    // initial stays at roughly half the slot.
                                    font.pixelSize: Math.round(iconSize / 2)
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label || modelData.id || ""
                            color: theme.foreground
                            font.family: theme.fontFamily
                            font.pixelSize: labelSize
                            elide: Text.ElideRight
                            // One line when the cell is short, two otherwise:
                            // the name and the missing caption together must
                            // fit the tile (live 875x492).
                            maximumLineCount: grid.cellHeight < 150 ? 1 : 2
                            wrapMode: Text.WordWrap
                            width: parent.parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // The manifest does not make an unavailable app look runnable.
                        // Live review: 12px low-contrast grey was unreadable; still
                        // secondary, now legible.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: missing
                            text: "not installed yet"
                            color: theme.foreground
                            opacity: 0.75
                            font.family: theme.fontFamily
                            font.pixelSize: Math.max(10, labelSize - 4)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            width: parent.parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        // --- Clock ---------------------------------------------------------
        // issue #54 (live review fix): id: clockText so the grid above can
        // bind its own top margin to clockText.height -- the clock gets its
        // own band above the grid (grid top = clock bottom + margin)
        // instead of sharing the grid's top inset, which overlapped the
        // fifth tile of row one in the live 1280x800/nine-tile screenshot.
        Text {
            id: clockText
            visible: !root.desktopMode
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: root.margin
            anchors.rightMargin: root.margin
            color: theme.foreground
            font.family: theme.fontFamily
            font.pixelSize: 28
            text: Qt.formatTime(new Date(), "hh:mm")

            Timer {
                interval: 15000
                running: true
                repeat: true
                onTriggered: parent.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }

        // Kids learn the time left here, not only from toasts (docs/time.md).
        Text {
            id: timeLeftText
            readonly property string label: GridNav.remainingLabel(root.remainingSeconds)
            visible: !root.desktopMode && label !== ""
            anchors.top: clockText.bottom
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: root.margin
            color: root.remainingSeconds <= 300 ? theme.warning : theme.caption
            font.family: theme.fontFamily
            font.pixelSize: 16
            text: label
        }
    }
    Desktop {
        visible: root.desktopMode
        clock: clockText.text
        timeLeft: GridNav.remainingLabel(root.remainingSeconds)
        onAppsRequested: root.showPicker()
    }
}
