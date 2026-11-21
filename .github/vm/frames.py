#!/usr/bin/env python3
"""Sort a run of screenshots (in time order) into what the screen showed, for the boot check (2026-11-21).

    frames.py boot FILE...     firmware -> her dark -> her opening: after the first frame of her dark, no black frame
                               and no text until her opening's green sparks appear
    frames.py signin FILE...   her login -> her desktop: no black frame and no text on the way
    frames.py dark FILE...     every frame is her dark with nothing on it (her boot screen)

Each frame is one of:
    black    almost all pure black (#000000): the firmware, or the PC's own text screen
    off      the virtual PC's "Display output is not active" (the picture switched off for a moment; counts as black)
    dark     almost all her dark (#0B0D0C, or the #0F1010 her login fades to), nothing on it
    text     mostly black or dark, with grey/white on it (letters on a text screen; more than a mouse pointer)
    opening  her green sparks on her dark (the opening / login scene)
    other    anything else (a firmware logo, her desktop's sky, a window on her desktop, ...)
Prints one line per frame and PASS / FAIL lines for the check.
"""
import sys
from PIL import Image

DARKS = [(11, 13, 12), (15, 16, 16)]


def near(p, c, d=4):
    return abs(p[0] - c[0]) <= d and abs(p[1] - c[1]) <= d and abs(p[2] - c[2]) <= d


def window(im, px):
    """A window on her desktop (one solid light box, e.g. Steam's first-run note), not lines of text: the light pixels
    sit in one small box and fill much of it."""
    pts = [(i % im.width, i // im.width) for i, p in enumerate(px) if min(p) > 90 and max(p) - min(p) < 25]
    if not pts:
        return False
    xs = [x for x, _ in pts]
    ys = [y for _, y in pts]
    box = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1)
    return box < 0.2 * im.width * im.height and len(pts) > 0.3 * box


def classify(path):
    im = Image.open(path).convert("RGB")
    im = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
    px = list(im.get_flattened_data()) if hasattr(im, "get_flattened_data") else list(im.getdata())
    n = len(px)
    black = sum(1 for p in px if max(p) <= 3)
    dark = sum(1 for p in px if near(p, DARKS[0]) or near(p, DARKS[1]))
    grey = sum(1 for p in px if min(p) > 90 and max(p) - min(p) < 25)
    green = sum(1 for p in px if p[1] > 80 and p[1] > p[0] + 25 and p[1] > p[2] + 10)
    if black > 0.97 * n:
        kind = "text" if grey > 150 else "black"
        if kind == "text" and grey < 600:
            # QEMU's own "Display output is not active." in the middle: the PC switched its picture off for a moment
            rows = [i // im.width for i, p in enumerate(px) if min(p) > 90 and max(p) - min(p) < 25]
            if rows and min(rows) > 0.4 * im.height and max(rows) < 0.6 * im.height:
                kind = "off"
    elif dark > 0.97 * n and green < 5:
        kind = "text" if grey > 150 else "dark"
    elif dark + black > 0.9 * n and grey > 150 and window(im, px):
        kind = "other"
    elif dark + black > 0.9 * n and green >= 5:
        # lines of start-up text (white, with green [ OK ]s) are text; her opening is green sparks with little white
        kind = "text" if grey > 3000 else "opening"
    elif black + dark > 0.9 * n and grey > 150:
        kind = "text"
    else:
        kind = "other"
    return kind, dict(black=round(black / n, 3), dark=round(dark / n, 3), grey=grey, green=green)


def main():
    mode, files = sys.argv[1], sys.argv[2:]
    kinds = []
    for f in files:
        k, info = classify(f)
        kinds.append(k)
        print(f"{f.split('/')[-1]}: {k} {info}")
    seq = " ".join(kinds)
    print("SEQUENCE", seq)
    if mode == "boot":
        if "dark" not in kinds:
            print("FAIL the boot screen shows her dark")
            return
        print("PASS the boot screen shows her dark")
        first = kinds.index("dark")
        op = kinds.index("opening", first) if "opening" in kinds[first:] else -1
        if op < 0:
            print("FAIL her opening follows the boot screen")
            return
        print("PASS her opening follows the boot screen")
        between = kinds[first:op]
        if "black" in between or "off" in between:
            print("FAIL no black screen between the boot screen and her opening")
        else:
            print("PASS no black screen between the boot screen and her opening")
        if "text" in between or "other" in between:
            print("FAIL no text screen between the boot screen and her opening")
        else:
            print("PASS no text screen between the boot screen and her opening")
    elif mode == "dark":
        if kinds and all(k == "dark" for k in kinds):
            print("PASS her boot screen is her dark with nothing on it")
        else:
            print("FAIL her boot screen is her dark with nothing on it")
    elif mode == "signin":
        # from her login to the first picture of her desktop (after it, her desktop's own windows are not this check's)
        start = kinds.index("dark") if "dark" in kinds else 0
        end = start
        while end < len(kinds) and kinds[end] in ("dark", "black", "off", "text"):
            end += 1
        kinds = kinds[:end]
        print("WINDOW", start + 1, "to", end)
        if "black" in kinds or "off" in kinds:
            print("FAIL no black screen between her login and her desktop")
        else:
            print("PASS no black screen between her login and her desktop")
        if "text" in kinds:
            print("FAIL no text on screen between her login and her desktop")
        else:
            print("PASS no text on screen between her login and her desktop")


if __name__ == "__main__":
    main()
