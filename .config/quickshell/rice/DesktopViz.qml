// Desktop visualiser, minimal style (THEME.md §3): while music plays, a wide
// low row of bars along the bottom of the wallpaper, behind every window
// (you see it on empty workspaces and between windows). 192 square bars
// across the full width of the bottom edge, 2px apart, growing up from a 2px
// baseline. Colour: light grey or near-black, whichever stands out more on the
// wallpaper underneath (rice-viz-colour).
// Clicks pass straight through; it fades in and out (150ms) with playback,
// and hides while any window is open on the workspace.
// Reduced motion: cava doesn't run, so it stays a still line.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 72
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom          // above the wallpaper, below windows
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "rice-visualiser"
    mask: Region {}                                // never takes a click
    visible: viz.opacity > 0

    // Hidden while you work: any window on this screen's workspace (or a shown
    // special workspace, like the drop-down terminal) fades it out; an empty
    // workspace brings it back.
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screen.name) || null
    readonly property bool busy: {
        if (!monitor) return false
        const ws = monitor.activeWorkspace
        const special = monitor.lastIpcObject && monitor.lastIpcObject.specialWorkspace
        return (ws && ws.toplevels && ws.toplevels.values.length > 0) || !!(special && special.name)
    }
    Connections {   // keep the special-workspace state current
        target: Hyprland
        function onRawEvent(event) {
            if (["activespecial", "openwindow", "closewindow", "movewindow", "workspace", "focusedmon"].includes(event.name))
                Hyprland.refreshMonitors()
        }
    }

    // the bar colour with the best contrast against this screen's wallpaper
    // (light grey on dark wallpapers, the palette's near-black on light ones),
    // picked by ~/.config/rice/bin/rice-viz-colour after every wallpaper change
    FileView {
        id: vizFile
        path: Quickshell.env("HOME") + "/.local/state/rice/viz.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }
    readonly property color barColour: {
        try { const m = JSON.parse(vizFile.text()); if (m[screen.name]) return m[screen.name] } catch (e) {}
        return Theme.textDim
    }

    Row {
        id: viz
        // the whole width of the screen, right on the bottom edge: 192 bars
        // sharing it, 2px apart (on 1080p each bar is about 8px wide)
        readonly property real barW: (win.width + spacing) / Cava.count - spacing
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 72
        spacing: 2
        opacity: Cava.playing && !win.busy ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        Repeater {
            model: Cava.count
            Item {
                required property int index
                width: viz.barW; height: viz.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, Math.round((Cava.values[parent.index] || 0) / 100 * parent.height))
                    color: win.barColour
                }
            }
        }
    }
}
