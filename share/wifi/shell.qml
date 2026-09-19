// shell.qml -- the kid-facing Wi-Fi picker, loaded by `omarchy-kids-wifi
// picker` (SPEC.md R-WIFI-1..2; I-5, I-6). Every action re-checks
// SO_PEERCRED via omarchy-kids-wifid -- this file's own gate is never trusted. docs/wifi.md.

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

    property string kidAccount: Quickshell.env("OMARCHY_KIDS_ACCOUNT") || ""

    // --- Network list ------------------------------------------------------
    property var networks: []   // [{ssid, signal, security, inUse}]
    property int currentIndex: 0
    property bool loading: true
    property string statusText: ""
    property bool joining: false

    // "omarchy-kids-wifi list" (bin/omarchy-kids-wifi), not nmcli
    // directly — this process is unprivileged; the daemon it talks to
    // over the socket is the one thing that may run nmcli at all.
    Process {
        id: listProcess
        command: ["/usr/bin/omarchy-kids-wifi", "list"]
        property string collected: ""
        onRunningChanged: if (running) collected = ""
        stdout: SplitParser {
            onRead: (line) => { listProcess.collected += line + "\n" }
        }
        onExited: (exitCode) => {
            root.loading = false
            if (exitCode !== 0) {
                root.statusText = "Couldn't list networks. Ask a grown-up."
                root.networks = []
                return
            }
            root.networks = root.parseList(listProcess.collected)
            if (root.currentIndex >= root.networks.length) {
                root.currentIndex = Math.max(0, root.networks.length - 1)
            }
        }
    }

    function refreshList(preserveStatus) {
        if (listProcess.running || root.joining) return
        root.loading = true
        if (!preserveStatus) root.statusText = ""
        listProcess.running = true
    }

    // parseList TEXT -> [{ssid, signal, security, inUse}], de-duplicated
    // by SSID (the same network shows once per BSSID otherwise), sorted
    // by signal strength, strongest first. See the UNTESTED header above
    // for why plain split(":") is a known-imperfect parse of nmcli -t.
    function parseList(text) {
        var seen = {}
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.length === 0) continue
            var fields = line.split(":")
            var ssid = fields[0] || ""
            if (ssid.length === 0) continue   // hidden/blank SSID: nothing to join by name
            if (seen[ssid]) continue
            seen[ssid] = true
            out.push({
                ssid: ssid,
                signal: parseInt(fields[1] || "0", 10) || 0,
                security: fields[2] || "",
                inUse: (fields[3] || "") === "*"
            })
        }
        out.sort(function(a, b) { return b.signal - a.signal })
        return out
    }

    Component.onCompleted: root.refreshList()

    function selectedNetwork() {
        if (root.currentIndex < 0 || root.currentIndex >= root.networks.length) return null
        return root.networks[root.currentIndex]
    }

    function needsPassword(net) {
        return !!net && net.security.length > 0 && net.security !== "--"
    }

    // Process.write() is only valid after the child starts. The
    // stdinEnabled change happens before running for a protected join,
    // so the Process.started handler calls this delivery edge.
    function deliverCandidate() {
        if (joinProcess.stdinEnabled && joinProcess.running && !joinProcess.sent) {
            joinProcess.write(joinProcess.candidate + "\n")
            joinProcess.candidate = ""
            joinProcess.sent = true
            joinProcess.stdinEnabled = false
        }
    }

    // --- Joining -------------------------------------------------------
    // "omarchy-kids-wifi join <ssid> --password-stdin" (or without the
    // flag for an open network) — same one-line-on-stdin-then-EOF shape
    // share/exit-modal/shell.qml already uses for
    // omarchy-kids-parent-auth, so this reuses the confirmed
    // stdinEnabled/write()/stdinEnabled=false sequence rather than
    // guessing a second one.
    Process {
        id: joinProcess
        property string ssid: ""
        property string candidate: ""
        property bool sent: false
        stdinEnabled: true
        property string collected: ""
        stdout: SplitParser {
            onRead: (line) => { joinProcess.collected += line + "\n" }
        }
        onRunningChanged: {
            if (running) {
                joinProcess.sent = false
                joinProcess.collected = ""
            }
        }
        onStarted: root.deliverCandidate()
        onExited: (exitCode) => {
            root.joining = false
            if (exitCode === 0) {
                root.statusText = "Joined " + joinProcess.ssid + "."
                root.showPasswordField = false
                root.passwordText = ""
                root.refreshList(true)
            } else if (exitCode === 3) {
                root.statusText = "Wi-Fi needs a grown-up right now."
            } else {
                root.statusText = "Couldn't join. Check the password and try again."
            }
        }
    }

    property bool showPasswordField: false
    property string passwordText: ""

    function beginJoin() {
        var net = root.selectedNetwork()
        if (!net || root.loading || root.joining) return
        if (root.needsPassword(net) && !root.showPasswordField) {
            root.showPasswordField = true
            root.statusText = ""
            return
        }
        root.joining = true
        joinProcess.ssid = net.ssid
        root.statusText = "Joining " + net.ssid + "…"
        if (root.needsPassword(net)) {
            joinProcess.command = ["/usr/bin/omarchy-kids-wifi", "join", net.ssid, "--password-stdin"]
            joinProcess.candidate = root.passwordText
            joinProcess.stdinEnabled = true
        } else {
            joinProcess.command = ["/usr/bin/omarchy-kids-wifi", "join", net.ssid]
            joinProcess.stdinEnabled = false
        }
        joinProcess.running = true
    }

    function activateCurrent() {
        if (root.loading || root.joining) return
        if (!root.showPasswordField && root.networks.length === 0) root.refreshList()
        else root.beginJoin()
    }

    function footerText() {
        if (root.showPasswordField) return root.joining ? "Esc back" : "Enter join · Esc back"
        if (root.loading || root.joining) return "Esc close"
        if (root.networks.length === 0) return "Enter try again · Esc close"
        return "↑/↓ choose · Enter join · Esc close"
    }

    function closeOverlay() { Qt.quit() }

    // --- Keyboard (I-5: keyboard-complete) --------------------------------
    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: (event) => {
            if (root.showPasswordField) {
                root.showPasswordField = false
                root.passwordText = ""
            } else {
                root.closeOverlay()
            }
            event.accepted = true
        }
        Keys.onUpPressed: (event) => {
            if (!root.loading && !root.joining && !root.showPasswordField && root.currentIndex > 0) root.currentIndex -= 1
            event.accepted = true
        }
        Keys.onDownPressed: (event) => {
            if (!root.loading && !root.joining && !root.showPasswordField && root.currentIndex + 1 < root.networks.length) root.currentIndex += 1
            event.accepted = true
        }
        Keys.onReturnPressed: (event) => { root.activateCurrent(); event.accepted = true }
        Keys.onEnterPressed: (event) => { root.activateCurrent(); event.accepted = true }

        Rectangle {
            anchors.fill: parent
            color: theme.dim

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 480
                height: Math.min(560, cardColumn.implicitHeight + 64)
                radius: 24
                color: theme.background
                border.color: theme.cardFill
                border.width: 2

                Column {
                    id: cardColumn
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: 32
                    width: parent.width - 64
                    spacing: 16

                    Text {
                        font.family: theme.fontFamily
                        text: "Wi-Fi"
                        color: theme.foreground
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        visible: root.loading
                        text: "Looking for networks…"
                        color: theme.foreground
                        font.family: theme.fontFamily
                        font.pixelSize: 16
                    }

                    ListView {
                        id: list
                        visible: !root.loading && !root.showPasswordField && root.networks.length > 0
                        width: parent.width
                        height: 320
                        clip: true
                        model: root.networks
                        currentIndex: root.currentIndex
                        highlightMoveDuration: 80

                        delegate: Rectangle {
                            width: list.width
                            height: 56
                            radius: 10
                            color: ListView.isCurrentItem ? theme.tileFill : theme.cardFill

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Text {
                                    font.family: theme.fontFamily
                                    text: modelData.ssid
                                    color: theme.foreground
                                    font.pixelSize: 16
                                    font.bold: modelData.inUse
                                    width: parent.width - 140
                                    elide: Text.ElideRight
                                }
                                Text {
                                    font.family: theme.fontFamily
                                    text: modelData.security.length > 0 ? "🔒" : "open"
                                    color: theme.caption
                                    font.pixelSize: 14
                                }
                                Text {
                                    font.family: theme.fontFamily
                                    text: modelData.signal + "%"
                                    color: theme.caption
                                    font.pixelSize: 14
                                }
                            }

                            MouseArea {
                                enabled: !root.joining
                                anchors.fill: parent
                                onClicked: {
                                    root.currentIndex = index
                                    root.beginJoin()
                                }
                            }
                        }
                    }

                    // --- Password step ---------------------------------
                    Column {
                        visible: root.showPasswordField
                        width: parent.width
                        spacing: 12

                        Text {
                            font.family: theme.fontFamily
                            width: parent.width
                            text: root.selectedNetwork() ? ("Password for " + root.selectedNetwork().ssid) : ""
                            color: theme.foreground
                            font.pixelSize: 16
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: parent.width
                            height: 48
                            radius: 8
                            color: theme.inputFill
                            border.color: passwordInput.activeFocus ? theme.accent : theme.cardFill
                            border.width: 2

                            TextInput {
                                font.family: theme.fontFamily
                                id: passwordInput
                                anchors.fill: parent
                                anchors.margins: 12
                                echoMode: TextInput.Password
                                focus: root.showPasswordField
                                enabled: !root.joining
                                color: theme.foreground
                                font.pixelSize: 18
                                clip: true
                                text: root.passwordText
                                onTextChanged: root.passwordText = text
                                Keys.onReturnPressed: (event) => { root.activateCurrent(); event.accepted = true }
                                Keys.onEnterPressed: (event) => { root.activateCurrent(); event.accepted = true }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: root.statusText.length > 0
                        text: root.statusText
                        color: theme.foreground
                        font.family: theme.fontFamily
                        font.pixelSize: 16
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        visible: !root.loading && !root.joining && !root.showPasswordField && root.networks.length === 0
                        width: parent.width
                        spacing: 16

                        Text {
                            visible: root.statusText.length === 0
                            width: parent.width
                            text: "No networks found"
                            color: theme.foreground
                            font.family: theme.fontFamily
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            width: parent.width
                            height: 48
                            radius: 10
                            color: theme.tileFill
                            border.color: theme.accent
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "Try again"
                                color: theme.foreground
                                font.family: theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.refreshList()
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.footerText()
                        color: theme.foreground
                        font.family: theme.fontFamily
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
