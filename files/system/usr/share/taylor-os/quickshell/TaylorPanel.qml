// TAYLOR herself, "Beside her" (her brief, "TAYLOR in TaylorOS", approved 2026-11-25; her preview taylor-os-desktop.html:
// openTaylor, openPanel, placePanel, particles, taylorUI, homeHTML, renderTY, consumeWants, ping). Built into the desktop,
// not a separate app (her brief).
//
// Ways she is called: a click on her dial, her slot on the dock, her dot by the clock, the "TAYLOR · Got a sec?" line, and
// Ask TAYLOR in the launcher (the question goes straight to her). The panel is 400 x up to 560 (her preview's sizes, times
// the dock's own scale on a big screen), next to her dial (on its left, or its right if there is no room), centred on her.
// While it is open her windows fade to about 15% and take no clicks (a copy of her live sky comes up over them at 85%, the
// same way her timeout does it, Away.qml), and her dial is drawn again over it, so she stays in front of everything faded.
// Esc or a click anywhere else closes it. Arrival "materialize": about 38 green specks fly from her ring into the panel's
// area over about 0.6 s; 0.3 s in, a glowing line sweeps across from the side nearest her and reveals the panel (0.56 s).
// On close the specks fly back into her ring. Less motion: it simply fades.
//
// Inside, as her TAYLOR page: My day (what is waiting, the next thing, Weather and Builds, a Needs you row with Open), her
// replies as plain text with a small tag under each saying which part answered ("Sonnet 5.5 · chat"), Jessica's messages
// as green bubbles on the right, and the input row: mic and read-aloud (placeholders until voice comes), Private, "Talk to
// me...", and the round green send. One conversation with her page: what she types here is an ordinary turn of hers.
//
// Wants Jessica: when TAYLOR has something new waiting, "TAYLOR · Got a sec?" rises above the clock for about 9 s while her
// dial keeps its glint going round until she is opened; opening her shows what she wanted as her first message.
//
// The line to TAYLOR is /usr/libexec/taylor-talk (it holds the desktop's own key; nothing here ever does). Nothing she
// types or reads is logged: the log gets counts and states only.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "dial_draw.js" as Dial

Scope {
    id: ty
    property var screen: null
    property QtObject theme
    property int waiting: 0            // what TAYLOR has waiting (Taylor.qml)
    property bool thinkingElsewhere: false
    property string status: "ALL CLEAR."   // the line under her dial (shell.qml's dialLine), drawn again in front while she is open

    // ---- what the desktop reads ----
    property bool open: false
    property bool wants: false         // her glint, the band's pulse, "1 THING IS WAITING.", the blinking dot by the clock
    property bool thinking: false      // a reply of hers is on its way (from here)
    property bool down: false          // TAYLOR is not answering (the panel says she is waking up)
    readonly property bool pinged: pingLine.shown
    readonly property real o: openT
    property real openT: open ? 1 : 0
    Behavior on openT { NumberAnimation { duration: ty.theme && ty.theme.still ? 200 : 340; easing.type: Easing.OutCubic } }

    // ---- sizes, from her preview's numbers times the dock's own scale ----
    readonly property real sw: screen ? screen.width : 1920
    readonly property real sh: screen ? screen.height : 1080
    readonly property real s: Math.max(1, Math.min(1.5, sh / 864))
    readonly property var sp: Dial.spot(sw, sh)
    readonly property real pw: 400 * s
    readonly property real ph: Math.min(560 * s, sh - 60 * s)
    readonly property real gapToDial: sp.r * 1.62 + 24 * s
    readonly property bool onRight: sp.x - gapToDial - pw < 12 * s
    readonly property real px: onRight ? Math.min(sw - pw - 12 * s, sp.x + gapToDial) : sp.x - gapToDial - pw
    readonly property real py: Math.max(20 * s, Math.min(sh - ph - 20 * s, sp.y - ph / 2))

    // ---- the conversation ----
    property var msgs: []              // {me, text, tag, priv}
    property int rev: 0
    property bool privateOn: false
    property string view: "day"        // day | chat
    property var day: null             // {cover, head, detail, cards, needs}
    property int seq: 0
    property int liveId: -1
    property bool historyAsked: false
    property int seen: 0               // how many were waiting when she last opened her

    // a reply that will not come: her line instead, so she is never left waiting on "thinking"
    function endLive(line) {
        const m = msgs[msgs.length - 1];
        if (!m || !m.live) return;
        m.live = false; m.text = m.text || line; m.tag = ""; thinking = false; rev++;
    }
    Timer { id: replyGuard; interval: 330000; onTriggered: ty.endLive("That took too long, so I stopped waiting. Ask me again?") }
    function send(text) {
        text = String(text || "").trim();
        if (!text || thinking) return;
        if (down) {
            msgs.push({ me: true, text: text });
            msgs.push({ me: false, text: "I'm still waking up. Try me again in a moment.", tag: "" });
            rev++; view = "chat";
            console.info("taylor-panel: a message while TAYLOR is not answering");
            return;
        }
        replyGuard.restart();
        msgs.push({ me: true, text: text });
        msgs.push({ me: false, text: "", tag: "", live: true, stage: "" });
        rev++;
        view = "chat";
        thinking = true;
        liveId = ++seq;
        link.write(JSON.stringify({ op: "chat", id: liveId, text: text, private: privateOn }) + "\n");
        console.info("taylor-panel: a message went to TAYLOR" + (privateOn ? " (private)" : ""));
    }
    function got(line) {
        let j;
        try { j = JSON.parse(line); } catch (e) { return; }
        if (j.type === "ready") { down = false; console.info("taylor-panel: connected to TAYLOR"); if (open) refresh(); return; }
        if (j.type === "down") { down = true; console.info("taylor-panel: TAYLOR is not answering yet"); return; }
        if (j.type === "home") { if (j.ok) day = j; return; }
        if (j.type === "history") {
            if (j.ok) { msgs = j.turns.slice(-30).concat(msgs); rev++; }
            return;
        }
        if (j.id !== liveId) return;
        const m = msgs[msgs.length - 1];
        if (!m || !m.live) return;
        if (j.type === "token") m.text += j.text;
        else if (j.type === "reset") m.text = "";
        else if (j.type === "stage") m.stage = j.text;
        else if (j.type === "done") { m.live = false; m.tag = j.tag; m.priv = !!j.private; thinking = false; console.info("taylor-panel: her reply came (" + j.tag + ")"); }
        else if (j.type === "failed") { m.live = false; m.text = m.text || "I couldn't answer that just now. Try me again in a moment."; m.tag = ""; thinking = false; console.info("taylor-panel: the reply failed"); }
        rev++;
    }
    function refresh() {
        link.write(JSON.stringify({ op: "home" }) + "\n");
        if (!historyAsked) { historyAsked = true; link.write(JSON.stringify({ op: "history", n: 20 }) + "\n"); }
    }
    function show() {
        if (open) return;
        if (wants) consumeWants();
        open = true;
        refresh();
        console.info("taylor-panel: open");
    }
    function hide() {
        if (!open) return;
        open = false;
        console.info("taylor-panel: closed");
    }
    function ask(text) { show(); send(text); }
    // what she wanted is her first message (her brief); it comes from her Home: the Needs you line, else its cover line
    function consumeWants() {
        wants = false;
        seen = waiting;
        pingLine.shown = false;
        const d = day;
        const what = d && d.needs && d.needs.text ? d.needs.text : (d && d.cover ? d.cover : "");
        msgs.push({ me: false, text: "Got a sec? " + (what || "Something's waiting for you on My day."), tag: "instant" });
        rev++;
        view = "chat";
        console.info("taylor-panel: what she wanted is shown first");
    }
    onWaitingChanged: {
        if (waiting < seen) seen = waiting;
        if (waiting > seen && !open) {
            wants = true;
            link.write(JSON.stringify({ op: "home" }) + "\n");
            pingLine.shown = true;
            pingTimer.restart();
            console.info("taylor-panel: she wants Jessica (" + waiting + " waiting)");
        } else if (waiting <= seen) wants = false;
    }
    Timer { id: pingTimer; interval: 9000; onTriggered: pingLine.shown = false }

    Process {
        id: link
        running: true
        stdinEnabled: true
        command: ["/usr/bin/python3", "-I", Quickshell.env("TAYLOR_TALK") || "/usr/libexec/taylor-talk"]
        stdout: SplitParser { onRead: (line) => ty.got(line) }
        stderr: SplitParser { onRead: (line) => console.info("taylor-panel: link: " + line.slice(0, 160)) }
        onExited: (code) => {
            console.info("taylor-panel: the link ended (" + code + "), starting it again");
            ty.down = true;
            ty.endLive("I lost my line for a moment. Try me again in a few seconds.");
            relink.restart();
        }
    }
    Timer { id: relink; interval: 3000; onTriggered: link.running = true }

    // ---- the specks: out of her ring into the panel's area, and back on close ----
    property real speckT0: 0
    property bool specksBack: false
    property var specks: []
    function makeSpecks(n) {
        const out = [];
        for (let i = 0; i < n; i++) {
            const a = i / n * 6.2832 + Math.random() * 0.2;
            out.push({ a: a, tx: px + Math.random() * pw, ty: py + Math.random() * ph, d: 520 + Math.random() * 200, delay: Math.random() * 200 });
        }
        return out;
    }
    onOpenChanged: {
        if (theme && theme.still) return;
        specks = makeSpecks(open ? 38 : 26);
        specksBack = !open;
        speckT0 = Date.now();
        overlay.reveal = open ? 0 : 1;
        if (open) revealRun.restart();
    }
    SequentialAnimation {
        id: revealRun
        PauseAnimation { duration: 300 }
        NumberAnimation { target: overlay; property: "reveal"; from: 0; to: 1; duration: 560; easing.type: Easing.OutCubic }
    }

    // ---- her sky over the windows, at 85%: the windows look faded to about 15% ----
    LazyLoader {
        active: ty.o > 0.001
        Sky {
            screen: ty.screen
            theme: ty.theme
            color: "transparent"
            contentItem.opacity: 0.85 * ty.o
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "taylor-panel-sky"
        }
    }

    PanelWindow {
        id: overlay
        screen: ty.screen
        visible: ty.o > 0.001 || ty.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "taylor-panel"
        WlrLayershell.keyboardFocus: ty.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        property real reveal: 1

        // a click anywhere else closes her
        MouseArea { anchors.fill: parent; onPressed: ty.hide() }

        // her dial, again, over the faded windows; its glint while she wants Jessica; the specks
        Canvas {
            id: art
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const x = getContext("2d");
                x.reset();
                const T = Date.now() / 1000, th = ty.thinking || ty.thinkingElsewhere;
                Dial.setColors(ty.theme.accent, ty.theme.text, ty.theme.text2);
                x.globalAlpha = 1;
                const rot = ty.theme.still ? Dial.arcAngle() : Dial.arcAngle() + (th ? T * 1.6 : 0);
                x.save(); x.globalAlpha = ty.o;
                Dial.draw(x, ty.sp.x, ty.sp.y, ty.sp.r, ty.o, 1, 1, th ? 0.6 : 0, rot, ty.theme.still ? 0 : T);
                x.restore();
                if (Prefs.statusLine) Dial.words(x, ty.sp.x, ty.sp.y + 118 * ty.sp.k, ty.sp.k, ty.o, Math.round(11 * ty.sp.k) + "px " + ty.theme.sans, ty.status);
                // the specks
                if (ty.specks.length && !ty.theme.still) {
                    const e = Date.now() - ty.speckT0;
                    let any = false;
                    x.fillStyle = ty.theme.accent;
                    for (const p of ty.specks) {
                        const u = (e - p.delay) / p.d;
                        if (u < 0) { any = true; continue; }
                        if (u > 1) continue;
                        any = true;
                        const R = ty.sp.r * 1.4;
                        const sx = ty.sp.x + Math.cos(p.a) * R, sy = ty.sp.y + Math.sin(p.a) * R;
                        const k = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
                        const f = ty.specksBack ? [p.tx, p.ty, sx, sy] : [sx, sy, p.tx, p.ty];
                        const cx = f[0] + (f[2] - f[0]) * k, cy = f[1] + (f[3] - f[1]) * k;
                        x.globalAlpha = (u < 0.18 ? u / 0.18 : 1 - (u - 0.18) / 0.82);
                        const r = 2.2 * ty.s * (1 - 0.5 * u);
                        x.beginPath(); x.arc(cx, cy, r * 2.4, 0, 6.2832); x.globalAlpha *= 0.25; x.fill();
                        x.globalAlpha = Math.min(1, x.globalAlpha * 4); x.beginPath(); x.arc(cx, cy, r, 0, 6.2832); x.fill();
                    }
                    if (!any) ty.specks = [];
                    x.globalAlpha = 1;
                }
                // the sweep: a glowing line across the panel from the side nearest her
                const rv = overlay.reveal;
                if (ty.open && rv > 0 && rv < 1 && !ty.theme.still) {
                    const lx = ty.onRight ? ty.px + ty.pw * rv : ty.px + ty.pw * (1 - rv);
                    x.globalAlpha = 1 - 0.8 * rv; x.fillStyle = ty.theme.accent;
                    x.shadowColor = ty.theme.accent; x.shadowBlur = 16 * ty.s;
                    x.fillRect(lx - 1 * ty.s, ty.py, 2 * ty.s, ty.ph);
                    x.shadowBlur = 0; x.globalAlpha = 1;
                }
            }
        }
        FrameAnimation { running: overlay.visible; onTriggered: art.requestPaint() }

        // the panel, revealed from the side nearest her
        Item {
            id: clipBox
            x: ty.onRight ? ty.px : ty.px + ty.pw * (1 - (ty.theme.still ? 1 : overlay.reveal))
            y: ty.py
            width: ty.pw * (ty.theme.still ? 1 : overlay.reveal)
            height: ty.ph
            clip: true
            opacity: ty.theme.still ? ty.o : 1
            visible: ty.open || ty.o > 0.01
            MouseArea { anchors.fill: parent }       // a click inside the panel does not close it

            Rectangle {
                id: card
                x: ty.onRight ? 0 : -(clipBox.x - ty.px)
                width: ty.pw; height: ty.ph
                radius: 18 * ty.s
                color: ty.theme.panel
                border.color: ty.theme.line; border.width: 1
                opacity: ty.open ? 1 : ty.o

                Column {
                    id: col
                    anchors { fill: parent; leftMargin: 16 * ty.s; rightMargin: 16 * ty.s; topMargin: 14 * ty.s; bottomMargin: 14 * ty.s }
                    spacing: 0

                    // ---- the top row ----
                    Item {
                      id: topRow
                      width: parent.width; height: 32 * ty.s
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TAYLOR"; font.family: ty.theme.sans; font.weight: Font.DemiBold; font.pixelSize: 11 * ty.s
                        font.letterSpacing: 0.3 * 11 * ty.s; color: ty.theme.muted
                      }
                      Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8 * ty.s
                        Text {
                            id: stText
                            anchors.verticalCenter: parent.verticalCenter
                            text: ty.down ? "waking up" : ty.thinking ? "thinking" : "ready"
                            font.family: ty.theme.mono; font.pixelSize: 11 * ty.s
                            color: ty.thinking ? ty.theme.accent : ty.theme.muted
                        }
                        TyButton {
                            id: dayBtn
                            anchors.verticalCenter: parent.verticalCenter
                            s: ty.s; theme: ty.theme
                            label: ty.view === "day" && ty.msgs.length ? "Back to chat" : "My day"
                            visible: ty.msgs.length > 0
                            onHit: { ty.view = ty.view === "day" ? "chat" : "day"; if (ty.view === "day") ty.refresh(); }
                        }
                        TyButton {
                            id: closeBtn
                            anchors.verticalCenter: parent.verticalCenter
                            s: ty.s; theme: ty.theme; label: "×"; square: true
                            onHit: ty.hide()
                        }
                      }
                    }

                    // ---- My day ----
                    Column {
                        id: dayView
                        visible: ty.view === "day" || ty.msgs.length === 0
                        width: parent.width
                        topPadding: 12 * ty.s; bottomPadding: 8 * ty.s
                        spacing: 12 * ty.s
                        Text {
                            width: parent.width; horizontalAlignment: Text.AlignHCenter
                            text: ty.down ? "SHE'S WAKING UP." : ty.wants || (ty.waiting > 0) ? (ty.waiting > 1 ? ty.waiting + " THINGS ARE WAITING." : "1 THING IS WAITING.") : "ALL CLEAR."
                            font.family: ty.theme.sans; font.pixelSize: 11 * ty.s; font.letterSpacing: 0.3 * 11 * ty.s; color: ty.theme.muted
                        }
                        Column {
                            width: parent.width; spacing: 4 * ty.s
                            visible: !!(ty.day && ty.day.head)
                            Text {
                                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                                text: ty.day ? ty.day.head : ""; font.family: ty.theme.sans; font.weight: Font.Medium; font.pixelSize: 26 * ty.s; color: ty.theme.text
                            }
                            Text {
                                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                                text: ty.day ? ty.day.detail : ""; font.family: ty.theme.sans; font.pixelSize: 13 * ty.s; color: ty.theme.text2
                            }
                        }
                        Row {
                            width: parent.width; spacing: 8 * ty.s
                            visible: !!(ty.day && ty.day.cards && ty.day.cards.length)
                            Repeater {
                                model: ty.day && ty.day.cards ? ty.day.cards : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: (col.width - 8 * ty.s) / 2; height: 64 * ty.s
                                    radius: 10 * ty.s; color: "transparent"; border.color: ty.theme.line; border.width: 1
                                    Text { x: 12 * ty.s; y: 10 * ty.s; text: String(modelData.label).toUpperCase(); font.family: ty.theme.sans; font.pixelSize: 10 * ty.s; font.letterSpacing: 0.2 * 10 * ty.s; color: ty.theme.muted }
                                    Text { x: 12 * ty.s; anchors.bottom: parent.bottom; anchors.bottomMargin: 10 * ty.s; width: parent.width - 24 * ty.s; elide: Text.ElideRight
                                           text: modelData.value; font.family: ty.theme.sans; font.pixelSize: 13 * ty.s; color: ty.theme.text }
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: ty.theme.line; visible: needsRow.visible }
                        Row {
                            id: needsRow
                            width: parent.width; spacing: 10 * ty.s
                            visible: !!(ty.day && ty.day.needs)
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "NEEDS YOU"; font.family: ty.theme.sans; font.pixelSize: 10 * ty.s; font.letterSpacing: 0.2 * 10 * ty.s; color: ty.theme.muted }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 90 * ty.s - openBtn.width; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                                text: ty.day && ty.day.needs ? ty.day.needs.text : ""; font.family: ty.theme.sans; font.pixelSize: 13 * ty.s; color: ty.theme.text; lineHeight: 1.15
                            }
                            TyButton { id: openBtn; anchors.verticalCenter: parent.verticalCenter; s: ty.s; theme: ty.theme; label: "Open"; onHit: ty.view = "chat" }
                        }
                    }

                    // ---- the conversation ----
                    ListView {
                        id: list
                        visible: !dayView.visible
                        width: parent.width
                        height: card.height - 28 * ty.s - topRow.height - inRow.height - (dayView.visible ? dayView.height : 0)
                        clip: true
                        spacing: 14 * ty.s
                        topMargin: 10 * ty.s; bottomMargin: 14 * ty.s
                        model: { ty.rev; return ty.msgs.length; }
                        onCountChanged: Qt.callLater(() => list.positionViewAtEnd())
                        Connections { target: ty; function onRevChanged() { Qt.callLater(() => list.positionViewAtEnd()); } }
                        delegate: Item {
                            required property int index
                            readonly property var m: { const o = ty.msgs[index] || { me: false, text: "" }; return { me: !!o.me, text: String(o.text || ""), tag: String(o.tag || ""), priv: !!o.priv, live: !!o.live, r: ty.rev }; }
                            width: list.width
                            height: m.me ? bubble.height : mine.height
                            Rectangle {
                                id: bubble
                                visible: m.me
                                anchors.right: parent.right
                                width: Math.min(list.width * 0.82, meText.implicitWidth + 26 * ty.s)
                                height: meText.implicitHeight + 18 * ty.s
                                radius: 16 * ty.s
                                color: ty.theme.alpha(ty.theme.accent, 0.16); border.color: ty.theme.alpha(ty.theme.accent, 0.3); border.width: 1
                                TextEdit {
                                    id: meText
                                    x: 13 * ty.s; y: 9 * ty.s; width: Math.min(list.width * 0.82 - 26 * ty.s, implicitWidth)
                                    readOnly: true; selectByMouse: true; wrapMode: Text.Wrap
                                    text: m.me ? m.text : ""; font.family: ty.theme.sans; font.pixelSize: 14 * ty.s; color: ty.theme.text
                                }
                            }
                            Column {
                                id: mine
                                visible: !m.me
                                width: parent.width
                                spacing: 6 * ty.s
                                TextEdit {
                                    width: parent.width; visible: text.length > 0
                                    readOnly: true; selectByMouse: true; wrapMode: Text.Wrap
                                    text: !m.me ? m.text : ""; font.family: ty.theme.sans; font.pixelSize: 14 * ty.s; color: ty.theme.text
                                }
                                Row {          // thinking: three dots until her words come
                                    visible: !!m.live && !m.text
                                    spacing: 5 * ty.s
                                    Repeater {
                                        model: 3
                                        delegate: Rectangle {
                                            required property int index
                                            width: 6 * ty.s; height: 6 * ty.s; radius: 3 * ty.s; color: ty.theme.accent
                                            SequentialAnimation on opacity {
                                                running: !ty.theme.still; loops: Animation.Infinite
                                                PauseAnimation { duration: index * 180 }
                                                NumberAnimation { from: 1; to: 0.25; duration: 550 }
                                                NumberAnimation { from: 0.25; to: 1; duration: 550 }
                                            }
                                        }
                                    }
                                }
                                Row {          // the tag: which part answered
                                    visible: !!m.tag
                                    spacing: 6 * ty.s
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 5 * ty.s; height: 5 * ty.s; radius: 2.5 * ty.s; color: m.priv || /private/.test(m.tag || "") ? ty.theme.accent : ty.theme.muted }
                                    Text { text: m.tag || ""; font.family: ty.theme.mono; font.pixelSize: 11 * ty.s; color: ty.theme.muted }
                                }
                            }
                        }
                    }
                    Item { width: 1; height: dayView.visible ? Math.max(0, card.height - 28 * ty.s - topRow.height - dayView.height - inRow.height) : 0 }

                    // ---- the input row ----
                    Rectangle {
                        id: inRow
                        width: parent.width; height: 50 * ty.s
                        radius: 16 * ty.s
                        color: ty.theme.window
                        border.width: 1; border.color: input.activeFocus ? ty.theme.accent : ty.theme.dim
                        Row {
                            anchors { left: parent.left; leftMargin: 8 * ty.s; verticalCenter: parent.verticalCenter }
                            spacing: 2 * ty.s
                            TyIcon { s: ty.s; theme: ty.theme; kind: "mic" }
                            TyIcon { s: ty.s; theme: ty.theme; kind: "spk" }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: privText.implicitWidth + 20 * ty.s; height: 28 * ty.s; radius: 14 * ty.s
                                color: ty.privateOn ? ty.theme.alpha(ty.theme.accent, 0.14) : "transparent"
                                border.width: 1; border.color: ty.privateOn ? ty.theme.accent : ty.theme.dim
                                Text { id: privText; anchors.centerIn: parent; text: "Private"; font.family: ty.theme.sans; font.pixelSize: 12 * ty.s; color: ty.privateOn ? ty.theme.accent : ty.theme.muted }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ty.privateOn = !ty.privateOn; console.info("taylor-panel: private " + (ty.privateOn ? "on" : "off")); } }
                            }
                        }
                        TextInput {
                            id: input
                            anchors { left: parent.left; leftMargin: 8 * ty.s + 2 * 34 * ty.s + privText.implicitWidth + 32 * ty.s; right: sendBtn.left; rightMargin: 8 * ty.s; verticalCenter: parent.verticalCenter }
                            font.family: ty.theme.sans; font.pixelSize: 14 * ty.s; color: ty.theme.text
                            selectionColor: ty.theme.alpha(ty.theme.accent, 0.4)
                            clip: true
                            focus: ty.open
                            Text { visible: !input.text; text: "Talk to me..."; font: input.font; color: ty.theme.muted }
                            Keys.onReturnPressed: { ty.send(input.text); input.text = ""; }
                            Keys.onEnterPressed: { ty.send(input.text); input.text = ""; }
                            Keys.onEscapePressed: ty.hide()
                        }
                        Rectangle {
                            id: sendBtn
                            anchors { right: parent.right; rightMargin: 8 * ty.s; verticalCenter: parent.verticalCenter }
                            width: 34 * ty.s; height: 34 * ty.s; radius: 17 * ty.s
                            color: ty.theme.accent
                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    const x = getContext("2d"); x.reset();
                                    const c = width / 2, k = width / 34;
                                    x.strokeStyle = ty.theme.accentInk; x.lineWidth = 1.8 * k; x.lineCap = "round"; x.lineJoin = "round";
                                    x.beginPath(); x.moveTo(c, c + 7 * k); x.lineTo(c, c - 7 * k); x.moveTo(c - 6 * k, c - 1 * k); x.lineTo(c, c - 7 * k); x.lineTo(c + 6 * k, c - 1 * k); x.stroke();
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ty.send(input.text); input.text = ""; input.forceActiveFocus(); } }
                        }
                    }
                }
                Keys.onEscapePressed: ty.hide()
            }
        }
        Item { anchors.fill: parent; focus: ty.open; Keys.onEscapePressed: ty.hide() }
    }

    // ---- "TAYLOR · Got a sec?" above the clock, over the windows, for about 9 s ----
    PanelWindow {
        id: pingLine
        screen: ty.screen
        property bool shown: false
        property real t: shown ? 1 : 0
        Behavior on t { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        visible: t > 0.01
        anchors { bottom: true; right: true }
        margins { bottom: 74; right: 16 }
        implicitWidth: pill.width; implicitHeight: 30 + 8
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "taylor-ping"
        Rectangle {
            id: pill
            y: 8 * (1 - pingLine.t)
            opacity: pingLine.t
            width: pingRow.implicitWidth + 26; height: 30; radius: 15
            color: ty.theme.panel; border.color: ty.theme.line; border.width: 1
            Row {
                id: pingRow
                anchors.centerIn: parent; spacing: 8
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: ty.theme.accent }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "TAYLOR · Got a sec?"; font.family: ty.theme.sans; font.pixelSize: 13; color: ty.theme.text }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ty.show() }
        }
    }
}
