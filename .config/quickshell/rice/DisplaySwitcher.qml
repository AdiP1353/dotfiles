// Display switcher (SUPER + P), like Windows' Win + P, minimal style
// (THEME.md §3): one 2px box with four plain lines, the selected one bright
// with an accent underline, the current mode marked "current".
//   pc screen only       laptop panel on, external screen off
//   duplicate            external mirrors the laptop panel
//   extend               external to the right of the laptop panel
//   second screen only   laptop panel off, external on
// Keys: Up/Down (or SUPER + P again) to move, Enter to apply, Esc to close.
//
// Applied live through `hyprctl eval` (Hyprland here uses a Lua config) and
// saved to ~/.config/hypr/display-mode.lua, which config/monitors.lua loads
// after nwg-displays' layout, so the choice survives reloads and reboots.
// "second screen only" is applied live but never saved: booting without the
// external screen plugged in must never leave every display switched off.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: win
    property bool open: false
    visible: open

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "rice-display"

    readonly property var modes: [
        { id: "pc",        label: "pc screen only" },
        { id: "duplicate", label: "duplicate" },
        { id: "extend",    label: "extend" },
        { id: "second",    label: "second screen only" }
    ]
    property int selected: 0
    property string current: "pc"
    property string internal: "eDP-1"
    property string external: ""          // "" when no second screen is connected
    property string status: ""

    function show() {
        status = ""
        monProc.running = true             // re-read the screens on every open
        open = true
        keys.forceActiveFocus()
    }
    function step(dir) {
        if (!open) { show(); return }
        selected = (selected + dir + modes.length) % modes.length
    }
    function close() { open = false }

    // Which screens exist (including switched-off ones), and the current mode.
    Process {
        id: monProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let mons = []
                try { mons = JSON.parse(text) } catch (e) {}
                const inner = mons.find(m => /^(eDP|LVDS|DSI)/.test(m.name))
                const outer = mons.find(m => m !== inner)
                win.internal = inner ? inner.name : "eDP-1"
                win.external = outer ? outer.name : ""
                if (!outer || outer.disabled) win.current = "pc"
                else if (inner && inner.disabled) win.current = "second"
                else if (outer.mirrorOf && outer.mirrorOf !== "none") win.current = "duplicate"
                else win.current = "extend"
                win.selected = win.modes.findIndex(m => m.id === win.current)
            }
        }
    }

    function available(id) { return id === "pc" || win.external !== "" }

    function luaFor(id) {
        const I = win.internal, E = win.external
        const on = (o, pos, extra) => 'hl.monitor({ output = "' + o + '", mode = "' + (o === I ? "highrr" : "preferred")
                                      + '", position = "' + pos + '", scale = 1' + (extra || "") + ' })'
        const off = o => 'hl.monitor({ output = "' + o + '", disabled = true })'
        switch (id) {
        case "pc":        return E ? [on(I, "0x0"), off(E)] : [on(I, "0x0")]
        case "duplicate": return [on(I, "0x0"), on(E, "auto", ', mirror = "' + I + '"')]
        case "extend":    return [on(I, "0x0"), on(E, "auto-right")]
        case "second":    return [on(E, "0x0"), off(I)]
        }
        return []
    }

    function apply() {
        const m = modes[selected]
        if (!available(m.id)) { status = "no second screen connected"; return }
        const lines = luaFor(m.id)
        applyProc.command = ["hyprctl", "eval", lines.join("\n")]
        applyProc.running = true
        // Save it for reloads and reboots (except "second": see the header).
        const file = Quickshell.env("HOME") + "/.config/hypr/display-mode.lua"
        if (m.id === "second")
            saveProc.command = ["rm", "-f", file]
        else
            saveProc.command = ["sh", "-c", 'printf "%s\\n" "$@" > "' + file + '"', "sh",
                                "-- Display mode chosen with SUPER + P (rice display switcher): " + m.label].concat(lines)
        saveProc.running = true
        close()
    }
    Process { id: applyProc }
    Process { id: saveProc }

    MouseArea { anchors.fill: parent; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Down: case Qt.Key_Tab: case Qt.Key_P: win.step(1); break
            case Qt.Key_Up: case Qt.Key_Backtab: win.step(-1); break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.apply(); break
            case Qt.Key_Escape: win.close(); break
            default: return
            }
            event.accepted = true
        }
    }

    LyBox {
        anchors.centerIn: parent
        color: Theme.surface
        width: 360
        height: col.implicitHeight + Theme.s4 * 2
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s2

            Text {
                text: "display"
                color: Theme.text
                bottomPadding: Theme.s1
                font { family: Theme.font; pointSize: Theme.fontSize }
            }

            Repeater {
                model: win.modes
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.selected
                    readonly property bool ok: win.available(modelData.id)
                    width: col.width
                    height: 22
                    Text {
                        id: name
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.sel && parent.ok ? Theme.text : Theme.textDim
                        opacity: parent.ok ? 1 : 0.5
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: modelData.id === win.current ? "current" : ""
                        color: Theme.textDim
                        font { family: Theme.font; pointSize: Theme.small }
                    }
                    Rectangle {   // accent underline on the selected mode
                        visible: parent.sel
                        anchors { left: name.left; right: name.right; top: name.bottom; topMargin: 1 }
                        height: 1
                        color: parent.ok ? Theme.primary : Theme.textDim
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.ok ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: win.selected = index
                        onClicked: { win.selected = index; win.apply() }
                    }
                }
            }

            Text {
                text: win.status !== "" ? win.status
                      : (win.external === "" ? "no second screen connected" : win.internal.toLowerCase() + " + " + win.external.toLowerCase())
                color: win.status !== "" ? Theme.error : Theme.textDim
                topPadding: Theme.s1
                font { family: Theme.font; pointSize: Theme.small }
            }
        }
    }
}
