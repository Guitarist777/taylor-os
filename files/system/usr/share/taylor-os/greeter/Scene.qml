// One screen of her login scene. The drawing is scene_engine.js (her three pieces), put on the screen by the graphics card
// (gpu_draw.js and shaders/); this window runs its clock, hands each frame over, and passes on what shell.qml tells it
// (a letter typed, Enter, the answer).
import Quickshell
import Quickshell.Wayland
import QtQuick
import "scene_engine.js" as Eng
import "gpu_draw.js" as Gpu

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
        if (manrope.status === FontLoader.Ready) { Eng.setFont(manrope.name); fontName = manrope.name; }
        Eng.setName(who);
        Eng.setMotion(still, full);
        Eng.spawn();
        console.info("taylor-greeter: opening " + (still ? "still (reduced motion)" : full ? "full" : "skipped, from the hand-off") + ", " + width + " x " + height);
        if (startFrom > 0) Eng.settleTo(startFrom);
        dataC.requestPaint();
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
    function setNote(t) { Eng.setNote(t); }
    function welcomeFor() { return Eng.welcomeFor(); }

    // Manrope from its own file: the greeter account's font list did not have it on the 2026-11-19 VM test, and the
    // canvas then drew every word at its tiny default size.
    FontLoader {
        id: manrope
        source: "file:///usr/share/fonts/taylor/Manrope-Variable.ttf"
        onStatusChanged: {
            if (status === FontLoader.Ready) { Eng.setFont(name); win.fontName = name; console.log("taylor-greeter: font " + name); }
            else if (status === FontLoader.Error) console.log("taylor-greeter: Manrope did not load");
        }
    }

    // ---- her scene, drawn by the graphics card (gpu_draw.js; 2026-11-24, her report "still 60" on her 240 Hz screen) ----
    // Back to front, as scene_engine.js draws it: the login sky, her waves, the shapes under the hills (the sparks, the
    // moon, the opening's dial), the hills, the clock and date, the shapes over them (the login dial, its dots, the
    // desktop dial), her name and the hint, the dark of a skipped opening, the dark before her desktop.
    readonly property int dataCols: 384
    readonly property int dataRows: 96          // 384 x 96 texels: 6144 shapes; a frame uses about 1,000
    property var rec: null
    property string fontName: "Manrope"
    ShaderEffect {
        id: sky
        anchors.fill: parent
        property real kk: 0
        visible: kk > 0
        fragmentShader: "shaders/sky.frag.qsb"
    }
    ShaderEffect {
        id: wavesFx
        anchors.fill: parent
        property real al: 0
        property real vt: 0
        property real sc: 1
        property size size: Qt.size(width, height)
        visible: al > 0
        fragmentShader: "shaders/waves.frag.qsb"
    }
    component Shapes: ShaderEffect {
        anchors.fill: parent
        property var prims: dataC
        property real first: 0
        property real count: 0
        property real cols: win.dataCols
        property real cells: 4 * win.dataCols * win.dataRows / 6 - 1
        visible: count > 0
        mesh: GridMesh { resolution: Qt.size(4 * win.dataCols * win.dataRows / 6 - 1, 1) }
        vertexShader: "shaders/prims.vert.qsb"
        fragmentShader: "shaders/prims.frag.qsb"
    }
    Shapes { id: under }
    ShaderEffect {
        id: hillsFx
        anchors.fill: parent
        property real kk: 0
        property real k: 1
        property size size: Qt.size(width, height)
        visible: kk > 0
        fragmentShader: "shaders/hills.frag.qsb"
    }
    // a word on the login: first the bare sky in its letter shapes (no star shows through it), then the word
    component Word: Item {
        id: wd
        property string s: ""
        property real px: 0
        property real py: 0
        property real size: 12
        property color col: "#EDEFEE"
        property real al: 0
        property color skyCol: "#0B0D0C"
        property real skyAl: 0
        anchors.fill: parent
        Text {
            text: wd.s; font.family: win.fontName; font.pixelSize: Math.max(1, wd.size); color: wd.skyCol; opacity: wd.skyAl
            x: Math.round(wd.px - width / 2); y: Math.round(wd.py + 0.235 * wd.size - baselineOffset)
        }
        Text {
            text: wd.s; font.family: win.fontName; font.pixelSize: Math.max(1, wd.size); color: wd.col; opacity: wd.al
            x: Math.round(wd.px - width / 2); y: Math.round(wd.py + 0.235 * wd.size - baselineOffset)
        }
    }
    Word { id: w0 }
    Word { id: w1 }
    Shapes { id: over }
    Word { id: w2 }
    Word { id: w3 }
    Rectangle { id: skipDark; anchors.fill: parent; color: "#0B0D0C"; opacity: 0; visible: opacity > 0 }
    Rectangle { anchors.fill: parent; color: "#0F1010"; opacity: win.fade; visible: opacity > 0 }   // fadeOut()

    // the shapes of each frame, as 6 texels each (gpu_draw.js); the shaders above read it as their texture
    Canvas {
        id: dataC
        x: -win.dataCols - 16; y: 0        // off the screen: only the shaders read it
        width: win.dataCols; height: win.dataRows
        canvasSize: Qt.size(win.dataCols, win.dataRows)
        renderStrategy: Canvas.Cooperative
        onPaint: {
            if (!win.started) return;
            const ctx = getContext("2d");
            if (!win.rec) win.rec = Gpu.make(win.dataCols, win.dataRows);
            const r = win.rec;
            r.begin(ctx);
            Eng.drawGpu(r);
            r.end();
            under.count = r.split;
            over.first = r.split; over.count = r.n - r.split;
            sky.kk = r.skyK;
            hillsFx.kk = r.hillsK; hillsFx.k = win.height / 380;
            wavesFx.al = r.wavesAl; wavesFx.vt = r.wavesT; wavesFx.sc = r.wavesS;
            const lo = [], hi = [];
            for (let i = 0; i < r.labels.length; i++) (r.labels[i].top ? hi : lo).push(r.labels[i]);
            win.word(w0, lo[0]); win.word(w1, lo[1]); win.word(w2, hi[0]); win.word(w3, hi[1]);
            skipDark.opacity = Eng.coverAmt();
            if (r.dropped && !win.droppedSaid) { win.droppedSaid = true; console.info("taylor-greeter: more shapes than the data texture holds (" + r.dropped + " left out)"); }
            win.paints++;
            if (!win.gpuSaid) { win.gpuSaid = true; console.info("taylor-greeter: drawn by the graphics card (" + r.n + " shapes in the first frame)"); }
        }
    }
    property bool droppedSaid: false
    property bool gpuSaid: false
    function word(w, l) {
        if (!l) { w.al = 0; w.skyAl = 0; w.s = ""; return; }
        w.s = l.s; w.px = l.x; w.py = l.y; w.size = l.size; w.col = l.col; w.al = l.al; w.skyCol = l.skyCol; w.skyAl = l.skyAl;
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
            dataC.requestPaint();
            win.ticks++;
        }
    }
    // frames a second, for the log (her report 2026-11-24: "still 60" on her 240 Hz screen): how often the screen asked
    // for a frame (ticks) and how many the drawing finished (drawn), every 2 s for the first 30 s
    property int ticks: 0
    property int paints: 0
    Timer {
        interval: 2000; repeat: true
        running: win.started && win.primary
        onTriggered: {
            if (Date.now() - win.startedMs > 30000) { stop(); return; }
            console.info("taylor-greeter: frames a second: screen " + Math.round(win.ticks / 2) + ", drawn " + Math.round(win.paints / 2));
            win.ticks = 0; win.paints = 0;
        }
    }

    // Her keys (only the screen with the keyboard): letters, Backspace, Enter, Escape, and F2 (the KDE backup, once).
    Item {
        anchors.fill: parent
        focus: win.primary
        Keys.onPressed: (event) => {
            event.accepted = true;
            // A held key never repeats into her password (2026-11-24: her login screen refused her password twice; a slow
            // frame can make one press look held, and the letter then counts twice). Backspace still repeats.
            if (event.isAutoRepeat && event.key !== Qt.Key_Backspace) return;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.keyEnter();
            else if (event.key === Qt.Key_Backspace) win.keyErase();
            else if (event.key === Qt.Key_Escape) win.keyEscape();
            else if (event.key === Qt.Key_F2) win.keyKde();
            else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) {
                const t = event.text;
                if (t.toLowerCase() !== t.toUpperCase()) Eng.keyNote((t === t.toUpperCase()) !== ((event.modifiers & Qt.ShiftModifier) !== 0) ? "caps" : "nocaps");
                win.keyTyped(t);
            }
            else if ((event.modifiers & Qt.KeypadModifier) && event.text === "" && [Qt.Key_Insert, Qt.Key_End, Qt.Key_Down, Qt.Key_PageDown, Qt.Key_Left, Qt.Key_Clear, Qt.Key_Right, Qt.Key_Home, Qt.Key_Up, Qt.Key_PageUp, Qt.Key_Delete].indexOf(event.key) >= 0) Eng.keyNote("num");
            else event.accepted = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: win.skipped()
    }
}
