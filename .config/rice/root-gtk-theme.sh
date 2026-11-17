#!/bin/sh
# Gives apps that run as root (Open Freeze Center, started through pkexec)
# the rice's GTK 4 look: the wallpaper colours, square corners, JetBrains
# Mono, breeze-dark icons and dark mode.
#
#   sudo ~/.config/rice/root-gtk-theme.sh
#
# It copies the files (root never reads your home while the app runs), so the
# colours are a snapshot: run it again after a wallpaper change to refresh.
set -eu

user="${SUDO_USER:-}"
[ -n "$user" ] && [ "$(id -u)" = 0 ] || { echo "run it with sudo" >&2; exit 1; }
home=$(getent passwd "$user" | cut -d: -f6)

install -d -m 755 /root/.config/gtk-4.0
for f in gtk.css noctalia.css noctalia-extensions.css settings.ini; do
    src="$home/.config/gtk-4.0/$f"
    # regular files only: never follow a link out of the theme folder
    if [ -f "$src" ] && [ ! -L "$src" ]; then
        install -m 644 "$src" "/root/.config/gtk-4.0/$f"
    fi
done

# With no portal, libadwaita reads dark mode, font and icons from GSettings.
dbus-run-session -- sh -c '
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 10"
    gsettings set org.gnome.desktop.interface icon-theme breeze-dark
    gsettings set org.gnome.desktop.interface cursor-theme phinger-cursors-light
'
echo "root GTK theme updated"
