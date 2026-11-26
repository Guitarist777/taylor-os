# In the virtual PC: does Hyprland's state match? Args like "active=probe_term" "steam_app_999=2" (fullscreen value).
# Exit 0 when every one holds; prints what it saw either way.
import json
import subprocess
import sys

clients = json.loads(subprocess.run(["hyprctl", "-j", "clients"], capture_output=True, text=True).stdout or "[]")
active = json.loads(subprocess.run(["hyprctl", "-j", "activewindow"], capture_output=True, text=True).stdout or "{}")
fs = {c["class"]: c["fullscreen"] for c in clients}
print("SAW active", active.get("class"), "fullscreen", fs)
good = True
for a in sys.argv[1:]:
    k, v = a.split("=", 1)
    if k == "active":
        good = good and active.get("class") == v
    else:
        good = good and str(fs.get(k)) == v
sys.exit(0 if good else 1)
