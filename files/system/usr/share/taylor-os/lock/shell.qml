// TAYLOR OS lock screen (her build brief, phase 6; her design tour parts 2, 3 and 9). Her login screen's own scene
// (greeter/scene_engine.js, loaded from where the login screen keeps it, not copied) on every screen while the session
// is locked: the sky, the big clock and date, and TAYLOR's dial taking her password one star at a time. The dial is on
// her main screen; the other screens show the sky. Her password is checked by PAM (the same "hyprlock" PAM file the
// fallback uses) against her own account; nothing here writes it down, logs it or shows it.
//
// Its own Quickshell, started by /usr/libexec/taylor-lock (which watches it: if this one ever dies while locked,
// hyprlock takes over in TAYLOR's colours so she can always type her password). Two ways in:
//   TAYLOR_LOCK_MODE=now    Windows key + L, before sleep, "loginctl lock-session": the lock screen at once.
//   TAYLOR_LOCK_MODE=burst  the end of her timeout (quickshell/Away.qml): TAYLOR, swollen in the middle, bursts into
//                           specks that drift for 4.5 s while the sky brightens, the clock and date fade in and the
//                           dial draws itself (her 1.75 s), then her name and the hint.
// After a good password her unlock plays (the ring fills, spins, a pulse, "Welcome back", the dots rise into stars, the
// faint stars fall into her desktop spot), the screen fades to the desktop's dark, the desktop is told to play her
// arrival (shell.qml: dock, mixer, clock and status follow), and only then is the session unlocked.
//
// Tests: TAYLOR_LOCK_DEMO=1 needs no session lock (a plain window, for the local preview): "taylortest" is right.
// TAYLOR_LOCK_TYPED=5 types 5 letters after 1.5 s; TAYLOR_LOCK_ANSWER=wrong then presses Enter with them.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

ShellRoot {
    id: root

    readonly property string mode: (Quickshell.env("TAYLOR_LOCK_MODE") || "now") === "burst" ? "burst" : "now"
    readonly property bool demo: Quickshell.env("TAYLOR_LOCK_DEMO") === "1"
    readonly property string run: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    // where her desktop's Quickshell runs from (taylor-lock passes it on when her desktop started this lock)
    readonly property string desktopDir: Quickshell.env("TAYLOR_DESKTOP_DIR") || ""

    property string who: ""
    property string pw: ""
    property bool busy: false
    property bool launching: false
    property bool done: false
    property real fade: 0

    // what happened, told to every screen's scene
    function each(f) { for (const s of surfaces) if (s) f(s); }
    function sTyped() { each((s) => s.letter()); }
    function sErase(left) { each((s) => s.erase(left)); }
    function sClear() { each((s) => s.clearAll()); }
    function sEmpty() { each((s) => s.emptyEnter()); }
    function sWaiting() { each((s) => s.waiting()); }
    function sAccepted() { each((s) => s.accepted()); }
    function sRejected() { each((s) => s.rejected()); }

    Component.onCompleted: console.info("taylor-lock: " + mode + (demo ? " (demo)" : ""))

    // Her first name, as the login screen shows it (her account's real name, else the account name).
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$(id -un)\" | awk -F: '{print $1 \":\" $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim(), i = line.indexOf(":");
                if (i < 0) return;
                const user = line.slice(0, i), first = line.slice(i + 1).split(",")[0].trim().split(" ")[0];
                root.who = first !== "" ? first : user.charAt(0).toUpperCase() + user.slice(1);
            }
        }
    }

    // ---- the session lock ----
    WlSessionLock {
        id: lock
        locked: !root.demo
        onSecureChanged: {
            console.info("taylor-lock: every screen covered: " + secure);
            if (secure) hint.say(true);
        }
        surface: Component {
            LockSurface {
                id: ls
                primary: screen === Quickshell.screens[0]
                mode: root.mode
                who: root.who
                fade: root.fade
                onKeyTyped: (t) => root.typed(t)
                onKeyErase: root.erase()
                onKeyEnter: root.submit()
                onKeyEscape: root.clear()
                Component.onCompleted: root.surfaces.push(ls.scene)
            }
        }
    }
    property var surfaces: []

    // The demo (local preview): the same scene in a plain full-screen window.
    Loader {
        active: root.demo
        sourceComponent: Component {
            DemoWindow {
                mode: root.mode
                who: root.who
                fade: root.fade
                onKeyTyped: (t) => root.typed(t)
                onKeyErase: root.erase()
                onKeyEnter: root.submit()
                onKeyEscape: root.clear()
                Component.onCompleted: root.surfaces.push(scene)
            }
        }
    }

    // LockedHint on her login session (what "loginctl show-session" and hypridle read).
    Process {
        id: hint
        function say(on) {
            if (root.demo) return;
            command = ["/usr/libexec/taylor-lock", "hint", on ? "true" : "false"];
            running = true;
        }
    }

    function primaryScene() {
        for (const s of surfaces) if (s && s.primary) return s;
        return surfaces.length ? surfaces[0] : null;
    }

    // ---- her keys ----
    function typed(ch) {
        if (busy || launching) return;
        pw += ch;
        sTyped();
    }
    function erase() {
        if (busy || launching || pw.length === 0) return;
        pw = pw.slice(0, -1);
        sErase(pw.length);
    }
    function clear() {
        if (busy || launching) return;
        pw = "";
        sClear();
    }
    function submit() {
        if (busy || launching) return;
        if (pw.length === 0) { sEmpty(); return; }
        busy = true;
        sWaiting();
        if (demo) { demoAnswer.start(); return; }
        if (!pam.start()) bad("PAM did not start");
    }
    function good() {
        pw = "";
        busy = false;
        launching = true;
        console.info("taylor-lock: password accepted");
        sAccepted();
        finishWatch.start();
    }
    function bad(why) {
        pw = "";
        busy = false;
        console.info("taylor-lock: not unlocked (" + why + ")");
        sRejected();
    }

    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: {
            if (responseRequired) { respond(root.pw); }
            else if (message) console.info("taylor-lock: pam " + (messageIsError ? "error: " : "") + message);
        }
        onCompleted: (result) => { if (result === PamResult.Success) root.good(); else root.bad("wrong password"); }
        onError: (err) => root.bad("pam error " + err)
    }

    Timer { id: demoAnswer; interval: 400; onTriggered: { if (root.pw === "taylortest") root.good(); else root.bad("demo"); } }

    // "Welcome back" plays to its end (4.6 s: the desktop dial drawn, the last faint star in), the screen fades to the
    // desktop's dark (0.4 s), then the desktop is told to arrive, then the session is unlocked.
    Timer {
        id: finishWatch
        interval: 50
        repeat: true
        onTriggered: {
            const s = root.primaryScene(), w = s ? s.welcomeFor() : 5;
            if (w < 4.6) return;
            root.fade = Math.min(1, (w - 4.6) / 0.4);
            if (root.fade < 1) return;
            stop();
            arrive.running = true;
        }
    }
    Process {
        id: arrive
        command: root.desktopDir !== "" ? ["quickshell", "ipc", "-p", root.desktopDir, "call", "lock", "arrived"]
                                        : ["quickshell", "ipc", "call", "lock", "arrived"]
        onExited: (code) => {
            console.info("taylor-lock: her desktop told to arrive (" + code + ")");
            root.unlockNow();
        }
    }
    function unlockNow() {
        if (done) return;
        done = true;
        if (!demo) lock.locked = false;
        console.info("taylor-lock: unlocked");
        hint.say(false);
        stateFile.running = true;
    }
    // Written AFTER the unlock: if this process died between the two, taylor-lock would lock again with hyprlock
    // (her password once more), never leave her locked out.
    Process {
        id: stateFile
        command: ["sh", "-c", "echo unlocked > \"" + root.run + "/taylor-lock.state\""]
        onExited: { if (!root.demo) quitSoon.start(); }
    }
    Timer { id: quitSoon; interval: 300; onTriggered: Qt.quit() }

    // the preview's frames
    Timer {
        running: (Quickshell.env("TAYLOR_LOCK_TYPED") || "") !== ""
        interval: (root.mode === "burst" ? 9000 : 1500)
        onTriggered: {
            const n = parseInt(Quickshell.env("TAYLOR_LOCK_TYPED"));
            for (let i = 0; i < n; i++) root.typed("x");
            const a = Quickshell.env("TAYLOR_LOCK_ANSWER") || "";
            if (a === "ok") { root.pw = "taylortest"; root.submit(); }
            else if (a === "wrong") root.submit();
        }
    }
}
