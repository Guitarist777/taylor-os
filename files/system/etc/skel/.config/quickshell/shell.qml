// TAYLOR OS desktop, from her mockup "7 · Dock your way + mixer widget" (the TAYLOR theme).
// Quickshell draws it on top of Hyprland: the clock card and mixer sit on the desktop (under windows),
// the dock floats at the top, the tray sits bottom right. The TAYLOR dial and "TAYLOR has a question"
// pill come later, once TAYLOR runs on Linux.
import Quickshell
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
        readonly property color onAccent: "#06140D"
        readonly property color chip: Qt.rgba(1, 1, 1, 0.06)
        readonly property color track: "#2A2E2C"
        readonly property color mute: "#D9826B"
        readonly property color dock: Qt.rgba(28 / 255, 30 / 255, 29 / 255, 0.8)
        readonly property color bar: Qt.rgba(20 / 255, 22 / 255, 21 / 255, 0.93)
        readonly property string sans: "Manrope"
        readonly property string mono: "Share Tech Mono"
    }

    property bool mixerShown: true

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: perScreen
                required property var modelData
                ClockCard { screen: perScreen.modelData; theme: root.c }
                Mixer { screen: perScreen.modelData; theme: root.c; visible: root.mixerShown }
                Dock { screen: perScreen.modelData; theme: root.c; onToggleMixer: root.mixerShown = !root.mixerShown }
                Tray { screen: perScreen.modelData; theme: root.c }
            }
        }
    }
}
