import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/config"

/**
 * SettingSliderRow — a settings row with a title, the current value on the
 * right ("33 px"), and a thin accent-filled track beneath. Drag or click the
 * track to change the value; the value is written by name into `Settings`.
 */
Item {
    id: root

    property string rowKey: ""
    property string title: ""
    property real   min: 0
    property real   max: 1
    property real   step: 1
    property int    decimals: 0
    property string suffix: ""

    readonly property real value: Settings.get(root.rowKey)
    readonly property real fraction: (max > min)
        ? Math.max(0, Math.min(1, (value - min) / (max - min))) : 0

    function display(v) {
        return Number(v).toFixed(root.decimals) + root.suffix
    }

    implicitHeight: 66

    function commit(mx, trackWidth) {
        if (trackWidth <= 0)
            return
        var raw = root.min + (mx / trackWidth) * (root.max - root.min)
        var stepped = Math.round((raw - root.min) / root.step) * root.step + root.min
        stepped = Math.max(root.min, Math.min(root.max, stepped))
        Settings.set(root.rowKey, Math.round(stepped * 1000) / 1000)
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        spacing: 9

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            // Revert-to-default button. It keeps its slot (a fixed width) so the
            // value never shifts, and only reveals itself when the value has
            // been changed away from the factory default.
            Item {
                id: revertSlot
                Layout.preferredWidth: 20
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                readonly property bool modified: Settings.isModified(root.rowKey)

                opacity: modified ? 1 : 0
                enabled: modified
                Behavior on opacity { NumberAnimation { duration: Theme.motionSnap } }

                Text {
                    anchors.centerIn: parent
                    text: "\uF0E2" // nf-fa-undo
                    color: revertHover.hovered ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
                }

                HoverHandler {
                    id: revertHover
                    cursorShape: revertSlot.modified ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: revertSlot.modified
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.reset(root.rowKey)
                }
            }

            Text {
                text: root.display(root.value)
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 16

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: height / 2
                color: Theme.track
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(track.width * root.fraction)
                height: 4
                radius: height / 2
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut } }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(track.width * root.fraction) - width / 2
                width: 15
                height: 15
                radius: width / 2
                color: Theme.textPrimary
                Behavior on x { NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function move(mx) { root.commit(mx, width) }
                onPressed: function(mouse) { move(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) move(mouse.x) }
            }
        }
    }
}
