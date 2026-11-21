// The dock's strip at the top of her main screen (66 px: the dock's 10 px margin and 56 px pill), kept here rather than by
// the dock itself so the dock can step away from a snapped or full-screen window (Covers.qml) without the strip
// changing: a maximised Settings or Files window stays under the dock, new windows open below it. Snaps and full screen
// ignore the strip (her brief: edge to edge). Invisible, takes no clicks.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    anchors { top: true; left: true; right: true }
    implicitHeight: 1
    color: "transparent"
    exclusiveZone: 66
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "taylor-reserve"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
}
