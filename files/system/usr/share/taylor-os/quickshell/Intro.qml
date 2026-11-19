// The opening: her own animation (TaylorOS_boot_animation.html, 2026-11-18, "that should be the opening"), played once
// when the desktop starts after she signs in, over everything, then the sparks fall as rain and the dark lifts onto the
// live sky. A key or a click skips it. It never stays up past 30 seconds, whatever happens.
// The drawing itself is intro_engine.js (her code, moved over). TAYLOR_INTRO_AT=8.5 (for example) shows the still frame
// at 8.5 seconds and stays, for the tests' screenshots.
import Quickshell
import Quickshell.Wayland
import QtQuick
import "intro_engine.js" as Eng

PanelWindow {
    id: win
    property QtObject theme
    property bool done: false
    visible: !done
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-intro"
    WlrLayershell.keyboardFocus: done ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    readonly property real stillAt: {
        const v = parseFloat(Quickshell.env("TAYLOR_INTRO_AT") || "");
        return isNaN(v) ? -1 : v;
    }
    property bool started: false
    property int frames: 0

    // The window is 100 x 100 for a moment before the screen's size arrives, so a size change in the first second and a
    // half starts it again at the real size (preview run 44479181462 drew it 100 x 100 in the corner).
    function begin() {
        if (width <= 0 || height <= 0 || done) return;
        if (started && stillAt < 0 && Eng.elapsed() > 1.5) { Eng.setSize(width, height); return; }
        started = true;
        frames = 0;
        Eng.setSize(width, height);
        Eng.spawn();
        if (stillAt >= 0) Eng.settleTo(stillAt);
        art.requestPaint();
        console.info("taylor-intro: playing on " + width + "x" + height + (stillAt >= 0 ? " (still at " + stillAt + " s)" : ""));
    }
    function finish(why) {
        if (done) return;
        done = true;
        console.info("taylor-intro: done (" + why + ") after " + frames + " frames, " + (frames / Math.max(0.01, Eng.elapsed())).toFixed(1) + " a second");
    }
    onWidthChanged: begin()
    onHeightChanged: begin()
    Component.onCompleted: begin()

    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: { if (win.started) Eng.draw(getContext("2d")); }
    }

    FrameAnimation {
        running: win.started && !win.done && win.stillAt < 0
        onTriggered: {
            Eng.advance(frameTime);
            win.frames++;
            art.requestPaint();
            if (Eng.finished()) win.finish(Eng.skipped() ? "skipped" : "played");
        }
    }

    // Skip: any key or click lifts it at once.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => { Eng.skip(); event.accepted = true; }
    }
    MouseArea {
        anchors.fill: parent
        onPressed: Eng.skip()
    }

    // The backstop: never more than 30 seconds, even if a frame never comes.
    Timer {
        interval: 30000
        running: win.started && !win.done && win.stillAt < 0
        onTriggered: win.finish("backstop")
    }
}
