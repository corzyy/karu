import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/config"

/**
 * SettingTextRow — a settings row with a free-text field on the right. The
 * value is committed on Enter or when the field loses focus.
 */
Item {
    id: root

    property string rowKey: ""
    property string title: ""
    property string subtitle: ""

    implicitHeight: subtitle.length > 0 ? 62 : 48

    function commit() {
        Settings.set(root.rowKey, field.text)
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

        Rectangle {
            Layout.preferredWidth: 210
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 30
            radius: Theme.radiusInner
            color: Theme.surfaceElevated
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: field.forceActiveFocus()
            }

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceMd
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary
                selectionColor: Theme.accent
                selectedTextColor: Theme.backgroundSolid
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                text: Settings.get(root.rowKey)
                clip: true
                onEditingFinished: root.commit()
                Keys.onReturnPressed: { root.commit(); focus = false }
                Keys.onEnterPressed: { root.commit(); focus = false }
                Keys.onEscapePressed: { text = Settings.get(root.rowKey); focus = false }
            }
        }
    }
}
