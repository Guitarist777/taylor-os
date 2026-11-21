// The mute dot (her design tour): green and filled while the channel plays, a hollow grey ring when muted.
import QtQuick

Item {
    id: b
    property bool muted: false
    signal clicked()
    width: 12; height: 12
    activeFocusOnTab: true
    Rectangle {
        anchors.centerIn: parent
        width: 9; height: 9; radius: 4.5
        color: b.muted ? "transparent" : Theme.accent
        border.width: 1.5
        border.color: b.muted ? Theme.muted : Theme.accent
    }
    Rectangle {
        visible: b.activeFocus
        anchors.fill: parent; anchors.margins: -2
        color: "transparent"; radius: 8
        border.color: Theme.accent; border.width: 1
    }
    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    Keys.onPressed: (e) => { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) { e.accepted = true; b.clicked(); } }
}
