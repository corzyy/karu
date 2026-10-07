import QtQuick

import "../../core/theme"

/**
 * TileGlass — the shared frosted gradient for a tile or card.
 *
 * The tile-sized counterpart of `PanelGlass`: the same panel glass gradient
 * (opaque at the top, fading to transparent at the bottom) so a tile reads as
 * part of the same sheet as the panel behind it. Assign it to a Rectangle's
 * `gradient` and leave that rectangle's `color` transparent; the rectangle
 * still draws its own border on top. With Panel blur off — or under Game Mode —
 * the stops collapse to the flat `surface` colour, so the tile looks exactly as
 * it did before.
 */
Gradient {
    id: root

    /// True while the pointer is over the tile; lifts the top of the glass
    /// (mirrors the host's own hover fill).
    property bool hovered: false

    GradientStop {
        position: 0.0
        color: root.hovered ? Theme.tileGlassTopHover : Theme.tileGlassTop
    }
    GradientStop { position: 1.0; color: Theme.tileGlassBottom }
}
