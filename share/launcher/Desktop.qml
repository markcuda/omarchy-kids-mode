// The Level 2 background stays below apps and never takes keyboard focus.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: desktop
    property string clock: ""
    property string timeLeft: ""
    signal appsRequested()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "omarchy-kids-desktop"
    color: theme.background
    KidsTheme { id: theme }

    Column {
        anchors.centerIn: parent
        spacing: 24
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Your desktop"
            color: theme.foreground
            font.family: theme.fontFamily
            font.pixelSize: 36
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(420, desktop.width - 48)
            height: 100
            radius: 16
            color: theme.cardFill
            border.color: theme.accent
            border.width: 2
            Text {
                anchors.centerIn: parent
                text: "Super + Space\nFind your apps"
                horizontalAlignment: Text.AlignHCenter
                color: theme.foreground
                font.family: theme.fontFamily
                font.pixelSize: 24
            }
            MouseArea { anchors.fill: parent; onClicked: desktop.appsRequested() }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Super is the key beside Alt."
            color: theme.caption
            font.family: theme.fontFamily
            font.pixelSize: 18
        }
    }
    Text {
        id: desktopClock
        anchors { top: parent.top; right: parent.right; margins: 40 }
        text: desktop.clock
        color: theme.foreground
        font.family: theme.fontFamily
        font.pixelSize: 28
    }
    // Root says how much time is left; the launcher only shows it.
    Text {
        visible: desktop.timeLeft !== ""
        anchors { top: desktopClock.bottom; right: parent.right; topMargin: 8; rightMargin: 40 }
        text: desktop.timeLeft
        color: theme.caption
        font.family: theme.fontFamily
        font.pixelSize: 16
    }
    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 32 }
        text: "Super + Q: Close app    ·    Super + Shift + K: Grown-up exit"
        color: theme.caption
        font.family: theme.fontFamily
        font.pixelSize: 16
    }
}
