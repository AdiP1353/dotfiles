pragma Singleton

// Login/lock screen tokens: the SAME font and values as the wallhaven picker's Theme.qml
// (~/.config/quickshell/wallhaven/Theme.qml, THEME.md), so both look like one
// system: mono 12pt / 10pt, 4/8/12/16 spacing, 0px corners, 1px outlines,
// accent only on focus, translucent surfaces over the wallpaper.
// Colors come from /var/lib/rice-greeter/colors.json (noctalia's rice_greeter
// template); RICE_GREETER_DATA overrides the folder (previews).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    readonly property string dataDir: Quickshell.env("RICE_GREETER_DATA") || "/var/lib/rice-greeter"

    // ---- Type & spacing (as in the picker) ----
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int small: 10
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16

    // ---- Palette (as in the picker) ----
    readonly property color surface: p.surface
    readonly property color surfaceContainer: p.surface_container
    readonly property color surfaceContainerHigh: p.surface_container_high
    readonly property color text: p.on_surface
    readonly property color textDim: p.on_surface_variant
    readonly property color outlineVariant: p.outline_variant
    readonly property color primary: p.primary
    readonly property color textOnPrimary: p.on_primary
    readonly property color error: p.error
    readonly property color shadow: p.shadow

    // Things drawn on top of the wallpaper are slightly see-through.
    readonly property real overlayAlpha: 0.82
    readonly property real overlayAlphaHover: 0.92

    // ---- Motion (as in the picker) ----
    // Motion on unless RICE_REDUCED_MOTION=1 (the greeter user has no desktop
    // settings to read). Off = opacity only, no movement.
    readonly property bool motion: Quickshell.env("RICE_REDUCED_MOTION") !== "1"
    readonly property var easeOut: [0.23, 1, 0.32, 1, 1, 1]
    readonly property int pressMs: 150

    FileView {
        path: Theme.dataDir + "/colors.json"
        printErrors: false
        JsonAdapter {
            id: p
            property string surface: "#141318"
            property string surface_container: "#201f24"
            property string surface_container_high: "#2b292f"
            property string on_surface: "#e6e1e9"
            property string on_surface_variant: "#c9c4d0"
            property string outline_variant: "#48454e"
            property string primary: "#cabeff"
            property string on_primary: "#31285f"
            property string error: "#ffb4ab"
            property string shadow: "#000000"
        }
    }
}
