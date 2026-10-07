import QtQuick

import "../../core/theme"
import "../widgets"

/**
 * DetailCard — the shared "tile detail" surface.
 *
 * A compact card that grows out of the tile it was opened from and shrinks back
 * into it. The tile hands over its own geometry *and its own look* — corner
 * radius, fill and border colour — through `openFrom()`, so the card starts life
 * as an exact, pixel-aligned copy of the tile and then morphs into the floating
 * dialog: same shape, same colour, one continuous motion.
 *
 * The card stays fully opaque for the whole trip (opening *and* closing) and
 * only disappears on the frame it settles onto the tile, so the tile never shows
 * through a half-faded card and neither direction cross-fades. Its contents are
 * held back until the card has opened out (`Theme.detailContentDelay`), so they
 * are not clipped by the still-small shape while it travels.
 *
 * The Bluetooth / Wi-Fi / LAN dialogs all share it, so every tile detail moves
 * identically (same primitives and timing as the island itself).
 *
 * `kind` selects the dialog: "bluetooth", "network" (merged Wi-Fi + LAN),
 * "brightness" or "gamemode"; "" is closed.
 */
Rectangle {
    id: root

    property string kind: ""
    property rect targetRect: Qt.rect(0, 0, 0, 0)

    /// The tile this card grows out of, in scene coordinates, plus the look it
    /// borrows from that tile for the closed state (see `openFrom`). The card's
    /// parent is the island, so `originSceneRect` is mapped into island
    /// coordinates below.
    property rect originSceneRect: Qt.rect(0, 0, 0, 0)
    property real originRadius: Theme.radiusCard
    property color originFill: Theme.surface
    property color originBorder: Theme.border

    readonly property rect originRect: parent
        ? parent.mapFromItem(null, originSceneRect.x, originSceneRect.y,
                             originSceneRect.width, originSceneRect.height)
        : Qt.rect(0, 0, 0, 0)

    /// While true the geometry Behaviors are bypassed so `openFrom()` can jump
    /// the (invisible) card onto a new tile without animating across the panel.
    property bool snap: false

    /// The active dialog asked to close (its back chevron).
    signal closeRequested()

    readonly property bool open: kind !== ""

    /// Grow the card out of `tile` — an object carrying the tile's scene
    /// rectangle (`x`/`y`/`width`/`height`), corner `radius` and `fill` /
    /// `border` colours (see `ToggleButton.tileGeometry()`). The invisible card is
    /// snapped to that geometry first, so changing `kind` afterwards morphs out
    /// of the right tile.
    function openFrom(tile) {
        snap = true
        originSceneRect = Qt.rect(tile.x, tile.y, tile.width, tile.height)
        originRadius = tile.radius
        originFill = tile.fill
        originBorder = tile.border
        snap = false
    }

    // ── Morph geometry ───────────────────────────────────────────────────────
    // Closed, the card sits exactly on its tile, sharing its radius and colour;
    // open, it is the centred dialog. Every channel animates on the island's own
    // curve and duration, so the card and the surface under it move as one.
    x: open ? targetRect.x : originRect.x
    y: open ? targetRect.y : originRect.y
    width: open ? targetRect.width : originRect.width
    height: open ? targetRect.height : originRect.height
    radius: open ? Theme.radiusPanel : originRadius

    color: open ? Theme.backgroundSolid : originFill
    border.width: 1
    border.color: open ? Theme.border : originBorder

    // Opaque through the entire morph — including the shrink home — then gone
    // once the spring has settled onto the tile. Set imperatively (rather than
    // bound to `open`) so the opening frame is already opaque and the close keeps
    // it until `closeSettle` fires.
    opacity: 0
    visible: opacity > 0.01
    enabled: open
    clip: true
    // Open, the card floats over the panel. Closing, it drops behind the panel
    // content so the tile it is shrinking onto (already un-suppressed) shows
    // its real content the whole way home, instead of leaving a blank pill
    // covering it until the card vanishes.
    z: open ? 1 : -1

    // Morph geometry on the same physics spring as the island, so the card and
    // the surface under it move as one. `snap` (used by `openFrom()` to jump the
    // invisible card onto a new tile) and Game Mode / Reduce Motion both bypass
    // the Behavior for an instant assignment.
    Behavior on x {
        enabled: !root.snap && !Theme.motionOff
        SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
    }
    Behavior on y {
        enabled: !root.snap && !Theme.motionOff
        SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
    }
    Behavior on width {
        enabled: !root.snap && !Theme.motionOff
        SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
    }
    Behavior on height {
        enabled: !root.snap && !Theme.motionOff
        SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
    }
    Behavior on radius {
        enabled: !root.snap && !Theme.motionOff
        SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
    }
    Behavior on color { enabled: !root.snap; ColorAnimation { duration: Theme.expandDuration; easing.type: Theme.easeOut } }
    Behavior on border.color { enabled: !root.snap; ColorAnimation { duration: Theme.expandDuration; easing.type: Theme.easeOut } }

    // One place drives the visibility state machine. Opening cancels any
    // in-flight close and schedules the contents; closing drops the contents at
    // once — they must not linger over the shrinking surface — and keeps the
    // card opaque until it has shrunk back onto the tile.
    onOpenChanged: {
        if (open) {
            _closing = false
            closeSettle.stop()
            opacity = 1
            contentTimer.restart()
        } else {
            // Arm the close *before* tearing the contents down. The card must
            // stay opaque while it springs home, so it is hidden only once the
            // geometry stops moving; if dropping the contents threw (a stale
            // reveal row can), doing it first would leave the card stranded on
            // top of its tile, showing nothing.
            _closing = true
            closeSettle.restart()
            contentTimer.stop()
            loader.opacity = 0
            reveal.stop()
        }
    }

    // True while the card is shrinking back into its tile; each geometry change
    // then re-arms the settle timer, so it fires only after the spring has come
    // to rest.
    property bool _closing: false
    onXChanged: if (_closing) closeSettle.restart()
    onYChanged: if (_closing) closeSettle.restart()
    onWidthChanged: if (_closing) closeSettle.restart()
    onHeightChanged: if (_closing) closeSettle.restart()
    onRadiusChanged: if (_closing) closeSettle.restart()

    // The tile dialog's contents cascade in (the shared reveal) once the card
    // has opened out. There is deliberately no matching fade-out: closing drops
    // them instantly so only the surface morphs back into the tile.
    ContentReveal { id: reveal }

    Timer {
        id: contentTimer
        interval: Theme.detailContentDelay
        onTriggered: {
            loader.opacity = 1
            reveal.play(loader.item)
        }
    }

    Timer {
        id: closeSettle
        // A short quiet beat after the last geometry change, i.e. once the spring
        // has settled onto the tile.
        interval: 70
        onTriggered: root.opacity = 0
    }

    // Swallow clicks on empty card space so they never reach the island toggle.
    MouseArea { anchors.fill: parent }

    Loader {
        id: loader
        anchors.fill: parent
        anchors.margins: Theme.cardPadding
        // Revealed by `contentTimer` (set to 1, then the rows cascade via
        // `reveal`) and hidden instantly on close.
        opacity: 0

        sourceComponent: root.kind === "bluetooth" ? bluetoothPanel
                       : root.kind === "network" ? networkPanel
                       : root.kind === "brightness" ? brightnessPanel
                       : root.kind === "gamemode" ? gameModePanel
                       : null
    }

    Connections {
        target: loader.item
        function onCloseRequested() { root.closeRequested() }
    }

    Component { id: bluetoothPanel; BluetoothPanel {} }
    Component { id: networkPanel;   NetworkPanel {} }
    Component { id: brightnessPanel; BrightnessPanel {} }
    Component { id: gameModePanel;  GameModePanel {} }
}
