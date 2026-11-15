// The tray, bottom right (mockup: dark pill, wifi and sound icons, time over date).
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    anchors { bottom: true; right: true }
    margins { bottom: 14; right: 14 }
    implicitWidth: pill.width
    implicitHeight: 52
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-tray"

    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property bool soundOff: Pipewire.defaultAudioSink !== null && Pipewire.defaultAudioSink.audio !== null && Pipewire.defaultAudioSink.audio.muted

    Rectangle {
        id: pill
        height: 52
        width: content.width + 32
        radius: 14
        color: win.theme.bar
        border.color: win.theme.line
        border.width: 1

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 14
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: Quickshell.iconPath("network-wireless-symbolic", "network-wireless")
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["systemsettings", "kcm_networkmanagement"]) }
            }
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: Quickshell.iconPath(win.soundOff ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic", "audio-volume-high")
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
