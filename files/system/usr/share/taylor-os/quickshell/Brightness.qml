pragma Singleton
// Her screen's brightness, through the screen itself (DDC/CI, ddcutil). Brightness keys on a desktop PC usually do
// nothing on an external monitor (her brief); a monitor that answers DDC/CI can be set from the PC. At start this asks
// the first monitor for its brightness (VCP code 10); if no monitor answers, `available` stays false and everything
// that uses it (the Display row in Settings, the brightness half of the volume and brightness ring) hides itself.
// ddcutil can reach the screen without root: Bazzite loads i2c-dev and its udev rule gives the signed-in seat the
// i2c devices of the graphics card (uaccess).
// Keys: Hyprland's XF86MonBrightnessUp / Down call "quickshell ipc call brightness up|down".
// Untested on her monitor (the virtual PC has no monitor that speaks DDC/CI).
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: b
    property bool available: false
    property bool probed: false
    property int level: 80            // 0..100
    property int maxRaw: 100
    property real changedAt: 0        // when a key or Settings last changed it (the ring shows on this)
    property int pending: -1

    function set(v) {
        if (!available) return;
        v = Math.max(0, Math.min(100, Math.round(v)));
        level = v;
        pending = Math.round(v * maxRaw / 100);
        if (!setter.running) flush();
    }
    function step(d) {
        if (!available) { console.info("taylor-brightness: no monitor answers; the key does nothing"); return; }
        set(level + d);
        changedAt = Date.now() / 1000;
    }
    function flush() {
        if (pending < 0) return;
        setter.command = ["ddcutil", "--noverify", "--sleep-multiplier", "0.4", "setvcp", "10", String(pending)];
        pending = -1;
        setter.running = true;
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v ddcutil >/dev/null || exit 3; timeout 20 ddcutil --brief getvcp 10 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "VCP 10 C 80 100"
                const m = this.text.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                if (m && parseInt(m[2]) > 0) {
                    b.maxRaw = parseInt(m[2]);
                    b.level = Math.round(parseInt(m[1]) * 100 / b.maxRaw);
                    b.available = true;
                }
            }
        }
        onExited: (code) => {
            b.probed = true;
            console.info("taylor-brightness: " + (b.available ? "the monitor answers (" + b.level + ")" : "no monitor answers DDC/CI (exit " + code + "); brightness hidden"));
        }
    }
    Process {
        id: setter
        onExited: (code) => { if (code !== 0) console.info("taylor-brightness: the monitor did not take it (exit " + code + ")"); b.flush(); }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { b.step(5); }
        function down(): void { b.step(-5); }
        function get(): int { return b.available ? b.level : -1; }
    }
}
