// Her notification list (her design tour, part 5), above the clock at the bottom right. It shows only when she asks:
// a click on the dial or on the green count by the clock. Each waiting notification is one thin line (a green dot, the
// title, then the rest in grey), right-aligned, sorted by length with the shortest nearest the clock; the lines slide in
// one after another. A click on a line dismisses it: it fades in 0.6 seconds and its dot falls back into the dial. A
// click anywhere else closes the list; so does the last line going. Her mockup's lengths are multiplied by u = 1.6, as
// in the launcher (the size at which her mockup's dock and mixer match the real ones).
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property var notes: []            // shell.qml's list: {id, t, b, st: in | fade | out, t0}
    property int rev: 0               // bumped by shell.qml whenever the list changes
    property real o: 0                // 0 shut .. 1 open (shell.qml eases it)
    property bool open: false
    property real above: 0            // how high the tray reaches: the list sits just over it
    signal dismiss(var note)
    signal clickedAway()

    readonly property real u: 1.6
    readonly property real rh: Math.round(22 * u)           // her line height 22, gap 4, widest 250
    readonly property real gap: Math.round(4 * u)
    readonly property real maxw: Math.round(250 * u)
    readonly property real fs: Math.round(12 * u)

    anchors { bottom: true; right: true }
    margins { bottom: Math.round(above + 10); right: 14 }
    implicitWidth: maxw + 16
    implicitHeight: 5 * rh + 4 * gap + 16
    color: "transparent"
    visible: o > 0.001 && rows.length > 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-notes"

    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

    readonly property var rows: { rev; return notes.filter((n) => n.st === "in" || n.st === "fade"); }

    // A click outside the list closes it (Hyprland tells us when she clicks anywhere else).
    HyprlandFocusGrab {
        windows: [win]
        active: win.open && win.visible
        onCleared: win.clickedAway()
    }

    property real lastT: Date.now() / 1000
    property var hits: []
    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const x = getContext("2d");
            x.reset();
            const T = Date.now() / 1000, dt = Math.min(0.1, Math.max(0, T - win.lastT));
            win.lastT = T;
            const fb = "600 " + win.fs + "px " + win.theme.sans, fr = win.fs + "px " + win.theme.sans;
            function fit(s, w) {
                if (x.measureText(s).width <= w) return s;
                while (s.length > 3 && x.measureText(s + "…").width > w) s = s.slice(0, -1);
                return s + "…";
            }
            const l = win.rows.slice();
            for (const n of l) {
                x.font = fb; n.tt = fit(n.t, 110 * win.u); n.w1 = x.measureText(n.tt).width;
                x.font = fr; n.bt = fit(n.b, win.maxw - n.w1 - 44 * win.u); n.w2 = x.measureText(n.bt).width;
                n.nat = n.w1 + n.w2 + 40 * win.u;
            }
            l.sort((p, r) => p.nat - r.nat || r.id - p.id);    // shortest nearest the clock
            const right = width - 8, base = height - 8, rh = win.rh, hits = [];
            x.textBaseline = "middle";
            for (let q = 0; q < l.length; q++) {
                const n = l[q];
                const wantY = base - (q + 1) * rh - q * win.gap;
                if (n.ry === undefined) n.ry = wantY;
                n.ry += (wantY - n.ry) * Math.min(1, dt * 8);
                const pe = win.sm(win.cl(win.o * 1.6 - q * 0.15));
                const fa = n.st === "fade" ? 1 - win.sm((T - n.t0) / 0.6) : 1;
                const al = pe * fa, rx = right - n.nat + (1 - pe) * 12 * win.u;
                if (al <= 0.003) continue;
                const r = rh / 2;
                x.globalAlpha = 0.62 * al; x.fillStyle = "#0B0D0C";
                x.beginPath(); x.moveTo(rx + r, n.ry); x.arcTo(rx + n.nat, n.ry, rx + n.nat, n.ry + rh, r);
                x.arcTo(rx + n.nat, n.ry + rh, rx, n.ry + rh, r); x.arcTo(rx, n.ry + rh, rx, n.ry, r);
                x.arcTo(rx, n.ry, rx + n.nat, n.ry, r); x.closePath(); x.fill();
                x.globalAlpha = al; x.fillStyle = win.theme.accent;
                x.beginPath(); x.arc(rx + 11 * win.u, n.ry + r, 2.6 * win.u, 0, 6.2832); x.fill();
                x.textAlign = "left";
                x.globalAlpha = 0.97 * al; x.fillStyle = win.theme.text; x.font = fb;
                x.fillText(n.tt, rx + 20 * win.u, n.ry + r + 0.5);
                x.globalAlpha = 0.9 * al; x.fillStyle = "#B9C0BC"; x.font = fr;
                x.fillText(n.bt, rx + 20 * win.u + n.w1 + 8 * win.u, n.ry + r + 0.5);
                if (n.st === "in") hits.push({ x: rx, y: n.ry, w: n.nat, h: rh, n: n });
            }
            x.globalAlpha = 1;
            win.hits = hits;
        }
    }
    // sixty pictures a second, only while the list is on screen
    Timer { interval: 16; repeat: true; running: win.visible; onTriggered: art.requestPaint() }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        function at(px, py) {
            for (const b of win.hits) if (px >= b.x && px <= b.x + b.w && py >= b.y - 2 && py <= b.y + b.h + 2) return b.n;
            return null;
        }
        cursorShape: at(mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (m) => {
            const n = at(m.x, m.y);
            if (n) { console.info("taylor-notes: one dismissed from the list"); win.dismiss(n); }
            else win.clickedAway();
        }
    }
}
