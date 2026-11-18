// Shortcuts window (SUPER + H), minimal style (THEME.md §3): one 2px box with
// a "search:" field on top and your keybinds below.
//   nothing typed   all keybinds in four plain columns, keys in the accent, what they do dim
//   typing          a fuzzy search over the keys, what they do and extra words
//                   for each (e.g. "mv ws", "screensht", "volume", "new desktop");
//                   the best matches first, matched letters bright
// Keys: type to search, Up/Down move through the results, Esc clears the
// search (or closes when it is empty). SUPER + H again or a click outside closes.
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

    property string query: ""
    property int selected: 0

    function toggle() { open ? close() : show() }
    function show() { field.text = ""; query = ""; selected = 0; open = true; field.forceActiveFocus() }
    function close() { open = false }
    function setQuery(q) { field.text = q; query = q; selected = 0 }

    // [keys, what it does, extra words people might search for]
    readonly property var sections: [
        { title: "windows", rows: [
            ["super q", "close (spotify, discord: hide)", "quit exit kill app"],
            ["super escape", "kill (click a window)", "force quit frozen"],
            ["alt right-click", "window menu at the cursor", "move workspace float pin close options"],
            ["super m", "window menu (focused window)", "move workspace float pin close options"],
            ["super f", "fullscreen", "full screen"],
            ["super d", "maximise", "maximize bigger"],
            ["super alt space", "float / tile", "floating tiling"],
            ["super j", "toggle split", "layout direction"],
            ["super arrows", "focus", "select window left right up down"],
            ["super shift arrows", "move window", "swap position"],
            ["super drag", "move window (mouse)", "left click drag"],
            ["super right-drag", "resize window (mouse)", "size bigger smaller"],
            ["alt tab", "switch windows", "switcher next overview"] ] },
        { title: "apps", rows: [
            ["super space", "launcher", "run open apps search start"],
            ["super w", "wallpapers", "wallhaven picker background"],
            ["super shift w", "noctalia wallpaper panel", "background"],
            ["super t", "terminal", "kitty shell console"],
            ["copilot key", "drop-down terminal", "quake dropdown kitty quick shell"],
            ["super e", "files", "dolphin file manager explorer"],
            ["super n", "editor", "text notes gnome"],
            ["super c", "calculator", "maths calc"],
            ["super 1 - 5", "firefox spotify claude obsidian zed", "browser music notes code"],
            ["super v", "clipboard", "copy paste history"],
            ["super .", "emoji", "emoticons symbols"],
            ["ctrl shift escape", "btop", "task manager processes system monitor"] ] },
        { title: "workspaces", rows: [
            ["super ctrl 1 - 9", "go to", "switch desktop workspace number"],
            ["super shift 1 - 9", "move window, follow", "send desktop workspace"],
            ["super shift alt 1 - 9", "move window, stay", "send desktop workspace silent"],
            ["super ctrl left right", "previous / next", "desktop switch"],
            ["super ctrl up", "last one", "previous back desktop"],
            ["super ctrl down", "new empty", "new desktop workspace"],
            ["super ctrl shift left right", "move window prev / next", "send desktop workspace"],
            ["super ctrl shift down", "move window to a new one", "new desktop workspace send"],
            ["super scroll", "cycle", "mouse wheel desktop"],
            ["super shift scroll", "move window to monitor", "screen display mouse wheel"],
            ["super s", "scratchpad", "hidden special workspace"],
            ["super shift s", "send to scratchpad", "hide special workspace"],
            ["super b", "background apps", "hidden spotify discord"] ] },
        { title: "system", rows: [
            ["super l", "lock", "lock screen password"],
            ["super alt c", "session menu", "shutdown reboot logout power off restart"],
            ["super x", "control centre", "settings wifi bluetooth quick"],
            ["super z", "settings", "noctalia preferences"],
            ["super a", "notifications", "messages alerts"],
            ["super shift d", "do not disturb", "notifications quiet silence focus dnd"],
            ["super shift a", "stay awake", "keep screen on caffeine idle sleep lock dim awake"],
            ["bar: right-click clock", "dnd / stay awake menu", "toggles"],
            ["bar: apps", "show the tray icons", "tray discord claude spotify"],
            ["bar: usb", "open drive / right-click eject", "usb stick drive mount unmount"],
            ["bar: upd", "install updates (click)", "update upgrade pacman yay"],
            ["super h", "this window", "help shortcuts keybinds cheat sheet"],
            ["super p", "display mode", "monitor screen projector duplicate extend"],
            ["super shift p", "colour picker", "color pick eyedropper hex"],
            ["print", "screenshot a region (edit)", "screen capture snip swappy"],
            ["super print", "screenshot the full screen", "screen capture whole display"],
            ["super + / -", "zoom", "magnify bigger smaller"],
            ["volume keys", "volume up / down / mute", "audio sound speaker mic"],
            ["media keys", "play / pause / next / previous", "music spotify song"],
            ["brightness keys", "brightness up / down", "screen backlight dim"] ] }
    ]

    // every row once, for searching
    readonly property var allRows: {
        const out = []
        for (const s of sections) for (const r of s.rows) out.push({ keys: r[0], desc: r[1], extra: r[2] || "", section: s.title })
        return out
    }

    // ---------------------------------------------------------------- fuzzy search
    // Each word of the query must appear in order (not necessarily together) in
    // the row's keys, description, extra words or section. Letters in a row and
    // letters at the start of a word score more, gaps score less.
    function fuzzy(word, text) {
        let score = 0, ti = 0, last = -2
        for (let qi = 0; qi < word.length; qi++) {
            const ch = word[qi]
            let found = -1
            for (let j = ti; j < text.length; j++) if (text[j] === ch) { found = j; break }
            if (found < 0) return -1
            score += 1
            if (found === last + 1) score += 3                       // consecutive
            if (found === 0 || " -/,.(".includes(text[found - 1])) score += 4   // word start
            score -= Math.min(found - ti, 5) * 0.1                   // gap
            last = found; ti = found + 1
        }
        return score
    }
    function rank(q) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w)
        if (!words.length) return []
        const res = []
        allRows.forEach((r, i) => {
            const fields = [r.keys, r.desc, r.extra, r.section].map(f => f.toLowerCase())
            let total = 0
            for (const w of words) {
                // best field for this word; keys and description count a bit more
                const best = Math.max(fuzzy(w, fields[0]) * 1.2, fuzzy(w, fields[1]) * 1.2, fuzzy(w, fields[2]), fuzzy(w, fields[3]) * 0.8)
                if (best < 0) return
                total += best
            }
            res.push({ row: r, score: total, i: i })
        })
        return res.sort((a, b) => b.score - a.score || a.i - b.i).slice(0, 14).map(x => x.row)
    }
    readonly property var results: rank(query)

    // matched letters bright (rich text), the rest dim
    function highlight(text, dimColor, brightColor) {
        const words = query.toLowerCase().split(/\s+/).filter(w => w)
        const hit = new Array(text.length).fill(false)
        const low = text.toLowerCase()
        for (const w of words) {
            let ti = 0; const pos = []
            for (const ch of w) { const j = low.indexOf(ch, ti); if (j < 0) { pos.length = 0; break } pos.push(j); ti = j + 1 }
            for (const p of pos) hit[p] = true
        }
        const esc = c => c === "<" ? "&lt;" : c === ">" ? "&gt;" : c === "&" ? "&amp;" : c
        let out = ""
        for (let i = 0; i < text.length; i++)
            out += hit[i] ? '<font color="' + brightColor + '">' + esc(text[i]) + "</font>" : esc(text[i])
        return '<font color="' + dimColor + '">' + out + "</font>"
    }

    MouseArea { anchors.fill: parent; onClicked: win.close() }

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

            // ---- the search field: the launcher's 2px box, "search:" and a block cursor
            LyBox {
                width: grid.implicitWidth
                height: 34
                Row {
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    Text {
                        id: label
                        text: "search: "
                        color: Theme.text
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    TextInput {
                        id: field
                        width: parent.width - label.width - hint.width
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
                            const n = win.results.length
                            switch (event.key) {
                            case Qt.Key_Escape:
                                if (win.query !== "") { field.text = ""; win.query = "" } else win.close()
                                break
                            case Qt.Key_Down: case Qt.Key_Tab: if (n) win.selected = (win.selected + 1) % n; break
                            case Qt.Key_Up: case Qt.Key_Backtab: if (n) win.selected = (win.selected - 1 + n) % n; break
                            default: return
                            }
                            event.accepted = true
                        }
                    }
                    Text {
                        id: hint
                        text: win.query === "" ? "type to search" : win.results.length + (win.results.length === 1 ? " match" : " matches")
                        color: Theme.textDim
                        opacity: 0.7
                        font { family: Theme.font; pointSize: Theme.small }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ---- below: all keybinds, or the search results in the same space
            Item {
                width: grid.implicitWidth
                height: grid.implicitHeight     // same size either way: the box never jumps

                Row {
                    id: grid
                    visible: win.query === ""
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
                                        width: 214          // the longest key fits ("super ctrl shift left right")
                                        elide: Text.ElideRight
                                        text: modelData[0]
                                        color: Theme.primary     // keys in the accent, so they stand apart from what they do
                                        font { family: Theme.font; pointSize: Theme.small }
                                    }
                                    Text {
                                        width: 168
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

                Column {
                    visible: win.query !== ""
                    width: parent.width
                    spacing: Theme.s2
                    Repeater {
                        model: win.results
                        Item {
                            id: res
                            required property var modelData
                            required property int index
                            readonly property bool sel: index === win.selected
                            width: parent.width
                            height: 22
                            Text {
                                id: keysText
                                width: 260
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.RichText
                                text: win.highlight(res.modelData.keys, Theme.primary, Theme.text)
                                font { family: Theme.font; pointSize: Theme.fontSize; bold: false }
                            }
                            Rectangle {   // accent underline on the selected result, like the launcher
                                visible: res.sel
                                anchors { left: keysText.left; top: keysText.bottom; topMargin: 1 }
                                width: keysText.contentWidth
                                height: 1
                                color: Theme.primary
                            }
                            Text {
                                anchors { left: keysText.right; leftMargin: Theme.s3; right: sec.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                                elide: Text.ElideRight
                                textFormat: Text.RichText
                                text: win.highlight(res.modelData.desc, Theme.textDim, Theme.text)
                                font { family: Theme.font; pointSize: Theme.fontSize }
                            }
                            Text {
                                id: sec
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: res.modelData.section
                                color: Theme.textDim
                                opacity: 0.7
                                font { family: Theme.font; pointSize: Theme.small }
                            }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: win.selected = res.index }
                        }
                    }
                    Text {
                        visible: win.results.length === 0
                        text: "no matches"
                        color: Theme.textDim
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                }
            }
        }
    }
}
