// Window switcher (ALT + Tab), minimal style (THEME.md §3): one 2px box with
// the open windows as plain lowercase lines, "class   title", the selected
// one bright with an accent underline, like the launcher.
//
// ALT + Tab opens it on the previous window; keep holding ALT and press Tab
// (Shift+Tab back) to move; let go of ALT to switch. Enter / click switch too,
// Esc closes. The bar's window title opens it as well.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
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
    WlrLayershell.namespace: "rice-switcher"

    property int selected: 0
    property var windows: []          // most recently focused first

    function refresh() {
        Hyprland.refreshToplevels()
        // lastIpcObject.focusHistoryID: 0 = focused now, 1 = before that, ...
        windows = Hyprland.toplevels.values.slice().sort((a, b) =>
            ((a.lastIpcObject && a.lastIpcObject.focusHistoryID) ?? 99) - ((b.lastIpcObject && b.lastIpcObject.focusHistoryID) ?? 99))
    }
    function show(start) {
        refresh()
        selected = Math.min(start, Math.max(0, windows.length - 1))
        open = true
        keys.forceActiveFocus()
    }
    function step(dir) {
        if (!open) { show(1); return }
        const n = windows.length
        if (n) selected = (selected + dir + n) % n
    }
    function pick() {
        const w = windows[selected]
        open = false
        if (!w) return
        // Hyprland here uses a Lua config, so dispatches are Lua.
        const addr = String(w.address).startsWith("0x") ? w.address : "0x" + w.address
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })')
    }
    function close() { open = false }

    MouseArea { anchors.fill: parent; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Tab: win.step(1); break
            case Qt.Key_Backtab: win.step(-1); break
            case Qt.Key_Down: win.step(1); break
            case Qt.Key_Up: win.step(-1); break
            case Qt.Key_Return: case Qt.Key_Enter: win.pick(); break
            case Qt.Key_Escape: win.close(); break
            default: return
            }
            event.accepted = true
        }
        // Letting go of ALT switches, as with any ALT + Tab.
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt && win.open) { win.pick(); event.accepted = true } }
    }

    LyBox {
        anchors.centerIn: parent
        color: Theme.surface
        width: 560
        height: col.implicitHeight + Theme.s4 * 2
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s2

            Text {
                text: "windows"
                color: Theme.text
                font { family: Theme.font; pointSize: Theme.fontSize }
                bottomPadding: Theme.s1
            }

            Repeater {
                model: win.windows
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.selected
                    readonly property var ipc: modelData.lastIpcObject || ({})
                    width: col.width
                    height: 22
                    IconImage {
                        id: icon
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        source: Quickshell.iconPath(({ vesktop: "discord" })[(ipc.class || "").toLowerCase()] || (ipc.class || "").toLowerCase(), "application-x-executable")
                        opacity: parent.sel ? 1 : 0.75
                    }
                    Text {
                        id: cls
                        anchors { left: icon.right; leftMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                        width: 120
                        elide: Text.ElideRight
                        // last part of the app id: com.anthropic.claude -> claude
                        text: ({ vesktop: "discord" })[(ipc.class || "").toLowerCase()] || ((ipc.class || "window").split(".").pop()).toLowerCase()
                        color: parent.sel ? Theme.text : Theme.textDim
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Text {
                        anchors { left: cls.right; leftMargin: Theme.s3; right: ws.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: (modelData.title || "").toLowerCase()
                        color: Theme.textDim
                        opacity: parent.sel ? 1 : 0.7
                        font { family: Theme.font; pointSize: Theme.small }
                    }
                    Text {
                        id: ws
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: ipc.workspace ? String(ipc.workspace.name) : ""
                        color: Theme.textDim
                        font { family: Theme.font; pointSize: Theme.small }
                    }
                    Rectangle {   // accent underline on the selected window
                        visible: parent.sel
                        anchors { left: cls.left; right: cls.right; top: cls.bottom; topMargin: 1 }
                        height: 1
                        color: Theme.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.selected = index
                        onClicked: { win.selected = index; win.pick() }
                    }
                }
            }

            Text {
                visible: win.windows.length === 0
                text: "no windows"
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
        }
    }
}
