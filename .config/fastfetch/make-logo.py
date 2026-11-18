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
px = im.load()

def solid(p): return p[3] >= 128
out = []
for y in range(0, rows_px, 2):
    line = ""
    for x in range(cols):
        t, b = px[x, y], px[x, y + 1]
        if solid(t) and solid(b):
            line += f"\x1b[38;2;{t[0]};{t[1]};{t[2]}m\x1b[48;2;{b[0]};{b[1]};{b[2]}m▀"
        elif solid(t):
            line += f"\x1b[49m\x1b[38;2;{t[0]};{t[1]};{t[2]}m▀"
        elif solid(b):
            line += f"\x1b[49m\x1b[38;2;{b[0]};{b[1]};{b[2]}m▄"
        else:
            line += "\x1b[0m "
    out.append(line + "\x1b[0m")
open(dst, "w").write("\n".join(out) + "\n")
print(f"{dst}: {cols}x{rows_px // 2}")
