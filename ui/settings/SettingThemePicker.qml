import QtQuick
import QtQuick.Layouts

import "../../core/theme"

/**
 * SettingThemePicker — the theme carousel inside the Appearance page. Each chip
 * previews a palette; clicking it applies that theme (through `Themes`).
 */
Item {
    id: root

    readonly property var themes: Themes.themes
    implicitHeight: inner.implicitHeight + Theme.cardPadding * 2

    ColumnLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        spacing: 10

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Repeater {
                model: root.themes

                delegate: Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool applied: modelData.id === Themes.appliedId

                    width: 104
                    height: 62
                    radius: Theme.radiusInner
                    color: modelData.bg
                    border.width: applied ? 2 : 1
                    border.color: applied ? Theme.accent : Theme.border
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 3

                            Repeater {
                                model: chip.modelData.colors
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 9
                                    height: 9
                                    radius: width / 2
                                    color: modelData
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: chip.modelData.name
                            color: chip.applied ? Theme.accent : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.subtitleSize
                        }
                    }

                    TapHandler { onTapped: Themes.apply(chip.modelData.id) }
                }
            }
        }
    }
}
