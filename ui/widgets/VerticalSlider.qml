import QtQuick

import "../../core/theme"

/**
 * VerticalSlider — the upright counterpart to `SliderRow`.
 *
 * Same contract as `SliderRow` (renders `value`, emits `moved` as the user drags
 * the track), but the track runs bottom-to-top: the fill rises from the bottom
 * and the icon sits at the foot of the card. `ControlItem` switches to it when a
 * Sound / Display control is taller than it is wide, so a slider resized to a
 * narrow, tall slot becomes a vertical iOS-style bar.
 *
 * A trailing chevron (when `openable`) opens the row's detail card, exactly like
 * the horizontal slider's.
 */
Rectangle {
    id: root

    property string icon: "\uF028"
    property real value: 0.65
    property color fillColor: Theme.accent
    property color iconColor: Theme.accent

    /// Show the value as a percentage at the top of the card.
    property bool showValue: false

    /// When true, a chevron at the top opens a detail panel.
    property bool openable: false

    /// True while this control's detail dialog is open. The row fades out but
    /// keeps its space, so the column never reflows.
    property bool suppressed: false

    /// Emitted with the new 0..1 value while the user drags the track.
    signal moved(real value)
    signal detailRequested(var tile)

    /// Everything a detail card needs to morph out of this row.
    function tileGeometry() {
        var r = root.mapToItem(null, 0, 0, root.width, root.height)
        return {
            x: r.x,
            y: r.y,
            width: r.width,
            height: r.height,
            radius: root.radius,
            fill: Theme.flatten(Theme.tileGlassTop, Theme.background),
            border: root.border.color
        }
    }

    function clamp(v) {
        return Math.max(0, Math.min(1, v))
    }

    implicitWidth: Theme.toggleHeight
    implicitHeight: Theme.toggleHeight * 2
    radius: Theme.radiusCard
    color: "transparent"
    gradient: TileGlass {}
    border.width: 1
    border.color: Theme.border
    opacity: suppressed ? 0 : 1

    Text {
        id: valueLabel
        anchors.top: parent.top
        anchors.topMargin: Theme.padRow
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showValue
        text: Math.round(root.value * 100) + "%"
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.subtitleSize
    }

    Item {
        id: chevron
        visible: root.openable
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.padTight
        width: 14
        height: 14

        Text {
            anchors.centerIn: parent
            text: "\uF054" // nf-fa-chevron_right
            color: chevronHover.hovered ? Theme.textPrimary : Theme.textDim
            font.family: Theme.iconFont
            font.pixelSize: 10
        }

        HoverHandler { id: chevronHover; cursorShape: Qt.PointingHandCursor }

        MouseArea {
            anchors.fill: parent
            enabled: root.openable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailRequested(root.tileGeometry())
        }
    }

    Text {
        id: iconLabel
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padRow
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.icon
        color: root.iconColor
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
    }

    // The track runs between the top slot (value and/or chevron) and the icon.
    Item {
        id: trackWrap
        anchors.top: valueLabel.visible ? valueLabel.bottom
            : (chevron.visible ? chevron.bottom : parent.top)
        anchors.bottom: iconLabel.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spaceSm
        anchors.bottomMargin: Theme.spaceSm
        width: Math.max(10, Math.min(18, root.width - Theme.padRow * 2))

        Rectangle {
            id: track
            anchors.fill: parent
            radius: width / 2
            color: Theme.track
        }

        Rectangle {
            width: trackWrap.width
            height: Math.round(trackWrap.height * root.clamp(root.value))
            anchors.bottom: parent.bottom
            radius: width / 2
            color: root.fillColor
            Behavior on height { NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut } }
        }

        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function commit(my) {
                root.moved(root.clamp(1 - my / trackWrap.height))
            }

            onClicked: function (mouse) { commit(mouse.y) }
            onPositionChanged: function (mouse) { if (pressed) commit(mouse.y) }
        }
    }
}
