import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../widgets"

/**
 * SettingGameModeRow — the live Game Mode switch in the System page. Unlike the
 * other switches this reads/writes the `GameMode` singleton directly.
 */
Item {
    id: root

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
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }
        }

        Switch {
            Layout.alignment: Qt.AlignVCenter
            checked: GameMode.enabled
            onToggled: GameMode.toggle()
        }
    }
}
