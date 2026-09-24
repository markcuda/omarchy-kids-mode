// toast.qml -- the small top-right kid notice (SPEC.md R-TIME-3): it carries
// the time command's "N minutes left" warning and, with its own leading glyph
// (OMARCHY_KIDS_TOAST_ICON), the Wi-Fi refusal bin/omarchy-kids-wifi shows.
// Deliberately NOT keyboard-exclusive (that's timesup.qml's job) -- see
// docs/time.md.

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
    // Which plain glyph leads the card. The time warning's alarm clock is the
    // default; a caller whose words are not about time (the Wi-Fi notice)
    // names its own, so the icon never contradicts the message beside it
    // (I-6; live finding: a Wi-Fi refusal wore the clock).
    property string icon: Quickshell.env("OMARCHY_KIDS_TOAST_ICON") || "⏰"

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
            // share/avatars/*.svg, which are per-kid, not decorative). The
            // caller picks it (root.icon), so a time warning and a Wi-Fi
            // notice each show a glyph that matches their own words.
            Text {
                font.family: theme.fontFamily
                text: root.icon
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
