import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/services"
import "../widgets"

/**
 * BrightnessPanel — the Display dialog's content, hosted by DetailCard.
 *
 * One slider per DDC/CI monitor so each screen's brightness can be set
 * independently. The Control Center's Display slider moves them all together;
 * this panel is where they are tuned apart. The monitor list comes from the
 * `Brightness` singleton (`ddcutil`); with none reachable it shows a short hint
 * instead.
 */
Flickable {
    id: root

    signal closeRequested()

    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content
        width: root.width
        spacing: 0

        // Header: back · title.
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
                text: "Brightness"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }
        }

        Item { Layout.preferredHeight: Theme.spaceLg }

        // One row per monitor, each writing only its own bus.
        Repeater {
            model: Brightness.displays
            delegate: SliderRow {
                Layout.fillWidth: true
                Layout.topMargin: index > 0 ? Theme.spaceSm : 0
                icon: "\uF185" // nf-fa-sun_o
                title: modelData.label
                showValue: true
                value: modelData.value
                onMoved: function(v) { modelData.setValue(v) }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: Brightness.displays.length === 0
            text: Brightness.status.length > 0
                ? Brightness.status
                : "No DDC/CI displays found"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignTop
        }
    }
}
