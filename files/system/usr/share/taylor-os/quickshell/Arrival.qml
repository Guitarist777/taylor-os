// Her arrival on the desktop, the last part of her "login unlock to desktop" mockup. The login screen ended on her
// night sky with the desktop dial drawn right of centre; this starts from that same picture (out of the dark the
// login faded to), then lets it go so her real sky shows, while the dock, clock card, mixer and tray come in
// (shell.qml moves them). Once per sign-in, about three seconds, then it is gone. It takes no keys and no clicks.
import Quickshell
import Quickshell.Wayland
import QtQuick
import "dial_draw.js" as Dial

PanelWindow {
    id: win
    property real at: 0               // seconds into the arrival (shell.qml's clock)

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-arrival"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

    // her 210 stars, made once for this screen
    property var stars: []
    function makeStars() {
        const s = [], H = height, k = H / 380;
        for (let i = 0; i < 210; i++)
            s.push({ x: Math.random() * width, y: (8 + Math.pow(Math.random(), 1.3) * 380 * 0.68) * k, r: (0.45 + Math.random() * 0.95) * k,
                     ph: Math.random() * 6.28, tw: 0.6 + Math.random() * 1.6 });
        stars = s;
    }
    onWidthChanged: if (width > 200 && height > 200) makeStars()
    onHeightChanged: if (width > 200 && height > 200) makeStars()

    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const x = getContext("2d");
            x.reset();
            const W = width, H = height, k = H / 380, T = Date.now() / 1000;
            const veil = 1 - win.sm((win.at - 0.9) / 1.0);      // her login night lets go of the screen
            const dark = 1 - win.sm(win.at / 0.5);              // out of the dark the login faded to
            if (veil > 0) {
                x.globalAlpha = veil;
                const gr = x.createLinearGradient(0, 0, 0, H);
                gr.addColorStop(0, '#090B0E'); gr.addColorStop(0.7, '#0E1716'); gr.addColorStop(1, '#14261F');
                x.fillStyle = gr; x.fillRect(0, 0, W, H);
                x.globalAlpha = 0.9 * veil; x.fillStyle = '#DDE8E2'; x.beginPath(); x.arc(W * 0.17, 70 * k, 15 * k, 0, 6.2832, false); x.fill();
                x.fillStyle = '#0A0D0F'; x.beginPath(); x.arc(W * 0.17 + 7 * k, 66 * k, 14 * k, 0, 6.2832, false); x.fill();
                for (let i = 0; i < win.stars.length; i++) {
                    const s = win.stars[i];
                    x.globalAlpha = veil * (0.55 + 0.4 * Math.sin(T * s.tw + s.ph));
                    x.fillStyle = '#E4EEE8'; x.beginPath(); x.arc(s.x, s.y, s.r, 0, 6.2832, false); x.fill();
                }
                x.globalAlpha = veil;
                x.fillStyle = '#0E1512'; x.beginPath(); x.moveTo(0, H);
                for (let u = 0; u <= W + 10 * k; u += 10 * k) { const uu = u / k; x.lineTo(u, (338 + Math.sin(uu * 0.008 + 1.2) * 14 + Math.sin(uu * 0.021) * 6) * k); }
                x.lineTo(W, H); x.closePath(); x.fill();
                x.fillStyle = '#080B0A'; x.beginPath(); x.moveTo(0, H);
                for (let v = 0; v <= W + 10 * k; v += 10 * k) { const vv = v / k; x.lineTo(v, (356 + Math.sin(vv * 0.006 + 3.1) * 12 + Math.sin(vv * 0.017 + 0.6) * 5) * k); }
                x.lineTo(W, H); x.closePath(); x.fill();
                // the dial is the desktop's own (Dial.qml, under this); drawn here too so the veil shows it until it lets go
                const sp = Dial.spot(W, H);
                Dial.draw(x, sp.x, sp.y, sp.r, veil, 1, 1, 0, Dial.arcAngle(), T);
            }
            if (dark > 0) { x.globalAlpha = dark; x.fillStyle = '#0F1010'; x.fillRect(0, 0, W, H); }
            x.globalAlpha = 1;
        }
    }
    FrameAnimation { running: win.visible; onTriggered: art.requestPaint() }
}
