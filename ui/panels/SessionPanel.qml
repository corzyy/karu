import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../core/theme"
import "../widgets"

/**
 * SessionPanel — the Session tab: a single rounded container with evenly spaced
 * icon+label buttons.
 *
 * Keyboard: ←/→ (or ↑/↓) move the highlight, Enter activates, Esc collapses the
 * island. The pointer also moves the highlight on hover, and clicking an item
 * activates it directly. The shell grants the panel keyboard focus while it is
 * open (see shell.qml).
 *
 * Activating runs the item's system action:
 *   Lock      -> raises the Karu lockscreen (see LockContext / Lockscreen)
 *   Suspend   -> systemctl suspend
 *   Log Out   -> uwsm stop (falls back to loginctl terminate-session)
 *   Reboot    -> systemctl reboot
 *   Power Off -> systemctl poweroff
 *
 * Commands run detached through Quickshell.execDetached() so the shell never
 * blocks.
 */
Rectangle {
    id: root

    /// Bubbled up so the island can collapse after an action is triggered.
    signal requestClose()

    /// Bubbled up when Lock is chosen, so the shell can raise the lockscreen
    /// instead of shelling out to an external locker.
    signal requestLock()

    implicitHeight: 84
    radius: Theme.radiusCard
    color: "transparent"

    /// Index of the highlighted action.
    property int selected: 0

    property var actions: [
        { icon: "\uF023", label: "Lock", lock: true },        // nf-fa-lock
        { icon: "\uF186", label: "Suspend",                   // nf-fa-moon_o
          command: ["systemctl", "suspend"] },
        { icon: "\uF08B", label: "Log Out",                   // nf-fa-sign_out
          command: ["sh", "-c",
            "command -v uwsm >/dev/null 2>&1 && exec uwsm stop || exec loginctl terminate-session \"$XDG_SESSION_ID\""] },
        { icon: "\uF021", label: "Reboot",                    // nf-fa-refresh
          command: ["systemctl", "reboot"] },
        { icon: "\uF011", label: "Power Off",                 // nf-fa-power_off
          command: ["systemctl", "poweroff"] }
    ]

    // ── Keyboard ─────────────────────────────────────────────────────────────
    focus: true
    Component.onCompleted: forceActiveFocus()
    onVisibleChanged: if (visible) forceActiveFocus()

    function move(delta) {
        var n = root.actions.length
        if (n === 0)
            return
        root.selected = (root.selected + delta + n) % n
    }

    function activate(index) {
        var a = root.actions[index]
        if (!a)
            return
        if (a.lock)
            root.requestLock()
        else
            Quickshell.execDetached(a.command)
        root.requestClose()
    }

    Keys.onLeftPressed: move(-1)
    Keys.onRightPressed: move(1)
    Keys.onUpPressed: move(-1)
    Keys.onDownPressed: move(1)
    Keys.onReturnPressed: activate(root.selected)
    Keys.onEnterPressed: activate(root.selected)
    Keys.onEscapePressed: root.requestClose()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceSm

        Repeater {
            model: root.actions

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property bool isSelected: index === root.selected

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusInner

                HoverHandler {
                    id: btnHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.selected = index
                }

                color: isSelected
                    ? Theme.accent
                    : (btnHover.hovered ? Theme.surfaceHover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spaceXs

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.icon
                        color: isSelected ? Theme.backgroundSolid : Theme.textPrimary
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.toggleIconSize
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.label
                        color: isSelected ? Theme.backgroundSolid : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.subtitleSize
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(index)
                }
            }
        }
    }
}
