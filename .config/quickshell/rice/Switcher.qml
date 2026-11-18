// Window switcher (ALT + Tab), minimal style (THEME.md §3), with live
// previews of the windows. Three layouts to pick from (`variant`):
//   strip   a row of preview tiles in one 2px box, name under each,
//           the selected tile framed in the accent (like the picker's grid)
//   split   the launcher's layout: a big live preview of the selected window
//           on the left, a 2px line, the window list on the right
//   grid    an overview: one column per workspace, its windows as tiles
//
// ALT + Tab opens it on the previous window; keep holding ALT and press Tab
// (Shift+Tab back, or the arrows) to move; let go of ALT to switch.
// Enter / click switch too, Esc closes. The bar's window title opens it too.
// Previews: the selected window is live, the others are a single frame.
// Opens and closes instantly (keyboard, many times a day).

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

    property string variant: "strip"     // strip (chosen) | split | grid
    property int selected: 0
    property var windows: []              // most recently focused first

    function ipcOf(w) { return (w && w.lastIpcObject) || ({}) }
    function cls(w) {
        const c = (ipcOf(w).class || "window").toLowerCase()
        return ({ vesktop: "discord" })[c] || c.split(".").pop()
    }
    function icon(w) {
        const c = (ipcOf(w).class || "").toLowerCase()
        return Quickshell.iconPath(({ vesktop: "discord" })[c] || c, "application-x-executable")
    }
    function wsName(w) { const ws = ipcOf(w).workspace; return ws ? String(ws.name).replace(/^special:/, "") : "" }

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
            case Qt.Key_Tab: case Qt.Key_Right: case Qt.Key_Down: win.step(1); break
            case Qt.Key_Backtab: case Qt.Key_Left: case Qt.Key_Up: win.step(-1); break
            case Qt.Key_Return: case Qt.Key_Enter: win.pick(); break
            case Qt.Key_Escape: win.close(); break
            default: return
            }
            event.accepted = true
        }
        // Letting go of ALT switches, as with any ALT + Tab.
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt && win.open) { win.pick(); event.accepted = true } }
    }

    // ---------------------------------------------------------------- pieces
    // A window's picture, fitted inside its area, with the rice's image outline.
    component Preview: Item {
        id: pv
        required property var toplevel
        property bool live: false
        ScreencopyView {
            id: sc
            readonly property real ar: hasContent && sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
            anchors.centerIn: parent
            width: Math.min(pv.width, pv.height * ar)
            height: width / ar
            captureSource: win.open && pv.toplevel ? pv.toplevel.wayland : null
            live: pv.live && win.open
            Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Theme.imageOutline }
        }
        IconImage {   // until a frame arrives (or if the window can't be captured)
            visible: !sc.hasContent
            anchors.centerIn: parent
            implicitSize: Math.min(48, pv.height / 3)
            source: win.icon(pv.toplevel)
            opacity: 0.6
        }
    }

    // A tile: preview, then "class   ws" under it; accent frame when selected.
    component Tile: Item {
        id: tile
        required property var toplevel
        property int idx: 0
        property real previewW: 300
        property real previewH: 169
        readonly property bool sel: idx === win.selected
        width: previewW + 2 * 10
        height: previewH + 2 * 10 + 26
        Rectangle {     // the frame: 2px dim, accent when selected
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: tile.sel ? Theme.primary : Theme.outlineVariant
        }
        Preview {
            id: tp
            toplevel: tile.toplevel
            live: tile.sel
            x: 10; y: 10
            width: tile.previewW; height: tile.previewH
        }
        Text {
            anchors { left: parent.left; leftMargin: 10; right: tws.left; rightMargin: 8; top: tp.bottom; topMargin: 4 }
            elide: Text.ElideRight
            text: win.cls(tile.toplevel)
            color: tile.sel ? Theme.text : Theme.textDim
            font { family: Theme.font; pointSize: Theme.small }
        }
        Text {
            id: tws
            anchors { right: parent.right; rightMargin: 10; top: tp.bottom; topMargin: 4 }
            text: win.wsName(tile.toplevel)
            color: Theme.textDim
            opacity: 0.7
            font { family: Theme.font; pointSize: Theme.small }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: win.selected = tile.idx
            onClicked: { win.selected = tile.idx; win.pick() }
        }
    }

    // ---------------------------------------------------------------- strip
    LyBox {
        visible: win.variant === "strip"
        anchors.centerIn: parent
        color: Theme.surface
        readonly property int perRow: Math.max(1, Math.min(win.windows.length, 5))
        width: flowStrip.implicitWidth + Theme.s4 * 2
        height: stripCol.implicitHeight + Theme.s4 * 2
        MouseArea { anchors.fill: parent }
        Column {
            id: stripCol
            anchors { left: parent.left; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s3
            Text {
                text: "windows"
                color: Theme.text
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
            Grid {
                id: flowStrip
                columns: parent.parent.perRow
                spacing: Theme.s3
                Repeater {
                    model: win.variant === "strip" ? win.windows : []
                    Tile { required property var modelData; required property int index; toplevel: modelData; idx: index }
                }
            }
            Text {   // the selected window's title, under the strip
                width: flowStrip.implicitWidth
                elide: Text.ElideRight
                text: win.windows[win.selected] ? (win.windows[win.selected].title || "").toLowerCase() : "no windows"
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.small }
            }
        }
    }

    // ---------------------------------------------------------------- split
    LyBox {
        id: splitBox
        visible: win.variant === "split"
        anchors.centerIn: parent
        color: Theme.surface
        readonly property int pad: 32
        width: 760 + 2 + 440 + pad * 4
        height: Math.max(428 + 30, splitList.implicitHeight) + pad * 2
        MouseArea { anchors.fill: parent }

        Item {   // left: the selected window, live, big
            id: bigSide
            x: splitBox.pad; y: splitBox.pad
            width: 760; height: splitBox.height - splitBox.pad * 2
            Preview {
                id: big
                toplevel: win.variant === "split" ? (win.windows[win.selected] || null) : null
                live: true
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 428
            }
            Text {
                anchors { left: parent.left; right: parent.right; top: big.bottom; topMargin: Theme.s2 }
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: win.windows[win.selected] ? (win.windows[win.selected].title || "").toLowerCase() : ""
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.small }
            }
        }
        Rectangle {   // the rice's 2px line
            id: splitLine
            x: bigSide.x + bigSide.width + splitBox.pad
            y: splitBox.pad; width: 2; height: splitBox.height - splitBox.pad * 2
            color: Theme.textDim
        }
        Column {   // right: the list, like before
            id: splitList
            x: splitLine.x + 2 + splitBox.pad
            y: splitBox.pad
            width: 440
            spacing: Theme.s2
            Text {
                text: "windows"
                color: Theme.text
                bottomPadding: Theme.s1
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
            Repeater {
                model: win.variant === "split" ? win.windows : []
                Item {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.selected
                    width: splitList.width
                    height: 22
                    IconImage {
                        id: li
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        source: win.icon(line.modelData)
                        opacity: line.sel ? 1 : 0.75
                    }
                    Text {
                        id: lc
                        anchors { left: li.right; leftMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                        width: 110
                        elide: Text.ElideRight
                        text: win.cls(line.modelData)
                        color: line.sel ? Theme.text : Theme.textDim
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Text {
                        anchors { left: lc.right; leftMargin: Theme.s3; right: lw.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: (line.modelData.title || "").toLowerCase()
                        color: Theme.textDim
                        opacity: line.sel ? 1 : 0.7
                        font { family: Theme.font; pointSize: Theme.small }
                    }
                    Text {
                        id: lw
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: win.wsName(line.modelData)
                        color: Theme.textDim
                        font { family: Theme.font; pointSize: Theme.small }
                    }
                    Rectangle {
                        visible: line.sel
                        anchors { left: lc.left; top: lc.bottom; topMargin: 1 }
                        width: lc.contentWidth
                        height: 1
                        color: Theme.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.selected = line.index
                        onClicked: { win.selected = line.index; win.pick() }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- grid
    // one column per workspace, its windows stacked under it
    LyBox {
        id: gridBox
        visible: win.variant === "grid"
        anchors.centerIn: parent
        color: Theme.surface
        width: Math.min(win.width - 80, gridRow.implicitWidth + Theme.s4 * 2)
        height: Math.min(win.height - 80, gridRow.implicitHeight + Theme.s4 * 2)
        clip: true
        MouseArea { anchors.fill: parent }

        // windows grouped by workspace, in workspace order
        readonly property var groups: {
            if (win.variant !== "grid") return []
            const by = {}
            win.windows.forEach((w, i) => { const n = win.wsName(w) || "?"; (by[n] = by[n] || []).push({ w: w, i: i }) })
            return Object.keys(by).sort((a, b) => (parseInt(a) || 999) - (parseInt(b) || 999) || a.localeCompare(b))
                .map(n => ({ name: n, items: by[n] }))
        }

        Row {
            id: gridRow
            x: Theme.s4; y: Theme.s4
            spacing: Theme.s4
            Repeater {
                model: gridBox.groups
                Column {
                    id: grp
                    required property var modelData
                    spacing: Theme.s2
                    Text {
                        text: "workspace " + grp.modelData.name
                        color: Theme.textDim
                        font { family: Theme.font; pointSize: Theme.small }
                    }
                    Repeater {
                        model: grp.modelData.items
                        Tile {
                            required property var modelData
                            toplevel: modelData.w
                            idx: modelData.i
                            previewW: 300; previewH: 169
                        }
                    }
                }
            }
        }
    }
}
