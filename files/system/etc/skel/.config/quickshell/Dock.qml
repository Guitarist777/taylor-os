// The floating dock, top centre (mockup: a dark pill of icon buttons, the TAYLOR "J" chip first).
// Buttons: TAYLOR, files, browser, games, messages, mixer (show/hide), notes, settings.
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    signal toggleMixer()
    anchors { top: true }
    margins { top: 10 }
    implicitWidth: pill.width
    implicitHeight: 48
    color: "transparent"
    exclusiveZone: 58
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-dock"

    // TAYLOR's page on this PC (the tailnet name "home"); opens in the browser until TAYLOR has an app here.
    readonly property string taylorUrl: "https://home.tail0b45b7.ts.net/"

    readonly property var buttons: [
        { icon: "", letter: "J", tip: "TAYLOR", run: ["xdg-open", taylorUrl] },
        { icon: "system-file-manager", tip: "Files", run: ["dolphin"] },
        { icon: "internet-web-browser", tip: "Browser", run: ["xdg-open", "https://"] },
        { icon: "input-gaming", tip: "Games", run: ["steam"] },
        { icon: "mail-message", tip: "Messages", run: ["xdg-open", taylorUrl] },
        { icon: "audio-volume-high", tip: "Mixer", mixer: true },
        { icon: "accessories-text-editor", tip: "Notes", run: ["kate"] },
        { icon: "preferences-system", tip: "Settings", run: ["systemsettings"] }
    ]

    Rectangle {
        id: pill
        height: 48
        width: icons.width + 16
        radius: 14
        color: win.theme.dock
        border.color: win.theme.line
        border.width: 1

        Row {
            id: icons
            anchors.centerIn: parent
            spacing: 6
            Repeater {
                model: win.buttons
                delegate: Rectangle {
                    required property var modelData
                    width: 36; height: 36; radius: 9
                    color: hover.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.16) : "transparent"
                    HoverHandler { id: hover }

                    Rectangle {
                        visible: modelData.letter !== undefined
                        anchors.centerIn: parent
                        width: 26; height: 26; radius: 8
                        color: win.theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: modelData.letter || ""
                            font.family: win.theme.sans
                            font.weight: Font.Bold
                            font.pixelSize: 13
                            color: win.theme.accentInk
                        }
                    }
                    IconImage {
                        visible: modelData.letter === undefined
                        anchors.centerIn: parent
                        implicitSize: 20
                        source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.mixer) win.toggleMixer();
                            else Quickshell.execDetached(modelData.run);
                        }
                    }
                }
            }
        }
    }
}
