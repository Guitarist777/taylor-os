-- TAYLOR OS: her screen as Settings > Display has it (her ask 2026-11-25: "make my settings look like the windows
-- settings ... i'm missing my HDR options and framerate and such"). Loaded by windows.lua, so it reaches every desktop
-- with no change to her own hyprland.lua. At load it reads her picks from ~/.config/taylor-os/settings.json; Settings
-- calls taylor.display(...) to try a change, and keeps it only when she says so (else it goes back after 15 s, as on
-- Windows), so a screen that goes dark with a setting it can't show comes back by itself.
--
-- One rule for every screen (output ""), placed after her file's own "highrr" rule, which it replaces.
--   displayMode   ""  = the highest refresh rate at full size (her file's "highrr"), else "2560x1440@240"
--   displayScale  0   = automatic, else 1, 1.25, 1.5, 1.75, 2
--   hdr           true: HDR (10-bit colour, the HDR colour space); false: the usual sRGB
--   sdrBrightness how bright ordinary (non-HDR) things look while HDR is on: 1 = as Hyprland has it
--   vrr           0 off, 1 on, 2 only for a full-screen window (a game)
taylor = taylor or {}
local T = taylor

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

-- only values of the right shape get through; anything else is the default
local function clean(mode, scale, hdr, sdr, vrr)
    mode = tostring(mode or "")
    if not mode:match("^%d+x%d+@[%d%.]+$") then mode = "" end
    scale = tonumber(scale) or 0
    if scale ~= 0 and (scale < 1 or scale > 3) then scale = 0 end
    hdr = hdr == true
    sdr = tonumber(sdr) or 1
    if sdr < 0.5 or sdr > 2 then sdr = 1 end
    vrr = math.floor(tonumber(vrr) or 0)
    if vrr < 0 or vrr > 2 then vrr = 0 end
    return mode, scale, hdr, sdr, vrr
end

local function apply(mode, scale, hdr, sdr, vrr)
    mode, scale, hdr, sdr, vrr = clean(mode, scale, hdr, sdr, vrr)
    local spec = {
        output   = "",
        mode     = mode ~= "" and mode or "highrr",
        position = "auto",
        scale    = scale ~= 0 and scale or "auto",
        vrr      = vrr,
    }
    if hdr then
        spec.cm = "hdr"; spec.bitdepth = 10; spec.sdrbrightness = sdr; spec.sdrsaturation = 1.0
    else
        spec.cm = "srgb"; spec.bitdepth = 8
    end
    hl.monitor(spec)
    T.displayNow = { mode = mode, scale = scale, hdr = hdr, sdr = sdr, vrr = vrr }
    return "display " .. spec.mode .. " scale " .. tostring(spec.scale) .. (hdr and " hdr" or " sdr") .. " vrr " .. vrr
end

-- Settings: hyprctl eval 'return taylor.display("2560x1440@240", 0, true, 1, 2)'
function T.display(mode, scale, hdr, sdr, vrr)
    local ok, res = pcall(apply, mode, scale, hdr, sdr, vrr)
    return ok and res or ("display error: " .. tostring(res))
end

do
    local txt = readText()
    if txt then
        local mode  = txt:match('"displayMode"%s*:%s*"([^"]*)"')
        local scale = txt:match('"displayScale"%s*:%s*([%d%.]+)')
        local hdr   = txt:match('"hdr"%s*:%s*true') ~= nil
        local sdr   = txt:match('"sdrBrightness"%s*:%s*([%d%.]+)')
        local vrr   = txt:match('"vrr"%s*:%s*(%d+)')
        -- nothing picked yet: leave her file's own rule alone
        if mode or scale or hdr or vrr then T.display(mode, scale, hdr, sdr, vrr) end
    end
end
