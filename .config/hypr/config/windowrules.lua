-- Window rules wiki https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Generic floating position
hl.window_rule({ match = { float = true }, persistent_size = true })

-- Picture-in-Picture
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    size              = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
    pin               = true,
})

-- Gaming
local gamingApps = "^(steam_app.*|gamescope)$"
local gamingWorkspace = "name:gaming"

hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { xdg_tag = "^(.*game.*)$" }, workspace = gamingWorkspace, fullscreen_state = 2, content = "game", sync_fullscreen = true })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Launching\\.{3})$" }, float = true, center = true, workspace = gamingWorkspace })
hl.window_rule({
    match = {
        class         = gamingApps,
        title         = "^(.+)$",
        initial_title = "negative:^(.*\\\\home\\\\.*)$",
    },
    content          = "game",
    decorate         = false,
    fullscreen_state = 2,
    size             = { "monitor_w", "monitor_h" },
    sync_fullscreen  = true,
})
hl.window_rule({
    match = {
        class         = "^(steam_app.*)$",
        initial_title = "^$",
    },
    center           = true,
    float            = true,
    fullscreen       = false,
    fullscreen_state = 0,
    workspace        = gamingWorkspace,
})

-- Apps
hl.window_rule({ match = { class = "^(.*\\.exe)$", float = true }, monitor = PRIMARY_MONITOR, center = true, fullscreen_state = 0 })
hl.window_rule({ match = { class = "^(.*[Ll]auncher.*)$" }, float = true, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(vesktop|discord)$" }, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(.*[Cc]alc.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({ match = { class = "^(.*swash)$", title = "^(Swash)$" }, min_size = { "max(monitor_w, monitor_h)*0.35", "min(monitor_w, monitor_h)*0.35" }, float = true })
hl.window_rule({ match = { class = "^(dev\\.)?(noctalia\\.Noctalia(\\.Settings)?)$" }, float = true, size = { "monitor_w*0.70", "monitor_h*0.70" } })
-- Dolphin: main windows tile like every other app (no rule needed); only its
-- progress, settings and properties dialogs float.
hl.window_rule({
    match = {
        class = "^(org\\.kde\\.dolphin)$",
        title = "^(Moving.*|Create New.*|Extract.*|Compress.*|Copying.*|Progress.*|Configure.*|Properties.*|Choose\\sApplication.*)$",
    },
    float = true,
})

-- Opacity Overrides
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)$"

hl.window_rule({ match = { class = "^(firefox|zen)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" }) -- Override opacity in favor of terminal settings for opacity. If your terminal doesn't support transparency, you can remove this rule.
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })

-- Float Utility Windows
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
}
for _, m in ipairs(floatApps) do hl.window_rule({ match = m, float = true }) end

-- Float Common Modals
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$"},
}
for _, m in ipairs(modalMatches) do hl.window_rule({ match = m, float = true }) end

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Noctalia layer rule
hl.layer_rule({
  name = "noctalia",
  match = {
    namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
  },
  no_anim = true,
  ignore_alpha = 0.5,
  blur = true,
  blur_popups = true,
})

-- Apps open in their own places (one app per workspace, matching SUPER + 1-5).
-- Opening one takes you there; SUPER + number still focuses it wherever it is.
local pip = "negative:^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
hl.window_rule({ match = { class = "^(firefox)$", title = pip },        workspace = "1" })
hl.window_rule({ match = { class = "^(Spotify|spotify)$" },             workspace = "2" })
hl.window_rule({ match = { class = "^(com\\.anthropic\\.Claude)$" },    workspace = "3" })
hl.window_rule({ match = { class = "^(md\\.obsidian\\.Obsidian|obsidian)$" }, workspace = "4" })
hl.window_rule({ match = { class = "^(dev\\.zed\\.Zed)$" },             workspace = "5" })
hl.window_rule({ match = { class = "^(vesktop|whatsapp)$" },            workspace = "6" })

-- Drop-down terminal (Copilot key, binds.lua): Kitty in its own hidden
-- workspace, floating across the top of the screen under the bar, 45% high.
-- Shown and hidden with the special-workspace slide (animations.lua).
hl.window_rule({
    match     = { class = "^(rice-dropdown)$" },
    workspace = "special:dropdown",
    float     = true,
    size      = { "monitor_w - 8", "monitor_h * 0.45" },
    move      = { 4, 34 },
})

-- Fullscreen windows (games, videos) keep the screen awake (hypridle).
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
