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
// oldest away. Only counts go to the log, never what a notification says.
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
    Timer { id: statusBack; interval: 2400; onTriggered: { root.dialStatus = "ALL CLEAR."; root.dialBusy = false; } }
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
        const s = n.src; n.src = null;
        if (s) { try { s.dismiss(); } catch (e) {} }
    }
    function noteIn(src) {
        src.tracked = true;
        const live = notes.filter((n) => n.st === "in");
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
    function dialClicked() {
        if (notesWaiting > 0) toggleList();
        else { console.info("taylor-desktop: the dial opens her launcher"); launcherOpen = true; }
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
    IpcHandler {
        target: "notes"
        function waiting(): int { return root.notesWaiting; }
        function toggle(): void { root.toggleList(); }
        function clear(): void { for (const n of root.notes.filter((n) => n.st === "in")) root.noteDismiss(n); }
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
        status: root.dialStatus; busy: root.dialBusy
        stepAside: root.launcherO > 0.001
        notes: root.notes; waiting: root.notesWaiting; kickAt: root.kickAt; whisper: root.whisper
        onClicked: root.dialClicked()
    }
    ClockCard { screen: root.mainScreen; theme: root.c; arrive: root.arriveU }
    Mixer { screen: root.mainScreen; theme: root.c; visible: root.mixerShown; arrive: root.arriveU }
    // the taskbar (Dock.qml): its dial opens the launcher, its Mixer slot the Mixer window, its lines go to her status
    property bool mixerWindowOpen: false     // the Mixer window (the mixer piece shows its window from this)
    property bool dockHidden: false          // true full screen (the windows piece sets it)
    Dock {
        screen: root.mainScreen; theme: root.c; arrive: root.arriveU
        hiddenForFullscreen: root.dockHidden
        onOpenLauncher: root.launcherOpen = true
        onOpenMixer: root.mixerWindowOpen = true
        onSay: (line) => { root.dialStatus = line; root.dialBusy = true; statusBack.restart(); }
    }
    Tray {
        screen: root.mainScreen; theme: root.c; arrive: root.arriveU2
        waiting: root.notesWaiting
        onCountClicked: root.toggleList()
    }
    WindowBar { screen: root.mainScreen; theme: root.c }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Arrival { required property var modelData; screen: modelData; at: root.arriveT; visible: root.arriving && (arriveRun.running || root.holdAt >= 0) }
        }
    }

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
    Launcher {
        screen: root.mainScreen
        theme: root.c
        o: root.launcherO
        open: root.launcherOpen
        status: root.dialStatus
        preset: root.launcherPreview === "-" ? "" : root.launcherPreview
        onCloseMe: root.launcherOpen = false
        onPicked: (line) => { root.dialStatus = line; root.dialBusy = true; statusBack.restart(); }
        onToggleMixer: root.mixerShown = !root.mixerShown
    }
}
