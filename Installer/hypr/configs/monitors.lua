-- MONITORS
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- HDMI-A-1 on the left, DP-1 on the right, both maximized.
-- DP-1 supports up to 1920x1080@144 (from `hyprctl monitors`).
-- HDMI-A-1 max is 1920x1080@60 (its preferred mode).
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@144",
    position = "1920x0",
    scale    = 1,
})

-- Fallback for any other / unplugged monitors.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
