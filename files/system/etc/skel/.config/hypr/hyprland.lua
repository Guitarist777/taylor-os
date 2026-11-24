-- TAYLOR OS: Hyprland, styled after her mockup "7 · Dock your way + mixer widget" (the TAYLOR theme).
-- This file is copied into her home when her account is made; edit ~/.config/hypr/hyprland.lua to change it.
-- Hyprland 0.57 reads only this Lua file (hyprland.conf is no longer read). Options: https://wiki.hypr.land/configuring/
-- TAYLOR-OS-DESKTOP (taylor-heal recognises this file as TAYLOR's by this line; keep it if you edit the file)

-- "highrr": the screen's highest refresh rate at its full size (2026-11-21: "preferred" is what the monitor names first,
-- usually 60 Hz; her 240 Hz monitor ran the whole desktop at 60). Settings will offer the others (her ask: refresh rate in Settings).
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = "auto",
})

-- What starts with the desktop
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    -- Qt's threaded render loop: with Qt's default one on her NVIDIA card the whole shell drew at 60 frames a second;
    -- the Windows key + Space dial measured 63 frames a second before, 250 after (2026-11-23, her 240 Hz screen)
    hl.exec_cmd("env QSG_RENDER_LOOP=threaded quickshell")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle -c /usr/share/taylor-os/hypridle.conf")   -- only locks before sleep; her timeout is the desktop's own
    hl.exec_cmd("/usr/libexec/taylor-cursor")   -- her cursor pick (Settings > Appearance > Cursor), everywhere
end)

-- Her cursors (her design pack): White by default, size 32; taylor-cursor above switches to her pick
hl.env("HYPRCURSOR_THEME", "TAYLOR-White")
hl.env("HYPRCURSOR_SIZE", "32")
hl.env("XCURSOR_THEME", "TAYLOR-White")
hl.env("XCURSOR_SIZE", "32")
hl.env("QT_QPA_PLATFORMTHEME", "kde")

hl.config({
    general = {
        gaps_in          = 0,
        gaps_out         = 0,
        border_size      = 1,
        col = {
            active_border   = "rgba(4fb386ee)",
            inactive_border = "rgba(ffffff14)",
        },
        layout           = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding         = 10,
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

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = "rgb(0f1010)",
        allow_session_lock_restore = true,   -- if her lock screen ever dies, the backup lock screen can take over (taylor-lock)
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
    },
})

-- Glass behind the dock, tray, clock and mixer (they draw their own see-through backgrounds)
for _, name in ipairs({ "taylor-dock", "taylor-tray", "taylor-clock" }) do
    hl.layer_rule({
        name         = "glass-" .. name,
        match        = { namespace = "^" .. name .. "$" },
        blur         = true,
        ignore_alpha = 0,
    })
end

-- Her Mixer window (the desktop shell draws it): a normal window that floats in the middle, not a tile
hl.window_rule({
    name  = "taylor-mixer-window",
    match = { class = "(?i).*quickshell.*", title = "^Mixer$" },
    float  = true,
    center = true,
})

hl.curve("calm", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "calm", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "calm", style = "popin 90%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 5, bezier = "calm" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "calm", style = "slide" })   -- windows slide fully across (her tour)
hl.animation({ leaf = "layers",     enabled = true, speed = 4, bezier = "calm", style = "fade" })

-- Keys. SUPER is the Windows key.
local mod = "SUPER"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + Space",  hl.dsp.exec_cmd("quickshell ipc call launcher toggle"))   -- her launcher (TAYLOR's dial)
hl.bind(mod .. " + E",      hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd("xdg-open https://"))
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mod .. " + L",      hl.dsp.exec_cmd("/usr/libexec/taylor-lock now"))   -- her lock screen (the dial)
hl.bind("XF86PowerOff",     hl.dsp.exec_cmd("quickshell ipc call power shutdown"), { locked = true })   -- her goodnight, then off
hl.bind(mod .. " + SHIFT + M", hl.dsp.exit())

-- Windows key + arrows snap the window (halves, quarters, the whole screen): see the windows file at the end.

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
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ==== TAYLOR-OS-SETTINGS (her Settings window and the volume and brightness ring, 2026-11-21) ====
-- (The window outline in her colour scheme is set by /usr/share/taylor-os/hypr/windows.lua, at the end of this file.)

-- Settings is one normal window: floating, a sensible size, centred (not full screen)
hl.window_rule({
    name   = "taylor-settings",
    match  = { class = "^org[.]quickshell$", title = "^Settings$" },
    float  = true,
    size   = "760 560",
    center = true,
})

-- Brightness keys: the screen's own brightness through DDC/CI (quickshell's Brightness.qml); when no monitor answers,
-- the keys do nothing and the ring stays away. Volume keys above show the ring by themselves (it follows PipeWire).
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("quickshell ipc call brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("quickshell ipc call brightness down"), { locked = true, repeating = true })
-- ==== end TAYLOR-OS-SETTINGS ====

-- Her windows and workspaces (her brief): edge-to-edge snaps, the dotted outline while dragging, the dock and clock
-- stepping away from a full-screen window, workspaces sliding, the outline in her colour scheme, less motion.
-- It lives in the system so every update reaches it. TAYLOR-WINDOWS (taylor-heal looks for this word)
taylor_fresh_binds = true   -- this file binds no arrow keys itself
local taylorOk, taylorErr = pcall(dofile, "/usr/share/taylor-os/hypr/windows.lua")
if not taylorOk then taylor_windows_error = tostring(taylorErr) end

-- Buttons on every window (her pick 2026-11-23, "on the window for each window"). Hyprland draws no title bars, and it
-- ignores an app's own minimise button (tested on her PC: no event at all). So Hyprland's own title bar plugin (hyprbars)
-- draws a slim bar on each window with minimise, full screen and close, and those three call TAYLOR's own (windows.lua):
-- minimise hides the window until the dock or the window switcher brings it back. Apps that draw their own bar
-- (browsers, Steam) get none, so there are never two.
pcall(function()
    hl.plugin.load("/usr/lib64/hyprland/libhyprbars.so")
    hl.config({ plugin = { hyprbars = {
        bar_height = 30, bar_padding = 10, bar_button_padding = 8, bar_buttons_alignment = "right",
        bar_color = "rgba(141917ff)", ["col.text"] = "rgba(c8cccaff)", bar_text_size = 11, bar_text_font = "Manrope",
        bar_text_align = "left", bar_part_of_window = true, bar_precedence_over_border = true,
    } } })
    local hb = hl.plugin.hyprbars
    -- right to left: close, full screen, minimise
    hb.add_button({ bg_color = "rgba(2a302dff)", fg_color = "rgba(edefeeff)", size = 16, icon = "×",
        action = [[hyprctl eval 'if taylor and taylor.closeActive then taylor.closeActive() end']] })
    hb.add_button({ bg_color = "rgba(2a302dff)", fg_color = "rgba(edefeeff)", size = 16, icon = "□",
        action = [[hyprctl eval 'if taylor and taylor.squareActive then taylor.squareActive() end']] })
    hb.add_button({ bg_color = "rgba(2a302dff)", fg_color = "rgba(edefeeff)", size = 16, icon = "–",
        action = [[hyprctl eval 'if taylor and taylor.minimize then taylor.minimize(hl.get_active_window()) end']] })
    hl.window_rule({ name = "taylor-own-bars", match = { class = [[^(firefox|org\.mozilla\.firefox|google-chrome|chromium.*|microsoft-edge.*|steam|Spotify|spotify|com\.spotify\.Client|com\.mitchellh\.ghostty)$]] }, ["hyprbars:no_bar"] = true })
end)

