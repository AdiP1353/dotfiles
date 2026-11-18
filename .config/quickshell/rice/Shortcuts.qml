// Shortcuts window (SUPER + H), minimal style (THEME.md §3): one 2px box with
// your keybinds in four plain columns. Keys bright, what they do dim.
// Esc, SUPER + H again, or a click outside closes it.
// The list mirrors ~/.config/hypr/config/binds.lua; update both together.

import QtQuick
import Quickshell
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
    WlrLayershell.namespace: "rice-shortcuts"

    function toggle() { open = !open; if (open) keys.forceActiveFocus() }
    function close() { open = false }

    readonly property var sections: [
        { title: "windows", rows: [
            ["super q", "close (spotify: hide)"],
            ["super f", "fullscreen"],
            ["super d", "maximise"],
            ["super alt space", "float / tile"],
            ["super j", "toggle split"],
            ["super arrows", "focus"],
            ["super shift arrows", "move window"],
            ["alt tab", "switch windows"],
            ["super escape", "kill (click a window)"],
            ["super drag", "move / resize"],
            ["alt right-click", "window menu at the cursor"],
            ["super m", "window menu (or right-click title)"] ] },
        { title: "apps", rows: [
            ["super space", "launcher"],
            ["super w", "wallpapers"],
            ["super t", "terminal"],
            ["super e", "files"],
            ["super n", "editor"],
            ["super c", "calculator"],
            ["super 1 - 5", "firefox spotify claude obsidian zed"],
            ["super v", "clipboard"],
            ["super .", "emoji"],
            ["ctrl shift escape", "btop"] ] },
        { title: "workspaces", rows: [
            ["super ctrl 1 - 9", "go to"],
            ["super shift 1 - 9", "move window, follow"],
            ["super shift alt 1 - 9", "move window, stay"],
            ["super ctrl left right", "previous / next"],
            ["super ctrl up", "last one"],
            ["super ctrl down", "new empty"],
            ["super s", "scratchpad"],
            ["super shift s", "send to scratchpad"],
            ["super b", "background apps"],
            ["super scroll", "cycle"] ] },
        { title: "system", rows: [
            ["super l", "lock"],
            ["super alt c", "session menu"],
            ["super x", "control centre"],
            ["super z", "settings"],
            ["super a", "notifications"],
            ["super h", "this window"],
            ["super p", "display mode"],
            ["super shift p", "colour picker"],
            ["print", "screenshot region"],
            ["super + / -", "zoom"],
            ["super tab", "window overview"] ] }
    ]

    MouseArea { anchors.fill: parent; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_H) { win.close(); event.accepted = true }
        }
    }

    LyBox {
        anchors.centerIn: parent
        color: Theme.surface
        width: grid.implicitWidth + 32 * 2
        height: col.implicitHeight + 32 * 2
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; top: parent.top; margins: 32 }
            spacing: Theme.s4

            Text {
                text: "shortcuts"
                color: Theme.text
                font { family: Theme.font; pointSize: Theme.fontSize }
            }

            Row {
                id: grid
                spacing: 28
                Repeater {
                    model: win.sections
                    Column {
                        required property var modelData
                        spacing: Theme.s2
                        Text {
                            text: modelData.title
                            color: Theme.textDim
                            font { family: Theme.font; pointSize: Theme.small }
                            bottomPadding: Theme.s1
                        }
                        Repeater {
                            model: modelData.rows
                            Row {
                                required property var modelData
                                spacing: Theme.s3
                                Text {
                                    width: 172
                                    text: modelData[0]
                                    color: Theme.text
                                    font { family: Theme.font; pointSize: Theme.small }
                                }
                                Text {
                                    width: 176
                                    elide: Text.ElideRight
                                    text: modelData[1]
                                    color: Theme.textDim
                                    font { family: Theme.font; pointSize: Theme.small }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
