// A plain word that can be clicked or chosen (her brief: "a choice between a few options is plain words with a thin
// green underline under the chosen one").
import QtQuick

Item {
    id: w
    property string text
    property int size: 13
    property bool chosen: false
    property bool clickable: true
    property color tint: chosen ? Theme.text : Theme.muted
    signal clicked()
    implicitWidth: t.implicitWidth
    implicitHeight: t.implicitHeight + 4
    activeFocusOnTab: clickable
    Text { id: t; text: w.text; font.family: Theme.sans; font.pixelSize: w.size; color: w.tint }
    Rectangle { y: t.implicitHeight + 1; width: t.implicitWidth; height: 1.5; color: Theme.accent; visible: w.chosen }
    Rectangle { visible: w.activeFocus; anchors.fill: parent; anchors.margins: -3; color: "transparent"; radius: 4; border.color: Theme.accent; border.width: 1 }
    MouseArea { anchors.fill: parent; anchors.margins: -3; enabled: w.clickable; cursorShape: Qt.PointingHandCursor; onClicked: w.clicked() }
    Keys.onPressed: (e) => { if (w.clickable && (e.key === Qt.Key_Space || e.key === Qt.Key_Return)) { e.accepted = true; w.clicked(); } }
}
