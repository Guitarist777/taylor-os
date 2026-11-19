//@ pragma IconTheme breeze-dark
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
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    // The mockup's "taylor" theme, value for value.
    readonly property QtObject c: QtObject {
        readonly property color glass: Qt.rgba(28 / 255, 30 / 255, 29 / 255, 0.74)
        readonly property color panel: "#171918"
        readonly property color line: Qt.rgba(1, 1, 1, 0.08)
        readonly property color text: "#EDEFEE"
        readonly property color text2: "#C8CCCA"
        readonly property color muted: "#9AA19D"
        readonly property color accent: "#4FB386"
        readonly property color accentInk: "#06140D"
        readonly property color chip: Qt.rgba(1, 1, 1, 0.06)
        readonly property color track: "#2A2E2C"
        readonly property color mute: "#D9826B"
        readonly property color dock: Qt.rgba(28 / 255, 30 / 255, 29 / 255, 0.8)
        readonly property color bar: Qt.rgba(20 / 255, 22 / 255, 21 / 255, 0.93)
        readonly property string sans: "Manrope"
        readonly property string mono: "Share Tech Mono"
    }

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

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: perScreen
                required property var modelData
                Sky { screen: perScreen.modelData; theme: root.c }
                Dial {
                    screen: perScreen.modelData; theme: root.c; arrive2: root.arriveU2
                    status: root.dialStatus; busy: root.dialBusy
                    stepAside: root.launcherO > 0.001 && perScreen.modelData === Quickshell.screens[0]
                    onClicked: root.launcherOpen = true
                }
                ClockCard { screen: perScreen.modelData; theme: root.c; arrive: root.arriveU }
                Mixer { screen: perScreen.modelData; theme: root.c; visible: root.mixerShown; arrive: root.arriveU }
                Dock { screen: perScreen.modelData; theme: root.c; mixerShown: root.mixerShown; onToggleMixer: root.mixerShown = !root.mixerShown; arrive: root.arriveU }
                Tray { screen: perScreen.modelData; theme: root.c; arrive: root.arriveU2 }
                WindowBar { screen: perScreen.modelData; theme: root.c }
                Arrival { screen: perScreen.modelData; at: root.arriveT; visible: root.arriving && (arriveRun.running || root.holdAt >= 0) }
            }
        }
    }

    // one launcher, on the main screen
    Launcher {
        screen: Quickshell.screens.length ? Quickshell.screens[0] : null
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
