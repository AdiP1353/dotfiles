// App launcher (SUPER + Space), minimal style (THEME.md §3), laid out like
// the user's sketch: one 2px box; on the left the current wallpaper, inset
// with space around it; a 2px vertical line in the middle that stops short
// of the top and bottom; on the right a small bordered search box ("run:" and
// a block cursor) and under it the matching apps as small icons + lowercase
// names, the selected one bright with an accent underline.
// Keys: type to filter, Up/Down (or Tab) to move, Enter to launch, Esc to close.
// Apps start through uwsm, like the rest of the desktop's launchers.
// With nothing typed, your most-used apps come first. An app that's already
// open is focused (brought out of the background if hidden), not started again.
// "/" lists your setups (~/.config/rice/setups.conf): "/study" opens its apps
// on their workspaces; "/edit" opens the file.

import QtQuick
import Quickshell
import Quickshell.Io
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
    WlrLayershell.namespace: "rice-launcher"

    property string query: ""
    property int selected: 0
    readonly property int maxRows: 8

    function toggle() { open ? close() : show() }
    function show() {
        query = ""; field.text = ""; selected = 0
        wallProc.running = true          // refresh the wallpaper on every open
        open = true; field.forceActiveFocus()
    }

    // The current wallpaper, from noctalia.
    property string wallpaper: ""
    Process {
        id: wallProc
        command: ["noctalia", "msg", "wallpaper-get"]
        stdout: StdioCollector { onStreamFinished: win.wallpaper = text.trim().replace(/^['"]|['"]$/g, "") }
    }
    Component.onCompleted: wallProc.running = true
    function close() { open = false }
    function setQuery(t) { field.text = t; query = t; selected = 0 }

    // ---- what the query means ----
    readonly property string term: query.trim()

    // ---- launch counts, for "most used first" ----
    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/state/rice/launcher.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter { id: usage; property var counts: ({}) }
    }

    // Apps whose name, generic name or keywords contain the query; names that
    // start with it come first. With nothing typed: most used first.
    function appRows() {
        const q = term.toLowerCase()
        const counts = usage.counts || {}
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
        const hit = a => !q || a.name.toLowerCase().includes(q)
            || (a.genericName || "").toLowerCase().includes(q)
            || (a.keywords || []).some(k => k.toLowerCase().includes(q))
        return apps.filter(hit).sort((a, b) => {
            if (!q) return (counts[b.id] || 0) - (counts[a.id] || 0) || a.name.localeCompare(b.name)
            const pa = a.name.toLowerCase().startsWith(q) ? 0 : 1
            const pb = b.name.toLowerCase().startsWith(q) ? 0 : 1
            return pa - pb || a.name.localeCompare(b.name)
        }).slice(0, maxRows).map(a => ({
            kind: "app", entry: a, icon: Quickshell.iconPath(a.icon, "application-x-executable"),
            label: a.name.toLowerCase(),
            detail: !q && counts[a.id] ? counts[a.id] + "x" : (a.genericName || "").toLowerCase()
        }))
    }

    // "/name": the setups from ~/.config/rice/setups.conf (Setups.qml), and
    // "/edit" to open that file
    function setupRows() {
        const q = term.slice(1).toLowerCase()
        const r = Setups.list.filter(x => x.name.startsWith(q) || (q && x.name.includes(q)))
            .slice(0, maxRows - 1).map(x => ({
                kind: "setup", name: x.name, icon: "", label: "/" + x.name,
                detail: x.about || x.apps.map(a => a.app.replace(/^\$\s*/, "")).join(", ")
            }))
        if ("edit".startsWith(q)) r.push({ kind: "edit", icon: "", label: "/edit", detail: "change the setups (setups.conf)" })
        return r
    }

    readonly property var rows: term.startsWith("/") ? setupRows() : appRows()

    function activate(row) {
        if (!row) return
        if (row.kind === "setup") { Setups.run(row.name); close(); return }
        if (row.kind === "edit") { Quickshell.execDetached(["gnome-text-editor", Setups.path]); close(); return }
        const c = Object.assign({}, usage.counts || {}); c[row.entry.id] = (c[row.entry.id] || 0) + 1; usage.counts = c
        RiceApps.openOrFocus(row.entry)      // already open: take you to it; else start it
        close()
    }

    // kept for the IPC state check
    readonly property var matches: rows.map(r => ({ name: r.label }))

    MouseArea { anchors.fill: parent; onClicked: win.close() }   // click outside closes

    LyBox {
        id: box
        // Over windows, not a wallpaper: solid, so busy apps behind never
        // fight the text.
        color: Theme.surface
        anchors.centerIn: parent
        width: 820
        // Tall enough for a full list, so the box does not jump while typing.
        height: Math.max(col.implicitHeight, 300) + 32 * 2
        MouseArea { anchors.fill: parent }    // clicks inside stay inside

        readonly property int pad: 32       // space inside the box, as in the sketch

        // ---- left: the current wallpaper, inset ----
        Item {
            id: left
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 380
            Image {
                id: wall
                anchors.centerIn: parent
                width: parent.width - box.pad * 2
                height: Math.round(width * 3 / 4)
                source: win.wallpaper ? "file://" + win.wallpaper : ""
                sourceSize.width: 640
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                clip: true
                // image outline: pure white/black at 10% (THEME.md)
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Theme.imageOutline }
            }
        }

        // ---- the rice's 2px line, stopping short of top and bottom ----
        Rectangle {
            id: divider
            anchors { left: left.right; top: parent.top; bottom: parent.bottom; topMargin: box.pad; bottomMargin: box.pad }
            width: 2
            color: Theme.textDim
        }

        // ---- right: search box, then the apps ----
        Column {
            id: col
            anchors { left: divider.right; right: parent.right; top: parent.top
                      leftMargin: box.pad; rightMargin: box.pad; topMargin: box.pad }
            spacing: Theme.s2

            LyBox {   // the small search box at the top of the column
                width: parent.width
                height: 34
              Row {
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                Text {
                    id: label
                    text: "run: "
                    color: Theme.text
                    font { family: Theme.font; pointSize: Theme.fontSize }
                }
                TextInput {
                    id: field
                    width: parent.width - label.width
                    color: Theme.text
                    font { family: Theme.font; pointSize: Theme.fontSize }
                    onTextEdited: { win.query = text; win.selected = 0 }
                    cursorDelegate: Rectangle {
                        width: 7
                        color: Theme.text
                        visible: field.activeFocus && blink.on
                        Timer {
                            id: blink
                            property bool on: true
                            interval: 530; running: field.activeFocus; repeat: true
                            onTriggered: on = !on
                            onRunningChanged: on = true
                        }
                    }
                    Keys.onPressed: event => {
                        const n = win.rows.length
                        switch (event.key) {
                        case Qt.Key_Escape: win.close(); break
                        case Qt.Key_Down: case Qt.Key_Tab: if (n) win.selected = (win.selected + 1) % n; break
                        case Qt.Key_Up: case Qt.Key_Backtab: if (n) win.selected = (win.selected - 1 + n) % n; break
                        case Qt.Key_Return: case Qt.Key_Enter: win.activate(win.rows[win.selected]); break
                        default: return
                        }
                        event.accepted = true
                    }
                }
              }
            }

            Item { width: 1; height: Theme.s2 }

            Repeater {
                model: win.rows
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.selected
                    width: col.width
                    height: Math.max(name.implicitHeight, 16) + 6
                    IconImage {
                        id: icon
                        anchors.verticalCenter: name.verticalCenter
                        implicitSize: 16
                        visible: !!modelData.icon
                        width: visible ? 16 : 0
                        source: modelData.icon || ""
                        opacity: parent.sel ? 1 : 0.75
                    }
                    Text {
                        id: name
                        anchors { left: icon.right; leftMargin: icon.visible ? Theme.s2 : 0 }
                        width: Math.min(implicitWidth, parent.width * 0.5)
                        elide: Text.ElideRight
                        text: modelData.label
                        color: parent.sel ? Theme.text : Theme.textDim
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Text {
                        anchors { right: parent.right; baseline: name.baseline }
                        width: parent.width * 0.4
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: modelData.detail || ""
                        color: Theme.textDim
                        opacity: 0.7
                        font { family: Theme.font; pointSize: Theme.small }
                    }
                    Rectangle {   // accent underline on the selected app
                        visible: parent.sel
                        anchors { left: name.left; right: name.right; top: name.bottom; topMargin: 1 }
                        height: 1
                        color: Theme.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.selected = index
                        onClicked: win.activate(modelData)
                    }
                }
            }

            Text {
                visible: win.rows.length === 0
                text: "no matches"
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
        }
    }
}
