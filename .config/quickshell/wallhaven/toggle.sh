#!/usr/bin/env bash
# Open the wallhaven picker, or close it if it is already open.
if pgrep -f 'qs -c wallhaven$' >/dev/null; then
    pkill -f 'qs -c wallhaven$'
else
    exec qs -c wallhaven
fi
