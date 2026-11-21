// Stepping away: her timeout to the lock screen (her build brief, "Timeout to lock"; her design tour part 9, her numbers).
// After Prefs.idleMinutes with no input (3 by default) the windows, dock, mixer and corner clock dim and then disappear
// (about two seconds), the background dims just behind them (a lot; TAYLOR only slightly) and her status reads STILL
// THERE?, pulsing gently. Once the windows are gone she glides to the middle in 3.5 s and waits alone for
// Prefs.waitMinutes (2 by default). Any mouse or key input before the burst cancels it all: she glides back and the
// windows return. Otherwise she swells slightly and the lock screen takes over (/usr/libexec/taylor-lock burst; the
// burst into specks and the lock screen drawing in are drawn there, lock/LockScene.qml).
//
// How it is drawn: windows cannot be faded from here, so a copy of her live sky (Sky.qml) comes up over them (just
// above the windows, below nothing she needs) and fades in as they "disappear"; the dimming and TAYLOR are drawn on a
// cover over everything, which also takes the clicks and keys meanwhile, so nothing typed reaches a hidden window.
//
// How the desktop knows she is away: the compositor's idle notice (Quickshell's IdleMonitor, ext-idle-notify), which
// honours idle inhibitors (videos and games set them) when Prefs.stayAwakeForMedia is on. On top of that, with that
// setting on, the timeout does not start while any player says it is playing (MPRIS) or the focused window is full
// screen; it then waits a full idle time again after the video or game stops. Any input at all ends the idle (the
// compositor tells us), and the cover also takes clicks and keys as input.
//
// Tests only: TAYLOR_IDLE_SECONDS and TAYLOR_WAIT_SECONDS replace her minutes. IPC "lock": now (lock at once), away
// (start the timeout now), arrived (the lock screen has unlocked), state.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import "dial_draw.js" as Dial

Scope {
    id: aw
    property var mainScreen: null
    property QtObject theme
    signal arrived()               // the lock screen has unlocked: shell.qml plays her arrival
    property real arriveAt: 3      // shell.qml's arrival clock (0..3)
    property bool again: false     // her arrival after an unlock: drawn by a fresh Arrival here
    onArriveAtChanged: if (again && arriveAt >= 3) { again = false; console.info("taylor-away: arrived"); }

    // her arrival again, on every screen, out of the dark the lock screen faded to
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: ag
                required property var modelData
                LazyLoader { active: aw.again; Arrival { screen: ag.modelData; at: aw.arriveAt } }
            }
        }
    }

    // off | out (dimming, gliding, waiting) | back (she came back: everything returns) | locking | locked
    property string phase: "off"
    readonly property bool active: phase !== "off"
    property real t: 0
    property real rot: 0

    function envNum(n) { const v = parseFloat(Quickshell.env(n) || ""); return isNaN(v) ? -1 : v; }
    readonly property real idleSeconds: envNum("TAYLOR_IDLE_SECONDS") > 0 ? envNum("TAYLOR_IDLE_SECONDS") : Math.max(0.25, Prefs.idleMinutes) * 60
    readonly property real waitSeconds: envNum("TAYLOR_WAIT_SECONDS") >= 0 ? envNum("TAYLOR_WAIT_SECONDS") : Math.max(0, Prefs.waitMinutes) * 60

    // her timings (the tour's, from the first moment of idle)
    readonly property real hold: 4.9                  // windows gone, she has glided to the middle
    readonly property real lockAt: hold + waitSeconds // the burst
    readonly property real launchAt: lockAt - 0.45    // she swells; the lock screen starts
    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }
    readonly property real wd: sm(t / 1.0)                    // windows dim
    readonly property real ui: 1 - sm((t - 0.8) / 1.0)       // then disappear
    readonly property real bd: sm((t - 0.6) / 2.0)           // the background dims just behind them
    readonly property real g: sm((t - 1.4) / 3.5)            // her glide to the middle
    readonly property real puff: 1 + 0.08 * sm((t - launchAt) / 0.45)

    readonly property string run: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    // ---- noticing she is away ----
    IdleMonitor {
        id: idle
        enabled: true
        timeout: aw.idleSeconds
        respectInhibitors: Prefs.stayAwakeForMedia
        onIsIdleChanged: {
            console.info("taylor-away: " + (isIdle ? "idle" : "input"));
            if (isIdle) aw.idleBegan(); else aw.input();
        }
    }
    property double heldUntil: 0
    function playing() {
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return true;
        return false;
    }
    function idleBegan() {
        if (phase !== "off") return;
        mediaCheck.running = true;
    }
    // the focused window full screen (a game, a film), asked of Hyprland at the moment it matters
    Process {
        id: mediaCheck
        // (and whether she is already locked: then there is nothing to time out)
        command: ["sh", "-c", "if [ -e \"" + aw.run + "/taylor-lock.pid\" ] || pgrep -u \"$(id -u)\" -x hyprlock >/dev/null; then echo LOCKED; fi; "
                              + "hyprctl -j activewindow 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let full = false, txt = this.text;
                if (txt.indexOf("LOCKED") === 0) return;
                try { const w = JSON.parse(txt); full = w && (w.fullscreen === true || w.fullscreen >= 2); } catch (e) {}
                const now = Date.now();
                if (Prefs.stayAwakeForMedia && (full || aw.playing())) {
                    aw.heldUntil = now + aw.idleSeconds * 1000;
                    console.info("taylor-away: held (" + (full ? "a full-screen window" : "something is playing") + ")");
                    return;
                }
                if (!idle.isIdle || aw.phase !== "off") return;
                if (now < aw.heldUntil) return;
                aw.start("idle");
            }
        }
    }
    // while she is idle and the timeout is held (or waiting out a fresh idle time after a video), look again
    Timer {
        interval: 15000
        repeat: true
        running: idle.isIdle && aw.phase === "off"
        onTriggered: mediaCheck.running = true
    }

    function start(why) {
        if (phase !== "off") return;
        t = 0;
        rot = Dial.arcAngle();
        phase = "out";
        rects.running = true;
        console.info("taylor-away: dimming (" + why + "; burst after " + lockAt.toFixed(1) + " s)");
    }
    function input() {
        if (phase !== "out") return;
        if (t >= launchAt) return;            // too late: the lock screen is already on its way
        t = Math.min(t, hold);
        phase = "back";
        console.info("taylor-away: she is back; everything returns");
    }
    function reset() {
        phase = "off"; t = 0;
    }
    function lockNow(mode) {
        Quickshell.execDetached(["env", "TAYLOR_DESKTOP_DIR=" + Quickshell.shellDir, "/usr/libexec/taylor-lock", mode]);
    }

    // her clock for the sequence
    FrameAnimation {
        running: aw.phase === "out" || aw.phase === "back" || aw.phase === "locking"
        onTriggered: {
            const dt = Math.min(0.1, Math.max(0, frameTime));
            aw.rot += 0.12 * (1 - 0.7 * aw.bd) * dt;
            if (aw.phase === "back") {
                aw.t -= dt * 7;
                if (aw.t <= 0) { aw.reset(); console.info("taylor-away: back to the desktop"); }
                return;
            }
            aw.t += dt;
            if (aw.phase === "out" && aw.t >= aw.launchAt) {
                aw.phase = "locking";
                console.info("taylor-away: the burst; her lock screen");
                aw.lockNow(Theme.still ? "now" : "burst");
            } else if (aw.phase === "locking" && aw.t >= aw.lockAt + 3) {
                aw.phase = "locked";
            }
        }
    }
    // If the lock screen's own word never reaches us, its state file does: the cover never stays up after an unlock.
    Process {
        id: stateRead
        command: ["cat", aw.run + "/taylor-lock.state"]
        stdout: StdioCollector { onStreamFinished: if (this.text.trim() === "unlocked" && aw.phase === "locked") aw.unlocked("state file"); }
    }
    Timer { interval: 2000; repeat: true; running: aw.phase === "locked"; onTriggered: stateRead.running = true }
    function unlocked(how) {
        console.info("taylor-away: unlocked (" + how + "); her arrival");
        reset();
        again = true;
        arrivedLater.start();
    }

    // started a moment later, outside the IPC call that brought the news
    Timer { id: arrivedLater; interval: 1; onTriggered: aw.arrived() }

    IpcHandler {
        target: "lock"
        function now(): void { console.info("taylor-away: lock now"); aw.lockNow("now"); }
        function away(): void { aw.start("asked"); }
        function arrived(): void { aw.unlocked("lock screen"); }
        function state(): string { return aw.phase + " t=" + aw.t.toFixed(1) + " idle=" + idle.isIdle + " idleSeconds=" + aw.idleSeconds + " wait=" + aw.waitSeconds; }
    }

    // where her windows are (to dim them first), asked of Hyprland as the timeout starts
    property var winRects: ({})
    Process {
        id: rects
        command: ["sh", "-c", "hyprctl -j monitors 2>/dev/null || echo '[]'; echo '@@'; hyprctl -j clients 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                try {
                    const parts = this.text.split("@@"), mons = JSON.parse(parts[0]), cls = JSON.parse(parts[1]);
                    for (const m of mons) {
                        const ws = m.activeWorkspace ? m.activeWorkspace.id : -1, list = [];
                        for (const c of cls)
                            if (c.mapped !== false && !c.hidden && c.workspace && c.workspace.id === ws)
                                list.push({ x: c.at[0] - m.x, y: c.at[1] - m.y, w: c.size[0], h: c.size[1] });
                        out[m.name] = list;
                    }
                } catch (e) {}
                aw.winRects = out;
            }
        }
    }

    // ---- what she sees: on every screen, the sky copy over the windows and the cover over everything ----
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: per
                required property var modelData
                readonly property bool main: modelData === aw.mainScreen
                LazyLoader {
                    active: aw.active
                    Sky {
                        screen: per.modelData
                        theme: aw.theme
                        color: "transparent"
                        contentItem.opacity: 1 - aw.ui
                        mask: Region {}
                        WlrLayershell.layer: WlrLayer.Top
                        WlrLayershell.namespace: "taylor-away-sky"
                    }
                }
                LazyLoader {
                    active: aw.active
                    PanelWindow {
                        id: cover
                        screen: per.modelData
                        anchors { top: true; bottom: true; left: true; right: true }
                        color: "transparent"
                        exclusionMode: ExclusionMode.Ignore
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.namespace: "taylor-away"
                        WlrLayershell.keyboardFocus: per.main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                        Canvas {
                            id: art
                            anchors.fill: parent
                            renderStrategy: Canvas.Cooperative
                            onPaint: {
                                const x = getContext("2d");
                                x.reset();
                                const W = width, H = height, k = H / 380, T = Date.now() / 1000;
                                // her windows dim first
                                const rs = aw.winRects[per.modelData.name] || [];
                                if (aw.ui > 0.005 && rs.length) {
                                    x.fillStyle = "#000000"; x.globalAlpha = 0.62 * aw.wd * aw.ui;
                                    for (const r of rs) x.fillRect(r.x, r.y, r.w, r.h);
                                }
                                // the background dims a lot
                                x.globalAlpha = 0.58 * aw.bd; x.fillStyle = "#000000"; x.fillRect(0, 0, W, H);
                                x.globalAlpha = 1;
                                if (!per.main || !Prefs.showTaylor) return;
                                // TAYLOR dims only slightly, glides to the middle, waits; swells before the burst
                                Dial.setColors(aw.theme.accent, aw.theme.text, aw.theme.text2);
                                const sp = Dial.spot(W, H), mx = W / 2, my = 172 * k;
                                const ta = (1 - 0.25 * aw.bd) * (1 - aw.ui);
                                const drawAt = (px, py, al) => {
                                    if (al <= 0.003) return;
                                    x.save(); x.translate(px, py); x.scale(aw.puff, aw.puff); x.translate(-px, -py);
                                    Dial.draw(x, px, py, sp.r, al, 1, 1, 0, aw.rot, T);
                                    x.restore();
                                    const line = aw.phase === "locking" || aw.phase === "locked" ? "" : "STILL THERE?";
                                    if (line) Dial.words(x, px, py + 118 * k, k, al * (0.8 + 0.2 * Math.sin(T * 1.6)) / 0.85 * 0.9,
                                                         Math.round(11 * k) + "px " + aw.theme.sans, line);
                                };
                                if (Theme.still) {        // less motion: she fades out at her spot and in at the middle
                                    drawAt(sp.x, sp.y, ta * (1 - aw.g));
                                    drawAt(mx, my, ta * aw.g);
                                } else {
                                    drawAt(sp.x + (mx - sp.x) * aw.g, sp.y + (my - sp.y) * aw.g, ta);
                                }
                            }
                        }
                        FrameAnimation { running: aw.active && aw.phase !== "locked"; onTriggered: art.requestPaint() }

                        // a click or a key while she is away is her coming back (and never reaches a hidden window)
                        MouseArea {
                            anchors.fill: parent
                            onPressed: aw.input()
                            onWheel: aw.input()
                        }
                        Item {
                            anchors.fill: parent
                            focus: true
                            Keys.onPressed: (event) => { event.accepted = true; aw.input(); }
                        }
                    }
                }
            }
        }
    }
}
