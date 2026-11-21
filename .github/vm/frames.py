#!/usr/bin/env python3
"""Sort a run of screenshots (in time order) into what the screen showed, for the boot check (2026-11-21).

    frames.py boot FILE...     firmware -> her dark -> her opening: after the first frame of her dark, no black frame
                               and no text until her opening's green sparks appear
    frames.py signin FILE...   her login -> her desktop: no black frame and no text on the way
    frames.py dark FILE...     every frame is her dark with nothing on it (her boot screen)

Each frame is one of:
    black    almost all pure black (#000000): the firmware, or the PC's own text screen
    dark     almost all her dark (#0B0D0C, or the #0F1010 her login fades to), nothing on it
    text     mostly black or dark, with a little grey/white on it (letters on a text screen)
    opening  her green sparks on her dark (the opening / login scene)
    other    anything else (a firmware logo, her desktop's sky, ...)
Prints one line per frame and PASS / FAIL lines for the check.
"""
import sys
from PIL import Image

DARKS = [(11, 13, 12), (15, 16, 16)]


def near(p, c, d=4):
    return abs(p[0] - c[0]) <= d and abs(p[1] - c[1]) <= d and abs(p[2] - c[2]) <= d


def classify(path):
    im = Image.open(path).convert("RGB")
    im = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
    px = list(im.getdata())
    n = len(px)
    black = sum(1 for p in px if max(p) <= 3)
    dark = sum(1 for p in px if near(p, DARKS[0]) or near(p, DARKS[1]))
    grey = sum(1 for p in px if min(p) > 90 and max(p) - min(p) < 25)
    green = sum(1 for p in px if p[1] > 80 and p[1] > p[0] + 25 and p[1] > p[2] + 10)
    if black > 0.97 * n:
        kind = "text" if grey > 20 else "black"
    elif dark > 0.97 * n and green < 5:
        kind = "text" if grey > 20 else "dark"
    elif dark + black > 0.9 * n and green >= 5:
        kind = "opening"
    elif black + dark > 0.9 * n and grey > 20:
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
        if "black" in between:
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
        if "black" in kinds:
            print("FAIL no black screen between her login and her desktop")
        else:
            print("PASS no black screen between her login and her desktop")
        if "text" in kinds:
            print("FAIL no text on screen between her login and her desktop")
        else:
            print("PASS no text on screen between her login and her desktop")


if __name__ == "__main__":
    main()
