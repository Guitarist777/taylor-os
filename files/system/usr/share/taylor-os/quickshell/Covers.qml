pragma Singleton
// Her windows (her build brief, "Windows"; her design tour, part 6), the desktop's half. Hyprland's side is
// /usr/share/taylor-os/hypr/windows.lua: it watches the windows 25 times a second and tells the desktop, as
// "custom>>taylorwin ..." events, two things:
//   cover NAME top br rt rb   on monitor NAME a snapped or full-screen window covers the dock (top) / the clock and tray
//                             (br); the pointer at the top edge brought the dock back (rt) / at the bottom edge the clock (rb)
//   zone Z x y w h            a window is being dragged into snap zone Z (her dotted outline); "zone none" when not
// What the dock, the window bar, the workspace dots and the tray read from here:
//   dockShown / trayShown     0..1: how far in they are (1 = in place); slides and fades with her motion setting
//   dockMapped / trayMapped   false only when they are fully away (then they are not on the screen at all, so a
//                             full-screen window is truly alone, and they come back over it when the pointer asks)
// It also hands Hyprland her colour scheme's outline colour and her less-motion setting (taylor.look).
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: c

    // the main screen's monitor name (shell.qml's root.mainScreen is Quickshell.screens[0])
    readonly property string mainName: Quickshell.screens.length ? Quickshell.screens[0].name : ""

    property var cover: ({})       // name -> {top, br, rt, rb}
    property int coverRev: 0
    readonly property var mine: { coverRev; return cover[mainName] || { top: false, br: false, rt: false, rb: false }; }
    readonly property bool dockWanted: !mine.top || mine.rt
    readonly property bool trayWanted: !mine.br || mine.rb

    property real dockShown: 1
    property real trayShown: 1
    Behavior on dockShown { NumberAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
    Behavior on trayShown { NumberAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
    onDockWantedChanged: { dockShown = dockWanted ? 1 : 0; console.info("taylor-windows: dock " + (dockWanted ? "in" : "away")); }
    onTrayWantedChanged: { trayShown = trayWanted ? 1 : 0; console.info("taylor-windows: clock " + (trayWanted ? "in" : "away")); }
    readonly property bool dockMapped: dockWanted || dockShown > 0.001
    readonly property bool trayMapped: trayWanted || trayShown > 0.001

    // her dotted outline while dragging
    property string zone: ""
    property rect zoneRect: Qt.rect(0, 0, 0, 0)

    property bool heard: false
    function onLine(s) {
        const p = s.trim().split(/\s+/);
        if (p[0] !== "taylorwin") return;
        if (!heard) { heard = true; console.info("taylor-windows: events from Hyprland"); }
        if (p[1] === "cover" && p.length >= 7) {
            const m = Object.assign({}, cover);
            m[p[2]] = { top: p[3] === "1", br: p[4] === "1", rt: p[5] === "1", rb: p[6] === "1" };
            cover = m; coverRev++;
        } else if (p[1] === "zone" && p.length >= 7) {
            if (p[2] === "none") zone = "";
            else { zoneRect = Qt.rect(+p[3], +p[4], +p[5], +p[6]); zone = p[2]; }
            console.info("taylor-windows: drag zone " + (zone || "none"));
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            // hl.dsp.event("taylorwin ...") arrives as custom>>taylorwin ...; take it whichever way it is named
            const n = String(ev.name), d = String(ev.data);
            if (n === "custom") c.onLine(d);
            else if (n.indexOf("taylorwin") === 0) c.onLine(n + " " + d);
        }
    }

    // ask Hyprland for the state once at start, and hand it her look; again whenever her scheme or motion changes
    function hypr(code) { Quickshell.execDetached(["hyprctl", "eval", code]); }
    function sendLook() {
        hypr("if taylor then taylor.look('" + Theme.hex + "', " + (Theme.light ? "true" : "false") + ", " + (Theme.still ? "true" : "false") + ", " + (Theme.systemStill ? "true" : "false") + ") end");
    }
    Timer { id: lookSoon; interval: 300; onTriggered: c.sendLook() }
    readonly property string lookKey: Theme.hex + Theme.light + Theme.still + Theme.systemStill
    onLookKeyChanged: lookSoon.restart()
    Component.onCompleted: { hypr("if taylor then taylor.push() end"); lookSoon.restart(); }

    IpcHandler {
        target: "windows"
        function state(): string { return JSON.stringify({ cover: c.cover, dock: c.dockShown, tray: c.trayShown, dockMapped: c.dockMapped, trayMapped: c.trayMapped, zone: c.zone, heard: c.heard }); }
    }
}
