// Main.qml -- the Omarchy Kids Mode SDDM portal (SPEC.md R-LOGIN-1..5,
// R-SEC-3, R-LOGIN-3, I-5; issue #14, issue #39).
// See docs/portal.md for the upstream source citations and unverified list.

import QtQuick 2.0
import Qt5Compat.GraphicalEffects
import "PortalConfig.js" as PortalConfig

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.backgroundColor || "#1a1b26"

    // --- palette: theme.conf's [General] keys, with hardcoded fallbacks
    // so a missing/blank key never leaves a tile invisible or unreadable.
    readonly property color colTile: config.tileColor || "#232838"
    readonly property color colTileHighlight: config.tileHighlightColor || "#3a4266"
    readonly property color colParentTile: config.parentTileColor || "#1f2335"
    readonly property color colAccent: config.accentColor || "#8fb8ff"
    readonly property color colText: config.textColor || "#ffffff"
    readonly property color colMuted: config.mutedTextColor || "#9aa5ce"
    readonly property color colError: config.errorColor || "#f7768e"
    readonly property string fontFam: config.fontFamily || "JetBrainsMono Nerd Font"

    readonly property real cornerRadius: PortalConfig.geometryNumber(config.cornerRadius, 0, 256)
    function controlNumber(state, suffix, fallback, maximum) {
        return PortalConfig.geometryNumber(config[state + suffix], fallback, maximum)
    }
    function controlColor(state) {
        var value = String(config[state + "Color"] || "foreground").trim().toLowerCase()
        var channels = PortalConfig.colorChannels(value)
        if (channels) return Qt.rgba(channels[0], channels[1], channels[2], channels[3])
        if (value === "accent") return root.colAccent
        if (value === "urgent") return root.colError
        if (value === "background") return root.color
        return root.colText
    }
    function controlFill(state, fallback) {
        var c = controlColor(state)
        return Qt.rgba(c.r, c.g, c.b, controlNumber(state, "FillAlpha", fallback, 1))
    }
    function controlBorder(state, fallback) {
        var c = controlColor(state)
        return Qt.rgba(c.r, c.g, c.b, controlNumber(state, "BorderAlpha", fallback, 1))
    }

    // --- theme.conf.user (issues #39/#100): parent + per-kid name/avatar data,
    // parsed once at startup out of the SAME "config" QQmlPropertyMap
    // theme.conf's own colors already come through (ThemeConfig::setTo(),
    // docs/portal.md) -- no XHR, no file:// URL. A property, not an
    // inline call, so it runs once before any Repeater delegate's
    // Component.onCompleted needs it. config.kids' format
    // (lib/posture.sh's posture_portal_conf_text) percent-encodes each
    // field before joining "account:name:avatar" records.
    function parsePortalConfig() {
        return PortalConfig.parsePortalConfig(
            config.parent ? String(config.parent) : "",
            config.parents ? String(config.parents) : "",
            config.kids ? String(config.kids) : "")
    }
    readonly property var portalData: root.parsePortalConfig()
    readonly property string portalParent: portalData.parent
    readonly property var portalParents: portalData.parents
    readonly property var portalKids: portalData.kids
    readonly property bool portalLoaded: portalData.loaded === true

    // --- kid-vs-parent (R-LOGIN-1: parent tile last and smaller) --------
    // The producer writes both the profile and parent allowlists; account
    // naming is only retained for display fallback text.
    function isKidName(name) { return String(name).indexOf("kid-") === 0 }
    function hasPortalKid(name) {
        return root.portalKids && Object.prototype.hasOwnProperty.call(root.portalKids, String(name))
    }
    function isParentAccount(name) {
        return !root.hasPortalKid(name) && root.portalParents && Object.prototype.hasOwnProperty.call(root.portalParents, String(name)) && root.portalParents[String(name)] === true
    }
    function isPortalUser(name) {
        return root.hasPortalKid(name) || root.isParentAccount(name)
    }
    // displayNameFor: config.kids carries the exact root-owned profile name.
    // passwd GECOS is a fallback for old configs and representable names.
    function displayNameFor(name, realName) {
        var portalEntry = root.hasPortalKid(name) ? root.portalKids[String(name)] : undefined
        if (portalEntry && portalEntry.name && portalEntry.name.length > 0) return portalEntry.name
        if (realName && realName.length > 0) return realName
        var base = isKidName(name) ? String(name).slice(4) : String(name)
        return base.length > 0 ? base.charAt(0).toUpperCase() + base.slice(1) : base
    }
    // avatarSourceFor: AccountsService's "icon" role wins if set, else the
    // same path rebuilt from config.kids' per-account avatar id. The file
    // that actually has to exist on disk for a real greeter to render it
    // is lib/posture.sh's posture_write_face_icon output, not this path
    // (docs/portal.md's "Avatars" section).
    function avatarSourceFor(modelData) {
        if (modelData.icon && modelData.icon.length > 0) return modelData.icon
        var portalEntry = root.hasPortalKid(modelData.name) ? root.portalKids[String(modelData.name)] : undefined
        if (portalEntry && portalEntry.avatar && portalEntry.avatar.length > 0) {
            return "/usr/share/omarchy-kids/avatars/" + portalEntry.avatar + ".svg"
        }
        return ""
    }

    // --- harvest userModel into a plain, reorderable JS array -----------
    // userModel is a QAbstractListModel with named roles (name, realName,
    // icon, needsPassword) that a Repeater/ListView delegate receives as
    // plain context properties -- that part is standard Qt item-view
    // behavior and needs no verification. Reordering the *view* itself
    // (kids first, parent last, R-LOGIN-1) is not possible on the model
    // directly with no C++ proxy model available here, so this hidden
    // Repeater's only job is to read allowlisted rows back into root.users
    // once; the ordered tiles use that plain array, not userModel directly.
    property var users: []

    Repeater {
        model: userModel
        delegate: Item {
            Component.onCompleted: {
                var u = root.users
                if (root.isPortalUser(name)) {
                    u.push({
                        name: name,
                        realName: realName,
                        icon: icon,
                        needsPassword: needsPassword,
                        isParent: root.isParentAccount(name)
                    })
                    root.users = u
                }
                if (index === userModel.count - 1) root.finishLoadingUsers()
            }
        }
    }

    Component.onCompleted: {
        if (userModel.count === 0) root.finishLoadingUsers()
        keyScope.forceActiveFocus()
    }

    function finishLoadingUsers() {
        var kids = root.users.filter(function (u) { return !u.isParent })
        var parents = root.users.filter(function (u) { return u.isParent })
        root.users = kids.concat(parents)
        console.error("portal: " + root.users.length + " tiles (kids=" + kids.length + " parents=" + parents.length + ")")
        // R-LOGIN-1: the last-used tile preselected.
        for (var i = 0; i < root.users.length; i++) {
            if (root.users[i].name === userModel.lastUser) { root.currentIndex = i; break }
        }
        if (root.users.length === 0) {
            root.statusMessage = "No accounts to show yet. A grown-up can fix this."
        }
    }

    // --- same harvest trick for sessionModel, so a kid's Enter always
    // lands on the omarchy-kids session and the parent's on omarchy --
    // exactly what the boot-time autologin path already assumes
    // -- and never a session picker (R-LOGIN-3). --------------------------
    property var sessionFiles: []  // [{index, base}], base = the .desktop file's basename

    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: {
                var parts = String(file).split("/")
                var s = root.sessionFiles
                s.push({ index: index, base: parts[parts.length - 1] })
                root.sessionFiles = s
            }
        }
    }

    function sessionIndexForFile(baseName) {
        for (var i = 0; i < root.sessionFiles.length; i++) {
            if (root.sessionFiles[i].base === baseName) return root.sessionFiles[i].index
        }
        return -1
    }

    function sessionIndexForUser(user) {
        return root.sessionIndexForFile(user.isParent ? "omarchy.desktop" : "omarchy-kids.desktop")
    }

    function loginUser(user, password) {
        var sessionIndex = root.sessionIndexForUser(user)
        if (sessionIndex < 0) {
            root.statusMessage = "This desktop isn't set up yet. A grown-up can fix it."
            return
        }
        sddm.login(user.name, password, sessionIndex)
    }

    // --- selection state --------------------------------------------------
    property int currentIndex: 0
    property bool passwordMode: false
    property bool loginFailed: false
    property int failCount: 0
    property string statusMessage: ""

    function currentUser() {
        return (root.currentIndex >= 0 && root.currentIndex < root.users.length) ? root.users[root.currentIndex] : null
    }

    function selectTile(i) {
        root.currentIndex = i
        root.passwordMode = false
        root.loginFailed = false
        root.statusMessage = ""
        keyScope.forceActiveFocus() // the closed password field would otherwise keep the arrows
    }

    // I-6: the footer names a key only when that key acts on this box. Left/right
    // need a second tile to move to, Enter needs a tile at all (with none, the
    // status line says no accounts are visible), and the greeter may
    // refuse power-off -- sddm.canPowerOff gates the chord's own handler too.
    function keyHelpText() {
        if (root.passwordMode) return "Enter Sign in    ·    Esc Back"
        var parts = []
        if (root.users.length > 1) parts.push("← → Choose")
        if (root.users.length > 0) parts.push("Enter Sign in")
        if (sddm.canPowerOff) parts.push("Ctrl+Shift+P Power off")
        return parts.join("    ·    ")
    }

    // Enter on the highlighted tile (R-LOGIN-2/4): "no password" profiles
    // (3-5 band only, R-SEC-3) log in immediately with an empty password;
    // every other tile opens the password field under it instead.
    function activateCurrent() {
        var u = root.currentUser()
        if (!u) return
        if (!u.needsPassword) {
            root.loginUser(u, "")
            return
        }
        root.passwordMode = true
        root.loginFailed = false
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loginFailed = true
            root.failCount += 1
        }
        function onLoginSucceeded() {
            root.loginFailed = false
        }
    }

    // --- layout: tiles centered, parent last and smaller -------------------
    Row {
        id: tileRow
        anchors.centerIn: parent
        spacing: 48

        Repeater {
            model: root.users

            delegate: Item {
                id: tileItem
                property bool isCurrent: index === root.currentIndex
                property bool hasCursor: isCurrent && !root.passwordMode
                property string borderState: hasCursor ? "focus" : (isCurrent ? "selected" : "normal")
                property real tileSize: modelData.isParent ? 140 : 200
                property real shakeOffset: 0
                width: tileSize
                height: tileSize + 56 + (isCurrent && root.passwordMode ? 64 : 0)

                Column {
                    id: visualColumn
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    transform: Translate { x: tileItem.shakeOffset }

                    Rectangle {
                        id: avatarBox
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tileItem.tileSize
                        height: tileItem.tileSize
                        radius: root.cornerRadius
                        clip: true
                        color: Qt.tint(root.color, root.controlFill(tileItem.isCurrent ? "selected" : "normal", tileItem.isCurrent ? 0.18 : 0.04))
                        border.width: root.controlNumber(tileItem.borderState, "BorderWidth", tileItem.borderState === "selected" ? 0 : 1, 256)
                        border.color: root.controlBorder(tileItem.borderState, tileItem.hasCursor ? 0.25 : (tileItem.isCurrent ? 1 : 0.4))

                        // Avatar from the AccountsService Icon= path, or
                        // config.kids' own avatar id if that role comes
                        // back empty (avatarSourceFor(), issue #39;
                        // docs/provision.md, R-LOGIN-1).
                        // The image and its frame share the parent's corner geometry.
                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            anchors.margins: 8
                            source: root.avatarSourceFor(modelData)
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            asynchronous: true
                        }

                        Rectangle {
                            id: avatarMask
                            anchors.fill: avatarImage
                            radius: Math.max(0, root.cornerRadius - avatarImage.anchors.margins)
                            color: root.colText
                            visible: false
                        }

                        OpacityMask {
                            id: avatarMaskedImage
                            anchors.fill: avatarImage
                            source: avatarImage
                            maskSource: avatarMask
                            visible: avatarImage.status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: avatarImage.status !== Image.Ready
                            text: root.displayNameFor(modelData.name, modelData.realName).charAt(0).toUpperCase()
                            color: root.colText
                            font.family: root.fontFam
                            font.pixelSize: tileItem.tileSize * 0.4
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.displayNameFor(modelData.name, modelData.realName)
                        color: modelData.isParent ? root.colMuted : root.colText
                        font.family: root.fontFam
                        font.pixelSize: modelData.isParent ? 16 : 20
                        font.bold: tileItem.isCurrent
                        width: tileItem.tileSize
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    // Password field, shown under the selected tile only
                    // after Enter (R-LOGIN-1/2/4). No field at all for a
                    // "no password" profile: activateCurrent() logs it in
                    // directly instead of ever setting passwordMode.
                    Rectangle {
                        visible: tileItem.isCurrent && root.passwordMode
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(tileItem.tileSize, 160)
                        height: 40
                        radius: root.cornerRadius
                        color: Qt.tint(root.color, root.controlFill("focus", 0.08))
                        border.width: root.controlNumber("focus", "BorderWidth", 1, 256)
                        border.color: root.loginFailed ? root.colError : root.controlBorder("focus", 0.25)

                        TextInput {
                            id: passwordField
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            color: root.colText
                            font.family: root.fontFam
                            font.pixelSize: 18
                            focus: tileItem.isCurrent && root.passwordMode

                            onTextChanged: root.loginFailed = false

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.loginUser(modelData, passwordField.text)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    passwordField.text = ""
                                    root.selectTile(root.currentIndex)
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                // Wrong password (R-LOGIN, "a wrong password shakes and
                // clears"): only the tile that was actually submitting
                // reacts, matched by isCurrent at the moment of failure.
                SequentialAnimation {
                    id: tileShake
                    NumberAnimation { target: tileItem; property: "shakeOffset"; to: -12; duration: 40 }
                    NumberAnimation { target: tileItem; property: "shakeOffset"; to: 12; duration: 60 }
                    NumberAnimation { target: tileItem; property: "shakeOffset"; to: -8; duration: 60 }
                    NumberAnimation { target: tileItem; property: "shakeOffset"; to: 0; duration: 40 }
                }

                Connections {
                    target: root
                    function onFailCountChanged() {
                        if (tileItem.isCurrent) {
                            passwordField.text = ""
                            tileShake.start()
                        }
                    }
                }
            }
        }
    }

    // R-LOGIN: a wrong password is worded, not only shaken (I-6).
    Text {
        id: loginErrorText
        visible: root.loginFailed
        anchors.top: tileRow.bottom
        anchors.topMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        text: "That password didn't work. Try again."
        color: root.colError
        font.family: root.fontFam
        font.pixelSize: 16
    }

    // A setup problem says so instead of a silent Enter (I-6; review B6).
    Text {
        id: setupStatus
        visible: root.statusMessage !== ""
        anchors { bottom: keyHelp.top; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
        width: parent.width - 64
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.statusMessage
        color: root.colError
        font.family: root.fontFam
        font.pixelSize: 16
    }

    // I-5: the keys are discoverable, not memorized.
    Text {
        id: keyHelp
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        text: root.keyHelpText()
        color: root.colMuted
        font.family: root.fontFam
        font.pixelSize: 16
    }

    // --- keyboard (I-5: keyboard-complete) ---------------------------------
    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onLeftPressed: (event) => {
            if (!root.passwordMode && root.currentIndex > 0) root.selectTile(root.currentIndex - 1)
            event.accepted = true
        }
        Keys.onRightPressed: (event) => {
            if (!root.passwordMode && root.currentIndex < root.users.length - 1) root.selectTile(root.currentIndex + 1)
            event.accepted = true
        }
        Keys.onReturnPressed: (event) => { if (!root.passwordMode) root.activateCurrent(); event.accepted = true }
        Keys.onEnterPressed: (event) => { if (!root.passwordMode) root.activateCurrent(); event.accepted = true }
        Keys.onEscapePressed: (event) => {
            if (root.passwordMode) root.selectTile(root.currentIndex)
            event.accepted = true
        }

        // Power-off chord (Ctrl+Alt+Del is handled elsewhere, per the
        // issue). canPowerOff mirrors upstream Main.qml's own caution
        // around calling powerOff() unconditionally (GreeterProxy.h).
        Keys.onPressed: (event) => {
            if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_P) {
                if (sddm.canPowerOff) sddm.powerOff()
                event.accepted = true
            }
        }
    }

    // --- clock ---------------------------------------------------------------
    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        color: root.colText
        font.family: root.fontFam
        font.pixelSize: 28
        text: Qt.formatTime(new Date(), "hh:mm")

        Timer {
            interval: 15000
            running: true
            repeat: true
            onTriggered: parent.text = Qt.formatTime(new Date(), "hh:mm")
        }
    }
}
