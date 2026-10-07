.pragma library

// ControlCatalog — the registry of every Control Center control plus the pure
// geometry helpers shared by the layout editor (ui/settings/ControlLayoutEditor)
// and the live panel (ui/panels/ControlCenterPanel).
//
// Plain data + math only — no QML references — so both the Settings app and the
// shell can import it. A layout is an ordered array of entries:
//
//   { type: "network", col: 0, row: 0, w: 3, h: 1 }
//
// `col`/`row` are zero-based grid cells and `w`/`h` spans in cells. The grid has
// `Settings.controlColumns` columns (4..9, 7 by default); a cell's pixel size is
// derived from the panel width so the editor preview and the real panel agree.

var defaultColumns = 7

// One record per control type. `kind` decides how the control is drawn (and
// which live behaviour it maps to); `defW`/`defH` are the default grid span.
var controls = {
    network:       { title: "Wi-Fi",          icon: "\uF0AC", kind: "toggle",        defW: 3, defH: 1 },
    bluetooth:     { title: "Bluetooth",      icon: "\uF293", kind: "toggle",        defW: 3, defH: 1 },
    focus:         { title: "Focus",          icon: "\uF186", kind: "toggle",        defW: 3, defH: 1 },
    gamemode:      { title: "Game Mode",      icon: "\uF11B", kind: "toggle",        defW: 3, defH: 1 },
    lock:          { title: "Lock",           icon: "\uF023", kind: "action",        defW: 1, defH: 1 },
    dnd:           { title: "Do Not Disturb", icon: "\uF186", kind: "small",         defW: 1, defH: 1 },
    sound:         { title: "Sound",          icon: "\uF028", kind: "slider",        defW: 7, defH: 1 },
    display:       { title: "Display",        icon: "\uF185", kind: "slider",        defW: 7, defH: 1 },
    notifications: { title: "Notifications",  icon: "\uF0F3", kind: "notifications", defW: 7, defH: 3 },
    nowplaying:    { title: "Now Playing",    icon: "\uF001", kind: "media",         defW: 3, defH: 2 },
    tray:          { title: "System Tray",    icon: "\uF0C9", kind: "tray",          defW: 4, defH: 1 }
}

/// Palette order for the "Add a control" list.
var order = [
    "network", "bluetooth", "focus", "gamemode", "lock", "dnd",
    "sound", "display", "notifications", "nowplaying", "tray"
]

/// The record for a control type, or null.
function info(type) {
    return controls[type] || null
}

/// The out-of-the-box layout: the classic Control Center arrangement.
function defaultLayout() {
    return [
        { type: "network",       col: 0, row: 0, w: 3, h: 1 },
        { type: "focus",         col: 3, row: 0, w: 3, h: 1 },
        { type: "lock",          col: 6, row: 0, w: 1, h: 1 },
        { type: "bluetooth",     col: 0, row: 1, w: 3, h: 1 },
        { type: "gamemode",      col: 3, row: 1, w: 3, h: 1 },
        { type: "dnd",           col: 6, row: 1, w: 1, h: 1 },
        { type: "sound",         col: 0, row: 2, w: 7, h: 1 },
        { type: "display",       col: 0, row: 3, w: 7, h: 1 },
        { type: "notifications", col: 0, row: 4, w: 7, h: 3 },
        { type: "tray",          col: 0, row: 7, w: 7, h: 1 }
    ]
}

/// Deep copy, so a commit never mutates the array currently bound in the UI.
function clone(layout) {
    var out = []
    if (!layout)
        return out
    for (var i = 0; i < layout.length; i++) {
        var e = layout[i]
        out.push({ type: e.type, col: e.col, row: e.row, w: e.w, h: e.h })
    }
    return out
}

/// True when the layout already holds a control of this type.
function has(layout, type) {
    for (var i = 0; i < layout.length; i++)
        if (layout[i].type === type)
            return true
    return false
}

/// The entry with a given type, or null.
function entryFor(layout, type) {
    for (var i = 0; i < layout.length; i++)
        if (layout[i].type === type)
            return layout[i]
    return null
}

/// Every size a control supports at the current column count, as [w, h] pairs,
/// de-duplicated and clamped to the grid. Used by the right-click size menu.
function sizesFor(type, columns) {
    var c = controls[type]
    if (!c)
        return [[1, 1]]
    var list
    switch (c.kind) {
        case "slider":
            // Wide bars (horizontal) and tall, narrow bars (vertical).
            list = [
                [columns, 1],
                [Math.max(2, Math.floor(columns * 0.6)), 1],
                [1, 3], [1, 2], [2, 3], [2, 2]
            ]
            break
        case "notifications":
            list = [[columns, 3], [columns, 2], [columns, 1], [Math.max(3, Math.floor(columns * 0.6)), 2]]
            break
        case "tray":
            // Always a single row of icons; full width reads best, but allow
            // narrower slots for a short tray.
            list = [[columns, 1], [Math.max(3, Math.floor(columns * 0.6)), 1], [3, 1], [2, 1]]
            break
        case "media":
            list = [[3, 2], [2, 2], [1, 2], [3, 1], [2, 1]]
            break
        case "small":
        case "action":
            list = [[1, 1]]
            break
        default:
            list = [[3, 1], [2, 1], [1, 1]]
    }
    var out = []
    for (var i = 0; i < list.length; i++) {
        var w = Math.max(1, Math.min(columns, list[i][0]))
        var h = Math.max(1, list[i][1])
        var dup = false
        for (var j = 0; j < out.length; j++) {
            if (out[j][0] === w && out[j][1] === h) { dup = true; break }
        }
        if (!dup)
            out.push([w, h])
    }
    return out
}

/// Pixel width of one grid cell for a content width.
function cellWidth(total, columns, gap) {
    if (columns < 1)
        columns = 1
    return Math.max(20, (total - gap * (columns - 1)) / columns)
}

/// Total pixel height of a layout (rows win).
function layoutHeight(layout, rowH, gap) {
    var maxRow = 0
    for (var i = 0; i < layout.length; i++) {
        var e = layout[i]
        if (e.row + e.h > maxRow)
            maxRow = e.row + e.h
    }
    return maxRow > 0 ? maxRow * rowH + (maxRow - 1) * gap : 0
}

/// The pixel rectangle of a layout entry on the grid.
function rect(entry, cellW, rowH, gap) {
    return {
        x: entry.col * (cellW + gap),
        y: entry.row * (rowH + gap),
        width: entry.w * cellW + (entry.w - 1) * gap,
        height: entry.h * rowH + (entry.h - 1) * gap
    }
}

/// Convert a pixel position back to the nearest grid cell.
function cellAt(px, cellPx, gap) {
    return Math.round(px / (cellPx + gap))
}

/// Convert a pixel extent back to a span in cells (at least one).
function spanAt(px, cellPx, gap) {
    return Math.max(1, Math.round((px + gap) / (cellPx + gap)))
}

/// Do two entries share a cell?
function overlaps(a, b) {
    return !(a.col + a.w <= b.col || b.col + b.w <= a.col
        || a.row + a.h <= b.row || b.row + b.h <= a.row)
}

/// Can `entry` sit here without colliding with the rest of the layout? The entry
/// whose type matches `ignoreType` is skipped (you may overlap yourself).
function fits(layout, entry, ignoreType) {
    if (entry.col < 0 || entry.row < 0)
        return false
    for (var i = 0; i < layout.length; i++) {
        var o = layout[i]
        if (o.type === ignoreType)
            continue
        if (overlaps(entry, o))
            return false
    }
    return true
}

/// The first free slot big enough for a w x h control, scanning top-to-bottom.
function freeSlot(layout, w, h, columns) {
    w = Math.max(1, Math.min(columns, w))
    h = Math.max(1, h)
    for (var row = 0; row < 500; row++) {
        for (var col = 0; col + w <= columns; col++) {
            if (fits(layout, { col: col, row: row, w: w, h: h }, null))
                return { col: col, row: row, w: w, h: h }
        }
    }
    return { col: 0, row: 0, w: w, h: h }
}

/// Shelf-pack the controls in their current order, top-to-bottom, left-to-right,
/// dropping each into the first gap it fits. This is the "Tidy" action.
function tidy(layout, columns) {
    var out = []
    for (var i = 0; i < layout.length; i++) {
        var e = layout[i]
        var w = Math.max(1, Math.min(columns, e.w))
        var h = Math.max(1, e.h)
        var slot = freeSlot(out, w, h, columns)
        out.push({ type: e.type, col: slot.col, row: slot.row, w: w, h: h })
    }
    return out
}

/// Does any entry in `list` collide with `e`?
function overlapsAny(list, e) {
    for (var i = 0; i < list.length; i++)
        if (overlaps(list[i], e))
            return true
    return false
}

/// Force a strictly non-overlapping layout, in place, and return it.
///
/// When `movedType` is given that control is pinned exactly where it was
/// dropped and every control it covers is pushed straight down; the rest are
/// then packed in their existing order, each nudged down only as far as it needs
/// to clear the ones already placed. This is what makes a drag feel like the
/// iOS home screen instead of letting tiles pile on top of one another.
function settle(layout, columns, movedType) {
    var ordered = []
    if (movedType) {
        var moved = entryFor(layout, movedType)
        if (moved)
            ordered.push(moved)
    }
    for (var i = 0; i < layout.length; i++) {
        if (layout[i].type !== movedType)
            ordered.push(layout[i])
    }

    var placed = []
    for (var j = 0; j < ordered.length; j++) {
        var e = ordered[j]
        e.w = Math.max(1, Math.min(columns, e.w))
        e.h = Math.max(1, e.h)
        e.col = Math.max(0, Math.min(columns - e.w, e.col))
        e.row = Math.max(0, e.row)
        var guard = 0
        while (overlapsAny(placed, e) && guard++ < 500)
            e.row++
        placed.push(e)
    }
    return layout
}
