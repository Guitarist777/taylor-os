// The mixer on the desktop (her design tour, "Mixer on the desktop"): the quick view of the TaylorOS mixer, on the left
// of her main screen under the clock card. Master on top, then Game, Chat, Media, Aux and Mic, one thin line each:
// the line is the volume (drag anywhere along it, the number follows), the tiny dots under it are the live level, the
// green dot at the end mutes (a hollow grey ring when muted, and the line turns grey). Channels with nothing playing
// are dimmed. The word in the corner switches everything between the speakers and the headset; "Mixer" opens the
// Mixer window. The state and the sound itself: MixerCore.qml.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property real arrive: 1           // her arrival after signing in (shell.qml): 0 hidden, 1 in place
    signal openMixer()
    anchors { top: true; left: true }
    margins { top: 40 + 84 + 14; left: 40 }
    implicitWidth: 250
    implicitHeight: panel.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "taylor-mixer"

    onVisibleChanged: MixerCore.widgetShown = visible
    Component.onCompleted: MixerCore.widgetShown = visible

    Rectangle {
        id: panel
        width: parent.width
        height: col.height + 22
        opacity: win.arrive
        transform: Translate { x: -(1 - win.arrive) * 80 }   // slides in from the left
        radius: 12
        color: Theme.alpha(Theme.panel, 0.93)
        border.color: Theme.light ? Theme.line : Theme.alpha(Theme.text, 0.12)
        border.width: 1

        Column {
            id: col
            x: 14; y: 12
            width: parent.width - 28

            Item {
                width: parent.width; height: 24
                Text {
                    id: title
                    Component.onCompleted: MixerCore.spot("w:title", title)
                    y: 2
                    text: "Mixer"
                    font.family: Theme.sans; font.pixelSize: 13; font.weight: Font.Medium
                    color: Theme.text
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: win.openMixer() }
                }
                Text {
                    id: corner
                    Component.onCompleted: MixerCore.spot("w:out", corner)
                    anchors.right: parent.right
                    anchors.baseline: title.baseline
                    text: MixerCore.mainWord
                    font.family: Theme.sans; font.pixelSize: 12
                    color: Theme.soft
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: MixerCore.toggleMain() }
                }
            }

            Repeater {
                model: MixerCore.keys
                delegate: Column {
                    id: rowc
                    required property string modelData
                    required property int index
                    width: col.width
                    WidgetRow { width: parent.width; k: rowc.modelData }
                    Item {           // the line under Master
                        visible: rowc.index === 0
                        width: parent.width; height: 9
                        Rectangle { y: 4; width: parent.width; height: 1; color: Theme.alpha(Theme.text, 0.09) }
                    }
                }
            }
        }
    }

    component WidgetRow: Item {
        id: r
        property string k
        readonly property bool master: k === "master"
        readonly property bool quiet: !master && !MixerCore.playing(k)
        readonly property bool isMuted: MixerCore.muted(k)
        height: 26
        opacity: MixerCore.live(k) ? 1 : 0.45
        Text {
            x: 0; width: 62; anchors.verticalCenter: parent.verticalCenter
            text: MixerCore.names[r.k]
            elide: Text.ElideRight
            font.family: Theme.sans; font.pixelSize: 12
            color: r.master ? Theme.text : Theme.muted
            opacity: r.quiet ? 0.45 : 1
        }
        Item {
            id: tr
            x: 70; width: r.width - 70 - 8 - 26 - 8 - 12; height: 16
            anchors.verticalCenter: parent.verticalCenter
            MxLine {
                id: wl
                Component.onCompleted: MixerCore.spot("w:line:" + r.k, wl)
                anchors.fill: parent
                value: MixerCore.vol(r.k)
                grey: r.isMuted
                active: MixerCore.live(r.k)
                onMoved: (v) => MixerCore.setVol(r.k, v)
            }
            MxDots {
                y: 12; width: tr.width; count: 12
                level: MixerCore.levels[r.k] || 0
                opacity: r.quiet ? 0.45 : 1
            }
        }
        Text {
            x: r.width - 12 - 8 - 26; width: 26; anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(MixerCore.vol(r.k) * 100)
            font.family: Theme.sans; font.pixelSize: 12; font.features: { "tnum": 1 }
            color: Theme.muted
            opacity: r.isMuted ? 0.5 : 1
        }
        MxMute {
            id: wm
            Component.onCompleted: MixerCore.spot("w:mute:" + r.k, wm)
            x: r.width - 12; anchors.verticalCenter: parent.verticalCenter
            muted: r.isMuted
            onClicked: MixerCore.toggleMute(r.k)
        }
    }
}
