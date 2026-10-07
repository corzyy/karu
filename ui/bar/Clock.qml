import QtQuick

import "../../core/theme"
import "../../core/config"

/**
 * Clock — HH:mm, updating once a second, with an optional date beside it.
 *
 * A single instance is shared by the collapsed pill and the Control Center
 * (`shell.qml`): it behaves as the pill's clock at rest, then `timeSize` grows
 * and `showDate` reveals the date to the right of the time as it glides into
 * the Control Center header, so the same element visibly transitions between
 * the two.
 *
 * Uses a plain QML Timer so it works with zero extra services. Swap for
 * Quickshell.SystemClock if you prefer a shared clock instance.
 */
Item {
    id: root

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Format follows the Settings app (24-hour / seconds); the date pattern is
    // configurable too. Assigning `format` / `dateFormat` from outside still
    // overrides these.
    property string format: Settings.use24Hour
        ? (Settings.showSeconds ? "HH:mm:ss" : "HH:mm")
        : (Settings.showSeconds ? "h:mm:ss AP" : "h:mm AP")
    property string dateFormat: Settings.dateFormat

    /// Time size in pixels. Animated, so the clock can grow into the Control
    /// Center instead of being swapped for a second clock.
    property int timeSize: Theme.clockSize

    /// Reveal the date beside the time (Control Center only).
    property bool showDate: false

    /// Reassigned once a second; the two text bindings depend on it.
    property var now: new Date()

    // Laid out by hand rather than with a Row: the date box animates its width
    // from zero and the time must stay vertically centred against it throughout,
    // which anchors on a positioner's children cannot guarantee.
    Item {
        id: layout
        anchors.centerIn: parent

        readonly property int gap: Theme.spaceSm

        width: implicitWidth
        height: implicitHeight
        implicitWidth: timeLabel.implicitWidth +
            (root.showDate ? layout.gap + dateBox.width : 0)
        implicitHeight: Math.max(timeLabel.implicitHeight, dateLabel.implicitHeight)

        Text {
            id: timeLabel
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            text: Qt.formatDateTime(root.now, root.format)
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: root.timeSize
            font.weight: Font.Medium

            // The size rides the same panel spring as the glide, so the time
            // grows into the header as one motion with the shared status icons
            // rather than on a separate eased curve.
            Behavior on font.pixelSize {
                enabled: !Theme.motionOff
                SpringAnimation {
                    spring: Theme.panelSpring
                    damping: root.showDate ? Theme.panelDamping : Theme.panelCloseDamping
                    mass: Theme.panelMass
                    epsilon: Theme.panelEpsilon
                }
            }
        }

        // The date lives in a box whose width animates to zero when hidden, so
        // the time slides back to centre smoothly as the date unfolds beside it
        // rather than jumping when the line appears.
        Item {
            id: dateBox
            anchors.verticalCenter: parent.verticalCenter
            x: timeLabel.implicitWidth + layout.gap
            width: root.showDate ? dateLabel.implicitWidth : 0
            height: dateLabel.implicitHeight
            opacity: root.showDate ? 1 : 0
            clip: true

            // The date unfolds on the same panel spring so its width travels in
            // lockstep with the time's growth and the island's glide.
            Behavior on width {
                enabled: !Theme.motionOff
                SpringAnimation {
                    spring: Theme.panelSpring
                    damping: root.showDate ? Theme.panelDamping : Theme.panelCloseDamping
                    mass: Theme.panelMass
                    epsilon: Theme.panelEpsilon
                }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration; easing.type: Theme.easeOut } }

            Text {
                id: dateLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(root.now, root.dateFormat)
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.clockDateSize
                font.weight: Font.Medium
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
