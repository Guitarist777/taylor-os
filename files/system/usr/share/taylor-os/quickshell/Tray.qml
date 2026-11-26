// The tray, bottom right (mockup: dark pill, wifi and sound icons, time over date).
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property real arrive: 1           // her arrival after signing in (shell.qml): 0 hidden, 1 in place
    property int waiting: 0           // her notifications waiting (her design tour, part 5): the green count
    property bool wants: false        // TAYLOR wants her (TaylorPanel.qml): her dot here blinks
    signal countClicked()
    signal taylorClicked()            // her dot by the clock opens her (her brief, 2026-11-25)

    // How she is connected (2026-11-23: the icon was always Wi-Fi, but her PC is on a cable): a cable wins over Wi-Fi,
    // Wi-Fi shows its signal in four steps, nothing connected shows offline. NetworkManager is asked every 5 seconds.
    property string netIcon: "network-wired-activated"
    Process {
        id: netRead
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device 2>/dev/null; echo ---; nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("---"), devs = parts[0].split("\n");
                let wired = false, wifi = false, sig = -1;
                for (const l of devs) {
                    if (/^ethernet:connected$/.test(l.trim())) wired = true;
                    if (/^wifi:connected$/.test(l.trim())) wifi = true;
                }
                for (const l of (parts[1] || "").split("\n")) { const m = l.trim().match(/^\*:(\d+)$/); if (m) sig = parseInt(m[1]); }
                win.netIcon = wired ? "network-wired-activated"
                    : wifi ? (sig >= 75 ? "network-wireless-signal-excellent" : sig >= 50 ? "network-wireless-signal-good"
                              : sig >= 25 ? "network-wireless-signal-ok" : "network-wireless-signal-weak")
                    : "network-offline";
            }
        }
    }
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: netRead.running = true }
    anchors { bottom: true; right: true }
    margins { bottom: 14; right: 14 }
    implicitWidth: pill.width + (waiting > 0 ? count.width + 10 : 0)
    implicitHeight: 52
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-tray"
    visible: Covers.trayMapped     // her windows (Covers.qml): away from a covering window, back at the bottom edge

    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property bool soundOff: Pipewire.defaultAudioSink !== null && Pipewire.defaultAudioSink.audio !== null && Pipewire.defaultAudioSink.audio.muted

    // The green count, left of the tray: how many notifications are waiting. A click shows or hides her list.
    Rectangle {
        id: count
        visible: win.waiting > 0
        opacity: win.arrive * Covers.trayShown
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
        opacity: win.arrive * Covers.trayShown
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
                width: 18; height: 18; sourceSize: Qt.size(36, 36)
                source: Quickshell.iconPath(win.netIcon, "network-wired")   // her icon set; follows how she is connected (netRead)
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["systemsettings", "kcm_networkmanagement"]) }
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; sourceSize: Qt.size(36, 36)
                source: Quickshell.iconPath(win.soundOff ? "audio-volume-muted" : "audio-volume-high", "audio-card")   // her icon set
                MouseArea {
                    anchors.fill: parent
                    onClicked: { const s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted }
                }
            }
            // TAYLOR's dot (her preview's trayT): a ring with a green centre; it blinks while she wants Jessica
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                Rectangle { anchors.centerIn: parent; width: 13; height: 13; radius: 6.5; color: "transparent"; border.width: 1.5; border.color: win.theme.accent }
                Rectangle {
                    id: herDot
                    anchors.centerIn: parent; width: 4.4; height: 4.4; radius: 2.2; color: win.theme.accent
                    SequentialAnimation on opacity {
                        id: blink
                        running: win.wants && !win.theme.still; loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.15; to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                    Connections { target: blink; function onRunningChanged() { if (!blink.running) herDot.opacity = 1; } }
                }
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { console.info("taylor-tray: her dot was clicked"); win.taylorClicked(); } }
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
