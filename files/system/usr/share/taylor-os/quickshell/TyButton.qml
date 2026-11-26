// A plain button in TAYLOR's panel (her preview's .ty-b): a thin outline, words, the outline green on hover.
import QtQuick

Rectangle {
    id: b
    property real s: 1
    property QtObject theme
    property string label: ""
    property bool square: false
    signal hit()
    width: square ? 28 * s : t.implicitWidth + 20 * s
    height: 28 * s
    radius: 8 * s
    color: "transparent"
    border.width: 1
    border.color: ma.containsMouse ? theme.accent : theme.dim
    Text { id: t; anchors.centerIn: parent; text: b.label; font.family: b.theme.sans; font.pixelSize: (b.square ? 16 : 12) * b.s; color: b.theme.text2 }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.hit() }
}
