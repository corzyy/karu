import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

import "../../core/theme"
import "../widgets"

/**
 * NetworkPanel — the merged Wi-Fi + LAN dialog, hosted by DetailCard.
 *
 * Header (back chevron, title, Wi-Fi radio switch), a "Wi-Fi" section listing
 * the visible networks, and a "LAN" section with the wired device's details and
 * a connect / disconnect action. Scanning runs while the dialog is up; every
 * action is a no-op with no adapter.
 */
Flickable {
    id: root

    signal closeRequested()

    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property var wifiDevice: {
        var list = Networking.devices.values
        for (var i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wifi)
                return list[i]
        return null
    }
    readonly property var wiredDevice: {
        var list = Networking.devices.values
        for (var i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wired)
                return list[i]
        return null
    }

    readonly property var networks: {
        if (!wifiDevice)
            return []
        var list = wifiDevice.networks.values.filter(function(n) {
            return n.name && n.name.length > 0
        })
        list.sort(function(a, b) { return b.signalStrength - a.signalStrength })
        return list
    }

    readonly property bool wiredConnected: wiredDevice ? wiredDevice.connected : false
    readonly property string wiredStatus:
        !wiredDevice ? "No adapter"
        : wiredConnected ? "Connected"
        : wiredDevice.hasLink ? "Disconnected"
        : "Cable unplugged"

    function toggleWired() {
        if (!wiredDevice)
            return
        if (wiredDevice.connected)
            wiredDevice.disconnect()
        else if (wiredDevice.network)
            wiredDevice.network.connect()
    }

    Component.onCompleted: if (root.wifiDevice) root.wifiDevice.scannerEnabled = true
    Component.onDestruction: if (root.wifiDevice) root.wifiDevice.scannerEnabled = false

    ColumnLayout {
        id: content
        width: root.width
        spacing: 0

        // Header: back · title · Wi-Fi radio switch.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: width / 2
                color: backHover.hovered ? Theme.surfaceHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uF104" // nf-fa-angle_left
                    color: Theme.textPrimary
                    font.family: Theme.iconFont
                    font.pixelSize: 17
                }

                HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }

            Text {
                text: "Network"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            Switch {
                enabled: root.wifiDevice !== null
                checked: root.wifiDevice !== null && Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        // ── Wi-Fi ────────────────────────────────────────────────────────────
        Item { Layout.preferredHeight: Theme.spaceLg }

        Text {
            text: "Wi-Fi"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sectionSize
            font.weight: Font.Medium
        }

        Item { Layout.preferredHeight: Theme.spaceSm }

        Text {
            Layout.fillWidth: true
            visible: root.wifiDevice === null || !Networking.wifiEnabled
            text: root.wifiDevice === null ? "No Wi-Fi adapter." : "Wi-Fi is off."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
        }

        Repeater {
            model: (root.wifiDevice !== null && Networking.wifiEnabled) ? root.networks : []

            delegate: WifiNetworkRow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spaceSm
                network: modelData
            }
        }

        // ── LAN ──────────────────────────────────────────────────────────────
        Item { Layout.preferredHeight: Theme.spaceLg }

        Text {
            text: "LAN"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sectionSize
            font.weight: Font.Medium
        }

        Item { Layout.preferredHeight: Theme.spaceSm }

        Text {
            Layout.fillWidth: true
            visible: root.wiredDevice === null
            text: "No wired adapter."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.wiredDevice !== null
            implicitHeight: wiredInfo.implicitHeight + Theme.spaceLg * 2
            radius: Theme.radiusInner
            color: "transparent"
            gradient: TileGlass {}
            border.width: 1
            border.color: root.wiredConnected ? Theme.accent : Theme.border

            ColumnLayout {
                id: wiredInfo
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spaceLg
                anchors.rightMargin: Theme.spaceLg
                spacing: Theme.spaceXs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceMd

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: Theme.iconCircle

                        Text {
                            anchors.centerIn: parent
                            text: "\uF1E6" // nf-fa-plug
                            color: root.wiredConnected ? Theme.accent : Theme.textSecondary
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.wiredDevice ? (root.wiredDevice.name || "Wired") : ""
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleSize
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.wiredStatus
                            color: root.wiredConnected ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.subtitleSize
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: wiredAction.implicitWidth + Theme.spaceXl
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.wiredDevice !== null && root.wiredDevice.hasLink
                        radius: height / 2
                        color: root.wiredConnected ? "transparent" : Theme.accentMuted
                        border.width: root.wiredConnected ? 1 : 0
                        border.color: Theme.border

                        Text {
                            id: wiredAction
                            anchors.centerIn: parent
                            text: root.wiredConnected ? "Disconnect" : "Connect"
                            color: root.wiredConnected ? Theme.textSecondary : Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.subtitleSize
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleWired()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spaceXs
                    visible: root.wiredDevice !== null && root.wiredDevice.address
                    text: "Address  " + (root.wiredDevice ? root.wiredDevice.address : "")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.wiredDevice !== null && root.wiredDevice.linkSpeed > 0
                    text: "Link  " + (root.wiredDevice ? root.wiredDevice.linkSpeed : 0) + " Mb/s"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                }
            }
        }
    }
}
