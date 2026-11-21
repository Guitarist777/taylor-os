// The floating dock, top centre (mockup: a dark pill of 48 px buttons with 22 px line icons, the TAYLOR "J" chip
// first, a thin divider before Settings). The icons are the mockup's own drawings (icons/*.svg).
// Buttons: TAYLOR, files, browser, games, messages, mixer (show/hide), notes | settings.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property bool mixerShown: true
    property real arrive: 1           // her arrival after signing in (shell.qml): 0 hidden, 1 in place
    signal toggleMixer()
    anchors { top: true }
    margins { top: 10 }
    implicitWidth: pill.width
    implicitHeight: pill.height
    color: "transparent"
    exclusiveZone: 66
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-dock"

    // TAYLOR's page on this PC (the tailnet name "home"); opens in the browser until TAYLOR has an app here.
    readonly property string taylorUrl: "https://home.tail0b45b7.ts.net/"

    readonly property var buttons: [
        { letter: "J", tip: "TAYLOR", run: ["xdg-open", taylorUrl] },
        { icon: "files", tip: "Files", run: ["dolphin"] },
        { icon: "browser", tip: "Browser", run: ["xdg-open", "https://"] },
        { icon: "games", tip: "Games", run: ["steam"] },
        { icon: "chat", tip: "Messages", run: ["xdg-open", taylorUrl] },
        { icon: "studio", tip: "Mixer", mixer: true },
        { icon: "notes", tip: "Notes", run: ["kate"] },
        { divider: true },
        { icon: "settings", tip: "Settings", run: ["systemsettings"] }
    ]

    Rectangle {
        id: pill
        height: 56
        opacity: win.arrive
        transform: Translate { y: -(1 - win.arrive) * 66 }   // drops in from the top
        width: icons.width + 16
        radius: 16
        color: win.theme.dock
        border.color: win.theme.line
        border.width: 1

        Row {
            id: icons
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: win.buttons
                delegate: Item {
                    id: btn
                    required property var modelData
                    width: modelData.divider ? 13 : 48
                    height: 48

                    // the thin line before Settings
                    Rectangle {
                        visible: btn.modelData.divider === true
                        anchors.centerIn: parent
                        width: 1; height: 28
                        color: win.theme.line
                    }

                    Rectangle {
                        visible: btn.modelData.divider !== true
                        anchors.fill: parent
                        radius: 12
                        color: hover.hovered ? win.theme.chip : "transparent"
                        HoverHandler { id: hover }

                        // TAYLOR's chip
                        Rectangle {
                            visible: btn.modelData.letter !== undefined
                            anchors.centerIn: parent
                            width: 30; height: 30; radius: 9
                            color: win.theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: btn.modelData.letter || ""
                                font.family: win.theme.mono
                                font.pixelSize: 15
                                color: win.theme.accentInk
                            }
                        }
                        Image {
                            visible: btn.modelData.icon !== undefined
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -3
                            width: 22; height: 22
                            sourceSize: Qt.size(44, 44)
                            source: btn.modelData.icon ? Qt.resolvedUrl("icons/" + btn.modelData.icon + ".svg") : ""
                            smooth: true
                        }
                        // the little bar under an icon: green under the mixer while it is showing (as in the mockup)
                        Rectangle {
                            visible: btn.modelData.mixer === true
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                            width: win.mixerShown ? 14 : 5; height: 3; radius: 2
                            color: win.mixerShown ? win.theme.accent : "transparent"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btn.modelData.mixer) win.toggleMixer();
                                else if (btn.modelData.run) Quickshell.execDetached(btn.modelData.run);
                            }
                        }
                    }
                }
            }
        }
    }
}
