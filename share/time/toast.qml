// toast.qml -- the small top-right "N minutes left" warning (SPEC.md
// R-TIME-3), loaded by bin/omarchy-kids-time's show_toast. Deliberately NOT
// keyboard-exclusive (that's timesup.qml's job) -- see docs/time.md.

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    // Theme colors/font (docs/theming.md) — see share/qml/KidsTheme.qml.
    KidsTheme { id: theme }

    WlrLayershell.layer: WlrLayer.Overlay
    // Small and out of the way: this only reserves screen space if
    // exclusiveZone is set, and a toast shouldn't shove any app's
    // content around, so leave it at Quickshell's default (0, "don't
    // reserve").
    anchors {
        top: true
        right: true
    }
    margins {
        // Clear the launcher's top-right clock block (the time and the
        // "N minutes left" line under it). Both heights below are arithmetic
        // from the font sizes, not measured: the block comes to ~98-102px on
        // a short screen (launcher margin 32 under 640px tall) and ~122px on
        // a taller one (margin 56); 144 clears the worst case with a ~22px
        // cushion. The 2026-09-21 live check saw only the toast window's own
        // geometry (320x32 at y=120, message overflowing), not the block.
        top: 144
        right: 24
    }
    implicitWidth: 320
    // Size to the message, not to an empty Rectangle: a Rectangle with
    // anchors.fill has no implicit height of its own, so this was 32px and
    // the wrapped text overflowed the window over the clock. `cardContent`
    // is the Row of glyph + text, whose implicit height tracks the wrap.
    implicitHeight: cardContent.implicitHeight + 32
    color: "transparent"
    visible: true

    property string message: Quickshell.env("OMARCHY_KIDS_TOAST_TEXT") || ""

    // Auto-dismiss after 6s (issue #40 tightened this from the original
    // 8s) -- overridable only for a future test harness; there is no
    // env var for this today because nothing here has been run against
    // real Quickshell to confirm quitting a PanelWindow this way is
    // even the right shutdown path.
    Timer {
        interval: 6000
        running: true
        onTriggered: Qt.quit()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 8
        radius: 14
        color: theme.background
        border.color: theme.cardFill
        border.width: 2

        Row {
            id: cardContent
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 12

            // A plain glyph, not an icon asset: this repo ships no icon
            // font/svg set of its own for UI chrome (only
            // share/avatars/*.svg, which are per-kid, not decorative).
            Text {
                font.family: theme.fontFamily
                text: "⏰" // alarm clock
                font.pixelSize: 28
                color: theme.warning
            }

            Text {
                font.family: theme.fontFamily
                width: parent.width - 40
                text: root.message
                color: theme.foreground
                font.pixelSize: 16
                font.bold: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
