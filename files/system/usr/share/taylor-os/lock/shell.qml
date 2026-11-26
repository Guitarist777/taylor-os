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
// A file $XDG_RUNTIME_DIR/taylor-lock.test-stall (the VM test makes it) holds "Welcome back" forever, as a screen that
// stops drawing does, to prove her password still lets her in.
//
// Her password always lets her in (2026-11-26: twice her password was accepted and she stayed locked, because the
// screen stopped drawing and "Welcome back" waits on drawn frames). The animation is only decoration: 7 s after a good
// password, by the wall clock, the session is unlocked whatever the animation is doing.
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
    property bool stallTest: false

    // what happened, told to every screen's scene
    // A screen that reconnects (the monitor waking, a switch to a text screen and back) gets a new surface; the old
    // one's scene is gone. Calls skip anything gone, so one dead screen never stops her keys or her unlock
    // (2026-11-26: "Property 'letter' ... is not a function" and she stayed locked).
    function alive(s) { try { return !!s && typeof s.letter === "function"; } catch (e) { return false; } }
    function each(f) { for (const s of surfaces.slice()) if (alive(s)) { try { f(s); } catch (e) { console.warn("taylor-lock: a screen skipped: " + e); } } }
    function forget(sc) { surfaces = surfaces.filter((x) => x !== sc && alive(x)); }
    function sTyped() { each((s) => s.letter()); }
    function sErase(left) { each((s) => s.erase(left)); }
    function sClear() { each((s) => s.clearAll()); }
    function sEmpty() { each((s) => s.emptyEnter()); }
    function sWaiting() { each((s) => s.waiting()); }
    function sAccepted() { each((s) => s.accepted()); }
    function sRejected() { each((s) => s.rejected()); }

    Component.onCompleted: console.info("taylor-lock: " + mode + (demo ? " (demo)" : ""))
    Process {
        running: true
        command: ["sh", "-c", "test -e \"" + root.run + "/taylor-lock.test-stall\""]
        onExited: (code) => { if (code === 0) { root.stallTest = true; console.info("taylor-lock: test: Welcome back will stall"); } }
    }

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
                onKeyNote: (s) => root.each((x) => x.note(s))
                Component.onCompleted: { root.surfaces = root.surfaces.filter((x) => root.alive(x)).concat([ls.scene]); }
                Component.onDestruction: root.forget(ls.scene)
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
                onKeyNote: (s) => root.each((x) => x.note(s))
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
        const live = surfaces.filter((x) => alive(x));
        for (const s of live) if (s.primary) return s;
        return live.length ? live[0] : null;
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
        alwaysIn.start();
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
            if (root.stallTest) return;
            const s = root.primaryScene();
            let w = 5;
            try { if (s) w = s.welcomeFor(); } catch (e) { w = 5; }
            if (w < 4.6) return;
            root.fade = Math.min(1, (w - 4.6) / 0.4);
            if (root.fade < 1) return;
            stop();
            arrive.running = true;
        }
    }
    // The wall-clock promise: in by 7 s after a good password, drawn or not.
    Timer {
        id: alwaysIn
        interval: 7000
        onTriggered: {
            if (root.done) return;
            console.info("taylor-lock: Welcome back did not finish in 7 s; unlocking anyway");
            finishWatch.stop();
            root.fade = 1;
            root.unlockNow();
            if (!arrive.running) arrive.running = true;
        }
    }
    Process {
        id: arrive
        // never waits more than 3 s on her desktop: a stuck desktop must not keep her locked
        command: root.desktopDir !== "" ? ["timeout", "3", "quickshell", "ipc", "-p", root.desktopDir, "call", "lock", "arrived"]
                                        : ["timeout", "3", "quickshell", "ipc", "call", "lock", "arrived"]
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
