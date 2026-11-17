#!/usr/bin/env bash
# Copy the current wallpaper to the login screen's data folder, small: it is
# shown heavily blurred, so 640px wide is plenty and loads instantly.
# Run by noctalia's rice_greeter template on every wallpaper/palette change.
set -euo pipefail

dest=/var/lib/rice-greeter
[[ -w "$dest" ]] || exit 0
img=$(noctalia msg wallpaper-get 2>/dev/null | tr -d "'\"")
[[ -f "$img" ]] || exit 0

magick "$img" -resize '640x360^' -gravity center -extent 640x360 -quality 90 "$dest/.wallpaper.tmp.jpg"
chmod 644 "$dest/.wallpaper.tmp.jpg"
mv "$dest/.wallpaper.tmp.jpg" "$dest/wallpaper.jpg"
