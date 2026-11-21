// The volume and brightness ring (her build brief, "Volume and brightness"; her design tour, part 10, drawn with the
// tour's own drawing code). A small ring of 24 dots at the bottom middle, the level as a number in the centre, a
// one-word label under it in a dark see-through pill (Volume, Brightness or Muted). Every dot position shows as a tiny
// faint dot; filled ones grow and take the colour (her accent for volume, warm white for brightness). Muted shows
// hollow grey dots. It shows at once, stays about 1.5 s after the last press, then fades in 0.6 s; a small bump on
// each press. Reduced motion: no bump and no easing of the dots, a plain fade.
//
// It follows the REAL default output (PipeWire): any change of its volume or mute shows the ring, so the keyboard's
// volume keys, the headset's dial and the mixer all show it. Brightness shows when Brightness.qml changes it (keys).
// It never takes the keyboard (no keyboard interactivity) and lets every click through (an empty input mask). It is
// on the Overlay layer, so it shows over a full-screen window too.
//
// One change from the tour's code, on purpose: in the tour a press while the ring is already showing restarts its
// 0.12 s fade-in from nothing (a flicker on held keys); here the ring only fades in when it was not already showing.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    anchors { bottom: true }
    implicitWidth: 160
    implicitHeight: 124
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "taylor-osd"
    mask: Region {}

    // the ring keeps the tour's dark see-through disc and pill on every scheme, with light words on them
    readonly property color disc: "#0B0D0C"
    readonly property color words: "#EDEFEE"
    readonly property color grey: "#9AA19D"

    readonly property int n: 24
    property string kind: "v"
    property real vol: 0
    property bool muted: false
    property real shV: 0
    property real shB: 80
    property real inAt: -99          // when it last started to show
    property real lastAt: -99        // the last press
    property real bump: -99
    property real lastT: 0
    property bool ready: false       // no ring for the values PipeWire reports at start or when the output changes

    function now() { return Date.now() / 1000; }
    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }
    function alphaAt(T) {
        const e = T - win.lastAt;
        if (win.theme.still) return e < 1.5 ? 1 : 1 - cl((e - 1.5) / 0.6);
        return sm((T - win.inAt) / 0.12) * (1 - sm((e - 1.5) / 0.6));
    }
    function poke(k) {
        const T = now();
        if (alphaAt(T) < 0.5) win.inAt = T; else win.inAt = T - 1;
        win.kind = k; win.lastAt = T; win.bump = T;
        if (k === "v") console.info("taylor-osd: " + (win.muted ? "muted" : "volume " + Math.round(win.vol)));
        else console.info("taylor-osd: brightness " + Brightness.level);
        art.requestPaint();
    }

    // ---- the default output ----
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: win.sink ? [win.sink] : [] }
    function readSink() {
        const a = win.sink && win.sink.audio;
        if (!a) return false;
        const v = Math.max(0, Math.min(100, Math.round(a.volume * 100)));   // the ring shows 0 to 100
        const changed = v !== Math.round(win.vol) || a.muted !== win.muted;
        win.vol = v; win.muted = a.muted;
        return changed;
    }
    onSinkChanged: { win.ready = false; settle.restart(); readSink(); }
    Timer { id: settle; interval: 1200; onTriggered: { win.readSink(); win.shV = win.vol; win.ready = true; } }
    Component.onCompleted: settle.start()
    Connections {
        target: win.sink ? win.sink.audio : null
        function onVolumesChanged() { if (win.readSink() && win.ready) win.poke("v"); }
        function onMutedChanged() { if (win.readSink() && win.ready) win.poke("v"); }
    }
    Connections {
        target: Brightness
        function onChangedAtChanged() { win.poke("b"); }
    }

    property bool active: false      // drawing frames only while it shows
    onLastAtChanged: { active = true; hideT.restart(); }
    Timer { id: hideT; interval: 2300; onTriggered: { win.active = false; art.requestPaint(); console.info("taylor-osd: gone"); } }
    FrameAnimation { running: win.active; onTriggered: art.requestPaint() }

    Canvas {
        id: art
        anchors.fill: parent
        onPaint: {
            const x = getContext("2d");
            x.reset();
            const T = win.now(), dt = Math.min(0.033, Math.max(0, T - win.lastT));
            win.lastT = T;
            const still = win.theme.still;
            const bri = Brightness.level;
            win.shV = still ? win.vol : win.shV + (win.vol - win.shV) * Math.min(1, dt * 14);
            win.shB = still ? bri : win.shB + (bri - win.shB) * Math.min(1, dt * 14);
            const al = win.alphaAt(T);
            if (al <= 0.005) return;
            const N = win.n, kind = win.kind;
            const rx = width / 2, ry2 = height - 72, rad = 19;
            const lvl = (kind === "v" ? win.shV : win.shB) / 100;
            const isMute = kind === "v" && (win.muted || Math.round(win.vol) === 0);
            const pop = still ? 1 : 1 + 0.08 * Math.exp(-(T - win.bump) * 14);
            const rr = (px, py, w, h, r) => {
                r = Math.max(0, Math.min(r, w / 2, h / 2)); x.beginPath(); x.moveTo(px + r, py);
                x.arcTo(px + w, py, px + w, py + h, r); x.arcTo(px + w, py + h, px, py + h, r);
                x.arcTo(px, py + h, px, py, r); x.arcTo(px, py, px + w, py, r); x.closePath();
            };
            x.textAlign = "center"; x.textBaseline = "middle";
            x.globalAlpha = 0.62 * al; x.fillStyle = String(win.disc); x.beginPath(); x.arc(rx, ry2, (rad + 10) * pop, 0, 6.2832, false); x.fill();
            const lab = kind === "v" ? (isMute ? "Muted" : "Volume") : "Brightness";
            x.font = "400 12px " + win.theme.sans;
            const lw = x.measureText(lab).width + 22;
            x.globalAlpha = 0.62 * al; x.fillStyle = String(win.disc); rr(rx - lw / 2, ry2 + rad + 15, lw, 22, 11); x.fill();
            x.globalAlpha = 0.92 * al; x.fillStyle = String(win.words); x.fillText(lab, rx, ry2 + rad + 26.5);
            const colOn = String(kind === "v" ? win.theme.accent : win.theme.warm), fill = lvl * N;
            for (let i = 0; i < N; i++) {
                const a2 = -1.5708 + i / N * 6.2832, on = win.cl(fill - i);
                const dx2 = rx + Math.cos(a2) * rad * pop, dy2 = ry2 + Math.sin(a2) * rad * pop;
                x.globalAlpha = 0.28 * al; x.fillStyle = String(win.words); x.beginPath(); x.arc(dx2, dy2, 1, 0, 6.2832, false); x.fill();
                if (on > 0) {
                    if (isMute) { x.globalAlpha = 0.8 * al * on; x.strokeStyle = String(win.grey); x.lineWidth = 1; x.beginPath(); x.arc(dx2, dy2, 2, 0, 6.2832, false); x.stroke(); }
                    else { x.globalAlpha = al * on; x.fillStyle = colOn; x.beginPath(); x.arc(dx2, dy2, 1.2 + 1.2 * on, 0, 6.2832, false); x.fill(); }
                }
            }
            x.globalAlpha = al; x.fillStyle = String(isMute ? win.grey : win.words); x.font = "500 13px " + win.theme.sans;
            x.fillText(String(Math.round(kind === "v" ? win.vol : bri)), rx, ry2 + 0.5);
            x.globalAlpha = 1;
        }
    }
}
