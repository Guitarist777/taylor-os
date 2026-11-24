// One screen of her login scene. The drawing is scene_engine.js (her three pieces); this window only runs its clock,
// repaints it, and passes on what shell.qml tells it (a letter typed, Enter, the answer).
import Quickshell
import Quickshell.Wayland
import QtQuick
import "scene_engine.js" as Eng

PanelWindow {
    id: win
    property bool primary: false
    property string who: ""
    property real fade: 0          // 0..1, the dark before her desktop starts
    // her two Settings choices, as the login screen got them (shell.qml reads /var/lib/taylor-os/greeter.json)
    property bool still: false     // "Reduce motion": the still word, then the login as one simple fade
    property bool full: true       // "Boot animation": play the full opening (off: start at the hand-off)
    property real cover: 0         // reduced motion: the still word over the login, 1 .. 0
    // TAYLOR_GREETER_FROM=20 starts the scene 20 seconds in (the preview's frames).
    readonly property real startFrom: {
        const v = parseFloat(Quickshell.env("TAYLOR_GREETER_FROM") || "");
        return isNaN(v) ? 0 : v;
    }
    // TAYLOR_GREETER_UNLOCK_AT=2 holds her unlock 2 seconds after "Welcome back" (the preview's frames).
    readonly property real unlockAt: {
        const v = parseFloat(Quickshell.env("TAYLOR_GREETER_UNLOCK_AT") || "");
        return isNaN(v) ? -1 : v;
    }
    // TAYLOR_GREETER_HOLD=1 stops the clock where TAYLOR_GREETER_FROM put it (the preview's still frames).
    property bool held: Quickshell.env("TAYLOR_GREETER_HOLD") === "1"
    property bool started: false
    property int marks: 0
    property real lastW: 0
    property real lastH: 0
    property double startedMs: 0
    signal skipped()
    signal keyTyped(string text)
    signal keyErase()
    signal keyEnter()
    signal keyEscape()
    signal keyKde()

    anchors { top: true; bottom: true; left: true; right: true }
    color: "#0B0D0C"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-greeter"
    WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The window is 100 x 100 for a moment before the screen's size arrives: in the first second and a half a new
    // size starts the scene again at the real size; later, it only resizes.
    function begin() {
        if (width <= 200 || height <= 200) return;   // the 100 x 100 placeholder: wait for the real size
        if (started && Date.now() - startedMs > 1500) { Eng.setSize(width, height); return; }
        if (started && width === lastW && height === lastH) return;   // the same size again: nothing to start over
        lastW = width; lastH = height;
        started = true;
        startedMs = Date.now();
        marks = 0;
        Eng.setSize(width, height);
        if (manrope.status === FontLoader.Ready) Eng.setFont(manrope.name);
        Eng.setName(who);
        Eng.setMotion(still, full);
        Eng.spawn();
        console.info("taylor-greeter: opening " + (still ? "still (reduced motion)" : full ? "full" : "skipped, from the hand-off") + ", " + width + " x " + height);
        if (startFrom > 0) Eng.settleTo(startFrom);
        art.requestPaint();
    }
    onWidthChanged: begin()
    onHeightChanged: begin()
    onWhoChanged: Eng.setName(who)
    // a choice that arrives in the first moment starts the scene again with it
    function again() { if (started && Date.now() - startedMs < 1500) { started = false; begin(); } }
    onStillChanged: again()
    onFullChanged: again()
    Component.onCompleted: begin()

    function letter() { Eng.skipToLogin(); Eng.addChar(); }
    function erase(left) { Eng.delChar(left); }
    function clearAll() { Eng.clearAll(); }
    function emptyEnter() { Eng.skipToLogin(); Eng.emptyEnter(); }
    function waiting() { Eng.waiting(); }
    function accepted() { Eng.accepted(); }
    function rejected() { Eng.rejected(); }
    function skip() { Eng.skipToLogin(); }
    function setKde(on) { Eng.skipToLogin(); Eng.setKde(on); }
    function autoKde(n) { Eng.autoKde(n); }
    function welcomeFor() { return Eng.welcomeFor(); }

    // Manrope from its own file: the greeter account's font list did not have it on the 2026-11-19 VM test, and the
    // canvas then drew every word at its tiny default size.
    FontLoader {
        id: manrope
        source: "file:///usr/share/fonts/taylor/Manrope-Variable.ttf"
        onStatusChanged: {
            if (status === FontLoader.Ready) { Eng.setFont(name); console.log("taylor-greeter: font " + name); }
            else if (status === FontLoader.Error) console.log("taylor-greeter: Manrope did not load");
        }
    }

    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Threaded   // her opening at 120 frames a second, not 21 (see taylor-greeter-scene)
        onPaint: {
            if (!win.started) return;
            const ctx = getContext("2d");
            Eng.draw(ctx);
            if (win.fade > 0) Eng.fadeOut(ctx, win.fade);
        }
    }

    // Reduced motion: the still word, drawn once, fading off the login over her one second.
    Canvas {
        id: stillWord
        anchors.fill: parent
        visible: win.cover > 0
        opacity: win.cover
        renderStrategy: Canvas.Cooperative
        property bool drawn: false
        onVisibleChanged: if (visible && !drawn) requestPaint()
        onPaint: { Eng.drawStillWord(getContext("2d")); drawn = true; }
    }

    FrameAnimation {
        running: win.started
        onTriggered: {
            if (!win.held) {
                Eng.advance(frameTime);
                if (win.unlockAt >= 0 && Eng.welcomeFor() >= 0) {
                    while (Eng.welcomeFor() < win.unlockAt) Eng.advance(1 / 60);
                    win.held = true;
                }
            }
            win.cover = Eng.stillCover();
            // the opening's milestones, for the log (the virtual PC's boot check reads them)
            const st = Eng.sceneT();
            if (win.marks === 0 && st >= 9.3 && !Eng.inLogin() && !win.still) { win.marks = 1; console.info("taylor-greeter: the friend goes to fetch the lost dot (" + st.toFixed(1) + " s)"); }
            if (win.marks <= 1 && st >= 10.7 && !Eng.inLogin() && !win.still) { win.marks = 2; console.info("taylor-greeter: the lost dot hops, the friend hops lower (" + st.toFixed(1) + " s)"); }
            if (win.marks <= 2 && Eng.inLogin()) { win.marks = 3; console.info("taylor-greeter: the hand-off begins at " + st.toFixed(1) + " s of the opening, " + ((Date.now() - win.startedMs) / 1000).toFixed(1) + " s after the screen first drew"); }
            art.requestPaint();
        }
    }

    // Her keys (only the screen with the keyboard): letters, Backspace, Enter, Escape, and F2 (the KDE backup, once).
    Item {
        anchors.fill: parent
        focus: win.primary
        Keys.onPressed: (event) => {
            event.accepted = true;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.keyEnter();
            else if (event.key === Qt.Key_Backspace) win.keyErase();
            else if (event.key === Qt.Key_Escape) win.keyEscape();
            else if (event.key === Qt.Key_F2) win.keyKde();
            else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) win.keyTyped(event.text);
            else event.accepted = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: win.skipped()
    }
}
