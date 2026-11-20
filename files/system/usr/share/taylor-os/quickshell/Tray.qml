// The tray, bottom right (mockup: dark pill, wifi and sound icons, time over date).
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property real arrive: 1           // her arrival after signing in (shell.qml): 0 hidden, 1 in place
    property int waiting: 0           // her notifications waiting (her design tour, part 5): the green count
    signal countClicked()
    anchors { bottom: true; right: true }
    margins { bottom: 14; right: 14 }
    implicitWidth: pill.width + (waiting > 0 ? count.width + 10 : 0)
    implicitHeight: 52
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-tray"

    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property bool soundOff: Pipewire.defaultAudioSink !== null && Pipewire.defaultAudioSink.audio !== null && Pipewire.defaultAudioSink.audio.muted

    // The green count, left of the tray: how many notifications are waiting. A click shows or hides her list.
    Rectangle {
        id: count
        visible: win.waiting > 0
        opacity: win.arrive
        anchors { right: pill.left; rightMargin: 10; verticalCenter: pill.verticalCenter }
        width: Math.max(32, num.implicitWidth + 16); height: 32; radius: 16
        color: win.theme.accent
        Text {
            id: num
            anchors.centerIn: parent
            text: String(win.waiting)
            font.family: win.theme.sans
            font.weight: Font.DemiBold
            font.pixelSize: 15
            color: win.theme.accentInk
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { console.info("taylor-notes: the count was clicked"); win.countClicked(); }
        }
    }

    Rectangle {
        id: pill
        anchors.right: parent.right
        height: 52
        opacity: win.arrive
        width: content.width + 32
        radius: 14
        color: win.theme.bar
        border.color: win.theme.line
        border.width: 1

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 14
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 15; height: 15; sourceSize: Qt.size(30, 30)
                source: Qt.resolvedUrl("icons/wifi.svg")
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["systemsettings", "kcm_networkmanagement"]) }
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 15; height: 15; sourceSize: Qt.size(30, 30)
                source: Qt.resolvedUrl(win.soundOff ? "icons/sound-off.svg" : "icons/sound.svg")
                MouseArea {
                    anchors.fill: parent
                    onClicked: { const s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(clock.date, "h:mm AP")
                    font.family: win.theme.sans
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                    color: win.theme.text
                }
                Text {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(clock.date, "M/d/yyyy")
                    font.family: win.theme.sans
                    font.pixelSize: 11
                    color: win.theme.muted
                }
            }
        }
    }
}
