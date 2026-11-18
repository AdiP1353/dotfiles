#!/bin/sh
# Keeps wallpaper.jpg (shown on Firefox's new tab page) pointing at the
# current wallpaper. Run by noctalia after every wallpaper change.
# Firefox follows newtab.html's link into ~/dotfiles and looks for its files
# there, so the wallpaper and the colours are linked next to the real page too
# (both are git-ignored: they differ per machine).
here="$HOME/.config/rice/firefox"
w=$(noctalia msg wallpaper-get 2>/dev/null | tr -d "'\"")
[ -f "$w" ] && ln -sfn "$w" "$here/wallpaper.jpg"
real=$(dirname "$(readlink -f "$here/newtab.html")")
if [ "$real" != "$here" ]; then
    [ -f "$w" ] && ln -sfn "$w" "$real/wallpaper.jpg"
    ln -sfn "$here/rice-colors.css" "$real/rice-colors.css"
fi
exit 0
