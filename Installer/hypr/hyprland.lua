-- Hyprland configuration entry point.
--
-- Everything is split into modules under configs/ and pulled in with require.
-- A module is a plain Lua file; whatever it returns is handed back to require.
-- Paths are resolved relative to this file, so require("configs/binds") loads
-- ~/.config/hypr/configs/binds.lua.

require("configs/monitors")    -- outputs, positions, scales
require("configs/programs")    -- the apps the binds launch
require("configs/autostart")   -- processes started with the session
require("configs/environment") -- environment variables
require("configs/appearance")  -- gaps, borders, decoration, layouts, misc
require("configs/animations")  -- curves and the animation tree
require("configs/input")       -- keyboard, mouse, touchpad, gestures
require("configs/binds")       -- keybindings
require("configs/windows")     -- workspace and window rules

-- Matugen colours, applied last so they win over the defaults above.
require("configs/theme")
