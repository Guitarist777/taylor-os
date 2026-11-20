// The clock card, top left: big time, date on the right (mockup: 380 wide, radius 22, glass).
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property real arrive: 1           // her arrival after signing in (shell.qml): 0 hidden, 1 in place
    anchors { top: true; left: true }
    margins { top: 40; left: 40 }
    implicitWidth: 380
    implicitHeight: 84
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "taylor-clock"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        opacity: win.arrive
        transform: Translate { x: -(1 - win.arrive) * 80 }   // slides in from the left
        radius: 22
        color: win.theme.glass
        border.color: win.theme.line
        border.width: 1

        Text {
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            text: Qt.formatDateTime(clock.date, "h:mm AP").replace(/\s*[AP]M$/i, "")   // 12-hour, no AM/PM (as in the mockup)
            font.family: win.theme.sans
            font.weight: Font.Light
            font.pixelSize: 46
            color: win.theme.text
        }
        Text {
            anchors { right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 22 }
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            font.family: win.theme.sans
            font.pixelSize: 13
            color: win.theme.muted
        }
    }
}
