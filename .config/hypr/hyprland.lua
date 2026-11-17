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
require("config.wallpaper_colors")
