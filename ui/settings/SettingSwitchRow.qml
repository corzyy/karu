import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/config"
import "../widgets"

/**
 * SettingSwitchRow — a settings row with a title/subtitle and an on/off switch.
 * The value is read and written by name in the `Settings` singleton.
 */
Item {
    id: root

    property string rowKey: ""
    property string title: ""
    property string subtitle: ""

    implicitHeight: subtitle.length > 0 ? 62 : 48

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        spacing: Theme.spaceMd

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                elide: Text.ElideRight
            }
        }

        Switch {
            Layout.alignment: Qt.AlignVCenter
            checked: Settings.get(root.rowKey)
            onToggled: Settings.set(root.rowKey, !Settings.get(root.rowKey))
        }
    }
}
