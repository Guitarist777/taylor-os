-- TAYLOR OS login screen: a bare Hyprland that shows only her login scene (Quickshell, /usr/share/taylor-os/greeter)
-- and closes itself when the scene is done. Started by greetd as the greeter account, through /usr/libexec/taylor-greeter.
-- No keys of its own: everything typed goes to the scene.

hl.monitor({
    output   = "",
    mode     = "highrr",          -- the screen's highest refresh rate (2026-11-21: "preferred" was 60 Hz on her 240 Hz monitor, so the opening looked slow)
    position = "auto",
    scale    = "auto",
})

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/libexec/taylor-greeter-scene")
end)

-- her default cursor (White, size 32) on the login screen too
hl.env("HYPRCURSOR_THEME", "TAYLOR-White")
hl.env("HYPRCURSOR_SIZE", "32")
hl.env("XCURSOR_THEME", "TAYLOR-White")
hl.env("XCURSOR_SIZE", "32")

hl.config({
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = "rgb(0b0d0c)",
    },
    animations = {
        enabled = false,
    },
    input = {
        kb_layout    = "us",
        numlock_by_default = true,   -- the number pad types digits at once (2026-11-24: her login screen refused two passwords)
        follow_mouse = 1,
    },
})
