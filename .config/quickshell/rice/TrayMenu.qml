// Tray menu, minimal style (THEME.md §3): right-click a tray icon in the top
// bar for that app's own menu, redrawn as plain lowercase lines in one 2px
// box under the icon, and a "close <app>" line at the bottom that runs the
// app's own Quit (so it closes properly, like choosing Quit in its menu).
// Disabled lines (e.g. Claude's "usage") are dim and can't be picked;
// submenus open in place ("‹ back" returns).
// Keys: Up/Down, Enter, Esc. Opens and closes instantly.

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
    WlrLayershell.namespace: "rice-traymenu"

    property var item: null          // the SystemTrayItem
    property real menuX: 0
    property int row: 0
    property var stack: []           // submenus we went into

    function appName(it) {
        if (!it) return ""
        const n = String(it.title || it.tooltipTitle || it.id || "app").toLowerCase()
        if (n.startsWith("vesktop")) return "discord"
        return n.replace(/_status_icon_\d+$/, "").replace(/_client$/, "")
    }

    function show(it, x) {
        item = it; menuX = x; stack = []; opener.menu = it ? it.menu : null
        row = 0; open = true; keys.forceActiveFocus()
    }
    function close() { open = false; opener.menu = null }

    QsMenuOpener { id: opener }

    readonly property var entries: opener.children ? opener.children.values : []
    // the app's own Quit / Exit, shown separately as "close <app>"
    readonly property var quitEntry: stack.length ? null
        : entries.find(e => !e.isSeparator && /^(quit|exit)\b/i.test(String(e.text).trim())) || null

    // the lines: [back], the app's entries (without Quit), [close]
    readonly property var rows: {
        const r = []
        if (stack.length) r.push({ kind: "back", text: "‹ back", enabled: true })
        for (const e of entries) {
            if (e === quitEntry) continue
            if (e.isSeparator) { if (r.length && r[r.length - 1].kind !== "sep") r.push({ kind: "sep" }); continue }
            r.push({ kind: "entry", entry: e, enabled: e.enabled,
                     text: (e.checkState === Qt.Checked ? "✓ " : "") + String(e.text).replace(/&/g, "").toLowerCase()
                           + (e.hasChildren ? "  ›" : "") })
        }
        while (r.length && r[r.length - 1].kind === "sep") r.pop()
        if (quitEntry) { r.push({ kind: "sep" }); r.push({ kind: "close", text: "close " + appName(item), enabled: true }) }
        if (!r.some(x => x.kind !== "sep")) r.push({ kind: "activate", text: "open " + appName(item), enabled: true })
        return r
    }
    function selectable(i) { const x = rows[i]; return x && x.kind !== "sep" && x.enabled }
    function move(dir) {
        const n = rows.length
        for (let k = 1; k <= n; k++) { const i = (row + dir * k + n * 2) % n; if (selectable(i)) { row = i; return } }
    }
    onRowsChanged: if (!selectable(row)) { row = -1; move(1) }

    function activate(i) {
        const x = rows[i]
        if (!x || !selectable(i)) return
        switch (x.kind) {
        case "back": { const s = stack.slice(); opener.menu = s.pop(); stack = s; row = 0; return }
        case "close": quitEntry.triggered(); break
        case "activate": item.activate(); break
        case "entry":
            if (x.entry.hasChildren) { stack = stack.concat([opener.menu]); opener.menu = x.entry; row = 0; return }
            x.entry.triggered(); break
        }
        close()
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Down: case Qt.Key_Tab: win.move(1); break
            case Qt.Key_Up: case Qt.Key_Backtab: win.move(-1); break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.activate(win.row); break
            case Qt.Key_Escape: win.close(); break
            default: return
            }
            event.accepted = true
        }
    }

    LyBox {
        id: box
        color: Theme.surface
        width: Math.max(220, col.implicitWidth + Theme.s3 * 2)
        height: col.implicitHeight + Theme.s3 * 2
        x: Math.min(Math.max(4, win.menuX - width / 2), win.width - width - 4)
        y: 30 + 4          // just under the bar
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: Theme.s3; y: Theme.s3
            spacing: Theme.s2

            Text {   // which app this is
                text: win.appName(win.item)
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
                    readonly property bool sep: modelData.kind === "sep"
                    readonly property bool sel: index === win.row
                    readonly property bool danger: modelData.kind === "close"
                    width: Math.max(label.implicitWidth, box.width - Theme.s3 * 2)
                    height: sep ? 2 : 20

                    Rectangle {   // the rice's 2px line between groups
                        visible: line.sep
                        width: parent.width; height: 2
                        color: Theme.outlineVariant
                    }
                    Text {
                        id: label
                        visible: !line.sep
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.text || ""
                        color: !line.modelData.enabled ? Theme.outlineVariant
                             : line.sel ? (line.danger ? Theme.error : Theme.text)
                             : (line.danger ? Theme.error : Theme.textDim)
                        opacity: line.danger && !line.sel ? 0.8 : 1
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Rectangle {   // accent underline on the selected line (error tone for close)
                        visible: line.sel && !line.sep
                        anchors { left: label.left; top: label.bottom; topMargin: 1 }
                        width: label.contentWidth; height: 1
                        color: line.danger ? Theme.error : Theme.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        visible: !line.sep && line.modelData.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.row = line.index
                        onClicked: win.activate(line.index)
                    }
                }
            }
        }
    }
}
