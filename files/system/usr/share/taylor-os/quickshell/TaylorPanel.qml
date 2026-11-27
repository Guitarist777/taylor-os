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
// Her topics (2026-11-27, her report: "I clicked 'I have one thing to talk about' and she didn't say anything"): My day's
// Needs you row opens them one at a time, with the same taps as her page (Talk about it, Not now, Don't bring this up; Show
// for a covered one). Talk about it sends TAYLOR's fixed line the way her page does, so TAYLOR speaks first.
//
// Smoothness (2026-11-27, her report: "the animation is super laggy and buggy"): her screen runs at 240 Hz. The drawing over
// the windows used to be the whole screen, painted 240 times a second; it is now only the box around her dial and the
// panel, painted 60 times a second while something moves and 20 (her dial's own pace) otherwise. Her sky's copy is made once
// at start, not again on every open, and her dial here turns with the dial underneath (the same angle), so the two never
// show as two rings while she fades in.
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
    property real dialSpin: 0          // how far the dial underneath has turned (Dial.qml's spin): hers here turns with it

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
    // the conversation: a ListModel, so the list follows each change (it used to be a plain array, rebuilt on every word,
    // and "is there a conversation yet" never noticed a new message)
    ListModel { id: chat }             // {me, words, tag, priv, live}
    readonly property int count: chat.count
    property int rev: 0
    function lastInfo() { if (!chat.count) return ""; const m = chat.get(chat.count - 1); return (m.me ? "me" : "her") + "|" + (m.tag || "") + "|" + String(m.words || "").length; }
    function add(o) { chat.append({ me: !!o.me, words: String(o.text || ""), tag: String(o.tag || ""), priv: !!o.priv, live: !!o.live }); rev++; }
    function liveRow() { const i = chat.count - 1; return i >= 0 && chat.get(i).live ? i : -1; }
    // her topics (My day's Needs you row): one at a time
    property int topicAt: 0
    property var shownLine: ({})       // a covered topic's words once she pressed Show: id -> line
    property string topicBusy: ""      // the topic whose tap is on its way
    readonly property var topicItems: day && day.needs && day.needs.items ? day.needs.items : []
    readonly property var topicNow: topicItems.length ? topicItems[Math.min(topicAt, topicItems.length - 1)] : null
    property bool privateOn: false
    property string view: "day"        // day | chat
    property var day: null             // {cover, head, detail, cards, needs}
    property int seq: 0
    property int liveId: -1
    property bool historyAsked: false
    property int seen: 0               // how many were waiting when she last opened her

    // a reply that will not come: her line instead, so she is never left waiting on "thinking"
    function endLive(line) {
        const i = liveRow();
        if (i < 0) return;
        chat.setProperty(i, "live", false);
        if (!chat.get(i).words) chat.setProperty(i, "words", line);
        chat.setProperty(i, "tag", ""); thinking = false; rev++;
    }
    Timer { id: replyGuard; interval: 330000; onTriggered: ty.endLive("That took too long, so I stopped waiting. Ask me again?") }
    // opener: TAYLOR's own line from a topic she tapped (her page's launchTopicOpening): it goes as her turn, but no bubble of hers
    function send(text, opener) {
        text = String(text || "").trim();
        if (!text || thinking) return;
        if (down) {
            if (!opener) add({ me: true, text: text });
            add({ me: false, text: "I'm still waking up. Try me again in a moment." });
            view = "chat";
            console.info("taylor-panel: a message while TAYLOR is not answering");
            return;
        }
        replyGuard.restart();
        if (!opener) add({ me: true, text: text });
        add({ me: false, text: "", live: true });
        view = "chat";
        thinking = true;
        liveId = ++seq;
        link.write(JSON.stringify({ op: "chat", id: liveId, text: text, private: privateOn }) + "\n");
        console.info("taylor-panel: " + (opener ? "a topic went to TAYLOR (she speaks first)" : "a message went to TAYLOR") + (privateOn ? " (private)" : ""));
    }
    function got(line) {
        let j;
        try { j = JSON.parse(line); } catch (e) { return; }
        if (j.type === "ready") { down = false; console.info("taylor-panel: connected to TAYLOR"); if (open) refresh(); return; }
        if (j.type === "down") { down = true; console.info("taylor-panel: TAYLOR is not answering yet"); return; }
        if (j.type === "home") { if (j.ok) { day = j; if (topicAt >= topicItems.length) topicAt = 0; if (view === "topic" && !topicItems.length) view = "day"; } return; }
        if (j.type === "history") {
            if (j.ok) {
                const turns = j.turns.slice(-30);
                for (let k = 0; k < turns.length; k++) {
                    const t = turns[k];
                    chat.insert(k, { me: !!t.me, words: String(t.text || ""), tag: String(t.tag || ""), priv: false, live: false });
                }
                rev++;
            }
            return;
        }
        if (j.type === "topic") { gotTopic(j); return; }
        if (j.id !== liveId) return;
        const i = liveRow();
        if (i < 0) return;
        if (j.type === "token") chat.setProperty(i, "words", chat.get(i).words + j.text);
        else if (j.type === "reset") chat.setProperty(i, "words", "");
        else if (j.type === "stage") return;
        else if (j.type === "done") { chat.setProperty(i, "live", false); chat.setProperty(i, "tag", String(j.tag || "")); chat.setProperty(i, "priv", !!j.private); thinking = false; console.info("taylor-panel: her reply came (" + j.tag + ")"); }
        else if (j.type === "failed") { chat.setProperty(i, "live", false); if (!chat.get(i).words) chat.setProperty(i, "words", "I couldn't answer that just now. Try me again in a moment."); chat.setProperty(i, "tag", ""); thinking = false; console.info("taylor-panel: the reply failed"); }
        rev++;
    }
    // ---- her topics ----
    function openTopics() {
        if (topicItems.length) { topicAt = 0; view = "topic"; console.info("taylor-panel: her topics shown (" + topicItems.length + ")"); }
        else view = "chat";
    }
    function topicTap(act) {
        const t = topicNow;
        if (!t || topicBusy) return;
        if (act === "talk" && thinking) return;          // a reply is still on its way: not a second turn on top of it
        topicBusy = t.id;
        link.write(JSON.stringify({ op: "topic", id: t.id, act: act }) + "\n");
        console.info("taylor-panel: topic " + act);
    }
    function gotTopic(j) {
        topicBusy = "";
        if (j.act === "reveal") {
            if (j.ok) { const m = Object.assign({}, shownLine); m[j.id] = j.line; shownLine = m; }
            return;
        }
        if (!j.ok) { console.info("taylor-panel: topic " + j.act + " did not go through"); topicFail = j.act; return; }
        topicFail = "";
        if (j.act === "talk") { view = "chat"; send(j.line, true); }
        else if (j.act === "got_it" || j.act === "not_now" || j.act === "dismiss") { if (topicItems.length <= 1) view = "day"; }
        link.write(JSON.stringify({ op: "home" }) + "\n");    // the topic is closed on her Home: fetch the row again
    }
    property string topicFail: ""
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
    // where each named control is on the screen (the virtual PC clicks there for real): "name x y" per line
    function places() {
        const out = [];
        const walk = (it) => {
            for (let i = 0; i < it.children.length; i++) {
                const c = it.children[i];
                if (!c.visible) continue;
                if (c.placeName) { const p = c.mapToItem(null, c.width / 2, c.height / 2); out.push(c.placeName + " " + Math.round(p.x) + " " + Math.round(p.y)); }
                if (["dots", "row", "inrow", "list"].indexOf(c.objectName) >= 0) { const p = c.mapToItem(null, 0, 0); out.push(c.objectName + " " + Math.round(p.x) + " " + Math.round(p.y) + " " + Math.round(c.width) + " " + Math.round(c.height)); }
                walk(c);
            }
        };
        walk(overlay.contentItem);
        return out.join("\n");
    }
    // what she wanted is her first message (her brief); it comes from her Home: the Needs you line, else its cover line
    function consumeWants() {
        wants = false;
        seen = waiting;
        pingLine.shown = false;
        const d = day;
        const what = d && d.needs && d.needs.text ? d.needs.text : (d && d.cover ? d.cover : "");
        add({ me: false, text: "Got a sec? " + (what || "Something's waiting for you on My day."), tag: "instant" });
        view = topicItems.length ? "topic" : "chat";
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
    Sky {
        screen: ty.screen
        theme: ty.theme
        visible: ty.o > 0.001          // made once at start; opening only shows it (it used to be built again on every open)
        color: "transparent"
        contentItem.opacity: 0.85 * ty.o
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "taylor-panel-sky"
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
            // only the box around her dial (with its line under it) and the panel, not the whole screen
            readonly property real pad: 28 * ty.s
            readonly property real ext: ty.sp.r * 1.75 + 8 * ty.s
            readonly property real bx: Math.max(0, Math.min(ty.px, ty.sp.x - ext) - pad)
            readonly property real by: Math.max(0, Math.min(ty.py, ty.sp.y - ext) - pad)
            x: bx; y: by
            width: Math.min(ty.sw, Math.max(ty.px + ty.pw, ty.sp.x + ext) + pad) - bx
            height: Math.min(ty.sh, Math.max(ty.py + ty.ph, ty.sp.y + Math.max(ext, 136 * ty.sp.k)) + pad) - by
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const x = getContext("2d");
                x.reset();
                x.translate(-bx, -by);
                const T = Date.now() / 1000, th = ty.thinking || ty.thinkingElsewhere;
                Dial.setColors(ty.theme.accent, ty.theme.text, ty.theme.text2);
                x.globalAlpha = 1;
                const rot = ty.theme.still ? Dial.arcAngle() : Dial.arcAngle() + ty.dialSpin;     // the same angle as the dial underneath
                x.save(); x.globalAlpha = ty.o;
                Dial.draw(x, ty.sp.x, ty.sp.y, ty.sp.r, ty.o, 1, 1, th ? 0.6 : 0, rot, ty.theme.still ? 0 : T);
                x.restore();
                // thinking: her five dots swirl inside the ring, drawn here too (the same places as on the dial underneath),
                // so they are clear in front and not grey ghosts showing through the faded sky
                if (th && !ty.theme.still) {
                    const acc = ty.theme.accent, soft = ty.theme.soft, kk = ty.sp.k, RR = ty.sp.r;
                    const cols = [acc, ty.theme.mix(acc, soft, 0.5), soft];
                    for (let i = 0; i < 5; i++) {
                        const a = T * 3.4 + i * (6.2832 / 5) + 0.55 * Math.sin(T * 3.4 * 0.9 + i * 1.3);
                        x.globalAlpha = ty.o * (0.6 + 0.4 * Math.sin(T * 3 + i));
                        x.fillStyle = cols[i % 3];
                        const dr = 2.6 * kk * (0.8 + 0.3 * Math.sin(T * 2 + i * 2));
                        x.beginPath(); x.arc(ty.sp.x + Math.cos(a) * RR * 0.34, ty.sp.y + Math.sin(a) * RR * 0.34, dr, 0, 6.2832); x.fill();
                    }
                    x.globalAlpha = 1;
                }
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
        // 60 pictures a second while something moves (opening, the specks, the sweep, thinking), else 20 (her dial's own pace)
        readonly property bool moving: !ty.theme.still && (ty.o < 0.999 || ty.specks.length > 0 || (reveal > 0 && reveal < 1) || ty.thinking || ty.thinkingElsewhere)
        Timer { interval: overlay.moving ? 16 : 50; repeat: true; running: overlay.visible; onTriggered: art.requestPaint() }

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
                            placeName: "dayswitch"
                            anchors.verticalCenter: parent.verticalCenter
                            s: ty.s; theme: ty.theme
                            label: ty.view !== "chat" && ty.count ? "Back to chat" : "My day"
                            visible: ty.count > 0 || ty.view === "topic"
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
                        visible: ty.view === "day" || (ty.count === 0 && ty.view !== "topic")
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
                            TyButton { id: openBtn; placeName: "needsshow"; anchors.verticalCenter: parent.verticalCenter; s: ty.s; theme: ty.theme; label: ty.topicItems.length ? "Show" : "Open"; onHit: ty.openTopics() }
                        }
                    }

                    // ---- her topics, one at a time (her page's topicRow): the same taps, the same doors ----
                    Column {
                        id: topicView
                        visible: ty.view === "topic" && !!ty.topicNow
                        width: parent.width
                        topPadding: 14 * ty.s; bottomPadding: 8 * ty.s
                        spacing: 12 * ty.s
                        readonly property var t: ty.topicNow
                        readonly property bool card: !!t && (t.kind === "money" || t.kind === "week")
                        readonly property string words: !t ? "" : card ? t.line : (t.covered ? (ty.shownLine[t.id] || "") : t.line)
                        Row {
                            width: parent.width; spacing: 10 * ty.s
                            visible: ty.topicItems.length > 1
                            Text { anchors.verticalCenter: parent.verticalCenter; text: (Math.min(ty.topicAt, ty.topicItems.length - 1) + 1) + " of " + ty.topicItems.length; font.family: ty.theme.sans; font.pixelSize: 11 * ty.s; color: ty.theme.muted }
                            TyButton { anchors.verticalCenter: parent.verticalCenter; s: ty.s; theme: ty.theme; label: "Next"; placeName: "topicnext"; onHit: { ty.topicAt = (ty.topicAt + 1) % ty.topicItems.length; ty.topicFail = ""; } }
                        }
                        Text {
                            width: parent.width; visible: !!(topicView.t && topicView.t.helper) && !topicView.card
                            text: topicView.t && topicView.t.helper ? "From " + topicView.t.helper : ""
                            font.family: ty.theme.sans; font.pixelSize: 11 * ty.s; color: ty.theme.muted
                        }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap
                            text: topicView.words || (topicView.t ? topicView.t.covered_line || "I have something to ask you" : "")
                            font.family: ty.theme.sans; font.pixelSize: 16 * ty.s; color: ty.theme.text; lineHeight: 1.2
                        }
                        Repeater {
                            model: topicView.card && topicView.t.lines ? topicView.t.lines : []
                            delegate: Text { required property var modelData; width: topicView.width; wrapMode: Text.Wrap; text: modelData; font.family: ty.theme.sans; font.pixelSize: 13 * ty.s; color: ty.theme.text2 }
                        }
                        Flow {
                            width: parent.width; spacing: 8 * ty.s
                            opacity: ty.topicBusy ? 0.5 : 1
                            // a money or week card: one tap
                            TyButton { visible: topicView.card; s: ty.s; theme: ty.theme; placeName: "topicgotit"; label: topicView.t && topicView.t.taps && topicView.t.taps[0] ? topicView.t.taps[0] : "Got it"; onHit: ty.topicTap("got_it") }
                            // a covered topic: Show first (Don't bring this up works before she has looked)
                            TyButton { visible: !topicView.card && !topicView.words; s: ty.s; theme: ty.theme; placeName: "topicshow"; label: "Show"; onHit: ty.topicTap("reveal") }
                            TyButton { visible: !topicView.card && !!topicView.words; s: ty.s; theme: ty.theme; placeName: "topictalk"; label: topicView.t && topicView.t.taps && topicView.t.taps[0] ? topicView.t.taps[0] : "Talk about it"; onHit: ty.topicTap("talk") }
                            TyButton { visible: !topicView.card && !!topicView.words; s: ty.s; theme: ty.theme; placeName: "topicnotnow"; label: topicView.t && topicView.t.taps && topicView.t.taps[1] ? topicView.t.taps[1] : "Not now"; onHit: ty.topicTap("not_now") }
                            TyButton { visible: !topicView.card; s: ty.s; theme: ty.theme; placeName: "topicdismiss"; label: topicView.t && topicView.t.taps && topicView.t.taps[2] ? topicView.t.taps[2] : "Don't bring this up"; onHit: ty.topicTap("dismiss") }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap; visible: ty.topicFail !== ""
                            text: "Couldn't reach TAYLOR for that. Tap again."
                            font.family: ty.theme.sans; font.pixelSize: 12 * ty.s; color: ty.theme.muted
                        }
                    }

                    // ---- the conversation ----
                    ListView {
                        id: list
                        objectName: "list"
                        visible: !dayView.visible && !topicView.visible
                        width: parent.width
                        height: card.height - 28 * ty.s - topRow.height - inRow.height
                        clip: true
                        spacing: 14 * ty.s
                        topMargin: 10 * ty.s
                        footer: Item { width: 1; height: 22 * ty.s }     // room above the typing box (positionViewAtEnd counts a footer, not a margin)
                        model: chat
                        // it stays at the newest words while they come in, unless she has scrolled up to read
                        property bool stick: true
                        onMovementEnded: stick = atYEnd
                        onCountChanged: { stick = true; Qt.callLater(() => list.positionViewAtEnd()); }
                        onContentHeightChanged: if (stick) Qt.callLater(() => list.positionViewAtEnd())
                        onHeightChanged: if (stick) Qt.callLater(() => list.positionViewAtEnd())
                        onVisibleChanged: if (visible) { stick = true; Qt.callLater(() => list.positionViewAtEnd()); }
                        Connections { target: ty; function onRevChanged() { if (list.stick) Qt.callLater(() => list.positionViewAtEnd()); } }
                        delegate: Item {
                            required property int index
                            required property bool me
                            required property string words
                            required property string tag
                            required property bool priv
                            required property bool live
                            readonly property var m: ({ me: me, text: words, tag: tag, priv: priv, live: live })
                            objectName: "row"
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
                                Item {         // thinking: three dots until her words come, in a row of their own
                                    visible: !!m.live && !m.text
                                    width: parent.width; height: 24 * ty.s
                                    Row {
                                    objectName: "dots"
                                    anchors { left: parent.left; leftMargin: 2 * ty.s; top: parent.top; topMargin: 4 * ty.s }
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
                    Item { width: 1; height: dayView.visible || topicView.visible ? Math.max(0, card.height - 28 * ty.s - topRow.height - (dayView.visible ? dayView.height : topicView.height) - inRow.height) : 0 }

                    // ---- the input row ----
                    Rectangle {
                        id: inRow
                        objectName: "inrow"
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
