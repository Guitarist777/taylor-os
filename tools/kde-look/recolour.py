#!/usr/bin/env python3
"""Make the TAYLOR look for her KDE backup session from L4ki's Slot Plasma Themes (GPL-3.0).

    python3 tools/kde-look/recolour.py SLOT_CHECKOUT REPO

SLOT_CHECKOUT is https://github.com/L4ki/Slot-Plasma-Themes at the pinned commit below. This writes, under
REPO/files/system/usr/share:
  plasma/desktoptheme/TAYLOR/   Slot-Dark-Plasma with the TAYLOR colours swapped in
  aurorae/themes/TAYLOR/        Slot-Dark-Aurorae-6 (window title bars) with the TAYLOR colours swapped in
each with the author's LICENSE and AUTHORS kept and a CHANGES.txt saying what was changed (GPL-3.0 section 5).
The colour scheme (color-schemes/TAYLOR.colors) is written by hand in the repo; it is copied into the Plasma theme
as its `colors` file so the panel, menus and pop-ups follow the same colours.
Run it again after changing the table; it replaces both folders.
"""
import colorsys
import os
import re
import shutil
import sys

SLOT_COMMIT = "e0f0d69ef253cbc971dd0b1f4315b08a4b7a5ed1"

# Slot's own colours -> the TAYLOR colour table (her build brief: background #0B0D0C, panels #171918,
# windows #121413, text #EDEFEE, muted #9AA19D, accent #4FB386, light green #A8E3C6).
EXACT = {
    "182030": "171918", "1e2431": "1d201e", "1c202f": "1b1e1c", "1d212f": "1b1e1c", "1d2030": "1b1e1c",
    "141622": "121413", "1e2639": "1a1d1b", "1c2436": "1a1d1b", "1a2233": "1a1d1b", "2a3956": "262a28",
    "2a3955": "262a28", "20212b": "1e201f", "3c4f77": "2e3431", "1e2129": "1a1c1b", "2b4254": "26302b",
    "4e5a7e": "3e4743", "2b2f3b": "262927", "3b4f77": "2e3431", "0a0b10": "0b0d0c", "d3dae3": "edefee",
    "6f7c91": "9aa19d", "0495e2": "4fb386", "0099e5": "4fb386", "3daee9": "4fb386", "3daee6": "4fb386",
    "19b6ee": "a8e3c6", "9adbfd": "a8e3c6", "008080": "4fb386", "006a80": "3a8a66", "02334b": "173a2b",
    "035e8b": "2e6e52", "00344d": "173a2b", "05615f": "2e6e52",
}
# Pure colours Plasma themes use for hint shapes that are never drawn: left alone.
KEEP = {"ff00ff", "00ffff", "ffff00", "00ff00", "0000ff", "ff0000"}


def swap(hex6):
    h = hex6.lower()
    if h in EXACT:
        return EXACT[h]
    if h in KEEP:
        return h
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, light, sat = colorsys.rgb_to_hls(r, g, b)
    deg = hue * 360
    if sat < 0.05 or not (170 <= deg <= 290):
        return h                       # greys, reds, oranges, yellows: not Slot's blue, kept
    if light < 0.6 and sat < 0.5:      # Slot's blue-greys -> TAYLOR's green-tinted greys
        nh, ns = 150 / 360, min(sat, 0.07)
    else:                              # Slot's blue and purple accents -> TAYLOR green
        nh, ns = 153 / 360, min(sat, 0.5)
    r, g, b = colorsys.hls_to_rgb(nh, light, ns)
    return "%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


HEX = re.compile(r"#([0-9a-fA-F]{6})\b")


def recolour_svg(path, counts):
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
        text = f.read()

    def rep(m):
        new = swap(m.group(1))
        if new != m.group(1).lower():
            counts[m.group(1).lower() + "->" + new] = counts.get(m.group(1).lower() + "->" + new, 0) + 1
        return "#" + new
    with open(path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
        f.write(HEX.sub(rep, text))


def recolour_tree(root):
    counts = {}
    for d, _, files in os.walk(root):
        for n in files:
            if n.endswith(".svg"):
                recolour_svg(os.path.join(d, n), counts)
    return counts


CHANGES = """TAYLOR {what} for TaylorOS (https://github.com/Guitarist777/taylor-os)

This is a modified version of "{orig}" from Slot Plasma Themes by l4k1
(https://github.com/L4ki/Slot-Plasma-Themes, commit {commit}), licensed under the
GNU General Public License version 3 (see LICENSE, kept as the author shipped it). The modified
version is under the same licence.

Changed on 2026-11-21 by tools/kde-look/recolour.py in the taylor-os repository:
- renamed to TAYLOR (folder, Id and Name in the metadata), the author's credit kept
- the colours swapped for the TAYLOR colour table: Slot's blue-greys for TAYLOR's near-black
  green-greys (#0B0D0C, #121413, #171918), Slot's text colours for #EDEFEE and #9AA19D, Slot's
  blue and purple accents for TAYLOR green (#4FB386, #A8E3C6); the exact swaps are listed below
{extra}
Nothing else was changed: every shape, size and layout is l4k1's.

Colour swaps made (old -> new: how many times):
{table}
"""


def write_changes(dest, what, orig, counts, extra=""):
    table = "\n".join("  #%s: %d" % (k.replace("->", " -> #"), v) for k, v in sorted(counts.items()))
    with open(os.path.join(dest, "CHANGES.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(CHANGES.format(what=what, orig=orig, commit=SLOT_COMMIT, extra=extra, table=table))


def main(slot, repo):
    share = os.path.join(repo, "files", "system", "usr", "share")
    lic = os.path.join(slot, "LICENSE")
    authors = os.path.join(slot, "Slot Plasma Themes", "Slot-Dark-Plasma", "AUTHORS")

    # The Plasma theme (panel, menus, pop-ups, tray)
    src = os.path.join(slot, "Slot Plasma Themes", "Slot-Dark-Plasma")
    dst = os.path.join(share, "plasma", "desktoptheme", "TAYLOR")
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(src, dst)
    counts = recolour_tree(dst)
    shutil.copyfile(os.path.join(share, "color-schemes", "TAYLOR.colors"), os.path.join(dst, "colors"))
    for n in ("metadata.json", "metadata.desktop", "plasmarc"):
        p = os.path.join(dst, n)
        with open(p, encoding="utf-8", newline="") as f:
            t = f.read()
        t = t.replace('"Name": "Slot-Dark-Plasma"', '"Name": "TAYLOR"').replace('"Id": "Slot-Dark-Plasma"', '"Id": "TAYLOR"')
        t = t.replace('"Description": "Slot-Dark-Plasma"', '"Description": "TAYLOR colours on Slot Dark Plasma by l4k1"')
        t = t.replace('"Website": "https://github.com/Slot-Plasma-Themes"', '"Website": "https://github.com/L4ki/Slot-Plasma-Themes"')
        t = t.replace("Name=Slot-Dark-Plasma", "Name=TAYLOR").replace("X-KDE-PluginInfo-Name=Slot-Dark-Plasma", "X-KDE-PluginInfo-Name=TAYLOR")
        t = t.replace("Comment=Slot Dark Plasma Theme by l4k1", "Comment=TAYLOR colours on Slot Dark Plasma by l4k1")
        t = t.replace("defaultWallpaperTheme=Slot Wallpaper", "defaultWallpaperTheme=TAYLOR-Sky")
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(t)
    write_changes(dst, "Plasma theme", "Slot-Dark-Plasma", counts,
                  "- its `colors` file replaced by the TAYLOR colour scheme (color-schemes/TAYLOR.colors)\n"
                  "- plasmarc: the default wallpaper named TAYLOR-Sky (Slot's wallpaper is not shipped)\n")

    # The window title bars (Aurorae)
    src = os.path.join(slot, "Slot Window Decorations", "Slot-Dark-Aurorae-6")
    dst = os.path.join(share, "aurorae", "themes", "TAYLOR")
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(src, dst)
    counts = recolour_tree(dst)
    os.rename(os.path.join(dst, "Slot-Dark-Aurorae-6rc"), os.path.join(dst, "TAYLORrc"))
    rc = os.path.join(dst, "TAYLORrc")
    with open(rc, encoding="utf-8", newline="") as f:
        t = f.read()
    t = t.replace("ActiveTextColor=225, 225, 225", "ActiveTextColor=237,239,238")
    t = t.replace("InactiveTextColor=166, 166, 166\n", "").replace("InactiveTextColor=120,120,120", "InactiveTextColor=154,161,157")
    with open(rc, "w", encoding="utf-8", newline="") as f:
        f.write(t)
    for n in ("metadata.json", "metadata.desktop"):
        p = os.path.join(dst, n)
        with open(p, encoding="utf-8", newline="") as f:
            t = f.read()
        t = t.replace("Slot-Dark-Aurorae-6", "TAYLOR").replace("Slot Dark Window Decorations", "TAYLOR colours on Slot Dark window decorations by l4k1")
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(t)
    shutil.copyfile(lic, os.path.join(dst, "LICENSE"))
    shutil.copyfile(authors, os.path.join(dst, "AUTHORS"))
    write_changes(dst, "window decoration", "Slot-Dark-Aurorae-6", counts,
                  "- Slot-Dark-Aurorae-6rc renamed TAYLORrc; title text #EDEFEE (active) and #9AA19D (inactive),\n"
                  "  and a repeated InactiveTextColor line removed\n")
    print("done")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
