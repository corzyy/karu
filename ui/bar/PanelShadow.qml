import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

import "../../core/theme"

/**
 * PanelShadow — the drop shadow behind an island panel.
 *
 * Hyprland renders a shadow for windows but not for layer-shell surfaces (the
 * island is a full-screen, mostly-transparent layer), so the shell draws the
 * same shadow itself, tuned to the compositor's `decoration:shadow` through the
 * `Theme.shadow*` values.
 *
 * Place one as a sibling *before* the panel it belongs to, binding its geometry
 * and corner radius to that panel. The panel keeps `clip: true` and stays crisp;
 * only this rectangle is blurred, so nothing rasterises the panel's contents.
 *
 * When `path` is set the shadow is cast from that exact SVG silhouette instead
 * of a rounded rectangle — used for the Notch Mode bar, whose concave coves and
 * fused media companion cannot be expressed as a plain rectangle. Shadowing the
 * same path the bar is filled with keeps the two silhouettes identical.
 */
Item {
    id: root

    /// Corner radius of the panel being shadowed. The per-corner properties
    /// below default to it; override them when the panel is not uniformly
    /// rounded (e.g. Notch Mode only rounds the bottom corners).
    property real radius: Theme.radiusPanel
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    /// Optional SVG silhouette. When non-empty it replaces the rectangle.
    property string path: ""

    Rectangle {
        anchors.fill: parent
        visible: root.path === ""
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Theme.shadowColor

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: Theme.shadowBlur
            blurMax: Theme.shadowBlurMax
            autoPaddingEnabled: true
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.path !== ""
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: Theme.shadowBlur
            blurMax: Theme.shadowBlurMax
            autoPaddingEnabled: true
        }
        ShapePath {
            fillColor: Theme.shadowColor
            strokeWidth: 0
            strokeColor: "transparent"
            PathSvg { path: root.path }
        }
    }
}
