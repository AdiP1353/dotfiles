#!/usr/bin/env python3
"""Build the "Rice" Kvantum theme (Qt apps) from the wallpaper's colours.

Starts from Kvantum's own KvFlat theme and makes it look like the rest of the
rice (THEME.md §3):
  - every frame piece (the 8 border parts of buttons, fields, menus, tabs,
    scroll bars...) becomes a plain square rectangle, so corners are 0px;
  - borders are on_surface_variant, the accent only for focus and selection
    ("focused" / "toggled" states), insides use the surface colours;
  - every other colour in KvFlat (arrows, check marks...) is mapped onto the
    wallpaper palette by how light it is;
  - frames are 2px, no menu or tooltip shadows.

Run by noctalia after each wallpaper change (rice_colors post_hook) and by
`rice apply qt`. Writes ~/.config/Kvantum/Rice/{Rice.svg,Rice.kvconfig}.
Qt apps pick up new colours when they restart.
"""
import json, os, re, sys
import xml.etree.ElementTree as ET

import gi
gi.require_version("Rsvg", "2.0")
from gi.repository import Rsvg

BASE = "/usr/share/Kvantum/KvFlat"
HOME = os.path.expanduser("~")
OUT = os.path.join(HOME, ".config/Kvantum/Rice")
COLORS = os.path.join(HOME, ".local/state/rice/colors.json")
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)
for p, u in {"svg": SVG_NS, "xlink": "http://www.w3.org/1999/xlink",
             "inkscape": "http://www.inkscape.org/namespaces/inkscape",
             "sodipodi": "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd",
             "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
             "cc": "http://creativecommons.org/ns#", "dc": "http://purl.org/dc/elements/1.1/"}.items():
    ET.register_namespace(p, u)

c = json.load(open(COLORS))
surface, container, high = c["surface"], c["surface_container"], c["surface_container_high"]
text, dim, outline = c["on_surface"], c["on_surface_variant"], c["outline_variant"]
primary, on_primary, error = c["primary"], c["on_primary"], c["error"]

def lum(h):
    h = h.lstrip("#"); r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def is_blue(h):
    h = h.lstrip("#"); r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return b > r + 40 and b > g

def remap(h):
    """KvFlat colour -> palette colour, by hue (blue = accent) and lightness."""
    if is_blue(h):
        return primary
    l = lum(h)
    if l < 0.13: return surface
    if l < 0.20: return container
    if l < 0.26: return high
    if l < 0.55: return outline if l < 0.38 else dim
    return text

# ---------------------------------------------------------------- frame pieces
PARTS = ("topleft", "topright", "bottomleft", "bottomright", "top", "bottom", "left", "right")
STATES = ("normal", "focused", "pressed", "toggled", "disabled")
piece_re = re.compile(r"^(?P<base>.+)-(?P<state>" + "|".join(STATES) + r")-(?P<part>" + "|".join(PARTS) + r")$")

def border_for(state):
    return {"focused": primary, "toggled": primary, "pressed": text, "disabled": outline}.get(state, dim)

def fill_for(state):
    return {"pressed": container, "toggled": surface, "disabled": surface}.get(state, surface)

def main():
    src = os.path.join(BASE, "KvFlat.svg")
    handle = Rsvg.Handle.new_from_file(src)
    _, w, h = handle.get_intrinsic_size_in_pixels()
    vp = Rsvg.Rectangle(); vp.x = vp.y = 0; vp.width = w; vp.height = h

    tree = ET.parse(src)
    root = tree.getroot()
    parent = {ch: p for p in root.iter() for ch in p}

    ids = {el.get("id"): el for el in root.iter() if el.get("id")}
    bases = {m.group("base") + "-" + m.group("state") for i in ids if (m := piece_re.match(i))}

    new_rects = []
    for i, el in list(ids.items()):
        m = piece_re.match(i)
        if m:
            colour = border_for(m.group("state"))
        elif i in bases:                       # the inside of a framed element
            colour = fill_for(i.rsplit("-", 1)[1])
        else:
            continue
        ok, ink, _ = handle.get_geometry_for_layer("#" + i, vp)
        if not ok or ink.width <= 0 or ink.height <= 0:
            continue
        p = parent.get(el)
        if p is not None:
            p.remove(el)
        new_rects.append((i, ink, colour))

    # new pieces at the top level (no inherited transforms): exact same boxes
    for i, ink, colour in new_rects:
        ET.SubElement(root, f"{{{SVG_NS}}}rect", {
            "id": i, "x": f"{ink.x:.3f}", "y": f"{ink.y:.3f}",
            "width": f"{ink.width:.3f}", "height": f"{ink.height:.3f}",
            "style": f"fill:{colour};stroke:none"})

    svg = ET.tostring(root, encoding="unicode")
    # every remaining KvFlat colour (indicators, arrows, check marks...) onto the palette
    svg = re.sub(r"#[0-9a-fA-F]{6}\b", lambda mm: remap(mm.group(0)), svg)

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Rice.svg"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n' + svg)

    # ---------------------------------------------------------------- kvconfig
    cfg = open(os.path.join(BASE, "KvFlat.kvconfig")).read()
    cfg = re.sub(r"(?m)^(frame\.(top|bottom|left|right))=([1-9]\d*)$", r"\1=2", cfg)   # 2px frames
    general = {"menu_shadow_depth": "0", "tooltip_shadow_depth": "0", "spread_menuitems": "false",
               "composite": "false", "translucent_windows": "false", "blurring": "false",
               "popup_blurring": "false", "animate_states": "false", "no_inactiveness": "true"}
    for k, v in general.items():
        if re.search(rf"(?m)^{k}=", cfg):
            cfg = re.sub(rf"(?m)^{k}=.*$", f"{k}={v}", cfg)
        else:
            cfg = cfg.replace("[%General]\n", f"[%General]\n{k}={v}\n", 1)
    colours = {
        "window.color": surface, "base.color": surface, "alt.base.color": container,
        "button.color": surface, "light.color": high, "mid.light.color": container,
        "dark.color": surface, "mid.color": outline, "highlight.color": primary,
        "inactive.highlight.color": outline, "text.color": text, "window.text.color": text,
        "button.text.color": text, "disabled.text.color": outline, "tooltip.text.color": text,
        "highlight.text.color": on_primary, "link.color": primary, "link.visited.color": dim,
        "progress.indicator.text.color": text,
    }
    for k, v in colours.items():
        if re.search(rf"(?m)^{re.escape(k)}=", cfg):
            cfg = re.sub(rf"(?m)^{re.escape(k)}=.*$", f"{k}={v}", cfg)
        else:
            cfg = cfg.replace("[GeneralColors]\n", f"[GeneralColors]\n{k}={v}\n", 1)
    cfg = "# Generated by ~/.config/rice/qt/make-kvantum.py from KvFlat and the wallpaper.\n" + cfg
    with open(os.path.join(OUT, "Rice.kvconfig"), "w") as f:
        f.write(cfg)

    kv = os.path.join(HOME, ".config/Kvantum/kvantum.kvconfig")
    with open(kv, "w") as f:
        f.write("[General]\ntheme=Rice\n")
    print(f"Rice Kvantum theme: {len(new_rects)} square pieces")

if __name__ == "__main__":
    sys.exit(main())
