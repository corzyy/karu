import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Widgets

import "../../core/theme"
import "../../core/services"

/**
 * NotificationToast — one banner in the island's notification stack.
 *
 * A compact card: the sending app's icon, its name, the summary and up to two
 * lines of body, and a × affordance. The whole card is a dismiss target.
 *
 * The delegate is instantiated by the Repeater in NotificationStack.qml, so the
 * `required` properties below are filled from the ListModel roles. New banners
 * are animated in by the stack's positioner transitions; this component only
 * describes the card and owns its auto-expire timer.
 */
Rectangle {
    id: root

    // Model roles (see Notifications.qml `push`).
    required property int nid
    required property string appName
    required property string appIcon
    required property string summary
    required property string body
    required property int urgency
    required property bool resident
    required property bool durable
    required property real timeout
    /// Model-driven exit request (auto-expiry / overflow prune); see
    /// Notifications.qml `beginLeave` and `pruneToasts`.
    required property bool leaving

    /// Critical notifications stay until dismissed, like a resident one.
    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property bool sticky: resident || critical
    readonly property int pad: Theme.spaceSm + 2
    readonly property int baseHeight: Math.max(Theme.notificationMinHeight, row.implicitHeight + pad * 2)

    width: Theme.notificationWidth
    implicitHeight: baseHeight * root.shrink
    height: implicitHeight
    radius: Theme.radiusCard
    color: Theme.background
    border.width: 1
    border.color: root.critical ? Theme.danger
                : (hover.hovered ? Theme.hoverBorder : Theme.border)
    clip: true

    Behavior on border.color { ColorAnimation { duration: Theme.fadeDuration } }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

    // ── Exit animation ───────────────────────────────────────────────────────
    // A Positioner has no `remove` transition, so the banner animates itself
    // out first and is only then dropped from the model: it fades, scales down,
    // rises and collapses its height, and the cards below glide up on the
    // column's `move` transition as the slot closes. `dismissing` guards against
    // a second trigger (the timer racing a click) while the exit plays.
    property bool dismissing: false
    /// "expire" keeps a durable notification in the history; "dismiss" really
    /// dismisses it (a click / the ×).
    property string exitAction: "expire"
    /// 1 at rest, animated to 0 to collapse the card's height without breaking
    /// the `implicitHeight` binding above.
    property real shrink: 1
    /// Upward drift during the exit (px); a transform, so it does not fight the
    /// column that positions the card.
    property real rise: 0
    transform: Translate { y: root.rise }

    function startExit(action) {
        if (action)
            root.exitAction = action
        if (root.dismissing)
            return
        root.dismissing = true
        exitAnim.restart()
    }

    function finishExit() {
        if (root.exitAction === "dismiss")
            Notifications.dismissById(root.nid)
        else if (root.durable)
            Notifications.expireToast(root.nid)
        else
            Notifications.forget(root.nid)
    }

    onLeavingChanged: if (root.leaving) root.startExit("expire")

    ParallelAnimation {
        id: exitAnim
        NumberAnimation {
            target: root; property: "opacity"; to: 0
            duration: Theme.motionFast; easing.type: Theme.easeOut
        }
        NumberAnimation {
            target: root; property: "scale"; to: 0.92
            duration: Theme.motionFast; easing.type: Theme.easeOut
        }
        NumberAnimation {
            target: root; property: "shrink"; to: 0
            duration: Theme.motionMedium; easing.type: Theme.easeOut
        }
        NumberAnimation {
            target: root; property: "rise"; to: -16
            duration: Theme.motionMedium; easing.type: Theme.easeOut
        }
        onFinished: root.finishExit()
    }

    // Auto-expire unless the notification is sticky. Leaving starts the animated
    // exit above rather than dropping the banner outright. Durable notifications
    // stay in the history; transient ones are forgotten entirely.
    Timer {
        interval: Math.max(1500, root.timeout * 1000)
        running: !root.sticky && !root.dismissing
        onTriggered: Notifications.beginLeave(root.nid)
    }

    // Clicking anywhere on the card dismisses it.
    MouseArea {
        anchors.fill: parent
        enabled: !root.dismissing
        onClicked: root.startExit("dismiss")
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        spacing: Theme.spaceSm

        // App icon in a soft circle, with a bell fallback.
        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 1
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: width / 2
            color: Theme.iconCircle

            IconImage {
                id: icon
                anchors.fill: parent
                anchors.margins: 5
                visible: source.length > 0 && status === Image.Ready
                source: Notifications.iconSource(root.appIcon)
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: !icon.visible
                text: "\uF0F3" // nf-fa-bell
                color: root.critical ? Theme.danger : Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: Theme.subtitleSize + 2
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.appName
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.summary
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize - 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.body
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize - 2
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                textFormat: Text.PlainText
            }
        }

        // Close affordance (the card itself is also a dismiss target).
        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20

            Text {
                anchors.centerIn: parent
                text: "\uF00D" // nf-fa-times
                color: closeHover.hovered ? Theme.textPrimary : Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.subtitleSize
                Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
            }
            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                enabled: !root.dismissing
                onClicked: root.startExit("dismiss")
            }
        }
    }
}
