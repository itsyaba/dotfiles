-- Depth: recessed (or raised) windows, ported from denonmaryland/omarchy-dotfiles
-- (recessed_windows.lua). Follows the Caelestia scheme instead of Omarchy's theme.
-- Loaded from hypr-user.lua. Tweak S below; set enabled = false to turn it off.
local S = { enabled = true, style = "recessed", -- "recessed" or "raised"
  light = { win_depth = 0.45, win_soft = 10, win_light = 0.3, win_lip = 0.5 },
  dark = { win_depth = 0.896, win_soft = 14, win_light = 0.3, win_lip = 0.64 } }

-- Overrides from studio.json (edited live by the Pebble Studio drawer).
local ok_s, studio = pcall(dofile, os.getenv("HOME") .. "/.config/caelestia/studio-load.lua")
local depth = ok_s and type(studio) == "table" and studio.depth
if type(depth) == "table" then
  if depth.style == "off" then S.enabled = false elseif depth.style then S.style = depth.style end
  for _, m in ipairs({ "light", "dark" }) do
    if type(depth[m]) == "table" then for k, v in pairs(depth[m]) do S[m][k] = v end end
  end
end

if not S.enabled then return end

local ok, scheme = pcall(require, "scheme.current")
if not ok or type(scheme) ~= "table" then scheme = {} end
local bg = scheme.background
local fg = scheme.onSurface or "ffffff"

local function brightness(hex)
  return (0.2126 * tonumber(hex:sub(1, 2), 16) + 0.7152 * tonumber(hex:sub(3, 4), 16) + 0.0722 * tonumber(hex:sub(5, 6), 16)) / 255
end
local light = bg ~= nil and brightness(bg) > 0.55
local P = light and S.light or S.dark

local function rgba(rgb, a)
  return string.format("rgba(%s%02x)", rgb, math.floor(math.max(0, math.min(1, a)) * 255 + 0.5))
end
local function vertical(top, middle, bottom) return { colors = { top, middle, bottom }, angle = 90 } end
local function grad(...) return { colors = { ... }, angle = 90 } end

if S.style == "raised" then
  -- Raised (pebble): dark outline, an inner rim of light rolling off the top edge,
  -- and a soft drop shadow weighted toward the bottom.
  local h, soft, sun, sheen = P.win_depth, P.win_soft, P.win_light, P.win_lip
  local o = light and (0.05 + 0.14 * h) or (0.12 + 0.32 * h)
  local s = sheen * (light and 1.0 or 0.85)
  local b = (light and (0.04 + 0.12 * h) or (0.1 + 0.3 * h)) * (0.6 + 0.4 * sun)
  local lift = h * (light and 0.36 or 0.8)
  local function outline(k)
    return grad(rgba("000000", o * 0.95 * k), rgba("000000", o * k), rgba("000000", o * 1.25 * k), rgba("000000", o * 1.6 * k))
  end
  local top_only = { 1, 0.29, 0.07, 0, 0, 0 }
  local wrapped = { 1, 0.8, 0.7, 0.66, 0.62, 0.58 }
  local function bevel(k)
    local stops = {}
    for i = 1, 6 do stops[i] = rgba("ffffff", s * (top_only[i] * sun + wrapped[i] * (1 - sun)) * k) end
    local bottom = s * 0.3 * (1 - sun) - b * sun
    stops[7] = bottom >= 0 and rgba("ffffff", bottom * k) or rgba("000000", -bottom * k)
    return { colors = stops, angle = 90 }
  end
  local function shade(k)
    return grad(rgba("000000", lift * (0.65 - 0.35 * sun) * k), rgba("000000", lift * 0.8 * k), rgba("000000", lift * k))
  end
  hl.config({
    general = { border_size = 1, col = { active_border = outline(1), inactive_border = outline(0.8) } },
    group = { col = { border_active = outline(1), border_inactive = outline(0.8) } },
    decoration = {
      shadow = { enabled = true, range = math.floor(soft * 1.6 + 0.5), render_power = 3, scale = 0.98,
                 offset = { 0, math.floor(soft * (0.2 + 0.35 * sun) + 0.5) },
                 color = shade(1), color_inactive = shade(0.7) },
      glow = { enabled = true, range = 2 + math.floor(soft * 0.3 + 0.5), render_power = 3,
               color = bevel(1), color_inactive = bevel(0.65) },
    },
  })
  return
end

-- Recessed: a dark cut along the top fading to a lit lower lip, plus an inner shade.
-- Near-black backgrounds get a tighter shade and a lip tinted with the foreground.
local t = not light and bg and math.max(0, math.min(1, (0.12 - brightness(bg)) / 0.085)) or 0
local night = t * t * (3 - 2 * t)
local channels = {}
for i = 1, 3 do
  local c = tonumber(fg:sub(i * 2 - 1, i * 2), 16)
  channels[i] = string.format("%02x", math.floor(255 + (c - 255) * night + 0.5))
end
local lip_rgb = table.concat(channels)
local shade = light and 0.45 or (0.85 + 0.1 * night)
local glint = light and 0.85 or (0.2 + 0.16 * night)
local soft = math.max(2, math.floor(P.win_soft * (1 - 0.35 * night) + 0.5))
local function inset(scale)
  local a = P.win_depth * shade * scale
  return vertical(rgba("000000", a), rgba("000000", a * (1 - P.win_light * 0.5)), rgba("000000", a * (1 - P.win_light)))
end
local function edge(scale)
  local a = P.win_depth * shade * scale
  local lip = P.win_lip * glint * scale
  if night == 0 then
    return vertical(rgba("000000", a * 0.85), rgba("000000", a * 0.15), rgba("ffffff", lip))
  end
  return grad(rgba("000000", a * 0.85), rgba("000000", a * (0.5 + 0.15 * night)),
              rgba("000000", a * 0.15), rgba(lip_rgb, lip * (0.5 + 0.1 * night)), rgba(lip_rgb, lip))
end

hl.config({
  general = { border_size = 1, col = { active_border = edge(1), inactive_border = edge(0.75) } },
  group = { col = { border_active = edge(1), border_inactive = edge(0.75) } },
  decoration = {
    shadow = { enabled = false },
    glow = { enabled = true, range = soft, render_power = 2, color = inset(1), color_inactive = inset(0.75) },
  },
})
