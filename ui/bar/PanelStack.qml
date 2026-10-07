import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../panels"
import "../settings"
import "../widgets"

/**
 * PanelStack — owns the currently-selected panel and cross-fades between them.
 *
 * The expanded height follows the visible panel's implicit height via
 * `currentHeight`, which shell.qml reads to size the island.
 */
ColumnLayout {
    id: root

    /// Bubbled up from a panel that wants the island to collapse (e.g. the app
    /// launcher after launching something, or when Esc is pressed).
    signal requestClose()

    /// Bubbled up from the Session panel's Lock button.
    signal lockRequested()

    /// Bubbled up from the Control Center's Now Playing control: open the media
    /// companion's Now Playing card.
    signal mediaRequested()

    /// Bubbled up from the Control Center's System Tray control: open a tray
    /// item's own menu (rendered Karu-styled by shell.qml).
    signal trayMenuRequested(var item, var rect)

    /// Bubbled up from the Control Center header's settings button: open the
    /// Settings app.
    signal settingsRequested()

    /// Bubbled up from a Control Center tile: open its detail dialog, morphing
    /// from the tile. `which` is "bluetooth", "network" (merged Wi-Fi + LAN) or
    /// "brightness"; `tile` carries the tile's geometry and look.
    signal detailRequested(string which, var tile)

    /// Bubbled up from the PanelSwitcher (the right-click panel menu): switch
    /// the island straight to the chosen panel key.
    signal panelSelected(string key)

    /// Bubbled up from the Overview panel.
    signal overviewActivateRequested(var toplevel)
    signal overviewCloseRequested(var toplevel)
    signal overviewKillRequested(var toplevel)
    signal overviewMoveRequested(var toplevel, int workspaceId)

    /// Screen of the island (from shell.qml) — the overview caps its height to it.
    property var screen: null

    /// True while the island is expanded. Owned here (shell.qml drives it) so the
    /// stack can play its staggered content reveal exactly when a panel opens.
    property bool expanded: false

    /// Which tile detail dialog is open (from shell.qml): "" (none),
    /// "bluetooth", "network" or "brightness". The Control Center suppresses the
    /// tile it belongs to while its card is showing.
    property string activeDetail: ""

    property string current: "control"

    /// The panel the island was showing before the switcher opened; the switcher
    /// highlights its tile. Shell.qml keeps this in step.
    property string currentPanel: "control"

    /// The Control Center is kept instantiated for the whole session instead of
    /// being built by the `Loader` like the other panels. It is the default
    /// panel, so rebuilding it on every switch was both the most common and the
    /// most expensive reload: each open re-created every live control (network /
    /// Bluetooth / sound / MPRIS bindings, the DDC `Brightness.ensure()` probe)
    /// plus two full copies of the notification list. Keeping it alive makes
    /// reopening it — after the volume OSD, another panel, or a while idle —
    /// warm instead of a cold rebuild. `activePanel` names whichever of the two
    /// is on screen so `currentHeight` / `ContentReveal` read the right one.
    readonly property var activePanel: root.current === "control"
        ? controlPanel : loader.item

    // With the category/tab bar removed, the expanded island is just the
    // selected panel; its height drives the island height.
    readonly property int currentHeight: activePanel ? activePanel.implicitHeight : 0

    /// True while the loaded panel is actively being used and has asked the
    /// island to stay open (e.g. the app launcher with a non-empty query).
    readonly property bool keepOpen: activePanel ? (activePanel.keepOpen === true) : false

    /// True while the loaded panel wants the island's exclusive keyboard focus
    /// (e.g. the Wallpapers panel's Local carousel, but not its click-only
    /// Browse tab). shell.qml reads this to decide whether to grab the keyboard.
    readonly property bool wantsKeyboard: activePanel
        ? (activePanel.wantsKeyboard === true) : false

    /// Natural content width of the current panel, if it advertises one (the
    /// overview does) — shell.qml uses it to size the island so nothing clips.
    readonly property real preferredContentWidth: (root.current === "overview"
        && loader.item && loader.item.preferredContentWidth !== undefined)
        ? loader.item.preferredContentWidth
        : 0

    spacing: Theme.gap

    // The whole stack fades with the island and eases out of a slight zoom on
    // open, while its rows cascade in one after another (see `reveal`).
    opacity: expanded ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

    ContentReveal { id: reveal }

    onExpandedChanged: if (expanded) reveal.play(activePanel)
    onCurrentChanged: if (expanded) Qt.callLater(reveal.play, activePanel)

    // The item area is clipped so a taller panel can never bleed past the
    // island while the container animates to the new (possibly shorter) height.
    Item {
        Layout.fillWidth: true
        implicitHeight: root.activePanel ? root.activePanel.implicitHeight : 0
        clip: true

        // The panel eases out of a subtle zoom as it opens, so the contents
        // settle into place rather than snapping to full size. Anchored to the
        // top so it grows downward out of the pill; spring-driven so it carries
        // a touch of overshoot like the island itself. Collapsed this is neutral
        // because the stack is hidden anyway.
        transformOrigin: Item.Top
        scale: expanded ? 1 : Theme.contentScaleFrom
        Behavior on scale {
            enabled: !Theme.motionOff
            SpringAnimation {
                spring: Theme.panelSpring
                damping: expanded ? Theme.panelDamping : Theme.panelCloseDamping
                mass: Theme.panelMass
                epsilon: 0.002
            }
        }

        // The Control Center, instantiated once and kept for the whole session
        // (see `activePanel`). Hidden — and inert — while another panel is up.
        ControlCenterPanel {
            id: controlPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: root.current === "control"
            enabled: visible

            screen: root.screen
            activeDetail: root.activeDetail
            onDetailRequested: function(which, tile) { root.detailRequested(which, tile) }
            onLockRequested: root.lockRequested()
            onMediaRequested: root.mediaRequested()
            onTrayMenuRequested: function(item, rect) { root.trayMenuRequested(item, rect) }
            onSettingsRequested: root.settingsRequested()
        }

        Loader {
            id: loader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: root.current !== "control"

            sourceComponent: {
                switch (root.current) {
                    case "themes":     return themePanel
                    case "wallpapers": return wallpaperPanel
                    case "session":    return sessionPanel
                    case "apps":       return appPanel
                    case "switcher":   return switcherPanel
                    case "overview":   return overviewPanel
                    case "polkit":     return polkitPanel
                    case "volume":     return volumePanel
                    case "settings":   return settingsPanel
                    default:           return null
                }
            }

            // Cross-fade the content whenever the panel changes.
            opacity: 1
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
        }

        Component { id: themePanel;     ThemePanel {} }
        Component { id: wallpaperPanel; WallpaperPanel {} }
        Component { id: sessionPanel;   SessionPanel { onRequestClose: root.requestClose(); onRequestLock: root.lockRequested() } }
        Component {
            id: appPanel
            AppLauncherPanel { onRequestClose: root.requestClose() }
        }
        Component {
            id: switcherPanel
            PanelSwitcher {
                current: root.currentPanel
                onRequestClose: root.requestClose()
                onPanelChosen: function (key) { root.panelSelected(key) }
            }
        }
        Component {
            id: polkitPanel
            PolkitPanel {}
        }
        Component {
            id: volumePanel
            VolumePanel {}
        }
        Component {
            id: overviewPanel
            Overview {
                screen: root.screen
                onRequestClose: root.requestClose()
                onActivateRequested: function (tl) { root.overviewActivateRequested(tl) }
                onCloseRequested: function (tl) { root.overviewCloseRequested(tl) }
                onKillRequested: function (tl) { root.overviewKillRequested(tl) }
                onMoveRequested: function (tl, wsId) { root.overviewMoveRequested(tl, wsId) }
            }
        }
        Component {
            id: settingsPanel
            SettingsPanel {
                screen: root.screen
                onRequestClose: root.requestClose()
            }
        }
    }
}
