// The window bar, top right, on the dock's line (her pick 2026-11-18: "a slim bar with an X"). Hyprland draws no title
// bars, so a window whose app draws none (Dolphin, Kate, the terminal) had no X. This shows the window she is in (the
// app's icon and the window's name) and an X that closes it. The close is the polite kind (the app is asked, so it can
// still say "save changes?"). The bar is hidden when no window is open.
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    readonly property var top: ToplevelManager.activeToplevel
    readonly property var entry: top ? DesktopEntries.heuristicLookup(top.appId) : null
    readonly property string iconSource: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""

    // her windows (Covers.qml): it steps away with the dock when a snapped or full-screen window reaches the top, so it never
    // sits over the window's own corner, and comes back with the dock at the top edge
    // and it is not shown on an empty workspace (the last window she used is on another one)
    readonly property bool wsHasWindows: Hyprland.focusedWorkspace === null || Hyprland.focusedWorkspace.toplevels.values.length > 0
    visible: top !== null && Covers.dockMapped && wsHasWindows
    anchors { top: true; right: true }
    margins { top: 18; right: 14 }
    implicitWidth: pill.width
    implicitHeight: pill.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-windowbar"

    Rectangle {
        id: pill
        height: 40
        width: row.width + 14
        radius: 12
        opacity: Covers.dockShown
        transform: Translate { y: -(1 - Covers.dockShown) * 66 }
        color: win.theme.dock
        border.color: win.theme.line
        border.width: 1

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            spacing: 9

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                visible: win.iconSource !== ""
                implicitSize: 18
                source: win.iconSource
            }
            Text {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 300)
                elide: Text.ElideRight
                text: win.top ? (win.top.title || (win.entry ? win.entry.name : win.top.appId)) : ""
                font.family: win.theme.sans
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: win.theme.text2
            }
            // the X
            Rectangle {
                id: closeButton
                objectName: "taylor-close"
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28; radius: 8
                color: closeHover.hovered ? win.theme.mute : win.theme.chip
                HoverHandler { id: closeHover }
                Canvas {
                    anchors.centerIn: parent
                    width: 12; height: 12
                    property color ink: closeHover.hovered ? "#FFFFFF" : win.theme.text
                    onInkChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        g.strokeStyle = ink;
                        g.lineWidth = 2;
                        g.lineCap = "round";
                        g.beginPath();
                        g.moveTo(1, 1); g.lineTo(11, 11);
                        g.moveTo(11, 1); g.lineTo(1, 11);
                        g.stroke();
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (win.top) win.top.close()
                }
            }
        }
    }
}
