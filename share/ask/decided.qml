// decided.qml -- the kid-facing result card (SPEC.md R-NOTIFY-6, Appendix A K7).
// omarchy-kids-ask watch names the root-written decision file in
// OMARCHY_KIDS_ASK_DECISION; one Enter (or Esc, or ten seconds) closes it. The
// file is the only input; this surface has no action and decides nothing. See
// docs/ask.md.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

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
    visible: false

    readonly property string decisionPath: Quickshell.env("OMARCHY_KIDS_ASK_DECISION") || ""
    property string state: ""
    property string kind: ""
    property string what: ""
    property int minutes: 0
    property string reply: ""

    FileView {
        id: decisionFile
        path: root.decisionPath
        watchChanges: false
        printErrors: false
        onLoaded: root.read()
        // A file we cannot read must never wedge the watcher: quit and let
        // `watch` mark it seen and move on.
        onLoadFailed: Qt.quit()
    }

    function read() {
        var data
        try {
            data = JSON.parse(decisionFile.text())
        } catch (error) {
            data = null
        }
        if (!data || (data.state !== "approved" && data.state !== "declined")) {
            root.hide()
            return
        }
        root.state = data.state
        root.kind = String(data.kind || "")
        root.what = String(data.what || "")
        root.minutes = Number(data.minutes) || 0
        root.reply = typeof data.reply === "string" ? data.reply : ""
        root.visible = true
        dismiss.restart()
    }

    function hide() {
        root.visible = false
        dismiss.stop()
        Qt.quit()
    }

    function headline() {
        if (root.state === "declined") return "Not this time."
        if (root.kind === "time") return "Yes!"
        return "All set!"
    }

    function body() {
        if (root.state === "declined") return root.reply.length > 0 ? root.reply : "Maybe next time."
        if (root.kind === "time") {
            var plural = root.minutes === 1 ? "" : "s"
            return "You have " + root.minutes + " more minute" + plural + "."
        }
        if (root.kind === "site") return "You can visit " + root.what + " now."
        return root.what + " is ready."
    }

    Timer {
        id: dismiss
        interval: 10000
        running: false
        onTriggered: Qt.quit()
    }

    // Backstop: however the card got here, the process is gone within 15s, so
    // `watch`'s synchronous launch can never stall on it.
    Timer {
        interval: 15000
        running: true
        onTriggered: Qt.quit()
    }

    // --- the card ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: theme.dim

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 460
            radius: 24
            color: theme.background
            border.color: theme.cardFill
            border.width: 2
            height: cardColumn.implicitHeight + 64

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onReturnPressed: (event) => { Qt.quit(); event.accepted = true }
                Keys.onEnterPressed: (event) => { Qt.quit(); event.accepted = true }
                Keys.onEscapePressed: (event) => { Qt.quit(); event.accepted = true }

                Column {
                    id: cardColumn
                    anchors.centerIn: parent
                    width: parent.width - 64
                    spacing: 16

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        text: root.headline()
                        color: root.state === "declined" ? theme.caption : theme.accent
                        font.pixelSize: 30
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        textFormat: Text.PlainText
                        text: root.body()
                        color: theme.foreground
                        font.pixelSize: 18
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // I-5: one key, and it says which one.
                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        text: "Enter Close"
                        color: theme.foreground
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
