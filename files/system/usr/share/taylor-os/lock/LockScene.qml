// One screen of her lock screen. The drawing is her login screen's own scene engine, loaded from where the login
// screen keeps it (/usr/share/taylor-os/greeter/scene_engine.js): each screen gets its own copy of it, and this file
// only sets where in her scene it starts, runs its clock, and passes on what shell.qml tells it.
//   now:   straight to her login picture (sky, clock, date, dial, name, "Type your password"), out of the dark in 0.5 s.
//   burst: the end of her timeout (her design tour part 9): TAYLOR, swollen in the middle, bursts into specks that
//          fly out, slow, sway and drift upward for 4.5 s (at night some stay as stars) with a barely visible pop
//          ring; meanwhile the sky brightens out of the dark, the big clock and date fade in, the dial draws itself at
//          its usual spot in 1.75 s, then her name and the hint.
// Screens other than her main one show the sky only.
import Quickshell
import QtQuick
import "file:///usr/share/taylor-os/greeter/scene_engine.js" as Eng
import "file:///usr/share/taylor-os/greeter/dial_draw.js" as Dial

Item {
    id: sc
    property bool primary: true
    property string mode: "now"
    property string who: ""
    property real fade: 0
    signal keyTyped(string text)
    signal keyErase()
    signal keyEnter()
    signal keyEscape()

    property bool started: false
    property double startedMs: 0
    property real bt: -0.15        // seconds into the burst (before 0: her swollen dial waits a moment)
    property var specks: []

    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

    // her login picture's sky only: the moment the sky is in and the clock not yet (the opening's waves left out)
    readonly property real skyOnly: 3.69

    function begin() {
        if (width <= 200 || height <= 200) return;
        if (started && Date.now() - startedMs > 1500) { Eng.setSize(width, height); return; }
        started = true;
        startedMs = Date.now();
        Eng.setSize(width, height);
        if (manrope.status === FontLoader.Ready) Eng.setFont(manrope.name);
        Eng.setName(who);
        Eng.spawn();
        if (mode === "burst" || !primary) {
            // Her sky as the hand-off leaves it, every spark already in place: the stars where they rest, the rest
            // gone. Then the scene clock is set back so the sky brightens, the clock, date and dial come in.
            Eng.beginHandoff(0);
            for (let i = 0; i < Eng.P.length; i++) Eng.P[i].dl = -9;
            Eng.waves = function () {};
            Eng.tb = primary ? 1.6 : skyOnly;
            if (primary) makeSpecks();
        } else {
            Eng.skipToLogin();
        }
        console.info("taylor-lock: scene " + width + "x" + height + (primary ? " (main screen)" : " (sky)"));
        art.requestPaint();
    }
    onWidthChanged: begin()
    onHeightChanged: begin()
    onWhoChanged: Eng.setName(who)
    Component.onCompleted: begin()

    // a key during the burst: straight to the lock screen (no dark cover; the burst itself carries on above)
    function ready() { if (mode === "burst" && Eng.tb < 6.8) Eng.tb = 6.8; }
    function letter() { if (!primary) return; ready(); Eng.addChar(); }
    function erase(left) { if (primary) Eng.delChar(left); }
    function clearAll() { if (primary) Eng.clearAll(); }
    function emptyEnter() { if (!primary) return; ready(); Eng.emptyEnter(); }
    function waiting() { if (primary) Eng.waiting(); }
    function accepted() { if (primary) Eng.accepted(); }
    function rejected() { if (primary) Eng.rejected(); }
    function welcomeFor() { return Eng.welcomeFor(); }

    FontLoader {
        id: manrope
        source: "file:///usr/share/fonts/taylor/Manrope-Variable.ttf"
        onStatusChanged: if (status === FontLoader.Ready) Eng.setFont(name)
    }

    // Her burst (design tour part 9, her numbers): 300 specks from the ring, the inner ring, the ticks and the arcs.
    readonly property var cols: ['#4FB386', '#7FD0A8', '#3A9A70', '#A8E3C6', '#2E7F5C', '#E4EEE8']
    function centre() { const k = height / 380; return { x: width / 2, y: 172 * k, k: k }; }
    function makeSpecks() {
        const c = centre(), k = c.k, R = 58 * k, kk = R / 30, s = [];
        for (let i = 0; i < 300; i++) {
            const q = Math.random(), a = Math.random() * 6.2832, f = Math.random();
            const r = q < 0.38 ? R : (q < 0.52 ? R * 0.62 : (q < 0.72 ? R + (6 + Math.random() * 6) * kk : R + 18 * kk));
            s.push({ x: c.x + Math.cos(a) * r, y: c.y + Math.sin(a) * r, dir: a + (Math.random() - 0.5) * 0.9, v: (110 + f * f * 430) * k,
                     kd: 1.15 + Math.random() * 0.5, up: (5 + Math.random() * 15) * k, f: 0.7 + Math.random() * 1.3, ph: Math.random() * 6.28,
                     amp: (4 + Math.random() * 10) * k, life: 0.55 + Math.random() * 0.45, s: (1 + Math.random() * 1.5) * k,
                     c: cols[Math.floor(Math.random() * cols.length)], tw: Math.random() * 6.28 });
        }
        specks = s;
    }
    readonly property bool day: { const h = new Date().getHours(); return h >= 6 && h < 18; }

    function drawBurst(x, T) {
        const c = centre(), k = c.k, u = bt, D = 4.5;
        if (u < 0) {
            // her dial, swollen, in the middle (where Away.qml left it), "STILL THERE?" under it
            const R = 58 * k, puff = 1.08;
            x.save(); x.translate(c.x, c.y); x.scale(puff, puff); x.translate(-c.x, -c.y);
            Dial.draw(x, c.x, c.y, R, 0.75, 1, 1, 0, Dial.arcAngle(), T);
            x.restore();
            return;
        }
        if (u < 0.4) {
            x.strokeStyle = '#A8E3C6'; x.globalAlpha = 0.14 * (1 - sm(u / 0.4)); x.lineWidth = k;
            x.beginPath(); x.arc(c.x, c.y, 58 * k * 1.08 + u * 90 * k, 0, 6.2832, false); x.stroke();
        }
        const H = height;
        for (let n = 0; n < specks.length; n++) {
            const p = specks[n], life = D * p.life;
            if (u > life && day) continue;
            const dist = p.v * (1 - Math.exp(-p.kd * u)) / p.kd, sw = Math.sin(u * p.f + p.ph) * p.amp * sm(u / 1.4);
            const px = p.x + Math.cos(p.dir) * dist + sw, py = p.y + Math.sin(p.dir) * dist - p.up * Math.pow(Math.min(u, life), 1.15);
            let al = sm(u / 0.06) * (1 - sm((u - life * 0.5) / (life * 0.5)));
            al *= 0.7 + 0.3 * Math.sin(u * 3.2 + p.tw);
            if (!day && py < H * 0.6) al = Math.max(al, 0.4 * sm(u / 1.5) * (0.7 + 0.3 * Math.sin(T * 1.3 + p.tw)));
            if (al <= 0.01) continue;
            x.globalAlpha = cl(al); x.fillStyle = p.c; x.beginPath(); x.arc(px, py, p.s, 0, 6.2832, false); x.fill();
        }
        x.globalAlpha = 1;
    }

    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            if (!sc.started) return;
            const x = getContext("2d");
            Eng.draw(x);
            if (sc.mode === "burst" && sc.primary && sc.bt < 6) sc.drawBurst(x, Date.now() / 1000);
            if (sc.fade > 0) Eng.fadeOut(x, sc.fade);
        }
    }

    FrameAnimation {
        running: sc.started
        onTriggered: {
            const dt = Math.min(0.033, Math.max(0, frameTime));
            if (sc.mode === "burst" && sc.primary && sc.bt < 0) {
                sc.bt += dt;          // the swollen dial waits; the scene's clock waits with it
            } else {
                if (sc.mode === "burst" && sc.primary) sc.bt += dt;
                Eng.advance(dt);
                if (!sc.primary) Eng.tb = sc.skyOnly;
            }
            art.requestPaint();
        }
    }

    // Her keys (every screen passes them on; the dots land on the main screen's dial).
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            event.accepted = true;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) sc.keyEnter();
            else if (event.key === Qt.Key_Backspace) sc.keyErase();
            else if (event.key === Qt.Key_Escape) sc.keyEscape();
            else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) sc.keyTyped(event.text);
            else event.accepted = false;
        }
    }
}
