-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Example: output can be found with hyprctl monitors. Edit variables.lua for the monitor outputs instead of here directly
-- hl.monitor({
--     output    = MONITOR1,
--     mode      = "1920x1080@60",
--     position  = "0x0",
--     scale     = "1",
-- })

-- Load the monitor layout saved by nwg-displays (machine-specific, not in the
-- dotfiles repo; skipped when missing so a fresh machine still starts).
local nwg_layout = os.getenv("HOME") .. "/.config/hypr/monitors.lua"
local nf = io.open(nwg_layout, "r")
if nf then
  nf:close()
  dofile(nwg_layout)
end


hl.monitor(
  {
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
  }
)

-- Display mode chosen with SUPER + P (rice display switcher, written by
-- quickshell/rice/DisplaySwitcher.qml). Loaded last so it wins.
local display_mode = os.getenv("HOME") .. "/.config/hypr/display-mode.lua"
local f = io.open(display_mode, "r")
if f then
  f:close()
  dofile(display_mode)
end
