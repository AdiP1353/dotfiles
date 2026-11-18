-- CachyOS Hyprland Configuration

require("config.animations")
require("config.autostart")
require("config.colors")
require("config.decorations")
require("config.variables")
require("config.environment")
require("config.inputs")
require("config.binds")
require("config.dragtoworkspace")
require("config.misc")
require("config.monitors")
require("config.windowrules")
require("config.workspaces")

-- Window border colors from the wallpaper (rendered by noctalia, see THEME.md).
-- Loaded last so it overrides the fixed colors in config/colors.lua.
-- Git-ignored and generated: on a fresh machine it only exists after noctalia
-- renders the first wallpaper, so a missing file is not an error.
local ok, err = pcall(require, "config.wallpaper_colors")
if not ok and not tostring(err):find("module 'config.wallpaper_colors' not found", 1, true) then
  error(err, 0)   -- the file exists but is broken: show that
end
