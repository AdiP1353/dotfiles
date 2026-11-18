pragma Singleton

// Finding an app's window and taking you there, shared by the launcher, the
// tray icons and the launcher's /setups.
//   windowFor(hints)      the most recently used window whose class matches
//                         one of the hints (desktop-entry id, StartupWMClass,
//                         name, tray id...)
//   focus(window, ws)     go to it; a window hidden in a special workspace
//                         (scratchpad, background) is brought onto `ws`
//                         (default: the workspace you're on) first
//   openOrFocus(entry)    focus the app if it's open, start it if not

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    function norm(s) { return String(s || "").toLowerCase().replace(/\.desktop$/, "") }
    function last(s) { return norm(s).split(".").pop() }

    function hintsFor(entry) {
        if (!entry) return []
        const hs = [entry.startupClass, entry.id, entry.name].filter(h => h).map(norm)
        // launcher entries named after their wrapper: spotify-launcher -> spotify,
        // whatsapp-linux-desktop -> whatsapp
        for (const h of hs.slice()) {
            const bare = h.replace(/(-launcher|-linux-desktop|-desktop|-bin)$/, "")
            if (bare !== h) hs.push(bare)
        }
        return hs
    }

    function windowFor(hints) {
        Hyprland.refreshToplevels()
        const hs = hints.map(norm).filter(h => h)
        const match = t => {
            const c = norm(t.lastIpcObject && t.lastIpcObject.class)
            return c && hs.some(h => c === h || last(c) === last(h) || c === last(h))
        }
        const wins = Hyprland.toplevels.values.filter(match)
            .sort((a, b) => ((a.lastIpcObject && a.lastIpcObject.focusHistoryID) ?? 99) - ((b.lastIpcObject && b.lastIpcObject.focusHistoryID) ?? 99))
        return wins[0] || null
    }

    function focus(w, ws) {
        if (!w) return
        const addr = String(w.address).startsWith("0x") ? w.address : "0x" + w.address
        const cur = w.lastIpcObject && w.lastIpcObject.workspace
        const target = ws || (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : "")
        if (cur && String(cur.name).startsWith("special:") && target)
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + target + '", window = "address:' + addr + '" })')
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })')
    }

    function launch(entry) {
        const id = String(entry.id).endsWith(".desktop") ? entry.id : entry.id + ".desktop"
        Quickshell.execDetached(["uwsm", "app", "--", id])
    }

    function openOrFocus(entry) {
        const w = windowFor(hintsFor(entry))
        if (w) focus(w)
        else launch(entry)
    }
}
