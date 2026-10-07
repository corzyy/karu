import QtQuick

import "../../core/theme"
import "../../core/services"

/**
 * NotificationStack — the banners that drop out of the island.
 *
 * A vertical stack of NotificationToast cards, newest on top. It is positioned
 * by shell.qml just under the island's bottom edge and clipped, so a new banner
 * appears to grow out from behind the island: its entry transition slides it
 * down from above while the cards below glide out of the way. Older banners are
 * pushed down and, past `Notifications.maxToasts`, off the bottom.
 *
 * While another surface owns the top of the screen (an expanded panel or the
 * media card) shell.qml sets `suppressed`, and the stack fades out so it never
 * collides with it.
 */
Item {
    id: root

    /// True while another island surface is open over the same space.
    property bool suppressed: false

    readonly property bool showing: !suppressed && Notifications.toasts.count > 0

    width: Theme.notificationWidth
    implicitHeight: column.implicitHeight
    height: implicitHeight
    clip: true

    opacity: showing ? 1 : 0
    visible: opacity > 0.01
    enabled: showing
    Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

    Column {
        id: column
        width: parent.width
        spacing: Theme.notificationGap

        // A new banner slides down out of the island and pops in on top.
        add: Transition {
            NumberAnimation {
                property: "opacity"; from: 0; to: 1
                duration: Theme.motionFast; easing.type: Theme.easeOut
            }
            NumberAnimation {
                property: "y"; from: -28
                duration: Theme.motionMedium; easing.type: Theme.easeEmphasized
            }
            NumberAnimation {
                property: "scale"; from: 0.9; to: 1
                duration: Theme.motionMedium
                easing.type: Theme.easeSpring; easing.overshoot: Theme.springOvershoot
            }
        }
        // NOTE: a Positioner (Column/Row/Grid/Flow) supports only the `add`,
        // `move` and `populate` transitions — there is no `remove` or
        // `displaced`. Repositioning as cards come and go is handled by `move`;
        // an exit animation would have to be driven by the toast itself before
        // the model drops it (see Notifications.qml).
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Theme.motionMedium; easing.type: Theme.easeEmphasized
            }
        }
        populate: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motionFast }
        }

        Repeater {
            model: Notifications.toasts
            delegate: NotificationToast {}
        }
    }
}
