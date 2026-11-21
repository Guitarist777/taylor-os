// Progress by the clock (her build brief, "Loading"; her design tour, part 8): a small ring of twelve dots that fills
// dot by dot as a job goes on, with one plain line beside it ("Copying 3 of 24 items"), and ends in a pulse
// ("Copied 24 items"), then fades. Where the numbers come from (only real reports, nothing guessed):
//   - KDE apps' jobs (Dolphin copying or moving a folder, and the like): /usr/libexec/taylor-jobs takes the place of
//     Plasma's job tracker on the session bus and prints each change; this starts it and reads it.
//   - a notification that carries a progress value (the freedesktop "value" hint, 0..100): shell.qml hands it here
//     instead of making it a dot.
// Only the newest running job is drawn. It sits left of the tray, on the same layer as the tray, takes no clicks.
// Reduced motion: dots appear in place and the end is a fade, not a pulse.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property real trayWidth: 200      // the tray's width (shell.qml): this sits just left of it
    readonly property real u: 1.6

    anchors { bottom: true; right: true }
    margins { bottom: 0; right: 14 + trayWidth + 12 }
    implicitWidth: 320
    implicitHeight: 80                // the tray is 52 high, 14 up: the line sits level with it, the dots fly in from further out
    color: "transparent"
    visible: job !== null
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "taylor-progress"

    // jobs by key: {key, title, percent, files, of, done, t0, born: [times each dot filled], doneAt}
    property var jobs: ({})
    property var job: null            // the one drawn
    function now() { return Date.now() / 1000; }
    function report(key, title, percent, files, of, done) {
        let j = jobs[key];
        const T = now();
        if (!j) {
            if (done && percent <= 0) return;          // ended before it ever showed: nothing to show
            j = { key: key, title: "", percent: 0, files: 0, of: 0, done: false, t0: T, born: [], doneAt: 0 };
            jobs[key] = j;
            console.info("taylor-progress: a job started");
        }
        if (title) j.title = String(title);
        j.percent = Math.max(j.percent, Math.max(0, Math.min(100, Number(percent) || 0)));
        j.files = Number(files) || j.files;
        j.of = Number(of) || j.of;
        if (done && !j.done) { j.done = true; j.doneAt = T; j.percent = 100; console.info("taylor-progress: a job finished"); }
        const filled = Math.floor(j.percent / 100 * 12 + 0.001);
        for (let i = j.born.length; i < filled; i++) j.born.push(T + (i - j.born.length) * 0.05);
        if (!job || job.key === key || job.done || !j.done) job = j;
        jobsChanged();
    }
    // the taylor-jobs bridge: one JSON line per change
    Process {
        id: bridge
        running: true
        command: ["/usr/libexec/taylor-jobs"]
        stdout: SplitParser {
            onRead: (line) => {
                let d = null;
                try { d = JSON.parse(line); } catch (e) { return; }
                win.report("kde-" + d.id, d.title, d.percent, d.files, d.of, d.done);
            }
        }
        stderr: SplitParser { onRead: (line) => console.info("taylor-progress: " + line.replace(/^#\s*/, "")) }
        onExited: (code) => console.info("taylor-progress: the job bridge ended (" + code + ")")
    }

    function label(j) {
        const t = j.title || "Working";
        if (!j.done) return j.of > 0 ? t + " " + Math.min(j.files, j.of) + " of " + j.of + " items" : t + " " + Math.round(j.percent) + "%";
        const past = { Copying: "Copied", Moving: "Moved", Deleting: "Deleted", Downloading: "Downloaded", Extracting: "Extracted" }[t.split(" ")[0]];
        if (past) return j.of > 0 ? past + " " + j.of + " items" : past;
        return "Done";
    }

    function cl(v) { return Math.max(0, Math.min(1, v)); }
    function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }
    Canvas {
        id: art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const x = getContext("2d");
            x.reset();
            const j = win.job;
            if (!j) return;
            const T = win.now(), U = win.u, still = win.theme.still;
            const ce = j.done ? T - j.doneAt : 0, gone = j.done ? win.sm((ce - 2.2) / 0.6) : 0;
            if (j.done && ce > 2.9) {
                delete win.jobs[j.key];
                const rest = Object.keys(win.jobs).map((k) => win.jobs[k]).filter((o) => !o.done);
                win.job = rest.length ? rest[rest.length - 1] : null;
                return;
            }
            const ca = 1 - gone;
            const s = win.label(j);
            x.font = Math.round(12 * U) + "px " + win.theme.sans;
            const tw = x.measureText(s).width;
            const by = height - 14 - 26, bx = width - tw - 16 * U - 14;
            const cols = [win.theme.accent, win.theme.mix(win.theme.accent, win.theme.soft, 0.5), win.theme.soft];
            // the same dark see-through line her notification list uses, so it reads on the daytime sky
            const px0 = bx - 13 * U, pw = width - px0, ph = 22 * U, py0 = by - ph / 2, r = ph / 2;
            x.globalAlpha = 0.62 * ca; x.fillStyle = win.theme.bg;
            x.beginPath(); x.moveTo(px0 + r, py0); x.arcTo(px0 + pw, py0, px0 + pw, py0 + ph, r); x.arcTo(px0 + pw, py0 + ph, px0, py0 + ph, r);
            x.arcTo(px0, py0 + ph, px0, py0, r); x.arcTo(px0, py0, px0 + pw, py0, r); x.closePath(); x.fill();
            x.globalAlpha = 0.25 * ca; x.strokeStyle = win.theme.text; x.lineWidth = 1;
            x.beginPath(); x.arc(bx, by, 7 * U, 0, 6.2832); x.stroke();
            for (let i = 0; i < j.born.length && i < 12; i++) {
                const aa = -1.5708 + i / 12 * 6.2832, pe = still ? 1 : win.sm((T - j.born[i]) / 0.3);
                if (pe <= 0) continue;
                const r2 = (7 + (1 - pe) * 14) * U;
                x.globalAlpha = pe * ca; x.fillStyle = cols[i % 3];
                x.beginPath(); x.arc(bx + Math.cos(aa) * r2, by + Math.sin(aa) * r2, 1.5 * U, 0, 6.2832); x.fill();
            }
            if (j.done && !still) {
                const pu = win.cl(ce / 0.9);
                x.globalAlpha = 0.6 * (1 - pu) * ca; x.strokeStyle = win.theme.accent; x.lineWidth = 1.5 * U;
                x.beginPath(); x.arc(bx, by, (7 + pu * 14) * U, 0, 6.2832); x.stroke();
            }
            x.textAlign = "left"; x.textBaseline = "middle";
            x.globalAlpha = 0.9 * ca; x.fillStyle = j.done ? win.theme.soft : win.theme.text2;
            x.fillText(s, bx + 16 * U, by + 0.5);
            x.globalAlpha = 1;
        }
    }
    FrameAnimation { running: win.visible; onTriggered: art.requestPaint() }
}
