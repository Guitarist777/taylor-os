-- TAYLOR OS: Hyprland, styled after her mockup "7 · Dock your way + mixer widget" (the TAYLOR theme).
-- Hyprland 0.57 reads only this Lua file (the old hyprland.conf format was dropped). This copy is put in a new
-- account's home by /etc/skel, and /usr/libexec/taylor-desktop puts it in place for an account made before it existed.
-- TAYLOR-OS-DESKTOP (this line tells taylor-desktop the file is ours; keep it if you edit the file)

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- What starts with the desktop
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "kde")

hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 14,
        border_size = 2,
        col = {
            active_border   = "rgba(4fb386ee)",
            inactive_border = "rgba(ffffff14)",
        },
        layout = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding = 14,
        active_opacity   = 1.0,
        inactive_opacity = 0.97,
        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 3,
            color        = "rgba(00000073)",
        },
        blur = {
            enabled  = true,
            size     = 8,
            passes   = 2,
            vibrancy = 0.17,
        },
    },

    animations = { enabled = true },

    dwindle = {
        pseudotile     = true,
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(0f1010)",
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
    },
})

-- Calm motion
hl.curve("calm", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "calm", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "calm", style = "popin 90%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 5, bezier = "calm" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "calm", style = "slidefade 15%" })
hl.animation({ leaf = "layers",     enabled = true, speed = 4, bezier = "calm", style = "fade" })

-- Glass behind the dock, tray, clock and mixer (they draw their own see-through backgrounds)
for _, ns in ipairs({ "taylor-dock", "taylor-tray", "taylor-clock" }) do
    hl.layer_rule({ name = "glass-" .. ns, match = { namespace = "^" .. ns .. "$" }, blur = true, ignore_alpha = 0 })
end

-- Keys. SUPER is the Windows key.
local mod = "SUPER"
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + Space",  hl.dsp.exec_cmd("fuzzel"))
hl.bind(mod .. " + E",      hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd("xdg-open https://"))
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + L",      hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 5 do
    hl.bind(mod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume and media keys (and the headset's)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
