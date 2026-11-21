// A soft dot by the pointer (her build brief, "Loading"; her design tour, part 8, made quieter at her call 2026-11-21:
// the tour's three circling dots read as "a thinking thing"): while an app she picked in her launcher has not opened its
// window yet, one small dot just below and right of the pointer gently brightens and dims, 1.6 s a breath, as the
// app's dock icon does when it has one. They go the
// moment Hyprland says a window opened (its "openwindow" event), or after 20 seconds. This draws over windows (it is
// a pointer helper, not TAYLOR), takes no clicks and no keys. The dots on the dock icon are the dock's own.
// Reduced motion: the dot stays, a little dimmed, without breathing.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property bool waiting: false
    property real t0: 0
    property real px: -1
    property real py: -1

    function start() {
        t0 = Date.now() / 1000;
        waiting = true;
        stopAfter.restart();
        console.info("taylor-loading: waiting for the window");
    }
    function stop(why) {
        if (!waiting) return;
        waiting = false;
        console.info("taylor-loading: " + why + " after " + (Date.now() / 1000 - t0).toFixed(1) + " s");
    }
    Timer { id: stopAfter; interval: 20000; onTriggered: win.stop("gave up waiting") }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (win.waiting && ev.name === "openwindow") win.stop("the window opened"); }
    }

    // where the pointer is (Hyprland's own answer, ten times a second while waiting)
    Process {
        id: where
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/);
                if (m) { win.px = parseFloat(m[1]) - (win.screen ? win.screen.x : 0); win.py = parseFloat(m[2]) - (win.screen ? win.screen.y : 0); }
            }
        }
    }
    Timer { interval: 100; repeat: true; running: win.waiting; triggeredOnStart: true; onTriggered: if (!where.running) where.running = true }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: waiting && px >= 0
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-loading"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property real u: 1.6
    Canvas {
        id: art
        x: win.px + 14 * win.u - width / 2; y: win.py + 14 * win.u - height / 2
        width: 40; height: 40
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const T = Date.now() / 1000, still = win.theme.still;
            const fadeIn = Math.min(1, (T - win.t0) / 0.3);
            c.globalAlpha = fadeIn * (still ? 0.6 : 0.725 + 0.275 * Math.cos((T - win.t0) * 6.2832 / 1.6));
            c.fillStyle = win.theme.accent;
            c.beginPath(); c.arc(20, 20, 2 * win.u, 0, 6.2832); c.fill();
        }
    }
    FrameAnimation { running: win.visible; onTriggered: art.requestPaint() }
}
