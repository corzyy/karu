-- WINDOWS AND WORKSPACES
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Bind workspaces to monitors:
-- 1, 3, 4, 5 -> DP-1 (right/main), 2 -> HDMI-A-1 (left)
hl.workspace_rule({ workspace = "1", monitor = "DP-1",     default = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1",     default = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-1",     default = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-1",     default = true })

-- Ignore maximize requests from all apps.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run window rule.
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Karu Settings app: a centred floating window at its designed size.
hl.window_rule({
    name  = "karu-settings",
    match = { title = "^(Karu Settings)$" },

    float  = true,
    center = true,
    size   = "1000 680",
})
