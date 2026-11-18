pragma Singleton

// The launcher's "/" setups, read from ~/.config/rice/setups.conf (watched:
// edits apply at once). run(name) opens each listed app on its workspace,
// moving apps that are already open instead of opening them twice, then goes
// to the setup's "go" workspace.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: setups
    readonly property string path: Quickshell.env("HOME") + "/.config/rice/setups.conf"
    property var list: []           // [{ name, about, go, apps: [{ ws, app }] }]

    FileView {
        id: file
        path: setups.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: setups.list = setups.parse(text())
        printErrors: false
    }

    function parse(t) {
        const out = []; let cur = null
        for (let raw of String(t).split("\n")) {
            const line = raw.replace(/^\s+|\s+$/g, "")
            if (!line || line.startsWith("#")) continue
            const sec = line.match(/^\[(.+)\]$/)
            if (sec) { cur = { name: sec[1].trim().toLowerCase(), about: "", go: "", apps: [] }; out.push(cur); continue }
            const kv = line.match(/^([^=]+?)\s*=\s*(.+)$/)
            if (!kv || !cur) continue
            const key = kv[1].trim(), val = kv[2].trim()
            if (key === "about") cur.about = val
            else if (key === "go") cur.go = val
            else cur.apps.push({ ws: key, app: val })
        }
        return out
    }

    function entryFor(name) {
        const n = String(name).toLowerCase()
        const apps = DesktopEntries.applications.values
        const id = a => String(a.id).toLowerCase().replace(/\.desktop$/, "")
        return apps.find(a => id(a) === n) || apps.find(a => a.name.toLowerCase() === n)
            || apps.find(a => (a.startupClass || "").toLowerCase() === n)
            || apps.find(a => id(a).split(".").pop() === n)
            || apps.find(a => a.name.toLowerCase().startsWith(n) || id(a).includes(n)) || null
    }

    function sh(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function luaStr(s) { return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') }
    function execOn(ws, cmd) {
        Hyprland.dispatch('hl.dsp.exec_cmd("' + luaStr(cmd) + '", { workspace = "' + luaStr(ws) + ' silent" })')
    }

    function run(name) {
        const s = list.find(x => x.name === name)
        if (!s) return false
        for (const a of s.apps) {
            if (a.app.startsWith("$")) { execOn(a.ws, a.app.slice(1).trim()); continue }
            const e = entryFor(a.app)
            if (!e) { Quickshell.execDetached(["noctalia", "msg", "notification-show", "setup /" + s.name, "no app called " + a.app]); continue }
            const w = RiceApps.windowFor(RiceApps.hintsFor(e))
            if (w) {
                const addr = String(w.address).startsWith("0x") ? w.address : "0x" + w.address
                Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + luaStr(a.ws) + '", follow = false, window = "address:' + addr + '" })')
            } else {
                // the entry's own command, without its %u / %f placeholders
                const cmd = (e.command || []).filter(c => !/^%[a-zA-Z]$/.test(c)).map(sh).join(" ")
                if (cmd) execOn(a.ws, cmd)
            }
        }
        const go = s.go || (s.apps[0] && s.apps[0].ws)
        if (go) Hyprland.dispatch('hl.dsp.focus({ workspace = "' + luaStr(go) + '" })')
        return true
    }
}
