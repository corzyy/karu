import QtQuick
import QtQuick.Layouts

import "../../core/theme"

/**
 * ToggleButton — a pill-shaped tile: circular icon + title + muted subtitle.
 *
 * Every tile shares the same surface fill and border. When `active` only the
 * icon circle picks up the accent color, signalling the toggle's state.
 *
 * Clicks:
 *   - the icon circle always emits `toggled()`;
 *   - the rest of the tile emits `openRequested(tile)` when `openable` is set
 *     (carrying the tile's geometry *and look*, so a caller can grow a panel
 *     straight out of it), otherwise it also emits `toggled()`.
 *
 * The owner decides what `toggled()` means, which lets a tile bind `active` to
 * a live service without the component fighting the binding.
 */
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    /// When true, clicking the tile body opens a panel instead of toggling.
    property bool openable: false
    /// True while this tile's detail dialog is open. The card has taken the
    /// tile's place, so the tile must not show through behind it — but its space
    /// is kept (opacity, not visible) so the grid never reflows.
    property bool suppressed: false

    signal toggled()
    /// Body click while `openable`. `tile` carries the tile's scene rectangle
    /// (`x`/`y`/`width`/`height`), corner `radius` and `fill` / `border`
    /// colours, so a detail card starts as a pixel-aligned copy of the tile.
    signal openRequested(var tile)

    /// Everything a detail card needs to morph out of this tile. The fill is
    /// flattened over the island background so a tinted (active) tile hands
    /// over an opaque colour the card can start from. The radius is clamped to
    /// half the height because that is the corner the pill actually renders.
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

    implicitHeight: Theme.toggleHeight
    radius: Theme.radiusPill
    opacity: suppressed ? 0 : 1
    enabled: !suppressed

    color: "transparent"
    gradient: TileGlass {}
    border.width: 1
    border.color: Theme.border

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

    // Body click. Declared before the content so the icon's own MouseArea (below
    // in the tree) wins its area, while empty space falls through to here.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.openable)
                root.openRequested(root.tileGeometry())
            else
                root.toggled()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.padTight
        anchors.rightMargin: Theme.padRow
        spacing: Theme.spaceMd

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: root.active ? Theme.accent : Theme.iconCircle
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.active ? Theme.backgroundSolid : Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: Theme.toggleIconSize
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spaceXs / 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
                // Shrink long titles (e.g. "Do not Disturb") to fit the tile
                // rather than eliding them.
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 9
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                elide: Text.ElideRight
            }
        }
    }
}
