import QtQuick
import QtQuick.Layouts

import "../../core/theme"

/**
 * GameModePanel — the Control Center's Game Mode confirmation, hosted by
 * DetailCard.
 *
 * The Game Mode tile never flips the mode on its own: tapping it grows this
 * card out of the tile (the same morph as the Bluetooth / Wi-Fi / Display
 * dialogs), which states what Game Mode does and asks for a decision. Enabling
 * it switches the shell to a flat, animation-free, edge-to-edge bar; once it is
 * on, the same card offers to turn it back off.
 *
 * `Theme.gameMode` is the live state; the write goes through the `GameMode`
 * singleton (`GameMode.setEnabled`) so this prompt and the tile stay in sync.
 */
Item {
    id: root

    signal closeRequested()

    readonly property bool on: Theme.gameMode

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceLg

        // Icon + heading.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                radius: width / 2
                color: Theme.accentMuted

                Text {
                    anchors.centerIn: parent
                    text: "\uF11B" // nf-fa-gamepad
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.toggleIconSize
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.on ? "Game Mode is on" : "Enable Game Mode?"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.on
                ? "The bar is a flat, full-width strip with animations and the Wallhaven browser switched off."
                : "Turns the bar into a flat, full-width strip and switches off shell animations and the Wallhaven browser, to keep the shell light while gaming."
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        // Cancel / Enable or Keep on / Disable.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: height / 2
                color: cancelHover.hovered ? Theme.surfaceHover : "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: root.on ? "Keep on" : "Cancel"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                    font.weight: Font.Medium
                }

                HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: height / 2
                color: confirmHover.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: root.on ? "Disable" : "Enable"
                    color: Theme.backgroundSolid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                    font.weight: Font.DemiBold
                }

                HoverHandler { id: confirmHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        GameMode.setEnabled(!root.on)
                        root.closeRequested()
                    }
                }
            }
        }
    }
}
