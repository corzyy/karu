import QtQuick

import "../../core/theme"

/**
 * PanelGlass — the frosted-glass fill for an island surface.
 *
 * A rounded rectangle painted with the panel's dark glass gradient: a fully
 * opaque band at the top — as tall as the collapsed island, so the panel reads
 * as a continuation of it — then fading to fully transparent at the bottom, so
 * the backdrop blur the panel asks the compositor for (see shell.qml) shows
 * through below. It draws nothing unless `active` is true, so a surface can
 * carry it unconditionally and keep its flat fill the rest of the time.
 *
 * Place it as the first child of the surface, behind the content, and give it
 * the surface's corner radii. The host is expected to drop its own fill to
 * transparent while `active` is true, or the blur cannot show through.
 */
Rectangle {
    id: root

    /// Whether the glass is drawn. The host normally binds this to whether a
    /// panel is open under `Theme.panelBlur`.
    property bool active: Theme.panelBlur

    /// True while the pointer is over the host surface, to lift the top of the
    /// glass a touch (mirrors the host's own hover fill).
    property bool hovered: false

    /// Height of the fully-opaque band at the top before the fade begins.
    /// Defaults to the collapsed island height, so the opaque area is exactly
    /// as tall as the pill / notch bar it grows out of.
    property real opaqueHeight: Theme.collapsedHeight

    /// Where that band ends, as a 0..1 fraction of the surface height.
    readonly property real opaqueStop:
        height > 0 ? Math.max(0, Math.min(1, root.opaqueHeight / height)) : 0

    visible: root.active
    antialiasing: true

    gradient: Gradient {
        GradientStop {
            position: 0.0
            color: root.hovered ? Theme.panelGlassTopHover : Theme.panelGlassTop
        }
        GradientStop {
            position: root.opaqueStop
            color: root.hovered ? Theme.panelGlassTopHover : Theme.panelGlassTop
        }
        GradientStop { position: 1.0; color: Theme.panelGlassBottom }
    }
}
