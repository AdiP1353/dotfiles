#!/usr/bin/env bash
# SUPER + L: lock with the rice lock screen (same look as the login screen).
# Does nothing if it is already locked.
pgrep -f 'qs -p .*rice-greeter/lock\.qml' >/dev/null && exit 0
exec qs -p "$HOME/.config/rice-greeter/lock.qml"
