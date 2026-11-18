// Desktop visualiser, minimal style (THEME.md §3): while music plays, a wide
// low row of bars along the bottom of the wallpaper, behind every window
// (you see it on empty workspaces and between windows). 192 square bars
// across the full width of the bottom edge, 2px apart, in the dim text
// colour, growing up from a 2px baseline.
// Clicks pass straight through; it fades in and out with playback (150ms).
// Reduced motion: cava doesn't run, so it stays a still line.

import QtQuick
import Quickshell
import Quickshell.Wayland

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

    Row {
        id: viz
        // the whole width of the screen, right on the bottom edge: 192 bars
        // sharing it, 2px apart (on 1080p each bar is about 8px wide)
        readonly property real barW: (win.width + spacing) / Cava.count - spacing
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 72
        spacing: 2
        opacity: Cava.playing ? 1 : 0
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
                    color: Theme.textDim
                }
            }
        }
    }
}
