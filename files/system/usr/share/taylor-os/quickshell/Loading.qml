// Circling dots by the pointer (her build brief, "Loading"; her design tour, part 8): while an app she picked in her
// launcher has not opened its window yet, three small dots circle just below and right of the pointer. They go the
// moment Hyprland says a window opened (its "openwindow" event), or after 20 seconds. This draws over windows (it is
// a pointer helper, not TAYLOR), takes no clicks and no keys. The dots on the dock icon are the dock's own.
// Reduced motion: the three dots stand still and pulse once instead of circling.
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
            const cols = [win.theme.accent, win.theme.mix(win.theme.accent, win.theme.soft, 0.5), win.theme.soft];
            const fadeIn = Math.min(1, (T - win.t0) / 0.3);
            for (let i = 0; i < 3; i++) {      // her orbit(ptr.x + 14, ptr.y + 14, 5, 3, T, 0.95, 1.3, 5.5)
                const a = still ? i / 3 * 6.2832 : T * 5.5 + i * (6.2832 / 3) + 0.55 * Math.sin(T * 5.5 * 0.9 + i * 1.3);
                c.globalAlpha = 0.95 * fadeIn * (still ? 0.8 : 0.6 + 0.4 * Math.sin(T * 3 + i));
                c.fillStyle = cols[i % 3];
                const dr = 1.3 * win.u * (still ? 1 : 0.8 + 0.3 * Math.sin(T * 2 + i * 2));
                c.beginPath(); c.arc(20 + Math.cos(a) * 5 * win.u, 20 + Math.sin(a) * 5 * win.u, dr, 0, 6.2832); c.fill();
            }
        }
    }
    FrameAnimation { running: win.visible; onTriggered: art.requestPaint() }
}
