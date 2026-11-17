#!/usr/bin/env python3
"""Find where Noctalia draws the workspace circles in the top bar.

Called by config/dragtoworkspace.lua when a window drag starts:

    map-workspace-circles.py <monitor_name> <token> <output_file>

Noctalia does not report where it draws the circles (and they shift sideways as
the window title next to them changes length), so this script finds them on
screen. It captures the bar, splits each capsule into the marks drawn on it, and
keeps the capsule whose marks match the workspaces: the same number of circles,
evenly spaced, with the wide pill where the current workspace is.

It writes a small text file that the Lua side reads while the drag continues:

    <token>
    ok                                  (or "none" if no circles were found)
    alerts <names already alerted>      (workspaces Noctalia already highlights)
    <start_x> <end_x> <move_selector> <alert_name>     one line per circle,
    ...                                                 in logical px
"""

import json
import os
import subprocess
import sys
import time

BAR_HEIGHT = 40          # logical px from the top of the monitor that count as the bar
LOG = "/tmp/hypr-drag-to-workspace.log"
DEBUG = True             # keep in step with DEBUG in config/dragtoworkspace.lua


def log(message):
    if DEBUG:
        with open(LOG, "a") as handle:
            handle.write(time.strftime("%H:%M:%S ") + "[py] " + message + "\n")


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def capture(x, y, width, height):
    """Screenshot a region and return (width, height, rows of (r, g, b))."""
    data = subprocess.run(["grim", "-t", "ppm", "-g", f"{x},{y} {width}x{height}", "-"],
                          capture_output=True, check=True).stdout
    # Binary PPM: "P6\n<w> <h>\n<max>\n" then RGB bytes.
    fields, pos = [], 0
    while len(fields) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            pos = data.index(b"\n", pos) + 1
            continue
        end = pos
        while not data[end:end + 1].isspace():
            end += 1
        fields.append(data[pos:end])
        pos = end
    pos += 1
    w, h = int(fields[1]), int(fields[2])
    pixels = data[pos:pos + w * h * 3]
    rows = [[tuple(pixels[(r * w + c) * 3:(r * w + c) * 3 + 3]) for c in range(w)] for r in range(h)]
    return w, h, rows


def lum(p):
    return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]


def differs(a, b, tolerance=30):
    return max(abs(x - y) for x, y in zip(a, b)) > tolerance


def mode(colours):
    counts = {}
    for c in colours:
        counts[c] = counts.get(c, 0) + 1
    return max(counts, key=counts.get)


def capsules(row):
    """Runs of pixels that differ from the bar background: capsules, icons, text."""
    background = mode(row)
    runs, start = [], None
    for c, p in enumerate(row + [background]):
        if differs(p, background):
            if start is None:
                start = c
        elif start is not None:
            if c - start >= 10:
                runs.append((start, c - 1))
            start = None
    return runs


def marks(row, left, right):
    """The circles drawn on one capsule, as (start, end) columns."""
    capsule = row[left:right + 1]
    # The capsule's two ends are always plain fill (the circles are inset), while
    # the circles can cover most of the middle, so take the fill colour from the ends.
    ends = capsule[:4] + capsule[-4:]
    fill = sum(lum(p) for p in ends) / len(ends)
    contrast = max(abs(lum(p) - fill) for p in capsule)
    if contrast < 40:
        return []
    on = [abs(lum(p) - fill) > contrast / 2 for p in capsule]
    blobs, inside = [], None
    for i, mark in enumerate(on + [False]):
        if mark and inside is None:
            inside = i
        elif not mark and inside is not None:
            if i - inside >= 3:
                blobs.append((left + inside, left + i - 1))
            inside = None
    return blobs


def plausible(blobs, ids, active_id):
    """Evenly spaced circles of one size, plus a wider pill at the current workspace."""
    if len(blobs) != len(ids):
        return False
    widths = [b - a + 1 for a, b in blobs]
    if len(blobs) > 1:
        widest = widths.index(max(widths))
        if active_id not in ids or ids.index(active_id) != widest:
            return False
        small = widths[:widest] + widths[widest + 1:]
        if max(widths) < 1.6 * min(small) or max(small) > 1.4 * min(small):
            return False
    gaps = [blobs[i + 1][0] - blobs[i][1] for i in range(len(blobs) - 1)]
    return not gaps or max(gaps) - min(gaps) <= 3


def main():
    monitor_name, token, output = sys.argv[1], sys.argv[2], sys.argv[3]
    monitor = next(m for m in json.loads(run("hyprctl", "-j", "monitors")) if m["name"] == monitor_name)

    # Workspaces shown in the bar for this monitor, in the order they are drawn.
    workspaces = sorted((w for w in json.loads(run("hyprctl", "-j", "workspaces"))
                         if w["monitor"] == monitor_name and not w["name"].startswith("special:")),
                        key=lambda w: w["id"])
    candidates = [workspaces, [w for w in workspaces if w["id"] > 0]]
    active_id = monitor["activeWorkspace"]["id"]

    logical_width = int(monitor["width"] / monitor["scale"])
    width, _, rows = capture(monitor["x"], monitor["y"], logical_width, BAR_HEIGHT)
    scale = width / logical_width

    # Of all rows that show a matching set of circles, use the one through their
    # middle, where they are widest.
    best = None
    for row in rows:
        for left, right in capsules(row):
            blobs = marks(row, left, right)
            for shown in candidates:
                if blobs and plausible(blobs, [w["id"] for w in shown], active_id):
                    total = sum(b - a for a, b in blobs)
                    if best is None or total > best[0]:
                        best = (total, blobs, shown)

    try:
        alerted = run("noctalia", "msg", "workspace-alert-status").split()
        alerted = [] if "(no" in alerted else alerted
    except (OSError, subprocess.CalledProcessError):
        alerted = []

    lines = [token]
    if best is None:
        lines.append("none")
        log(f"no workspace circles found (workspaces: {[w['name'] for w in workspaces]})")
    else:
        _, blobs, shown = best
        lines.append("ok")
        lines.append("alerts " + " ".join(alerted))
        for (a, b), w in zip(blobs, shown):
            selector = str(w["id"]) if w["id"] > 0 else "name:" + w["name"]
            lines.append(f"{monitor['x'] + a / scale:.1f} {monitor['x'] + b / scale:.1f} {selector} {w['name']}")
        log(f"found {len(blobs)} circles at {[(round(a / scale), round(b / scale)) for a, b in blobs]}")

    tmp = output + ".tmp"
    with open(tmp, "w") as handle:
        handle.write("\n".join(lines) + "\n")
    os.replace(tmp, output)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # never let a failed lookup disturb the desktop
        log(f"error: {error!r}")
