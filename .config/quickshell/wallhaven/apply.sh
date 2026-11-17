#!/usr/bin/env bash
# Download a wallhaven wallpaper and hand it to noctalia, which sets it and
# regenerates every color template from it.
#
# Usage: apply.sh <image-url> <wallhaven-id>
# Everything stays in dark mode whatever the wallpaper's brightness.
set -euo pipefail

url=${1:?image url missing}
id=${2:?wallhaven id missing}

# Save into the folder noctalia's own picker browses, so downloads show up there too.
dir=$(noctalia msg config-get wallpaper.directory 2>/dev/null | tr -d "'\"" || true)
[[ -n "$dir" ]] || dir="$HOME/Wallpapers"
mkdir -p "$dir"

ext=${url##*.}
file="$dir/wallhaven-$id.$ext"

cache="${XDG_CACHE_HOME:-$HOME/.cache}/rice/wallhaven/full/$id.$ext"
here=$(dirname "$(realpath "$0")")

# Already checked and kept by the background pre-check: instant.
if [[ ! -s "$file" && -s "$cache" ]]; then
    install -m 644 "$cache" "$file" && rm -f "$cache"
fi

if [[ ! -s "$file" ]]; then
    tmp=$(mktemp "$dir/.wallhaven-$id.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    if ! curl -fsSL --retry 2 --max-time 120 -o "$tmp" "$url"; then
        echo "Download failed" >&2
        exit 1
    fi
    chmod 644 "$tmp"   # mktemp creates 600; make it a normal readable file
    mv "$tmp" "$file"
    trap - EXIT
fi

# Blurry at full size (upscaled or soft)? Then it is not applied, and the
# picker hides it from now on (taste.py remembers the verdict). Exit 3.
verdict=$(python3 "$here/taste.py" check "$file" "$id" 2>/dev/null || echo '{"sharp": true}')
if [[ "$verdict" == *'"sharp": false'* ]]; then
    rm -f "$file"
    echo "blurry at full size, skipped" >&2
    exit 3
fi

# Apps always stay dark; the wallpaper only changes the colors (THEME.md).
# Re-assert it in case something else switched the mode.
if [[ "$(noctalia msg theme-mode-get 2>/dev/null)" != dark ]]; then
    noctalia msg theme-mode-set dark >/dev/null
fi
noctalia msg wallpaper-set "$file" >/dev/null

echo "$file"
