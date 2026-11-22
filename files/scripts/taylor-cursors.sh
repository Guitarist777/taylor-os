#!/usr/bin/bash
# Her two cursor sets (her design pack, 2026-11-22): White (Windows-style: white with a green outline, the default) and
# Black (Mac-style: black with a white outline), 12 shapes each, drawn as SVG in /usr/share/taylor-os/cursors/<set>/.
# This builds two cursor themes from them when the image is built:
#   /usr/share/icons/TAYLOR-White and /usr/share/icons/TAYLOR-Black, each with
#     hyprcursors/   Hyprland's own format, straight from the SVGs (sharp at any size)
#     cursors/       the classic Xcursor files (24, 32, 48 and 64 px), for apps that read those (games, Steam, XWayland)
# Size 32; hot spots from her pack's README (x y on the 32 px drawing). The diagonal resize the other way round (nesw)
# is her diagonal drawing mirrored. Every common name an app may ask for points at one of her 12 shapes.
set -euo pipefail
SRC=${TAYLOR_CURSOR_SRC:-/usr/share/taylor-os/cursors}
OUT=${TAYLOR_CURSOR_OUT:-/usr/share/icons}      # (both settable, for a try-out outside the image)
command -v hyprcursor-util >/dev/null || { echo "hyprcursor-util missing"; exit 1; }
command -v magick >/dev/null || { echo "magick missing"; exit 1; }
python3 -c 'import PIL' || { echo "python3 PIL missing"; exit 1; }

python3 -I - "$SRC" "$OUT" <<'PY'
import os, struct, subprocess, sys, shutil, tempfile, io
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
# shape: (her file, mirrored?, hot spot x y on 32 px, names apps ask for (the first is the shape's own name))
SHAPES = [
    ("arrow", False, (4, 3), ["left_ptr", "default", "arrow", "top_left_arrow"]),
    ("pointer", False, (4, 3), ["pointer", "hand2", "hand1", "pointing_hand"]),
    ("text", False, (15, 16), ["text", "xterm", "ibeam"]),
    ("busy", False, (16, 16), ["wait", "watch"]),
    ("working", False, (4, 3), ["progress", "left_ptr_watch", "half-busy"]),
    ("notallowed", False, (4, 3), ["not-allowed", "crossed_circle", "forbidden", "no-drop", "circle", "dnd-no-drop"]),
    ("move", False, (16, 16), ["move", "fleur", "all-scroll", "size_all", "dnd-move"]),
    ("grab", False, (15, 15), ["grab", "openhand", "hand"]),
    ("grabbing", False, (15, 15), ["grabbing", "closedhand", "dnd-none"]),
    ("resize", False, (16, 16), ["ew-resize", "col-resize", "sb_h_double_arrow", "h_double_arrow", "e-resize", "w-resize",
                                 "right_side", "left_side", "size_hor", "split_h"]),
    ("resize-vertical", False, (16, 16), ["ns-resize", "row-resize", "sb_v_double_arrow", "v_double_arrow", "n-resize",
                                          "s-resize", "top_side", "bottom_side", "size_ver", "split_v"]),
    ("resize-diagonal", False, (16, 16), ["nwse-resize", "size_fdiag", "bd_double_arrow", "nw-resize", "se-resize",
                                          "top_left_corner", "bottom_right_corner"]),
    ("resize-diagonal", True, (16, 16), ["nesw-resize", "size_bdiag", "fd_double_arrow", "ne-resize", "sw-resize",
                                         "top_right_corner", "bottom_left_corner"]),
]
SIZES = [24, 32, 48, 64]

def svg_text(path, mirror):
    s = open(path, encoding="utf-8").read()
    if not mirror:
        return s
    start = s.index(">", s.index("<svg")) + 1
    end = s.rindex("</svg>")
    return s[:start] + '<g transform="translate(32,0) scale(-1,1)">' + s[start:end] + "</g>" + s[end:]

def render(svg, size):
    out = subprocess.run(["magick", "-background", "none", "-density", str(96 * size / 32 * 4), "svg:-",
                          "-resize", f"{size}x{size}", "png:-"], input=svg.encode(), capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(out)).convert("RGBA")
    if im.size != (size, size):
        c = Image.new("RGBA", (size, size)); c.paste(im, ((size - im.width) // 2, (size - im.height) // 2)); im = c
    return im

def xcursor(images):
    """images: [(size, xhot, yhot, PIL RGBA)] -> Xcursor bytes (ARGB, premultiplied)."""
    n = len(images)
    header = 16
    toc = 12 * n
    chunks, pos = [], header + toc
    entries = []
    for size, xh, yh, im in images:
        px = bytearray()
        for r, g, b, a in (im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()):
            px += struct.pack("<I", (a << 24) | ((r * a // 255) << 16) | ((g * a // 255) << 8) | (b * a // 255))
        ch = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, im.width, im.height, xh, yh, 0) + bytes(px)
        entries.append(struct.pack("<III", 0xFFFD0002, size, pos))
        chunks.append(ch); pos += len(ch)
    return struct.pack("<4sIII", b"Xcur", header, 0x10000, n) + b"".join(entries) + b"".join(chunks)

for kind, title, desc in [("white", "TAYLOR-White", "white with a green outline (Windows-style)"),
                          ("black", "TAYLOR-Black", "black with a white outline (Mac-style)")]:
    dest = f"{OUT}/{title}"
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(f"{dest}/cursors")
    work = tempfile.mkdtemp()
    os.makedirs(f"{work}/hyprcursors")
    with open(f"{work}/manifest.hl", "w") as f:
        f.write(f"name = {title}\ndescription = TAYLOR OS cursors: {desc}\nversion = 1.0\ncursors_directory = hyprcursors\n")
    for fname, mirror, (hx, hy), names in SHAPES:
        svg = svg_text(f"{SRC}/{kind}/{fname}.svg", mirror)
        own = names[0]
        d = f"{work}/hyprcursors/{own}"
        os.makedirs(d)
        open(f"{d}/{own}.svg", "w", encoding="utf-8").write(svg)
        with open(f"{d}/meta.hl", "w") as f:
            f.write(f"resize_algorithm = bilinear\nhotspot_x = {hx / 32:.4f}\nhotspot_y = {hy / 32:.4f}\n")
            for other in names[1:]:
                f.write(f"define_override = {other}\n")
            f.write(f"define_size = 0, {own}.svg\n")
        imgs = [(sz, round(hx * sz / 32), round(hy * sz / 32), render(svg, sz)) for sz in SIZES]
        open(f"{dest}/cursors/{own}", "wb").write(xcursor(imgs))
        for other in names[1:]:
            os.symlink(own, f"{dest}/cursors/{other}")
    subprocess.run(["hyprcursor-util", "--create", work, "--output", work], check=True, capture_output=True)
    built = [p for p in os.listdir(work) if p.startswith("theme_")]
    assert len(built) == 1, built
    shutil.copytree(f"{work}/{built[0]}", dest, dirs_exist_ok=True)
    shutil.rmtree(work)
    with open(f"{dest}/index.theme", "w") as f:
        f.write(f"[Icon Theme]\nName={title}\nComment=TAYLOR OS cursors: {desc}\nInherits=breeze_cursors\n")
    print(f"{title}: {len(os.listdir(dest + '/cursors'))} cursor names, {len(os.listdir(dest + '/hyprcursors'))} shapes")
PY

# the checks: both themes have every shape in both formats
for t in TAYLOR-White TAYLOR-Black; do
    for n in left_ptr pointer text wait progress not-allowed move grab grabbing ew-resize ns-resize nwse-resize nesw-resize default hand2 xterm; do
        test -e "$OUT/$t/cursors/$n" || { echo "$t is missing $n"; exit 1; }
    done
    test -f "$OUT/$t/manifest.hl" && test "$(ls "$OUT/$t/hyprcursors" | wc -l)" -eq 13
done
chmod -R u=rwX,go=rX "$OUT/TAYLOR-White" "$OUT/TAYLOR-Black"
echo "TAYLOR cursors: built"
