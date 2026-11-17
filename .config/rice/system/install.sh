#!/bin/sh
# System part of the rice (run once with sudo):
#   sudo ~/.config/rice/system/install.sh
# Installs a pacman hook so the theme is re-applied (as you, in your session)
# right after pacman updates any of the themed apps, and points Firefox's new
# tab at the rice's page.
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

# Firefox: new tabs open the rice's page (~/.config/rice/firefox/newtab.html).
# Autoconfig files are not part of the firefox package, so updates keep them.
if [ -d /usr/lib/firefox ]; then
    install -d -m 755 /usr/lib/firefox/defaults/pref
    cat > /usr/lib/firefox/defaults/pref/rice-autoconfig.js <<CFG
pref("general.config.filename", "rice.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
CFG
    home=$(getent passwd "$user" | cut -d: -f6)
    cat > /usr/lib/firefox/rice.cfg <<CFG
// rice: new tabs show ~/.config/rice/firefox/newtab.html (first line must be a comment)
try {
  const { AboutNewTab } = ChromeUtils.importESModule("resource:///modules/AboutNewTab.sys.mjs");
  AboutNewTab.newTabURL = "file://$home/.config/rice/firefox/newtab.html";
} catch (e) {}
CFG
    chmod 644 /usr/lib/firefox/rice.cfg
    echo "firefox new tab page installed: /usr/lib/firefox/rice.cfg"
fi
