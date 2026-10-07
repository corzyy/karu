import QtQuick

import "../../core/theme"
import "../../core/config"
import "../../core/config/ControlCatalog.js" as ControlCatalog
import "../../core/services"

/**
 * ControlCenterPanel — the expanded Control Center, laid out on the user's grid.
 *
 * It positions one live `ControlItem` per entry in `Settings.controlLayout` on a
 * `Settings.controlColumns`-wide grid of `Theme.toggleHeight` rows. The Settings
 * app's Control Center page is a drag-and-drop editor for that array (see
 * ui/settings/ControlLayoutEditor.qml), and both the editor and this panel draw
 * the very same `ControlItem`, so the preview is pixel-for-pixel the panel.
 */
Item {
    id: root

    /// Which detail dialog is currently open over the panel: "" (none),
    /// "bluetooth", "network", "brightness" or "gamemode".
    property string activeDetail: ""

    /// The screen the island lives on (injected by PanelStack); used to cap how
    /// tall the auto-growing Notifications tile may become.
    property var screen: null

    /// Bubble to shell.qml: open a tile detail dialog, morphing from the tile.
    signal detailRequested(string which, var tile)
    /// The Lock control asked to lock the session.
    signal lockRequested()
    /// The Now Playing control asked to open the media companion.
    signal mediaRequested()
    /// The System Tray control asked to open a tray item's own menu.
    signal trayMenuRequested(var item, var rect)
    /// The header's settings button asked to open the Settings app.
    signal settingsRequested()

    // ── Grid metrics ─────────────────────────────────────────────────────────
    readonly property int columns: Math.max(1, Settings.controlColumns)
    readonly property int gap: Theme.gap
    readonly property int rowH: Settings.toggleHeight
    readonly property real cellW: ControlCatalog.cellWidth(width, columns, gap)
    readonly property int gridTop: Theme.clockHeaderHeight + gap
    readonly property bool showBrightnessStatus: Brightness.status.length > 0

    // ── Auto-growing Notifications tile ──────────────────────────────────────
    // The Notifications control is unlike the rest: its tile grows to show the
    // whole list rather than clipping to its grid slot. `notifMeasure` below is
    // a hidden copy of the real card, used purely to measure how tall the list
    // wants to be; the tile and the island then grow (or shrink) to match.
    readonly property var notifEntry:
        ControlCatalog.entryFor(Settings.controlLayout, "notifications")
    /// Height of the Notifications tile at its authored grid size.
    readonly property real notifCellH: notifEntry
        ? notifEntry.h * rowH + (notifEntry.h - 1) * gap : 0
    /// Height the card needs for every notification. Held at the tile's base
    /// height until the panel has its real width, so a pre-layout measurement
    /// (width 0) can never spike the island on open.
    readonly property real notifNeed:
        (notifEntry && width > 0) ? notifMeasure.preferredHeight : 0
    /// Ceiling so the grown tile (and island) stays on screen: whatever vertical
    /// room is left after the space the other controls already claim.
    readonly property real notifMaxH: {
        if (!notifEntry)
            return 0
        var others = ControlCatalog.layoutHeight(Settings.controlLayout, rowH, gap) - notifCellH
        var avail = screen
            ? screen.height - Theme.topMargin - Theme.panelPadding * 2 - gridTop
            : notifNeed
        return Math.max(notifCellH, avail - others)
    }
    /// The tile's real height: never below its grid slot, never past the screen.
    readonly property real notifH: notifEntry
        ? Math.max(notifCellH, Math.min(notifNeed, notifMaxH)) : 0
    /// How much taller the tile is than its grid slot; controls below slide down
    /// by this so nothing is covered.
    readonly property real notifOverflow: Math.max(0, notifH - notifCellH)
    /// Row below which controls are pushed down when the tile grows.
    readonly property int notifBaseBottom: notifEntry ? notifEntry.row + notifEntry.h : 0

    readonly property int gridH:
        ControlCatalog.layoutHeight(Settings.controlLayout, rowH, gap) + notifOverflow

    implicitHeight: gridTop + gridH
        + (showBrightnessStatus ? Theme.subtitleSize + gap : 0)

    // Re-read (or discover) the monitors whenever the panel is (re)created and
    // whenever it comes back to the front, so access granted while another panel
    // was showing starts working without restarting the shell. The panel is kept
    // instantiated across panel switches (see PanelStack), so `visible` — not
    // `Component.onCompleted` — is what marks an open.
    Component.onCompleted: Brightness.ensure()
    onVisibleChanged: if (visible) Brightness.ensure()

    // A hidden copy of the Notifications card, measured at the tile's real width
    // so its `preferredHeight` matches what the live tile would need (text wraps
    // the same, icons size the same). Never shown.
    ControlNotificationsCard {
        id: notifMeasure
        visible: false
        width: root.notifEntry
            ? root.notifEntry.w * root.cellW + (root.notifEntry.w - 1) * root.gap
            : 0
    }

    // The clock is a shared island overlay (shell.qml); this slot reserves its
    // height so the overlay settles into the header while the panel is open,
    // and carries the Settings button on the clock's left.
    Item {
        width: parent.width
        height: Theme.clockHeaderHeight

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: width / 2
            color: settingsButtonMouse.containsMouse ? Theme.iconCircle : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            Text {
                anchors.centerIn: parent
                text: "\uF013" // nf-fa-cog
                // Match the status cluster's glyph tint.
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: Theme.toggleIconSize
            }

            MouseArea {
                id: settingsButtonMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsRequested()
            }
        }
    }

    Repeater {
        model: Settings.controlLayout

        delegate: ControlItem {
            required property var modelData

            readonly property var cell: ControlCatalog.rect(modelData, root.cellW, root.rowH, root.gap)
            readonly property bool isNotif: modelData.type === "notifications"

            // Controls below the Notifications tile slide down as it grows, so
            // its auto-expansion never covers them. Animated so they glide rather
            // than jump when a notification arrives or is dismissed.
            property real push: (root.notifEntry && !isNotif
                && modelData.row >= root.notifBaseBottom) ? root.notifOverflow : 0
            Behavior on push {
                enabled: !Theme.motionOff
                NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
            }

            x: cell.x
            y: root.gridTop + cell.y + push
            width: cell.width
            height: isNotif ? root.notifH : cell.height

            // The Notifications tile grows/shrinks as the list changes; ease it
            // so the reveal reads as the card expanding rather than snapping.
            Behavior on height {
                enabled: isNotif && !Theme.motionOff
                NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
            }

            type: modelData.type
            interactive: true
            activeDetail: root.activeDetail

            onDetailRequested: function (which, tile) { root.detailRequested(which, tile) }
            onLockRequested: root.lockRequested()
            onMediaRequested: root.mediaRequested()
            onTrayMenuRequested: function (item, rect) { root.trayMenuRequested(item, rect) }
        }
    }

    // Shown when ddcutil cannot reach the monitors, so the inert Display slider
    // has an explanation right where it is used.
    Text {
        x: 0
        y: root.gridTop + root.gridH + root.gap
        width: parent.width
        visible: root.showBrightnessStatus
        text: Brightness.status
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.subtitleSize
        wrapMode: Text.WordWrap
    }
}
