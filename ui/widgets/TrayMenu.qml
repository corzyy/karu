import QtQuick

import Quickshell

import "../../core/theme"

/**
 * TrayMenu — a Karu-styled context menu for a system tray item.
 *
 * Renders the entries of a StatusNotifierItem's own menu (a DBusMenu) as a
 * themed card that matches the island, instead of the compositor's native
 * popup. Everything is data-driven from `QsMenuOpener.children`: separators,
 * disabled rows, checkbox / radio state, per-item icons and nested submenus
 * are all drawn.
 *
 * It is a full-window overlay owned by shell.qml so it can float outside the
 * island's clipped bounds: `handle` is the menu to show (the tray item's
 * `.menu`) and `anchorRect` the scene rectangle of the icon it drops from.
 * `dismissed()` asks the host to close it (an entry was activated, or a click
 * landed outside the card).
 *
 * Submenus open as columns to the right; each column is aligned to the row that
 * opened it via `mapToItem`, so nesting stays correct inside a scrolled menu.
 */
Item {
    id: root

    /// The menu to display — a tray item's `.menu` handle — or null.
    property var handle: null
    /// Scene rectangle (`x`/`y`/`width`/`height`) of the icon the menu hangs
    /// from.
    property var anchorRect: Qt.rect(0, 0, 0, 0)
    /// The screen the menu is kept within.
    property real screenWidth: 0
    property real screenHeight: 0

    signal dismissed()

    readonly property bool open: handle !== null
    visible: open
    anchors.fill: parent

    // ── Metrics ──────────────────────────────────────────────────────────────
    readonly property int rowHeight: 30
    readonly property int separatorHeight: 9
    readonly property int rowSpacing: 1
    readonly property int menuWidth: 210
    readonly property int maxMenuHeight: 340
    readonly property int gap: Theme.spaceXs

    /// Handles of the open submenu chain: entry N is the submenu opened from the
    /// row at `path[N-1].y` (a y measured in this overlay's coordinates).
    property var path: []

    onHandleChanged: path = []
    onVisibleChanged: if (!visible) path = []

    // The root menu, opened once here purely to measure its height for the
    // open-upward decision; the visible column has its own opener.
    QsMenuOpener { id: measureOpener; menu: root.handle }
    readonly property var rootEntries:
        measureOpener.children ? measureOpener.children.values : []
    readonly property real rootHeight:
        Math.min(root.maxMenuHeight, menuHeight(rootEntries) + Theme.spaceXs * 2)

    /// Pixel height of a list of entries: rows, separators and the 1px gaps
    /// between them. Computed from the known row metrics so it stays correct
    /// even though the rows set their size explicitly (a positioner would
    /// otherwise measure them as zero-tall).
    function menuHeight(entries) {
        var h = 0
        for (var i = 0; i < entries.length; i++) {
            if (i > 0)
                h += rowSpacing
            h += entries[i].isSeparator ? separatorHeight : rowHeight
        }
        return h
    }

    // ── Placement ────────────────────────────────────────────────────────────
    readonly property real belowY: anchorRect.y + anchorRect.height + gap
    readonly property real aboveY: anchorRect.y - rootHeight - gap
    readonly property real menuY:
        (screenHeight > 0 && belowY + rootHeight > screenHeight - 8)
            ? Math.max(8, aboveY) : belowY
    readonly property real totalWidth:
        (1 + path.length) * menuWidth + path.length * gap
    readonly property real menuX: {
        var maxX = (screenWidth > 0 ? screenWidth : anchorRect.x + totalWidth)
            - totalWidth - 8
        return Math.max(8, Math.min(anchorRect.x, maxX))
    }

    readonly property var columns:
        open ? [{ handle: handle, y: 0 }].concat(path) : []

    // ── Model edits ──────────────────────────────────────────────────────────
    function openSub(depth, entry, absY) {
        var p = path.slice(0, depth)
        p.push({ handle: entry, y: absY })
        path = p
    }
    function clearSubs(depth) {
        if (path.length > depth)
            path = path.slice(0, depth)
    }
    function activate(entry) {
        entry.triggered()
        root.dismissed()
    }

    // Click anywhere outside the cards to dismiss. Declared first so the
    // columns below sit on top of it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: root.dismissed()
    }

    Repeater {
        model: root.columns

        delegate: MenuColumn {
            required property var modelData
            required property int index

            handle: modelData.handle
            depth: index
            x: root.menuX + index * (root.menuWidth + root.gap)
            y: index === 0 ? root.menuY : modelData.y
        }
    }

    // ── One menu column ──────────────────────────────────────────────────────
    // A themed card of rows for a single menu level. Nested levels are just more
    // columns, positioned by the root; a row with children opens the next.
    component MenuColumn: Rectangle {
        id: column

        property var handle: null
        property int depth: 0
        readonly property var entries:
            opener.children ? opener.children.values : []
        readonly property real contentHeight: root.menuHeight(entries)

        width: root.menuWidth
        height: Math.min(root.maxMenuHeight,
            contentHeight + Theme.spaceXs * 2)
        radius: Theme.radiusCard
        color: Theme.surfaceElevated
        border.width: 1
        border.color: Theme.borderStrong
        clip: true

        QsMenuOpener { id: opener; menu: column.handle }

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: width
            contentHeight: column.contentHeight + Theme.spaceXs * 2
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: list
                x: Theme.cardPadding
                y: Theme.spaceXs
                width: column.width - Theme.cardPadding * 2
                height: column.contentHeight
                spacing: root.rowSpacing

                Repeater {
                    model: column.entries

                    delegate: Item {
                        id: entryItem
                        required property var modelData

                        readonly property var entry: modelData
                        readonly property bool checkable:
                            entry.buttonType !== QsMenuButtonType.None
                        readonly property bool checked:
                            checkable && entry.checkState === Qt.Checked

                        width: list.width
                        height: entry.isSeparator ? root.separatorHeight
                            : root.rowHeight

                        // Separator.
                        Rectangle {
                            visible: entryItem.entry.isSeparator
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            color: Theme.border
                        }

                        // Hover / press background.
                        Rectangle {
                            visible: !entryItem.entry.isSeparator
                            anchors.fill: parent
                            radius: Theme.radiusInner
                            color: (rowHover.hovered && entryItem.entry.enabled)
                                ? Theme.surfaceHover : "transparent"
                            Behavior on color {
                                ColorAnimation { duration: Theme.motionSnap }
                            }
                        }

                        // Check / radio indicator (space reserved either way).
                        Text {
                            visible: !entryItem.entry.isSeparator
                                && entryItem.checkable && entryItem.checked
                            width: 16
                            x: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: entryItem.entry.buttonType === QsMenuButtonType.RadioButton
                                ? "\uF111" : "\uF00C" // nf-fa-dot_circle_o / nf-fa-check
                            color: Theme.accent
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }

                        // Optional per-item icon.
                        Image {
                            id: rowIcon
                            visible: !entryItem.entry.isSeparator
                                && entryItem.entry.icon.length > 0
                                && status === Image.Ready
                            x: 16 + Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            source: entryItem.entry.icon
                            sourceSize.width: 32
                            sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {
                            id: rowLabel
                            visible: !entryItem.entry.isSeparator
                            anchors.left: parent.left
                            anchors.leftMargin: (rowIcon.visible
                                ? rowIcon.x + rowIcon.width : 16 + Theme.spaceSm)
                                + (rowIcon.visible ? Theme.spaceSm : 0)
                            anchors.right: chevron.left
                            anchors.rightMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            text: entryItem.entry.text
                            color: entryItem.entry.enabled
                                ? Theme.textPrimary : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleSize
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Submenu arrow.
                        Text {
                            id: chevron
                            visible: !entryItem.entry.isSeparator
                                && entryItem.entry.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uF105" // nf-fa-angle_right
                            color: Theme.textSecondary
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                        }

                        HoverHandler {
                            id: rowHover
                            enabled: !entryItem.entry.isSeparator
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (!hovered)
                                    return
                                if (entryItem.entry.hasChildren)
                                    root.openSub(column.depth, entryItem.entry,
                                        entryItem.mapToItem(root, 0, 0).y)
                                else
                                    root.clearSubs(column.depth)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !entryItem.entry.isSeparator
                                && entryItem.entry.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entryItem.entry.hasChildren)
                                    root.openSub(column.depth, entryItem.entry,
                                        entryItem.mapToItem(root, 0, 0).y)
                                else
                                    root.activate(entryItem.entry)
                            }
                        }
                    }
                }
            }
        }
    }
}
