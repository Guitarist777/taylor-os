// Shutdown (her build brief, phase 7; her design tour part 15, her numbers): the desktop fades, the sky turns to night,
// her status reads GOODNIGHT., the arcs retract, the ring un-draws in 1.75 s to one dot, and the dot bursts into
// shooting stars that settle as small stars before everything goes dark. About six seconds, then the PC powers off
// the normal way (systemctl poweroff: programs are asked to close; nothing is killed beyond what that does).
// Restart plays the same, then restarts.
//
// Started by "quickshell ipc call power shutdown" (or restart): the launcher, Settings, and the power key (Hyprland
// binds it; while her desktop runs, it holds logind's power-key handling so the key plays this instead of cutting the
// power at once; if the desktop is not running the key does what it always did).
// Tests only: TAYLOR_POWER_DRY=1 plays it but does not power off.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "dial_draw.js" as Dial

Scope {
    id: gn
    property var mainScreen: null
    property QtObject theme
    property string action: ""          // "" | poweroff | reboot
    property real t: 0
    readonly property bool on: action !== ""
    readonly property real total: Theme.still ? 2.2 : 6.2
    readonly property bool dry: Quickshell.env("TAYLOR_POWER_DRY") === "1"

    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

    function begin(what) {
        if (on) return;
        t = 0;
        action = what;
        console.info("taylor-power: goodnight, then " + what + (dry ? " (dry run)" : ""));
    }

    IpcHandler {
        target: "power"
        function shutdown(): void { gn.begin("poweroff"); }
        function restart(): void { gn.begin("reboot"); }
        function state(): string { return gn.action === "" ? "idle" : gn.action + " t=" + gn.t.toFixed(1); }
    }

    // While her desktop runs, the power key plays the goodnight (Hyprland binds XF86PowerOff to it). If this process
    // ends, the hold ends with it and logind handles the key again.
    Process {
        running: true
        command: ["systemd-inhibit", "--what=handle-power-key", "--who=TAYLOR", "--why=The power key plays her goodnight first", "--mode=block", "sleep", "infinity"]
    }

    Process { id: off }
    FrameAnimation {
        running: gn.on
        onTriggered: {
            const was = gn.t;
            gn.t += Math.min(0.1, Math.max(0, frameTime));
            if (was < gn.total && gn.t >= gn.total) {
                console.info("taylor-power: " + gn.action + " now");
                if (!gn.dry) { off.command = ["systemctl", gn.action]; off.running = true; }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: per
                required property var modelData
                readonly property bool main: modelData === gn.mainScreen
                LazyLoader {
                    active: gn.on
                    PanelWindow {
                        id: gw
                        screen: per.modelData
                        anchors { top: true; bottom: true; left: true; right: true }
                        color: "transparent"
                        exclusionMode: ExclusionMode.Ignore
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.namespace: "taylor-goodnight"
                        WlrLayershell.keyboardFocus: per.main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                        // her night sky (her login's), her 170 stars and 46 shooting stars, made for this screen
                        property var stars: []
                        property var shoot: []
                        function make() {
                            if (width <= 200 || height <= 200) return;
                            const W = width, H = height, k = H / 380, sp = Dial.spot(W, H), s = [], S = [];
                            for (let i = 0; i < 170; i++)
                                s.push({ x: Math.random() * W, y: (8 + Math.pow(Math.random(), 1.3) * 380 * 0.68) * k, r: (0.45 + Math.random() * 0.95) * k,
                                         ph: Math.random() * 6.28, tw: 0.6 + Math.random() * 1.6 });
                            const ox = sp.x, oy = sp.y - sp.r;
                            for (let j = 0; j < 46; j++) {
                                const a = Math.random() * 6.2832, far = Math.max(W, H) * (0.35 + Math.random() * 0.75);
                                S.push({ ex: ox + Math.cos(a) * far, ey: oy + Math.sin(a) * far * 0.62, dl: Math.random() * 0.35, dur: 0.75 + Math.random() * 0.7,
                                         r: (0.8 + Math.random() * 1.1) * k, green: Math.random() < 0.4, ph: Math.random() * 6.28, tw: 0.8 + Math.random() * 1.6,
                                         bend: (Math.random() - 0.5) * 50 * k });
                            }
                            stars = s; shoot = S;
                        }
                        onWidthChanged: make()
                        onHeightChanged: make()
                        Component.onCompleted: make()

                        Canvas {
                            id: art
                            anchors.fill: parent
                            renderStrategy: Canvas.Cooperative
                            onPaint: {
                                const x = getContext("2d");
                                x.reset();
                                const W = width, H = height, k = H / 380, T = Date.now() / 1000, th = gn.theme;
                                const t = gn.t, sm = gn.sm, cl = gn.cl;
                                if (Theme.still) {
                                    // less motion: one plain fade to dark
                                    x.globalAlpha = sm(t / 1.8); x.fillStyle = "#000000"; x.fillRect(0, 0, W, H);
                                    return;
                                }
                                // the desktop fades and the sky turns to night; then everything goes dark
                                const night = sm((t - 0.5) / 2.0), dark = sm((t - 4.3) / 1.7), sk = 1 - dark;
                                x.globalAlpha = night;
                                const gr = x.createLinearGradient(0, 0, 0, H);
                                gr.addColorStop(0, '#090B0E'); gr.addColorStop(0.7, '#0E1716'); gr.addColorStop(1, '#14261F');
                                x.fillStyle = gr; x.fillRect(0, 0, W, H);
                                x.globalAlpha = 0.9 * night * sk; x.fillStyle = '#DDE8E2'; x.beginPath(); x.arc(W * 0.17, 70 * k, 15 * k, 0, 6.2832, false); x.fill();
                                x.fillStyle = '#0A0D0F'; x.beginPath(); x.arc(W * 0.17 + 7 * k, 66 * k, 14 * k, 0, 6.2832, false); x.fill();
                                const st = gw.stars;
                                for (let i = 0; i < st.length; i++) {
                                    const s = st[i];
                                    x.globalAlpha = (0.55 + 0.4 * Math.sin(T * s.tw + s.ph)) * night * sk;
                                    x.fillStyle = th.star; x.beginPath(); x.arc(s.x, s.y, s.r, 0, 6.2832, false); x.fill();
                                }
                                x.globalAlpha = night * sk;
                                x.fillStyle = '#0E1512'; x.beginPath(); x.moveTo(0, H);
                                for (let u = 0; u <= W + 10 * k; u += 10 * k) { const uu = u / k; x.lineTo(u, (338 + Math.sin(uu * 0.008 + 1.2) * 14 + Math.sin(uu * 0.021) * 6) * k); }
                                x.lineTo(W, H); x.closePath(); x.fill();
                                x.fillStyle = '#080B0A'; x.beginPath(); x.moveTo(0, H);
                                for (let v = 0; v <= W + 10 * k; v += 10 * k) { const vv = v / k; x.lineTo(v, (356 + Math.sin(vv * 0.006 + 3.1) * 12 + Math.sin(vv * 0.017 + 0.6) * 5) * k); }
                                x.lineTo(W, H); x.closePath(); x.fill();
                                if (per.main && Prefs.showTaylor) {
                                    Dial.setColors(th.accent, th.text, th.text2);
                                    const sp = Dial.spot(W, H), BURST = 2.85;
                                    // the arcs retract, the ring un-draws to one dot (1.75 s)
                                    const pr = 1 - sm((t - 1.0) / 1.75), ab = 1 - sm((t - 0.8) / 0.7);
                                    if (pr > 0) Dial.draw(x, sp.x, sp.y, sp.r, 1, pr, ab, 0, Dial.arcAngle(), T);
                                    const la = t < 0.9 ? 1 - sm((t - 0.5) / 0.4) : sm((t - 0.9) / 0.5) * (1 - sm((t - 2.5) / 0.5));
                                    Dial.words(x, sp.x, sp.y + 118 * k, k, la, Math.round(11 * k) + "px " + th.sans, t < 0.9 ? "ALL CLEAR." : "GOODNIGHT.");
                                    const ox = sp.x, oy = sp.y - sp.r;
                                    if (t > 1.0 && t < BURST) {
                                        const ch = sm((t - (BURST - 0.5)) / 0.5);
                                        x.globalAlpha = 0.18 * ch; x.fillStyle = th.soft; x.beginPath(); x.arc(ox, oy, (9 * ch + 3) * k, 0, 6.2832, false); x.fill();
                                        x.globalAlpha = 1; x.fillStyle = th.accent; x.beginPath(); x.arc(ox, oy, (2.6 + 1.6 * ch) * k, 0, 6.2832, false); x.fill();
                                    }
                                    if (t >= BURST) {
                                        // the dot bursts into shooting stars that settle as small stars
                                        const e = t - BURST, fl = cl(e / 0.5);
                                        if (fl < 1) { x.globalAlpha = 0.7 * (1 - fl) * sk; x.strokeStyle = th.star; x.lineWidth = (2 * (1 - fl) + 0.5) * k; x.beginPath(); x.arc(ox, oy, (6 + fl * 70) * k, 0, 6.2832, false); x.stroke(); }
                                        x.lineCap = 'round';
                                        const S = gw.shoot;
                                        for (let i = 0; i < S.length; i++) {
                                            const p = S[i], v = cl((e - p.dl) / p.dur);
                                            if (e < p.dl) continue;
                                            const u = 1 - (1 - v) * (1 - v), px = ox + (p.ex - ox) * u, py = oy + (p.ey - oy) * u + Math.sin(u * 3.1416) * p.bend * 0.3 + u * u * 18 * k;
                                            if (v < 1) {
                                                const ub = Math.max(0, u - 0.16 * (1 - v) - 0.03), bx = ox + (p.ex - ox) * ub, by = oy + (p.ey - oy) * ub + Math.sin(ub * 3.1416) * p.bend * 0.3 + ub * ub * 18 * k;
                                                x.globalAlpha = 0.55 * (1 - v) * sk; x.strokeStyle = p.green ? th.soft : th.star; x.lineWidth = p.r * 1.3;
                                                x.beginPath(); x.moveTo(bx, by); x.lineTo(px, py); x.stroke();
                                                x.globalAlpha = sk; x.fillStyle = p.green ? th.soft : '#FFFFFF'; x.beginPath(); x.arc(px, py, p.r * 1.25, 0, 6.2832, false); x.fill();
                                            } else {
                                                x.globalAlpha = (0.5 + 0.4 * Math.sin(T * p.tw + p.ph)) * sk; x.fillStyle = th.star; x.beginPath(); x.arc(px, py, p.r * 0.8, 0, 6.2832, false); x.fill();
                                            }
                                        }
                                    }
                                }
                                if (dark > 0) { x.globalAlpha = dark; x.fillStyle = "#000000"; x.fillRect(0, 0, W, H); }
                                x.globalAlpha = 1;
                            }
                        }
                        FrameAnimation { running: gn.on; onTriggered: art.requestPaint() }
                        MouseArea { anchors.fill: parent }          // nothing under it takes a click any more
                        Item { anchors.fill: parent; focus: true; Keys.onPressed: (event) => { event.accepted = true; } }
                    }
                }
            }
        }
    }
}
