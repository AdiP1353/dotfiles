pragma Singleton

// Audio levels for the rice's visualisers (top bar and desktop), from cava in
// raw mode (~/.config/rice/cava/raw.conf): 192 numbers, 0-100, 60 times a
// second. cava only runs while something is playing, and not at all when
// animations are off (reduced motion: the visualisers show a still line).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: cava

    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool active: playing && Theme.motion
    readonly property int count: 192
    property var values: []

    // n levels, each the loudest of its group of cava's bars (for small visualisers)
    function grouped(n) {
        const v = values, out = []
        if (!v.length) { for (let i = 0; i < n; i++) out.push(0); return out }
        const step = v.length / n
        for (let i = 0; i < n; i++) {
            let m = 0
            for (let j = Math.floor(i * step); j < Math.floor((i + 1) * step); j++) m = Math.max(m, v[j] || 0)
            out.push(m)
        }
        return out
    }

    Process {
        id: proc
        // started by onActiveChanged / the restart timer below, stopped when music stops
        running: false
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/rice/cava/raw.conf"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";")
                const out = new Array(parts.length)
                for (let i = 0; i < parts.length; i++) out[i] = parseInt(parts[i]) || 0
                cava.values = out
            }
        }
        onRunningChanged: if (!running) { cava.values = []; if (cava.active) restart.restart() }
    }
    // if cava stops while music is still playing (crash, new settings), start it again
    Timer { id: restart; interval: 1000; onTriggered: if (cava.active && !proc.running) proc.running = true }
    onActiveChanged: proc.running = active
    Component.onCompleted: proc.running = active
}
