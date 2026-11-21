// The taskbar (her build brief, "Taskbar"; her design tour, part 14): the floating rounded bar at the top middle.
// TAYLOR's dial at the left end opens her launcher; then the pinned slots Files, Browser, Terminal, Games, Spotify,
// Messages, Mixer, Settings. A small green dot under an icon: the app is running; the app she is in gets a wider green
// dash. The app's name shows under the bar while the pointer is on it.
//
// Browser and Games are group slots: a click splays their apps out BELOW the bar in a small arc, one after another,
// each with its name (Edge, Firefox, Chrome; Steam, EA, Battle.net). A click on one opens it and the rest fold back; a
// click anywhere else folds them away. The last one used has a green ring in the splay and is the icon the slot shows
// (Prefs.lastBrowser / Prefs.lastGames). The splay is the tour's own motion, number for number: angles -42, 0, 42
// degrees, 84 / 74 / 84 px out, each one 45 ms after the last, 0.32 s on cubic-bezier(.2,.9,.3,1.2) from a third of
// its size, fading in over 0.2 s; folding goes back the same way with no delay. With less motion (Theme.still) they
// only fade, already in place.
//
// Icons are each app's real icon from her set, Slot-Dark-Icons (shell.qml's IconTheme); where the set has none, the
// app's own icon through the same theme lookup (its .desktop Icon=). Nothing here is drawn except TAYLOR's dial.
// An app that is not on the PC yet (the first sign-in fetches Edge, Chrome and Spotify; EA and Battle.net install
// through Lutris) shows its icon dimmed; a click says in her status line that it is being set up.
// After a launch, the icon gently brightens and dims until the app's window appears (her call 2026-11-21: no dots).
//
// The log says what it does (app ids and counts, nothing private): "taylor-dock: ..." lines.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "dial_draw.js" as Dial

Scope {
    id: dock
    property var screen: null
    property QtObject theme
    property real arrive: 1               // her arrival after signing in (shell.qml): 0 hidden, 1 in place
    property bool hiddenForFullscreen: false   // true full screen: the bar goes up out of sight (the windows piece sets it)
    signal openLauncher()
    signal openMixer()
    signal say(string line)               // a line for her status under the dial ("OPENING FIREFOX.")

    // ---- sizes: the tour's numbers, a little larger on a big screen (1.25 at 1080 tall; 1 at 800) ----
    readonly property real sw: screen ? screen.width : 1920
    readonly property real sh: screen ? screen.height : 1080
    readonly property real s: Math.max(1, Math.min(1.5, sh / 864))
    readonly property real top: 12 * s            // the bar's distance from the top edge
    readonly property real ic: 32 * s             // a slot
    readonly property real gap: 6 * s
    readonly property real padX: 12 * s
    readonly property real padY: 7 * s
    readonly property real sepW: 1 + 6 * s        // the thin line after the dial, with its margins
    readonly property real barW: 2 * padX + 2 + (slots.length + 1) * ic + slots.length * gap + sepW + gap
    readonly property real barH: 2 * padY + ic + 2
    readonly property real barX: Math.round((sw - barW) / 2)
    // the centre of slot i on the screen (0 is the dial)
    function slotX(i) { return barX + 1 + padX + i * (ic + gap) + (i >= 1 ? sepW + gap : 0) + ic / 2; }
    readonly property real slotY: top + 1 + padY + ic / 2

    // ---- the apps ----
    // icons: names tried in her set first (then breeze-dark, breeze, hicolor, as the set itself inherits); desktop:
    // the app's own .desktop, whose Icon= is the last try and which runs it. match: the window's app id (and title).
    readonly property var apps: ({
        files:     { name: "Files", icons: ["system-file-manager", "org.kde.dolphin"], desktop: "org.kde.dolphin", run: ["dolphin"], match: /^(org\.kde\.)?dolphin$/i },
        edge:      { name: "Edge", icons: ["microsoft-edge", "com.microsoft.Edge"], desktop: "com.microsoft.Edge", flatpak: "com.microsoft.Edge", match: /^(microsoft-edge|com\.microsoft\.edge|msedge)$/i },
        firefox:   { name: "Firefox", icons: ["firefox", "org.mozilla.firefox"], desktop: "org.mozilla.firefox", flatpak: "org.mozilla.firefox", match: /^(firefox|org\.mozilla\.firefox)$/i },
        chrome:    { name: "Chrome", icons: ["google-chrome", "com.google.Chrome"], desktop: "com.google.Chrome", flatpak: "com.google.Chrome", match: /^(google-chrome|com\.google\.chrome)$/i },
        terminal:  { name: "Terminal", icons: ["kitty", "utilities-terminal"], desktop: "kitty", run: ["kitty"], match: /^kitty$/i },
        steam:     { name: "Steam", icons: ["steam"], desktop: "steam", run: ["steam"], need: true, match: /^steam$/i },
        ea:        { name: "EA", icons: ["ea-app", "lutris_ea-app", "9AD6_Origin"], lutris: "ea-app", need: true, match: /^(eadesktop|ealauncher|origin)(\.exe)?$/i },
        battlenet: { name: "Battle.net", icons: ["Battle.net", "lutris_battlenet"], lutris: "battlenet", need: true, match: /^battle\.net(\.exe)?$/i },
        spotify:   { name: "Spotify", icons: ["spotify", "com.spotify.Client"], desktop: "com.spotify.Client", flatpak: "com.spotify.Client", match: /^(spotify|com\.spotify\.client)$/i },
        messages:  { name: "Messages", tip: "Messages for web", icons: ["taylor-messages"], desktop: "taylor-messages", run: ["/usr/libexec/taylor-open-messages"], match: /messages\.google\.com/i, orTitle: /Messages for web/i },
        mixer:     { name: "Mixer", icons: ["multimedia-volume-control", "audio-card"], match: /quickshell/i, andTitle: /^Mixer$/ },
        settings:  { name: "Settings", icons: ["preferences-system", "systemsettings"], match: /quickshell/i, andTitle: /^Settings$/ }
    })
    readonly property var groups: ({ browser: ["edge", "firefox", "chrome"], games: ["steam", "ea", "battlenet"] })
    readonly property var slots: [
        { id: "files" }, { group: "browser", name: "Browser" }, { id: "terminal" }, { group: "games", name: "Games" },
        { id: "spotify" }, { id: "messages" }, { id: "mixer" }, { id: "settings" }
    ]

    // what is on the PC (the flatpaks, Steam, the Lutris games, the Messages icon): taylor-dock-apps prints one id a line
    property var have: ({})
    property bool scanned: false
    function present(id) {
        const a = apps[id];
        if (!a.flatpak && !a.need) return true;
        if (!scanned) return true;               // no dimming before the first look
        return have[id] === true;
    }
    Process {
        id: scan
        command: ["/usr/libexec/taylor-dock-apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {};
                for (const l of this.text.split("\n")) if (l.trim()) h[l.trim()] = true;
                const was = JSON.stringify(dock.have);
                dock.have = h; dock.scanned = true;
                if (JSON.stringify(h) !== was) console.info("taylor-dock: on this PC: " + Object.keys(h).sort().join(" "));
                dock.followDefaultBrowser(h);
            }
        }
    }
    // look again every 20 s while something is missing (the first sign-in is still fetching), else every 2 minutes
    Timer {
        interval: { dock.have; const miss = Object.keys(dock.apps).some((k) => !dock.present(k)); return miss ? 20000 : 120000; }
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: scan.running = true
    }

    function iconFor(id) {
        const a = apps[id];
        if (id === "messages" && have["messages-icon"]) return "file://" + Quickshell.env("HOME") + "/.local/share/icons/hicolor/192x192/apps/taylor-messages.png";
        for (const n of a.icons) { const p = Quickshell.iconPath(n, true); if (p) return p; }
        const e = a.desktop ? DesktopEntries.byId(a.desktop) : null;
        if (e && e.icon) { const p = Quickshell.iconPath(e.icon, true); if (p) return p; }
        if (id === "messages") { for (const n of ["internet-mail", "mail-message", "dialog-messages"]) { const p = Quickshell.iconPath(n, true); if (p) return p; } }
        return Quickshell.iconPath(a.icons[a.icons.length - 1], "application-x-executable");
    }

    // the app a group slot shows: the last one she used, else the first one on the PC, else the first
    function groupShows(g) {
        const last = g === "browser" ? Prefs.lastBrowser : Prefs.lastGames;
        if (groups[g].indexOf(last) >= 0) return last;
        for (const k of groups[g]) if (present(k)) return k;
        return groups[g][0];
    }

    // ---- running and focused (the windows on the desktop, from Wayland's list of open windows) ----
    function matches(a, t) {
        const appId = t.appId || "", title = t.title || "";
        if (a.andTitle) return a.match.test(appId) && a.andTitle.test(title);
        if (a.orTitle && a.orTitle.test(title)) return true;
        return a.match.test(appId);
    }
    readonly property var run: {
        const out = {};
        for (const t of ToplevelManager.toplevels.values) {
            const act = t.activated, ti = t.title;   // read here so a change of either redoes this
            for (const k in apps) if (matches(apps[k], t)) out[k] = Math.max(out[k] || 0, act ? 2 : 1);
        }
        return out;
    }
    function slotRun(sl) {
        if (sl.group) { let m = 0; for (const k of groups[sl.group]) m = Math.max(m, run[k] || 0); return m; }
        return run[sl.id] || 0;
    }
    property string runSeen: "-"
    onRunChanged: {
        const tops = ToplevelManager.toplevels.values;
        const txt = Object.keys(run).sort().map((k) => k + (run[k] === 2 ? "*" : "")).join(" ");
        if (txt !== runSeen) {
            runSeen = txt;
            console.info("taylor-dock: windows [" + tops.map((t) => t.appId || "?").join(" ") + "] running [" + txt + "] (* = the one she is in)");
        }
        const l = Object.assign({}, loading);
        let changed = false;
        const lut = tops.some((t) => /lutris/i.test(t.appId || ""));
        for (const k in l) if (run[k] || (apps[k].lutris && lut)) { delete l[k]; changed = true; }
        if (changed) loading = l;
    }

    // ---- loading: after a launch, the icon breathes until the window appears (at most 45 s) ----
    property var loading: ({})
    property real clock: 0
    Timer {
        interval: 33; repeat: true
        running: Object.keys(dock.loading).length > 0
        onTriggered: {
            dock.clock = Date.now() / 1000;
            const l = Object.assign({}, dock.loading);
            let changed = false;
            for (const k in l) if (Date.now() - l[k] > 45000) { delete l[k]; changed = true; }
            if (changed) dock.loading = l;
        }
    }
    function slotLoading(sl) {
        if (sl.group) return groups[sl.group].some((k) => loading[k] !== undefined);
        return loading[sl.id] !== undefined;
    }
    function mark(id) { const l = Object.assign({}, loading); l[id] = Date.now(); loading = l; }

    // ---- doing things ----
    function launch(id) {
        const a = apps[id];
        if (id === "mixer") { console.info("taylor-dock: open the mixer"); dock.openMixer(); return; }
        if (id === "settings") {
            console.info("taylor-dock: launch settings: quickshell ipc call settings toggle");
            Quickshell.execDetached(["sh", "-c", "quickshell ipc call settings toggle || systemsettings"]);
            return;
        }
        if (!present(id)) {
            if (a.lutris) {
                // EA and Battle.net install through Lutris: its own installer for that launcher opens
                console.info("taylor-dock: launch " + id + ": lutris lutris:" + a.lutris + " (not installed yet: Lutris sets it up)");
                Quickshell.execDetached(["lutris", "lutris:" + a.lutris]);
                dock.say("SETTING UP " + a.name.toUpperCase() + ".");
                mark(id);
            } else {
                console.info("taylor-dock: " + id + " is not on this PC yet: being set up");
                Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "taylor-apps-setup.service"]);
                dock.say(a.name.toUpperCase() + " IS BEING SET UP.");
            }
            return;
        }
        // running already: bring its window forward
        const ts = ToplevelManager.toplevels.values.filter((t) => matches(a, t));
        if (ts.length) {
            const w = ts[ts.length - 1];
            console.info("taylor-dock: " + id + " is running: bring it forward (" + (w.appId || "?") + ")");
            w.activate();
            return;
        }
        const e = a.desktop ? DesktopEntries.byId(a.desktop) : null;
        if (a.lutris) {
            console.info("taylor-dock: launch " + id + ": lutris lutris:rungame/" + a.lutris);
            Quickshell.execDetached(["lutris", "lutris:rungame/" + a.lutris]);
        } else if (e) {
            console.info("taylor-dock: launch " + id + ": " + e.id + ".desktop (" + (e.command || []).join(" ") + ")");
            e.execute();
        } else {
            const cmd = a.flatpak ? ["flatpak", "run", a.flatpak] : a.run;
            console.info("taylor-dock: launch " + id + ": " + cmd.join(" "));
            Quickshell.execDetached(cmd);
        }
        dock.say("OPENING " + a.name.toUpperCase() + ".");
        mark(id);
    }

    function slotClicked(i) {
        if (i === 0) { console.info("taylor-dock: the dial opens her launcher"); fold(); dock.openLauncher(); return; }
        const sl = slots[i - 1];
        if (sl.group) { if (openGroup === sl.group && fanOn) fold(); else splay(sl.group, i); return; }
        fold();
        launch(sl.id);
    }

    // ---- the splay ----
    property string openGroup: ""
    property int openSlot: 0
    property bool fanOn: false            // the tour's fan "on": out and visible
    property bool fanShown: false         // its window is up (while out and while folding back)
    function splay(g, i) {
        foldDone.stop();
        fanOn = false;
        openGroup = g; openSlot = i;
        hoverTip = "";
        fanShown = true;
        Qt.callLater(() => { if (dock.openGroup === g) dock.fanOn = true; });   // the tour's requestAnimationFrame
        console.info("taylor-dock: splay " + g + " [" + groups[g].join(" ") + "] from " + Math.round(slotX(i)) + "," + Math.round(slotY)
                     + "; the fan at " + [0, 1, 2].map((k) => Math.round(slotX(i) + fanAt(k).x) + "," + Math.round(slotY + fanAt(k).y)).join(" "));
    }
    function fold() {
        if (openGroup === "" || !fanShown) return;
        console.info("taylor-dock: fold " + openGroup);
        fanOn = false;
        foldDone.restart();
    }
    Timer { id: foldDone; interval: 380; onTriggered: { dock.fanShown = false; dock.openGroup = ""; } }
    // The Browser slot and the PC's default browser follow each other (her call, 2026-11-21: the slot said Edge while
    // links, Messages and TAYLOR's page opened in the default, Firefox). A pick in the slot sets the default; a default
    // changed anywhere else (KDE's settings, a browser's own "make default") moves the slot at the next look.
    property real defaultSetAt: 0          // a pick just set the default: a look already under way still has the old one
    function followDefaultBrowser(h) {
        if (Date.now() - defaultSetAt < 15000) return;
        for (const k of groups.browser) {
            if (h["default-browser:" + k] && Prefs.lastBrowser !== k) {
                console.info("taylor-dock: the PC's default browser is " + k + " (the browser slot shows it now)");
                Prefs.lastBrowser = k;
            }
        }
    }
    function makeDefaultBrowser(id) {
        if (have["default-browser:" + id]) return;
        defaultSetAt = Date.now();
        const h = Object.assign({}, have);
        for (const k of groups.browser) delete h["default-browser:" + k];
        h["default-browser:" + id] = true;
        have = h;
        console.info("taylor-dock: make " + id + " the PC's default browser: xdg-settings set default-web-browser " + apps[id].desktop + ".desktop");
        Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", apps[id].desktop + ".desktop"]);
    }
    function pick(id) {
        const g = openGroup;
        if (present(id) || apps[id].lutris) {
            if (g === "browser") { Prefs.lastBrowser = id; makeDefaultBrowser(id); } else Prefs.lastGames = id;
            console.info("taylor-dock: picked " + id + " (the " + g + " slot shows it now)");
        }
        fold();
        launch(id);
    }
    // where each one in the fan goes (the tour: sin/cos of -42, 0, 42 degrees; 84, 74, 84 px)
    function fanAt(k) {
        const r = [-42, 0, 42][k] * Math.PI / 180, R = (k === 1 ? 74 : 84) * s;
        return Qt.point(Math.sin(r) * R, Math.cos(r) * R);
    }

    property string hoverTip: ""
    function tipFor(i) {
        if (i === 0) return "TAYLOR";
        const sl = slots[i - 1];
        if (sl.group) return sl.name + ": " + apps[groupShows(sl.group)].name;
        return apps[sl.id].tip || apps[sl.id].name;
    }

    function logSlots() {
        const xs = [];
        for (let i = 0; i <= slots.length; i++) xs.push(Math.round(slotX(i)));
        console.info("taylor-dock: slots at y=" + Math.round(slotY) + " x=" + xs.join(",") + " (dial, " + slots.map((q) => q.id || q.group).join(", ") + ")");
    }
    // for looking at it without a pointer (the local preview): quickshell ipc call dock slot 2 / hover 2 / fold
    IpcHandler {
        target: "dock"
        function slot(i: int): void { dock.slotClicked(i); }
        function hover(i: int): void { dock.hoverTip = i >= 0 ? dock.tipFor(i) : ""; }
        function fold(): void { dock.fold(); }
        function pick(k: int): void { if (dock.openGroup !== "") dock.pick(dock.groups[dock.openGroup][k]); }
    }
    Component.onCompleted: logSlots()
    onSwChanged: Qt.callLater(logSlots)

    // true full screen: the bar rises out of sight (and comes back when the windows piece says so)
    // the windows piece (Covers.qml) moves the bar away from a snapped or full-screen window and back at the top edge
    property real hideT: Math.max(hiddenForFullscreen ? 1 : 0, 1 - Covers.dockShown)
    onHideTChanged: if (hideT > 0.5 && dock.openGroup !== "") fold();
    onHiddenForFullscreenChanged: { console.info("taylor-dock: " + (hiddenForFullscreen ? "hidden for full screen" : "back")); if (hiddenForFullscreen) fold(); }

    // ================= the bar =================
    PanelWindow {
        id: bar
        screen: dock.screen
        visible: Covers.dockMapped && dock.hideT < 0.999
        anchors { top: true }
        margins { top: Math.round(dock.top) }
        implicitWidth: Math.ceil(dock.barW)
        implicitHeight: Math.ceil(dock.barH + 3 * dock.s)    // a little room under the bar for the running dot
        color: "transparent"
        // windows snap edge to edge below the bar; in true full screen nothing is kept for it
        exclusionMode: ExclusionMode.Ignore    // the strip under it is kept by DockReserve.qml (the windows piece), so it can leave
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "taylor-dock"

        Rectangle {
            id: pill
            width: dock.barW; height: dock.barH
            radius: 14 * dock.s
            opacity: dock.arrive * (1 - dock.hideT)
            transform: Translate { y: -(1 - dock.arrive) * 66 - dock.hideT * (dock.barH + dock.top) }
            color: Qt.rgba(dock.theme.panel.r, dock.theme.panel.g, dock.theme.panel.b, 0.94)
            border.color: Qt.rgba(dock.theme.text.r, dock.theme.text.g, dock.theme.text.b, 0.14)
            border.width: 1

            // TAYLOR's dial, small: her ring with its glow and the three arcs, turning with her big one (dial_draw.js)
            Canvas {
                id: mini
                x: dock.slotX(0) - dock.barX - width / 2; y: 1 + dock.padY + (dock.ic - height) / 2
                width: 22 * dock.s; height: 22 * dock.s
                renderStrategy: Canvas.Cooperative
                onPaint: {
                    const x = getContext("2d");
                    x.reset();
                    Dial.setColors(dock.theme.accent, dock.theme.text, dock.theme.text2);
                    const c = width / 2, u = width / 20;
                    x.lineCap = "round"; x.strokeStyle = Dial.ACC;
                    x.globalAlpha = 0.18; x.lineWidth = 3 * u; x.beginPath(); x.arc(c, c, 4 * u, 0, 6.2832); x.stroke();
                    x.globalAlpha = 1; x.lineWidth = 1.5 * u; x.beginPath(); x.arc(c, c, 4 * u, 0, 6.2832); x.stroke();
                    const rot = Dial.arcAngle();
                    for (let j = 0; j < 3; j++) {
                        const st = rot + j * 2.0944;
                        x.beginPath(); x.arc(c, c, 7.5 * u, st, st + 1.0, false); x.stroke();
                    }
                    x.globalAlpha = 1;
                }
                Timer { interval: 100; running: !dock.theme.still && bar.visible; repeat: true; onTriggered: mini.requestPaint() }
                Connections { target: dock.theme; function onAccentChanged() { mini.requestPaint(); } }
            }
            // the thin line after the dial
            Rectangle {
                x: dock.slotX(0) - dock.barX + dock.ic / 2 + dock.gap + 3 * dock.s
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 20 * dock.s
                color: Qt.rgba(dock.theme.text.r, dock.theme.text.g, dock.theme.text.b, 0.12)
            }

            Repeater {
                model: dock.slots
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property int i: index + 1
                    readonly property string appId: modelData.group ? dock.groupShows(modelData.group) : modelData.id
                    readonly property int rs: dock.slotRun(modelData)
                    readonly property bool here: dock.present(appId)
                    readonly property bool busy: dock.slotLoading(modelData)
                    property real busyFrom: 0          // the breath starts bright, at the click
                    onBusyChanged: if (busy) { busyFrom = Date.now() / 1000; console.info("taylor-dock: " + appId + " opening: its icon breathes until its window appears"); }
                    x: dock.slotX(i) - dock.barX - dock.ic / 2; y: 1 + dock.padY
                    width: dock.ic; height: dock.ic

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: dock.ic
                        source: { dock.have; return dock.iconFor(slot.appId); }
                        // loading (her call 2026-11-21, instead of the tour's circling dots, which she read as "a
                        // thinking thing"): the icon itself gently brightens and dims, 1.6 s a breath, until the app's
                        // window appears. Reduced motion: it only stays a little dimmed.
                        opacity: !slot.here ? 0.4
                               : !slot.busy ? 1
                               : dock.theme.still ? 0.6
                               : 0.725 + 0.275 * Math.cos((dock.clock - slot.busyFrom) * 6.2832 / 1.6)
                        Behavior on opacity { enabled: !slot.busy; NumberAnimation { duration: dock.theme.ms(200) } }
                    }
                    // the green dot (running) or wider dash (the app she is in): the tour's ::after under the icon
                    Rectangle {
                        visible: !slot.busy
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 3 * dock.s }
                        height: 3 * dock.s; radius: 2 * dock.s
                        width: slot.rs === 2 ? 12 * dock.s : slot.rs === 1 ? 3 * dock.s : 0
                        color: dock.theme.accent
                        Behavior on width { NumberAnimation { duration: dock.theme.ms(200) } }
                    }
                }
            }
        }
        // one place takes the clicks and the pointer for the whole bar (the slots are laid out by number)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(mx) {
                for (let i = 0; i <= dock.slots.length; i++) {
                    if (Math.abs(mx - (dock.slotX(i) - dock.barX)) <= (dock.ic + dock.gap) / 2) return i;
                }
                return -1;
            }
            onPositionChanged: (m) => { const i = at(m.x); if (dock.openGroup === "") dock.hoverTip = i >= 0 ? dock.tipFor(i) : ""; }
            onExited: dock.hoverTip = ""
            onClicked: (m) => { const i = at(m.x); if (i >= 0) dock.slotClicked(i); }
        }
    }

    // ================= the name under the bar (takes no clicks) =================
    PanelWindow {
        screen: dock.screen
        visible: dock.hoverTip !== "" && dock.openGroup === "" && bar.visible
        anchors { top: true }
        margins { top: Math.round(dock.top + dock.barH + 6 * dock.s) }
        implicitWidth: Math.ceil(name.implicitWidth + 16)
        implicitHeight: Math.ceil(name.implicitHeight + 4)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "taylor-dock-name"
        Text {
            id: name
            anchors.centerIn: parent
            text: dock.hoverTip
            font.family: dock.theme.sans
            font.pixelSize: 12 * dock.s
            color: dock.theme.text
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        onVisibleChanged: if (visible) console.info("taylor-dock: the name under the bar: " + dock.hoverTip)
    }

    // ================= the splay (while it is out, a click anywhere else folds it) =================
    PanelWindow {
        id: fanWin
        screen: dock.screen
        visible: dock.fanShown
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "taylor-dock-splay"
        WlrLayershell.keyboardFocus: dock.fanOn ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: dock.fold()
            MouseArea {
                anchors.fill: parent
                onClicked: (m) => {
                    // a click on the bar itself still works the bar (another slot, or this one again to fold)
                    const inBar = m.y >= dock.top && m.y <= dock.top + dock.barH && m.x >= dock.barX && m.x <= dock.barX + dock.barW;
                    if (inBar) {
                        for (let i = 0; i <= dock.slots.length; i++) {
                            if (Math.abs(m.x - dock.slotX(i)) <= (dock.ic + dock.gap) / 2) { dock.slotClicked(i); return; }
                        }
                    }
                    dock.fold();
                }
            }
        }

        Repeater {
            model: dock.openGroup !== "" ? dock.groups[dock.openGroup] : []
            delegate: Item {
                id: fi
                required property string modelData
                required property int index
                readonly property point to: dock.fanAt(index)
                readonly property bool last: dock.groupShows(dock.openGroup) === modelData
                // the tour's .fi: a 38 px circle with its name 5 px under it, starting on the slot at a third of its size
                property real u: 0          // 0 folded, 1 out
                property real o: 0
                readonly property real m: dock.theme.still ? 1 : u
                x: dock.slotX(dock.openSlot) - width / 2 + to.x * m
                y: dock.slotY - height / 2 + to.y * m
                width: 38 * dock.s; height: 38 * dock.s
                opacity: o
                scale: dock.theme.still ? 1 : 0.3 + 0.7 * u
                states: State { name: "on"; when: dock.fanOn; PropertyChanges { target: fi; u: 1; o: 1 } }
                transitions: [
                    Transition {
                        to: "on"
                        ParallelAnimation {
                            NumberAnimation { target: fi; property: "o"; duration: 200 }
                            SequentialAnimation {
                                PauseAnimation { duration: dock.theme.still ? 0 : fi.index * 45 }
                                NumberAnimation { target: fi; property: "u"; duration: dock.theme.still ? 0 : 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.9, 0.3, 1.2, 1, 1] }
                            }
                        }
                    },
                    Transition {
                        from: "on"
                        ParallelAnimation {
                            NumberAnimation { target: fi; property: "o"; duration: 200 }
                            NumberAnimation { target: fi; property: "u"; duration: dock.theme.still ? 0 : 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.9, 0.3, 1.2, 1, 1] }
                        }
                    }
                ]

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: dock.theme.panel
                    border.width: fi.last ? 1.5 * dock.s : 1
                    border.color: fi.last ? dock.theme.accent : Qt.rgba(dock.theme.text.r, dock.theme.text.g, dock.theme.text.b, 0.18)
                }
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 26 * dock.s
                    source: { dock.have; return dock.iconFor(fi.modelData); }
                    opacity: dock.present(fi.modelData) ? 1 : 0.4
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 5 * dock.s }
                    text: dock.apps[fi.modelData].name
                    font.family: dock.theme.sans
                    font.pixelSize: 11 * dock.s
                    color: dock.theme.text
                    style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.6)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: dock.fanOn
                    onClicked: dock.pick(fi.modelData)
                }
            }
        }
    }
}
