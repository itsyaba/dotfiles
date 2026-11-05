-- Reads studio.json (written by the Pebble Studio drawer). Returns {} if missing or broken.
local f = io.open(os.getenv("HOME") .. "/.config/caelestia/studio.json")
if not f then return {} end
local text = f:read("a"); f:close()
local ok, t = pcall(require("utils.json").decode, text)
return ok and type(t) == "table" and t or {}
