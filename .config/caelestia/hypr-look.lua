-- Look & feel ported from denonmaryland/omarchy-dotfiles (looknfeel.lua + glass.lua),
-- adapted for Caelestia. Loaded from hypr-user.lua.
-- Kept from Caelestia/you: dwindle layout, gaps (HyprMod), rounding 15 (matches the shell).

-- Glass: frosted blur with a little vibrancy, popups frosted too.
hl.config({
    decoration = {
        blur = {
            enabled            = true,
            size               = 6,
            passes             = 2,
            xray               = false,
            noise              = 0,
            contrast           = 0.9,
            brightness         = 1.15,
            vibrancy           = 0.08,
            popups             = true,
            popups_ignorealpha = 0.5,
        },
    },
})

-- macOS-style motion: short durations, responsive start, soft landing.
-- Speeds are in tenths of a second (2.8 = 280 ms).
hl.curve("macEase", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("macExit", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
local move = 2.8 -- window moves and workspace slides (kept matched)

hl.animation({ leaf = "windows",       enabled = true, speed = move, bezier = "macEase" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 2.2,  bezier = "macEase", style = "popin 92%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.4,  bezier = "macExit", style = "popin 95%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = move, bezier = "macEase" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.8,  bezier = "macEase" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.3,  bezier = "macExit" })
hl.animation({ leaf = "fade",          enabled = true, speed = 2.0,  bezier = "macEase" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 2.0,  bezier = "macEase" })
hl.animation({ leaf = "border",        enabled = true, speed = 2.5,  bezier = "macEase" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.0,  bezier = "macEase", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.3,  bezier = "macExit", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.6,  bezier = "macEase" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.1,  bezier = "macExit" })
-- Workspaces slide horizontally to match your 4-finger horizontal swipe;
-- special workspaces slide vertically to match the up/down 3-finger gestures.
hl.animation({ leaf = "workspaces",       enabled = true, speed = move, bezier = "macEase", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = move, bezier = "macEase", style = "slidevert" })
