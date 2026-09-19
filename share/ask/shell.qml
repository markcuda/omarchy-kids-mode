// shell.qml -- the "Ask a parent" modal, loaded by bin/omarchy-kids-ask.
// SPEC.md R-ASK-1..3 (two choices only, never a pointer-only path); I-5
// keyboard-complete, I-6 honest UI. See docs/ask.md for verified status.

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

    // --- What's being asked (bin/omarchy-kids-ask sets these before
    //     exec'ing quickshell) ---------------------------------------
    property string kidAccount: Quickshell.env("OMARCHY_KIDS_ACCOUNT") || ""
    property string kind: Quickshell.env("OMARCHY_KIDS_ASK_KIND") || ""
    property string what: Quickshell.env("OMARCHY_KIDS_ASK_WHAT") || ""
    property string desc: Quickshell.env("OMARCHY_KIDS_ASK_DESC") || "this"
    property string minutes: Quickshell.env("OMARCHY_KIDS_ASK_MINUTES") || ""
    // Absolute, and not from the environment: this surface runs inside the
    // kid's session (AGENTS.md rule 9, review S12).
    readonly property string askBin: "/usr/bin/omarchy-kids-ask"

    // 0 = "A grown-up is here" (needs the password), 1 = "Ask later"
    // (doesn't). "A grown-up is here" is preselected: it's the answer
    // most requests expect, and Enter-with-nothing-typed just fails
    // verification honestly rather than silently doing the lesser thing.
    property int selectedAction: 0

    property bool locked: false
    property int wrongCount: 0
    property bool verifying: false
    property bool done: false
    property string hint: ""
    property string doneMessage: ""

    Timer {
        id: lockoutTimer
        interval: 30000
        onTriggered: {
            root.locked = false
            root.wrongCount = 0
            root.hint = ""
        }
    }

    // Shown after either path submits, so the kid actually sees it
    // before the modal closes (R-ASK-1's own wording for "Ask later";
    // see onGranted()/submitLater() for the on-the-spot wording).
    Timer {
        id: closeTimer
        interval: 1600
        onTriggered: Qt.quit()
    }

    // "omarchy-kids-ask grant" (docs/ask.md): one line of typed password
    // on stdin, then EOF. It forwards the request and the password to
    // root's verifier socket; exit 0 means *root* verified the password
    // and applied the grant itself. Nothing in this session decides
    // anything -- this exit code only chooses which message to show.
    // Never logs the password anywhere.
    Process {
        id: grantProcess
        property string candidate: ""
        command: [root.askBin, "grant", root.kind, root.what].concat(
            root.kind === "time" && root.minutes.length > 0 ? ["--minutes", root.minutes] : [])
        stdinEnabled: true
        onRunningChanged: {
            if (running) {
                write(candidate + "\n")
                candidate = ""
                stdinEnabled = false
            }
        }
        onExited: (exitCode) => {
            root.verifying = false
            if (exitCode === 0) {
                root.onGranted()
            } else {
                root.onWrongPassword()
            }
        }
    }

    // onGranted -- root already did it, by the time grantProcess exits.
    // There is deliberately nothing to write here: this session cannot
    // approve anything, so it does not try (review S1).
    function onGranted() {
        root.wrongCount = 0
        root.doneMessage = "Got it! " + root.desc + " is ready now."
        root.done = true
        closeTimer.restart()
    }

    // submitLater -- "Ask later": no password needed, R-ASK-1's exact
    // wording ("Asked. Your grown-up will see it."). Always an open
    // claim; `submit` has no way to write anything else.
    function submitLater() {
        var args = ["submit", root.kind, root.what]
        if (root.kind === "time" && root.minutes.length > 0) {
            args = args.concat(["--minutes", root.minutes])
        }
        Quickshell.execDetached([root.askBin].concat(args))
        root.doneMessage = "Asked. Your grown-up will see it."
        root.done = true
        closeTimer.restart()
    }

    function onWrongPassword() {
        root.wrongCount += 1
        passwordInput.text = ""
        shakeAnim.start()
        if (root.wrongCount >= 3) {
            root.locked = true
            root.hint = "Too many tries. Try again in 30 seconds."
            lockoutTimer.restart()
        } else {
            root.hint = "That wasn't it."
        }
    }

    function toggleSelection() {
        root.selectedAction = root.selectedAction === 0 ? 1 : 0
        root.hint = ""
    }

    function submit() {
        if (root.done || root.locked || root.verifying) return
        if (root.selectedAction === 1) {
            root.submitLater()
            return
        }
        root.verifying = true
        grantProcess.candidate = passwordInput.text
        grantProcess.running = true
    }

    function closeModal() {
        Qt.quit() // Esc: never mind -- nothing written, nothing asked.
    }

    // --- The card ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        // Stronger than theme.dim: this card opens over Time's Up, whose own card must fade away.
        color: Qt.rgba(theme.dim.r, theme.dim.g, theme.dim.b, 0.85)

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 460
            radius: 24
            color: theme.background
            border.color: theme.cardFill
            border.width: 2
            height: cardColumn.implicitHeight + 64

            SequentialAnimation {
                id: shakeAnim
                loops: 1
                NumberAnimation { target: card; property: "x"; from: card.x; to: card.x - 12; duration: 40 }
                NumberAnimation { target: card; property: "x"; to: card.x + 24; duration: 60 }
                NumberAnimation { target: card; property: "x"; to: card.x - 16; duration: 60 }
                NumberAnimation { target: card; property: "x"; to: card.x; duration: 40 }
            }

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: (event) => { root.closeModal(); event.accepted = true }
                Keys.onTabPressed: (event) => { root.toggleSelection(); event.accepted = true }
                Keys.onBacktabPressed: (event) => { root.toggleSelection(); event.accepted = true }
                Keys.onReturnPressed: (event) => { root.submit(); event.accepted = true }
                Keys.onEnterPressed: (event) => { root.submit(); event.accepted = true }

                Column {
                    id: cardColumn
                    anchors.centerIn: parent
                    width: parent.width - 64
                    spacing: 16

                    Text {
                        font.family: theme.fontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Ask a grown-up"
                        color: theme.foreground
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        text: root.desc
                        color: theme.caption
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // --- Done message (either path) -- replaces the
                    //     rest of the card once submitted (I-6: no
                    //     dead controls left visible after the choice
                    //     is made) --------------------------------------
                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        visible: root.done
                        text: root.doneMessage
                        color: theme.accent
                        font.pixelSize: 16
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // --- Password field (I-5: focused, masked, Enter/Esc) --
                    Rectangle {
                        visible: !root.done
                        width: parent.width
                        height: 48
                        radius: 8
                        color: root.locked ? theme.errorFill : theme.inputFill
                        border.color: passwordInput.activeFocus ? theme.accent : theme.cardFill
                        border.width: 2

                        TextInput {
                            font.family: theme.fontFamily
                            id: passwordInput
                            anchors.fill: parent
                            anchors.margins: 12
                            echoMode: TextInput.Password
                            focus: true
                            enabled: !root.locked && !root.verifying
                            color: theme.foreground
                            font.pixelSize: 18
                            clip: true
                        }
                    }

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        visible: !root.done && root.hint.length > 0
                        text: root.hint
                        color: root.locked ? theme.error : theme.warning
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // --- "A grown-up is here" / "Ask later" (R-ASK-1) ----
                    Row {
                        visible: !root.done
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        Rectangle {
                            id: hereButton
                            width: (cardColumn.width - 16) / 2
                            height: 84
                            radius: 12
                            color: root.selectedAction === 0 ? theme.tileFill : theme.cardFill
                            border.width: root.selectedAction === 0 ? 3 : 0
                            border.color: theme.accent

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 16
                                spacing: 4
                                Text {
                                    font.family: theme.fontFamily
                                    width: parent.width
                                    text: "A grown-up is here"
                                    color: theme.foreground
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    font.family: theme.fontFamily
                                    width: parent.width
                                    text: "Type their password"
                                    color: theme.caption
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedAction = 0
                                    root.submit()
                                }
                            }
                        }

                        Rectangle {
                            id: laterButton
                            width: (cardColumn.width - 16) / 2
                            height: 84
                            radius: 12
                            color: root.selectedAction === 1 ? theme.tileFill : theme.cardFill
                            border.width: root.selectedAction === 1 ? 3 : 0
                            border.color: theme.accent

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 16
                                spacing: 4
                                Text {
                                    font.family: theme.fontFamily
                                    width: parent.width
                                    text: "Ask later"
                                    color: theme.foreground
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    font.family: theme.fontFamily
                                    width: parent.width
                                    text: "Your grown-up will see it"
                                    color: theme.caption
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedAction = 1
                                    root.submit()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
