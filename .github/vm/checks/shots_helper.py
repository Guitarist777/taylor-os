# In the virtual PC, for the screenshot checks: where things are.
#   layer  -> "SHOT x y w h" (the little picture, Shot.qml) or "SHOT none"
#   drop   -> "DROP cx cy" (the middle of the drop-target test window) or "DROP none"
#   droptarget -> writes the drop-target test window's QML to /tmp/droptest/shell.qml
import json
import os
import subprocess
import sys


def hj(what):
    return json.loads(subprocess.run(["hyprctl", "-j", what], capture_output=True, text=True).stdout or "{}")


a = sys.argv[1]
if a == "layer":
    found = None
    for mon in hj("layers").values():
        for lv in mon.get("levels", {}).values():
            for l in lv:
                if l.get("namespace") == "taylor-shot":
                    found = l
    print("SHOT", *([found[k] for k in ("x", "y", "w", "h")] if found else ["none"]))
elif a == "drop":
    c = [c for c in hj("clients") if c.get("title") == "droptest"]
    print("DROP", *([c[0]["at"][0] + c[0]["size"][0] // 2, c[0]["at"][1] + c[0]["size"][1] // 2] if c else ["none"]))
elif a == "droptarget":
    os.makedirs("/tmp/droptest", exist_ok=True)
    open("/tmp/droptest/shell.qml", "w").write('''import Quickshell
import QtQuick
FloatingWindow {
    title: "droptest"
    implicitWidth: 500; implicitHeight: 400
    color: "#203040"
    Text { anchors.centerIn: parent; text: "drop here"; color: "white"; font.pixelSize: 30 }
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            drop.acceptProposedAction();
            Quickshell.execDetached(["sh", "-c", "printf '%s\\\\n' \\"$1\\" > /tmp/drop.txt", "sh",
                                     "URLS " + drop.urls.join(" ") + " TYPES " + drop.formats.join(",")]);
        }
    }
}
''')
    print("droptarget written")
