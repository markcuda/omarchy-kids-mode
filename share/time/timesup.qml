// The display-only Time's Up card reads root state (SPEC.md R-TIME-4,
// R-TIMEAUTH-6). See docs/time.md for the trust boundary.

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

    property string kidAccount: Quickshell.env("OMARCHY_KIDS_ACCOUNT") || ""
    property string kidName: Quickshell.env("OMARCHY_KIDS_NAME") || ""
    property string kidAvatar: Quickshell.env("OMARCHY_KIDS_AVATAR") || ""
    property string displayName: kidName.length > 0 ? kidName : kidAccount

    // The account is supplied by id -un; the prefix is fixed at build time.
    readonly property string statusPath: "/run/omarchy-kids/time/" + root.kidAccount + ".json"
    property int secondsLeft: 0
    property string reason: "budget"
    property bool mediaReady: false

    IpcHandler {
        target: "media"

        function timesUpReady(): bool {
            return root.mediaReady
        }
    }

    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        printErrors: false
        onLoaded: root.readStatus()
        onTextChanged: root.readStatus()
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (root.secondsLeft > 0) root.secondsLeft -= 1
            root.mediaReady = root.visible && root.secondsLeft > 0
        }
    }

    function readStatus() {
        var status
        try {
            status = JSON.parse(statusFile.text())
        } catch (error) {
            root.hideCard()
            return
        }
        if (!root.isGraceStatus(status)) {
            root.hideCard()
            return
        }
        root.secondsLeft = status.grace_deadline - status.last_tick
        root.reason = status.reason === "lights-out" ? "lights-out" : "budget"
        root.mediaReady = false
        root.visible = true
        countdown.restart()
    }

    function isGraceStatus(status) {
        return status && (status.state === "grace" || status.state === "finishing") &&
            Number.isInteger(status.grace_deadline) && status.grace_deadline >= 0 &&
            Number.isInteger(status.last_tick) && status.last_tick >= 0 &&
            status.grace_deadline >= status.last_tick
    }

    function hideCard() {
        root.visible = false
        root.mediaReady = false
        countdown.stop()
    }

    function doAskGrownup() {
        Quickshell.execDetached(["/usr/bin/omarchy-kids-ask", "time", "15"])
    }

    // --- The card ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: theme.dim

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 480
            radius: 24
            color: theme.background
            border.color: theme.cardFill
            border.width: 2
            height: cardColumn.implicitHeight + 64

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onReturnPressed: (event) => { root.doAskGrownup(); event.accepted = true }
                Keys.onEnterPressed: (event) => { root.doAskGrownup(); event.accepted = true }

                Column {
                    id: cardColumn
                    anchors.centerIn: parent
                    width: parent.width - 64
                    spacing: 16

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: root.kidAvatar
                        width: 96
                        height: 96
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Time's up, " + root.displayName + "!"
                        color: theme.foreground
                        font.pixelSize: 26
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: root.reason === "lights-out"
                            ? "It's bedtime. This desktop is finishing up."
                            : "Your screen time for today is done."
                        color: theme.caption
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Closing in " + root.secondsLeft + "s"
                        color: root.secondsLeft <= 10 ? theme.error : theme.warning
                        font.pixelSize: 14
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0

                        Rectangle {
                            id: askButton
                            width: cardColumn.width
                            height: 84
                            radius: 12
                            color: theme.tileFill
                            border.width: 3
                            border.color: theme.accent

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 16
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: "Ask a grown-up"
                                    color: theme.foreground
                                    font.pixelSize: 16
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: parent.width
                                    text: "for more time"
                                    color: theme.caption
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.doAskGrownup()
                            }
                        }
                    }
                }
            }
        }
    }
}
