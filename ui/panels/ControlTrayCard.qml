import QtQuick

import Quickshell.Services.SystemTray

import "../../core/theme"
import "../widgets"

/**
 * ControlTrayCard — the Control Center's system tray.
 *
 * A single row of every StatusNotifierItem registered on the session
 * (`Quickshell.Services.SystemTray`), so tray apps — network, Bluetooth,
 * clipboard managers, VPNs and the like — are reachable from the Control
 * Center. The row scrolls sideways when the icons outgrow their grid slot.
 *
 * Each icon behaves like a conventional tray icon:
 *   - left click  → the item's primary action (`activate()`);
 *   - middle click→ the secondary action (`secondaryActivate()`);
 *   - right click → its menu, rendered Karu-styled by ui/widgets/TrayMenu.qml
 *     (the tile bubbles a `menuRequested` up to shell.qml, which owns it);
 *   - wheel       → the item's scroll action (e.g. a mixer's volume);
 *   - menus-only items open their menu on a left click too.
 *
 * It is a standalone component so the Control Center panel can drop it into any
 * grid slot the layout gives the System Tray control; `enabled: false` (the
 * Settings editor) makes it a non-interactive preview.
 */
Rectangle {
    id: trayCard

    /// Every live tray item, in registration order.
    readonly property var items: SystemTray.items.values
    readonly property bool empty: items.length === 0
    /// Edge of one icon's circular hit box.
    readonly property int box: 36

    /// A right click (or a menu-only item's left click) asked for the item's
    /// own menu. `rect` is the icon's scene rectangle, so shell.qml can hang
    /// the themed menu from it. The menu itself is rendered by
    /// ui/widgets/TrayMenu.qml.
    signal menuRequested(var item, var rect)

    clip: true
    radius: Theme.radiusCard
    color: "transparent"
    gradient: TileGlass {}
    border.width: 1
    border.color: Theme.border

    // Placeholder-safe: with no tray apps running the tile reads as an empty
    // tray rather than a blank slot.
    Row {
        visible: trayCard.empty
        anchors.centerIn: parent
        spacing: Theme.spaceSm

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uF0C9" // nf-fa-bars
            color: Theme.textDim
            font.family: Theme.iconFont
            font.pixelSize: Theme.toggleIconSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "No tray items"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
        }
    }

    // The icon row. A Flickable so a crowded tray can be scrolled sideways;
    // it stays centred while the icons fit (contentWidth pinned to the view).
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: Theme.padTight
        anchors.rightMargin: Theme.padTight
        visible: !trayCard.empty
        contentWidth: content.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        Item {
            id: content
            width: Math.max(flick.width, trayRow.width)
            height: flick.height

            Row {
                id: trayRow
                height: parent.height
                x: Math.round((content.width - width) / 2)
                spacing: Theme.spaceSm

                Repeater {
                    model: trayCard.items

                    delegate: Item {
                        id: trayItem
                        required property var modelData

                        readonly property var item: modelData

                        width: trayCard.box
                        height: trayRow.height

                        /// The icon's scene rectangle, handed to the themed menu.
                        function iconRect() {
                            var r = chip.mapToItem(null, 0, 0, chip.width, chip.height)
                            return { x: r.x, y: r.y, width: r.width, height: r.height }
                        }

                        Rectangle {
                            id: chip
                            anchors.centerIn: parent
                            width: Math.min(trayCard.box, trayItem.height)
                            height: width
                            radius: width / 2
                            color: chipHover.hovered ? Theme.surfaceHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

                            // `icon` is already an Image-usable source (a path,
                            // a themed name resolved by Quickshell, or an image
                            // provider URL).
                            Image {
                                id: trayIcon
                                anchors.centerIn: parent
                                width: Math.round(chip.width * 0.58)
                                height: width
                                source: trayItem.item.icon
                                sourceSize.width: Math.round(chip.width * 2)
                                sourceSize.height: Math.round(chip.width * 2)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                // Passive items read dimmer, as in a real tray.
                                opacity: trayItem.item.status === Status.Passive ? 0.6 : 1
                                Behavior on opacity { NumberAnimation { duration: Theme.motionSnap } }
                            }

                            // Fallback while the icon loads, or when an item
                            // ships none.
                            Text {
                                anchors.centerIn: parent
                                visible: trayIcon.status !== Image.Ready
                                text: "\uF0C9" // nf-fa-bars
                                color: Theme.textSecondary
                                font.family: Theme.iconFont
                                font.pixelSize: Math.round(chip.width * 0.4)
                            }
                        }

                        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: function (mouse) {
                                var it = trayItem.item
                                if (mouse.button === Qt.MiddleButton) {
                                    it.secondaryActivate()
                                } else if (mouse.button === Qt.RightButton) {
                                    if (it.hasMenu)
                                        trayCard.menuRequested(it, trayItem.iconRect())
                                } else if (it.onlyMenu && it.hasMenu) {
                                    trayCard.menuRequested(it, trayItem.iconRect())
                                } else {
                                    it.activate()
                                }
                            }

                            onWheel: function (wheel) {
                                trayItem.item.scroll(wheel.angleDelta.y, false)
                                wheel.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
