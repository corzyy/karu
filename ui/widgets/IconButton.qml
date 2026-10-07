import QtQuick

import "../../core/theme"

/**
 * IconButton — a compact, square control tile: a single glyph on a rounded
 * surface, optionally tinted with the accent when `active`.
 *
 * It is the Control Center's small control kind (the Lock and Do Not Disturb
 * buttons), the tile equivalent of `ToggleButton` for a one-cell slot. Like a
 * tile it can hand its geometry to a detail card via `tileGeometry()`.
 */
Rectangle {
    id: root

    property string icon: ""
    property bool active: false

    signal triggered()

    /// Everything a detail card needs to morph out of this tile (same shape as
    /// ToggleButton.tileGeometry()).
    function tileGeometry() {
        var r = root.mapToItem(null, 0, 0, root.width, root.height)
        return {
            x: r.x,
            y: r.y,
            width: r.width,
            height: r.height,
            radius: root.radius,
            fill: Theme.flatten(root.active ? Theme.accentMuted : Theme.tileGlassTop, Theme.background),
            border: root.border.color
        }
    }

    implicitWidth: Theme.toggleHeight
    implicitHeight: Theme.toggleHeight
    radius: Theme.radiusInner
    color: root.active ? Theme.accentMuted : "transparent"
    gradient: root.active ? null : glass
    border.width: 1
    border.color: root.active ? Theme.accent : Theme.border

    // The frosted fill while the button is idle; the active (accent-tinted)
    // state keeps its flat fill so the tint stays solid.
    TileGlass { id: glass }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.active ? Theme.accent : Theme.textSecondary
        font.family: Theme.iconFont
        font.pixelSize: Theme.toggleIconSize
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
