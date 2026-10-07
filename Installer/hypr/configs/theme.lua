-- MATUGEN THEME
-- Colours come from the InioX/matugen-themes hyprland-colors.lua template,
-- written to ~/.config/hypr/colors.lua whenever the theme changes (e.g. from
-- the Karu island, SUPER + H). Loaded last so it overrides the defaults above.

local colors = require("colors")

hl.config({
    general = {
        col = {
            -- Focused window: primary -> tertiary gradient.
            active_border = {
                colors = { colors.primary, colors.tertiary },
                angle  = 45,
            },
            -- Unfocused windows: muted outline.
            inactive_border = colors.outline,
        },
    },
    decoration = {
        shadow = {
            color = colors.surface_container_lowest,
        },
    },
})
