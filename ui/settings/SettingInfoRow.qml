import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../core/theme"

/**
 * SettingInfoRow — a read-only label and value. `$config` / `$settings` tokens
 * are resolved to the real paths.
 */
Item {
    id: root

    property string title: ""
    property string value: ""

    readonly property string resolved: {
        if (value === "$config")
            return Quickshell.shellDir
        if (value === "$settings")
            return Quickshell.shellDir + "/settings.json"
        return value
    }

    implicitHeight: 46

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        spacing: Theme.spaceMd

        Text {
            text: root.title
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
            font.weight: Font.Medium
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.maximumWidth: parent.width * 0.62
            text: root.resolved
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
        }
    }
}
