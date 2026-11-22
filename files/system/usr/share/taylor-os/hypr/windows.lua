-- TAYLOR OS: her windows and workspaces (her build brief, "Windows" and "Workspaces"; her design tour, parts 6 and 7).
-- Lives in the system (/usr/share/taylor-os/hypr) so every update reaches it; her ~/.config/hypr/hyprland.lua runs it
-- with dofile() at its end (taylor-heal adds that line to an older TAYLOR file). It changes only what it names here.
--
-- What she gets:
--   * Windows float, near-black (each app draws its own inside), no title bar from Hyprland, a thin green outline on
--     the focused window only (the others keep the tour's faint line), rounded corners while floating.
--   * Snaps are edge to edge with no gaps, over the dock's strip too: Windows key + Left / Right = left / right half,
--     then + Up / Down = the quarter above / below (as on Windows); Windows key + Up = the whole screen (the window
--     keeps its own controls; the dock and the clock step away); Windows key + Down or + V = back to floating.
--     Windows key + F = true full screen (the app is told, so a video or game goes full screen too).
--   * Dragging a window (by its own title bar, or anywhere with the Windows key held) to an edge or a corner shows a
--     dotted outline of where it will go (drawn by the desktop, SnapPreview.qml); letting go snaps it there. Dragging a
--     snapped window away gives it back its floating size.
--   * Settings and Files open as a plain maximise (inside the dock's strip); no other app maximises.
--   * When a snapped or full-screen window covers the dock or the clock, they step away; the pointer at the very top
--     edge brings the dock back, at the very bottom edge the clock and tray (the desktop draws them, Covers.qml).
--   * Workspaces slide fully across (the sky's parallax is the desktop's, Sky.qml).
--   * Less motion (her Settings switch, or the system's): windows stop moving and only fade; workspaces fade.
-- The desktop (Quickshell) and this file talk through Hyprland: this file sends "custom>>taylorwin ..." events, the
-- desktop calls taylor.look(...) / taylor.push() with "hyprctl eval".

taylor = taylor or {}
local T = taylor
T.snaps = T.snaps or {}        -- window address -> { zone = "L"|..., fx, fy, fw, fh } (its floating place)
T.logs = T.logs or {}
T.version = "2026-11-21"

local function log(s)
    T.logs[#T.logs + 1] = s
    if #T.logs > 60 then table.remove(T.logs, 1) end
end
function T.tail() return table.concat(T.logs, "\n") end

local function xy(v)
    if type(v) == "table" then return (v.x or v[1] or 0), (v.y or v[2] or 0) end
    return 0, 0
end
local function dsp(d)
    local ok, err = pcall(hl.dispatch, d)
    if not ok then log("dispatch failed: " .. tostring(err)) end
end
-- a monitor's box in layout coordinates
local function mbox(m)
    local s = (m and m.scale and m.scale > 0) and m.scale or 1
    return m.x or 0, m.y or 0, math.floor((m.width or 0) / s + 0.5), math.floor((m.height or 0) / s + 0.5)
end
local function emit(s) pcall(hl.dispatch, hl.dsp.event("taylorwin " .. s)) end
local function byAddr(a)
    if not a then return nil end
    if a:sub(1, 2) ~= "0x" then a = "0x" .. a end
    local ok, w = pcall(hl.get_window, "address:" .. a)
    return ok and w or nil
end

-- ---------------------------------------------------------------- the look
-- TAYLOR scheme ---------------------------------------------------------------------------------------------------
-- The window outline follows her colour scheme (Theme.qml has the same table). At load it is read from her settings
-- file, and read again every two seconds (only when the file changed does anything happen), so a change in Settings
-- needs no reload. The desktop also calls taylor.look(accent, light, still, systemStill) when its own colours change,
-- and it alone knows the system's "no animations" setting (systemStill). (The settings helper changes only
-- settings.json; this is the one place Hyprland's colours are set.)
T.accents = { taylor = "4fb386", quiet = "3f6152", night = "8fb5a1", slate = "8fb5a1" }
local function readText()
    local ok, txt = pcall(function()
        local home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
        local f = io.open(home .. "/taylor-os/settings.json", "r")
        if not f then return nil end
        local t = f:read("*a"); f:close(); return t
    end)
    if not ok or type(txt) ~= "string" then return nil end
    return txt
end
local function parseSettings(txt)
    if not txt then return nil end
    local scheme = txt:match('"scheme"%s*:%s*"(%w+)"') or "taylor"
    if not T.accents[scheme] then scheme = "taylor" end
    local level = tonumber(txt:match('"slateLevel"%s*:%s*([%d%.]+)') or "0.19") or 0.19
    local still = txt:match('"reduceMotion"%s*:%s*true') ~= nil
    local light = scheme == "quiet" or (scheme == "slate" and level > 0.55)
    return { accent = T.accents[scheme], light = light, still = still }
end

function T.motion(still)
    T.still = still and true or false
    if T.still then
        hl.animation({ leaf = "windows",    enabled = false, speed = 4, bezier = "calm" })
        hl.animation({ leaf = "fade",       enabled = true,  speed = 4, bezier = "calm" })
        hl.animation({ leaf = "workspaces", enabled = true,  speed = 4, bezier = "calm", style = "fade" })
        T.ws_style = "fade"
        hl.animation({ leaf = "layers",     enabled = true,  speed = 4, bezier = "calm", style = "fade" })
    else
        hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "calm", style = "popin 90%" })
        hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "calm", style = "popin 90%" })
        hl.animation({ leaf = "fade",       enabled = true, speed = 5, bezier = "calm" })
        -- her tour: windows slide fully across (the whole screen width), nothing fades
        hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "calm", style = "slide" })
        T.ws_style = "slide"
        hl.animation({ leaf = "layers",     enabled = true, speed = 4, bezier = "calm", style = "fade" })
    end
end

function T.look(accent, light, still, systemStill)
    if systemStill ~= nil then T.sysStill = systemStill and true or false end
    accent = tostring(accent or "4fb386"):gsub("^#", ""):lower():sub(1, 6)
    if not accent:match("^%x%x%x%x%x%x$") then accent = "4fb386" end
    hl.config({ general = { col = {
        active_border   = "rgba(" .. accent .. "ff)",
        -- the tour's faint line round the other windows (Theme.line): not an outline in her colour
        inactive_border = light and "rgba(1c1c1a1a)" or "rgba(ffffff14)",
    } } })
    if still ~= nil and (still and true or false) ~= T.still then T.motion(still) end
    T.accent = accent
    log("look " .. accent .. (light and " light" or " dark") .. (T.still and " still" or ""))
    return "ok"
end
-- end of TAYLOR scheme ----------------------------------------------------------------------------------------------

hl.curve("calm", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.config({
    general = {
        border_size      = 1,            -- her tour: a thin outline
        resize_on_border = true,
        gaps_in          = 0,
        gaps_out         = 0,
    },
    decoration = {
        rounding = 10,                   -- floating windows (a snapped one has square corners)
    },
    layers = {
        allow_new_top_layers_over_existing_fullscreen = true,   -- the dock and clock come back over a full-screen window
    },
})
do
    T.settingsText = readText()
    local s = parseSettings(T.settingsText) or { accent = "4fb386", light = false, still = false }
    T.still = nil
    T.motion(s.still)
    T.look(s.accent, s.light, s.still)
end

-- the dotted drag outline appears at once (the layers' fade would hide most of a short drag)
hl.layer_rule({ name = "taylor-snap-instant", match = { namespace = "^taylor-snap$" }, no_anim = true })

-- ---------------------------------------------------------------- windows open floating
hl.window_rule({ name = "taylor-float", match = { class = ".*" }, float = true, center = true })
-- only Settings and Files maximise (her brief); every other app's own maximise request is ignored
hl.window_rule({ name = "taylor-no-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "taylor-maximize-files",
    match = { class = [[^(org\.kde\.dolphin|dolphin|systemsettings|org\.kde\.systemsettings)$]] }, maximize = true })
-- Her TaylorOS Settings is "one normal window (not full screen)" (her brief's Settings row and the tour): it floats at
-- its own size, centred (hyprland.lua's taylor-settings rule), so it is not maximised here (coordinator, 2026-11-21).

-- ---------------------------------------------------------------- snaps
-- zone boxes on a monitor: edge to edge, no gaps (the halves meet exactly in the middle)
function T.rect(zone, m)
    local x, y, W, H = mbox(m)
    local hw, hh = math.floor(W / 2), math.floor(H / 2)
    local r = ({
        L = { x, y, hw, H },           R = { x + hw, y, W - hw, H },      F = { x, y, W, H },
        TL = { x, y, hw, hh },         TR = { x + hw, y, W - hw, hh },
        BL = { x, y + hh, hw, H - hh }, BR = { x + hw, y + hh, W - hw, H - hh },
    })[zone]
    return r
end

local function props(w, snapped, zone)
    dsp(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = snapped and "0" or "10" }))
    dsp(hl.dsp.window.set_prop({ window = w, prop = "no_shadow", value = snapped and "1" or "0" }))
    -- whole screen: no outline at all (her tour); halves and quarters keep the thin one
    dsp(hl.dsp.window.set_prop({ window = w, prop = "border_size", value = (zone == "F") and "0" or "1" }))
end

local function place(w, x, y, ww, hh)
    dsp(hl.dsp.window.resize({ window = w, x = ww, y = hh }))
    dsp(hl.dsp.window.move({ window = w, x = x, y = y }))
end

-- the zone a window is in now ("none" when it is floating or was moved off its snap)
function T.zoneOf(w)
    if not w then return "none" end
    local s = T.snaps[w.address]
    if not s or not s.zone then return "none" end
    return s.zone
end

function T.snap(zone, w)
    w = w or hl.get_active_window()
    if not w then return "no window" end
    if zone == nil or zone == "none" then return T.unsnap(w) end
    local m = w.monitor or hl.get_active_monitor()
    local r = T.rect(zone, m)
    if not r then return "no such zone" end
    if (w.fullscreen or 0) ~= 0 then dsp(hl.dsp.window.fullscreen({ window = w, action = "unset" })) end
    if not w.floating then dsp(hl.dsp.window.float({ window = w, action = "enable" })) end
    local s = T.snaps[w.address]
    if not s or not s.zone then
        local ax, ay = xy(w.at); local sw, sh = xy(w.size)
        s = { fx = ax, fy = ay, fw = sw, fh = sh }
        T.snaps[w.address] = s
    end
    s.zone = zone
    props(w, true, zone)
    place(w, r[1], r[2], r[3], r[4])
    log("snap " .. zone .. " " .. table.concat(r, " ") .. " " .. tostring(w.class))
    T.dirty = true
    return "ok"
end

-- back to floating; at = where (nil: its old place)
function T.unsnap(w, at)
    w = w or hl.get_active_window()
    if not w then return "no window" end
    if (w.fullscreen or 0) ~= 0 then dsp(hl.dsp.window.fullscreen({ window = w, action = "unset" })) end
    local s = T.snaps[w.address]
    if not s or not s.zone then return "not snapped" end
    s.zone = nil
    props(w, false, nil)
    local fw, fh = s.fw, s.fh
    if not fw or fw < 120 or not fh or fh < 80 then
        local _, _, W, H = mbox(w.monitor or hl.get_active_monitor()); fw, fh = math.floor(W * 0.5), math.floor(H * 0.6)
    end
    local x, y = s.fx, s.fy
    if at then x, y = at[1], at[2] end
    place(w, x, y, fw, fh)
    log("unsnap " .. tostring(w.class))
    T.dirty = true
    return "ok"
end

-- Windows key + arrows, composed the way Windows does it
local NEXT = {
    left  = { none = "L", L = "L",  R = "none", F = "L", TL = "L",  TR = "TL", BL = "L",    BR = "BL" },
    right = { none = "R", L = "none", R = "R",  F = "R", TL = "TR", TR = "R",  BL = "BR",   BR = "R" },
    up    = { none = "F", L = "TL", R = "TR",   F = "F", TL = "F",  TR = "F",  BL = "L",    BR = "R" },
    down  = { none = "none", L = "BL", R = "BR", F = "none", TL = "L", TR = "R", BL = "none", BR = "none" },
}
function T.key(dir)
    local w = hl.get_active_window()
    if not w then return end
    if (w.fullscreen or 0) >= 2 and dir == "down" then
        dsp(hl.dsp.window.fullscreen({ window = w, action = "unset" })); T.dirty = true; return
    end
    local z = T.zoneOf(w)
    if (w.fullscreen or 0) == 1 then z = "none" end     -- a maximised Settings or Files
    local nz = NEXT[dir][z] or "none"
    if nz == "none" then
        if (w.fullscreen or 0) ~= 0 then dsp(hl.dsp.window.fullscreen({ window = w, action = "unset" })) end
        T.unsnap(w)
    else
        T.snap(nz, w)
    end
end

-- ---------------------------------------------------------------- dragging
-- A drag is seen here, in the compositor, 25 times a second: the left button is down and the focused floating
-- window moves with the pointer (whether her app's own title bar or the Windows key started it).
local E, C, TOPF = 34, 64, 20       -- her tour's edge, corner and top-edge distances (pixels)
local function zoneAt(cx, cy, m)
    local x, y, W, H = mbox(m)
    local px, py = cx - x, cy - y
    if px < C and py < C then return "TL" end
    if px > W - C and py < C then return "TR" end
    if px < C and py > H - C then return "BL" end
    if px > W - C and py > H - C then return "BR" end
    if px < E then return "L" end
    if px > W - E then return "R" end
    if py < TOPF then return "F" end
    return nil
end

-- Whether the left button is down: Hyprland's is_key_down cannot see mouse buttons (the 2026-11-21 virtual PC test:
-- asking it about "mouse:272" puts an error on screen), so two binds on the left button tell us instead. They are
-- non-consuming: every click still reaches the window or the dock as before.
T.btn_method = "binds"
local function leftDown() return T.bound_down == true end

T.drag = nil   -- { addr, ax, ay, sw, sh, moving, zone }
local function dragTick(w, cur)
    local down = leftDown()
    if down and not T.drag then
        if w and w.floating then
            local ax, ay = xy(w.at); local sw, sh = xy(w.size)
            T.drag = { addr = w.address, ax = ax, ay = ay, sw = sw, sh = sh, cx = cur.x, cy = cur.y, moving = false }
        else
            T.drag = { addr = nil }
        end
        return
    end
    local d = T.drag
    if down and d then
        if not w then return end
        if not d.moving and w.address ~= d.addr then
            -- a click on another window focuses it a moment after the press: watch that one instead
            if not w.floating then return end
            local ax, ay = xy(w.at); local sw, sh = xy(w.size)
            d.addr, d.ax, d.ay, d.sw, d.sh = w.address, ax, ay, sw, sh
            return
        end
        if w.address ~= d.addr then return end
        local ax, ay = xy(w.at); local sw, sh = xy(w.size)
        if not d.moving and (ax ~= d.ax or ay ~= d.ay) and sw == d.sw and sh == d.sh then
            d.moving = true
            log("drag starts " .. tostring(w.class) .. " via " .. T.btn_method .. " at tick " .. tostring(T.n))
            -- a snapped window dragged away gets its floating size back, under the pointer as in her tour
            local s = T.snaps[w.address]
            if s and s.zone then
                local fw = (s.fw and s.fw >= 120) and s.fw or math.floor(sw * 0.6)
                local rx = sw > 0 and (d.cx - d.ax) / sw or 0.5
                T.unsnap(w, { math.floor(cur.x - fw * rx), math.floor(cur.y - 16) })
            end
        end
        if d.moving then
            local m = hl.get_monitor_at_cursor() or w.monitor
            local z = zoneAt(cur.x, cur.y, m)
            if z ~= d.zone then
                d.zone = z
                if z then
                    local r = T.rect(z, m)
                    emit("zone " .. z .. " " .. table.concat(r, " "))
                    log("zone " .. z .. " at tick " .. tostring(T.n))
                else
                    emit("zone none 0 0 0 0")
                end
            end
        end
        return
    end
    if not down and d then
        T.drag = nil
        if d.moving then
            log("let go at tick " .. tostring(T.n))
            if d.zone then
                emit("zone none 0 0 0 0")
                local ww = byAddr(d.addr) or w
                if ww then T.snap(d.zone, ww) end
            else
                local s = w and T.snaps[w.address]
                if s then s.zone = nil end
                log("drag ends, floating")
            end
        end
    end
end

-- ---------------------------------------------------------------- the dock and the clock step away
-- For each monitor: does a snapped or full-screen window on its workspace cover the dock (top middle) or the clock
-- (bottom right)? The pointer at the very top edge brings the dock back until it goes down past the dock's strip; at
-- the very bottom edge, the clock and tray until it goes up past theirs. Sent only when something changes.
T.cover = T.cover or {}
local REVEAL_OUT = 110
local function near(a, b) return math.abs(a - b) <= 3 end
local function coverTick(cur)
    local all = hl.get_windows() or {}
    for _, m in ipairs(hl.get_monitors() or {}) do
        local ws = m.active_workspace
        local top, br = false, false
        if ws then
            for _, w in ipairs(all) do
                if w.workspace and w.workspace.id == ws.id and w.mapped and not w.hidden then
                    local fs = w.fullscreen or 0
                    if fs >= 2 then top = true; br = true
                    else
                        local s = T.snaps[w.address]
                        if s and s.zone then
                            local r = T.rect(s.zone, m)
                            local ax, ay = xy(w.at); local sw, sh = xy(w.size)
                            if r and near(ax, r[1]) and near(ay, r[2]) and near(sw, r[3]) and near(sh, r[4]) then
                                if s.zone ~= "BL" and s.zone ~= "BR" then top = true end
                                if s.zone == "F" or s.zone == "R" or s.zone == "BR" then br = true end
                            end
                        end
                    end
                end
            end
        end
        local c = T.cover[m.name] or { top = false, br = false, rt = false, rb = false }
        local _, my, _, H = mbox(m)
        local onm = hl.get_monitor_at_cursor()
        local here = onm and onm.name == m.name
        local py = cur.y - my
        local dragging = T.drag and T.drag.moving
        local rt, rb = c.rt, c.rb
        if not top or dragging or not here then rt = false
        elseif py <= 1 then rt = true
        elseif py > REVEAL_OUT then rt = false end
        if not br or dragging or not here then rb = false
        elseif py >= H - 2 then rb = true
        elseif py < H - REVEAL_OUT then rb = false end
        if T.dirty or c.top ~= top or c.br ~= br or c.rt ~= rt or c.rb ~= rb then
            T.cover[m.name] = { top = top, br = br, rt = rt, rb = rb }
            emit(string.format("cover %s %d %d %d %d", m.name, top and 1 or 0, br and 1 or 0, rt and 1 or 0, rb and 1 or 0))
        end
    end
    T.dirty = false
end

-- the desktop asks for everything again (when it starts)
function T.push()
    T.cover = {}
    T.dirty = true
    return "ok"
end
-- for checks: one line of state
function T.state()
    local parts = { "btn=" .. tostring(T.btn_method) .. "/" .. tostring(T.presses or 0) .. (T.bound_down and "/down" or "/up"), "ws=" .. tostring(T.ws_style), "drag=" .. tostring(T.drag and T.drag.moving and (T.drag.zone or "-") or "no") }
    for name, c in pairs(T.cover) do
        parts[#parts + 1] = string.format("%s:top=%d,br=%d,rt=%d,rb=%d", name, c.top and 1 or 0, c.br and 1 or 0, c.rt and 1 or 0, c.rb and 1 or 0)
    end
    for addr, s in pairs(T.snaps) do if s.zone then parts[#parts + 1] = addr .. "=" .. s.zone end end
    return table.concat(parts, " ")
end

local function tick()
    local ok, err = pcall(function()
        local cur = hl.get_cursor_pos() or { x = 0, y = 0 }
        local w = hl.get_active_window()
        dragTick(w, cur)
        T.n = (T.n or 0) + 1
        if T.n % 50 == 0 then        -- every two seconds: her settings file, if it changed
            local txt = readText()
            if txt and txt ~= T.settingsText then
                T.settingsText = txt
                local st = parseSettings(txt)
                if st then T.look(st.accent, st.light, st.still or T.sysStill == true) end
            end
        end
        coverTick(cur)
    end)
    if not ok then
        T.errs = (T.errs or 0) + 1
        if T.errs < 5 then log("tick failed: " .. tostring(err)) end
    end
end
if T.timer then pcall(function() T.timer:set_enabled(false) end) end
T.timer = hl.timer(tick, { timeout = 40, type = "repeat" })

-- a closed window forgets its place
hl.on("window.destroy", function(w) if w and w.address then T.snaps[w.address] = nil; T.dirty = true end end)

function T.bind_buttons(on)
    if T.btn_binds then for _, bd in ipairs(T.btn_binds) do pcall(function() bd:remove() end) end end
    T.btn_binds = nil
    T.bound_down = false
    if on then
        T.btn_binds = {
            hl.bind("mouse:272", function() T.bound_down = true; T.presses = (T.presses or 0) + 1 end,
                { non_consuming = true, ignore_mods = true, transparent = true }),
            hl.bind("mouse:272", function() T.bound_down = false end,
                { release = true, non_consuming = true, ignore_mods = true, transparent = true }),
        }
    end
    return "ok"
end
T.bind_buttons(true)

-- ---------------------------------------------------------------- keys
local mod = "SUPER"
-- A TAYLOR settings file from before this one moved focus with these keys (and floated with V); they snap now. A file
-- from now on does not bind them (it says so with taylor_fresh_binds), so nothing is unbound that was never bound.
if not taylor_fresh_binds then
    for _, k in ipairs({ "left", "right", "up", "down", "V" }) do pcall(hl.unbind, mod .. " + " .. k) end
end
hl.bind(mod .. " + left",  function() T.key("left") end)
hl.bind(mod .. " + right", function() T.key("right") end)
hl.bind(mod .. " + up",    function() T.key("up") end)
hl.bind(mod .. " + down",  function() T.key("down") end)
hl.bind(mod .. " + V",     function() T.unsnap() end)
-- Switching windows (her ask 2026-11-22, the Mac's Cmd + Tab): Windows key + Tab, or Alt + Tab, shows her open windows
-- (the desktop's Switcher.qml); Tab moves along while the key is held, Shift + Tab goes back, letting go switches.
local function sw(what) hl.dispatch(hl.dsp.exec_cmd("quickshell ipc call switcher " .. what)) end
for _, m in ipairs({ "SUPER", "ALT" }) do
    pcall(hl.unbind, m .. " + Tab")
    hl.bind(m .. " + Tab",         function() sw("next") end)
    hl.bind(m .. " + SHIFT + Tab", function() sw("prev") end)
end
-- letting go of the Windows key or Alt switches (only while the strip is open; otherwise the desktop ignores it)
hl.bind("SUPER + Super_L", function() sw("commit") end, { release = true, non_consuming = true })
hl.bind("ALT + Alt_L",     function() sw("commit") end, { release = true, non_consuming = true })

-- Show desktop (her ask 2026-11-22, Windows key + D as on Windows: "i couldn't get out" of a full-screen game). The windows
-- on the workspace she is on step aside to a hidden one (a game keeps running); Windows key + D again brings them all
-- back where they were. Picking one in the window switcher, or from the dock, brings them back too.
T.aside = T.aside or nil      -- { ws = id, addrs = { ... } } while her desktop is shown
local function byAddress()
    local m = {}
    for _, w in ipairs(hl.get_windows() or {}) do if w.address then m[w.address] = w end end
    return m
end
function T.unhide()
    local a = T.aside
    if not a then return "nothing aside" end
    T.aside = nil
    local all = byAddress()
    local last
    for _, addr in ipairs(a.addrs) do
        local w = all[addr]
        if w then dsp(hl.dsp.window.move({ window = w, workspace = a.ws, follow = false })); last = w end
    end
    if last then dsp(hl.dsp.focus({ window = last })) end
    log("show desktop: " .. #a.addrs .. " windows back")
    emit("desktop back")
    T.dirty = true
    return "back"
end
function T.showDesktop()
    if T.aside then return T.unhide() end
    local ws = hl.get_active_workspace()
    if not ws then return "no workspace" end
    local addrs = {}
    local act = hl.get_active_window()
    for _, w in ipairs(hl.get_windows() or {}) do
        if w.workspace and w.workspace.id == ws.id and w.mapped and w.address and not (act and act.address == w.address) then
            addrs[#addrs + 1] = w.address
        end
    end
    if act and act.workspace and act.workspace.id == ws.id then addrs[#addrs + 1] = act.address end   -- the one in front comes back last, in front
    if #addrs == 0 then return "nothing open" end
    T.aside = { ws = ws.id, addrs = addrs }
    local all = byAddress()
    for _, addr in ipairs(addrs) do
        local w = all[addr]
        if w then dsp(hl.dsp.window.move({ window = w, workspace = "special:taylor-desktop", follow = false })) end
    end
    log("show desktop: " .. #addrs .. " windows aside")
    emit("desktop shown")
    T.dirty = true
    return "aside " .. #addrs
end
pcall(hl.unbind, mod .. " + D")
hl.bind(mod .. " + D", function() T.showDesktop() end)

log("windows.lua loaded")
