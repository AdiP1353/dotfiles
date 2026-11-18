#!/usr/bin/env python3
"""Tints ~/.config/fastfetch/logo.png in the wallpaper's colours (grayscale,
then two tones: shadows a deep version of the accent, highlights the light
text colour) into logo-tinted.png, and turns that into logo.ansi: the same picture as
coloured half-block characters (truecolor), for terminals that can't show
images (fastfetch prints it with --logo-type file-raw). Transparent pixels
stay the terminal's own background. Run again after changing logo.png."""
import os, sys
from PIL import Image

src = os.path.expanduser("~/.config/fastfetch/logo.png")
dst = os.path.expanduser("~/.config/fastfetch/logo.ansi")
cols = int(sys.argv[1]) if len(sys.argv) > 1 else 36

import json
pal = json.load(open(os.path.expanduser("~/.local/state/rice/colors.json")))
hx = lambda h: tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
p, t = hx(pal["primary"]), hx(pal["on_surface"])
dark = tuple(int(c * 0.35) for c in p)          # shadows: deep accent
im = Image.open(src).convert("RGBA")
px0 = im.load()
for y in range(im.height):
    for x in range(im.width):
        r, g, b, a = px0[x, y]
        if not a: continue
        l = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        px0[x, y] = tuple(int(dark[i] + (t[i] - dark[i]) * l) for i in range(3)) + (a,)
im.save(os.path.expanduser("~/.config/fastfetch/logo-tinted.png"))
rows_px = round(im.height / im.width * cols)
rows_px += rows_px % 2
im = im.resize((cols, rows_px), Image.Resampling.BOX)
im = im  # (tinted above)
px = im.load()

# ASCII art: each character cell covers 1 x 2 pixels; shape from the alpha,
# density from how dark the picture is there (dark body = dense), colour from
# the tinted pixel. Transparent cells are spaces.
RAMP = " .:-=+*#%@"
out = []
for y in range(0, rows_px, 2):
    line = ""
    for x in range(cols):
        t, b = px[x, y], px[x, y + 1]
        a_ = (t[3] + b[3]) / 2
        if a_ < 100:
            line += " "; continue
        c = tuple((t[i] + b[i]) // 2 for i in range(3))
        l = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255
        ch = RAMP[max(1, min(len(RAMP) - 1, int((1 - l) * (len(RAMP) - 1) + 0.5)))]
        line += f"\x1b[38;2;{c[0]};{c[1]};{c[2]}m{ch}"
    out.append(line.rstrip() + "\x1b[0m")
open(dst, "w").write("\n".join(out) + "\n")
print(f"{dst}: {cols}x{rows_px // 2} ascii")
