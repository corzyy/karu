-- INPUT
-- See https://wiki.hypr.land/Configuring/Basics/Variables/ (input)

hl.config({
    input = {
        kb_layout = "de",

        follow_mouse = 1,

        sensitivity   = 0, -- -1.0 - 1.0, 0 means no modification.
        accel_profile = "flat",

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Per-device config for the Logitech Pro X Rapid.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({
    name          = "logitech-pro-x-rapid-mouse",
    accel_profile = "flat",
})
