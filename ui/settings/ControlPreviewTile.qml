import QtQuick

import "../panels"
import "../../core/theme"
import "../../core/config/ControlCatalog.js" as ControlCatalog

/**
 * ControlPreviewTile — one control on the layout editor's grid.
 *
 * It draws the real, live control (`ControlItem`, made non-interactive) so the
 * preview is identical to the panel, then wraps it in the editor's affordances:
 * click to select, drag to move, pull the corner to resize, right-click for the
 * size menu. A ghost outline marks the cell the drag will snap to, and the whole
 * gesture grabs the surrounding scroll view so the page never scrolls out from
 * under the pointer.
 *
 * The editor owns the layout model and receives edits as signals.
 */
Item {
    id: tile

    property var entry: null
    property bool selected: false
    property int columns: 7
    property real cellW: 60
    property int rowH: 44
    property int gap: 8

    signal selectRequested(var entry)
    signal moved(var entry, int col, int row)
    signal resized(var entry, int w, int h)
    signal contextMenuRequested(var entry, real gx, real gy)
    signal removed(var entry)

    readonly property var info: entry ? ControlCatalog.info(entry.type) : null
    readonly property string kind: info ? info.kind : "toggle"

    // Match the real control's corner so the selection outline sits exactly on
    // its edge: toggle tiles are pills, the small buttons use the inner radius,
    // everything else the card radius.
    readonly property int outlineRadius: kind === "toggle"
        ? Math.round(Math.min(width, height) / 2)
        : (kind === "small" || kind === "action") ? Theme.radiusInner : Theme.radiusCard

    readonly property var cell: entry
        ? ControlCatalog.rect(entry, cellW, rowH, gap)
        : ({ x: 0, y: 0, width: 0, height: 0 })

    property real dragDX: 0
    property real dragDY: 0
    property real resizeDW: 0
    property real resizeDH: 0
    property bool dragging: false
    property bool resizing: false
    // Pointer anchors, in the parent (canvas) coordinate system, so a tile moving
    // under the pointer cannot feed back into its own offset.
    property real pressX: 0
    property real pressY: 0
    property real baseX: 0
    property real baseY: 0
    property real baseW: 0
    property real baseH: 0

    x: cell.x + dragDX
    y: cell.y + dragDY
    width: Math.max(cellW, cell.width + resizeDW)
    height: Math.max(rowH, cell.height + resizeDH)
    z: (dragging || resizing) ? 100 : (selected ? 10 : 0)

    // The cell the drag will snap to, in parent coordinates.
    readonly property int snapCol: ControlCatalog.cellAt(baseX + dragDX, cellW, gap)
    readonly property int snapRow: ControlCatalog.cellAt(baseY + dragDY, rowH, gap)

    // ── Scroll guard ─────────────────────────────────────────────────────────
    // The Settings page is a Flickable; without this a drag would also flick the
    // page. Find the enclosing Flickable and switch it off for the gesture.
    property var scrollView: null
    function holdScroll() {
        var p = tile.parent
        while (p) {
            if (p instanceof Flickable) {
                scrollView = p
                p.interactive = false
                return
            }
            p = p.parent
        }
    }
    function releaseScroll() {
        if (scrollView) {
            scrollView.interactive = true
            scrollView = null
        }
    }

    // ── Ghost: where the tile will land ──────────────────────────────────────
    Rectangle {
        visible: tile.dragging
        x: tile.snapCol * (tile.cellW + tile.gap) - tile.x
        y: tile.snapRow * (tile.rowH + tile.gap) - tile.y
        width: tile.width
        height: tile.height
        radius: tile.outlineRadius
        color: Theme.accentMuted
        border.width: 2
        border.color: Theme.accent
        opacity: 0.6
    }

    // ── The real control, display-only ───────────────────────────────────────
    ControlItem {
        anchors.fill: parent
        type: tile.entry ? tile.entry.type : ""
        interactive: false
        opacity: tile.dragging ? 0.9 : 1
    }

    // ── Selection / hover outline ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: tile.outlineRadius
        color: "transparent"
        border.width: tile.selected ? 2 : (hover.hovered ? 1 : 0)
        border.color: tile.selected ? Theme.accent : Theme.accentGlow
        z: 1

        HoverHandler {
            id: hover
            cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
    }

    // ── Drag to move ─────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        cursorShape: Qt.OpenHandCursor
        z: 2

        onPressed: function (mouse) {
            tile.selectRequested(tile.entry)
            tile.holdScroll()
            var p = tile.mapToItem(tile.parent, mouse.x, mouse.y)
            tile.pressX = p.x
            tile.pressY = p.y
            tile.baseX = tile.x
            tile.baseY = tile.y
            tile.dragging = true
        }
        onPositionChanged: function (mouse) {
            if (!tile.dragging)
                return
            var p = tile.mapToItem(tile.parent, mouse.x, mouse.y)
            tile.dragDX = p.x - tile.pressX
            tile.dragDY = p.y - tile.pressY
        }
        onReleased: function (mouse) {
            if (!tile.dragging)
                return
            tile.dragging = false
            tile.releaseScroll()
            var col = ControlCatalog.cellAt(tile.baseX + tile.dragDX, tile.cellW, tile.gap)
            var row = ControlCatalog.cellAt(tile.baseY + tile.dragDY, tile.rowH, tile.gap)
            tile.dragDX = 0
            tile.dragDY = 0
            tile.moved(tile.entry, col, row)
        }
        onCanceled: {
            tile.dragging = false
            tile.dragDX = 0
            tile.dragDY = 0
            tile.releaseScroll()
        }
    }

    // ── Right-click: the size menu ────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        z: 2
        onClicked: {
            tile.selectRequested(tile.entry)
            tile.contextMenuRequested(tile.entry, tile.x, tile.y)
        }
    }

    // ── Delete badge (only while selected) ────────────────────────────────────
    Rectangle {
        visible: tile.selected
        x: 2
        y: 2
        width: 20
        height: 20
        radius: width / 2
        color: Theme.danger
        z: 20

        Text {
            anchors.centerIn: parent
            text: "\uF00D" // nf-fa-times
            color: Theme.background
            font.family: Theme.iconFont
            font.pixelSize: 10
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.removed(tile.entry)
        }
    }

    // ── Resize corner (only while selected) ───────────────────────────────────
    Item {
        visible: tile.selected
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 20
        height: 20
        z: 20

        Text {
            anchors.centerIn: parent
            text: "\uF0C9" // nf-fa-bars, used as a diagonal resize hint
            rotation: -45
            color: Theme.accent
            font.family: Theme.iconFont
            font.pixelSize: 10
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.SizeFDiagCursor

            onPressed: function (mouse) {
                tile.selectRequested(tile.entry)
                tile.holdScroll()
                var p = tile.mapToItem(tile.parent, mouse.x, mouse.y)
                tile.pressX = p.x
                tile.pressY = p.y
                tile.baseW = tile.width
                tile.baseH = tile.height
                tile.resizing = true
            }
            onPositionChanged: function (mouse) {
                if (!tile.resizing)
                    return
                var p = tile.mapToItem(tile.parent, mouse.x, mouse.y)
                tile.resizeDW = p.x - tile.pressX
                tile.resizeDH = p.y - tile.pressY
            }
            onReleased: function (mouse) {
                if (!tile.resizing)
                    return
                var w = ControlCatalog.spanAt(tile.baseW + tile.resizeDW, tile.cellW, tile.gap)
                var h = ControlCatalog.spanAt(tile.baseH + tile.resizeDH, tile.rowH, tile.gap)
                tile.resizing = false
                tile.resizeDW = 0
                tile.resizeDH = 0
                tile.releaseScroll()
                tile.resized(tile.entry, w, h)
            }
            onCanceled: {
                tile.resizing = false
                tile.resizeDW = 0
                tile.resizeDH = 0
                tile.releaseScroll()
            }
        }
    }
}
