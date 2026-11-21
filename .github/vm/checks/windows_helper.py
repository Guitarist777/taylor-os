import json, os, re, subprocess, sys
# Runs inside the virtual PC (sent there by windows.sh): reads Hyprland's real state and exits 0 when the claim holds.
def hj(*a):
    return json.loads(subprocess.run(["hyprctl", "-j", *a], capture_output=True, text=True).stdout or "null")
m = hj("monitors")[0]
sc = m.get("scale") or 1
X, Y, W, H = m["x"], m["y"], round(m["width"] / sc), round(m["height"] / sc)
hw, hh = W // 2, H // 2
Z = {"L": (X, Y, hw, H), "R": (X + hw, Y, W - hw, H), "F": (X, Y, W, H), "TL": (X, Y, hw, hh), "TR": (X + hw, Y, W - hw, hh),
     "BL": (X, Y + hh, hw, H - hh), "BR": (X + hw, Y + hh, W - hw, H - hh)}
def rect(c): return (c["at"][0], c["at"][1], c["size"][0], c["size"][1])
def mine():
    ws = m["activeWorkspace"]["id"]
    return [c for c in hj("clients") if c.get("mapped") and not c.get("hidden") and c["workspace"]["id"] == ws]
def layers(full=False):
    out = []
    def walk(o):
        if isinstance(o, dict):
            if "namespace" in o: out.append(o if full else o["namespace"])
            for v in o.values(): walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(hj("layers")); return out
cmd = sys.argv[1]
if cmd == "quarters":
    got = sorted(rect(c) for c in mine())
    want = sorted(Z[k] for k in ("TL", "TR", "BL", "BR"))
    print("info: screen", W, H, "windows", got)
    # the four tile the screen exactly: same rectangles, so no gap and no overlap, edges at 0, W/2, W and 0, H/2, H
    sys.exit(0 if got == want else 1)
elif cmd == "active":
    a = hj("activewindow"); r = rect(a)
    print("info: active", r, "fullscreen", a.get("fullscreen"), "floating", a.get("floating"), "want", Z.get(sys.argv[2]))
    sys.exit(0 if r == Z[sys.argv[2]] else 1)
elif cmd == "fullscreen":
    a = hj("activewindow"); print("info: fullscreen", a.get("fullscreen")); sys.exit(0 if (a.get("fullscreen") or 0) >= 2 else 1)
elif cmd == "layer":
    ns = layers(); print("info: layers", ns)
    there = sys.argv[2] in ns
    sys.exit(0 if there == (sys.argv[3] == "present") else 1)
elif cmd == "floating":
    a = hj("activewindow"); r = rect(a)
    print("info: active", r)
    sys.exit(0 if a.get("floating") and r not in Z.values() else 1)
elif cmd == "dockxy":
    # the dock's second button (Files): the pill has 8 px of padding, 48 px buttons 4 px apart
    d = [o for o in layers(True) if o["namespace"] == "taylor-dock"][0]
    print("DOCKXY", d["x"] + 8 + 48 + 4 + 24, d["y"] + 28)
elif cmd == "maxed":
    cs = [c for c in hj("clients") if re.search(sys.argv[2], c.get("class") or "", re.I)]
    for c in cs: print("info: maxed?", c.get("class"), rect(c), "fullscreen", c.get("fullscreen"))
    sys.exit(0 if cs and all(c.get("fullscreen") == 1 and rect(c)[1] >= Y + 60 for c in cs) else 1)
elif cmd == "settings":
    # change her settings file in place (as the Settings window does), e.g. settings reduceMotion=true scheme=night
    p = os.path.expanduser("~/.config/taylor-os/settings.json")
    d = json.load(open(p))
    for kv in sys.argv[2:]:
        k, v = kv.split("=", 1)
        d[k] = {"true": True, "false": False}.get(v, v)
    with open(p, "r+") as f:
        f.seek(0); f.write(json.dumps(d, indent=4)); f.truncate()
    print("info: settings", {k: d[k] for k in ("scheme", "reduceMotion")})
elif cmd == "anim":
    a = hj("animations")
    a = a[0] if a and isinstance(a[0], list) else a
    got = [x for x in a if x.get("name") == sys.argv[2]]
    print("info: animation", got)
    sys.exit(0 if got and got[0].get("style", "").startswith(sys.argv[3]) else 1)
elif cmd == "info":
    print("info: screen", X, Y, W, H)
    for c in hj("clients"): print("info: client", c.get("class"), rect(c), "ws", c["workspace"]["id"], "fs", c.get("fullscreen"), "fl", c.get("floating"))
    print("info: layers", layers())
