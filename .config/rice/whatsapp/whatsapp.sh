#!/bin/sh
# WhatsApp as a Firefox web app (its own profile, its own window class
# "whatsapp"). If it is already open, focus it instead.
addr=$(hyprctl clients -j | jq -r '.[] | select(.class == "whatsapp") | .address' | head -n1)
if [ -n "$addr" ]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
    exit 0
fi
exec firefox --new-instance --name whatsapp --class whatsapp \
    --profile "$HOME/.local/share/rice/whatsapp-profile" https://web.whatsapp.com
