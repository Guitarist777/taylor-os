pragma Singleton
// Her screen's brightness, through the screen itself (DDC/CI, ddcutil). Brightness keys on a desktop PC usually do
// nothing on an external monitor (her brief); a monitor that answers DDC/CI can be set from the PC. At start this asks
// the first monitor for its brightness (VCP code 10); if no monitor answers, `available` stays false and everything
// that uses it (the Display row in Settings, the brightness half of the volume and brightness ring) hides itself.
// ddcutil can reach the screen without root: Bazzite loads i2c-dev and its udev rule gives the signed-in seat the
// i2c devices of the graphics card (uaccess).
// Keys: Hyprland's XF86MonBrightnessUp / Down call "quickshell ipc call brightness up|down".
// As she drags (2026-11-21, her "react in real time"): the start-up look also finds the monitor's I2C bus, and
// /usr/libexec/taylor-ddc stays running on it and sends each new level straight to the monitor (25-28 ms a write on
// her monitor, against 0.3-0.57 s for a ddcutil each time). If it can't be used, ddcutil as before.
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
        const raw = Math.round(v * maxRaw / 100);
        if (fast.ready) { fast.write(raw + "\n"); return; }
        pending = raw;
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
        // the first monitor ddcutil finds (as a plain ddcutil would use), its bus, then its brightness on that bus
        command: ["sh", "-c", "command -v ddcutil >/dev/null || exit 3; bus=$(timeout 20 ddcutil detect --brief 2>/dev/null | sed -n 's|.*I2C bus:.*/dev/i2c-\\([0-9][0-9]*\\).*|\\1|p' | head -1); echo \"BUS ${bus:-none}\"; if [ -n \"$bus\" ]; then timeout 20 ddcutil --bus \"$bus\" --brief getvcp 10 2>/dev/null; else timeout 20 ddcutil --brief getvcp 10 2>/dev/null; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "BUS 3" then "VCP 10 C 80 100"
                const m = this.text.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                if (m && parseInt(m[2]) > 0) {
                    b.maxRaw = parseInt(m[2]);
                    b.level = Math.round(parseInt(m[1]) * 100 / b.maxRaw);
                    b.available = true;
                }
                const bm = this.text.match(/BUS (\d+)/);
                if (b.available && bm) { fast.command = ["/usr/libexec/taylor-ddc", bm[1]]; fast.running = true; }
            }
        }
        onExited: (code) => {
            b.probed = true;
            console.info("taylor-brightness: " + (b.available ? "the monitor answers (" + b.level + ")" : "no monitor answers DDC/CI (exit " + code + "); brightness hidden"));
        }
    }
    // the live line to the monitor (taylor-ddc); until it says "ready", and if it ever stops, ddcutil does it
    Process {
        id: fast
        property bool ready: false
        stdinEnabled: true
        stdout: SplitParser {
            onRead: (l) => {
                if (l === "ready") { fast.ready = true; console.info("taylor-brightness: live to the monitor (" + fast.command.join(" ") + ")"); }
                else if (l.startsWith("error")) console.info("taylor-brightness: taylor-ddc " + l + "; ddcutil instead");
                else if (l.startsWith("set ")) b.sent = parseInt(l.slice(4));
            }
        }
        onExited: (code) => { if (ready) console.info("taylor-brightness: taylor-ddc stopped (exit " + code + "); ddcutil instead"); ready = false; }
    }
    property int sent: -1             // the last level taylor-ddc wrote (the monitor's scale), for the log and the tests
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
