// The rice's own shell pieces, in the minimal style (THEME.md §3):
// the always-on top bar (one per screen), the app launcher, the window
// switcher (ALT + Tab), the shortcuts window (SUPER + H) and the display
// switcher (SUPER + P) and the window menu (right-click the bar's window
// title, or SUPER + M).
// noctalia still provides notifications, the control centre and OSDs; its own
// bar is switched off (bar.default.enabled = false in its config).
//
// Run:      qs -c rice -d     (started at login from Hyprland's autostart)
// Launcher: qs -c rice ipc call launcher toggle     (SUPER + Space)
// Shared look: Theme.qml, LyBox.qml, ActionButton.qml link to the wallhaven picker's.

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Launcher { id: launcher }
    Switcher { id: switcher }
    Shortcuts { id: shortcuts }
    DisplaySwitcher { id: display }
    WindowMenu { id: windowMenu }

    IpcHandler {
        target: "switcher"
        function next(): void { switcher.step(1) }      // ALT + Tab
        function prev(): void { switcher.step(-1) }     // ALT + Shift + Tab
        function open(): void { switcher.show(0) }
        function close(): void { switcher.close() }
        function select(i: int): void { switcher.selected = i }
        function pick(): void { switcher.pick() }
        function style(v: string): void { switcher.variant = v }   // strip | split | grid
        function state(): string { return (switcher.open ? "open " : "closed ") + switcher.selected + "/" + switcher.windows.length }
    }
    IpcHandler {
        target: "shortcuts"
        function toggle(): void { shortcuts.toggle() }
        function close(): void { shortcuts.close() }
        function search(q: string): void { shortcuts.show(); shortcuts.setQuery(q) }
        function results(): string { return shortcuts.results.map(r => r.keys + " = " + r.desc).join(" | ") }
    }

    IpcHandler {
        target: "display"
        function toggle(): void { display.open ? display.step(1) : display.show() }   // SUPER + P
        function close(): void { display.close() }
        function apply(): void { display.apply() }
        function state(): string { return (display.open ? "open " : "closed ") + display.current + " sel:" + display.selected + " ext:" + display.external }
    }

    IpcHandler {
        target: "windowmenu"
        function toggle(): void { windowMenu.open ? windowMenu.close() : windowMenu.show(-1) }   // SUPER + M
        function openAt(x: int): void { windowMenu.show(x) }
        function openAtCursor(): void { windowMenu.showAtCursor() }   // ALT + right-click
        function close(): void { windowMenu.close() }
        function state(): string { return (windowMenu.open ? "open " : "closed ") + windowMenu.addr + " rows:" + windowMenu.rows.map(r => r.id).join(",") + " ws:" + windowMenu.workspaces.join(",") }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle() }
        function open(): void { launcher.show() }
        function close(): void { launcher.close() }
        function query(text: string): void { launcher.show(); launcher.setQuery(text) }
        function state(): string { return (launcher.open ? "open" : "closed") + " matches:" + launcher.matches.map(a => a.name).join(", ") }
    }
}
