// A row (or column) of tiny dots that shows a live level: the first `on` dots light up light green.
import QtQuick

Item {
    id: d
    property int count: 12
    property real level: 0               // 0..1
    property bool vertical: false
    property real gap: 3
    readonly property int on: Math.round(Math.max(0, Math.min(1, level)) * count)
    implicitWidth: vertical ? 3 : count * 3 + (count - 1) * gap
    implicitHeight: vertical ? count * 3 + (count - 1) * gap : 3
    Repeater {
        model: d.count
        delegate: Rectangle {
            required property int index
            width: 3; height: 3; radius: 1.5
            readonly property real g: d.count > 1 ? ((d.vertical ? d.height : d.width) - 3) / (d.count - 1) : 0
            x: d.vertical ? 0 : index * g
            y: d.vertical ? d.height - 3 - index * g : 0
            color: index < d.on ? Theme.soft : Theme.alpha(Theme.text, 0.14)
        }
    }
}
