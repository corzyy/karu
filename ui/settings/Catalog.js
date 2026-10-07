.pragma library

// The Settings app's page model. Plain data only — no QML references — so it can
// be imported anywhere. `SettingsPage.qml` renders it and addresses values in
// the `Settings` singleton by the string `key` on each row.
//
// Pages are grouped into `sections` for the sidebar: each page names its
// `section` and the `sections` list fixes their order and labels. Search walks
// every page regardless of section (see `pageMatches`).
//
// Inside a page, `groups` are the labelled sub-sections the page lays out as
// separate cards (side by side where the width allows — see SettingsPage.qml).
// A group that contains a `theme`, `accent` or `controllayout` row is treated
// as full-width, because those rows need the whole column.
//
// Row types:
//   switch   toggle a bool setting
//   slider   numeric setting, shown as "value px/ms/…" with a track
//   text     free text setting
//   action   a button that runs `action` (see SettingsPage.qml)
//   info     read-only label; `value` supports $config / $settings tokens
//   theme    the theme carousel (Appearance)
//   accent   the accent-colour swatches (Appearance)
//   gamemode the live Game Mode switch (System)
//   motionpreset the motion-feel picker with a live preview (Motion)
//   controllayout the Control Center drag-and-drop editor

/// Sidebar sections, in display order. A page's `section` names one of these.
var sections = [
    { key: "appearance", label: "Appearance" },
    { key: "features",   label: "Features" },
    { key: "system",     label: "System" }
]

var pages = [
    {
        key: "bar",
        section: "appearance",
        name: "Bar & Island",
        icon: "\uF2D0", // nf-fa-window_maximize
        desc: "Shape and size of the island, the pill, and the bar.",
        groups: [
            {
                label: "Geometry",
                rows: [
                    { type: "slider", key: "collapsedHeight", title: "Bar height", min: 28, max: 80, step: 1, suffix: " px" },
                    { type: "slider", key: "collapsedWidth", title: "Collapsed width", min: 180, max: 420, step: 1, suffix: " px" },
                    { type: "slider", key: "expandedWidth", title: "Expanded width", min: 320, max: 640, step: 1, suffix: " px" },
                    { type: "slider", key: "topMargin", title: "Gap from screen edge", min: 0, max: 40, step: 1, suffix: " px" },
                    { type: "slider", key: "collapsedPadding", title: "Pill padding", min: 0, max: 30, step: 1, suffix: " px" },
                    { type: "slider", key: "panelPadding", title: "Island padding", min: 0, max: 40, step: 1, suffix: " px" }
                ]
            },
            {
                label: "Corner radius",
                rows: [
                    { type: "slider", key: "radiusPanel", title: "Expanded panel", min: 0, max: 48, step: 1, suffix: " px" },
                    { type: "slider", key: "radiusCard", title: "Cards", min: 0, max: 32, step: 1, suffix: " px" },
                    { type: "slider", key: "radiusInner", title: "Inner elements", min: 0, max: 24, step: 1, suffix: " px" }
                ]
            },
            {
                label: "Bar style",
                rows: [
                    { type: "switch", key: "notchMode", title: "Notch mode", subtitle: "Rounded, flush bar that fuses with the media island." }
                ]
            },
            {
                label: "Components",
                rows: [
                    { type: "switch", key: "showStatusIcons", title: "Status icons", subtitle: "Wi-Fi, Bluetooth and volume in the pill." },
                    { type: "switch", key: "showMediaPlayer", title: "Media player", subtitle: "Show the media player pill beside the bar." },
                    { type: "switch", key: "mediaArtCircle", title: "Album art circle", subtitle: "Show the cover art in the media circle." }
                ]
            }
        ]
    },
    {
        key: "appearance",
        section: "appearance",
        name: "Appearance",
        icon: "\uEFCC", // nf-fa-palette
        desc: "Theme, accent colour and typography.",
        groups: [
            {
                label: "Theme",
                rows: [
                    { type: "theme" },
                    { type: "switch", key: "oled", title: "OLED mode", subtitle: "Black shell background with dark-grey tiles, for OLED displays." },
                    { type: "switch", key: "panelBlur", title: "Panel blur", subtitle: "Frosted-glass panels over a blurred, translucent backdrop." }
                ]
            },
            {
                label: "Accent colour",
                rows: [
                    { type: "accent" }
                ]
            },
            {
                label: "Wallpaper",
                rows: [
                    { type: "text", key: "wallpaperDir", title: "Wallpaper folder", subtitle: "Folder the Wallpapers tab scans. Empty = built-in default." }
                ]
            },
            {
                label: "Fonts",
                rows: [
                    { type: "text", key: "fontFamily", title: "Interface font" },
                    { type: "text", key: "iconFont", title: "Icon font" }
                ]
            },
            {
                label: "Type & icons",
                rows: [
                    { type: "slider", key: "titleSize", title: "Title size", min: 10, max: 20, step: 1, suffix: " px" },
                    { type: "slider", key: "subtitleSize", title: "Subtitle size", min: 9, max: 16, step: 1, suffix: " px" },
                    { type: "slider", key: "sectionSize", title: "Section labels", min: 9, max: 18, step: 1, suffix: " px" },
                    { type: "slider", key: "iconSize", title: "Icon size", min: 10, max: 24, step: 1, suffix: " px" }
                ]
            }
        ]
    },
    {
        key: "clock",
        section: "appearance",
        name: "Clock & Date",
        icon: "\uF017", // nf-fa-clock_o
        desc: "Clock and date shown in the bar and the Control Center.",
        groups: [
            {
                label: "Clock",
                rows: [
                    { type: "slider", key: "clockSize", title: "Size in the bar", min: 10, max: 24, step: 1, suffix: " px" },
                    { type: "slider", key: "clockExpandedSize", title: "Size when expanded", min: 20, max: 56, step: 1, suffix: " px" },
                    { type: "slider", key: "clockDateSize", title: "Date size", min: 9, max: 20, step: 1, suffix: " px" },
                    { type: "slider", key: "clockHeaderHeight", title: "Control Center header", min: 48, max: 120, step: 1, suffix: " px" }
                ]
            },
            {
                label: "Format",
                rows: [
                    { type: "switch", key: "use24Hour", title: "24-hour time" },
                    { type: "switch", key: "showSeconds", title: "Show seconds" },
                    { type: "switch", key: "barShowDate", title: "Date in the bar", subtitle: "Show the date beside the clock in the bar too." },
                    { type: "text", key: "dateFormat", title: "Date format", subtitle: "Qt date pattern, e.g. dddd, d MMMM." }
                ]
            }
        ]
    },
    {
        key: "motion",
        section: "appearance",
        name: "Motion",
        icon: "\uF01E", // nf-fa-refresh
        desc: "How the shell animates as it expands and reacts.",
        groups: [
            {
                label: "Preset",
                rows: [
                    { type: "motionpreset", title: "Motion preset", subtitle: "Pick a ready-made feel \u2014 the preview animates as you choose." }
                ]
            },
            {
                label: "General",
                rows: [
                    { type: "switch", key: "reduceMotion", title: "Reduce motion", subtitle: "Switch off every shell animation." }
                ]
            }
        ]
    },
    {
        key: "launcher",
        section: "features",
        name: "Launcher",
        icon: "\uF00A", // nf-fa-th
        desc: "The application launcher grid and its rows.",
        groups: [
            {
                label: "Grid",
                rows: [
                    { type: "slider", key: "launcherRows", title: "Visible rows", min: 3, max: 12, step: 1 },
                    { type: "slider", key: "launcherRowHeight", title: "Row height", min: 24, max: 56, step: 1, suffix: " px" }
                ]
            },
            {
                label: "Icons",
                rows: [
                    { type: "slider", key: "launcherIconSize", title: "Icon size", min: 16, max: 40, step: 1, suffix: " px" }
                ]
            }
        ]
    },
    {
        key: "notifications",
        section: "features",
        name: "Notifications",
        icon: "\uF0F3", // nf-fa-bell
        desc: "Banner stack, history, and Do Not Disturb.",
        groups: [
            {
                label: "Behaviour",
                rows: [
                    { type: "switch", key: "doNotDisturb", title: "Do Not Disturb", subtitle: "Silence banners; keep them in the history." }
                ]
            },
            {
                label: "Banners",
                rows: [
                    { type: "slider", key: "notificationWidth", title: "Width", min: 260, max: 480, step: 2, suffix: " px" },
                    { type: "slider", key: "notificationMinHeight", title: "Minimum height", min: 48, max: 100, step: 1, suffix: " px" },
                    { type: "slider", key: "notificationGap", title: "Gap between banners", min: 0, max: 20, step: 1, suffix: " px" },
                    { type: "slider", key: "notificationTopGap", title: "Gap below bar", min: 0, max: 40, step: 1, suffix: " px" },
                    { type: "slider", key: "notificationMaxVisible", title: "Maximum visible", min: 1, max: 8, step: 1 },
                    { type: "slider", key: "notificationTimeout", title: "Timeout", min: 1, max: 30, step: 1, suffix: " s" }
                ]
            },
            {
                label: "History",
                rows: [
                    { type: "slider", key: "notificationMaxHistory", title: "History size", min: 0, max: 200, step: 5 }
                ]
            }
        ]
    },
    {
        key: "control",
        section: "features",
        name: "Control Center",
        icon: "\uF1DE", // nf-fa-sliders
        desc: "Arrange, resize, add and remove the controls.",
        groups: [
            {
                label: "",
                rows: [
                    { type: "controllayout" }
                ]
            },
            {
                label: "Grid",
                rows: [
                    { type: "slider", key: "controlPanelWidth", title: "Panel width", min: 320, max: 760, step: 2, suffix: " px" },
                    { type: "slider", key: "toggleHeight", title: "Control height", min: 40, max: 80, step: 1, suffix: " px" }
                ]
            },
            {
                label: "Volume OSD",
                rows: [
                    { type: "switch", key: "volumeOsd", title: "Volume OSD", subtitle: "Morph the island into a volume panel on a volume change." },
                    { type: "slider", key: "volumeOsdWidth", title: "OSD width", min: 200, max: 420, step: 2, suffix: " px" },
                    { type: "slider", key: "volumeOsdTimeout", title: "OSD timeout", min: 1, max: 10, step: 1, suffix: " s" }
                ]
            }
        ]
    },
    {
        key: "lock",
        section: "system",
        name: "Lock Screen",
        icon: "\uF023", // nf-fa-lock
        desc: "The macOS-style lock surface.",
        groups: [
            {
                label: "Layout",
                rows: [
                    { type: "slider", key: "lockClockSize", title: "Clock size", min: 60, max: 160, step: 2, suffix: " px" },
                    { type: "slider", key: "lockDateSize", title: "Date size", min: 12, max: 40, step: 1, suffix: " px" },
                    { type: "slider", key: "lockAvatarSize", title: "Avatar size", min: 60, max: 160, step: 2, suffix: " px" },
                    { type: "text", key: "lockFont", title: "Clock font" }
                ]
            },
            {
                label: "Wallpaper",
                rows: [
                    { type: "slider", key: "lockBlurMax", title: "Blur", min: 0, max: 200, step: 4 },
                    { type: "slider", key: "lockDim", title: "Dim", min: 0, max: 0.8, step: 0.01, decimals: 2, suffix: "" }
                ]
            },
            {
                label: "Motion",
                rows: [
                    { type: "slider", key: "lockRevealDuration", title: "Reveal duration", min: 0, max: 1200, step: 20, suffix: " ms" },
                    { type: "slider", key: "lockRevealStagger", title: "Login stagger", min: 0, max: 400, step: 10, suffix: " ms" },
                    { type: "slider", key: "lockLeaveDuration", title: "Leave duration", min: 0, max: 1000, step: 20, suffix: " ms" }
                ]
            }
        ]
    },
    {
        key: "system",
        section: "system",
        name: "System",
        icon: "\uF013", // nf-fa-cog
        desc: "Monitor placement, overview, and shell actions.",
        groups: [
            {
                label: "Display",
                rows: [
                    { type: "text", key: "barMonitor", title: "Bar monitor", subtitle: "Wayland output name, e.g. DP-1. Empty = first." },
                    { type: "slider", key: "overviewWidth", title: "Overview width", min: 600, max: 1400, step: 20, suffix: " px" },
                    { type: "slider", key: "overviewMirrorWidth", title: "Overview preview width", min: 180, max: 420, step: 10, suffix: " px" }
                ]
            },
            {
                label: "Behaviour",
                rows: [
                    { type: "switch", key: "settingsDocked", title: "Docked settings", subtitle: "Open the Settings app docked in the island instead of a floating window." },
                    { type: "gamemode", title: "Game Mode", subtitle: "Flat, animation-free, edge-to-edge bar." }
                ]
            },
            {
                label: "Shell",
                rows: [
                    { type: "action", action: "restart", title: "Restart shell", subtitle: "Reload every QML file." },
                    { type: "action", action: "openconfig", title: "Open config folder", subtitle: "Reveal the Karu config directory." }
                ]
            },
            {
                label: "About",
                rows: [
                    { type: "info", title: "Config directory", value: "$config" },
                    { type: "info", title: "Settings file", value: "$settings" }
                ]
            }
        ]
    }
]

/// The page with a given key, or the first page.
function pageByKey(key) {
    for (var i = 0; i < pages.length; i++)
        if (pages[i].key === key)
            return pages[i]
    return pages[0]
}

/// True when a page (its name, or any title/subtitle of its rows) matches the
/// lower-cased query `q`. An empty query matches every page.
function pageMatches(page, q) {
    if (q === "")
        return true
    if (page.name.toLowerCase().indexOf(q) !== -1)
        return true
    for (var g = 0; g < page.groups.length; g++) {
        var grp = page.groups[g]
        for (var r = 0; r < grp.rows.length; r++) {
            var row = grp.rows[r]
            var hay = (row.title + " " + (row.subtitle || "")).toLowerCase()
            if (hay.indexOf(q) !== -1)
                return true
        }
    }
    return false
}
