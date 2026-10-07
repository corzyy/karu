// shell.qml — entry point for the Dynamic Island bar.
//
// Launch:
//   quickshell -c /path/to/karu          (directory containing this file)
//
// The window is a Wayland layer-shell surface anchored to the top edge and
// stretched across the full screen width so we can reliably centre the island.
// A `Region` mask limits clickable input to just the island, so the rest of the
// bar strip passes clicks through to windows underneath.
//
// Collapsed layout: workspaces (left) · clock (centre) · status icons (right).
// Expanded layout:  one of the separated panels, picked from the panel switcher —
//                   Control Center / Themes / Wallpapers / Session / Apps.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire

import "core/theme"
import "core/config"
import "core/services"
import "ui/bar"
import "ui/lock"
import "ui/media"
import "ui/notifications"
import "ui/panels"
import "ui/settings"
import "ui/widgets"

PanelWindow {
    id: panel

    // ── Layer-shell placement ────────────────────────────────────────────────
    anchors {
        top: true
        left: true
        right: true
    }
    margins.top: (panel.gameMode || Settings.notchMode) ? 0 : Theme.topMargin

    // ── Monitor placement ────────────────────────────────────────────────────
    // Pin the island to the output named in Theme.barMonitor (DP-1 by default)
    // instead of letting Quickshell pick a default screen. This is a live
    // binding over Quickshell.screens, which updates as monitors connect and
    // disconnect: if DP-1 is absent we fall back to the first available screen,
    // and as soon as DP-1 (re)appears the bar snaps back to it. That makes the
    // placement stick across shell restarts and hotplug events.
    //
    // NB: never cache the ShellScreen object — a disconnected monitor's object
    // goes dangling and does not revive, so always look it up from the live list.
    screen: {
        var wanted = Theme.barMonitor
        var list = Quickshell.screens
        if (wanted && wanted.length > 0) {
            for (var i = 0; i < list.length; i++)
                if (list[i].name === wanted)
                    return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    // Reserve a strip at the top so maximised windows do not slide under the
    // collapsed pill. (Either 1 or 3 anchors are required for this to apply.)
    // Game Mode sits flush at the top edge, so it reserves exactly the bar
    // height rather than the pill's height plus its top margin.
    exclusiveZone: (panel.gameMode || Settings.notchMode)
        ? Theme.collapsedHeight : Theme.exclusiveZone
    exclusionMode: ExclusionMode.Normal

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:dynamicIsland"
    // The Themes and Wallpapers carousels are driven with ←/→ (plus Enter to
    // apply), the App launcher's search field needs typing, the Session panel is
    // driven with ←/→ + Enter, and the overview with Alt+Tab (to toggle it
    // closed) plus Tab/Enter/Esc, so the surface grabs keyboard input while one
    // of those panels is open; any other panel (or collapsing) hands it straight
    // back to the focused window. Wallpapers only asks for the keyboard on its
    // keyboard-driven Local tab — its Browse tab is click-only.
    WlrLayershell.keyboardFocus: (panel.expanded
        && (stack.current === "themes" || stack.current === "apps"
            || stack.current === "session" || stack.current === "overview"
            || stack.current === "switcher"
            || stack.current === "polkit"
            || stack.current === "settings"
            || (stack.current === "wallpapers" && stack.wantsKeyboard)))
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    color: "transparent"

    // Height of the two islands at rest (the pill, or the media card when it is
    // opened).
    readonly property int stripHeight: Math.max(island.height, media.height)
    // True while the main panel or the media card is showing. (The overview is a
    // panel too, so `expanded` already covers it.)
    readonly property bool anyOpen: panel.expanded || media.open

    // Frosted glass for an open panel (Settings ▸ Appearance ▸ Panel blur).
    // Only the real expanded panels — Control Center, launcher, themes, … — get
    // it; the collapsed pill and the media island keep their flat fill.
    readonly property bool glass: Theme.panelBlur && panel.expanded

    // While something is open the surface grows to cover the screen so a click
    // anywhere outside the islands can dismiss it; at rest it hugs the islands.
    // The surface keeps a stable, full-screen height and the islands animate
    // inside it. Following `island.height` here would resize the layer surface on
    // every animation frame, which makes the compositor smear the previous
    // buffer — the ghost/trail seen while a panel closes. Input is still limited
    // to the islands by the mask below.
    implicitHeight: panel.screen ? panel.screen.height : panel.stripHeight

    // At rest only the islands are clickable and the rest passes through. While
    // open the whole surface is clickable, so a click outside the islands lands
    // on the backdrop below.
    Region {
        id: islandsMask
        Region { item: island }
        Region { item: media }
        Region { item: notificationStack }
    }
    mask: panel.anyOpen ? null : islandsMask

    // ── Backdrop blur (Settings ▸ Appearance ▸ Panel blur) ───────────────────
    // Ask the compositor to blur what is behind an open panel through the
    // ext-background-effect-v1 protocol, so the panel reads as a frosted glass
    // sheet over the desktop. The region follows the panel's rounded corners
    // (and, in Notch Mode, the bottom rounding of the flush slab). The panel
    // drops its own fill to transparent and paints a dark glass gradient over
    // the blur (PanelGlass / the notch silhouette). Only expanded panels do
    // this — the collapsed pill and the media island are left alone.
    BackgroundEffect.blurRegion: panel.glass ? blurRegion : null
    Region {
        id: blurRegion
        Region {
            x: island.x
            y: island.y
            width: island.width
            height: island.height
            topLeftRadius: island.topLeftRadius
            topRightRadius: island.topRightRadius
            bottomLeftRadius: island.bottomLeftRadius
            bottomRightRadius: island.bottomRightRadius
        }
    }

    /// Close every open island (main panel, media card and any tile detail).
    /// The overview is a panel, so `expanded = false` closes it too.
    function dismissAll() {
        // A pending polkit request owns the island until it is answered, so a
        // stray click outside must not hide the prompt (it has its own Cancel).
        if (panel.polkitActive)
            return
        panel.expanded = false
        media.open = false
        panel.detailPanel = ""
        panel.trayMenuItem = null
    }

    /// Bring the theme manager and wallpaper catalogue to life at startup. This
    /// re-applies the theme chosen last session (through Matugen) and begins
    /// scanning for wallpapers, so the Themes / Wallpapers tabs are ready before
    /// they are opened.
    Component.onCompleted: {
        Themes.restore()
        Notifications.doNotDisturb = Settings.doNotDisturb
        if (volumeAudio)
            volumeArmTimer.restart()
    }

    // Keep the Settings app's Do Not Disturb switch and the notification hub's
    // flag in step, whichever side changes first. Assigning an equal value is a
    // no-op in QML, so this cannot oscillate.
    Connections {
        target: Settings
        function onDoNotDisturbChanged() { Notifications.doNotDisturb = Settings.doNotDisturb }
    }
    Connections {
        target: Notifications
        function onDoNotDisturbChanged() { Settings.set("doNotDisturb", Notifications.doNotDisturb) }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  IPC — driven by the `karu` command (see ~/.local/bin/karu)
    // ════════════════════════════════════════════════════════════════════════
    //  `qs ipc -p <config> call karu <fn> [arg]` reaches the running shell.
    //  Targets are the same names PanelStack understands, plus friendly
    //  aliases ("launcher" -> "apps", "power" -> "session", …).
    IpcHandler {
        target: "karu"

        function panelName(name: string): string {
            switch (String(name).toLowerCase()) {
                case "control":
                case "center":
                case "controlcenter":  return "control"
                case "theme":
                case "themes":         return "themes"
                case "wallpaper":
                case "wallpapers":     return "wallpapers"
                case "session":
                case "power":          return "session"
                case "app":
                case "apps":
                case "launcher":
                case "launch":         return "apps"
                default:               return ""
            }
        }

        /// Expand the island on the named panel ("launch themes", etc.).
        function open(name: string): void {
            var p = panelName(name)
            if (p.length === 0)
                return
            stack.current = p
            panel.expanded = true
        }

        /// Open the panel, or collapse if it is already showing.
        function toggle(name: string): void {
            var p = panelName(name)
            if (p.length === 0)
                return
            if (panel.expanded && stack.current === p)
                panel.expanded = false
            else
                open(name)
        }

        /// Collapse the island back to the pill without quitting.
        function collapse(): void {
            panel.expanded = false
        }

        /// Show / hide the Settings app — as a floating window, or docked as an
        /// island panel when Settings ▸ System ▸ Docked settings is on. Optional
        /// arg: "open" / "close"; anything else (including none) toggles.
        function settings(arg: string): void {
            var a = String(arg).toLowerCase()
            if (a === "open" || a === "show")
                panel.openSettings()
            else if (a === "close" || a === "hide")
                panel.closeSettings()
            else
                panel.toggleSettings()
        }

        /// Report whether the Settings app is showing (either way).
        function settingsstate(): string {
            return panel.settingsShowing ? "open" : "closed"
        }

        /// Turn Game Mode on / off. Optional arg: "on" / "off" ("enable" /
        /// "disable" also work); anything else (including none) toggles. This
        /// bypasses the Control Center prompt for scripting and keybinds.
        function gamemode(arg: string): void {
            var a = String(arg).toLowerCase()
            if (a === "on" || a === "enable" || a === "true")
                GameMode.setEnabled(true)
            else if (a === "off" || a === "disable" || a === "false")
                GameMode.setEnabled(false)
            else
                GameMode.toggle()
        }

        /// Report the Game Mode state, e.g. "on" / "off".
        function gamemodestate(): string {
            return GameMode.enabled ? "on" : "off"
        }

        /// Show / hide the Alt+Tab window overview. Optional arg: "open" /
        /// "close"; anything else (including none) toggles.
        function overview(arg: string): void {
            var a = String(arg).toLowerCase()
            if (a === "open" || a === "show")
                panel.setOverview(true)
            else if (a === "close" || a === "hide")
                panel.setOverview(false)
            else
                panel.setOverview(!panel.overviewOpen)
        }

        /// Report whether the overview is showing (e.g. "open" / "closed").
        function overviewstate(): string {
            return panel.overviewOpen ? "open" : "closed"
        }

        /// Lock the session with the Karu lockscreen.
        function lock(): void {
            engageLock()
        }

        /// Release the session lock (emergency / scripting).
        function unlock(): void {
            sessionLock.locked = false
        }

        /// Report the lock state, e.g. "locked secure" / "unlocked insecure".
        function lockstate(): string {
            return (sessionLock.locked ? "locked" : "unlocked")
                + (sessionLock.secure ? " secure" : " insecure")
        }
    }

    /// Bring up the lockscreen: clear any previous attempt, collapse the bar and
    /// engage the session lock.
    function engageLock() {
        lockContext.reset()
        panel.expanded = false
        sessionLock.locked = true
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Session lock — macOS-style lockscreen (ui/lock/Lockscreen.qml)
    // ════════════════════════════════════════════════════════════════════════
    //  Opt-in: `locked` is only set by the IPC `lock()` method (from a keybind,
    //  `karu lock`, or the Session panel's Lock button), never at startup, so
    //  editing files can never trap the session behind an unfinished lock.
    //  A successful PAM password clears it again.
    LockContext {
        id: lockContext
    }

    // The lockscreen fades its clock and login box out on a successful unlock;
    // `LockContext.unlocked()` merely starts that dismissal. Release the session
    // lock when the surface reports the animation finished (`exitDone` below),
    // with this timer as a watchdog so a missing signal can never leave the
    // session stuck behind the lock.
    Timer {
        id: unlockRelease
        interval: Theme.lockLeaveDuration + 150
        onTriggered: sessionLock.locked = false
    }
    Connections {
        target: lockContext
        function onUnlocked() { unlockRelease.restart() }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            Lockscreen {
                anchors.fill: parent
                context: lockContext
                // The surface is created once per monitor; hand its screen to
                // the Lockscreen so only the main one draws the clock/login box.
                surfaceScreen: screen
                // Hold the lock until the dismissal has actually played.
                onExitDone: {
                    unlockRelease.stop()
                    sessionLock.locked = false
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Expand / collapse state machine
    // ────────────────────────────────────────────────────────────────────────
    //  The island opens on a click, never on hover.
    //
    //    expanded – target size of the island. Animating width/height on
    //               `island` between the collapsed and expanded values is what
    //               produces the grow-from-centre-top motion.
    //
    //  Transitions:
    //    click (collapsed) -> open, landing on the Control Center
    //    click (expanded)  -> collapse
    //    IPC open/toggle   -> drive `expanded` directly (see the IpcHandler)
    //
    //  Hovering only makes the pill react: a small scale-up and a brighter
    //  border (the `hover` HoverHandler in the island below).
    // ════════════════════════════════════════════════════════════════════════
    property bool expanded: false

    /// True while a polkit authentication request is pending. The island morphs
    /// into the authentication card (the "polkit" panel) and is held open — the
    /// backdrop, the island's click-to-collapse and the media companion are all
    /// suppressed so the prompt cannot be dismissed by accident. See
    /// core/services/Polkit.qml and ui/panels/PolkitPanel.qml.
    readonly property bool polkitActive: Polkit.active

    // A polkit request grows the island into its prompt; when it finishes
    // (success, failure or cancel) the island collapses again. This is the only
    // way the "polkit" panel is opened or closed.
    Connections {
        target: Polkit
        function onRequestStarted() {
            media.open = false
            stack.current = "polkit"
            panel.expanded = true
        }
        function onRequestEnded() {
            if (stack.current === "polkit")
                panel.expanded = false
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Volume OSD — the island morphs into the volume panel
    // ════════════════════════════════════════════════════════════════════════
    //  When the default sink's volume or mute changes (hardware/media keys, a
    //  keyboard volume slider, the status-icon wheel, …) the island grows into
    //  the "volume" panel exactly like the Control Center, holds for
    //  `Theme.volumeOsdTimeout`, then collapses back into the pill. A change is
    //  ignored while another surface owns the top of the screen (an expanded
    //  panel, the media card, the lock), so the Control Center's own Sound
    //  slider never pops it.
    //
    //  We watch the sink directly, so the OSD appears for whatever actually
    //  changed it and needs no keybind wiring of its own. `armed` suppresses the
    //  first value a sink reports on startup / hotplug — only genuine *changes*
    //  show the OSD.
    property bool volumeOsdOpen: false

    /// True while the island is showing the volume panel. Guarded against
    /// `stack.current` so a stale `volumeOsdOpen` (e.g. the OSD was dismissed by
    /// opening another panel) can never make it re-appear or mis-suppress.
    readonly property bool volumeOsdActive: volumeOsdOpen && stack.current === "volume"

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    readonly property var volumeSink: Pipewire.defaultAudioSink
    readonly property var volumeAudio: (volumeSink && volumeSink.audio) ? volumeSink.audio : null
    readonly property real volumeLevel: volumeAudio ? volumeAudio.volume : 0
    readonly property bool volumeMuted: volumeAudio ? volumeAudio.muted : false

    property bool volumeArmed: false
    property real volumeLast: 0
    property bool volumeLastMuted: false

    Timer {
        id: volumeArmTimer
        interval: 400
        onTriggered: {
            panel.volumeLast = panel.volumeLevel
            panel.volumeLastMuted = panel.volumeMuted
            panel.volumeArmed = true
        }
    }

    // A new default sink (hotplug, PipeWire start): re-baseline and re-arm.
    onVolumeAudioChanged: {
        panel.volumeArmed = false
        if (panel.volumeAudio) {
            panel.volumeLast = panel.volumeLevel
            panel.volumeLastMuted = panel.volumeMuted
            volumeArmTimer.restart()
        }
    }

    onVolumeLevelChanged: {
        if (!volumeArmed)
            return
        if (Math.abs(volumeLevel - volumeLast) < 0.0005)
            return
        volumeLast = volumeLevel
        showVolumeOsd()
    }
    onVolumeMutedChanged: {
        if (!volumeArmed)
            return
        if (volumeMuted === volumeLastMuted)
            return
        volumeLastMuted = volumeMuted
        showVolumeOsd()
    }

    /// Grow the island into the volume panel (or keep it open and restart its
    /// timer if it is already showing).
    function showVolumeOsd() {
        if (!Settings.volumeOsd)
            return
        if (media.open || sessionLock.locked)
            return
        // Another panel is open — it owns the island, so leave it alone.
        if (panel.expanded && !panel.volumeOsdActive)
            return
        panel.volumeOsdOpen = true
        stack.current = "volume"
        panel.expanded = true
        volumeOsdTimer.restart()
    }

    // Collapse the OSD back into the pill after the timeout. Only collapse if
    // the volume panel is still what the island is showing, so opening another
    // panel in the meantime is not undone.
    Timer {
        id: volumeOsdTimer
        interval: Math.max(500, Settings.volumeOsdTimeout * 1000)
        onTriggered: {
            panel.volumeOsdOpen = false
            if (stack.current === "volume")
                panel.expanded = false
        }
    }

    /// True while the standalone Settings *window* is showing. Only used while
    /// `Settings.settingsDocked` is off; driven by the IPC handler and the
    /// window's own close button (SUPER + comma by default).
    property bool settingsOpen: false

    /// True while the Settings app is showing at all — as the floating window,
    /// or as the island panel when `Settings.settingsDocked` is on.
    readonly property bool settingsShowing: Settings.settingsDocked
        ? (panel.expanded && stack.current === "settings")
        : panel.settingsOpen

    /// Open the Settings app the way `Settings.settingsDocked` asks: docked as
    /// an island panel, or as the standalone floating window.
    function openSettings() {
        if (Settings.settingsDocked) {
            media.open = false
            stack.current = "settings"
            panel.expanded = true
        } else {
            panel.settingsOpen = true
        }
    }

    /// Close the Settings app whichever way it is showing.
    function closeSettings() {
        panel.settingsOpen = false
        if (panel.expanded && stack.current === "settings")
            panel.expanded = false
    }

    /// Open or close the Settings app depending on its current state.
    function toggleSettings() {
        if (panel.settingsShowing)
            panel.closeSettings()
        else
            panel.openSettings()
    }

    // Toggling Docked mode from inside the app hands it over live: a floating
    // window becomes the island panel (and vice versa) rather than vanishing.
    Connections {
        target: Settings
        function onSettingsDockedChanged() {
            if (Settings.settingsDocked && panel.settingsOpen) {
                panel.settingsOpen = false
                panel.openSettings()
            } else if (!Settings.settingsDocked
                    && panel.expanded && stack.current === "settings") {
                panel.expanded = false
                panel.openSettings()
            }
        }
    }

    /// True while Game Mode is engaged (see core/theme/GameMode.qml). At rest the
    /// island turns into a flat, edge-to-edge top bar; the shell also runs
    /// without motion and hides the floating media companion.
    readonly property bool gameMode: Theme.gameMode

    /// Which tile detail dialog is open over the Control Center: "" (none),
    /// "bluetooth", "network" or "brightness". Owned here so the panel stack,
    /// the overlay and dismissal share one source of truth.
    property string detailPanel: ""

    /// The system tray item whose own menu is open over the Control Center
    /// (null when none) and the scene rectangle of the icon it hangs from. The
    /// themed menu itself is ui/widgets/TrayMenu.qml, placed at the bottom of
    /// this file so it floats outside the island's clip.
    property var trayMenuItem: null
    property rect trayMenuRect: Qt.rect(0, 0, 0, 0)

    /// Open a tray item's own menu, hanging from its icon. The item is assigned
    /// last so the menu opens with `trayMenuRect` already in place.
    function openTrayMenu(item, rect) {
        panel.trayMenuItem = null
        panel.trayMenuRect = Qt.rect(rect.x, rect.y, rect.width, rect.height)
        panel.trayMenuItem = item
    }

    // Opening any surface closes the others: the two islands are mutually
    // exclusive, and a tile detail lives inside the main island, so it must go
    // when the island collapses. (The media side does the reverse below.)
    onExpandedChanged: {
        if (expanded)
            media.open = false
        else {
            detailPanel = ""
            trayMenuItem = null
        }
    }

    /// The panel the island showed before the panel menu (the switcher) opened,
    /// so the menu can highlight where you were. Kept in step with the stack.
    property string switcherFrom: "control"

    Connections {
        target: stack
        function onCurrentChanged() {
            if (stack.current !== "switcher")
                panel.switcherFrom = stack.current
        }
    }

    /// Right-click the island: grow it into the panel menu — a
    /// Session-panel-style list of every panel — or collapse it if the menu is
    /// already showing.
    function openSwitcher() {
        if (panel.expanded && stack.current === "switcher") {
            panel.expanded = false
            return
        }
        media.open = false
        stack.current = "switcher"
        panel.expanded = true
    }

    /// A tile in the panel menu was chosen: switch straight to that panel. The
    /// overview needs its Hyprland state refreshed, so it goes through
    /// `setOverview` rather than a plain stack switch.
    function choosePanel(key) {
        if (key === "overview") {
            panel.setOverview(true)
            return
        }
        stack.current = key
        panel.expanded = true
    }

    /// True while the overview panel is what the island is showing. The overview
    /// is an ordinary panel, so this is just derived from the shared panel state.
    readonly property bool overviewOpen: panel.expanded && stack.current === "overview"

    /// Width of the island for the current expanded panel. The Control Center
    /// uses its own `Theme.controlPanelWidth`; other panels use the standard
    /// `Theme.expandedWidth`, the Themes and Wallpapers carousels use the wider
    /// `Theme.expandedWidthWide`, the overview grows to fit its columns and the
    /// volume OSD is a deliberately short bar.
    readonly property int panelWidth: stack.current === "overview" ? Math.round(panel.overviewPanelWidth)
        : (stack.current === "volume" ? Theme.volumeOsdWidth
        : (stack.current === "settings" ? Theme.settingsPanelWidth
        : (stack.current === "control" ? Theme.controlPanelWidth
        : ((stack.current === "themes" || stack.current === "wallpapers")
            ? Theme.expandedWidthWide : Theme.expandedWidth))))

    /// Width of the island while the overview panel is open: as wide as the
    /// columns need (so no workspace is clipped off the end), within the screen.
    readonly property real overviewPanelWidth: {
        var maxWidth = (panel.screen ? panel.screen.width : Theme.overviewWidth) - Theme.spaceXl * 2
        var wanted = stack.preferredContentWidth + Theme.panelPadding * 2
        return Math.max(Theme.expandedWidth, Math.min(wanted, maxWidth))
    }

    /// Click-to-toggle. Bound to the island's background MouseArea and reused
    /// by the IPC handler.
    function toggleExpanded() {
        if (panel.expanded)
            panel.expanded = false
        else {
            if (stack.current !== "control")
                stack.current = "control"
            panel.expanded = true
        }
    }

    // ── Overview actions ─────────────────────────────────────────────────────
    /// Show or hide the overview. It is just another island panel: opening it
    /// selects it and expands the island, which then morphs out of the pill the
    /// same way the Control Center does.
    function setOverview(on) {
        if (on) {
            // The mirror is drawn from `lastIpcObject` (window `at` / `size`),
            // which is not pushed live, so pull fresh compositor state each time
            // the overview opens. Refresh first, then show.
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            media.open = false
            stack.current = "overview"
            panel.expanded = true
        } else if (stack.current === "overview") {
            panel.expanded = false
        }
    }

    /// Focus the window behind an overview card. Hyprland 0.55+ in Lua mode
    /// rejects the legacy dispatcher, so the Lua `hl.dsp.focus` form is used
    /// there (same guard as WorkspaceIndicator.focusWorkspace). Quickshell's
    /// `address` has no `0x` prefix, which Hyprland's selector requires.
    function focusToplevel(tl) {
        if (!tl)
            return
        var sel = "address:" + panel.hexAddress(tl)
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ window = '" + sel + "' })")
        else
            Hyprland.dispatch("focuswindow " + sel)
    }

    /// Close the window behind an overview card's × button.
    function closeToplevel(tl) {
        if (!tl)
            return
        var sel = "address:" + panel.hexAddress(tl)
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.window.close({ window = '" + sel + "' })")
        else
            Hyprland.dispatch("closewindow " + sel)
    }

    /// Force-kill the window behind an overview card (middle-click). This is a
    /// SIGKILL, unlike `closeToplevel`'s polite close. Lua/legacy split as above.
    function killToplevel(tl) {
        if (!tl)
            return
        var sel = "address:" + panel.hexAddress(tl)
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.window.kill({ window = '" + sel + "' })")
        else
            Hyprland.dispatch("killwindow " + sel)
    }

    /// `tl.address` is bare hex; Hyprland selectors want an `0x` prefix.
    function hexAddress(tl) {
        var a = String(tl.address)
        return a.indexOf("0x") === 0 ? a : "0x" + a
    }

    /// Move the window behind an overview card to another workspace (drag and
    /// drop in the overview). The move is silent so the workspace/focus you are
    /// on is not yanked away while the overview closes; the overview stays open
    /// so more windows can be moved. Same Lua/legacy split as focus/close.
    function moveToplevelToWorkspace(tl, wsId) {
        if (!tl || wsId === undefined || wsId === null)
            return
        var sel = "address:" + panel.hexAddress(tl)
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.window.move({ workspace = " + wsId
                + ", window = '" + sel + "', follow = false })")
        else
            Hyprland.dispatch("movetoworkspacesilent " + wsId + "," + sel)
        // Pull fresh state so the card settles into its new column right away.
        Hyprland.refreshToplevels()
    }

    // ── Click-outside backdrop ───────────────────────────────────────────────
    // Sits behind both islands. While anything is open it catches clicks that
    // miss the islands and dismisses everything; at rest it is disabled.
    MouseArea {
        anchors.fill: parent
        enabled: panel.anyOpen && !panel.polkitActive
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: panel.dismissAll()
    }

    // ── Click-outside backdrop on every other output ─────────────────────────
    // The surface above only spans the monitor named in Theme.barMonitor, so a
    // click on a second screen would otherwise do nothing while a panel is open.
    // Mirror the backdrop on every *other* screen: inert at rest (its mask is
    // empty, so clicks pass through to whatever is underneath) and a
    // full-screen dismiss target while the island or the media card is open.
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                // The screen this instance covers; never the bar's own output,
                // which already has the handler and must stay interactive.
                property var modelData
                screen: modelData
                visible: modelData !== panel.screen

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell:karuBackdrop"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                // Do not reserve space or shove maximised windows around.
                exclusiveZone: 0
                exclusionMode: ExclusionMode.Ignore

                // Empty while collapsed: the surface catches nothing and clicks
                // fall through. Dropped while open so the whole screen dismisses.
                mask: panel.anyOpen ? null : noInput
                Region {
                    id: noInput
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: panel.anyOpen && !panel.polkitActive
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onPressed: panel.dismissAll()
                }
            }
        }
    }

    // No drop shadow is cast by the islands (the pill, an expanded panel or the
    // Notch-mode slab). The panel blur is the only thing that separates them
    // from the desktop; a blurred shadow behind a translucent glass surface
    // would bleed through it as a muddy inner shadow anyway.

    // Notch Mode silhouette: the bar (fused with the media companion at rest)
    // or an open panel, drawn as one path with concave coves at the outer top
    // corners that flow into the screen edge and a rounded bottom. The island
    // and media draw no fill of their own in this mode; this provides it.
    NotchBar {
        id: notchBarShape
        visible: island.notchBar
        barLeft: island.x
        outerRight: island.notchRightEdge
        barTop: island.y
        barHeight: island.height
        // Frosted glass for an open panel; the flat bar at rest stays opaque.
        glass: panel.glass
    }

    // ── The island itself ────────────────────────────────────────────────────
    Rectangle {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        width: panel.expanded
            ? panel.panelWidth
            : (panel.gameMode
                ? (panel.screen ? panel.screen.width : Theme.collapsedWidth)
                : Theme.collapsedWidth)
        height: panel.expanded
            ? stack.currentHeight + Theme.panelPadding * 2
            : Theme.collapsedHeight

        // Game Mode at rest is a plain, full-width bar: square corners, opaque
        // fill and a flat hover. Notch mode (a Settings option) turns the pill
        // into a flush slab hugging the screen edge, its silhouette drawn by
        // NotchBar (concave coves at the outer top corners, rounded bottom, and
        // the media companion fused onto the right as one path), so the island
        // itself paints no fill in that mode. Opening a panel keeps that same
        // flush slab, just grown to the panel size; the media companion drops
        // away while the panel owns the top of the screen.
        readonly property bool flatBar: panel.gameMode && !panel.expanded
        readonly property bool notchBar:
            Settings.notchMode && !panel.gameMode
        readonly property bool mediaConnected: notchBar
            && !panel.expanded && media.visible && !media.open
        // Outer right edge of the fused notch: the media companion when it is
        // attached, otherwise the bar itself.
        readonly property real notchRightEdge: mediaConnected
            ? media.x + media.width
            : x + width
        readonly property real cornerAll:
            panel.expanded ? Theme.radiusPanel : height / 2

        topLeftRadius:     flatBar ? 0 : (notchBar ? 0 : cornerAll)
        topRightRadius:    flatBar ? 0 : (notchBar ? 0 : cornerAll)
        bottomLeftRadius:  flatBar ? 0 : (notchBar ? Theme.notchBottomRadius : cornerAll)
        bottomRightRadius: flatBar ? 0
            : (notchBar ? (mediaConnected ? 0 : Theme.notchBottomRadius) : cornerAll)

        color: (panel.gameMode && !panel.expanded)
            ? Theme.backgroundSolid
            : ((notchBar || panel.glass)
                ? "transparent"
                : ((hover.hovered && !panel.expanded) ? Theme.hoverSurface : Theme.background))
        border.width: (panel.gameMode && !panel.expanded)
            ? 0
            : (notchBar
                ? 0
                : ((hover.hovered && !panel.expanded) ? Theme.hoverBorderWidth : 1))
        border.color: (panel.gameMode && !panel.expanded)
            ? Theme.border
            : (panel.expanded
                ? Theme.borderStrong
                : (hover.hovered ? Theme.hoverBorder : Theme.border))
        clip: true
        // The corners are set per-corner (not via `radius`), so ask for
        // antialiasing explicitly; otherwise the rounded notch corners alias.
        antialiasing: true

        // Hover reaction: a pronounced scale-up, anchored to the top so the pill
        // grows downward and outward, with a springy pop. Left flat while the
        // full panel is open, and while Game Mode's static bar is showing.
        transformOrigin: Item.Top
        scale: (!panel.gameMode && !Settings.notchMode && hover.hovered && !panel.expanded) ? Theme.hoverScale : 1

        // Fluid grow/shrink on a real physics spring, so the island visibly
        // overshoots its target and settles back — the "expensive" open. The
        // stiffness and damping are user-tunable (Settings ▸ Motion ▸ Panel
        // open): a stiffer spring is quicker and more energetic, a lower damping
        // bouncier. Game Mode / Reduce Motion disables the Behavior outright, so
        // the size snaps instead of springing.
        Behavior on width {
            enabled: !Theme.motionOff
            SpringAnimation {
                spring: Theme.panelSpring
                damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                mass: Theme.panelMass
                epsilon: Theme.panelEpsilon
            }
        }
        Behavior on height {
            enabled: !Theme.motionOff
            SpringAnimation {
                spring: Theme.panelSpring
                damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                mass: Theme.panelMass
                epsilon: Theme.panelEpsilon
            }
        }
        Behavior on topLeftRadius {
            enabled: !Theme.motionOff
            SpringAnimation {
                spring: Theme.panelSpring
                damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                mass: Theme.panelMass
                epsilon: Theme.panelEpsilon
            }
        }
        Behavior on topRightRadius {
            enabled: !Theme.motionOff
            SpringAnimation {
                spring: Theme.panelSpring
                damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                mass: Theme.panelMass
                epsilon: Theme.panelEpsilon
            }
        }
        Behavior on bottomLeftRadius {
            enabled: !Theme.motionOff
            SpringAnimation {
                spring: Theme.panelSpring
                damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                mass: Theme.panelMass
                epsilon: Theme.panelEpsilon
            }
        }
        Behavior on bottomRightRadius {
            enabled: !Theme.motionOff
            SpringAnimation {
                spring: Theme.panelSpring
                damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                mass: Theme.panelMass
                epsilon: Theme.panelEpsilon
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easeSpring
                easing.overshoot: Theme.springOvershoot
            }
        }
        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        Behavior on border.width { NumberAnimation { duration: Theme.fadeDuration; easing.type: Theme.easeOut } }
        Behavior on border.color { ColorAnimation { duration: Theme.fadeDuration } }

        // Hover only reports the pointer for the effect above; it never opens
        // the island.
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        // Frosted-glass fill for an open panel. The island's own colour is
        // transparent in that mode (above) so the compositor's backdrop blur
        // shows through this dark gradient; it sits behind all panel content.
        // Skipped in Notch Mode, where the fused silhouette (NotchBar) carries
        // the gradient instead of this plain rounded rectangle.
        PanelGlass {
            anchors.fill: parent
            active: panel.glass && !island.notchBar
            topLeftRadius: island.topLeftRadius
            topRightRadius: island.topRightRadius
            bottomLeftRadius: island.bottomLeftRadius
            bottomRightRadius: island.bottomRightRadius
        }

        // Click-to-collapse for the open panel. It sits behind the content, so
        // panel controls still win. Every panel collapses only from the top
        // header band around the clock (the same band the Control Center uses):
        // a press anywhere below it is swallowed but ignored, so a stray click
        // on empty space in a panel's body never closes it.
        // At rest it is disabled: in the collapsed pill the clock, the gap
        // around it and the status icons all open the Control Center (see the
        // two MouseAreas below), while the workspace dots keep their own
        // handlers and never toggle the island.
        MouseArea {
            anchors.fill: parent
            enabled: panel.expanded && !panel.polkitActive
            cursorShape: panel.expanded ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: function (mouse) {
                if (mouse.y > Theme.panelPadding + Theme.clockHeaderHeight)
                    return
                panel.toggleExpanded()
            }
        }

        // Right-click anywhere on the island — collapsed or expanded — opens the
        // panel menu (the Session-panel-style switcher). A MouseArea ignores
        // buttons it does not accept, so the left-click handler above, the
        // workspace dots and the panel's own controls are all untouched: this
        // claims only the right button.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            enabled: !panel.polkitActive
            cursorShape: Qt.PointingHandCursor
            onPressed: panel.openSwitcher()
        }

        // ── Collapsed content ────────────────────────────────────────────────
        // Left: workspace dots. The clock and the status cluster are shared
        // overlays (below), so they are not part of this fading row.
        Item {
            // Game Mode spreads the row to the full bar width (workspaces hard
            // left, status icons hard right, clock centred on the screen); the
            // normal pill keeps its compact fixed width.
            width: panel.gameMode ? parent.width : Theme.collapsedWidth
            height: Theme.collapsedHeight
            // Pinned to the pill's own slot rather than centred in the island:
            // as the island springs open the row must melt away *where it was*,
            // not drift down into the middle of the growing panel. (Collapsed,
            // top and centre are the same spot, so the resting look is
            // unchanged.)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            opacity: panel.expanded ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

            WorkspaceIndicator {
                id: workspaces
                anchors.left: parent.left
                anchors.leftMargin: Theme.collapsedPadding
                anchors.verticalCenter: parent.verticalCenter
                // Mirror the status icons' width so the two clusters balance
                // and the shared clock stays centred in the pill.
                matchWidth: statusIcons.width
            }

            // The clock and the status cluster are not part of this fading row:
            // they are shared overlays (below) so they can transition into the
            // Control Center.

            // The Control Center opens from anywhere to the right of the
            // workspace dots — the clock, the empty space around it and the
            // status cluster all toggle it. The target starts exactly at the
            // dots' right edge so the row keeps its own TapHandlers: a click
            // (or scroll) on a workspace is never swallowed by the island.
            MouseArea {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: workspaces.right
                anchors.right: parent.right
                cursorShape: Qt.PointingHandCursor
                onPressed: panel.toggleExpanded()
            }
        }

        // ── Expanded content: the selected panel ─────────────────────────────
        PanelStack {
            id: stack
            width: panel.panelWidth - Theme.panelPadding * 2
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.panelPadding
            // The stack owns its own fade + row cascade; shell just tells it
            // whether the island is open.
            expanded: panel.expanded
            visible: opacity > 0.01
            enabled: panel.expanded

            // The overview caps its height to the display, so it needs the screen.
            screen: panel.screen

            // Lets the Control Center hide the tile whose detail card is open.
            activeDetail: panel.detailPanel

            // The panel the switcher menu highlights (where we came from).
            currentPanel: panel.switcherFrom

            // A panel (e.g. the app launcher) asked to be closed.
            onRequestClose: panel.expanded = false

            // A tile in the panel menu was chosen: switch straight to it.
            onPanelSelected: function (key) { panel.choosePanel(key) }

            // The Session panel's Lock button asked to lock the session.
            onLockRequested: engageLock()

            // The Control Center's Now Playing control asked to open the media
            // companion's card. Opening it collapses the island (see MediaIsland).
            onMediaRequested: media.open = true

            // The Control Center's System Tray control asked to open a tray
            // item's own menu (rendered Karu-styled by the TrayMenu below).
            onTrayMenuRequested: function(item, rect) { panel.openTrayMenu(item, rect) }

            // The Control Center header's settings button asked to open Settings.
            onSettingsRequested: panel.openSettings()

            // A Control Center tile asked to open its detail dialog.
            onDetailRequested: function(which, tile) {
                detailCard.openFrom(tile)
                panel.detailPanel = which
            }

            // An overview card was activated (focus it) / its × was pressed.
            onOverviewActivateRequested: function (tl) {
                panel.setOverview(false)
                panel.focusToplevel(tl)
            }
            onOverviewCloseRequested: function (tl) { panel.closeToplevel(tl) }
            onOverviewKillRequested: function (tl) { panel.killToplevel(tl) }
            onOverviewMoveRequested: function (tl, wsId) { panel.moveToplevelToWorkspace(tl, wsId) }
        }

        // ── Shared clock ─────────────────────────────────────────────────────
        // One clock for the whole island. At rest it sits centred in the pill;
        // opening the Control Center glides it down into the header the panel
        // reserves (`Theme.clockHeaderHeight`), growing the time and revealing
        // the date. It is declared after PanelStack so it flies over the panel
        // content, and before the detail card so that card still overlays it.
        // On every other panel the clock simply fades out with the bar content.
        Clock {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter

            readonly property bool inControl: panel.expanded && stack.current === "control"

            // Measured from the island's top edge in both states, so the pill's
            // height and the panel's drive the same expression and the clock
            // glides between the two.
            y: panel.expanded
                ? Theme.panelPadding + (Theme.clockHeaderHeight - height) / 2
                : (Theme.collapsedHeight - height) / 2

            timeSize: inControl ? Theme.clockExpandedSize : Theme.clockSize
            showDate: inControl || Settings.barShowDate

            opacity: (panel.expanded && !inControl) ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
            // The clock glides on the island's own spring, so it descends into
            // the Control Center header as part of the same motion.
            Behavior on y {
                enabled: !Theme.motionOff
                SpringAnimation {
                    spring: Theme.panelSpring
                    damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                    mass: Theme.panelMass
                    epsilon: Theme.panelEpsilon
                }
            }
        }

        // The clock is a click target for the Control Center while the pill is
        // collapsed. Declared after the clock so it rides along with its glide,
        // and disabled once expanded so the panel background keeps handling
        // click-to-collapse.
        MouseArea {
            anchors.fill: clock
            enabled: !panel.expanded
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: panel.toggleExpanded()
        }

        // ── Shared status icons ──────────────────────────────────────────────
        // One status cluster for the whole island, like the clock. At rest it
        // sits right-aligned in the pill; opening the Control Center glides it
        // down into the header the panel reserves (`Theme.clockHeaderHeight`),
        // staying vertically centred against the clock. On any other panel it
        // fades out with the rest of the bar content.
        StatusIcons {
            id: statusIcons

            visible: Settings.showStatusIcons && opacity > 0.01

            readonly property bool inControl: panel.expanded && stack.current === "control"

            // Right-aligned inside the island, exactly like the pill row it
            // replaces: anchoring to the island's own edge means the cluster
            // tracks the growing panel (and the hover scale) for free.
            anchors.right: parent.right
            anchors.rightMargin: panel.expanded
                ? Theme.panelPadding : Theme.collapsedPadding

            // Measured from the island's top edge in both states, mirroring the
            // clock so the two settle into the header together.
            y: panel.expanded
                ? Theme.panelPadding + (Theme.clockHeaderHeight - height) / 2
                : (Theme.collapsedHeight - height) / 2

            opacity: (panel.expanded && !inControl) ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
            Behavior on y {
                enabled: !Theme.motionOff
                SpringAnimation {
                    spring: Theme.panelSpring
                    damping: panel.expanded ? Theme.panelDamping : Theme.panelCloseDamping
                    mass: Theme.panelMass
                    epsilon: Theme.panelEpsilon
                }
            }
        }

        // The cluster is a click target for the Control Center while the pill is
        // collapsed; disabled once expanded so the panel background keeps
        // handling click-to-collapse. Wheel events still fall through to the
        // volume glyph's own handler underneath.
        MouseArea {
            anchors.fill: statusIcons
            enabled: statusIcons.visible && !panel.expanded
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: panel.toggleExpanded()
        }

        // ── Tile detail card ─────────────────────────────────────────────────
        // A compact card that floats over the Control Center and morphs out of
        // the tile that opened it — the Bluetooth / Wi-Fi / LAN dialogs all
        // share it. Its origin is the tile's scene rectangle, converted to
        // island coordinates; its target is a centred card, smaller than the
        // panel area.
        // Drop shadow behind the tile-detail card.
        PanelShadow {
            x: detailCard.x
            y: detailCard.y
            width: detailCard.width
            height: detailCard.height
            radius: detailCard.radius
            opacity: detailCard.opacity
            // Ride just under the card: on top of the panel while open, and
            // behind it (with the card) as it shrinks back into its tile.
            z: detailCard.z - 1
        }

        DetailCard {
            id: detailCard

            kind: panel.detailPanel
            targetRect: {
                var gameCard = panel.detailPanel === "gamemode"
                var w = Math.min(gameCard ? Theme.gameModeCardWidth : Theme.bluetoothCardWidth,
                                 panel.panelWidth - Theme.panelPadding * 2)
                var h = Math.min(gameCard ? Theme.gameModeCardHeight : Theme.bluetoothCardHeight,
                                 Math.max(160, stack.currentHeight - Theme.spaceLg * 2))
                return Qt.rect(Math.round((panel.panelWidth - w) / 2),
                               Math.round(Theme.panelPadding + (stack.currentHeight - h) / 2),
                               Math.round(w), Math.round(h))
            }

            onCloseRequested: panel.detailPanel = ""
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Notification banners — the stack that drops out of the island
    // ════════════════════════════════════════════════════════════════════════
    //  Toasts emerge from under the pill, newest on top, and stack downward
    //  (see ui/notifications/NotificationStack.qml). They ride the island's bottom
    //  edge, and while a panel or the media card is open the island owns that
    //  space, so the stack is suppressed and reappears when the island
    //  collapses. It is part of the input Region above, so a click can dismiss
    //  a banner individually.
    NotificationStack {
        id: notificationStack
        x: Math.round(island.x + (island.width - width) / 2)
        y: island.y + island.height + Theme.notificationTopGap
        suppressed: panel.anyOpen
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Media island — the small round companion on the right
    // ════════════════════════════════════════════════════════════════════════
    //  Sits to the right of the main island, vertically aligned with its top
    //  row. It is a circle until clicked, then morphs into a wide, horizontal
    //  "Now Playing" panel that drops below the bar. `x` tracks the main
    //  island's animated width *and* its live hover scale, keeping the pair a
    //  constant visual distance apart: the pill scales out from its top centre
    //  on hover, so without compensating its right edge would grow into the
    //  companion and the two would touch.
    // The media island casts no drop shadow either (see the island note above).

    MediaIsland {
        id: media
        y: island.y
        // In Notch Mode the companion is fused to the bar only while the bar is
        // collapsed; an open panel pushes it out to the side as a floating
        // circle instead. MediaIsland reads this to decide whether to fuse.
        panelOpen: panel.expanded
        // Anchor to the main island's *rendered* right edge rather than its
        // untransformed width. `island.scale` is the live (animated) hover
        // scale, and the pill is scaled about its top centre, so its right edge
        // sits at `island.x + island.width * (1 + island.scale) / 2`. Reading
        // both live means the companion glides out in lockstep with the pill's
        // spring and back in when the hover ends, so the gap never closes.
        x: island.x + island.width * (1 + island.scale) / 2 + media.gap

        // Game Mode hides the floating companion entirely: a full-width bar has
        // no room beside it, and it is one less live surface to keep running.
        // While a polkit prompt is up it is hidden and disabled too, so the
        // prompt stands alone and opening the media card can never collapse the
        // island out from under it. In Notch Mode it stays fused to the bar at
        // rest and simply detaches to the side of an open panel (see
        // `panelOpen` below).
        visible: Settings.showMediaPlayer && !panel.gameMode && !panel.polkitActive
        enabled: Settings.showMediaPlayer && !panel.gameMode && !panel.polkitActive

        // Switching the media player off (or any other reason it hides) drops
        // the card, so it never lingers open and invisible.
        onVisibleChanged: if (!visible) media.open = false

        // Opening the media card closes whatever else was showing: any main-island
        // panel, including the overview (which is just another panel).
        onOpenChanged: if (open && !panel.polkitActive)
            panel.expanded = false
    }

    // Entering Game Mode drops the floating media card (it is being hidden) and
    // any open tile dialog (which would otherwise hang over the changed bar).
    onGameModeChanged: if (panel.gameMode) {
        media.open = false
        panel.detailPanel = ""
        panel.trayMenuItem = null
    }

    // ════════════════════════════════════════════════════════════════════════
    //  System tray context menu — a Karu-styled menu for a tray item
    // ════════════════════════════════════════════════════════════════════════
    //  Right-clicking a tray icon in the Control Center's System Tray tile
    //  renders that item's own menu here instead of the compositor's native
    //  popup, so it matches the island (fill, radius, fonts, hover). It is a
    //  full-window overlay declared last (outside the island's `clip`) and
    //  hangs from the icon's scene rectangle.
    TrayMenu {
        id: trayMenu
        handle: panel.trayMenuItem ? panel.trayMenuItem.menu : null
        anchorRect: panel.trayMenuRect
        screenWidth: panel.screen ? panel.screen.width : 0
        screenHeight: panel.screen ? panel.screen.height : 0
        onDismissed: panel.trayMenuItem = null
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Settings — standalone macOS-style settings app (SUPER + comma)
    // ════════════════════════════════════════════════════════════════════════
    //  A real floating window (not a layer-shell panel), so it behaves like a
    //  normal application: compositor-managed, focusable, closable. It edits the
    //  `Settings` singleton live, which re-themes the shell as you drag.
    SettingsWindow {
        screen: panel.screen
        // Hidden while Docked mode is on: the app lives in the island instead.
        visible: panel.settingsOpen && !Settings.settingsDocked
        onCloseRequested: panel.settingsOpen = false
    }
}
