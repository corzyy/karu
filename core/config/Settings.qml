pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "ControlCatalog.js" as ControlCatalog

/**
 * Settings — the user-facing configuration behind the Settings app.
 *
 * Every value the Settings app can change lives here as an ordinary typed
 * property, so the rest of the shell (mostly `Theme.qml`) can bind to it and
 * react live. Values are persisted to `settings.json` next to `shell.qml`
 * (`~/.config/karu/settings.json`) and restored on the next launch.
 *
 * The Settings UI is data-driven and addresses values by their property name
 * (see ui/settings/Catalog.js). Because QML needs a static reference to
 * track a dependency, `get()` reads `revision` first; every change bumps
 * `revision`, which invalidates any binding that went through `get()` / `set()`.
 * The shell itself never uses `get()` — it binds to the properties directly, so
 * those stay fully reactive on their own.
 *
 * NOTE: the root is an `Item`, not a `QtObject`, so the `FileView` child below
 * can be declared through the default `data` property. It is never shown.
 */
Item {
    id: root

    // ── Bar & Island ─────────────────────────────────────────────────────────
    property int  topMargin:          8      // gap from the screen edge
    property int  collapsedWidth:     280    // pill width at rest
    property int  collapsedHeight:    40     // pill height at rest ("bar height")
    property int  collapsedPadding:   14     // content padding inside the pill
    property int  expandedWidth:      420    // width of an expanded panel
    property int  panelPadding:       16     // island edge padding
    property int  radiusPanel:        30     // expanded panel corner radius
    property int  radiusCard:         18     // card corner radius
    property int  radiusInner:        14     // inner element corner radius
    property bool notchMode:          false  // flush, rounded notch bar fused with media
    property bool showStatusIcons:    true   // Wi-Fi / Bluetooth / volume cluster
    property bool showMediaPlayer:    true   // the MPRIS companion beside the bar
    property bool mediaArtCircle:     true   // album art in the media circle

    // ── Clock & Date ─────────────────────────────────────────────────────────
    property int    clockSize:         15
    property int    clockExpandedSize: 26
    property int    clockDateSize:     12
    property int    clockHeaderHeight: 48
    property bool   use24Hour:         true
    property bool   showSeconds:       false
    property bool   barShowDate:       false  // show the date beside the bar clock too
    property string dateFormat:        "dddd, d MMMM"

    // ── Appearance ───────────────────────────────────────────────────────────
    property string fontFamily:        "SF Pro Display"
    property string lockFont:          "SF Pro Display"
    property string iconFont:          "Symbols Nerd Font"
    property int    iconSize:          15
    property int    titleSize:         13
    property int    subtitleSize:      11
    property int    sectionSize:       12
    property string accentOverride:    ""   // "" follows the active theme
    property bool   oled:              false // pure-black panel backgrounds (OLED displays)
    property bool   panelBlur:         false // frosted-glass panels over a blurred backdrop
    // Folder the Wallpapers tab scans. Empty = $KARU_WALLPAPER_DIR, else the
    // built-in default. Changing it rescans the list live.
    property string wallpaperDir:      ""

    // ── Motion ───────────────────────────────────────────────────────────────
    // Motion is chosen from a small set of named presets rather than tuned with
    // individual sliders; `motionPreset` is the selected id and the values below
    // are written from the matching entry in `motionPresets` (see
    // `applyMotionPreset`). `reduceMotion` still switches every animation off.
    property string motionPreset:      "balanced"
    property bool reduceMotion:        false
    property int  motionSnap:          110
    property int  motionFast:          165
    property int  motionMedium:        245
    property int  motionSlow:          290
    property real hoverScale:          1.05
    property real springOvershoot:     1.03
    // Panel open/close runs on a real physics spring (SpringAnimation) rather
    // than a fixed duration: `panelSpring` is the stiffness and `panelDamping`
    // how quickly it settles (lower = bouncier). See Theme.qml and shell.qml.
    property real panelSpring:         6.5
    property real panelDamping:        0.42
    // Staggered content entrance: each row of an opening panel fades and rises
    // into place, one after the next. `contentStagger` is the beat between rows,
    // `contentRevealDelay` the lead-in after the panel is asked to open,
    // `contentRise` how far each row travels and `contentScaleFrom` the zoom the
    // whole panel eases out from. See ui/widgets/ContentReveal.qml.
    property int  contentStagger:      48
    property int  contentRevealDelay:  52
    property int  contentRise:         13
    property real contentScaleFrom:    0.972

    /// The named motion feels offered in Settings ▸ Motion. Each bundles a value
    /// for every motion setting so picking one is a single, atomic change; the
    /// Settings preview (ui/settings/SettingMotionPresetRow.qml) animates the
    /// selected entry live. Keep `values` in sync with the declarations above.
    readonly property var motionPresets: [
        {
            id: "snappy", name: "Snappy",
            desc: "Quick and crisp, with almost no bounce.",
            values: {
                motionSnap: 80, motionFast: 120, motionMedium: 180, motionSlow: 220,
                hoverScale: 1.04, springOvershoot: 1.0,
                panelSpring: 9.0, panelDamping: 0.6,
                contentStagger: 30, contentRevealDelay: 30,
                contentRise: 10, contentScaleFrom: 0.985
            }
        },
        {
            id: "balanced", name: "Balanced",
            desc: "The default feel: lively but calm, with a touch of spring.",
            values: {
                motionSnap: 110, motionFast: 165, motionMedium: 245, motionSlow: 290,
                hoverScale: 1.05, springOvershoot: 1.03,
                panelSpring: 6.5, panelDamping: 0.42,
                contentStagger: 48, contentRevealDelay: 52,
                contentRise: 13, contentScaleFrom: 0.972
            }
        },
        {
            id: "smooth", name: "Smooth",
            desc: "Long, gentle glides that settle without overshoot.",
            values: {
                motionSnap: 140, motionFast: 220, motionMedium: 340, motionSlow: 420,
                hoverScale: 1.05, springOvershoot: 1.0,
                panelSpring: 5.0, panelDamping: 0.7,
                contentStagger: 70, contentRevealDelay: 90,
                contentRise: 20, contentScaleFrom: 0.95
            }
        },
        {
            id: "bouncy", name: "Bouncy",
            desc: "Springy, with a playful overshoot.",
            values: {
                motionSnap: 100, motionFast: 160, motionMedium: 260, motionSlow: 320,
                hoverScale: 1.07, springOvershoot: 1.06,
                panelSpring: 8.0, panelDamping: 0.45,
                contentStagger: 60, contentRevealDelay: 50,
                contentRise: 16, contentScaleFrom: 0.955
            }
        }
    ]

    /// Every setting a motion preset controls — used to apply one and to find
    /// the closest preset when the loaded file predates `motionPreset`.
    readonly property var motionValueKeys: [
        "motionSnap", "motionFast", "motionMedium", "motionSlow",
        "hoverScale", "springOvershoot", "panelSpring", "panelDamping",
        "contentStagger", "contentRevealDelay", "contentRise", "contentScaleFrom"
    ]

    // ── Launcher ─────────────────────────────────────────────────────────────
    property int launcherRows:      6
    property int launcherRowHeight: 34
    property int launcherIconSize:  24

    // ── Notifications ────────────────────────────────────────────────────────
    property int  notificationWidth:      300
    property int  notificationMinHeight:  48
    property int  notificationGap:        4
    property int  notificationTopGap:     8    // gap between the bar and the first banner
    property int  notificationMaxVisible: 4
    property int  notificationTimeout:    5
    property int  notificationMaxHistory: 50
    property bool doNotDisturb:           false

    // ── Control Center ───────────────────────────────────────────────────────
    // Width of the expanded Control Center panel. Kept separate from the shared
    // `expandedWidth` so the Control Center can be made wider (or narrower) on
    // its own without affecting the other panels. The grid re-derives its cell
    // size from this, so widening it spreads the same controls over more room.
    property int  controlPanelWidth:      420
    property int  toggleHeight:           56
    property int  searchHeight:           38
    // The Control Center is laid out on a grid. `controlColumns` is the grid's
    // width in cells (4..9, 7 default) and `controlLayout` the ordered list of
    // controls placed on it — each `{ type, col, row, w, h }` in grid cells. The
    // Settings app's Control Center page is a drag-and-drop editor for this
    // array (see ui/settings/ControlLayoutEditor.qml); the live panel renders
    // straight from it (ui/panels/ControlCenterPanel.qml). The registry of
    // control types lives in core/config/ControlCatalog.js.
    property int  controlColumns:         7
    property var  controlLayout:          ControlCatalog.defaultLayout()

    // ── Volume OSD ───────────────────────────────────────────────────────────
    // The island morphs into the volume panel whenever the default sink's volume
    // or mute changes (keyboard/media keys, the status-icon wheel, …).
    property bool volumeOsd:         true
    property int  volumeOsdWidth:    300    // width of the volume OSD panel
    property int  volumeOsdTimeout:  2      // seconds on screen after a change

    // ── Lock Screen ──────────────────────────────────────────────────────────
    property int  lockClockSize:      104
    property int  lockDateSize:       21
    property int  lockAvatarSize:     104
    property int  lockRevealDuration: 520
    property int  lockRevealStagger:  90
    property int  lockLeaveDuration:  360
    property int  lockBlurMax:        96
    property real lockDim:            0.38

    // ── System ───────────────────────────────────────────────────────────────
    property string barMonitor:   "DP-1"
    property int    overviewWidth: 880
    property int    overviewMirrorWidth: 280   // width of one workspace preview in the overview
    // Open the Settings app docked inside the island (as a panel) instead of as
    // a floating window. `karu settings` / SUPER + comma respect this.
    property bool   settingsDocked: false

    // ── Reactivity / persistence plumbing ────────────────────────────────────
    /// Bumped on every `set()` / load so generic `get()` bindings re-evaluate.
    property int revision: 0
    /// True while loading from disk, so writes are not triggered by the load.
    property bool loading: false

    readonly property var keys: [
        "topMargin", "collapsedWidth", "collapsedHeight", "collapsedPadding",
        "expandedWidth", "panelPadding", "radiusPanel", "radiusCard",
        "radiusInner", "notchMode", "showStatusIcons", "mediaArtCircle",
        "showMediaPlayer",
        "clockSize", "clockExpandedSize", "clockDateSize", "clockHeaderHeight",
        "use24Hour", "showSeconds", "barShowDate", "dateFormat",
        "fontFamily", "lockFont", "iconFont", "iconSize", "titleSize",
        "subtitleSize", "sectionSize", "accentOverride", "oled", "panelBlur",
        "wallpaperDir",
        "motionPreset", "reduceMotion", "motionSnap", "motionFast", "motionMedium", "motionSlow",
        "hoverScale", "springOvershoot",
        "panelSpring", "panelDamping",
        "contentStagger", "contentRevealDelay", "contentRise", "contentScaleFrom",
        "launcherRows", "launcherRowHeight", "launcherIconSize",
        "notificationWidth", "notificationMinHeight", "notificationGap",
        "notificationTopGap",
        "notificationMaxVisible", "notificationTimeout", "notificationMaxHistory",
        "doNotDisturb",
        "controlPanelWidth", "toggleHeight", "searchHeight",
        "controlColumns", "controlLayout",
        "volumeOsd", "volumeOsdWidth", "volumeOsdTimeout",
        "lockClockSize", "lockDateSize", "lockAvatarSize", "lockRevealDuration",
        "lockRevealStagger", "lockLeaveDuration", "lockBlurMax", "lockDim",
        "barMonitor", "overviewWidth", "overviewMirrorWidth", "settingsDocked"
    ]

    /// Factory defaults, one per setting — the values the declarative properties
    /// above start at. Used by the "revert" button on every slider to restore a
    /// value without editing the file. Keep in sync with the declarations.
    readonly property var defaults: ({
        topMargin: 8, collapsedWidth: 280, collapsedHeight: 40,
        collapsedPadding: 14, expandedWidth: 420, panelPadding: 16,
        radiusPanel: 30, radiusCard: 18, radiusInner: 14,
        notchMode: false, showStatusIcons: true, mediaArtCircle: true,
        showMediaPlayer: true,

        clockSize: 15, clockExpandedSize: 26, clockDateSize: 12,
        clockHeaderHeight: 48, use24Hour: true, showSeconds: false,
        barShowDate: false, dateFormat: "dddd, d MMMM",

        fontFamily: "SF Pro Display", lockFont: "SF Pro Display",
        iconFont: "Symbols Nerd Font", iconSize: 15, titleSize: 13,
        subtitleSize: 11, sectionSize: 12, accentOverride: "", oled: false,
        panelBlur: false, wallpaperDir: "",

        motionPreset: "balanced",
        reduceMotion: false, motionSnap: 110, motionFast: 165,
        motionMedium: 245, motionSlow: 290,
        hoverScale: 1.05, springOvershoot: 1.03,
        panelSpring: 6.5, panelDamping: 0.42,
        contentStagger: 48, contentRevealDelay: 52,
        contentRise: 13, contentScaleFrom: 0.972,

        launcherRows: 6, launcherRowHeight: 34, launcherIconSize: 24,

        notificationWidth: 300, notificationMinHeight: 48, notificationGap: 4,
        notificationTopGap: 8,
        notificationMaxVisible: 4, notificationTimeout: 5,
        notificationMaxHistory: 50, doNotDisturb: false,

        toggleHeight: 56, searchHeight: 38,
        controlPanelWidth: 420,
        controlColumns: 7, controlLayout: ControlCatalog.defaultLayout(),
        volumeOsd: true, volumeOsdWidth: 300, volumeOsdTimeout: 2,

        lockClockSize: 104, lockDateSize: 21, lockAvatarSize: 104,
        lockRevealDuration: 520, lockRevealStagger: 90,
        lockLeaveDuration: 360, lockBlurMax: 96, lockDim: 0.38,

        barMonitor: "DP-1", overviewWidth: 880, overviewMirrorWidth: 280,
        settingsDocked: false
    })

    /// True when a setting differs from its default. Reads `revision` so a
    /// binding on it re-evaluates when the value changes.
    function isModified(key) {
        var r = revision
        if (defaults[key] === undefined)
            return false
        return root[key] !== defaults[key]
    }

    /// Restore one setting to its factory default.
    function reset(key) {
        if (defaults[key] !== undefined)
            set(key, defaults[key])
    }

    /// The motion preset record for `id`, or null.
    function motionPresetById(id) {
        for (var i = 0; i < motionPresets.length; i++)
            if (motionPresets[i].id === id)
                return motionPresets[i]
        return null
    }

    /// Apply a motion preset: remember its id and write every value it bundles.
    function applyMotionPreset(id) {
        var p = motionPresetById(id)
        if (!p)
            return
        root.motionPreset = p.id
        for (var k in p.values)
            root[k] = p.values[k]
        revision++
        if (!loading)
            saveTimer.restart()
    }

    /// The preset whose values are closest to the current ones — used when the
    /// loaded file predates `motionPreset`, so the selected chip matches the
    /// shell even for hand-tuned values.
    function nearestMotionPreset() {
        var best = motionPresets.length > 0 ? motionPresets[0].id : ""
        var bestScore = Infinity
        for (var i = 0; i < motionPresets.length; i++) {
            var p = motionPresets[i]
            var score = 0
            for (var j = 0; j < motionValueKeys.length; j++) {
                var k = motionValueKeys[j]
                var span = Math.max(1, Math.abs(p.values[k]))
                score += Math.abs(root[k] - p.values[k]) / span
            }
            if (score < bestScore) {
                bestScore = score
                best = p.id
            }
        }
        return best
    }

    /// Read one value by name (tracks `revision`, so this is binding-safe).
    function get(key) {
        var r = revision
        return root[key]
    }

    /// Write one value by name; the property change re-themes the shell and a
    /// debounced save writes it out.
    function set(key, value) {
        root[key] = value
        revision++
        if (!loading)
            saveTimer.restart()
    }

    // ── Persistence ──────────────────────────────────────────────────────────
    FileView {
        id: stateFile
        path: Quickshell.shellDir + "/settings.json"
        blockLoading: true
        blockWrites: false
        printErrors: false
    }

    Timer {
        id: saveTimer
        interval: 250
        repeat: false
        onTriggered: root.save()
    }

    function save() {
        if (loading)
            return
        var obj = {}
        for (var i = 0; i < keys.length; i++)
            obj[keys[i]] = root[keys[i]]
        try { stateFile.setText(JSON.stringify(obj, null, 2)) } catch (e) { /* best effort */ }
    }

    function load() {
        loading = true
        var saved = ""
        try { saved = String(stateFile.text()) } catch (e) { saved = "" }
        if (saved.length > 0) {
            try {
                var obj = JSON.parse(saved)
                for (var i = 0; i < keys.length; i++) {
                    var k = keys[i]
                    if (obj[k] !== undefined)
                        root[k] = obj[k]
                }
                // A file written before presets existed (or with a stale id)
                // gets the closest match so the selected chip reflects the shell.
                if (motionPresetById(root.motionPreset) === null)
                    root.motionPreset = nearestMotionPreset()
            } catch (e) { /* ignore a corrupt file */ }
        }
        revision++
        loading = false
    }

    Component.onCompleted: load()
}
