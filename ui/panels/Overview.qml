import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

import "../../core/theme"

/**
 * Overview — the Alt+Tab window switcher / expo.
 *
 * It is an ordinary island panel (like the Control Center): selecting it sets
 * `stack.current = "overview"` in shell.qml, the island grows out of its pill
 * using the island's own width/height animations, and this content is revealed
 * inside it. It is simply a wider panel (Theme.overviewWidth) so the workspace
 * mirrors fit; its height is its content height, capped to the screen so a tall
 * stack scrolls instead of growing the island off-screen.
 *
 * Layout: one column per Hyprland workspace, ordered to match the desk — left
 * to right (then top to bottom) by the physical position of each workspace's
 * monitor, and by workspace id within a monitor. Rather than stacking window
 * thumbnails, each column is a *scaled mirror of the workspace*: the column body
 * is the monitor drawn at its true aspect ratio, and every window is placed at
 * its real position and size within it (mapped from the toplevel's
 * `lastIpcObject.at` / `size` onto the monitor's logical box). Two tiled windows
 * therefore show side by side, a floating dialog sits in the middle, a
 * fullscreen window fills the screen — exactly the arrangement on that
 * workspace. Window content is captured per-toplevel with `ScreencopyView` —
 * Hyprland exposes the needed protocols, so these are real live thumbnails, not
 * screenshots of the whole screen.
 *
 * Interaction (the shell gives the island exclusive keyboard focus while this
 * panel is open):
 *   Alt+Tab         close (the same binding opens it, so it is a plain toggle)
 *   Tab / ↓ / →     next window      Shift+Tab / ↑ / ←   previous window
 *   Enter           focus the highlight
 *   Esc             close
 *   click a card    focus that window
 *   click its ×     close that window
 *   middle-click    force-kill that window
 *   drag a card     move that window to the workspace you drop it on
 *
 * The component owns no compositor state: it reports intent through the
 * `activateRequested` / `closeRequested` / `killRequested` / `moveRequested` /
 * `requestClose` signals and shell.qml performs the dispatch (Lua-aware,
 * matching WorkspaceIndicator).
 *
 * The root is a plain Item holding the scrolling content plus a drag overlay, so
 * a card being dragged can render above the columns (and outside the Flickable's
 * clip) while it follows the pointer.
 */
Item {
    id: root

    implicitHeight: layout.implicitHeight

    /// The screen the island lives on (injected by PanelStack); only used to cap
    /// the panel height so a busy workspace scrolls rather than overflows.
    property var screen: null

    /// A card was chosen — shell.qml focuses that toplevel.
    signal activateRequested(var toplevel)
    /// The × on a card was pressed — shell.qml closes that toplevel.
    signal closeRequested(var toplevel)
    /// Middle-click on a card — shell.qml force-kills that toplevel.
    signal killRequested(var toplevel)
    /// A card was dragged onto another workspace — shell.qml moves that toplevel
    /// to `workspaceId`.
    signal moveRequested(var toplevel, int workspaceId)
    /// Esc was pressed — shell.qml collapses the island.
    signal requestClose()

    // ── Live model ───────────────────────────────────────────────────────────
    // One entry per workspace that currently holds windows:
    //   { id, name, monitor, ws, mon, items: [ { tl, flat, mon } ] }
    // `flat` is the index into the flattened `cells` list, which is what
    // keyboard navigation moves through. Grouping straight off each toplevel's
    // workspace (rather than Hyprland.workspaces) keeps every window visible
    // even across monitors and special workspaces. `mon` is the HyprlandMonitor
    // the workspace lives on, used to map window coordinates onto the mirror.
    readonly property var groups: {
        var tls = Hyprland.toplevels.values
        var byId = ({})
        var order = []
        for (var i = 0; i < tls.length; i++) {
            var tl = tls[i]
            var ws = tl.workspace
            var key = ws ? ws.id : -2147483648
            if (byId[key] === undefined) {
                var gm = (ws && ws.monitor) ? ws.monitor : (tl.monitor ? tl.monitor : null)
                byId[key] = {
                    id: key,
                    name: ws ? ws.name : "?",
                    monitor: gm ? gm.name : "",
                    ws: ws,
                    mon: gm,
                    items: []
                }
                order.push(key)
            }
            byId[key].items.push({
                tl: tl,
                flat: 0,
                mon: tl.monitor ? tl.monitor : byId[key].mon
            })
        }

        // Order the columns to match the desk: left-to-right (and top-to-bottom)
        // by the physical position of each workspace's monitor, then by
        // workspace id within a monitor. A monitor's workspaces therefore stay
        // contiguous, so the overview reads the same way you see your screens.
        // Workspaces with no resolvable monitor sort last.
        order.sort(function (a, b) {
            var ma = byId[a].mon
            var mb = byId[b].mon
            var ax = ma ? ma.x : 1e9
            var ay = ma ? ma.y : 1e9
            var bx = mb ? mb.x : 1e9
            var by = mb ? mb.y : 1e9
            if (ax !== bx) return ax - bx
            if (ay !== by) return ay - by
            return a - b
        })

        var out = []
        var flat = 0
        for (var j = 0; j < order.length; j++) {
            var g = byId[order[j]]
            for (var k = 0; k < g.items.length; k++)
                g.items[k].flat = flat++
            out.push(g)
        }
        return out
    }

    /// Flattened window list; `selectedFlat` indexes into this.
    readonly property var cells: {
        var out = []
        for (var i = 0; i < root.groups.length; i++) {
            var items = root.groups[i].items
            for (var j = 0; j < items.length; j++)
                out.push(items[j])
        }
        return out
    }

    property int selectedFlat: -1

    // ── Workspace mirror mapping ─────────────────────────────────────────────
    // Each column draws its monitor as a screen of width `displayWidth` with a
    // small `pad` bezel, at the monitor's true aspect ratio. A window's global
    // layout box (`lastIpcObject.at` / `.size`, in logical pixels) is shifted by
    // the monitor's origin and scaled by `innerWidth / logicalMonitorWidth`, so
    // the mirror reproduces the real arrangement.
    readonly property int displayWidth: Theme.overviewWorkspaceWidth
    readonly property int pad: Theme.overviewPad

    function monitorAspect(mon) {
        if (mon && mon.width > 0 && mon.height > 0)
            return mon.height / mon.width
        return 9 / 16
    }

    /// Height of a workspace mirror: the bezel plus the monitor's aspect box.
    function canvasHeightForMonitor(mon) {
        return Math.round((root.displayWidth - root.pad * 2) * root.monitorAspect(mon))
            + root.pad * 2
    }

    /// A window's position and size inside the mirror, in column coordinates.
    /// Falls back to a full-canvas card when the compositor has reported no
    /// geometry for the toplevel yet (e.g. a hidden or just-mapped window).
    function rectFor(item) {
        var mon = item.mon
        var innerW = root.displayWidth - root.pad * 2
        var innerH = root.canvasHeightForMonitor(mon) - root.pad * 2
        var full = { x: root.pad, y: root.pad, w: innerW, h: innerH }

        var tl = item.tl
        var o = tl ? tl.lastIpcObject : null
        if (!mon || mon.width <= 0 || !o || !o.at || !o.size)
            return full

        var s = mon.scale > 0 ? mon.scale : 1
        var logicalW = mon.width / s
        if (logicalW <= 0)
            return full

        var k = innerW / logicalW
        return {
            x: root.pad + (o.at[0] - mon.x) * k,
            y: root.pad + (o.at[1] - mon.y) * k,
            w: Math.max(Theme.overviewMinWindow, o.size[0] * k),
            h: Math.max(Theme.overviewMinWindow, o.size[1] * k)
        }
    }

    // ── Sizing ───────────────────────────────────────────────────────────────
    /// Natural width of the columns, so the island can grow to fit them all
    /// (shell.qml reads this to size the panel) instead of clipping the last one.
    readonly property real preferredContentWidth: root.groups.length > 0
        ? root.groups.length * Theme.overviewWorkspaceWidth
            + Math.max(0, root.groups.length - 1) * Theme.overviewColumnGap
        : 0

    readonly property int columnHeaderHeight: 20
    // The tallest mirror decides the panel height, so no workspace is clipped.
    readonly property real maxCanvasHeight: {
        var m = 1
        for (var i = 0; i < root.groups.length; i++)
            m = Math.max(m, root.canvasHeightForMonitor(root.groups[i].mon))
        return m
    }
    // A column is the workspace header plus its mirror.
    readonly property real columnsHeight: root.columnHeaderHeight + Theme.overviewCardGap
        + root.maxCanvasHeight
    // Grow to fit the tallest mirror; only if that would run past the bottom of
    // the screen does the area fall back to scrolling. A few px of slack keep
    // the selected card's small scale-up from being clipped by the Flickable.
    readonly property real maxContentHeight: Math.max(160,
        (root.screen ? root.screen.height : 1080) - Theme.topMargin
            - Theme.panelPadding * 2 - Theme.spaceLg)
    readonly property real contentHeight: Math.min(Math.max(root.columnsHeight, 160) + Theme.spaceXs,
        root.maxContentHeight)

    // ── Drag to move a window to another workspace ───────────────────────────
    // A card is dragged with the pointer (its MouseArea owns the gesture, so it
    // survives leaving the card). While dragging, a proxy follows the cursor on
    // `dragLayer` and the column under the pointer is highlighted; on release the
    // window is moved to that workspace's id.
    property bool dragging: false
    property var dragToplevel: null
    property int dragSourceWs: -2147483648
    property real dragX: 0
    property real dragY: 0
    property int dropIndex: -1

    function beginDrag(tl, ws) {
        root.dragging = true
        root.dragToplevel = tl
        root.dragSourceWs = ws ? ws.id : -2147483648
        root.dropIndex = -1
    }

    /// Update the drag from a pointer position in root coordinates.
    function updateDrag(rootX, rootY) {
        root.dragX = rootX
        root.dragY = rootY

        var p = columnsRow.mapFromItem(root, rootX, rootY)
        var n = root.groups.length
        var step = Theme.overviewWorkspaceWidth + Theme.overviewColumnGap
        var idx = -1
        if (n > 0 && p.x >= 0 && p.y >= -20 && p.y <= columnsRow.height + 20) {
            var i = Math.floor(p.x / step)
            if (i >= 0 && i < n)
                idx = i
        }
        root.dropIndex = idx
    }

    function endDrag() {
        if (!root.dragging)
            return
        var tl = root.dragToplevel
        var idx = root.dropIndex
        if (tl && idx >= 0 && idx < root.groups.length) {
            var target = root.groups[idx]
            if (target.id !== root.dragSourceWs)
                root.moveRequested(tl, target.id)
        }
        root.dragging = false
        root.dragToplevel = null
        root.dropIndex = -1
    }

    // ── Selection / actions ──────────────────────────────────────────────────
    function cycle(delta) {
        var n = root.cells.length
        if (n === 0)
            return
        root.selectedFlat = ((root.selectedFlat + delta) % n + n) % n
    }

    function activateAt(flat) {
        if (flat >= 0 && flat < root.cells.length)
            root.activateRequested(root.cells[flat].tl)
        else
            root.requestClose()
    }

    function activateSelected() {
        if (root.selectedFlat >= 0 && root.selectedFlat < root.cells.length)
            root.activateRequested(root.cells[root.selectedFlat].tl)
        else
            root.requestClose()
    }

    /// Prefer the window title; fall back to the class Hyprland reports.
    function labelFor(tl) {
        if (!tl)
            return ""
        if (tl.title && tl.title.length > 0)
            return tl.title
        var o = tl.lastIpcObject
        if (o && o.class)
            return o.class
        return tl.address || ""
    }

    function isFocusedGroup(group) {
        return group.ws ? group.ws.focused : false
    }

    // On load, highlight the currently focused window so the highlight starts
    // where you are; Tab/arrows move it from there.
    Component.onCompleted: {
        var idx = -1
        var at = Hyprland.activeToplevel
        if (at) {
            for (var i = 0; i < root.cells.length; i++) {
                if (root.cells[i].tl.address === at.address) {
                    idx = i
                    break
                }
            }
        }
        root.selectedFlat = root.cells.length > 0
            ? (idx >= 0 ? idx : 0)
            : -1
    }

    // Keep the highlight valid as windows come and go while it is open.
    onCellsChanged: {
        if (root.selectedFlat >= root.cells.length)
            root.selectedFlat = root.cells.length - 1
        if (root.selectedFlat < 0 && root.cells.length > 0)
            root.selectedFlat = 0
    }

    // ── Keyboard ─────────────────────────────────────────────────────────────
    // Alt+Tab is a plain toggle: while the overview is open it holds exclusive
    // keyboard focus, so the key reaches us here and closes it again. Tab and
    // the arrows move the highlight, Enter focuses it, Esc closes.
    focus: true
    Keys.onPressed: function (event) {
        var alt = event.modifiers & Qt.AltModifier
        if (event.key === Qt.Key_Escape || (event.key === Qt.Key_Tab && alt)) {
            root.requestClose()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            root.cycle((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.cycle(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.cycle(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateSelected()
            event.accepted = true
        }
    }

    // ── Scrolling content ────────────────────────────────────────────────────
    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        spacing: Theme.spaceLg

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: root.contentHeight

            contentWidth: Math.max(width, columnsRow.width)
            contentHeight: Math.max(height, columnsRow.height)
            clip: true
            interactive: columnsRow.width > width || columnsRow.height > height
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: columnsRow
                // Centre when it fits; scrolls when it does not.
                x: Math.max(0, (flick.width - width) / 2)
                y: Math.max(0, (flick.height - height) / 2)
                spacing: Theme.overviewColumnGap

                Repeater {
                    model: root.groups

                    delegate: Column {
                        id: column

                        required property var modelData

                        readonly property bool dropTarget: root.dragging && root.dropIndex === index

                        spacing: Theme.overviewCardGap

                        // Workspace label: accent when this workspace is focused
                        // on its monitor, otherwise a dim dot + name.
                        Item {
                            width: Theme.overviewWorkspaceWidth
                            height: root.columnHeaderHeight

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spaceSm

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 7
                                    height: 7
                                    radius: width / 2
                                    color: root.isFocusedGroup(modelData) ? Theme.accent : Theme.textDim
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Workspace " + modelData.id
                                    color: column.dropTarget || root.isFocusedGroup(modelData)
                                        ? Theme.textPrimary : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sectionSize
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: modelData.monitor.length > 0
                                    text: modelData.monitor
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.subtitleSize
                                }
                            }
                        }

                        // The mirror itself: the workspace's monitor drawn at its
                        // true aspect, with every window placed where it really
                        // is. Clipped to the rounded screen so nothing spills
                        // out. Highlighted while it is a drop target.
                        ClippingRectangle {
                            width: Theme.overviewWorkspaceWidth
                            height: root.canvasHeightForMonitor(modelData.mon)
                            radius: Theme.radiusCard
                            color: column.dropTarget
                                ? Qt.rgba(0.66, 0.90, 0.85, 0.10)
                                : Qt.rgba(0, 0, 0, 0.35)
                            border.width: column.dropTarget ? 2 : 1
                            border.color: column.dropTarget ? Theme.accent : Theme.border
                            Behavior on border.color { ColorAnimation { duration: Theme.motionSnap } }

                            Repeater {
                                model: modelData.items

                                delegate: OverviewCard {
                                    required property var modelData
                                    toplevel: modelData.tl
                                    flatIndex: modelData.flat
                                    selected: root.selectedFlat === modelData.flat
                                    layout: root.rectFor(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Shown instead of the columns when nothing is open.
            Text {
                anchors.centerIn: parent
                visible: root.cells.length === 0
                text: "No open windows"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
            }
        }
    }

    // ── Drag proxy ───────────────────────────────────────────────────────────
    // Follows the pointer above everything, showing what is being dragged.
    Item {
        anchors.fill: parent
        z: 100
        visible: root.dragging

        Rectangle {
            x: Math.round(root.dragX - width / 2)
            y: Math.round(root.dragY - height / 2)
            width: Math.min(240, Math.max(120, proxyText.implicitWidth + 28))
            height: 40
            radius: Theme.radiusInner
            color: Theme.surfaceElevated
            border.width: 2
            border.color: root.dropIndex >= 0 ? Theme.accent : Theme.borderStrong
            opacity: 0.96

            Text {
                id: proxyText
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: root.labelFor(root.dragToplevel)
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize + 1
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    // ── A single live window thumbnail ───────────────────────────────────────
    // Positioned and sized by `layout` (see root.rectFor), so it mirrors where
    // the window actually sits on its workspace rather than stacking in a list.
    component OverviewCard: Item {
        id: card

        property var toplevel: null
        property int flatIndex: -1
        property bool selected: false
        property var layout: ({ x: 0, y: 0,
                                w: Theme.overviewWorkspaceWidth, h: 100 })

        x: layout.x
        y: layout.y
        width: layout.w
        height: layout.h
        // Keep the highlighted window above its neighbours so its ring shows.
        z: selected ? 2 : 1
        scale: selected ? Theme.overviewSelectedScale : 1
        // Dim the card that is currently being dragged; the proxy flies instead.
        opacity: (root.dragging && root.dragToplevel === card.toplevel) ? 0.3 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easeSpring
                easing.overshoot: Theme.springOvershoot
            }
        }

        ClippingRectangle {
            id: frame
            anchors.fill: parent
            radius: Math.max(2, Math.min(Theme.radiusThumb, card.width / 5, card.height / 5))
            color: Theme.surfaceElevated
            border.width: card.selected ? 2 : 1
            border.color: card.selected ? Theme.accent : Theme.border
            clip: true
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            // Live per-window capture. Only run the stream while the overview
            // is up; at rest this stops and costs nothing.
            ScreencopyView {
                id: shot
                anchors.fill: parent
                captureSource: card.toplevel ? card.toplevel.wayland : null
                live: true
                paintCursor: false
                constraintSize: Qt.size(frame.width, frame.height)
            }

            // Placeholder while there is no frame yet (hidden window, capture
            // not started, …).
            Text {
                anchors.centerIn: parent
                visible: !shot.hasContent
                text: "\uF2D0" // nf-md-window_restore
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Math.max(10, Math.min(26, card.height * 0.4))
            }

            // Bottom label: the window title. Hidden on windows too small to
            // carry one, so the mirror stays legible.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(22, card.height * 0.3)
                color: Qt.rgba(0, 0, 0, 0.55)
                visible: card.width >= 64 && card.height >= 28

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: root.labelFor(card.toplevel)
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(8, Math.min(Theme.subtitleSize + 1, parent.height - 4))
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        // Hover selects; click commits (focuses) this window; middle-click
        // force-kills it; press-and-drag (left) moves the window to the
        // workspace it is dropped on. The MouseArea owns the gesture (rather than
        // a DragHandler) so the card can be carried past the canvas it lives in.
        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: cardMouse.didDrag ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property bool pressActive: false
            property bool didDrag: false
            property real pressX: 0
            property real pressY: 0

            function rootPoint(mx, my) {
                return root.mapFromItem(cardMouse, mx, my)
            }

            onPressed: function (mouse) {
                // Only the left button starts a drag; the middle button is a
                // kill click.
                cardMouse.pressActive = mouse.button === Qt.LeftButton
                cardMouse.didDrag = false
                var p = cardMouse.rootPoint(mouse.x, mouse.y)
                cardMouse.pressX = p.x
                cardMouse.pressY = p.y
            }

            onPositionChanged: function (mouse) {
                if (!cardMouse.pressActive)
                    return
                var p = cardMouse.rootPoint(mouse.x, mouse.y)
                if (!cardMouse.didDrag) {
                    var dx = p.x - cardMouse.pressX
                    var dy = p.y - cardMouse.pressY
                    if (dx * dx + dy * dy > 36) {
                        cardMouse.didDrag = true
                        root.beginDrag(card.toplevel, card.toplevel ? card.toplevel.workspace : null)
                    }
                }
                if (cardMouse.didDrag)
                    root.updateDrag(p.x, p.y)
            }

            onReleased: {
                if (cardMouse.didDrag)
                    root.endDrag()
                cardMouse.pressActive = false
            }

            onCanceled: {
                if (cardMouse.didDrag)
                    root.endDrag()
                cardMouse.pressActive = false
                cardMouse.didDrag = false
            }

            onEntered: root.selectedFlat = card.flatIndex
            onClicked: function (mouse) {
                if (mouse.button === Qt.MiddleButton)
                    root.killRequested(card.toplevel)
                else if (!cardMouse.didDrag)
                    root.activateAt(card.flatIndex)
            }
        }

        // Close affordance, revealed on hover. Declared last so it sits above
        // the card's MouseArea and swallows the click.
        Rectangle {
            id: closeButton
            readonly property real d: Math.max(14, Math.min(22,
                Math.min(card.width, card.height) * 0.45))
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 5
            width: d
            height: d
            radius: width / 2
            color: closeHover.hovered ? Theme.danger : Qt.rgba(0, 0, 0, 0.55)
            opacity: (cardMouse.containsMouse && !cardMouse.didDrag
                && card.width >= 44 && card.height >= 32) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motionSnap } }
            Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }

            Text {
                anchors.centerIn: parent
                text: "\uF00D" // nf-fa-times
                color: Theme.textPrimary
                font.family: Theme.iconFont
                font.pixelSize: Math.max(8, Math.min(11, closeButton.d - 8))
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeRequested(card.toplevel)
            }
        }
    }
}
