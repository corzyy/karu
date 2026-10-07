pragma Singleton

import QtQuick

import "../config"

/**
 * Theme — the single source of truth for every color, radius, size and font
 * used by the island.
 *
 * Restyle the whole thing from here. In particular:
 *   - `accent`       drives the selected workspace, active toggles, borders
 *   - `sliderAccent` drives the Sound / Display slider fill
 *   - `background` / `surface` / `surfaceElevated` control the dark stack
 *
 * Changing a value here re-themes every component automatically.
 *
 * Colours are not defined here any more: every colour below is a binding into
 * `Colors.qml`, the mutable active palette. Pick a theme in the Themes tab (or
 * let the Wallpaper theme run) and `Themes.qml` rewrites `Colors`, which flows
 * back through these properties into every component.
 */
QtObject {
    id: theme

    // ── Game Mode ────────────────────────────────────────────────────────────
    // Mirrors the GameMode singleton so components can test one flag. While it
    // is on the shell switches to a flat, full-width bar and every motion token
    // below collapses to zero (and the hover lifts go away) — the whole shell
    // runs without animation. See core/theme/GameMode.qml and
    // ui/panels/GameModePanel.qml.
    readonly property bool gameMode: GameMode.enabled

    /**
     * Composite a possibly-translucent colour `c` over the opaque `base`,
     * returning an opaque colour. A tile's fill can be tinted (its `accentMuted`
     * state is ~16% alpha), and the detail card that grows out of it has to be
     * fully opaque or the tile underneath would show through the moving card.
     * Flattening the tint over the island background first reproduces exactly
     * what the tile looks like where it sits.
     */
    function flatten(c, base) {
        if (c.a >= 1)
            return c
        return Qt.rgba(c.r * c.a + base.r * (1 - c.a),
                       c.g * c.a + base.g * (1 - c.a),
                       c.b * c.a + base.b * (1 - c.a),
                       1)
    }

    // ── Base surfaces (active palette — see Colors.qml) ──────────────────────
    // OLED mode pins the bottom-most background — the island/panel surface
    // itself — to pure black, while tiles and cards are forced to a neutral
    // dark grey so they still read as raised elements above it.
    readonly property bool  oled:              Settings.oled
    readonly property color background:        oled ? "#000000" : Colors.background
    readonly property color backgroundSolid:   oled ? "#000000" : Colors.backgroundSolid
    readonly property color surface:           oled ? "#1A1A1C" : Colors.surface
    readonly property color surfaceElevated:   oled ? "#1C1C1E" : Colors.surfaceElevated
    readonly property color surfaceHover:      oled ? "#242427" : Colors.surfaceHover
    readonly property color track:             oled ? "#2A2A2D" : Colors.track
    readonly property color iconCircle:        oled ? "#26262A" : Colors.iconCircle

    // ── Borders ──────────────────────────────────────────────────────────────
    readonly property color border:            Colors.border
    readonly property color borderStrong:      Colors.borderStrong
    // The media panel's frosted outer rim: brighter and a touch heavier than the
    // flat panel border so it reads as a glass card floating over its cover.
    readonly property color borderMedia:       Qt.rgba(1, 1, 1, 0.45)

    // ── Text ─────────────────────────────────────────────────────────────────
    readonly property color textPrimary:       Colors.textPrimary
    readonly property color textSecondary:     Colors.textSecondary
    readonly property color textDim:           Colors.textDim

    // ── Accents (driven by the active theme's primary / tertiary / error) ────
    // `accentOverride` lets the Settings app pin an accent on top of Matugen;
    // empty means "follow the active theme".
    readonly property color accent:            Settings.accentOverride.length > 0
        ? Settings.accentOverride : Colors.accent
    readonly property color accentMuted:       Qt.rgba(accent.r, accent.g, accent.b, 0.16)
    readonly property color accentGlow:        Qt.rgba(accent.r, accent.g, accent.b, 0.35)
    readonly property color sliderAccent:      Colors.sliderAccent
    readonly property color danger:            Colors.danger

    // ── Radii ────────────────────────────────────────────────────────────────
    readonly property int radiusPanel:         Settings.radiusPanel
    readonly property int radiusCard:          Settings.radiusCard
    readonly property int radiusInner:         Settings.radiusInner
    readonly property int radiusThumb:         12
    readonly property int radiusPill:          999

    // Notch Mode hugs the collapsed bar to the top screen edge. `notchCorner`
    // is the radius of the concave "cove" (Solstice's panel-to-bar fillet,
    // drawn as a tangent cubic) that joins the bar's outer top corners to the
    // edge. `notchBottomRadius` is just the theme's card rounding, so the
    // notch's bottom corners match the rest of the shell's rounded corners.
    readonly property int notchCornerRadius:   Math.round(Settings.collapsedHeight * 0.26)
    readonly property int notchBottomRadius:   radiusCard

    // ── Monitor placement ────────────────────────────────────────────────────
    // Wayland output name the island should always live on (e.g. "DP-1",
    // "HDMI-A-1", "eDP-1"). shell.qml re-binds to this output on startup and
    // whenever monitors are hotplugged, so the bar returns to the right screen
    // after a restart or a dock/undock. Set to "" to use the first screen.
    readonly property string barMonitor:        Settings.barMonitor

    // ── Island geometry ──────────────────────────────────────────────────────
    // Widths are kept as tight as the content allows: the collapsed pill fits
    // the workspace row, clock and status icons with breathing room, and the
    // expanded island fits the Control Center's 2-column toggle grid plus its
    // action button without clipping (the widest panel — see
    // ControlCenterPanel.qml). Panels that need less simply centre/fill.
    readonly property int topMargin:           Settings.topMargin
    readonly property int collapsedWidth:      Settings.collapsedWidth
    readonly property int collapsedHeight:     Settings.collapsedHeight
    readonly property int collapsedPadding:    Settings.collapsedPadding
    readonly property int expandedWidth:       Settings.expandedWidth
    // Width of the expanded Control Center panel. Separate from `expandedWidth`
    // so the Control Center alone can be widened from Settings ▸ Control Center
    // (see shell.qml `panelWidth` and ui/panels/ControlCenterPanel.qml).
    readonly property int controlPanelWidth:   Settings.controlPanelWidth
    // A wider island for the two carousel panels (Themes and Wallpapers): their
    // centred rows want more horizontal room than the standard panel so the
    // selected card can sit in the middle with its neighbours visible either
    // side. See shell.qml `panelWidth`.
    readonly property int expandedWidthWide:   600
    // The Settings app docked in the island (Settings ▸ System ▸ Docked
    // settings) is wider still: a searchable category sidebar beside the page.
    readonly property int settingsPanelWidth:  780

    // ── Spacing scale ────────────────────────────────────────────────────────
    // One scale for the whole UI. `xs`..`xl` for gaps, `tight`..`card` for
    // internal padding. Everything should reference these, not literals.
    readonly property int spaceXs:             4
    readonly property int spaceSm:             6
    readonly property int spaceMd:             10
    readonly property int spaceLg:             14
    readonly property int spaceXl:             18

    readonly property int padTight:            8      // small inner paddings
    readonly property int padRow:              12     // list rows / pills
    readonly property int cardPadding:         14     // inner card padding
    readonly property int panelPadding:        Settings.panelPadding   // island edge padding

    readonly property int gap:                 spaceMd  // between stacked cards
    readonly property int iconSpacing:         spaceMd  // between status icons

    // Fixed component heights
    readonly property int tabHeight:           34
    readonly property int toggleHeight:        Settings.toggleHeight
    readonly property int searchHeight:        Settings.searchHeight
    readonly property int wallpaperThumbHeight: 172
    // Wallpapers "Local" carousel (see WallpaperPanel.qml). The highlighted
    // wallpaper is centred at its full `wallpaperSelectedWidth`; its neighbours
    // are these narrower thumbnails, and as they leave the panel their image is
    // squeezed into the visible slice rather than hard-clipped. The headroom is
    // the extra vertical room the gently raised selected card needs, and
    // `wallpaperCardLift` how far it rises.
    readonly property int wallpaperThumbWidth:    148
    readonly property int wallpaperSelectedWidth: 248
    readonly property int wallpaperCardHeadroom:  26
    readonly property int wallpaperCardLift:      10
    // Wallhaven "Browse" tab: the results grid (see WallhavenBrowse.qml). Three
    // columns of thumbnails, three rows tall and scrollable.
    readonly property int wallhavenColumns:     3
    readonly property int wallhavenThumbHeight: 116
    readonly property int wallhavenGridRows:    3
    // The tile detail card (Bluetooth / Wi-Fi / LAN): a compact floating panel
    // over the Control Center (capped, and never taller than the panel it
    // overlays).
    readonly property int bluetoothCardWidth:  300
    readonly property int bluetoothCardHeight: 288
    // The Game Mode confirmation card (Control Center tile -> GameModePanel).
    // Smaller than the device dialogs: it only holds the prompt and two buttons.
    readonly property int gameModeCardWidth:   320
    readonly property int gameModeCardHeight:  196
    // Themes carousel (see ThemePanel.qml). Mirrors the Wallpapers "Local"
    // carousel: the highlighted card is centred at `themeCardWidth` while its
    // neighbours are the narrower `themeCardPlainWidth`, so the row reads as one
    // focused card framed by slimmer ones, and a card leaving the panel squeezes
    // into its visible slice instead of being hard-clipped.
    readonly property int themeCardWidth:      148     // highlighted card width
    readonly property int themeCardPlainWidth: 110     // neighbour card width
    readonly property int themeCardHeight:     92
    readonly property int themeCardHeadroom:   40      // room for the raised selected card
    readonly property int themeCardLift:       10      // selected card rise (px)
    readonly property int themeDotSize:        12
    readonly property int themeDotSpacing:     4

    // ── Notifications ────────────────────────────────────────────────────────
    // The banner stack that drops out of the island (see ui/
    // NotificationStack.qml). The width is fixed so banners line up;
    // `notificationMaxVisible` caps how many stack before the oldest is pushed
    // out (it stays in the Control Center history), and `notificationTimeout`
    // is the fallback lifetime when an app asks for none.
    readonly property int  notificationWidth:      Settings.notificationWidth
    readonly property int  notificationMinHeight:  Settings.notificationMinHeight
    readonly property int  notificationGap:        Settings.notificationGap
    readonly property int  notificationTopGap:     Settings.notificationTopGap
    readonly property int  notificationMaxVisible: Settings.notificationMaxVisible
    readonly property int  notificationMaxHistory: Settings.notificationMaxHistory
    readonly property int  notificationTimeout:    Settings.notificationTimeout

    // ── Volume OSD ───────────────────────────────────────────────────────────
    // The island morphs into the volume panel (ui/panels/VolumePanel.qml)
    // when the default sink's volume or mute changes. It is a deliberately short
    // bar (`volumeOsdWidth`, narrower than the standard `expandedWidth`) and
    // stays for `volumeOsdTimeout` before collapsing back into the pill.
    readonly property int volumeOsdWidth:   Settings.volumeOsdWidth
    readonly property int volumeOsdTimeout: Settings.volumeOsdTimeout

    readonly property int exclusiveZone:       collapsedHeight + topMargin

    // ── Hover feedback ───────────────────────────────────────────────────────
    // The islands open on a click, never on hover — but hovering is meant to be
    // felt. The pill scales up noticeably, its border picks up the accent and
    // its fill lifts, so the feedback reads at a glance instead of being a
    // barely-visible nudge. The small value is tuned for the round media island.
    // Game Mode flattens both to 1, so the bar never scales under the pointer.
    readonly property real hoverScale:         gameMode ? 1.0 : Settings.hoverScale
    readonly property color hoverBorder:       accent   // border colour while hovered
    readonly property int hoverBorderWidth:    2        // border thickness while hovered
    // The lift is composited over the opaque island background so the hover
    // fill stays fully opaque — a translucent overlay here would let the
    // wallpaper bleed through the pill (and the media circle) on hover.
    readonly property color hoverSurface:      oled
        ? flatten(Qt.rgba(1, 1, 1, 0.08), background)
        : Qt.lighter(background, 1.5)

    // ── Panel blur (frosted glass) ───────────────────────────────────────────
    // Optional backdrop blur behind an open panel (Settings ▸ Appearance ▸
    // Panel blur). The compositor blurs whatever sits behind the panel —
    // requested with the ext-background-effect-v1 protocol (see shell.qml) —
    // and the panel paints a dark glass gradient over it: a fully opaque band
    // as tall as the collapsed island at the top, fading to fully transparent
    // at the bottom so the blur shows through below. Only the expanded panels use it; the collapsed pill and the media
    // island keep their flat fill. Disabled under Game Mode, whose whole point
    // is to drop every costly effect.
    readonly property bool  panelBlur:       Settings.panelBlur && !gameMode
    readonly property color panelGlassTop:       Qt.rgba(background.r, background.g, background.b, 1.0)
    readonly property color panelGlassTopHover:  Qt.rgba(background.r, background.g, background.b, 1.0)
    readonly property color panelGlassBottom:    Qt.rgba(background.r, background.g, background.b, 0.0)

    // ── Tile / card glass ────────────────────────────────────────────────────
    // Tiles and cards reuse the panel's glass gradient (opaque at the top,
    // fading to transparent at the bottom) so they read as part of the same
    // frosted sheet as the panel behind them. With Panel blur off — or under
    // Game Mode — the stops collapse to the flat `surface` fill, leaving the
    // tiles exactly as they were. See ui/widgets/TileGlass.qml.
    readonly property color tileGlassTop:        panelBlur ? panelGlassTop : surface
    readonly property color tileGlassTopHover:   panelBlur ? panelGlassTopHover : surfaceHover
    readonly property color tileGlassBottom:     panelBlur ? panelGlassBottom : surface

    // ── Motion ───────────────────────────────────────────────────────────────
    // One shared motion language so every animation in the shell eases the
    // same way. Durations step up with the size of the change; the curves below
    // are the names components should reference instead of raw easing values.
    // Game Mode zeroes every duration, which turns each Behavior into an
    // instant assignment — the shell's animations are switched off everywhere
    // they reference these tokens. `Settings.reduceMotion` does the same on
    // demand from the Settings app.
    readonly property bool motionOff:          gameMode || Settings.reduceMotion
    readonly property int motionSnap:          motionOff ? 0 : Settings.motionSnap
    readonly property int motionFast:          motionOff ? 0 : Settings.motionFast
    readonly property int motionMedium:        motionOff ? 0 : Settings.motionMedium
    readonly property int motionSlow:          motionOff ? 0 : Settings.motionSlow

    readonly property var easeOut:             Easing.OutCubic   // settle without overshoot
    readonly property var easeEmphasized:      Easing.OutQuint   // long glides, very smooth tail
    readonly property var easeSpring:          Easing.OutBack    // grow / shrink with a pop
    readonly property real springOvershoot:    Settings.springOvershoot

    // ── Panel open & close spring ────────────────────────────────────────────
    // The island (and every card that morphs with it) opens and closes on a
    // real physics spring rather than a fixed duration, so a panel visibly
    // overshoots its target and settles back — the "expensive", fluid feel.
    // `panelSpring` is the stiffness (higher = faster, more energetic) and
    // `panelDamping` how quickly the motion dies away (lower = bouncier). Both
    // drive opening *and* closing, and are exposed in Settings ▸ Motion ▸
    // Panel open & close. Behavior on these properties is disabled entirely
    // under Game Mode / Reduce Motion, which snaps them.
    readonly property real panelSpring:        Settings.panelSpring
    readonly property real panelDamping:       Settings.panelDamping
    // Closing shares the same damping as opening. (Qt caps a spring's damping at
    // 1.0; at exactly 1.0 its integrator drops the velocity term and settles
    // monotonically, so a low damping now lets the island bob below the pill on
    // the way home too — that is intentional, matching the opening motion.)
    readonly property real panelCloseDamping:  Settings.panelDamping
    readonly property real panelMass:          1.0
    // Epsilon floor for the pixel-sized geometry springs (width/height/radius).
    readonly property real panelEpsilon:       0.25

    // ── Content reveal ───────────────────────────────────────────────────────
    // A panel's contents do not simply appear: its rows cascade in, each fading
    // and rising into place a beat after the one above. `contentStagger` is the
    // beat between rows, `contentRevealDelay` the lead-in after the panel is
    // asked to open, `contentRise` how far each row travels up and
    // `contentScaleFrom` the zoom the whole panel eases out from. Driven by
    // ui/widgets/ContentReveal.qml; collapsed to no-ops under Game Mode /
    // Reduce Motion.
    readonly property int  contentStagger:        motionOff ? 0 : Settings.contentStagger
    readonly property int  contentRevealDelay:    motionOff ? 0 : Settings.contentRevealDelay
    readonly property int  contentRise:           motionOff ? 0 : Settings.contentRise
    readonly property real contentScaleFrom:      motionOff ? 1.0 : Settings.contentScaleFrom
    // Each row's own fade/rise duration, and the beat the whole block waits out.
    readonly property int  contentRevealDuration: motionOff ? 0 : Settings.motionMedium

    // Named aliases kept for the existing call sites (and the README).
    readonly property int expandDuration:      motionSlow
    readonly property int fadeDuration:        motionFast

    // ── Tile detail morph ────────────────────────────────────────────────────
    // A Control Center tile's detail card grows straight out of the tile and
    // shrinks back into it (see DetailCard.qml). The geometry runs on
    // `expandDuration` so it matches the island; the dialog's contents hold off
    // for `detailContentDelay` so they are still hidden while the card is small
    // and only fade in once it has opened out. Set to 0 to fade them in with the
    // shape instead.
    readonly property int detailContentDelay:  motionOff ? 0 : 120

    // ── Lockscreen motion ────────────────────────────────────────────────────
    // The lock surface assembles itself on entry and disperses on a successful
    // unlock (see ui/lock/Lockscreen.qml). `lockRevealDuration` is the
    // entrance glide, `lockRevealStagger` delays the login cluster behind the
    // clock so the two settle one after the other, and `lockLeaveDuration` is
    // the dismissal the shell waits on before releasing the session lock.
    readonly property int lockRevealDuration:  Settings.lockRevealDuration
    readonly property int lockRevealStagger:   Settings.lockRevealStagger
    readonly property int lockLeaveDuration:   Settings.lockLeaveDuration
    // Lock surface metrics (see ui/lock/Lockscreen.qml).
    readonly property int  lockClockSize:      Settings.lockClockSize
    readonly property int  lockDateSize:       Settings.lockDateSize
    readonly property int  lockAvatarSize:     Settings.lockAvatarSize
    readonly property int  lockBlurMax:        Settings.lockBlurMax
    readonly property real lockDim:            Settings.lockDim

    // ── Workspace indicator ──────────────────────────────────────────────────
    // Live workspace data comes from Quickshell.Hyprland (see
    // WorkspaceIndicator.qml). The row's total width is matched to the status
    // icons on the other side of the pill (see shell.qml) so the collapsed bar
    // stays symmetric; these values set the capsule shapes and the fallback row
    // width, and are intentionally tight so the widget stays compact.
    //
    // Each workspace is a tall, soft-capped capsule, not a dot: the focused one
    // is a bright accent lens with a halo, the rest are dim accent capsules.
    // They share a width so the row reads as one set, and the focused capsule
    // is taller so it still stands out. `dotWidth` / `dotCircle` are that
    // shared width; the two heights are the resting and focused lengths.
    readonly property int dotWidth:            8      // focused lens width
    readonly property int dotHeightActive:     17     // focused lens height
    readonly property int dotCircle:           8      // unselected capsule width
    readonly property int dotHeightInactive:   15     // unselected capsule height
    readonly property int dotCircleHover:      10     // hovered capsule width
    readonly property int dotHeightHover:      17     // hovered capsule height
    readonly property int workspaceItemWidth:  9      // fallback per-workspace draw box
    readonly property int workspaceSpacing:    1      // gap between workspaces

    // Travelling lens. The glide time and the squash both grow with how far the
    // lens has to travel, so a hop to the next workspace is quick and light
    // while a jump across the row is a longer, stretchier glide.
    readonly property int  workspaceTravelBaseMs: 230   // glide time for a single-slot hop
    readonly property real workspaceTravelPerPx:  4.5   // extra ms per pixel travelled
    readonly property int  workspaceTravelMaxMs:  640   // cap for very long jumps
    readonly property real workspaceStretchRef:   28    // px travelled for a full stretch
    readonly property real workspaceStretchMin:   0.3   // floor: even short hops squash a little

    // Workspaces that stay visible even when Hyprland has no such workspace
    // yet (empty or uncreated), so the row keeps a stable width. Keep this in
    // sync with the persistent/workspace rules in your Hyprland config.
    readonly property var persistentWorkspaces: [1, 2, 3, 4, 5]

    // ── Overview (Alt+Tab window switcher) ───────────────────────────────────
    // The overview is just another island panel: opening it grows the island out
    // of its pill exactly like the Control Center (see ui/panels/Overview.qml).
    // Its width follows the number of workspace columns and its height the
    // tallest column, so it is exactly as big as the open windows need (never
    // clipping one); `overviewWidth` is only a fallback when the screen is
    // unknown.
    readonly property int  overviewWidth:          Settings.overviewWidth    // fallback island width if the screen is unknown
    // Each workspace column is a scaled mirror of its monitor: the body is the
    // screen at its true aspect ratio and every window is drawn where it really
    // is. `overviewWorkspaceWidth` is that mirror's width; its height follows
    // from the monitor's aspect. `overviewPad` is the bezel inside it, and
    // `overviewMinWindow` keeps tiny floating windows visible and clickable.
    readonly property int  overviewWorkspaceWidth: Settings.overviewMirrorWidth // displayed width of one mirrored workspace
    readonly property int  overviewPad:            4      // bezel inside a workspace mirror
    readonly property int  overviewMinWindow:      14     // smallest drawn window (px)
    readonly property int  overviewColumnGap:      20     // gap between workspace columns
    readonly property int  overviewCardGap:        12     // gap between header and mirror
    readonly property real overviewSelectedScale:  1.06   // zoom of the highlighted window

    // ── Panel shadow ─────────────────────────────────────────────────────────
    // A soft drop shadow drawn behind every island panel, matching the Hyprland
    // window shadow (`decoration:shadow` in hyprland.lua). Hyprland cannot shadow
    // layer-shell surfaces — the island is a full-screen, mostly-transparent
    // layer — so the shell draws the equivalent itself (ui/bar/PanelShadow).
    readonly property color shadowColor:   Qt.rgba(0.05, 0.04, 0.04, 0.62) // ~ your shadow colour
    readonly property real  shadowBlur:    0.45   // MultiEffect blur amount (0..1)
    readonly property int   shadowBlurMax: 24     // px — the shadow's softness

    // ── Typography ───────────────────────────────────────────────────────────
    // UI text uses SF Pro (Apple's system sans). Icons keep a Nerd Font so the
    // glyphs still resolve. Set a family to "" to fall back to the system
    // default font.
    readonly property string fontFamily:       Settings.fontFamily
    readonly property string iconFont:         Settings.iconFont
    // Proportional sans used by the lockscreen. Kept in step with the rest of
    // the shell so the clock matches the macOS look.
    readonly property string lockFont:         Settings.lockFont
    readonly property int clockSize:           Settings.clockSize
    // The clock is a single, shared element: collapsed it sits in the pill at
    // `clockSize`, and it grows to `clockExpandedSize` (with the date beside
    // it) as it settles into the Control Center header. `clockHeaderHeight` is
    // the slot the Control Center reserves for it at the top of the panel.
    readonly property int clockExpandedSize:   Settings.clockExpandedSize
    readonly property int clockDateSize:       Settings.clockDateSize
    readonly property int clockHeaderHeight:   Settings.clockHeaderHeight
    readonly property int iconSize:            Settings.iconSize
    readonly property int toggleIconSize:      17
    readonly property int titleSize:           Settings.titleSize
    readonly property int subtitleSize:        Settings.subtitleSize
    readonly property int sectionSize:         Settings.sectionSize
}
