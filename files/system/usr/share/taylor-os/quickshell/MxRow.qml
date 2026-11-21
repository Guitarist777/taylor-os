// One setting as a thin line (her design tour, the Mixer window's sound shaping): its name, the line, its value.
import QtQuick

Row {
    id: r
    property string label
    property real from: 0
    property real to: 1
    property real value: 0
    property bool centred: false
    property bool active: true
    property string shown: ""
    property real lineWidth: 170
    signal moved(real v)
    spacing: 10
    height: 26
    Text { width: 84; text: r.label; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.sans; font.pixelSize: 12; color: Theme.muted }
    MxLine {
        id: ln
        width: r.lineWidth
        anchors.verticalCenter: parent.verticalCenter
        from: r.from; to: r.to; value: r.value; centred: r.centred; active: r.active
        onMoved: (v) => r.moved(v)
    }
    Text { width: 70; horizontalAlignment: Text.AlignRight; text: r.shown; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.sans; font.pixelSize: 12; font.features: { "tnum": 1 }; color: Theme.soft }
}
