// The hook to the real TAYLOR (her request, 2026-11-21: "implement TAYLOR into the OS"). TAYLOR is her own assistant,
// a separate program that runs on this PC as a local server at http://127.0.0.1:8080. This one file is the only place
// the desktop talks to it, so the real TAYLOR can be swapped in (or out) here alone.
//
//   GET  /desktop/state   (bearer token) -> {"up": true, "thinking": bool, "waiting": int, "since": unix time}
//   POST /desktop/ask     (bearer token) {"text": "..."} -> {"nonce": "..."}, then her page opens at /?ask=<nonce>
//                         and TAYLOR's page sends the text as her message.
//
// The token is read at run time from ~/.config/taylor/taylor.env (a line TAYLOR_TOKEN=...). It is never printed,
// logged or passed on a command line (the requests are made from here, not by a program whose arguments anyone can
// read). The log gets plain facts only: up or not, thinking or not, how many waiting, the nonce's length.
// While TAYLOR answers, the state is asked every 2 seconds; when the file or the server is not there, it stops quietly
// and asks again every 30 seconds. Nothing on the dial changes while TAYLOR is away: no error, no red.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: t
    readonly property string base: "http://127.0.0.1:8080"
    readonly property string envPath: (Quickshell.env("HOME") || "") + "/.config/taylor/taylor.env"

    property bool up: false
    property bool thinking: false
    property int waiting: 0
    property real since: 0

    property string token: ""
    readonly property bool hasToken: token.length > 0
    onHasTokenChanged: { console.info("taylor-hook: token file read:", hasToken); if (hasToken) poll.restart(); }
    onUpChanged: console.info("taylor-hook: TAYLOR answering:", up)
    onThinkingChanged: console.info("taylor-hook: thinking:", thinking)
    onWaitingChanged: console.info("taylor-hook: waiting:", waiting)

    function parse(s) {
        const lines = String(s || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].trim().match(/^(?:export\s+)?TAYLOR_TOKEN\s*=\s*(.*)$/);
            if (m) return m[1].trim().replace(/^["']|["']$/g, "");
        }
        return "";
    }
    FileView {
        id: envFile
        path: t.envPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: t.token = t.parse(text())
        onLoadFailed: t.token = ""
    }
    // the file may only appear later (TAYLOR installed or set up after she signed in): look again every 30 seconds
    Timer { interval: 30000; repeat: true; running: !t.hasToken; onTriggered: envFile.reload() }

    function down() { up = false; thinking = false; waiting = 0; }

    // one request at a time; a request that does not answer within 4 s counts as no answer
    property var busyReq: null
    Timer { id: giveUp; interval: 4000; onTriggered: { if (t.busyReq) { const r = t.busyReq; t.busyReq = null; r.abort(); t.down(); } } }
    function stateNow() {
        if (!hasToken) { down(); return; }
        if (busyReq) return;
        const r = new XMLHttpRequest();
        busyReq = r;
        r.onreadystatechange = function () {
            if (r.readyState !== XMLHttpRequest.DONE || t.busyReq !== r) return;
            t.busyReq = null; giveUp.stop();
            let j = null;
            if (r.status === 200) { try { j = JSON.parse(r.responseText); } catch (e) { j = null; } }
            if (!j || j.up === false) { t.down(); return; }
            t.up = true;
            t.thinking = j.thinking === true;
            t.waiting = Math.max(0, parseInt(j.waiting) || 0);
            t.since = Number(j.since) || 0;
        };
        r.open("GET", base + "/desktop/state");
        r.setRequestHeader("Authorization", "Bearer " + token);
        r.send();
        giveUp.restart();
    }
    Timer {
        id: poll
        interval: t.up ? 2000 : 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: t.stateNow()
    }

    // "Ask TAYLOR" from her launcher. If TAYLOR is not reachable her page opens plainly.
    // her window: the TAYLOR app when it is installed, else her page in the browser (/usr/libexec/taylor-open-app)
    function openPage(url) {
        const m = /[?&]ask=([A-Za-z0-9_-]+)/.exec(url);
        Quickshell.execDetached(["sh", "-c", "/usr/libexec/taylor-open-app \"$@\" 2>&1 | logger -t taylor-open-app", "sh"].concat(m ? ["--ask", m[1]] : []));
    }
    function ask(text) {
        const plainPage = () => { console.info("taylor-hook: TAYLOR not reachable; opening her page plainly"); openPage(base + "/"); };
        if (!hasToken) { plainPage(); return; }
        const r = new XMLHttpRequest();
        let done = false;
        const timer = Qt.createQmlObject('import QtQuick; Timer { interval: 5000 }', t);
        timer.triggered.connect(() => { if (!done) { done = true; r.abort(); plainPage(); } timer.destroy(); });
        r.onreadystatechange = function () {
            if (r.readyState !== XMLHttpRequest.DONE || done) return;
            done = true; timer.stop(); timer.destroy();
            let nonce = "";
            if (r.status === 200) { try { nonce = String(JSON.parse(r.responseText).nonce || ""); } catch (e) {} }
            if (!nonce) { plainPage(); return; }
            console.info("taylor-hook: ask sent; opening her page with its nonce (length " + nonce.length + ")");
            openPage(base + "/?ask=" + encodeURIComponent(nonce));
            t.stateNow();
        };
        r.open("POST", base + "/desktop/ask");
        r.setRequestHeader("Authorization", "Bearer " + token);
        r.setRequestHeader("Content-Type", "application/json");
        r.send(JSON.stringify({ text: String(text) }));
        timer.start();
    }
}
