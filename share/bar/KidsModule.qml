// KidsModule.qml -- the parent's bar widget: one dot per logged-in kid,
// an "ask a parent" badge, a click/Enter quick-action menu (SPEC.md R-BAR-1..3, I-1, I-6).
// See docs/bar.md for the confirmed/unverified Omarchy shell-plugin API list.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
    id: root
    moduleName: "omarchy-kids.bar"
    ipcTarget: "omarchy-kids.bar"

    // --- external commands, every path overridable for tests/dev ----------
    readonly property string statusPath: Quickshell.env("OMARCHY_KIDS_STATUS_JSON") || "/run/omarchy-kids/status.json"
    // Absolute, and not from the environment (AGENTS.md rule 9, review S12).
    readonly property string barCtlBin: "/usr/bin/omarchy-kids-bar"
    readonly property string kidsBin: "/usr/bin/omarchy-kids"
    // How many more minutes one click grants (bin/omarchy-kids-time grant
    // takes any positive integer; this is just this menu's one-click amount).
    readonly property int grantMinutes: 15

    // --- status.json (R-BAR-3) ---------------------------------------------
    property bool hasFile: false
    property var liveKids: []   // [{kid, initial, minutesLeft, paused}]
    property int openRequestCount: 0
    property int cursorIndex: 0

    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.reloadStatus()
        onTextChanged: root.reloadStatus()
    }

    // Renders nothing when the file is missing or unreadable (I-6: no
    // control shown for data that isn't there) -- same defensive
    // try/catch-around-text() shape share/launcher/shell.qml uses, since
    // whether a missing FileView.path throws or just returns "" was not
    // confirmed either.
    function reloadStatus() {
        var text = ""
        try {
            text = statusFile.text()
        } catch (e) {
            text = ""
        }
        if (!text || text.length === 0) {
            root.hasFile = false
            root.liveKids = []
            root.openRequestCount = 0
            if (root.cursorIndex >= root.menuRows.length) root.cursorIndex = 0
            return
        }
        var data
        try {
            data = JSON.parse(text)
        } catch (e) {
            root.hasFile = false
            root.liveKids = []
            root.openRequestCount = 0
            if (root.cursorIndex >= root.menuRows.length) root.cursorIndex = 0
            return
        }
        root.hasFile = true
        // R-NOTIFY-7 (R-BAR-3): the count comes root-written with the rest of
        // the document -- no command runs from the parent's unprivileged bar
        // (omarchy-kids-ask list is only readable by root/omarchy-parents, and
        // the widget must not depend on that).
        root.openRequestCount = Math.max(0, Math.round(Number(data && data.open_requests) || 0))
        var rows = (data && data.kids) || []
        var out = []
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i] || {}
            if (row.live !== true) continue
            out.push({
                kid: String(row.kid || ""),
                slug: kidSlug(row.kid),
                initial: kidInitial(row.kid),
                minutesLeft: Math.max(0, Math.round(Number(row.minutes_left) || 0)),
                paused: row.paused === true
            })
        }
        root.liveKids = out
        if (root.cursorIndex >= root.menuRows.length) root.cursorIndex = 0
    }

    function kidSlug(kid) {
        var s = String(kid || "")
        return s.indexOf("kid-") === 0 ? s.slice(4) : s
    }

    function kidInitial(kid) {
        var s = kidSlug(kid)
        return s.length > 0 ? s.charAt(0).toUpperCase() : "?"
    }

    // --- open request badge: read from status.json (R-NOTIFY-7) ------------
    // The count is root-written into status.json's `open_requests` and reloaded
    // with the rest of the document (reloadStatus). No command runs from the
    // bar: `omarchy-kids-ask list` is readable only by root/omarchy-parents, so
    // polling it here could never populate the badge.

    // --- menu rows: R-BAR-2's three actions ("give more time, end
    //     session, open Kids Mode") -- the first two per live kid (with
    //     that kid's own status line, R-BAR-1's "Ada · paused · 32 min"),
    //     plus the open-requests row this widget also carries (SPEC.md's
    //     Ask flow: "queue -> panel or bar widget approve") ------------
    function makeMenuRows(kids, requests, minutes) {
        var rows = []
        for (var i = 0; i < kids.length; i++) {
            var k = kids[i]
            var status = k.paused ? "paused" : "live"
            var who = k.initial + " " + k.slug + " · " + status + " · " + k.minutesLeft + " min"
            rows.push({
                kind: "grant",
                kid: k.kid,
                actionLabel: "Give " + minutes + " more",
                detailLabel: who
            })
            rows.push({
                kind: "end",
                kid: k.kid,
                actionLabel: "End session",
                detailLabel: who
            })
        }
        rows.push({
            kind: "requests",
            label: "Open requests" + (requests > 0 ? " (" + requests + ")" : "")
        })
        rows.push({ kind: "open", label: "Open Kids Mode" })
        return rows
    }

    readonly property var menuRows: root.makeMenuRows(root.liveKids, root.openRequestCount, root.grantMinutes)

    // --- actions: shell out, never block the widget ------------------------
    Process { id: actionProcess }

    function runDetached(argv) {
        actionProcess.command = argv
        actionProcess.running = true
    }

    // Neither "give N more minutes" nor "end session" ever runs
    // bin/omarchy-kids-time or loginctl directly from here -- both need
    // root, and this widget runs in the parent's ordinary, unprivileged
    // session. bin/omarchy-kids-bar grant/end is the one place that
    // decides how to open a real terminal for the sudo prompt (parent's
    // own login password, I-8) -- see that command's own header for why.
    function activateRow(row) {
        if (!row) return
        if (row.kind === "grant") {
            root.runDetached([root.barCtlBin, "grant", row.kid, String(root.grantMinutes)])
        } else if (row.kind === "end") {
            root.runDetached([root.barCtlBin, "end", row.kid])
        } else if (row.kind === "requests") {
            root.runDetached([root.kidsBin, "--requests"])
        } else if (row.kind === "open") {
            root.runDetached([root.kidsBin])
        }
        root.close()
    }

    // --- visibility: nothing to show, nothing painted -----------------------
    visible: root.hasFile && (root.liveKids.length > 0 || root.openRequestCount > 0)
    implicitWidth: root.visible ? iconRow.implicitWidth + 12 : 0
    implicitHeight: root.visible ? 22 : 0

    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.liveKids
            delegate: Rectangle {
                required property var modelData
                width: 16
                height: 16
                radius: 8
                color: modelData.paused ? Color.muted : Color.accent
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.initial
                    color: Color.background
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        Rectangle {
            visible: root.openRequestCount > 0
            width: reqBadgeText.implicitWidth + 10
            height: 16
            radius: 8
            color: Color.urgent
            Text {
                id: reqBadgeText
                anchors.centerIn: parent
                text: String(root.openRequestCount)
                color: Color.background
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        onClicked: root.toggle()
    }

    Keys.onReturnPressed: root.toggle()
    Keys.onEnterPressed: root.toggle()

    KeyboardPanel {
        id: menu
        anchorItem: clickArea
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: menu.fittedContentWidth(260)
        contentHeight: menu.fittedContentHeight(rowsColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onMoveRequested: function (dx, dy) {
                if (dy === 0) return
                var n = root.menuRows.length
                if (n === 0) return
                root.cursorIndex = ((root.cursorIndex + dy) % n + n) % n
            }
            onActivateRequested: root.activateRow(root.menuRows[root.cursorIndex])
            onReturnRequested: root.activateRow(root.menuRows[root.cursorIndex])
            onCloseRequested: root.close()

            Column {
                id: rowsColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 4

                Repeater {
                    model: root.menuRows
                    delegate: Rectangle {
                        id: rowDelegate
                        required property var modelData
                        required property int index
                        width: rowsColumn.width
                        height: rowDelegate.modelData.kind === "grant" || rowDelegate.modelData.kind === "end" ? 44 : 28
                        radius: 6
                        color: index === root.cursorIndex ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent) : "transparent"

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                visible: rowDelegate.modelData.actionLabel !== undefined || rowDelegate.modelData.detailLabel === undefined
                                width: parent.width
                                text: rowDelegate.modelData.actionLabel || rowDelegate.modelData.label
                                color: root.bar ? root.bar.foreground : Color.foreground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: 13
                                font.bold: rowDelegate.modelData.actionLabel !== undefined
                            }

                            Text {
                                visible: rowDelegate.modelData.detailLabel !== undefined
                                width: parent.width
                                text: rowDelegate.modelData.detailLabel || ""
                                color: root.bar ? root.bar.foreground : Color.foreground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.cursorIndex = rowDelegate.index
                                root.activateRow(rowDelegate.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
