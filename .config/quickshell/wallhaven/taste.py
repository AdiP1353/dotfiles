#!/usr/bin/env python3
"""Taste engine for the wallhaven picker.

Learns what wallpapers you like from swipe ratings, likes, dislikes and the
wallpapers you actually apply, then finds and ranks new ones from wallhaven.

Data (all in ~/.local/state/rice/wallhaven/):
  events.jsonl      append-only log of everything you did (source of truth)
  items.json        metadata cache: every wallpaper seen, with tags when known
  impressions.json  how often each item was shown in "For you" without action

Commands (all print JSON on stdout):
  session [n]          ensure a candidate pool, return n wallpapers to rate
  event TYPE ID [JSON] log like | dislike | skip | apply | unlike | reset
                       (skip = no opinion; reset = change an earlier rating to skip)
  curated [n] [quiet]  ranked "For you" list (quiet: don't count impressions)
  liked                your liked / applied wallpapers, newest first
  history              everything rated or skipped, newest first, with its rating
  check PATH [ID]      measure a downloaded wallpaper's sharpness (and remember it)
  blurry               ids known to be blurry at full size
  screen               the screen size and search filters in use
  refresh [budget]     background network work: tags, new candidates
  stats                what the model has learned (for debugging)

How it scores (see score()):
  Each tag, color and category gets a weight in -1..1 from your ratings:
      w = (likes - dislikes) / (likes + dislikes + PRIOR)
  where applying counts as 2 likes and old events fade (half-life 120 days).
  A wallpaper's score adds up its tag, color and category weights, a bit of
  popularity, and a bonus when several of your taste searches found it.
  "For you" picks greedily by score with a penalty for repeating the same
  tags, so it stays varied; things you keep scrolling past slowly sink.
"""

import fcntl
import json
import math
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from contextlib import contextmanager

API = "https://wallhaven.cc/api/v1"


def screen_size():
    """Resolution of the focused monitor (WALLHAVEN_SCREEN=WxH overrides)."""
    env = os.environ.get("WALLHAVEN_SCREEN", "")
    if "x" in env:
        w, h = env.lower().split("x")
        return int(w), int(h)
    try:
        import subprocess
        mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True,
                                         text=True, timeout=2).stdout)
        m = next((m for m in mons if m.get("focused")), mons[0])
        return int(m["width"]), int(m["height"])
    except Exception:
        return 1920, 1080


def ratio_name(w, h):
    r = w / h
    for name, (a, b) in {"16x9": (16, 9), "16x10": (16, 10), "21x9": (21, 9), "32x9": (32, 9),
                         "4x3": (4, 3), "3x2": (3, 2), "5x4": (5, 4)}.items():
        if abs(r - a / b) < 0.01:
            return name
    g = math.gcd(w, h)
    return f"{w // g}x{h // g}"


SCREEN_W, SCREEN_H = screen_size()
# SFW only; same shape as the screen and at least as big, so it fills it uncropped.
BASE_FILTERS = {"purity": "100", "atleast": f"{SCREEN_W}x{SCREEN_H}",
                "ratios": ratio_name(SCREEN_W, SCREEN_H)}


def fits(item):
    """SFW, and the screen's aspect ratio at the screen's size or larger."""
    if item.get("purity", "sfw") != "sfw":
        return False
    try:
        w, h = (int(x) for x in item.get("resolution", "").split("x"))
    except ValueError:
        return False
    return w >= SCREEN_W and h >= SCREEN_H and abs(w / h - SCREEN_W / SCREEN_H) < 0.01
STATE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
                     "rice", "wallhaven")
EVENTS = os.path.join(STATE, "events.jsonl")
ITEMS = os.path.join(STATE, "items.json")
IMPRESSIONS = os.path.join(STATE, "impressions.json")
LOCK = os.path.join(STATE, "data.lock")
REFRESH_LOCK = os.path.join(STATE, "refresh.lock")

# Full-size downloads checked for sharpness; the sharp ones are kept so that
# applying them later is instant (the picker's apply.sh moves them into place).
FULL_CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
                          "rice", "wallhaven", "full")
FULL_CACHE_MAX = 40          # files kept
PRECHECK_BUDGET = 8          # full images checked per background refresh

PRIOR = 2.0                 # smoothing: how many ratings before a weight gets confident
HALF_LIFE = 120 * 86400     # old ratings fade
PASS_COOLDOWN = 30 * 86400  # a passed wallpaper can come back after this
REQUEST_GAP = 1.5           # seconds between API calls (limit is 45/min)
POOL_CAP = 900              # unrated candidates kept

STRENGTH = {"like": 1.0, "apply": 2.0, "dislike": -1.0}


# ---------------------------------------------------------------- storage

def ensure_dir():
    os.makedirs(STATE, exist_ok=True)


@contextmanager
def data_lock():
    ensure_dir()
    with open(LOCK, "a") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def save_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    os.replace(tmp, path)


def load_events():
    out = []
    try:
        with open(EVENTS) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        out.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
    except FileNotFoundError:
        pass
    return out


def normalize(w, source=None):
    """Turn a wallhaven API result into our item shape."""
    item = {
        "id": w["id"],
        "thumb": w["thumbs"]["large"],
        "full": w["path"],
        "resolution": w.get("resolution", ""),
        "category": w.get("category", ""),
        "favorites": w.get("favorites", 0),
        "colors": w.get("colors", [])[:5],
        "purity": w.get("purity", "sfw"),
        "added": time.time(),
        "sources": {},
    }
    if "tags" in w:
        item["tags"] = [{"id": t["id"], "name": t["name"]} for t in w["tags"]]
    if source:
        item["sources"][source] = 1
    return item


def merge_item(items, new):
    """Add or update an item without losing tags, sources or its added time."""
    old = items.get(new["id"])
    if not old:
        items[new["id"]] = new
        return
    for k in ("thumb", "full", "resolution", "category", "favorites", "colors", "purity"):
        if new.get(k):
            old[k] = new[k]
    if new.get("tags"):
        old["tags"] = new["tags"]
    old.setdefault("sources", {}).update(new.get("sources", {}))


# ---------------------------------------------------------------- learning

def latest_status(events):
    """id -> (status, time, strength). Latest like/dislike/unlike wins; apply adds."""
    status = {}
    for e in events:
        t, i, ts = e.get("type"), e.get("id"), e.get("t", 0)
        if not i:
            continue
        cur = status.get(i, {"rating": None, "applied": 0, "t": 0, "pass": 0})
        if t in ("like", "dislike"):
            cur["rating"] = t
            cur["t"] = ts
        elif t == "unlike":
            cur["rating"] = None
            cur["applied"] = 0
            cur["t"] = ts
        elif t == "apply":
            cur["applied"] += 1
            cur["t"] = ts
            if cur["rating"] == "dislike":
                cur["rating"] = None
        elif t == "pass":
            cur["pass"] = ts
        elif t == "reset":      # rating changed to "skip": no opinion, and not offered again soon
            cur["rating"] = None
            cur["applied"] = 0
            cur["t"] = ts
            cur["pass"] = ts
        status[i] = cur
    return status


def strength_of(st, now):
    s = 0.0
    if st["rating"] == "like":
        s += STRENGTH["like"]
    elif st["rating"] == "dislike":
        s += STRENGTH["dislike"]
    if st["applied"]:
        s += STRENGTH["apply"]
    decay = 0.5 ** (max(0.0, now - st["t"]) / HALF_LIFE)
    return s * decay


def features(item):
    tags = [f"tag:{t['id']}" for t in (item.get("tags") or [])]
    if not tags:
        # Not enriched yet: the tag searches that found it are known tags.
        tags = [k for k in item.get("sources", {}) if k.startswith("tag:")]
    colors = [f"color:{c.lower()}" for c in item.get("colors", [])[:3]]
    cat = [f"cat:{item['category']}"] if item.get("category") else []
    return tags, colors, cat


def learn(items, status, now):
    """Return feature -> weight in -1..1, plus tag names for display."""
    pos, neg, names = {}, {}, {}
    for i, st in status.items():
        s = strength_of(st, now)
        it = items.get(i)
        if not it or s == 0:
            continue
        for t in it.get("tags") or []:
            names[f"tag:{t['id']}"] = t["name"]
        tags, colors, cat = features(it)
        for f in tags + colors + cat:
            if s > 0:
                pos[f] = pos.get(f, 0) + s
            else:
                neg[f] = neg.get(f, 0) - s
    weights = {}
    for f in set(pos) | set(neg):
        p, n = pos.get(f, 0), neg.get(f, 0)
        weights[f] = (p - n) / (p + n + PRIOR)
    return weights, names, pos, neg


def score(item, weights, impressions):
    tags, colors, cat = features(item)
    tag_part = sum(weights.get(t, 0) for t in tags) / math.sqrt(len(tags)) if tags else 0
    color_part = sum(weights.get(c, 0) for c in colors) / len(colors) if colors else 0
    cat_part = sum(weights.get(c, 0) for c in cat)
    quality = min(1.0, math.log10(item.get("favorites", 0) + 1) / 3)
    found_by = len([k for k in item.get("sources", {}) if k != "explore"])
    source_part = min(0.45, 0.15 * found_by)
    seen = min(6, impressions.get(item["id"], 0))
    checked = 0.3 if item.get("sharp") is True else 0.0   # known sharp: ahead of unchecked
    return (1.0 * tag_part + 0.5 * color_part + 0.4 * cat_part
            + 0.25 * quality + source_part + checked - 0.08 * seen)


def why(item, weights, names):
    tags, _, _ = features(item)
    good = sorted((weights.get(t, 0), t) for t in tags)
    good = [names.get(t, "") for w, t in reversed(good) if w > 0.1 and names.get(t)]
    if good:
        return "because: " + " · ".join(good[:2])
    if item.get("sources", {}).keys() == {"explore"}:
        return "something new"
    return ""


def jaccard(a, b):
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def rank(cands, weights, impressions, n, diversify=True):
    scored = [(score(it, weights, impressions), it) for it in cands]
    scored.sort(key=lambda x: -x[0])
    if not diversify:
        return scored[:n]
    pool = scored[: max(n * 6, 60)]
    picked = []
    while pool and len(picked) < n:
        best, best_v = None, -1e9
        for idx, (s, it) in enumerate(pool):
            ft = set(features(it)[0])
            overlap = max((jaccard(ft, set(features(p)[0])) for _, p in picked[-12:]), default=0)
            v = s - 0.35 * overlap
            if v > best_v:
                best, best_v = idx, v
        picked.append(pool.pop(best))
    return picked


def public(item, extra=None):
    out = {k: item.get(k) for k in ("id", "thumb", "full", "resolution", "category", "favorites", "colors", "purity")}
    if extra:
        out.update(extra)
    return out


# ---------------------------------------------------------------- sharpness
#
# Some wallpapers are upscaled or soft: their thumbnails look fine, but at
# full size on the screen they are blurry. File size does not reveal it (clean
# flat art compresses tiny yet is sharp), so the full image is measured, at the
# screen's size:
#   edge    99.5th percentile of the gradient: how steep the sharpest edges are
#   detail  mean change when the image is halved and restored: real fine detail
# Calibrated on the user's downloads: the blurry ones scored edge 37-61 and
# detail 0.7-0.9; sharp ones edge 84-166 or detail 1.1-4.5.

EDGE_MIN = 70.0
DETAIL_MIN = 1.2


def sharpness(path):
    import numpy as np
    from PIL import Image
    im = Image.open(path).convert("L")
    w, h = SCREEN_W, SCREEN_H
    # cover the screen like the wallpaper does (crop), then measure there
    s = max(w / im.width, h / im.height)
    im = im.resize((max(w, round(im.width * s)), max(h, round(im.height * s))), Image.LANCZOS)
    left, top = (im.width - w) // 2, (im.height - h) // 2
    g = np.asarray(im.crop((left, top, left + w, top + h)), dtype=np.float32)
    gx = np.abs(np.diff(g, axis=1))[:-1, :]
    gy = np.abs(np.diff(g, axis=0))[:, :-1]
    edge = float(np.percentile(np.hypot(gx, gy), 99.5))
    half = Image.fromarray(g.astype("uint8")).resize((w // 2, h // 2), Image.LANCZOS).resize((w, h), Image.LANCZOS)
    detail = float(np.mean(np.abs(g - np.asarray(half, dtype=np.float32))))
    return edge, detail


def is_sharp(edge, detail):
    return edge >= EDGE_MIN or detail >= DETAIL_MIN


def record_sharpness(wid, edge, detail):
    with data_lock():
        items = load_json(ITEMS, {})
        it = items.setdefault(wid, {"id": wid, "sources": {}, "added": time.time()})
        it["sharp"] = is_sharp(edge, detail)
        it["edge"] = round(edge, 1)
        it["detail"] = round(detail, 2)
        save_json(ITEMS, items)


def unrated(items, status, now):
    out = []
    for i, it in items.items():
        if not fits(it) or it.get("sharp") is False:
            continue
        st = status.get(i)
        if st and (st["rating"] or st["applied"]):
            continue
        if st and st["pass"] and now - st["pass"] < PASS_COOLDOWN:
            continue
        out.append(it)
    return out


# ---------------------------------------------------------------- network

class RateLimited(Exception):
    pass


_last_request = [0.0]


def api(path, params=None):
    wait = REQUEST_GAP - (time.time() - _last_request[0])
    if wait > 0:
        time.sleep(wait)
    url = f"{API}/{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "wallhaven-picker/1.0"})
    _last_request[0] = time.time()
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            body = r.read()
    except urllib.error.HTTPError as e:
        if e.code == 429:
            raise RateLimited()
        raise
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        # Cloudflare challenge page or similar: back off for this run.
        raise RateLimited()


def search(params, source):
    p = dict(BASE_FILTERS)
    p.update(params)
    data = api("search", p)
    return [normalize(w, source) for w in data.get("data", [])]


def details(wid):
    return normalize(api(f"w/{wid}")["data"])


def explore_fetch(budget):
    """Broad, popular wallpapers to learn from. Returns list of items."""
    out = []
    plans = [
        {"sorting": "toplist", "topRange": "1y", "page": random.randint(1, 25), "categories": "111"},
        {"sorting": "toplist", "topRange": "1M", "page": random.randint(1, 3), "categories": "111"},
        {"sorting": "random", "categories": "111"},
    ]
    for p in plans[:budget]:
        out += search(p, "explore")
    return out


# ---------------------------------------------------------------- commands

def cmd_session(n=10):
    now = time.time()
    with data_lock():
        items = load_json(ITEMS, {})
        events = load_events()
    status = latest_status(events)
    cands = unrated(items, status, now)
    if len(cands) < 30:
        try:
            fresh = explore_fetch(2)
        except Exception as e:  # offline or rate limited: rate what we have
            fresh = []
            print(f"explore fetch failed: {e}", file=sys.stderr)
        with data_lock():
            items = load_json(ITEMS, {})
            for it in fresh:
                merge_item(items, it)
            save_json(ITEMS, items)
        cands = unrated(items, status, now)

    weights, names, _, _ = learn(items, status, now)
    impressions = load_json(IMPRESSIONS, {})
    n_rated = sum(1 for st in status.values() if st["rating"] or st["applied"])
    # Explore a lot while the model knows little, less as it learns.
    explore_share = max(0.3, 1.0 - n_rated / 60)
    n_explore = round(n * explore_share)

    explore_pool = [it for it in cands if set(it.get("sources", {})) <= {"explore"}]
    explore_ids = {it["id"] for it in explore_pool}
    exploit_pool = [it for it in cands if it["id"] not in explore_ids]

    # Explore picks: spread across categories and main colors.
    random.shuffle(explore_pool)
    explore_pool.sort(key=lambda it: -min(1.0, math.log10(it.get("favorites", 0) + 1) / 3) + random.random())
    seen_keys, ex, ex_ids = set(), [], set()
    for it in explore_pool:
        key = (it.get("category"), (it.get("colors") or ["?"])[0])
        if key in seen_keys:
            continue
        seen_keys.add(key)
        ex.append(it)
        ex_ids.add(it["id"])
        if len(ex) >= n_explore:
            break
    for it in explore_pool:
        if len(ex) >= n_explore:
            break
        if it["id"] not in ex_ids:
            ex.append(it)
            ex_ids.add(it["id"])

    ranked = [it for _, it in rank(exploit_pool, weights, impressions, n - len(ex))]
    queue = ex + ranked
    if len(queue) < n:  # fill from whatever is left
        q_ids = {it["id"] for it in queue}
        rest = [it for it in cands if it["id"] not in q_ids]
        random.shuffle(rest)
        queue += rest[: n - len(queue)]
    random.shuffle(queue)
    return {"queue": [public(it, {"why": why(it, weights, names)}) for it in queue[:n]],
            "rated": n_rated}


def cmd_event(etype, wid, item_json=None):
    if etype == "skip":     # the UI calls it "skip"; stored as "pass" (no opinion)
        etype = "pass"
    if etype not in ("like", "dislike", "pass", "apply", "unlike", "reset"):
        raise SystemExit(f"unknown event type {etype}")
    with data_lock():
        if item_json:
            items = load_json(ITEMS, {})
            it = json.loads(item_json)
            it.setdefault("added", time.time())
            it.setdefault("sources", {})
            it.pop("why", None)
            merge_item(items, it)
            save_json(ITEMS, items)
        with open(EVENTS, "a") as f:
            f.write(json.dumps({"t": time.time(), "type": etype, "id": wid}) + "\n")
        if etype in ("like", "dislike", "apply"):
            imp = load_json(IMPRESSIONS, {})
            if imp.pop(wid, None) is not None:
                save_json(IMPRESSIONS, imp)
    return {"ok": True}


def cmd_curated(n=48, count_impressions=True):
    now = time.time()
    with data_lock():
        items = load_json(ITEMS, {})
        events = load_events()
        impressions = load_json(IMPRESSIONS, {})
    status = latest_status(events)
    weights, names, _, _ = learn(items, status, now)
    picks = rank(unrated(items, status, now), weights, impressions, n)
    # The first rows are what you actually see; count them as impressions.
    if not count_impressions:
        return [public(it, {"why": why(it, weights, names), "score": round(s, 3)}) for s, it in picks]
    with data_lock():
        imp = load_json(IMPRESSIONS, {})
        for _, it in picks[:12]:
            imp[it["id"]] = imp.get(it["id"], 0) + 1
        save_json(IMPRESSIONS, imp)
    return [public(it, {"why": why(it, weights, names), "score": round(s, 3)}) for s, it in picks]


def cmd_liked():
    now = time.time()
    with data_lock():
        items = load_json(ITEMS, {})
        events = load_events()
    status = latest_status(events)
    rows = [(st["t"], i, st) for i, st in status.items()
            if (st["rating"] == "like" or st["applied"]) and i in items and fits(items[i])
            and items[i].get("sharp") is not False]
    rows.sort(reverse=True)
    return [public(items[i], {"why": "applied" if st["applied"] else "liked"}) for _, i, st in rows]


def cmd_history():
    """Everything you rated or skipped, newest first, with its current rating."""
    with data_lock():
        items = load_json(ITEMS, {})
        events = load_events()
    status = latest_status(events)
    rows = []
    for i, st in status.items():
        if i not in items or not fits(items[i]):
            continue
        if st["rating"] == "like" or st["applied"]:
            r = "like"
        elif st["rating"] == "dislike":
            r = "dislike"
        elif st["pass"]:
            r = "skip"
        else:
            continue
        rows.append((max(st["t"], st["pass"]), i, r))
    rows.sort(reverse=True)
    return [public(items[i], {"rating": r, "why": {"like": "liked", "dislike": "nope", "skip": "skipped"}[r]})
            for _, i, r in rows]


def cmd_check(path, wid):
    """Measure a downloaded wallpaper; remember the verdict for this id."""
    edge, detail = sharpness(path)
    if wid:
        record_sharpness(wid, edge, detail)
    return {"sharp": is_sharp(edge, detail), "edge": round(edge, 1), "detail": round(detail, 2)}


def cmd_blurry():
    """Ids known to be blurry at full size (the picker hides them everywhere)."""
    return sorted(i for i, it in load_json(ITEMS, {}).items() if it.get("sharp") is False)


def precheck(items, status, weights, now, limit):
    """Download and measure the best unchecked candidates (background)."""
    os.makedirs(FULL_CACHE, exist_ok=True)
    impressions = load_json(IMPRESSIONS, {})
    todo = [it for _, it in rank(unrated(items, status, now), weights, impressions, 40, diversify=False)
            if "sharp" not in it and it.get("full")][:limit]
    done = 0
    for it in todo:
        ext = it["full"].rsplit(".", 1)[-1]
        dest = os.path.join(FULL_CACHE, f"{it['id']}.{ext}")
        try:
            if not os.path.exists(dest):
                req = urllib.request.Request(it["full"], headers={"User-Agent": "wallhaven-picker/1.0"})
                with urllib.request.urlopen(req, timeout=60) as r, open(dest + ".part", "wb") as f:
                    f.write(r.read())
                os.replace(dest + ".part", dest)
            edge, detail = sharpness(dest)
            record_sharpness(it["id"], edge, detail)
            if not is_sharp(edge, detail):
                os.remove(dest)          # never needed: it will not be offered
            done += 1
        except Exception:
            for f in (dest, dest + ".part"):
                if os.path.exists(f):
                    os.remove(f)
    # keep the cache small: newest FULL_CACHE_MAX files
    files = sorted((os.path.join(FULL_CACHE, f) for f in os.listdir(FULL_CACHE)), key=os.path.getmtime, reverse=True)
    for f in files[FULL_CACHE_MAX:]:
        os.remove(f)
    return done


def cmd_refresh(budget=20):
    ensure_dir()
    lockf = open(REFRESH_LOCK, "a")
    try:
        fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return {"skipped": "another refresh is running"}

    now = time.time()
    with data_lock():
        items = load_json(ITEMS, {})
        events = load_events()
    status = latest_status(events)
    found, enriched, used = [], [], 0
    log = []

    def spend():
        nonlocal used
        used += 1
        return used <= budget

    try:
        # 1. Tags for rated wallpapers (the model learns from these).
        rated = sorted((st["t"], i) for i, st in status.items()
                       if (st["rating"] or st["applied"]) and i in items and not items[i].get("tags"))
        for _, i in reversed(rated[-8:]):
            if not spend():
                break
            enriched.append(details(i))
        for it in enriched:
            merge_item(items, it)

        weights, names, pos, neg = learn(items, status, now)

        # Categories you clearly dislike are left out of taste searches.
        cats = []
        for name in ("general", "anime", "people"):
            w = weights.get(f"cat:{name}", 0)
            cats.append("0" if (w < -0.5 and neg.get(f"cat:{name}", 0) >= 4) else "1")
        cat_mask = "".join(cats) if "1" in cats else "111"

        # 2. Search your best tags (some randomness so it keeps finding new ones).
        good_tags = sorted(((w, f) for f, w in weights.items() if f.startswith("tag:") and w > 0.15),
                           reverse=True)[:8]
        random.shuffle(good_tags)
        good_tags = sorted(good_tags[:3], reverse=True)
        for w, f in good_tags:
            if not spend():
                break
            tid = f.split(":")[1]
            got = search({"q": f"id:{tid}", "sorting": random.choice(["favorites", "toplist", "relevance"]),
                          "topRange": "1y", "categories": cat_mask, "page": random.randint(1, 3)}, f)
            found += got
            log.append(f"tag {names.get(f, tid)}: {len(got)}")

        # 3. Search your best color.
        good_colors = sorted(((w, f) for f, w in weights.items() if f.startswith("color:") and w > 0.2),
                             reverse=True)[:3]
        if good_colors and spend():
            w, f = random.choice(good_colors)
            hexc = f.split("#")[-1]
            got = search({"colors": hexc, "sorting": "toplist", "topRange": "1y",
                          "categories": cat_mask, "page": random.randint(1, 5)}, f)
            found += got
            log.append(f"color #{hexc}: {len(got)}")

        # 4. Keep exploring.
        n_explore = 2 if len(good_tags) < 2 else 1
        for _ in range(n_explore):
            if not spend():
                break
            got = explore_fetch(1) if random.random() < 0.6 else search({"sorting": "random", "categories": "111"}, "explore")
            found += got
            log.append(f"explore: {len(got)}")

        with data_lock():
            fresh = load_json(ITEMS, {})
            for it in enriched + found:
                merge_item(fresh, it)
            items = fresh
            save_json(ITEMS, items)

        # 5. Tags for the most promising candidates, so scoring sharpens.
        status = latest_status(load_events())
        impressions = load_json(IMPRESSIONS, {})
        top = [it for _, it in rank(unrated(items, status, now), weights, impressions, 30, diversify=False)
               if not it.get("tags")]
        more = []
        for it in top:
            if not spend():
                break
            more.append(details(it["id"]))
        log.append(f"enriched {len(enriched) + len(more)}")
    except RateLimited:
        log.append("rate limited, stopped early")
        more = locals().get("more", [])
    except (urllib.error.URLError, TimeoutError) as e:
        log.append(f"network error: {e}")
        more = locals().get("more", [])

    with data_lock():
        items = load_json(ITEMS, {})
        for it in enriched + found + more:
            merge_item(items, it)
        prune(items, latest_status(load_events()), now)
        save_json(ITEMS, items)
    # Measure the best unchecked candidates at full size (blurry ones are then
    # never offered; sharp ones stay cached for an instant apply).
    try:
        status = latest_status(load_events())
        weights, _, _, _ = learn(items, status, now)
        log.append(f"sharpness checked {precheck(items, status, weights, now, PRECHECK_BUDGET)}")
    except Exception as e:
        log.append(f"sharpness check failed: {e}")
    # The picker watches this file to know new picks are ready.
    save_json(os.path.join(STATE, "last_refresh.json"), {"t": time.time(), "log": log})
    return {"requests": min(used, budget), "log": log, "pool": len(items)}


def prune(items, status, now):
    """Keep every rated item; keep the best and newest unrated candidates."""
    weights, _, _, _ = learn(items, status, now)
    impressions = load_json(IMPRESSIONS, {})
    cands = [it for i, it in items.items()
             if not (status.get(i) and (status[i]["rating"] or status[i]["applied"]))]
    if len(cands) <= POOL_CAP:
        return
    by_score = sorted(cands, key=lambda it: -score(it, weights, impressions))
    by_age = sorted(cands, key=lambda it: -it.get("added", 0))
    keep = {it["id"] for it in by_score[: POOL_CAP - 150]} | {it["id"] for it in by_age[:150]}
    for it in cands:
        if it["id"] not in keep:
            del items[it["id"]]


def cmd_stats():
    now = time.time()
    items = load_json(ITEMS, {})
    status = latest_status(load_events())
    weights, names, pos, neg = learn(items, status, now)
    tags = sorted(((w, names.get(f, f)) for f, w in weights.items() if f.startswith("tag:")), reverse=True)
    return {
        "pool": len(items),
        "rated": sum(1 for st in status.values() if st["rating"] or st["applied"]),
        "liked": sum(1 for st in status.values() if st["rating"] == "like" or st["applied"]),
        "top_tags": [f"{n} {w:+.2f}" for w, n in tags[:10]],
        "bottom_tags": [f"{n} {w:+.2f}" for w, n in tags[-5:]],
        "colors": {f: round(w, 2) for f, w in weights.items() if f.startswith("color:")},
        "categories": {f: round(w, 2) for f, w in weights.items() if f.startswith("cat:")},
    }


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd, args = argv[1], argv[2:]
    if cmd == "session":
        out = cmd_session(int(args[0]) if args else 10)
    elif cmd == "event":
        out = cmd_event(*args[:3])
    elif cmd == "curated":
        out = cmd_curated(int(args[0]) if args else 48, "quiet" not in args[1:])
    elif cmd == "liked":
        out = cmd_liked()
    elif cmd == "history":
        out = cmd_history()
    elif cmd == "check":
        out = cmd_check(args[0], args[1] if len(args) > 1 else "")
    elif cmd == "blurry":
        out = cmd_blurry()
    elif cmd == "screen":
        out = {"width": SCREEN_W, "height": SCREEN_H, "filters": BASE_FILTERS}
    elif cmd == "refresh":
        out = cmd_refresh(int(args[0]) if args else 20)
    elif cmd == "stats":
        out = cmd_stats()
    else:
        print(__doc__)
        return 1
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
