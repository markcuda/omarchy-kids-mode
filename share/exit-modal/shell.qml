// shell.qml -- the Super+Shift+K / triple-Super-tap exit modal, loaded by
// bin/omarchy-kids-exit --open (SPEC.md R-EXIT-1..6; I-5, I-6).
// Verified live 2026-09-02 against a real Hyprland+Quickshell -- docs/exit.md.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // Theme colors/font (docs/theming.md) — see share/qml/KidsTheme.qml.
    KidsTheme { id: theme }

    // --- Layer-shell specifics (docs/exit.md) ----------------------------
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    // Verified live 2026-09-02: without this the overlay draws but keys go to the window
    // underneath (Quickshell 0.3.1 on Hyprland 0.56).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: true

    // --- Who this is for: bin/omarchy-kids-exit sets these three before
    //     exec'ing quickshell (docs/exit.md) --------------------------
    property string kidAccount: Quickshell.env("OMARCHY_KIDS_ACCOUNT") || ""
    property string kidName: Quickshell.env("OMARCHY_KIDS_NAME") || ""
    property string kidAvatar: Quickshell.env("OMARCHY_KIDS_AVATAR") || ""

    property string displayName: kidName.length > 0 ? kidName : kidAccount
    property string avatarSource: kidAvatar

    // Possessive form for the sublines (R-EXIT-1): "Ada's", "Chris'".
    function possessive(name) {
        if (name.length === 0) return "Their"
        return name + (name.charAt(name.length - 1).toLowerCase() === "s" ? "'" : "'s")
    }

    // --- Password / verification state -----------------------------------
    property bool locked: false
    property int wrongCount: 0
    property bool verifying: false
    property string hint: ""

    Timer {
        id: lockoutTimer
        interval: 30000
        onTriggered: {
            root.locked = false
            root.wrongCount = 0
            root.hint = ""
        }
    }

    // omarchy-kids-parent-auth (docs/authd.md): one line of candidate
    // password on stdin, then EOF, then its exit code is the answer.
    // Never logs the password anywhere -- not to a file, not to a
    // console, not left sitting in a QML property longer than the one
    // Process invocation needs it for.
    Process {
        id: authProcess
        property string candidate: ""
        command: ["/usr/bin/omarchy-kids-parent-auth"]
        stdinEnabled: true
        onRunningChanged: {
            if (running) {
                write(candidate + "\n")
                candidate = ""
                // Quickshell 0.3.1: flipping stdinEnabled off closes the child's
                // stdin. Without it, omarchy-kids-parent-auth's `cat -` never
                // sees EOF and this hangs forever.
                stdinEnabled = false
            }
        }
        onExited: (exitCode) => {
            root.verifying = false
            if (exitCode === 0) {
                root.onVerified()
            } else if (exitCode === 2) {
                // The verifier is unreachable (parent-auth exits 2): not a
                // wrong password, so it must not count toward the lockout.
                passwordInput.text = ""
                root.hint = "Can't check the password right now. Try again in a moment."
            } else {
                root.onWrongPassword()
            }
        }
    }

    // Finish runs only after authProcess confirms a parent typed their password.
    function onVerified() {
        root.wrongCount = 0
        // Detached, not a child Process: Qt.quit() right after starting a child
        // killed it before it ran (seen live 2026-09-02: the modal closed, the
        // session stayed). --finish ends this compositor anyway.
        Quickshell.execDetached(["/usr/bin/omarchy-kids-exit", "--finish"])
        Qt.quit()
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

    function submit() {
        if (root.locked || root.verifying) return
        root.verifying = true
        authProcess.candidate = passwordInput.text
        authProcess.running = true
    }

    function closeModal() {
        Qt.quit()
    }

    // --- The card ----------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: theme.dim // dim scrim over whatever was on screen

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 440
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
                Keys.onReturnPressed: (event) => { root.submit(); event.accepted = true }
                Keys.onEnterPressed: (event) => { root.submit(); event.accepted = true }

                Column {
                    id: cardColumn
                    anchors.centerIn: parent
                    width: parent.width - 64
                    spacing: 16

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: root.avatarSource
                        width: 96
                        height: 96
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }

                    Text {
                        font.family: theme.fontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 32
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.displayName
                        color: theme.foreground
                        font.pixelSize: 24
                        font.bold: true
                    }

                    // --- Password field (I-5: focused, masked, Enter/Esc) --
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 8
                        color: root.locked ? theme.errorFill : theme.inputFill
                        border.color: passwordInput.activeFocus ? theme.accent : theme.cardFill
                        border.width: 2

                        TextInput {
                            id: passwordInput
                            font.family: theme.fontFamily
                            anchors.fill: parent
                            anchors.margins: 12
                            echoMode: TextInput.Password
                            focus: true
                            enabled: !root.locked && !root.verifying
                            color: theme.foreground
                            font.pixelSize: 18
                            clip: true
                        }
                        // QtQuick's TextInput has no placeholderText: the live
                        // review (2026-09-21) found an empty field beside the
                        // *kid's* face with no clue that the parent's password
                        // is wanted. Shown only while empty, never clickable.
                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            verticalAlignment: Text.AlignVCenter
                            visible: passwordInput.text.length === 0
                            text: "Your password"
                            color: theme.foreground
                            opacity: 0.5
                            font.family: theme.fontFamily
                            font.pixelSize: 18
                        }
                    }

                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        visible: root.hint.length > 0
                        text: root.hint
                        color: root.locked ? theme.error : theme.warning
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // --- Finish (R-EXIT-1) ----------------------------------
                    Rectangle {
                        id: finishButton
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: (cardColumn.width - 16) / 2
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
                                font.family: theme.fontFamily
                                width: parent.width
                                text: "Finish for " + root.displayName
                                color: theme.foreground
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                font.family: theme.fontFamily
                                width: parent.width
                                text: "Closes " + root.possessive(root.displayName) + " apps. You return to the login screen."
                                color: theme.caption
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.submit()
                            }
                        }
                    }
                    // I-5: the keys are discoverable, not memorized -- the portal,
                    // the picker, the Wi-Fi picker and the plugins shelf all say
                    // which keys work; these two modals did not (live 2026-09-22).
                    Text {
                        font.family: theme.fontFamily
                        width: parent.width
                        visible: !root.locked
                        text: "Enter Finish    ·    Esc Back"
                        color: theme.foreground
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
