.pragma library
// TAYLOR's dial on her desktop, from her "login unlock to desktop" mockup (tayloros_login_unlock_to_desktop_full_sequence.html),
// her dial() drawing line for line. The same file is in greeter/ (the login screen draws the dial into place, the
// desktop keeps it): keep the two copies the same.
//
// Where it sits: the spot the Horizon sky already keeps free for it (Sky.qml steers the sun and moon round a circle at
// 930, 390 of its 1440 x 900 drawing). Its size is hers: radius 58 on her 380 px tall mockup.

function spot(W, H) {
    return { x: W * 930 / 1440, y: H * 390 / 900, r: 58 * H / 380, k: H / 380 };
}

// The three arcs turn slowly round the dial; both the login screen and the desktop take the angle from the clock, so
// the dial does not jump when one hands over to the other.
function arcAngle() { return (Date.now() / 1000 * 0.12) % 6.2832; }

// prog: how much of the ring is drawn (0..1). arcB: the three outer arcs (0..1). hot: the glow (0..1). al: fade.
function draw(x, px, py, R, al, prog, arcB, hot, rot, T) {
    if (al <= 0 || prog <= 0) return;
    var ACC = '#4FB386';
    var k = R / 30, s0 = -1.5708, s1 = s0 + prog * 6.2832;
    x.lineCap = 'round'; x.strokeStyle = ACC;
    x.globalAlpha = (0.12 + 0.2 * hot) * al; x.lineWidth = (7 + 4 * hot) * k; x.beginPath(); x.arc(px, py, R, s0, s1, false); x.stroke();
    x.globalAlpha = 0.95 * al; x.lineWidth = (1.5 + 1.5 * hot) * k / 1.93; x.beginPath(); x.arc(px, py, R, s0, s1, false); x.stroke();
    if (R > 40 * k / 1.93) { x.globalAlpha = 0.35 * al * prog; x.lineWidth = k / 1.93; x.beginPath(); x.arc(px, py, R * 0.62, s0, s1, false); x.stroke(); }
    x.strokeStyle = '#EDEFEE'; x.lineWidth = k / 1.93;
    var nt = Math.floor(48 * prog);
    for (var q = 0; q < nt; q++) {
        var an = s0 + q / 48 * 6.2832, big = q % 4 === 0;
        x.globalAlpha = (big ? 0.5 : 0.25) * al;
        x.beginPath(); x.moveTo(px + Math.cos(an) * (R + 6 * k), py + Math.sin(an) * (R + 6 * k));
        x.lineTo(px + Math.cos(an) * (R + (big ? 12 : 9) * k), py + Math.sin(an) * (R + (big ? 12 : 9) * k)); x.stroke();
    }
    if (arcB > 0) {
        x.strokeStyle = ACC; x.lineWidth = 2.5 * k / 1.93;
        for (var j = 0; j < 3; j++) {
            var st = rot + j * 2.0944;
            x.globalAlpha = 0.8 * al * arcB * (0.85 + 0.15 * Math.sin(T * 0.8));
            x.beginPath(); x.arc(px, py, R + 18 * k, st, st + 0.2 + 0.7 * arcB, false); x.stroke();
        }
    }
    x.globalAlpha = 1;
}

// The status line under the dial, letter-spaced: her "ALL CLEAR.", or what the launcher just did ("OPENING STEAM.").
function words(x, px, py, k, al, font, str) {
    if (al <= 0) return;
    str = str || 'ALL CLEAR.';
    var gap = 3 * k, w = 0, i;
    x.font = font; x.fillStyle = '#C8CCCA'; x.globalAlpha = 0.85 * al; x.textBaseline = 'middle';
    for (i = 0; i < str.length; i++) w += x.measureText(str[i]).width + gap;
    w -= gap;
    var sx = px - w / 2; x.textAlign = 'left';
    for (i = 0; i < str.length; i++) { x.fillText(str[i], sx, py); sx += x.measureText(str[i]).width + gap; }
    x.textAlign = 'center'; x.globalAlpha = 1;
}
