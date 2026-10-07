import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

import "../../core/theme"

/**
 * WifiNetworkRow — one Wi-Fi network in the Wi-Fi dialog.
 *
 * Shows a signal glyph, the SSID, whether it is secured, and a Connect /
 * Disconnect action. A secured network that is not yet known reveals an inline
 * password field (submitted with `connectWithPsk`).
 */
Rectangle {
    id: row

    property var network: null
    property bool showPass: false

    readonly property bool connected: network ? network.connected : false
    readonly property bool secured: network ? network.security !== WifiSecurityType.Open : false
    readonly property bool known: network ? network.known : false

    readonly property string statusText:
        !network ? ""
        : connected ? "Connected"
        : known ? "Saved"
        : "Available"

    readonly property string actionText: connected ? "Disconnect" : "Connect"

    implicitHeight: 46 + (showPass ? 40 : 0)
    radius: Theme.radiusInner
    color: "transparent"
    gradient: TileGlass {}
    border.width: 1
    border.color: connected ? Theme.accent : Theme.border

    function activate() {
        if (!network)
            return
        if (network.connected)
            network.disconnect()
        else if (network.known || network.security === WifiSecurityType.Open)
            network.connect()
        else
            showPass = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceMd
        anchors.rightMargin: Theme.spaceMd
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            spacing: Theme.spaceMd

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter
                radius: width / 2
                color: Theme.iconCircle

                Text {
                    anchors.centerIn: parent
                    text: "\uF1EB" // nf-fa-wifi
                    color: row.connected ? Theme.accent : Theme.textSecondary
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceXs

                    Text {
                        Layout.fillWidth: true
                        text: row.network ? row.network.name : ""
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.titleSize
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: row.secured
                        text: "\uF023" // nf-fa-lock
                        color: Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: row.statusText
                    color: row.connected ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                }
            }

            Rectangle {
                Layout.preferredWidth: actionLabel.implicitWidth + Theme.spaceXl
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: row.connected ? "transparent" : Theme.accentMuted
                border.width: row.connected ? 1 : 0
                border.color: Theme.border

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: row.actionText
                    color: row.connected ? Theme.textSecondary : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.activate()
                }
            }
        }

        // Inline password field for a secured, unknown network.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.bottomMargin: Theme.spaceSm
            visible: row.showPass
            radius: Theme.radiusInner
            color: Theme.surfaceElevated
            border.width: 1
            border.color: pass.activeFocus ? Theme.accent : Theme.border

            TextInput {
                id: pass
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceMd
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                echoMode: TextInput.Password
                selectionColor: Theme.accent
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pass.text.length === 0
                    text: "Password"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                }

                onAccepted: {
                    if (row.network && pass.text.length > 0)
                        row.network.connectWithPsk(pass.text)
                    row.showPass = false
                }
            }
        }
    }
}
