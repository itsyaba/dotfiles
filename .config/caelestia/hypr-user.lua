-- Look & feel + depth (ported from omarchy-dotfiles, see ~/.config/caelestia/hypr-look.lua)
require("hypr-look")
require("hypr-recess")

-- GNOME-style screenshot UI (~/.config/quickshell/gshot)
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c gshot -d")
end)
hl.unbind("Print")
hl.bind("Print", hl.dsp.exec_cmd("/home/yeab/.local/bin/gshot"))

-- Super+Shift+S: instant full-screen screenshot
hl.unbind("SUPER + SHIFT + S")
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("caelestia screenshot"))

-- Ignore maximize requests so new windows (e.g. kitty) tile normally
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Vicinae: launcher server + clipboard history on Super+V
hl.on("hyprland.start", function()
    hl.exec_cmd("vicinae server")
end)
hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.exec_cmd("vicinae cmd launch clipboard:history"))

-- >>> redat (Amharic voice assistant, ~/projects/redat) >>>
-- SUPER+Y: start listening; press again to stop recording early, or to interrupt a spoken reply
hl.bind("SUPER + Y", hl.dsp.exec_cmd("/home/yeab/.local/bin/redat listen"))
-- SUPER+SHIFT+Y: show/hide the Redat panel (focuses its text box, Esc closes)
hl.bind("SUPER + SHIFT + Y", hl.dsp.exec_cmd("/home/yeab/.local/bin/redat panel"))
-- Panel: blur behind it like Caelestia's drawers; it animates itself, so no Hyprland animation
hl.layer_rule({ match = { namespace = "redat-panel" }, blur = true, ignore_alpha = 0.82, no_anim = true })
-- <<< redat <<<

-- Zen: no padding when it's the only tiled window on a workspace
-- (Caelestia's singleWindowGapsOut). Bar and notifications stay visible.
local zen_gap_rules = {}

local function update_zen_gaps()
    for _, ws in ipairs(hl.get_workspaces()) do
        local tiled = {}
        for _, w in ipairs(ws:get_windows()) do
            if w.mapped and not w.hidden and not w.floating then
                table.insert(tiled, w)
            end
        end
        local zen_alone = #tiled == 1 and tiled[1].class == "zen"

        local rule = zen_gap_rules[ws.name]
        if zen_alone and not rule then
            zen_gap_rules[ws.name] = hl.workspace_rule({ workspace = "name:" .. ws.name, gaps_out = 0 })
        elseif rule and rule:is_enabled() ~= zen_alone then
            rule:set_enabled(zen_alone)
        end
    end
end

for _, ev in ipairs({ "window.open", "window.close", "window.destroy", "window.move_to_workspace", "window.update_rules" }) do
    hl.on(ev, update_zen_gaps)
end

-- Super+N on the workspace you're already on jumps back to the previous one;
-- switching workspace also hides an open special workspace (Telegram, Slack, ...)
hl.config({
    binds = {
        workspace_back_and_forth = true,
        hide_special_on_workspace_change = true,
    },
})

-- Workspace 2 (Zen) lives on the external monitor
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })

-- Caelestia bar: shown on an empty workspace, hidden once windows are open
for _, ev in ipairs({ "window.open", "window.close", "window.destroy", "window.move_to_workspace",
                      "workspace.active", "workspace.special_active", "monitor.focused" }) do
    hl.on(ev, function() hl.exec_cmd("/home/yeab/.local/bin/caelestia-bar-autoshow") end)
end

-- Desktop music card (~/.config/quickshell/desktop-media), blurred like Caelestia's panels
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c desktop-media -d")
end)
hl.layer_rule({ match = { namespace = "desktop-media" }, blur = true, ignore_alpha = 0.3 })

-- Media keys control the most recently active player (playerctld tracks it),
-- instead of Caelestia's default player (Spotify)
hl.on("hyprland.start", function()
    hl.exec_cmd("playerctld daemon")
end)
local media_keys = {
    ["play-pause"] = { "SUPER + Space", "XF86AudioPlay", "XF86AudioPause" },
    ["next"]       = { "CTRL + SUPER + Equal", "XF86AudioNext" },
    ["previous"]   = { "CTRL + SUPER + Minus", "XF86AudioPrev" },
    ["stop"]       = { "CTRL + SUPER + Backspace", "XF86AudioStop" },
}
for cmd, keys in pairs(media_keys) do
    for _, key in ipairs(keys) do
        hl.unbind(key)
        hl.bind(key, hl.dsp.exec_cmd("playerctl -p playerctld " .. cmd), { locked = true })
    end
end

-- Super+I: Hyprland settings window (~/.config/quickshell/hypr-settings), press again to close
hl.unbind("SUPER + I")
hl.bind("SUPER + I", hl.dsp.exec_cmd("if qs list -c hypr-settings | grep -q 'Process ID'; then qs -c hypr-settings kill; else qs -c hypr-settings -d; fi"))

-- Monitor layout: Dell above the laptop, laptop centered under it
-- Monitor 2 (Dell S2725QS)
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "2560x1440@120",
    position = "0x0",
    scale    = 1,
})
-- Laptop screen
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "320x1440",
    scale    = 1,
})

-- Pebble panels (~/.config/quickshell/pebble): control corner on Super+O or the bottom-left hot corner,
-- Studio (glass + depth) on Super+Shift+O
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c pebble -d")
end)
hl.bind("SUPER + O", hl.dsp.exec_cmd("qs -c pebble ipc call corner toggle"))
hl.bind("SUPER + SHIFT + O", hl.dsp.exec_cmd("qs -c pebble ipc call studio toggle"))
