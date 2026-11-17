pragma Singleton

// Design tokens for the picker: palette from noctalia's rice_colors template
// (see THEME.md), type, spacing and motion. Colors reload by themselves when
// noctalia regenerates them.
//
// Note: color properties must not start with "on" + capital letter; QML reads
// those names as signal handlers, so on_surface is exposed as `text`.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // ---- Type & spacing (THEME.md: mono 12pt, 4/8/12/16 scale) ----
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int small: 10
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16

    // ---- Palette ----
    readonly property bool isDark: p.mode !== "light"
    readonly property color surface: p.surface
    readonly property color surfaceContainer: p.surface_container
    readonly property color surfaceContainerHigh: p.surface_container_high
    readonly property color text: p.on_surface
    readonly property color textDim: p.on_surface_variant
    readonly property color outlineVariant: p.outline_variant
    readonly property color primary: p.primary
    readonly property color textOnPrimary: p.on_primary
    readonly property color error: p.error
    readonly property color textOnError: p.on_error
    readonly property color shadow: p.shadow
    // Pure black/white at 10% so image edges never pick up a tinted fringe.
    readonly property color imageOutline: isDark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)

    // Controls drawn on top of a wallpaper are slightly see-through (the user's
    // call; everything else stays solid as in THEME.md).
    readonly property real overlayAlpha: 0.82
    readonly property real overlayAlphaHover: 0.92

    // ---- Rating choice colors (like = accent, nope = error, skip = neutral) ----
    function tone(type) { return type === "like" ? primary : type === "dislike" ? error : textDim }
    function onTone(type) { return type === "like" ? textOnPrimary : type === "dislike" ? textOnError : surface }

    // ---- Motion ----
    // Off when the desktop asks for no animations (GNOME/GTK setting).
    property bool motion: true
    // Strong ease-out for entering/exiting, strong ease-in-out for on-screen moves.
    readonly property var easeOut: [0.23, 1, 0.32, 1, 1, 1]
    readonly property var easeInOut: [0.77, 0, 0.175, 1, 1, 1]
    // Icon state cross-fade curve (better-ui).
    readonly property var easeIcon: [0.2, 0, 0, 1, 1, 1]
    readonly property int pressMs: 150      // press scale to 0.96
    readonly property int fadeMs: 150       // opacity-only changes, exits
    readonly property int exitMs: 200       // card leaving the stack
    readonly property int moveMs: 200       // grid items closing a gap
    readonly property int iconMs: 300       // like heart cross-fade

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        stdout: StdioCollector { onStreamFinished: theme.motion = text.trim() !== "false" }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/rice/colors.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: p
            property string mode: "dark"
            property string surface: "#131318"
            property string surface_container: "#201f25"
            property string surface_container_high: "#2a292f"
            property string on_surface: "#e5e1e9"
            property string on_surface_variant: "#c8c5d0"
            property string outline_variant: "#47464f"
            property string primary: "#c4c0ff"
            property string on_primary: "#2c2960"
            property string error: "#ffb4ab"
            property string on_error: "#690005"
            property string shadow: "#000000"
        }
    }
}
