pragma Singleton
// Her colour schemes (her build brief, "Colors"), live: choosing one in Settings recolours the whole desktop at once,
// the dial included. TAYLOR is the default; Quiet, Quiet Night and Slate are her earlier picks, with the values the
// brief gives (the rest derived in the same spirit, for her to check by eye). Slate's background follows her
// black-to-white slider (Prefs.slateLevel).
//
// Reduced motion: her Settings switch, or the system's own "no animations" setting (GNOME's enable-animations, which
// GTK and Qt apps on this desktop also follow). Every animation in the desktop asks Theme.still.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: t
    readonly property string scheme: ["taylor", "quiet", "night", "slate"].indexOf(Prefs.scheme) >= 0 ? Prefs.scheme : "taylor"
    readonly property bool light: scheme === "quiet" || (scheme === "slate" && Prefs.slateLevel > 0.55)

    function mix(a, b, u) { return Qt.rgba(a.r + (b.r - a.r) * u, a.g + (b.g - a.g) * u, a.b + (b.b - a.b) * u, 1); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    readonly property color slateBg: mix(Qt.color("#000000"), Qt.color("#FFFFFF"), Math.max(0, Math.min(1, Prefs.slateLevel)))

    readonly property var table: ({
        taylor: { bg: "#0B0D0C", panel: "#171918", window: "#121413", text: "#EDEFEE", text2: "#C8CCCA", muted: "#9AA19D", accent: "#4FB386", soft: "#A8E3C6", star: "#E4EEE8", ink: "#06140D" },
        quiet:  { bg: "#F4F2EC", panel: "#FFFFFF", window: "#FFFFFF", text: "#1C1C1A", text2: "#3A3A36", muted: "#5E5E58", accent: "#3F6152", soft: "#3F6152", star: "#E4EEE8", ink: "#FFFFFF" },
        night:  { bg: "#1C1C1A", panel: "#262623", window: "#262623", text: "#F2F1ED", text2: "#D6D4CE", muted: "#A3A199", accent: "#8FB5A1", soft: "#8FB5A1", star: "#E4EEE8", ink: "#141A17" },
        slate:  { bg: "#2F3033", panel: "#38393D", window: "#303135", text: "#F2F2F0", text2: "#D8D8D4", muted: "#AEAEA8", accent: "#8FB5A1", soft: "#8FB5A1", star: "#E4EEE8", ink: "#141A17" }
    })
    readonly property var s: table[scheme]
    onSchemeChanged: console.info("taylor-theme: " + scheme)
    Component.onCompleted: console.info("taylor-theme: " + scheme)

    readonly property color bg: scheme === "slate" ? slateBg : s.bg
    readonly property color panel: s.panel
    readonly property color window: scheme === "slate" ? mix(slateBg, Qt.color("#FFFFFF"), 0.02) : s.window
    readonly property color text: (scheme === "slate" && light) ? "#1C1C1A" : s.text
    readonly property color text2: (scheme === "slate" && light) ? "#3A3A36" : s.text2
    readonly property color muted: (scheme === "slate" && light) ? "#5E5E58" : s.muted
    readonly property color accent: s.accent
    readonly property color soft: s.soft            // the brief's "light green"
    readonly property color star: s.star
    readonly property color accentInk: s.ink
    readonly property color line: light ? Qt.rgba(28 / 255, 28 / 255, 26 / 255, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color dim: light ? Qt.rgba(28 / 255, 28 / 255, 26 / 255, 0.2) : Qt.rgba(1, 1, 1, 0.2)
    readonly property color sel: alpha(accent, light ? 0.12 : 0.14)
    readonly property color chip: light ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
    readonly property color track: light ? "#D8D6D0" : "#2A2E2C"
    readonly property color mute: "#D9826B"
    readonly property color glass: alpha(panel, light ? 0.86 : 0.74)
    readonly property color dock: alpha(panel, light ? 0.9 : 0.8)
    readonly property color bar: alpha(window, 0.93)
    readonly property color warm: "#F4EBD0"         // brightness on her volume and brightness ring
    readonly property string sans: "Manrope"
    readonly property string mono: "Share Tech Mono"
    readonly property string hex: String(accent).slice(1)   // for Hyprland's border colour

    // ---- reduced motion ----
    property bool systemStill: false
    readonly property bool still: Prefs.reduceMotion || systemStill || Quickshell.env("TAYLOR_STILL") === "1"
    Process {
        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface enable-animations 2>/dev/null || echo true"]
        stdout: StdioCollector { onStreamFinished: t.systemStill = this.text.trim() === "false" }
    }
    // ipc: quickshell ipc call theme scheme night (Settings does the same from inside; the tests use this)
    IpcHandler {
        target: "theme"
        function scheme(name: string): void { if (["taylor", "quiet", "night", "slate"].indexOf(name) >= 0) { Prefs.scheme = name; } }
        function current(): string { return t.scheme; }
    }
    // a motion length, or none at all when she asked for less motion
    function ms(v) { return still ? 0 : v; }
}
