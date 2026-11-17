# Workspace shortcuts

A **workspace** is a separate screen of windows. Workspaces 1, 2 and 3 always
exist. Any other workspace is created when you go to it or move a window to it,
and disappears once it is empty.

`Super` is the Windows key. Number shortcuts cover workspaces 1 to 9.

`Super` + number (without `Ctrl`) opens apps, not workspaces:
`1` Firefox, `2` Spotify, `3` Claude, `4` Obsidian, `5` Zed.

## Go to a workspace

| Shortcut | What it does |
|---|---|
| `Super` + `Ctrl` + `1`–`9` | Go to workspace 1–9 (creates it if needed) |
| `Super` + `Ctrl` + `→` | Next workspace |
| `Super` + `Ctrl` + `←` | Previous workspace |
| `Super` + `Ctrl` + `↑` | Back to the workspace you were just on (press again to return) |
| `Super` + `Ctrl` + `↓` | Open a new, empty workspace |
| `Super` + mouse wheel | Scroll through workspaces |

## Move a window to another workspace

These act on the window you are using (the focused window).

| Shortcut | What it does |
|---|---|
| `Super` + `Shift` + `1`–`9` | Move the window to workspace 1–9 and go with it |
| `Super` + `Shift` + `Alt` + `1`–`9` | Move the window to workspace 1–9 and stay where you are |
| `Super` + `Ctrl` + `Shift` + `→` | Move the window to the next workspace and go with it |
| `Super` + `Ctrl` + `Shift` + `←` | Move the window to the previous workspace and go with it |
| `Super` + `Ctrl` + `Shift` + `↓` | Move the window to a new, empty workspace and go with it |
| `Super` + `Ctrl` + `Shift` + mouse wheel | Move the window through workspaces |
| Drag a window onto a workspace circle in the top bar | Move the window to that workspace and stay where you are |

### Dragging a window onto the workspace circles

The circles in the middle of the top bar are your workspaces, in order (1, 2, 3, …).
The wide pill is the workspace you are on.

The top bar is hidden until you move the cursor to the top edge of the screen.
While it is hidden, windows use the full height of the screen.

1. Start dragging a window: `Super` + left mouse drag on any window, or drag
   Dolphin by an empty part of its toolbar.
2. The top bar slides down on its own when you start dragging. Move the cursor
   onto a circle in it. The circle under the cursor changes colour to show
   where the window will go.
3. Let go. The window moves to that workspace and you stay where you are.

If you let go anywhere else in the bar, the window stays on its current
workspace.

How it works: `config/dragtoworkspace.lua` notices when a window starts being
dragged. It then runs `scripts/map-workspace-circles.py`, which finds the
circles on screen. Noctalia doesn't report where it draws them, so the script
finds them by colour and checks that they match your workspaces. While you
drag, the circle under the cursor is highlighted using Noctalia's workspace
alert. When you let go, the window moves. If a drop does nothing, read
`/tmp/hypr-drag-to-workspace.log`. To turn the feature off, delete the line
`require("config.dragtoworkspace")` from `hyprland.lua` and run `hyprctl reload`.

## Hidden workspaces

A hidden workspace sits on top of your normal workspaces. It opens over
whatever you are doing and closes again with the same shortcut. There are two:

- **Scratchpad**: for windows you want to keep nearby but out of the way, such
  as a terminal or notes.
- **Background**: where apps go when you "close" them but they keep running.
  Today that is Spotify (see below).

| Shortcut | What it does |
|---|---|
| `Super` + `S` | Open or close the scratchpad |
| `Super` + `Shift` + `S` | Send the window to the scratchpad. If the window is already in a hidden workspace, bring it back to your current workspace |
| `Super` + `B` | Open or close the background workspace |

Hidden workspaces have no "delete" step. One that is empty disappears on its
own.

### Apps that keep running when closed

`Super` + `Q` closes a window. For Spotify it hides the window in the background
workspace instead, so the music keeps playing. To get Spotify back, press
`Super` + `2`, or open the background workspace with `Super` + `B`.

Quitting from inside Spotify (`Ctrl` + `Q` or its menu) still quits it fully.

To add another app, put its window class in `hideOnClose` at the top of
`config/binds.lua`. To find an app's class, run `hyprctl activewindow` while
the app is focused and read the `class:` line.

## Moving windows within a workspace

| Shortcut | What it does |
|---|---|
| `Super` + arrow keys | Move focus to the window in that direction |
| `Super` + `Shift` + arrow keys | Move the window in that direction |
| `Super` + left mouse drag | Move a window |
| `Super` + right mouse drag | Resize a window |
| `Super` + `Alt` + `Space` | Switch the window between tiled and floating |
| `Super` + `J` | Switch the split direction |

## Where this lives

- Shortcuts: `~/.config/hypr/config/binds.lua`
- Drag-to-workspace: `~/.config/hypr/config/dragtoworkspace.lua` and `~/.config/hypr/scripts/map-workspace-circles.py`
- Workspaces 1–3 that always exist: `~/.config/hypr/config/workspaces.lua`
- Apply changes after editing: `hyprctl reload`
- Check for mistakes after editing: `hyprctl configerrors` (no output means no errors)
- Backup from before these changes: `config/binds.lua.bak-2026-11-13`

## Old shortcuts that were replaced (13 Nov 2026)

| Old shortcut | Now |
|---|---|
| `Super` + `Ctrl` + `Shift` + `S` (send to scratchpad) | `Super` + `Shift` + `S` |
| `Super` + `Shift` + `Ctrl` + `1`–`3` (move window) | `Super` + `Shift` + `1`–`9` |
| `Super` + `Alt` + `1`–`3` (go to workspace) | `Super` + `Ctrl` + `1`–`9` |
| `Super` + `1`–`3` and `Super` + `Shift` + `1`–`3` (focus or move to monitor) | Removed. No monitors were set up for them, so they did nothing |
