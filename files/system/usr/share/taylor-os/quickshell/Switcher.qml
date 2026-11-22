// Switching windows (her ask 2026-11-22: "that thing on Mac, Cmd + Tab"). Windows key + Tab, or Alt + Tab as on Windows,
// shows a strip of her open windows in the middle of the screen, the one she used last first: each one's app icon
// with its window name under it. While the key is held, Tab moves along (Shift + Tab goes back); letting go of the
// Windows key (or Alt) brings that window forward. Escape, or a click outside, closes the strip and changes nothing.
// Windows that Windows key + D put aside are in the strip too; picking one brings it back.
// Hyprland sends the keys (windows.lua binds them, and the letting go): "quickshell ipc call switcher next | prev |
// commit | cancel". Colours are her scheme's (Theme.qml). Less motion: the strip appears with no fade.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: sw
    property QtObject theme
    property bool open: false
    property int sel: 0
    property var items: []          // the toplevels, most recent first, while open

    // the order she used them in (the one in front first), kept as she moves between windows
    property var order: []
    readonly property var active: ToplevelManager.activeToplevel
    onActiveChanged: {
        if (!active) return;
        const o = order.filter((t) => t !== active && ToplevelManager.toplevels.values.indexOf(t) >= 0);
        o.unshift(active);
        order = o;
    }
    function recent() {
        const all = ToplevelManager.toplevels.values.filter((t) => !/^(org\.)?quickshell$/i.test(t.appId || ""));
        const known = order.filter((t) => all.indexOf(t) >= 0);
        return known.concat(all.filter((t) => known.indexOf(t) < 0));
    }

    // a safety net: if letting go of the key is ever missed, the strip does not stay over her screen; 4 s with no key
    // pressed switches to the one picked
    Timer { id: idle; interval: 4000; onTriggered: { console.info("taylor-switcher: no key for 4 s, switching"); sw.commit(); } }
    function step(d) {
        idle.restart();
        if (!open) {
            items = recent();
            if (items.length === 0) return;
            sel = items.length > 1 ? (d > 0 ? 1 : items.length - 1) : 0;   // the first press goes to the one before
            open = true;
            console.info("taylor-switcher: open, " + items.length + " windows");
            return;
        }
        if (items.length) sel = (sel + d + items.length) % items.length;
    }
    function commit() {
        idle.stop();
        if (!open) return;
        const t = items[sel];
        open = false;
        if (t) {
            console.info("taylor-switcher: switch to " + (t.appId || "?"));
            // windows put aside by Windows key + D come back first (windows.lua), then this one comes forward
            Quickshell.execDetached(["hyprctl", "eval", "if taylor and taylor.unhide then taylor.unhide() end"]);
            pending = t;
            later.restart();
        }
        items = [];
    }
    property var pending: null
    Timer { id: later; interval: 150; onTriggered: { if (sw.pending) sw.pending.activate(); sw.pending = null; } }
    function cancel() { idle.stop(); if (open) { open = false; items = []; console.info("taylor-switcher: closed, nothing changed"); } }

    IpcHandler {
        target: "switcher"
        function next(): void { sw.step(1); }
        function prev(): void { sw.step(-1); }
        function commit(): void { sw.commit(); }
        function cancel(): void { sw.cancel(); }
        function state(): string { return sw.open ? "open " + sw.sel + "/" + sw.items.length : "closed"; }
    }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-switcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: sw.cancel() }
    Item {
        anchors.fill: parent
        focus: sw.open
        Keys.onEscapePressed: sw.cancel()
        Keys.onReturnPressed: sw.commit()
        Keys.onLeftPressed: sw.step(-1)
        Keys.onRightPressed: sw.step(1)
    }

    Rectangle {
        id: strip
        anchors.centerIn: parent
        readonly property real cell: 112
        width: Math.min(parent.width - 80, row.implicitWidth + 28)
        height: cell + 28
        radius: 18
        color: Qt.rgba(sw.theme.panel.r, sw.theme.panel.g, sw.theme.panel.b, 0.94)
        border.color: sw.theme.line
        border.width: 1
        opacity: sw.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: sw.theme.ms(120) } }
        clip: true

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Repeater {
                model: sw.items
                delegate: Item {
                    id: cellItem
                    required property var modelData
                    required property int index
                    readonly property bool on: index === sw.sel
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData.appId || "")
                    width: strip.cell; height: strip.cell
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: cellItem.on ? Qt.rgba(sw.theme.accent.r, sw.theme.accent.g, sw.theme.accent.b, 0.16) : "transparent"
                        border.width: cellItem.on ? 1.5 : 0
                        border.color: sw.theme.accent
                    }
                    IconImage {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
                        implicitSize: 56
                        source: {
                            const e = cellItem.entry;
                            const n = e && e.icon ? e.icon : (cellItem.modelData.appId || "");
                            return Quickshell.iconPath(n, "application-x-executable");
                        }
                    }
                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: cellItem.modelData.title || (cellItem.entry ? cellItem.entry.name : cellItem.modelData.appId) || ""
                        font.family: sw.theme.sans
                        font.pixelSize: 12
                        color: cellItem.on ? sw.theme.text : sw.theme.muted
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { sw.sel = cellItem.index; sw.commit(); }
                    }
                }
            }
        }
    }
}
