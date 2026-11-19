// TAYLOR's dial on her desktop, right of centre, with its status line under it (her "login unlock to desktop" and
// "app launcher and search" mockups). The login screen draws it into this spot as she signs in; from then on it stays
// here, its three arcs turning slowly. A click on it opens her launcher (the dial itself shrinks into the search bar:
// Launcher.qml draws it while the launcher is open, so this one steps aside). After she picks something the line says
// what it is doing ("OPENING STEAM.") and the arcs turn faster for a moment, then it is "ALL CLEAR." again.
// "ALL CLEAR." is her mockup's wording; it is not tied to anything yet (TAYLOR does not run on Linux).
import Quickshell
import Quickshell.Wayland
import QtQuick
import "dial_draw.js" as Dial

PanelWindow {
    id: win
    property QtObject theme
    property real arrive2: 1          // the status line fades in with the tray as she arrives
    property string status: "ALL CLEAR."
    property bool busy: false         // a moment after she picked something: the arcs turn faster
    property bool stepAside: false    // the launcher is open and draws the dial itself
    signal clicked()

    readonly property var sp: Dial.spot(screen ? screen.width : 1920, screen ? screen.height : 1080)
    readonly property real ext: Math.ceil(sp.r + 20 * sp.r / 30)        // the outer arcs and their stroke
    readonly property real below: Math.ceil(118 * sp.k + 14 * sp.k)    // down to the status line
    readonly property real side: Math.ceil(70 * sp.k)                  // room for a longer status line ("OPENING SETTINGS.")

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

    property real spin: 0
    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const x = getContext("2d");
            x.reset();
            if (win.stepAside) return;
            const T = Date.now() / 1000, cx = win.ext + win.side;
            Dial.draw(x, cx, win.ext, win.sp.r, 1, 1, 1, 0, Dial.arcAngle() + win.spin, T);
            Dial.words(x, cx, win.ext + 118 * win.sp.k, win.sp.k, win.arrive2, Math.round(11 * win.sp.k) + "px " + win.theme.sans, win.status);
        }
    }
    onArrive2Changed: art.requestPaint()
    onStatusChanged: art.requestPaint()
    onStepAsideChanged: art.requestPaint()
    // The arcs turn at her 0.12 a second (faster for a moment after she picks something): twenty pictures a second.
    Timer { interval: 50; repeat: true; running: true; onTriggered: { if (win.busy) win.spin += 0.5 * 0.05; art.requestPaint(); } }

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
