import QtQuick
import Quickshell.Hyprland

import "../../core/theme"

/**
 * WorkspaceIndicator — live Hyprland workspace switcher.
 *
 * Always renders the workspaces listed in Theme.persistentWorkspaces (1–5 by
 * default), so the row keeps a stable width even when a workspace is empty or
 * has not been created yet. Any other numeric workspace Hyprland currently
 * reports is merged in so a real workspace is never hidden.
 *
 * For each entry:
 *   selected  – the focused workspace: a tall accent lens. Selection follows
 *               focus across monitors, so activating a workspace on a second
 *               output still highlights its capsule here.
 *   occupied  – holds at least one window: brighter accent capsule
 *   empty     – no such workspace, or no windows: faint accent capsule
 *   urgent    – a window is asking for attention: breathing danger capsule
 *
 * Switching workspace animates as motion, not a size flip: one shared lens
 * glides from the old slot to the new one, squash-and-stretching as it travels
 * (elongating as it sets off, relaxing and settling once it arrives). The
 * stretch has a dynamic origin: the edge facing the destination stays fixed and
 * the lens grows out behind it, so a lens moving right pins its right edge and
 * trails to the left, and one moving left pins its left edge and trails to the
 * right. Both the glide time and the amount of stretch scale with the distance
 * travelled, so a hop to the next workspace is quick and light while a jump
 * across the row is a longer, stretchier glide.
 *
 * Interaction:
 *   click  – activating the workspace (creating it if it did not exist)
 *   hover  – the dot grows and brightens so the target reads before clicking
 *   scroll – steps to the previous / next visible workspace, wrapping around
 *
 * When Hyprland is not running the row simply shows the persistent set as faint
 * dots.
 */
Item {
    id: root

    /**
     * Optional total width to match another element — shell.qml binds it to the
     * status icons so the collapsed pill's left and right clusters are the same
     * width and the clock stays centred. When <= 0 the natural Theme width is
     * used. The dots are spread evenly across the target rather than padded, so
     * the row really is that wide.
     */
    property real matchWidth: 0

    /**
     * Focus the given workspace id, switching monitors if it lives on another
     * one. Hyprland 0.55+ in Lua mode rejects the legacy `workspace N`
     * dispatcher, so the Lua equivalent `hl.dsp.focus({ workspace = N })` is
     * used there instead.
     */
    function focusWorkspace(id) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else
            Hyprland.dispatch("workspace " + id)
    }

    /**
     * Step to the previous (-1) or next (+1) visible workspace, wrapping at the
     * ends. Wired to the scroll wheel so the row can be cycled in place.
     */
    function cycleWorkspace(delta) {
        var list = root.workspaces
        if (list.length === 0)
            return

        var current = root.selectedIndex < 0 ? 0 : root.selectedIndex
        var next = (current + delta + list.length) % list.length
        root.focusWorkspace(list[next].id)
    }

    // Model: one `{ id, ws }` entry per visible workspace, sorted by id. `ws`
    // is the live HyprlandWorkspace object, or null when it doesn't exist.
    // Reading `.values` keeps the binding live when workspaces come and go.
    readonly property var workspaces: {
        var all = Hyprland.workspaces.values
        var byId = ({})
        for (var i = 0; i < all.length; i++)
            byId[all[i].id] = all[i]

        var ids = []
        var fixed = Theme.persistentWorkspaces || []
        for (var f = 0; f < fixed.length; f++)
            ids.push(fixed[f])

        // Merge any other numeric workspace so it is never hidden. Named and
        // special workspaces (negative ids) are skipped — they have no place
        // in a row of anonymous numeric dots.
        for (var j = 0; j < all.length; j++) {
            if (all[j].id > 0 && ids.indexOf(all[j].id) === -1)
                ids.push(all[j].id)
        }

        ids.sort(function (a, b) { return a - b })

        var out = []
        for (var k = 0; k < ids.length; k++) {
            out.push({ id: ids[k], ws: byId[ids[k]] !== undefined ? byId[ids[k]] : null })
        }
        return out
    }

    // Per-workspace draw box. Spreads evenly over `matchWidth` when set, but
    // never squeezes a dot below a full circle; otherwise the Theme width.
    readonly property real itemWidth: {
        var n = root.workspaces.length
        if (root.matchWidth <= 0 || n === 0)
            return Theme.workspaceItemWidth
        var gaps = (n - 1) * Theme.workspaceSpacing
        return Math.max((root.matchWidth - gaps) / n, Theme.dotCircle + 2)
    }

    readonly property int spacing: Theme.workspaceSpacing
    readonly property real step: itemWidth + spacing

    // Index of the workspace that owns the travelling lens, or -1 when the
    // focused workspace is not in the visible set (e.g. a special workspace).
    // `focused` (unlike `active`) is only true for the focused monitor, so the
    // lens follows focus across monitors.
    readonly property int selectedIndex: {
        var list = root.workspaces
        for (var i = 0; i < list.length; i++) {
            var w = list[i].ws
            if (w && w.focused)
                return i
        }
        return -1
    }

    // Does the focused workspace want attention? Drives the lens colour.
    readonly property bool selectedUrgent: {
        if (selectedIndex < 0 || selectedIndex >= workspaces.length)
            return false
        var w = workspaces[selectedIndex].ws
        return w !== null && w.urgent
    }

    implicitWidth: dots.implicitWidth
    implicitHeight: dots.implicitHeight

    // Start the travel animation only once the row has settled, so the very
    // first placement of the lens does not slide in from nowhere.
    property bool markReady: false
    Component.onCompleted: {
        marker.x = marker.targetX
        markReady = true
    }

    // ── Idle capsules ────────────────────────────────────────────────────────
    Row {
        id: dots
        spacing: root.spacing

        Repeater {
            model: root.workspaces

            delegate: Item {
                id: item
                required property var modelData
                readonly property var ws: modelData.ws
                readonly property bool exists: ws !== null
                readonly property bool isSelected: exists && ws.focused
                readonly property bool isUrgent: exists && ws.urgent
                readonly property bool isOccupied: exists && ws.toplevels.values.length > 0

                width: root.itemWidth
                height: Theme.dotHeightActive + Theme.spaceXs

                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    // A capsule, not a circle: a tall soft-ended bar, widening
                    // and growing on hover so the target reads before clicking.
                    // The selected workspace hides its capsule — the lens above
                    // is its representation.
                    width: (hover.hovered && !item.isSelected) ? Theme.dotCircleHover : Theme.dotCircle
                    height: (hover.hovered && !item.isSelected) ? Theme.dotHeightHover : Theme.dotHeightInactive
                    radius: width / 2
                    // Every resting capsule is the accent at a low opacity, so
                    // the row reads as one set of (hollow) slots; an occupied
                    // workspace sits brighter than an empty one.
                    color: item.isUrgent ? Theme.danger : Theme.accent
                    opacity: item.isSelected ? 0
                           : item.isUrgent ? 1
                           : item.isOccupied ? 0.8
                           : hover.hovered ? 1 : 0.4

                    Behavior on width { NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeSpring; easing.overshoot: Theme.springOvershoot } }
                    Behavior on height { NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeSpring; easing.overshoot: Theme.springOvershoot } }
                    Behavior on opacity { NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeOut } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    SequentialAnimation on scale {
                        running: item.isUrgent && !item.isSelected && !Theme.gameMode
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.25; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                    Connections {
                        target: item
                        function onIsUrgentChanged() {
                            if (!item.isUrgent)
                                dot.scale = 1
                        }
                        function onIsSelectedChanged() {
                            if (item.isSelected)
                                dot.scale = 1
                        }
                    }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.focusWorkspace(item.modelData.id)
                }
            }
        }
    }

    // ── Travelling lens ──────────────────────────────────────────────────────
    // Declared after `dots`, so it glides *over* them like a cursor. The move is
    // animated imperatively so both the glide time and the squash can be sized
    // to the distance actually travelled: a hop to the next workspace is quick
    // and light, a jump across the row stretches further and glides longer.
    Item {
        id: marker

        width: Theme.dotWidth
        height: Theme.dotHeightActive
        y: (root.height - height) / 2
        opacity: root.selectedIndex >= 0 ? 1 : 0
        visible: opacity > 0.01

        // Slot centre of the selected workspace (slot 0 while nothing is
        // selected, so the lens simply fades in there).
        readonly property real targetX: (root.selectedIndex >= 0 ? root.selectedIndex : 0)
            * root.step + root.itemWidth / 2 - width / 2

        // Squash-and-stretch amount: 0 at rest, up to 1 mid-travel. Sized per
        // move by `travelTo()`.
        property real stretch: 0

        // Direction of the current glide: +1 travels right, -1 travels left.
        // Drives the stretch origin (see `pill`): the edge facing the direction
        // of travel stays fixed and the lens trails out behind it.
        property int travelDir: 1

        // Glide the lens to its slot, scaling the duration and the squash to the
        // distance. Re-entrant: a new focus change retargets from wherever the
        // lens currently is, so rapid switches stay smooth.
        function travelTo() {
            // Game Mode runs without motion: drop the lens straight onto its
            // slot instead of gliding and squashing it across the row.
            if (Theme.gameMode) {
                move.stop()
                stretchAnim.stop()
                stretch = 0
                x = targetX
                return
            }

            var dir = targetX >= x ? 1 : -1
            var distance = Math.abs(targetX - x)
            if (distance < 0.5) {
                x = targetX
                return
            }

            // Pin the stretch to the destination edge (the one the lens is
            // heading toward) so the lens trails out behind it. A reversal
            // mid-glide swaps that pinned edge; rather than snapping the live
            // stretch away — which flickers the width — shift the container by
            // exactly the amount the new origin moves the shape, so the
            // rendered lens is pixel-identical on the swap frame and the
            // stretch simply carries on from where it was.
            if (dir !== travelDir) {
                var scale = 1 + stretch * 1.7
                x += dir < 0 ? width * (1 - scale) : width * (scale - 1)
                travelDir = dir
                distance = Math.abs(targetX - x)
            }

            // Theme tokens with inline defaults: a missing or blank value must
            // never turn the animation into a NaN no-op.
            var base = Theme.workspaceTravelBaseMs > 0 ? Theme.workspaceTravelBaseMs : 230
            var perPx = Theme.workspaceTravelPerPx > 0 ? Theme.workspaceTravelPerPx : 4.5
            var maxMs = Theme.workspaceTravelMaxMs > 0 ? Theme.workspaceTravelMaxMs : 640
            var refPx = Theme.workspaceStretchRef > 0 ? Theme.workspaceStretchRef : 28
            var minStretch = Theme.workspaceStretchMin > 0 ? Theme.workspaceStretchMin : 0.3

            var duration = Math.min(base + distance * perPx, maxMs)

            move.stop()
            move.to = targetX
            move.duration = duration
            move.start()

            // Longer jumps stretch more; short hops still get a little squash.
            stretchOut.to = Math.max(minStretch, Math.min(1, distance / refPx))
            stretchOut.duration = Math.max(Theme.motionSnap, duration * 0.45)
            stretchIn.duration = duration * 0.7
            stretchAnim.restart()
        }

        // Snap the first placement so the lens does not slide in from nowhere;
        // afterwards every target change travels.
        onTargetXChanged: {
            if (root.markReady)
                travelTo()
            else
                x = targetX
        }

        NumberAnimation {
            id: move
            target: marker
            property: "x"
            easing.type: Theme.easeEmphasized
        }

        // Elongate as the lens leaves, then relax with a soft spring as it
        // settles, so the motion has a beginning, a middle and an end.
        SequentialAnimation {
            id: stretchAnim
            NumberAnimation {
                id: stretchOut
                target: marker
                property: "stretch"
                to: 1
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                id: stretchIn
                target: marker
                property: "stretch"
                to: 0
                duration: Theme.motionSlow
                easing.type: Theme.easeSpring
                easing.overshoot: Theme.springOvershoot
            }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

        // The stretched pill. Its transform origin is dynamic: the edge facing
        // the destination (right when travelling right, left when travelling
        // left) stays fixed while the rest of the lens grows out behind it, so
        // the stretch trails in the direction the lens came from.
        Item {
            id: pill

            anchors.fill: parent

            // Point the stretch grows from: the destination-facing edge. The
            // vertical origin stays centred so the squash is symmetric.
            readonly property real originX: marker.travelDir >= 0 ? width : 0

            transform: Scale {
                origin.x: pill.originX
                origin.y: pill.height / 2
                xScale: 1 + marker.stretch * 1.7
                yScale: 1 - marker.stretch * 0.24
            }

            // Soft glow that rides along with the lens.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + Theme.spaceSm
                height: parent.height + Theme.spaceXs
                radius: width / 2
                color: root.selectedUrgent
                    ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.35)
                    : Theme.accentGlow
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }

            Rectangle {
                id: lens
                anchors.fill: parent
                radius: width / 2
                color: root.selectedUrgent ? Theme.danger : Theme.accent
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                // An urgent workspace breathes so it catches the eye without
                // becoming noisy. Reset to rest as soon as attention clears.
                SequentialAnimation on scale {
                    running: root.selectedUrgent && !Theme.gameMode
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.25; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                }
                Connections {
                    target: root
                    function onSelectedUrgentChanged() {
                        if (!root.selectedUrgent)
                            lens.scale = 1
                    }
                }
            }
        }
    }

    // Scroll over the row to step through the visible workspaces.
    WheelHandler {
        onWheel: function (event) {
            if (event.angleDelta.y === 0 && event.angleDelta.x === 0)
                return
            var delta = (event.angleDelta.y > 0 || event.angleDelta.x > 0) ? -1 : 1
            root.cycleWorkspace(delta)
        }
    }
}
