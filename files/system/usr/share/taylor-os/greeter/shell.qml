//@ pragma IconTheme breeze-dark
// TAYLOR OS login screen (her designs of 2026-11-18/19): her opening, the hand-off to the night sky, and TAYLOR's dial
// that takes her password one star at a time. One Scene per screen; the keyboard goes to the first screen.
// greetd checks the password (Quickshell.Services.Greetd); nothing here ever writes it down, logs it or shows it.
// After "Welcome back" her TAYLOR desktop starts (Hyprland through uwsm, as the old login screen did).
// Without greetd (the automatic preview) it runs as a demo: the password "taylortest" is right, anything else wrong.
// TAYLOR_GREETER_FROM=20 starts 20 s in; TAYLOR_GREETER_TYPED=5 then types 5 letters; with
// TAYLOR_GREETER_ANSWER=ok or wrong, it then shows that answer (the preview's frames).
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import QtQuick

ShellRoot {
    id: root

    property string user: ""
    property string who: ""
    property string pw: ""
    property bool busy: false
    property bool launching: false
    property real fade: 0

    // Started exactly so: on 2026-11-19 wrapping it (screen cleared, its lines sent to the journal) made uwsm stop at
    // once and her login came back. uwsm's start-up lines still show on the text screen until Hyprland's first picture.
    readonly property var session: ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"]
    readonly property var sessionEnv: ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland", "XDG_SESSION_DESKTOP=Hyprland"]
    // The KDE backup (her build brief: KDE always works as a backup login). F2 on this screen picks it for the next
    // sign-in only; the hint says "KDE next" while it is picked, and F2 again takes it back.
    property bool kde: false
    readonly property var kdeSession: ["/usr/libexec/taylor-kde-session"]
    readonly property var kdeEnv: ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=KDE", "XDG_SESSION_DESKTOP=KDE"]
    // Her ruling 2026-11-20: when her TAYLOR desktop failed to start 5 times in a row (/usr/libexec/taylor-greeter
    // counts them), this screen picks KDE itself and says why; F2 takes it back. A desktop that runs resets the count.
    readonly property int kdeAfter: 5
    property int desktopFails: 0
    signal sKdeAuto(int n)
    Process {
        running: true
        command: ["cat", "/tmp/taylor-desktop-fails"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(this.text.trim());
                if (isNaN(n) || n < root.kdeAfter) return;
                root.desktopFails = n;
                root.kde = true;
                console.info("taylor-greeter: her TAYLOR desktop failed to start " + n + " times; next sign-in opens the KDE backup");
                root.sKdeAuto(n);
            }
        }
    }
    // Written just before her desktop starts; the start script reads it when this screen comes back.
    Process { id: startFile }

    signal sTyped()
    signal sErase(int left)
    signal sClear()
    signal sEmpty()
    signal sWaiting()
    signal sAccepted()
    signal sRejected()
    signal sSkip()
    signal sKde(bool on)

    // Whose PC it is: the first person's account (her name as the account has it, else the account name).
    Process {
        running: true
        command: ["sh", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /nologin|false/ {print $1 \":\" $5; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim();
                const i = line.indexOf(":");
                if (i < 0) return;
                root.user = line.slice(0, i);
                const real = line.slice(i + 1).split(",")[0].trim();
                const first = real.split(" ")[0];
                root.who = first !== "" ? first : root.user.charAt(0).toUpperCase() + root.user.slice(1);
                console.info("taylor-greeter: signing in " + root.user);
            }
        }
    }

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
    function toggleKde() {
        if (busy || launching) return;
        kde = !kde;
        console.info("taylor-greeter: next sign-in opens " + (kde ? "the KDE backup" : "her TAYLOR desktop"));
        sKde(kde);
    }
    function submit() {
        if (busy || launching) return;
        if (pw.length === 0) { sEmpty(); return; }
        busy = true;
        sWaiting();
        if (!Greetd.available) { demo.start(); return; }
        Greetd.createSession(user);
    }
    function good() {
        pw = "";
        busy = false;
        launching = true;
        sAccepted();
        okFile.running = true;
        startFile.command = ["sh", "-c", "echo " + (kde ? "kde" : "taylor") + " $(date +%s) > /tmp/taylor-desktop-start"];
        startFile.running = true;
        launchWatch.start();
    }
    function bad(why) {
        pw = "";
        busy = false;
        console.info("taylor-greeter: not signed in (" + why + ")");
        sRejected();
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.pw);
            else console.info("taylor-greeter: " + (error ? "error: " : "") + message);
        }
        function onAuthFailure(message) { root.bad("wrong password"); }
        function onReadyToLaunch() { root.good(); }
        function onError(error) {
            root.bad("greetd: " + error);
            if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
        }
    }

    // The demo answer, when there is no greetd.
    Timer {
        id: demo
        interval: 400
        onTriggered: { if (root.pw === "taylortest") root.good(); else root.bad("demo"); }
    }

    // Tells /usr/libexec/taylor-greeter that this start went well (so the text sign-in is not needed). The count is
    // set back to none HERE, when her password is accepted: the start script's own reset after Hyprland ends never ran
    // (greetd ends it when her desktop starts), so every sign-out added one and the second sign-out of a boot got the
    // text sign-in (found by the virtual PC, run 44862946750).
    Process { id: okFile; command: ["sh", "-c", "touch /tmp/taylor-greeter-ok; echo 0 > /tmp/taylor-greeter-fails-$(id -u)"] }

    // "Welcome back" plays (her ring fill, spin and pulse), the screen fades, then her desktop starts.
    Timer {
        id: launchWatch
        interval: 50
        repeat: true
        property real faded: -1
        onTriggered: {
            const w = sceneList.count > 0 ? sceneList.objectAt(0).welcomeFor() : 2;
            if (w < 4.6) return;   // her unlock plays to the end: the desktop dial drawn, the last faint star in
            root.fade = Math.min(1, (w - 4.6) / 0.4);
            if (root.fade >= 1) {
                stop();
                if (Greetd.available) {
                    console.info("taylor-greeter: starting " + (root.kde ? "the KDE backup" : "her desktop"));
                    Greetd.launch(root.kde ? root.kdeSession : root.session, root.kde ? root.kdeEnv : root.sessionEnv, true);
                } else {
                    console.info("taylor-greeter: demo signed in");
                    root.fade = 0;   // the demo stays on "Welcome back", for the preview's picture
                }
            }
        }
    }

    Variants {
        id: sceneList
        property int count: instances.length
        function objectAt(i) { return instances[i]; }
        model: Quickshell.screens
        delegate: Component {
            Scene {
                id: sc
                required property var modelData
                screen: modelData
                primary: modelData === Quickshell.screens[0]
                who: root.who
                fade: root.fade
                onKeyTyped: (text) => root.typed(text)
                onKeyErase: root.erase()
                onKeyEnter: root.submit()
                onKeyEscape: root.clear()
                onSkipped: root.sSkip()
                onKeyKde: root.toggleKde()
                Component.onCompleted: if (root.desktopFails >= root.kdeAfter && root.kde) autoKde(root.desktopFails)
                Connections {
                    target: root
                    function onSTyped() { sc.letter(); }
                    function onSErase(left) { sc.erase(left); }
                    function onSClear() { sc.clearAll(); }
                    function onSEmpty() { sc.emptyEnter(); }
                    function onSWaiting() { sc.waiting(); }
                    function onSAccepted() { sc.accepted(); }
                    function onSRejected() { sc.rejected(); }
                    function onSSkip() { sc.skip(); }
                    function onSKde(on) { sc.setKde(on); }
                    function onSKdeAuto(n) { sc.autoKde(n); }
                }
            }
        }
    }

    // The preview's still frames: letters typed, then the answer.
    Timer {
        running: (Quickshell.env("TAYLOR_GREETER_TYPED") || "") !== ""
        interval: 1500
        onTriggered: {
            const n = parseInt(Quickshell.env("TAYLOR_GREETER_TYPED"));
            for (let i = 0; i < n; i++) root.typed("x");
            const a = Quickshell.env("TAYLOR_GREETER_ANSWER") || "";
            if (a === "ok") { root.pw = "taylortest"; root.submit(); }
            else if (a === "wrong") root.submit();
        }
    }
}
