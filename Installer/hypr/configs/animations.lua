-- ANIMATIONS
-- Curves and the animation tree.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
--
-- The motion here mirrors the Karu Quickshell island (theme/Theme.qml) so the
-- compositor and the shell move as one language:
--
--   shell token      QML                         here
--   ----------------------------------------------------------------------
--   easeOut          Easing.OutCubic             settle      (bezier)
--   easeEmphasized   Easing.OutQuint             emphasized  (bezier)
--   easeSpring       Easing.OutBack (overshoot)  pop         (spring ~5%)
--
--   motionSnap    110 ms  -> 1.1
--   motionFast    170 ms  -> 1.7
--   motionMedium  260 ms  -> 2.6
--   motionSlow    300 ms  -> 3.0   (island grow / shrink)
--
-- `speed` is in deciseconds: speed = 1 is 100 ms.

-- Durations, straight from the shell's Motion block.
local fast   = 1.7   -- motionFast   - small size + opacity
local medium = 2.6   -- motionMedium - component trips & glides
local slow   = 3.0   -- motionSlow   - island grow / shrink

-- Bezier curves. `settle` is the shell's `easeOut`, used wherever something
-- should come to rest without overshoot; `emphasized` is `easeEmphasized`, the
-- long, very smooth glide the island opens with.
hl.curve("settle",     { type = "bezier", points = { {0.33, 1}, {0.68, 1} } })  -- Easing.OutCubic
hl.curve("emphasized", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })  -- Easing.OutQuint

-- The shell's `easeSpring` (Easing.OutBack with `springOvershoot` 1.05). A
-- spring at damping ~0.69 settles with the same ~5% pop, so windows grow and
-- shrink the way the island does.
hl.curve("pop",        { type = "spring", mass = 1, stiffness = 450, dampening = 29.3 })

-- Animation tree. Anything omitted inherits from its parent.
hl.animation({ leaf = "global",             enabled = true, speed = slow,   bezier = "emphasized" })

-- Border colour switch - matches the shell's fast colour transitions.
hl.animation({ leaf = "border",             enabled = true, speed = fast,   bezier = "settle" })

-- Windows: move/resize glides on the long curve; opening pops in, closing
-- settles back down quickly.
hl.animation({ leaf = "windows",            enabled = true, speed = medium, bezier = "emphasized" })
hl.animation({ leaf = "windowsIn",          enabled = true, speed = medium, spring = "pop",        style = "popin 87%" })
hl.animation({ leaf = "windowsOut",         enabled = true, speed = fast,   bezier = "settle",     style = "popin 87%" })

-- Fades sit on the fast step, like every opacity Behavior in the shell.
hl.animation({ leaf = "fade",               enabled = true, speed = medium, bezier = "settle" })
hl.animation({ leaf = "fadeIn",             enabled = true, speed = fast,   bezier = "settle" })
hl.animation({ leaf = "fadeOut",            enabled = true, speed = fast,   bezier = "settle" })

-- Layer shells.
hl.animation({ leaf = "layers",             enabled = true, speed = medium, bezier = "emphasized" })
hl.animation({ leaf = "layersIn",           enabled = true, speed = medium, bezier = "emphasized", style = "fade" })
hl.animation({ leaf = "layersOut",          enabled = true, speed = fast,   bezier = "settle",     style = "fade" })
hl.animation({ leaf = "fadeLayersIn",       enabled = true, speed = fast,   bezier = "settle" })
hl.animation({ leaf = "fadeLayersOut",      enabled = true, speed = fast,   bezier = "settle" })

-- Workspaces slide on the long curve, echoing the workspace lens that glides
-- across the shell's pill (theme/Theme.qml, workspaceTravel*).
hl.animation({ leaf = "workspaces",         enabled = true, speed = slow,   bezier = "emphasized", style = "slide" })
hl.animation({ leaf = "workspacesIn",       enabled = true, speed = slow,   bezier = "emphasized", style = "slide" })
hl.animation({ leaf = "workspacesOut",      enabled = true, speed = slow,   bezier = "emphasized", style = "slide" })

hl.animation({ leaf = "zoomFactor",         enabled = true, speed = medium, bezier = "settle" })
