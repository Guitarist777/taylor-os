// Her app launcher and search (her mockup tayloros_step4_app_launcher_and_search.html). A click on TAYLOR's dial (or
// Windows key + Space) dims the desktop; the dial shrinks and slides up to become the icon of one search bar. Empty, the
// list shows what she opened last ("Recent"); typing narrows one plain list of her apps, files and folders, and the
// last row is always "Ask TAYLOR". Up / Down move, Enter opens, Escape (or a click outside) closes. Picking something
// closes the bar, the dial goes back to its spot and its line says what is happening ("OPENING STEAM.").
// Her mockup is a small picture of the desktop; here its lengths are multiplied by u = 1.6, the size at which her
// mockup's dock and mixer match the real ones. The dial's own move uses its real size and spot (dial_draw.js).
//
// Ask TAYLOR opens TAYLOR's page (as the dock's TAYLOR button does); the question is not carried into it yet.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "dial_draw.js" as Dial

PanelWindow {
    id: win
    property QtObject theme
    property real o: 0                // 0 shut .. 1 open (shell.qml eases it)
    property bool open: false
    property string status: "ALL CLEAR."
    property string preset: ""        // the preview's pictures: text typed into the box when it opens
    signal closeMe()
    signal picked(string line)        // the dial's line: "OPENING STEAM."
    signal toggleMixer()

    readonly property string taylorUrl: "https://home.tail0b45b7.ts.net/"
    readonly property real u: 1.6

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: o > 0.001 || open
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

    // her geometry (geo()): the bar, top centre, under the dock
    readonly property real bw: Math.min(400 * u, width * 0.6)
    readonly property real bx: (width - bw) / 2
    readonly property real by: 112
    readonly property bool shown: o > 0.86 && open

    // ---- what the list can hold ----
    property var recent: []           // [{k, n, id|path}], newest first; kept in her state folder
    property var fileHits: ({ q: "", list: [] })
    property var rows: []
    property int sel: 0

    readonly property string recentPath: (Quickshell.env("HOME") || "/tmp") + "/.local/state/taylor-os/launcher-recent.json"
    Process {
        id: readRecent
        running: true
        command: ["cat", win.recentPath]
        stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); if (Array.isArray(r)) win.recent = r; } catch (e) {} } }
    }
    Process { id: writeRecent }
    function remember(it) {
        const key = it.k + "|" + (it.id || it.path || it.n);
        const next = [{ k: it.k, n: it.n, id: it.id || "", path: it.path || "" }];
        for (let i = 0; i < recent.length && next.length < 8; i++)
            if (recent[i].k + "|" + (recent[i].id || recent[i].path || recent[i].n) !== key) next.push(recent[i]);
        recent = next;
        writeRecent.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", recentPath, JSON.stringify(next)];
        writeRecent.running = true;
    }

    function apps() {
        const out = [], all = DesktopEntries.applications.values;
        for (let i = 0; i < all.length; i++) { const e = all[i]; if (e && !e.noDisplay && e.name) out.push(e); }
        return out;
    }
    function appById(id) {
        const a = apps(), bare = id.replace(/\.desktop$/, "");
        for (let i = 0; i < a.length; i++) if (a[i].id === id || a[i].id === bare || a[i].id === bare + ".desktop") return a[i];
        return null;
    }
    // The app list arrives a moment after the desktop starts: show the list again when it does.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { if (win.open) win.render(); }
    }
    // Best first: a name that starts with what she typed, then one with a word that starts with it, then the rest.
    function rank(name, lo) {
        const n = name.toLowerCase(), at = n.indexOf(lo);
        if (at < 0) return -1;
        if (at === 0) return 0;
        return (" -_.(".indexOf(n[at - 1]) >= 0) ? 1 : 2;
    }

    // Files and folders in her home (four folders deep, hidden ones skipped), asked a moment after she stops typing.
    Process {
        id: findFiles
        property string forQ: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const tab = lines[i].indexOf("\t");
                    if (tab < 0) continue;
                    const path = lines[i].slice(tab + 1), name = path.slice(path.lastIndexOf("/") + 1);
                    list.push({ k: lines[i].slice(0, tab) === "d" ? "Folder" : "File", n: name, path: path });
                }
                win.fileHits = { q: findFiles.forQ, list: list };
                win.render();
            }
        }
    }
    Timer {
        id: findSoon
        interval: 150
        onTriggered: {
            const q = input.text.trim();
            if (!q) return;
            findFiles.running = false;
            findFiles.forQ = q;
            findFiles.command = ["sh", "-c",
                "q=$(printf '%s' \"$1\" | tr -d '[]*?\\\\'); [ -n \"$q\" ] || exit 0; " +
                "find \"$HOME\" -mindepth 1 -maxdepth 4 -name '.*' -prune -o -iname \"*$q*\" -printf '%y\\t%p\\n' 2>/dev/null | head -n 20",
                "sh", q];
            findFiles.running = true;
        }
    }

    function render() {
        const q = input.text.trim(), lo = q.toLowerCase(), list = [];
        if (!q) {
            for (let i = 0; i < recent.length && list.length < 4; i++) {
                const r = recent[i];
                if (r.k === "App") { const e = appById(r.id); if (e) list.push({ k: "App", n: e.name, id: e.id, entry: e }); }
                else if (r.k === "Mixer") list.push({ k: "App", n: "Mixer", id: "", mixer: true });
                else if (r.path) list.push({ k: r.k, n: r.n, path: r.path });
            }
            // nothing opened yet: a few of her everyday apps
            const starters = ["steam", "org.kde.dolphin", "kitty", "systemsettings"];
            for (let j = 0; j < starters.length && list.length < 4; j++) {
                const e = appById(starters[j]);
                if (e && !list.some(x => x.id === e.id)) list.push({ k: "App", n: e.name, id: e.id, entry: e });
            }
        } else {
            const found = [], a = apps();
            for (let i = 0; i < a.length; i++) {
                const r = rank(a[i].name, lo);
                if (r >= 0) found.push({ r: r, g: 0, it: { k: "App", n: a[i].name, id: a[i].id, entry: a[i] } });
            }
            const rm = rank("Mixer", lo);
            if (rm >= 0) found.push({ r: rm, g: 0, it: { k: "App", n: "Mixer", id: "", mixer: true } });
            if (fileHits.q === q)
                for (let f = 0; f < fileHits.list.length; f++) found.push({ r: rank(fileHits.list[f].n, lo), g: 1, it: fileHits.list[f] });
            // apps before files at the same rank; then shorter names, then A to Z
            found.sort((p, q2) => (p.r - q2.r) || (p.g - q2.g) || (p.it.n.length - q2.it.n.length) || p.it.n.localeCompare(q2.it.n));
            const seen = {};
            for (let i = 0; i < found.length && list.length < 5; i++) {
                const key = found[i].it.k + "|" + found[i].it.n;
                if (seen[key]) continue;
                seen[key] = true;
                list.push(found[i].it);
            }
            if (Prefs.askTaylor) list.push({ k: "TAYLOR", n: "Ask TAYLOR: “" + q + "”" });   // her Settings switch
        }
        rows = list;
        if (sel >= list.length) sel = list.length - 1;
        if (sel < 0) sel = 0;
    }

    function choose(it) {
        if (!it) return;
        let line;
        if (it.k === "TAYLOR") { Quickshell.execDetached(["xdg-open", taylorUrl]); line = "OPENING TAYLOR."; }
        else if (it.mixer) { toggleMixer(); line = "OPENING MIXER."; remember({ k: "Mixer", n: "Mixer" }); }
        else if (it.k === "App") {
            if (it.entry) it.entry.execute();
            line = it.n.length <= 14 ? "OPENING " + it.n.toUpperCase() + "." : "OPENING APP.";
            remember(it);
        } else {
            Quickshell.execDetached(["xdg-open", it.path]);
            line = "OPENING " + it.k.toUpperCase() + ".";
            remember(it);
        }
        console.info("taylor-launcher: " + line);
        picked(line);
        closeMe();
    }

    onOpenChanged: {
        if (open) {
            sel = 0;
            input.text = preset;
            render();
            focusSoon.start();
            renderLater.start();   // and once more, in case the app list was still arriving
            if (preset) findSoon.restart();
        } else {
            input.focus = false;
        }
    }
    Timer { id: focusSoon; interval: 260; onTriggered: input.forceActiveFocus() }
    Timer { id: renderLater; interval: 700; onTriggered: win.render() }

    // ---- the drawing: the dim, the bar growing, the dial on its way ----
    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        function rr(x, px, py, w, h, r) {
            x.beginPath(); x.moveTo(px + r, py); x.arcTo(px + w, py, px + w, py + h, r); x.arcTo(px + w, py + h, px, py + h, r);
            x.arcTo(px, py + h, px, py, r); x.arcTo(px, py, px + w, py, r); x.closePath();
        }
        onPaint: {
            const x = getContext("2d");
            x.reset();
            const e = win.sm(win.o), U = win.u, T = Date.now() / 1000;
            if (e <= 0) return;
            const sp = Dial.spot(width, height);
            x.globalAlpha = 0.34 * e; x.fillStyle = "#000"; x.fillRect(0, 0, width, height);
            const bwid = Math.max(46 * U, win.bw * e);
            x.globalAlpha = 0.97 * Math.min(1, e * 1.6); x.fillStyle = String(win.theme.panel); rr(x, win.bx, win.by, bwid, 44 * U, 12 * U); x.fill();
            x.globalAlpha = 0.6 * e; x.strokeStyle = "rgba(255,255,255,0.16)"; x.lineWidth = 1; rr(x, win.bx, win.by, bwid, 44 * U, 12 * U); x.stroke();
            // the dial: from her spot to the bar's icon, shrinking; its ticks, arcs and line fade on the way
            const px = sp.x + (win.bx + 23 * U - sp.x) * e, py = sp.y + (win.by + 22 * U - sp.y) * e;
            const R = sp.r + (12 * U - sp.r) * e, k = R / 30, ks = sp.k + (U - sp.k) * e;
            x.lineCap = "round"; x.strokeStyle = String(win.theme.accent);
            x.globalAlpha = 0.12 * (1 - e) + 0.05; x.lineWidth = 7 * k; x.beginPath(); x.arc(px, py, R, 0, 6.2832, false); x.stroke();
            x.globalAlpha = 0.95; x.lineWidth = 1.5 * ks; x.beginPath(); x.arc(px, py, R, 0, 6.2832, false); x.stroke();
            if (e < 1) {
                x.globalAlpha = 0.35 * (1 - e); x.lineWidth = ks; x.beginPath(); x.arc(px, py, R * 0.62, 0, 6.2832, false); x.stroke();
                x.strokeStyle = String(win.theme.text);
                for (let t2 = 0; t2 < 48; t2++) {
                    const an = -1.5708 + t2 / 48 * 6.2832, big = t2 % 4 === 0;
                    x.globalAlpha = (big ? 0.5 : 0.25) * (1 - e);
                    x.beginPath(); x.moveTo(px + Math.cos(an) * (R + 6 * k), py + Math.sin(an) * (R + 6 * k));
                    x.lineTo(px + Math.cos(an) * (R + (big ? 12 : 9) * k), py + Math.sin(an) * (R + (big ? 12 : 9) * k)); x.stroke();
                }
                x.strokeStyle = String(win.theme.accent); x.lineWidth = 2.5 * ks;
                const rot = Dial.arcAngle();
                for (let j = 0; j < 3; j++) {
                    const st = rot + j * 2.0944;
                    x.globalAlpha = 0.8 * (1 - e) * (0.85 + 0.15 * Math.sin(T * 0.8));
                    x.beginPath(); x.arc(px, py, R + 18 * k, st, st + 0.9, false); x.stroke();
                }
                Dial.words(x, sp.x, sp.y + 118 * sp.k, sp.k, 1 - e, Math.round(11 * sp.k) + "px " + win.theme.sans, win.status);
            }
            if (e > 0.2) { x.globalAlpha = e; x.fillStyle = String(win.theme.accent); x.beginPath(); x.arc(px, py, 2.2 * U, 0, 6.2832, false); x.fill(); }
            x.globalAlpha = 1;
        }
    }
    FrameAnimation { running: win.visible; onTriggered: art.requestPaint() }

    // a click anywhere outside the bar and the list closes it
    MouseArea { anchors.fill: parent; enabled: win.open; onClicked: win.closeMe() }

    // ---- the box she types in, and the list ----
    Item {
        anchors.fill: parent
        opacity: win.shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea { x: win.bx; y: win.by; width: win.bw; height: 44 * win.u }   // a click on the bar keeps it open
        TextInput {
            id: input
            x: win.bx + 46 * win.u; y: win.by + 6 * win.u
            width: win.bw - 60 * win.u; height: 32 * win.u
            verticalAlignment: TextInput.AlignVCenter
            color: win.theme.text
            selectionColor: win.theme.alpha(win.theme.accent, 0.4)
            font.family: win.theme.sans
            font.pixelSize: Math.round(15 * win.u)
            clip: true
            onTextChanged: { win.sel = 0; win.render(); findSoon.restart(); }
            Keys.onPressed: (ev) => {
                if (ev.key === Qt.Key_Down) { win.sel = Math.min(win.rows.length - 1, win.sel + 1); ev.accepted = true; }
                else if (ev.key === Qt.Key_Up) { win.sel = Math.max(0, win.sel - 1); ev.accepted = true; }
                else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { win.choose(win.rows[win.sel]); ev.accepted = true; }
                else if (ev.key === Qt.Key_Escape) { win.closeMe(); ev.accepted = true; }
            }
            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text.length === 0
                text: Prefs.askTaylor ? "Search apps, files, or ask TAYLOR" : "Search apps or files"
                color: win.theme.muted
                font: input.font
            }
        }

        Rectangle {
            id: box
            x: win.bx; y: win.by + 52 * win.u
            width: win.bw
            height: list.height + 12 * win.u
            radius: 12 * win.u
            color: win.theme.panel
            border.color: win.theme.line
            border.width: 1
            MouseArea { anchors.fill: parent }   // a click in the list (between rows) keeps it open
            Column {
                id: list
                x: 6 * win.u; y: 6 * win.u
                width: parent.width - 12 * win.u
                Text {
                    visible: input.text.trim().length === 0
                    text: "Recent"
                    color: win.theme.muted
                    font.family: win.theme.sans
                    font.pixelSize: Math.round(12 * win.u)
                    leftPadding: 10 * win.u; topPadding: 4 * win.u; bottomPadding: 6 * win.u
                }
                Repeater {
                    model: win.rows
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 30 * win.u
                        radius: 8 * win.u
                        color: index === win.sel ? win.theme.alpha(win.theme.accent, 0.18) : "transparent"
                        Text {
                            anchors { left: parent.left; leftMargin: 10 * win.u; right: kind.left; rightMargin: 12 * win.u; verticalCenter: parent.verticalCenter }
                            text: row.modelData.n
                            elide: Text.ElideRight
                            color: row.modelData.k === "TAYLOR" ? win.theme.soft : win.theme.text
                            font.family: win.theme.sans
                            font.pixelSize: Math.round(14 * win.u)
                        }
                        Text {
                            id: kind
                            anchors { right: parent.right; rightMargin: 10 * win.u; verticalCenter: parent.verticalCenter }
                            text: row.modelData.k
                            color: win.theme.muted
                            font.family: win.theme.sans
                            font.pixelSize: Math.round(12 * win.u)
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: win.sel = row.index
                            onClicked: win.choose(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
