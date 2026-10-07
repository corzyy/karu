pragma Singleton

import QtQuick

/**
 * GameMode — the shell's lightweight "Game Mode" state.
 *
 * When `enabled` the shell drops its Dynamic Island look for a plain, edge-to-
 * edge top bar: the island spans the full screen width with square corners and
 * no hover lift, every shell animation is switched off (the motion tokens in
 * `Theme.qml` collapse to zero), the floating media companion is hidden and the
 * Wallpapers panel's Wallhaven "Browse" sub-tab is removed — so nothing rushes
 * to decode a thumbnail or run an effect while a game has the foreground.
 *
 * It is a singleton so `Theme` can read it for the motion/hover tokens and the
 * Control Center's tile, the Wallpapers panel and the shell can all share one
 * source of truth. The toggle is deliberate: the Control Center tile opens a
 * confirmation card (see `GameModePanel`) rather than flipping it directly.
 */
QtObject {
    id: root

    /// True while Game Mode is engaged.
    property bool enabled: false

    /// Explicit setter, so callers never have to reach for the property.
    function setEnabled(on: bool): void {
        root.enabled = on === true
    }

    /// Flip the mode.
    function toggle(): void {
        root.enabled = !root.enabled
    }
}
