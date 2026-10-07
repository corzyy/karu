import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/config"

/**
 * SettingAccentPicker — chooses an accent colour on top of the active theme, or
 * follows the theme ("Follow theme"). Writes `Settings.accentOverride`, which
 * `Theme.accent` honours.
 */
Item {
    id: root

    readonly property var presets: [
        "#A8E6D8", "#7AA2F7", "#CBA6F7", "#EB6F92", "#E8B4D0",
        "#88C0D0", "#A3BE8C", "#EBCB8B", "#FF897D"
    ]
    readonly property string current: String(Settings.get("accentOverride")).toLowerCase()

    implicitHeight: inner.implicitHeight + Theme.cardPadding * 2

    function choose(color) { Settings.set("accentOverride", color) }

    ColumnLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            // "Follow theme" pill.
            Rectangle {
                implicitWidth: 108
                implicitHeight: 30
                radius: height / 2
                color: root.current === "" ? Theme.accentMuted : Theme.surfaceElevated
                border.width: 1
                border.color: root.current === "" ? Theme.accent : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                Text {
                    anchors.centerIn: parent
                    text: "Follow theme"
                    color: root.current === "" ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.choose("") }
            }

            Repeater {
                model: root.presets

                delegate: Rectangle {
                    id: swatch
                    required property string modelData
                    readonly property bool selected: root.current === modelData.toLowerCase()

                    Layout.alignment: Qt.AlignVCenter
                    width: 24
                    height: 24
                    radius: width / 2
                    color: modelData
                    border.width: selected ? 2 : 1
                    border.color: selected ? Theme.textPrimary : Theme.border

                    Text {
                        anchors.centerIn: parent
                        visible: swatch.selected
                        text: "\uF00C" // nf-fa-check
                        color: Theme.backgroundSolid
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.choose(modelData) }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
