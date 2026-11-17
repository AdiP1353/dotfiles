# dotfiles

A minimal, wallpaper-driven rice for CachyOS: Hyprland (Lua config), the
noctalia shell, my own Quickshell pieces, Kitty and fish.

One look everywhere: plain 2px boxes with square corners, lowercase text-only
buttons, `label:` fields with a block cursor, JetBrains Mono, the accent colour
only on focus and selection, always dark. Colours come from the wallpaper.
The full design spec is [`.config/rice/THEME.md`](../.config/rice/THEME.md).

## What's here

| Path | What it is |
|---|---|
| `.config/hypr/` | Hyprland, Lua config: binds, rules, decorations, autostart |
| `.config/quickshell/rice/` | top bar, app launcher (super space), window switcher (alt tab), shortcuts (super h), display mode switcher (super p) |
| `.config/quickshell/wallhaven/` | wallpaper picker (super w): browses wallhaven, learns from your ratings, SFW and screen-sized only |
| `.config/rice-greeter/` | login screen (greetd) and lock screen (super l) in the Ly layout |
| `.config/noctalia/` | noctalia settings and the rice's colour templates |
| `.config/kitty/`, `.config/fish/`, `.config/fastfetch/` | terminal, prompt and greeting |
| `.config/gtk-*/gtk.css`, `.config/qt6ct/` | square corners and fonts for GTK and Qt apps |

## Needs

Hyprland 0.57+ (Lua config), noctalia, quickshell, greetd, kitty, fish,
fastfetch, JetBrains Mono Nerd Font, hyprpicker, grim, slurp, uwsm.

## Install

```sh
git clone --bare <this repo> ~/.dotfiles
alias dots='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dots checkout            # move any clashing files out of the way first
dots config status.showUntrackedFiles no
sudo ~/.config/rice-greeter/install.sh   # login screen
```

Not included (machine-specific or generated): the monitor layout
(`~/.config/hypr/monitors.lua`, from nwg-displays; optional), the SUPER + P
display mode, the colour files noctalia writes on each wallpaper change, and
the fastfetch logo art (`logo.png`, `logo.txt`; the greeting falls back to fastfetch's own logo).
