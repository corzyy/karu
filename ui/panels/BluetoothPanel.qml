import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

import "../../core/theme"
import "../widgets"

/**
 * BluetoothPanel — the Bluetooth dialog's content, hosted by DetailCard.
 *
 * A header (back chevron, title, adapter switch), a "Saved" list of bonded
 * devices and a "Nearby" section that scans while the dialog is up. All state
 * comes from `Quickshell.Bluetooth`; every action is a no-op with no adapter.
 */
Flickable {
    id: root

    signal closeRequested()

    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var allDevices: adapter ? adapter.devices.values : []
    readonly property var savedDevices: allDevices.filter(function(d) {
        return d.paired || d.bonded
    })
    readonly property var nearbyDevices: allDevices.filter(function(d) {
        return !d.paired && !d.bonded && (d.name || d.deviceName)
    })

    // Scan only while the dialog exists and the adapter is on (BlueZ rejects
    // `Discovering` otherwise).
    function syncScanning() {
        if (root.adapter)
            root.adapter.discovering = root.adapter.enabled
    }
    Component.onCompleted: syncScanning()
    Component.onDestruction: if (root.adapter) root.adapter.discovering = false

    Connections {
        target: root.adapter
        function onEnabledChanged() { root.syncScanning() }
    }

    ColumnLayout {
        id: content
        width: root.width
        spacing: 0

        // Header: back · title · adapter switch.
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
                text: "Bluetooth"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            Switch {
                checked: root.adapter ? root.adapter.enabled : false
                onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            }
        }

        Item { Layout.preferredHeight: Theme.spaceLg }

        // Saved devices.
        Text {
            text: "Saved"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sectionSize
            font.weight: Font.Medium
        }

        Item { Layout.preferredHeight: Theme.spaceSm }

        Text {
            Layout.fillWidth: true
            visible: root.savedDevices.length === 0
            text: "No saved devices yet"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }

        Repeater {
            model: root.savedDevices
            delegate: BluetoothDeviceRow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spaceSm
                device: modelData
            }
        }

        Item { Layout.preferredHeight: Theme.spaceLg }

        // Nearby.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Text {
                text: "Nearby"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sectionSize
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 7
                height: 7
                radius: width / 2
                color: Theme.accent
                visible: root.adapter && root.adapter.discovering

                SequentialAnimation on opacity {
                    running: root.adapter && root.adapter.discovering && !Theme.gameMode
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: "Scanning"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                visible: root.adapter && root.adapter.discovering
            }
        }

        Item { Layout.preferredHeight: Theme.spaceSm }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: root.nearbyDevices.length === 0
            text: "Looking for devices… put the device in pairing mode"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignTop
        }

        Repeater {
            model: root.nearbyDevices
            delegate: BluetoothDeviceRow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spaceSm
                device: modelData
            }
        }
    }
}
