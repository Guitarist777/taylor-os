// TAYLOR's dial on her desktop, right of centre, with "ALL CLEAR." under it (her "login unlock to desktop" mockup).
// The login screen draws it into this spot as she signs in; from then on it stays here, its three arcs turning slowly.
// It sits on the desktop (under windows) and takes no clicks. "ALL CLEAR." is her mockup's wording; it is not tied to
// anything yet (TAYLOR does not run on Linux).
import Quickshell
import Quickshell.Wayland
import QtQuick
import "dial_draw.js" as Dial

PanelWindow {
    id: win
    property QtObject theme
    property real arrive2: 1          // "ALL CLEAR." fades in with the tray as she arrives

    readonly property var sp: Dial.spot(screen ? screen.width : 1920, screen ? screen.height : 1080)
    readonly property real ext: Math.ceil(sp.r + 20 * sp.r / 30)        // the outer arcs and their stroke
    readonly property real below: Math.ceil(118 * sp.k + 14 * sp.k)    // down to "ALL CLEAR."

    anchors { top: true; left: true }
    margins { left: Math.round(sp.x - ext); top: Math.round(sp.y - ext) }
    implicitWidth: 2 * ext
    implicitHeight: ext + below
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "taylor-dial"

    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const x = getContext("2d");
            x.reset();
            const T = Date.now() / 1000;
            Dial.draw(x, win.ext, win.ext, win.sp.r, 1, 1, 1, 0, Dial.arcAngle(), T);
            Dial.words(x, win.ext, win.ext + 118 * win.sp.k, win.sp.k, win.arrive2, Math.round(11 * win.sp.k) + "px " + win.theme.sans);
        }
    }
    onArrive2Changed: art.requestPaint()
    // The arcs turn at her 0.12 a second: twenty pictures a second is smooth for that.
    Timer { interval: 50; repeat: true; running: true; onTriggered: art.requestPaint() }
}
