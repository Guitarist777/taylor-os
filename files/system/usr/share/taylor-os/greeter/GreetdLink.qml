// The login screen's line to greetd (2026-11-25), in place of Quickshell's Greetd service: the same calls and signals,
// with greetd's answers read whole by /usr/libexec/taylor-greetd-link (see that file for why). The steps follow
// Quickshell's own (src/services/greetd/connection.cpp at the Fedora build), so greetd sees exactly the same requests.
// Her password goes from respond() to the link's stdin and on to greetd; it is never logged or kept here.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: g

    readonly property bool available: (Quickshell.env("GREETD_SOCK") || "") !== ""
    // "Inactive", "Authenticating", "ReadyToLaunch", "Launching", "Launched"
    property string gstate: "Inactive"
    property bool ready: false
    property bool responseRequired: false
    property bool exitAfterLaunch: false
    property var waiting: []   // requests made before the link was up (sent the moment it is)
    // greetd answers every request exactly once, in order: what each answer still to come is for. Its answer to a
    // cancel is a "success" too, and one that came after the next sign-in had started would have read as "password
    // accepted" (Quickshell's reader has that mix-up; found here 2026-11-25 with a fake greetd). Now it is skipped.
    property var asked: []

    signal authMessage(string message, bool error, bool responseRequired, bool echoResponse)
    signal authFailure(string message)
    signal readyToLaunch()
    signal launched()
    signal error(string error)

    function send(o) {
        asked.push(o.type);
        const line = JSON.stringify(o) + "\n";
        if (!ready) { waiting.push(line); return; }
        link.write(line);
    }
    function setInactive() {
        responseRequired = false;
        gstate = "Inactive";
    }
    function createSession(user) {
        lastUser = user;
        if (gstate !== "Inactive") return;
        gstate = "Authenticating";
        send({ type: "create_session", username: user });
    }
    function cancelSession() {
        if (gstate === "Inactive") return;
        send({ type: "cancel_session" });
        setInactive();
    }
    function respond(response) {
        if (!responseRequired) { console.info("taylor-greeter: greetd asked for nothing; no answer sent"); return; }
        responseRequired = false;
        send({ type: "post_auth_message_response", response: response });
    }
    function launch(command, environment, exit) {
        if (gstate !== "ReadyToLaunch") { console.info("taylor-greeter: cannot start a desktop from state " + gstate); return; }
        gstate = "Launching";
        exitAfterLaunch = exit === true;
        send({ type: "start_session", cmd: command, env: environment });
    }

    function got(line) {
        let j;
        try { j = JSON.parse(line); } catch (e) { console.info("taylor-greeter: an unreadable line from the greetd link"); return; }
        const type = j.type;
        if (type === "link_ready") {
            ready = true;
            const w = waiting;
            waiting = [];
            for (let i = 0; i < w.length; i++) link.write(w[i]);
            console.info("taylor-greeter: connected to greetd");
        } else if (type === "link_closed") {
            ready = false;
            asked = [];
            console.info("taylor-greeter: the line to greetd closed (" + j.why + ")");
        } else if (asked.length === 0) {
            unexpected(type + " (nothing asked)");
        } else if (asked.shift() === "cancel_session") {
            return;   // the answer to a cancel: nothing to do
        } else if (type === "success") {
            if (gstate === "Authenticating") {
                gstate = "ReadyToLaunch";
                readyToLaunch();
            } else if (gstate === "Launching") {
                gstate = "Launched";
                launched();
                if (exitAfterLaunch) Qt.callLater(Qt.quit);
            } else unexpected(type);
        } else if (type === "error") {
            const kind = j.error_type, desc = j.description || "";
            // a session already being set up: cancel it and start again (as Quickshell does)
            if (kind === "error" && desc === "a session is already being configured") {
                send({ type: "cancel_session" });
                gstate = "Authenticating";
                send({ type: "create_session", username: lastUser });
                return;
            }
            if (kind === "auth_error") {
                authFailure(desc);
                if (gstate !== "Inactive") send({ type: "cancel_session" });
            } else if (kind === "error") {
                console.info("taylor-greeter: greetd error: " + desc);
                error(desc);
            } else { unexpected(type + "/" + kind); return; }
            setInactive();   // errors end the session
        } else if (type === "auth_message") {
            const t = j.auth_message_type;
            const needs = t === "visible" || t === "secret";
            responseRequired = needs;
            authMessage(j.auth_message || "", t === "error", needs, t !== "secret");
            if (!needs) send({ type: "post_auth_message_response" });
        } else unexpected(type);
    }
    function unexpected(what) {
        console.info("taylor-greeter: an answer from greetd that fits no step (" + what + ", state " + gstate + ")");
        cancelSession();
    }

    property string lastUser: ""
    onGstateChanged: console.info("taylor-greeter: greetd state " + gstate)

    Process {
        id: link
        running: g.available
        stdinEnabled: true
        command: ["/usr/bin/python3", "-I", "/usr/libexec/taylor-greetd-link"]
        stdout: SplitParser { onRead: (line) => g.got(line) }
        stderr: SplitParser { onRead: (line) => console.info("taylor-greeter: greetd link: " + line) }
        onExited: (code) => { g.ready = false; console.info("taylor-greeter: the greetd link ended (" + code + ")"); }
    }
}
