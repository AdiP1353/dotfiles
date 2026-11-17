#!/usr/bin/env bash
# Install or update the rice login screen. Run with sudo after editing:
#   sudo ~/.config/rice-greeter/install.sh
#
#  1. copies the greeter to /etc/greetd/rice-greeter (root-owned code);
#  2. makes sure /var/lib/rice-greeter exists, owned by you and readable by
#     the greeter (noctalia writes the colors there, no password needed);
#  3. points greetd at it (once), still inside noctalia's greeter session.
# Safety: if the greeter fails to start, run.sh falls back to noctalia's.
# Undo:   sudo cp /etc/greetd/config.toml.bak-rice /etc/greetd/config.toml
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
owner=${SUDO_USER:?run with sudo from your own account}
src=$(dirname "$(realpath "$0")")
dest=/etc/greetd/rice-greeter
data=/var/lib/rice-greeter

install -d -m 755 "$dest"
rm -f "$dest"/*.qml                     # drop files from older versions
install -m 644 "$src"/*.qml "$dest"/
cat > "$dest/run.sh" <<'RUN'
#!/bin/sh
# Started by noctalia-greeter-session's compositor (NOCTALIA_GREETER_BIN).
# Falls back to noctalia's own greeter if Quickshell exits with an error.
export RICE_GREETER_DATA=/var/lib/rice-greeter
# The greeter compositor draws no window decorations, so Qt would draw its own
# title bar, whose close button leaves a bare grey screen. No title bar.
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
qs -p /etc/greetd/rice-greeter/shell.qml "$@"
status=$?
[ "$status" -eq 0 ] || exec /usr/bin/noctalia-greeter "$@"
exit 0
RUN
chmod 755 "$dest/run.sh"

install -d -m 755 -o "$owner" -g "$owner" "$data"

cfg=/etc/greetd/config.toml
[[ -f "$cfg.bak-rice" ]] || cp -a "$cfg" "$cfg.bak-rice"
if ! grep -q 'rice-greeter' "$cfg"; then
    sed -i '/^\[default_session\]/,/^\[/ s|^command = .*|command = "env NOCTALIA_GREETER_BIN=/etc/greetd/rice-greeter/run.sh /usr/bin/noctalia-greeter-session"|' "$cfg"
fi
echo "installed:"; ls "$dest"
grep '^command' "$cfg"
