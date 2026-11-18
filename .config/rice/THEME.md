# Rice theme spec

The single source of truth for how everything looks. **§3, the minimal style,
is the reference for any new or changed UI.** Every config (Hyprland, Quickshell,
Kitty, GTK, Qt, Firefox/Zen, Vesktop, Spotify, lock/login) follows these rules.
If a new app can't follow them, it stays on its default theme rather than half-matching.

## 1. Color source

- Generator: **noctalia**, scheme **tonal spot** (`theme.wallpaper_scheme` in `~/.config/noctalia/config.toml`). "vibrant" was tried and was too strong.
- Wallpapers: any kind (anime, photos, abstract).
- Mode: **always dark**. The wallpaper never switches apps to light mode; it only changes the colors (accent, tinted dark surfaces, borders). `gsettings` color-scheme stays `prefer-dark`.

## 2. Color roles (Material 3 names from matugen)

Use only these roles. Never hard-code a hex value in any config.

| Role | Used for |
|---|---|
| `surface` | Bar background, popup background, lock screen panel |
| `surface_container` | Cards and sections inside popups (control center groups, launcher list) |
| `surface_container_high` | Hovered row that isn't selected, input fields |
| `on_surface` | Main text and icons; **active workspace**; toggle "on" state |
| `on_surface_variant` | Secondary text, inactive workspaces, toggle "off" state, slider track |
| `outline_variant` | 1px popup outline, inactive window border, dividers |
| `primary` | **Accent:** active window border, selected item background |
| `on_primary` | Text/icons on a selected item |
| `error` | Low battery, failed actions, critical notifications only |

### Where the accent (`primary`) is allowed

Only these two places:

1. **Active window border.**
2. **Selection / hover highlight** in the launcher, wallpaper picker, power menu and control center lists.

Everything else stays neutral. That includes the active workspace, toggles, sliders and the clock.
"On" is shown by contrast (`on_surface` vs `on_surface_variant`), not by color.

## 3. The minimal style (THE reference for everything new)

Set by the login screen (Ly's look) and applied to the wallpaper picker; the
user called it perfect. Anything new or changed must look like this.
Reference code: `~/.config/rice-greeter/LoginBox.qml` and
`~/.config/quickshell/wallhaven/{Layout,LyBox,ActionButton,SearchField}.qml`.

| Rule | Value |
|---|---|
| Containers | **One kind of box**: a plain **2px border** in `on_surface_variant`, 0px corners, **no shadow**. No cards, no chips with their own styles |
| Fills | None on the surface itself. Over a wallpaper/image only: the box gets `surface` at 82% (92% on hover) so text stays readable |
| Buttons | **Plain lowercase text**, no fill, no border, no icons (`back  nope  skip  like`, `keep rating`, `rate more`). Rest: `on_surface_variant`; hover: `on_surface` + 1px underline; keyboard focus: 1px **accent** underline; a picked choice: bold in its tone for a moment |
| Text fields | Ly-style: a label with a colon (`search:`, `login:`, `password:`), then plain text and a **blinking block cursor**; no input box |
| Labels & copy | Lowercase, terse (`incorrect password`, `finding wallpapers to rate...`, `10 rated`) |
| Accent | Only for focus/selection: focused underline, selected thumbnail border, active window border |
| Rating tones | like = `primary`, nope = `error`, skip = neutral (`on_surface_variant`) |
| Small tile buttons | Translucent `surface` squares with a glyph, no outline (thumbnail like/nope) |
| Corner radius | **0px everywhere** |
| Window border | 2px: 45° gradient `primary` to `tertiary` when active, `outline_variant` when inactive |
| Windows (all apps) | Hyprland: rounding 0, gaps 2 / 4px, fully opaque, blur off, shadows off (`hypr/config/decorations.lua`) |
| App fonts | JetBrains Mono Nerd Font 10 for GTK (gsettings), Qt (qt6ct `[Fonts]`) and KDE apps (`kdeglobals`); GTK corners squared in `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` (below noctalia's import) |
| Wallpaper picker | A normal window ("wallpapers", tiles like any app); its layout stretches to the window |
| Shadows | None in the rice's own UI. (Hyprland may still give floating windows a subtle one) |
| Blur | Only behind the login and lock box: the wallpaper, heavily blurred and dimmed |
| Opacity | Solid, except boxes over images (above) and Kitty (92%) |
| Key hints | Only where the keys are not obvious, as small plain text (login screen: `F1 shutdown F2 reboot F3 show password`) |
| Motion | Short and functional (THEME §4 timings): 150ms fades, 0.96 press scale, 200ms swipe exits; nothing decorative. Keyboard-opened overlays (launcher, ALT+Tab, SUPER+H, SUPER+P, lock) open and close instantly. Only rare moments animate: the login screen enters clock → box → hints, 100ms apart, fade + 12px rise, 300ms strong ease-out (`RICE_REDUCED_MOTION=1` = fades only) |

## 4. Size and spacing (medium scale, 1080p)

| Token | Value |
|---|---|
| Font | JetBrains Mono Nerd Font (or Iosevka Nerd Font) everywhere, monospace only |
| Base font size | 12pt (Kitty 12, bar 12, popups 12, small labels 10) |
| Bar height | 28px, always on, tiny: workspaces, clock, battery |
| Spacing scale | 4 / 8 / 12 / 16px only |
| Hyprland gaps | inner 2px, outer 4px |
| Popup padding | 12px; rows 8px apart |
| Icon size | 16px in the bar, 20px in popups |
| Animations | Short or off (snappy) |

## 5. Per-app rules

Colors come from **noctalia** (it plays the matugen role): every time the
wallpaper changes it renders the templates below. Built-in and community
templates are listed in `~/.config/noctalia/config.toml`; the rice's own ones
live in `~/.config/noctalia/templates.toml` + `templates/`.

| App | How | Follows |
|---|---|---|
| Hyprland | user template `rice_hyprland` → `hypr/config/wallpaper_colors.lua`, required last by `hyprland.lua` | active border = 45° gradient primary → tertiary, inactive = outline_variant, groups, shadow color |
| Quickshell picker (and later the bar/popups) | user template `rice_colors` → `~/.local/state/rice/colors.json`, watched live | all roles above |
| Top bar (always on) | `~/.config/quickshell/rice/Bar.qml` (`qs -c rice`, autostarted): 28px, plain lowercase text, 2px bottom line; workspaces (accent underline on the current one), now playing, time/date, tray, `net:` `vol:` `bat:`. noctalia's bar is off (`bar.default.enabled = false`) | palette (via the picker's `Theme.qml`) |
| App launcher (SUPER + Space) | `~/.config/quickshell/rice/Launcher.qml`: a solid 2px box, `run:` with a block cursor, matching apps as lowercase lines, accent underline on the selected one; launches through uwsm | palette |
| Display switcher (SUPER + P) | `~/.config/quickshell/rice/DisplaySwitcher.qml`: Win + P style 2px box (pc screen only / duplicate / extend / second screen only), accent underline on the selection, `current` marked; applied with `hyprctl eval`, saved to `~/.config/hypr/display-mode.lua` (loaded last by `hypr/config/monitors.lua`), "second screen only" never saved. Colour picker is now SUPER + SHIFT + P | palette |
| noctalia panels, settings window, notifications, OSDs | noctalia itself (its bar and launcher are no longer used), set to the minimal style in `config.toml`: `[shell]` corner_radius_scale 0, JetBrains Mono, outlines on, popup shadows off; `[shell.panel]` 2px `on_surface_variant` border, no shadow, solid. noctalia keeps its own icons, sliders and toggles | palette |
| Terminals: Kitty, Alacritty, btop | **Not wallpaper-driven.** One fixed minimal palette: `kitty/themes/rice-minimal.conf` and the same colours in `alacritty/themes/rice-minimal.toml`; both JetBrains Mono 12, 16px padding, 92% opacity, blinking block cursor (530ms). btop uses the `TTY` theme (the terminal's own colours), square corners, no background | fixed palette |
| GTK 3/4 (Text Editor, Calculator, Firefox's dialogs) | adw-gtk3-dark + noctalia `gtk3` / `gtk4`; `gtk.css`: corners squared, buttons and text fields are plain 2px boxes with no fills (not even the accent "suggested" button), accent only on keyboard focus and checked toggles, 0.96 press; `settings.ini` in both folders (breeze-dark icons, Bibata cursor, JetBrains Mono 10) | all roles, mode |
| GNOME Text Editor | user template `rice_gtksourceview` → `~/.local/share/gtksourceview-5/styles/rice.xml` (style scheme `rice`: comments dim, primary / secondary / tertiary for code, accent search matches) | all roles |
| Qt / KDE apps (Dolphin, Ark) | qt6ct with the **Kvantum** style and theme `Rice` (`~/.config/Kvantum/Rice`), built by `~/.config/rice/qt/make-kvantum.py` from Kvantum's KvFlat: every frame piece redrawn as a square rectangle (0px corners, 2px frames), borders `on_surface_variant`, accent for focus and selection, palette from the wallpaper (re-built by the rice_colors hook on every wallpaper change; Qt apps pick it up on restart). breeze-dark icons, JetBrains Mono 10 | all roles |
| Firefox | `~/.config/rice/firefox` is the profile's `chrome` folder (symlink) and `user.js` (symlink): system theme, dark, `userChrome.css` on Firefox 160's design tokens. Tabs: lowercase text, the current one with a 1px accent underline; address bar: the launcher's 2px box, accent border when focused; dropdown rows: accent underline like the launcher; menus: 2px box, square, no shadow; no window buttons; dim icons that brighten on hover, 0.96 press. Colours: user template `rice_firefox` → `rice-colors.css`. Read on start: restart Firefox to see a new wallpaper's colours | all roles |
| Zed | noctalia community template `zed` → `~/.config/zed/themes/noctalia.json`; `settings.json`: theme "Noctalia Dark", JetBrains Mono for UI, buffer and terminal | all roles |
| Obsidian | `obsidian` community template (colours) + `rice.css` snippet (master copy `~/.config/rice/obsidian/rice.css`, copied into each vault's `.obsidian/snippets`): JetBrains Mono, 0px corners, 2px borders, no shadows, text-only lowercase buttons (hover underline, accent focus underline, 0.96 press), accent underline on the active tab, image outlines. Window frame hidden (`obsidian.json`) | all roles |
| Discord | **Vesktop** (replaces the official client). User template `rice_discord` renders noctalia's Midnight theme into `~/.config/vesktop/themes/noctalia.theme.css`; `rice.theme.css` on top: square, 2px borders, JetBrains Mono, 150ms hovers, image outlines. Both enabled in `vesktop/settings/settings.json`. Vesktop's splash follows the theme (`splashTheming`) | all roles |
| Spotify | **Spicetify** (Spotify from spotify-launcher, patched with `spicetify backup apply`). Theme `Rice` in `~/.config/spicetify/Themes/Rice`: `color.ini` from user template `rice_spicetify`, `user.css`: JetBrains Mono (Spotify's font stacks are set in a layer with `!important`, so `user.css` sets them on every element), 0px corners, no shadows, a 2px box around the library, main view and right panel (by their stable ids: Spotify hashes class names), image outlines. noctalia's `spicetify-noctalia` extension recolours it live on a wallpaper change. **After a Spotify update:** `spicetify backup apply` | all roles |
| Claude | Electron app with no theme support: follows dark mode only | mode |
| Open Freeze Center | Runs as root (pkexec), so it can't read your theme: `sudo ~/.config/rice/root-gtk-theme.sh` copies the GTK 4 look to root (a snapshot: run again after a wallpaper change) | snapshot |
| Videos: mpv (instead of VLC) | default for video files (`xdg-mime`); `mpv.conf` (mono OSD, no border) and `script-opts/osc.conf` from user template `rice_mpv`: one plain bottom bar, JetBrains Mono, the accent only for the played part | all roles |
| Steam | **Not themed** (needs Millennium; declined) | — |
| Window switcher (ALT + Tab) | `~/.config/quickshell/rice/Switcher.qml`, layout `strip`: one 2px box with a row of live window previews (wraps after five), app name and workspace under each, the selected tile framed in the accent, its title underneath. The selected window's preview is live, the rest one frame (ScreencopyView). Also has `split` and `grid` layouts (`qs -c rice ipc call switcher style split`). Opens instantly | palette |
| Tray menus (right-click a tray icon) | `~/.config/quickshell/rice/TrayMenu.qml`: the app's own tray menu redrawn as lowercase lines in one 2px box under the icon (2px lines between groups, disabled lines dim, submenus open in place), and `close <app>` at the bottom (error tone) which runs the app's own Quit | palette |
| Window menu (ALT + right-click any window, or SUPER + M) | `~/.config/quickshell/rice/WindowMenu.qml`: ALT + right-click opens it at the cursor for the window under the mouse (floating windows on top, then the most recently used); SUPER + M uses the focused window. (The bar no longer shows the window title.) The window's options as lowercase lines in one 2px box: `move to 1 2 3 ... new` (the window moves, you stay), send to scratchpad, hide in background, float / tile, fullscreen, maximise, pin (floating only), close, force quit (error tone). Arrows / Enter / Esc; instant open and close | palette |
| Shortcuts window (SUPER + H) | `~/.config/quickshell/rice/Shortcuts.qml`: a `search:` field (the launcher's 2px box, block cursor) over all keybinds in four columns; typing switches to a fuzzy search over keys, descriptions, extra search words and sections, best matches first, matched letters bright, accent underline on the selected result. Esc clears, then closes. Hand-kept copy of `binds.lua` | palette |
| Notifications | noctalia, set through `noctalia msg config-set`: solid (opacity 1), 2px `on_surface_variant` border | palette |
| Password and keyring prompts | noctalia's own polkit agent (`polkit_agent = true`, panel style) and gcr's GTK 4 prompter (GTK theme) | palette |
| File picker | one GTK picker everywhere: portal `FileChooser=gtk` (`~/.config/xdg-desktop-portal/hyprland-portals.conf`), Firefox `widget.use-xdg-desktop-portal.file-picker = 1`, qt6ct `standard_dialogs=gtk3` | GTK theme |
| Firefox new tab and built-in pages | `newtab.html` (launcher layout: wallpaper, 2px line, time, date, `search:` with a block cursor), set as the new tab by `/usr/lib/firefox/rice.cfg` (autoconfig, from `sudo ~/.config/rice/system/install.sh`); `wallpaper.jpg` kept current by `sync-wallpaper.sh` (rice_firefox hook). `userContent.css`: settings, add-ons and other `about:` pages on Firefox's design tokens (colours, JetBrains Mono, 0px, 2px boxes, no button fills). Momentum is turned off (it replaced the new tab) | all roles |
| WhatsApp | Firefox web app: `~/.config/rice/whatsapp/whatsapp.sh` (own profile in `~/.local/share/rice/whatsapp-profile`, window class `whatsapp`, no toolbars, JetBrains Mono); the launcher's WhatsApp entry opens it. Choose WhatsApp's dark theme once after linking your phone | mode |
| Screenshots | `rice-slurp` (accent 2px selection border, dimmed screen, mono size label) for Print / SUPER + Print; swappy uses JetBrains Mono | palette |
| Terminal tools | fzf (`--color=16`, sharp border, `search:` prompt), bat (`ansi` theme) and btop all use the terminal's own palette | fixed palette |
| Sounds | `rice` sound theme (`~/.config/rice/sounds/rice`, short quiet tones, inherits freedesktop), set in gsettings and both GTK `settings.ini` | — |
| Icons and cursor | breeze-dark icons in GTK, Qt and KDE; **phinger-cursors-light** everywhere (uwsm env for Hyprland and Qt, gsettings and both GTK `settings.ini`, `~/.local/share/icons/default`) | — |
| Login screen | Own greetd greeter (`~/.config/rice-greeter`, installed to `/etc/greetd/rice-greeter` with `sudo …/install.sh`) inside noctalia's greeter session. Ly's layout (hints, hostname, `< session >`, login, password) drawn with the picker's tokens: same Theme values, translucent panel, 1px outlines, accent on the focused field only, heavily blurred wallpaper behind. Template `rice_greeter` writes colors + a small wallpaper to `/var/lib/rice-greeter` (no password) | colors, blurred wallpaper |

## 6. Wallpaper change pipeline

The wallhaven picker (`~/.config/quickshell/wallhaven/apply.sh`):

1. Downloads the wallpaper into `~/Wallpapers`.
2. Keeps noctalia in dark mode (`noctalia msg theme-mode-set dark` if anything changed it).
3. `noctalia msg wallpaper-set` → noctalia sets it, generates the tonal-spot palette and renders every template above; their hooks reload Hyprland, Obsidian, Spotify (Spicetify) and the greeter. Firefox picks up new colours on its next start.

## 7. Keeping it in place (updates)

Everything lives in `~/.config` (the dotfiles repo); nothing is patched inside
a package except Spotify. The `rice` command checks and repairs the lot:

| Command | Does |
|---|---|
| `rice check` | lists every themed piece as ok / needs |
| `rice apply [part...]` | fixes only what is off (parts: colors gtk firefox obsidian spotify discord editor launcher greeter) |
| `rice install` | new machine: links `~/.local/bin/rice` and the systemd user units, enables them, runs `rice apply` |

Automatic, no action needed:

- `rice-apply.timer`: at login and every 6 hours, `rice apply --quiet`.
- `rice-spotify.path`: Spotify updates (spotify-launcher) bring back `Apps/xpui.spa`; that starts `rice apply spotify`, which re-patches with Spicetify.
- pacman hook `/etc/pacman.d/hooks/90-rice-theme.hook` (install once: `sudo ~/.config/rice/system/install.sh`): after pacman updates Firefox, Vesktop, Spicetify, Obsidian, Zed, Text Editor, noctalia, Quickshell, Hyprland or the GTK/Qt theme packages, it starts `rice-apply.service` in your session.

Why the rest survives updates: Firefox reads `chrome/` and `user.js` from the profile (links to this folder) and `rice` keeps its add-on theme on the default one; Vesktop, Obsidian, Zed, GTK, Qt and the terminals read their theme from files in your home that packages never touch; the login screen is a copy in `/etc/greetd/rice-greeter` (`rice check` says when it is out of date: `sudo ~/.config/rice-greeter/install.sh`). What `rice` cannot see: a big redesign inside an app (e.g. Firefox renaming its CSS tokens) can change how the theme looks; THEME.md §5 says where each app's theme file is.

## Open decisions

- Steam stays unthemed (Millennium declined).
