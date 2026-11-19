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
    // TAYLOR_GREETER_FROM=20 starts the scene 20 seconds in (the preview's frames).
    readonly property real startFrom: {
        const v = parseFloat(Quickshell.env("TAYLOR_GREETER_FROM") || "");
        return isNaN(v) ? 0 : v;
    }
    property bool started: false
    property double startedMs: 0
    signal skipped()
    signal keyTyped(string text)
    signal keyErase()
    signal keyEnter()
    signal keyEscape()

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
        started = true;
        startedMs = Date.now();
        Eng.setSize(width, height);
        Eng.setName(who);
        Eng.spawn();
        if (startFrom > 0) Eng.settleTo(startFrom);
        art.requestPaint();
    }
    onWidthChanged: begin()
    onHeightChanged: begin()
    onWhoChanged: Eng.setName(who)
    Component.onCompleted: begin()

    function letter() { Eng.skipToLogin(); Eng.addChar(); }
    function erase(left) { Eng.delChar(left); }
    function clearAll() { Eng.clearAll(); }
    function emptyEnter() { Eng.skipToLogin(); Eng.emptyEnter(); }
    function waiting() { Eng.waiting(); }
    function accepted() { Eng.accepted(); }
    function rejected() { Eng.rejected(); }
    function skip() { Eng.skipToLogin(); }
    function welcomeFor() { return Eng.welcomeFor(); }

    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            if (!win.started) return;
            const ctx = getContext("2d");
            Eng.draw(ctx);
            if (win.fade > 0) Eng.fadeOut(ctx, win.fade);
        }
    }

    FrameAnimation {
        running: win.started
        onTriggered: { Eng.advance(frameTime); art.requestPaint(); }
    }

    // Her keys (only the screen with the keyboard): letters, Backspace, Enter, Escape.
    Item {
        anchors.fill: parent
        focus: win.primary
        Keys.onPressed: (event) => {
            event.accepted = true;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.keyEnter();
            else if (event.key === Qt.Key_Backspace) win.keyErase();
            else if (event.key === Qt.Key_Escape) win.keyEscape();
            else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) win.keyTyped(event.text);
            else event.accepted = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: win.skipped()
    }
}
