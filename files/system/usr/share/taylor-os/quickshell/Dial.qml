// TAYLOR's dial on her desktop, right of centre, with its status line under it (her build brief, "TAYLOR's dial"; her
// "login unlock to desktop" and "app launcher and search" mockups). The login screen draws it into this spot as she
// signs in; from then on it stays here, its three arcs turning slowly. It is part of the background (the Bottom layer):
// every window, the dock and every panel draw over it.
// A click on it opens her launcher (the dial itself shrinks into the search bar: Launcher.qml draws it while the
// launcher is open, so this one steps aside). After she picks something the line says what it is doing
// ("OPENING STEAM.") and the arcs turn faster for a moment. shell.qml decides the line (status).
//
// Thinking (her design tour, part 8): while TAYLOR is thinking the arcs turn faster, the ring glows a little and five
// dots swirl inside the dial; the line says "THINKING." (shell.qml).
//
// Her notifications (her design tour, part 5): nothing pops up. Each one that comes in becomes a green dot that flies
// out and circles the dial, the arcs spin up for a moment, and one quiet line under the status says what it was for
// about four seconds, then fades. A dismissed one's dot falls back into the dial.
//
// Her settings: "Show TAYLOR" off hides all of this (shell.qml); "Status line" off hides the line under her and the
// quiet line. Reduced motion (Theme.still): the arcs stand still, the swirl stands still, dots fade in and out in
// place instead of flying.
import Quickshell
import Quickshell.Wayland
import QtQuick
import "dial_draw.js" as Dial

PanelWindow {
    id: win
    property QtObject theme
    property real arrive2: 1          // the status line fades in with the tray as she arrives
    property string status: "ALL CLEAR."
    property bool showLine: true      // her "Status line" setting
    property bool busy: false         // a moment after she picked something: the arcs turn faster
    property bool thinking: false     // TAYLOR is thinking: faster arcs, dots swirling inside
    property bool stepAside: false    // the launcher is open and draws the dial itself
    property var notes: []            // her notifications (shell.qml): {t, b, st: in | fade | out, t0}
    property int waiting: 0           // how many are waiting (st "in")
    property real kickAt: 0           // when one came in or fell back in: the arcs spin up, the ring glows
    property var whisper: null        // {txt, t0}: the line under the status as one comes in
    signal clicked()

    readonly property var sp: Dial.spot(screen ? screen.width : 1920, screen ? screen.height : 1080)
    readonly property real orbit: sp.r + 36 * sp.k                      // her dots circle at R + 36
    readonly property real ext: Math.ceil(orbit + 6 * sp.k)            // the dots and the outer arcs
    readonly property real below: Math.ceil(150 * sp.k)                // down past the status and its quiet line
    readonly property real side: Math.ceil(66 * sp.k)                  // room for a longer line ("OPENING SETTINGS.")

    anchors { top: true; left: true }
    margins { left: Math.round(sp.x - ext - side); top: Math.round(sp.y - ext) }
    implicitWidth: 2 * (ext + side)
    implicitHeight: ext + below
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "taylor-dial"
    // No input mask: with "mask: Region { item: ring }" the test PC's click never reached the dial (2026-11-19). The
    // window is kept narrow enough to stay clear of the mixer, and nothing else on the desktop under it takes a click.

    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

    readonly property bool still: theme ? theme.still : false
    // thinking eases in and out over 0.4 s (her tour: sm(e / 0.4)); with reduced motion the swirl stands still and fades
    property real tk: thinking ? 1 : 0
    Behavior on tk { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    onThinkingChanged: console.info("taylor-dial: thinking", thinking)
    onStatusChanged: { console.info("taylor-dial: status " + status); art.requestPaint(); }

    property real spin: 0
    property real lastT: Date.now() / 1000
    readonly property real stillAngle: Dial.arcAngle()
    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const x = getContext("2d");
            x.reset();
            const T = Date.now() / 1000, dt = Math.min(0.1, Math.max(0, T - win.lastT));
            win.lastT = T;
            const kk = win.kickAt > 0 ? Math.exp(-(T - win.kickAt) * 2.2) : 0;
            const tk = win.tk, still = win.still;
            if (!still) win.spin += (2.2 * kk + 2.4 * tk + (win.busy ? 0.5 : 0)) * dt;
            if (win.stepAside) return;
            const acc = win.theme.accent, soft = win.theme.soft;
            Dial.setColors(acc, win.theme.text, win.theme.text2);
            const cx = win.ext + win.side, cy = win.ext, k = win.sp.k, R = win.sp.r;
            const rot = still ? win.stillAngle : Dial.arcAngle() + win.spin;
            Dial.draw(x, cx, cy, R, 1, 1, 1, Math.max(0.7 * kk, 0.6 * tk), rot, still ? 0 : T);

            // thinking: five dots swirl inside her dial (her tour's orbit(tx, ty, R * 0.34, 5, T, tk, 2.6, 3.4))
            if (tk > 0.002) {
                const cols = [acc, win.theme.mix(acc, soft, 0.5), soft];
                for (let i = 0; i < 5; i++) {
                    const a = still ? i / 5 * 6.2832 : T * 3.4 + i * (6.2832 / 5) + 0.55 * Math.sin(T * 3.4 * 0.9 + i * 1.3);
                    x.globalAlpha = tk * (still ? 0.9 : 0.6 + 0.4 * Math.sin(T * 3 + i));
                    x.fillStyle = cols[i % 3];
                    const dr = 2.6 * k * (still ? 1 : 0.8 + 0.3 * Math.sin(T * 2 + i * 2));
                    x.beginPath(); x.arc(cx + Math.cos(a) * R * 0.34, cy + Math.sin(a) * R * 0.34, dr, 0, 6.2832); x.fill();
                }
                x.globalAlpha = 1;
            }

            // her dots: one per notification, flying out to circle the dial; a dismissed one falls back in
            let li = 0;
            x.fillStyle = acc;
            for (const n of win.notes) {
                const e = T - n.t0;
                let rad;
                if (n.st === "in" || n.st === "fade") {
                    n.a = still ? li * 0.55 - 1.5708 : T * 0.3 + li * 0.55; li++;
                    rad = (n.st === "in" && !still) ? win.orbit * win.sm(e / 0.6) : win.orbit;
                    n.r = rad;
                    x.globalAlpha = (n.st === "in" && still) ? win.sm(e / 0.6) : 1;
                } else if (n.st === "out") {
                    rad = still ? win.orbit : (n.r === undefined ? win.orbit : n.r) * (1 - win.sm(e / 0.45));
                    x.globalAlpha = still ? 1 - win.sm(e / 0.45) : 1 - win.sm(e / 0.45) * 0.6;
                } else continue;
                if (n.a === undefined) continue;
                x.beginPath(); x.arc(cx + Math.cos(n.a) * rad, cy + Math.sin(n.a) * rad, 3.4 * k, 0, 6.2832); x.fill();
            }
            x.globalAlpha = 1;

            if (!win.showLine) return;
            Dial.words(x, cx, cy + 118 * k, k, win.arrive2, Math.round(11 * k) + "px " + win.theme.sans, win.status);

            // the quiet line as one comes in: fades in, stays about four seconds, fades out
            const wh = win.whisper;
            if (wh && T - wh.t0 < 5.2) {
                const we = T - wh.t0, wa = win.sm(we / 0.35) * (1 - win.sm((we - 4.2) / 0.9));
                x.font = Math.round(12 * k) + "px " + win.theme.sans;
                x.textAlign = "center"; x.textBaseline = "middle";
                let s = wh.txt;
                const maxw = Math.min(300 * k, win.width - 8 * k);
                if (x.measureText(s).width > maxw) {
                    while (s.length > 3 && x.measureText(s + "…").width > maxw) s = s.slice(0, -1);
                    s += "…";
                }
                x.globalAlpha = 0.9 * wa * win.arrive2; x.fillStyle = soft;
                x.fillText(s, cx, cy + 138 * k);
                x.globalAlpha = 1;
            }
        }
    }
    onArrive2Changed: art.requestPaint()
    onStepAsideChanged: art.requestPaint()
    onShowLineChanged: art.requestPaint()
    // Twenty pictures a second while anything moves; with reduced motion and nothing happening, two a second.
    property bool calm: false
    Timer {
        interval: win.calm ? 500 : 50; repeat: true; running: win.visible
        onTriggered: {
            const wh = win.whisper;
            win.calm = win.still && win.tk === 0 && !win.busy && (!wh || Date.now() / 1000 - wh.t0 > 5.2) && !win.notes.some((n) => n.st !== "in");
            art.requestPaint();
        }
    }
    onWhisperChanged: calm = false
    onKickAtChanged: calm = false
    onTkChanged: calm = false

    Item {
        id: ring
        width: 2 * win.ext; height: 2 * win.ext
        x: win.side; y: 0
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (m) => console.info("taylor-dial: pressed at", Math.round(m.x), Math.round(m.y))
            onClicked: (m) => {
                const dx = m.x - width / 2, dy = m.y - height / 2;
                const inside = dx * dx + dy * dy <= win.ext * win.ext;
                console.info("taylor-dial: clicked", Math.round(dx), Math.round(dy), inside ? "inside" : "outside");
                if (inside) win.clicked();
            }
        }
    }
}
