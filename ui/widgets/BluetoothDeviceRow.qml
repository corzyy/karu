import QtQuick
import QtQuick.Layouts

import "../../core/theme"

/**
 * BluetoothDeviceRow — one row in the Bluetooth dialog's Saved / Nearby lists.
 *
 * Shows a (mapped) device glyph, the device name, a status subtitle and a
 * Connect / Disconnect / Pair action. All actions are no-ops with a null
 * `device`.
 */
Rectangle {
    id: row

    property var device: null

    implicitHeight: 46
    radius: Theme.radiusInner
    color: "transparent"
    gradient: TileGlass {}
    border.width: 1
    border.color: Theme.border

    // BlueZ reports freedesktop icon names, not Nerd Font glyphs — map the
    // common classes, fall back to the Bluetooth mark.
    function deviceGlyph(icon) {
        var s = String(icon || "").toLowerCase()
        if (s.indexOf("headphone") >= 0 || s.indexOf("headset") >= 0) return "\uF025"
        if (s.indexOf("speaker") >= 0 || s.indexOf("audio") >= 0)      return "\uF028"
        if (s.indexOf("phone") >= 0 || s.indexOf("mobile") >= 0)       return "\uF10B"
        if (s.indexOf("keyboard") >= 0)                                return "\uF11C"
        if (s.indexOf("mouse") >= 0)                                   return "\uF245"
        if (s.indexOf("computer") >= 0 || s.indexOf("laptop") >= 0)    return "\uF109"
        if (s.indexOf("game") >= 0)                                    return "\uF11B"
        return "\uF293" // nf-fa-bluetooth_b
    }

    readonly property bool connected: device ? device.connected : false

    readonly property string statusText: {
        if (!device) return ""
        if (device.connected) return "Connected"
        if (device.pairing) return "Pairing…"
        if (device.paired || device.bonded) return "Saved"
        return "Nearby"
    }

    readonly property string actionText: {
        if (!device) return ""
        if (device.connected) return "Disconnect"
        if (device.paired || device.bonded) return "Connect"
        return "Pair"
    }

    function act() {
        if (!device)
            return
        if (device.connected)
            device.disconnect()
        else if (device.paired || device.bonded)
            device.connect()
        else
            device.pair()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceMd
        anchors.rightMargin: Theme.spaceMd
        spacing: Theme.spaceMd

        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: Theme.iconCircle

            Text {
                anchors.centerIn: parent
                text: row.deviceGlyph(row.device ? row.device.icon : "")
                color: Theme.accent
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
                text: row.device
                    ? (row.device.name || row.device.deviceName || "Unknown")
                    : ""
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
                elide: Text.ElideRight
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
                onClicked: row.act()
            }
        }
    }
}
