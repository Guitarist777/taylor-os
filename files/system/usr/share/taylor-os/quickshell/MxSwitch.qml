// A light switch (her brief): the word On or Off with a small dot beside it, filled green when on, a hollow grey ring
// when off. No pills, no boxes.
import QtQuick

Item {
    id: sw
    property string text
    property bool on: false
    signal toggled()
    implicitWidth: row.width
    implicitHeight: 18
    activeFocusOnTab: true
    Row {
        id: row
        spacing: 7
        anchors.verticalCenter: parent.verticalCenter
        Text { text: sw.text + (sw.on ? " on" : " off"); font.family: Theme.sans; font.pixelSize: 13; color: sw.on ? Theme.text : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 9; height: 9; radius: 4.5
            color: sw.on ? Theme.accent : "transparent"
            border.width: 1.5; border.color: sw.on ? Theme.accent : Theme.muted
        }
    }
    Rectangle { visible: sw.activeFocus; anchors.fill: parent; anchors.margins: -3; color: "transparent"; radius: 4; border.color: Theme.accent; border.width: 1 }
    MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    Keys.onPressed: (e) => { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) { e.accepted = true; sw.toggled(); } }
}
