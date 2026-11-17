-- Drag a window onto a workspace circle in the Noctalia bar to move it there.
--
-- Works with any window drag: SUPER + left-drag, or dragging a window by its
-- toolbar (Dolphin and other Breeze apps). While the left mouse button is held,
-- a timer watches whether the window under the cursor actually moves. When it
-- starts moving, the auto-hidden bar is shown for the length of the drag, and
-- scripts/map-workspace-circles.py finds where the circles are
-- in the bar. From then on, the circle under the cursor is highlighted (using
-- Noctalia's workspace alert), and letting go over a circle moves the window to
-- that workspace. The window moves; you stay on the workspace you are on.
--
-- Clicks and text selection are not affected: the bindings below pass every
-- click through to the app, and nothing happens unless a window was dragged.

local SCRIPT     = os.getenv("HOME") .. "/.config/hypr/scripts/map-workspace-circles.py"
local MAP_FILE   = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-ws-circles.map"
local BAR_HEIGHT = 40     -- logical px from the top of the monitor that count as the bar
local REACH      = 8      -- px either side of the circles that still count as on them
local LOG        = "/tmp/hypr-drag-to-workspace.log"
local DEBUG      = true   -- keep in step with DEBUG in the Python script

local function log(message)
    if not DEBUG then return end
    local f = io.open(LOG, "a")
    if f then
        f:write(os.date("%H:%M:%S "), message, "\n")
        f:close()
    end
end

-- State of the current press; nil when the button is up.
-- { address, x, y, moved, monitor, token, tries, map, target }
local drag = nil
local counter = 0

local function position(address)
    local w = hl.get_window("address:" .. address)
    if w and type(w.at) == "table" then return w.at.x, w.at.y end
end

local function requestMap()
    counter = counter + 1
    drag.token = tostring(os.time()) .. "-" .. counter
    drag.tries = (drag.tries or 0) + 1
    hl.exec_cmd(string.format("python3 -I %q %q %q %q", SCRIPT, drag.monitor, drag.token, MAP_FILE))
end

-- Read the circle map once the script has written it for this drag.
-- Returns a table of circles, false if the script found none, or nil if not ready.
local function readMap()
    local f = io.open(MAP_FILE, "r")
    if not f then return nil end
    local token, status = f:read("l"), f:read("l")
    if token ~= drag.token or not status then
        f:close()
        return nil
    end
    if status ~= "ok" then
        f:close()
        return false
    end
    local map = { circles = {}, alerted = {} }
    for name in (f:read("l") or ""):gmatch("%S+") do map.alerted[name] = true end
    map.alerted["alerts"] = nil
    for line in f:lines() do
        local a, b, selector, name = line:match("^(%S+) (%S+) (%S+) (%S+)$")
        if a then
            table.insert(map.circles, { a = tonumber(a), b = tonumber(b), selector = selector, name = name })
        end
    end
    f:close()
    return #map.circles > 0 and map or false
end

-- The circle under the cursor, or nil.
local function circleAt(cursor)
    local monitor = hl.get_monitor_at(cursor)
    if not monitor or not drag.map or cursor.y - monitor.y >= BAR_HEIGHT then return nil end
    local circles = drag.map.circles
    if cursor.x < circles[1].a - REACH or cursor.x > circles[#circles].b + REACH then return nil end
    local best, bestDistance
    for _, c in ipairs(circles) do
        local d = (cursor.x < c.a and c.a - cursor.x) or (cursor.x > c.b and cursor.x - c.b) or 0
        if not best or d < bestDistance then best, bestDistance = c, d end
    end
    return best
end

-- Highlight a circle with a Noctalia workspace alert, leaving any alerts that
-- were already showing (for example, an app asking for attention) alone.
local function highlight(circle)
    local old = drag.target
    if old == circle then return end
    if old and not drag.map.alerted[old.name] then
        hl.exec_cmd("noctalia msg workspace-alert-clear " .. old.name)
    end
    if circle and not drag.map.alerted[circle.name] then
        hl.exec_cmd("noctalia msg workspace-alert-add " .. circle.name)
    end
    drag.target = circle
end

-- The bar auto-hides, so show it for the length of a drag (runtime only; the
-- saved setting is untouched), and put it back to the saved setting afterwards.
local SHOW_BAR    = "sh -c '[ \"$(noctalia msg config-get bar.default.auto_hide)\" = true ] && noctalia msg bar-auto-hide-set off'"
local RESTORE_BAR = "sh -c '[ \"$(noctalia msg config-get bar.default.auto_hide)\" = true ] && noctalia msg bar-auto-hide-set on'"
local REVEAL_TICKS = 8    -- ticks (of 40 ms) to let the bar slide in before mapping it

local function tick()
    if not drag then return end
    if not drag.moved then
        local x, y = position(drag.address)
        if not x or (x == drag.x and y == drag.y) then return end
        drag.moved = true
        drag.wait = REVEAL_TICKS
        hl.exec_cmd(SHOW_BAR)
        return
    end
    if drag.wait then
        drag.wait = drag.wait - 1
        if drag.wait > 0 then return end
        drag.wait = nil
        requestMap()
        return
    end
    local cursor = hl.get_cursor_pos()
    if drag.map == nil then
        local map = readMap()
        if map == false then
            -- Nothing found (the dragged window may have covered the bar).
            -- Try again while the cursor is well away from the bar.
            drag.map = false
            local monitor = cursor and hl.get_monitor_at(cursor)
            if drag.tries < 3 and monitor and cursor.y - monitor.y > 100 then
                drag.map = nil
                requestMap()
            end
        elseif map then
            drag.map = map
        end
    end
    if drag.map and cursor then highlight(circleAt(cursor)) end
end

local watcher = hl.timer(tick, { timeout = 40, type = "repeat" })
watcher:set_enabled(false)

local function onPress()
    local w = hl.get_active_window()
    local monitor = w and w.monitor
    if not w or not monitor or (w.workspace and w.workspace.special) then
        drag = nil
        return
    end
    local x, y = position(w.address)
    drag = { address = w.address, x = x, y = y, moved = false, monitor = monitor.name }
    watcher:set_enabled(true)
end

local function onRelease()
    watcher:set_enabled(false)
    if not drag then return end
    tick()
    local d = drag
    local target = d.map and not d.wait and circleAt(hl.get_cursor_pos()) or nil
    highlight(nil)
    drag = nil
    if not d.moved then return end
    hl.exec_cmd(RESTORE_BAR)
    if not target then
        log("drag ended, not on a workspace circle" .. (d.map and "" or " (circles not mapped yet)"))
        return
    end
    local w = hl.get_window("address:" .. d.address)
    if not w then return end
    if w.workspace and w.workspace.name == target.name then
        log("dropped on its own workspace " .. target.name)
        return
    end
    hl.dispatch(hl.dsp.window.move({ workspace = target.selector, follow = false, window = "address:" .. d.address }))
    log("moved " .. w.class .. " to workspace " .. target.name)
end

hl.bind("mouse:272", onPress,   { non_consuming = true, ignore_mods = true })
hl.bind("mouse:272", onRelease, { non_consuming = true, ignore_mods = true, release = true })
