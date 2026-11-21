// Her workspace dots (her build brief, "Workspaces"; her design tour, part 7): small dots just under the dock, one per
// workspace, the current one a short green dash that glides to the next as the windows slide across. At least three
// dots (as in her tour), more once she uses more. They step away with the dock (Covers.qml) and take no clicks.
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property real arrive: 1           // her arrival after signing in (shell.qml)

    readonly property var mon: win.screen ? Hyprland.monitorFor(win.screen) : null
    readonly property int current: mon && mon.activeWorkspace ? Math.max(1, mon.activeWorkspace.id) : 1
    readonly property int count: {
        let n = Math.max(3, current);
        const ws = Hyprland.workspaces.values;
        for (let i = 0; i < ws.length; i++) {
            const w = ws[i];
            if (w && w.id > 0 && w.id <= 10 && (!w.monitor || !mon || w.monitor === mon)) n = Math.max(n, w.id);
        }
        return Math.min(10, n);
    }
    property real pos: current - 1
    Behavior on pos { NumberAnimation { duration: win.theme.ms(500); easing.type: Easing.OutQuint } }
    onCurrentChanged: console.info("taylor-windows: workspace " + current)

    anchors { top: true }
    margins { top: 75 }               // the dock ends at 66 (10 + 56): the tour's 9 px below it
    implicitWidth: count * 20 + 8
    implicitHeight: 8
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-workspaces"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    visible: Covers.dockMapped

    Item {
        anchors.fill: parent
        opacity: win.arrive * Covers.dockShown
        transform: Translate { y: -(1 - Covers.dockShown) * 66 }
        Repeater {
            model: win.count
            delegate: Rectangle {
                required property int index
                readonly property real act: Math.max(0, 1 - Math.abs(win.pos - index))
                width: 6 + 12 * act
                height: 6
                radius: 3
                x: win.width / 2 + (index - (win.count - 1) / 2) * 20 - width / 2
                y: 1
                color: act > 0.5 ? win.theme.accent : Qt.rgba(win.theme.text.r, win.theme.text.g, win.theme.text.b, 0.6)
                opacity: 0.45 + 0.55 * act
            }
        }
    }
}
