import QtQuick
import QtQuick.Layouts

import "../../core/theme"

/**
 * SliderRow — a card with a heading, an icon and a thin rounded track whose
 * filled portion uses the accent color.
 *
 * The slider is display-only: it renders `value` (0..1) and emits `moved` as the
 * user clicks/drags the track. The owner is responsible for applying the value
 * (e.g. writing it to the default PipeWire sink) and feeding it back into
 * `value`, which keeps `value` a live binding instead of a local copy.
 *
 * The trailing chevron (shown when `showValue` is false) doubles as a detail
 * opener: with `openable` set, clicking it emits `detailRequested(tile)` carrying
 * the row's geometry and look, so a caller can grow a panel straight out of it.
 */
Rectangle {
    id: root

    property string icon: "\uF028"
    property string title: "Sound"
    property real value: 0.65
    property color fillColor: Theme.accent
    property color iconColor: Theme.accent

    /// Show the value as a percentage on the right instead of a chevron.
    property bool showValue: false

    /// When true, clicking the trailing chevron opens a detail panel.
    property bool openable: false

    /// True while this row's detail dialog is open. The card has taken the row's
    /// place, so the row must not show through behind it — but its space is kept
    /// (opacity, not visible) so the column never reflows.
    property bool suppressed: false

    /// Tighter vertical padding, so the row fits a single Control Center grid
    /// cell (`Theme.toggleHeight`) instead of spilling over the tile above it.
    property bool compact: false

    /// Emitted with the new 0..1 value while the user clicks/drags the track.
    signal moved(real value)

    /// Emitted from a chevron click while `openable`. `tile` carries the row's
    /// scene rectangle (`x`/`y`/`width`/`height`), corner `radius` and `fill` /
    /// `border` colours, so a detail card starts as a pixel-aligned copy of the
    /// row.
    signal detailRequested(var tile)

    /// Everything a detail card needs to morph out of this row. The fill is
    /// flattened over the island background so a tinted row hands over an opaque
    /// colour the card can start from.
    function tileGeometry() {
        var r = root.mapToItem(null, 0, 0, root.width, root.height)
        return {
            x: r.x,
            y: r.y,
            width: r.width,
            height: r.height,
            radius: Math.min(root.radius, root.height / 2),
            fill: Theme.flatten(Theme.tileGlassTop, Theme.background),
            border: root.border.color
        }
    }

    implicitHeight: content.implicitHeight + (compact ? Theme.spaceSm : Theme.cardPadding) * 2
    radius: Theme.radiusCard
    opacity: suppressed ? 0 : 1
    enabled: !suppressed
    color: "transparent"
    gradient: TileGlass {}
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        spacing: compact ? Theme.spaceXs : Theme.spaceSm

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sectionSize
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.showValue
                text: Math.round(root.value * 100) + "%"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }

            // The chevron on the right is the tile-detail opener (the Display
            // slider uses it to reveal the per-monitor panel). When the row
            // shows its value instead there is no chevron, so no opener either.
            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                visible: !root.showValue

                Text {
                    anchors.centerIn: parent
                    text: "\uF054" // nf-fa-chevron_right
                    color: (chevronHover.hovered && root.openable) ? Theme.textPrimary : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                }

                HoverHandler {
                    id: chevronHover
                    cursorShape: root.openable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.openable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.detailRequested(root.tileGeometry())
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Text {
                text: root.icon
                color: root.iconColor
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                id: track
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 8
                radius: height / 2
                color: Theme.track

                Rectangle {
                    width: Math.round(track.width * Math.max(0, Math.min(1, root.value)))
                    height: parent.height
                    radius: height / 2
                    color: root.fillColor
                    Behavior on width { NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function commit(mx) {
                        root.moved(Math.max(0, Math.min(1, mx / width)))
                    }

                    onClicked: function(mouse) { commit(mouse.x) }
                    onPositionChanged: function(mouse) { if (pressed) commit(mouse.x) }
                }
            }
        }
    }
}
