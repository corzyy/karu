-- AUTOSTART
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Quickshell "Dynamic Island" bar (personal config at ~/.config/karu).
-- `-n` makes a second invocation exit instead of stacking another bar, which
-- keeps Hyprland reloads from spawning duplicates.
hl.on("hyprland.start", function()
    hl.exec_cmd("karu start")
end)
