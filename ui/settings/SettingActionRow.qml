import QtQuick
import QtQuick.Layouts

import "../../core/theme"

/**
 * SettingActionRow — a tappable settings row with a trailing chevron. Emits
 * `triggered` with the row's action id; the page runs it.
 */
Item {
    id: root

    property string action: ""
    property string title: ""
    property string subtitle: ""

    signal triggered(string action)

    implicitHeight: subtitle.length > 0 ? 58 : 46

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered(root.action)
    }

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
                color: hover.hovered ? Theme.accent : Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
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

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "\uF054" // nf-fa-chevron_right
            color: Theme.textDim
            font.family: Theme.iconFont
            font.pixelSize: 11
        }
    }
}
