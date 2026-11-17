#!/bin/sh
# System part of the rice (run once with sudo):
#   sudo ~/.config/rice/system/install.sh
# Installs a pacman hook so the theme is re-applied (as you, in your session)
# right after pacman updates any of the themed apps.
set -eu
user="${SUDO_USER:-}"
[ -n "$user" ] && [ "$(id -u)" = 0 ] || { echo "run it with sudo" >&2; exit 1; }
install -d -m 755 /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/90-rice-theme.hook <<HOOK
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = firefox
Target = vesktop-bin
Target = spicetify-cli
Target = obsidian
Target = zed
Target = gnome-text-editor
Target = noctalia
Target = quickshell
Target = adw-gtk-theme
Target = qt6ct
Target = breeze-icons
Target = hyprland

[Action]
Description = Re-applying the rice theme...
When = PostTransaction
Exec = /usr/bin/systemctl --user --machine=$user@.host start --no-block rice-apply.service
HOOK
echo "pacman hook installed: /etc/pacman.d/hooks/90-rice-theme.hook"
