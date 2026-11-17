#!/bin/sh
# Keeps wallpaper.jpg (shown on Firefox's new tab page) pointing at the
# current wallpaper. Run by noctalia after every wallpaper change.
w=$(noctalia msg wallpaper-get 2>/dev/null | tr -d "'\"")
[ -f "$w" ] && ln -sfn "$w" "$HOME/.config/rice/firefox/wallpaper.jpg"
exit 0
