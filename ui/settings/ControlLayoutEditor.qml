import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/config"
import "../../core/config/ControlCatalog.js" as ControlCatalog
import "../bar"

/**
 * ControlLayoutEditor — the Control Center page of the Settings app.
 *
 * A small drag-and-drop editor for the Control Center. The preview under the
 * toolbar is drawn at the panel's real width and row height with the real,
 * non-interactive controls (`ControlItem`), framed by the panel's own fill,
 * corner radius and clock header — so it reads as the actual Control Center.
 *
 * The "Layout" toolbar picks the grid width (4–9 columns) and offers Tidy /
 * Undo / Reset; a tile can be dragged to move, pulled by its corner to resize
 * and right-clicked for the sizes it supports; the "Add a control" palette drops
 * in the ones not yet placed. Every edit is settled so controls can never
 * overlap, and is written to the `Settings` singleton so the live panel follows
 * along immediately.
 *
 * With a control selected the arrow keys nudge it, `[` / `]` step through its
 * sizes and Delete removes it.
 */
Column {
    id: root

    spacing: Theme.spaceLg
    focus: true

    /// The type of the currently selected control ("" when none).
    property string selected: ""
    /// Undo history: a stack of `{ columns, layout }` snapshots.
    property var history: []
    /// The open right-click size menu: `{ entry, x, y }` or null.
    property var sizeMenu: null

    /// Grid rows/key all controls share, so the preview matches the panel.
    readonly property int gap: Theme.gap
    readonly property int rowH: Theme.toggleHeight
    readonly property int columns: Math.max(1, Settings.controlColumns)
    readonly property real panelWidth: Theme.expandedWidth
    readonly property real canvasW: panelWidth - Theme.panelPadding * 2
    readonly property real cellW: ControlCatalog.cellWidth(canvasW, columns, gap)
    readonly property real gridH: ControlCatalog.layoutHeight(Settings.controlLayout, rowH, gap)
    readonly property real headerH: Theme.clockHeaderHeight
    readonly property real panelH: Theme.panelPadding * 2 + headerH + gap + gridH

    // The palette: every control type not already on the grid, in registry order.
    readonly property var availableControls: {
        var out = []
        for (var i = 0; i < ControlCatalog.order.length; i++) {
            var t = ControlCatalog.order[i]
            if (!ControlCatalog.has(Settings.controlLayout, t))
                out.push(t)
        }
        return out
    }

    // ── Model edits ──────────────────────────────────────────────────────────
    /// Push the current state onto the undo stack, then write a new layout (and
    /// optionally a new column count) to Settings.
    function commit(layout, columns) {
        var stack = history.slice()
        stack.push({ columns: Settings.controlColumns, layout: ControlCatalog.clone(Settings.controlLayout) })
        if (stack.length > 60)
            stack.shift()
        history = stack

        if (columns !== undefined && columns !== Settings.controlColumns)
            Settings.set("controlColumns", columns)
        Settings.set("controlLayout", layout)
    }

    function undo() {
        if (history.length === 0)
            return
        var stack = history.slice()
        var s = stack.pop()
        history = stack
        Settings.set("controlColumns", s.columns)
        Settings.set("controlLayout", s.layout)
        selected = ""
    }

    function tidy() {
        var layout = ControlCatalog.tidy(Settings.controlLayout, columns)
        commit(ControlCatalog.settle(layout, columns, null))
    }

    function reset() {
        commit(ControlCatalog.defaultLayout(), ControlCatalog.defaultColumns)
        selected = ""
    }

    function setColumns(n) {
        var layout = ControlCatalog.clone(Settings.controlLayout)
        for (var i = 0; i < layout.length; i++) {
            var e = layout[i]
            if (e.w > n)
                e.w = n
            if (e.col + e.w > n)
                e.col = Math.max(0, n - e.w)
        }
        commit(ControlCatalog.settle(layout, n, null), n)
    }

    function addControl(type) {
        if (ControlCatalog.has(Settings.controlLayout, type))
            return
        var info = ControlCatalog.info(type)
        var w = Math.min(info ? info.defW : 1, columns)
        var h = info ? info.defH : 1
        var slot = ControlCatalog.freeSlot(Settings.controlLayout, w, h, columns)
        var layout = ControlCatalog.clone(Settings.controlLayout)
        layout.push({ type: type, col: slot.col, row: slot.row, w: slot.w, h: h })
        commit(ControlCatalog.settle(layout, columns, type))
        selected = type
    }

    function removeEntry(entry) {
        if (!entry)
            return
        var layout = []
        for (var i = 0; i < Settings.controlLayout.length; i++)
            if (Settings.controlLayout[i].type !== entry.type)
                layout.push(ControlCatalog.clone([Settings.controlLayout[i]])[0])
        if (selected === entry.type)
            selected = ""
        commit(layout)
    }

    function moveEntry(entry, col, row) {
        if (!entry)
            return
        col = Math.max(0, Math.min(columns - entry.w, col))
        row = Math.max(0, row)
        if (col === entry.col && row === entry.row)
            return
        var layout = ControlCatalog.clone(Settings.controlLayout)
        var target = ControlCatalog.entryFor(layout, entry.type)
        if (!target)
            return
        target.col = col
        target.row = row
        commit(ControlCatalog.settle(layout, columns, entry.type))
    }

    function resizeEntry(entry, w, h) {
        if (!entry)
            return
        w = Math.max(1, Math.min(columns - entry.col, w))
        h = Math.max(1, h)
        if (w === entry.w && h === entry.h)
            return
        var layout = ControlCatalog.clone(Settings.controlLayout)
        var target = ControlCatalog.entryFor(layout, entry.type)
        target.w = w
        target.h = h
        commit(ControlCatalog.settle(layout, columns, entry.type))
    }

    function applySize(entry, w, h) {
        if (!entry)
            return
        w = Math.max(1, Math.min(columns - entry.col, w))
        h = Math.max(1, h)
        var layout = ControlCatalog.clone(Settings.controlLayout)
        var target = ControlCatalog.entryFor(layout, entry.type)
        target.w = w
        target.h = h
        commit(ControlCatalog.settle(layout, columns, entry.type))
        selected = entry.type
    }

    function cycleSize(entry, dir) {
        if (!entry)
            return
        var sizes = ControlCatalog.sizesFor(entry.type, columns)
        var idx = 0
        for (var i = 0; i < sizes.length; i++) {
            if (sizes[i][0] === entry.w && sizes[i][1] === entry.h) {
                idx = i
                break
            }
        }
        idx = (idx + dir + sizes.length) % sizes.length
        applySize(entry, sizes[idx][0], sizes[idx][1])
    }

    function openSizeMenu(entry, gx, gy) {
        sizeMenu = { entry: entry, x: gx, y: gy }
    }

    // ── Keyboard nudging / sizing / deletion ─────────────────────────────────
    Keys.onPressed: function (event) {
        if (root.selected === "")
            return
        var entry = ControlCatalog.entryFor(Settings.controlLayout, root.selected)
        if (!entry)
            return
        switch (event.key) {
            case Qt.Key_Left:        root.moveEntry(entry, entry.col - 1, entry.row); event.accepted = true; break
            case Qt.Key_Right:       root.moveEntry(entry, entry.col + 1, entry.row); event.accepted = true; break
            case Qt.Key_Up:          root.moveEntry(entry, entry.col, entry.row - 1); event.accepted = true; break
            case Qt.Key_Down:        root.moveEntry(entry, entry.col, entry.row + 1); event.accepted = true; break
            case Qt.Key_Delete:
            case Qt.Key_Backspace:   root.removeEntry(entry); event.accepted = true; break
            case Qt.Key_BracketLeft:  root.cycleSize(entry, -1); event.accepted = true; break
            case Qt.Key_BracketRight: root.cycleSize(entry, 1); event.accepted = true; break
        }
    }

    // ── Toolbar ──────────────────────────────────────────────────────────────
    RowLayout {
        width: parent.width
        spacing: Theme.spaceSm

        Text {
            text: "Layout"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sectionSize
            font.weight: Font.Medium
        }

        Repeater {
            model: [4, 5, 6, 7, 8, 9]

            delegate: Rectangle {
                required property int modelData

                readonly property bool active: modelData === Settings.controlColumns

                Layout.preferredWidth: 30
                Layout.preferredHeight: 28
                radius: Theme.radiusInner
                color: active ? Theme.accent : (chipHover.hovered ? Theme.surfaceHover : Theme.surfaceElevated)
                border.width: 1
                border.color: active ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

                HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: parent.active ? Theme.backgroundSolid : Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setColumns(modelData)
                }
            }
        }

        Item { Layout.preferredWidth: Theme.spaceSm }

        Repeater {
            model: [
                { label: "Tidy", action: "tidy" },
                { label: "Undo", action: "undo" },
                { label: "Reset", action: "reset" }
            ]

            delegate: Rectangle {
                required property var modelData

                Layout.preferredWidth: btnText.implicitWidth + 22
                Layout.preferredHeight: 28
                radius: Theme.radiusInner
                color: btnHover.hovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.width: 1
                border.color: Theme.border
                Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

                HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }

                Text {
                    id: btnText
                    anchors.centerIn: parent
                    text: modelData.label
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "tidy")
                            root.tidy()
                        else if (modelData.action === "undo")
                            root.undo()
                        else
                            root.reset()
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "Drag to move · corner to resize · right-click for sizes"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }
    }

    // ── Preview: the Control Center drawn at its real size ───────────────────
    Item {
        width: parent.width
        height: root.panelH

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.panelWidth
            height: root.panelH
            radius: Theme.radiusPanel
            color: Theme.background
            border.width: 1
            border.color: Theme.borderStrong

            Clock {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.panelPadding + (root.headerH - height) / 2
                timeSize: Theme.clockExpandedSize
                showDate: true
            }

            Item {
                x: Theme.panelPadding
                y: Theme.panelPadding + root.headerH + root.gap
                width: root.canvasW
                height: root.gridH
                clip: false

                Repeater {
                    model: Settings.controlLayout

                    delegate: ControlPreviewTile {
                        required property var modelData

                        entry: modelData
                        columns: root.columns
                        cellW: root.cellW
                        rowH: root.rowH
                        gap: root.gap
                        selected: root.selected === modelData.type

                        onSelectRequested: function (entry) { root.selected = entry.type }
                        onMoved: function (entry, col, row) { root.moveEntry(entry, col, row) }
                        onResized: function (entry, w, h) { root.resizeEntry(entry, w, h) }
                        onContextMenuRequested: function (entry, gx, gy) { root.openSizeMenu(entry, gx, gy) }
                        onRemoved: function (entry) { root.removeEntry(entry) }
                    }
                }

                // Right-click size menu.
                Rectangle {
                    visible: root.sizeMenu !== null
                    x: root.sizeMenu ? root.sizeMenu.x : 0
                    y: root.sizeMenu ? root.sizeMenu.y : 0
                    width: sizeRow.implicitWidth + 18
                    height: 40
                    radius: Theme.radiusInner
                    color: Theme.surfaceElevated
                    border.width: 1
                    border.color: Theme.borderStrong
                    z: 100

                    Row {
                        id: sizeRow
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: root.sizeMenu
                                ? ControlCatalog.sizesFor(root.sizeMenu.entry.type, root.columns)
                                : []

                            delegate: Rectangle {
                                required property var modelData

                                width: sizeLabel.implicitWidth + 16
                                height: 26
                                radius: 13
                                color: sizeHover.hovered ? Theme.surfaceHover : Theme.surface
                                border.width: 1
                                border.color: Theme.border

                                HoverHandler { id: sizeHover; cursorShape: Qt.PointingHandCursor }

                                Text {
                                    id: sizeLabel
                                    anchors.centerIn: parent
                                    text: modelData[0] + "\u00D7" + modelData[1]
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.subtitleSize
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.applySize(root.sizeMenu.entry, modelData[0], modelData[1])
                                        root.sizeMenu = null
                                    }
                                }
                            }
                        }
                    }
                }

                // Closes the size menu when you click elsewhere on the canvas.
                MouseArea {
                    anchors.fill: parent
                    visible: root.sizeMenu !== null
                    z: 90
                    onClicked: root.sizeMenu = null
                }
            }
        }
    }

    // ── Add a control ────────────────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: Theme.spaceSm

        Text {
            text: "Add a control"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sectionSize
            font.weight: Font.Medium
        }

        Flow {
            width: parent.width
            spacing: Theme.spaceSm

            Repeater {
                model: root.availableControls

                delegate: Rectangle {
                    id: addChip
                    required property string modelData

                    readonly property var info: ControlCatalog.info(modelData)

                    width: addRow.implicitWidth + 22
                    height: 32
                    radius: Theme.radiusInner
                    color: addHover.hovered ? Theme.surfaceHover : Theme.surfaceElevated
                    border.width: 1
                    border.color: Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

                    HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }

                    Row {
                        id: addRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: addChip.info ? addChip.info.icon : ""
                            color: Theme.accent
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: addChip.info ? addChip.info.title : ""
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (addChip.info ? addChip.info.defW : 1)
                                + "\u00D7" + (addChip.info ? addChip.info.defH : 1)
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.subtitleSize
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addControl(addChip.modelData)
                    }
                }
            }
        }
    }

    // ── Footer help ──────────────────────────────────────────────────────────
    Text {
        width: parent.width
        text: "Drag a control to move it, pull its corner to resize, right-click for every size it supports. With one selected: arrows nudge, [ and ] step through sizes, Delete removes."
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.subtitleSize
        wrapMode: Text.WordWrap
    }
}
