// One mixer channel: level bar, slider, dB, mute (M), name. 46 wide, slider 176 tall (mockup values).
import QtQuick

Item {
    id: strip
    property QtObject theme
    property string label
    property var node: null
    property bool main: false
    readonly property bool live: node !== null && node.audio !== null
    readonly property real level: live ? Math.max(0, Math.min(1, node.audio.volume)) : 0
    readonly property bool muted: live && node.audio.muted
    width: 46
    height: 270
    opacity: live ? 1 : 0.35

    function setFromY(y) {
        if (!live) return;
        node.audio.volume = Math.max(0, Math.min(1, 1 - y / track.height));
    }
    function dbText() {
        if (!live) return "--";
        if (muted) return "MUTED";
        if (level <= 0.0001) return "-inf";
        const db = Math.round(20 * Math.log(Math.pow(level, 3)) / Math.LN10);  // PipeWire's cubic volume curve
        return (db > 0 ? "+" : "") + db + " dB";
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Item {
            id: track
            width: 34
            height: 176
            anchors.horizontalCenter: parent.horizontalCenter

            // the level bar (left, 5 wide)
            Rectangle {
                x: 0; width: 5; height: parent.height; radius: 3
                color: strip.theme.track
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 5; radius: 3
                    height: parent.height * (strip.muted ? 0 : strip.level)
                    color: strip.theme.accent
                    opacity: 0.85
                }
            }
            // the slider (right)
            Rectangle {
                x: 18; width: 6; height: parent.height; radius: 3
                color: strip.theme.track
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 6; radius: 3
                    height: parent.height * strip.level
                    color: strip.muted ? strip.theme.muted : strip.theme.accent
                }
            }
            Rectangle {
                x: 21 - 9
                y: (1 - strip.level) * (parent.height - 18)
                width: 18; height: 18; radius: 9
                color: strip.muted ? strip.theme.muted : strip.theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: strip.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: (m) => strip.setFromY(m.y)
                onPositionChanged: (m) => { if (pressed) strip.setFromY(m.y) }
                onWheel: (w) => { if (strip.live) strip.node.audio.volume = Math.max(0, Math.min(1, strip.level + (w.angleDelta.y > 0 ? 0.03 : -0.03))) }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: strip.dbText()
            font.family: strip.theme.mono
            font.pixelSize: 10
            color: strip.theme.muted
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 30; height: 24; radius: 7
            color: strip.muted ? strip.theme.mute : "transparent"
            border.width: 1
            border.color: strip.muted ? strip.theme.mute : strip.theme.line
            Text {
                anchors.centerIn: parent
                text: "M"
                font.family: strip.theme.mono
                font.pixelSize: 11
                color: strip.muted ? strip.theme.onAccent : strip.theme.text2
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (strip.live) strip.node.audio.muted = !strip.node.audio.muted }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: strip.label
            font.family: strip.theme.sans
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 0.6
            color: strip.main ? strip.theme.accent : strip.theme.text
        }
    }
}
