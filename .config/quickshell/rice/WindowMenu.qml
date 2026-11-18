// Window menu, minimal style (THEME.md §3): ALT + right-click any window
// (the menu opens at the cursor), right-click the window title in the top
// bar, or press SUPER + M (the focused window) for that window's options, as plain
// lowercase lines in one 2px box. The selected line is bright with a 1px
// accent underline.
//
//   move to   1 2 3 ... new     (the window moves, you stay where you are)
//   send to scratchpad          hide in background
//   float / tile                fullscreen          maximise
//   pin on every workspace      (floating windows only)
//   close                       force quit
//
// Keys: Up/Down move between lines, Left/Right pick a workspace on the
// "move to" line, Enter does it, Esc or a click outside closes.
// Opens and closes instantly (opened from the keyboard many times a day).

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win
    property bool open: false
    visible: open

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "rice-windowmenu"

    // the window the menu acts on, captured when it opens
    property string addr: ""
    property string title: ""
    property bool floating: false
    property bool pinned: false
    property var workspaces: []      // normal workspace names, sorted, plus "new"
    property string currentWs: ""
    property int row: 0
    property int wsIndex: 0
    property real menuX: 8

    readonly property var rows: {
        const r = [{ id: "move", label: "move to" },
                   { id: "scratch", label: "send to scratchpad" },
                   { id: "background", label: "hide in background" },
                   { id: "float", label: floating ? "tile" : "float" },
                   { id: "fullscreen", label: "fullscreen" },
                   { id: "maximise", label: "maximise" }]
        if (floating) r.push({ id: "pin", label: pinned ? "unpin" : "pin on every workspace" })
        r.push({ id: "close", label: "close" }, { id: "kill", label: "force quit" })
        return r
    }

    // show(x):      the focused window; the box under the bar at x (the bar's
    //               title), or in the middle of the screen when x is -1
    // showAtCursor: the window under the mouse (ALT + right-click); the box
    //               opens at the cursor
    // Details come straight from Hyprland, so they are always current.
    property real pendingX: -1
    property bool atCursor: false
    property real menuY: 0
    function show(x) { pendingX = x; atCursor = false; info.running = true }
    function showAtCursor() { atCursor = true; info.running = true }
    Process {
        id: info
        command: ["sh", "-c", "hyprctl activewindow -j; echo RICE_SPLIT; hyprctl workspaces -j; echo RICE_SPLIT; "
                  + "hyprctl cursorpos -j; echo RICE_SPLIT; hyprctl clients -j; echo RICE_SPLIT; hyprctl monitors -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("RICE_SPLIT")
                const parse = (t, d) => { try { return JSON.parse(t) } catch (e) { return d } }
                let w = parse(parts[0], {})
                const wss = parse(parts[1], []), cur = parse(parts[2], null)
                const clients = parse(parts[3], []), mons = parse(parts[4], [])
                let mon = mons.find(m => m.focused) || mons[0]
                if (win.atCursor && cur) {
                    // the window under the mouse: floating ones sit on top, then the most recently used
                    mon = mons.find(m => cur.x >= m.x && cur.x < m.x + m.width && cur.y >= m.y && cur.y < m.y + m.height) || mon
                    const shown = [mon.activeWorkspace && mon.activeWorkspace.id, mon.specialWorkspace && mon.specialWorkspace.id]
                    const under = clients.filter(c => c.mapped && !c.hidden
                            && (shown.includes(c.workspace.id) || c.pinned)
                            && cur.x >= c.at[0] && cur.x < c.at[0] + c.size[0]
                            && cur.y >= c.at[1] && cur.y < c.at[1] + c.size[1])
                        .sort((a, b) => (b.floating - a.floating) || (a.focusHistoryID - b.focusHistoryID))
                    if (!under.length) return               // clicked on the wallpaper
                    w = under[0]
                    win.menuX = cur.x - mon.x
                    win.menuY = cur.y - mon.y
                } else {
                    win.menuX = win.pendingX
                    win.menuY = -1
                }
                if (!w || !w.address) return                  // nothing focused
                const scr = Quickshell.screens.find(s => mon && s.name === mon.name)
                if (scr) win.screen = scr
                win.addr = w.address
                win.title = (w.title || w.class || "window").toLowerCase()
                win.floating = !!w.floating
                win.pinned = !!w.pinned
                win.currentWs = w.workspace ? String(w.workspace.name) : ""
                win.workspaces = wss.filter(s => s.id > 0).map(s => String(s.name))
                    .sort((a, b) => (parseInt(a) || 999) - (parseInt(b) || 999)).concat(["new"])
                win.wsIndex = Math.max(0, win.workspaces.findIndex(n => n !== win.currentWs))
                win.row = 0
                win.open = true
                keys.forceActiveFocus()
            }
        }
    }
    function close() { open = false }

    function dispatch(lua) { Hyprland.dispatch(lua) }
    function run(id) {
        const w = 'window = "address:' + addr + '"'
        switch (id) {
        case "move": {
            const target = workspaces[wsIndex] === "new" ? "emptym" : workspaces[wsIndex]
            if (target === currentWs) return
            dispatch('hl.dsp.window.move({ workspace = "' + target + '", follow = false, ' + w + ' })'); break
        }
        case "scratch":    dispatch('hl.dsp.window.move({ workspace = "special:special", follow = false, ' + w + ' })'); break
        case "background": dispatch('hl.dsp.window.move({ workspace = "special:background", follow = false, ' + w + ' })'); break
        case "float":      dispatch('hl.dsp.window.float({ action = "toggle", ' + w + ' })'); break
        case "fullscreen": dispatch('hl.dsp.window.fullscreen({ ' + w + ' })'); break
        case "maximise":   dispatch('hl.dsp.window.fullscreen({ mode = 1, ' + w + ' })'); break
        case "pin":        dispatch('hl.dsp.window.pin({ ' + w + ' })'); break
        case "close":      dispatch('hl.dsp.window.close({ ' + w + ' })'); break
        case "kill":       dispatch('hl.dsp.window.kill({ ' + w + ' })'); break
        }
        close()
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const n = win.rows.length
            switch (event.key) {
            case Qt.Key_Down: case Qt.Key_Tab: win.row = (win.row + 1) % n; break
            case Qt.Key_Up: case Qt.Key_Backtab: win.row = (win.row - 1 + n) % n; break
            case Qt.Key_Right: if (win.rows[win.row].id === "move") win.wsIndex = (win.wsIndex + 1) % win.workspaces.length; break
            case Qt.Key_Left: if (win.rows[win.row].id === "move") win.wsIndex = (win.wsIndex - 1 + win.workspaces.length) % win.workspaces.length; break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.run(win.rows[win.row].id); break
            case Qt.Key_Escape: case Qt.Key_M: win.close(); break
            default: return
            }
            event.accepted = true
        }
    }

    LyBox {
        id: box
        color: Theme.surface
        width: 300
        height: col.implicitHeight + Theme.s3 * 2
        x: win.menuX < 0 ? (win.width - width) / 2 : Math.min(Math.max(4, win.menuX), win.width - width - 4)
        // at the cursor (kept on screen), under the bar, or a third of the way down
        y: win.atCursor ? Math.min(Math.max(30 + 4, win.menuY), win.height - height - 4)
                        : (win.menuX < 0 ? (win.height - height) / 3 : 30 + 4)
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s3 }
            spacing: Theme.s2

            Text {   // which window this is for
                width: parent.width
                elide: Text.ElideRight
                text: win.title
                color: Theme.textDim
                bottomPadding: Theme.s1
                font { family: Theme.font; pointSize: Theme.small }
            }

            Repeater {
                model: win.rows
                Item {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.row
                    readonly property bool danger: modelData.id === "kill"
                    width: col.width
                    height: 20

                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.label
                        color: line.sel ? (line.danger ? Theme.error : Theme.text) : Theme.textDim
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Rectangle {   // accent underline on the selected line (not on "move to": its workspace gets it)
                        visible: line.sel && line.modelData.id !== "move"
                        anchors { left: label.left; right: label.right; top: label.bottom; topMargin: 1 }
                        height: 1
                        color: line.danger ? Theme.error : Theme.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        visible: line.modelData.id !== "move"
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.row = line.index
                        onClicked: win.run(line.modelData.id)
                    }

                    // "move to": the workspaces as plain numbers, then "new"
                    Row {
                        visible: line.modelData.id === "move"
                        anchors { left: label.right; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        spacing: Theme.s2
                        Repeater {
                            model: win.workspaces
                            Item {
                                id: ws
                                required property string modelData
                                required property int index
                                readonly property bool here: modelData === win.currentWs
                                readonly property bool picked: line.sel && index === win.wsIndex
                                width: wsText.implicitWidth; height: 20
                                Text {
                                    id: wsText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ws.modelData
                                    color: ws.picked ? Theme.text : Theme.textDim
                                    opacity: ws.here ? 0.4 : 1      // the window is already there
                                    font { family: Theme.font; pointSize: Theme.fontSize }
                                }
                                Rectangle {
                                    visible: ws.picked
                                    anchors { left: wsText.left; right: wsText.right; top: wsText.bottom; topMargin: 1 }
                                    height: 1
                                    color: Theme.primary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: ws.here ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onEntered: { win.row = line.index; win.wsIndex = ws.index }
                                    onClicked: { win.wsIndex = ws.index; win.run("move") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
