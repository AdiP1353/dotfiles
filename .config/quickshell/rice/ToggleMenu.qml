// The bar's toggles, minimal style (THEME.md §3): right-click the clock for
// one 2px box under it with two lowercase lines, each showing its state:
//   do not disturb   on / off      (SUPER + SHIFT + D)
//   stay awake       on / off      (SUPER + SHIFT + A)
// Click or Enter flips one; Esc or a click outside closes. Opens instantly.

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
    WlrLayershell.namespace: "rice-toggles"

    property real menuX: 0
    property int row: 0
    readonly property var rows: [
        { label: "do not disturb", on: RiceStatus.dnd, flip: () => RiceStatus.toggleDnd() },
        { label: "stay awake", on: RiceStatus.awake, flip: () => RiceStatus.toggleAwake() }
    ]

    function show(x) { menuX = x; row = 0; open = true; keys.forceActiveFocus() }
    function close() { open = false }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Down: case Qt.Key_Up: case Qt.Key_Tab: case Qt.Key_Backtab: win.row = 1 - win.row; break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.rows[win.row].flip(); break
            case Qt.Key_Escape: win.close(); break
            default: return
            }
            event.accepted = true
        }
    }

    LyBox {
        color: Theme.surface
        width: 260
        height: col.implicitHeight + Theme.s3 * 2
        x: Math.min(Math.max(4, win.menuX - width / 2), win.width - width - 4)
        y: 30 + 4
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: Theme.s3; y: Theme.s3
            width: parent.width - Theme.s3 * 2
            spacing: Theme.s2
            Repeater {
                model: win.rows
                Item {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.row
                    width: col.width; height: 20
                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.label
                        color: line.sel ? Theme.text : Theme.textDim
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Text {   // the state: bright when on
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: line.modelData.on ? "on" : "off"
                        color: line.modelData.on ? Theme.text : Theme.textDim
                        opacity: line.modelData.on ? 1 : 0.6
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Rectangle {   // accent underline on the selected line
                        visible: line.sel
                        anchors { left: label.left; top: label.bottom; topMargin: 1 }
                        width: label.contentWidth; height: 1
                        color: Theme.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.row = line.index
                        onClicked: line.modelData.flip()
                    }
                }
            }
        }
    }
}
