// shell.qml -- the read-only kids-plugins shelf overlay, exec'd from the
// Level 1 launcher's "More apps" tile (SPEC.md R-APPS-7; I-5, I-6; issue #28).
// Live-verified empty on the VM 2026-09-21; docs/plugins.md has what's confirmed and what is not.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // Theme colors/font (docs/theming.md) — see share/qml/KidsTheme.qml.
    KidsTheme { id: theme }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: true

    // --- Inputs (bin/omarchy-kids-session-start sets OMARCHY_KIDS_BAND
    //     on the tile's own exec line) -----------------------------------
    property string band: Quickshell.env("OMARCHY_KIDS_BAND") || ""
    readonly property string pluginsBin: "/usr/bin/omarchy-kids-plugins"
    // Absolute, and not from the environment (AGENTS.md rule 9, review S12).
    readonly property string askBin: "/usr/bin/omarchy-kids-ask"

    // --- Shelf data: `omarchy-kids-plugins shelf --json [--band ...]`,
    //     the same verified-Kids-only filter the panel's own screen
    //     uses -- this overlay never passes --all (I-6: nothing a kid
    //     can Enter on should be anything but installable). -----------
    property var shelf: []
    property int currentIndex: 0
    property bool loaded: false
    property string loadError: ""

    Process {
        id: shelfProcess
        command: root.band.length > 0
            ? [root.pluginsBin, "shelf", "--json", "--band", root.band]
            : [root.pluginsBin, "shelf", "--json"]
        stdout: StdioCollector {
            id: shelfStdout
            onStreamFinished: root.handleShelf(shelfStdout.text)
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && !root.loaded) {
                root.loaded = true
                root.loadError = "Could not load the shelf."
            }
        }
    }

    Component.onCompleted: shelfProcess.running = true

    function handleShelf(text) {
        root.loaded = true
        var parsed = []
        try {
            var data = JSON.parse(text)
            if (Array.isArray(data)) parsed = data
        } catch (e) {
            parsed = []
            root.loadError = "Could not read the shelf."
        }
        root.shelf = parsed
        if (root.currentIndex >= root.shelf.length) {
            root.currentIndex = Math.max(0, root.shelf.length - 1)
        }
    }

    // --- Enter: hand off to the existing Ask flow, then close -----------
    function askForCurrent() {
        if (root.currentIndex < 0 || root.currentIndex >= root.shelf.length) return
        var item = root.shelf[root.currentIndex]
        if (!item || !item.id) return
        Quickshell.execDetached([root.askBin, "app", item.id])
        Qt.quit()
    }

    function moveUp() {
        if (root.currentIndex > 0) root.currentIndex -= 1
    }
    function moveDown() {
        if (root.currentIndex < root.shelf.length - 1) root.currentIndex += 1
    }
    function closeModal() {
        Qt.quit() // Esc: read-only, nothing to undo -- just leave.
    }

    // --- The card ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: theme.dim

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 560
            height: Math.min(parent.height - 96, 640)
            radius: 24
            color: theme.background
            border.color: theme.cardFill
            border.width: 2

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: (event) => { root.closeModal(); event.accepted = true }
                Keys.onUpPressed: (event) => { root.moveUp(); event.accepted = true }
                Keys.onDownPressed: (event) => { root.moveDown(); event.accepted = true }
                Keys.onReturnPressed: (event) => { root.askForCurrent(); event.accepted = true }
                Keys.onEnterPressed: (event) => { root.askForCurrent(); event.accepted = true }

                Column {
                    anchors.fill: parent
                    anchors.margins: 32
                    spacing: 16

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        text: "More apps"
                        color: theme.foreground
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        text: "Pick one, then press Enter to ask a grown-up."
                        color: theme.caption
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }

                    // --- Loading / empty / error states (I-6: never a
                    //     blank screen with no explanation) --------------
                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        visible: !root.loaded
                        text: "Looking for apps to add…"
                        color: theme.caption
                        font.pixelSize: 15
                    }

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        visible: root.loaded && root.loadError.length > 0
                        text: root.loadError
                        color: theme.error
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        visible: root.loaded && root.loadError.length === 0 && root.shelf.length === 0
                        text: "Nothing here yet -- check back later!"
                        color: theme.caption
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }

                    // --- The list --------------------------------------
                    ListView {
                        id: shelfList
                        width: parent.width
                        height: parent.height - 140
                        visible: root.loaded && root.shelf.length > 0
                        model: root.shelf
                        currentIndex: root.currentIndex
                        clip: true
                        spacing: 8
                        interactive: false

                        delegate: Rectangle {
                            width: shelfList.width
                            height: 76
                            radius: 12
                            color: ListView.isCurrentItem ? theme.tileFill : theme.cardFill
                            border.width: ListView.isCurrentItem ? 3 : 0
                            border.color: theme.accent

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 16
                                spacing: 4

                                Text {
                                    font.family: theme.fontFamily
                                    width: parent.width
                                    text: (modelData.name || modelData.id || "")
                                        + (modelData.age ? "  ·  ages " + modelData.age + "+" : "")
                                    color: theme.foreground
                                    font.pixelSize: 16
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    font.family: theme.fontFamily
                                    width: parent.width
                                    text: modelData.description || ""
                                    color: theme.caption
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
