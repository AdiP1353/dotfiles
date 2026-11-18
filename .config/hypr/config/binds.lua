
local mainMod = "SUPER"
local noctCall = "noctalia msg "
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

-- AZERTY fix: the number-row keys emit symbols (& é " ' ...) without Shift, so
-- binding to the digit characters fails. Bind by physical keycode instead.
-- Digit d -> evdev keycode: 1..9 => 10..18, 0 => 19
local function digitCode(d)
    return "code:" .. (d == 0 and 19 or (9 + d))
end

-- Apps that keep running in the background when closed with SUPER + Q,
-- the way Discord does (lower-case window class). Their window is moved to a
-- hidden special workspace instead of being closed; the app shortcut below
-- brings it back.
local hideOnClose = { spotify = true }
local hiddenWorkspace = "special:background"

-- Workspaces 1..NUM_WORKSPACE_KEYS get number-key shortcuts (max 9).
NUM_WORKSPACE_KEYS = 9

-- The most recently focused window whose class matches (case-insensitive).
local function findWindow(class)
    class = class:lower()
    local best
    for _, w in ipairs(hl.get_windows()) do
        if (w.class or ""):lower() == class or (w.initial_class or ""):lower() == class then
            if not best or w.focus_history_id < best.focus_history_id then best = w end
        end
    end
    return best
end

-- Focus the app if it is open (fetching it back if it is hidden), else start it.
local function focusOrLaunch(class, command)
    return function()
        local w = findWindow(class)
        if not w then
            hl.exec_cmd(launchPrefix .. command)
            return
        end
        local target = "address:" .. w.address
        if w.workspace and w.workspace.special then
            hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace().name, window = target }))
        end
        hl.dispatch(hl.dsp.focus({ window = target }))
    end
end

-- SUPER + SHIFT + S: send the window to the scratchpad, or, if it is already
-- in a hidden workspace (scratchpad or background), bring it back out.
local function toggleScratchpad()
    local w = hl.get_active_window()
    if not w then return end
    local target = "address:" .. w.address
    if w.workspace and w.workspace.special then
        hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace().name, window = target }))
        -- Close the hidden workspace if it is still showing other windows.
        local shown = hl.get_active_special_workspace()
        if shown then hl.dispatch(hl.dsp.workspace.toggle_special((shown.name:gsub("^special:", "")))) end
        hl.dispatch(hl.dsp.focus({ window = target }))
    else
        hl.dispatch(hl.dsp.window.move({ workspace = "special:special", follow = false, window = target }))
    end
end

-- SUPER + Q: hide the apps listed in hideOnClose, close everything else.
local function closeOrHide()
    local w = hl.get_active_window()
    if w and hideOnClose[(w.class or ""):lower()] then
        hl.dispatch(hl.dsp.window.move({ workspace = hiddenWorkspace, follow = false, window = "address:" .. w.address }))
    else
        hl.dispatch(hl.dsp.window.close())
    end
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + Q",           closeOrHide)
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D",           hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))

-- Change focus
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }))
-- Window switcher (~/.config/quickshell/rice/Switcher.qml): hold ALT, Tab to move, let go to switch
hl.bind("ALT + Tab",           hl.dsp.exec_cmd("qs -c rice ipc call switcher next"))
hl.bind("ALT + SHIFT + Tab",   hl.dsp.exec_cmd("qs -c rice ipc call switcher prev"))
-- Shortcuts window (~/.config/quickshell/rice/Shortcuts.qml)
hl.bind(mainMod .. " + H",     hl.dsp.exec_cmd("qs -c rice ipc call shortcuts toggle"))
hl.bind(mainMod .. " + M",     hl.dsp.exec_cmd("qs -c rice ipc call windowmenu toggle"))
hl.bind(mainMod .. " + Tab",   hl.dsp.exec_cmd(noctCall .. "window-switcher"))

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + Up",                   hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Right",                hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left",                 hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Down",                 hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + mouse_up",             hl.dsp.window.move({ monitor   = "-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down",           hl.dsp.window.move({ monitor   = "+1" }))

-- Move active window between workspaces (cheat sheet: ~/.config/hypr/WORKSPACES.md)
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Down",       hl.dsp.window.move({ workspace = "emptym" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "m+1" }))
for i = 1, NUM_WORKSPACE_KEYS do
    -- SUPER + SHIFT + number: move the window there and go with it
    hl.bind(mainMod .. " + SHIFT + " .. digitCode(i),       hl.dsp.window.move({ workspace = tostring(i) }))
    -- SUPER + SHIFT + ALT + number: move the window there, stay where you are
    hl.bind(mainMod .. " + SHIFT + ALT + " .. digitCode(i), hl.dsp.window.move({ workspace = tostring(i), follow = false }))
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())
-- ALT + right-click any window: the rice's window menu at the cursor (move to a workspace, float, close...)
hl.bind("ALT + mouse:273", hl.dsp.exec_cmd("qs -c rice ipc call windowmenu openAtCursor"))

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true})
hl.bind(mainMod .. " + Plus", function() zoomfunction(0.3) end, { repeating = true })

--# Zoom with keypad
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })


------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + T",     hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + N",          hl.dsp.exec_cmd(launchPrefix .. EDITOR))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("XF86Calculator",           hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind(mainMod .. " + 1",          hl.dsp.exec_cmd(launchPrefix .. BROWSER))
hl.bind(mainMod .. " + 2",          focusOrLaunch("Spotify", "spotify-launcher"))
hl.bind(mainMod .. " + 3",          focusOrLaunch("com.anthropic.Claude", "claude-desktop"))
hl.bind(mainMod .. " + 4",          focusOrLaunch("obsidian", "obsidian"))
hl.bind(mainMod .. " + 5",          focusOrLaunch("dev.zed.Zed", "zeditor"))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
hl.bind(mainMod .. " + Z",          hl.dsp.exec_cmd(noctCall .. "settings-toggle"))
hl.bind(mainMod .. " + X",          hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center"))
-- Launcher: the rice's minimal launcher (~/.config/quickshell/rice/Launcher.qml)
hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd("qs -c rice ipc call launcher toggle"))
hl.bind(mainMod .. " + period",     hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher /emo"))
-- Lock: the rice lock screen (same look as the login screen), ~/.config/rice-greeter/lock.qml
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd("~/.config/rice-greeter/lock.sh"))
hl.bind(mainMod .. " + ALT + C",    hl.dsp.exec_cmd(noctCall .. "panel-toggle session"))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctCall .. "volume-up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctCall .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(noctCall .. "volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(noctCall .. "mic-mute"),    { locked = true })

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(noctCall .. "media next"),     { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(noctCall .. "media previous"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctCall .. "brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctCall .. "brightness-down"), { locked = true, repeating = true })

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("qs -c rice ipc call display toggle"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a -n"))
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$($HOME/.local/bin/rice-slurp)" - | swappy -f -'))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(noctCall .. "screenshot-fullscreen"))
-- Theming and Wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(noctCall .. "panel-toggle wallpaper"))
-- Wallhaven picker (~/.config/quickshell/wallhaven): search, download, recolor
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("~/.config/quickshell/wallhaven/toggle.sh"))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(noctCall .. "panel-toggle clipboard"))

-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center notifications"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Cheat sheet for everything below: ~/.config/hypr/WORKSPACES.md
-- (SUPER + number is used for app shortcuts, so workspaces use SUPER + CONTROL.)

-- Go to workspace number
for i = 1, NUM_WORKSPACE_KEYS do
    hl.bind(mainMod .. " + CONTROL + " .. digitCode(i), hl.dsp.focus({ workspace = i }))
end

-- Previous / next workspace, back to the last one, and a new empty one
hl.bind(mainMod .. " + CONTROL + Right",       hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + Left",        hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + Up",          hl.dsp.focus({ workspace = "previous" }))
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "emptym" }))

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }))

-- Hidden workspaces
-- Scratchpad: a hidden workspace you can pop open over any workspace
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())
hl.bind(mainMod .. " + SHIFT + S", toggleScratchpad)
-- Background: where SUPER + Q puts apps like Spotify
hl.bind(mainMod .. " + B",         hl.dsp.workspace.toggle_special("background"))

-- Move
