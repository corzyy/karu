import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../../core/theme"
import "../../core/services"
import "../widgets"

/**
 * ControlNotificationsCard — the Control Center's live notification list.
 *
 * Every tracked notification (newest first) from the shared `Notifications`
 * store, with a "Clear all" action. The card reports the height it needs to show
 * the whole list via `preferredHeight`; the Control Center grows the tile (and
 * with it the island) to that height automatically, so the list expands as
 * notifications arrive and shrinks back as they are dismissed. The tile never
 * goes below the grid slot the layout gives the Notifications control.
 *
 * Once the list outgrows the room the island can afford, the rows scroll under
 * the pinned header instead of being clipped.
 *
 * A click dismisses a row and a sideways swipe throws it away (past a third of
 * the width it flies off, otherwise it springs back); as you drag, the row
 * squashes and the rows below glide up to close the gap.
 *
 * It is a standalone component so the Control Center panel can drop it into any
 * grid slot the layout gives the Notifications control.
 */
Rectangle {
    id: notifCard

    // The control's grid slot sets width/height. Clip so a short slot never
    // bleeds past the panel.
    clip: true
    radius: Theme.radiusCard
    color: "transparent"
    gradient: TileGlass {}
    border.width: 1
    border.color: Theme.border

    // Live swipe state, shared by every row: which row is being dragged
    // (`-1` when none) and how far it has been pulled sideways. Rows below
    // read this to close the gap it leaves, so a swipe puts some "pressure"
    // on the rest of the list instead of moving the card in isolation.
    property int dragIndex: -1
    property real dragOffset: 0
    /// True once a swipe is committed to dismissal; lets the gap reset in
    /// step with the row actually leaving the model.
    property bool dragDismissing: false
    /// Briefly true while resetting, so the gap snaps shut in time with the
    /// row being removed instead of easing at a different speed.
    property bool dragSnap: false

    /// The height this card needs to show every notification, padding included.
    /// The Control Center reads this to grow the tile (and the island) to fit,
    /// so the list expands as notifications arrive and shrinks as they clear.
    readonly property real preferredHeight:
        notifContent.implicitHeight + Theme.cardPadding * 2

    function endDrag() {
        dragSnap = true
        dragIndex = -1
        dragOffset = 0
        dragSnap = false
    }

    // A dismissed row leaves `history`, which shifts the rows below it up a
    // slot; snapping the swipe offset at that same moment cancels the move,
    // so the list settles without a jump.
    Connections {
        target: Notifications.history
        function onCountChanged() {
            if (notifCard.dragDismissing) {
                notifCard.dragDismissing = false
                notifCard.endDrag()
            }
        }
    }

    ColumnLayout {
        id: notifContent
        // Fill the tile: the header stays pinned to the top while the list below
        // takes the remaining height and scrolls once it overflows.
        anchors.fill: parent
        anchors.margins: Theme.cardPadding
        spacing: Theme.spaceSm

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Notifications"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sectionSize
                font.weight: Font.Medium
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: Notifications.history.count > 0
                text: "Clear all"
                color: clearHover.hovered ? Theme.accent : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: Notifications.clearAll()
                }
            }
        }

        Text {
            visible: Notifications.history.count === 0
            text: "No notifications"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
        }

        // The scrollable list. `implicitHeight` reports the full list so the
        // hidden measuring card still drives the tile's auto-growth; once the
        // tile is capped by the screen, this Flickable reveals the overflow. A
        // vertical flick scrolls the list while a horizontal drag still swipes
        // a row away.
        Item {
            id: listArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: rowsColumn.implicitHeight

            Flickable {
                id: listFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: rowsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                clip: true

                Column {
                    id: rowsColumn
                    width: listFlick.width
                    spacing: notifContent.spacing

                    Repeater {
                        model: Notifications.history
                        delegate: Item {
                            id: delegateRoot
                            required property int nid
                            required property string appName
                            required property string appIcon
                            required property string summary
                            required property string body
                            required property int index

                            readonly property real rowHeight: notifRow.implicitHeight + Theme.spaceMd * 2
                            // How far this row has been pulled, 0..1, driving its squash.
                            readonly property real squeeze: notifCard.dragIndex >= 0
                                ? Math.min(1, Math.abs(notifCard.dragOffset) / (delegateRoot.width * 0.6))
                                : 0
                            // Rows below the dragged one glide up to close the gap it
                            // leaves; `shiftAnim` trails the finger for a springy feel.
                            readonly property real shift:
                                (notifCard.dragIndex >= 0 && index > notifCard.dragIndex)
                                    ? delegateRoot.rowHeight * delegateRoot.squeeze : 0
                            property real shiftAnim: shift

                            Behavior on shiftAnim {
                                enabled: !notifCard.dragSnap
                                NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
                            }

                            width: rowsColumn.width
                            // Fixed slot: the card inside squashes without resizing the
                            // panel, and the rows below are nudged up with a transform.
                            height: delegateRoot.rowHeight
                            clip: true
                            transform: Translate { y: -delegateRoot.shiftAnim }

                            // The visible card; it is the drag target so it can be swiped
                            // sideways and thrown away. It squashes vertically while it is
                            // the row being dragged.
                            Rectangle {
                                id: card
                                width: parent.width
                                height: delegateRoot.rowHeight
                                    * (notifCard.dragIndex === index ? 1 - delegateRoot.squeeze : 1)
                                radius: Theme.radiusInner
                                clip: true
                                color: rowHover.hovered ? Theme.surfaceHover : Theme.surfaceElevated
                                // Fade out as the card is dragged away from rest.
                                opacity: 1 - Math.min(1, Math.abs(x) / (width * 0.6))

                                Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
                                // Snap back to rest, but not while dragging or flying out.
                                Behavior on x {
                                    enabled: !swipe.drag.active && !flingOut.running
                                    NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
                                }
                                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }

                                // Whole-row target: a click dismisses, a sideways drag
                                // throws the notification away. Declared before the content
                                // so the close affordance still gets its own clicks.
                                MouseArea {
                                    id: swipe
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    drag.target: card
                                    drag.axis: Drag.XAxis
                                    drag.threshold: 8

                                    onClicked: {
                                        notifCard.endDrag()
                                        Notifications.dismissById(delegateRoot.nid)
                                    }

                                    onPressed: {
                                        notifCard.dragIndex = delegateRoot.index
                                        notifCard.dragOffset = 0
                                    }
                                    // Track the live drag distance so the rest of the
                                    // list reacts under the finger.
                                    onPositionChanged: {
                                        if (swipe.drag.active)
                                            notifCard.dragOffset = card.x
                                    }
                                    // The list can steal the grab for a vertical
                                    // scroll, so reset the swipe state if it does.
                                    onCanceled: notifCard.endDrag()
                                    onReleased: {
                                        // Past a third of the width it is thrown away;
                                        // otherwise it springs back and the list reopens.
                                        if (Math.abs(card.x) > delegateRoot.width * 0.3) {
                                            flingOut.to = (card.x < 0 ? -1 : 1) * delegateRoot.width
                                            flingOut.start()
                                            settle.to = flingOut.to
                                            settle.duration = Theme.motionFast
                                            settle.start()
                                            notifCard.dragDismissing = true
                                        } else {
                                            card.x = 0
                                            settle.to = 0
                                            settle.duration = Theme.motionMedium
                                            settle.start()
                                        }
                                    }
                                }

                                // Eases the shared drag offset back to rest (sprung back)
                                // or fully out (thrown away), so the squash and the rows
                                // below settle smoothly either way.
                                NumberAnimation {
                                    id: settle
                                    target: notifCard
                                    property: "dragOffset"
                                    to: 0
                                    duration: Theme.motionMedium
                                    easing.type: Theme.easeOut
                                }

                                // Carries the card the rest of the way off, then dismisses.
                                NumberAnimation {
                                    id: flingOut
                                    target: card
                                    property: "x"
                                    duration: Theme.motionFast
                                    easing.type: Theme.easeOut
                                    onStopped: {
                                        settle.stop()
                                        Notifications.dismissById(delegateRoot.nid)
                                    }
                                }

                                RowLayout {
                                    id: notifRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spaceMd
                                    anchors.rightMargin: Theme.spaceMd
                                    spacing: Theme.spaceMd

                                    // App icon in a tinted circle, falling back to the app's
                                    // initial (or a bell when it has no name).
                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: width / 2
                                        color: Theme.accent

                                        IconImage {
                                            id: ccIcon
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            visible: source.length > 0 && status === Image.Ready
                                            source: Notifications.iconSource(appIcon)
                                            asynchronous: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !ccIcon.visible
                                            text: appName.length > 0 ? appName.charAt(0).toUpperCase() : "\uF0F3"
                                            color: Theme.background
                                            font.family: appName.length > 0 ? Theme.fontFamily : Theme.iconFont
                                            font.pixelSize: Theme.titleSize
                                            font.weight: Font.Bold
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            visible: text.length > 0
                                            text: appName
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
                                            text: summary
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.titleSize
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            textFormat: Text.PlainText
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            visible: text.length > 0
                                            text: body
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.titleSize - 1
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            textFormat: Text.PlainText
                                        }
                                    }

                                    // Close affordance (the row itself is also a dismiss target).
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
                                            onClicked: Notifications.dismissById(delegateRoot.nid)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // A slim, auto-hiding scroll thumb, shown only when the list really
            // overflows the tile.
            Rectangle {
                id: scrollThumb
                readonly property bool scrolling: listFlick.contentHeight > listFlick.height
                visible: scrolling
                width: 3
                radius: width / 2
                color: Theme.textDim
                opacity: 0.7
                height: scrolling
                    ? Math.max(24, listFlick.height * (listFlick.height / listFlick.contentHeight))
                    : 0
                x: listArea.width - width
                y: scrolling
                    ? (listFlick.height - height)
                        * (listFlick.contentY / (listFlick.contentHeight - listFlick.height))
                    : 0
            }
        }
    }
}
