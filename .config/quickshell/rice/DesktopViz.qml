// Desktop visualiser, minimal style (THEME.md §3): while music plays, a wide
// low row of bars along the bottom of the wallpaper, behind every window
// (you see it on empty workspaces and between windows). 192 bars, 2px wide,
// 2px apart, square, in the dim text colour, growing up from a 2px baseline.
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
    implicitHeight: 96
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom          // above the wallpaper, below windows
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "rice-visualiser"
    mask: Region {}                                // never takes a click
    visible: viz.opacity > 0

    Row {
        id: viz
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
        height: 56
        spacing: 2
        opacity: Cava.playing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        Repeater {
            model: Cava.count
            Item {
                required property int index
                width: 2; height: viz.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 2
                    height: Math.max(2, Math.round((Cava.values[parent.index] || 0) / 100 * parent.height))
                    color: Theme.textDim
                }
            }
        }
    }
}
