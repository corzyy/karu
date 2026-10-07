import QtQuick
import QtQuick.Shapes

import "../../core/theme"

/**
 * NotchBar — the Notch Mode silhouette, drawn as one Shape path.
 *
 * This mirrors the technique Solstice uses for its docked bar (see
 * TopBar.qml's `barPath()`): the bar and whatever is fused to it are drawn as
 * a single filled path rather than as a rectangle plus separate corner
 * patches. A patch-on-top fillet leaves a hairline where the patch and the
 * body meet, so the cove never quite reads as one mass; one path — and a
 * shadow cast from that same path — fixes that.
 *
 * Geometry, in the shell's own coordinates:
 *   barLeft .. outerRight   the bar, and the outer right edge of the fused
 *                           media companion (equal to barRight when nothing
 *                           is fused)
 *   barTop / barHeight      top (the screen edge) and height
 * The outer top corners carry concave "coves", so the bar flares out into the
 * top screen edge; the bottom corners are ordinary convex rounds, matching the
 * rest of the shell's cards. `cove` sizes the top pair, `bottomCove` the bottom
 * pair. The item anchors itself so `path` is in local coordinates and can be
 * reused verbatim by a PanelShadow.
 */
Item {
    id: root

    /// Left edge of the bar.
    property real barLeft: 0
    /// Outer right edge of the whole silhouette (media edge when fused).
    property real outerRight: 0
    /// Top edge (the screen edge the bar sits flush against).
    property real barTop: 0
    /// Bar height.
    property real barHeight: 0
    /// Concave cove radius at the outer top corners.
    property real cove: Theme.notchCornerRadius
    /// Convex corner radius at the outer bottom corners.
    property real bottomCove: Theme.notchBottomRadius
    /// Fill colour.
    property color fillColor: Theme.backgroundSolid
    /// Paint the fill as the panel glass gradient (top opaque → bottom
    /// transparent) instead of the flat `fillColor`, so the backdrop blur
    /// behind an open panel shows through. Driven by shell.qml when Panel blur
    /// is on and a panel is expanded; the bar at rest stays opaque.
    property bool glass: false
    /// Height of the fully-opaque band at the top before the fade begins,
    /// matching the collapsed bar so the slab reads as a continuation of it.
    property real opaqueHeight: Theme.collapsedHeight

    readonly property real span: Math.max(1, outerRight - barLeft)
    // Room for the top cove, the only corner that reaches outward.
    readonly property real pad: Math.max(0, cove)

    x: barLeft - pad
    y: barTop
    width: span + pad * 2
    height: Math.max(1, barHeight)

    /// The unified silhouette as an SVG path, in local coordinates (so a
    /// PanelShadow of the same size can reuse it directly).
    readonly property string path: barPath()

    /// The top-to-bottom glass gradient used when `glass` is set. Shape
    /// gradients are in the shape's own coordinate space, hence the local
    /// 0..height span. The first `opaqueHeight` is held fully opaque, then it
    /// fades to transparent.
    readonly property real opaqueStop:
        height > 0 ? Math.max(0, Math.min(1, root.opaqueHeight / height)) : 0
    readonly property LinearGradient glassGradient: LinearGradient {
        x1: 0
        y1: 0
        x2: 0
        y2: root.height
        GradientStop { position: 0.0; color: Theme.panelGlassTop }
        GradientStop { position: root.opaqueStop; color: Theme.panelGlassTop }
        GradientStop { position: 1.0; color: Theme.panelGlassBottom }
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fillColor
            fillGradient: root.glass ? root.glassGradient : null
            strokeWidth: 0
            strokeColor: "transparent"
            PathSvg { path: root.path }
        }
    }

    function barPath(): string {
        const H = root.height
        const half = H / 2
        const ct = Math.max(0, Math.min(root.cove, half, root.span / 2))
        const cb = Math.max(0, Math.min(root.bottomCove, half, root.span / 2))
        const x0 = root.pad
        const x1 = root.pad + root.span
        // Cubic control offset for a near-circular tangent cove — the same
        // 0.5523 constant Solstice uses in its panel-to-bar Fillet.
        const ck = 0.5523
        const n = v => "" + (Math.round(v * 100) / 100)

        if (ct <= 0.01 && cb <= 0.01)
            return "M " + n(x0) + " 0 H " + n(x1) + " V " + n(H) + " H " + n(x0) + " Z"

        return "M " + n(x0 - ct) + " 0"
             // Concave cove from the top edge into the bar's left edge.
             + " C " + n(x0 - ct + ck * ct) + " 0"
                     + " " + n(x0) + " " + n(ct - ck * ct)
                     + " " + n(x0) + " " + n(ct)
             + " V " + n(H - cb)
             // Convex round from the left edge in to the bottom edge.
             + " C " + n(x0) + " " + n(H - cb + ck * cb)
                     + " " + n(x0 + cb - ck * cb) + " " + n(H)
                     + " " + n(x0 + cb) + " " + n(H)
             + " H " + n(x1 - cb)
             // Convex round from the bottom edge up into the right edge.
             + " C " + n(x1 - cb + ck * cb) + " " + n(H)
                     + " " + n(x1) + " " + n(H - cb + ck * cb)
                     + " " + n(x1) + " " + n(H - cb)
             + " V " + n(ct)
             // Concave cove from the right edge back out to the top edge.
             + " C " + n(x1) + " " + n(ct - ck * ct)
                     + " " + n(x1 + ct - ck * ct) + " 0"
                     + " " + n(x1 + ct) + " 0"
             + " Z"
    }
}
