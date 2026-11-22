//@ pragma IconTheme Slot-Dark-Icons
// TAYLOR OS desktop, from her mockup "7 · Dock your way + mixer widget" (the TAYLOR theme).
// Quickshell draws it on top of Hyprland: the live Horizon sky is the wallpaper, the clock card and mixer sit on the desktop (under windows),
// the dock floats at the top, the tray sits bottom right, TAYLOR's dial sits right of centre (her "login unlock to
// desktop" mockup). The "TAYLOR has a question" pill comes later, once TAYLOR runs on Linux.
//
// Her arrival (the same mockup): the first time the desktop starts after she signs in, it starts from the login's last
// picture (her night sky, the dial drawn) and lets it go, the dock drops in from the top, the clock card and mixer slide
// in from the left, the tray and "ALL CLEAR." fade in. A restart of the desktop in the same sign-in does not play it
// again (a mark in her runtime folder, gone when she signs out). TAYLOR_ARRIVE_AT=1.5 holds it at 1.5 seconds (the
// preview's pictures).
//
// Her launcher (Launcher.qml, her "app launcher and search" mockup) opens from a click on the dial, or from Windows key +
// Space (Hyprland runs "quickshell ipc call launcher toggle"). TAYLOR_LAUNCHER_PREVIEW=st opens it at start with "st"
// typed (the preview's pictures; "-" opens it empty).
//
// Her notifications (her design tour, part 5): the desktop is the notification service itself, and nothing pops up.
// Each one becomes a dot circling the dial (Dial.qml) and a green count by the clock (Tray.qml); a click on either shows
// the list (NoteList.qml). With none waiting the dial opens the launcher as before. At most five wait: a sixth sends the
// oldest away. Only counts go to the log, never what a notification says. A notification that carries a progress value
// (the "value" hint) is drawn as the filling ring by the clock (Progress.qml) instead of a dot.
//
// TAYLOR herself (Taylor.qml, the one hook to her assistant at 127.0.0.1:8080): while she is thinking the dial says
// "THINKING." and dots swirl inside it; what she has waiting is counted with the notifications ("2 NEW.") and is one
// line in the list (a click opens her page). Ask TAYLOR in the launcher hands the question to her. When TAYLOR is not
// running nothing changes on the dial.
// Loading (Loading.qml): circling dots by the pointer until an app she picked opens its window.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: root

    // Her colours (Theme.qml: the scheme she picks in Settings, live) and her settings (Prefs.qml).
    readonly property var c: Theme
    // Her main screen: TAYLOR, the dock, the clock, the mixer and the tray live here only (her brief: on the main
    // screen only; the sky covers every screen, and the lock covers every screen).
    readonly property var mainScreen: Quickshell.screens.length ? Quickshell.screens[0] : null

    property bool mixerShown: true

    // ---- her launcher ----
    readonly property string launcherPreview: Quickshell.env("TAYLOR_LAUNCHER_PREVIEW") || ""
    property bool launcherOpen: launcherPreview !== ""
    property real launcherO: launcherOpen ? 1 : 0
    Behavior on launcherO { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    property string dialStatus: "ALL CLEAR."
    property bool dialBusy: false
    property bool askThinking: false  // a moment after she asked TAYLOR from the launcher (her tour: think for 2.4 s)
    Timer { id: statusBack; interval: 2400; onTriggered: { root.dialStatus = "ALL CLEAR."; root.dialBusy = false; root.askThinking = false; } }

    // ---- TAYLOR herself ----
    Taylor { id: taylor }
    readonly property bool thinking: taylor.thinking || askThinking
    // her count: each notification waiting, plus everything TAYLOR has waiting (her one line stands for all of them)
    readonly property int waitingAll: { notesRev; return notes.filter((n) => n.st === "in" && !n.taylor).length + ((taylorNote && taylorNote.st === "in") ? taylor.waiting : 0); }
    // the line under her: what she just did, then a sequence's own word (GOODNIGHT.), then thinking, then what waits
    readonly property string dialLine: dialBusy && !askThinking ? dialStatus
        : dialStatus !== "ALL CLEAR." && !askThinking ? dialStatus
        : thinking ? "THINKING."
        : waitingAll === 1 ? "ONE NEW." : waitingAll > 1 ? waitingAll + " NEW." : "ALL CLEAR."
    onDialLineChanged: console.info("taylor-desktop: status " + dialLine)
    // what TAYLOR has waiting is one line in her list (and so one dot and part of the count)
    property var taylorNote: null
    property int taylorSeen: 0        // how many were waiting when she last opened them from the list
    function taylorWaiting() {
        const w = taylor.waiting;
        if (w < taylorSeen) taylorSeen = w;
        const show = w > taylorSeen;
        if (show && !(taylorNote && taylorNote.st === "in")) {
            const now = Date.now() / 1000;
            taylorNote = { id: ++noteSeq, t: "TAYLOR", b: "", st: "in", t0: now, src: null, taylor: true };
            notes.push(taylorNote);
            kickAt = now;
        } else if (!show && taylorNote && taylorNote.st === "in") {
            taylorNote.st = "fade"; taylorNote.t0 = Date.now() / 1000;
        }
        if (taylorNote && taylorNote.st === "in") taylorNote.b = w === 1 ? "1 thing waiting for you" : w + " things waiting for you";
        notesRev++;
    }
    Connections { target: taylor; function onWaitingChanged() { root.taylorWaiting(); } }
    IpcHandler {
        target: "taylor"
        function state(): string { return "up=" + taylor.up + " thinking=" + taylor.thinking + " waiting=" + taylor.waiting + " line=" + root.dialLine; }
        // the same as picking "Ask TAYLOR" in her launcher (for the checks)
        function ask(text: string): void { root.askThinking = true; root.dialBusy = true; statusBack.restart(); taylor.ask(text); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.launcherOpen = !root.launcherOpen; }
        function open(): void { root.launcherOpen = true; }
        function close(): void { root.launcherOpen = false; }
    }

    // ---- her notifications ----
    property var notes: []            // {id, t, b, st: in | fade | out, t0, src}; Dial and NoteList add their own drawing state
    property int notesRev: 0          // bumped whenever the list changes (a JS array does not say so itself)
    property int noteSeq: 0
    readonly property int notesWaiting: { notesRev; return notes.filter((n) => n.st === "in").length; }
    property real kickAt: 0
    property var whisper: null
    property bool listOpen: false
    property real listO: listOpen ? 1 : 0
    Behavior on listO { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    property real listShutAt: 0
    onNotesWaitingChanged: {
        console.info("taylor-notes:", notesWaiting, "waiting");
        if (notesWaiting === 0) listOpen = false;
    }
    onListOpenChanged: { if (!listOpen) listShutAt = Date.now(); console.info("taylor-notes: list", listOpen ? "open" : "shut"); }

    function plain(s) { return String(s || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(); }
    function noteDismiss(n) {
        if (!n || n.st !== "in") return;
        n.st = "fade"; n.t0 = Date.now() / 1000; notesRev++;
        if (n.taylor) { taylorSeen = taylor.waiting; taylor.openPage(taylor.base + "/"); console.info("taylor-notes: her TAYLOR line opens her page"); return; }
        const s = n.src; n.src = null;
        if (s) { try { s.dismiss(); } catch (e) {} }
    }
    // a progress value (0..100) in a notification's hints, or -1
    function progressOf(src) {
        let h = null;
        try { h = src.hints; } catch (e) { h = null; }
        if (!h || h.value === undefined || h.value === null) return -1;
        const v = Number(h.value);
        return isNaN(v) ? -1 : Math.max(0, Math.min(100, v));
    }
    function noteIn(src) {
        src.tracked = true;
        const pv = progressOf(src);
        if (pv >= 0) {           // a progress report: the filling ring by the clock, not a dot
            const key = "note-" + src.id;
            const say = () => { const v = progressOf(src); progress.report(key, plain(src.summary), v < 0 ? 100 : v, 0, 0, v < 0 || v >= 100); };
            say();
            src.hintsChanged.connect(say);
            src.summaryChanged.connect(say);
            src.closed.connect(() => progress.report(key, "", 100, 0, 0, true));
            console.info("taylor-notes: one came in with progress");
            return;
        }
        const live = notes.filter((n) => n.st === "in" && !n.taylor);
        if (live.length >= 5) noteDismiss(live[0]);
        const now = Date.now() / 1000;
        const m = { id: ++noteSeq, t: "", b: "", st: "in", t0: now, src: src };
        const words = () => {
            let t = plain(src.summary), b = plain(src.body);
            if (!b) { b = t; t = plain(src.appName) || "Notice"; }
            m.t = t; m.b = b;
        };
        words();
        src.summaryChanged.connect(() => { if (m.src) { words(); notesRev++; } });
        src.bodyChanged.connect(() => { if (m.src) { words(); notesRev++; } });
        src.closed.connect(() => { if (m.src) { m.src = null; root.noteDismiss(m); } });   // the app took it back
        notes.push(m); notesRev++;
        kickAt = now;
        whisper = { txt: m.t + " · " + m.b, t0: now };
        console.info("taylor-notes: one came in");
    }
    // the dial: her list while any are waiting, else her launcher. A click that has just shut the list (by clicking
    // away from it) does not open it again.
    // Her dial opens TAYLOR's window (her ask, 2026-11-21: "her whole window, as on the Mac and Windows"): the TAYLOR app, or her page.
    // Before, it opened the launcher (now Windows key + Space and the dock's dial) or, with some waiting, their list (now the count by
    // the clock; and what waits is on her Home in that window too).
    function dialClicked() {
        console.info("taylor-desktop: the dial opens TAYLOR's window");
        listOpen = false; launcherOpen = false;
        Quickshell.execDetached(["sh", "-c", "/usr/libexec/taylor-open-app 2>&1 | logger -t taylor-open-app"]);
    }
    function toggleList() {
        if (!listOpen && Date.now() - listShutAt < 400) return;
        listOpen = notesWaiting > 0 && !listOpen;
    }
    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: false
        imageSupported: false
        persistenceSupported: true
        onNotification: (n) => root.noteIn(n)
    }
    // a dismissed one fades (0.6 s), then its dot falls back into the dial (0.45 s) and the arcs spin up
    Timer {
        interval: 50; repeat: true
        running: { root.notesRev; return root.notes.some((n) => n.st !== "in"); }
        onTriggered: {
            const T = Date.now() / 1000;
            let changed = false;
            for (const n of root.notes) {
                if (n.st === "fade" && T - n.t0 > 0.6) { n.st = "out"; n.t0 = T; changed = true; }
                else if (n.st === "out" && T - n.t0 > 0.45) { n.st = "gone"; root.kickAt = T; changed = true; }
            }
            if (changed) { root.notes = root.notes.filter((n) => n.st !== "gone"); root.notesRev++; }
        }
    }
    // gaming mode (taylor-gamewatch, her pick S4): while a game is full screen the desktop behind it holds still
    IpcHandler {
        target: "gaming"
        function set(on: bool): void { Theme.gameStill = on; console.info("taylor-desktop: gaming mode " + (on ? "on: holding still" : "off")); }
        function state(): string { return Theme.gameStill ? "on" : "off"; }
    }
    IpcHandler {
        target: "notes"
        function waiting(): int { return root.notesWaiting; }
        function toggle(): void { root.toggleList(); }
        function clear(): void { for (const n of root.notes.filter((n) => n.st === "in" && !n.taylor)) root.noteDismiss(n); }
    }

    // ---- her arrival ----
    readonly property real holdAt: {
        const v = parseFloat(Quickshell.env("TAYLOR_ARRIVE_AT") || "");
        return isNaN(v) ? -1 : v;
    }
    property real arriveT: holdAt >= 0 ? holdAt : 0      // 0 until we know whether this sign-in has arrived yet
    readonly property real arriveEnd: 3
    function sm(v) { v = Math.max(0, Math.min(1, v)); return v * v * (3 - 2 * v); }
    readonly property real arriveU: sm((arriveT - 1.4) / 1.0)     // dock, clock card, mixer (her U)
    readonly property real arriveU2: sm((arriveT - 1.8) / 1.0)    // tray, "ALL CLEAR." (her U2)
    readonly property bool arriving: arriveT < arriveEnd

    NumberAnimation on arriveT { id: arriveRun; running: false; from: 0; to: root.arriveEnd; duration: root.arriveEnd * 1000 }
    Process {
        id: arriveMark
        running: root.holdAt < 0
        command: ["sh", "-c", "f=\"${XDG_RUNTIME_DIR:-/tmp}/taylor-arrived\"; if [ -e \"$f\" ]; then echo seen; else : > \"$f\" && echo new || echo seen; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "new") { console.info("taylor-desktop: her arrival"); arriveRun.start(); }
                else root.arriveT = root.arriveEnd;
            }
        }
        onExited: (code) => { if (code !== 0 && root.arriveT === 0 && !arriveRun.running) root.arriveT = root.arriveEnd; }
    }

    // the sky on every screen
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Sky { required property var modelData; screen: modelData; theme: root.c }
        }
    }

    // the rest on her main screen only
    Dial {
        screen: root.mainScreen; theme: root.c; arrive2: root.arriveU2
        visible: Prefs.showTaylor
        status: away.active ? "STILL THERE?" : root.dialLine; busy: root.dialBusy; thinking: root.thinking
        showLine: Prefs.statusLine
        stepAside: root.launcherO > 0.001
        notes: root.notes; waiting: root.notesWaiting; kickAt: root.kickAt; whisper: root.whisper
        onClicked: root.dialClicked()
    }
    ClockCard { screen: root.mainScreen; theme: root.c; arrive: root.arriveU }
    // her mixer: the quick view on the desktop and the Mixer window (ipc target "mixer": open / toggle)
    Mixer { screen: root.mainScreen; theme: root.c; visible: root.mixerShown; arrive: root.arriveU; onOpenMixer: mixerWindow.open = true }
    MixerWindow { id: mixerWindow }
    // the taskbar (Dock.qml): its dial opens the launcher, its Mixer slot the Mixer window, its lines go to her status
    property bool dockHidden: false          // true full screen (the windows piece sets it)
    Dock {
        id: taskbar
        screen: root.mainScreen; theme: root.c; arrive: root.arriveU
        hiddenForFullscreen: root.dockHidden
        onOpenLauncher: root.launcherOpen = true
        onOpenMixer: mixerWindow.toggle()
        onSay: (line) => { root.dialStatus = line; root.dialBusy = true; statusBack.restart(); }
    }
    Tray {
        screen: root.mainScreen; theme: root.c; arrive: root.arriveU2
        id: tray
        waiting: root.waitingAll
        onCountClicked: root.toggleList()
    }
    Progress { screen: root.mainScreen; theme: root.c; id: progress; trayWidth: tray.implicitWidth }
    Loading { screen: root.mainScreen; theme: root.c; id: loading }
    WindowBar { screen: root.mainScreen; theme: root.c }
    // her Settings window, the volume and brightness ring (on the main screen; it shows over a full-screen window),
    // and warmer colours at night (Settings.qml, Osd.qml, Warm.qml)
    Settings {}
    Osd { screen: root.mainScreen; theme: root.c }
    Warm {}
    // her windows and workspaces (Covers.qml, with Hyprland's windows.lua): the dock's strip, the workspace dots under the
    // dock, and the dotted outline while dragging a window (on every screen)
    DockReserve { screen: root.mainScreen }
    WorkspaceDots { screen: root.mainScreen; theme: root.c; arrive: root.arriveU }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            SnapPreview { required property var modelData; screen: modelData; scr: modelData; theme: root.c }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Arrival { required property var modelData; screen: modelData; at: root.arriveT; visible: root.arriving && (arriveRun.running || root.holdAt >= 0) && !away.again }
        }
    }

    // her timeout to the lock screen (Away.qml); after every unlock her arrival plays again (Away.qml shows a fresh
    // Arrival: showing this one a second time froze the desktop, local test 2026-11-21). Her goodnight (Goodnight.qml).
    Away { id: away; mainScreen: root.mainScreen; theme: root.c; arriveAt: root.arriveT; onArrived: { root.arriveT = 0; arriveRun.start(); } }
    Goodnight { mainScreen: root.mainScreen; theme: root.c }

    // her notification list, on the main screen, just over the tray
    NoteList {
        screen: root.mainScreen
        theme: root.c
        notes: root.notes; rev: root.notesRev
        o: root.listO; open: root.listOpen
        above: 14 + 52
        onDismiss: (n) => root.noteDismiss(n)
        onClickedAway: root.listOpen = false
    }

    // one launcher, on the main screen
    // Windows key + Tab / Alt + Tab: her open windows, most recent first (her ask, like the Mac's Cmd + Tab)
    Switcher {
        screen: root.mainScreen
        theme: root.c
    }
    Launcher {
        screen: root.mainScreen
        theme: root.c
        o: root.launcherO
        open: root.launcherOpen
        status: root.dialLine
        askOn: Prefs.askTaylor
        dialShown: Prefs.showTaylor
        preset: root.launcherPreview === "-" ? "" : root.launcherPreview
        onCloseMe: root.launcherOpen = false
        onPicked: (line, kind) => {
            root.askThinking = kind === "TAYLOR";
            root.dialStatus = kind === "TAYLOR" ? "ALL CLEAR." : line;
            root.dialBusy = true; statusBack.restart();
            if (kind === "App" || kind === "File" || kind === "Folder") loading.start();
        }
        onPickedApp: (id) => taskbar.opening(id)
        onAsk: (text) => taylor.ask(text)
        onToggleMixer: mixerWindow.open = true
    }
}
