#!/usr/bin/env python3
"""The still sky wallpaper for her KDE look: the desktop's sky (quickshell/Sky.qml) at midday in its
"Day, deeper" colours (her build brief: about #1E3A4C to #2F5568 to #4A7480), clear weather, with the same three
hills and the sun where Sky.qml puts it, so the hills rise behind KDE's bottom panel.

    python3 tools/kde-look/render-sky.py OUTDIR [WxH ...]

No libraries needed (writes PNG with zlib). Same drawing as Sky.qml: the 1440 x 900 picture stretched to the screen,
round things kept round. A light ordered dither keeps the long gradient from banding.
"""
import math
import os
import re
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
SKY_QML = os.path.join(HERE, "..", "..", "files", "system", "usr", "share", "taylor-os", "quickshell", "Sky.qml")

TOP, MID, BOTTOM = "#1E3A4C", "#2F5568", "#4A7480"        # "Day, deeper"
HILLS = ["#5B8A6E", "#3E6A51", "#2A4B39"]                    # Sky.qml's day hills, back to front
SUN, SUN_R = "#FFF6DC", 38
GLOW, GLOW_R, GLOW_A = (255, 240, 200), 130, 0.22
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hills_from_qml():
    """The three hill outlines, read from Sky.qml itself so the two never drift apart: lists of (x, y)."""
    text = open(SKY_QML, encoding="utf-8").read()
    paths = re.findall(r'"(M0,900 L[^"]+ Z)"', text)
    assert len(paths) == 3, "Sky.qml hills not found"
    out = []
    for p in paths:
        pts = [(float(a), float(b)) for a, b in re.findall(r"L(-?[\d.]+),(-?[\d.]+)", p)]
        out.append([q for q in pts if q[1] < 900])      # the top edge only
    return out


def hill_top(edge, x):
    """y of the hill edge at drawing x (linear between the points, as the path draws it)."""
    for (x0, y0), (x1, y1) in zip(edge, edge[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * ((x - x0) / (x1 - x0) if x1 != x0 else 0)
    return edge[-1][1]


def sun_pos():
    # Sky.qml: arcPos(0.5, 520) pushed out of the ring around the dial (cx 930, cy 390, R 320)
    x, y = 140 + 0.5 * 1160, 680 - 520
    cx, cy, R = 930, 390, 320
    dx, dy = x - cx, y - cy
    d = math.hypot(dx, dy)
    if d < R:
        x, y = cx + dx / d * R, cy + dy / d * R
    return round(x), round(y)


def sky_at(v):
    """Sky.qml's gradient: stops at 0, 0.55, 0.8 and 1 (the last two the same colour)."""
    t, m, b = rgb(TOP), rgb(MID), rgb(BOTTOM)
    if v <= 0.55:
        u, a, c = v / 0.55, t, m
    elif v <= 0.8:
        u, a, c = (v - 0.55) / 0.25, m, b
    else:
        return b
    return tuple(a[i] + (c[i] - a[i]) * u for i in range(3))


def render(W, H):
    sx, sy = W / 1440, H / 900
    sr = min(sx, sy)
    edges = hills_from_qml()
    hill_cols = [rgb(h) for h in HILLS]
    # per screen column, each hill's top in screen pixels
    tops = [[hill_top(e, (x + 0.5) / sx) * sy for x in range(W)] for e in edges]
    sunx, suny = sun_pos()
    scx, scy = sunx * sx, suny * sy
    sun_c = rgb(SUN)
    glow_r, sun_r = GLOW_R * sr, SUN_R * sr
    rows = []
    for y in range(H):
        base = sky_at((y + 0.5) / H)
        row = bytearray(1 + 3 * W)
        near_sun = abs(y + 0.5 - scy) <= glow_r + 1
        for x in range(W):
            c = base
            if near_sun:
                d = math.hypot(x + 0.5 - scx, y + 0.5 - scy)
                cov = max(0.0, min(1.0, glow_r + 0.5 - d))
                if cov > 0:
                    a = GLOW_A * cov
                    c = tuple(c[i] + (GLOW[i] - c[i]) * a for i in range(3))
                cov = max(0.0, min(1.0, sun_r + 0.5 - d))
                if cov > 0:
                    c = tuple(c[i] + (sun_c[i] - c[i]) * cov for i in range(3))
            for k in range(3):
                cov = (y + 1) - tops[k][x]          # how much of this pixel is under the hill edge
                if cov > 0:
                    cov = min(1.0, cov)
                    hc = hill_cols[k]
                    c = tuple(c[i] + (hc[i] - c[i]) * cov for i in range(3))
            dth = (BAYER[y & 3][x & 3] + 0.5) / 16 - 0.5
            o = 1 + 3 * x
            row[o] = max(0, min(255, int(c[0] + dth + 0.5)))
            row[o + 1] = max(0, min(255, int(c[1] + dth + 0.5)))
            row[o + 2] = max(0, min(255, int(c[2] + dth + 0.5)))
        rows.append(bytes(row))
    return b"".join(rows)


def png(path, W, H, raw):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    out = sys.argv[1]
    sizes = sys.argv[2:] or ["1920x1080", "2560x1440", "3840x2160", "1280x800"]
    os.makedirs(out, exist_ok=True)
    for s in sizes:
        W, H = (int(v) for v in s.split("x"))
        png(os.path.join(out, "%dx%d.png" % (W, H)), W, H, render(W, H))
        print("wrote", s)
